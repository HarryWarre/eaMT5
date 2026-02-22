//+------------------------------------------------------------------+
//|                                    QuantumRSI v3.0 - Multi-Indicator |
//|                        Copyright 2024, Multi-Indicator Strategy    |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, QuantumRSI v3.0"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
sinput group "=== TRADING MODE ==="
enum ENUM_TRADING_MODE { SINGLE_DIRECTION = 0, HEDGE = 1, GRID = 2 };
input ENUM_TRADING_MODE tradingMode = SINGLE_DIRECTION;  // Trading Mode
input bool   enableBuy       = true;            // Enable Buy
input bool   enableSell      = true;            // Enable Sell

sinput group "=== INDICATOR SELECTION ==="
input bool   use_RSI         = true;            // Use RSI
input bool   use_EMA         = false;           // Use EMA Crossover
input bool   use_MACD        = false;           // Use MACD
input bool   use_BB          = false;           // Use Bollinger Bands

sinput group "=== MACHINE LEARNING ==="
input bool   useML           = false;           // Use ML Reinforcement Learning
input double mlLearningRate  = 0.1;             // Learning Rate (0.01-0.5)
input int    mlMemorySize    = 100;             // Memory Size (trades)

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
input string rsi_timeframes  = "CURRENT,H1,H4"; // RSI Timeframes (comma-separated)

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
enum ENUM_TPSL_MODE { PIPS_RR = 0, ATR_PIPS = 1 };
input ENUM_TPSL_MODE tpSlMode = PIPS_RR;        // TP/SL Mode
input int    slPips          = 30;              // SL pips
input double rr              = 3.0;             // RR (PIPS_RR mode)
input int    atr_len         = 14;              // ATR Length
input double atr_mult_tp     = 1.5;             // ATR Multiplier for TP

sinput group "=== GRID Settings ==="
input int    gridLevels      = 5;               // Grid Levels (GRID mode)
input int    gridSpacing     = 20;              // Grid Spacing (pips)
input double gridLotMultiplier = 1.5;           // Grid Lot Multiplier

sinput group "=== Money Management ==="
enum ENUM_RISK_MODE { FIXED = 0, MARTINGALE = 1, FIBONACCI = 2, ALGORITHMIC = 3 };
input ENUM_RISK_MODE riskMode    = FIXED;       // Risk Management Mode
input double lotSize             = 0.1;         // Lot Size (FIXED mode)
input double riskPercent         = 2.0;         // Risk % of Balance (ALGORITHMIC mode)
input double martingaleMultiplier = 2.0;        // Martingale Multiplier
input double maxLotSize          = 10.0;        // Max Lot Size (safety)
input int    maxOpenPositions    = 10;          // Max concurrent positions

//--- Multi-Timeframe Indicator Handles
struct MTFHandles
{
    int handles[];      // Array of indicator handles for different timeframes
    ENUM_TIMEFRAMES timeframes[];  // Array of timeframes
    int count;          // Number of timeframes
};

MTFHandles rsiMTF;
MTFHandles emaFastMTF;
MTFHandles emaSlowMTF;
MTFHandles macdMTF;
MTFHandles bbMTF;
int atrHandle = INVALID_HANDLE;

//--- Risk Management Variables
double currentLotSize = 0.1;
int consecutiveLosses = 0;
double lastLotSize = 0.1;
int fibIndex = 0;

//--- Grid Trading Variables
double lastGridLongPrice = 0;
double lastGridShortPrice = 0;
int currentGridLevel = 0;

//--- Machine Learning Variables
struct MLMemory
{
    bool rsi_signal;
    bool ema_signal;
    bool macd_signal;
    bool bb_signal;
    bool final_decision;  // BUY or SELL
    double profit;        // Actual profit/loss
    datetime timestamp;
};

MLMemory mlHistory[];
int mlHistoryCount = 0;

// Multi-Timeframe Signal Weights (dynamic per indicator+timeframe)
struct SignalWeight
{
    string name;          // "RSI_M15", "EMA_H1", etc.
    double weight;        // Current weight
    double total_profit;  // Total profit from this signal
    int trade_count;      // Number of trades
};

SignalWeight signalWeights[];
int signalWeightCount = 0;

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

//+------------------------------------------------------------------+
//| Parse timeframe string to ENUM_TIMEFRAMES                        |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES StringToTimeframe(string tf)
{
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
        // Trim whitespace
        StringTrimLeft(tfArray[i]);
        StringTrimRight(tfArray[i]);
        
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
            PrintFormat("Failed to create %s handle for %s", indicatorType, TimeframeToString(tf));
            return false;
        }
        
        mtf.handles[mtf.count] = handle;
        mtf.timeframes[mtf.count] = tf;
        mtf.count++;
        
        // Initialize weight for this signal
        string signalName = indicatorType + "_" + TimeframeToString(tf);
        AddSignalWeight(signalName);
        
        PrintFormat("✅ Initialized %s on %s", indicatorType, TimeframeToString(tf));
    }
    
    return true;
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
    signalWeights[index].weight = 1.0 / signalWeightCount;  // Equal weight initially
    signalWeights[index].total_profit = 0;
    signalWeights[index].trade_count = 0;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize signal weights array
    ArrayResize(signalWeights, 0);
    signalWeightCount = 0;
    
    // Initialize multi-timeframe indicators based on selection
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
    atrHandle = iATR(_Symbol, _Period, atr_len);
    if(atrHandle == INVALID_HANDLE)
    {
        PrintFormat("Failed to create ATR handle");
        return(INIT_FAILED);
    }
    
    // Normalize all signal weights after initialization
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
    
    // Print configuration
    PrintFormat("=== QuantumRSI v3.0 - Multi-Timeframe Strategy ===");
    
    string modeStr = "SINGLE_DIRECTION";
    if(tradingMode == HEDGE) modeStr = "HEDGE";
    else if(tradingMode == GRID) modeStr = "GRID";
    PrintFormat("Trading Mode: %s", modeStr);
    
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
    
    if(tradingMode == GRID)
    {
        PrintFormat("Grid: %d levels, %d pips spacing, %.2fx multiplier", 
                   gridLevels, gridSpacing, gridLotMultiplier);
    }
    
    PrintFormat("Max Open Positions: %d", maxOpenPositions);
    
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
    
    // Initialize ML
    if(useML)
    {
        ArrayResize(mlHistory, mlMemorySize);
        mlHistoryCount = 0;
        
        // Initialize equal weights
        weight_RSI  = 0.25;
        weight_EMA  = 0.25;
        weight_MACD = 0.25;
        weight_BB   = 0.25;
        
        PrintFormat("ML Reinforcement: ENABLED | Learning Rate: %.2f | Memory: %d trades", 
                   mlLearningRate, mlMemorySize);
    }
    else
    {
        PrintFormat("ML Reinforcement: DISABLED (Using fixed 50%% consensus)");
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
        
    PrintFormat("EA stopped. Reason: %d | Total MTF signals tracked: %d", reason, signalWeightCount);
}

//+------------------------------------------------------------------+
//| Get indicator values                                              |
//+------------------------------------------------------------------+
double GetRSI(int shift)
{
    if(rsiHandle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(rsiHandle, 0, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

double GetATR(int shift)
{
    if(atrHandle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(atrHandle, 0, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

double GetEMA(int handle, int shift)
{
    if(handle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

double GetMACD(int buffer, int shift)
{
    if(macdHandle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(macdHandle, buffer, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

double GetBB(int buffer, int shift)
{
    if(bbHandle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(bbHandle, buffer, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

//+------------------------------------------------------------------+
//| Universal pip size                                                |
//+------------------------------------------------------------------+
double GetPip()
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(point <= 0) return(point);
    
    double mintick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    int denom = (int)MathRound(1.0 / mintick);
    
    if(denom >= 100000) return(0.0001);
    if(denom >= 10000)  return(0.0001);
    if(denom >= 1000)   return(0.1);
    if(denom >= 100)    return(0.01);
    
    return(mintick > 0 ? mintick : point);
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
//| Fetch news from ForexFactory calendar (manual implementation)    |
//+------------------------------------------------------------------+
void FetchNewsEvents()
{
    if(newsFilter == NEWS_OFF) return;
    
    // Check if we need to refresh (every hour)
    datetime currentTime = TimeCurrent();
    if(currentTime - lastNewsCheck < 3600) return;
    
    lastNewsCheck = currentTime;
    newsCount = 0;
    
    // ⚠️ MANUAL NEWS ENTRY (In real implementation, parse from ForexFactory RSS/CSV)
    // This is a placeholder - you need to manually update or implement RSS parser
    
    PrintFormat("📰 News check at %s - Manual entry required", TimeToString(currentTime));
    
    // Example: Manually add known news events
    // You should replace this with actual ForexFactory RSS feed parser
    // or use a paid news API service
    
    // Sample news events (replace with actual data)
    /*
    datetime nfpTime = D'2024.11.01 13:30';  // NFP example
    if(nfpTime > currentTime)
    {
        upcomingNews[newsCount].time = nfpTime;
        upcomingNews[newsCount].currency = "USD";
        upcomingNews[newsCount].title = "Non-Farm Payrolls";
        upcomingNews[newsCount].impact = 3;  // High
        newsCount++;
    }
    */
}

//+------------------------------------------------------------------+
//| Check if we're in news blackout period                           |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
    if(newsFilter == NEWS_OFF) return false;
    
    FetchNewsEvents();
    
    datetime currentTime = TimeCurrent();
    int bufferBefore = newsMinutesBefore * 60;
    int bufferAfter = newsMinutesAfter * 60;
    
    // Check against all upcoming news
    for(int i = 0; i < newsCount; i++)
    {
        // Skip if news is too old
        if(upcomingNews[i].time + bufferAfter < currentTime)
            continue;
        
        // Check impact level
        bool shouldBlock = false;
        if(newsFilter == NEWS_HIGH_ONLY && upcomingNews[i].impact >= 3)
            shouldBlock = true;
        else if(newsFilter == NEWS_ALL && upcomingNews[i].impact >= 1)
            shouldBlock = true;
        
        if(!shouldBlock) continue;
        
        // Check if currency is monitored
        if(!IsCurrencyMonitored(upcomingNews[i].currency))
            continue;
        
        // Check if we're in blackout window
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
            else
            {
                int minutesAfterNews = (int)((currentTime - upcomingNews[i].time) / 60);
                PrintFormat("🚫 NEWS BLOCK: %d minutes after %s (%s)", 
                           minutesAfterNews, upcomingNews[i].title, upcomingNews[i].currency);
            }
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Manual news entry function (call from Expert Advisor)            |
//+------------------------------------------------------------------+
void AddManualNewsEvent(datetime newsTime, string currency, string title, int impact)
{
    if(newsCount >= ArraySize(upcomingNews))
        ArrayResize(upcomingNews, newsCount + 50);
    
    upcomingNews[newsCount].time = newsTime;
    upcomingNews[newsCount].currency = currency;
    upcomingNews[newsCount].title = title;
    upcomingNews[newsCount].impact = impact;
    newsCount++;
    
    PrintFormat("📅 Added news: %s - %s (%s) - Impact: %d", 
               TimeToString(newsTime), title, currency, impact);
}

//+------------------------------------------------------------------+
//| Normalize all MTF signal weights                                 |
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
    
    // Clamp weights to [0.01, 0.50] to prevent dominance
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
//| Store ML memory                                                   |
//+------------------------------------------------------------------+
void StoreMLMemory(bool rsi_sig, bool ema_sig, bool macd_sig, bool bb_sig, bool decision)
{
    if(!useML) return;
    
    int index = mlHistoryCount % mlMemorySize;
    
    mlHistory[index].rsi_signal = rsi_sig;
    mlHistory[index].ema_signal = ema_sig;
    mlHistory[index].macd_signal = macd_sig;
    mlHistory[index].bb_signal = bb_sig;
    mlHistory[index].final_decision = decision;
    mlHistory[index].profit = 0;  // Will be updated when trade closes
    mlHistory[index].timestamp = TimeCurrent();
    
    mlHistoryCount++;
}

//+------------------------------------------------------------------+
//| Find and update ML memory with profit                            |
//+------------------------------------------------------------------+
void UpdateMLMemoryProfit(double profit)
{
    if(!useML || mlHistoryCount == 0) return;
    
    // Update most recent memory entry
    int index = (mlHistoryCount - 1) % mlMemorySize;
    mlHistory[index].profit = profit;
    
    // Update weights
    UpdateMLWeights(mlHistory[index]);
}

//+------------------------------------------------------------------+
//| Check multi-timeframe buy signal                                 |
//+------------------------------------------------------------------+
bool IsBuySignal()
{
    double signalScore = 0;
    double totalWeight = 0;
    string activeSignals = "";  // Track which signals fired
    
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
                    // Oversold signal
                    if(rsi_prev > rsi_entry && rsi_now <= rsi_entry)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        activeSignals += signalName + " ";
                    }
                    totalWeight += signalWeights[weightIndex].weight;
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
                    // Bullish crossover
                    if(ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        activeSignals += signalName + " ";
                    }
                    totalWeight += signalWeights[weightIndex].weight;
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
                    // Bullish crossover
                    if(macd_main_prev <= macd_signal_prev && macd_main_now > macd_signal_now)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        activeSignals += signalName + " ";
                    }
                    totalWeight += signalWeights[weightIndex].weight;
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
            double bb_lower = GetMTFValue(bbMTF.handles[i], 2, 0);  // Lower band
            
            if(bb_lower != EMPTY_VALUE)
            {
                string signalName = "BB_" + TimeframeToString(bbMTF.timeframes[i]);
                int weightIndex = FindSignalWeightIndex(signalName);
                
                if(weightIndex >= 0)
                {
                    // Price touches lower band
                    if(price <= bb_lower * 1.001)
                    {
                        signalScore += signalWeights[weightIndex].weight;
                        activeSignals += signalName + " ";
                    }
                    totalWeight += signalWeights[weightIndex].weight;
                }
            }
        }
    }
    
    if(totalWeight == 0) return false;
    
    // Decision threshold (50% weighted consensus)
    double threshold = 0.5;
    double score = signalScore / totalWeight;
    bool decision = (score >= threshold);
    
    if(decision && activeSignals != "")
    {
        PrintFormat("📈 BUY Signal | Score: %.2f%% | Active: %s", score * 100, activeSignals);
    }
    
    return decision;
}

//+------------------------------------------------------------------+
//| Check multi-indicator sell signal                                |
//+------------------------------------------------------------------+
bool IsSellSignal()
{
    // Track individual signals
    bool rsi_sig = false;
    bool ema_sig = false;
    bool macd_sig = false;
    bool bb_sig = false;
    
    double signalScore = 0;
    double totalWeight = 0;
    
    // RSI Signal
    if(use_RSI)
    {
        double rsi_prev = GetRSI(1);
        double rsi_now = GetRSI(0);
        if(rsi_prev < rsi_exit && rsi_now >= rsi_exit)
        {
            rsi_sig = true;
            signalScore += weight_RSI;
        }
        totalWeight += weight_RSI;
    }
    
    // EMA Signal
    if(use_EMA)
    {
        double ema_fast_prev = GetEMA(emaFastHandle, 1);
        double ema_slow_prev = GetEMA(emaSlowHandle, 1);
        double ema_fast_now = GetEMA(emaFastHandle, 0);
        double ema_slow_now = GetEMA(emaSlowHandle, 0);
        
        // Fast EMA crosses below Slow EMA
        if(ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now)
        {
            ema_sig = true;
            signalScore += weight_EMA;
        }
        totalWeight += weight_EMA;
    }
    
    // MACD Signal
    if(use_MACD)
    {
        double macd_main_prev = GetMACD(0, 1);
        double macd_signal_prev = GetMACD(1, 1);
        double macd_main_now = GetMACD(0, 0);
        double macd_signal_now = GetMACD(1, 0);
        
        // MACD line crosses below signal line
        if(macd_main_prev >= macd_signal_prev && macd_main_now < macd_signal_now)
        {
            macd_sig = true;
            signalScore += weight_MACD;
        }
        totalWeight += weight_MACD;
    }
    
    // Bollinger Bands Signal
    if(use_BB)
    {
        double bb_upper = GetBB(1, 0);  // Upper band
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Price touches or breaks upper band
        if(price >= bb_upper * 0.999)  // 0.1% tolerance
        {
            bb_sig = true;
            signalScore += weight_BB;
        }
        totalWeight += weight_BB;
    }
    
    if(totalWeight == 0) return false;
    
    // Decision threshold
    double threshold = useML ? 0.5 : 0.5;
    bool decision = (signalScore / totalWeight) >= threshold;
    
    // Store ML memory if signal detected
    if(useML && (rsi_sig || ema_sig || macd_sig || bb_sig))
    {
        StoreMLMemory(rsi_sig, ema_sig, macd_sig, bb_sig, decision);
    }
    
    return decision;
}

//+------------------------------------------------------------------+
//| Calc SL & TP                                                      |
//+------------------------------------------------------------------+
void CalcSLTP_fromEntry(double entryPrice, bool isLong, double atrAtEntry, double &outSL, double &outTP)
{
    outSL = 0;
    outTP = 0;
    double pip = GetPip();

    // Calculate SL if enabled
    if(useStopLoss)
    {
        if(isLong)
            outSL = entryPrice - slPips * pip;
        else
            outSL = entryPrice + slPips * pip;
            
        outSL = NormalizeDouble(outSL, _Digits);
    }
    
    // Calculate TP if enabled
    if(useTakeProfit)
    {
        if(tpSlMode == PIPS_RR)
        {
            if(isLong)
                outTP = entryPrice + slPips * pip * rr;
            else
                outTP = entryPrice - slPips * pip * rr;
        }
        else // ATR_PIPS
        {
            if(atrAtEntry <= 0 || atrAtEntry == EMPTY_VALUE) 
                atrAtEntry = GetATR(0);
            
            if(isLong)
                outTP = entryPrice + atrAtEntry * atr_mult_tp;
            else
                outTP = entryPrice - atrAtEntry * atr_mult_tp;
        }
        
        outTP = NormalizeDouble(outTP, _Digits);
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
double CalculateLotSize(int gridLevel = 0)
{
    double calculatedLot = lotSize;
    
    // Apply grid multiplier if in grid mode
    if(tradingMode == GRID && gridLevel > 0)
    {
        calculatedLot = lotSize * MathPow(gridLotMultiplier, gridLevel);
    }
    else
    {
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
    }
    
    // Apply max lot limit
    if(calculatedLot > maxLotSize)
        calculatedLot = maxLotSize;
    
    // Normalize to broker's lot step
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
    }
    else
    {
        consecutiveLosses++;
        fibIndex++;
        if(fibIndex > 9) fibIndex = 9;
    }
}

//+------------------------------------------------------------------+
//| Count open positions by type                                      |
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

bool MaxPositionsReached()
{
    return (CountOpenPositions() >= maxOpenPositions);
}

//+------------------------------------------------------------------+
//| Close all positions (or by type in hedge mode)                   |
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
                
                // If typeToClose is specified, only close that type
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
                request.type_filling = ORDER_FILLING_IOC;
                
                OrderSend(request, result);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open position (single, hedge, or grid)                           |
//+------------------------------------------------------------------+
void OpenPosition(bool isLong, int gridLevel = 0)
{
    double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double atrAtEntry = GetATR(0);
    double sl, tp;
    CalcSLTP_fromEntry(price, isLong, atrAtEntry, sl, tp);
    
    // Skip validation if SL/TP are disabled
    // if(sl <= 0 || tp <= 0) return;
    
    // Calculate lot size
    currentLotSize = CalculateLotSize(gridLevel);
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
    
    // Comment based on mode
    string comment = "";
    if(tradingMode == GRID)
        comment = StringFormat("Grid L%d", gridLevel);
    else if(tradingMode == HEDGE)
        comment = isLong ? "Hedge Long" : "Hedge Short";
    else
        comment = isLong ? "Single Long" : "Single Short";
        
    request.comment = comment;
    request.type_filling = ORDER_FILLING_IOC;
    
    if(OrderSend(request, result))
    {
        string slStr = useStopLoss ? StringFormat("%.5f", sl) : "None";
        string tpStr = useTakeProfit ? StringFormat("%.5f", tp) : "None";
        PrintFormat("%s ENTRY: Lot=%.2f, Price=%.5f, SL=%s, TP=%s", 
                   comment, currentLotSize, price, slStr, tpStr);
        
        // Update grid tracking
        if(tradingMode == GRID)
        {
            if(isLong)
                lastGridLongPrice = price;
            else
                lastGridShortPrice = price;
        }
    }
    else
    {
        PrintFormat("%s order failed: %d - %s", comment, result.retcode, result.comment);
    }
}

//+------------------------------------------------------------------+
//| Check if should open grid order                                  |
//+------------------------------------------------------------------+
bool ShouldOpenGridOrder(bool isLong, double currentPrice)
{
    if(tradingMode != GRID) return false;
    
    double pip = GetPip();
    double gridDistance = gridSpacing * pip;
    
    if(isLong)
    {
        if(lastGridLongPrice == 0) return true;  // First grid order
        
        // Open new grid if price moved down by gridSpacing
        if(currentPrice <= lastGridLongPrice - gridDistance)
            return true;
    }
    else
    {
        if(lastGridShortPrice == 0) return true;
        
        // Open new grid if price moved up by gridSpacing
        if(currentPrice >= lastGridShortPrice + gridDistance)
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
    
    // Only process on new bar
    if(currentBar == lastBar) return;
    lastBar = currentBar;
    
    // Check news filter
    if(IsNewsTime())
    {
        // Don't trade during news time
        return;
    }
    
    // Get signals
    bool buy_signal = IsBuySignal();
    bool sell_signal = IsSellSignal();
    
    // Count positions
    int longPositions = CountPositionsByType(POSITION_TYPE_BUY);
    int shortPositions = CountPositionsByType(POSITION_TYPE_SELL);
    int totalPositions = longPositions + shortPositions;
    
    // Get current prices
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    //====================================================================
    // TRADING MODE: SINGLE DIRECTION
    //====================================================================
    if(tradingMode == SINGLE_DIRECTION)
    {
        // Close opposite direction
        if(buy_signal && shortPositions > 0)
        {
            PrintFormat("Closing SHORT positions before opening LONG");
            ClosePositions(POSITION_TYPE_SELL);
        }
        else if(sell_signal && longPositions > 0)
        {
            PrintFormat("Closing LONG positions before opening SHORT");
            ClosePositions(POSITION_TYPE_BUY);
        }
        
        // Open new position
        if(enableBuy && buy_signal && longPositions == 0 && !MaxPositionsReached())
        {
            OpenPosition(true);
        }
        else if(enableSell && sell_signal && shortPositions == 0 && !MaxPositionsReached())
        {
            OpenPosition(false);
        }
    }
    
    //====================================================================
    // TRADING MODE: HEDGE
    //====================================================================
    else if(tradingMode == HEDGE)
    {
        // Allow both long and short simultaneously
        if(enableBuy && buy_signal && !MaxPositionsReached())
        {
            OpenPosition(true);
        }
        
        if(enableSell && sell_signal && !MaxPositionsReached())
        {
            OpenPosition(false);
        }
    }
    
    //====================================================================
    // TRADING MODE: GRID
    //====================================================================
    else if(tradingMode == GRID)
    {
        // Open first grid orders on signal
        if(enableBuy && buy_signal && longPositions == 0)
        {
            OpenPosition(true, 0);
        }
        
        if(enableSell && sell_signal && shortPositions == 0)
        {
            OpenPosition(false, 0);
        }
        
        // Open additional grid levels
        if(enableBuy && longPositions > 0 && longPositions < gridLevels && !MaxPositionsReached())
        {
            if(ShouldOpenGridOrder(true, bid))
            {
                OpenPosition(true, longPositions);
            }
        }
        
        if(enableSell && shortPositions > 0 && shortPositions < gridLevels && !MaxPositionsReached())
        {
            if(ShouldOpenGridOrder(false, ask))
            {
                OpenPosition(false, shortPositions);
            }
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
                    
                    // Update ML with profit
                    if(useML)
                    {
                        UpdateMLMemoryProfit(dealProfit);
                    }
                    
                    UpdateRiskManagement(wasWin);
                    
                    // Reset grid tracking on position close
                    if(tradingMode == GRID)
                    {
                        int longPos = CountPositionsByType(POSITION_TYPE_BUY);
                        int shortPos = CountPositionsByType(POSITION_TYPE_SELL);
                        
                        if(longPos == 0) lastGridLongPrice = 0;
                        if(shortPos == 0) lastGridShortPrice = 0;
                    }
                    
                    if(wasWin)
                    {
                        PrintFormat("✅ Trade CLOSED with PROFIT: %.2f", dealProfit);
                    }
                    else
                    {
                        PrintFormat("❌ Trade CLOSED with LOSS: %.2f | Losses: %d, Next lot: %.2f", 
                                   dealProfit, consecutiveLosses, CalculateLotSize());
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
