//+------------------------------------------------------------------+
//|                                                        Hydra.mq5 |
//|                                  Copyright 2026, Deepmind Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Deepmind Agent based on BigBeluga & Viper"
#property link      "https://www.mql5.com"
#property version   "3.10"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "Risk Management"
input double   InpRiskPercent    = 5.0;      // Risk Percent per Setup

input group "BigBeluga Settings"
input int      InpATRPeriod      = 200;      // ATR Period for Box Height
input double   InpATRMulitplier  = 2.0;      // ATR Multiplier
input int      InpVolumeLength   = 1000;     // Volume MA Length (approx)

input group "Structure Filter"
input bool     InpUseStructure   = true;     // Use HH/LL Filter
input int      InpTrendLookback  = 100;      // Bars to scan for structure

input group "Trailing & Breakeven"
input bool     InpUseBreakeven    = true;     // Move SL to Breakeven
input int      InpBEStartPoints   = 200;      // Points profit to trigger BE (e.g. 20 pips)
input int      InpBEOffsetPoints  = 10;       // Points above entry (Cover Comm)
input bool     InpUseTrailing     = false;    // Use Trailing Stop (Continuous)
input int      InpTrailDistPoints = 200;      // Trailing Distance
input int      InpTrailStepPoints = 50;       // Trailing Step

input group "== TIME TRADING (VIETNAM TIME GMT+7) =="
input bool   InpUseTimeSlot      = true;     // Co su dung thoi gian trading khong?
input string InpT1Start          = "09:00";  // Gio phut 1 bat dau tradding
input string InpT1End            = "17:00";  // Gio phut 1 ket thuc tradding
input string InpT2Start          = "22:00";  // Gio phut 2 bat dau tradding
input string InpT2End            = "03:00";  // Gio phut 2 ket thuc tradding
input int    InpServerGMTOffset  = 2;        // Mui gio Server (VD: IC Markets=2 hoac 3)

input int    InpMagicNumber      = 123456;   // Magic Number

//--- Global Objects
CTrade         trade;
CSymbolInfo    m_symbol;
CPositionInfo  m_position;
COrderInfo     m_order;

int            m_handle_atr;

//--- Structure for Zone
struct Zone {
   double top;
   double bottom;
   datetime time;
   int type; // 1 Buy, -1 Sell
   bool active;
};

Zone zones[]; // Active zones

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!m_symbol.Name(Symbol()))
      return(INIT_FAILED);
   RefreshRates();

   m_handle_atr = iATR(Symbol(), Period(), InpATRPeriod);
   if(m_handle_atr == INVALID_HANDLE) return(INIT_FAILED);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(Symbol());

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(m_handle_atr);
   ObjectsDeleteAll(0, "Hydra_Zone_");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!RefreshRates())
      return;

   // Manage active zones vs Price (Delete if broken)
   ManageZones();
   
   // Manage Pending Orders (Cleanup)
   ManagePendingOrders();
   
   // Manage Trailing & Breakeven
   ManageTrailing();

   // Scan for NEW Zones (BigBeluga Logic)
   ScanForNewZones();

   // Check Time Filter
   if(!CheckTime()) return;

   // Trading Logic: Check if price enters any Active Zone
   CheckEntry();
  }

//+------------------------------------------------------------------+
//| Helper: Refresh Rates                                            |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
   if(!m_symbol.RefreshRates()) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Logic: Scan for New Zones (BigBeluga Port)                       |
//+------------------------------------------------------------------+
void ScanForNewZones()
  {
   // Pine Logic Port
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(Symbol(), Period(), 0, 10, rates) < 10) return;
   
   long volSum = 0;
   long volArr[];
   ArraySetAsSeries(volArr, true);
   if(CopyTickVolume(Symbol(), Period(), 0, InpVolumeLength, volArr) < InpVolumeLength) return;
   
   for(int i=0; i<InpVolumeLength; i++) volSum += volArr[i];
   double avgVol = (double)volSum / InpVolumeLength;
   
   bool bear1 = rates[1].close < rates[1].open;
   bool bear2 = rates[2].close < rates[2].open;
   bool bear3 = rates[3].close < rates[3].open;
   
   bool extraVol = (double)rates[2].tick_volume > avgVol; 
   
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(m_handle_atr, 0, 0, 2, atr);
   double boxSize = atr[1] * InpATRMulitplier;
   
   // SUPPLY Detection
   if(bear1 && bear2 && bear3 && extraVol)
     {
      for(int i=1; i<=6; i++)
        {
         if(rates[i].close > rates[i].open) // Bull "Base"
           {
            CreateZone(-1, rates[i].low + boxSize, rates[i].low, rates[i].time); 
            break;
           }
        }
     }
     
   // DEMAND Detection
   bool bull1 = rates[1].close > rates[1].open;
   bool bull2 = rates[2].close > rates[2].open;
   bool bull3 = rates[3].close > rates[3].open;
   
   if(bull1 && bull2 && bull3 && extraVol)
     {
      for(int i=1; i<=6; i++)
        {
         if(rates[i].close < rates[i].open) // Bear "Base"
           {
            CreateZone(1, rates[i].high, rates[i].high - boxSize, rates[i].time);
            break;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Logic: Create and Draw Zone                                      |
//+------------------------------------------------------------------+
void CreateZone(int type, double top, double bottom, datetime t)
  {
   for(int i=0; i<ArraySize(zones); i++)
     {
      if(zones[i].time == t && zones[i].type == type) return;
     }
     
   int size = ArraySize(zones);
   ArrayResize(zones, size+1);
   zones[size].top = top;
   zones[size].bottom = bottom;
   zones[size].time = t;
   zones[size].type = type;
   zones[size].active = true;
   
   string name = "Hydra_Zone_" + TimeToString(t);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t, top, TimeCurrent(), bottom);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (type==1)?clrBlue:clrOrange);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); 
  }

//+------------------------------------------------------------------+
//| Logic: Manage Zones (Delete broken ones)                         |
//+------------------------------------------------------------------+
void ManageZones()
  {
   for(int i=0; i<ArraySize(zones); i++)
     {
      if(!zones[i].active) continue;
      
      string name = "Hydra_Zone_" + TimeToString(zones[i].time);
      double close = iClose(Symbol(), Period(), 0); 
      
      if(zones[i].type == -1) // Supply
        {
         if(close > zones[i].top) 
           {
            zones[i].active = false;
            ObjectDelete(0, name);
           }
        }
      else // Demand
        {
         if(close < zones[i].bottom)
           {
            zones[i].active = false;
            ObjectDelete(0, name);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Logic: Entry Check                                               |
//+------------------------------------------------------------------+
void CheckEntry()
  {
   if(PositionsTotal() > 0 || OrdersTotal() > 0) return; 
   
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();

   int trend = 0;
   if(InpUseStructure) trend = GetTrendStructure();
   
   for(int i=0; i<ArraySize(zones); i++)
     {
      if(!zones[i].active) continue;
      
      if(zones[i].type == 1) // Demand / Buy
        {
         if(InpUseStructure && trend == -1) continue; 

         if(ask <= zones[i].top && ask >= zones[i].bottom)
           {
            ExecuteSetup(1, zones[i]);
            zones[i].active = false; 
            return;
           }
        }
      else // Supply / Sell
        {
         if(InpUseStructure && trend == 1) continue; 
         
         if(bid >= zones[i].bottom && bid <= zones[i].top)
           {
            ExecuteSetup(-1, zones[i]);
            zones[i].active = false;
            return;
           }
        }
     }
  }
  
//+------------------------------------------------------------------+
//| Logic: Execute Setup (Single Entry)                              |
//+------------------------------------------------------------------+
void ExecuteSetup(int type, Zone &z)
  {
   double height = z.top - z.bottom;
   double slPrice, tpPrice;
   double buffer = 0.0; // Box Edge
   
   if(type == 1) // Buy
     {
      slPrice = z.bottom - buffer;
      tpPrice = z.top + height; 
     }
   else
     {
      slPrice = z.top + buffer;
      tpPrice = z.bottom - height;
     }

   double currentPrice = (type==1) ? m_symbol.Ask() : m_symbol.Bid();
   double dist = MathAbs(currentPrice - slPrice);
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double tickVal = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();
   
   if(tickSize == 0 || dist == 0) return;
   
   double lot = riskMoney / ((dist/tickSize) * tickVal);
   
   double stepLot = m_symbol.LotsStep();
   lot = MathFloor(lot/stepLot) * stepLot;
   if(lot < m_symbol.LotsMin()) lot = m_symbol.LotsMin();
   if(lot > m_symbol.LotsMax()) lot = m_symbol.LotsMax();
   
   double slNorm = m_symbol.NormalizePrice(slPrice);
   double tpNorm = m_symbol.NormalizePrice(tpPrice);
   
   if(type == 1)
      trade.Buy(lot, Symbol(), currentPrice, slNorm, tpNorm, "Hydra Single");
   else
      trade.Sell(lot, Symbol(), currentPrice, slNorm, tpNorm, "Hydra Single");
  }

//+------------------------------------------------------------------+
//| Logic: Manage Trailing & Breakeven                               |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   if(PositionsTotal() == 0) return;
   
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() != Symbol() || m_position.Magic() != InpMagicNumber) continue;
         
         // 1. Breakeven
         if(InpUseBreakeven)
           {
            double open = m_position.PriceOpen();
            double sl = m_position.StopLoss();
            double current = (m_position.PositionType()==POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
            double point = m_symbol.Point();
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
              {
               if(current - open >= InpBEStartPoints * point) 
                 {
                  double newSL = open + InpBEOffsetPoints * point;
                  if(sl < newSL) trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
                 }
              }
            else
              {
               // Sell: Open - Current > Start
               if(open - current >= InpBEStartPoints * point)
                 {
                  double newSL = open - InpBEOffsetPoints * point;
                  if(sl == 0 || sl > newSL) trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
                 }
              }
           }
           
         // 2. Trailing Stop
         if(InpUseTrailing)
           {
            double current = (m_position.PositionType()==POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
            double sl = m_position.StopLoss();
            double point = m_symbol.Point();
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
              {
               double targetSL = current - InpTrailDistPoints * point;
               if(targetSL > sl + InpTrailStepPoints * point)
                  trade.PositionModify(m_position.Ticket(), targetSL, m_position.TakeProfit());
              }
            else
              {
               double targetSL = current + InpTrailDistPoints * point;
               if(sl == 0 || targetSL < sl - InpTrailStepPoints * point)
                  trade.PositionModify(m_position.Ticket(), targetSL, m_position.TakeProfit());
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Logic: Manage Pending Orders (Cleanup)                           |
//+------------------------------------------------------------------+
void ManagePendingOrders()
  {
   int total = OrdersTotal();
   if(total == 0) return;

   for(int i = total - 1; i >= 0; i--)
     {
      if(m_order.SelectByIndex(i))
        {
         if(m_order.Symbol() != Symbol() || m_order.Magic() != InpMagicNumber) continue;
         
         double currentPrice = (m_order.OrderType() == ORDER_TYPE_BUY_LIMIT) ? m_symbol.Ask() : m_symbol.Bid();
         double ordTP = m_order.TakeProfit();
         double ordSL = m_order.StopLoss();
         
         bool cancel = false;
         if(m_order.OrderType() == ORDER_TYPE_BUY_LIMIT)
           {
            if(currentPrice >= ordTP || currentPrice <= ordSL) cancel = true;
           }
         else if(m_order.OrderType() == ORDER_TYPE_SELL_LIMIT)
           {
            if(currentPrice <= ordTP || currentPrice >= ordSL) cancel = true;
           }
           
         if(cancel) trade.OrderDelete(m_order.Ticket());
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Get Trend Structure (HH/HL)                              |
//+------------------------------------------------------------------+
int GetTrendStructure()
  {
   double highs[]; double lows[];
   ArrayResize(highs, 2); ArrayResize(lows, 2);
   int hCount = 0, lCount = 0;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int look = InpTrendLookback;
   if(CopyRates(Symbol(), Period(), 0, look, rates) < look) return 0;
   
   for(int i=5; i<look-5; i++)
     {
      bool isHigh = true;
      for(int k=1; k<=5; k++) {
         if(rates[i].high < rates[i-k].high || rates[i].high < rates[i+k].high) { isHigh=false; break; }
      }
      if(isHigh && hCount < 2) { highs[hCount] = rates[i].high; hCount++; }
      
      bool isLow = true;
      for(int k=1; k<=5; k++) {
         if(rates[i].low > rates[i-k].low || rates[i].low > rates[i+k].low) { isLow=false; break; }
      }
      if(isLow && lCount < 2) { lows[lCount] = rates[i].low; lCount++; }
      
      if(hCount >= 2 && lCount >= 2) break;
     }
     
   if(hCount < 2 || lCount < 2) return 0; 
   
   if (highs[0] > highs[1] && lows[0] > lows[1]) return 1;  
   if (highs[0] < highs[1] && lows[0] < lows[1]) return -1; 
   
   return 0; 
  }

//+------------------------------------------------------------------+
//| Helper: Check Time (From Viper: GMT+7)                           |
//+------------------------------------------------------------------+
bool CheckTime() {
   if(!InpUseTimeSlot) return true;

   datetime serverTime = TimeCurrent();
   datetime vnTime = serverTime - (InpServerGMTOffset * 3600) + (7 * 3600);
   
   MqlDateTime dt; TimeToStruct(vnTime, dt); 
   int h = dt.hour, m = dt.min;
   
   return (InTimeRange(h,m,InpT1Start,InpT1End) || InTimeRange(h,m,InpT2Start,InpT2End));
}

bool InTimeRange(int h, int m, string start, string end) {
   int sh, sm, eh, em;
   if(StringLen(start)<5 || StringLen(end)<5) return false;
   sh = (int)StringToInteger(StringSubstr(start,0,2)); sm = (int)StringToInteger(StringSubstr(start,3,2));
   eh = (int)StringToInteger(StringSubstr(end,0,2)); em = (int)StringToInteger(StringSubstr(end,3,2));
   int now = h*60+m, s = sh*60+sm, e = eh*60+em;
   return (s<=e) ? (now>=s && now<e) : (now>=s || now<e);
}
//+------------------------------------------------------------------+
