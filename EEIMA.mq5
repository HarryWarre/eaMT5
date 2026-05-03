//+------------------------------------------------------------------+
//|                                                       EEIMA.mq5  |
//|        Elder Impulse + EMA Filter + MTF Elder Ray + ADX          |
//|                     Copyright 2026, DaiViet Quant                |
//+------------------------------------------------------------------+
//| Strategy: Elder Impulse System + EFI confirmation                |
//| MTF: Elder Ray (Bull/Bear Power) trên khung lớn                  |
//| Filter: ADX (trend strength), S/R Zones (pivot), Scalp Mode     |
//| Entry: Market hoặc Breakout Stop Order                           |
//| Exit: Opposite Elder+EFI (normal) / Neutral+Pinbar (scalp)      |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, DaiViet Quant"
#property version     "1.00"
#property strict
#property description "EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Defines.mqh - Enumerations & Constants                           |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+

//--- Preset Mode (matching PineScript presets)
enum ENUM_PRESET_MODE {
   PRESET_AUTO         = 0,  // Auto (Tự do)
   PRESET_SCALP_1H     = 1,  // Set 1: Scalp (1H)
   PRESET_INTRADAY_4H  = 2,  // Set 2: Intraday (4H)
   PRESET_SWING_1D     = 3,  // Set 3: Swing day (1D)
   PRESET_STOCK_1W     = 4   // Set 4: Stock (1W)
};

//--- Elder Impulse Color State
enum ENUM_ELDER_COLOR {
   ELDER_GREEN  = 1,   // Bullish (EMA up + MACD hist up)
   ELDER_RED    = -1,   // Bearish (EMA down + MACD hist down)
   ELDER_BLUE   = 0    // Neutral
};

//--- Signal Direction
#define DIR_NONE   0
#define DIR_BUY    1
#define DIR_SELL  -1

//--- Comment tag for orders
#define EA_COMMENT "EEIMA"

//+------------------------------------------------------------------+
//| Inputs.mqh - All Input Parameters                                |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+

//--- Preset Mode
input group "=== PRESET MODE ==="
input ENUM_PRESET_MODE InpPresetMode = PRESET_AUTO; // Trading Mode (Presets)

//--- Entry Options
input group "=== Entry Options ==="
input bool   InpUseBreakoutEntry = false;  // Use Breakout Entry (stop order at High/Low)
input bool   InpUseSR            = false;  // Use Support/Resistance Zone Filter

//--- Scalp Mode
input group "=== Scalp Mode ==="
input bool   InpScalpMode        = false;  // Enable Scalp Mode
input double InpScalpEMADist     = 0.5;    // Max Distance from EMA (%)

//--- Indicator Settings
input group "=== Indicators Settings ==="
input int    InpMACDFast         = 12;     // MACD Fast Length
input int    InpMACDSlow         = 26;     // MACD Slow Length
input int    InpMACDSignal       = 9;      // MACD Signal Length
input int    InpEMAShort         = 13;     // Short EMA Length
input int    InpEMALong          = 50;     // Long EMA Length (unused in entry, for display)
input int    InpEMATrend         = 153;    // Trend EMA Length (EMA156 filter)
input double InpChannelPct       = 0.04;   // EMA Channel %
input int    InpEFILength        = 13;     // EFI EMA Length
input int    InpDILength         = 14;     // DI Length
input int    InpADXSmoothing     = 14;     // ADX Smoothing
input double InpADXThreshold     = 20.0;   // ADX Threshold

//--- Timeframe Settings
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpMTFTimeframe = PERIOD_D1;  // Higher Timeframe for MTF Elder Ray (Auto mode)
input int    InpMTFMALen         = 13;     // MTF EMA Length for Elder Ray
input ENUM_TIMEFRAMES InpSRTimeframe = PERIOD_H4;   // Support/Resistance Timeframe (Auto mode)
input int    InpPivotLeft        = 15;     // Pivot Left Bars
input int    InpPivotRight       = 15;     // Pivot Right Bars

//--- Lot Size
input group "=== Lot Size ==="
input double InpLotSize          = 0.01;   // Fixed Lot Size

//--- Time Trading (Vietnam GMT+7)
input group "== TIME TRADING (VIETNAM TIME GMT+7) =="
input bool   InpUseTimeSlot      = true;   // Enable Time Slot Filter
input string InpT1Start          = "09:00";// Slot 1 Start
input string InpT1End            = "17:00";// Slot 1 End
input string InpT2Start          = "22:00";// Slot 2 Start
input string InpT2End            = "03:00";// Slot 2 End
input int    InpServerGMTOffset  = 2;      // Server GMT Offset

//--- Magic Number
input group "=== Trading ==="
input int    InpMagicNumber      = 556677; // Magic Number
input int    InpMaxSpread        = 30;     // Max Spread (Points)

//+------------------------------------------------------------------+
//| GlobalVars.mqh - Global Objects & State Variables                 |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+

//--- Trade Objects
CTrade         m_trade;
CSymbolInfo    m_symbol;
CPositionInfo  m_position;

//--- Point helpers
double g_point  = 0;
double g_p2p    = 1;  // Point-to-pip multiplier

//--- Indicator Handles (Current TF)
int h_macd        = INVALID_HANDLE;
int h_ema_short   = INVALID_HANDLE;
int h_ema_long    = INVALID_HANDLE;
int h_ema_trend   = INVALID_HANDLE;
int h_efi         = INVALID_HANDLE;
int h_adx         = INVALID_HANDLE;

//--- Indicator Handles (MTF)
int h_mtf_ema     = INVALID_HANDLE;
int h_mtf_adx     = INVALID_HANDLE;

//--- Resolved Timeframes (after preset logic)
ENUM_TIMEFRAMES g_mtfTimeframe = PERIOD_D1;
ENUM_TIMEFRAMES g_srTimeframe  = PERIOD_H4;

//--- Elder Impulse State (updated each bar)
bool g_elderBull  = false;
bool g_elderBear  = false;
ENUM_ELDER_COLOR g_elderColor = ELDER_BLUE;

//--- EFI State
bool g_efiBull    = false;
bool g_efiBear    = false;

//--- MTF Elder Ray State
bool   g_mtfBull      = false;
bool   g_mtfBear      = false;
double g_mtfElderRay  = 0;
double g_mtfADXValue  = 0;
bool   g_mtfADXStrong = false;

//--- Scalp Mode State
bool   g_isWithinScalpZone = false;
double g_distPct           = 0;

//--- Pinbar Detection State
bool g_isBearishPinbar = false;
bool g_isBullishPinbar = false;

//--- S/R Zone State
bool g_nearResistance = false;
bool g_nearSupport    = false;

//--- S/R Zone Struct
struct SRZone {
   double top;
   double bottom;
   bool   valid;
};

//--- New bar detection
datetime g_lastBar = 0;

//--- EMA buffer values (for GUI)
double g_emaShortVal  = 0;
double g_emaLongVal   = 0;
double g_emaTrendVal  = 0;
double g_efiVal       = 0;
double g_adxVal       = 0;

//+------------------------------------------------------------------+
//| Indicators.mqh - Indicator Init, Read, Release                   |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Resolve Preset Timeframes                                        |
//+------------------------------------------------------------------+
void ResolvePresetTimeframes() {
   switch(InpPresetMode) {
      case PRESET_SCALP_1H:
         g_mtfTimeframe = PERIOD_H1;
         g_srTimeframe  = PERIOD_H1;
         break;
      case PRESET_INTRADAY_4H:
         g_mtfTimeframe = PERIOD_H4;
         g_srTimeframe  = PERIOD_H4;
         break;
      case PRESET_SWING_1D:
         g_mtfTimeframe = PERIOD_D1;
         g_srTimeframe  = PERIOD_D1;
         break;
      case PRESET_STOCK_1W:
         g_mtfTimeframe = PERIOD_W1;
         g_srTimeframe  = PERIOD_W1;
         break;
      default: // PRESET_AUTO
         g_mtfTimeframe = InpMTFTimeframe;
         g_srTimeframe  = InpSRTimeframe;
         break;
   }
}

//+------------------------------------------------------------------+
//| Initialize all indicator handles                                 |
//+------------------------------------------------------------------+
bool InitIndicators() {
   ResolvePresetTimeframes();

   //--- Current TF indicators
   h_macd      = iMACD(_Symbol, PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   h_ema_short = iMA(_Symbol, PERIOD_CURRENT, InpEMAShort, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_long  = iMA(_Symbol, PERIOD_CURRENT, InpEMALong, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_trend = iMA(_Symbol, PERIOD_CURRENT, InpEMATrend, 0, MODE_EMA, PRICE_CLOSE);
   h_efi       = iForce(_Symbol, PERIOD_CURRENT, InpEFILength, MODE_EMA, VOLUME_TICK);
   h_adx       = iADX(_Symbol, PERIOD_CURRENT, InpDILength);

   //--- MTF indicators
   h_mtf_ema   = iMA(_Symbol, g_mtfTimeframe, InpMTFMALen, 0, MODE_EMA, PRICE_CLOSE);
   h_mtf_adx   = iADX(_Symbol, g_mtfTimeframe, InpDILength);

   //--- Validate
   if(h_macd == INVALID_HANDLE || h_ema_short == INVALID_HANDLE ||
      h_ema_long == INVALID_HANDLE || h_ema_trend == INVALID_HANDLE ||
      h_efi == INVALID_HANDLE || h_adx == INVALID_HANDLE ||
      h_mtf_ema == INVALID_HANDLE || h_mtf_adx == INVALID_HANDLE) {
      Print("[EEIMA] ERROR: Failed to create indicator handles!");
      return false;
   }

   Print("[EEIMA] Indicators initialized OK. MTF=", EnumToString(g_mtfTimeframe),
         " SR=", EnumToString(g_srTimeframe));
   return true;
}

//+------------------------------------------------------------------+
//| Read all indicator buffers for current bar                       |
//+------------------------------------------------------------------+
bool ReadIndicators() {
   //--- EMA Short (need 2 bars for slope comparison)
   double emaShort[];
   ArraySetAsSeries(emaShort, true);
   if(CopyBuffer(h_ema_short, 0, 0, 3, emaShort) < 3) return false;

   //--- EMA Long
   double emaLong[];
   ArraySetAsSeries(emaLong, true);
   if(CopyBuffer(h_ema_long, 0, 0, 2, emaLong) < 2) return false;

   //--- EMA Trend
   double emaTrend[];
   ArraySetAsSeries(emaTrend, true);
   if(CopyBuffer(h_ema_trend, 0, 0, 2, emaTrend) < 2) return false;

   //--- MACD (buffer 0 = main line, buffer 1 = signal line)
   double macdMain[], macdSig[];
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSig, true);
   if(CopyBuffer(h_macd, 0, 0, 3, macdMain) < 3) return false;
   if(CopyBuffer(h_macd, 1, 0, 3, macdSig)  < 3) return false;

   double hist0 = macdMain[0] - macdSig[0];
   double hist1 = macdMain[1] - macdSig[1];

   //--- EFI
   double efi[];
   ArraySetAsSeries(efi, true);
   if(CopyBuffer(h_efi, 0, 0, 2, efi) < 2) return false;

   //--- ADX (buffer 0 = ADX main, buffer 1 = +DI, buffer 2 = -DI)
   double adxBuf[];
   ArraySetAsSeries(adxBuf, true);
   if(CopyBuffer(h_adx, 0, 0, 2, adxBuf) < 2) return false;

   //--- Save to global vars
   g_emaShortVal  = emaShort[0];
   g_emaLongVal   = emaLong[0];
   g_emaTrendVal  = emaTrend[0];
   g_efiVal       = efi[0];
   g_adxVal       = adxBuf[0];

   //--- Elder Impulse calculation
   g_elderBull = (emaShort[0] > emaShort[1]) && (hist0 > hist1);
   g_elderBear = (emaShort[0] < emaShort[1]) && (hist0 < hist1);

   if(g_elderBull)      g_elderColor = ELDER_GREEN;
   else if(g_elderBear) g_elderColor = ELDER_RED;
   else                 g_elderColor = ELDER_BLUE;

   //--- EFI
   g_efiBull = efi[0] > 0;
   g_efiBear = efi[0] < 0;

   //--- Scalp distance calc
   if(g_emaShortVal > 0) {
      double bid = m_symbol.Bid();
      g_distPct = (MathAbs(bid - g_emaShortVal) / g_emaShortVal) * 100.0;
      g_isWithinScalpZone = (g_distPct <= InpScalpEMADist);
   }

   //--- Pinbar detection
   double o = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double h = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double l = iLow(_Symbol, PERIOD_CURRENT, 0);
   double c = iClose(_Symbol, PERIOD_CURRENT, 0);

   double body = MathAbs(c - o);
   double upperWick = h - MathMax(c, o);
   double lowerWick = MathMin(c, o) - l;

   g_isBearishPinbar = (upperWick > (2.0 * body)) && (lowerWick <= body);
   g_isBullishPinbar = (lowerWick > (2.0 * body)) && (upperWick <= body);

   return true;
}

//+------------------------------------------------------------------+
//| Release all indicator handles                                    |
//+------------------------------------------------------------------+
void ReleaseIndicators() {
   if(h_macd      != INVALID_HANDLE) IndicatorRelease(h_macd);
   if(h_ema_short != INVALID_HANDLE) IndicatorRelease(h_ema_short);
   if(h_ema_long  != INVALID_HANDLE) IndicatorRelease(h_ema_long);
   if(h_ema_trend != INVALID_HANDLE) IndicatorRelease(h_ema_trend);
   if(h_efi       != INVALID_HANDLE) IndicatorRelease(h_efi);
   if(h_adx       != INVALID_HANDLE) IndicatorRelease(h_adx);
   if(h_mtf_ema   != INVALID_HANDLE) IndicatorRelease(h_mtf_ema);
   if(h_mtf_adx   != INVALID_HANDLE) IndicatorRelease(h_mtf_adx);
}

//+------------------------------------------------------------------+
//| ElderImpulse.mqh - Elder Impulse System Logic                    |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+
//| The Elder Impulse System uses:                                   |
//| 1. EMA Short slope (ema[0] vs ema[1])                            |
//| 2. MACD Histogram slope (hist[0] vs hist[1])                     |
//|                                                                  |
//| Both rising → Green (Bull)                                       |
//| Both falling → Red (Bear)                                        |
//| Otherwise → Blue (Neutral)                                       |
//|                                                                  |
//| NOTE: The actual calculation is done in Indicators.mqh:           |
//| ReadIndicators() to avoid duplicate buffer reads.                 |
//| This file provides helper functions for the Elder system.         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Elder Impulse status as string (for GUI/logging)             |
//+------------------------------------------------------------------+
string ElderColorToString(ENUM_ELDER_COLOR clr) {
   switch(clr) {
      case ELDER_GREEN: return "BULLISH (Green)";
      case ELDER_RED:   return "BEARISH (Red)";
      default:          return "NEUTRAL (Blue)";
   }
}

//+------------------------------------------------------------------+
//| Get Elder Impulse color for chart display                        |
//+------------------------------------------------------------------+
color ElderColorToColor(ENUM_ELDER_COLOR clr) {
   switch(clr) {
      case ELDER_GREEN: return clrLime;
      case ELDER_RED:   return clrRed;
      default:          return clrDodgerBlue;
   }
}

//+------------------------------------------------------------------+
//| Check if Elder Impulse is aligned with given direction           |
//| dir: DIR_BUY(1) or DIR_SELL(-1)                                  |
//+------------------------------------------------------------------+
bool IsElderAligned(int dir) {
   if(dir == DIR_BUY)  return g_elderBull;
   if(dir == DIR_SELL) return g_elderBear;
   return false;
}

//+------------------------------------------------------------------+
//| MTFElderRay.mqh - Multi-Timeframe Elder Ray + ADX                |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+
//| Replicates PineScript:                                           |
//|   mtf_bull_power = mtf_high - mtf_ema                            |
//|   mtf_bear_power = mtf_low  - mtf_ema                            |
//|   mtf_elder_ray  = bull_power + bear_power                       |
//|   mtf_is_bull    = elder_ray > 0                                 |
//|   mtf_adx > threshold                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate MTF Elder Ray and MTF ADX                              |
//| Call once per bar after ReadIndicators()                          |
//+------------------------------------------------------------------+
bool CalcMTFElderRay() {
   //--- Get MTF EMA value
   double mtfEMA[];
   ArraySetAsSeries(mtfEMA, true);
   if(CopyBuffer(h_mtf_ema, 0, 0, 2, mtfEMA) < 2) return false;

   //--- Get MTF candle data (most recent closed bar on MTF)
   MqlRates mtfRates[];
   ArraySetAsSeries(mtfRates, true);
   if(CopyRates(_Symbol, g_mtfTimeframe, 0, 2, mtfRates) < 2) return false;

   //--- Calculate Elder Ray
   //--- Use bar[0] which is the current (possibly forming) MTF bar
   //--- This matches PineScript's lookahead_on behavior with request.security
   double bullPower = mtfRates[0].high - mtfEMA[0];
   double bearPower = mtfRates[0].low  - mtfEMA[0];
   g_mtfElderRay    = bullPower + bearPower;

   g_mtfBull = (g_mtfElderRay > 0);
   g_mtfBear = (g_mtfElderRay < 0);

   //--- Get MTF ADX (buffer 0 = ADX main value)
   double mtfADX[];
   ArraySetAsSeries(mtfADX, true);
   if(CopyBuffer(h_mtf_adx, 0, 0, 2, mtfADX) < 2) return false;

   g_mtfADXValue  = mtfADX[0];
   g_mtfADXStrong = (mtfADX[0] > InpADXThreshold);

   return true;
}

//+------------------------------------------------------------------+
//| Get MTF trend status as string (for GUI/logging)                 |
//+------------------------------------------------------------------+
string MTFTrendToString() {
   if(g_mtfBull) return "BULL";
   if(g_mtfBear) return "BEAR";
   return "FLAT";
}

//+------------------------------------------------------------------+
//| SRZones.mqh - Pivot-Based Support/Resistance Zones               |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+
//| Scans higher TF bars for Pivot High/Low using left/right bars.   |
//| Returns SRZone with top/bottom (high/low of pivot candle).       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Pivot Zone from higher TF                                    |
//| type: 1 = High (Resistance), -1 = Low (Support)                 |
//+------------------------------------------------------------------+
SRZone GetPivotZone(int type) {
   SRZone z;
   z.valid  = false;
   z.top    = 0;
   z.bottom = 0;

   int limit = 500; // Max bars to scan to protect performance

   for(int i = InpPivotRight + 1; i < limit; i++) {
      if(type == 1) {
         //--- Looking for Pivot High (Resistance)
         double center = iHigh(_Symbol, g_srTimeframe, i);
         bool valid = true;

         // Check Left bars: all must have lower highs
         for(int k = 1; k <= InpPivotLeft; k++) {
            if(iHigh(_Symbol, g_srTimeframe, i + k) > center) {
               valid = false;
               break;
            }
         }
         // Check Right bars: all must have lower highs
         if(valid) {
            for(int k = 1; k <= InpPivotRight; k++) {
               if(iHigh(_Symbol, g_srTimeframe, i - k) > center) {
                  valid = false;
                  break;
               }
            }
         }

         if(valid) {
            z.top    = iHigh(_Symbol, g_srTimeframe, i);
            z.bottom = iLow(_Symbol, g_srTimeframe, i);
            z.valid  = true;
            return z;
         }
      }
      else {
         //--- Looking for Pivot Low (Support)
         double center = iLow(_Symbol, g_srTimeframe, i);
         bool valid = true;

         // Check Left bars
         for(int k = 1; k <= InpPivotLeft; k++) {
            if(iLow(_Symbol, g_srTimeframe, i + k) < center) {
               valid = false;
               break;
            }
         }
         // Check Right bars
         if(valid) {
            for(int k = 1; k <= InpPivotRight; k++) {
               if(iLow(_Symbol, g_srTimeframe, i - k) < center) {
                  valid = false;
                  break;
               }
            }
         }

         if(valid) {
            z.top    = iHigh(_Symbol, g_srTimeframe, i);
            z.bottom = iLow(_Symbol, g_srTimeframe, i);
            z.valid  = true;
            return z;
         }
      }
   }

   return z;
}

//+------------------------------------------------------------------+
//| Update S/R Zone state (nearResistance / nearSupport)             |
//+------------------------------------------------------------------+
void UpdateSRZones() {
   g_nearResistance = false;
   g_nearSupport    = false;

   if(!InpUseSR) return;

   double bid = m_symbol.Bid();

   SRZone res = GetPivotZone(1);  // Resistance
   SRZone sup = GetPivotZone(-1); // Support

   if(res.valid && bid <= res.top && bid >= res.bottom)
      g_nearResistance = true;

   if(sup.valid && bid <= sup.top && bid >= sup.bottom)
      g_nearSupport = true;
}

//+------------------------------------------------------------------+
//| ScalpMode.mqh - Scalp Mode Logic                                 |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+
//| Scalp mode differences from normal:                              |
//| - Ignores MTF trend filter (enters on Elder + EFI only)          |
//| - Requires price to be within X% of Short EMA                   |
//| - Exits on neutral candles (not just opposite) or pinbars        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Scalp Entry Conditions (replaces MTF filter)               |
//+------------------------------------------------------------------+
bool ScalpLongCondition() {
   return g_elderBull && g_efiBull && g_isWithinScalpZone;
}

bool ScalpShortCondition() {
   return g_elderBear && g_efiBear && g_isWithinScalpZone;
}

//+------------------------------------------------------------------+
//| Check Scalp Exit Conditions (stricter than normal)               |
//+------------------------------------------------------------------+
bool ScalpExitLong() {
   // Exit if Elder is not bullish (neutral or bearish) OR bearish pinbar
   return (!g_elderBull) || g_isBearishPinbar;
}

bool ScalpExitShort() {
   // Exit if Elder is not bearish (neutral or bullish) OR bullish pinbar
   return (!g_elderBear) || g_isBullishPinbar;
}

//+------------------------------------------------------------------+
//| TradeLogic.mqh - Entry/Exit Logic & Order Execution              |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//| NO SL / NO TP - Exit purely by signal (Elder Impulse reversal)   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Count positions for this EA (by magic number)                    |
//+------------------------------------------------------------------+
int CountMyPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count pending orders for this EA                                 |
//+------------------------------------------------------------------+
int CountMyOrders() {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0) {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Cancel all pending orders for this EA                            |
//+------------------------------------------------------------------+
void CancelMyOrders() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0) {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber) {
            m_trade.OrderDelete(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open a market trade - NO SL, NO TP                               |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type) {
   //--- Spread check
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;

   double price = (type == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();

   if(type == ORDER_TYPE_BUY)
      m_trade.Buy(InpLotSize, _Symbol, price, 0, 0, EA_COMMENT + " Buy");
   else
      m_trade.Sell(InpLotSize, _Symbol, price, 0, 0, EA_COMMENT + " Sell");
}

//+------------------------------------------------------------------+
//| Open Breakout Stop Order - NO SL, NO TP                          |
//+------------------------------------------------------------------+
void OpenBreakoutOrder(ENUM_ORDER_TYPE baseType) {
   //--- Spread check
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;

   double point = m_symbol.Point();

   if(baseType == ORDER_TYPE_BUY) {
      double triggerPrice = iHigh(_Symbol, PERIOD_CURRENT, 0) + point;
      triggerPrice = m_symbol.NormalizePrice(triggerPrice);
      m_trade.BuyStop(InpLotSize, triggerPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, EA_COMMENT + " BuyStop");
   }
   else {
      double triggerPrice = iLow(_Symbol, PERIOD_CURRENT, 0) - point;
      triggerPrice = m_symbol.NormalizePrice(triggerPrice);
      m_trade.SellStop(InpLotSize, triggerPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, EA_COMMENT + " SellStop");
   }
}

//+------------------------------------------------------------------+
//| Manage Exits: Close positions on exit signal                     |
//+------------------------------------------------------------------+
void ManageExits() {
   bool exitLong  = false;
   bool exitShort = false;

   if(InpScalpMode) {
      exitLong  = ScalpExitLong();
      exitShort = ScalpExitShort();
   } else {
      exitLong  = g_elderBear && g_efiBear;
      exitShort = g_elderBull && g_efiBull;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() != _Symbol) continue;
         if(m_position.Magic()  != InpMagicNumber) continue;

         if(m_position.PositionType() == POSITION_TYPE_BUY && exitLong) {
            m_trade.PositionClose(m_position.Ticket());
            Print("[EEIMA] Close BUY: ", InpScalpMode ? "Scalp Exit" : "Signal Exit");
         }

         if(m_position.PositionType() == POSITION_TYPE_SELL && exitShort) {
            m_trade.PositionClose(m_position.Ticket());
            Print("[EEIMA] Close SELL: ", InpScalpMode ? "Scalp Exit" : "Signal Exit");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Entries: Open positions on entry signal                   |
//+------------------------------------------------------------------+
void ManageEntries() {
   //--- STRICT: Only 1 position at a time (single trade strategy)
   if(CountMyPositions() > 0) return;

   bool longCond  = false;
   bool shortCond = false;

   if(InpScalpMode) {
      longCond  = ScalpLongCondition();
      shortCond = ScalpShortCondition();
   } else {
      longCond  = g_elderBull && g_efiBull && g_mtfBull;
      shortCond = g_elderBear && g_efiBear && g_mtfBear;
   }

   bool allowLong  = InpUseSR ? !g_nearResistance : true;
   bool allowShort = InpUseSR ? !g_nearSupport    : true;

   if(InpUseBreakoutEntry) {
      CancelMyOrders(); // Cancel stale pending orders
      if(longCond && allowLong)       OpenBreakoutOrder(ORDER_TYPE_BUY);
      else if(shortCond && allowShort) OpenBreakoutOrder(ORDER_TYPE_SELL);
   }
   else {
      if(longCond && allowLong)       OpenTrade(ORDER_TYPE_BUY);
      else if(shortCond && allowShort) OpenTrade(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| TimeFilter.mqh - Vietnam Time Slot Filter                        |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+
//| Converts server time → Vietnam time (GMT+7)                      |
//| Supports cross-midnight time slots (e.g. 22:00 → 03:00)         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if current Vietnam time is in a given range                |
//+------------------------------------------------------------------+
bool InTimeRange(int h, int m, string start, string end) {
   if(StringLen(start) < 5 || StringLen(end) < 5) return false;

   int sh = (int)StringToInteger(StringSubstr(start, 0, 2));
   int sm = (int)StringToInteger(StringSubstr(start, 3, 2));
   int eh = (int)StringToInteger(StringSubstr(end, 0, 2));
   int em = (int)StringToInteger(StringSubstr(end, 3, 2));

   int now = h * 60 + m;
   int s   = sh * 60 + sm;
   int e   = eh * 60 + em;

   // Handle cross-midnight (e.g. 22:00 → 03:00)
   return (s <= e) ? (now >= s && now < e) : (now >= s || now < e);
}

//+------------------------------------------------------------------+
//| Main time check: returns true if trading is allowed now          |
//+------------------------------------------------------------------+
bool CheckTimeFilter() {
   if(!InpUseTimeSlot) return true;

   datetime serverTime = TimeCurrent();
   // Convert server time → Vietnam time (GMT+7)
   datetime vnTime = serverTime - (InpServerGMTOffset * 3600) + (7 * 3600);

   MqlDateTime dt;
   TimeToStruct(vnTime, dt);
   int h = dt.hour;
   int m = dt.min;

   return (InTimeRange(h, m, InpT1Start, InpT1End) ||
           InTimeRange(h, m, InpT2Start, InpT2End));
}

//+------------------------------------------------------------------+
//| GUI.mqh - On-Chart Information Panel                             |
//| EEIMA - Elder Impulse + EMA Filter + MTF Elder Ray + ADX         |
//+------------------------------------------------------------------+

#define GUI_PREFIX "EEIMA_"
#define GUI_X      10
#define GUI_Y      30
#define GUI_LINE_H 18
#define GUI_FONT   "Consolas"
#define GUI_SIZE   9

//+------------------------------------------------------------------+
//| Create a text label on chart                                     |
//+------------------------------------------------------------------+
void GUILabel(string name, int x, int y, string text, color clr = clrWhite) {
   string objName = GUI_PREFIX + name;

   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, objName, OBJPROP_FONT, GUI_FONT);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, GUI_SIZE);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Create background rectangle                                      |
//+------------------------------------------------------------------+
void GUIBackground(int x, int y, int w, int h) {
   string objName = GUI_PREFIX + "BG";

   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, C'20,25,35');
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, C'50,60,80');
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Update GUI panel with current status                             |
//+------------------------------------------------------------------+
void UpdateGUI() {
   int x = GUI_X;
   int y = GUI_Y;
   int line = 0;

   //--- Background
   int panelHeight = InpScalpMode ? (GUI_LINE_H * 12 + 10) : (GUI_LINE_H * 10 + 10);
   GUIBackground(x - 5, y - 5, 260, panelHeight);

   //--- Title
   GUILabel("title", x, y + (line++) * GUI_LINE_H,
            "═══ EEIMA v1.0 ═══", clrGold);

   //--- Preset
   string presetStr = "";
   switch(InpPresetMode) {
      case PRESET_SCALP_1H:    presetStr = "Scalp (1H)";     break;
      case PRESET_INTRADAY_4H: presetStr = "Intraday (4H)";  break;
      case PRESET_SWING_1D:    presetStr = "Swing (1D)";      break;
      case PRESET_STOCK_1W:    presetStr = "Stock (1W)";      break;
      default:                 presetStr = "Auto";            break;
   }
   GUILabel("preset", x, y + (line++) * GUI_LINE_H,
            "Preset: " + presetStr, clrSilver);

   //--- Elder Impulse
   GUILabel("elder", x, y + (line++) * GUI_LINE_H,
            "Elder: " + ElderColorToString(g_elderColor),
            ElderColorToColor(g_elderColor));

   //--- EFI
   string efiStr = StringFormat("EFI: %.2f %s", g_efiVal, g_efiBull ? "▲" : (g_efiBear ? "▼" : "—"));
   GUILabel("efi", x, y + (line++) * GUI_LINE_H,
            efiStr, g_efiBull ? clrLime : (g_efiBear ? clrRed : clrGray));

   //--- MTF Elder Ray
   string mtfStr = StringFormat("MTF Ray: %.4f [%s]", g_mtfElderRay, MTFTrendToString());
   color mtfClr = g_mtfBull ? clrLime : (g_mtfBear ? clrRed : clrGray);
   GUILabel("mtf", x, y + (line++) * GUI_LINE_H, mtfStr, mtfClr);

   //--- MTF ADX
   string adxStr = StringFormat("MTF ADX: %.1f %s", g_mtfADXValue,
                                g_mtfADXStrong ? "STRONG" : "WEAK");
   GUILabel("adx", x, y + (line++) * GUI_LINE_H,
            adxStr, g_mtfADXStrong ? clrYellow : clrGray);

   //--- Current ADX
   GUILabel("cadx", x, y + (line++) * GUI_LINE_H,
            StringFormat("ADX: %.1f", g_adxVal),
            g_adxVal > InpADXThreshold ? clrYellow : clrGray);

   //--- S/R Status
   if(InpUseSR) {
      string srStr = "S/R: ";
      if(g_nearResistance) srStr += "NEAR RES ⚠";
      else if(g_nearSupport) srStr += "NEAR SUP ⚠";
      else srStr += "CLEAR";
      GUILabel("sr", x, y + (line++) * GUI_LINE_H,
               srStr, (g_nearResistance || g_nearSupport) ? clrOrange : clrGreen);
   }

   //--- Scalp Mode Info
   if(InpScalpMode) {
      GUILabel("scalp_mode", x, y + (line++) * GUI_LINE_H,
               "★ SCALP MODE ★", clrMagenta);
      GUILabel("scalp_dist", x, y + (line++) * GUI_LINE_H,
               StringFormat("Dist: %.2f%% [Max: %.1f%%] %s",
                            g_distPct, InpScalpEMADist,
                            g_isWithinScalpZone ? "✓" : "✗"),
               g_isWithinScalpZone ? clrLime : clrRed);
   }

   //--- Positions
   GUILabel("pos", x, y + (line++) * GUI_LINE_H,
            StringFormat("Pos: %d | Orders: %d", CountMyPositions(), CountMyOrders()),
            clrSilver);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Cleanup GUI objects                                               |
//+------------------------------------------------------------------+
void CleanupGUI() {
   ObjectsDeleteAll(0, GUI_PREFIX);
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("=== EEIMA: Elder Impulse + EMA Filter + MTF Elder Ray + ADX ===");

   //--- Init symbol
   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   g_point = m_symbol.Point();
   g_p2p   = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10.0 : 1.0;

   //--- Init trade object
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);

   //--- Init indicators (also resolves preset timeframes)
   if(!InitIndicators()) return INIT_FAILED;

   //--- Print config
   PrintFormat("[EEIMA] Preset: %s | Scalp: %s | Breakout: %s | S/R: %s",
      EnumToString(InpPresetMode),
      InpScalpMode ? "ON" : "OFF",
      InpUseBreakoutEntry ? "ON" : "OFF",
      InpUseSR ? "ON" : "OFF");
   PrintFormat("[EEIMA] MACD(%d,%d,%d) | EMA Short=%d | EFI=%d | ADX Thresh=%.1f",
      InpMACDFast, InpMACDSlow, InpMACDSignal,
      InpEMAShort, InpEFILength, InpADXThreshold);
   PrintFormat("[EEIMA] Lot=%.2f | Magic=%d | No SL/TP (signal-based exit)",
      InpLotSize, InpMagicNumber);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ReleaseIndicators();
   CleanupGUI();
   Print("[EEIMA] Stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   //--- New bar detection (signal processing once per bar)
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (curBar != g_lastBar);
   if(!newBar) return;
   g_lastBar = curBar;

   //--- Refresh symbol data
   if(!m_symbol.RefreshRates()) return;

   //--- Read all indicator values
   if(!ReadIndicators()) return;

   //--- Calculate MTF Elder Ray
   if(!CalcMTFElderRay()) return;

   //--- Update S/R zones
   UpdateSRZones();

   //--- 1. Manage Exits FIRST (close positions on exit signal)
   ManageExits();

   //--- 2. Check time filter before entries
   if(!CheckTimeFilter()) {
      UpdateGUI();
      return;
   }

   //--- 3. Manage Entries (open positions on entry signal)
   ManageEntries();

   //--- 4. Update GUI
   UpdateGUI();
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester() {
   return AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
}
