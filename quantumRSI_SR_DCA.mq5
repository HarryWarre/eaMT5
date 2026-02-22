//+------------------------------------------------------------------+
//|                      RSI S&R DCA + Smart Hedge System            |
//|              Copyright 2024, RSI Support/Resistance Strategy     |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, RSI S&R DCA+Hedge"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "RSI Support/Resistance Strategy - No Stop Loss"
#property description "DCA + Smart Hedge Recovery System"
#property description "Based on TradingView RSI S&R Zones by DGT"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

sinput group "=== BASIC SETTINGS ==="
input int    MagicNumber     = 999777;          // 🔢 Magic Number
input double accountPer500   = 500.0;           // 💰 Account Size per 0.01 lot

sinput group "=== MULTI SYMBOL TRADING ==="
input bool   useMultiSymbol  = true;            // 🌍 Enable Multi-Symbol Trading
input string tradingSymbols  = "EURUSD,GBPUSD,USDJPY,AUDUSD"; // 📊 Trading Symbols (comma separated)
input int    maxSymbolsActive = 3;              // 🎯 Max Active Symbols at Once

sinput group "=== RSI SETTINGS ==="
input ENUM_APPLIED_PRICE rsiSource = PRICE_CLOSE; // RSI Source
input int    rsiLength       = 14;              // RSI Length
input int    rsiOverbought   = 70;              // Overbought Level
input int    rsiBullZone     = 60;              // Bull Zone Level
input int    rsiBearZone     = 40;              // Bear Zone Level
input int    rsiOversold     = 30;              // Oversold Level

sinput group "=== SIGNAL CONFIRMATION ==="
input int    confirmBars     = 2;               // Confirmation Bars
input bool   usePriceTouch   = true;            // Use Price Touch S&R
input double srTouchPips     = 5.0;             // S/R Touch Distance (pips)
input bool   useSwingFilter  = true;            // 🎯 Use Swing High/Low Filter (Better Entry)
input ENUM_TIMEFRAMES swingTimeframe = PERIOD_H1; // 📊 Swing Detection Timeframe
input int    swingLookback   = 20;              // 🔍 Swing Lookback Bars
input double swingTouchPips  = 10.0;            // 📏 Swing Touch Distance (pips)

sinput group "=== DCA + HEDGE SYSTEM ==="
input int    dcaMaxLevel     = 5;               // 📊 DCA Max Level
input double dcaStepPips     = 20.0;            // 📏 DCA Step Distance (pips)
input double dcaMultiplier   = 1.5;             // 📈 DCA Martingale Multiplier (Base)
input bool   useDynamicMultiplier = true;       // 🔥 Use Dynamic Multiplier (↑ with loss)
input double dynamicMultiplierMax = 3.0;        // 🔥 Max Dynamic Multiplier
input int    hedgeAtLevel    = 5;               // 🛡️ Activate Hedge at Level
input double hedgeMultiplier = 1.2;             // 🛡️ Hedge Volume Multiplier
input double hedgeRRRatio    = 1.0;             // 🎯 Hedge RR Ratio (1:1)
input bool   useBreakeven    = true;            // 💰 Close at Breakeven
input bool   useHedgeTPSL    = true;            // 🎯 Use Hedge TP/SL Protection
input double hedgeTPRatio    = 1.5;             // 🎯 Hedge TP Ratio (1.5 = +150% recovery)
input double hedgeSLRatio    = 3.0;             // 🛑 Hedge SL Ratio (3.0 = -300% max loss, very wide for martingale)

sinput group "=== TAKE PROFIT & TRAILING ==="
input bool   useIndividualTP = true;            // ✅ Use Individual TP for Each Order
input double individualTPPips = 50.0;           // 🎯 Individual TP (pips per order)
input bool   useTrailingStop = true;            // 📈 Use Trailing Stop
input double trailingStartPips = 20.0;          // 🚀 Trailing Start (pips in profit)
input double trailingStepPips = 10.0;           // 📊 Trailing Step (pips to move SL)

sinput group "=== RISK PROTECTION ==="
input bool   useMaxDrawdown  = true;            // 🛑 Use Max Drawdown Stop
input double maxDrawdownPct  = 20.0;            // 🛑 Max Drawdown (%)
input bool   useDailyTarget  = false;           // 💰 Use Daily Target
input double dailyTarget     = 1000.0;          // 💰 Daily Target ($)

//+------------------------------------------------------------------+
//| RSI S&R Level Structure                                           |
//+------------------------------------------------------------------+
struct RSI_SR_Level {
    double price;                 // Support/Resistance price
    int rsiValue;                 // RSI value at formation (70, 60, 40, 30)
    datetime formTime;            // Formation time
    bool isResistance;            // true=resistance, false=support
    bool isActive;                // Is level still active?
    int touchCount;               // Number of touches
};

//+------------------------------------------------------------------+
//| DCA Position Structure                                            |
//+------------------------------------------------------------------+
struct DCAPosition {
    ulong ticket;                 // Position ticket
    ENUM_POSITION_TYPE type;      // BUY or SELL
    double lots;                  // Lot size
    double openPrice;             // Open price
    double currentProfit;         // Current P/L
    datetime openTime;            // Open time
    int dcaLevel;                 // DCA level
    bool isHedge;                 // Is hedge?
};

//+------------------------------------------------------------------+
//| DCA Sequence Structure                                            |
//+------------------------------------------------------------------+
struct DCASequence {
    ENUM_POSITION_TYPE direction; // BUY or SELL
    DCAPosition positions[20];    // Positions array
    int positionCount;            // Position count
    double totalLots;             // Total lots
    double totalProfit;           // Total P/L
    double avgPrice;              // Average price
    bool hasHedge;                // Has hedge?
    ulong hedgeTicket;            // Hedge ticket
    double hedgeLots;             // Hedge lots
    datetime lastDCATime;         // Last DCA time
    bool isActive;                // Active?
    double entryRSI;              // RSI at entry
};

//+------------------------------------------------------------------+
//| Symbol Data Structure                                             |
//+------------------------------------------------------------------+
struct SymbolData {
    string symbol;                    // Symbol name
    int handleRSI;                    // RSI indicator handle
    double pipSize;                   // Pip size for this symbol
    DCASequence sequences[2];         // BUY and SELL sequences
    RSI_SR_Level srLevels[100];       // S/R levels
    int srLevelCount;                 // Number of S/R levels
    bool isActive;                    // Is symbol active?
    datetime lastBarTime;             // Last processed bar
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

// Multi-Symbol Data
SymbolData symbolData[20];            // Support up to 20 symbols
int symbolCount = 0;                  // Number of active symbols
string symbolList[];                  // List of symbols to trade

// Legacy variables (for backward compatibility)
DCASequence dcaSequences[2];
RSI_SR_Level rsiSRLevels[100];
int srLevelCount = 0;
int handleRSI;

// Price tracking
double currentEquity = 0;
double peakEquity = 0;
double currentDrawdown = 0;
double dailyPL = 0;
datetime lastDailyReset = 0;

// Pip size
double pipSize = 0;

// Statistics
int totalSequences = 0;
int winSequences = 0;
double totalProfit = 0;

// Martingale tracking (after sequence loss)
int consecutiveLosses = 0;        // Track consecutive losing sequences
double currentMartingaleMultiplier = 1.0;  // Current lot multiplier after losses

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("🚀 RSI S&R DCA+Hedge EA Starting...");
    Print("========================================");
    
    // Initialize multi-symbol or single symbol
    if(useMultiSymbol)
    {
        if(!InitializeMultiSymbol())
        {
            Print("❌ Failed to initialize multi-symbol trading");
            return INIT_FAILED;
        }
    }
    else
    {
        // Single symbol mode (current chart)
        if(!InitializeSingleSymbol(_Symbol))
        {
            Print("❌ Failed to initialize single symbol");
            return INIT_FAILED;
        }
    }
    
    // Set initial equity
    currentEquity = AccountInfoDouble(ACCOUNT_BALANCE);
    peakEquity = currentEquity;
    
    PrintConfiguration();
    
    Print("✅ RSI S&R DCA+Hedge EA Initialized");
    Print("========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize Multi-Symbol Trading                                   |
//+------------------------------------------------------------------+
bool InitializeMultiSymbol()
{
    Print("🌍 Initializing Multi-Symbol Trading...");
    
    // Parse symbol list
    symbolCount = ParseSymbolList(tradingSymbols, symbolList);
    
    if(symbolCount == 0)
    {
        Print("❌ No valid symbols found in list");
        return false;
    }
    
    PrintFormat("📊 Found %d symbols to trade", symbolCount);
    
    // Initialize each symbol
    for(int i = 0; i < symbolCount; i++)
    {
        string symbol = symbolList[i];
        
        if(!InitializeSingleSymbol(symbol, i))
        {
            PrintFormat("⚠️ Failed to initialize %s, skipping...", symbol);
            continue;
        }
        
        PrintFormat("✅ Initialized: %s", symbol);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Single Symbol                                          |
//+------------------------------------------------------------------+
bool InitializeSingleSymbol(string symbol, int index = 0)
{
    // Check if symbol exists
    if(!SymbolSelect(symbol, true))
    {
        PrintFormat("❌ Symbol %s not found in Market Watch", symbol);
        return false;
    }
    
    // Calculate pip size
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipSz = (digits == 3 || digits == 5) ? point * 10 : point;
    
    // Initialize RSI
    int rsiHandle = iRSI(symbol, PERIOD_CURRENT, rsiLength, rsiSource);
    if(rsiHandle == INVALID_HANDLE)
    {
        PrintFormat("❌ Failed to create RSI for %s", symbol);
        return false;
    }
    
    // Store symbol data
    symbolData[index].symbol = symbol;
    symbolData[index].handleRSI = rsiHandle;
    symbolData[index].pipSize = pipSz;
    symbolData[index].srLevelCount = 0;
    symbolData[index].isActive = true;
    symbolData[index].lastBarTime = 0;
    
    // Initialize DCA sequences for this symbol
    for(int i = 0; i < 2; i++)
    {
        symbolData[index].sequences[i].direction = (i == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        symbolData[index].sequences[i].positionCount = 0;
        symbolData[index].sequences[i].totalLots = 0;
        symbolData[index].sequences[i].totalProfit = 0;
        symbolData[index].sequences[i].avgPrice = 0;
        symbolData[index].sequences[i].hasHedge = false;
        symbolData[index].sequences[i].hedgeTicket = 0;
        symbolData[index].sequences[i].hedgeLots = 0;
        symbolData[index].sequences[i].lastDCATime = 0;
        symbolData[index].sequences[i].isActive = false;
        symbolData[index].sequences[i].entryRSI = 0;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Parse Symbol List                                                 |
//+------------------------------------------------------------------+
int ParseSymbolList(string symbolString, string &outputArray[])
{
    string temp[];
    int count = StringSplit(symbolString, ',', temp);
    
    if(count <= 0) return 0;
    
    ArrayResize(outputArray, count);
    
    for(int i = 0; i < count; i++)
    {
        // Remove spaces
        StringTrimLeft(temp[i]);
        StringTrimRight(temp[i]);
        outputArray[i] = temp[i];
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("========================================");
    Print("👋 RSI S&R DCA+Hedge EA Stopping...");
    
    PrintFinalStats();
    
    if(handleRSI != INVALID_HANDLE) 
        IndicatorRelease(handleRSI);
    
    Print("✅ EA Stopped");
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update equity and check protection
    UpdateEquityMetrics();
    
    if(CheckProtection())
        return;
    
    if(useMultiSymbol)
    {
        // Process all symbols
        for(int i = 0; i < symbolCount; i++)
        {
            if(!symbolData[i].isActive) continue;
            
            ProcessSymbol(i);
        }
    }
    else
    {
        // Single symbol mode (legacy)
        ProcessSingleSymbol();
    }
}

//+------------------------------------------------------------------+
//| Process Single Symbol (Legacy Mode)                               |
//+------------------------------------------------------------------+
void ProcessSingleSymbol()
{
    // Update DCA sequences
    UpdateAllSequences();
    
    // Update Trailing Stop for all positions
    if(useTrailingStop)
        UpdateTrailingStops();
    
    // Check individual TP for each position
    if(useIndividualTP)
        CheckIndividualTakeProfit();
    
    // Check hedge TP/SL hit (auto-close main positions)
    CheckHedgeTPSL();
    
    // Check close conditions
    CheckCloseConditions();
    
    // Update RSI S/R levels on new bar
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if(currentBar != lastBar)
    {
        lastBar = currentBar;
        UpdateRSI_SR_Levels();
    }
    
    // Check for new signals
    CheckForNewSignals();
}

//+------------------------------------------------------------------+
//| Process Symbol (Multi-Symbol Mode)                                |
//+------------------------------------------------------------------+
void ProcessSymbol(int symbolIndex)
{
    string symbol = symbolData[symbolIndex].symbol;
    
    // Update sequences
    UpdateAllSequences_Multi(symbolIndex);
    
    // Update Trailing Stop
    if(useTrailingStop)
        UpdateTrailingStops_Multi(symbolIndex);
    
    // Check individual TP
    if(useIndividualTP)
        CheckIndividualTakeProfit_Multi(symbolIndex);
    
    // Check hedge TP/SL hit (auto-close main positions)
    CheckHedgeTPSL_Multi(symbolIndex);
    
    // Check close conditions
    CheckCloseConditions_Multi(symbolIndex);
    
    // Update RSI S/R levels on new bar
    datetime currentBar = iTime(symbol, PERIOD_CURRENT, 0);
    
    if(currentBar != symbolData[symbolIndex].lastBarTime)
    {
        symbolData[symbolIndex].lastBarTime = currentBar;
        UpdateRSI_SR_Levels_Multi(symbolIndex);
    }
    
    // Check for new signals
    CheckForNewSignals_Multi(symbolIndex);
}

//+------------------------------------------------------------------+
//| Print Configuration                                               |
//+------------------------------------------------------------------+
void PrintConfiguration()
{
    Print("📊 === RSI S&R CONFIGURATION ===");
    PrintFormat("RSI Length: %d", rsiLength);
    PrintFormat("Overbought: %d | Bull Zone: %d", rsiOverbought, rsiBullZone);
    PrintFormat("Bear Zone: %d | Oversold: %d", rsiBearZone, rsiOversold);
    PrintFormat("Confirm Bars: %d", confirmBars);
    
    Print("\n💰 === DCA + HEDGE ===");
    PrintFormat("Max DCA Level: %d", dcaMaxLevel);
    PrintFormat("DCA Step: %.1f pips", dcaStepPips);
    PrintFormat("DCA Multiplier: %.2fx", dcaMultiplier);
    PrintFormat("Hedge at Level: %d", hedgeAtLevel);
    PrintFormat("Hedge Multiplier: %.2fx", hedgeMultiplier);
    
    Print("\n🎯 === TAKE PROFIT & TRAILING ===");
    PrintFormat("Individual TP: %s (%.1f pips)", 
               useIndividualTP ? "ON" : "OFF", individualTPPips);
    PrintFormat("Trailing Stop: %s (Start: %.1f pips, Step: %.1f pips)", 
               useTrailingStop ? "ON" : "OFF", trailingStartPips, trailingStepPips);
    
    if(useMultiSymbol)
    {
        Print("\n🌍 === MULTI-SYMBOL TRADING ===");
        PrintFormat("Symbols: %s", tradingSymbols);
        PrintFormat("Max Active: %d", maxSymbolsActive);
        PrintFormat("Total Symbols: %d", symbolCount);
    }
}

//+------------------------------------------------------------------+
//| Update RSI Support/Resistance Levels                              |
//+------------------------------------------------------------------+
void UpdateRSI_SR_Levels()
{
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3)
        return;
    
    // Get current bar prices
    double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
    double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    double avgHigh = (currentHigh + currentClose) / 2.0;
    double avgLow = (currentLow + currentClose) / 2.0;
    double currentRSI = rsi[0];
    double prevRSI = rsi[1];
    
    // Check for RSI crossovers and create S/R levels
    
    // Crossover Overbought (70) - Resistance
    if(prevRSI <= rsiOverbought && currentRSI > rsiOverbought)
    {
        AddRSI_SR_Level(avgHigh, rsiOverbought, true);
        PrintFormat("📈 RSI Resistance formed at %.5f (RSI crossed above %d)", avgHigh, rsiOverbought);
    }
    
    // Crossunder Overbought (70) - Support
    if(prevRSI >= rsiOverbought && currentRSI < rsiOverbought)
    {
        AddRSI_SR_Level(avgHigh, rsiOverbought, false);
        PrintFormat("📉 RSI Support formed at %.5f (RSI crossed below %d)", avgHigh, rsiOverbought);
    }
    
    // Bull Zone (60) crossovers
    if(prevRSI <= rsiBullZone && currentRSI > rsiBullZone)
    {
        AddRSI_SR_Level(avgHigh, rsiBullZone, true);
    }
    if(prevRSI >= rsiBullZone && currentRSI < rsiBullZone)
    {
        AddRSI_SR_Level(avgHigh, rsiBullZone, false);
    }
    
    // Bear Zone (40) crossovers
    if(prevRSI <= rsiBearZone && currentRSI > rsiBearZone)
    {
        AddRSI_SR_Level(avgLow, rsiBearZone, true);
    }
    if(prevRSI >= rsiBearZone && currentRSI < rsiBearZone)
    {
        AddRSI_SR_Level(avgLow, rsiBearZone, false);
    }
    
    // Crossover Oversold (30) - Support
    if(prevRSI <= rsiOversold && currentRSI > rsiOversold)
    {
        AddRSI_SR_Level(avgLow, rsiOversold, false);
        PrintFormat("📈 RSI Support formed at %.5f (RSI crossed above %d)", avgLow, rsiOversold);
    }
    
    // Crossunder Oversold (30) - Resistance
    if(prevRSI >= rsiOversold && currentRSI < rsiOversold)
    {
        AddRSI_SR_Level(avgLow, rsiOversold, true);
        PrintFormat("📉 RSI Resistance formed at %.5f (RSI crossed below %d)", avgLow, rsiOversold);
    }
    
    // Clean old levels (older than 50 bars)
    CleanOldSRLevels();
}

//+------------------------------------------------------------------+
//| Add RSI S/R Level                                                 |
//+------------------------------------------------------------------+
void AddRSI_SR_Level(double price, int rsiVal, bool isResist)
{
    // Check if level already exists nearby
    for(int i = 0; i < srLevelCount; i++)
    {
        if(!rsiSRLevels[i].isActive) continue;
        
        double distance = MathAbs(rsiSRLevels[i].price - price) / pipSize;
        if(distance < 10.0 && rsiSRLevels[i].isResistance == isResist)
        {
            // Update existing level
            rsiSRLevels[i].price = price;
            rsiSRLevels[i].formTime = TimeCurrent();
            rsiSRLevels[i].touchCount++;
            return;
        }
    }
    
    // Add new level
    if(srLevelCount >= 100)
    {
        // Remove oldest level
        int oldestIdx = 0;
        datetime oldestTime = rsiSRLevels[0].formTime;
        for(int i = 1; i < srLevelCount; i++)
        {
            if(rsiSRLevels[i].formTime < oldestTime)
            {
                oldestTime = rsiSRLevels[i].formTime;
                oldestIdx = i;
            }
        }
        srLevelCount--;
        for(int i = oldestIdx; i < srLevelCount; i++)
        {
            rsiSRLevels[i] = rsiSRLevels[i+1];
        }
    }
    
    rsiSRLevels[srLevelCount].price = price;
    rsiSRLevels[srLevelCount].rsiValue = rsiVal;
    rsiSRLevels[srLevelCount].formTime = TimeCurrent();
    rsiSRLevels[srLevelCount].isResistance = isResist;
    rsiSRLevels[srLevelCount].isActive = true;
    rsiSRLevels[srLevelCount].touchCount = 1;
    srLevelCount++;
}

//+------------------------------------------------------------------+
//| Clean Old S/R Levels                                              |
//+------------------------------------------------------------------+
void CleanOldSRLevels()
{
    datetime cutoffTime = TimeCurrent() - 50 * PeriodSeconds();
    
    for(int i = 0; i < srLevelCount; i++)
    {
        if(rsiSRLevels[i].formTime < cutoffTime)
        {
            rsiSRLevels[i].isActive = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Swing High                                                 |
//+------------------------------------------------------------------+
double GetSwingHigh(string symbol, ENUM_TIMEFRAMES timeframe, int lookback)
{
    double swingHigh = 0;
    
    for(int i = 2; i < lookback; i++)
    {
        double high1 = iHigh(symbol, timeframe, i - 1);
        double high0 = iHigh(symbol, timeframe, i);
        double high2 = iHigh(symbol, timeframe, i + 1);
        
        // Swing high: current bar higher than previous and next
        if(high0 > high1 && high0 > high2)
        {
            swingHigh = high0;
            break;  // Get most recent swing
        }
    }
    
    return swingHigh;
}

//+------------------------------------------------------------------+
//| Detect Swing Low                                                  |
//+------------------------------------------------------------------+
double GetSwingLow(string symbol, ENUM_TIMEFRAMES timeframe, int lookback)
{
    double swingLow = 0;
    
    for(int i = 2; i < lookback; i++)
    {
        double low1 = iLow(symbol, timeframe, i - 1);
        double low0 = iLow(symbol, timeframe, i);
        double low2 = iLow(symbol, timeframe, i + 1);
        
        // Swing low: current bar lower than previous and next
        if(low0 < low1 && low0 < low2)
        {
            swingLow = low0;
            break;  // Get most recent swing
        }
    }
    
    return swingLow;
}

//+------------------------------------------------------------------+
//| Check if Price Near Swing Level                                   |
//+------------------------------------------------------------------+
bool IsNearSwingLevel(double currentPrice, double swingLevel, double touchPips, double pipSz)
{
    if(swingLevel == 0) return false;
    
    double distance = MathAbs(currentPrice - swingLevel) / pipSz;
    return (distance <= touchPips);
}

//+------------------------------------------------------------------+
//| Check For New Trading Signals                                     |
//+------------------------------------------------------------------+
void CheckForNewSignals()
{
    // Don't open if both directions already active
    if(dcaSequences[0].isActive && dcaSequences[1].isActive)
        return;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    if(CopyBuffer(handleRSI, 0, 0, confirmBars + 1, rsi) < confirmBars + 1)
        return;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentRSI = rsi[0];
    
    // BUY Signal: RSI in oversold zone + price near support
    if(!dcaSequences[0].isActive)  // BUY sequence
    {
        bool rsiOversoldConfirmed = true;
        for(int i = 0; i < confirmBars; i++)
        {
            if(rsi[i] >= rsiOversold)
            {
                rsiOversoldConfirmed = false;
                break;
            }
        }
        
        if(rsiOversoldConfirmed)
        {
            // Check if price near support level
            bool nearSupport = false;
            
            if(usePriceTouch)
            {
                for(int i = 0; i < srLevelCount; i++)
                {
                    if(!rsiSRLevels[i].isActive || rsiSRLevels[i].isResistance)
                        continue;
                    
                    double distance = MathAbs(currentPrice - rsiSRLevels[i].price) / pipSize;
                    if(distance <= srTouchPips)
                    {
                        nearSupport = true;
                        break;
                    }
                }
            }
            else
            {
                nearSupport = true;  // Just use RSI signal
            }
            
            // NEW: Check swing low filter
            bool swingConfirmed = true;
            if(useSwingFilter)
            {
                double swingLow = GetSwingLow(_Symbol, swingTimeframe, swingLookback);
                swingConfirmed = IsNearSwingLevel(currentPrice, swingLow, swingTouchPips, pipSize);
                
                if(swingConfirmed)
                {
                    PrintFormat("🎯 SWING LOW detected at %.5f (distance: %.1f pips)", 
                               swingLow, MathAbs(currentPrice - swingLow) / pipSize);
                }
                else
                {
                    PrintFormat("⏭️ Skip BUY: Not near swing low (swing: %.5f, current: %.5f)", 
                               swingLow, currentPrice);
                }
            }
            
            if((nearSupport || !usePriceTouch) && swingConfirmed)
            {
                PrintFormat("🔵 BUY SIGNAL: RSI=%.1f (Oversold), Price=%.5f", currentRSI, currentPrice);
                OpenNewSequence(0, currentRSI);  // Index 0 = BUY
            }
        }
    }
    
    // SELL Signal: RSI in overbought zone + price near resistance
    if(!dcaSequences[1].isActive)  // SELL sequence
    {
        bool rsiOverboughtConfirmed = true;
        for(int i = 0; i < confirmBars; i++)
        {
            if(rsi[i] <= rsiOverbought)
            {
                rsiOverboughtConfirmed = false;
                break;
            }
        }
        
        if(rsiOverboughtConfirmed)
        {
            // Check if price near resistance level
            bool nearResistance = false;
            
            if(usePriceTouch)
            {
                for(int i = 0; i < srLevelCount; i++)
                {
                    if(!rsiSRLevels[i].isActive || !rsiSRLevels[i].isResistance)
                        continue;
                    
                    double distance = MathAbs(currentPrice - rsiSRLevels[i].price) / pipSize;
                    if(distance <= srTouchPips)
                    {
                        nearResistance = true;
                        break;
                    }
                }
            }
            else
            {
                nearResistance = true;  // Just use RSI signal
            }
            
            // NEW: Check swing high filter
            bool swingConfirmed = true;
            if(useSwingFilter)
            {
                double swingHigh = GetSwingHigh(_Symbol, swingTimeframe, swingLookback);
                swingConfirmed = IsNearSwingLevel(currentPrice, swingHigh, swingTouchPips, pipSize);
                
                if(swingConfirmed)
                {
                    PrintFormat("🎯 SWING HIGH detected at %.5f (distance: %.1f pips)", 
                               swingHigh, MathAbs(currentPrice - swingHigh) / pipSize);
                }
                else
                {
                    PrintFormat("⏭️ Skip SELL: Not near swing high (swing: %.5f, current: %.5f)", 
                               swingHigh, currentPrice);
                }
            }
            
            if((nearResistance || !usePriceTouch) && swingConfirmed)
            {
                PrintFormat("🔴 SELL SIGNAL: RSI=%.1f (Overbought), Price=%.5f", currentRSI, currentPrice);
                OpenNewSequence(1, currentRSI);  // Index 1 = SELL
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open New DCA Sequence                                             |
//+------------------------------------------------------------------+
void OpenNewSequence(int seqIdx, double entryRSI)
{
    double baseLot = CalculateBaseLot();
    double lots = CalculateDCALot(1, baseLot);
    
    // Apply martingale multiplier after consecutive losses
    lots = lots * currentMartingaleMultiplier;
    
    // Normalize
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    lots = MathFloor(lots / lotStep) * lotStep;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = (dcaSequences[seqIdx].direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = (request.type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = StringFormat("RSI_SR_L1_M%.1fx", currentMartingaleMultiplier);
    request.sl = 0;  // NO STOP LOSS
    request.tp = 0;  // NO TAKE PROFIT
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            if(currentMartingaleMultiplier > 1.0)
            {
                PrintFormat("🎯 NEW SEQUENCE (MARTINGALE %.1fx): %s %.2f lots @ %.5f (RSI=%.1f) [After %d losses]", 
                           currentMartingaleMultiplier,
                           (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                           lots, request.price, entryRSI, consecutiveLosses);
            }
            else
            {
                PrintFormat("🎯 NEW SEQUENCE: %s %.2f lots @ %.5f (RSI=%.1f)", 
                           (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                           lots, request.price, entryRSI);
            }
            
            // Initialize sequence
            dcaSequences[seqIdx].positionCount = 1;
            dcaSequences[seqIdx].positions[0].ticket = result.order;
            dcaSequences[seqIdx].positions[0].type = dcaSequences[seqIdx].direction;
            dcaSequences[seqIdx].positions[0].lots = lots;
            dcaSequences[seqIdx].positions[0].openPrice = request.price;
            dcaSequences[seqIdx].positions[0].currentProfit = 0;
            dcaSequences[seqIdx].positions[0].openTime = TimeCurrent();
            dcaSequences[seqIdx].positions[0].dcaLevel = 1;
            dcaSequences[seqIdx].positions[0].isHedge = false;
            
            dcaSequences[seqIdx].totalLots = lots;
            dcaSequences[seqIdx].avgPrice = request.price;
            dcaSequences[seqIdx].hasHedge = false;
            dcaSequences[seqIdx].lastDCATime = TimeCurrent();
            dcaSequences[seqIdx].isActive = true;
            dcaSequences[seqIdx].entryRSI = entryRSI;
        }
    }
}

//+------------------------------------------------------------------+
//| Update All Sequences (Single Symbol)                              |
//+------------------------------------------------------------------+
void UpdateAllSequences()
{
    for(int i = 0; i < 2; i++)
    {
        if(!dcaSequences[i].isActive) continue;
        
        UpdateSequenceData(i);
        CheckDCACondition(i);
        
        // Check if need hedge
        if(!dcaSequences[i].hasHedge && dcaSequences[i].positionCount >= hedgeAtLevel)
        {
            OpenHedge(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Update All Sequences (Multi-Symbol)                               |
//+------------------------------------------------------------------+
void UpdateAllSequences_Multi(int symbolIndex)
{
    for(int i = 0; i < 2; i++)
    {
        if(!symbolData[symbolIndex].sequences[i].isActive) continue;
        
        UpdateSequenceData_Multi(symbolIndex, i);
        CheckDCACondition_Multi(symbolIndex, i);
        
        // Check if need hedge
        if(!symbolData[symbolIndex].sequences[i].hasHedge && 
           symbolData[symbolIndex].sequences[i].positionCount >= hedgeAtLevel)
        {
            OpenHedge_Multi(symbolIndex, i);
        }
    }
}

//+------------------------------------------------------------------+
//| Update Sequence Data (Single Symbol)                              |
//+------------------------------------------------------------------+
void UpdateSequenceData(int seqIdx)
{
    dcaSequences[seqIdx].totalLots = 0;
    dcaSequences[seqIdx].totalProfit = 0;
    double sumPriceLots = 0;
    
    // Update positions
    for(int j = 0; j < dcaSequences[seqIdx].positionCount; j++)
    {
        ulong ticket = dcaSequences[seqIdx].positions[j].ticket;
        
        if(PositionSelectByTicket(ticket))
        {
            double lots = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            dcaSequences[seqIdx].positions[j].lots = lots;
            dcaSequences[seqIdx].positions[j].currentProfit = profit;
            dcaSequences[seqIdx].positions[j].openPrice = openPrice;
            
            dcaSequences[seqIdx].totalLots += lots;
            dcaSequences[seqIdx].totalProfit += profit;
            sumPriceLots += openPrice * lots;
        }
    }
    
    if(dcaSequences[seqIdx].totalLots > 0)
        dcaSequences[seqIdx].avgPrice = sumPriceLots / dcaSequences[seqIdx].totalLots;
    
    // Update hedge
    if(dcaSequences[seqIdx].hasHedge && dcaSequences[seqIdx].hedgeTicket > 0)
    {
        if(PositionSelectByTicket(dcaSequences[seqIdx].hedgeTicket))
        {
            double hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            dcaSequences[seqIdx].totalProfit += hedgeProfit;
        }
    }
}

//+------------------------------------------------------------------+
//| Update Sequence Data (Multi-Symbol)                               |
//+------------------------------------------------------------------+
void UpdateSequenceData_Multi(int symbolIndex, int seqIdx)
{
    symbolData[symbolIndex].sequences[seqIdx].totalLots = 0;
    symbolData[symbolIndex].sequences[seqIdx].totalProfit = 0;
    double sumPriceLots = 0;
    
    for(int j = 0; j < symbolData[symbolIndex].sequences[seqIdx].positionCount; j++)
    {
        ulong ticket = symbolData[symbolIndex].sequences[seqIdx].positions[j].ticket;
        
        if(PositionSelectByTicket(ticket))
        {
            double lots = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            symbolData[symbolIndex].sequences[seqIdx].positions[j].lots = lots;
            symbolData[symbolIndex].sequences[seqIdx].positions[j].currentProfit = profit;
            symbolData[symbolIndex].sequences[seqIdx].positions[j].openPrice = openPrice;
            
            symbolData[symbolIndex].sequences[seqIdx].totalLots += lots;
            symbolData[symbolIndex].sequences[seqIdx].totalProfit += profit;
            sumPriceLots += openPrice * lots;
        }
    }
    
    if(symbolData[symbolIndex].sequences[seqIdx].totalLots > 0)
        symbolData[symbolIndex].sequences[seqIdx].avgPrice = sumPriceLots / symbolData[symbolIndex].sequences[seqIdx].totalLots;
    
    if(symbolData[symbolIndex].sequences[seqIdx].hasHedge && symbolData[symbolIndex].sequences[seqIdx].hedgeTicket > 0)
    {
        if(PositionSelectByTicket(symbolData[symbolIndex].sequences[seqIdx].hedgeTicket))
        {
            double hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            symbolData[symbolIndex].sequences[seqIdx].totalProfit += hedgeProfit;
        }
    }
}

//+------------------------------------------------------------------+
//| Check DCA Condition                                               |
//+------------------------------------------------------------------+
void CheckDCACondition(int seqIdx)
{
    if(dcaSequences[seqIdx].positionCount >= dcaMaxLevel) return;
    if(dcaSequences[seqIdx].hasHedge) return;
    
    int lastIdx = dcaSequences[seqIdx].positionCount - 1;
    if(lastIdx < 0) return;
    
    double lastPrice = dcaSequences[seqIdx].positions[lastIdx].openPrice;
    double currentPrice = (dcaSequences[seqIdx].direction == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double distancePips = 0;
    
    if(dcaSequences[seqIdx].direction == POSITION_TYPE_BUY)
        distancePips = (lastPrice - currentPrice) / pipSize;
    else
        distancePips = (currentPrice - lastPrice) / pipSize;
    
    if(distancePips >= dcaStepPips)
    {
        datetime currentTime = TimeCurrent();
        if(currentTime - dcaSequences[seqIdx].lastDCATime > 60)
        {
            OpenDCAPosition(seqIdx);
        }
    }
}

//+------------------------------------------------------------------+
//| Open DCA Position                                                 |
//+------------------------------------------------------------------+
void OpenDCAPosition(int seqIdx)
{
    int newLevel = dcaSequences[seqIdx].positionCount + 1;
    double baseLot = CalculateBaseLot();
    
    // Calculate dynamic multiplier based on current loss and level
    double effectiveMultiplier = dcaMultiplier;
    
    if(useDynamicMultiplier && newLevel > 1)
    {
        // Calculate current loss percentage
        double currentLoss = 0;
        for(int j = 0; j < dcaSequences[seqIdx].positionCount; j++)
        {
            if(PositionSelectByTicket(dcaSequences[seqIdx].positions[j].ticket))
                currentLoss += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
        
        if(currentLoss < 0)
        {
            double lossPercent = MathAbs(currentLoss) / AccountInfoDouble(ACCOUNT_BALANCE) * 100.0;
            
            // Progressive multiplier: increases with BOTH loss and level
            // Formula: baseMultiplier + (level × 0.2) + (lossPercent × 0.3)
            // Level 2: 1.5 + 0.4 + (loss%) = starts at 1.9+
            // Level 3: 1.5 + 0.6 + (loss%) = starts at 2.1+
            // Level 4: 1.5 + 0.8 + (loss%) = starts at 2.3+
            // Level 5: 1.5 + 1.0 + (loss%) = starts at 2.5+
            
            double levelBonus = (newLevel - 1) * 0.2;  // Each level adds 0.2
            double lossBonus = lossPercent * 0.3;       // Each 1% loss adds 0.3
            
            effectiveMultiplier = dcaMultiplier + levelBonus + lossBonus;
            effectiveMultiplier = MathMin(effectiveMultiplier, dynamicMultiplierMax);
            
            PrintFormat("🔥 Dynamic Multiplier: %.2f (Level %d + Loss: $%.2f = %.2f%% of balance)", 
                       effectiveMultiplier, newLevel, MathAbs(currentLoss), lossPercent);
        }
        else
        {
            // No loss yet, use progressive by level only
            double levelBonus = (newLevel - 1) * 0.2;
            effectiveMultiplier = dcaMultiplier + levelBonus;
            effectiveMultiplier = MathMin(effectiveMultiplier, dynamicMultiplierMax);
            
            PrintFormat("🔥 Dynamic Multiplier: %.2f (Level %d bonus)", 
                       effectiveMultiplier, newLevel);
        }
    }
    
    // Calculate lot with dynamic multiplier
    double lots = baseLot * MathPow(effectiveMultiplier, newLevel - 1);
    
    PrintFormat("💰 Lot Calculation: Base %.4f × %.2f^%d = %.4f lots", 
               baseLot, effectiveMultiplier, newLevel - 1, lots);
    
    // Normalize
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    lots = MathFloor(lots / lotStep) * lotStep;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = (dcaSequences[seqIdx].direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = (request.type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = StringFormat("RSI_SR_L%d", newLevel);
    request.sl = 0;
    request.tp = 0;
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("📊 DCA Level %d: %s %.2f lots @ %.5f", 
                       newLevel,
                       (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                       lots, request.price);
            
            int pos = dcaSequences[seqIdx].positionCount;
            dcaSequences[seqIdx].positions[pos].ticket = result.order;
            dcaSequences[seqIdx].positions[pos].type = dcaSequences[seqIdx].direction;
            dcaSequences[seqIdx].positions[pos].lots = lots;
            dcaSequences[seqIdx].positions[pos].openPrice = request.price;
            dcaSequences[seqIdx].positions[pos].currentProfit = 0;
            dcaSequences[seqIdx].positions[pos].openTime = TimeCurrent();
            dcaSequences[seqIdx].positions[pos].dcaLevel = newLevel;
            dcaSequences[seqIdx].positions[pos].isHedge = false;
            
            dcaSequences[seqIdx].positionCount++;
            dcaSequences[seqIdx].lastDCATime = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| Open Hedge                                                        |
//+------------------------------------------------------------------+
void OpenHedge(int seqIdx)
{
    if(dcaSequences[seqIdx].hasHedge) return;
    
    // Calculate current main positions loss
    double mainLoss = 0;
    for(int j = 0; j < dcaSequences[seqIdx].positionCount; j++)
    {
        if(PositionSelectByTicket(dcaSequences[seqIdx].positions[j].ticket))
            mainLoss += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    
    double hedgeLots = dcaSequences[seqIdx].totalLots * hedgeMultiplier;
    
    // Normalize
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    hedgeLots = MathMax(hedgeLots, minLot);
    hedgeLots = MathMin(hedgeLots, maxLot);
    hedgeLots = MathFloor(hedgeLots / lotStep) * lotStep;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = hedgeLots;
    request.type = (dcaSequences[seqIdx].direction == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = "RSI_SR_HEDGE";
    
    // Calculate TP/SL for hedge if enabled
    if(useHedgeTPSL && mainLoss < 0)
    {
        double absMainLoss = MathAbs(mainLoss);
        
        // TP: Main loss * TP ratio (e.g., $100 loss → $120 TP)
        double targetProfit = absMainLoss * hedgeTPRatio;
        double tpDistance = (targetProfit / hedgeLots) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        
        // SL: Main loss * SL ratio (e.g., $100 loss → $50 SL)
        double maxLoss = absMainLoss * hedgeSLRatio;
        double slDistance = (maxLoss / hedgeLots) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        
        if(request.type == ORDER_TYPE_BUY)
        {
            request.tp = NormalizeDouble(request.price + tpDistance * SymbolInfoDouble(_Symbol, SYMBOL_POINT), digits);
            request.sl = NormalizeDouble(request.price - slDistance * SymbolInfoDouble(_Symbol, SYMBOL_POINT), digits);
        }
        else
        {
            request.tp = NormalizeDouble(request.price - tpDistance * SymbolInfoDouble(_Symbol, SYMBOL_POINT), digits);
            request.sl = NormalizeDouble(request.price + slDistance * SymbolInfoDouble(_Symbol, SYMBOL_POINT), digits);
        }
        
        PrintFormat("🛡️ Hedge TP/SL: TP=$%.2f (%.5f), SL=$%.2f (%.5f)", 
                   targetProfit, request.tp, -maxLoss, request.sl);
    }
    else
    {
        request.sl = 0;
        request.tp = 0;
    }
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("🛡️ HEDGE: %s %.2f lots @ %.5f", 
                       (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                       hedgeLots, request.price);
            
            dcaSequences[seqIdx].hasHedge = true;
            dcaSequences[seqIdx].hedgeTicket = result.order;
            dcaSequences[seqIdx].hedgeLots = hedgeLots;
        }
    }
}

//+------------------------------------------------------------------+
//| Check Individual Take Profit                                      |
//+------------------------------------------------------------------+
void CheckIndividualTakeProfit()
{
    for(int i = 0; i < 2; i++)
    {
        if(!dcaSequences[i].isActive) continue;
        
        for(int j = 0; j < dcaSequences[i].positionCount; j++)
        {
            ulong ticket = dcaSequences[i].positions[j].ticket;
            
            if(!PositionSelectByTicket(ticket)) continue;
            if(dcaSequences[i].positions[j].isHedge) continue;  // Don't TP hedge
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (dcaSequences[i].direction == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double profitPips = 0;
            
            if(dcaSequences[i].direction == POSITION_TYPE_BUY)
                profitPips = (currentPrice - openPrice) / pipSize;
            else
                profitPips = (openPrice - currentPrice) / pipSize;
            
            // Check if reached TP
            if(profitPips >= individualTPPips)
            {
                PrintFormat("🎯 Individual TP Hit: Ticket #%I64u, Profit: %.1f pips", 
                           ticket, profitPips);
                ClosePosition(ticket);
                
                // Remove position from array
                for(int k = j; k < dcaSequences[i].positionCount - 1; k++)
                {
                    dcaSequences[i].positions[k] = dcaSequences[i].positions[k+1];
                }
                dcaSequences[i].positionCount--;
                j--;  // Re-check same index
                
                // If all positions closed, reset sequence
                if(dcaSequences[i].positionCount == 0)
                {
                    dcaSequences[i].isActive = false;
                    dcaSequences[i].hasHedge = false;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Trailing Stops                                             |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    for(int i = 0; i < 2; i++)
    {
        if(!dcaSequences[i].isActive) continue;
        
        for(int j = 0; j < dcaSequences[i].positionCount; j++)
        {
            ulong ticket = dcaSequences[i].positions[j].ticket;
            
            if(!PositionSelectByTicket(ticket)) continue;
            if(dcaSequences[i].positions[j].isHedge) continue;  // Don't trail hedge
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (dcaSequences[i].direction == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            
            double profitPips = 0;
            
            if(dcaSequences[i].direction == POSITION_TYPE_BUY)
                profitPips = (currentPrice - openPrice) / pipSize;
            else
                profitPips = (openPrice - currentPrice) / pipSize;
            
            // Only trail if profit >= trailing start
            if(profitPips >= trailingStartPips)
            {
                double newSL = 0;
                
                if(dcaSequences[i].direction == POSITION_TYPE_BUY)
                {
                    // BUY: Move SL up
                    newSL = currentPrice - (trailingStepPips * pipSize);
                    
                    // Only move SL if new SL is higher
                    if(currentSL == 0 || newSL > currentSL)
                    {
                        // Make sure new SL is above open price (in profit)
                        if(newSL > openPrice)
                        {
                            ModifyPositionSL(ticket, newSL);
                        }
                    }
                }
                else
                {
                    // SELL: Move SL down
                    newSL = currentPrice + (trailingStepPips * pipSize);
                    
                    // Only move SL if new SL is lower
                    if(currentSL == 0 || newSL < currentSL)
                    {
                        // Make sure new SL is below open price (in profit)
                        if(newSL < openPrice)
                        {
                            ModifyPositionSL(ticket, newSL);
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify Position Stop Loss                                         |
//+------------------------------------------------------------------+
void ModifyPositionSL(ulong ticket, double newSL)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double currentTP = PositionGetDouble(POSITION_TP);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    request.tp = currentTP;
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("📊 Trailing Stop Updated: #%I64u, New SL: %.5f", ticket, newSL);
        }
    }
}

//+------------------------------------------------------------------+
//| Check Hedge TP/SL Hit                                             |
//+------------------------------------------------------------------+
void CheckHedgeTPSL()
{
    if(!useHedgeTPSL) return;
    
    for(int i = 0; i < 2; i++)
    {
        if(!dcaSequences[i].isActive || !dcaSequences[i].hasHedge) continue;
        
        // Check if hedge position still exists
        if(!PositionSelectByTicket(dcaSequences[i].hedgeTicket))
        {
            // Hedge was closed (TP or SL hit)
            PrintFormat("⚠️ Hedge closed for %s sequence - Closing all main positions",
                       (dcaSequences[i].direction == POSITION_TYPE_BUY) ? "BUY" : "SELL");
            
            CloseSequence(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Check Close Conditions                                            |
//+------------------------------------------------------------------+
void CheckCloseConditions()
{
    for(int i = 0; i < 2; i++)
    {
        if(!dcaSequences[i].isActive || !dcaSequences[i].hasHedge) continue;
        
        double hedgeProfit = 0;
        if(PositionSelectByTicket(dcaSequences[i].hedgeTicket))
            hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        
        double mainLoss = 0;
        for(int j = 0; j < dcaSequences[i].positionCount; j++)
        {
            if(PositionSelectByTicket(dcaSequences[i].positions[j].ticket))
                mainLoss += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
        
        bool shouldClose = false;
        string reason = "";
        
        if(useBreakeven)
        {
            double totalPL = hedgeProfit + mainLoss;
            if(totalPL >= 0)
            {
                shouldClose = true;
                reason = StringFormat("BREAKEVEN: $%.2f", totalPL);
            }
        }
        else
        {
            double requiredProfit = MathAbs(mainLoss) * hedgeRRRatio;
            if(hedgeProfit >= requiredProfit)
            {
                shouldClose = true;
                reason = StringFormat("RR 1:1: Hedge $%.2f >= $%.2f", hedgeProfit, requiredProfit);
            }
        }
        
        if(shouldClose)
        {
            PrintFormat("💰 Closing: %s - %s", 
                       (dcaSequences[i].direction == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                       reason);
            CloseSequence(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Close Sequence                                                    |
//+------------------------------------------------------------------+
void CloseSequence(int seqIdx)
{
    double finalProfit = dcaSequences[seqIdx].totalProfit;
    
    // Close hedge
    if(dcaSequences[seqIdx].hasHedge && dcaSequences[seqIdx].hedgeTicket > 0)
        ClosePosition(dcaSequences[seqIdx].hedgeTicket);
    
    // Close all positions
    for(int j = 0; j < dcaSequences[seqIdx].positionCount; j++)
        ClosePosition(dcaSequences[seqIdx].positions[j].ticket);
    
    // Update stats
    totalSequences++;
    if(finalProfit > 0)
    {
        winSequences++;
        
        // WIN: Reset martingale multiplier
        consecutiveLosses = 0;
        currentMartingaleMultiplier = 1.0;
        PrintFormat("✅ Sequence WIN: $%.2f | Martingale reset to 1.0x", finalProfit);
    }
    else
    {
        // LOSS: Increase martingale multiplier
        consecutiveLosses++;
        
        if(useDynamicMultiplier)
        {
            // Increase multiplier: 1.0 → 1.5 → 2.25 → 3.375 (× 1.5 each loss)
            currentMartingaleMultiplier *= dcaMultiplier;
            currentMartingaleMultiplier = MathMin(currentMartingaleMultiplier, dynamicMultiplierMax);
        }
        
        PrintFormat("❌ Sequence LOSS: $%.2f | Consecutive: %d | Martingale: %.2fx", 
                   finalProfit, consecutiveLosses, currentMartingaleMultiplier);
    }
    
    totalProfit += finalProfit;
    
    // Reset sequence
    dcaSequences[seqIdx].positionCount = 0;
    dcaSequences[seqIdx].totalLots = 0;
    dcaSequences[seqIdx].totalProfit = 0;
    dcaSequences[seqIdx].hasHedge = false;
    dcaSequences[seqIdx].isActive = false;
}

//+------------------------------------------------------------------+
//| Close Position                                                    |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = 50;
    request.magic = MagicNumber;
    
    OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Calculate Base Lot                                                |
//+------------------------------------------------------------------+
double CalculateBaseLot()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double baseLot = (balance / accountPer500) * 0.01;
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    baseLot = MathMax(baseLot, minLot);
    baseLot = MathMin(baseLot, maxLot);
    baseLot = MathFloor(baseLot / lotStep) * lotStep;
    
    return baseLot;
}

//+------------------------------------------------------------------+
//| Calculate DCA Lot                                                 |
//+------------------------------------------------------------------+
double CalculateDCALot(int level, double baseLot)
{
    double lot = baseLot * MathPow(dcaMultiplier, level - 1);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    lot = MathFloor(lot / lotStep) * lotStep;
    
    return lot;
}

//+------------------------------------------------------------------+
//| Update Equity Metrics                                             |
//+------------------------------------------------------------------+
void UpdateEquityMetrics()
{
    currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    if(currentEquity > peakEquity)
        peakEquity = currentEquity;
    
    if(peakEquity > 0)
        currentDrawdown = ((peakEquity - currentEquity) / peakEquity) * 100.0;
    
    // Daily P/L
    datetime currentDate = TimeCurrent();
    MqlDateTime currentDT, lastResetDT;
    TimeToStruct(currentDate, currentDT);
    TimeToStruct(lastDailyReset, lastResetDT);
    
    if(currentDT.day != lastResetDT.day)
    {
        dailyPL = 0;
        lastDailyReset = currentDate;
    }
    
    dailyPL = currentEquity - balance;
}

//+------------------------------------------------------------------+
//| Check Protection                                                  |
//+------------------------------------------------------------------+
bool CheckProtection()
{
    if(useMaxDrawdown && currentDrawdown >= maxDrawdownPct)
    {
        PrintFormat("🚨 MAX DRAWDOWN: %.2f%%", currentDrawdown);
        CloseAll();
        return true;
    }
    
    if(useDailyTarget && dailyPL >= dailyTarget)
    {
        PrintFormat("💰 DAILY TARGET: $%.2f", dailyPL);
        CloseAll();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Close All                                                         |
//+------------------------------------------------------------------+
void CloseAll()
{
    for(int i = 0; i < 2; i++)
        if(dcaSequences[i].isActive)
            CloseSequence(i);
}

//+------------------------------------------------------------------+
//| Print Final Stats                                                 |
//+------------------------------------------------------------------+
void PrintFinalStats()
{
    Print("\n📊 === FINAL STATISTICS ===");
    PrintFormat("Total Sequences: %d", totalSequences);
    if(totalSequences > 0)
    {
        PrintFormat("Win Rate: %.1f%%", (double)winSequences / totalSequences * 100);
        PrintFormat("Total Profit: $%.2f", totalProfit);
    }
    PrintFormat("Final Equity: $%.2f", currentEquity);
    PrintFormat("Max Drawdown: %.2f%%", currentDrawdown);
}

//+------------------------------------------------------------------+
//| MULTI-SYMBOL IMPLEMENTATIONS                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check DCA Condition (Multi-Symbol)                                |
//+------------------------------------------------------------------+
void CheckDCACondition_Multi(int symbolIndex, int seqIdx) 
{ 
    if(symbolData[symbolIndex].sequences[seqIdx].positionCount >= dcaMaxLevel) return;
    if(symbolData[symbolIndex].sequences[seqIdx].hasHedge) return;
    
    int lastIdx = symbolData[symbolIndex].sequences[seqIdx].positionCount - 1;
    if(lastIdx < 0) return;
    
    string symbol = symbolData[symbolIndex].symbol;
    double lastPrice = symbolData[symbolIndex].sequences[seqIdx].positions[lastIdx].openPrice;
    double currentPrice = (symbolData[symbolIndex].sequences[seqIdx].direction == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    double distancePips = 0;
    
    if(symbolData[symbolIndex].sequences[seqIdx].direction == POSITION_TYPE_BUY)
        distancePips = (lastPrice - currentPrice) / symbolData[symbolIndex].pipSize;
    else
        distancePips = (currentPrice - lastPrice) / symbolData[symbolIndex].pipSize;
    
    if(distancePips >= dcaStepPips)
    {
        datetime currentTime = TimeCurrent();
        if(currentTime - symbolData[symbolIndex].sequences[seqIdx].lastDCATime > 60)
        {
            OpenDCAPosition_Multi(symbolIndex, seqIdx);
        }
    }
}

//+------------------------------------------------------------------+
//| Open DCA Position (Multi-Symbol)                                  |
//+------------------------------------------------------------------+
void OpenDCAPosition_Multi(int symbolIndex, int seqIdx)
{
    int newLevel = symbolData[symbolIndex].sequences[seqIdx].positionCount + 1;
    double baseLot = CalculateBaseLot();
    string symbol = symbolData[symbolIndex].symbol;
    
    // Calculate dynamic multiplier based on current loss and level
    double effectiveMultiplier = dcaMultiplier;
    
    if(useDynamicMultiplier && newLevel > 1)
    {
        // Calculate current loss percentage
        double currentLoss = 0;
        for(int j = 0; j < symbolData[symbolIndex].sequences[seqIdx].positionCount; j++)
        {
            if(PositionSelectByTicket(symbolData[symbolIndex].sequences[seqIdx].positions[j].ticket))
                currentLoss += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
        
        if(currentLoss < 0)
        {
            double lossPercent = MathAbs(currentLoss) / AccountInfoDouble(ACCOUNT_BALANCE) * 100.0;
            
            // Progressive multiplier: increases with BOTH loss and level
            double levelBonus = (newLevel - 1) * 0.2;  // Each level adds 0.2
            double lossBonus = lossPercent * 0.3;       // Each 1% loss adds 0.3
            
            effectiveMultiplier = dcaMultiplier + levelBonus + lossBonus;
            effectiveMultiplier = MathMin(effectiveMultiplier, dynamicMultiplierMax);
            
            PrintFormat("🔥 [%s] Dynamic Multiplier: %.2f (Level %d + Loss: $%.2f = %.2f%% of balance)", 
                       symbol, effectiveMultiplier, newLevel, MathAbs(currentLoss), lossPercent);
        }
        else
        {
            // No loss yet, use progressive by level only
            double levelBonus = (newLevel - 1) * 0.2;
            effectiveMultiplier = dcaMultiplier + levelBonus;
            effectiveMultiplier = MathMin(effectiveMultiplier, dynamicMultiplierMax);
            
            PrintFormat("🔥 [%s] Dynamic Multiplier: %.2f (Level %d bonus)", 
                       symbol, effectiveMultiplier, newLevel);
        }
    }
    
    // Calculate lot with dynamic multiplier
    double lots = baseLot * MathPow(effectiveMultiplier, newLevel - 1);
    
    PrintFormat("💰 [%s] Lot Calculation: Base %.4f × %.2f^%d = %.4f lots", 
               symbol, baseLot, effectiveMultiplier, newLevel - 1, lots);
    
    // Normalize
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    lots = MathFloor(lots / lotStep) * lotStep;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lots;
    request.type = (symbolData[symbolIndex].sequences[seqIdx].direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = (request.type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = StringFormat("RSI_SR_%s_L%d", symbol, newLevel);
    request.sl = 0;
    request.tp = 0;
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("📊 [%s] DCA Level %d: %s %.2f lots @ %.5f", 
                       symbol, newLevel,
                       (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                       lots, request.price);
            
            int pos = symbolData[symbolIndex].sequences[seqIdx].positionCount;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].ticket = result.order;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].type = symbolData[symbolIndex].sequences[seqIdx].direction;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].lots = lots;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].openPrice = request.price;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].currentProfit = 0;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].openTime = TimeCurrent();
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].dcaLevel = newLevel;
            symbolData[symbolIndex].sequences[seqIdx].positions[pos].isHedge = false;
            
            symbolData[symbolIndex].sequences[seqIdx].positionCount++;
            symbolData[symbolIndex].sequences[seqIdx].lastDCATime = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| Open Hedge (Multi-Symbol)                                         |
//+------------------------------------------------------------------+
void OpenHedge_Multi(int symbolIndex, int seqIdx) 
{ 
    if(symbolData[symbolIndex].sequences[seqIdx].hasHedge) return;
    
    string symbol = symbolData[symbolIndex].symbol;
    
    // Calculate current main positions loss
    double mainLoss = 0;
    for(int j = 0; j < symbolData[symbolIndex].sequences[seqIdx].positionCount; j++)
    {
        if(PositionSelectByTicket(symbolData[symbolIndex].sequences[seqIdx].positions[j].ticket))
            mainLoss += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    
    double hedgeLots = symbolData[symbolIndex].sequences[seqIdx].totalLots * hedgeMultiplier;
    
    // Normalize
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    hedgeLots = MathMax(hedgeLots, minLot);
    hedgeLots = MathMin(hedgeLots, maxLot);
    hedgeLots = MathFloor(hedgeLots / lotStep) * lotStep;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = hedgeLots;
    request.type = (symbolData[symbolIndex].sequences[seqIdx].direction == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = StringFormat("RSI_SR_%s_HEDGE", symbol);
    
    // Calculate TP/SL for hedge if enabled
    if(useHedgeTPSL && mainLoss < 0)
    {
        double absMainLoss = MathAbs(mainLoss);
        
        // TP: Main loss * TP ratio (e.g., $100 loss → $120 TP)
        double targetProfit = absMainLoss * hedgeTPRatio;
        double tpDistance = (targetProfit / hedgeLots) / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        
        // SL: Main loss * SL ratio (e.g., $100 loss → $50 SL)
        double maxLoss = absMainLoss * hedgeSLRatio;
        double slDistance = (maxLoss / hedgeLots) / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        if(request.type == ORDER_TYPE_BUY)
        {
            request.tp = NormalizeDouble(request.price + tpDistance * SymbolInfoDouble(symbol, SYMBOL_POINT), digits);
            request.sl = NormalizeDouble(request.price - slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT), digits);
        }
        else
        {
            request.tp = NormalizeDouble(request.price - tpDistance * SymbolInfoDouble(symbol, SYMBOL_POINT), digits);
            request.sl = NormalizeDouble(request.price + slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT), digits);
        }
        
        PrintFormat("🛡️ [%s] Hedge TP/SL: TP=$%.2f (%.5f), SL=$%.2f (%.5f)", 
                   symbol, targetProfit, request.tp, -maxLoss, request.sl);
    }
    else
    {
        request.sl = 0;
        request.tp = 0;
    }
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("🛡️ [%s] HEDGE: %s %.2f lots @ %.5f", 
                       symbol,
                       (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                       hedgeLots, request.price);
            
            symbolData[symbolIndex].sequences[seqIdx].hasHedge = true;
            symbolData[symbolIndex].sequences[seqIdx].hedgeTicket = result.order;
            symbolData[symbolIndex].sequences[seqIdx].hedgeLots = hedgeLots;
        }
    }
}

//+------------------------------------------------------------------+
//| Update Trailing Stops (Multi-Symbol)                              |
//+------------------------------------------------------------------+
void UpdateTrailingStops_Multi(int symbolIndex) 
{ 
    string symbol = symbolData[symbolIndex].symbol;
    
    for(int i = 0; i < 2; i++)
    {
        if(!symbolData[symbolIndex].sequences[i].isActive) continue;
        
        for(int j = 0; j < symbolData[symbolIndex].sequences[i].positionCount; j++)
        {
            ulong ticket = symbolData[symbolIndex].sequences[i].positions[j].ticket;
            
            if(!PositionSelectByTicket(ticket)) continue;
            if(symbolData[symbolIndex].sequences[i].positions[j].isHedge) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            
            double profitPips = 0;
            
            if(symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY)
                profitPips = (currentPrice - openPrice) / symbolData[symbolIndex].pipSize;
            else
                profitPips = (openPrice - currentPrice) / symbolData[symbolIndex].pipSize;
            
            if(profitPips >= trailingStartPips)
            {
                double newSL = 0;
                
                if(symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY)
                {
                    newSL = currentPrice - (trailingStepPips * symbolData[symbolIndex].pipSize);
                    
                    if(currentSL == 0 || newSL > currentSL)
                    {
                        if(newSL > openPrice)
                        {
                            ModifyPositionSL_Multi(ticket, newSL, symbol);
                        }
                    }
                }
                else
                {
                    newSL = currentPrice + (trailingStepPips * symbolData[symbolIndex].pipSize);
                    
                    if(currentSL == 0 || newSL < currentSL)
                    {
                        if(newSL < openPrice)
                        {
                            ModifyPositionSL_Multi(ticket, newSL, symbol);
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify Position SL (Multi-Symbol)                                 |
//+------------------------------------------------------------------+
void ModifyPositionSL_Multi(ulong ticket, double newSL, string symbol)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double currentTP = PositionGetDouble(POSITION_TP);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = symbol;
    request.sl = NormalizeDouble(newSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    request.tp = currentTP;
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("📊 [%s] Trailing Stop Updated: #%I64u, New SL: %.5f", symbol, ticket, newSL);
        }
    }
}

//+------------------------------------------------------------------+
//| Check Individual Take Profit (Multi-Symbol)                       |
//+------------------------------------------------------------------+
void CheckIndividualTakeProfit_Multi(int symbolIndex) 
{ 
    string symbol = symbolData[symbolIndex].symbol;
    
    for(int i = 0; i < 2; i++)
    {
        if(!symbolData[symbolIndex].sequences[i].isActive) continue;
        
        for(int j = 0; j < symbolData[symbolIndex].sequences[i].positionCount; j++)
        {
            ulong ticket = symbolData[symbolIndex].sequences[i].positions[j].ticket;
            
            if(!PositionSelectByTicket(ticket)) continue;
            if(symbolData[symbolIndex].sequences[i].positions[j].isHedge) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(symbol, SYMBOL_ASK);
            
            double profitPips = 0;
            
            if(symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY)
                profitPips = (currentPrice - openPrice) / symbolData[symbolIndex].pipSize;
            else
                profitPips = (openPrice - currentPrice) / symbolData[symbolIndex].pipSize;
            
            if(profitPips >= individualTPPips)
            {
                PrintFormat("🎯 [%s] Individual TP Hit: Ticket #%I64u, Profit: %.1f pips", 
                           symbol, ticket, profitPips);
                ClosePosition_Multi(ticket, symbol);
                
                // Remove position from array
                for(int k = j; k < symbolData[symbolIndex].sequences[i].positionCount - 1; k++)
                {
                    symbolData[symbolIndex].sequences[i].positions[k] = symbolData[symbolIndex].sequences[i].positions[k+1];
                }
                symbolData[symbolIndex].sequences[i].positionCount--;
                j--;
                
                if(symbolData[symbolIndex].sequences[i].positionCount == 0)
                {
                    symbolData[symbolIndex].sequences[i].isActive = false;
                    symbolData[symbolIndex].sequences[i].hasHedge = false;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check Hedge TP/SL Hit (Multi-Symbol)                              |
//+------------------------------------------------------------------+
void CheckHedgeTPSL_Multi(int symbolIndex)
{
    if(!useHedgeTPSL) return;
    
    string symbol = symbolData[symbolIndex].symbol;
    
    for(int i = 0; i < 2; i++)
    {
        if(!symbolData[symbolIndex].sequences[i].isActive || !symbolData[symbolIndex].sequences[i].hasHedge) continue;
        
        // Check if hedge position still exists
        if(!PositionSelectByTicket(symbolData[symbolIndex].sequences[i].hedgeTicket))
        {
            // Hedge was closed (TP or SL hit)
            PrintFormat("⚠️ [%s] Hedge closed for %s sequence - Closing all main positions",
                       symbol,
                       (symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY) ? "BUY" : "SELL");
            
            CloseSequence_Multi(symbolIndex, i);
        }
    }
}

//+------------------------------------------------------------------+
//| Check Close Conditions (Multi-Symbol)                             |
//+------------------------------------------------------------------+
void CheckCloseConditions_Multi(int symbolIndex) 
{ 
    string symbol = symbolData[symbolIndex].symbol;
    
    for(int i = 0; i < 2; i++)
    {
        if(!symbolData[symbolIndex].sequences[i].isActive || !symbolData[symbolIndex].sequences[i].hasHedge) continue;
        
        double hedgeProfit = 0;
        if(PositionSelectByTicket(symbolData[symbolIndex].sequences[i].hedgeTicket))
            hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        
        double mainLoss = 0;
        for(int j = 0; j < symbolData[symbolIndex].sequences[i].positionCount; j++)
        {
            if(PositionSelectByTicket(symbolData[symbolIndex].sequences[i].positions[j].ticket))
                mainLoss += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
        
        bool shouldClose = false;
        string reason = "";
        
        if(useBreakeven)
        {
            double totalPL = hedgeProfit + mainLoss;
            if(totalPL >= 0)
            {
                shouldClose = true;
                reason = StringFormat("BREAKEVEN: $%.2f", totalPL);
            }
        }
        else
        {
            double requiredProfit = MathAbs(mainLoss) * hedgeRRRatio;
            if(hedgeProfit >= requiredProfit)
            {
                shouldClose = true;
                reason = StringFormat("RR 1:1: Hedge $%.2f >= $%.2f", hedgeProfit, requiredProfit);
            }
        }
        
        if(shouldClose)
        {
            PrintFormat("💰 [%s] Closing: %s - %s", 
                       symbol,
                       (symbolData[symbolIndex].sequences[i].direction == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                       reason);
            CloseSequence_Multi(symbolIndex, i);
        }
    }
}

//+------------------------------------------------------------------+
//| Close Sequence (Multi-Symbol)                                     |
//+------------------------------------------------------------------+
void CloseSequence_Multi(int symbolIndex, int seqIdx)
{
    string symbol = symbolData[symbolIndex].symbol;
    double finalProfit = symbolData[symbolIndex].sequences[seqIdx].totalProfit;
    
    // Close hedge
    if(symbolData[symbolIndex].sequences[seqIdx].hasHedge && symbolData[symbolIndex].sequences[seqIdx].hedgeTicket > 0)
        ClosePosition_Multi(symbolData[symbolIndex].sequences[seqIdx].hedgeTicket, symbol);
    
    // Close all positions
    for(int j = 0; j < symbolData[symbolIndex].sequences[seqIdx].positionCount; j++)
        ClosePosition_Multi(symbolData[symbolIndex].sequences[seqIdx].positions[j].ticket, symbol);
    
    // Update stats
    totalSequences++;
    if(finalProfit > 0)
    {
        winSequences++;
        
        // WIN: Reset martingale multiplier
        consecutiveLosses = 0;
        currentMartingaleMultiplier = 1.0;
        PrintFormat("✅ [%s] Sequence WIN: $%.2f | Martingale reset to 1.0x", symbol, finalProfit);
    }
    else
    {
        // LOSS: Increase martingale multiplier
        consecutiveLosses++;
        
        if(useDynamicMultiplier)
        {
            // Increase multiplier: 1.0 → 1.5 → 2.25 → 3.375 (× 1.5 each loss)
            currentMartingaleMultiplier *= dcaMultiplier;
            currentMartingaleMultiplier = MathMin(currentMartingaleMultiplier, dynamicMultiplierMax);
        }
        
        PrintFormat("❌ [%s] Sequence LOSS: $%.2f | Consecutive: %d | Martingale: %.2fx", 
                   symbol, finalProfit, consecutiveLosses, currentMartingaleMultiplier);
    }
    
    totalProfit += finalProfit;
    
    // Reset sequence
    symbolData[symbolIndex].sequences[seqIdx].positionCount = 0;
    symbolData[symbolIndex].sequences[seqIdx].totalLots = 0;
    symbolData[symbolIndex].sequences[seqIdx].totalProfit = 0;
    symbolData[symbolIndex].sequences[seqIdx].hasHedge = false;
    symbolData[symbolIndex].sequences[seqIdx].isActive = false;
}

//+------------------------------------------------------------------+
//| Close Position (Multi-Symbol)                                     |
//+------------------------------------------------------------------+
void ClosePosition_Multi(ulong ticket, string symbol)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? 
                   SymbolInfoDouble(symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(symbol, SYMBOL_ASK);
    request.deviation = 50;
    request.magic = MagicNumber;
    
    OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Update RSI S/R Levels (Multi-Symbol)                              |
//+------------------------------------------------------------------+
void UpdateRSI_SR_Levels_Multi(int symbolIndex) 
{ 
    string symbol = symbolData[symbolIndex].symbol;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    if(CopyBuffer(symbolData[symbolIndex].handleRSI, 0, 0, 3, rsi) < 3)
        return;
    
    double currentHigh = iHigh(symbol, PERIOD_CURRENT, 0);
    double currentLow = iLow(symbol, PERIOD_CURRENT, 0);
    double currentClose = iClose(symbol, PERIOD_CURRENT, 0);
    
    double avgHigh = (currentHigh + currentClose) / 2.0;
    double avgLow = (currentLow + currentClose) / 2.0;
    double currentRSI = rsi[0];
    double prevRSI = rsi[1];
    
    // Crossover Overbought (70) - Resistance
    if(prevRSI <= rsiOverbought && currentRSI > rsiOverbought)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgHigh, rsiOverbought, true);
        PrintFormat("📈 [%s] RSI Resistance at %.5f (RSI > %d)", symbol, avgHigh, rsiOverbought);
    }
    
    // Crossunder Overbought (70) - Support
    if(prevRSI >= rsiOverbought && currentRSI < rsiOverbought)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgHigh, rsiOverbought, false);
    }
    
    // Bull Zone (60) crossovers
    if(prevRSI <= rsiBullZone && currentRSI > rsiBullZone)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgHigh, rsiBullZone, true);
    }
    if(prevRSI >= rsiBullZone && currentRSI < rsiBullZone)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgHigh, rsiBullZone, false);
    }
    
    // Bear Zone (40) crossovers
    if(prevRSI <= rsiBearZone && currentRSI > rsiBearZone)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgLow, rsiBearZone, true);
    }
    if(prevRSI >= rsiBearZone && currentRSI < rsiBearZone)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgLow, rsiBearZone, false);
    }
    
    // Crossover Oversold (30) - Support
    if(prevRSI <= rsiOversold && currentRSI > rsiOversold)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgLow, rsiOversold, false);
        PrintFormat("📈 [%s] RSI Support at %.5f (RSI > %d)", symbol, avgLow, rsiOversold);
    }
    
    // Crossunder Oversold (30) - Resistance
    if(prevRSI >= rsiOversold && currentRSI < rsiOversold)
    {
        AddRSI_SR_Level_Multi(symbolIndex, avgLow, rsiOversold, true);
    }
    
    CleanOldSRLevels_Multi(symbolIndex);
}

//+------------------------------------------------------------------+
//| Add RSI S/R Level (Multi-Symbol)                                  |
//+------------------------------------------------------------------+
void AddRSI_SR_Level_Multi(int symbolIndex, double price, int rsiVal, bool isResist)
{
    int count = symbolData[symbolIndex].srLevelCount;
    
    // Check if level exists nearby
    for(int i = 0; i < count; i++)
    {
        if(!symbolData[symbolIndex].srLevels[i].isActive) continue;
        
        double distance = MathAbs(symbolData[symbolIndex].srLevels[i].price - price) / symbolData[symbolIndex].pipSize;
        if(distance < 10.0 && symbolData[symbolIndex].srLevels[i].isResistance == isResist)
        {
            symbolData[symbolIndex].srLevels[i].price = price;
            symbolData[symbolIndex].srLevels[i].formTime = TimeCurrent();
            symbolData[symbolIndex].srLevels[i].touchCount++;
            return;
        }
    }
    
    // Add new level
    if(count >= 100)
    {
        int oldestIdx = 0;
        datetime oldestTime = symbolData[symbolIndex].srLevels[0].formTime;
        for(int i = 1; i < count; i++)
        {
            if(symbolData[symbolIndex].srLevels[i].formTime < oldestTime)
            {
                oldestTime = symbolData[symbolIndex].srLevels[i].formTime;
                oldestIdx = i;
            }
        }
        count--;
        for(int i = oldestIdx; i < count; i++)
        {
            symbolData[symbolIndex].srLevels[i] = symbolData[symbolIndex].srLevels[i+1];
        }
        symbolData[symbolIndex].srLevelCount = count;
    }
    
    symbolData[symbolIndex].srLevels[count].price = price;
    symbolData[symbolIndex].srLevels[count].rsiValue = rsiVal;
    symbolData[symbolIndex].srLevels[count].formTime = TimeCurrent();
    symbolData[symbolIndex].srLevels[count].isResistance = isResist;
    symbolData[symbolIndex].srLevels[count].isActive = true;
    symbolData[symbolIndex].srLevels[count].touchCount = 1;
    symbolData[symbolIndex].srLevelCount++;
}

//+------------------------------------------------------------------+
//| Clean Old S/R Levels (Multi-Symbol)                               |
//+------------------------------------------------------------------+
void CleanOldSRLevels_Multi(int symbolIndex)
{
    datetime cutoffTime = TimeCurrent() - 50 * PeriodSeconds();
    
    for(int i = 0; i < symbolData[symbolIndex].srLevelCount; i++)
    {
        if(symbolData[symbolIndex].srLevels[i].formTime < cutoffTime)
        {
            symbolData[symbolIndex].srLevels[i].isActive = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Check For New Signals (Multi-Symbol)                              |
//+------------------------------------------------------------------+
void CheckForNewSignals_Multi(int symbolIndex) 
{ 
    // Don't open if both directions already active
    if(symbolData[symbolIndex].sequences[0].isActive && symbolData[symbolIndex].sequences[1].isActive)
        return;
    
    string symbol = symbolData[symbolIndex].symbol;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    if(CopyBuffer(symbolData[symbolIndex].handleRSI, 0, 0, confirmBars + 1, rsi) < confirmBars + 1)
        return;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double currentRSI = rsi[0];
    
    // BUY Signal
    if(!symbolData[symbolIndex].sequences[0].isActive)
    {
        bool rsiOversoldConfirmed = true;
        for(int i = 0; i < confirmBars; i++)
        {
            if(rsi[i] >= rsiOversold)
            {
                rsiOversoldConfirmed = false;
                break;
            }
        }
        
        if(rsiOversoldConfirmed)
        {
            bool nearSupport = false;
            
            if(usePriceTouch)
            {
                for(int i = 0; i < symbolData[symbolIndex].srLevelCount; i++)
                {
                    if(!symbolData[symbolIndex].srLevels[i].isActive || symbolData[symbolIndex].srLevels[i].isResistance)
                        continue;
                    
                    double distance = MathAbs(currentPrice - symbolData[symbolIndex].srLevels[i].price) / symbolData[symbolIndex].pipSize;
                    if(distance <= srTouchPips)
                    {
                        nearSupport = true;
                        break;
                    }
                }
            }
            else
            {
                nearSupport = true;
            }
            
            if(nearSupport || !usePriceTouch)
            {
                PrintFormat("🔵 [%s] BUY SIGNAL: RSI=%.1f, Price=%.5f", symbol, currentRSI, currentPrice);
                OpenNewSequence_Multi(symbolIndex, 0, currentRSI);
            }
        }
    }
    
    // SELL Signal
    if(!symbolData[symbolIndex].sequences[1].isActive)
    {
        bool rsiOverboughtConfirmed = true;
        for(int i = 0; i < confirmBars; i++)
        {
            if(rsi[i] <= rsiOverbought)
            {
                rsiOverboughtConfirmed = false;
                break;
            }
        }
        
        if(rsiOverboughtConfirmed)
        {
            bool nearResistance = false;
            
            if(usePriceTouch)
            {
                for(int i = 0; i < symbolData[symbolIndex].srLevelCount; i++)
                {
                    if(!symbolData[symbolIndex].srLevels[i].isActive || !symbolData[symbolIndex].srLevels[i].isResistance)
                        continue;
                    
                    double distance = MathAbs(currentPrice - symbolData[symbolIndex].srLevels[i].price) / symbolData[symbolIndex].pipSize;
                    if(distance <= srTouchPips)
                    {
                        nearResistance = true;
                        break;
                    }
                }
            }
            else
            {
                nearResistance = true;
            }
            
            if(nearResistance || !usePriceTouch)
            {
                PrintFormat("🔴 [%s] SELL SIGNAL: RSI=%.1f, Price=%.5f", symbol, currentRSI, currentPrice);
                OpenNewSequence_Multi(symbolIndex, 1, currentRSI);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open New Sequence (Multi-Symbol)                                  |
//+------------------------------------------------------------------+
void OpenNewSequence_Multi(int symbolIndex, int seqIdx, double entryRSI)
{
    double baseLot = CalculateBaseLot();
    double lots = CalculateDCALot(1, baseLot);
    
    string symbol = symbolData[symbolIndex].symbol;
    
    // Apply martingale multiplier after consecutive losses
    lots = lots * currentMartingaleMultiplier;
    
    // Normalize
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    lots = MathFloor(lots / lotStep) * lotStep;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lots;
    request.type = (symbolData[symbolIndex].sequences[seqIdx].direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = (request.type == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(symbol, SYMBOL_BID);
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = StringFormat("RSI_SR_%s_L1_M%.1fx", symbol, currentMartingaleMultiplier);
    request.sl = 0;
    request.tp = 0;
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            if(currentMartingaleMultiplier > 1.0)
            {
                PrintFormat("🎯 [%s] NEW SEQUENCE (MARTINGALE %.1fx): %s %.2f lots @ %.5f (RSI=%.1f) [After %d losses]", 
                           symbol, currentMartingaleMultiplier,
                           (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                           lots, request.price, entryRSI, consecutiveLosses);
            }
            else
            {
                PrintFormat("🎯 [%s] NEW SEQUENCE: %s %.2f lots @ %.5f (RSI=%.1f)", 
                           symbol,
                           (request.type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
                           lots, request.price, entryRSI);
            }
            
            symbolData[symbolIndex].sequences[seqIdx].positionCount = 1;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].ticket = result.order;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].type = symbolData[symbolIndex].sequences[seqIdx].direction;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].lots = lots;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].openPrice = request.price;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].currentProfit = 0;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].openTime = TimeCurrent();
            symbolData[symbolIndex].sequences[seqIdx].positions[0].dcaLevel = 1;
            symbolData[symbolIndex].sequences[seqIdx].positions[0].isHedge = false;
            
            symbolData[symbolIndex].sequences[seqIdx].totalLots = lots;
            symbolData[symbolIndex].sequences[seqIdx].avgPrice = request.price;
            symbolData[symbolIndex].sequences[seqIdx].hasHedge = false;
            symbolData[symbolIndex].sequences[seqIdx].lastDCATime = TimeCurrent();
            symbolData[symbolIndex].sequences[seqIdx].isActive = true;
            symbolData[symbolIndex].sequences[seqIdx].entryRSI = entryRSI;
        }
    }
}
