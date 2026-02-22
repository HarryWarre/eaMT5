//+------------------------------------------------------------------+
//|                           QuantumRSI v4.0 - Multi-Timeframe ML   |
//|                        Copyright 2024, Multi-Timeframe Strategy  |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
// #property copyright "Copyright 2024, QuantumRSI v4.0 MTF"
// #property link      "https://www.mql5.com"
// #property version   "4.00"
// #property strict

// (No explicit includes — rely on MetaEditor built-ins and standard MQL5 include paths)

// Function to detect Strategy Tester; falls back to false when not compiling in MQL5
bool IsRunningInTester()
{
#ifdef __MQL5__
    // Detect Strategy Tester using terminal information (more portable than direct IsTesting() reference)
    // Use TerminalInfoInteger which is available in MQL5 to detect tester mode.
    return(TerminalInfoInteger(TERMINAL_TESTER) == 1);
#else
    return(false);
#endif
}

// (Strategy tester detection will be done locally in OnInit to keep inputs at top)

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
// === TRADING MODE ===
enum ENUM_TRADING_MODE { SINGLE_DIRECTION = 0, HEDGE = 1, GRID = 2 };
input ENUM_TRADING_MODE tradingMode = SINGLE_DIRECTION;  // Trading Mode
input int    MagicNumber     = 123456;          // Magic Number (unique ID)
input bool   useHistoryRecovery = true;         // Auto-recover state from trading history
input int    historyDays     = 30;              // Days of history to analyze
input bool   enableBuy       = true;            // Enable Buy
input bool   enableSell      = true;            // Enable Sell

// === INDICATOR SELECTION ===
input bool   use_RSI         = true;            // Use RSI
input bool   use_EMA         = false;           // Use EMA Crossover
input bool   use_MACD        = false;           // Use MACD
input bool   use_BB          = false;           // Use Bollinger Bands

// === MACHINE LEARNING ===
input bool   useML           = true;            // Use ML Reinforcement Learning
input double mlLearningRate  = 0.1;             // Learning Rate (0.01-0.5)
input int    mlMemorySize    = 100;             // Memory Size (trades)
input double signalThreshold = 0.60;            // Signal Threshold (50-80%) - Higher = Less trades
input int    minConfirmBars  = 2;               // Min Confirmation Bars (1-5)
input int    cooldownBars    = 3;               // Cooldown Between Trades (bars)

// === NEWS FILTER ===
enum ENUM_NEWS_FILTER { NEWS_OFF = 0, NEWS_HIGH_ONLY = 1, NEWS_ALL = 2 };
input ENUM_NEWS_FILTER newsFilter = NEWS_OFF;   // News Filter Mode
input int    newsMinutesBefore = 30;            // Minutes Before News
input int    newsMinutesAfter  = 30;            // Minutes After News
input string newsCurrency      = "USD,EUR,GBP,JPY,AUD,CAD,CHF,NZD"; // Currencies to Monitor

// === RSI Settings ===
input int    length_rsi      = 14;              // RSI Length
input int    rsi_entry       = 35;              // RSI Oversold (BUY)
input int    rsi_exit        = 75;              // RSI Overbought (SELL)
input string rsi_timeframes  = "CURRENT,H1,H4"; // RSI Timeframes (comma-separated: M1,M5,M15,M30,H1,H4,D1,W1,MN1,CURRENT)

// === EMA Settings ===
input int    ema_fast        = 12;              // EMA Fast Period
input int    ema_slow        = 26;              // EMA Slow Period
input string ema_timeframes  = "CURRENT,H1";    // EMA Timeframes

// === MACD Settings ===
input int    macd_fast       = 12;              // MACD Fast EMA
input int    macd_slow       = 26;              // MACD Slow EMA
input int    macd_signal     = 9;               // MACD Signal Period
input string macd_timeframes = "CURRENT,H4";    // MACD Timeframes

// === Bollinger Bands Settings ===
input int    bb_period       = 20;              // BB Period
input double bb_deviation    = 2.0;             // BB Deviation
input string bb_timeframes   = "CURRENT,H1";    // BB Timeframes

// === TP/SL Settings ===
input bool   useStopLoss     = true;            // Use Stop Loss
input bool   useTakeProfit   = true;            // Use Take Profit
enum ENUM_TPSL_MODE { PIPS_RR = 0, ATR_PIPS = 1, TRAILING_STOP = 2, TRAILING_ATR = 3 };
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

// === GRID Settings ===
input int    gridLevels      = 5;               // Grid Levels (GRID mode)
input int    gridSpacing     = 20;              // Grid Spacing (pips) - Base
input double gridLotMultiplier = 1.5;           // Grid Lot Multiplier - Legacy

// === ADVANCED GRID PRO ===
input bool   useSmartGrid      = true;          // Use Smart Grid System
input bool   useDynamicSpacing = true;          // Dynamic ATR Spacing
input double gridATRMultiplier = 1.5;           // ATR Multiplier for Spacing
input bool   useSmartLot       = true;          // Smart Lot Progression
input string lotProgression    = "1.0,1.2,1.5,2.0,2.5"; // Lot Multipliers (comma-separated)
input bool   useGridTP         = true;          // Grid Take Profit (close all)
input double gridTPPercent     = 3.0;           // Grid TP % (from average entry)
input bool   useGridBreakeven  = true;          // Grid Breakeven Close
input bool   useHedgeGrid      = false;         // Hedge Grid (Long + Short)
input bool   useRecoveryZone   = true;          // Recovery Zone Protection
input double maxDrawdownPercent = 10.0;         // Max Drawdown % (stop new grids)
input double recoveryTPPercent  = 2.0;          // Recovery TP % (close all when recovering)
input bool   useGridCover      = true;          // Grid Cover (close on max levels/losses)
input int    maxGridLossStreak = 3;             // Max Consecutive Grid Losses
input double gridCoverMinPL    = -5.0;          // Min P/L % to allow cover (-5% = only if loss < 5%)

// === ADVANCED HEDGE MODULE ===
input bool   useAdvancedHedge    = false;       // Use Advanced Hedge System
enum ENUM_HEDGE_STRATEGY { 
    HEDGE_FIXED = 0,           // Fixed Ratio
    HEDGE_DYNAMIC = 1,         // Dynamic Ratio (based on PL)
    HEDGE_PYRAMID = 2,         // Pyramid Hedging
    HEDGE_BALANCE = 3,         // Balance Hedge (equalize exposure)
    HEDGE_PROFIT_LOCK = 4,     // Profit Lock Hedge
    HEDGE_SL_PROTECT = 5       // Stop Loss Protection
};
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

// === HEDGE REDUCTION MECHANISM ===
input bool   useHedgeReduction   = true;        // 🎯 Use Hedge Reduction System
input bool   useSmartHedgeClose  = true;        // Smart partial hedge close
input double hedgeProfitTarget   = 2.0;         // Hedge Profit Target (%)
input bool   useBreakevenHedge   = true;        // Close hedge at breakeven
input double breakevenThreshold  = 0.5;         // Breakeven threshold (%)
input bool   useCorrelationClose = true;        // Close when main+hedge both profit
input bool   usePartialReduction = true;        // Reduce hedge gradually (not all)
input double reductionPercent    = 50.0;        // Reduce % each time (50% = half)
input int    minHedgeBars        = 5;           // Min bars before reduction
input bool   useTimeReduction    = false;       // Time-based reduction
input int    maxHedgeHours       = 24;          // Max hedge duration (hours)
// === Emergency / Backtest controls ===
input bool   enableEmergencyClose = true;      // Enable emergency close mechanism
input double emergencyDrawdownPct = 30.0;     // If equity drops this % vs balance, force close hedges
input int    emergencyMaxHoldHours = 72;      // If any hedge held longer than this (hours), force close
input bool   emergencyCloseAllPositions = false; // If true, close ALL positions for this MagicNumber, else only hedge/grid
input bool   skipHistoryRecoveryInBacktest = true; // If running in strategy tester, skip history recovery/expensive ops


// === Money Management ===
// Close positions matching criteria (magic + comment filters)
void ClosePositionsByCriteria(bool closeAllForMagic=false)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

        string comment = PositionGetString(POSITION_COMMENT);
        bool isHedge = (StringFind(comment, "HEDGE") >= 0 || StringFind(comment, "Hedge") >= 0);
        bool isGrid  = (StringFind(comment, "GRID") >= 0 || StringFind(comment, "Grid") >= 0);

        // If not closing all, only close hedge/grid positions
        if(!closeAllForMagic && !(isHedge || isGrid))
            continue;

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        MqlTradeRequest request;
        MqlTradeResult  result;
        ZeroMemory(request);
        ZeroMemory(result);

        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = _Symbol;
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        request.deviation = 10;
        request.type_filling = ORDER_FILLING_IOC;

        // Use safe send
        if(!SafeOrderSend(request, result))
        {
            PrintFormat("Emergency close failed for ticket %I64u: ret=%d", ticket, result.retcode);
        }
        else
        {
            PrintFormat("Emergency closed ticket %I64u (was %s)", ticket, (posType==POSITION_TYPE_BUY)?"BUY":"SELL");
        }
    }
}

// Wrapper to close hedge/grid or all positions depending on config
void CloseAllHedgePositions()
{
    if(emergencyCloseAllPositions)
    {
        PrintFormat("Emergency: closing ALL positions for Magic %d", MagicNumber);
        ClosePositionsByCriteria(true);
    }
    else
    {
        PrintFormat("Emergency: closing only HEDGE/GRID positions for Magic %d", MagicNumber);
        ClosePositionsByCriteria(false);
    }
}

// Safe wrapper around OrderSend that returns true on success
bool SafeOrderSend(MqlTradeRequest &request, MqlTradeResult &result)
{
    ZeroMemory(result);
    bool sent = OrderSend(request, result);
    if(!sent || result.retcode != TRADE_RETCODE_DONE)
    {
        // Log detailed error
        PrintFormat("OrderSend failed: sent=%d ret=%d comment=%s", sent ? 1 : 0, result.retcode, result.comment);
        return false;
    }
    return true;
}

// Check emergency conditions (drawdown / max hold time)
void CheckEmergencyConditions()
{
    if(!enableEmergencyClose || !useAdvancedHedge) return;

    // Drawdown check
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
    if(balance > 0)
    {
        double drawPct = (balance - equity) / balance * 100.0;
        if(drawPct >= emergencyDrawdownPct)
        {
            PrintFormat("Emergency triggered by drawdown: %.2f%% >= %.2f%%", drawPct, emergencyDrawdownPct);
            CloseAllHedgePositions();
            return;
        }
    }

    // Max hold time check for hedge/grid positions
    datetime now = TimeCurrent();
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

        string comment = PositionGetString(POSITION_COMMENT);
        bool isHedge = (StringFind(comment, "HEDGE") >= 0 || StringFind(comment, "Hedge") >= 0);
        bool isGrid  = (StringFind(comment, "GRID") >= 0 || StringFind(comment, "Grid") >= 0);

        if(!(isHedge || isGrid)) continue;

        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        int hoursHeld = (int)((now - openTime) / 3600);
        if(hoursHeld >= emergencyMaxHoldHours)
        {
            PrintFormat("Emergency triggered by max hold time: ticket=%I64u held %d hours >= %d hours", ticket, hoursHeld, emergencyMaxHoldHours);
            CloseAllHedgePositions();
            return;
        }
    }
}

//+------------------------------------------------------------------+
//| Main tick handler                                                 |
//+------------------------------------------------------------------+
input double riskPercent         = 2.0;         // Risk % of Balance (ALGORITHMIC mode)
input double martingaleMultiplier = 2.0;        // Martingale Multiplier
input double maxLotSize          = 10.0;        // Max Lot Size (safety)
input double lotSize             = 0.10;        // Base lot size
// Risk mode enum and selection
enum ENUM_RISK_MODE { RISK_FIXED = 0, RISK_MARTINGALE = 1, RISK_FIBONACCI = 2, RISK_ALGORITHMIC = 3 };
input ENUM_RISK_MODE riskMode = RISK_FIXED;          // Risk allocation mode
input int    maxOpenPositions    = 10;          // Max concurrent positions

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

//--- Grid Trading Variables
double lastGridLongPrice = 0;
double lastGridShortPrice = 0;
int currentGridLevel = 0;

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

//--- Grid Cover Variables
int gridConsecutiveLossesLong = 0;   // Consecutive grid losses (long)
int gridConsecutiveLossesShort = 0;  // Consecutive grid losses (short)
double gridLastClosePLLong = 0;       // Last grid close P/L (long)
double gridLastClosePLShort = 0;      // Last grid close P/L (short)

//--- Advanced Hedge Variables
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
//| Get dynamic grid spacing                                         |
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
        ClosePositions(POSITION_TYPE_BUY);
        ClosePositions(POSITION_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Check Grid Cover conditions                                      |
//+------------------------------------------------------------------+
bool ShouldCoverGrid(bool isLong)
{
    if(!useGridCover || !useSmartGrid) return false;
    
    int posCount = isLong ? CountPositionsByType(POSITION_TYPE_BUY) : 
                           CountPositionsByType(POSITION_TYPE_SELL);
    
    if(posCount == 0) return false;
    
    // Calculate current grid P/L
    double totalPL = 0;
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
                }
            }
        }
    }
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double plPercent = (totalPL / balance) * 100.0;
    
    // Condition 1: Grid reached max levels
    bool gridFull = (posCount >= gridLevels);
    
    // Condition 2: Consecutive losses exceeded
    int lossStreak = isLong ? gridConsecutiveLossesLong : gridConsecutiveLossesShort;
    bool tooManyLosses = (lossStreak >= maxGridLossStreak);
    
    // Condition 3: P/L is acceptable for cover (not too deep loss)
    bool plAcceptable = (plPercent >= gridCoverMinPL);
    
    // Cover if: (Grid full OR too many losses) AND P/L is acceptable
    if((gridFull || tooManyLosses) && plAcceptable)
    {
        string reason = "";
        if(gridFull && tooManyLosses)
            reason = StringFormat("Grid Full (%d levels) + Loss Streak (%d)", posCount, lossStreak);
        else if(gridFull)
            reason = StringFormat("Grid Full (%d/%d levels)", posCount, gridLevels);
        else
            reason = StringFormat("Loss Streak (%d/%d)", lossStreak, maxGridLossStreak);
        
        PrintFormat("🔒 GRID COVER TRIGGERED (%s): %s | PL=%.2f%% (Min: %.1f%%)", 
                   isLong ? "LONG" : "SHORT", reason, plPercent, gridCoverMinPL);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update grid loss streak tracking                                 |
//+------------------------------------------------------------------+
void UpdateGridLossStreak(bool isLong, double gridPL)
{
    if(!useGridCover || !useSmartGrid) return;
    
    if(isLong)
    {
        gridLastClosePLLong = gridPL;
        if(gridPL < 0)
        {
            gridConsecutiveLossesLong++;
        }
        else
        {
            gridConsecutiveLossesLong = 0;  // Reset on win
        }
    }
    else
    {
        gridLastClosePLShort = gridPL;
        if(gridPL < 0)
        {
            gridConsecutiveLossesShort++;
        }
        else
        {
            gridConsecutiveLossesShort = 0;  // Reset on win
        }
    }
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
    request.magic = MagicNumber;
    request.comment = StringFormat("HEDGE_%s_L%d", isLong ? "LONG" : "SHORT", hedgeCount + 1);
    
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
    
    if(!SafeOrderSend(request, result))
    {
        PrintFormat("Hedge open failed: ret=%d comment=%s", result.retcode, result.comment);
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
            
            // Use safe send wrapper
            if(!SafeOrderSend(request, result))
            {
                PrintFormat("Close hedge send failed: ret=%d comment=%s", result.retcode, result.comment);
            }
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
            
            if(SafeOrderSend(request, result))
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
    
    // Initialize grid variables
    lastGridLongPrice = 0;
    lastGridShortPrice = 0;
    currentGridLevel = 0;
    ArrayResize(gridPositions, 0);
    gridPositionCount = 0;
    gridRecoveryMode = false;
    
    // Initialize Grid Cover
    gridConsecutiveLossesLong = 0;
    gridConsecutiveLossesShort = 0;
    gridLastClosePLLong = 0;
    gridLastClosePLShort = 0;
    
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
    PrintFormat("=== QuantumRSI v4.0 - Multi-Timeframe Strategy ===");
    
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
    if(riskMode == RISK_MARTINGALE) riskModeStr = "MARTINGALE";
    else if(riskMode == RISK_FIBONACCI) riskModeStr = "FIBONACCI";
    else if(riskMode == RISK_ALGORITHMIC) riskModeStr = "ALGORITHMIC";
    PrintFormat("Risk Mode: %s, Base Lot: %.2f, Max Lot: %.2f", riskModeStr, lotSize, maxLotSize);
    
    string tpslModeStr = "PIPS_RR";
    if(tpSlMode == ATR_PIPS) tpslModeStr = "ATR_PIPS";
    else if(tpSlMode == TRAILING_STOP) tpslModeStr = "TRAILING_STOP";
    else if(tpSlMode == TRAILING_ATR) tpslModeStr = "TRAILING_ATR";
    PrintFormat("TP/SL Mode: %s | ATR TF: %s", tpslModeStr, TimeframeToString(atrTF));
    
    if(tradingMode == GRID)
    {
        if(useSmartGrid)
        {
            PrintFormat("SMART GRID ENABLED:");
            PrintFormat("   Dynamic Spacing: %s (ATR x %.2f)", useDynamicSpacing ? "YES" : "NO", gridATRMultiplier);
            PrintFormat("   Smart Lot: %s", useSmartLot ? "YES" : "NO");
            PrintFormat("   Grid TP: %s (%.1f%%)", useGridTP ? "YES" : "NO", gridTPPercent);
            PrintFormat("   Breakeven: %s", useGridBreakeven ? "YES" : "NO");
            PrintFormat("   Hedge Grid: %s", useHedgeGrid ? "YES" : "NO");
            PrintFormat("   Recovery Zone: %s (Max DD: %.1f%%)", useRecoveryZone ? "YES" : "NO", maxDrawdownPercent);
            PrintFormat("   Grid Cover: %s (Loss Streak: %d, Min PL: %.1f%%)", 
                       useGridCover ? "YES" : "NO", maxGridLossStreak, gridCoverMinPL);
        }
        else
        {
            PrintFormat("Grid: %d levels, %d pips spacing, %.2fx multiplier", 
                       gridLevels, gridSpacing, gridLotMultiplier);
        }
    }
    
    // Advanced Hedge Module Config
    if(useAdvancedHedge)
    {
    PrintFormat("=== ADVANCED HEDGE MODULE ===");
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
        // Optionally skip heavy history analysis during backtests
        if(skipHistoryRecoveryInBacktest)
        {
            // If configured to skip history recovery in backtests, detect testing mode
            if(IsRunningInTester())
            {
                PrintFormat("Strategy tester detected - skipping history recovery (to speed up backtest)");
            }
            else
            {
                PrintFormat("=== HISTORY-BASED STATE RECOVERY ===");
                PrintFormat("   Magic Number: %d", MagicNumber);
                PrintFormat("   Analysis Period: Last %d days", historyDays);
                
                RecoverStateFromHistory();
                RecoverOpenPositionsState();
            }
        }
        else
        {
            PrintFormat("=== HISTORY-BASED STATE RECOVERY ===");
            PrintFormat("   Magic Number: %d", MagicNumber);
            PrintFormat("   Analysis Period: Last %d days", historyDays);
            
            RecoverStateFromHistory();
            RecoverOpenPositionsState();
        }
    }
    else
    {
        PrintFormat("State Persistence: DISABLED");
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
double CalculateLotSize(int gridLevel = 0)
{
    double calculatedLot = lotSize;
    
    if(tradingMode == GRID && gridLevel > 0)
    {
        // Use Smart Lot progression if enabled
        if(useSmartGrid && useSmartLot && smartLotCount > 0)
        {
            double multiplier = 1.0;
            if(gridLevel < smartLotCount)
            {
                multiplier = smartLotMultipliers[gridLevel];
            }
            else
            {
                // Use last multiplier for levels beyond array
                multiplier = smartLotMultipliers[smartLotCount - 1];
            }
            calculatedLot = lotSize * multiplier;
        }
        else
        {
            // Legacy exponential
            calculatedLot = lotSize * MathPow(gridLotMultiplier, gridLevel);
        }
    }
    else
    {
        switch(riskMode)
        {
            case RISK_FIXED:
                calculatedLot = lotSize;
                break;
                
            case RISK_MARTINGALE:
                if(consecutiveLosses > 0)
                    calculatedLot = lastLotSize * martingaleMultiplier;
                else
                    calculatedLot = lotSize;
                break;
                
            case RISK_FIBONACCI:
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
                
            case RISK_ALGORITHMIC:
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
    }
    else
    {
        consecutiveLosses++;
        fibIndex++;
        if(fibIndex > 9) fibIndex = 9;
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
    
    // Update global counters based on history
    if(recoveredTrades > 0)
    {
        // Update grid consecutive losses
        gridConsecutiveLossesLong = consecutiveLossCount / 2;
        gridConsecutiveLossesShort = consecutiveLossCount - gridConsecutiveLossesLong;
        
        // Calculate metrics
        double winRate = (double)winCount / recoveredTrades;
        double avgProfit = totalProfit / recoveredTrades;
        
        // Adjust ML weights based on performance
        for(int i = 0; i < signalWeightCount; i++)
        {
            signalWeights[i].trade_count = recoveredTrades / MathMax(1, signalWeightCount);
            signalWeights[i].total_profit = avgProfit;
            
            // Dynamic weight adjustment
            if(winRate > 0.65)
                signalWeights[i].weight = MathMin(1.5, 1.15);
            else if(winRate > 0.55)
                signalWeights[i].weight = MathMin(1.3, 1.08);
            else if(winRate < 0.35)
                signalWeights[i].weight = MathMax(0.5, 0.85);
            else if(winRate < 0.45)
                signalWeights[i].weight = MathMax(0.7, 0.92);
        }
        
        // Update last P/L
        if(recentCount > 0)
        {
            gridLastClosePLLong = recentProfits[0];
            gridLastClosePLShort = recentProfits[0];
        }
        
        PrintFormat("✅ Recovery Complete: %d trades analyzed", recoveredTrades);
        PrintFormat("   💰 Total P/L: %.2f | Win Rate: %.1f%%", totalProfit, winRate * 100);
        PrintFormat("   📉 Consecutive Losses: %d (L:%d S:%d)", 
                    consecutiveLossCount, gridConsecutiveLossesLong, gridConsecutiveLossesShort);
        PrintFormat("   ⏰ Last Trade: %s", TimeToString(lastTradeTime));
    }
    else
    {
        PrintFormat("ℹ️ No previous trades found, starting fresh");
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
                request.type_filling = ORDER_FILLING_IOC;
                
                SafeOrderSend(request, result);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open position                                                     |
//+------------------------------------------------------------------+
void OpenPosition(bool isLong, int gridLevel, string signals)
{
    double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double atrAtEntry = GetATR(0);
    double sl, tp;
    CalcSLTP_fromEntry(price, isLong, atrAtEntry, sl, tp);
    
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
    
    string comment = "";
    if(tradingMode == GRID)
        comment = StringFormat("Grid L%d", gridLevel);
    else if(tradingMode == HEDGE)
        comment = isLong ? "Hedge Long" : "Hedge Short";
    else
        comment = isLong ? "Single Long" : "Single Short";
        
    request.comment = comment;
    request.type_filling = ORDER_FILLING_IOC;
    
    if(SafeOrderSend(request, result))
    {
        string slStr = useStopLoss ? StringFormat("%.5f", sl) : "None";
        string tpStr = useTakeProfit ? StringFormat("%.5f", tp) : "None";
        PrintFormat("%s ENTRY: Lot=%.2f, Price=%.5f, SL=%s, TP=%s | Signals: %s", 
                   comment, currentLotSize, price, slStr, tpStr, signals);
        
        if(tradingMode == GRID)
        {
            if(isLong)
                lastGridLongPrice = price;
            else
                lastGridShortPrice = price;
            
            // Track grid position for Smart Grid
            if(useSmartGrid)
            {
                AddGridPosition(result.order, price, currentLotSize, gridLevel, isLong);
            }
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
    
    // Stop opening new grids in recovery mode
    if(useSmartGrid && gridRecoveryMode) return false;
    
    double gridDistance;
    if(useSmartGrid && useDynamicSpacing)
    {
        gridDistance = GetDynamicGridSpacing();
    }
    else
    {
        double pip = GetPip();
        gridDistance = gridSpacing * pip;
    }
    
    if(isLong)
    {
        if(lastGridLongPrice == 0) return true;
        if(currentPrice <= lastGridLongPrice - gridDistance)
            return true;
    }
    else
    {
        if(lastGridShortPrice == 0) return true;
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
    
    if(currentBar == lastBar) return;
    lastBar = currentBar;
    
    if(IsNewsTime()) return;
    
    // Check recovery zone for Smart Grid
    if(tradingMode == GRID && useSmartGrid)
    {
        CheckRecoveryZone();
        CalculateGridAverages();
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
    
    if(tradingMode == SINGLE_DIRECTION)
    {
        if(buy_signal && shortPositions > 0)
        {
            ClosePositions(POSITION_TYPE_SELL);
        }
        else if(sell_signal && longPositions > 0)
        {
            ClosePositions(POSITION_TYPE_BUY);
        }
        
        if(enableBuy && buy_signal && longPositions == 0 && !MaxPositionsReached())
        {
            PrintFormat("📈 BUY CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastBuyScore * 100, consecutiveBuyBars, buySignals);
            lastActiveSignals = buySignals;  // Store for ML update
            OpenPosition(true, 0, buySignals);
            lastTradeTime = currentBar;
            consecutiveBuyBars = 0;  // Reset after trade
        }
        else if(enableSell && sell_signal && shortPositions == 0 && !MaxPositionsReached())
        {
            PrintFormat("📉 SELL CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastSellScore * 100, consecutiveSellBars, sellSignals);
            lastActiveSignals = sellSignals;  // Store for ML update
            OpenPosition(false, 0, sellSignals);
            lastTradeTime = currentBar;
            consecutiveSellBars = 0;  // Reset after trade
        }
        
        // Advanced Hedge Module for SINGLE_DIRECTION mode
        if(useAdvancedHedge)
        {
            UpdateHedgePositions();
            // Emergency checks (drawdown / long-held hedges)
            CheckEmergencyConditions();
            
            // Check hedge for existing positions
            if(longPositions > 0 && !hedgeActiveLong && ShouldOpenHedge(POSITION_TYPE_BUY))
                OpenHedgePosition(POSITION_TYPE_BUY);
                
            if(shortPositions > 0 && !hedgeActiveShort && ShouldOpenHedge(POSITION_TYPE_SELL))
                OpenHedgePosition(POSITION_TYPE_SELL);
            
            // Hedge Reduction
            CheckHedgeReduction();
        }
    }
    else if(tradingMode == HEDGE)
    {
        if(enableBuy && buy_signal && !MaxPositionsReached())
        {
            PrintFormat("📈 BUY CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastBuyScore * 100, consecutiveBuyBars, buySignals);
            lastActiveSignals = buySignals;  // Store for ML update
            OpenPosition(true, 0, buySignals);
            lastTradeTime = currentBar;
            consecutiveBuyBars = 0;  // Reset after trade
        }
        
        if(enableSell && sell_signal && !MaxPositionsReached())
        {
            PrintFormat("📉 SELL CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastSellScore * 100, consecutiveSellBars, sellSignals);
            lastActiveSignals = sellSignals;  // Store for ML update
            OpenPosition(false, 0, sellSignals);
            lastTradeTime = currentBar;
            consecutiveSellBars = 0;  // Reset after trade
        }
        
        // Advanced Hedge Module for HEDGE mode
        if(useAdvancedHedge)
        {
            UpdateHedgePositions();
            // Emergency checks (drawdown / long-held hedges)
            CheckEmergencyConditions();
            
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
    else if(tradingMode == GRID)
    {
        // Check Grid TP (Smart Grid)
        if(useSmartGrid && useGridTP)
        {
            if(longPositions > 0 && ShouldCloseGridTP(true))
            {
                ClosePositions(POSITION_TYPE_BUY);
                PrintFormat("✅ Grid LONG closed with TP");
            }
            
            if(shortPositions > 0 && ShouldCloseGridTP(false))
            {
                ClosePositions(POSITION_TYPE_SELL);
                PrintFormat("✅ Grid SHORT closed with TP");
            }
        }
        
        // Check Grid Breakeven (Smart Grid)
        if(useSmartGrid && useGridBreakeven)
        {
            if(longPositions > 0 && ShouldCloseGridBreakeven(true))
            {
                ClosePositions(POSITION_TYPE_BUY);
                PrintFormat("✅ Grid LONG closed at breakeven");
            }
            
            if(shortPositions > 0 && ShouldCloseGridBreakeven(false))
            {
                ClosePositions(POSITION_TYPE_SELL);
                PrintFormat("✅ Grid SHORT closed at breakeven");
            }
        }
        
        // Check Grid Cover (Smart Grid) - Close on max levels or loss streak
        if(useSmartGrid && useGridCover)
        {
            if(longPositions > 0 && ShouldCoverGrid(true))
            {
                // Calculate total P/L before close
                double totalPL = 0;
                for(int i = PositionsTotal() - 1; i >= 0; i--)
                {
                    if(PositionGetSymbol(i) == _Symbol)
                    {
                        ulong ticket = PositionGetTicket(i);
                        if(PositionSelectByTicket(ticket))
                        {
                            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                            if(posType == POSITION_TYPE_BUY)
                                totalPL += PositionGetDouble(POSITION_PROFIT);
                        }
                    }
                }
                
                ClosePositions(POSITION_TYPE_BUY);
                UpdateGridLossStreak(true, totalPL);
                PrintFormat("🔒 Grid LONG covered | P/L: $%.2f | Loss Streak: %d", 
                           totalPL, gridConsecutiveLossesLong);
            }
            
            if(shortPositions > 0 && ShouldCoverGrid(false))
            {
                // Calculate total P/L before close
                double totalPL = 0;
                for(int i = PositionsTotal() - 1; i >= 0; i--)
                {
                    if(PositionGetSymbol(i) == _Symbol)
                    {
                        ulong ticket = PositionGetTicket(i);
                        if(PositionSelectByTicket(ticket))
                        {
                            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                            if(posType == POSITION_TYPE_SELL)
                                totalPL += PositionGetDouble(POSITION_PROFIT);
                        }
                    }
                }
                
                ClosePositions(POSITION_TYPE_SELL);
                UpdateGridLossStreak(false, totalPL);
                PrintFormat("🔒 Grid SHORT covered | P/L: $%.2f | Loss Streak: %d", 
                           totalPL, gridConsecutiveLossesShort);
            }
        }
        
        // Advanced Hedge Module - Check and manage hedges
        if(useAdvancedHedge)
        {
            // Update hedge positions status
            UpdateHedgePositions();
            // Emergency checks (drawdown / long-held hedges)
            CheckEmergencyConditions();
            
            // Check if should open hedge for LONG positions
            if(longPositions > 0 && !hedgeActiveLong)
            {
                if(ShouldOpenHedge(POSITION_TYPE_BUY))
                {
                    OpenHedgePosition(POSITION_TYPE_BUY);
                }
            }
            
            // Check if should open hedge for SHORT positions
            if(shortPositions > 0 && !hedgeActiveShort)
            {
                if(ShouldOpenHedge(POSITION_TYPE_SELL))
                {
                    OpenHedgePosition(POSITION_TYPE_SELL);
                }
            }
            
            // Pyramid hedge - open additional levels
            if(usePyramidHedge)
            {
                // Check if should add pyramid level for LONG hedge
                if(hedgeActiveLong && hedgeCountLong < pyramidLevels)
                {
                    if(ShouldOpenHedge(POSITION_TYPE_BUY))
                    {
                        OpenHedgePosition(POSITION_TYPE_BUY);
                    }
                }
                
                // Check if should add pyramid level for SHORT hedge
                if(hedgeActiveShort && hedgeCountShort < pyramidLevels)
                {
                    if(ShouldOpenHedge(POSITION_TYPE_SELL))
                    {
                        OpenHedgePosition(POSITION_TYPE_SELL);
                    }
                }
            }
            
            // Hedge Reduction - Check if should reduce/close hedge
            CheckHedgeReduction();
        }
        
        // Open first grid level on signal
        if(enableBuy && buy_signal && longPositions == 0)
        {
            PrintFormat("📈 BUY CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastBuyScore * 100, consecutiveBuyBars, buySignals);
            lastActiveSignals = buySignals;  // Store for ML update
            OpenPosition(true, 0, buySignals);
            lastTradeTime = currentBar;
            consecutiveBuyBars = 0;  // Reset after trade
        }
        
        if(enableSell && sell_signal && shortPositions == 0)
        {
            PrintFormat("📉 SELL CONFIRMED | Score: %.1f%% | Bars: %d | Signals: %s", 
                       lastSellScore * 100, consecutiveSellBars, sellSignals);
            lastActiveSignals = sellSignals;  // Store for ML update
            OpenPosition(false, 0, sellSignals);
            lastTradeTime = currentBar;
            consecutiveSellBars = 0;  // Reset after trade
        }
        
        // Add grid levels
        if(enableBuy && longPositions > 0 && longPositions < gridLevels && !MaxPositionsReached())
        {
            if(ShouldOpenGridOrder(true, bid))
            {
                OpenPosition(true, longPositions, "Grid expansion");
            }
        }
        
        if(enableSell && shortPositions > 0 && shortPositions < gridLevels && !MaxPositionsReached())
        {
            if(ShouldOpenGridOrder(false, ask))
            {
                OpenPosition(false, shortPositions, "Grid expansion");
            }
        }
        
        // Hedge Grid (Smart Grid feature)
        if(useSmartGrid && useHedgeGrid)
        {
            // Open opposite direction grid
            if(enableBuy && buy_signal && shortPositions > 0 && longPositions == 0 && !MaxPositionsReached())
            {
                OpenPosition(true, 0, "Hedge Long");
            }
            
            if(enableSell && sell_signal && longPositions > 0 && shortPositions == 0 && !MaxPositionsReached())
            {
                OpenPosition(false, 0, "Hedge Short");
            }
        }
    }
    
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
        
        if(SafeOrderSend(request, result))
        {
            PrintFormat("Trailing SL updated | Ticket: %d | New SL: %.5f | Profit: %.1f pips", 
                       ticket, newSL, profitPips);
        }
        else
        {
            PrintFormat("Trailing SL update failed | Ticket: %d | ret=%d comment=%s", ticket, result.retcode, result.comment);
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
                    bool wasWin = (dealProfit > 0);
                    
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
                    
                    // Remove from grid tracking (Smart Grid)
                    if(tradingMode == GRID && useSmartGrid)
                    {
                        RemoveGridPosition(trans.position);
                    }
                    
                    if(tradingMode == GRID)
                    {
                        int longPos = CountPositionsByType(POSITION_TYPE_BUY);
                        int shortPos = CountPositionsByType(POSITION_TYPE_SELL);
                        
                        // Reset loss streak on win (for last grid close of this direction)
                        if(useSmartGrid && useGridCover)
                        {
                            if(longPos == 0 && wasWin)
                            {
                                gridConsecutiveLossesLong = 0;
                                PrintFormat("✅ Grid LONG loss streak RESET (profitable close)");
                            }
                            if(shortPos == 0 && wasWin)
                            {
                                gridConsecutiveLossesShort = 0;
                                PrintFormat("✅ Grid SHORT loss streak RESET (profitable close)");
                            }
                        }
                        
                        if(longPos == 0) lastGridLongPrice = 0;
                        if(shortPos == 0) lastGridShortPrice = 0;
                    }
                    
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

