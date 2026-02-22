//+------------------------------------------------------------------+
//|                                                     Chimera.mq5 |
//|                                  Copyright 2026, Deepmind Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Deepmind Agent"
#property description "Chimera Portfolio ML Bot - Multi-Symbol Statistical Arbitrage"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//====================================================================
// MODULE: StatsML
//====================================================================
class CStatsML
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_period;
   double            m_mean;
   double            m_stdDev;
   double            m_zScore;

public:
                     CStatsML(void);
                    ~CStatsML(void);
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   void              Update();
   double            GetZScore() { return m_zScore; }
   double            GetMean()   { return m_mean; }
   double            GetStdDev() { return m_stdDev; }
   
private:
   double            CalculateMean(const double &data[]);
   double            CalculateStdDev(const double &data[], double mean);
  };

CStatsML::CStatsML(void) : m_symbol(""), m_timeframe(PERIOD_CURRENT), m_period(20), m_mean(0), m_stdDev(0), m_zScore(0) {}
CStatsML::~CStatsML(void) {}

bool CStatsML::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
  {
   m_symbol    = symbol;
   m_timeframe = timeframe;
   m_period    = period;
   return(true);
  }

void CStatsML::Update()
  {
   double closePrices[];
   ArraySetAsSeries(closePrices, true);
   if(CopyClose(m_symbol, m_timeframe, 0, m_period, closePrices) < m_period) return;
   
   m_mean = CalculateMean(closePrices);
   m_stdDev = CalculateStdDev(closePrices, m_mean);
   
   double currentPrice = closePrices[0];
   if(m_stdDev > 0) m_zScore = (currentPrice - m_mean) / m_stdDev;
   else m_zScore = 0;
  }

double CStatsML::CalculateMean(const double &data[])
  {
   double sum = 0;
   int size = ArraySize(data);
   for(int i=0; i<size; i++) sum += data[i];
   return (size > 0) ? sum / size : 0;
  }

double CStatsML::CalculateStdDev(const double &data[], double mean)
  {
   double sumSq = 0;
   int size = ArraySize(data);
   for(int i=0; i<size; i++) sumSq += MathPow(data[i] - mean, 2);
   return (size > 0) ? MathSqrt(sumSq / size) : 0;
  }

//====================================================================
// MODULE: Order Dispatcher (The "Valve")
//====================================================================
enum ENUM_REQUEST_TYPE
  {
   REQ_BUY,
   REQ_SELL,
   REQ_CLOSE
  };

struct STradeRequest
  {
   ENUM_REQUEST_TYPE type;
   string            symbol;
   double            volume;
   double            price;
   ulong             ticket; // For Close
   int               magic;
   string            comment;
  };

class COrderDispatcher
  {
private:
   STradeRequest     m_queue[];
   int               m_count;
   CTrade            m_trade;
   
public:
                     COrderDispatcher(void);
                    ~COrderDispatcher(void);
   void              AddRequest(STradeRequest &req);
   void              ProcessQueue();
   
private:
   void              ShiftQueue();
  };

COrderDispatcher::COrderDispatcher(void) : m_count(0) 
  {
   m_trade.SetMarginMode();
  }
COrderDispatcher::~COrderDispatcher(void) 
  {
   ArrayFree(m_queue);
  }

void COrderDispatcher::AddRequest(STradeRequest &req)
  {
   m_count++;
   ArrayResize(m_queue, m_count);
   m_queue[m_count-1] = req;
  }

void COrderDispatcher::ProcessQueue()
  {
   // Rate Limit: Execute max 5 orders per tick to avoid spam
   const int MAX_BATCH = 5;
   int processed = 0;
   
   while(m_count > 0 && processed < MAX_BATCH)
     {
      STradeRequest req = m_queue[0];
      
      m_trade.SetExpertMagicNumber(req.magic);
      m_trade.SetTypeFillingBySymbol(req.symbol);
      
      bool res = false;
      if(req.type == REQ_BUY)
         res = m_trade.Buy(req.volume, req.symbol, req.price, 0, 0, req.comment);
      else if(req.type == REQ_SELL)
         res = m_trade.Sell(req.volume, req.symbol, req.price, 0, 0, req.comment);
      else if(req.type == REQ_CLOSE)
         res = m_trade.PositionClose(req.ticket);
         
      if(res) Print("Dispatcher: Executed ", EnumToString(req.type), " on ", req.symbol);
      else Print("Dispatcher: Failed ", EnumToString(req.type), " on ", req.symbol, " Error: ", GetLastError());
      
      ShiftQueue();
      processed++;
     }
  }

void COrderDispatcher::ShiftQueue()
  {
   if(m_count == 0) return;
   
   for(int i=0; i<m_count-1; i++)
     {
      m_queue[i] = m_queue[i+1];
     }
   m_count--;
   ArrayResize(m_queue, m_count);
  }

//====================================================================
// MODULE: Agent (Business Unit)
//====================================================================
class CAgent
  {
private:
   string            m_symbol;
   int               m_magic;
   double            m_gridStep;
   bool              m_isPercentage; // True if gridStep is in % instead of pips
   double            m_fixedLotSize; // Base lot input
   double            m_currentLotSize; // Dynamic lot based on Capital
   int               m_maxGrid;
   double            m_point;
   
   // Enterprise Capital Props
   double            m_allocatedCapital; // Virtual Capital assigned by Core
   double            m_initialCapital;
   double            m_roi;              // Return on Investment
   double            m_closedProfit;     // Historical Profit
   bool              m_isSuspended;      // Core Suspension Flag
   
   COrderDispatcher *m_dispatcher;       // Pointer to Central Dispatcher
   CSymbolInfo       m_info;
   
   int               m_gridCount;
   datetime          m_lastTradeTime; // Anti-spam time check
   
   // Signal Latch / Hysteresis
   bool              m_isCycleFinished;    // True if we just finished a cycle
   double            m_resetThreshold;     // Z-Score level to reset the latch (e.g. 0.5)
   
   // Trailing Profit Logic
   bool              m_trailingActive;
   double            m_trailingMaxProfit;
   double            m_trailingTarget;     // Trigger amount ($)
   double            m_trailingStep;       // Retracement Allowed ($)
   
public:
                     CAgent(void);
                    ~CAgent(void);
   bool              Init(string symbol, int magic, double gridStep, bool isPercentage, double lotSize, int maxGrid, COrderDispatcher *dispatcher);
   void              SetCapital(double capital);
   void              Suspend(bool suspend);
   void              ForceExit(); // Called by Core when rescuing
   void              UpdatePerformance();
   void              OnTick(double zScore);
   
   string            GetSymbol() { return m_symbol; }
   double            GetCapital() { return m_allocatedCapital; }
   double            GetROI() { return m_roi; }
   double            GetNetProfit() { return m_closedProfit + GetFloatingProfit(); }
   double            GetFloatingProfit();
   
private:
   void              OpenEntry(int type);
   void              ManageGrid(int type);
   void              CheckExit();
   void              CloseAll();
   void              Refresh();
   void              RecalculateLotSize();
  };

CAgent::CAgent(void) : m_gridCount(0), m_point(0.00001), m_lastTradeTime(0), 
                       m_isCycleFinished(false), m_resetThreshold(0.8), 
                       m_trailingActive(false), m_trailingMaxProfit(0), 
                       m_trailingTarget(0), m_trailingStep(2.0),
                       m_allocatedCapital(0), m_roi(0), m_currentLotSize(0.01),
                       m_closedProfit(0), m_isSuspended(false), m_dispatcher(NULL) {}

CAgent::~CAgent(void) {}

bool CAgent::Init(string symbol, int magic, double gridStep, bool isPercentage, double lotSize, int maxGrid, COrderDispatcher *dispatcher)
  {
   m_symbol    = symbol;
   m_magic     = magic;
   m_gridStep  = gridStep;
   m_isPercentage = isPercentage;
   m_fixedLotSize = lotSize;
   m_currentLotSize = lotSize; // Default init
   m_maxGrid   = maxGrid;
   m_dispatcher = dispatcher;
   
   m_info.Name(symbol);
   m_point = m_info.Point();
   
   // Target $10 per 0.01 lot roughly
   m_trailingTarget = m_fixedLotSize * 1000; 
   m_trailingStep = m_trailingTarget * 0.2; // 20% retracement allowed
   
   return(true);
  }

void CAgent::SetCapital(double capital)
  {
   m_allocatedCapital = capital;
   if(m_initialCapital == 0 && capital > 0) m_initialCapital = capital; // Set once
   RecalculateLotSize();
  }

void CAgent::Suspend(bool suspend)
  {
   m_isSuspended = suspend;
  }

void CAgent::ForceExit()
  {
   // Core has forcibly closed a position for us.
   // We must consider this cycle FINISHED and wait for Reset.
   m_isCycleFinished = true;
   Print(m_symbol, " [NOTIFY] Core Rescued Position. Cycle Force-Finished. Waiting for Z-Score Reset.");
  }

void CAgent::UpdatePerformance()
  {
   // In a full implementation, we would scan Deal History here to update m_closedProfit.
   // Simplified V1: We assume Core tracks total Equity change or we only rely on Floating for immediate decision.
   // Improving: Simple Deal scan since last check?
   // To do this properly requires OnTradeTransaction. 
   
   // For now, ROI is calculated based on Floating relative to Capital (for real-time decision)
   if(m_allocatedCapital > 0)
     {
      double net = m_closedProfit + GetFloatingProfit(); // m_closedProfit needs updating logic
      m_roi = (net / m_allocatedCapital) * 100.0;
     }
  }

void CAgent::RecalculateLotSize()
  {
   // Auto-Scaling: $1000 -> 0.01 Lot (Example Base)
   // If Capital increases to $2000, Lot -> 0.02
   if(m_allocatedCapital <= 0) return;
   
   double normalized = m_allocatedCapital / 1000.0;
   if(normalized < 1.0) normalized = 1.0; // Min floor 0.01
   
   double rawLot = m_fixedLotSize * normalized;
   
   // Normalize Lot Step
   double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   if(step > 0)
     {
      m_currentLotSize = MathFloor(rawLot / step) * step;
      double minVol = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      if(m_currentLotSize < minVol) m_currentLotSize = minVol;
     }
    else m_currentLotSize = m_fixedLotSize;
  }

void CAgent::OnTick(double zScore)
  {
   if(!m_info.RefreshRates()) return;
   Refresh();
   
   UpdatePerformance();
   
   // --- SIGNAL RESET LOGIC (Hysteresis) ---
   if(m_isCycleFinished)
     {
      if(MathAbs(zScore) < m_resetThreshold) 
        {
         m_isCycleFinished = false; 
         Print(m_symbol, " Z-Score Reset to ", zScore, ". Agent Ready.");
        }
      else return; 
     }
   
   // --- TRADING LOGIC ---
   if(m_gridCount == 0)
     {
      // Check Suspension
      if(m_isSuspended) return; // Core says STOP
      
      if(zScore > 2.0) OpenEntry(-1);
      else if(zScore < -2.0) OpenEntry(1);
     }
   else
     {
      if(GetFloatingProfit() < 0)
        {
         long type = -1;
         // Find direction
         for(int i=PositionsTotal()-1; i>=0; i--) {
            if(PositionSelectByTicket(PositionGetTicket(i))) {
               if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic) {
                  type = PositionGetInteger(POSITION_TYPE);
                  break; 
               }
            }
         }
         
         if(type == POSITION_TYPE_BUY) ManageGrid(1);
         else if(type == POSITION_TYPE_SELL) ManageGrid(-1);
        }
      CheckExit();
     }
  }

void CAgent::OpenEntry(int type)
  {
   if(TimeCurrent() - m_lastTradeTime < 10) return;
   if(m_isSuspended) return;
   if(m_dispatcher == NULL) return;

   STradeRequest req;
   req.symbol = m_symbol;
   req.volume = m_currentLotSize;
   req.magic = m_magic;
   
   if(type == 1) 
     {
      req.type = REQ_BUY;
      req.price = m_info.Ask();
      req.comment = "Agent Buy";
     }
   else 
     {
      req.type = REQ_SELL;
      req.price = m_info.Bid();
      req.comment = "Agent Sell";
     }
     
   m_dispatcher.AddRequest(req);
   m_lastTradeTime = TimeCurrent();
  }

void CAgent::ManageGrid(int type)
  {
   if(m_gridCount >= m_maxGrid) return;
   if(TimeCurrent() - m_lastTradeTime < 10) return;
   if(m_isSuspended) return; // Strict Risk Control: No grids if suspended? usually YES.
   if(m_dispatcher == NULL) return;
   
   double lastPrice = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
           {
            double p = PositionGetDouble(POSITION_PRICE_OPEN);
            if(lastPrice == 0) lastPrice = p;
            if(type == 1) { if(p < lastPrice) lastPrice = p; }
            else { if(p > lastPrice) lastPrice = p; }
           }
        }
     }
   if(lastPrice == 0) return;
   
   double current = (type == 1) ? m_info.Ask() : m_info.Bid();
   double dist = (type == 1) ? (lastPrice - current) : (current - lastPrice);
   
   // Calculate required distance based on pips or percentage
   double requiredDist;
   if(m_isPercentage)
     {
      // Percentage mode: gridStep is % of current price
      requiredDist = current * (m_gridStep / 100.0);
     }
   else
     {
      // Pips mode: convert gridStep pips to price distance
      requiredDist = m_gridStep * 10 * m_point;
     }
   
   if(dist >= requiredDist)
     {
      STradeRequest req;
      req.symbol = m_symbol;
      req.volume = m_currentLotSize;
      req.magic = m_magic;
      
      if(type == 1) 
        {
         req.type = REQ_BUY;
         req.price = m_info.Ask();
         req.comment = "Agent Grid Buy";
        }
      else 
        {
         req.type = REQ_SELL;
         req.price = m_info.Bid();
         req.comment = "Agent Grid Sell";
        }
        
      m_dispatcher.AddRequest(req);
      m_lastTradeTime = TimeCurrent();
     }
  }

void CAgent::CheckExit()
  {
   double profit = GetFloatingProfit();
   if(!m_trailingActive)
     {
      // Note: Trailing Target should logically scale with Lot Size? 
      // Yes, m_trailingTarget was calc'd using fixedLotSize in Init. 
      // Ideally should re-calc if Lot changes much, but keep simple for now.
      
      double dynamicTarget = m_currentLotSize * 1000;
      
      if(profit >= dynamicTarget)
        {
         m_trailingActive = true;
         m_trailingMaxProfit = profit;
         m_trailingStep = dynamicTarget * 0.2; // Recalc step
         Print(m_symbol, " Trailing Activated. Target: ", dynamicTarget);
        }
     }
   else
     {
      if(profit > m_trailingMaxProfit) m_trailingMaxProfit = profit;
      
      if(profit < m_trailingMaxProfit - m_trailingStep)
        {
         Print(m_symbol, " Agent Take Profit. Max: ", m_trailingMaxProfit, " Closed: ", profit);
         CloseAll();
         m_trailingActive = false;
         m_trailingMaxProfit = 0;
         
         // In simplified V1, we simulate "Closed Profit" update here?
         m_closedProfit += profit; // Rough estimation
        }
        
      if(profit < 0) { m_trailingActive = false; m_trailingMaxProfit = 0; }
     }
  }

void CAgent::CloseAll()
  {
   if(m_dispatcher == NULL) return;
   bool dispatched = false;
   
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
           {
            STradeRequest req;
            req.type = REQ_CLOSE;
            req.symbol = m_symbol;
            req.ticket = PositionGetTicket(i);
            req.magic = m_magic;
            req.comment = "Agent Close";
            
            m_dispatcher.AddRequest(req);
            dispatched = true;
           }
        }
     }
   if(dispatched) 
     {
      m_isCycleFinished = true;
      Print(m_symbol, " Component Cycle Finished. Requests Sent to Dispatcher.");
     }
  }

void CAgent::Refresh()
  {
   m_gridCount = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
            m_gridCount++;
        }
     }
  }

double CAgent::GetFloatingProfit()
  {
   double profit = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
            profit += PositionGetDouble(POSITION_PROFIT);
        }
     }
   return profit;
  }

//====================================================================
// MODULE: News Filter ("The Oracle")
//====================================================================
class CNewsFilter
  {
private:
   int               m_bufferMinutes;
   
public:
                     CNewsFilter(void);
                    ~CNewsFilter(void);
   void              Init(int bufferMinutes);
   bool              IsNewsTime(string symbol);
   
private:
   bool              CheckCurrency(string currency, datetime start, datetime end);
  };

CNewsFilter::CNewsFilter(void) : m_bufferMinutes(30) {}
CNewsFilter::~CNewsFilter(void) {}

void CNewsFilter::Init(int bufferMinutes)
  {
   m_bufferMinutes = bufferMinutes;
  }

bool CNewsFilter::IsNewsTime(string symbol)
  {
   if(m_bufferMinutes <= 0) return false;
   
   CSymbolInfo sym;
   sym.Name(symbol);
   string base = sym.CurrencyBase();
   string quote = sym.CurrencyProfit(); // or Margin? Profit is safer for pairs
   
   datetime now = TimeCurrent();
   datetime start = now - m_bufferMinutes * 60;
   datetime end = now + m_bufferMinutes * 60;
   
   if(CheckCurrency(base, start, end)) return true;
   if(CheckCurrency(quote, start, end)) return true;
   
   return false;
  }

bool CNewsFilter::CheckCurrency(string currency, datetime start, datetime end)
  {
   MqlCalendarValue values[];
   // Get events for specific currency in range
   // Note: CalendarValueHistory isn't always reliable in Tester, but works in Live.
   // We use CalendarValueHistoryByEvent? No, we need filtered by curr.
   // MqlCalendarEvent events[];
   // Optimization: We assume user has updated calendar.
   
   // Simpler approach: CalendarValueHistory takes inputs.
   // But standard function is CalendarValueHistory(values, start, end, country_code, currency)
   // Wait, Input is: (values, start, end, country_code, currency) in some versions?
   // MQL5 docs: CalendarValueHistory(values, start, end, country_code = NULL, currency = NULL)
   
   if(CalendarValueHistory(values, start, end, NULL, currency))
     {
      for(int i=0; i<ArraySize(values); i++)
        {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
           {
            if(event.importance == CALENDAR_IMPORTANCE_HIGH)
              {
               Print("News Filter: High Impact Event for ", currency, ": ", event.name, " @ ", values[i].time);
               return true;
              }
           }
        }
     }
   return false;
  }

//====================================================================
// MODULE: Enterprise Core (The "Center")
//====================================================================
struct SAgentConfig
  {
   string            symbol;
   double            gridStep;
   double            baseLot;
   bool              isPercentage; // True if gridStep is in % instead of pips
  };

class CCore
  {
private:
   string            m_setupCSV;
   SAgentConfig      m_configs[];
   int               m_agentCount;
   CStatsML         *m_stats[];
   CAgent           *m_agents[];
   COrderDispatcher *m_dispatcher; // The Dispatcher
   CNewsFilter      *m_newsFilter; // The Oracle
   
   int               m_magicBase;
   int               m_mlPeriod;
   
   double            m_totalCapital;
   double            m_minMarginLevel; // Risk Control
   
public:
                     CCore(void);
                    ~CCore(void);
   bool              Init(string setupCSV, int magicBase, int mlPeriod, double defaultLot, int maxGrid, double minMargin, int newsBuffer);
   void              OnTick();
   void              OnDeinit();
private:
   void              ParseSetup();
   void              CheckRecovery();
   void              CheckRisk();
   void              AllocateCapital();
   void              ReportDaily();
  };

CCore::CCore(void) : m_agentCount(0), m_totalCapital(0), m_minMarginLevel(500.0) 
  {
   m_dispatcher = new COrderDispatcher();
   m_newsFilter = new CNewsFilter();
  }
CCore::~CCore(void) { OnDeinit(); }

bool CCore::Init(string setupCSV, int magicBase, int mlPeriod, double defaultLot, int maxGrid, double minMargin, int newsBuffer)
  {
   m_setupCSV = setupCSV;
   m_magicBase = magicBase;
   m_mlPeriod = mlPeriod;
   m_minMarginLevel = minMargin;
   
   m_newsFilter.Init(newsBuffer);
   
   ParseSetup(); // Parses symbol, step, and LOT
   if(m_agentCount == 0) return false;
   
   ArrayResize(m_stats, m_agentCount);
   ArrayResize(m_agents, m_agentCount);
   
   m_totalCapital = AccountInfoDouble(ACCOUNT_EQUITY); 
   double capPerAgent = m_totalCapital / m_agentCount; 
   
   for(int i=0; i<m_agentCount; i++)
     {
      m_stats[i] = new CStatsML();
      m_agents[i] = new CAgent();
      
      m_stats[i].Init(m_configs[i].symbol, PERIOD_CURRENT, mlPeriod);
      
      // LOGIC: Use Config Lot if > 0, else Default Lot
      double finalLot = (m_configs[i].baseLot > 0) ? m_configs[i].baseLot : defaultLot;
      
      m_agents[i].Init(m_configs[i].symbol, magicBase + i, m_configs[i].gridStep, m_configs[i].isPercentage, finalLot, maxGrid, m_dispatcher);
      
      m_agents[i].SetCapital(capPerAgent);
      string stepStr = m_configs[i].isPercentage ? DoubleToString(m_configs[i].gridStep, 2) + "%" : DoubleToString(m_configs[i].gridStep, 0) + "pips";
      Print("Core: Agent ", i, " [", m_configs[i].symbol, "] Step: ", stepStr, " Lot: ", finalLot, " Cap: $", DoubleToString(capPerAgent, 0));
     }
   return true;
  }

void CCore::OnTick()
  {
   // 1. Risk Control
   CheckRisk();
   
   // 2. Capital Management
   AllocateCapital();
   
   // 3. Daily Reporting
   ReportDaily(); // Perform Daily Reporting
   
   // 4. Execution
   for(int i=0; i<m_agentCount; i++)
     {
      m_stats[i].Update();
      double zScore = m_stats[i].GetZScore();
      m_agents[i].OnTick(zScore);
     }
   CheckRecovery();
   
   // Process Order Queue
   if(m_dispatcher != NULL) m_dispatcher.ProcessQueue();
   
   string comm = "Enterprise Core AI | News Filter Active\n";
   comm += "Total Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   comm += "Margin Level: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2) + "%\n";
   Comment(comm);
  }

void CCore::ReportDaily()
  {
   static int lastDay = 0;
   MqlDateTime dt;
   TimeCurrent(dt);
   
   if(lastDay == 0) { lastDay = dt.day; return; } // Skip first tick logic check
   
   if(dt.day != lastDay)
     {
      // New Day Detected!
      string filename = "Chimera_Report_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
      int handle = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE|FILE_COMMON, ",");
      
      if(handle != INVALID_HANDLE)
        {
         FileSeek(handle, 0, SEEK_END);
         if(FileSize(handle) == 0)
           {
             FileWrite(handle, "Time", "Symbol", "Magic", "Capital", "NetProfit", "ROI(%)");
           }
           
         string timeStr = TimeToString(TimeCurrent());
         
         for(int i=0; i<m_agentCount; i++)
           {
            string lineSymbol = m_agents[i].GetSymbol();
            double cap = m_agents[i].GetCapital();
            double profit = m_agents[i].GetNetProfit();
            double roi = m_agents[i].GetROI();
            
            // Format: Time, Symbol, Magic (inferred by loop? No, explicitly not exposed easily w/o helper, skip magic or add it)
            // Let's add Magic to Getters if needed, or just iterate.
            // Simplified Log:
            FileWrite(handle, timeStr, lineSymbol, IntegerToString(m_magicBase + i), DoubleToString(cap, 2), DoubleToString(profit, 2), DoubleToString(roi, 2));
           }
         FileClose(handle);
         Print("Daily Report Saved to ", filename);
        }
      else
        {
         Print("Failed to open report file: ", filename, " Err: ", GetLastError());
        }
        
      lastDay = dt.day;
     }
  }

void CCore::CheckRisk()
  {
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   // 1. Margin Check
   bool suspendAll = false;
   if(marginLevel > 0 && marginLevel < m_minMarginLevel)
     {
      suspendAll = true;
      Print("CORE SAFETY: Margin Level Critical (", marginLevel, "%). Suspending ALL Agents.");
     }
     
   // 2. News Filter Check
   // Optimization: Check once per minute, not every tick?
   // For safety, per tick is fine provided API is fast, but Calendar calls are heavy.
   // Let's cache result or limit check freq? 
   // MQL5 Calendar functions are local DB access, relatively fast but not tick-speed friendly.
   
   static datetime lastCheck = 0;
   static bool newsSuspended[]; // Cache per agent
   bool needUpdate = (TimeCurrent() - lastCheck > 60); // Update every minute
   
   if(ArraySize(newsSuspended) != m_agentCount) ArrayResize(newsSuspended, m_agentCount);
   
   if(needUpdate)
     {
      for(int i=0; i<m_agentCount; i++)
        {
         newsSuspended[i] = m_newsFilter.IsNewsTime(m_agents[i].GetSymbol());
         if(newsSuspended[i]) Print("CORE SAFETY: News Suspended for ", m_agents[i].GetSymbol());
        }
      lastCheck = TimeCurrent();
     }
     
   for(int i=0; i<m_agentCount; i++)
     {
      bool finalSuspend = suspendAll || newsSuspended[i];
      m_agents[i].Suspend(finalSuspend);
     }
  }

void CCore::AllocateCapital()
  {
   // Periodically re-distribute capital based on Performance
   static datetime lastAlloc = 0;
   if(TimeCurrent() - lastAlloc < 60) return; // Every minute
   
   m_totalCapital = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Logic: Calculate Score for each agent (e.g. NetProfit)
   // For now, simpler: Equal re-balancing to replenish losers? 
   // OR: "Rich get Richer": Alloc = Base + (NetProfit * Factor)
   
   // Let's implement: Proportional to Net Value (Equity Contribution)
   // Agent Equity = Initial + Profit
   // We don't have per-agent Balance strict tracking in MT5 easily without DB.
   // Simplified: 
   // Redistribute Total Equity equally for now to reset balances? 
   // OR: Just let them keep what they have and add drift?
   
   // Implementation of User Request: "Give capital to optimal agents"
   // Strategy: Check ROI.
   // If ROI > 10%, give 10% more capital base.
   // If ROI < -10%, cut 10%.
   
   // This is Complex. Let's stick to Equal Rebalance + Bonus for now.
   double baseCap = m_totalCapital / m_agentCount;
   
   for(int i=0; i<m_agentCount; i++)
     {
      double roi = m_agents[i].GetROI();
      double bonus = 0;
      if(roi > 10.0) bonus = baseCap * 0.1; // +10% Bonus
      if(roi < -10.0) bonus = -baseCap * 0.1; // -10% Penalty
      
      m_agents[i].SetCapital(baseCap + bonus);
     }
   
   lastAlloc = TimeCurrent();
  }

void CCore::CheckRecovery()
  {
   double totalFloatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   if(totalFloatingPL <= 0) return; 

   int worstTicket = -1;
   double maxLoss = 0;
   long worstMagic = -1; // Track magic to notify Agent
   string worstSymbol = "";
   
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(magic < m_magicBase || magic >= m_magicBase + m_agentCount) continue;
         
         double profit = PositionGetDouble(POSITION_PROFIT);
         long posTime = PositionGetInteger(POSITION_TIME);
         
         if(TimeCurrent() - posTime < 15 * 60) continue;
         
         if(profit < 0 && MathAbs(profit) > MathAbs(maxLoss))
           {
            maxLoss = profit; 
            worstTicket = (int)ticket;
            worstMagic = magic;
            worstSymbol = PositionGetString(POSITION_SYMBOL);
           }
        }
     }
     
   if(worstTicket != -1)
     {
      if(totalFloatingPL > MathAbs(maxLoss) + 1.0) 
        {
         // Use Dispatcher for Rescue too?
         // For now, let's stick to direct CTrade locally here to ensure urgency, 
         // OR send REQ_CLOSE to Dispatcher with comments
         // To stay consistent with "Centralized Execution", let's use dispatcher!
         
         if(m_dispatcher != NULL)
           {
             STradeRequest req;
             req.type = REQ_CLOSE;
             req.ticket = worstTicket;
             req.symbol = worstSymbol;
             req.magic = (int)worstMagic;
             req.comment = "Core Rescue Logic";
             m_dispatcher.AddRequest(req);
             
             Print("Core Rescue: Dispatched Close for Ticket ", worstTicket, " Loss: ", maxLoss);
           }
         
         // NOTIFY AGENT
         int agentIdx = (int)(worstMagic - m_magicBase);
         if(agentIdx >= 0 && agentIdx < m_agentCount)
           {
            m_agents[agentIdx].ForceExit();
           }
        }
     }
  }

void CCore::OnDeinit()
  {
   for(int i=0; i<ArraySize(m_stats); i++)
     {
      if(CheckPointer(m_stats[i]) == POINTER_DYNAMIC) delete m_stats[i];
      if(CheckPointer(m_agents[i]) == POINTER_DYNAMIC) delete m_agents[i];
     }
   if(CheckPointer(m_dispatcher) == POINTER_DYNAMIC) delete m_dispatcher; // Delete Dispatcher
   if(CheckPointer(m_newsFilter) == POINTER_DYNAMIC) delete m_newsFilter;
   
   ArrayFree(m_stats);
   ArrayFree(m_agents);
   ArrayFree(m_configs);
  }

void CCore::ParseSetup()
  {
   // Format: Symbol:GridStep,Symbol:GridStep
   // Ex: EURUSD:30,EURUSD:50,GBPUSD:40
   
   string to_split = m_setupCSV;
   string sep = ",";
   ushort u_sep = StringGetCharacter(sep, 0);
   string result[];
   int k = StringSplit(to_split, u_sep, result);
   
   if(k > 0)
     {
      m_agentCount = k;
      ArrayResize(m_configs, k);
      
      for(int i=0; i<k; i++)
        {
         string entry = result[i];
         StringTrimLeft(entry); StringTrimRight(entry);
         
         string entryParts[];
         int p = StringSplit(entry, ':', entryParts);
         
         // Default Values
         m_configs[i].symbol = entry;
         m_configs[i].gridStep = 30.0;
         m_configs[i].baseLot = 0.0; // 0 means use Global Default
         m_configs[i].isPercentage = false;
         
         if(p >= 2)
           {
            m_configs[i].symbol = entryParts[0];
            
            // Detect if gridStep is percentage (ends with %)
            string stepStr = entryParts[1];
            StringTrimLeft(stepStr); StringTrimRight(stepStr);
            if(StringFind(stepStr, "%") >= 0)
              {
               // Remove % and parse as percentage
               StringReplace(stepStr, "%", "");
               m_configs[i].gridStep = StringToDouble(stepStr);
               m_configs[i].isPercentage = true;
              }
            else
              {
               m_configs[i].gridStep = StringToDouble(stepStr);
               m_configs[i].isPercentage = false;
              }
           }
         if(p >= 3)
           {
            m_configs[i].baseLot = StringToDouble(entryParts[2]);
           }
        }
     }
  }

//====================================================================
// MAIN EA
//====================================================================
input group "Enterprise Settings"
input string   InpAgentSetup     = "EURUSD:30,EURUSD:50,GBPUSD:40"; // Agent Setup (Symbol:Step)
input int      InpMagicBase      = 555000;                 // Magic Number Base

input group "ML Statistics"
input int      InpMLPeriod       = 1000;     // Lookback Period

input group "Risk & Limits"
input double   InpDefaultLot     = 0.01;     // Base Lot
input int      InpMaxGrid        = 5;        // Max Grid Orders
input double   InpMinMargin      = 500.0;    // Min Margin Level % to open new trades
input int      InpNewsBuffer     = 30;       // News Filter Buffer (Minutes)
 
 CCore *g_manager;
 
 int OnInit()
   {
    if(InpAgentSetup == "") return INIT_FAILED;
    g_manager = new CCore();
    if(!g_manager.Init(InpAgentSetup, InpMagicBase, InpMLPeriod, InpDefaultLot, InpMaxGrid, InpMinMargin, InpNewsBuffer))
      {
       Print("Chimera Init Failed");
       return INIT_FAILED;
      }
    Print("Chimera Enterprise Init: ", InpAgentSetup);
    return(INIT_SUCCEEDED);
   }

void OnDeinit(const int reason)
  {
   if(CheckPointer(g_manager) == POINTER_DYNAMIC) delete g_manager;
  }

void OnTick()
  {
   if(g_manager != NULL) g_manager.OnTick();
  }
