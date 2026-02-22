//+------------------------------------------------------------------+
//|                     QuantumRSI v5.0 - Grid Pro with Smart ML     |
//|                        Copyright 2024, Grid Pro Strategy         |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, QuantumRSI v5.0 Grid Pro"
#property link      "https://www.mql5.com"
#property version   "5.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
sinput group "=== TRADING MODE ==="
enum ENUM_TRADING_MODE { SINGLE_DIRECTION = 0, HEDGE = 1, GRID = 2 };
input ENUM_TRADING_MODE tradingMode = GRID;      // Trading Mode
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
input double signalThreshold = 0.60;            // Signal Threshold (50-80%)
input int    minConfirmBars  = 2;               // Min Confirmation Bars (1-5)
input int    cooldownBars    = 3;               // Cooldown Between Trades (bars)

sinput group "=== NEWS FILTER ==="
enum ENUM_NEWS_FILTER { NEWS_OFF = 0, NEWS_HIGH_ONLY = 1, NEWS_ALL = 2 };
input ENUM_NEWS_FILTER newsFilter = NEWS_OFF;   // News Filter Mode
input int    newsMinutesBefore = 30;            // Minutes Before News
input int    newsMinutesAfter  = 30;            // Minutes After News
input string newsCurrency      = "USD,EUR,GBP,JPY,AUD,CAD,CHF,NZD"; // Currencies to Monitor

sinput group "=== RSI Settings ==="
input int    length_rsi      = 14;              // RSI Length
input int    rsi_entry       = 35;              // RSI Oversold (BUY)
input int    rsi_exit        = 75;              // RSI Overbought (SELL)
input string rsi_timeframes  = "CURRENT,H1,H4"; // RSI Timeframes

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
enum ENUM_TPSL_MODE { PIPS_RR = 0, ATR_PIPS = 1, TRAILING_STOP = 2, TRAILING_ATR = 3 };
input ENUM_TPSL_MODE tpSlMode = PIPS_RR;        // TP/SL Mode
input int    slPips          = 30;              // SL pips
input double rr              = 3.0;             // Risk:Reward Ratio
input int    atr_len         = 14;              // ATR Length
input string atr_timeframe   = "CURRENT";       // ATR Timeframe
input double atr_mult_sl     = 1.0;             // ATR Multiplier for SL
input double atr_mult_tp     = 2.5;             // ATR Multiplier for TP
input int    trailingStart   = 20;              // Trailing Start (pips)
input int    trailingStep    = 10;              // Trailing Step (pips)
input double trailingATRMult = 1.5;             // Trailing ATR Multiplier

sinput group "=== BASIC GRID Settings ==="
input int    gridLevels      = 5;               // Grid Levels (max)
input int    gridSpacing     = 20;              // Grid Spacing (pips) - Base
input double gridLotMultiplier = 1.5;           // Grid Lot Multiplier - Legacy

sinput group "=== ADVANCED GRID PRO ==="
input bool   useSmartGrid      = true;          // 🚀 Use Smart Grid System
input bool   useDynamicSpacing = true;          // ⚡ Dynamic ATR Spacing
input double gridATRMultiplier = 1.5;           // ATR Multiplier for Spacing
input bool   useSmartLot       = true;          // 📊 Smart Lot Progression
input string lotProgression    = "1.0,1.2,1.5,2.0,2.5"; // Lot Multipliers (comma-separated)
input bool   useGridTP         = true;          // 🎯 Grid Take Profit (close all)
input double gridTPPercent     = 3.0;           // Grid TP % (from average entry)
input bool   useGridBreakeven  = true;          // ⚖️ Grid Breakeven Close
input bool   useHedgeGrid      = false;         // 🔄 Hedge Grid (Long + Short)
input bool   useRecoveryZone   = true;          // 🛡️ Recovery Zone Protection
input double maxDrawdownPercent = 10.0;         // Max Drawdown % (stop new grids)
input double recoveryTPPercent  = 2.0;          // Recovery TP % (close all when recovering)

sinput group "=== Money Management ==="
enum ENUM_RISK_MODE { FIXED = 0, MARTINGALE = 1, FIBONACCI = 2, ALGORITHMIC = 3 };
input ENUM_RISK_MODE riskMode    = FIXED;       // Risk Management Mode
input double lotSize             = 0.1;         // Lot Size (FIXED mode)
input double riskPercent         = 2.0;         // Risk % of Balance
input double martingaleMultiplier = 2.0;        // Martingale Multiplier
input double maxLotSize          = 10.0;        // Max Lot Size (safety)
input int    maxOpenPositions    = 10;          // Max concurrent positions

//+------------------------------------------------------------------+
//| Multi-Timeframe Structure                                        |
//+------------------------------------------------------------------+
struct MTFHandles
{
    int handles[];
    ENUM_TIMEFRAMES timeframes[];
    int count;
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
    string name;
    double weight;
    double total_profit;
    int trade_count;
};

SignalWeight signalWeights[];
int signalWeightCount = 0;
int mlTradeCounter = 0;

//+------------------------------------------------------------------+
//| Grid Position Structure                                          |
//+------------------------------------------------------------------+
struct GridPosition
{
    ulong ticket;
    double entryPrice;
    double lotSize;
    int level;
    bool isLong;
    datetime openTime;
};

GridPosition gridPositions[];
int gridPositionCount = 0;

//--- Grid Pro Variables
double gridAverageEntryLong = 0;
double gridAverageEntryShort = 0;
double gridTotalVolumeLong = 0;
double gridTotalVolumeShort = 0;
bool gridRecoveryMode = false;
datetime gridLastRecoveryCheck = 0;

//--- Risk Management Variables
double currentLotSize = 0.1;
int consecutiveLosses = 0;
double lastLotSize = 0.1;
int fibIndex = 0;

//--- Grid Trading Variables
double lastGridLongPrice = 0;
double lastGridShortPrice = 0;
int currentGridLevel = 0;

//--- Track active signals for ML updates
string lastActiveSignals = "";

//--- Signal Smoothing Variables
datetime lastTradeTime = 0;
int consecutiveBuyBars = 0;
int consecutiveSellBars = 0;
double lastBuyScore = 0;
double lastSellScore = 0;

//--- Smart Lot Progression Array
double smartLotMultipliers[];
int smartLotCount = 0;

//--- News Filter Variables
struct NewsEvent
{
    datetime time;
    string currency;
    string title;
    int impact;
};

NewsEvent upcomingNews[];
int newsCount = 0;
datetime lastNewsCheck = 0;

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
//| Parse Smart Lot Progression                                      |
//+------------------------------------------------------------------+
void ParseSmartLotProgression()
{
    if(!useSmartLot) return;
    
    string lotArray[];
    smartLotCount = StringSplit(lotProgression, ',', lotArray);
    
    if(smartLotCount > 0)
    {
        ArrayResize(smartLotMultipliers, smartLotCount);
        for(int i = 0; i < smartLotCount; i++)
        {
            smartLotMultipliers[i] = StringToDouble(lotArray[i]);
            if(smartLotMultipliers[i] <= 0) smartLotMultipliers[i] = 1.0;
        }
        
        PrintFormat("✅ Smart Lot Progression: %d levels loaded", smartLotCount);
        string output = "";
        for(int i = 0; i < smartLotCount && i < 10; i++)
            output += StringFormat("%.2f ", smartLotMultipliers[i]);
        PrintFormat("   Multipliers: %s", output);
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
    signalWeights[index].weight = 1.0;
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
            handle = iRSI(_Symbol, tf, length_rsi, PRICE_CLOSE);
        else if(indicatorType == "EMA_FAST")
            handle = iMA(_Symbol, tf, ema_fast, 0, MODE_EMA, PRICE_CLOSE);
        else if(indicatorType == "EMA_SLOW")
            handle = iMA(_Symbol, tf, ema_slow, 0, MODE_EMA, PRICE_CLOSE);
        else if(indicatorType == "MACD")
            handle = iMACD(_Symbol, tf, macd_fast, macd_slow, macd_signal, PRICE_CLOSE);
        else if(indicatorType == "BB")
            handle = iBands(_Symbol, tf, bb_period, 0, bb_deviation, PRICE_CLOSE);
        
        if(handle == INVALID_HANDLE)
        {
            PrintFormat("❌ Failed to create %s handle for %s", indicatorType, TimeframeToString(tf));
            return false;
        }
        
        mtf.handles[mtf.count] = handle;
        mtf.timeframes[mtf.count] = tf;
        mtf.count++;
        
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
    
    double reward = profit > 0 ? 1.0 : -1.0;
    
    signalWeights[index].weight += mlLearningRate * reward;
    signalWeights[index].total_profit += profit;
    signalWeights[index].trade_count++;
    
    NormalizeAllSignalWeights();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    ArrayResize(signalWeights, 0);
    signalWeightCount = 0;
    
    // Parse Smart Lot Progression
    ParseSmartLotProgression();
    
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
    
    // Always create ATR
    atrTF = StringToTimeframe(atr_timeframe);
    atrHandle = iATR(_Symbol, atrTF, atr_len);
    if(atrHandle == INVALID_HANDLE)
    {
        PrintFormat("Failed to create ATR handle");
        return(INIT_FAILED);
    }
    PrintFormat("✅ ATR initialized on %s", TimeframeToString(atrTF));
    
    // Normalize weights
    if(signalWeightCount > 0)
    {
        NormalizeAllSignalWeights();
        PrintFormat("📊 Initialized %d MTF signals with ML tracking", signalWeightCount);
    }
    
    // Initialize risk management
    currentLotSize = lotSize;
    lastLotSize = lotSize;
    consecutiveLosses = 0;
    fibIndex = 0;
    
    // Initialize grid variables
    lastGridLongPrice = 0;
    lastGridShortPrice = 0;
    currentGridLevel = 0;
    ArrayResize(gridPositions, 0);
    gridPositionCount = 0;
    gridRecoveryMode = false;
    
    // Print configuration
    PrintFormat("=== QuantumRSI v5.0 - Grid Pro Strategy ===");
    
    string modeStr = "SINGLE_DIRECTION";
    if(tradingMode == HEDGE) modeStr = "HEDGE";
    else if(tradingMode == GRID) modeStr = "GRID PRO";
    PrintFormat("Trading Mode: %s", modeStr);
    
    if(tradingMode == GRID && useSmartGrid)
    {
        PrintFormat("🚀 SMART GRID ENABLED:");
        PrintFormat("   ⚡ Dynamic Spacing: %s (ATR × %.2f)", useDynamicSpacing ? "YES" : "NO", gridATRMultiplier);
        PrintFormat("   📊 Smart Lot: %s", useSmartLot ? "YES" : "NO");
        PrintFormat("   🎯 Grid TP: %s (%.1f%%)", useGridTP ? "YES" : "NO", gridTPPercent);
        PrintFormat("   ⚖️ Breakeven: %s", useGridBreakeven ? "YES" : "NO");
        PrintFormat("   🔄 Hedge Grid: %s", useHedgeGrid ? "YES" : "NO");
        PrintFormat("   🛡️ Recovery Zone: %s (Max DD: %.1f%%)", useRecoveryZone ? "YES" : "NO", maxDrawdownPercent);
    }
    
    string indicators = "";
    if(use_RSI) indicators += StringFormat("RSI(%d TFs) ", rsiMTF.count);
    if(use_EMA) indicators += StringFormat("EMA(%d TFs) ", emaFastMTF.count);
    if(use_MACD) indicators += StringFormat("MACD(%d TFs) ", macdMTF.count);
    if(use_BB) indicators += StringFormat("BB(%d TFs) ", bbMTF.count);
    PrintFormat("Active Indicators: %s", indicators);
    
    string tpslModeStr = "PIPS_RR";
    if(tpSlMode == ATR_PIPS) tpslModeStr = "ATR_PIPS";
    else if(tpSlMode == TRAILING_STOP) tpslModeStr = "TRAILING_STOP";
    else if(tpSlMode == TRAILING_ATR) tpslModeStr = "TRAILING_ATR";
    PrintFormat("TP/SL Mode: %s | ATR TF: %s", tpslModeStr, TimeframeToString(atrTF));
    
    // Initialize News Filter
    if(newsFilter != NEWS_OFF)
    {
        ArrayResize(upcomingNews, 100);
        newsCount = 0;
        lastNewsCheck = 0;
        PrintFormat("News Filter: ENABLED");
    }
    
    PrintFormat("=== Ready to trade ===");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
    
    if(useML && signalWeightCount > 0)
    {
        PrintFormat("=== Final ML Statistics ===");
        for(int i = 0; i < signalWeightCount; i++)
        {
            if(signalWeights[i].trade_count > 0)
            {
                double avgProfit = signalWeights[i].total_profit / signalWeights[i].trade_count;
                PrintFormat("%s: Weight=%.4f | Trades=%d | Avg=%.2f", 
                           signalWeights[i].name, signalWeights[i].weight, 
                           signalWeights[i].trade_count, avgProfit);
            }
        }
    }
        
    PrintFormat("EA stopped. Reason: %d", reason);
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
                PrintFormat("🚫 NEWS BLOCK: %s in %d minutes", upcomingNews[i].title, minutesUntil);
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
//| Calculate dynamic grid spacing                                   |
//+------------------------------------------------------------------+
double GetDynamicGridSpacing()
{
    if(!useDynamicSpacing || !useSmartGrid)
    {
        return gridSpacing * GetPip();
    }
    
    double atr = GetATR(0);
    if(atr == EMPTY_VALUE || atr <= 0)
    {
        return gridSpacing * GetPip();
    }
    
    // ATR-based spacing
    double spacing = atr * gridATRMultiplier;
    double pip = GetPip();
    double minSpacing = 10 * pip;  // Minimum 10 pips
    double maxSpacing = 100 * pip; // Maximum 100 pips
    
    if(spacing < minSpacing) spacing = minSpacing;
    if(spacing > maxSpacing) spacing = maxSpacing;
    
    return spacing;
}

//+------------------------------------------------------------------+
//| Calculate smart lot size for grid level                          |
//+------------------------------------------------------------------+
double CalculateSmartGridLot(int gridLevel)
{
    double baseLot = lotSize;
    double multiplier = 1.0;
    
    if(useSmartLot && useSmartGrid && smartLotCount > 0)
    {
        // Use smart progression
        if(gridLevel < smartLotCount)
        {
            multiplier = smartLotMultipliers[gridLevel];
        }
        else
        {
            // Use last multiplier for levels beyond array
            multiplier = smartLotMultipliers[smartLotCount - 1];
        }
    }
    else
    {
        // Legacy exponential
        multiplier = MathPow(gridLotMultiplier, gridLevel);
    }
    
    double calculatedLot = baseLot * multiplier;
    
    // Safety limits
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
//| Add position to grid tracking                                    |
//+------------------------------------------------------------------+
void AddGridPosition(ulong ticket, double price, double lot, int level, bool isLong)
{
    int index = gridPositionCount;
    gridPositionCount++;
    ArrayResize(gridPositions, gridPositionCount);
    
    gridPositions[index].ticket = ticket;
    gridPositions[index].entryPrice = price;
    gridPositions[index].lotSize = lot;
    gridPositions[index].level = level;
    gridPositions[index].isLong = isLong;
    gridPositions[index].openTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Remove position from grid tracking                               |
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
            ArrayResize(gridPositions, gridPositionCount);
            return;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate grid average entry and total volume                    |
//+------------------------------------------------------------------+
void CalculateGridAverages()
{
    double totalPriceLong = 0;
    double totalVolumeLong = 0;
    double totalPriceShort = 0;
    double totalVolumeShort = 0;
    
    for(int i = 0; i < gridPositionCount; i++)
    {
        if(gridPositions[i].isLong)
        {
            totalPriceLong += gridPositions[i].entryPrice * gridPositions[i].lotSize;
            totalVolumeLong += gridPositions[i].lotSize;
        }
        else
        {
            totalPriceShort += gridPositions[i].entryPrice * gridPositions[i].lotSize;
            totalVolumeShort += gridPositions[i].lotSize;
        }
    }
    
    if(totalVolumeLong > 0)
        gridAverageEntryLong = totalPriceLong / totalVolumeLong;
    else
        gridAverageEntryLong = 0;
    
    if(totalVolumeShort > 0)
        gridAverageEntryShort = totalPriceShort / totalVolumeShort;
    else
        gridAverageEntryShort = 0;
    
    gridTotalVolumeLong = totalVolumeLong;
    gridTotalVolumeShort = totalVolumeShort;
}

//+------------------------------------------------------------------+
//| Calculate grid floating P/L percentage                           |
//+------------------------------------------------------------------+
double CalculateGridFloatingPL()
{
    double totalPL = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            totalPL += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(balance <= 0) return 0;
    
    return (totalPL / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| Check if should close grid with TP                               |
//+------------------------------------------------------------------+
bool ShouldCloseGridTP(bool isLong)
{
    if(!useGridTP || !useSmartGrid) return false;
    
    double averageEntry = isLong ? gridAverageEntryLong : gridAverageEntryShort;
    if(averageEntry == 0) return false;
    
    double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double profitPercent = 0;
    if(isLong)
        profitPercent = ((currentPrice - averageEntry) / averageEntry) * 100.0;
    else
        profitPercent = ((averageEntry - currentPrice) / averageEntry) * 100.0;
    
    if(profitPercent >= gridTPPercent)
    {
        PrintFormat("🎯 Grid TP reached: %.2f%% (target: %.1f%%)", profitPercent, gridTPPercent);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if should close grid at breakeven                          |
//+------------------------------------------------------------------+
bool ShouldCloseGridBreakeven(bool isLong)
{
    if(!useGridBreakeven || !useSmartGrid) return false;
    
    double totalPL = 0;
    int gridCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                bool posIsLong = (posType == POSITION_TYPE_BUY);
                
                if(posIsLong == isLong)
                {
                    totalPL += PositionGetDouble(POSITION_PROFIT);
                    gridCount++;
                }
            }
        }
    }
    
    if(gridCount >= 2 && totalPL >= -1.0 && totalPL <= 1.0)
    {
        PrintFormat("⚖️ Grid Breakeven close: PL=%.2f, Positions=%d", totalPL, gridCount);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check recovery zone status                                       |
//+------------------------------------------------------------------+
void CheckRecoveryZone()
{
    if(!useRecoveryZone || !useSmartGrid) return;
    
    datetime currentTime = TimeCurrent();
    if(currentTime - gridLastRecoveryCheck < 60) return; // Check every minute
    gridLastRecoveryCheck = currentTime;
    
    double floatingPL = CalculateGridFloatingPL();
    
    if(!gridRecoveryMode && floatingPL < -maxDrawdownPercent)
    {
        gridRecoveryMode = true;
        PrintFormat("🛡️ RECOVERY MODE ACTIVATED: Floating PL=%.2f%% (Max: -%.1f%%)", 
                   floatingPL, maxDrawdownPercent);
        PrintFormat("   → Stopping new grid levels. Waiting for recovery...");
    }
    else if(gridRecoveryMode && floatingPL >= -recoveryTPPercent)
    {
        gridRecoveryMode = false;
        PrintFormat("✅ RECOVERY MODE DEACTIVATED: Floating PL=%.2f%%", floatingPL);
        
        // Close all positions in recovery
        CloseAllGridPositions(true);  // Long
        CloseAllGridPositions(false); // Short
    }
}

//+------------------------------------------------------------------+
//| Close all grid positions of one direction                        |
//+------------------------------------------------------------------+
void CloseAllGridPositions(bool isLong)
{
    ENUM_POSITION_TYPE typeToClose = isLong ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                if(posType == typeToClose)
                {
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
                    request.type_filling = ORDER_FILLING_IOC;
                    
                    OrderSend(request, result);
                }
            }
        }
    }
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
            if(isLong)
                outSL = entryPrice - atrAtEntry * atr_mult_sl;
            else
                outSL = entryPrice + atrAtEntry * atr_mult_sl;
        }
        else
        {
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
            outTP = 0;
        }
        else if(tpSlMode == PIPS_RR)
        {
            if(isLong)
                outTP = entryPrice + slPips * pip * rr;
            else
                outTP = entryPrice - slPips * pip * rr;
            outTP = NormalizeDouble(outTP, _Digits);
        }
        else if(tpSlMode == ATR_PIPS)
        {
            if(isLong)
                outTP = entryPrice + atrAtEntry * atr_mult_tp;
            else
                outTP = entryPrice - atrAtEntry * atr_mult_tp;
            outTP = NormalizeDouble(outTP, _Digits);
        }
    }
}

//+------------------------------------------------------------------+
//| Count open positions by type                                     |
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

//+------------------------------------------------------------------+
//| Open grid position                                                |
//+------------------------------------------------------------------+
void OpenGridPosition(bool isLong, int gridLevel, string signals)
{
    double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double atrAtEntry = GetATR(0);
    double sl, tp;
    CalcSLTP_fromEntry(price, isLong, atrAtEntry, sl, tp);
    
    double calcLot = CalculateSmartGridLot(gridLevel);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = calcLot;
    request.type = isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.comment = StringFormat("GridPro L%d", gridLevel);
    request.type_filling = ORDER_FILLING_IOC;
    
    if(OrderSend(request, result))
    {
        PrintFormat("📊 Grid L%d %s: Lot=%.2f, Price=%.5f | Signals: %s", 
                   gridLevel, isLong ? "BUY" : "SELL", calcLot, price, signals);
        
        AddGridPosition(result.order, price, calcLot, gridLevel, isLong);
        
        if(isLong)
            lastGridLongPrice = price;
        else
            lastGridShortPrice = price;
    }
}

//+------------------------------------------------------------------+
//| Check if should open new grid level                              |
//+------------------------------------------------------------------+
bool ShouldOpenGridLevel(bool isLong, double currentPrice)
{
    if(gridRecoveryMode)
    {
        return false; // Stop opening new grids in recovery mode
    }
    
    double lastPrice = isLong ? lastGridLongPrice : lastGridShortPrice;
    if(lastPrice == 0) return true;
    
    double dynamicSpacing = GetDynamicGridSpacing();
    
    if(isLong)
    {
        if(currentPrice <= lastPrice - dynamicSpacing)
            return true;
    }
    else
    {
        if(currentPrice >= lastPrice + dynamicSpacing)
            return true;
    }
    
    return false;
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
    
    // Check recovery zone
    if(tradingMode == GRID && useSmartGrid)
    {
        CheckRecoveryZone();
        CalculateGridAverages();
    }
    
    // Check cooldown
    if(lastTradeTime > 0)
    {
        int barsSinceLastTrade = Bars(_Symbol, _Period, lastTradeTime, currentBar);
        if(barsSinceLastTrade < cooldownBars)
        {
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
    
    // Grid Pro Logic
    if(tradingMode == GRID)
    {
        // Check Grid TP
        if(useSmartGrid && useGridTP)
        {
            if(longPositions > 0 && ShouldCloseGridTP(true))
            {
                CloseAllGridPositions(true);
                PrintFormat("✅ Grid LONG closed with TP");
            }
            
            if(shortPositions > 0 && ShouldCloseGridTP(false))
            {
                CloseAllGridPositions(false);
                PrintFormat("✅ Grid SHORT closed with TP");
            }
        }
        
        // Check Grid Breakeven
        if(useSmartGrid && useGridBreakeven)
        {
            if(longPositions > 0 && ShouldCloseGridBreakeven(true))
            {
                CloseAllGridPositions(true);
                PrintFormat("✅ Grid LONG closed at breakeven");
            }
            
            if(shortPositions > 0 && ShouldCloseGridBreakeven(false))
            {
                CloseAllGridPositions(false);
                PrintFormat("✅ Grid SHORT closed at breakeven");
            }
        }
        
        // Open first grid level on signal
        if(enableBuy && buy_signal && longPositions == 0)
        {
            PrintFormat("📈 BUY CONFIRMED | Score: %.1f%%", lastBuyScore * 100);
            lastActiveSignals = buySignals;
            OpenGridPosition(true, 0, buySignals);
            lastTradeTime = currentBar;
            consecutiveBuyBars = 0;
        }
        
        if(enableSell && sell_signal && shortPositions == 0)
        {
            PrintFormat("📉 SELL CONFIRMED | Score: %.1f%%", lastSellScore * 100);
            lastActiveSignals = sellSignals;
            OpenGridPosition(false, 0, sellSignals);
            lastTradeTime = currentBar;
            consecutiveSellBars = 0;
        }
        
        // Add grid levels
        if(enableBuy && longPositions > 0 && longPositions < gridLevels)
        {
            if(ShouldOpenGridLevel(true, bid))
            {
                OpenGridPosition(true, longPositions, "Grid expansion");
            }
        }
        
        if(enableSell && shortPositions > 0 && shortPositions < gridLevels)
        {
            if(ShouldOpenGridLevel(false, ask))
            {
                OpenGridPosition(false, shortPositions, "Grid expansion");
            }
        }
        
        // Hedge Grid
        if(useSmartGrid && useHedgeGrid)
        {
            // Open opposite direction grid
            if(enableBuy && buy_signal && shortPositions > 0 && longPositions == 0)
            {
                OpenGridPosition(true, 0, "Hedge Long");
            }
            
            if(enableSell && sell_signal && longPositions > 0 && shortPositions == 0)
            {
                OpenGridPosition(false, 0, "Hedge Short");
            }
        }
    }
    
    // Trailing Stop
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
        
        double trailingStartPips = trailingStart;
        if(tpSlMode == TRAILING_ATR && atr > 0)
            trailingStartPips = (atr / pip) * trailingATRMult;
        
        if(profitPips < trailingStartPips) continue;
        
        double newSL = 0;
        double trailingDistance = trailingStep * pip;
        
        if(tpSlMode == TRAILING_ATR && atr > 0)
            trailingDistance = atr * trailingATRMult;
        
        if(isLong)
        {
            newSL = currentPrice - trailingDistance;
            
            if(currentSL > 0 && newSL <= currentSL) continue;
            if(newSL <= entryPrice) newSL = entryPrice + pip;
        }
        else
        {
            newSL = currentPrice + trailingDistance;
            
            if(currentSL > 0 && newSL >= currentSL) continue;
            if(newSL >= entryPrice) newSL = entryPrice - pip;
        }
        
        newSL = NormalizeDouble(newSL, _Digits);
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = _Symbol;
        request.sl = newSL;
        request.tp = PositionGetDouble(POSITION_TP);
        
        if(OrderSend(request, result))
        {
            PrintFormat("🔄 Trailing SL: Ticket=%d, SL=%.5f, Profit=%.1f pips", 
                       ticket, newSL, profitPips);
        }
    }
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
                    bool wasWin = (dealProfit > 0);
                    
                    // Update ML
                    if(useML && signalWeightCount > 0 && lastActiveSignals != "")
                    {
                        mlTradeCounter++;
                        
                        string activeSignalArray[];
                        int count = StringSplit(lastActiveSignals, ' ', activeSignalArray);
                        
                        for(int i = 0; i < count; i++)
                        {
                            if(activeSignalArray[i] != "")
                            {
                                UpdateSignalWeight(activeSignalArray[i], dealProfit);
                            }
                        }
                        
                        lastActiveSignals = "";
                    }
                    
                    // Remove from grid tracking
                    RemoveGridPosition(trans.position);
                    
                    if(wasWin)
                    {
                        PrintFormat("✅ Trade CLOSED: +%.2f", dealProfit);
                    }
                    else
                    {
                        PrintFormat("❌ Trade CLOSED: %.2f", dealProfit);
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
