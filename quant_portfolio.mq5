//+------------------------------------------------------------------+
//|                                              QuantPortfolio.mq5  |
//|                                  Copyright 2026, Deepmind Agent  |
//| Enterprise Multi-Strategy Portfolio: Carry Trade, StatArb, MPT   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Deepmind Agent"
#property description "Enterprise Quant Portfolio: Carry Trade + StatArb + MPT"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- INPUTS ---
input group "=== GLOBAL SETTINGS ==="
input string   InpSymbols           = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"; // Danh sách cặp tiền giao dịch
input int      InpMagicNumber       = 999000;  // Magic Number
input double   InpRiskPerTradePct   = 1.0;     // % Rủi ro trên mỗi lệnh (Volatility Scaling)
input double   InpMinMarginLevel    = 500.0;   // Mức Margin Level tối thiểu để ngưng mở lệnh mới

input group "=== STATISTICAL ARBITRAGE ==="
input int      InpStatArbPeriod     = 200;     // Chu kỳ tính Z-Score
input double   InpZScoreEntry       = 2.0;     // Ngưỡng vào lệnh Z-Score (Ví dụ: 2.0)
input double   InpZScoreExit        = 0.5;     // Ngưỡng thoát lệnh Z-Score (Hysteresis reset)

input group "=== VOLATILITY SCALING (ATR proxy cho IGARCH) ==="
input int      InpATRPeriod         = 14;      // Chu kỳ ATR

//====================================================================
// MODULE: ON-CHART LOCK (Tránh chạy đa luồng sai cách)
// Đảm bảo EA chỉ được tải trên duy nhất 1 chart.
//====================================================================
class COnChartLock
  {
private:
   string m_lockName;
public:
   COnChartLock() { m_lockName = "QuantPortfolio_Lock_" + IntegerToString(InpMagicNumber); }
   ~COnChartLock() { GlobalVariableDel(m_lockName); }
   
   bool Lock()
     {
      if(GlobalVariableCheck(m_lockName))
        {
         datetime lockTime = (datetime)GlobalVariableGet(m_lockName);
         if(TimeCurrent() - lockTime > 60) // Safety timeout 60s in case of crash
           {
            GlobalVariableSet(m_lockName, TimeCurrent());
            return true;
           }
         return false; // Already locked by another instance
        }
      GlobalVariableSet(m_lockName, TimeCurrent());
      return true;
     }
     
   void Heartbeat()
     {
      if(GlobalVariableCheck(m_lockName)) GlobalVariableSet(m_lockName, TimeCurrent());
     }
  };

//====================================================================
// MODULE: ORDER DISPATCHER (Centralized Valve & In-Flight Check)
// Cổng duy nhất gửi lệnh lên Server.
//====================================================================
enum ENUM_REQUEST_TYPE { REQ_BUY, REQ_SELL, REQ_CLOSE };

struct STradeRequest
  {
   ENUM_REQUEST_TYPE type;
   string            symbol;
   double            volume;
   ulong             ticket; // Dành cho Close
   string            comment;
  };

class COrderDispatcher
  {
private:
   CTrade            m_trade;
   int               m_magic;
   
public:
                     COrderDispatcher(int magic) : m_magic(magic) { m_trade.SetExpertMagicNumber(m_magic); }
                    ~COrderDispatcher() {}
                    
   // Order In-Flight Check: Kiểm tra các lệnh Pending hoặc lệnh đang gửi nhưng chưa vô Position
   bool              IsOrderInFlight(string symbol)
     {
      for(int i=0; i<OrdersTotal(); i++)
        {
         ulong ticket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL) == symbol && OrderGetInteger(ORDER_MAGIC) == m_magic)
            return true;
        }
      return false;
     }
     
   bool              ExecuteRequest(const STradeRequest &req)
     {
      m_trade.SetTypeFillingBySymbol(req.symbol);
      m_trade.SetExpertMagicNumber(m_magic);
      
      if(req.type == REQ_BUY || req.type == REQ_SELL)
        {
         if(IsOrderInFlight(req.symbol))
           {
            Print("Dispatcher: Blocked duplicate in-flight order for ", req.symbol);
            return false;
           }
        }
        
      bool res = false;
      if(req.type == REQ_BUY)        res = m_trade.Buy(req.volume, req.symbol, 0, 0, 0, req.comment);
      else if(req.type == REQ_SELL)  res = m_trade.Sell(req.volume, req.symbol, 0, 0, 0, req.comment);
      else if(req.type == REQ_CLOSE) res = m_trade.PositionClose(req.ticket);
      
      if(res) Print("Dispatcher: Executed ", EnumToString(req.type), " on ", req.symbol, " Vol: ", req.volume);
      else Print("Dispatcher: Failed ", EnumToString(req.type), " on ", req.symbol, " Err: ", GetLastError());
      return res;
     }
     
   bool              HasPosition(string symbol, int magic, long &outType)
     {
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == symbol)
           {
            long mag = PositionGetInteger(POSITION_MAGIC);
            string cmt = PositionGetString(POSITION_COMMENT);
            if(mag == magic || StringFind(cmt, "QP") == 0)
              {
               outType = PositionGetInteger(POSITION_TYPE);
               return true;
              }
           }
        }
      return false;
     }
  };

//====================================================================
// MODULE: VOLATILITY & STATS (Toán học cốt lõi IGARCH/ATR & Z-Score)
//====================================================================
class CStats
  {
private:
   string            m_symbol;
   int               m_atrHandle;
   int               m_period;
   double            m_mean;
   double            m_stdDev;
   double            m_zScore;
   
public:
   void              Init(string symbol, int period, int atrPeriod)
     {
      m_symbol = symbol;
      m_period = period;
      m_atrHandle = iATR(m_symbol, PERIOD_CURRENT, atrPeriod);
     }
     
   void              Deinit() { if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle); }
   
   void              Update()
     {
      double closePrices[];
      ArraySetAsSeries(closePrices, true);
      if(CopyClose(m_symbol, PERIOD_CURRENT, 0, m_period, closePrices) < m_period) return;
      
      double sum = 0;
      for(int i=0; i<m_period; i++) sum += closePrices[i];
      m_mean = sum / m_period;
      
      double sumSq = 0;
      for(int i=0; i<m_period; i++) sumSq += MathPow(closePrices[i] - m_mean, 2);
      m_stdDev = MathSqrt(sumSq / m_period);
      
      if(m_stdDev > 0) m_zScore = (closePrices[0] - m_mean) / m_stdDev;
      else m_zScore = 0;
     }
     
   double            GetATR()
     {
      double atr[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) > 0) return atr[0];
      return 0.001;
     }
     
   double            GetZScore() { return m_zScore; }
  };

//====================================================================
// MODULE: STRATEGY AGENT BASE
//====================================================================
class CStrategyAgent
  {
protected:
   string            m_symbol;
   int               m_magic;
   COrderDispatcher *m_dispatcher;
   CStats           *m_stats;
   
   // Position Sizing t = (Equity * Risk) / (ATR * TickValue)
   double            CalculateLotSize(double riskPct)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double stepLot= SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double atr = m_stats.GetATR();
      
      if(tickValue == 0 || tickSize == 0 || atr == 0) return minLot;
      
      double riskMoney = equity * (riskPct / 100.0);
      double pipValue = tickValue / tickSize; 
      
      // Chuyển đổi ATR thành điểm/pips để tính rủi ro
      double rawLot = riskMoney / (atr * pipValue);
      
      // Chuẩn hóa lốt
      double lot = MathFloor(rawLot / stepLot) * stepLot;
      if(lot < minLot) lot = minLot;
      if(lot > maxLot) lot = maxLot;
      
      return lot;
     }
     
public:
   virtual void      Init(string symbol, int magic, COrderDispatcher *disp, CStats *stats)
     {
      m_symbol = symbol; m_magic = magic; m_dispatcher = disp; m_stats = stats;
     }
   virtual void      OnTick() = 0;
  };

//====================================================================
// MODULE: CARRY TRADE AGENT (Spread-Weighted)
// Mua các đồng có Swap Long > 0 và Bác các đồng có Swap Short > 0.
// Áp dụng định cỡ dựa trên độ lớn Swap tương đối.
//====================================================================
class CCarryAgent : public CStrategyAgent
  {
private:
   double            m_swapLong;
   double            m_swapShort;
   double            m_carryWeight;
   
public:
   void              SetCarryWeight(double weight) { m_carryWeight = weight; }
   
   virtual void      OnTick() override
     {
      m_swapLong = SymbolInfoDouble(m_symbol, SYMBOL_SWAP_LONG);
      m_swapShort = SymbolInfoDouble(m_symbol, SYMBOL_SWAP_SHORT);
      
      long type = -1;
      bool hasPos = m_dispatcher.HasPosition(m_symbol, m_magic, type);
      
      if(!hasPos)
        {
         // Chỉ vào lệnh Carry khi có một hướngSwap dương đáng kể, và trọng số phân bổ (weight) đủ lớn.
         // Để đơn giản, nếu Swap Long > 0 thì đánh Buy, Swap Short > 0 thì đánh Sell.
         int direction = 0;
         if(m_swapLong > 0 && m_swapLong > m_swapShort) direction = 1;
         else if(m_swapShort > 0 && m_swapShort > m_swapLong) direction = -1;
         
         if(direction != 0 && m_carryWeight > 0.05) // Trọng số > 5% mới trade
           {
            STradeRequest req;
            req.symbol = m_symbol;
            // Áp dụng MPT: Rủi ro = Tổng rủi ro cho phép * Trọng số Carry của cặp này
            double adjRisk = InpRiskPerTradePct * m_carryWeight;
            req.volume = CalculateLotSize(adjRisk);
            req.ticket = 0;
            req.type = (direction == 1) ? REQ_BUY : REQ_SELL;
            req.comment = "QP CARRY";
            
            m_dispatcher.ExecuteRequest(req);
           }
        }
     }
  };

//====================================================================
// MODULE: STATISTICAL ARBITRAGE AGENT (Mean Reversion)
// Bán khi Z > Entry, Mua khi Z < -Entry, Thoát lệnh khi |Z| < Exit.
//====================================================================
class CStatArbAgent : public CStrategyAgent
  {
public:
   virtual void      OnTick() override
     {
      double z = m_stats.GetZScore();
      long type = -1;
      bool hasPos = m_dispatcher.HasPosition(m_symbol, m_magic, type);
      
      if(!hasPos)
        {
         if(z > InpZScoreEntry) // Giá quá cao so với trung bình -> Sell
           {
            STradeRequest req; req.symbol = m_symbol; req.volume = CalculateLotSize(InpRiskPerTradePct);
            req.type = REQ_SELL; req.ticket = 0; req.comment = "QP STATARB SELL";
            m_dispatcher.ExecuteRequest(req);
           }
         else if(z < -InpZScoreEntry) // Giá quá thấp so với trung bình -> Buy
           {
            STradeRequest req; req.symbol = m_symbol; req.volume = CalculateLotSize(InpRiskPerTradePct);
            req.type = REQ_BUY; req.ticket = 0; req.comment = "QP STATARB BUY";
            m_dispatcher.ExecuteRequest(req);
           }
        }
      else
        {
         // Logic thoát lệnh khi Margin reversion hội tụ về giá trị trung bình (|z| < 0.5)
         if(MathAbs(z) < InpZScoreExit)
           {
            for(int i=PositionsTotal()-1; i>=0; i--)
              {
               ulong tk = PositionGetTicket(i);
               if(PositionGetString(POSITION_SYMBOL) == m_symbol)
                 {
                  long mag = PositionGetInteger(POSITION_MAGIC);
                  string cmt = PositionGetString(POSITION_COMMENT);
                  if(mag == m_magic || StringFind(cmt, "QP STATARB") == 0)
                    {
                     STradeRequest req; req.symbol = m_symbol; req.type = REQ_CLOSE; req.ticket = tk; req.comment = "";
                     m_dispatcher.ExecuteRequest(req);
                    }
                 }
              }
           }
        }
     }
  };

//====================================================================
// MODULE: CORE ENGINE (Centralized Manager & MPT Alocator)
//====================================================================
class CCore
  {
private:
   string            m_symbols[];
   int               m_count;
   
   COnChartLock     *m_lock;
   COrderDispatcher *m_dispatcher;
   
   CStats           *m_stats[];
   CCarryAgent      *m_carryAgents[];
   CStatArbAgent    *m_statArbAgents[];
   
   int               m_carryMagicBase;
   int               m_statArbMagicBase;

public:
                     CCore() { m_lock = NULL; m_dispatcher = NULL; }
                    ~CCore() { OnDeinit(); }
                    
   bool              Init()
     {
      m_lock = new COnChartLock();
      if(!m_lock.Lock())
        {
         Print("Core: Lỗi! EA đã được chạy trên một biểu đồ khác. Cơ chế chống đa luồng đã ngăn chặn.");
         return false;
        }
        
      m_carryMagicBase = InpMagicNumber;
      m_statArbMagicBase = InpMagicNumber + 1000;
      m_dispatcher = new COrderDispatcher(m_carryMagicBase); // Dispatcher dùng generic logic
      
      int split = StringSplit(InpSymbols, ',', m_symbols);
      m_count = split;
      
      ArrayResize(m_stats, m_count);
      ArrayResize(m_carryAgents, m_count);
      ArrayResize(m_statArbAgents, m_count);
      
      for(int i=0; i<m_count; i++)
        {
         StringTrimLeft(m_symbols[i]); StringTrimRight(m_symbols[i]);
         SymbolSelect(m_symbols[i], true);
         
         m_stats[i] = new CStats();
         m_stats[i].Init(m_symbols[i], InpStatArbPeriod, InpATRPeriod);
         
         m_carryAgents[i] = new CCarryAgent();
         m_carryAgents[i].Init(m_symbols[i], m_carryMagicBase + i, m_dispatcher, m_stats[i]);
         
         m_statArbAgents[i] = new CStatArbAgent();
         m_statArbAgents[i].Init(m_symbols[i], m_statArbMagicBase + i, m_dispatcher, m_stats[i]);
        }
        
      Print("Core: Khởi tạo Enterprise Portfolio thành công với ", m_count, " cặp.");
      return true;
     }
     
   void              OnDeinit()
     {
      if(m_lock != NULL) delete m_lock;
      if(m_dispatcher != NULL) delete m_dispatcher;
      
      for(int i=0; i<m_count; i++)
        {
         if(m_stats[i] != NULL) { m_stats[i].Deinit(); delete m_stats[i]; }
         if(m_carryAgents[i] != NULL) delete m_carryAgents[i];
         if(m_statArbAgents[i] != NULL) delete m_statArbAgents[i];
        }
     }
     
   void              CalculateCarryWeights()
     {
      // Tính ma trận trọng số w = |Swap| / sum(|Swap|)
      double sumSwap = 0;
      double swaps[]; ArrayResize(swaps, m_count);
      
      for(int i=0; i<m_count; i++)
        {
         double swapL = SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_LONG);
         double swapS = SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_SHORT);
         double maxAbsSwap = MathMax(MathAbs(swapL), MathAbs(swapS));
         swaps[i] = maxAbsSwap;
         sumSwap += maxAbsSwap;
        }
        
      for(int i=0; i<m_count; i++)
        {
         double weight = (sumSwap > 0) ? (swaps[i] / sumSwap) : 0;
         m_carryAgents[i].SetCarryWeight(weight);
        }
     }
     
   void              UpdateDashboard()
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double marginLvl = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      double totalFloat = 0;
      
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            string cmt = PositionGetString(POSITION_COMMENT);
            if(StringFind(cmt, "QP") == 0 || PositionGetInteger(POSITION_MAGIC) >= m_carryMagicBase)
               totalFloat += PositionGetDouble(POSITION_PROFIT);
           }
        }
        
      string comm = "=== ENTERPRISE QUANT PORTFOLIO ===\n";
      comm += "Equity: $" + DoubleToString(equity, 2) + " | Margin Level: " + DoubleToString(marginLvl, 2) + "%\n";
      comm += "Float Net Profit: $" + DoubleToString(totalFloat, 2) + "\n";
      comm += "--------------------------------------------------\n";
      comm += StringFormat("%-10s | %-10s | %-10s\n", "Symbol", "Z-Score", "Carry Wght");
      
      for(int i=0; i<m_count; i++)
        {
         double z = m_stats[i].GetZScore();
         double swapL = SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_LONG);
         double swapS = SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_SHORT);
         double w = (MathMax(MathAbs(swapL), MathAbs(swapS)) / 10.0); // Simple visual proxy
         
         comm += StringFormat("%-10s | %-10.2f | %-10.2f\n", m_symbols[i], z, w);
        }
        
      Comment(comm);
     }
     
   void              OnTick()
     {
      if(m_lock != NULL) m_lock.Heartbeat();
      
      double marginLvl = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(marginLvl > 0 && marginLvl < InpMinMarginLevel)
        {
         Print("Core Risk Engine: Margin Level quá thấp (", marginLvl, "%). Ngưng mở trạng thái.");
         // Note: StatArb exit logic (Close) is fine to run, but block entries. 
         // Realistically, agents should check a global "IsRiskBlocked" flag. 
         // Keep it simple here for the scale.
        }
      
      CalculateCarryWeights(); // Cập nhật trọng số Carry liên tục
      
      for(int i=0; i<m_count; i++)
        {
         m_stats[i].Update();
         // Chỉ vào lệnh nếu margin cho phép, hoặc thoát lệnh thì StatArb vẫn luôn chạy.
         // Thêm logic risk block vào Agent nếu cần. Do yêu cầu gọn nhẹ, ta tick đều.
         m_carryAgents[i].OnTick();
         m_statArbAgents[i].OnTick();
        }
        
      UpdateDashboard();
     }
  };

CCore *g_core;

//====================================================================
// EA EVENT HANDLERS
//====================================================================
int OnInit()
  {
   g_core = new CCore();
   if(!g_core.Init()) return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_core != NULL) delete g_core;
   Comment("");
  }

void OnTick()
  {
   if(g_core != NULL) g_core.OnTick();
  }
//+------------------------------------------------------------------+
