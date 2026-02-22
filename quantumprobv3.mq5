//+------------------------------------------------------------------+
//|                           QuantumRSI v4.0 - Multi-Timeframe ML   |
//|                        Copyright 2024, Multi-Timeframe Strategy  |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, QuantumRSI v4.0 MTF"
#property link      "https://www.mql5.com"
#property version   "4.00"

//+------------------------------------------------------------------+
//| Enum Declarations                                                 |
//+------------------------------------------------------------------+
enum ENUM_NEWS_FILTER { 
    NEWS_OFF = 0,              // No News Filter
    NEWS_HIGH_ONLY = 1,        // High Impact Only
    NEWS_ALL = 2               // All News Events
};

enum ENUM_TPSL_MODE { 
    PIPS_RR = 0,               // Pips + Risk/Reward
    ATR_PIPS = 1,              // ATR-based
    TRAILING_STOP = 2,         // Trailing Stop
    TRAILING_ATR = 3           // Trailing ATR
};

enum ENUM_HEDGE_STRATEGY { 
    HEDGE_FIXED = 0,           // Fixed Ratio
    HEDGE_DYNAMIC = 1,         // Dynamic Ratio (based on PL)
    HEDGE_PYRAMID = 2,         // Pyramid Hedging
    HEDGE_BALANCE = 3,         // Balance Hedge (equalize exposure)
    HEDGE_PROFIT_LOCK = 4,     // Profit Lock Hedge
    HEDGE_SL_PROTECT = 5       // Stop Loss Protection
};

enum ENUM_RISK_MODE { 
    FIXED = 0,                 // Fixed Lot Size
    MARTINGALE = 1,            // Martingale (double on loss)
    FIBONACCI = 2,             // Fibonacci Progression
    ALGORITHMIC = 3            // Risk % based
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
sinput group "=== TRADING MODE ==="
input int    MagicNumber     = 123456;          // 🔢 Magic Number (unique ID)
input bool   useHistoryRecovery = true;         // 🔄 Auto-recover state from trading history
input int    historyDays     = 30;              // 📅 Days of history to analyze
input bool   enableBuy       = true;            // Enable Buy
input bool   enableSell      = true;            // Enable Sell

sinput group "=== INDICATOR SELECTION ==="
input bool   use_RSI         = true;            // Use RSI
input bool   use_EMA         = false;           // Use EMA Crossover
input bool   use_MACD        = false;           // Use MACD
input bool   use_BB          = false;           // Use Bollinger Bands

sinput group "=== MACHINE LEARNING ==="
input bool   useML           = true;            // Use ML Reinforcement Learning
input double mlLearningRate  = 0.1;             // Learning Rate (0.01-0.5)
input int    mlMemorySize    = 100;             // Memory Size (trades)
input double signalThreshold = 0.60;            // Signal Threshold (50-80%) - Higher = Less trades
input int    minConfirmBars  = 2;               // Min Confirmation Bars (1-5)
input int    cooldownBars    = 3;               // Cooldown Between Trades (bars)

sinput group "=== NEWS FILTER ==="
input ENUM_NEWS_FILTER newsFilter = NEWS_OFF;   // News Filter Mode
input int    newsMinutesBefore = 30;            // Minutes Before News
input int    newsMinutesAfter  = 30;            // Minutes After News
input string newsCurrency      = "USD,EUR,GBP,JPY,AUD,CAD,CHF,NZD"; // Currencies to Monitor

sinput group "=== RSI Settings ==="
input int    length_rsi      = 14;              // RSI Length
input int    rsi_entry       = 35;              // RSI Oversold (BUY)
input int    rsi_exit        = 75;              // RSI Overbought (SELL)
input string rsi_timeframes  = "CURRENT,H1,H4"; // RSI Timeframes (comma-separated: M1,M5,M15,M30,H1,H4,D1,W1,MN1,CURRENT)

sinput group "=== EMA Settings ==="
input int    ema_fast        = 12;              // EMA Fast Period
input int    ema_slow        = 26;              // EMA Slow Period
input string ema_timeframes  = "CURRENT,H1";    // EMA Timeframes

sinput group "=== MACD Settings ==="
input int    macd_fast       = 12;              // MACD Fast EMA
input int    macd_slow       = 26;              // MACD Slow EMA
input int    macd_signal     = 9;               // MACD Signal Period
input string macd_timeframes = "CURRENT,H4";    // MACD Timeframes

sinput group "=== Bollinger Bands Settings ==="
input int    bb_period       = 20;              // BB Period
input double bb_deviation    = 2.0;             // BB Deviation
input string bb_timeframes   = "CURRENT,H1";    // BB Timeframes

sinput group "=== TP/SL Settings ==="
input bool   useStopLoss     = true;            // Use Stop Loss
input bool   useTakeProfit   = true;            // Use Take Profit
input ENUM_TPSL_MODE tpSlMode = PIPS_RR;        // TP/SL Mode
input int    slPips          = 30;              // SL pips (PIPS_RR mode)
input double rr              = 3.0;             // RR (PIPS_RR mode)
input int    atr_len         = 14;              // ATR Length
input string atr_timeframe   = "CURRENT";       // ATR Timeframe (M1,M5,M15,M30,H1,H4,D1,W1,MN1,CURRENT)
input double atr_mult_sl     = 1.0;             // ATR Multiplier for SL
input double atr_mult_tp     = 2.5;             // ATR Multiplier for TP
input int    trailingStart   = 20;              // Trailing Start (pips profit)
input int    trailingStep    = 10;              // Trailing Step (pips)
input double trailingATRMult = 1.5;             // Trailing ATR Multiplier

sinput group "=== SMART DCA SYSTEM ==="
input bool   useSmartDCA       = true;          // 🎯 Use Smart DCA (Auto Price Zones)
input bool   autoDCALevels     = true;          // ⚡ Auto Calculate DCA Levels from ATR
input int    manualDCALevels   = 5;             // Manual DCA Levels (if auto=false)
input double dcaATRMultiplier  = 2.0;           // DCA Zone ATR Multiplier
input double dcaMinDistance    = 30.0;          // Min DCA Distance (pips) - Prevent too close
input double dcaMaxDistance    = 200.0;         // Max DCA Distance (pips) - Prevent too far
input bool   skipExistingZones = true;          // 🚫 Skip signals if price zone has position
input double zoneTolerance     = 0.3;           // Zone Tolerance (0.3 = ±30% of DCA distance)
input int    maxDCAPositions   = 10;            // Max DCA positions per direction

sinput group "=== AUTO CLOSE ALL SYSTEM ==="
input bool   useAutoCloseAll   = true;          // 🎯 Use Auto Close All System
input bool   closeOnProfitTarget = true;        // Close all when profitable
input double profitTargetDollar = 0.0;          // Profit Target ($) - 0 = ANY profit
input double profitTargetPercent = 0.0;         // Profit Target (%) - 0 = ANY profit
input bool   closeOnDrawdown   = true;          // Close all on max drawdown
input double maxDrawdownPercent = 5.0;          // Max Drawdown % before close all
input bool   closeOnBreakeven  = true;          // Close all near breakeven (protect profit)
input double breakevenThreshold = 0.5;          // Breakeven threshold (± %)
input bool   closeOnTimeLimit  = false;         // Close all after time limit
input int    maxHoursOpen      = 24;            // Max hours positions can be open
input bool   useSmartClose     = true;          // Smart close (consider win rate)
input double minWinRateToHold  = 40.0;          // Min win rate % to hold positions

sinput group "=== ADVANCED HEDGE MODULE ==="
input bool   useAdvancedHedge    = false;       // Use Advanced Hedge System
input ENUM_HEDGE_STRATEGY hedgeStrategy = HEDGE_DYNAMIC; // Hedge Strategy
input double hedgeRatio          = 1.0;         // Base Hedge Ratio (1.0 = same lot)
input double hedgeActivationPips = 20.0;        // Pips to activate hedge
input bool   usePartialHedge     = true;        // Use Partial Hedge (not full)
input double partialHedgePercent = 60.0;        // Partial Hedge % (60% = hedge 60% of exposure)
input bool   usePyramidHedge     = false;       // Use Pyramid Hedging
input int    pyramidLevels       = 3;           // Pyramid Hedge Levels
input double pyramidMultiplier   = 1.3;         // Pyramid Lot Multiplier
input bool   useProfitLockHedge  = true;        // Lock Profit when threshold reached
input double profitLockThreshold = 50.0;        // Profit Lock Threshold ($)
input bool   useCorrelationHedge = false;       // Hedge based on correlation
input double correlationThreshold = 0.7;        // Correlation Threshold
input bool   autoCloseHedge      = true;        // Auto-close hedge when main closes
input bool   useHedgeTP          = true;        // Use TP for hedge positions
input double hedgeTPMultiplier   = 1.5;         // Hedge TP Multiplier

sinput group "=== HEDGE REDUCTION MECHANISM ==="
input bool   useHedgeReduction   = true;        // 🎯 Use Hedge Reduction System
input bool   useSmartHedgeClose  = true;        // Smart partial hedge close
input double hedgeProfitTarget   = 2.0;         // Hedge Profit Target (%)
input bool   useBreakevenHedge   = true;        // Close hedge at breakeven
// breakevenThreshold already defined in Auto Close All section above
input bool   useCorrelationClose = true;        // Close when main+hedge both profit
input bool   usePartialReduction = true;        // Reduce hedge gradually (not all)
input double reductionPercent    = 50.0;        // Reduce % each time (50% = half)
input int    minHedgeBars        = 5;           // Min bars before reduction
input bool   useTimeReduction    = false;       // Time-based reduction
input int    maxHedgeHours       = 24;          // Max hedge duration (hours)

sinput group "=== Money Management ==="
input ENUM_RISK_MODE riskMode    = FIXED;       // Risk Management Mode
input double lotSize             = 0.1;         // Lot Size (FIXED mode)
input double riskPercent         = 2.0;         // Risk % of Balance (ALGORITHMIC mode)
input double martingaleMultiplier = 2.0;        // Martingale Multiplier
input double maxLotSize          = 10.0;        // Max Lot Size (safety)
input int    maxOpenPositions    = 10;          // Max concurrent positions

sinput group "=== POC & SUPPORT/RESISTANCE ==="
input bool   usePOC              = true;        // 🎯 Use POC (Point of Control)
input string pocTimeframes       = "H4,D1";     // POC Timeframes (H4, D1, W1)
input int    pocLookback         = 50;          // POC Lookback Bars
input double pocProximity        = 20.0;        // POC Proximity (pips) to trigger
input bool   useSupportResistance = true;       // 🎯 Use Multi-TF S/R
input string srTimeframes        = "M15,H1,H4,D1"; // S/R Timeframes
input int    srSwingStrength     = 5;           // Swing High/Low Strength (bars)
input double srMinDistance       = 30.0;        // Min S/R Distance (pips)
input double srProximity         = 15.0;        // S/R Proximity (pips) to trigger
input bool   useMLBoost          = true;        // 🚀 Boost ML when near POC/S/R
input double mlBoostMultiplier   = 1.5;         // ML Boost Multiplier (1.5x weight)

//+------------------------------------------------------------------+
//| Multi-Timeframe Structure                                        |
//+------------------------------------------------------------------+
struct MTFHandles
{
    int handles[];              // Array of indicator handles
    ENUM_TIMEFRAMES timeframes[]; // Array of timeframes
    int count;                  // Number of timeframes
};

MTFHandles rsiMTF;
MTFHandles emaFastMTF;
MTFHandles emaSlowMTF;
MTFHandles macdMTF;
MTFHandles bbMTF;
int atrHandle = INVALID_HANDLE;
ENUM_TIMEFRAMES atrTF = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| ML Signal Weight Structure                                       |
//+------------------------------------------------------------------+
struct SignalWeight
{
    string name;            // "RSI_M15", "EMA_H1", etc.
    double weight;          // Current weight (0.0 to 1.0)
    double total_profit;    // Total profit from this signal
    int trade_count;        // Number of trades
};

SignalWeight signalWeights[];
int signalWeightCount = 0;
int mlTradeCounter = 0;

//--- Risk Management Variables
double currentLotSize = 0.1;
int consecutiveLosses = 0;
double lastLotSize = 0.1;
int fibIndex = 0;
int totalWins = 0;              // Total winning trades
int totalLosses = 0;            // Total losing trades

//+------------------------------------------------------------------+
//| Advanced Hedge Position Structure                                |
//+------------------------------------------------------------------+
struct HedgePosition {
    ulong ticket;
    ulong mainTicket;        // Main position ticket
    ENUM_POSITION_TYPE type;
    double lots;
    double openPrice;
    double currentPL;
    int pyramidLevel;
    datetime openTime;
    bool isProfitLock;
};
HedgePosition hedgePositionsLong[];
HedgePosition hedgePositionsShort[];
int hedgeCountLong = 0;
int hedgeCountShort = 0;
double totalHedgeLots = 0;
double lastHedgeCheckTime = 0;
double maxProfitReached = 0;      // Track max profit for profit lock
bool hedgeActiveLong = false;     // Hedge active flag
bool hedgeActiveShort = false;    // Hedge active flag

//--- Hedge Reduction Variables
double hedgeTotalProfitLong = 0;   // Accumulated hedge profit (long side)
double hedgeTotalProfitShort = 0;  // Accumulated hedge profit (short side)
int hedgeReductionCountLong = 0;   // Times reduced (long)
int hedgeReductionCountShort = 0;  // Times reduced (short)
datetime lastReductionTimeLong = 0;
datetime lastReductionTimeShort = 0;

//--- Trading Mode (HEDGE only - GRID removed)
enum TRADING_MODE { SINGLE_DIRECTION = 0, HEDGE = 1, GRID = 2 };
TRADING_MODE tradingMode = HEDGE;  // Default to HEDGE mode

//--- Smart Lot Progression Array
double smartLotMultipliers[];
int smartLotCount = 0;

//--- Track active signals for ML updates
string lastActiveSignals = "";  // Signals that fired on last trade

//--- Signal Smoothing Variables
datetime lastTradeTime = 0;       // Last trade open time
int consecutiveBuyBars = 0;       // Consecutive bars with buy signal
int consecutiveSellBars = 0;      // Consecutive bars with sell signal
double lastBuyScore = 0;          // Last buy signal score
double lastSellScore = 0;         // Last sell signal score

//--- News Filter Variables
struct NewsEvent
{
    datetime time;
    string currency;
    string title;
    int impact;  // 1=Low, 2=Medium, 3=High
};

NewsEvent upcomingNews[];
int newsCount = 0;
datetime lastNewsCheck = 0;

//--- Smart DCA Variables
double dcaDistance = 0;              // Auto-calculated DCA distance
double dcaLevelsArray[];             // DCA price levels
int dcaLevelCount = 0;

//--- Price Zone Tracking (for ML per candle price)
struct PriceZone
{
    double price;                    // Zone center price
    int positionCount;               // Number of positions in this zone
    double totalLots;                // Total lots in this zone
    double totalProfit;              // Accumulated profit from this zone
    int tradeCount;                  // Total trades closed from this zone
    double winRate;                  // Win rate for this zone
    datetime lastTradeTime;          // Last trade time in this zone
    string activeSignals;            // Signals that triggered this zone
};

PriceZone priceZonesLong[];
PriceZone priceZonesShort[];
int zoneCountLong = 0;
int zoneCountShort = 0;

//--- ML Price-based Learning
struct PriceLevelML
{
    double priceLevel;               // Normalized price level (candle price)
    string signalPattern;            // Signal combination at this level
    double weight;                   // ML weight for this price+signal combo
    double totalProfit;              // Total profit from this combo
    int tradeCount;                  // Number of trades
    double successRate;              // Success rate (0-1)
};

PriceLevelML mlPriceLevels[];
int mlPriceLevelCount = 0;

//+------------------------------------------------------------------+
//| POC (Point of Control) Structure                                 |
//+------------------------------------------------------------------+
struct POCLevel
{
    ENUM_TIMEFRAMES timeframe;       // Timeframe of POC
    double pocPrice;                 // POC price level
    double pocVolume;                // Volume at POC
    datetime calculatedTime;         // When was this calculated
    int barCount;                    // Number of bars used
};

POCLevel pocLevels[];
int pocLevelCount = 0;

//+------------------------------------------------------------------+
//| Support/Resistance Level Structure                               |
//+------------------------------------------------------------------+
struct SRLevel
{
    ENUM_TIMEFRAMES timeframe;       // Timeframe of S/R
    double price;                    // S/R price level
    bool isSupport;                  // true = Support, false = Resistance
    int touches;                     // Number of times price touched this level
    double strength;                 // Strength score (0-1)
    datetime lastTouch;              // Last time price touched
    bool isActive;                   // Still valid or broken
};

SRLevel srLevels[];
int srLevelCount = 0;

//+------------------------------------------------------------------+
//| Parse timeframe string to ENUM_TIMEFRAMES                        |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES StringToTimeframe(string tf)
{
    StringTrimLeft(tf);
    StringTrimRight(tf);
    StringToUpper(tf);
    
    if(tf == "CURRENT" || tf == "CHART") return _Period;
    if(tf == "M1") return PERIOD_M1;
    if(tf == "M5") return PERIOD_M5;
    if(tf == "M15") return PERIOD_M15;
    if(tf == "M30") return PERIOD_M30;
    if(tf == "H1") return PERIOD_H1;
    if(tf == "H4") return PERIOD_H4;
    if(tf == "D1") return PERIOD_D1;
    if(tf == "W1") return PERIOD_W1;
    if(tf == "MN1") return PERIOD_MN1;
    
    return _Period;
}

//+------------------------------------------------------------------+
//| Get timeframe name                                                |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Calculate Auto DCA Distance                                      |
//+------------------------------------------------------------------+
double CalculateAutoDCADistance()
{
    if(!autoDCALevels || !useSmartDCA)
    {
        // Use manual settings
        return manualDCALevels * GetPip();
    }
    
    double atr = GetATR(0);
    if(atr == EMPTY_VALUE || atr <= 0)
    {
        // Fallback to manual if ATR unavailable
        return dcaMinDistance * GetPip();
    }
    
    // ATR-based DCA distance
    double distance = atr * dcaATRMultiplier;
    double pip = GetPip();
    
    // Apply min/max limits
    double minDist = dcaMinDistance * pip;
    double maxDist = dcaMaxDistance * pip;
    
    if(distance < minDist) distance = minDist;
    if(distance > maxDist) distance = maxDist;
    
    return distance;
}

//+------------------------------------------------------------------+
//| Find or Create Price Zone                                        |
//+------------------------------------------------------------------+
int FindPriceZone(double price, bool isLong)
{
    if(!useSmartDCA) return -1;
    
    double tolerance = dcaDistance * zoneTolerance;
    
    if(isLong)
    {
        for(int i = 0; i < zoneCountLong; i++)
        {
            if(MathAbs(priceZonesLong[i].price - price) <= tolerance)
                return i;
        }
    }
    else
    {
        for(int i = 0; i < zoneCountShort; i++)
        {
            if(MathAbs(priceZonesShort[i].price - price) <= tolerance)
                return i;
        }
    }
    
    return -1; // Zone not found
}

//+------------------------------------------------------------------+
//| Create New Price Zone                                            |
//+------------------------------------------------------------------+
int CreatePriceZone(double price, bool isLong, string signals)
{
    if(!useSmartDCA) return -1;
    
    if(isLong)
    {
        int index = zoneCountLong;
        zoneCountLong++;
        ArrayResize(priceZonesLong, zoneCountLong);
        
        priceZonesLong[index].price = price;
        priceZonesLong[index].positionCount = 0;
        priceZonesLong[index].totalLots = 0;
        priceZonesLong[index].totalProfit = 0;
        priceZonesLong[index].tradeCount = 0;
        priceZonesLong[index].winRate = 0;
        priceZonesLong[index].lastTradeTime = TimeCurrent();
        priceZonesLong[index].activeSignals = signals;
        
        return index;
    }
    else
    {
        int index = zoneCountShort;
        zoneCountShort++;
        ArrayResize(priceZonesShort, zoneCountShort);
        
        priceZonesShort[index].price = price;
        priceZonesShort[index].positionCount = 0;
        priceZonesShort[index].totalLots = 0;
        priceZonesShort[index].totalProfit = 0;
        priceZonesShort[index].tradeCount = 0;
        priceZonesShort[index].winRate = 0;
        priceZonesShort[index].lastTradeTime = TimeCurrent();
        priceZonesShort[index].activeSignals = signals;
        
        return index;
    }
}

//+------------------------------------------------------------------+
//| Update Price Zone (add position)                                 |
//+------------------------------------------------------------------+
void UpdatePriceZone(int zoneIndex, bool isLong, double lots)
{
    if(!useSmartDCA || zoneIndex < 0) return;
    
    if(isLong)
    {
        if(zoneIndex >= zoneCountLong) return;
        priceZonesLong[zoneIndex].positionCount++;
        priceZonesLong[zoneIndex].totalLots += lots;
        priceZonesLong[zoneIndex].lastTradeTime = TimeCurrent();
    }
    else
    {
        if(zoneIndex >= zoneCountShort) return;
        priceZonesShort[zoneIndex].positionCount++;
        priceZonesShort[zoneIndex].totalLots += lots;
        priceZonesShort[zoneIndex].lastTradeTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Check if should skip signal (zone already has positions)         |
//+------------------------------------------------------------------+
bool ShouldSkipSignalDueToZone(double price, bool isLong)
{
    if(!useSmartDCA || !skipExistingZones) return false;
    
    int zoneIndex = FindPriceZone(price, isLong);
    
    if(zoneIndex >= 0)
    {
        int posCount = isLong ? priceZonesLong[zoneIndex].positionCount : 
                               priceZonesShort[zoneIndex].positionCount;
        
        if(posCount > 0)
        {
            PrintFormat("🚫 Signal SKIPPED: Zone %.5f already has %d position(s)", 
                       price, posCount);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Normalize price to candle level (for ML)                         |
//+------------------------------------------------------------------+
double NormalizePriceToLevel(double price)
{
    // Normalize to ATR-based levels for ML
    double atr = GetATR(0);
    if(atr <= 0 || atr == EMPTY_VALUE) return price;
    
    // Round to nearest ATR level
    double level = MathRound(price / atr) * atr;
    return level;
}

//+------------------------------------------------------------------+
//| Find or Create ML Price Level                                    |
//+------------------------------------------------------------------+
int FindMLPriceLevel(double priceLevel, string signalPattern)
{
    if(!useML) return -1;
    
    for(int i = 0; i < mlPriceLevelCount; i++)
    {
        if(MathAbs(mlPriceLevels[i].priceLevel - priceLevel) < 0.0001 &&
           mlPriceLevels[i].signalPattern == signalPattern)
        {
            return i;
        }
    }
    
    // Create new ML level
    int index = mlPriceLevelCount;
    mlPriceLevelCount++;
    ArrayResize(mlPriceLevels, mlPriceLevelCount);
    
    mlPriceLevels[index].priceLevel = priceLevel;
    mlPriceLevels[index].signalPattern = signalPattern;
    mlPriceLevels[index].weight = 1.0;
    mlPriceLevels[index].totalProfit = 0;
    mlPriceLevels[index].tradeCount = 0;
    mlPriceLevels[index].successRate = 0.5;
    
    return index;
}

//+------------------------------------------------------------------+
//| Update ML Price Level with trade result                          |
//+------------------------------------------------------------------+
void UpdateMLPriceLevel(double price, string signals, double profit)
{
    if(!useML) return;
    
    double priceLevel = NormalizePriceToLevel(price);
    int index = FindMLPriceLevel(priceLevel, signals);
    
    if(index < 0) return;
    
    // Update statistics
    mlPriceLevels[index].totalProfit += profit;
    mlPriceLevels[index].tradeCount++;
    
    // Calculate success rate
    double wins = 0;
    if(profit > 0) wins = 1.0;
    
    // Exponential moving average for success rate
    double alpha = 0.1; // Learning rate
    mlPriceLevels[index].successRate = 
        mlPriceLevels[index].successRate * (1 - alpha) + wins * alpha;
    
    // Update weight based on profit and success rate
    double reward = (profit > 0 ? 1.0 : -1.0);
    mlPriceLevels[index].weight += mlLearningRate * reward * mlPriceLevels[index].successRate;
    
    // Clamp weight
    if(mlPriceLevels[index].weight < 0.1) mlPriceLevels[index].weight = 0.1;
    if(mlPriceLevels[index].weight > 2.0) mlPriceLevels[index].weight = 2.0;
    
    PrintFormat("📊 ML Price Level Updated: %.5f | Pattern: %s | Weight: %.3f | Success: %.1f%%", 
               priceLevel, signals, mlPriceLevels[index].weight, 
               mlPriceLevels[index].successRate * 100);
}

//+------------------------------------------------------------------+
//| Get ML confidence for current price and signals                  |
//+------------------------------------------------------------------+
double GetMLPriceConfidence(double price, string signals)
{
    if(!useML) return 1.0;
    
    double priceLevel = NormalizePriceToLevel(price);
    int index = FindMLPriceLevel(priceLevel, signals);
    
    if(index < 0) return 1.0; // No history, neutral confidence
    
    // Return combined confidence from weight and success rate
    return mlPriceLevels[index].weight * mlPriceLevels[index].successRate;
}

//+------------------------------------------------------------------+
//| POC & SUPPORT/RESISTANCE SYSTEM                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate POC (Point of Control) for timeframe                   |
//+------------------------------------------------------------------+
void CalculatePOC(ENUM_TIMEFRAMES tf)
{
    if(!usePOC) return;
    
    // Find existing POC for this timeframe
    int existingIndex = -1;
    for(int i = 0; i < pocLevelCount; i++)
    {
        if(pocLevels[i].timeframe == tf)
        {
            existingIndex = i;
            break;
        }
    }
    
    // Create price histogram (simplified Volume Profile)
    const int BINS = 50;  // Number of price bins
    double priceMin = DBL_MAX;
    double priceMax = -DBL_MAX;
    
    // Find price range
    for(int i = 0; i < pocLookback && i < Bars(_Symbol, tf); i++)
    {
        double high = iHigh(_Symbol, tf, i);
        double low = iLow(_Symbol, tf, i);
        
        if(high > priceMax) priceMax = high;
        if(low < priceMin) priceMin = low;
    }
    
    if(priceMax <= priceMin) return;
    
    double binSize = (priceMax - priceMin) / BINS;
    double volumeProfile[];
    ArrayResize(volumeProfile, BINS);
    ArrayInitialize(volumeProfile, 0);
    
    // Build volume profile
    for(int i = 0; i < pocLookback && i < Bars(_Symbol, tf); i++)
    {
        double close = iClose(_Symbol, tf, i);
        double volume = (double)iVolume(_Symbol, tf, i);
        
        // Find which bin this price belongs to
        int binIndex = (int)((close - priceMin) / binSize);
        if(binIndex < 0) binIndex = 0;
        if(binIndex >= BINS) binIndex = BINS - 1;
        
        volumeProfile[binIndex] += volume;
    }
    
    // Find POC (bin with highest volume)
    int pocBin = 0;
    double maxVolume = volumeProfile[0];
    for(int i = 1; i < BINS; i++)
    {
        if(volumeProfile[i] > maxVolume)
        {
            maxVolume = volumeProfile[i];
            pocBin = i;
        }
    }
    
    // Calculate POC price (center of bin)
    double pocPrice = priceMin + (pocBin + 0.5) * binSize;
    
    // Update or add POC level
    if(existingIndex >= 0)
    {
        pocLevels[existingIndex].pocPrice = pocPrice;
        pocLevels[existingIndex].pocVolume = maxVolume;
        pocLevels[existingIndex].calculatedTime = TimeCurrent();
        pocLevels[existingIndex].barCount = pocLookback;
    }
    else
    {
        if(pocLevelCount >= ArraySize(pocLevels))
            ArrayResize(pocLevels, pocLevelCount + 10);
        
        pocLevels[pocLevelCount].timeframe = tf;
        pocLevels[pocLevelCount].pocPrice = pocPrice;
        pocLevels[pocLevelCount].pocVolume = maxVolume;
        pocLevels[pocLevelCount].calculatedTime = TimeCurrent();
        pocLevels[pocLevelCount].barCount = pocLookback;
        pocLevelCount++;
    }
}

//+------------------------------------------------------------------+
//| Update all POC levels                                            |
//+------------------------------------------------------------------+
void UpdateAllPOC()
{
    if(!usePOC) return;
    
    // Parse POC timeframes
    string tfArray[];
    int tfCount = StringSplit(pocTimeframes, ',', tfArray);
    
    for(int i = 0; i < tfCount; i++)
    {
        ENUM_TIMEFRAMES tf = StringToTimeframe(tfArray[i]);
        if(tf != PERIOD_CURRENT)
            CalculatePOC(tf);
    }
}

//+------------------------------------------------------------------+
//| Check if price is near any POC level                             |
//+------------------------------------------------------------------+
bool IsNearPOC(double price, double &nearestPOC, ENUM_TIMEFRAMES &pocTF)
{
    if(!usePOC || pocLevelCount == 0) return false;
    
    double pip = GetPip();
    double proximityPrice = pocProximity * pip;
    double minDistance = DBL_MAX;
    int nearestIndex = -1;
    
    for(int i = 0; i < pocLevelCount; i++)
    {
        double distance = MathAbs(price - pocLevels[i].pocPrice);
        
        if(distance < proximityPrice && distance < minDistance)
        {
            minDistance = distance;
            nearestIndex = i;
        }
    }
    
    if(nearestIndex >= 0)
    {
        nearestPOC = pocLevels[nearestIndex].pocPrice;
        pocTF = pocLevels[nearestIndex].timeframe;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Support/Resistance levels for timeframe                   |
//+------------------------------------------------------------------+
void DetectSupportResistance(ENUM_TIMEFRAMES tf)
{
    if(!useSupportResistance) return;
    
    double pip = GetPip();
    double minDist = srMinDistance * pip;
    int bars = Bars(_Symbol, tf);
    if(bars < srSwingStrength * 3) return;
    
    // Detect Swing Highs and Lows
    for(int i = srSwingStrength; i < MathMin(bars - srSwingStrength, 200); i++)
    {
        double high = iHigh(_Symbol, tf, i);
        double low = iLow(_Symbol, tf, i);
        
        // Check for Swing High (Resistance)
        bool isSwingHigh = true;
        for(int j = 1; j <= srSwingStrength; j++)
        {
            if(iHigh(_Symbol, tf, i-j) >= high || iHigh(_Symbol, tf, i+j) >= high)
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh)
        {
            // Check if this level already exists
            bool exists = false;
            for(int k = 0; k < srLevelCount; k++)
            {
                if(srLevels[k].timeframe == tf && 
                   !srLevels[k].isSupport &&
                   MathAbs(srLevels[k].price - high) < minDist)
                {
                    // Update existing resistance
                    srLevels[k].touches++;
                    srLevels[k].lastTouch = iTime(_Symbol, tf, i);
                    srLevels[k].strength = MathMin(1.0, srLevels[k].touches / 5.0);
                    exists = true;
                    break;
                }
            }
            
            if(!exists)
            {
                // Add new resistance
                if(srLevelCount >= ArraySize(srLevels))
                    ArrayResize(srLevels, srLevelCount + 50);
                
                srLevels[srLevelCount].timeframe = tf;
                srLevels[srLevelCount].price = high;
                srLevels[srLevelCount].isSupport = false;
                srLevels[srLevelCount].touches = 1;
                srLevels[srLevelCount].strength = 0.2;
                srLevels[srLevelCount].lastTouch = iTime(_Symbol, tf, i);
                srLevels[srLevelCount].isActive = true;
                srLevelCount++;
            }
        }
        
        // Check for Swing Low (Support)
        bool isSwingLow = true;
        for(int j = 1; j <= srSwingStrength; j++)
        {
            if(iLow(_Symbol, tf, i-j) <= low || iLow(_Symbol, tf, i+j) <= low)
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow)
        {
            // Check if this level already exists
            bool exists = false;
            for(int k = 0; k < srLevelCount; k++)
            {
                if(srLevels[k].timeframe == tf && 
                   srLevels[k].isSupport &&
                   MathAbs(srLevels[k].price - low) < minDist)
                {
                    // Update existing support
                    srLevels[k].touches++;
                    srLevels[k].lastTouch = iTime(_Symbol, tf, i);
                    srLevels[k].strength = MathMin(1.0, srLevels[k].touches / 5.0);
                    exists = true;
                    break;
                }
            }
            
            if(!exists)
            {
                // Add new support
                if(srLevelCount >= ArraySize(srLevels))
                    ArrayResize(srLevels, srLevelCount + 50);
                
                srLevels[srLevelCount].timeframe = tf;
                srLevels[srLevelCount].price = low;
                srLevels[srLevelCount].isSupport = true;
                srLevels[srLevelCount].touches = 1;
                srLevels[srLevelCount].strength = 0.2;
                srLevels[srLevelCount].lastTouch = iTime(_Symbol, tf, i);
                srLevels[srLevelCount].isActive = true;
                srLevelCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update all Support/Resistance levels                             |
//+------------------------------------------------------------------+
void UpdateAllSupportResistance()
{
    if(!useSupportResistance) return;
    
    // Clear old levels
    srLevelCount = 0;
    ArrayResize(srLevels, 0);
    
    // Parse S/R timeframes
    string tfArray[];
    int tfCount = StringSplit(srTimeframes, ',', tfArray);
    
    for(int i = 0; i < tfCount; i++)
    {
        ENUM_TIMEFRAMES tf = StringToTimeframe(tfArray[i]);
        if(tf != PERIOD_CURRENT)
            DetectSupportResistance(tf);
    }
}

//+------------------------------------------------------------------+
//| Check if price is near Support or Resistance                     |
//+------------------------------------------------------------------+
bool IsNearSR(double price, bool isBuySignal, double &nearestSR, string &srType, double &srStrength)
{
    if(!useSupportResistance || srLevelCount == 0) return false;
    
    double pip = GetPip();
    double proximityPrice = srProximity * pip;
    double minDistance = DBL_MAX;
    int nearestIndex = -1;
    
    for(int i = 0; i < srLevelCount; i++)
    {
        if(!srLevels[i].isActive) continue;
        
        double distance = MathAbs(price - srLevels[i].price);
        
        // For BUY signals, look for Support below
        // For SELL signals, look for Resistance above
        bool isRelevant = false;
        if(isBuySignal && srLevels[i].isSupport && price >= srLevels[i].price)
            isRelevant = true;
        else if(!isBuySignal && !srLevels[i].isSupport && price <= srLevels[i].price)
            isRelevant = true;
        
        if(isRelevant && distance < proximityPrice && distance < minDistance)
        {
            minDistance = distance;
            nearestIndex = i;
        }
    }
    
    if(nearestIndex >= 0)
    {
        nearestSR = srLevels[nearestIndex].price;
        srType = srLevels[nearestIndex].isSupport ? "SUPPORT" : "RESISTANCE";
        srStrength = srLevels[nearestIndex].strength;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get proper filling mode for the symbol                            |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode(string symbol = NULL)
{
    if(symbol == NULL) symbol = _Symbol;
    
    // Get symbol filling modes
    int filling = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    
    // Check each filling mode flag
    // SYMBOL_FILLING_FOK = 1, SYMBOL_FILLING_IOC = 2
    if((filling & 1) == 1)  // FOK
        return ORDER_FILLING_FOK;
    else if((filling & 2) == 2)  // IOC
        return ORDER_FILLING_IOC;
    
    // Default to RETURN (most compatible)
    return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| ADVANCED HEDGE MODULE - Professional Hedge Functions             |
//+------------------------------------------------------------------+

// Calculate dynamic hedge ratio based on current P/L
double CalculateDynamicHedgeRatio(double currentPL, double balance)
{
    if(!useAdvancedHedge || hedgeStrategy != HEDGE_DYNAMIC) return hedgeRatio;
    
    double plPercent = (currentPL / balance) * 100.0;
    
    // More loss = higher hedge ratio to protect
    if(plPercent < -5.0) return hedgeRatio * 1.5;      // -5% loss → 150% hedge
    if(plPercent < -3.0) return hedgeRatio * 1.3;      // -3% loss → 130% hedge
    if(plPercent < -1.0) return hedgeRatio * 1.1;      // -1% loss → 110% hedge
    
    return hedgeRatio;  // Default ratio
}

// Calculate pyramid hedge lot for next level
double CalculatePyramidHedgeLot(int level, double baseLot)
{
    if(!usePyramidHedge || level <= 0) return baseLot;
    
    return baseLot * MathPow(pyramidMultiplier, level);
}

// Check if should open hedge position
bool ShouldOpenHedge(ENUM_POSITION_TYPE mainType)
{
    if(!useAdvancedHedge) return false;
    
    bool isLong = (mainType == POSITION_TYPE_BUY);
    
    // Don't open if already have hedge
    if(isLong && hedgeActiveLong) return false;
    if(!isLong && hedgeActiveShort) return false;
    
    // Calculate current P/L and pips
    double totalPL = 0;
    double totalPips = 0;
    int mainCount = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType != mainType) continue;
            
            mainCount++;
            totalPL += PositionGetDouble(POSITION_PROFIT);
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            if(isLong)
                totalPips += (currentPrice - openPrice) / pointSize / 10.0;
            else
                totalPips += (openPrice - currentPrice) / pointSize / 10.0;
        }
    }
    
    if(mainCount == 0) return false;
    
    double avgPips = totalPips / mainCount;
    
    // Strategy-specific triggers
    switch(hedgeStrategy)
    {
        case HEDGE_FIXED:
        case HEDGE_DYNAMIC:
            // Open hedge if losing X pips
            return (avgPips < -hedgeActivationPips);
            
        case HEDGE_PROFIT_LOCK:
            // Open hedge to lock profit
            if(useProfitLockHedge && totalPL > profitLockThreshold)
            {
                if(totalPL > maxProfitReached)
                    maxProfitReached = totalPL;
                    
                // Lock profit if dropped 50% from peak
                double drawdownFromPeak = maxProfitReached - totalPL;
                return (drawdownFromPeak > (profitLockThreshold * 0.5));
            }
            return false;
            
        case HEDGE_SL_PROTECT:
            // Open hedge when close to SL
            return (avgPips < -(hedgeActivationPips * 0.7));
            
        case HEDGE_BALANCE:
        {
            // Check if exposure is imbalanced
            int longCount = CountPositionsByType(POSITION_TYPE_BUY);
            int shortCount = CountPositionsByType(POSITION_TYPE_SELL);
            int imbalance = MathAbs(longCount - shortCount);
            return (imbalance >= 3);  // 3+ position difference
        }
            
        default:
            return (avgPips < -hedgeActivationPips);
    }
    
    return false;
}

// Open hedge position
bool OpenHedgePosition(ENUM_POSITION_TYPE mainType)
{
    if(!useAdvancedHedge) return false;
    
    bool isLong = (mainType == POSITION_TYPE_BUY);
    ENUM_POSITION_TYPE hedgeType = isLong ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
    
    // Calculate main position exposure
    double mainLots = 0;
    ulong mainTicket = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType == mainType)
            {
                mainLots += PositionGetDouble(POSITION_VOLUME);
                if(mainTicket == 0)
                    mainTicket = PositionGetTicket(i);
            }
        }
    }
    
    if(mainLots <= 0) return false;
    
    // Calculate hedge lot
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Calculate total P/L for dynamic ratio
    double currentPL = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            currentPL += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    double dynamicRatio = CalculateDynamicHedgeRatio(currentPL, balance);
    
    double hedgeLot = mainLots * dynamicRatio;
    
    // Apply partial hedge
    if(usePartialHedge)
        hedgeLot *= (partialHedgePercent / 100.0);
    
    // Pyramid hedge
    int hedgeCount = isLong ? hedgeCountLong : hedgeCountShort;
    if(usePyramidHedge && hedgeCount > 0)
        hedgeLot = CalculatePyramidHedgeLot(hedgeCount, hedgeLot);
    
    hedgeLot = NormalizeLot(hedgeLot);
    hedgeLot = MathMin(hedgeLot, maxLotSize);
    
    if(hedgeLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return false;
    
    // Open hedge
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = hedgeLot;
    request.type = hedgeType == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = hedgeType == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = StringFormat("HEDGE_%s_L%d", isLong ? "LONG" : "SHORT", hedgeCount + 1);
    request.type_filling = GetFillingMode(_Symbol);
    
    // Add TP if enabled
    if(useHedgeTP && useTakeProfit)
    {
        double hedgeTpPips = slPips * rr;  // Calculate TP pips from SL and RR
        double hedgeTP = request.price;
        double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        if(hedgeType == POSITION_TYPE_BUY)
            hedgeTP += hedgeTpPips * 10 * pointSize * hedgeTPMultiplier;
        else
            hedgeTP -= hedgeTpPips * 10 * pointSize * hedgeTPMultiplier;
            
        request.tp = hedgeTP;
    }
    
    if(!OrderSend(request, result))
    {
        PrintFormat("❌ Hedge open failed: %d - %s", result.retcode, result.comment);
        return false;
    }
    
    // Track hedge position
    if(isLong)
    {
        ArrayResize(hedgePositionsLong, hedgeCountLong + 1);
        hedgePositionsLong[hedgeCountLong].ticket = result.order;
        hedgePositionsLong[hedgeCountLong].mainTicket = mainTicket;
        hedgePositionsLong[hedgeCountLong].type = hedgeType;
        hedgePositionsLong[hedgeCountLong].lots = hedgeLot;
        hedgePositionsLong[hedgeCountLong].openPrice = request.price;
        hedgePositionsLong[hedgeCountLong].pyramidLevel = hedgeCountLong;
        hedgePositionsLong[hedgeCountLong].openTime = TimeCurrent();
        hedgePositionsLong[hedgeCountLong].isProfitLock = (hedgeStrategy == HEDGE_PROFIT_LOCK);
        hedgeCountLong++;
        hedgeActiveLong = true;
    }
    else
    {
        ArrayResize(hedgePositionsShort, hedgeCountShort + 1);
        hedgePositionsShort[hedgeCountShort].ticket = result.order;
        hedgePositionsShort[hedgeCountShort].mainTicket = mainTicket;
        hedgePositionsShort[hedgeCountShort].type = hedgeType;
        hedgePositionsShort[hedgeCountShort].lots = hedgeLot;
        hedgePositionsShort[hedgeCountShort].openPrice = request.price;
        hedgePositionsShort[hedgeCountShort].pyramidLevel = hedgeCountShort;
        hedgePositionsShort[hedgeCountShort].openTime = TimeCurrent();
        hedgePositionsShort[hedgeCountShort].isProfitLock = (hedgeStrategy == HEDGE_PROFIT_LOCK);
        hedgeCountShort++;
        hedgeActiveShort = true;
    }
    
    PrintFormat("🛡️ HEDGE %s opened | Lot: %.2f | Ratio: %.1f%% | Strategy: %s | Level: %d", 
               isLong ? "SHORT" : "LONG", hedgeLot, dynamicRatio * 100, 
               EnumToString(hedgeStrategy), isLong ? hedgeCountLong : hedgeCountShort);
    
    return true;
}

// Close all hedge positions for a side
void CloseHedgePositions(bool isLong)
{
    if(!useAdvancedHedge) return;
    
    int hedgeCount = isLong ? hedgeCountLong : hedgeCountShort;
    if(hedgeCount == 0) return;
    
    double totalHedgePL = 0;
    ENUM_POSITION_TYPE hedgeType = isLong ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
    
    // Close all hedge positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType != hedgeType) continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, "HEDGE") < 0) continue;
            
            totalHedgePL += PositionGetDouble(POSITION_PROFIT);
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = hedgeType == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = hedgeType == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            request.deviation = 10;
            request.magic = MagicNumber;
            request.position = PositionGetTicket(i);
            request.type_filling = GetFillingMode(_Symbol);
            
            OrderSend(request, result);
        }
    }
    
    // Reset hedge tracking
    if(isLong)
    {
        ArrayResize(hedgePositionsLong, 0);
        hedgeCountLong = 0;
        hedgeActiveLong = false;
    }
    else
    {
        ArrayResize(hedgePositionsShort, 0);
        hedgeCountShort = 0;
        hedgeActiveShort = false;
    }
    
    PrintFormat("🛡️ All HEDGE %s closed | P/L: $%.2f", isLong ? "SHORT" : "LONG", totalHedgePL);
}

// Update hedge positions status
void UpdateHedgePositions()
{
    if(!useAdvancedHedge) return;
    
    // Check if main positions are closed
    int longMain = 0, shortMain = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, "HEDGE") >= 0) continue;  // Skip hedge positions
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_BUY)
                longMain++;
            else
                shortMain++;
        }
    }
    
    // Auto-close hedge if main positions are closed
    if(autoCloseHedge)
    {
        if(longMain == 0 && hedgeActiveLong)
            CloseHedgePositions(true);
            
        if(shortMain == 0 && hedgeActiveShort)
            CloseHedgePositions(false);
    }
}

//+------------------------------------------------------------------+
//| HEDGE REDUCTION MECHANISM - Smart Hedge Management               |
//+------------------------------------------------------------------+

// Calculate combined P/L of main + hedge positions
double CalculateCombinedPL(bool isLong)
{
    double mainPL = 0, hedgePL = 0;
    ENUM_POSITION_TYPE mainType = isLong ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    ENUM_POSITION_TYPE hedgeType = isLong ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            string comment = PositionGetString(POSITION_COMMENT);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(StringFind(comment, "HEDGE") >= 0)
            {
                if(posType == hedgeType)
                    hedgePL += profit;
            }
            else
            {
                if(posType == mainType)
                    mainPL += profit;
            }
        }
    }
    
    return mainPL + hedgePL;
}

// Check if should reduce hedge (close partially or fully)
bool ShouldReduceHedge(bool isLong)
{
    if(!useHedgeReduction) return false;
    if(isLong && !hedgeActiveLong) return false;
    if(!isLong && !hedgeActiveShort) return false;
    
    int hedgeCount = isLong ? hedgeCountLong : hedgeCountShort;
    if(hedgeCount == 0) return false;
    
    // Calculate hedge P/L
    double hedgePL = 0;
    double mainPL = 0;
    ENUM_POSITION_TYPE hedgeType = isLong ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
    ENUM_POSITION_TYPE mainType = isLong ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    
    datetime oldestHedgeTime = TimeCurrent();
    int hedgeBars = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            string comment = PositionGetString(POSITION_COMMENT);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(StringFind(comment, "HEDGE") >= 0 && posType == hedgeType)
            {
                hedgePL += profit;
                datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
                if(openTime < oldestHedgeTime)
                    oldestHedgeTime = openTime;
            }
            else if(posType == mainType)
            {
                mainPL += profit;
            }
        }
    }
    
    // Calculate hedge duration
    hedgeBars = (int)((TimeCurrent() - oldestHedgeTime) / PeriodSeconds());
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double hedgePLPercent = (hedgePL / balance) * 100.0;
    double combinedPL = mainPL + hedgePL;
    double combinedPLPercent = (combinedPL / balance) * 100.0;
    
    // 1. Hedge Profit Target - Hedge đang profit
    if(useSmartHedgeClose && hedgePLPercent >= hedgeProfitTarget)
    {
        PrintFormat("🎯 Hedge REDUCTION trigger: Profit Target | Hedge PL: %.2f%% (Target: %.1f%%)", 
                   hedgePLPercent, hedgeProfitTarget);
        return true;
    }
    
    // 2. Breakeven Close - Tổng P/L gần 0
    if(useBreakevenHedge && MathAbs(combinedPLPercent) <= breakevenThreshold)
    {
        PrintFormat("⚖️ Hedge REDUCTION trigger: Breakeven | Combined PL: %.2f%% (Threshold: %.1f%%)", 
                   combinedPLPercent, breakevenThreshold);
        return true;
    }
    
    // 3. Correlation Close - Cả main và hedge đều profit
    if(useCorrelationClose && mainPL > 0 && hedgePL > 0)
    {
        PrintFormat("🔄 Hedge REDUCTION trigger: Both Profitable | Main: $%.2f, Hedge: $%.2f", 
                   mainPL, hedgePL);
        return true;
    }
    
    // 4. Time-based Reduction - Giữ quá lâu
    if(useTimeReduction)
    {
        double hedgeHours = (TimeCurrent() - oldestHedgeTime) / 3600.0;
        if(hedgeHours >= maxHedgeHours)
        {
            PrintFormat("⏰ Hedge REDUCTION trigger: Max Duration | Duration: %.1f hours (Max: %d)", 
                       hedgeHours, maxHedgeHours);
            return true;
        }
    }
    
    // 5. Min bars check - Không reduce quá sớm
    if(hedgeBars < minHedgeBars)
        return false;
    
    return false;
}

// Reduce hedge positions (partial or full)
void ReduceHedgePositions(bool isLong)
{
    if(!useHedgeReduction) return;
    
    int hedgeCount = isLong ? hedgeCountLong : hedgeCountShort;
    if(hedgeCount == 0) return;
    
    ENUM_POSITION_TYPE hedgeType = isLong ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
    
    // Collect hedge positions
    ulong hedgeTickets[];
    double hedgeLots[];
    double totalHedgePL = 0;
    int count = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            string comment = PositionGetString(POSITION_COMMENT);
            
            if(StringFind(comment, "HEDGE") >= 0 && posType == hedgeType)
            {
                ArrayResize(hedgeTickets, count + 1);
                ArrayResize(hedgeLots, count + 1);
                hedgeTickets[count] = PositionGetTicket(i);
                hedgeLots[count] = PositionGetDouble(POSITION_VOLUME);
                totalHedgePL += PositionGetDouble(POSITION_PROFIT);
                count++;
            }
        }
    }
    
    if(count == 0) return;
    
    // Decide: Partial or Full reduction
    int positionsToClose = count;
    
    if(usePartialReduction)
    {
        // Close only X% of hedge positions
        positionsToClose = (int)MathCeil(count * (reductionPercent / 100.0));
        if(positionsToClose < 1) positionsToClose = 1;
    }
    
    // Close hedge positions (LIFO - Last In First Out)
    int closedCount = 0;
    double closedPL = 0;
    
    for(int i = count - 1; i >= 0 && closedCount < positionsToClose; i--)
    {
        if(PositionSelectByTicket(hedgeTickets[i]))
        {
            closedPL += PositionGetDouble(POSITION_PROFIT);
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = hedgeLots[i];
            request.type = hedgeType == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = hedgeType == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            request.deviation = 10;
            request.magic = MagicNumber;
            request.position = hedgeTickets[i];
            request.type_filling = GetFillingMode(_Symbol);
            
            if(OrderSend(request, result))
            {
                closedCount++;
            }
        }
    }
    
    // Update tracking
    if(isLong)
    {
        hedgeTotalProfitLong += closedPL;
        hedgeReductionCountLong++;
        lastReductionTimeLong = TimeCurrent();
        hedgeCountLong -= closedCount;
        
        if(hedgeCountLong == 0)
        {
            ArrayResize(hedgePositionsLong, 0);
            hedgeActiveLong = false;
        }
    }
    else
    {
        hedgeTotalProfitShort += closedPL;
        hedgeReductionCountShort++;
        lastReductionTimeShort = TimeCurrent();
        hedgeCountShort -= closedCount;
        
        if(hedgeCountShort == 0)
        {
            ArrayResize(hedgePositionsShort, 0);
            hedgeActiveShort = false;
        }
    }
    
    string reductionType = (closedCount == count) ? "FULL" : "PARTIAL";
    
    PrintFormat("📉 Hedge %s REDUCTION | %s: Closed %d/%d positions | P/L: $%.2f | Total Hedge Profit: $%.2f", 
               isLong ? "SHORT" : "LONG", reductionType, closedCount, count, 
               closedPL, isLong ? hedgeTotalProfitLong : hedgeTotalProfitShort);
}

// Check and execute hedge reduction
void CheckHedgeReduction()
{
    if(!useHedgeReduction || !useAdvancedHedge) return;
    
    // Check LONG side hedges (SHORT positions)
    if(hedgeActiveLong && ShouldReduceHedge(true))
    {
        ReduceHedgePositions(true);
    }
    
    // Check SHORT side hedges (LONG positions)
    if(hedgeActiveShort && ShouldReduceHedge(false))
    {
        ReduceHedgePositions(false);
    }
}

//+------------------------------------------------------------------+
//| Add signal weight entry                                          |
//+------------------------------------------------------------------+
void AddSignalWeight(string name)
{
    int index = signalWeightCount;
    signalWeightCount++;
    ArrayResize(signalWeights, signalWeightCount);
    
    signalWeights[index].name = name;
    signalWeights[index].weight = 1.0;  // Will be normalized later
    signalWeights[index].total_profit = 0;
    signalWeights[index].trade_count = 0;
}

//+------------------------------------------------------------------+
//| Initialize multi-timeframe indicator handles                     |
//+------------------------------------------------------------------+
bool InitMTFIndicator(string timeframesStr, MTFHandles &mtf, string indicatorType)
{
    string tfArray[];
    int count = StringSplit(timeframesStr, ',', tfArray);
    
    if(count == 0) return false;
    
    ArrayResize(mtf.handles, count);
    ArrayResize(mtf.timeframes, count);
    mtf.count = 0;
    
    for(int i = 0; i < count; i++)
    {
        ENUM_TIMEFRAMES tf = StringToTimeframe(tfArray[i]);
        int handle = INVALID_HANDLE;
        
        if(indicatorType == "RSI")
        {
            handle = iRSI(_Symbol, tf, length_rsi, PRICE_CLOSE);
        }
        else if(indicatorType == "EMA_FAST")
        {
            handle = iMA(_Symbol, tf, ema_fast, 0, MODE_EMA, PRICE_CLOSE);
        }
        else if(indicatorType == "EMA_SLOW")
        {
            handle = iMA(_Symbol, tf, ema_slow, 0, MODE_EMA, PRICE_CLOSE);
        }
        else if(indicatorType == "MACD")
        {
            handle = iMACD(_Symbol, tf, macd_fast, macd_slow, macd_signal, PRICE_CLOSE);
        }
        else if(indicatorType == "BB")
        {
            handle = iBands(_Symbol, tf, bb_period, 0, bb_deviation, PRICE_CLOSE);
        }
        
        if(handle == INVALID_HANDLE)
        {
            PrintFormat("❌ Failed to create %s handle for %s", indicatorType, TimeframeToString(tf));
            return false;
        }
        
        mtf.handles[mtf.count] = handle;
        mtf.timeframes[mtf.count] = tf;
        mtf.count++;
        
        // Add weight for this signal
        string signalName = indicatorType + "_" + TimeframeToString(tf);
        AddSignalWeight(signalName);
        
        PrintFormat("✅ Initialized %s on %s", indicatorType, TimeframeToString(tf));
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Normalize all signal weights                                     |
//+------------------------------------------------------------------+
void NormalizeAllSignalWeights()
{
    if(signalWeightCount == 0) return;
    
    double sum = 0;
    for(int i = 0; i < signalWeightCount; i++)
        sum += signalWeights[i].weight;
    
    if(sum > 0)
    {
        for(int i = 0; i < signalWeightCount; i++)
            signalWeights[i].weight /= sum;
    }
    
    // Clamp weights to [0.01, 0.50] to prevent single signal dominance
    for(int i = 0; i < signalWeightCount; i++)
    {
        if(signalWeights[i].weight < 0.01) signalWeights[i].weight = 0.01;
        if(signalWeights[i].weight > 0.50) signalWeights[i].weight = 0.50;
    }
}

//+------------------------------------------------------------------+
//| Find signal weight index by name                                 |
//+------------------------------------------------------------------+
int FindSignalWeightIndex(string name)
{
    for(int i = 0; i < signalWeightCount; i++)
    {
        if(signalWeights[i].name == name)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Update signal weight based on profit                             |
//+------------------------------------------------------------------+
void UpdateSignalWeight(string signalName, double profit)
{
    if(!useML) return;
    
    int index = FindSignalWeightIndex(signalName);
    if(index < 0) return;
    
    // Normalize profit as reward (-1 to +1)
    double reward = profit > 0 ? 1.0 : -1.0;
    
    // Update weight
    signalWeights[index].weight += mlLearningRate * reward;
    signalWeights[index].total_profit += profit;
    signalWeights[index].trade_count++;
    
    // Normalize all weights
    NormalizeAllSignalWeights();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize signal weights array
    ArrayResize(signalWeights, 0);
    signalWeightCount = 0;
    
    // Initialize multi-timeframe indicators
    if(use_RSI)
    {
        if(!InitMTFIndicator(rsi_timeframes, rsiMTF, "RSI"))
        {
            PrintFormat("Failed to initialize RSI MTF");
            return(INIT_FAILED);
        }
    }
    
    if(use_EMA)
    {
        if(!InitMTFIndicator(ema_timeframes, emaFastMTF, "EMA_FAST"))
        {
            PrintFormat("Failed to initialize EMA Fast MTF");
            return(INIT_FAILED);
        }
        if(!InitMTFIndicator(ema_timeframes, emaSlowMTF, "EMA_SLOW"))
        {
            PrintFormat("Failed to initialize EMA Slow MTF");
            return(INIT_FAILED);
        }
    }
    
    if(use_MACD)
    {
        if(!InitMTFIndicator(macd_timeframes, macdMTF, "MACD"))
        {
            PrintFormat("Failed to initialize MACD MTF");
            return(INIT_FAILED);
        }
    }
    
    if(use_BB)
    {
        if(!InitMTFIndicator(bb_timeframes, bbMTF, "BB"))
        {
            PrintFormat("Failed to initialize BB MTF");
            return(INIT_FAILED);
        }
    }
    
    // Always create ATR with specified timeframe
    atrTF = StringToTimeframe(atr_timeframe);
    atrHandle = iATR(_Symbol, atrTF, atr_len);
    if(atrHandle == INVALID_HANDLE)
    {
        PrintFormat("Failed to create ATR handle");
        return(INIT_FAILED);
    }
    PrintFormat("✅ ATR initialized on %s", TimeframeToString(atrTF));
    
    // Normalize all signal weights
    if(signalWeightCount > 0)
    {
        NormalizeAllSignalWeights();
        PrintFormat("📊 Initialized %d MTF signals with ML tracking", signalWeightCount);
        
        // Print initial weights
        if(useML)
        {
            PrintFormat("🤖 ML enabled - Initial equal weights:");
            for(int i = 0; i < signalWeightCount; i++)
            {
                PrintFormat("   %s: %.4f", signalWeights[i].name, signalWeights[i].weight);
            }
        }
    }
    
    // Initialize risk management
    currentLotSize = lotSize;
    lastLotSize = lotSize;
    consecutiveLosses = 0;
    fibIndex = 0;
    
    // Initialize Smart DCA System
    if(useSmartDCA)
    {
        dcaDistance = CalculateAutoDCADistance();
        ArrayResize(priceZonesLong, 0);
        ArrayResize(priceZonesShort, 0);
        zoneCountLong = 0;
        zoneCountShort = 0;
        
        PrintFormat("🎯 Smart DCA System initialized:");
        PrintFormat("   Auto DCA: %s", autoDCALevels ? "YES" : "NO");
        PrintFormat("   DCA Distance: %.1f pips (%.5f)", dcaDistance / GetPip(), dcaDistance);
        PrintFormat("   Zone Tolerance: ±%.0f%%", zoneTolerance * 100);
        PrintFormat("   Skip Existing Zones: %s", skipExistingZones ? "YES" : "NO");
    }
    
    // Initialize ML Price-based Learning
    if(useML)
    {
        ArrayResize(mlPriceLevels, 0);
        mlPriceLevelCount = 0;
        PrintFormat("🤖 ML Price-based Learning enabled");
        PrintFormat("   Learning per candle price level with signal patterns");
    }
    
    // Initialize Advanced Hedge
    if(useAdvancedHedge)
    {
        ArrayResize(hedgePositionsLong, 0);
        ArrayResize(hedgePositionsShort, 0);
        hedgeCountLong = 0;
        hedgeCountShort = 0;
        totalHedgeLots = 0;
        lastHedgeCheckTime = 0;
        maxProfitReached = 0;
        hedgeActiveLong = false;
        hedgeActiveShort = false;
        
        // Initialize Hedge Reduction
        hedgeTotalProfitLong = 0;
        hedgeTotalProfitShort = 0;
        hedgeReductionCountLong = 0;
        hedgeReductionCountShort = 0;
        lastReductionTimeLong = 0;
        lastReductionTimeShort = 0;
    }
    
    // Print configuration
    PrintFormat("=== QuantumRSI v4.0 - Smart DCA + ML ===");
    PrintFormat("Trading Mode: SINGLE_DIRECTION with Smart DCA");
    
    string indicators = "";
    if(use_RSI) indicators += StringFormat("RSI(%d TFs) ", rsiMTF.count);
    if(use_EMA) indicators += StringFormat("EMA(%d TFs) ", emaFastMTF.count);
    if(use_MACD) indicators += StringFormat("MACD(%d TFs) ", macdMTF.count);
    if(use_BB) indicators += StringFormat("BB(%d TFs) ", bbMTF.count);
    PrintFormat("Active Indicators: %s", indicators);
    
    string riskModeStr = "FIXED";
    if(riskMode == MARTINGALE) riskModeStr = "MARTINGALE";
    else if(riskMode == FIBONACCI) riskModeStr = "FIBONACCI";
    else if(riskMode == ALGORITHMIC) riskModeStr = "ALGORITHMIC";
    PrintFormat("Risk Mode: %s, Base Lot: %.2f, Max Lot: %.2f", riskModeStr, lotSize, maxLotSize);
    
    string tpslModeStr = "PIPS_RR";
    if(tpSlMode == ATR_PIPS) tpslModeStr = "ATR_PIPS";
    else if(tpSlMode == TRAILING_STOP) tpslModeStr = "TRAILING_STOP";
    else if(tpSlMode == TRAILING_ATR) tpslModeStr = "TRAILING_ATR";
    PrintFormat("TP/SL Mode: %s | ATR TF: %s", tpslModeStr, TimeframeToString(atrTF));
    
    // Smart DCA System Config
    if(useSmartDCA)
    {
        PrintFormat("🎯 === SMART DCA SYSTEM ===");
        if(autoDCALevels)
            PrintFormat("   ⚡ Auto DCA Levels: YES (ATR × %.1f)", dcaATRMultiplier);
        else
            PrintFormat("   📊 Manual DCA Levels: %d", manualDCALevels);
        PrintFormat("   � Skip Existing Zones: %s (Tolerance: %.0f%%)", 
                   skipExistingZones ? "YES" : "NO", zoneTolerance * 100);
        PrintFormat("   � DCA Range: %.0f - %.0f pips", dcaMinDistance, dcaMaxDistance);
        PrintFormat("   🔢 Max DCA Positions: %d", maxDCAPositions);
    }
    
    // Advanced Hedge Module Config
    if(useAdvancedHedge)
    {
        PrintFormat("🛡️ === ADVANCED HEDGE MODULE ===");
        PrintFormat("   Strategy: %s", EnumToString(hedgeStrategy));
        PrintFormat("   Base Ratio: %.1f%% | Activation: %.0f pips", hedgeRatio * 100, hedgeActivationPips);
        PrintFormat("   Partial Hedge: %s (%.0f%%)", usePartialHedge ? "YES" : "NO", partialHedgePercent);
        if(usePyramidHedge)
            PrintFormat("   📊 Pyramid: %d levels × %.2fx", pyramidLevels, pyramidMultiplier);
        if(useProfitLockHedge)
            PrintFormat("   💰 Profit Lock: $%.2f threshold", profitLockThreshold);
        PrintFormat("   Auto-Close: %s | Hedge TP: %s (%.1fx)", 
                   autoCloseHedge ? "YES" : "NO", useHedgeTP ? "YES" : "NO", hedgeTPMultiplier);
        
        // Hedge Reduction Config
        if(useHedgeReduction)
        {
            PrintFormat("   📉 Hedge Reduction: ACTIVE");
            if(useSmartHedgeClose)
                PrintFormat("      • Profit Target: %.1f%%", hedgeProfitTarget);
            if(useBreakevenHedge)
                PrintFormat("      • Breakeven: %.1f%% threshold", breakevenThreshold);
            if(useCorrelationClose)
                PrintFormat("      • Correlation Close: YES");
            if(usePartialReduction)
                PrintFormat("      • Partial Reduction: %.0f%% each time", reductionPercent);
            if(useTimeReduction)
                PrintFormat("      • Max Duration: %d hours", maxHedgeHours);
            PrintFormat("      • Min Bars: %d", minHedgeBars);
        }
    }
    
    PrintFormat("Max Open Positions: %d", maxOpenPositions);
    
    // Initialize POC & Support/Resistance
    if(usePOC || useSupportResistance)
    {
        PrintFormat("🎯 === POC & SUPPORT/RESISTANCE ===");
        
        if(usePOC)
        {
            ArrayResize(pocLevels, 0);
            pocLevelCount = 0;
            UpdateAllPOC();
            PrintFormat("   📊 POC Active | TFs: %s | Lookback: %d bars | Proximity: %.0f pips", 
                       pocTimeframes, pocLookback, pocProximity);
            PrintFormat("   Detected %d POC levels", pocLevelCount);
        }
        
        if(useSupportResistance)
        {
            ArrayResize(srLevels, 0);
            srLevelCount = 0;
            UpdateAllSupportResistance();
            PrintFormat("   📏 S/R Active | TFs: %s | Swing: %d bars | Proximity: %.0f pips", 
                       srTimeframes, srSwingStrength, srProximity);
            PrintFormat("   Detected %d S/R levels", srLevelCount);
        }
        
        if(useMLBoost)
            PrintFormat("   🚀 ML Boost: %.1fx when near POC/S/R", mlBoostMultiplier);
    }
    
    // Initialize News Filter
    if(newsFilter != NEWS_OFF)
    {
        ArrayResize(upcomingNews, 100);
        newsCount = 0;
        lastNewsCheck = 0;
        
        string filterMode = (newsFilter == NEWS_HIGH_ONLY) ? "HIGH IMPACT ONLY" : "ALL NEWS";
        PrintFormat("News Filter: ENABLED (%s) | Buffer: %d min before, %d min after", 
                   filterMode, newsMinutesBefore, newsMinutesAfter);
        PrintFormat("Monitoring currencies: %s", newsCurrency);
    }
    else
    {
        PrintFormat("News Filter: DISABLED");
    }
    
    // Recover bot state from trading history (NO FILES!)
    if(useHistoryRecovery)
    {
        PrintFormat("� === HISTORY-BASED STATE RECOVERY ===");
        PrintFormat("   Magic Number: %d", MagicNumber);
        PrintFormat("   Analysis Period: Last %d days", historyDays);
        
        RecoverStateFromHistory();
        RecoverOpenPositionsState();
    }
    else
    {
        PrintFormat("💾 State Persistence: DISABLED");
    }
    
    PrintFormat("=== Ready to trade ===");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release all MTF handles
    for(int i = 0; i < rsiMTF.count; i++)
        if(rsiMTF.handles[i] != INVALID_HANDLE) IndicatorRelease(rsiMTF.handles[i]);
    
    for(int i = 0; i < emaFastMTF.count; i++)
        if(emaFastMTF.handles[i] != INVALID_HANDLE) IndicatorRelease(emaFastMTF.handles[i]);
    
    for(int i = 0; i < emaSlowMTF.count; i++)
        if(emaSlowMTF.handles[i] != INVALID_HANDLE) IndicatorRelease(emaSlowMTF.handles[i]);
    
    for(int i = 0; i < macdMTF.count; i++)
        if(macdMTF.handles[i] != INVALID_HANDLE) IndicatorRelease(macdMTF.handles[i]);
    
    for(int i = 0; i < bbMTF.count; i++)
        if(bbMTF.handles[i] != INVALID_HANDLE) IndicatorRelease(bbMTF.handles[i]);
    
    if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
    
    // Print final ML statistics
    if(useML && signalWeightCount > 0)
    {
        PrintFormat("=== Final ML Statistics ===");
        for(int i = 0; i < signalWeightCount; i++)
        {
            if(signalWeights[i].trade_count > 0)
            {
                double avgProfit = signalWeights[i].total_profit / signalWeights[i].trade_count;
                PrintFormat("%s: Weight=%.4f | Trades=%d | Avg Profit=%.2f", 
                           signalWeights[i].name, signalWeights[i].weight, 
                           signalWeights[i].trade_count, avgProfit);
            }
        }
    }
    
    // Save bot state before shutdown
    // No need to save state - history-based recovery handles everything!
    PrintFormat("EA stopped. Reason: %d | Total MTF signals tracked: %d", reason, signalWeightCount);
}

//+------------------------------------------------------------------+
//| Get MTF indicator value                                          |
//+------------------------------------------------------------------+
double GetMTFValue(int handle, int buffer, int shift)
{
    if(handle == INVALID_HANDLE) return EMPTY_VALUE;
    
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(handle, buffer, shift, 1, buf) != 1)
        return EMPTY_VALUE;
    
    return buf[0];
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double GetATR(int shift)
{
    if(atrHandle == INVALID_HANDLE) return EMPTY_VALUE;
    
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(atrHandle, 0, shift, 1, buf) != 1)
        return EMPTY_VALUE;
    
    return buf[0];
}

//+------------------------------------------------------------------+
//| Universal pip size                                                |
//+------------------------------------------------------------------+
double GetPip()
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(point <= 0) return point;
    
    double mintick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    int denom = (int)MathRound(1.0 / mintick);
    
    if(denom >= 100000) return 0.0001;
    if(denom >= 10000)  return 0.0001;
    if(denom >= 1000)   return 0.1;
    if(denom >= 100)    return 0.01;
    
    return (mintick > 0 ? mintick : point);
}

//+------------------------------------------------------------------+
//| Check if currency is in monitoring list                          |
//+------------------------------------------------------------------+
bool IsCurrencyMonitored(string currency)
{
    if(newsFilter == NEWS_OFF) return false;
    
    string currencies[];
    int count = StringSplit(newsCurrency, ',', currencies);
    
    for(int i = 0; i < count; i++)
    {
        if(StringFind(currency, currencies[i]) >= 0)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if we're in news blackout period                           |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
    if(newsFilter == NEWS_OFF) return false;
    
    datetime currentTime = TimeCurrent();
    int bufferBefore = newsMinutesBefore * 60;
    int bufferAfter = newsMinutesAfter * 60;
    
    for(int i = 0; i < newsCount; i++)
    {
        if(upcomingNews[i].time + bufferAfter < currentTime)
            continue;
        
        bool shouldBlock = false;
        if(newsFilter == NEWS_HIGH_ONLY && upcomingNews[i].impact >= 3)
            shouldBlock = true;
        else if(newsFilter == NEWS_ALL && upcomingNews[i].impact >= 1)
            shouldBlock = true;
        
        if(!shouldBlock) continue;
        
        if(!IsCurrencyMonitored(upcomingNews[i].currency))
            continue;
        
        datetime newsStart = upcomingNews[i].time - bufferBefore;
        datetime newsEnd = upcomingNews[i].time + bufferAfter;
        
        if(currentTime >= newsStart && currentTime <= newsEnd)
        {
            int minutesUntil = (int)((upcomingNews[i].time - currentTime) / 60);
            if(minutesUntil >= 0)
            {
                PrintFormat("🚫 NEWS BLOCK: %s in %d minutes (%s)", 
                           upcomingNews[i].title, minutesUntil, upcomingNews[i].currency);
            }
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check multi-timeframe buy signal                                 |
//+------------------------------------------------------------------+
bool IsBuySignal(string &activeSignals)
{
    double signalScore = 0;
    double totalWeight = 0;
    activeSignals = "";
    
    // RSI Multi-Timeframe Signals
    if(use_RSI)
    {
        for(int i = 0; i < rsiMTF.count; i++)
        {
            double rsi_prev = GetMTFValue(rsiMTF.handles[i], 0, 1);
            double rsi_now = GetMTFValue(rsiMTF.handles[i], 0, 0);
            
            if(rsi_prev != EMPTY_VALUE && rsi_now != EMPTY_VALUE)
            {
                string signalName = "RSI_" + TimeframeToString(rsiMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(rsi_prev > rsi_entry && rsi_now <= rsi_entry)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    // EMA Multi-Timeframe Signals
    if(use_EMA)
    {
        for(int i = 0; i < emaFastMTF.count; i++)
        {
            double ema_fast_prev = GetMTFValue(emaFastMTF.handles[i], 0, 1);
            double ema_slow_prev = GetMTFValue(emaSlowMTF.handles[i], 0, 1);
            double ema_fast_now = GetMTFValue(emaFastMTF.handles[i], 0, 0);
            double ema_slow_now = GetMTFValue(emaSlowMTF.handles[i], 0, 0);
            
            if(ema_fast_prev != EMPTY_VALUE && ema_slow_prev != EMPTY_VALUE &&
               ema_fast_now != EMPTY_VALUE && ema_slow_now != EMPTY_VALUE)
            {
                string signalName = "EMA_FAST_" + TimeframeToString(emaFastMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    // MACD Multi-Timeframe Signals
    if(use_MACD)
    {
        for(int i = 0; i < macdMTF.count; i++)
        {
            double macd_main_prev = GetMTFValue(macdMTF.handles[i], 0, 1);
            double macd_signal_prev = GetMTFValue(macdMTF.handles[i], 1, 1);
            double macd_main_now = GetMTFValue(macdMTF.handles[i], 0, 0);
            double macd_signal_now = GetMTFValue(macdMTF.handles[i], 1, 0);
            
            if(macd_main_prev != EMPTY_VALUE && macd_signal_prev != EMPTY_VALUE &&
               macd_main_now != EMPTY_VALUE && macd_signal_now != EMPTY_VALUE)
            {
                string signalName = "MACD_" + TimeframeToString(macdMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(macd_main_prev <= macd_signal_prev && macd_main_now > macd_signal_now)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    // Bollinger Bands Multi-Timeframe Signals
    if(use_BB)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        for(int i = 0; i < bbMTF.count; i++)
        {
            double bb_lower = GetMTFValue(bbMTF.handles[i], 2, 0);
            
            if(bb_lower != EMPTY_VALUE)
            {
                string signalName = "BB_" + TimeframeToString(bbMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(price <= bb_lower * 1.001)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    if(totalWeight == 0) return false;
    
    double score = signalScore / totalWeight;
    
    // 🚀 POC & S/R BOOST - Enhance signals near key levels
    if(useMLBoost && score >= signalThreshold * 0.8) // At least 80% of threshold
    {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        // Check POC proximity
        double nearestPOC = 0;
        ENUM_TIMEFRAMES pocTF = PERIOD_CURRENT;
        if(IsNearPOC(currentPrice, nearestPOC, pocTF))
        {
            score *= mlBoostMultiplier;
            activeSignals += StringFormat("POC_%s ", TimeframeToString(pocTF));
            PrintFormat("🎯 POC BOOST: Price %.5f near POC %.5f (%s) | Score: %.1f%% → %.1f%%",
                       currentPrice, nearestPOC, TimeframeToString(pocTF),
                       (signalScore / totalWeight) * 100, score * 100);
        }
        
        // Check S/R proximity
        double nearestSR = 0;
        string srType = "";
        double srStrength = 0;
        if(IsNearSR(currentPrice, true, nearestSR, srType, srStrength)) // true = BUY signal
        {
            double srBoost = 1.0 + (mlBoostMultiplier - 1.0) * srStrength;
            score *= srBoost;
            activeSignals += StringFormat("SR_%s_%.0f ", srType, srStrength * 100);
            PrintFormat("🎯 S/R BOOST: Price %.5f near %s %.5f (Strength %.0f%%) | Score: %.1f%% → %.1f%%",
                       currentPrice, srType, nearestSR, srStrength * 100,
                       (signalScore / totalWeight) * 100, score * 100);
        }
    }
    
    // Update consecutive bars counter
    if(score >= signalThreshold)
    {
        consecutiveBuyBars++;
        lastBuyScore = score;
    }
    else
    {
        consecutiveBuyBars = 0;
        lastBuyScore = 0;
    }
    
    // Require minimum confirmation bars
    bool confirmed = (consecutiveBuyBars >= minConfirmBars);
    
    // Debug logging
    if(score >= signalThreshold)
    {
        PrintFormat("🔍 BUY Analysis: Score=%.4f / Total=%.4f = %.1f%% | Consecutive=%d/%d | Active: %s | Confirmed: %s", 
                   signalScore, totalWeight, score * 100, consecutiveBuyBars, minConfirmBars,
                   activeSignals, confirmed ? "YES" : "WAIT");
    }
    
    return confirmed;
}

//+------------------------------------------------------------------+
//| Check multi-timeframe sell signal                                |
//+------------------------------------------------------------------+
bool IsSellSignal(string &activeSignals)
{
    double signalScore = 0;
    double totalWeight = 0;
    activeSignals = "";
    
    // RSI Multi-Timeframe Signals
    if(use_RSI)
    {
        for(int i = 0; i < rsiMTF.count; i++)
        {
            double rsi_prev = GetMTFValue(rsiMTF.handles[i], 0, 1);
            double rsi_now = GetMTFValue(rsiMTF.handles[i], 0, 0);
            
            if(rsi_prev != EMPTY_VALUE && rsi_now != EMPTY_VALUE)
            {
                string signalName = "RSI_" + TimeframeToString(rsiMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(rsi_prev < rsi_exit && rsi_now >= rsi_exit)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    // EMA Multi-Timeframe Signals
    if(use_EMA)
    {
        for(int i = 0; i < emaFastMTF.count; i++)
        {
            double ema_fast_prev = GetMTFValue(emaFastMTF.handles[i], 0, 1);
            double ema_slow_prev = GetMTFValue(emaSlowMTF.handles[i], 0, 1);
            double ema_fast_now = GetMTFValue(emaFastMTF.handles[i], 0, 0);
            double ema_slow_now = GetMTFValue(emaSlowMTF.handles[i], 0, 0);
            
            if(ema_fast_prev != EMPTY_VALUE && ema_slow_prev != EMPTY_VALUE &&
               ema_fast_now != EMPTY_VALUE && ema_slow_now != EMPTY_VALUE)
            {
                string signalName = "EMA_FAST_" + TimeframeToString(emaFastMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    // MACD Multi-Timeframe Signals
    if(use_MACD)
    {
        for(int i = 0; i < macdMTF.count; i++)
        {
            double macd_main_prev = GetMTFValue(macdMTF.handles[i], 0, 1);
            double macd_signal_prev = GetMTFValue(macdMTF.handles[i], 1, 1);
            double macd_main_now = GetMTFValue(macdMTF.handles[i], 0, 0);
            double macd_signal_now = GetMTFValue(macdMTF.handles[i], 1, 0);
            
            if(macd_main_prev != EMPTY_VALUE && macd_signal_prev != EMPTY_VALUE &&
               macd_main_now != EMPTY_VALUE && macd_signal_now != EMPTY_VALUE)
            {
                string signalName = "MACD_" + TimeframeToString(macdMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(macd_main_prev >= macd_signal_prev && macd_main_now < macd_signal_now)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    // Bollinger Bands Multi-Timeframe Signals
    if(use_BB)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        for(int i = 0; i < bbMTF.count; i++)
        {
            double bb_upper = GetMTFValue(bbMTF.handles[i], 1, 0);
            
            if(bb_upper != EMPTY_VALUE)
            {
                string signalName = "BB_" + TimeframeToString(bbMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Check if signal fires
                    if(price >= bb_upper * 0.999)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        totalWeight += signalWeights[weightIndex].weight; // ✅ Only add when signal fires
                        activeSignals += signalName + " ";
                    }
                }
            }
        }
    }
    
    if(totalWeight == 0) return false;
    
    double score = signalScore / totalWeight;
    
    // 🚀 POC & S/R BOOST - Enhance signals near key levels
    if(useMLBoost && score >= signalThreshold * 0.8) // At least 80% of threshold
    {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Check POC proximity
        double nearestPOC = 0;
        ENUM_TIMEFRAMES pocTF = PERIOD_CURRENT;
        if(IsNearPOC(currentPrice, nearestPOC, pocTF))
        {
            score *= mlBoostMultiplier;
            activeSignals += StringFormat("POC_%s ", TimeframeToString(pocTF));
            PrintFormat("🎯 POC BOOST: Price %.5f near POC %.5f (%s) | Score: %.1f%% → %.1f%%",
                       currentPrice, nearestPOC, TimeframeToString(pocTF),
                       (signalScore / totalWeight) * 100, score * 100);
        }
        
        // Check S/R proximity
        double nearestSR = 0;
        string srType = "";
        double srStrength = 0;
        if(IsNearSR(currentPrice, false, nearestSR, srType, srStrength)) // false = SELL signal
        {
            double srBoost = 1.0 + (mlBoostMultiplier - 1.0) * srStrength;
            score *= srBoost;
            activeSignals += StringFormat("SR_%s_%.0f ", srType, srStrength * 100);
            PrintFormat("🎯 S/R BOOST: Price %.5f near %s %.5f (Strength %.0f%%) | Score: %.1f%% → %.1f%%",
                       currentPrice, srType, nearestSR, srStrength * 100,
                       (signalScore / totalWeight) * 100, score * 100);
        }
    }
    
    // Update consecutive bars counter
    if(score >= signalThreshold)
    {
        consecutiveSellBars++;
        lastSellScore = score;
    }
    else
    {
        consecutiveSellBars = 0;
        lastSellScore = 0;
    }
    
    // Require minimum confirmation bars
    bool confirmed = (consecutiveSellBars >= minConfirmBars);
    
    // Debug logging
    if(score >= signalThreshold)
    {
        PrintFormat("🔍 SELL Analysis: Score=%.4f / Total=%.4f = %.1f%% | Consecutive=%d/%d | Active: %s | Confirmed: %s", 
                   signalScore, totalWeight, score * 100, consecutiveSellBars, minConfirmBars,
                   activeSignals, confirmed ? "YES" : "WAIT");
    }
    
    return confirmed;
}

//+------------------------------------------------------------------+
//| Calculate SL & TP                                                 |
//+------------------------------------------------------------------+
void CalcSLTP_fromEntry(double entryPrice, bool isLong, double atrAtEntry, double &outSL, double &outTP)
{
    outSL = 0;
    outTP = 0;
    double pip = GetPip();

    if(atrAtEntry <= 0 || atrAtEntry == EMPTY_VALUE) 
        atrAtEntry = GetATR(0);

    if(useStopLoss)
    {
        if(tpSlMode == ATR_PIPS || tpSlMode == TRAILING_ATR)
        {
            // ATR-based SL
            if(isLong)
                outSL = entryPrice - atrAtEntry * atr_mult_sl;
            else
                outSL = entryPrice + atrAtEntry * atr_mult_sl;
        }
        else
        {
            // Pips-based SL
            if(isLong)
                outSL = entryPrice - slPips * pip;
            else
                outSL = entryPrice + slPips * pip;
        }
            
        outSL = NormalizeDouble(outSL, _Digits);
    }
    
    if(useTakeProfit)
    {
        if(tpSlMode == TRAILING_STOP || tpSlMode == TRAILING_ATR)
        {
            // Trailing mode - no fixed TP, will trail dynamically
            outTP = 0;
        }
        else if(tpSlMode == PIPS_RR)
        {
            // Risk:Reward ratio
            if(isLong)
                outTP = entryPrice + slPips * pip * rr;
            else
                outTP = entryPrice - slPips * pip * rr;
            outTP = NormalizeDouble(outTP, _Digits);
        }
        else if(tpSlMode == ATR_PIPS)
        {
            // ATR-based TP
            if(isLong)
                outTP = entryPrice + atrAtEntry * atr_mult_tp;
            else
                outTP = entryPrice - atrAtEntry * atr_mult_tp;
            outTP = NormalizeDouble(outTP, _Digits);
        }
    }
}

//+------------------------------------------------------------------+
//| Get Fibonacci number                                              |
//+------------------------------------------------------------------+
int GetFibonacci(int index)
{
    if(index <= 0) return 1;
    if(index == 1) return 1;
    if(index == 2) return 2;
    if(index == 3) return 3;
    if(index == 4) return 5;
    if(index == 5) return 8;
    if(index == 6) return 13;
    if(index == 7) return 21;
    if(index == 8) return 34;
    if(index == 9) return 55;
    return 89;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk mode                            |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double calculatedLot = lotSize;
     switch(riskMode)
     {
         case FIXED:
             calculatedLot = lotSize;
             break;
             
         case MARTINGALE:
             if(consecutiveLosses > 0)
                 calculatedLot = lastLotSize * martingaleMultiplier;
             else
                 calculatedLot = lotSize;
             break;
             
         case FIBONACCI:
             if(consecutiveLosses > 0)
             {
                 int fibMultiplier = GetFibonacci(fibIndex);
                 calculatedLot = lotSize * fibMultiplier;
             }
             else
             {
                 calculatedLot = lotSize;
                 fibIndex = 0;
             }
             break;
             
         case ALGORITHMIC:
         {
             double balance = AccountInfoDouble(ACCOUNT_BALANCE);
             double riskAmount = balance * (riskPercent / 100.0);
             double pip = GetPip();
             double slDistance = slPips * pip;
             
             if(slDistance > 0)
             {
                 double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                 double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                 
                 if(tickValue > 0 && tickSize > 0)
                 {
                     double moneyPerLot = (slDistance / tickSize) * tickValue;
                     if(moneyPerLot > 0)
                         calculatedLot = riskAmount / moneyPerLot;
                 }
             }
             
             if(calculatedLot < 0.01) calculatedLot = 0.01;
             break;
         }
    }
    
    if(calculatedLot > maxLotSize)
        calculatedLot = maxLotSize;
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(calculatedLot < minLot) calculatedLot = minLot;
    if(calculatedLot > maxLot) calculatedLot = maxLot;
    
    calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
    calculatedLot = NormalizeDouble(calculatedLot, 2);
    
    return calculatedLot;
}

//+------------------------------------------------------------------+
//| Update risk management                                            |
//+------------------------------------------------------------------+
void UpdateRiskManagement(bool wasWin)
{
    if(wasWin)
    {
        consecutiveLosses = 0;
        fibIndex = 0;
        lastLotSize = lotSize;
        totalWins++;  // Tăng số giao dịch thắng
    }
    else
    {
        consecutiveLosses++;
        fibIndex++;
        if(fibIndex > 9) fibIndex = 9;
        totalLosses++;  // Tăng số giao dịch thua
    }
}

//+------------------------------------------------------------------+
//| Count open positions                                              |
//+------------------------------------------------------------------+
int CountPositionsByType(ENUM_POSITION_TYPE posType)
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == posType)
                count++;
        }
    }
    return count;
}

int CountOpenPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Normalize lot size to valid range                                 |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    lot = MathFloor(lot / lotStep) * lotStep;
    
    return lot;
}

bool MaxPositionsReached()
{
    return (CountOpenPositions() >= maxOpenPositions);
}

//+------------------------------------------------------------------+
//| HISTORY-BASED STATE RECOVERY (NO FILES - ZERO DISK USAGE!)      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Recover bot state from MT5 trading history                       |
//+------------------------------------------------------------------+
void RecoverStateFromHistory()
{
    if(!useHistoryRecovery) 
    {
        PrintFormat("ℹ️ History recovery disabled, starting fresh");
        return;
    }
    
    // Select history period
    datetime from = TimeCurrent() - (historyDays * 24 * 60 * 60);
    datetime to = TimeCurrent();
    
    if(!HistorySelect(from, to))
    {
        PrintFormat("⚠️ Failed to load history");
        return;
    }
    
    PrintFormat("🔍 Analyzing %d days of trading history...", historyDays);
    
    int totalDeals = HistoryDealsTotal();
    int recoveredTrades = 0;
    double totalProfit = 0;
    int winCount = 0, lossCount = 0;
    int consecutiveLossCount = 0;
    bool countingLosses = true;
    
    // Track recent trades for consecutive loss calculation
    double recentProfits[20];
    int recentCount = 0;
    
    // Analyze deals from newest to oldest
    for(int i = totalDeals - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        // Filter by magic number and symbol
        long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
        if(dealMagic != MagicNumber) continue;
        
        string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
        if(dealSymbol != _Symbol) continue;
        
        // Only process exit deals
        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(dealEntry != DEAL_ENTRY_OUT) continue;
        
        // Calculate net profit
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
        double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        double netProfit = profit + swap + commission;
        
        totalProfit += netProfit;
        recoveredTrades++;
        
        // Count wins/losses
        if(netProfit > 0)
        {
            winCount++;
            if(countingLosses) countingLosses = false;
        }
        else if(netProfit < 0)
        {
            lossCount++;
            if(countingLosses) consecutiveLossCount++;
        }
        
        // Store recent profits
        if(recentCount < 20)
        {
            recentProfits[recentCount++] = netProfit;
        }
        
        // Update last trade time
        datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        if(dealTime > lastTradeTime)
            lastTradeTime = dealTime;
    }
    
    // Update global win/loss counters
    totalWins = winCount;
    totalLosses = lossCount;
    consecutiveLosses = consecutiveLossCount;
    
    // Display recovery summary
    if(recoveredTrades > 0)
    {
        double winRate = (recoveredTrades > 0) ? (double)winCount / recoveredTrades * 100.0 : 0;
        PrintFormat("✅ Recovered %d trades | Wins: %d | Losses: %d | Win Rate: %.1f%% | Total P/L: $%.2f",
                   recoveredTrades, winCount, lossCount, winRate, totalProfit);
        PrintFormat("📊 Consecutive Losses: %d | Last Trade: %s", 
                   consecutiveLossCount, TimeToString(lastTradeTime));
    }
    else
    {
        PrintFormat("ℹ️ No historical trades found for this EA");
    }
}

//+------------------------------------------------------------------+
//| Recover current open positions state                             |
//+------------------------------------------------------------------+
void RecoverOpenPositionsState()
{
    if(!useHistoryRecovery) return;
    
    int longCount = 0, shortCount = 0;
    int hedgeLongCount = 0, hedgeShortCount = 0;
    int gridLongCount = 0, gridShortCount = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            string comment = PositionGetString(POSITION_COMMENT);
            
            // Identify position type by comment
            if(StringFind(comment, "HEDGE") >= 0)
            {
                if(posType == POSITION_TYPE_BUY)
                    hedgeLongCount++;
                else
                    hedgeShortCount++;
            }
            else if(StringFind(comment, "GRID") >= 0 || StringFind(comment, "L") >= 0)
            {
                if(posType == POSITION_TYPE_BUY)
                    gridLongCount++;
                else
                    gridShortCount++;
            }
            else
            {
                if(posType == POSITION_TYPE_BUY)
                    longCount++;
                else
                    shortCount++;
            }
        }
    }
    
    // Update hedge flags
    if(useAdvancedHedge)
    {
        if(hedgeLongCount > 0)
        {
            hedgeActiveLong = true;
            hedgeCountLong = hedgeLongCount;
        }
        if(hedgeShortCount > 0)
        {
            hedgeActiveShort = true;
            hedgeCountShort = hedgeShortCount;
        }
    }
    
    PrintFormat("📊 Recovered positions: Regular L=%d/S=%d, Hedge L=%d/S=%d, Grid L=%d/S=%d",
               longCount, shortCount, hedgeLongCount, hedgeShortCount, gridLongCount, gridShortCount);
}

//+------------------------------------------------------------------+
//| Close positions                                                   |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE typeToClose = -1)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                if(typeToClose != -1 && posType != typeToClose)
                    continue;
                
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = _Symbol;
                request.volume = PositionGetDouble(POSITION_VOLUME);
                request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                request.price = (request.type == ORDER_TYPE_SELL) ? 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                request.deviation = 10;
                request.type_filling = GetFillingMode(_Symbol);
                
                OrderSend(request, result);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open position                                                     |
//+------------------------------------------------------------------+
void OpenPosition(bool isLong, string signals)
{
    double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Smart DCA: Check if should skip due to existing zone
    if(useSmartDCA && skipExistingZones)
    {
        if(ShouldSkipSignalDueToZone(price, isLong))
        {
            return; // Skip this signal
        }
    }
    
    // ML Price Confidence Check
    double mlConfidence = GetMLPriceConfidence(price, signals);
    if(useML && mlConfidence < 0.3)
    {
        PrintFormat("⚠️ ML Low Confidence (%.2f) at price %.5f - Signal skipped", 
                   mlConfidence, price);
        return;
    }
    
    double atrAtEntry = GetATR(0);
    double sl, tp;
    CalcSLTP_fromEntry(price, isLong, atrAtEntry, sl, tp);
    
    currentLotSize = CalculateLotSize();
    
    // Apply ML confidence to lot size
    if(useML && mlConfidence > 0)
    {
        currentLotSize = currentLotSize * MathMin(mlConfidence, 1.5);
        currentLotSize = NormalizeLot(currentLotSize);
    }
    
    lastLotSize = currentLotSize;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = currentLotSize;
    request.type = isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    
    string comment = "";
    if(tradingMode == HEDGE)
        comment = isLong ? "Hedge Long" : "Hedge Short";
    else
        comment = isLong ? "Single Long" : "Single Short";
        
    request.comment = comment;
    request.type_filling = GetFillingMode(_Symbol);
    
    if(OrderSend(request, result))
    {
        string slStr = useStopLoss ? StringFormat("%.5f", sl) : "None";
        string tpStr = useTakeProfit ? StringFormat("%.5f", tp) : "None";
        
        double mlConf = GetMLPriceConfidence(price, signals);
        PrintFormat("%s ENTRY: Lot=%.2f, Price=%.5f, SL=%s, TP=%s | ML Conf: %.2f | Signals: %s", 
                   comment, currentLotSize, price, slStr, tpStr, mlConf, signals);
        
        // Smart DCA: Create or update price zone
        if(useSmartDCA)
        {
            int zoneIndex = FindPriceZone(price, isLong);
            if(zoneIndex < 0)
            {
                // Create new zone
                zoneIndex = CreatePriceZone(price, isLong, signals);
                PrintFormat("📍 New Price Zone created at %.5f", price);
            }
            
            // Update zone with new position
            UpdatePriceZone(zoneIndex, isLong, currentLotSize);
        }
        
    }
    else
    {
        PrintFormat("%s order failed: %d - %s", comment, result.retcode, result.comment);
    }
}

//+------------------------------------------------------------------+
//| Main tick handler                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, _Period, 0);
    
    if(currentBar == lastBar) return;
    lastBar = currentBar;
    
    if(IsNewsTime()) return;
    
    // Update POC & S/R periodically (every new bar)
    static datetime lastPOCUpdate = 0;
    if(TimeCurrent() - lastPOCUpdate > 3600) // Update every hour
    {
        if(usePOC) UpdateAllPOC();
        if(useSupportResistance) UpdateAllSupportResistance();
        lastPOCUpdate = TimeCurrent();
    }
    
    // AUTO CLOSE ALL SYSTEM - Check first before any trading logic
    if(useAutoCloseAll)
    {
        CheckAutoCloseAll();
    }
    
    // Check cooldown period
    if(lastTradeTime > 0)
    {
        int barsSinceLastTrade = Bars(_Symbol, _Period, lastTradeTime, currentBar);
        if(barsSinceLastTrade < cooldownBars)
        {
            // Reset counters during cooldown
            consecutiveBuyBars = 0;
            consecutiveSellBars = 0;
            return;
        }
    }
    
    string buySignals = "";
    string sellSignals = "";
    bool buy_signal = IsBuySignal(buySignals);
    bool sell_signal = IsSellSignal(sellSignals);
    
    int longPositions = CountPositionsByType(POSITION_TYPE_BUY);
    int shortPositions = CountPositionsByType(POSITION_TYPE_SELL);
    
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(tradingMode == HEDGE)
    {
        if(enableBuy && buy_signal && !MaxPositionsReached())
        {
            PrintFormat("📈 BUY CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastBuyScore * 100, consecutiveBuyBars, buySignals);
            lastActiveSignals = buySignals;  // Store for ML update
            OpenPosition(true, buySignals);
            lastTradeTime = currentBar;
            consecutiveBuyBars = 0;  // Reset after trade
        }
        
        if(enableSell && sell_signal && !MaxPositionsReached())
        {
            PrintFormat("📉 SELL CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastSellScore * 100, consecutiveSellBars, sellSignals);
            lastActiveSignals = sellSignals;  // Store for ML update
            OpenPosition(false, sellSignals);
            lastTradeTime = currentBar;
            consecutiveSellBars = 0;  // Reset after trade
        }
        
        // Advanced Hedge Module for HEDGE mode
        if(useAdvancedHedge)
        {
            UpdateHedgePositions();
            
            int longMain = CountPositionsByType(POSITION_TYPE_BUY);
            int shortMain = CountPositionsByType(POSITION_TYPE_SELL);
            
            // Check hedge for existing positions
            if(longMain > 0 && !hedgeActiveLong && ShouldOpenHedge(POSITION_TYPE_BUY))
                OpenHedgePosition(POSITION_TYPE_BUY);
                
            if(shortMain > 0 && !hedgeActiveShort && ShouldOpenHedge(POSITION_TYPE_SELL))
                OpenHedgePosition(POSITION_TYPE_SELL);
            
            // Hedge Reduction
            CheckHedgeReduction();
        }
    }
    /* GRID MODE REMOVED - Using Smart DCA instead
    else if(tradingMode == GRID)
    {
        ... Grid code removed ...
    }
    */
    
    // Apply Trailing Stop if enabled
    if(tpSlMode == TRAILING_STOP || tpSlMode == TRAILING_ATR)
    {
        ManageTrailingStops();
    }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stops                                            |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
    double pip = GetPip();
    double atr = GetATR(0);
    if(atr == EMPTY_VALUE) atr = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                             SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        bool isLong = (posType == POSITION_TYPE_BUY);
        double profitPips = 0;
        
        if(isLong)
            profitPips = (currentPrice - entryPrice) / pip;
        else
            profitPips = (entryPrice - currentPrice) / pip;
        
        // Check if profit reached trailing start threshold
        double trailingStartPips = trailingStart;
        if(tpSlMode == TRAILING_ATR && atr > 0)
            trailingStartPips = (atr / pip) * trailingATRMult;
        
        if(profitPips < trailingStartPips) continue;
        
        // Calculate new trailing SL
        double newSL = 0;
        double trailingDistance = trailingStep * pip;
        
        if(tpSlMode == TRAILING_ATR && atr > 0)
            trailingDistance = atr * trailingATRMult;
        
        if(isLong)
        {
            newSL = currentPrice - trailingDistance;
            
            // Only move SL up (never down)
            if(currentSL > 0 && newSL <= currentSL) continue;
            if(newSL <= entryPrice) newSL = entryPrice + pip;  // Keep at breakeven minimum
        }
        else
        {
            newSL = currentPrice + trailingDistance;
            
            // Only move SL down (never up)
            if(currentSL > 0 && newSL >= currentSL) continue;
            if(newSL >= entryPrice) newSL = entryPrice - pip;  // Keep at breakeven minimum
        }
        
        newSL = NormalizeDouble(newSL, _Digits);
        
        // Modify position
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = _Symbol;
        request.sl = newSL;
        request.tp = PositionGetDouble(POSITION_TP);
        request.type_filling = GetFillingMode(_Symbol);
        
        if(OrderSend(request, result))
        {
            PrintFormat("🔄 Trailing SL updated | Ticket: %d | New SL: %.5f | Profit: %.1f pips", 
                       ticket, newSL, profitPips);
        }
    }
    
    // No periodic saves needed - history-based recovery!
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.symbol == _Symbol)
        {
            ulong dealTicket = trans.deal;
            if(HistoryDealSelect(dealTicket))
            {
                long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
                double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                
                if((dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) && dealProfit != 0)
                {
                    double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                    bool wasWin = (dealProfit > 0);
                    
                    // Update ML Price-based Learning (NEW!)
                    if(useML && lastActiveSignals != "")
                    {
                        UpdateMLPriceLevel(dealPrice, lastActiveSignals, dealProfit);
                    }
                    
                    // Update Smart DCA Zone
                    if(useSmartDCA && dealProfit != 0)
                    {
                        bool isLong = (dealType == DEAL_TYPE_BUY);
                        int zoneIndex = FindPriceZone(dealPrice, isLong);
                        
                        if(zoneIndex >= 0)
                        {
                            if(isLong)
                            {
                                priceZonesLong[zoneIndex].positionCount--;
                                priceZonesLong[zoneIndex].totalProfit += dealProfit;
                                priceZonesLong[zoneIndex].tradeCount++;
                                
                                // Update win rate
                                int wins = wasWin ? 1 : 0;
                                if(priceZonesLong[zoneIndex].tradeCount > 0)
                                {
                                    priceZonesLong[zoneIndex].winRate = 
                                        (priceZonesLong[zoneIndex].winRate * (priceZonesLong[zoneIndex].tradeCount - 1) + wins) / 
                                        priceZonesLong[zoneIndex].tradeCount;
                                }
                                
                                PrintFormat("📊 Zone %.5f updated | Pos: %d | WinRate: %.1f%% | P/L: $%.2f", 
                                           priceZonesLong[zoneIndex].price,
                                           priceZonesLong[zoneIndex].positionCount,
                                           priceZonesLong[zoneIndex].winRate * 100,
                                           priceZonesLong[zoneIndex].totalProfit);
                            }
                            else
                            {
                                priceZonesShort[zoneIndex].positionCount--;
                                priceZonesShort[zoneIndex].totalProfit += dealProfit;
                                priceZonesShort[zoneIndex].tradeCount++;
                                
                                int wins = wasWin ? 1 : 0;
                                if(priceZonesShort[zoneIndex].tradeCount > 0)
                                {
                                    priceZonesShort[zoneIndex].winRate = 
                                        (priceZonesShort[zoneIndex].winRate * (priceZonesShort[zoneIndex].tradeCount - 1) + wins) / 
                                        priceZonesShort[zoneIndex].tradeCount;
                                }
                                
                                PrintFormat("📊 Zone %.5f updated | Pos: %d | WinRate: %.1f%% | P/L: $%.2f", 
                                           priceZonesShort[zoneIndex].price,
                                           priceZonesShort[zoneIndex].positionCount,
                                           priceZonesShort[zoneIndex].winRate * 100,
                                           priceZonesShort[zoneIndex].totalProfit);
                            }
                        }
                    }
                    
                    // Update ML weights for ONLY active signals
                    if(useML && signalWeightCount > 0 && lastActiveSignals != "")
                    {
                        mlTradeCounter++;
                        
                        // Parse active signals and update only those
                        string activeSignalArray[];
                        int count = StringSplit(lastActiveSignals, ' ', activeSignalArray);
                        
                        PrintFormat("🔄 Updating ML for %d active signals: %s", count, lastActiveSignals);
                        
                        for(int i = 0; i < count; i++)
                        {
                            if(activeSignalArray[i] != "")
                            {
                                UpdateSignalWeight(activeSignalArray[i], dealProfit);
                            }
                        }
                        
                        // Log every 10 trades
                        if(mlTradeCounter % 10 == 0)
                        {
                            PrintFormat("🤖 ML Update #%d | Top 5 signals:", mlTradeCounter);
                            
                            // Create copy for sorting
                            SignalWeight sorted[];
                            ArrayResize(sorted, signalWeightCount);
                            for(int i = 0; i < signalWeightCount; i++)
                                sorted[i] = signalWeights[i];
                            
                            // Sort by weight (descending)
                            for(int i = 0; i < MathMin(5, signalWeightCount); i++)
                            {
                                int maxIdx = i;
                                for(int j = i + 1; j < signalWeightCount; j++)
                                {
                                    if(sorted[j].weight > sorted[maxIdx].weight)
                                        maxIdx = j;
                                }
                                
                                if(maxIdx != i)
                                {
                                    SignalWeight temp = sorted[i];
                                    sorted[i] = sorted[maxIdx];
                                    sorted[maxIdx] = temp;
                                }
                                
                                if(sorted[i].trade_count > 0)
                                {
                                    double avgProfit = sorted[i].total_profit / sorted[i].trade_count;
                                    PrintFormat("   #%d: %s | Weight=%.4f (%.1f%%) | Trades=%d | Avg=%.2f", 
                                               i+1, sorted[i].name, sorted[i].weight, sorted[i].weight * 100,
                                               sorted[i].trade_count, avgProfit);
                                }
                                else
                                {
                                    PrintFormat("   #%d: %s | Weight=%.4f (%.1f%%) | No trades yet", 
                                               i+1, sorted[i].name, sorted[i].weight, sorted[i].weight * 100);
                                }
                            }
                        }
                        
                        // Clear after update
                        lastActiveSignals = "";
                    }
                    
                    UpdateRiskManagement(wasWin);
                    
                    if(wasWin)
                    {
                        PrintFormat("✅ Trade CLOSED with PROFIT: %.2f", dealProfit);
                    }
                    else
                    {
                        PrintFormat("❌ Trade CLOSED with LOSS: %.2f | Losses: %d", 
                                   dealProfit, consecutiveLosses);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Display Advanced Hedge Info on Chart                             |
//+------------------------------------------------------------------+
void DisplayHedgeInfo()
{
    if(!useAdvancedHedge) return;
    
    string info = "\n🛡️ ADVANCED HEDGE MODULE\n";
    info += "━━━━━━━━━━━━━━━━━━━━━━━━\n";
    info += StringFormat("Strategy: %s\n", EnumToString(hedgeStrategy));
    
    if(hedgeActiveLong)
    {
        info += StringFormat("LONG Hedges: %d levels\n", hedgeCountLong);
        double totalHedgeLotLong = 0;
        for(int i = 0; i < hedgeCountLong; i++)
            totalHedgeLotLong += hedgePositionsLong[i].lots;
        info += StringFormat("  Total Lot: %.2f\n", totalHedgeLotLong);
    }
    
    if(hedgeActiveShort)
    {
        info += StringFormat("SHORT Hedges: %d levels\n", hedgeCountShort);
        double totalHedgeLotShort = 0;
        for(int i = 0; i < hedgeCountShort; i++)
            totalHedgeLotShort += hedgePositionsShort[i].lots;
        info += StringFormat("  Total Lot: %.2f\n", totalHedgeLotShort);
    }
    
    if(!hedgeActiveLong && !hedgeActiveShort)
        info += "Status: Monitoring...\n";
    
    if(useProfitLockHedge && maxProfitReached > 0)
        info += StringFormat("Max Profit: $%.2f\n", maxProfitReached);
    
    Comment(info);
}

//+------------------------------------------------------------------+
//| AUTO CLOSE ALL SYSTEM - Tự động đóng tất cả positions            |
//+------------------------------------------------------------------+
void CheckAutoCloseAll()
{
    // Đếm tổng số positions và tính P/L
    int totalPositions = 0;
    double totalProfit = 0.0;
    double totalLoss = 0.0;
    datetime oldestOpenTime = TimeCurrent();
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        string posSymbol = PositionGetString(POSITION_SYMBOL);
        long posMagic = PositionGetInteger(POSITION_MAGIC);
        
        if(posSymbol != _Symbol) continue;
        if(posMagic != MagicNumber) continue;
        
        totalPositions++;
        
        // Tính P/L bao gồm swap và commission
        double posProfit = PositionGetDouble(POSITION_PROFIT);
        double posSwap = PositionGetDouble(POSITION_SWAP);
        double netPL = posProfit + posSwap;
        
        if(netPL > 0)
            totalProfit += netPL;
        else
            totalLoss += netPL;
        
        // Track oldest position
        datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
        if(posTime < oldestOpenTime)
            oldestOpenTime = posTime;
    }
    
    // Nếu không có position thì skip
    if(totalPositions == 0) return;
    
    double netProfit = totalProfit + totalLoss;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatingPercent = (balance > 0) ? (netProfit / balance) * 100.0 : 0;
    
    bool shouldClose = false;
    string reason = "";
    
    // 1. ĐÓNG KHI CÓ PROFIT (tự động - không cần set %)
    if(closeOnProfitTarget && netProfit > 0)
    {
        // Strategy A: Đóng khi có bất kỳ profit nào (aggressive)
        if(profitTargetDollar <= 1.0 && profitTargetPercent <= 0.1)
        {
            shouldClose = true;
            reason = StringFormat("💰 AUTO CLOSE ALL: Any Profit = $%.2f (+%.2f%%) | Positions: %d", 
                                 netProfit, floatingPercent, totalPositions);
        }
        // Strategy B: Đóng khi đạt profit target cụ thể
        else if(netProfit >= profitTargetDollar || floatingPercent >= profitTargetPercent)
        {
            shouldClose = true;
            reason = StringFormat("💰 PROFIT TARGET: $%.2f (+%.2f%%) | Positions: %d | Target: $%.2f or +%.2f%%", 
                                 netProfit, floatingPercent, totalPositions, profitTargetDollar, profitTargetPercent);
        }
    }
    
    // 2. ĐÓNG KHI DRAWDOWN QUÁ LỚN (bảo vệ tài khoản)
    if(closeOnDrawdown && netProfit < 0)
    {
        double drawdownPercent = MathAbs(floatingPercent);
        if(drawdownPercent >= maxDrawdownPercent)
        {
            shouldClose = true;
            reason = StringFormat("🛑 MAX DRAWDOWN: $%.2f (-%.2f%%) | Positions: %d | Limit: -%.2f%%", 
                                 netProfit, drawdownPercent, totalPositions, maxDrawdownPercent);
        }
    }
    
    // 3. ĐÓNG KHI GẦN BREAKEVEN (tự động - không để lãi biến thành lỗ)
    if(closeOnBreakeven && !shouldClose)
    {
        // Nếu đang có profit nhỏ (gần breakeven), đóng luôn để bảo vệ
        if(netProfit > 0 && floatingPercent < breakevenThreshold && floatingPercent > 0)
        {
            shouldClose = true;
            reason = StringFormat("⚖️ BREAKEVEN PROTECT: $%.2f (+%.2f%%) | Positions: %d | Threshold: ±%.2f%%", 
                                 netProfit, floatingPercent, totalPositions, breakevenThreshold);
        }
        // Nếu đang lỗ nhỏ (gần breakeven), đóng để tránh lỗ thêm
        else if(netProfit < 0 && MathAbs(floatingPercent) < breakevenThreshold)
        {
            shouldClose = true;
            reason = StringFormat("⚖️ BREAKEVEN CUT: $%.2f (-%.2f%%) | Positions: %d | Threshold: ±%.2f%%", 
                                 netProfit, MathAbs(floatingPercent), totalPositions, breakevenThreshold);
        }
    }
    
    // 4. ĐÓNG KHI QUÁ THỜI GIAN (positions mở quá lâu)
    if(closeOnTimeLimit && !shouldClose)
    {
        int hoursOpen = (int)((TimeCurrent() - oldestOpenTime) / 3600);
        if(hoursOpen >= maxHoursOpen)
        {
            shouldClose = true;
            reason = StringFormat("⏰ TIME LIMIT: %d hours | Positions: %d | Limit: %d hours | P/L: $%.2f", 
                                 hoursOpen, totalPositions, maxHoursOpen, netProfit);
        }
    }
    
    // 5. SMART CLOSE - Xem xét win rate trước khi đóng
    if(useSmartClose && shouldClose && netProfit < 0)
    {
        // Tính win rate
        int totalTrades = totalWins + totalLosses;
        double winRate = (totalTrades > 0) ? (double)totalWins / totalTrades * 100.0 : 0;
        
        // Nếu win rate cao, cho thêm cơ hội recovery
        if(winRate >= minWinRateToHold && MathAbs(floatingPercent) < maxDrawdownPercent * 0.5)
        {
            PrintFormat("🔄 SMART HOLD: Win Rate %.1f%% >= %.1f%% | Giving recovery chance | Current: $%.2f",
                       winRate, minWinRateToHold, netProfit);
            return;  // Không đóng, cho cơ hội phục hồi
        }
    }
    
    // THỰC HIỆN ĐÓNG TẤT CẢ POSITIONS
    if(shouldClose)
    {
        PrintFormat("🚨🚨🚨 AUTO CLOSE ALL TRIGGERED 🚨🚨🚨");
        PrintFormat("🚨 %s", reason);
        PrintFormat("📊 BEFORE CLOSE | Positions: %d | Balance: $%.2f | Equity: $%.2f | Floating: $%.2f", 
                   totalPositions, balance, equity, netProfit);
        PrintFormat("📊 Breakdown | Profit: $%.2f | Loss: $%.2f | Net: $%.2f (%.2f%%)",
                   totalProfit, totalLoss, netProfit, floatingPercent);
        
        int closedCount = CloseAllPositions();
        
        if(closedCount > 0)
        {
            // Wait for positions to close
            Sleep(500);
            
            double newBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            double newEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            double realizedPL = newBalance - balance;
            
            PrintFormat("✅✅✅ AUTO CLOSE COMPLETED ✅✅✅");
            PrintFormat("✅ Closed: %d/%d positions", closedCount, totalPositions);
            PrintFormat("✅ New Balance: $%.2f (was $%.2f) | Change: $%.2f", 
                       newBalance, balance, realizedPL);
            PrintFormat("✅ New Equity: $%.2f | Gap: $%.2f", 
                       newEquity, newEquity - newBalance);
            
            if(MathAbs(newEquity - newBalance) < 0.01)
            {
                PrintFormat("✅ SUCCESS: No floating P/L remaining! Equity = Balance");
            }
            else
            {
                PrintFormat("⚠️ WARNING: Still has floating P/L = $%.2f", newEquity - newBalance);
            }
        }
        else
        {
            PrintFormat("❌ FAILED to close any positions!");
        }
    }
}

//+------------------------------------------------------------------+
//| Close All Positions for this Symbol and Magic Number             |
//+------------------------------------------------------------------+
int CloseAllPositions()
{
    int closedCount = 0;
    int totalPositions = PositionsTotal();
    
    PrintFormat("🔄 Attempting to close ALL %d positions...", totalPositions);
    
    // Loop từ cuối lên đầu để tránh index shift khi đóng
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        // Select position by ticket
        if(!PositionSelectByTicket(ticket)) continue;
        
        // Filter by Symbol and Magic Number
        string posSymbol = PositionGetString(POSITION_SYMBOL);
        long posMagic = PositionGetInteger(POSITION_MAGIC);
        
        if(posSymbol != _Symbol) continue;
        if(posMagic != MagicNumber) continue;
        
        // Get position details
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double posVolume = PositionGetDouble(POSITION_VOLUME);
        double posProfit = PositionGetDouble(POSITION_PROFIT);
        string posComment = PositionGetString(POSITION_COMMENT);
        
        // Prepare close request
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = _Symbol;
        request.volume = posVolume;
        request.deviation = 50;  // Tăng deviation để đảm bảo close được
        request.magic = MagicNumber;
        request.type_filling = GetFillingMode(_Symbol);
        
        if(posType == POSITION_TYPE_BUY)
        {
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        }
        else
        {
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        }
        
        // Send close order
        if(OrderSend(request, result))
        {
            if(result.retcode == TRADE_RETCODE_DONE || 
               result.retcode == TRADE_RETCODE_PLACED ||
               result.retcode == TRADE_RETCODE_DONE_PARTIAL)
            {
                closedCount++;
                PrintFormat("   ✓ Closed #%I64u | %s | %.2f lot | $%.2f | %s", 
                           ticket, 
                           posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
                           posVolume,
                           posProfit,
                           posComment);
            }
            else
            {
                PrintFormat("   ⚠️ Close result #%I64u | Retcode: %d - %s", 
                           ticket, result.retcode, result.comment);
            }
        }
        else
        {
            PrintFormat("   ✗ Failed to close #%I64u | Error: %d - %s", 
                       ticket, result.retcode, result.comment);
        }
        
        // Small delay để tránh requote
        Sleep(100);
    }
    
    // Reset ALL tracking variables sau khi đóng tất cả
    if(closedCount > 0)
    {
        ResetAllTrackingVariables();
    }
    
    return closedCount;
}

//+------------------------------------------------------------------+
//| Reset All Tracking Variables After Close All                     |
//+------------------------------------------------------------------+
void ResetAllTrackingVariables()
{
    // Reset Hedge tracking
    hedgeActiveLong = false;
    hedgeActiveShort = false;
    hedgeCountLong = 0;
    hedgeCountShort = 0;
    maxProfitReached = 0;
    
    ArrayResize(hedgePositionsLong, 0);
    ArrayResize(hedgePositionsShort, 0);
    
    // Reset Price Zone tracking (DCA zones)
    zoneCountLong = 0;
    zoneCountShort = 0;
    ArrayResize(priceZonesLong, 0);
    ArrayResize(priceZonesShort, 0);
    
    // Reset signal confirmation
    consecutiveBuyBars = 0;
    consecutiveSellBars = 0;
    lastBuyScore = 0;
    lastSellScore = 0;
    
    PrintFormat("🔄 All tracking variables RESET");
}

//+------------------------------------------------------------------+


