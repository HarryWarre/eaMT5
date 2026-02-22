//+------------------------------------------------------------------+
//|                                                        EIEMA.mq5 |
//|                                  Copyright 2026, Deepmind Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Deepmind Agent"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Group: Strategy
input group "Strategy: Elder Impulse"
input int    InpMACDFast     = 12;    // MACD Fast
input int    InpMACDSlow     = 26;    // MACD Slow
input int    InpMACDSignal   = 9;     // MACD Signal
input int    InpEMAShort     = 13;    // Short EMA (Trend)
input int    InpEFILength    = 13;    // EFI Length

input group "Strategy: MTF Filter"
input ENUM_TIMEFRAMES InpMTFFrame = PERIOD_D1; // MTF Timeframe (D1)
input int    InpMTFMALen      = 13;             // MTF EMA Length

input group "Strategy: S/R Zone"
input bool            InpUseSR          = false;    // Use Support/Resistance Filter
input ENUM_TIMEFRAMES InpSRFrame        = PERIOD_H4;// S/R Timeframe
input int             InpPivotLeft      = 15;       // Pivot Left Bars
input int             InpPivotRight     = 15;       // Pivot Right Bars

input group "Risk Management"
input double InpRiskPercent   = 2.0;   // Risk Percent per Trade
input int    InpSLPoints      = 500;   // Stop Loss (Points)
input int    InpTPPoints      = 1000;  // Take Profit (Points)

input group "== TIME TRADING (VIETNAM TIME GMT+7) =="
input bool   InpUseTimeSlot      = true;     
input string InpT1Start          = "09:00";  
input string InpT1End            = "17:00";  
input string InpT2Start          = "22:00";  
input string InpT2End            = "03:00";  
input int    InpServerGMTOffset  = 2;        

input int    InpMagicNumber      = 223344;

//--- Global Objects
CTrade         trade;
CSymbolInfo    m_symbol;
CPositionInfo  m_position;

//--- Indicator Handles
int h_macd;
int h_ema;
int h_efi;
int h_mtf_ma;

//--- S/R Struct
struct SRZone {
   double top;
   double bottom;
   bool valid;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!m_symbol.Name(Symbol())) return(INIT_FAILED);
   RefreshRates();
   
   // Initialize Indicators
   h_macd = iMACD(Symbol(), Period(), InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   h_ema  = iMA(Symbol(), Period(), InpEMAShort, 0, MODE_EMA, PRICE_CLOSE);
   h_efi  = iForce(Symbol(), Period(), InpEFILength, MODE_EMA, VOLUME_TICK); 
   // Note: Pine uses (Change * Volume). iForce does exactly this (Price-PrevPrice)*Volume.
   
   h_mtf_ma = iMA(Symbol(), InpMTFFrame, InpMTFMALen, 0, MODE_EMA, PRICE_CLOSE);
   
   if(h_macd == INVALID_HANDLE || h_ema == INVALID_HANDLE || h_efi == INVALID_HANDLE || h_mtf_ma == INVALID_HANDLE)
      return(INIT_FAILED);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(Symbol());

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(h_macd);
   IndicatorRelease(h_ema);
   IndicatorRelease(h_efi);
   IndicatorRelease(h_mtf_ma);
  }

void OnTick()
  {
   if(!RefreshRates()) return;
   
   // 1. Calculate Signals
   // --------------------
   
   // A. Elder Impulse System (Current TF)
   double ema[], macd_main[], macd_sig[];
   ArraySetAsSeries(ema, true); ArraySetAsSeries(macd_main, true); ArraySetAsSeries(macd_sig, true);
   
   CopyBuffer(h_ema, 0, 0, 3, ema);
   CopyBuffer(h_macd, 0, 0, 3, macd_main);
   CopyBuffer(h_macd, 1, 0, 3, macd_sig);
   
   double hist0 = macd_main[0] - macd_sig[0];
   double hist1 = macd_main[1] - macd_sig[1];
   
   bool elderBull = (ema[0] > ema[1]) && (hist0 > hist1);
   bool elderBear = (ema[0] < ema[1]) && (hist0 < hist1);
   
   // B. EFI
   double efi[];
   ArraySetAsSeries(efi, true);
   CopyBuffer(h_efi, 0, 0, 2, efi);
   bool efiBull = efi[0] > 0;
   bool efiBear = efi[0] < 0;
   
   // C. MTF Elder Ray
   double mtfMA[];
   ArraySetAsSeries(mtfMA, true);
   CopyBuffer(h_mtf_ma, 0, 0, 2, mtfMA); // Get recent D1 MA
   
   // We need D1 High/Low matching that MA bar
   MqlRates d1Rate[];
   ArraySetAsSeries(d1Rate, true);
   CopyRates(Symbol(), InpMTFFrame, 0, 1, d1Rate);
   
   double bullPower = d1Rate[0].high - mtfMA[0];
   double bearPower = d1Rate[0].low - mtfMA[0];
   double elderRay = bullPower + bearPower;
   
   bool mtfBull = elderRay > 0;
   bool mtfBear = elderRay < 0;
   
   // D. S/R Zones (Optional)
   bool nearRes = false;
   bool nearSup = false;
   
   if(InpUseSR) {
      SRZone res = GetPivotZone(1); // 1 = High/Res
      SRZone sup = GetPivotZone(-1); // -1 = Low/Sup
      
      double close = iClose(Symbol(), Period(), 0);
      
      if(res.valid && close <= res.top && close >= res.bottom) nearRes = true;
      if(sup.valid && close <= sup.top && close >= sup.bottom) nearSup = true;
   }
   
   // 2. Logic Conditions
   // -------------------
   // Entry
   bool longCond = elderBull && efiBull && mtfBull;
   bool shortCond = elderBear && efiBear && mtfBear;
   
   // Exit (Close)
   bool closeLong = elderBear && efiBear; // Close Long when Bear signal appears
   bool closeShort = elderBull && efiBull; // Close Short when Bull signal appears
   
   // 3. Execution
   // ------------
   
   // Check Exits
   if(PositionsTotal() > 0) {
      for(int i=PositionsTotal()-1; i>=0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Symbol()==Symbol() && m_position.Magic()==InpMagicNumber) {
               if(m_position.PositionType()==POSITION_TYPE_BUY && closeLong) trade.PositionClose(m_position.Ticket());
               if(m_position.PositionType()==POSITION_TYPE_SELL && closeShort) trade.PositionClose(m_position.Ticket());
            }
         }
      }
   }
   
   // Check Entries
   // Must check Time Filter first
   if(!CheckTime()) return;
   
   if(PositionsTotal() > 0) return; // Only 1 trade
   
   if(longCond && !nearRes) {
      OpenTrade(ORDER_TYPE_BUY);
   }
   else if(shortCond && !nearSup) {
      OpenTrade(ORDER_TYPE_SELL);
   }
  }

//+------------------------------------------------------------------+
//| Logic: Open Trade                                                |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type)
  {
   double price = (type==ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   double sl = 0, tp = 0;
   double point = m_symbol.Point();
   
   if(type == ORDER_TYPE_BUY) {
      sl = price - InpSLPoints * point;
      tp = price + InpTPPoints * point;
   } else {
      sl = price + InpSLPoints * point;
      tp = price - InpTPPoints * point;
   }
   
   double slNorm = m_symbol.NormalizePrice(sl);
   double tpNorm = m_symbol.NormalizePrice(tp);
   
   // Calculate Lot
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double dist = MathAbs(price - sl);
   double tickVal = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();
   
   double lot = 0.01;
   if(dist > 0 && tickSize > 0) {
      lot = riskMoney / ((dist/tickSize) * tickVal);
   }
   
   // Normalize Lot
   double stepLot = m_symbol.LotsStep();
   lot = MathFloor(lot/stepLot) * stepLot;
   if(lot < m_symbol.LotsMin()) lot = m_symbol.LotsMin();
   if(lot > m_symbol.LotsMax()) lot = m_symbol.LotsMax();
   
   if(type == ORDER_TYPE_BUY) trade.Buy(lot, Symbol(), price, slNorm, tpNorm, "EIEMA Buy");
   else trade.Sell(lot, Symbol(), price, slNorm, tpNorm, "EIEMA Sell");
  }

//+------------------------------------------------------------------+
//| Helper: Get Pivot Zone (H4 Scan)                                 |
//+------------------------------------------------------------------+
SRZone GetPivotZone(int type) {
   // Type 1 = High (Res), -1 = Low (Sup)
   SRZone z; z.valid = false;
   
   // Scan H4 history for Pivot
   // Lookback limited to prevent performance kill, e.g. 500 bars
   int limit = 500;
   
   // iHighest/iLowest is faster
   // But we need the pattern Left/Right
   // We search backwards from Right+1
   
   int barsToCheck = InpPivotLeft + InpPivotRight + 1;
   
   for(int i=InpPivotRight+1; i<limit; i++) {
      bool found = false;
      
      if(type == 1) { // High
         double center = iHigh(Symbol(), InpSRFrame, i);
         bool valid = true;
         // Check Left
         for(int k=1; k<=InpPivotLeft; k++) if(iHigh(Symbol(), InpSRFrame, i+k) > center) { valid=false; break; }
         // Check Right
         if(valid) for(int k=1; k<=InpPivotRight; k++) if(iHigh(Symbol(), InpSRFrame, i-k) > center) { valid=false; break; }
         
         if(valid) {
             z.top = iHigh(Symbol(), InpSRFrame, i); // High of pivot bar
             z.bottom = iLow(Symbol(), InpSRFrame, i); // Low of pivot bar (Zone Range)
             z.valid = true;
             return z;
         }
      } 
      else { // Low
         double center = iLow(Symbol(), InpSRFrame, i);
         bool valid = true;
         for(int k=1; k<=InpPivotLeft; k++) if(iLow(Symbol(), InpSRFrame, i+k) < center) { valid=false; break; }
         if(valid) for(int k=1; k<=InpPivotRight; k++) if(iLow(Symbol(), InpSRFrame, i-k) < center) { valid=false; break; }
         
         if(valid) {
             z.top = iHigh(Symbol(), InpSRFrame, i); 
             z.bottom = iLow(Symbol(), InpSRFrame, i); 
             z.valid = true;
             return z;
         }
      }
   }
   return z;
}

//+------------------------------------------------------------------+
//| Helper: Check Time (Viper)                                       |
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
bool RefreshRates() { return m_symbol.RefreshRates(); }
