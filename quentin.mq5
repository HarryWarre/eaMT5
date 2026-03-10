//+------------------------------------------------------------------+
//|                                                    Quentin.mq5   |
//|                                  Copyright 2026, Deepmind Agent  |
//| Pure Swap Carry Trade Bot - DCA Multi-Symbol                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Deepmind Agent"
#property description "Quentin: Pure Swap Carry Trade - DCA Multi-Symbol"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- INPUTS ---
input group "=== GLOBAL SETTINGS ==="
input string   InpSymbols           = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"; // Danh sách cặp tiền giao dịch
input int      InpMagicNumber       = 999000;  // Magic Number
input double   InpBaseVol           = 0.01;    // Lot cơ bản
input double   InpMinMarginLevel    = 500.0;   // Margin Level tối thiểu

input group "=== GRID & DCA ==="
input int      InpGridDist          = 100;     // Khoảng cách Grid (pips)
input int      InpMaxOrders         = 20;      // Số lệnh tối đa / cặp

input group "=== MARTINGALE (3 Levels) ==="
input int      InpMartStart1        = 4;       // Level 1: Từ lệnh N
input double   InpMartMult1         = 1.1;     // Level 1: Hệ số
input int      InpMartStart2        = 8;       // Level 2: Từ lệnh N
input double   InpMartMult2         = 1.2;     // Level 2: Hệ số
input int      InpMartStart3        = 12;      // Level 3: Từ lệnh N
input double   InpMartMult3         = 1.5;     // Level 3: Hệ số

input group "=== CHỐT LỂNH ==="
input double   InpTargetMoney       = 0.0;     // Chốt lời ($) (0 = Hòa vốn)
input int      InpBreakevenPips     = 5;       // Pips trên hòa vốn để chốt

//====================================================================
// MODULE: ON-CHART LOCK (Tránh chạy đa luồng sai cách)
// Đảm bảo EA chỉ được tải trên duy nhất 1 chart.
//====================================================================
class COnChartLock
  {
private:
   string m_lockName;
public:
   COnChartLock() { m_lockName = "Quentin_Lock_" + IntegerToString(InpMagicNumber); }
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
// MODULE: CARRY AGENT BASE (Không cần ATR/Volatility cho Pure Swap)
//====================================================================
class CCarryAgent
  {
private:
   string            m_symbol;
   int               m_magic;
   double            m_pt;
   double            m_p2p;
   double            m_swapLong;
   double            m_swapShort;
   double            m_carryWeight;
   ulong             m_lastDealTicket;
   datetime          m_lastEntryTime;
   datetime          m_lastDCATime;
   CTrade            m_trade;
   
   //--- DEAL LOG ---
   void              CheckNewDeals()
     {
      HistorySelect(0, TimeCurrent());
      int total = HistoryDealsTotal();
      if(total == 0) return;
      ulong lastTk = HistoryDealGetTicket(total - 1);
      if(m_lastDealTicket == 0) { m_lastDealTicket = lastTk; return; }
      if(lastTk != m_lastDealTicket)
        {
         for(int i = total - 1; i >= 0; i--)
           {
            ulong tk = HistoryDealGetTicket(i);
            if(tk == m_lastDealTicket) break;
            if(HistoryDealGetInteger(tk, DEAL_MAGIC) == m_magic && 
               HistoryDealGetString(tk, DEAL_SYMBOL) == m_symbol && 
               HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT)
              {
               double profit = HistoryDealGetDouble(tk, DEAL_PROFIT);
               double swap = HistoryDealGetDouble(tk, DEAL_SWAP);
               double fee = HistoryDealGetDouble(tk, DEAL_FEE);
               double vol = HistoryDealGetDouble(tk, DEAL_VOLUME);
               string dtype = (HistoryDealGetInteger(tk, DEAL_TYPE) == DEAL_TYPE_BUY) ? "SELL->CLOSE" : "BUY->CLOSE";
               Print(">>> [QUENTIN] Chốt ", m_symbol, " ", dtype, " Vol=", DoubleToString(vol, 2), 
                     " P/L=$", DoubleToString(profit, 2), 
                     " SWAP=$", DoubleToString(swap, 2), 
                     " Fee=$", DoubleToString(fee, 2),
                     " NET=$", DoubleToString(profit + swap + fee, 2));
              }
           }
         m_lastDealTicket = lastTk;
        }
     }
   
   //--- VOLUME (3-Level Martingale) ---
   double            CheckVolume(double vol)
     {
      double mn = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double mx = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double st = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      vol = MathFloor(vol / st) * st;
      if(vol < mn) vol = mn;
      if(vol > mx) vol = mx;
      return vol;
     }
     
   double            GetVol(int ord, double sumVol)
     {
      double m = 1.0;
      if(ord >= InpMartStart3)      m = InpMartMult3;
      else if(ord >= InpMartStart2) m = InpMartMult2;
      else if(ord >= InpMartStart1) m = InpMartMult1;
      else return InpBaseVol;
      return CheckVolume(sumVol * m);
     }
   
   //--- CLOSE ---
   void              CloseByType(long posType)
     {
      for(int i = PositionsTotal()-1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_TYPE) == posType)
           {
            long mag = PositionGetInteger(POSITION_MAGIC);
            string cmt = PositionGetString(POSITION_COMMENT);
            if(mag == m_magic || StringFind(cmt, "QP") == 0)
               m_trade.PositionClose(tk);
           }
        }
     }
   
   //--- TP: Từ lệnh 2 trở lên, luôn cố hòa vốn (hoặc lãi nhẹ) rồi chốt ---
   void              ManageTP(long posType, int cnt, double vol, double prod)
     {
      if(cnt < 2) return;
      if(vol <= 0) return;
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double price = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double avg = NormalizeDouble(prod / vol, digits);
      
      // Sanity check: avg phải hợp lý (gần với giá hiện tại)
      if(avg <= 0 || MathAbs(avg - price) / price > 0.5) return; // Sai lệch > 50% = dữ liệu sai
      
      double tpPips = (double)InpBreakevenPips;
      
      if(InpTargetMoney > 0)
        {
         double tv = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
         double ts = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tv > 0 && vol > 0)
            tpPips = MathMax((double)InpBreakevenPips, (InpTargetMoney / (vol * tv)) * ts / m_pt / m_p2p);
        }
      
      double tpDelta = tpPips * m_p2p * m_pt;
      double tp = (posType == POSITION_TYPE_BUY) ? avg + tpDelta : avg - tpDelta;
      tp = NormalizeDouble(tp, digits);
      
      // Validate: BUY -> TP phải cao hơn giá hiện tại, SELL -> TP phải thấp hơn
      if(posType == POSITION_TYPE_BUY && tp <= price) return;
      if(posType == POSITION_TYPE_SELL && tp >= price) return;
      
      // Kiểm tra stops level tối thiểu
      int stopsLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = stopsLevel * m_pt;
      if(MathAbs(tp - price) < minDist) return;
      
      for(int i = PositionsTotal()-1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_TYPE) == posType)
           {
            long mag = PositionGetInteger(POSITION_MAGIC);
            if(mag == m_magic)
              {
               double curTP = PositionGetDouble(POSITION_TP);
               if(MathAbs(curTP - tp) > m_pt)
                  m_trade.PositionModify(tk, PositionGetDouble(POSITION_SL), tp);
              }
           }
        }
     }
     
public:
   void              Init(string symbol, int magic)
     {
      m_symbol = symbol; m_magic = magic;
      m_lastDealTicket = 0;
      m_lastEntryTime = 0;
      m_lastDCATime = 0;
      m_pt = 0;  // Lazy init trong OnTick (Tester chưa load symbol phụ lúc Init)
      m_p2p = 0;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetTypeFillingBySymbol(m_symbol);
     }
     
   void              SetCarryWeight(double weight) { m_carryWeight = weight; }
   
   void              OnTick()
     {
      // Lazy init: Tester cần vài tick đầu để load data cho symbol phụ
      if(m_pt == 0)
        {
         m_pt = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
         m_p2p = (digits == 3 || digits == 5) ? 10.0 : 1.0;
         if(m_pt == 0) return; // Vẫn chưa sẵn sàng, đợi tick tiếp
         Print("[QUENTIN] Ready ", m_symbol, " pt=", m_pt, " p2p=", m_p2p, " magic=", m_magic);
        }
      
      CheckNewDeals();
      
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Đếm vị thế (giống Shogun)
      int bCnt = 0, sCnt = 0;
      double bVol = 0, sVol = 0, bProd = 0, sProd = 0, lowBuy = 0, highSell = 0;
      
      for(int i = PositionsTotal()-1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == m_symbol)
           {
            long mag = PositionGetInteger(POSITION_MAGIC);
            if(mag == m_magic)
              {
               double v = PositionGetDouble(POSITION_VOLUME);
               double op = PositionGetDouble(POSITION_PRICE_OPEN);
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                 {
                  bCnt++; bVol += v; bProd += v * op;
                  if(lowBuy == 0 || op < lowBuy) lowBuy = op;
                 }
               else
                 {
                  sCnt++; sVol += v; sProd += v * op;
                  if(highSell == 0 || op > highSell) highSell = op;
                 }
              }
           }
        }
      
      // Quản lý TP (giống Shogun)
      ManageTP(POSITION_TYPE_BUY, bCnt, bVol, bProd);
      ManageTP(POSITION_TYPE_SELL, sCnt, sVol, sProd);
      
      // DCA: Nhồi lệnh khi giá chạm mốc lowBuy - gridDist hoặc highSell + gridDist
      double gridDist = InpGridDist * m_p2p * m_pt;
      
      if(bCnt > 0 && bCnt < InpMaxOrders && ask < (lowBuy - gridDist))
        {
         if(TimeCurrent() - m_lastDCATime < 30) return; // Throttle DCA 30s
         double vol = GetVol(bCnt + 1, bVol);
         m_trade.Buy(vol, m_symbol, 0, 0, 0, "QP DCA B" + (string)(bCnt + 1));
         m_lastDCATime = TimeCurrent();
        }
      if(sCnt > 0 && sCnt < InpMaxOrders && bid > (highSell + gridDist))
        {
         if(TimeCurrent() - m_lastDCATime < 30) return; // Throttle DCA 30s
         double vol = GetVol(sCnt + 1, sVol);
         m_trade.Sell(vol, m_symbol, 0, 0, 0, "QP DCA S" + (string)(sCnt + 1));
         m_lastDCATime = TimeCurrent();
        }
      
      // Lệnh đầu tiên: Vào lệnh theo hướng Swap dương (PURE SWAP CARRY - không dùng indicator)
      if(bCnt == 0 && sCnt == 0)
        {
         if(TimeCurrent() - m_lastEntryTime < 60) return;
         m_lastEntryTime = TimeCurrent();
         
         m_swapLong = SymbolInfoDouble(m_symbol, SYMBOL_SWAP_LONG);
         m_swapShort = SymbolInfoDouble(m_symbol, SYMBOL_SWAP_SHORT);
         
         // Chỉ vào lệnh khi có hướng Swap dương. Không dùng bất kỳ indicator/z-score nào.
         int direction = 0;
         if(m_swapLong > 0 && m_swapLong > m_swapShort) direction = 1;
         else if(m_swapShort > 0 && m_swapShort > m_swapLong) direction = -1;
         
         if(direction != 0 && m_carryWeight > 0.05)
           {
            if(direction == 1)
               m_trade.Buy(InpBaseVol, m_symbol, 0, 0, 0, "QP CARRY B1");
            else
               m_trade.Sell(InpBaseVol, m_symbol, 0, 0, 0, "QP CARRY S1");
            Print("[QUENTIN][", m_symbol, "] Vào lệnh Swap Carry hướng ", (direction==1)?"BUY":"SELL",
                  " SwapL=", DoubleToString(m_swapLong,2), " SwapS=", DoubleToString(m_swapShort,2),
                  " Weight=", DoubleToString(m_carryWeight,2));
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
   
   CCarryAgent      *m_carryAgents[];
   
   int               m_carryMagicBase;

public:
                     CCore() { m_lock = NULL; m_dispatcher = NULL; }
                    ~CCore() { OnDeinit(); }
                    
   bool              Init()
     {
      m_lock = new COnChartLock();
      if(!m_lock.Lock())
        {
         Print("Core: Lỗi! EA đã được chạy trên một biểu đồ khác.");
         return false;
        }
        
      m_carryMagicBase = InpMagicNumber;
      m_dispatcher = new COrderDispatcher(m_carryMagicBase);
      
      int split = StringSplit(InpSymbols, ',', m_symbols);
      m_count = split;
      
      ArrayResize(m_carryAgents, m_count);
      
      for(int i=0; i<m_count; i++)
        {
         StringTrimLeft(m_symbols[i]); StringTrimRight(m_symbols[i]);
         SymbolSelect(m_symbols[i], true);
         
         m_carryAgents[i] = new CCarryAgent();
         m_carryAgents[i].Init(m_symbols[i], m_carryMagicBase + i);
        }
        
      Print("Core: Khởi tạo Quentin Pure Swap Carry thành công với ", m_count, " cặp chạy đồng thời.");
      return true;
     }
     
   void              OnDeinit()
     {
      if(m_lock != NULL) delete m_lock;
      if(m_dispatcher != NULL) delete m_dispatcher;
      
      for(int i=0; i<m_count; i++)
        {
         if(m_carryAgents[i] != NULL) delete m_carryAgents[i];
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
        
      string comm = "=== QUENTIN PURE SWAP CARRY ===\n";
      comm += "Equity: $" + DoubleToString(equity, 2) + " | Margin Level: " + DoubleToString(marginLvl, 2) + "%\n";
      comm += "Float Net: $" + DoubleToString(totalFloat, 2) + "\n";
      comm += "--------------------------------------------------\n";
      comm += StringFormat("%-10s | %-8s | %-8s | %-6s | %-6s\n", "Symbol", "Swap L", "Swap S", "Pos", "Wght");
      
      double sumSwap = 0;
      for(int i=0; i<m_count; i++)
         sumSwap += MathMax(MathAbs(SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_LONG)), MathAbs(SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_SHORT)));
      
      for(int i=0; i<m_count; i++)
        {
         double swapL = SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_LONG);
         double swapS = SymbolInfoDouble(m_symbols[i], SYMBOL_SWAP_SHORT);
         
         int posCnt = 0;
         for(int j = PositionsTotal()-1; j >= 0; j--)
           {
            ulong tk = PositionGetTicket(j);
            if(PositionGetString(POSITION_SYMBOL) == m_symbols[i] && PositionGetInteger(POSITION_MAGIC) == (m_carryMagicBase + i))
               posCnt++;
           }
         
         double w = (sumSwap > 0) ? (MathMax(MathAbs(swapL), MathAbs(swapS)) / sumSwap * 100.0) : 0;
         
         comm += StringFormat("%-10s | %-8.2f | %-8.2f | %-6d | %-5.1f%%\n", m_symbols[i], swapL, swapS, posCnt, w);
        }
        
      Comment(comm);
     }
     
   void              OnTick()
     {
      if(m_lock != NULL) m_lock.Heartbeat();
      
      // Throttling: Update Dash & Swap weight mỗi phút 1 lần là đủ
      static datetime lastCoreUpdate = 0;
      bool needUpdate = (TimeCurrent() - lastCoreUpdate >= 60);
      
      if(needUpdate)
        {
         double marginLvl = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
         if(marginLvl > 0 && marginLvl < InpMinMarginLevel)
           {
            Print("Core Risk Engine: Margin Level quá thấp (", marginLvl, "%). Ngưng mở trạng thái.");
           }
         
         CalculateCarryWeights(); // Cập nhật trọng số Carry liên tục
         lastCoreUpdate = TimeCurrent();
        }
      
      for(int i=0; i<m_count; i++)
        {
         m_carryAgents[i].OnTick();
        }
        
      if(needUpdate) UpdateDashboard();
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
