//+------------------------------------------------------------------+
//|                                             Reinforced RSI + SR  |
//|                        Copyright 2024, Reinforced RSI Strategy    |
//|                                      https://www.mql5.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Reinforced RSI + SR Filter"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
sinput group "=== RSI Settings ==="
input int    length_rsi      = 14;              // RSI Length
input int    rsi_entry       = 35;              // RSI BUY Oversold Level
input int    rsi_exit        = 75;              // RSI SELL Overbought Level
input bool   enableBuy       = true;            // Enable Buy
input bool   enableSell      = true;            // Enable Sell

sinput group "=== TP/SL Settings ==="
enum ENUM_TPSL_MODE { PIPS_RR = 0, ATR_PIPS = 1 };
input ENUM_TPSL_MODE tpSlMode = PIPS_RR;        // TP/SL Mode
input int    slPips          = 30;              // SL pips
input double rr              = 3.0;             // RR (PIPS_RR mode)
input int    atr_len         = 14;              // ATR Length
input double atr_mult_tp     = 1.5;             // ATR Multiplier for TP

sinput group "=== RSI Winrate Filter (SIMPLIFIED) ==="
input bool   require_prob_filter  = false;      // Require probability filter? (OFF for max trades)
input int    prob_look_back       = 100;        // Bars to look back for winrate calc
input double prob_threshold       = 40.0;       // Min RSI Winrate (%)

sinput group "=== Money Management ==="
enum ENUM_RISK_MODE { FIXED = 0, MARTINGALE = 1, FIBONACCI = 2, ALGORITHMIC = 3 };
input ENUM_RISK_MODE riskMode    = FIXED;       // Risk Management Mode
input double lotSize             = 0.1;         // Lot Size (FIXED mode)
input double riskPercent         = 2.0;         // Risk % of Balance (ALGORITHMIC mode)
input double martingaleMultiplier = 2.0;        // Martingale Multiplier (MARTINGALE mode)
input double maxLotSize          = 10.0;        // Max Lot Size (safety limit)
input int    maxOpenPositions    = 5;           // Max concurrent positions (pyramiding)

//--- Indicator handles
int rsiHandle   = INVALID_HANDLE;
int atrHandle   = INVALID_HANDLE;

//--- Global variables for SR zones
double res_high = 0, res_low = 0;
double sup_high = 0, sup_low = 0;

//--- Risk Management Variables
double currentLotSize = 0.1;        // Current lot size (dynamic)
int consecutiveLosses = 0;          // Count consecutive losses
double lastLotSize = 0.1;           // Last lot size used
int fibIndex = 0;                   // Fibonacci sequence index

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize RSI on current timeframe
    rsiHandle = iRSI(_Symbol, _Period, length_rsi, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        PrintFormat("Failed to create RSI handle. Error=%d", GetLastError());
        return(INIT_FAILED);
    }

    // Initialize ATR
    atrHandle = iATR(_Symbol, _Period, atr_len);
    if(atrHandle == INVALID_HANDLE)
    {
        PrintFormat("Failed to create ATR handle. Error=%d", GetLastError());
        IndicatorRelease(rsiHandle);
        return(INIT_FAILED);
    }
    
    // Initialize risk management
    currentLotSize = lotSize;
    lastLotSize = lotSize;
    consecutiveLosses = 0;
    fibIndex = 0;
    
    PrintFormat("=== Simple RSI Strategy (High Frequency Mode) ===");
    PrintFormat("RSI Length: %d, Entry: %d, Exit: %d", length_rsi, rsi_entry, rsi_exit);
    PrintFormat("SL/TP Mode: %s, SL Pips: %d, RR: %.2f", 
                tpSlMode == PIPS_RR ? "PIPS_RR" : "ATR_PIPS", slPips, rr);
    
    string riskModeStr = "FIXED";
    if(riskMode == MARTINGALE) riskModeStr = "MARTINGALE";
    else if(riskMode == FIBONACCI) riskModeStr = "FIBONACCI";
    else if(riskMode == ALGORITHMIC) riskModeStr = "ALGORITHMIC";
    
    PrintFormat("Risk Mode: %s, Base Lot: %.2f, Max Lot: %.2f", riskModeStr, lotSize, maxLotSize);
    PrintFormat("Probability Filter: %s, Threshold: %.1f%%, Lookback: %d bars", 
                require_prob_filter ? "ON" : "OFF (MORE TRADES)", prob_threshold, prob_look_back);
    PrintFormat("Max Open Positions: %d (Pyramiding enabled)", maxOpenPositions);
    PrintFormat("=== OPTIMIZED FOR MAXIMUM TRADE COUNT - NO SR ZONES ===");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(rsiHandle != INVALID_HANDLE)
        IndicatorRelease(rsiHandle);
    if(atrHandle != INVALID_HANDLE)
        IndicatorRelease(atrHandle);
        
    PrintFormat("EA stopped. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Get RSI value at bar 'shift'                                     |
//+------------------------------------------------------------------+
double GetRSI(int shift)
{
    if(rsiHandle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(rsiHandle, 0, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

//+------------------------------------------------------------------+
//| Get ATR value at bar 'shift'                                     |
//+------------------------------------------------------------------+
double GetATR(int shift)
{
    if(atrHandle == INVALID_HANDLE) return(EMPTY_VALUE);
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(atrHandle, 0, shift, 1, buf) != 1) return(EMPTY_VALUE);
    return(buf[0]);
}

//+------------------------------------------------------------------+
//| Universal pip size (robust calculation)                          |
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
//| Check for RSI crossunder (buy trigger)                           |
//+------------------------------------------------------------------+
bool IsBuyTrigger()
{
    double rsi_prev = GetRSI(1);
    double rsi_now  = GetRSI(0);
    if(rsi_prev == EMPTY_VALUE || rsi_now == EMPTY_VALUE) return false;
    
    // Crossunder: previous > level AND current <= level
    return (rsi_prev > rsi_entry && rsi_now <= rsi_entry);
}

//+------------------------------------------------------------------+
//| Check for RSI crossover (sell trigger)                           |
//+------------------------------------------------------------------+
bool IsSellTrigger()
{
    double rsi_prev = GetRSI(1);
    double rsi_now  = GetRSI(0);
    if(rsi_prev == EMPTY_VALUE || rsi_now == EMPTY_VALUE) return false;
    
    // Crossover: previous < level AND current >= level
    return (rsi_prev < rsi_exit && rsi_now >= rsi_exit);
}

//+------------------------------------------------------------------+
//| Check for BUY exit (RSI crosses over exit level)                 |
//+------------------------------------------------------------------+
bool IsBuyExit()
{
    double rsi_prev = GetRSI(1);
    double rsi_now  = GetRSI(0);
    if(rsi_prev == EMPTY_VALUE || rsi_now == EMPTY_VALUE) return false;
    
    return (rsi_prev < rsi_exit && rsi_now >= rsi_exit);
}

//+------------------------------------------------------------------+
//| Check for SELL exit (RSI crosses under entry level)              |
//+------------------------------------------------------------------+
bool IsSellExit()
{
    double rsi_prev = GetRSI(1);
    double rsi_now  = GetRSI(0);
    if(rsi_prev == EMPTY_VALUE || rsi_now == EMPTY_VALUE) return false;
    
    return (rsi_prev > rsi_entry && rsi_now <= rsi_entry);
}

//+------------------------------------------------------------------+
//| Calc SL & TP given entry price and mode                          |
//+------------------------------------------------------------------+
void CalcSLTP_fromEntry(double entryPrice, bool isLong, double atrAtEntry, double &outSL, double &outTP)
{
    outSL = 0;
    outTP = 0;
    double pip = GetPip();

    if(tpSlMode == PIPS_RR)
    {
        if(isLong)
        {
            outSL = entryPrice - slPips * pip;
            outTP = entryPrice + slPips * pip * rr;
        }
        else
        {
            outSL = entryPrice + slPips * pip;
            outTP = entryPrice - slPips * pip * rr;
        }
    }
    else // ATR_PIPS
    {
        if(atrAtEntry <= 0 || atrAtEntry == EMPTY_VALUE) 
            atrAtEntry = GetATR(0);
        
        if(isLong)
        {
            outSL = entryPrice - slPips * pip;
            outTP = entryPrice + atrAtEntry * atr_mult_tp;
        }
        else
        {
            outSL = entryPrice + slPips * pip;
            outTP = entryPrice - atrAtEntry * atr_mult_tp;
        }
    }
    
    // Normalize prices
    outSL = NormalizeDouble(outSL, _Digits);
    outTP = NormalizeDouble(outTP, _Digits);
}

//+------------------------------------------------------------------+
//| Get Fibonacci number at index                                     |
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
    return 89; // Max
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
            // Simple fixed lot size
            calculatedLot = lotSize;
            break;
            
        case MARTINGALE:
            // Double lot after each loss
            if(consecutiveLosses > 0)
                calculatedLot = lastLotSize * martingaleMultiplier;
            else
                calculatedLot = lotSize; // Reset to base
            break;
            
        case FIBONACCI:
            // Increase lot by Fibonacci sequence
            if(consecutiveLosses > 0)
            {
                int fibMultiplier = GetFibonacci(fibIndex);
                calculatedLot = lotSize * fibMultiplier;
            }
            else
            {
                calculatedLot = lotSize;
                fibIndex = 0; // Reset
            }
            break;
            
        case ALGORITHMIC:
        {
            // Calculate lot based on % risk of balance
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            double riskAmount = balance * (riskPercent / 100.0);
            
            // Calculate lot size based on SL distance
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
//| Update risk management after trade closed                        |
//+------------------------------------------------------------------+
void UpdateRiskManagement(bool wasWin)
{
    if(wasWin)
    {
        // Reset on win
        consecutiveLosses = 0;
        fibIndex = 0;
        lastLotSize = lotSize;
    }
    else
    {
        // Increment on loss
        consecutiveLosses++;
        fibIndex++;
        if(fibIndex > 9) fibIndex = 9; // Cap at Fib(9)=55
    }
}

// === SR ZONE FUNCTIONS REMOVED FOR SIMPLIFICATION ===

//+------------------------------------------------------------------+
//| Simple RSI Winrate Calculation (Simplified Version)              |
//+------------------------------------------------------------------+
void CalculateRSIWinrates(double &longProb, double &shortProb)
{
    longProb = 50.0;  // Default 50%
    shortProb = 50.0;
    
    int bars_available = Bars(_Symbol, _Period);
    if(bars_available < 50) return;
    
    int lookback = MathMin(bars_available - 5, prob_look_back);
    
    double rsi_arr[];
    ArraySetAsSeries(rsi_arr, true);
    
    // Copy RSI data only
    if(CopyBuffer(rsiHandle, 0, 0, lookback, rsi_arr) < lookback) return;
    
    // Simple winrate calculation: count recent RSI signals and their outcomes
    int longWins = 0, longTotal = 0;
    int shortWins = 0, shortTotal = 0;
    
    // Scan recent bars for RSI signals
    for(int i = 1; i < lookback - 1; i++)
    {
        // Check for buy signal (crossunder: RSI crosses below entry level)
        if(rsi_arr[i+1] > rsi_entry && rsi_arr[i] <= rsi_entry)
        {
            longTotal++;
            // Simple win condition: check if RSI reaches exit level within next 50 bars
            bool won = false;
            for(int j = i - 1; j >= MathMax(0, i - 50); j--)
            {
                if(rsi_arr[j] >= rsi_exit)
                {
                    won = true;
                    break;
                }
            }
            if(won) longWins++;
        }
        
        // Check for sell signal (crossover: RSI crosses above exit level)
        if(rsi_arr[i+1] < rsi_exit && rsi_arr[i] >= rsi_exit)
        {
            shortTotal++;
            // Simple win condition: check if RSI reaches entry level within next 50 bars
            bool won = false;
            for(int j = i - 1; j >= MathMax(0, i - 50); j--)
            {
                if(rsi_arr[j] <= rsi_entry)
                {
                    won = true;
                    break;
                }
            }
            if(won) shortWins++;
        }
    }
    
    // Calculate probabilities
    if(longTotal > 0)
        longProb = ((double)longWins / longTotal) * 100.0;
    if(shortTotal > 0)
        shortProb = ((double)shortWins / shortTotal) * 100.0;
    
    // Logging (every hour)
    static datetime lastLog = 0;
    if(TimeCurrent() - lastLog > 3600)
    {
        PrintFormat("RSI Simple Winrate - Long: %.1f%% (%d/%d), Short: %.1f%% (%d/%d)", 
                   longProb, longWins, longTotal, shortProb, shortWins, shortTotal);
        lastLog = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Count open positions for this symbol                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check if max positions reached                                   |
//+------------------------------------------------------------------+
bool MaxPositionsReached()
{
    return (CountOpenPositions() >= maxOpenPositions);
}

//+------------------------------------------------------------------+
//| Check if we have an open position (for backward compatibility)   |
//+------------------------------------------------------------------+
bool HasPosition()
{
    return (CountOpenPositions() > 0);
}

//+------------------------------------------------------------------+
//| Get current position type                                         |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetPositionType()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        }
    }
    return (ENUM_POSITION_TYPE)-1;
}

//+------------------------------------------------------------------+
//| Close all positions for this symbol                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = _Symbol;
                request.volume = PositionGetDouble(POSITION_VOLUME);
                request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                request.deviation = 10;
                request.type_filling = ORDER_FILLING_IOC;
                
                OrderSend(request, result);
            }
        }
    }
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
    
    // Calculate RSI winrates (simple probability)
    double longProb = 0, shortProb = 0;
    if(require_prob_filter)
    {
        CalculateRSIWinrates(longProb, shortProb);
    }
    
    // Check probability filter
    bool prob_pass_long = true;
    bool prob_pass_short = true;
    
    if(require_prob_filter)
    {
        prob_pass_long = (longProb >= prob_threshold);
        prob_pass_short = (shortProb >= prob_threshold);
    }
    
    // Get current position state
    bool hasPos = HasPosition();
    ENUM_POSITION_TYPE posType = GetPositionType();
    
    // Check for exit signals first
    if(hasPos)
    {
        if(posType == POSITION_TYPE_BUY && IsBuyExit())
        {
            PrintFormat("BUY EXIT: RSI crossed over %d", rsi_exit);
            CloseAllPositions();
            return;
        }
        else if(posType == POSITION_TYPE_SELL && IsSellExit())
        {
            PrintFormat("SELL EXIT: RSI crossed under %d", rsi_entry);
            CloseAllPositions();
            return;
        }
    }
    
    // Entry logic
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    bool buy_trigger = IsBuyTrigger();
    bool sell_trigger = IsSellTrigger();
    
    int openPositions = CountOpenPositions();
    bool canOpenMore = !MaxPositionsReached();
    
    // BUY Entry: SIMPLIFIED - Only RSI trigger + probability (NO SR filter)
    bool entry_condition_long = buy_trigger && prob_pass_long;
    
    if(enableBuy && entry_condition_long && canOpenMore)
    {
        // Check if we have opposite positions (close them first)
        if(posType == POSITION_TYPE_SELL)
        {
            PrintFormat("Closing SHORT positions before opening LONG");
            CloseAllPositions();
        }
        
        double atrAtEntry = GetATR(0);
        double sl, tp;
        CalcSLTP_fromEntry(price, true, atrAtEntry, sl, tp);
        
        if(sl > 0 && tp > 0)
        {
            // Calculate lot size based on risk mode
            currentLotSize = CalculateLotSize();
            lastLotSize = currentLotSize;
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = currentLotSize;
            request.type = ORDER_TYPE_BUY;
            request.price = price;
            request.sl = sl;
            request.tp = tp;
            request.deviation = 10;
            request.comment = "RSI Long";
            request.type_filling = ORDER_FILLING_IOC;
            
            if(OrderSend(request, result))
            {
                PrintFormat("LONG ENTRY #%d: Lot=%.2f, Price=%.5f, SL=%.5f, TP=%.5f, RSI Winrate=%.1f%%, Losses=%d", 
                           openPositions + 1, currentLotSize, price, sl, tp, longProb, consecutiveLosses);
            }
            else
            {
                PrintFormat("BUY order failed: %d - %s", result.retcode, result.comment);
            }
        }
    }
    
    // SELL Entry: SIMPLIFIED - Only RSI trigger + probability (NO SR filter)
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool entry_condition_short = sell_trigger && prob_pass_short;
    
    if(enableSell && entry_condition_short && canOpenMore)
    {
        // Check if we have opposite positions (close them first)
        if(posType == POSITION_TYPE_BUY)
        {
            PrintFormat("Closing LONG positions before opening SHORT");
            CloseAllPositions();
        }
        
        double atrAtEntry = GetATR(0);
        double sl, tp;
        CalcSLTP_fromEntry(bid, false, atrAtEntry, sl, tp);
        
        if(sl > 0 && tp > 0)
        {
            // Calculate lot size based on risk mode
            currentLotSize = CalculateLotSize();
            lastLotSize = currentLotSize;
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = currentLotSize;
            request.type = ORDER_TYPE_SELL;
            request.price = bid;
            request.sl = sl;
            request.tp = tp;
            request.deviation = 10;
            request.comment = "RSI Short";
            request.type_filling = ORDER_FILLING_IOC;
            
            if(OrderSend(request, result))
            {
                PrintFormat("SHORT ENTRY #%d: Lot=%.2f, Price=%.5f, SL=%.5f, TP=%.5f, RSI Winrate=%.1f%%, Losses=%d", 
                           openPositions + 1, currentLotSize, bid, sl, tp, shortProb, consecutiveLosses);
            }
            else
            {
                PrintFormat("SELL order failed: %d - %s", result.retcode, result.comment);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trade transaction event handler (for risk management updates)    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // Only process deal transactions
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        // Check if this is our symbol
        if(trans.symbol == _Symbol)
        {
            // Get deal info
            ulong dealTicket = trans.deal;
            if(HistoryDealSelect(dealTicket))
            {
                long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
                double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                
                // Check if it's a close deal (not entry)
                if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
                {
                    // Only update on position close (has profit/loss)
                    if(dealProfit != 0)
                    {
                        bool wasWin = (dealProfit > 0);
                        UpdateRiskManagement(wasWin);
                        
                        if(wasWin)
                        {
                            PrintFormat("✅ Trade CLOSED with PROFIT: %.2f | Resetting risk management", dealProfit);
                        }
                        else
                        {
                            PrintFormat("❌ Trade CLOSED with LOSS: %.2f | Consecutive losses: %d, Next lot: %.2f", 
                                       dealProfit, consecutiveLosses, CalculateLotSize());
                        }
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
