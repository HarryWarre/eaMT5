//+------------------------------------------------------------------+
//|                                          NanningbobEA.mq5        |
//|                      3 Strategies: EA#1, EA#2, EA#3              |
//|                      Based on Nanningbob 4H System               |
//+------------------------------------------------------------------+
#property copyright "Nanningbob EA 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "EA#1: BB Bounce + RWB + Sixths"
#property description "EA#2: Huggie Pattern (1MA crosses back BB)"
#property description "EA#3: No Man's Land + Basis Cross"

//+------------------------------------------------------------------+
//| Enums (MUST be defined BEFORE inputs)                            |
//+------------------------------------------------------------------+

enum ENUM_TP_MODE
{
    TP_FIXED_PIPS,      // Fixed Pips
    TP_BB_TARGET,       // BB Target (opposite band)
    TP_SIXTHS_TARGET,   // Sixths Target (opposite level)
    TP_SUPPORT_RESISTANCE // Support/Resistance Level
};

enum ENUM_SL_MODE
{
    SL_NONE,            // No Stop Loss
    SL_FIXED_PIPS,      // Fixed Pips
    SL_BB_BAND,         // Opposite BB Band
    SL_SWING_POINT,     // Swing High/Low
    SL_ATR              // ATR-based
};

enum ENUM_RISK_MODE
{
    RISK_STATIC,        // Static Lot Size
    RISK_MONEY,         // Money-based ($ per 0.01 lot)
    RISK_PERCENT        // % of Balance
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input bool   enableEA1       = true;            // ✅ Enable EA#1 (BB Bounce)
input bool   enableEA2       = true;            // ✅ Enable EA#2 (Huggie Pattern)
input bool   enableEA3       = true;            // ✅ Enable EA#3 (No Man's Land)
input bool   enableEA4       = false;           // 🔲 Enable EA#4 (Grid Trading - Sideway)

sinput group "=== BOLLINGER BANDS ==="
input int    bbLength        = 25;              // BB Length
input ENUM_MA_METHOD bbMAType = MODE_SMA;       // BB MA Type
input double bbStdDev        = 2.0;             // BB Standard Deviation
input int    bbShift         = 0;               // BB Shift (for EA#7 future)

sinput group "=== SIXTHS RANGE ==="
input ENUM_TIMEFRAMES sixthsTimeframe = PERIOD_H4; // Sixths Timeframe
input int    sixthsBars      = 168;             // Sixths Range Bars (168 = 1 week on H4)

sinput group "=== RWB INDICATOR ==="
input int    stoKLength      = 14;              // Stochastic %K Length
input int    stoSmoothK      = 3;               // Stochastic Smooth %K
input int    stoSmoothD      = 3;               // Stochastic Smooth %D
input int    macdFast        = 12;              // MACD Fast Length
input int    macdSlow        = 26;              // MACD Slow Length
input int    macdSignalLen   = 9;               // MACD Signal Length

sinput group "=== DIVERGENCE ==="
input bool   useDivergence   = true;            // Use Divergence (for Stop Loss management)
input int    divLookback     = 26;              // Divergence Lookback Bars

sinput group "=== EA#2 SETTINGS ==="
input double huggieSepPips   = 20.0;            // Huggie Separation (Pips)

sinput group "=== EA#3 SETTINGS ==="
input double ea3SepPips      = 10.0;            // EA#3 Separation from Basis (Pips)

sinput group "=== TAKE PROFIT ==="
input bool   useTP           = true;            // 🎯 Use Take Profit
input ENUM_TP_MODE tpMode    = TP_FIXED_PIPS;   // TP Mode
input double fixedTPPips     = 50.0;            // Fixed TP (Pips)
input int    srLookback      = 50;              // S/R Lookback Bars
input int    srTouchMin      = 2;               // Min S/R Touches
input double srBufferPips    = 5.0;             // S/R Buffer (Pips)
input bool   useTrailing     = false;           // 📈 Use Trailing Stop
input double trailingStart   = 30.0;            // Trailing Start (Pips)
input double trailingStep    = 15.0;            // Trailing Step (Pips)

sinput group "=== STOP LOSS ==="
input ENUM_SL_MODE slMode    = SL_FIXED_PIPS;   // 🛑 Stop Loss Mode
input double fixedSLPips     = 30.0;            // Fixed SL (Pips)
input double slBufferPips    = 5.0;             // SL Buffer (Pips, for BB/Swing)
input double atrMultiplier   = 2.0;             // ATR Multiplier (for ATR SL)
input int    atrPeriod       = 14;              // ATR Period
input bool   useBreakeven    = true;            // 🔒 Move to Breakeven
input double breakevenStart  = 20.0;            // Breakeven Start (Pips)
input double breakevenProfit = 5.0;             // Breakeven Profit (Pips)

sinput group "=== RISK MANAGEMENT ==="
input ENUM_RISK_MODE riskMode = RISK_STATIC;    // Risk Mode
input double staticLotSize   = 0.01;            // Static Lot Size
input double accountPerLot   = 500.0;           // 💰 Account $ per 0.01 lot (Money-based)
input double riskPercent     = 2.0;             // Risk Percent (for % mode)
input bool   useMartingale   = false;           // 🔥 Use Martingale After Loss
input double martingaleMult  = 1.5;             // Martingale Multiplier
input int    martingaleMax   = 3;               // Max Martingale Levels

sinput group "=== DCA SETTINGS ==="
input bool   useDCA          = false;           // 📊 Use DCA (EA#1 & EA#2 only)
input bool   dcaOnlyInTrend  = true;            // 🎯 DCA Only in Trend
input int    trendMAPeriod   = 50;              // Trend MA Period
input double trendMinPips    = 20.0;            // Min Trend Strength (Pips)
input double dcaStepPips     = 30.0;            // DCA Step (Pips)
input double dcaLotMultiplier = 1.5;            // DCA Lot Multiplier
input int    dcaMaxLevels    = 5;               // Max DCA Levels
input bool   dcaCloseAll     = true;            // Close All on Any TP Hit

sinput group "=== TRADE MANAGEMENT ==="
input int    MagicEA1        = 111111;          // Magic Number EA#1
input int    MagicEA2        = 222222;          // Magic Number EA#2
input int    MagicEA3        = 333333;          // Magic Number EA#3
input int    maxTradesPerEA  = 1;               // Max Simultaneous Trades per EA
input string tradeComment    = "NB_EA";         // Trade Comment

sinput group "=== MULTI-TIMEFRAME FILTER ==="
input bool   useMTFConfirm   = true;            // 🎯 Use Higher Timeframe Confirmation
input ENUM_TIMEFRAMES higherTF = PERIOD_H4;     // Higher Timeframe
input int    htfMAPeriod     = 200;             // HTF Trend MA Period
input bool   strictHTF       = true;            // Strict HTF (price must be on correct side)

sinput group "=== SESSION FILTER ==="
input bool   useSessionFilter = true;           // ⏰ Use Session Filter
input bool   tradeAsian      = false;           // Trade Asian Session (00:00-08:00 GMT)
input bool   tradeLondon     = true;            // Trade London Session (08:00-16:00 GMT)
input bool   tradeNewYork    = true;            // Trade New York Session (13:00-22:00 GMT)

sinput group "=== DAILY LIMITS ==="
input bool   useDailyLimits  = true;            // 💰 Use Daily Limits
input double maxDailyLossPct = 5.0;             // Max Daily Loss (%)
input double maxDailyProfitPct = 10.0;          // Max Daily Profit (%) - Stop Trading
input bool   closeOnMaxProfit = false;          // Close All Positions on Max Profit

sinput group "=== GRID EXPANSION (EA#1 & EA#2) ==="
input bool   useGridExpansion = false;          // 🔲 Enable Grid Expansion for EA#1 & EA#2
input double gridStepPips    = 20.0;            // Grid Step Distance (Pips)
input int    gridMaxLevels   = 5;               // Max Grid Levels (per EA)
input bool   gridUseSameLot  = false;           // Use Same Lot Size for All Grid Levels
input double gridLotMultiplier = 1.0;           // Grid Lot Multiplier (if not same lot)
input bool   gridIndependentTP = true;          // Each Grid Level Has Independent TP
input double gridMaxRangePips = 100.0;          // Max Grid Range (Pips) - Stop if exceeded

sinput group "=== GRID TRADING (EA#4) - SIDEWAY MARKET ==="
input bool   gridAutoDetect  = true;            // 🎯 Auto-Detect Sideway Market
input double adxThreshold    = 25.0;            // ADX Threshold (< value = sideway)
input int    adxPeriod       = 14;              // ADX Period
input double bbWidthMin      = 0.001;           // Min BB Width for Sideway (normalized)
input double bbWidthMax      = 0.005;           // Max BB Width for Sideway
input int    gridRangeBars   = 50;              // Grid Range Detection Bars
input double ea4GridStepPips = 15.0;            // EA#4 Grid Step (Pips)
input double ea4GridLotSize  = 0.01;            // EA#4 Grid Lot Size (fixed)
input int    ea4GridMaxLevels = 10;             // EA#4 Max Grid Levels (Buy + Sell)
input double ea4GridTPPips   = 30.0;            // EA#4 Grid TP (Pips)
input double ea4GridSLPips   = 100.0;           // EA#4 Grid SL (Pips) - Hedging protection
input bool   ea4GridPartialClose = true;        // EA#4 Partial Close on TP Hit
input double ea4GridPartialPct = 50.0;          // EA#4 Partial Close % on First TP
input int    MagicEA4        = 444444;          // Magic Number EA#4 (Grid)

sinput group "=== LINEAR REGRESSION ==="
input bool   useLinearRegression = true;        // 📈 Use Linear Regression Filter
input int    lrPeriod        = 50;              // Linear Regression Period
input double lrDeviation     = 2.0;             // LR Channel Deviation (Std Dev)
input bool   lrEntryFilter   = true;            // Only Enter When Price Near LR Line
input double lrEntryMaxDist  = 15.0;            // Max Distance from LR Line (Pips) for Entry
input bool   lrTrendConfirm  = true;            // Confirm Trend with LR Slope
input double lrMinSlope      = 0.0001;          // Min LR Slope for Trend (0 = any slope)

sinput group "=== MULTI-TIMEFRAME REVERSAL DETECTION (EA#4) ==="
input bool   useMTFReversal  = true;            // 🎯 Use MTF Reversal Signals for EA#4
input ENUM_TIMEFRAMES mtfTF1 = PERIOD_M15;      // MTF 1: Short-term (M15)
input ENUM_TIMEFRAMES mtfTF2 = PERIOD_H1;       // MTF 2: Medium-term (H1)  
input ENUM_TIMEFRAMES mtfTF3 = PERIOD_H4;       // MTF 3: Long-term (H4)
input int    rsiPeriod       = 14;              // RSI Period
input double rsiOverbought   = 70.0;            // RSI Overbought Level
input double rsiOversold     = 30.0;            // RSI Oversold Level
input int    minReversalScore = 60;             // Min Reversal Score (0-100) to Enter Grid

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

int handleBB;
int handleSTO;
int handleMACD;
int handleATR;
int handleTrendMA;
int handleHTFMA;
int handleADX;
int handleRSI_TF1, handleRSI_TF2, handleRSI_TF3;
int handleSTO_TF1, handleSTO_TF2, handleSTO_TF3;
int handleMACD_TF1, handleMACD_TF2, handleMACD_TF3;

double bbUpper[], bbLower[], bbBasis[];
double stoKArr[], stoDArr[];
double macdMainArr[], macdSignalArr[];
double atrArr[];
double trendMAArr[];
double htfMAArr[];
double adxArr[], adxPlusArr[], adxMinusArr[];

// Multi-timeframe arrays
double rsiTF1[], rsiTF2[], rsiTF3[];
double stoTF1_K[], stoTF1_D[], stoTF2_K[], stoTF2_D[], stoTF3_K[], stoTF3_D[];
double macdTF1[], macdTF2[], macdTF3[];

double pipSize;
int digits;

// Linear Regression values
double lrMiddle[];      // Linear Regression middle line
double lrUpper[];       // Upper channel (LR + deviation)
double lrLower[];       // Lower channel (LR - deviation)
double lrSlope = 0;     // Current slope of regression
double lrR2 = 0;        // R-squared (correlation coefficient)

// Sixths levels
double goldTop, goldBottom;
double greenTop, greenBottom;
double median;

// RWB value
double rwbValue;

// Divergence detection
bool bullishDiv, bearishDiv;

// Martingale tracking
int consecutiveLosses = 0;
double currentMartingaleLot = 0;

// Support/Resistance levels
double supportLevels[];
double resistanceLevels[];
int supportCount = 0;
int resistanceCount = 0;

// DCA/Grid Expansion tracking (unified for EA#1, EA#2, and old DCA)
struct GridPosition
{
    ulong ticket;
    int magic;
    int level;              // Grid level (0 = first trade, 1+ = grid expansion)
    double openPrice;
    double lotSize;
    datetime openTime;
    bool hasIndependentTP;  // If true, each grid has own TP; if false, close all together
};

GridPosition gridPositions[];
int gridPositionCount = 0;

// Daily limits tracking
double dailyStartBalance = 0;
double dailyProfit = 0;
double dailyLoss = 0;
datetime lastDailyReset = 0;
bool dailyLimitReached = false;

// Grid trading state
struct GridLevel
{
    ulong ticket;
    double price;
    int type;              // 0 = BUY, 1 = SELL
    double lotSize;
    bool isActive;
    datetime openTime;
};

GridLevel gridLevels[];
int gridLevelCount = 0;
double gridRangeTop = 0;
double gridRangeBottom = 0;
bool gridActive = false;
datetime lastGridCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("🚀 Nanningbob EA Starting...");
    Print("========================================");
    
    // Calculate pip size
    pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    if(digits == 3 || digits == 5)
        pipSize *= 10;
    
    // Initialize indicators
    handleBB = iBands(_Symbol, PERIOD_CURRENT, bbLength, bbShift, bbStdDev, PRICE_CLOSE);
    handleSTO = iStochastic(_Symbol, PERIOD_CURRENT, stoKLength, stoSmoothD, stoSmoothK, MODE_SMA, STO_LOWHIGH);
    handleMACD = iMACD(_Symbol, PERIOD_CURRENT, macdFast, macdSlow, macdSignalLen, PRICE_CLOSE);
    handleATR = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
    handleTrendMA = iMA(_Symbol, PERIOD_CURRENT, trendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    handleHTFMA = iMA(_Symbol, higherTF, htfMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    
    // Grid indicators
    if(enableEA4)
    {
        handleADX = iADX(_Symbol, PERIOD_CURRENT, adxPeriod);
        
        // Multi-timeframe RSI
        handleRSI_TF1 = iRSI(_Symbol, mtfTF1, rsiPeriod, PRICE_CLOSE);
        handleRSI_TF2 = iRSI(_Symbol, mtfTF2, rsiPeriod, PRICE_CLOSE);
        handleRSI_TF3 = iRSI(_Symbol, mtfTF3, rsiPeriod, PRICE_CLOSE);
        
        // Multi-timeframe Stochastic
        handleSTO_TF1 = iStochastic(_Symbol, mtfTF1, stoKLength, stoSmoothD, stoSmoothK, MODE_SMA, STO_LOWHIGH);
        handleSTO_TF2 = iStochastic(_Symbol, mtfTF2, stoKLength, stoSmoothD, stoSmoothK, MODE_SMA, STO_LOWHIGH);
        handleSTO_TF3 = iStochastic(_Symbol, mtfTF3, stoKLength, stoSmoothD, stoSmoothK, MODE_SMA, STO_LOWHIGH);
        
        // Multi-timeframe MACD
        handleMACD_TF1 = iMACD(_Symbol, mtfTF1, macdFast, macdSlow, macdSignalLen, PRICE_CLOSE);
        handleMACD_TF2 = iMACD(_Symbol, mtfTF2, macdFast, macdSlow, macdSignalLen, PRICE_CLOSE);
        handleMACD_TF3 = iMACD(_Symbol, mtfTF3, macdFast, macdSlow, macdSignalLen, PRICE_CLOSE);
    }
    
    if(handleBB == INVALID_HANDLE || handleSTO == INVALID_HANDLE || handleMACD == INVALID_HANDLE || 
       handleATR == INVALID_HANDLE || handleTrendMA == INVALID_HANDLE || handleHTFMA == INVALID_HANDLE)
    {
        Print("❌ Failed to create indicators");
        return INIT_FAILED;
    }
    
    if(enableEA4 && (handleADX == INVALID_HANDLE || 
       handleRSI_TF1 == INVALID_HANDLE || handleRSI_TF2 == INVALID_HANDLE || handleRSI_TF3 == INVALID_HANDLE))
    {
        Print("❌ Failed to create Grid indicators");
        return INIT_FAILED;
    }
    
    // Initialize arrays
    ArraySetAsSeries(bbUpper, true);
    ArraySetAsSeries(bbLower, true);
    ArraySetAsSeries(bbBasis, true);
    ArraySetAsSeries(stoKArr, true);
    ArraySetAsSeries(stoDArr, true);
    ArraySetAsSeries(macdMainArr, true);
    ArraySetAsSeries(macdSignalArr, true);
    ArraySetAsSeries(atrArr, true);
    ArraySetAsSeries(trendMAArr, true);
    ArraySetAsSeries(htfMAArr, true);
    
    if(enableEA4)
    {
        ArraySetAsSeries(adxArr, true);
        ArraySetAsSeries(adxPlusArr, true);
        ArraySetAsSeries(adxMinusArr, true);
        ArraySetAsSeries(rsiTF1, true);
        ArraySetAsSeries(rsiTF2, true);
        ArraySetAsSeries(rsiTF3, true);
        ArraySetAsSeries(stoTF1_K, true);
        ArraySetAsSeries(stoTF1_D, true);
        ArraySetAsSeries(stoTF2_K, true);
        ArraySetAsSeries(stoTF2_D, true);
        ArraySetAsSeries(stoTF3_K, true);
        ArraySetAsSeries(stoTF3_D, true);
        ArraySetAsSeries(macdTF1, true);
        ArraySetAsSeries(macdTF2, true);
        ArraySetAsSeries(macdTF3, true);
    }
    
    // Initialize daily tracking
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    lastDailyReset = TimeCurrent();
    dailyLimitReached = false;
    
    PrintConfiguration();
    
    Print("✅ Nanningbob EA Initialized");
    Print("========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("========================================");
    Print("👋 Nanningbob EA Stopping...");
    
    if(handleBB != INVALID_HANDLE) IndicatorRelease(handleBB);
    if(handleSTO != INVALID_HANDLE) IndicatorRelease(handleSTO);
    if(handleMACD != INVALID_HANDLE) IndicatorRelease(handleMACD);
    if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
    if(handleTrendMA != INVALID_HANDLE) IndicatorRelease(handleTrendMA);
    if(handleHTFMA != INVALID_HANDLE) IndicatorRelease(handleHTFMA);
    
    if(enableEA4)
    {
        if(handleADX != INVALID_HANDLE) IndicatorRelease(handleADX);
        if(handleRSI_TF1 != INVALID_HANDLE) IndicatorRelease(handleRSI_TF1);
        if(handleRSI_TF2 != INVALID_HANDLE) IndicatorRelease(handleRSI_TF2);
        if(handleRSI_TF3 != INVALID_HANDLE) IndicatorRelease(handleRSI_TF3);
        if(handleSTO_TF1 != INVALID_HANDLE) IndicatorRelease(handleSTO_TF1);
        if(handleSTO_TF2 != INVALID_HANDLE) IndicatorRelease(handleSTO_TF2);
        if(handleSTO_TF3 != INVALID_HANDLE) IndicatorRelease(handleSTO_TF3);
        if(handleMACD_TF1 != INVALID_HANDLE) IndicatorRelease(handleMACD_TF1);
        if(handleMACD_TF2 != INVALID_HANDLE) IndicatorRelease(handleMACD_TF2);
        if(handleMACD_TF3 != INVALID_HANDLE) IndicatorRelease(handleMACD_TF3);
    }
    
    Print("✅ EA Stopped");
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check daily limits reset
    CheckDailyReset();
    
    // Check if daily limit reached
    if(useDailyLimits && dailyLimitReached)
    {
        return; // Stop trading for today
    }
    
    // Update indicators
    if(!UpdateIndicators()) return;
    
    // Calculate Linear Regression
    if(useLinearRegression)
        CalculateLinearRegression();
    
    // Calculate Sixths levels
    CalculateSixths();
    
    // Calculate RWB value
    CalculateRWB();
    
    // Detect divergence
    if(useDivergence)
        DetectDivergence();
    
    // Calculate S/R levels if needed
    if(tpMode == TP_SUPPORT_RESISTANCE)
        CalculateSupportResistance();
    
    // Update trailing stops and breakeven
    if(useTrailing || useBreakeven)
        UpdateAllTrailingStops();
    
    // Check Grid Expansion opportunities (EA#1 & EA#2)
    if(useGridExpansion)
        CheckGridExpansionOpportunities();
    
    // Check for new bar
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if(currentBar != lastBar)
    {
        lastBar = currentBar;
        
        // Check session filter
        if(useSessionFilter && !IsValidSession())
        {
            return; // Not valid trading session
        }
        
        // Check signals on new bar
        if(enableEA1) CheckEA1Signals();
        if(enableEA2) CheckEA2Signals();
        if(enableEA3) CheckEA3Signals();
        if(enableEA4) CheckEA4GridSignals(); // Grid trading for sideway markets
    }
}

//+------------------------------------------------------------------+
//| Update Indicators                                                 |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    // Copy BB data
    if(CopyBuffer(handleBB, 0, 0, 3, bbBasis) < 3) return false;
    if(CopyBuffer(handleBB, 1, 0, 3, bbUpper) < 3) return false;
    if(CopyBuffer(handleBB, 2, 0, 3, bbLower) < 3) return false;
    
    // Copy Stochastic data
    if(CopyBuffer(handleSTO, 0, 0, divLookback + 1, stoKArr) < divLookback + 1) return false;
    if(CopyBuffer(handleSTO, 1, 0, divLookback + 1, stoDArr) < divLookback + 1) return false;
    
    // Copy MACD data
    if(CopyBuffer(handleMACD, 0, 0, divLookback + 1, macdMainArr) < divLookback + 1) return false;
    if(CopyBuffer(handleMACD, 1, 0, divLookback + 1, macdSignalArr) < divLookback + 1) return false;
    
    // Copy ATR data
    if(slMode == SL_ATR)
    {
        if(CopyBuffer(handleATR, 0, 0, 3, atrArr) < 3) return false;
    }
    
    // Copy Trend MA data
    if(useDCA && dcaOnlyInTrend)
    {
        if(CopyBuffer(handleTrendMA, 0, 0, 3, trendMAArr) < 3) return false;
    }
    
    // Copy HTF MA data
    if(useMTFConfirm)
    {
        if(CopyBuffer(handleHTFMA, 0, 0, 2, htfMAArr) < 2) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Sixths Levels                                           |
//+------------------------------------------------------------------+
void CalculateSixths()
{
    goldTop = iHigh(_Symbol, sixthsTimeframe, iHighest(_Symbol, sixthsTimeframe, MODE_HIGH, sixthsBars, 0));
    goldBottom = iLow(_Symbol, sixthsTimeframe, iLowest(_Symbol, sixthsTimeframe, MODE_LOW, sixthsBars, 0));
    
    double range = goldTop - goldBottom;
    median = (goldTop + goldBottom) / 2.0;
    double sixth = range / 6.0;
    
    greenTop = median + sixth;
    greenBottom = median - sixth;
}

//+------------------------------------------------------------------+
//| Calculate RWB Value                                               |
//+------------------------------------------------------------------+
void CalculateRWB()
{
    // Stochastic component
    double stoValue = (stoKArr[0] + stoDArr[0]) / 2.0;
    
    // MACD component (normalized to 0-100)
    double macdValue = macdMainArr[0] - macdSignalArr[0];
    
    // Find MACD min/max for normalization
    double macdMin = macdValue;
    double macdMax = macdValue;
    
    for(int i = 1; i < MathMin(50, divLookback); i++)
    {
        double val = macdMainArr[i] - macdSignalArr[i];
        macdMin = MathMin(macdMin, val);
        macdMax = MathMax(macdMax, val);
    }
    
    double macdNormalized = 100.0 * (macdValue - macdMin) / (macdMax - macdMin + 0.0000001);
    
    // RWB = average of Sto and normalized MACD
    rwbValue = (stoValue + macdNormalized) / 2.0;
}

//+------------------------------------------------------------------+
//| Calculate Linear Regression Channel                               |
//+------------------------------------------------------------------+
void CalculateLinearRegression()
{
    if(!useLinearRegression) return;
    
    ArrayResize(lrMiddle, lrPeriod);
    ArrayResize(lrUpper, lrPeriod);
    ArrayResize(lrLower, lrPeriod);
    
    // Get price data
    double prices[];
    ArrayResize(prices, lrPeriod);
    ArraySetAsSeries(prices, true);
    
    for(int i = 0; i < lrPeriod; i++)
    {
        prices[i] = iClose(_Symbol, PERIOD_CURRENT, i);
    }
    
    // Calculate Linear Regression using Least Squares Method
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for(int i = 0; i < lrPeriod; i++)
    {
        double x = i;
        double y = prices[i];
        
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumX2 += x * x;
    }
    
    // Calculate slope (m) and intercept (b)
    // y = mx + b
    double n = lrPeriod;
    double denominator = (n * sumX2 - sumX * sumX);
    
    if(denominator == 0) denominator = 0.0001; // Avoid division by zero
    
    double slope = (n * sumXY - sumX * sumY) / denominator;
    double intercept = (sumY - slope * sumX) / n;
    
    lrSlope = slope; // Store slope for trend detection
    
    // Calculate regression line values and standard deviation
    double sumSquaredResiduals = 0;
    
    for(int i = 0; i < lrPeriod; i++)
    {
        double x = i;
        lrMiddle[i] = slope * x + intercept;
        
        double residual = prices[i] - lrMiddle[i];
        sumSquaredResiduals += residual * residual;
    }
    
    // Standard deviation of residuals
    double stdDev = MathSqrt(sumSquaredResiduals / n);
    
    // Calculate R-squared (coefficient of determination)
    double meanY = sumY / n;
    double totalSumSquares = 0;
    
    for(int i = 0; i < lrPeriod; i++)
    {
        totalSumSquares += MathPow(prices[i] - meanY, 2);
    }
    
    lrR2 = 1.0 - (sumSquaredResiduals / (totalSumSquares + 0.0001));
    
    // Create channel with deviation
    for(int i = 0; i < lrPeriod; i++)
    {
        lrUpper[i] = lrMiddle[i] + (lrDeviation * stdDev);
        lrLower[i] = lrMiddle[i] - (lrDeviation * stdDev);
    }
    
    // Predict next value
    double nextX = 0; // Next bar (most recent in series)
    double predictedPrice = slope * nextX + intercept;
    
    // Debug output (optional)
    if(false) // Set to true for debugging
    {
        PrintFormat("📈 LR: Slope=%.5f, R²=%.3f, Predicted=%.5f, Current=%.5f", 
                   lrSlope, lrR2, predictedPrice, prices[0]);
    }
}

//+------------------------------------------------------------------+
//| Check if Price is Near Linear Regression Line                     |
//+------------------------------------------------------------------+
bool IsPriceNearLR()
{
    if(!useLinearRegression || !lrEntryFilter) return true;
    
    if(ArraySize(lrMiddle) < 1) return true;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double lrValue = lrMiddle[0]; // Most recent LR value
    
    double distancePips = MathAbs(currentPrice - lrValue) / pipSize;
    
    bool isNear = (distancePips <= lrEntryMaxDist);
    
    if(!isNear)
    {
        PrintFormat("⏳ Price too far from LR (%.1f pips > %.1f max) - waiting...", 
                   distancePips, lrEntryMaxDist);
    }
    
    return isNear;
}

//+------------------------------------------------------------------+
//| Check Linear Regression Trend Direction                           |
//+------------------------------------------------------------------+
bool IsLRTrendBullish()
{
    if(!useLinearRegression || !lrTrendConfirm) return true;
    
    // Positive slope = uptrend
    bool bullish = (lrSlope > lrMinSlope);
    
    if(!bullish)
    {
        PrintFormat("⏳ LR Slope (%.5f) not bullish (min: %.5f)", lrSlope, lrMinSlope);
    }
    
    return bullish;
}

bool IsLRTrendBearish()
{
    if(!useLinearRegression || !lrTrendConfirm) return true;
    
    // Negative slope = downtrend
    bool bearish = (lrSlope < -lrMinSlope);
    
    if(!bearish)
    {
        PrintFormat("⏳ LR Slope (%.5f) not bearish (min: -%.5f)", lrSlope, lrMinSlope);
    }
    
    return bearish;
}

//+------------------------------------------------------------------+
//| Get Linear Regression Signal for Mean Reversion (EA#1 & EA#2)     |
//+------------------------------------------------------------------+
int GetLRMeanReversionSignal()
{
    if(!useLinearRegression) return 0;
    if(ArraySize(lrMiddle) < 1 || ArraySize(lrUpper) < 1 || ArraySize(lrLower) < 1) return 0;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double lrMid = lrMiddle[0];
    double lrUp = lrUpper[0];
    double lrLow = lrLower[0];
    
    // MEAN REVERSION: Mua khi giá XA DƯỚI (oversold), Bán khi giá XA TRÊN (overbought)
    
    // Price near/below lower channel = oversold = BUY opportunity (mean reversion)
    if(currentPrice <= lrLow)
    {
        PrintFormat("📈 LR Mean Reversion: OVERSOLD (Price %.5f <= Lower %.5f) - BUY opportunity", 
                   currentPrice, lrLow);
        return 1; // BUY
    }
    
    // Price near/above upper channel = overbought = SELL opportunity (mean reversion)
    if(currentPrice >= lrUp)
    {
        PrintFormat("📉 LR Mean Reversion: OVERBOUGHT (Price %.5f >= Upper %.5f) - SELL opportunity", 
                   currentPrice, lrUp);
        return -1; // SELL
    }
    
    // Price near middle = no clear signal
    return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Get Linear Regression Trend Signal (for EA#3 or trend following)  |
//+------------------------------------------------------------------+
int GetLRTrendSignal()
{
    if(!useLinearRegression) return 0;
    if(ArraySize(lrMiddle) < 1) return 0;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double lrMid = lrMiddle[0];
    
    // TREND FOLLOWING: Mua khi giá TRÊN LR (uptrend), Bán khi giá DƯỚI LR (downtrend)
    
    if(currentPrice > lrMid && lrSlope > lrMinSlope)
    {
        // Price above LR + positive slope = uptrend = BUY
        return 1;
    }
    
    if(currentPrice < lrMid && lrSlope < -lrMinSlope)
    {
        // Price below LR + negative slope = downtrend = SELL
        return -1;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Detect Divergence                                                 |
//+------------------------------------------------------------------+
void DetectDivergence()
{
    bullishDiv = false;
    bearishDiv = false;
    
    // Find price high/low
    int highIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, divLookback, 1);
    int lowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, divLookback, 1);
    
    double priceHigh = iHigh(_Symbol, PERIOD_CURRENT, highIdx);
    double priceLow = iLow(_Symbol, PERIOD_CURRENT, lowIdx);
    
    // Find RWB high/low
    double rwbHigh = rwbValue;
    double rwbLow = rwbValue;
    
    for(int i = 1; i <= divLookback; i++)
    {
        double sto = (stoKArr[i] + stoDArr[i]) / 2.0;
        double macd = macdMainArr[i] - macdSignalArr[i];
        
        // Simple RWB calculation for past bars
        double rwb = sto; // Simplified
        
        rwbHigh = MathMax(rwbHigh, rwb);
        rwbLow = MathMin(rwbLow, rwb);
    }
    
    double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
    
    // Bullish divergence: price makes lower low, but RWB makes higher low
    if(currentLow < priceLow && rwbValue > rwbLow)
        bullishDiv = true;
    
    // Bearish divergence: price makes higher high, but RWB makes lower high
    if(currentHigh > priceHigh && rwbValue < rwbHigh)
        bearishDiv = true;
}

//+------------------------------------------------------------------+
//| Check EA#1 Signals (BB Bounce)                                    |
//+------------------------------------------------------------------+
void CheckEA1Signals()
{
    double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    // BUY: Cross above lower BB + below green bottom + RWB < 15
    bool buyCond = close1 <= bbLower[1] && close0 > bbLower[0] && 
                   close0 < greenBottom && rwbValue < 15;
    
    // SELL: Cross below upper BB + above green top + RWB > 85
    bool sellCond = close1 >= bbUpper[1] && close0 < bbUpper[0] && 
                    close0 > greenTop && rwbValue > 85;
    
    // Apply MTF filter
    if(useMTFConfirm)
    {
        if(buyCond && !IsHTFBullish()) buyCond = false;
        if(sellCond && !IsHTFBearish()) sellCond = false;
    }
    
    // Apply Linear Regression filters (MEAN REVERSION for EA#1)
    if(useLinearRegression)
    {
        int lrSignal = GetLRMeanReversionSignal();
        
        // EA#1 = Mean Reversion: Chỉ BUY khi giá oversold (xa dưới LR)
        if(buyCond && lrSignal != 1)
        {
            if(lrSignal == 0)
                PrintFormat("⏳ LR: Price not oversold yet - waiting for better BUY entry");
            else
                PrintFormat("❌ LR: Price overbought - blocking BUY signal");
            buyCond = false;
        }
        
        // EA#1 = Mean Reversion: Chỉ SELL khi giá overbought (xa trên LR)
        if(sellCond && lrSignal != -1)
        {
            if(lrSignal == 0)
                PrintFormat("⏳ LR: Price not overbought yet - waiting for better SELL entry");
            else
                PrintFormat("❌ LR: Price oversold - blocking SELL signal");
            sellCond = false;
        }
        
        // Bonus confirmation
        if(buyCond && lrSignal == 1)
        {
            PrintFormat("✅ LR confirms EA#1 BUY (price oversold from LR)");
        }
        if(sellCond && lrSignal == -1)
        {
            PrintFormat("✅ LR confirms EA#1 SELL (price overbought from LR)");
        }
    }
    
    if(buyCond)
    {
        if(CountOpenTrades(MagicEA1) < maxTradesPerEA || (useGridExpansion && CountGridLevels(MagicEA1) == 0))
        {
            PrintFormat("🔵 EA#1 BUY: Price=%.5f, Lower BB=%.5f, RWB=%.1f", 
                       close0, bbLower[0], rwbValue);
            OpenTrade(ORDER_TYPE_BUY, MagicEA1, "EA1_BUY", 0);
        }
    }
    
    if(sellCond)
    {
        if(CountOpenTrades(MagicEA1) < maxTradesPerEA || (useGridExpansion && CountGridLevels(MagicEA1) == 0))
        {
            PrintFormat("🔴 EA#1 SELL: Price=%.5f, Upper BB=%.5f, RWB=%.1f", 
                       close0, bbUpper[0], rwbValue);
            OpenTrade(ORDER_TYPE_SELL, MagicEA1, "EA1_SELL", 0);
        }
    }
}

//+------------------------------------------------------------------+
//| Check EA#2 Signals (Huggie Pattern)                               |
//+------------------------------------------------------------------+
void CheckEA2Signals()
{
    double ma1 = iClose(_Symbol, PERIOD_CURRENT, 0); // 1MA = close
    double ma1_prev = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    double separationPrice = huggieSepPips * pipSize;
    
    // BUY: 1MA was below lower BB by separation, now crosses back above
    bool ma1BelowLower = (ma1_prev < bbLower[1]) && ((bbLower[1] - ma1_prev) >= separationPrice);
    bool ma1CrossBack = ma1 > bbLower[0];
    bool buyCond = ma1BelowLower && ma1CrossBack && 
                   ma1 < greenBottom && rwbValue < 15;
    
    // SELL: 1MA was above upper BB by separation, now crosses back below
    bool ma1AboveUpper = (ma1_prev > bbUpper[1]) && ((ma1_prev - bbUpper[1]) >= separationPrice);
    bool ma1CrossBackSell = ma1 < bbUpper[0];
    bool sellCond = ma1AboveUpper && ma1CrossBackSell && 
                    ma1 > greenTop && rwbValue > 85;
    
    // Apply MTF filter
    if(useMTFConfirm)
    {
        if(buyCond && !IsHTFBullish()) buyCond = false;
        if(sellCond && !IsHTFBearish()) sellCond = false;
    }
    
    // Apply Linear Regression filters (MEAN REVERSION for EA#2)
    if(useLinearRegression)
    {
        int lrSignal = GetLRMeanReversionSignal();
        
        // EA#2 = Mean Reversion: Chỉ BUY khi giá oversold
        if(buyCond && lrSignal != 1)
        {
            PrintFormat("⏳ LR: Blocking EA#2 BUY - price not oversold (signal=%d)", lrSignal);
            buyCond = false;
        }
        
        // EA#2 = Mean Reversion: Chỉ SELL khi giá overbought
        if(sellCond && lrSignal != -1)
        {
            PrintFormat("⏳ LR: Blocking EA#2 SELL - price not overbought (signal=%d)", lrSignal);
            sellCond = false;
        }
        
        if(buyCond && lrSignal == 1)
        {
            PrintFormat("✅ LR confirms EA#2 BUY (mean reversion from oversold)");
        }
        if(sellCond && lrSignal == -1)
        {
            PrintFormat("✅ LR confirms EA#2 SELL (mean reversion from overbought)");
        }
    }
    
    if(buyCond)
    {
        if(CountOpenTrades(MagicEA2) < maxTradesPerEA || (useGridExpansion && CountGridLevels(MagicEA2) == 0))
        {
            PrintFormat("🟢 EA#2 BUY (Huggie): 1MA crossed back, RWB=%.1f", rwbValue);
            OpenTrade(ORDER_TYPE_BUY, MagicEA2, "EA2_BUY_Huggie", 0);
        }
    }
    
    if(sellCond)
    {
        if(CountOpenTrades(MagicEA2) < maxTradesPerEA || (useGridExpansion && CountGridLevels(MagicEA2) == 0))
        {
            PrintFormat("🟣 EA#2 SELL (Huggie): 1MA crossed back, RWB=%.1f", rwbValue);
            OpenTrade(ORDER_TYPE_SELL, MagicEA2, "EA2_SELL_Huggie", 0);
        }
    }
}

//+------------------------------------------------------------------+
//| Check EA#3 Signals (No Man's Land)                                |
//+------------------------------------------------------------------+
void CheckEA3Signals()
{
    double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
    double ma1 = close0;
    
    // No Man's Land check
    bool noMansLand = (close0 > greenBottom) && (close0 < greenTop);
    
    if(!noMansLand) return;
    
    double ea3SepPrice = ea3SepPips * pipSize;
    
    // Price near or crosses basis
    bool priceNearBasis = MathAbs(close0 - bbBasis[0]) <= ea3SepPrice;
    bool priceCrossBasis = (close1 <= bbBasis[1] && close0 > bbBasis[0]) || 
                           (close1 >= bbBasis[1] && close0 < bbBasis[0]);
    
    // 1MA near basis
    bool ma1NearBasis = MathAbs(ma1 - bbBasis[0]) <= ea3SepPrice;
    
    // BUY: Cross above basis or near basis + RWB < 15
    bool buyCond = noMansLand && (priceCrossBasis || priceNearBasis) && 
                   rwbValue < 15 && ma1NearBasis &&
                   (close0 > bbBasis[0] || close1 <= bbBasis[1]);
    
    // SELL: Cross below basis or near basis + RWB > 85
    bool sellCond = noMansLand && (priceCrossBasis || priceNearBasis) && 
                    rwbValue > 85 && ma1NearBasis &&
                    (close0 < bbBasis[0] || close1 >= bbBasis[1]);
    
    if(buyCond)
    {
        if(CountOpenTrades(MagicEA3) < maxTradesPerEA)
        {
            PrintFormat("🟠 EA#3 BUY (No Man's Land): Near Basis, RWB=%.1f", rwbValue);
            OpenTrade(ORDER_TYPE_BUY, MagicEA3, "EA3_BUY_NML", 0);
        }
    }
    
    if(sellCond)
    {
        if(CountOpenTrades(MagicEA3) < maxTradesPerEA)
        {
            PrintFormat("🔵 EA#3 SELL (No Man's Land): Near Basis, RWB=%.1f", rwbValue);
            OpenTrade(ORDER_TYPE_SELL, MagicEA3, "EA3_SELL_NML", 0);
        }
    }
}

//+------------------------------------------------------------------+
//| Open Trade                                                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, int magic, string comment, int gridLevel = 0)
{
    double lots = CalculateLotSize();
    
    // Apply Grid lot sizing
    if(gridLevel > 0 && useGridExpansion)
    {
        if(gridUseSameLot)
        {
            // Same lot size for all grid levels
            lots = lots;
        }
        else
        {
            // Multiply lot by gridLotMultiplier for each level
            lots = lots * MathPow(gridLotMultiplier, gridLevel);
            PrintFormat("📊 Grid Level %d: Lot multiplied to %.2f", gridLevel, lots);
        }
    }
    
    // Apply martingale if enabled
    if(useMartingale && consecutiveLosses > 0 && consecutiveLosses <= martingaleMax)
    {
        currentMartingaleLot = lots * MathPow(martingaleMult, consecutiveLosses);
        lots = currentMartingaleLot;
        PrintFormat("🔥 Martingale: Level %d, Lot %.2f", consecutiveLosses, lots);
    }
    
    // Normalize lot
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    lots = MathFloor(lots / lotStep) * lotStep;
    
    // Prepare order
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = type;
    request.price = (type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = magic;
    request.comment = tradeComment + "_" + comment;
    
    // Calculate TP/SL - each grid level gets independent TP based on tpMode
    request.tp = 0;
    request.sl = 0;
    
    if(useTP)
    {
        request.tp = CalculateTP(type, request.price);
    }
    
    if(slMode != SL_NONE)
    {
        request.sl = CalculateSL(type, request.price);
    }
    
    // Send order
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("✅ Trade Opened: %s %.2f lots @ %.5f [Magic: %d, Grid Lv: %d]", 
                       (type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                       lots, request.price, magic, gridLevel);
            
            // Add to Grid tracking if Grid Expansion is enabled for EA#1 or EA#2
            if(useGridExpansion && (magic == MagicEA1 || magic == MagicEA2))
            {
                AddGridPosition(result.order, magic, gridLevel, request.price, lots, gridIndependentTP);
            }
        }
        else
        {
            PrintFormat("❌ Order Failed: %d - %s", result.retcode, result.comment);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double lots = staticLotSize;
    
    switch(riskMode)
    {
        case RISK_STATIC:
            lots = staticLotSize;
            break;
            
        case RISK_MONEY:
        {
            // Money-based: 0.01 lot per X dollars
            // Example: If accountPerLot = 500, and balance = 2000
            // Then lots = (2000 / 500) * 0.01 = 0.04
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            lots = (balance / accountPerLot) * 0.01;
            break;
        }
        
        case RISK_PERCENT:
        {
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            double riskMoney = balance * riskPercent / 100.0;
            
            // Calculate based on SL distance
            double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double slPips = fixedSLPips > 0 ? fixedSLPips : 50; // Default 50 pips
            lots = riskMoney / (slPips * tickValue);
            break;
        }
    }
    
    return lots;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                             |
//+------------------------------------------------------------------+
double CalculateTP(ENUM_ORDER_TYPE type, double openPrice)
{
    double tp = 0;
    
    switch(tpMode)
    {
        case TP_FIXED_PIPS:
        {
            double tpDistance = fixedTPPips * pipSize;
            tp = (type == ORDER_TYPE_BUY) ? openPrice + tpDistance : openPrice - tpDistance;
            break;
        }
        
        case TP_BB_TARGET:
        {
            // Target opposite BB band
            tp = (type == ORDER_TYPE_BUY) ? bbUpper[0] : bbLower[0];
            break;
        }
        
        case TP_SIXTHS_TARGET:
        {
            // Target opposite sixths level
            tp = (type == ORDER_TYPE_BUY) ? greenTop : greenBottom;
            break;
        }
        
        case TP_SUPPORT_RESISTANCE:
        {
            // Target nearest S/R level
            double currentPrice = (type == ORDER_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            if(type == ORDER_TYPE_BUY)
            {
                // Find nearest resistance above current price
                double nearestR = 0;
                double minDistance = DBL_MAX;
                
                for(int i = 0; i < resistanceCount; i++)
                {
                    if(resistanceLevels[i] > currentPrice)
                    {
                        double dist = resistanceLevels[i] - currentPrice;
                        if(dist < minDistance)
                        {
                            minDistance = dist;
                            nearestR = resistanceLevels[i];
                        }
                    }
                }
                
                if(nearestR > 0)
                {
                    // Place TP slightly before resistance
                    double buffer = srBufferPips * pipSize;
                    tp = nearestR - buffer;
                }
                else
                {
                    // Fallback to fixed pips
                    tp = openPrice + (fixedTPPips * pipSize);
                }
            }
            else // SELL
            {
                // Find nearest support below current price
                double nearestS = 0;
                double minDistance = DBL_MAX;
                
                for(int i = 0; i < supportCount; i++)
                {
                    if(supportLevels[i] < currentPrice)
                    {
                        double dist = currentPrice - supportLevels[i];
                        if(dist < minDistance)
                        {
                            minDistance = dist;
                            nearestS = supportLevels[i];
                        }
                    }
                }
                
                if(nearestS > 0)
                {
                    // Place TP slightly before support
                    double buffer = srBufferPips * pipSize;
                    tp = nearestS + buffer;
                }
                else
                {
                    // Fallback to fixed pips
                    tp = openPrice - (fixedTPPips * pipSize);
                }
            }
            break;
        }
    }
    
    return NormalizeDouble(tp, digits);
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                               |
//+------------------------------------------------------------------+
double CalculateSL(ENUM_ORDER_TYPE type, double openPrice)
{
    double sl = 0;
    
    switch(slMode)
    {
        case SL_NONE:
            sl = 0;
            break;
            
        case SL_FIXED_PIPS:
        {
            double slDistance = fixedSLPips * pipSize;
            sl = (type == ORDER_TYPE_BUY) ? openPrice - slDistance : openPrice + slDistance;
            break;
        }
        
        case SL_BB_BAND:
        {
            // SL at opposite BB band + buffer
            double buffer = slBufferPips * pipSize;
            if(type == ORDER_TYPE_BUY)
                sl = bbLower[0] - buffer;
            else
                sl = bbUpper[0] + buffer;
            break;
        }
        
        case SL_SWING_POINT:
        {
            // SL at recent swing point + buffer
            double buffer = slBufferPips * pipSize;
            if(type == ORDER_TYPE_BUY)
            {
                // Find recent swing low
                double swingLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 1));
                sl = swingLow - buffer;
            }
            else
            {
                // Find recent swing high
                double swingHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1));
                sl = swingHigh + buffer;
            }
            break;
        }
        
        case SL_ATR:
        {
            // SL based on ATR
            double atr = atrArr[0];
            double slDistance = atr * atrMultiplier;
            sl = (type == ORDER_TYPE_BUY) ? openPrice - slDistance : openPrice + slDistance;
            break;
        }
    }
    
    return NormalizeDouble(sl, digits);
}

//+------------------------------------------------------------------+
//| Update Trailing Stops                                             |
//+------------------------------------------------------------------+
void UpdateAllTrailingStops()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        int magic = (int)PositionGetInteger(POSITION_MAGIC);
        if(magic != MagicEA1 && magic != MagicEA2 && magic != MagicEA3) continue;
        
        UpdateTrailingStop(ticket);
    }
}

//+------------------------------------------------------------------+
//| Update Trailing Stop for Single Position                          |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    double currentPrice = (type == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double profitPips = 0;
    if(type == POSITION_TYPE_BUY)
        profitPips = (currentPrice - openPrice) / pipSize;
    else
        profitPips = (openPrice - currentPrice) / pipSize;
    
    bool modified = false;
    double newSL = currentSL;
    
    // Check breakeven first
    if(useBreakeven && profitPips >= breakevenStart)
    {
        double bePrice = openPrice + (breakevenProfit * pipSize * (type == POSITION_TYPE_BUY ? 1 : -1));
        
        if(type == POSITION_TYPE_BUY)
        {
            if(currentSL < bePrice)
            {
                newSL = bePrice;
                modified = true;
                PrintFormat("🔒 Breakeven: #%I64u moved to %.5f (+%.1f pips)", ticket, newSL, breakevenProfit);
            }
        }
        else
        {
            if(currentSL == 0 || currentSL > bePrice)
            {
                newSL = bePrice;
                modified = true;
                PrintFormat("🔒 Breakeven: #%I64u moved to %.5f (+%.1f pips)", ticket, newSL, breakevenProfit);
            }
        }
    }
    
    // Then check trailing stop
    if(useTrailing && profitPips >= trailingStart)
    {
        if(type == POSITION_TYPE_BUY)
        {
            double trailSL = currentPrice - (trailingStep * pipSize);
            
            // Divergence-based Stop Loss Adjustment
            // Nếu có bearish divergence → Tighten SL (bảo vệ lợi nhuận)
            if(useDivergence && bearishDiv)
            {
                trailSL = currentPrice - (trailingStep * pipSize * 0.5); // Tighten 50%
                PrintFormat("⚠️ Bearish Divergence detected - Tightening BUY SL to %.5f", trailSL);
            }
            
            // Only move SL up
            if(trailSL > newSL && trailSL > openPrice)
            {
                newSL = trailSL;
                modified = true;
            }
        }
        else // SELL
        {
            double trailSL = currentPrice + (trailingStep * pipSize);
            
            // Divergence-based Stop Loss Adjustment
            // Nếu có bullish divergence → Tighten SL (bảo vệ lợi nhuận)
            if(useDivergence && bullishDiv)
            {
                trailSL = currentPrice + (trailingStep * pipSize * 0.5); // Tighten 50%
                PrintFormat("⚠️ Bullish Divergence detected - Tightening SELL SL to %.5f", trailSL);
            }
            
            // Only move SL down
            if((newSL == 0 || trailSL < newSL) && trailSL < openPrice)
            {
                newSL = trailSL;
                modified = true;
            }
        }
    }
    
    // Apply modification
    if(modified)
    {
        ModifyPosition(ticket, newSL, currentTP);
    }
}

//+------------------------------------------------------------------+
//| Modify Position                                                   |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = NormalizeDouble(sl, digits);
    request.tp = NormalizeDouble(tp, digits);
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("📊 Trailing Stop: #%I64u, New SL: %.5f", ticket, sl);
        }
    }
}

//+------------------------------------------------------------------+
//| Count Open Trades                                                 |
//+------------------------------------------------------------------+
int CountOpenTrades(int magic)
{
    int count = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
        
        count++;
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| On Trade Transaction (for martingale tracking)                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // Track closed positions for martingale
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(HistoryDealSelect(trans.deal))
        {
            long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
            
            if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
            {
                double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                int magic = (int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
                
                // Check if it's a close deal
                if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                {
                    if(magic == MagicEA1 || magic == MagicEA2 || magic == MagicEA3)
                    {
                        // Remove from Grid tracking
                        RemoveGridPosition(trans.position);
                        
                        // Update daily P/L
                        if(useDailyLimits)
                        {
                            if(profit > 0)
                                dailyProfit += profit;
                            else
                                dailyLoss += MathAbs(profit);
                            
                            CheckDailyLimits();
                        }
                        
                        // Grid Expansion: Close all positions if independentTP is false and one hits TP
                        if(useGridExpansion && !gridIndependentTP && profit > 0 && (magic == MagicEA1 || magic == MagicEA2))
                        {
                            if(CountGridLevels(magic) > 0)
                            {
                                PrintFormat("💰 TP Hit! Closing all grid positions (independentTP=false)");
                                CloseAllGridPositions(magic);
                            }
                        }
                        
                        if(profit > 0)
                        {
                            consecutiveLosses = 0;
                            currentMartingaleLot = 0;
                            PrintFormat("✅ WIN: Martingale reset");
                        }
                        else if(profit < 0)
                        {
                            if(useMartingale)
                            {
                                consecutiveLosses++;
                                if(consecutiveLosses > martingaleMax)
                                    consecutiveLosses = martingaleMax;
                                    
                                PrintFormat("❌ LOSS: Martingale level %d", consecutiveLosses);
                            }
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Print Configuration                                               |
//+------------------------------------------------------------------+
void PrintConfiguration()
{
    Print("\n📊 === NANNINGBOB EA CONFIGURATION ===");
    PrintFormat("Strategies: EA#1=%s, EA#2=%s, EA#3=%s", 
               enableEA1 ? "ON" : "OFF",
               enableEA2 ? "ON" : "OFF",
               enableEA3 ? "ON" : "OFF");
    
    Print("\n💰 === BOLLINGER BANDS ===");
    PrintFormat("Length: %d, StdDev: %.1f, MA Type: %d", bbLength, bbStdDev, bbMAType);
    
    Print("\n📊 === SIXTHS RANGE ===");
    PrintFormat("Timeframe: %s, Bars: %d", EnumToString(sixthsTimeframe), sixthsBars);
    
    Print("\n📈 === LINEAR REGRESSION ===");
    PrintFormat("Use LR: %s", useLinearRegression ? "YES" : "NO");
    if(useLinearRegression)
    {
        PrintFormat("Period: %d, Deviation: %.1f StdDev", lrPeriod, lrDeviation);
        PrintFormat("Strategy: MEAN REVERSION (EA#1/EA#2: BUY oversold, SELL overbought)");
        PrintFormat("Entry Filter: %s (Max Dist: %.1f pips)", 
                   lrEntryFilter ? "YES" : "NO", lrEntryMaxDist);
        PrintFormat("Trend Confirm: %s (Min Slope: %.5f)", 
                   lrTrendConfirm ? "YES" : "NO", lrMinSlope);
    }
    
    Print("\n🎯 === TAKE PROFIT ===");
    PrintFormat("Use TP: %s", useTP ? "YES" : "NO");
    if(useTP)
    {
        string tpModeStr = (tpMode == TP_FIXED_PIPS) ? "Fixed Pips" :
                          (tpMode == TP_BB_TARGET) ? "BB Target" :
                          (tpMode == TP_SIXTHS_TARGET) ? "Sixths Target" : "Support/Resistance";
        PrintFormat("TP Mode: %s, Fixed TP: %.1f pips", tpModeStr, fixedTPPips);
        
        if(tpMode == TP_SUPPORT_RESISTANCE)
            PrintFormat("S/R: Lookback %d bars, Min Touches %d, Buffer %.1f pips", 
                       srLookback, srTouchMin, srBufferPips);
        
        PrintFormat("Trailing: %s (Start: %.1f, Step: %.1f)", 
                   useTrailing ? "YES" : "NO", trailingStart, trailingStep);
    }
    
    Print("\n🛑 === STOP LOSS ===");
    string slModeStr = (slMode == SL_NONE) ? "None" :
                      (slMode == SL_FIXED_PIPS) ? "Fixed Pips" :
                      (slMode == SL_BB_BAND) ? "BB Band" :
                      (slMode == SL_SWING_POINT) ? "Swing Point" : "ATR";
    PrintFormat("SL Mode: %s", slModeStr);
    if(slMode == SL_FIXED_PIPS)
        PrintFormat("Fixed SL: %.1f pips", fixedSLPips);
    else if(slMode == SL_BB_BAND || slMode == SL_SWING_POINT)
        PrintFormat("SL Buffer: %.1f pips", slBufferPips);
    else if(slMode == SL_ATR)
        PrintFormat("ATR Multiplier: %.1fx, Period: %d", atrMultiplier, atrPeriod);
    
    if(useBreakeven)
        PrintFormat("Breakeven: Start %.1f pips, Profit %.1f pips", breakevenStart, breakevenProfit);
    
    Print("\n� === DIVERGENCE ===");
    PrintFormat("Use Divergence: %s (for STOP LOSS MANAGEMENT only)", useDivergence ? "YES" : "NO");
    if(useDivergence)
        PrintFormat("Lookback: %d bars (Tightens trailing SL by 50%% when detected)", divLookback);
    
    Print("\n�📈 === RISK MANAGEMENT ===");
    string riskModeStr = (riskMode == RISK_STATIC) ? "Static" : 
                         (riskMode == RISK_MONEY) ? "Money-based" : "Percent";
    PrintFormat("Risk Mode: %s", riskModeStr);
    
    if(riskMode == RISK_STATIC)
        PrintFormat("Static Lot: %.2f", staticLotSize);
    else if(riskMode == RISK_MONEY)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double calculatedLot = (balance / accountPerLot) * 0.01;
        PrintFormat("Account: $%.2f, Per Lot: $%.0f, Calculated Lot: %.2f", 
                   balance, accountPerLot, calculatedLot);
    }
    else if(riskMode == RISK_PERCENT)
        PrintFormat("Risk Percent: %.1f%%", riskPercent);
    
    PrintFormat("Martingale: %s (Mult: %.1fx, Max: %d)", 
               useMartingale ? "YES" : "NO", martingaleMult, martingaleMax);
    
    Print("\n� === GRID EXPANSION (EA#1 & EA#2) ===");
    PrintFormat("Use Grid Expansion: %s", useGridExpansion ? "YES" : "NO");
    if(useGridExpansion)
    {
        PrintFormat("Grid Step: %.1f pips, Max Levels: %d, Max Range: %.1f pips", 
                   gridStepPips, gridMaxLevels, gridMaxRangePips);
        
        if(gridUseSameLot)
            PrintFormat("Lot Sizing: Same lot (%.2f) for all grid levels", staticLotSize);
        else
            PrintFormat("Lot Sizing: Multiplier %.1fx per level", gridLotMultiplier);
        
        PrintFormat("Independent TP: %s (each grid has own TP based on TP Mode)", 
                   gridIndependentTP ? "YES" : "NO - close all on any TP");
    }
    
    Print("\n🎯 === MULTI-TIMEFRAME FILTER ===");
    PrintFormat("Use MTF Confirm: %s", useMTFConfirm ? "YES" : "NO");
    if(useMTFConfirm)
    {
        PrintFormat("Higher TF: %s, MA Period: %d, Strict: %s", 
                   EnumToString(higherTF), htfMAPeriod, strictHTF ? "YES" : "NO");
    }
    
    Print("\n⏰ === SESSION FILTER ===");
    PrintFormat("Use Session Filter: %s", useSessionFilter ? "YES" : "NO");
    if(useSessionFilter)
    {
        PrintFormat("Asian: %s, London: %s, NY: %s", 
                   tradeAsian ? "✅" : "❌",
                   tradeLondon ? "✅" : "❌",
                   tradeNewYork ? "✅" : "❌");
    }
    
    Print("\n💰 === DAILY LIMITS ===");
    PrintFormat("Use Daily Limits: %s", useDailyLimits ? "YES" : "NO");
    if(useDailyLimits)
    {
        PrintFormat("Max Loss: %.1f%%, Max Profit: %.1f%%, Close on Max: %s", 
                   maxDailyLossPct, maxDailyProfitPct, closeOnMaxProfit ? "YES" : "NO");
    }
    
    Print("\n🔲 === GRID TRADING (EA#4) - SIDEWAY MARKET ===");
    PrintFormat("Enable EA#4: %s", enableEA4 ? "YES" : "NO");
    if(enableEA4)
    {
        PrintFormat("Auto-Detect Sideway: %s", gridAutoDetect ? "YES" : "NO");
        if(gridAutoDetect)
        {
            PrintFormat("ADX Threshold: < %.1f, BB Width: %.4f - %.4f", 
                       adxThreshold, bbWidthMin, bbWidthMax);
            PrintFormat("Range Detection: %d bars", gridRangeBars);
        }
        
        PrintFormat("Grid Step: %.1f pips, Lot Size: %.2f, Max Levels: %d", 
                   gridStepPips, ea4GridLotSize, gridMaxLevels);
        PrintFormat("TP: %.1f pips, SL: %.1f pips (hedge protection)", ea4GridTPPips, ea4GridSLPips);
        PrintFormat("Partial Close: %s (%.0f%% on first TP)", 
                   ea4GridPartialClose ? "YES" : "NO", ea4GridPartialPct);
        
        Print("\n🎯 === MTF REVERSAL DETECTION ===");
        PrintFormat("Use MTF Reversal: %s", useMTFReversal ? "YES" : "NO");
        if(useMTFReversal)
        {
            PrintFormat("Timeframes: %s, %s, %s", 
                       EnumToString(mtfTF1), EnumToString(mtfTF2), EnumToString(mtfTF3));
            PrintFormat("RSI Period: %d, Overbought: %.0f, Oversold: %.0f", 
                       rsiPeriod, rsiOverbought, rsiOversold);
            PrintFormat("Min Reversal Score: %d (0-100)", minReversalScore);
        }
    }
}

//+------------------------------------------------------------------+
//| Add Grid Position to Tracking                                     |
//+------------------------------------------------------------------+
void AddGridPosition(ulong ticket, int magic, int level, double openPrice, double lotSize, bool independentTP)
{
    ArrayResize(gridPositions, gridPositionCount + 1);
    
    gridPositions[gridPositionCount].ticket = ticket;
    gridPositions[gridPositionCount].magic = magic;
    gridPositions[gridPositionCount].level = level;
    gridPositions[gridPositionCount].openPrice = openPrice;
    gridPositions[gridPositionCount].lotSize = lotSize;
    gridPositions[gridPositionCount].openTime = TimeCurrent();
    gridPositions[gridPositionCount].hasIndependentTP = independentTP;
    
    gridPositionCount++;
}

//+------------------------------------------------------------------+
//| Remove Grid Position from Tracking                                |
//+------------------------------------------------------------------+
void RemoveGridPosition(ulong ticket)
{
    for(int i = 0; i < gridPositionCount; i++)
    {
        if(gridPositions[i].ticket == ticket)
        {
            // Shift array
            for(int j = i; j < gridPositionCount - 1; j++)
            {
                gridPositions[j] = gridPositions[j + 1];
            }
            gridPositionCount--;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Count Grid Levels for Magic Number                                |
//+------------------------------------------------------------------+
int CountGridLevels(int magic)
{
    // Count actual positions from broker instead of gridPositions array
    return CountOpenTrades(magic);
}

//+------------------------------------------------------------------+
//| Get Last Grid Level for Magic Number                              |
//+------------------------------------------------------------------+
int GetLastGridLevel(int magic)
{
    int maxLevel = -1;
    for(int i = 0; i < gridPositionCount; i++)
    {
        if(gridPositions[i].magic == magic && gridPositions[i].level > maxLevel)
            maxLevel = gridPositions[i].level;
    }
    return maxLevel;
}

//+------------------------------------------------------------------+
//| Get First Position Price for Magic Number                         |
//+------------------------------------------------------------------+
double GetFirstPositionPrice(int magic)
{
    for(int i = 0; i < gridPositionCount; i++)
    {
        if(gridPositions[i].magic == magic && gridPositions[i].level == 0)
            return gridPositions[i].openPrice;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Check if in Trend                                                 |
//+------------------------------------------------------------------+
bool IsInTrend(ENUM_POSITION_TYPE posType)
{
    if(!dcaOnlyInTrend) return true; // Always allow DCA if filter disabled
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double ma = trendMAArr[0];
    double trendMinPrice = trendMinPips * pipSize;
    
    if(posType == POSITION_TYPE_BUY)
    {
        // BUY position: Need uptrend (price above MA + minimum distance)
        if(currentPrice > ma && (currentPrice - ma) >= trendMinPrice)
        {
            // Additional confirmation: MA slope (current MA > previous MA)
            if(trendMAArr[0] > trendMAArr[1])
            {
                return true;
            }
        }
    }
    else // SELL
    {
        // SELL position: Need downtrend (price below MA + minimum distance)
        if(currentPrice < ma && (ma - currentPrice) >= trendMinPrice)
        {
            // Additional confirmation: MA slope (current MA < previous MA)
            if(trendMAArr[0] < trendMAArr[1])
            {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Higher Timeframe - Bullish                                  |
//+------------------------------------------------------------------+
bool IsHTFBullish()
{
    double htfPrice = iClose(_Symbol, higherTF, 0);
    double htfMA = htfMAArr[0];
    
    if(strictHTF)
    {
        // Strict: Price must be above MA on HTF
        return (htfPrice > htfMA);
    }
    else
    {
        // Lenient: MA must be trending up
        return (htfMAArr[0] > htfMAArr[1]);
    }
}

//+------------------------------------------------------------------+
//| Check Higher Timeframe - Bearish                                  |
//+------------------------------------------------------------------+
bool IsHTFBearish()
{
    double htfPrice = iClose(_Symbol, higherTF, 0);
    double htfMA = htfMAArr[0];
    
    if(strictHTF)
    {
        // Strict: Price must be below MA on HTF
        return (htfPrice < htfMA);
    }
    else
    {
        // Lenient: MA must be trending down
        return (htfMAArr[0] < htfMAArr[1]);
    }
}

//+------------------------------------------------------------------+
//| Check Valid Trading Session                                       |
//+------------------------------------------------------------------+
bool IsValidSession()
{
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    int hourGMT = timeStruct.hour; // GMT time
    
    // Asian Session: 00:00 - 08:00 GMT
    bool isAsian = (hourGMT >= 0 && hourGMT < 8);
    
    // London Session: 08:00 - 16:00 GMT
    bool isLondon = (hourGMT >= 8 && hourGMT < 16);
    
    // New York Session: 13:00 - 22:00 GMT (overlap with London 13:00-16:00)
    bool isNewYork = (hourGMT >= 13 && hourGMT < 22);
    
    // Check if current session is allowed
    if(isAsian && tradeAsian) return true;
    if(isLondon && tradeLondon) return true;
    if(isNewYork && tradeNewYork) return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Daily Reset                                                 |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    MqlDateTime currentTime, lastResetTime;
    TimeToStruct(TimeCurrent(), currentTime);
    TimeToStruct(lastDailyReset, lastResetTime);
    
    // Reset at midnight GMT
    if(currentTime.day != lastResetTime.day)
    {
        // New day - reset counters
        dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        dailyProfit = 0;
        dailyLoss = 0;
        dailyLimitReached = false;
        lastDailyReset = TimeCurrent();
        
        PrintFormat("📅 Daily Reset: New day started. Start Balance: $%.2f", dailyStartBalance);
    }
}

//+------------------------------------------------------------------+
//| Check Daily Limits                                                |
//+------------------------------------------------------------------+
void CheckDailyLimits()
{
    if(!useDailyLimits) return;
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double netPL = currentBalance - dailyStartBalance;
    double netPLPercent = (netPL / dailyStartBalance) * 100.0;
    
    // Check max loss
    if(netPLPercent <= -maxDailyLossPct)
    {
        dailyLimitReached = true;
        PrintFormat("⚠️ DAILY LOSS LIMIT REACHED: %.2f%% (Max: %.2f%%) - Trading stopped for today!", 
                   netPLPercent, maxDailyLossPct);
        
        // Close all positions
        CloseAllPositions();
    }
    
    // Check max profit
    if(netPLPercent >= maxDailyProfitPct)
    {
        dailyLimitReached = true;
        PrintFormat("🎉 DAILY PROFIT TARGET REACHED: %.2f%% (Target: %.2f%%) - Trading stopped for today!", 
                   netPLPercent, maxDailyProfitPct);
        
        // Optionally close all positions
        if(closeOnMaxProfit)
        {
            CloseAllPositions();
            PrintFormat("💰 All positions closed due to max profit setting");
        }
    }
}

//+------------------------------------------------------------------+
//| Close All Positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        int magic = (int)PositionGetInteger(POSITION_MAGIC);
        if(magic != MagicEA1 && magic != MagicEA2 && magic != MagicEA3) continue;
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = _Symbol;
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                      ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = (request.type == ORDER_TYPE_SELL) ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        request.deviation = 50;
        
        OrderSend(request, result);
    }
}

//+------------------------------------------------------------------+
//| Check Grid Expansion Opportunities (EA#1 & EA#2)                  |
//+------------------------------------------------------------------+
void CheckGridExpansionOpportunities()
{
    if(!useGridExpansion) return;
    
    // Debug info once per minute
    static datetime lastGlobalDebug = 0;
    if(TimeCurrent() - lastGlobalDebug > 60)
    {
        PrintFormat("🔍 Grid Expansion Check: gridStepPips=%.1f, pipSize=%.5f, gridStepPrice=%.5f", 
                   gridStepPips, pipSize, gridStepPips * pipSize);
        lastGlobalDebug = TimeCurrent();
    }
    
    // Only check for EA#1 and EA#2
    int magics[] = {MagicEA1, MagicEA2};
    
    for(int m = 0; m < 2; m++)
    {
        int magic = magics[m];
        
        // Count actual open positions from broker
        int totalPositions = CountOpenTrades(magic);
        if(totalPositions == 0) continue; // No positions to expand from
        if(totalPositions >= gridMaxLevels) continue; // Max levels reached
        
        // Get first position info (earliest position)
        double firstPrice = 0;
        datetime firstTime = D'2099.12.31';
        ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY;
        bool foundFirst = false;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
            
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
            
            datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
            if(posTime < firstTime)
            {
                firstTime = posTime;
                firstPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                foundFirst = true;
            }
        }
        
        if(!foundFirst || firstPrice == 0)
        {
            // Debug: Print positions check
            static datetime lastPosDebug[2] = {0, 0};
            if(TimeCurrent() - lastPosDebug[m] > 30)
            {
                PrintFormat("⚠️ Magic %d: No first position found! Total positions checked: %d", magic, PositionsTotal());
                lastPosDebug[m] = TimeCurrent();
            }
            continue;
        }
        
        // Debug: Print found position (once per 30 seconds to avoid spam)
        static datetime lastFoundDebug[2] = {0, 0};
        if(TimeCurrent() - lastFoundDebug[m] > 30)
        {
            PrintFormat("✅ Magic %d: Found first position at %.5f (%s), %d total positions", 
                       magic, firstPrice, EnumToString(posType), totalPositions);
            lastFoundDebug[m] = TimeCurrent();
        }
        
        // Get last grid position price (furthest from first)
        double lastGridPrice = firstPrice;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
            
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
            
            double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            if(posType == POSITION_TYPE_BUY)
            {
                // For BUY, last grid is lowest price
                if(posPrice < lastGridPrice)
                    lastGridPrice = posPrice;
            }
            else
            {
                // For SELL, last grid is highest price
                if(posPrice > lastGridPrice)
                    lastGridPrice = posPrice;
            }
        }
        
        // Check if grid range exceeded
        double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
        double rangeFromFirst = MathAbs(currentPrice - firstPrice) / pipSize;
        
        if(rangeFromFirst > gridMaxRangePips)
        {
            // Only print warning once per minute to avoid spam
            static datetime lastWarning[2] = {0, 0};
            if(TimeCurrent() - lastWarning[m] > 60)
            {
                PrintFormat("⚠️ Grid range exceeded (%.1f > %.1f pips) for Magic %d - stopping expansion", 
                           rangeFromFirst, gridMaxRangePips, magic);
                lastWarning[m] = TimeCurrent();
            }
            continue;
        }
        
        double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        // Use current market price for comparison
        currentPrice = (posType == POSITION_TYPE_BUY) ? bidPrice : askPrice;
        
        double gridStepPrice = gridStepPips * pipSize;
        
        // Debug: Print current state
        static datetime lastDebug[2] = {0, 0};
        if(TimeCurrent() - lastDebug[m] > 5) // Print every 5 seconds
        {
            PrintFormat("🔍 Grid Check Magic %d: Positions=%d, First=%.5f, Last=%.5f, Current=%.5f, NextGrid=%.5f, Step=%.5f", 
                       magic, totalPositions, firstPrice, lastGridPrice, currentPrice, 
                       (posType == POSITION_TYPE_BUY) ? (lastGridPrice - gridStepPrice) : (lastGridPrice + gridStepPrice),
                       gridStepPrice);
            lastDebug[m] = TimeCurrent();
        }
        
        // Check if price has moved enough for next grid level
        bool shouldOpenGrid = false;
        
        if(posType == POSITION_TYPE_BUY)
        {
            // BUY: Price drops below last grid by gridStepPips, open new BUY
            double nextGridPrice = lastGridPrice - gridStepPrice;
            if(currentPrice <= nextGridPrice)
            {
                shouldOpenGrid = true;
                PrintFormat("📉 BUY Grid: Price %.5f <= Next Grid %.5f (Last: %.5f, Step: %.1f pips)", 
                           currentPrice, nextGridPrice, lastGridPrice, gridStepPips);
            }
        }
        else // SELL
        {
            // SELL: Price rises above last grid by gridStepPips, open new SELL
            double nextGridPrice = lastGridPrice + gridStepPrice;
            if(currentPrice >= nextGridPrice)
            {
                shouldOpenGrid = true;
                PrintFormat("📈 SELL Grid: Price %.5f >= Next Grid %.5f (Last: %.5f, Step: %.1f pips)", 
                           currentPrice, nextGridPrice, lastGridPrice, gridStepPips);
            }
        }
        
        if(shouldOpenGrid)
        {
            int newLevel = totalPositions; // Grid level = number of positions
            string comment = (magic == MagicEA1) ? "EA1_Grid" : "EA2_Grid";
            
            PrintFormat("🔲 Opening Grid Level %d for Magic %d at %.5f (%.1f pips from first)", 
                       newLevel, magic, currentPrice, rangeFromFirst);
            
            ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            OpenTrade(orderType, magic, comment, newLevel);
        }
    }
}

//+------------------------------------------------------------------+
//| Close All Grid Positions for Magic Number (when any TP hit)       |
//+------------------------------------------------------------------+
void CloseAllGridPositions(int magic)
{
    if(gridIndependentTP) return; // Each grid has independent TP, don't close all
    
    PrintFormat("💰 Closing all Grid positions for Magic %d", magic);
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == magic)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (request.type == ORDER_TYPE_SELL) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            request.deviation = 50;
            
            OrderSend(request, result);
            
            // Remove from grid tracking
            RemoveGridPosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Support/Resistance Levels                               |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
    ArrayResize(supportLevels, 0);
    ArrayResize(resistanceLevels, 0);
    supportCount = 0;
    resistanceCount = 0;
    
    // Find swing highs and lows
    double swingHighs[];
    double swingLows[];
    int highCount = 0;
    int lowCount = 0;
    
    ArrayResize(swingHighs, srLookback);
    ArrayResize(swingLows, srLookback);
    
    // Identify swing points
    for(int i = 2; i < srLookback - 2; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        
        // Check if it's a swing high
        bool isSwingHigh = true;
        for(int j = -2; j <= 2; j++)
        {
            if(j == 0) continue;
            if(iHigh(_Symbol, PERIOD_CURRENT, i + j) >= high)
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh)
        {
            swingHighs[highCount] = high;
            highCount++;
        }
        
        // Check if it's a swing low
        bool isSwingLow = true;
        for(int j = -2; j <= 2; j++)
        {
            if(j == 0) continue;
            if(iLow(_Symbol, PERIOD_CURRENT, i + j) <= low)
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow)
        {
            swingLows[lowCount] = low;
            lowCount++;
        }
    }
    
    // Cluster swing points to find S/R levels
    double tolerance = 10 * pipSize; // 10 pips clustering tolerance
    
    // Process resistance levels from swing highs
    for(int i = 0; i < highCount; i++)
    {
        double level = swingHighs[i];
        if(level == 0) continue;
        
        int touches = 1;
        
        // Count touches near this level
        for(int j = i + 1; j < highCount; j++)
        {
            if(swingHighs[j] == 0) continue;
            
            if(MathAbs(swingHighs[j] - level) <= tolerance)
            {
                level = (level + swingHighs[j]) / 2.0; // Average the level
                swingHighs[j] = 0; // Mark as processed
                touches++;
            }
        }
        
        // If enough touches, add as resistance
        if(touches >= srTouchMin)
        {
            ArrayResize(resistanceLevels, resistanceCount + 1);
            resistanceLevels[resistanceCount] = level;
            resistanceCount++;
        }
    }
    
    // Process support levels from swing lows
    for(int i = 0; i < lowCount; i++)
    {
        double level = swingLows[i];
        if(level == 0) continue;
        
        int touches = 1;
        
        // Count touches near this level
        for(int j = i + 1; j < lowCount; j++)
        {
            if(swingLows[j] == 0) continue;
            
            if(MathAbs(swingLows[j] - level) <= tolerance)
            {
                level = (level + swingLows[j]) / 2.0; // Average the level
                swingLows[j] = 0; // Mark as processed
                touches++;
            }
        }
        
        // If enough touches, add as support
        if(touches >= srTouchMin)
        {
            ArrayResize(supportLevels, supportCount + 1);
            supportLevels[supportCount] = level;
            supportCount++;
        }
    }
    
    // Sort levels for easier searching
    ArraySort(resistanceLevels);
    ArraySort(supportLevels);
    
    // Debug output
    if(supportCount > 0 || resistanceCount > 0)
    {
        PrintFormat("📊 S/R: %d Support levels, %d Resistance levels", supportCount, resistanceCount);
    }
}

//+------------------------------------------------------------------+
//| Check if Market is Sideway (Range-bound)                          |
//+------------------------------------------------------------------+
bool IsSidewayMarket()
{
    if(!gridAutoDetect) return true; // Manual mode - always allow grid
    
    // 1. Check ADX - low ADX = sideway
    if(CopyBuffer(handleADX, 0, 0, 1, adxArr) <= 0) return false;
    
    double adxValue = adxArr[0];
    if(adxValue >= adxThreshold) return false; // Strong trend detected
    
    // 2. Check Bollinger Bands Width (normalized)
    double bbWidth = (bbUpper[0] - bbLower[0]) / bbBasis[0];
    
    if(bbWidth < bbWidthMin || bbWidth > bbWidthMax) return false;
    
    // 3. Check price range oscillation
    double highPrice = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, gridRangeBars, 0));
    double lowPrice = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, gridRangeBars, 0));
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    double rangeHeight = highPrice - lowPrice;
    double rangeHeightPips = rangeHeight / pipSize;
    
    // Range should be between 50-300 pips for effective grid trading
    if(rangeHeightPips < 50 || rangeHeightPips > 300) return false;
    
    // Price should be oscillating within range (not breaking out)
    double upperThreshold = lowPrice + rangeHeight * 0.9;
    double lowerThreshold = lowPrice + rangeHeight * 0.1;
    
    bool withinRange = (currentPrice > lowerThreshold && currentPrice < upperThreshold);
    
    PrintFormat("🔍 Sideway Check: ADX=%.1f, BBWidth=%.5f, Range=%.1f pips, Within=%s", 
               adxValue, bbWidth, rangeHeightPips, withinRange ? "Yes" : "No");
    
    return (adxValue < adxThreshold && withinRange);
}

//+------------------------------------------------------------------+
//| Calculate Multi-Timeframe Reversal Score (0-100)                  |
//+------------------------------------------------------------------+
int CalculateMTFReversalScore(bool &isBullishReversal, bool &isBearishReversal)
{
    isBullishReversal = false;
    isBearishReversal = false;
    
    if(!useMTFReversal) return 0;
    
    int score = 0;
    int bullishSignals = 0;
    int bearishSignals = 0;
    
    // Copy indicator data for all timeframes
    if(CopyBuffer(handleRSI_TF1, 0, 0, 1, rsiTF1) <= 0) return 0;
    if(CopyBuffer(handleRSI_TF2, 0, 0, 1, rsiTF2) <= 0) return 0;
    if(CopyBuffer(handleRSI_TF3, 0, 0, 1, rsiTF3) <= 0) return 0;
    
    if(CopyBuffer(handleSTO_TF1, 0, 0, 1, stoTF1_K) <= 0) return 0;
    if(CopyBuffer(handleSTO_TF1, 1, 0, 1, stoTF1_D) <= 0) return 0;
    if(CopyBuffer(handleSTO_TF2, 0, 0, 1, stoTF2_K) <= 0) return 0;
    if(CopyBuffer(handleSTO_TF2, 1, 0, 1, stoTF2_D) <= 0) return 0;
    if(CopyBuffer(handleSTO_TF3, 0, 0, 1, stoTF3_K) <= 0) return 0;
    if(CopyBuffer(handleSTO_TF3, 1, 0, 1, stoTF3_D) <= 0) return 0;
    
    if(CopyBuffer(handleMACD_TF1, 0, 0, 1, macdTF1) <= 0) return 0;
    if(CopyBuffer(handleMACD_TF2, 0, 0, 1, macdTF2) <= 0) return 0;
    if(CopyBuffer(handleMACD_TF3, 0, 0, 1, macdTF3) <= 0) return 0;
    
    // === RSI Analysis (3 timeframes × 10 points each) ===
    // TF1 (M15) - Weight: 10 points
    if(rsiTF1[0] < rsiOversold) bullishSignals += 10;
    else if(rsiTF1[0] > rsiOverbought) bearishSignals += 10;
    
    // TF2 (H1) - Weight: 15 points  
    if(rsiTF2[0] < rsiOversold) bullishSignals += 15;
    else if(rsiTF2[0] > rsiOverbought) bearishSignals += 15;
    
    // TF3 (H4) - Weight: 20 points
    if(rsiTF3[0] < rsiOversold) bullishSignals += 20;
    else if(rsiTF3[0] > rsiOverbought) bearishSignals += 20;
    
    // === Stochastic Analysis (3 timeframes × 5 points each) ===
    // TF1
    if(stoTF1_K[0] < 20 && stoTF1_D[0] < 20) bullishSignals += 5;
    else if(stoTF1_K[0] > 80 && stoTF1_D[0] > 80) bearishSignals += 5;
    
    // TF2
    if(stoTF2_K[0] < 20 && stoTF2_D[0] < 20) bullishSignals += 10;
    else if(stoTF2_K[0] > 80 && stoTF2_D[0] > 80) bearishSignals += 10;
    
    // TF3
    if(stoTF3_K[0] < 20 && stoTF3_D[0] < 20) bullishSignals += 15;
    else if(stoTF3_K[0] > 80 && stoTF3_D[0] > 80) bearishSignals += 15;
    
    // === MACD Histogram Analysis (3 timeframes × 5 points each) ===
    // Looking for divergence or extreme negative/positive
    if(macdTF1[0] < 0) bullishSignals += 5;
    else if(macdTF1[0] > 0) bearishSignals += 5;
    
    if(macdTF2[0] < 0) bullishSignals += 10;
    else if(macdTF2[0] > 0) bearishSignals += 10;
    
    if(macdTF3[0] < 0) bullishSignals += 15;
    else if(macdTF3[0] > 0) bearishSignals += 15;
    
    // Determine reversal direction
    if(bullishSignals > bearishSignals)
    {
        isBullishReversal = true;
        score = bullishSignals;
    }
    else if(bearishSignals > bullishSignals)
    {
        isBearishReversal = true;
        score = bearishSignals;
    }
    
    PrintFormat("🎯 MTF Reversal Score: %d (Bullish: %d, Bearish: %d)", 
               score, bullishSignals, bearishSignals);
    
    return score;
}

//+------------------------------------------------------------------+
//| Check EA#4 Grid Trading Signals                                   |
//+------------------------------------------------------------------+
void CheckEA4GridSignals()
{
    if(!enableEA4) return;
    
    // Update indicators
    if(CopyBuffer(handleBB, 1, 0, 3, bbUpper) <= 0) return;
    if(CopyBuffer(handleBB, 2, 0, 3, bbLower) <= 0) return;
    if(CopyBuffer(handleBB, 0, 0, 3, bbBasis) <= 0) return;
    
    // Check if market is sideway
    bool isSideway = IsSidewayMarket();
    
    if(!isSideway)
    {
        // Market is trending - close all grid positions if any
        if(gridActive)
        {
            PrintFormat("⚠️ Market switched to TRENDING - Closing all grid positions");
            CloseAllGridPositions();
            gridActive = false;
        }
        return;
    }
    
    // Calculate MTF reversal score
    bool bullishReversal = false;
    bool bearishReversal = false;
    int reversalScore = CalculateMTFReversalScore(bullishReversal, bearishReversal);
    
    // Check if reversal score is strong enough
    if(reversalScore < minReversalScore)
    {
        PrintFormat("⏳ Reversal score (%d) below minimum (%d) - waiting...", reversalScore, minReversalScore);
        return;
    }
    
    // Establish grid range if not active
    if(!gridActive || TimeCurrent() - lastGridCheck > 3600) // Recheck every hour
    {
        double highPrice = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, gridRangeBars, 0));
        double lowPrice = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, gridRangeBars, 0));
        
        gridRangeTop = highPrice;
        gridRangeBottom = lowPrice;
        lastGridCheck = TimeCurrent();
        
        PrintFormat("📏 Grid Range Established: %.5f - %.5f (%.1f pips)", 
                   gridRangeBottom, gridRangeTop, (gridRangeTop - gridRangeBottom) / pipSize);
    }
    
    // Place grid orders
    PlaceGridOrders(bullishReversal, bearishReversal);
    
    // Manage existing grid positions
    ManageGridPositions();
    
    gridActive = true;
}

//+------------------------------------------------------------------+
//| Place Grid Orders                                                 |
//+------------------------------------------------------------------+
void PlaceGridOrders(bool bullishReversal, bool bearishReversal)
{
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double gridStepPrice = ea4GridStepPips * pipSize;
    
    int buyGridCount = 0;
    int sellGridCount = 0;
    
    // Count existing grid positions
    for(int i = 0; i < gridLevelCount; i++)
    {
        if(!gridLevels[i].isActive) continue;
        
        if(gridLevels[i].type == 0) buyGridCount++;
        else sellGridCount++;
    }
    
    // Place BUY grids below current price (if bullish reversal expected)
    if(bullishReversal && buyGridCount < ea4GridMaxLevels / 2)
    {
        for(int i = 1; i <= ea4GridMaxLevels / 2 && buyGridCount < ea4GridMaxLevels / 2; i++)
        {
            double gridPrice = currentPrice - (i * gridStepPrice);
            
            if(gridPrice < gridRangeBottom) break; // Don't go below range
            
            // Check if grid already exists at this level
            if(!GridExistsAtPrice(gridPrice, 0))
            {
                OpenGridTrade(ORDER_TYPE_BUY, gridPrice);
                buyGridCount++;
            }
        }
    }
    
    // Place SELL grids above current price (if bearish reversal expected)
    if(bearishReversal && sellGridCount < ea4GridMaxLevels / 2)
    {
        for(int i = 1; i <= ea4GridMaxLevels / 2 && sellGridCount < ea4GridMaxLevels / 2; i++)
        {
            double gridPrice = currentPrice + (i * gridStepPrice);
            
            if(gridPrice > gridRangeTop) break; // Don't go above range
            
            // Check if grid already exists at this level
            if(!GridExistsAtPrice(gridPrice, 1))
            {
                OpenGridTrade(ORDER_TYPE_SELL, gridPrice);
                sellGridCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Grid Exists at Price Level                               |
//+------------------------------------------------------------------+
bool GridExistsAtPrice(double price, int type)
{
    double tolerance = 5 * pipSize; // 5 pips tolerance
    
    for(int i = 0; i < gridLevelCount; i++)
    {
        if(!gridLevels[i].isActive) continue;
        if(gridLevels[i].type != type) continue;
        
        if(MathAbs(gridLevels[i].price - price) <= tolerance)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Open Grid Trade                                                   |
//+------------------------------------------------------------------+
void OpenGridTrade(ENUM_ORDER_TYPE orderType, double entryPrice)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = ea4GridLotSize;
    request.type = (orderType == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    request.price = entryPrice;
    request.deviation = 50;
    request.magic = MagicEA4;
    request.comment = "Grid_" + ((orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL");
    
    // Set TP and SL
    double tp = 0, sl = 0;
    
    if(orderType == ORDER_TYPE_BUY)
    {
        tp = entryPrice + (ea4GridTPPips * pipSize);
        sl = entryPrice - (ea4GridSLPips * pipSize);
    }
    else
    {
        tp = entryPrice - (ea4GridTPPips * pipSize);
        sl = entryPrice + (ea4GridSLPips * pipSize);
    }
    
    request.tp = tp;
    request.sl = sl;
    
    if(OrderSend(request, result))
    {
        // Add to grid tracking
        ArrayResize(gridLevels, gridLevelCount + 1);
        gridLevels[gridLevelCount].ticket = result.order;
        gridLevels[gridLevelCount].price = entryPrice;
        gridLevels[gridLevelCount].type = (orderType == ORDER_TYPE_BUY) ? 0 : 1;
        gridLevels[gridLevelCount].lotSize = ea4GridLotSize;
        gridLevels[gridLevelCount].isActive = true;
        gridLevels[gridLevelCount].openTime = TimeCurrent();
        gridLevelCount++;
        
        PrintFormat("✅ Grid %s order placed at %.5f (TP: %.5f, SL: %.5f)", 
                   (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL", entryPrice, tp, sl);
    }
    else
    {
        PrintFormat("❌ Failed to place grid order: %d - %s", result.retcode, result.comment);
    }
}

//+------------------------------------------------------------------+
//| Manage Grid Positions                                             |
//+------------------------------------------------------------------+
void ManageGridPositions()
{
    // Check for filled orders and partial close logic
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicEA4) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                             SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        double profitPips = MathAbs(currentPrice - openPrice) / pipSize;
        
        // Partial close at first TP level
        if(ea4GridPartialClose && profitPips >= ea4GridTPPips * 0.5) // 50% of TP
        {
            double currentVolume = PositionGetDouble(POSITION_VOLUME);
            double closeVolume = NormalizeDouble(currentVolume * (ea4GridPartialPct / 100.0), 2);
            
            if(closeVolume >= 0.01) // Minimum lot size
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = _Symbol;
                request.volume = closeVolume;
                request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                              ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                request.price = currentPrice;
                request.deviation = 50;
                
                if(OrderSend(request, result))
                {
                    PrintFormat("💰 Partial close %.2f lots at %.1f pips profit", closeVolume, profitPips);
                }
            }
        }
    }
    
    // Remove inactive grid levels
    for(int i = gridLevelCount - 1; i >= 0; i--)
    {
        if(!gridLevels[i].isActive) continue;
        
        // Check if order/position still exists
        bool exists = false;
        
        for(int j = 0; j < PositionsTotal(); j++)
        {
            if(PositionGetTicket(j) == gridLevels[i].ticket)
            {
                exists = true;
                break;
            }
        }
        
        if(!exists)
        {
            // Check pending orders
            for(int j = 0; j < OrdersTotal(); j++)
            {
                if(OrderGetTicket(j) == gridLevels[i].ticket)
                {
                    exists = true;
                    break;
                }
            }
        }
        
        if(!exists)
        {
            gridLevels[i].isActive = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Close All Grid Positions                                          |
//+------------------------------------------------------------------+
void CloseAllGridPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicEA4) continue;
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = _Symbol;
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                      ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = (request.type == ORDER_TYPE_SELL) ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        request.deviation = 50;
        
        OrderSend(request, result);
    }
    
    // Cancel all pending grid orders
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        
        if(OrderGetInteger(ORDER_MAGIC) != MagicEA4) continue;
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_REMOVE;
        request.order = ticket;
        
        OrderSend(request, result);
    }
    
    // Clear grid tracking
    ArrayResize(gridLevels, 0);
    gridLevelCount = 0;
}

