#property copyright "Copyright 2024, Reinforced RSI + SR Filter"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

//--- Input parameters
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

sinput group "=== Support/Resistance Settings ==="
input ENUM_TIMEFRAMES sr_tf  = PERIOD_H4;       // SR Timeframe
input int    leftBars        = 15;              // SR Left Bars
input int    rightBars       = 15;              // SR Right Bars

sinput group "=== RSI Winrate Filter ==="
input int    prob_look_signals    = 50;         // Max signals to learn from
input int    prob_max_future_bars = 50;         // Max bars to wait for outcome
input double prob_threshold       = 55.0;       // Min RSI Winrate (%)
input bool   require_prob_filter  = true;       // Require probability filter?
input bool   ignore_if_prob_zero  = true;       // Allow entry if prob==0 (no data)?

sinput group "=== Money Management ==="
input double lotSize         = 0.1;             // Lot Size

//--- Indicator handles
int rsiHandle   = INVALID_HANDLE;
int atrHandle   = INVALID_HANDLE;
int rsiHandle_TF = INVALID_HANDLE;  // for SR timeframe
int highHandle_TF = INVALID_HANDLE;
int lowHandle_TF = INVALID_HANDLE;

//--- Global variables for SR zones
double res_high = 0, res_low = 0;
double sup_high = 0, sup_low = 0;

//--- Position tracking
double entry_price = 0;
bool is_long_position = false;

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
    
    // Initialize indicators for SR timeframe
    rsiHandle_TF = iRSI(_Symbol, sr_tf, length_rsi, PRICE_CLOSE);
    if(rsiHandle_TF == INVALID_HANDLE)
    {
        PrintFormat("Failed to create RSI TF handle. Error=%d", GetLastError());
        return(INIT_FAILED);
    }
    
    // We don't have direct High/Low indicators, will use CopyHigh/CopyLow instead
    
    PrintFormat("=== Reinforced RSI + SR Filter Initialized ===");
    PrintFormat("RSI Length: %d, Entry: %d, Exit: %d", length_rsi, rsi_entry, rsi_exit);
    PrintFormat("SL/TP Mode: %s, SL Pips: %d, RR: %.2f", 
                tpSlMode == PIPS_RR ? "PIPS_RR" : "ATR_PIPS", slPips, rr);
    PrintFormat("SR Timeframe: %s, Pivot Bars: %d/%d", 
                EnumToString(sr_tf), leftBars, rightBars);
    PrintFormat("Probability Filter: %s, Threshold: %.1f%%", 
                require_prob_filter ? "ON" : "OFF", prob_threshold);

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
    if(rsiHandle_TF != INVALID_HANDLE)
        IndicatorRelease(rsiHandle_TF);
        
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
//| Find Pivot High in higher timeframe data                         |
//+------------------------------------------------------------------+
double FindPivotHigh(double &high_arr[], int size, int left, int right, int index)
{
    if(index < left || index + right >= size) return EMPTY_VALUE;
    
    double pivot = high_arr[index];
    
    // Check left bars
    for(int i = 1; i <= left; i++)
    {
        if(high_arr[index - i] >= pivot) return EMPTY_VALUE;
    }
    
    // Check right bars
    for(int i = 1; i <= right; i++)
    {
        if(high_arr[index + i] > pivot) return EMPTY_VALUE;
    }
    
    return pivot;
}

//+------------------------------------------------------------------+
//| Find Pivot Low in higher timeframe data                          |
//+------------------------------------------------------------------+
double FindPivotLow(double &low_arr[], int size, int left, int right, int index)
{
    if(index < left || index + right >= size) return EMPTY_VALUE;
    
    double pivot = low_arr[index];
    
    // Check left bars
    for(int i = 1; i <= left; i++)
    {
        if(low_arr[index - i] <= pivot) return EMPTY_VALUE;
    }
    
    // Check right bars
    for(int i = 1; i <= right; i++)
    {
        if(low_arr[index + i] < pivot) return EMPTY_VALUE;
    }
    
    return pivot;
}

//+------------------------------------------------------------------+
//| Update Support/Resistance zones from higher timeframe            |
//+------------------------------------------------------------------+
void UpdateSRZones()
{
    int bars_to_copy = leftBars + rightBars + 50;
    double high_tf[], low_tf[];
    
    ArraySetAsSeries(high_tf, true);
    ArraySetAsSeries(low_tf, true);
    
    int copied_high = CopyHigh(_Symbol, sr_tf, 0, bars_to_copy, high_tf);
    int copied_low = CopyLow(_Symbol, sr_tf, 0, bars_to_copy, low_tf);
    
    if(copied_high < bars_to_copy || copied_low < bars_to_copy)
        return;
    
    int offset = rightBars + 1;
    
    // Look for resistance pivot (pivot high)
    double rPivot = FindPivotHigh(high_tf, copied_high, leftBars, rightBars, offset);
    if(rPivot != EMPTY_VALUE)
    {
        res_high = high_tf[offset];
        res_low = low_tf[offset];
    }
    
    // Look for support pivot (pivot low)
    double sPivot = FindPivotLow(low_tf, copied_low, leftBars, rightBars, offset);
    if(sPivot != EMPTY_VALUE)
    {
        sup_high = high_tf[offset];
        sup_low = low_tf[offset];
    }
}

//+------------------------------------------------------------------+
//| Check if price is in Support zone                                |
//+------------------------------------------------------------------+
bool IsInSupport(double price)
{
    if(sup_low <= 0 || sup_high <= 0) return false;
    
    double lowb = MathMin(sup_low, sup_high);
    double highb = MathMax(sup_low, sup_high);
    
    return (price >= lowb && price <= highb);
}

//+------------------------------------------------------------------+
//| Check if price is in Resistance zone                             |
//+------------------------------------------------------------------+
bool IsInResistance(double price)
{
    if(res_low <= 0 || res_high <= 0) return false;
    
    double lowb = MathMin(res_low, res_high);
    double highb = MathMax(res_low, res_high);
    
    return (price >= lowb && price <= highb);
}

//+------------------------------------------------------------------+
//| Calculate RSI Winrate from historical signals                    |
//+------------------------------------------------------------------+
void CalculateRSIWinrates(double &longProb, double &shortProb)
{
    longProb = 0.0;
    shortProb = 0.0;
    
    int longWins = 0, longTotal = 0;
    int shortWins = 0, shortTotal = 0;
    
    int bars_available = Bars(_Symbol, _Period);
    if(bars_available < 100) return;  // Need minimum history
    
    int maxScan = MathMin(bars_available - 10, 1000);
    
    double rsi_arr[], close_arr[], high_arr[], low_arr[], atr_arr[];
    ArraySetAsSeries(rsi_arr, true);
    ArraySetAsSeries(close_arr, true);
    ArraySetAsSeries(high_arr, true);
    ArraySetAsSeries(low_arr, true);
    ArraySetAsSeries(atr_arr, true);
    
    // Copy data
    if(CopyBuffer(rsiHandle, 0, 0, maxScan, rsi_arr) < maxScan) return;
    if(CopyBuffer(atrHandle, 0, 0, maxScan, atr_arr) < maxScan) return;
    if(CopyClose(_Symbol, _Period, 0, maxScan, close_arr) < maxScan) return;
    if(CopyHigh(_Symbol, _Period, 0, maxScan, high_arr) < maxScan) return;
    if(CopyLow(_Symbol, _Period, 0, maxScan, low_arr) < maxScan) return;
    
    // Scan historical signals
    for(int i = 1; i < maxScan - 1 && (longTotal < prob_look_signals || shortTotal < prob_look_signals); i++)
    {
        // Check for Long signal (crossunder)
        if(longTotal < prob_look_signals)
        {
            bool crossunder = (rsi_arr[i+1] > rsi_entry && rsi_arr[i] <= rsi_entry);
            
            if(crossunder)
            {
                double entryPrice = close_arr[i];
                double atrAtEntry = atr_arr[i];
                double sl, tp;
                CalcSLTP_fromEntry(entryPrice, true, atrAtEntry, sl, tp);
                
                // Check outcome in future bars
                bool foundOutcome = false;
                int maxK = MathMin(i, prob_max_future_bars);
                
                for(int k = 1; k <= maxK && !foundOutcome; k++)
                {
                    int f = i - k;  // future bar index
                    if(f < 0) break;
                    
                    if(tp > 0 && high_arr[f] >= tp)
                    {
                        longWins++;
                        longTotal++;
                        foundOutcome = true;
                    }
                    else if(sl > 0 && low_arr[f] <= sl)
                    {
                        longTotal++;
                        foundOutcome = true;
                    }
                }
            }
        }
        
        // Check for Short signal (crossover)
        if(shortTotal < prob_look_signals)
        {
            bool crossover = (rsi_arr[i+1] < rsi_exit && rsi_arr[i] >= rsi_exit);
            
            if(crossover)
            {
                double entryPrice = close_arr[i];
                double atrAtEntry = atr_arr[i];
                double sl, tp;
                CalcSLTP_fromEntry(entryPrice, false, atrAtEntry, sl, tp);
                
                // Check outcome in future bars
                bool foundOutcome = false;
                int maxK = MathMin(i, prob_max_future_bars);
                
                for(int k = 1; k <= maxK && !foundOutcome; k++)
                {
                    int f = i - k;
                    if(f < 0) break;
                    
                    if(tp > 0 && low_arr[f] <= tp)
                    {
                        shortWins++;
                        shortTotal++;
                        foundOutcome = true;
                    }
                    else if(sl > 0 && high_arr[f] >= sl)
                    {
                        shortTotal++;
                        foundOutcome = true;
                    }
                }
            }
        }
    }
    
    // Calculate probabilities
    longProb = (longTotal > 0) ? (longWins * 100.0 / longTotal) : 0.0;
    shortProb = (shortTotal > 0) ? (shortWins * 100.0 / shortTotal) : 0.0;
    
    static datetime lastLog = 0;
    if(TimeCurrent() - lastLog > 3600) // Log every hour
    {
        PrintFormat("RSI Winrate - Long: %.1f%% (%d/%d), Short: %.1f%% (%d/%d)", 
                    longProb, longWins, longTotal, shortProb, shortWins, shortTotal);
        lastLog = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Check if we have an open position                                |
//+------------------------------------------------------------------+
bool HasPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            if(PositionGetInteger(POSITION_MAGIC) == 0) // Our EA
                return true;
        }
    }
    return false;
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
    return -1;
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
                request.magic = 0;
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
    
    // Update SR zones
    UpdateSRZones();
    
    // Calculate RSI winrates
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
        prob_pass_long = (longProb >= prob_threshold) || (ignore_if_prob_zero && longProb == 0.0);
        prob_pass_short = (shortProb >= prob_threshold) || (ignore_if_prob_zero && shortProb == 0.0);
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
    
    // BUY Entry: RSI crossunder + in Support zone + probability filter
    if(enableBuy && buy_trigger && !hasPos && IsInSupport(price) && prob_pass_long)
    {
        double atrAtEntry = GetATR(0);
        double sl, tp;
        CalcSLTP_fromEntry(price, true, atrAtEntry, sl, tp);
        
        if(sl > 0 && tp > 0)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = lotSize;
            request.type = ORDER_TYPE_BUY;
            request.price = price;
            request.sl = sl;
            request.tp = tp;
            request.deviation = 10;
            request.magic = 0;
            request.comment = "RSI Long";
            request.type_filling = ORDER_FILLING_IOC;
            
            if(OrderSend(request, result))
            {
                PrintFormat("LONG ENTRY: Price=%.5f, SL=%.5f, TP=%.5f, RSI Winrate=%.1f%%", 
                           price, sl, tp, longProb);
            }
            else
            {
                PrintFormat("BUY order failed: %d - %s", result.retcode, result.comment);
            }
        }
    }
    
    // SELL Entry: RSI crossover + in Resistance zone + probability filter
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(enableSell && sell_trigger && !hasPos && IsInResistance(bid) && prob_pass_short)
    {
        double atrAtEntry = GetATR(0);
        double sl, tp;
        CalcSLTP_fromEntry(bid, false, atrAtEntry, sl, tp);
        
        if(sl > 0 && tp > 0)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = lotSize;
            request.type = ORDER_TYPE_SELL;
            request.price = bid;
            request.sl = sl;
            request.tp = tp;
            request.deviation = 10;
            request.magic = 0;
            request.comment = "RSI Short";
            request.type_filling = ORDER_FILLING_IOC;
            
            if(OrderSend(request, result))
            {
                PrintFormat("SHORT ENTRY: Price=%.5f, SL=%.5f, TP=%.5f, RSI Winrate=%.1f%%", 
                           bid, sl, tp, shortProb);
            }
            else
            {
                PrintFormat("SELL order failed: %d - %s", result.retcode, result.comment);
            }
        }
    }
}
