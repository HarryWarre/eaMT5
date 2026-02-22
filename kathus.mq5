//+------------------------------------------------------------------+
//|                                          KATHUS BOT - Rìu Chiến |
//|                     Triết lý: Heavy Trend Following (High R:R)   |
//|                                  Copyright 2026, DaiViet         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DaiViet"
#property version   "1.00" // The Double-Edged Axe
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT - Kiến trúc Hệ thống                                      |
//+------------------------------------------------------------------+
input group "=== 1. MARKET REGIME & STRATEGY ==="
enum ENUM_STRATEGY { STRAT_BREAK_BOX, STRAT_PULLBACK, STRAT_BOTH };
input ENUM_STRATEGY InpStrategyMode = STRAT_BOTH; // Chế độ vào lệnh
input int    InpADXPeriod      = 14;      // ADX Period (Trend Strength)
input double InpMinADX         = 25.0;    // ADX tối thiểu
input int    InpEMA200Period   = 200;     // EMA 200 (Trend Filter)

input group "=== 2. ENTRY LOGIC (Chi tiết) ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;  // Khung chính
input ENUM_TIMEFRAMES InpHTF       = PERIOD_H4;  // Khung lớn xác nhận
input int    InpEMA20Period    = 20;      // EMA 20
input int    InpEMA50Period    = 50;      // EMA 50
input int    InpBoxPeriod      = 10;      // [BreakBox] Số nến xác định hộp
input double InpBoxMaxH4      = 100.0;   // [BreakBox] Chiều cao tối đa Hộp (Points)
input double InpEntryBuffer    = 5.0;     // [Pullback] Khoảng cách đặt lệnh Stop (Points)

input group "=== 3. SCALING & EXIT ==="
input bool   InpUseScaling     = true;    // Kích hoạt nhồi lệnh
input int    InpMaxLayers      = 3;       // Tối đa 3 lớp lệnh
input double InpFullExitR      = 15.0;    // [NEW] Chốt lời toàn bộ tại R này (0 = tắt)

input group "=== 4. RISK MANAGER ==="
input double InpRiskPerTrade   = 1.0;     // Rủi ro mỗi lệnh (%)
input double InpMaxDrawdownPct = 12.0;    // Kill Switch (%)
input double InpBreakEvenR     = 2.0;     // Dời SL về hòa vốn (+2R)
input double InpPartialClose1R = 5.0;     // Chốt 30% (+5R)
input double InpPartialClose2R = 10.0;    // Chốt 40% (+10R)
input double InpPinBarRatio    = 2.0;     // Tỉ lệ râu/thân nến (Pin Bar)

input int    InpMagic          = 202609;

//+------------------------------------------------------------------+
//| BIẾN TOÀN CỤC                                                   |
//+------------------------------------------------------------------+
CTrade         Trade;
int            hADX, hEMA200, hMACD, hEMA20, hEMA50; // Indicators Handles
int            hEMA200_HTF, hMACD_HTF;                     // HTF Handles

// Struct quản lý trạng thái Scaling
struct PositionState {
   bool beMetricsTriggered;
   bool tp1Triggered;
   bool tp2Triggered; // Thêm logic persist nếu cần
};
PositionState state; // Lưu ý: Cần logic map state cho từng ticket nếu đánh nhiều lệnh. 
// Ở đây giản lược cho 1 series trade.

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   Trade.SetExpertMagicNumber(InpMagic);
   
   // --- Khởi tạo Indicators ---
   hADX    = iADX(_Symbol, InpTimeframe, InpADXPeriod);
   hEMA200 = iMA(_Symbol, InpTimeframe, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hEMA20  = iMA(_Symbol, InpTimeframe, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50  = iMA(_Symbol, InpTimeframe, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
   hMACD   = iMACD(_Symbol, InpTimeframe, 12, 26, 9, PRICE_CLOSE);
   
   // HTF Indicators
   hEMA200_HTF = iMA(_Symbol, InpHTF, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hMACD_HTF   = iMACD(_Symbol, InpHTF, 12, 26, 9, PRICE_CLOSE);
   
   if(hADX==INVALID_HANDLE || hEMA200==INVALID_HANDLE)
      return INIT_FAILED;
      
   Print("Kathus: Chiến binh Rìu Lớn đã sẵn sàng. Trend Following Mode.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hADX); IndicatorRelease(hEMA200); IndicatorRelease(hEMA20);
   IndicatorRelease(hEMA50); IndicatorRelease(hMACD);
   IndicatorRelease(hEMA200_HTF); IndicatorRelease(hMACD_HTF);
  }

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Kiểm tra Kill Switch (Drawdown)
   if(IsDrawdownExceeded()) return;
   
   // 2. Quản lý lệnh đang chạy (Exit, Trailing, Partial Close, Scaling)
   ManageOpenPositions();
   
   // 3. Chỉ vào lệnh mới khi có nến mới
   if(!IsNewBar()) return;
   
   // 4. Kiểm tra Market Regime (Môi trường)
   if(!IsMarketRegimeValid()) return;
   
   // 5. Tìm tín hiệu vào lệnh (Entry Logic)
   if(CountMyOrders() == 0) // Chỉ vào lệnh gốc nếu chưa có lệnh
     {
      double sl = 0;
      double entryPrice = 0;
      int signal = GetEntrySignal(sl, entryPrice);
      
      if(signal != 0 && sl != 0 && entryPrice != 0) 
         ExecuteEntry(signal, entryPrice, sl);
     }
  }

//+------------------------------------------------------------------+
//| MARKET REGIME: ADX > 25, EMA Slope                              |
//+------------------------------------------------------------------+
bool IsMarketRegimeValid()
  {
   double adx[];
   if(CopyBuffer(hADX, 0, 0, 1, adx) < 1) return false;
   
   // Trend phải đủ mạnh
   if(adx[0] < InpMinADX) return false;
   
   return true;
  }

//+------------------------------------------------------------------+
//| HELPERS: Forward Declarations                                   |
//+------------------------------------------------------------------+
bool IsUptrend(bool isHTF);
bool IsDowntrend(bool isHTF);
double GetIndicatorValue(int handle, int shift);
double GetSwingStopLoss(int dir);
bool IsPinBar(MqlRates &rates, int dir);
bool IsEngulfing(MqlRates &c, MqlRates &p, int dir);
bool IsTweezer(MqlRates &c, MqlRates &p, int dir);
bool IsPiercing(MqlRates &c, MqlRates &p);
bool IsDarkCloud(MqlRates &c, MqlRates &p);
bool IsMorningStar(MqlRates &c, MqlRates &m, MqlRates &p);
bool IsEveningStar(MqlRates &c, MqlRates &m, MqlRates &p);
bool IsThreeSoldiers(MqlRates &c, MqlRates &p, MqlRates &pp);
bool IsThreeCrows(MqlRates &c, MqlRates &p, MqlRates &pp);

//+------------------------------------------------------------------+
//| ENTRY LOGIC: Trend + Pullback                                   |
//+------------------------------------------------------------------+
int GetEntrySignal(double &outSL, double &outEntryPrice)
  {
   outSL = 0; outEntryPrice = 0;
   
   // A. Trend Validation
   bool h1Uptrend = IsUptrend(InpTimeframe);
   bool h4Uptrend = IsUptrend(InpHTF);
   bool h1Downtrend = IsDowntrend(InpTimeframe);
   bool h4Downtrend = IsDowntrend(InpHTF);
   
   if(!((h1Uptrend && h4Uptrend) || (h1Downtrend && h4Downtrend))) return 0;
   
   MqlRates rates[]; ArraySetAsSeries(rates, true);
   // Cần 4 nến cho mẫu hình 3 nến + Break Box
   int needed = MathMax(InpBoxPeriod + 2, 4); 
   if(CopyRates(_Symbol, InpTimeframe, 0, needed, rates) < needed) return 0;
   
   // B. Strategy 1: BREAK BOX
   if(InpStrategyMode == STRAT_BREAK_BOX || InpStrategyMode == STRAT_BOTH)
     {
      double boxHigh = -DBL_MAX, boxLow = DBL_MAX;
      for(int i=1; i<=InpBoxPeriod; i++) {
         if(rates[i].high > boxHigh) boxHigh = rates[i].high;
         if(rates[i].low < boxLow) boxLow = rates[i].low;
      }
      double boxHeight = (boxHigh - boxLow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(boxHeight <= InpBoxMaxH4) 
        {
          // Break Box: SL placed TIGHTLY at Box High/Low (1-2 points buffer only)
         if(h1Uptrend && rates[0].close > boxHigh && rates[1].close <= boxHigh) { outSL = boxLow - 1.0*_Point; outEntryPrice = rates[0].close; return 1; }
         if(h1Downtrend && rates[0].close < boxLow && rates[1].close >= boxLow) { outSL = boxHigh + 1.0*_Point; outEntryPrice = rates[0].close; return -1; }
        }
     }
     
   // C. Strategy 2: PULLBACK + ADVANCED PRICE ACTION
   if(InpStrategyMode == STRAT_PULLBACK || InpStrategyMode == STRAT_BOTH)
     {
      double ema20 = GetIndicatorValue(hEMA20, 0);
      double ema50 = GetIndicatorValue(hEMA50, 0);
      
      // Kiểm tra nến tín hiệu (Signal Bar) nằm trong vùng EMA
      // Với mô hình nhiều nến, kiểm tra nến hoàn thành gần nhất
      bool inZone = false; 
      
      if(h1Uptrend)
        {
         // Điều kiện vùng: Low của cụm nến chạm EMA20, Close trên EMA50
         if(rates[1].low <= ema20 && rates[1].close >= ema50) inZone = true;
         
         if(inZone)
           {
             // Quét tất cả mẫu hình BUY
             bool signalBuy = false;
             double slCandidate = 0;
             bool isPinBarEntry = false;
             
             if(IsPinBar(rates[1], 1)) { signalBuy = true; slCandidate = rates[1].low; isPinBarEntry = true; }
             else if(IsEngulfing(rates[0], rates[1], 1)) { signalBuy = true; slCandidate = rates[1].low; }
             else if(IsMorningStar(rates[0], rates[1], rates[2])) { signalBuy = true; slCandidate = MathMin(rates[1].low, rates[2].low); }
             else if(IsThreeSoldiers(rates[0], rates[1], rates[2])) { signalBuy = true; slCandidate = rates[2].low; }
             else if(IsPiercing(rates[0], rates[1])) { signalBuy = true; slCandidate = rates[1].low; }
             else if(IsTweezer(rates[0], rates[1], 1)) { signalBuy = true; slCandidate = rates[1].low; }
             
             if(signalBuy)
               {
                // Nếu là Pinbar, đặt SL sát đáy nến (không cộng buffer quá lớn) hoặc tùy chỉnh
                double buffer = isPinBarEntry ? 0 : InpEntryBuffer * _Point; 
                outSL = slCandidate - buffer; 
                
                // Đảm bảo tối thiểu 1 point
                if(isPinBarEntry) outSL -= _Point;
                
                outEntryPrice = rates[0].close;
                return 1;
               }
            }
         }
         
       if(h1Downtrend)
         {
          if(rates[1].high >= ema20 && rates[1].close <= ema50) inZone = true;
          
          if(inZone)
            {
             bool signalSell = false;
             double slCandidate = 0;
             bool isPinBarEntry = false;
             
             if(IsPinBar(rates[1], -1)) { signalSell = true; slCandidate = rates[1].high; isPinBarEntry = true; }
             else if(IsEngulfing(rates[0], rates[1], -1)) { signalSell = true; slCandidate = rates[1].high; }
             else if(IsEveningStar(rates[0], rates[1], rates[2])) { signalSell = true; slCandidate = MathMax(rates[1].high, rates[2].high); }
             else if(IsThreeCrows(rates[0], rates[1], rates[2])) { signalSell = true; slCandidate = rates[2].high; }
             else if(IsDarkCloud(rates[0], rates[1])) { signalSell = true; slCandidate = rates[1].high; }
             else if(IsTweezer(rates[0], rates[1], -1)) { signalSell = true; slCandidate = rates[1].high; }
             
             if(signalSell)
               {
                double buffer = isPinBarEntry ? 0 : InpEntryBuffer * _Point;
                outSL = slCandidate + buffer;
                
                if(isPinBarEntry) outSL += _Point;
                
                outEntryPrice = rates[0].close;
                return -1;
               }
            }
        }
     }
     
   return 0;
  }

//+------------------------------------------------------------------+
//| EXECUTION: Vào lệnh với Swing SL                                |
//+------------------------------------------------------------------+
void ExecuteEntry(int direction, double entryPrice, double stopLoss)
  {
   double distSL = MathAbs(entryPrice - stopLoss);
   
   if(distSL <= _Point) return;
   
   // Tính Lot theo Risk %
   double lot = CalculateRiskLot(distSL);
   
   string comment = "Kathus Entry";
   
   if(direction == 1) Trade.Buy(lot, _Symbol, entryPrice, stopLoss, 0, comment); 
   else Trade.Sell(lot, _Symbol, entryPrice, stopLoss, 0, comment);
   
   Print("Kathus: ENTRY! Dir=", direction, " Lot=", lot, " Price=", entryPrice, " SL=", stopLoss);
  }

//+------------------------------------------------------------------+
//| MANAGEMENT: Trailing, Partial Close, Scaling                    |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   if(PositionsTotal() == 0) return;
   
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetSymbol(i) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double currentSL = PositionGetDouble(POSITION_SL); 
      double currentVol = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      
      // Lấy thông tin gốc
      double initialSL = 0;
      double initialVol = 0;
      if(!GetInitialTradeInfo(ticket, initialSL, initialVol)) { initialSL = currentSL; initialVol = currentVol; }
        
      double riskDist = MathAbs(entryPrice - initialSL);
      if(riskDist < _Point) continue;
      
      double profitDist = (type == POSITION_TYPE_BUY) ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
      double currentR = profitDist / riskDist;
      
      // 0. FULL EXIT (New Feature)
      if(InpFullExitR > 0 && currentR >= InpFullExitR)
        {
         Trade.PositionClose(ticket);
         Print("Kathus: FULL CLOSE at +", currentR, "R. Mission Complete!");
         continue; 
        }
      
      // 1. Break Even (+2R)
      bool isBESet = (type == POSITION_TYPE_BUY && currentSL >= entryPrice) || (type == POSITION_TYPE_SELL && currentSL <= entryPrice && currentSL > 0);
      
      if(currentR >= InpBreakEvenR && !isBESet)
        {
         Trade.PositionModify(ticket, entryPrice, 0); 
         Print("Kathus: Move SL to Breakeven (+2R). Ticket:", ticket);
        }
        
      // 2. Partial Close
      double pctRemaining = (initialVol > 0) ? (currentVol / initialVol) : 1.0;
      
      if(currentR >= InpPartialClose1R && pctRemaining > 0.75) 
        {
         double closeVol = NormalizeLot(initialVol * 0.3);
         if(closeVol > 0 && closeVol < currentVol) { Trade.PositionClosePartial(ticket, closeVol); Print("Kathus: Partial Close 30% (+5R)."); continue; }
        }
      
      if(currentR >= InpPartialClose2R && pctRemaining > 0.35)
        {
         double closeVol = NormalizeLot(initialVol * 0.4);
         if(closeVol > 0 && closeVol < currentVol) { Trade.PositionClosePartial(ticket, closeVol); Print("Kathus: Partial Close 40% (+10R)."); continue; }
        }
        
      // 3. Dynamic Trailing Stop (> 2R va da BE)
      if(currentR >= InpBreakEvenR && isBESet)
        {
           double newSL = GetSwingStopLoss(type == POSITION_TYPE_BUY ? 1 : -1);
           bool update = false;
           if(type == POSITION_TYPE_BUY && newSL > currentSL && newSL < currentPrice) update = true;
           if(type == POSITION_TYPE_SELL && (newSL < currentSL || currentSL == 0) && newSL > currentPrice) update = true;
           
           if(update) { Trade.PositionModify(ticket, newSL, 0); Print("Kathus: Trailing updates. R=", currentR); }
        }
     }
  }

// --- PRICE ACTION IMPL (Extended) ---

bool IsPinBar(MqlRates &rates, int dir)
  {
   double body = MathAbs(rates.close - rates.open);
   double u = rates.high - MathMax(rates.open, rates.close);
   double l = MathMin(rates.open, rates.close) - rates.low;
   if(body==0) body=_Point;
   if(dir==1) return (l >= body * InpPinBarRatio && u < l*0.5); // Bullish Pinbar uses InpRatio
   if(dir==-1) return (u >= body * InpPinBarRatio && l < u*0.5); // Bearish Pinbar uses InpRatio
   return false;
  }

bool IsEngulfing(MqlRates &c, MqlRates &p, int dir)
  {
   if(dir==1) return (c.close > c.open && c.close > p.high && c.open < p.low); 
   if(dir==-1) return (c.close < c.open && c.close < p.low && c.open > p.high);
   return false;
  }

bool IsTweezer(MqlRates &c, MqlRates &p, int dir)
  {
   double diff = 5 * _Point;
   if(dir==1) return (MathAbs(c.low - p.low) <= diff && c.close > c.open);
   if(dir==-1) return (MathAbs(c.high - p.high) <= diff && c.close < c.open);
   return false;
  }

bool IsPiercing(MqlRates &c, MqlRates &p)
  {
   return (p.close < p.open && c.close > c.open && c.open < p.low && c.close > (p.open + p.close)/2);
  }

bool IsDarkCloud(MqlRates &c, MqlRates &p)
  {
   return (p.close > p.open && c.close < c.open && c.open > p.high && c.close < (p.open + p.close)/2);
  }

bool IsMorningStar(MqlRates &c, MqlRates &m, MqlRates &p)
  {
   return (p.close < p.open && MathAbs(m.close - m.open) < (p.high-p.low)*0.3 && c.close > c.open && c.close > (p.open + p.close)/2);
  }

bool IsEveningStar(MqlRates &c, MqlRates &m, MqlRates &p)
  {
   return (p.close > p.open && MathAbs(m.close - m.open) < (p.high-p.low)*0.3 && c.close < c.open && c.close < (p.open + p.close)/2);
  }

bool IsThreeSoldiers(MqlRates &c, MqlRates &p, MqlRates &pp)
  {
   return (c.close > c.open && p.close > p.open && pp.close > pp.open && c.close > p.close && p.close > pp.close);
  }

bool IsThreeCrows(MqlRates &c, MqlRates &p, MqlRates &pp)
  {
   return (c.close < c.open && p.close < p.open && pp.close < pp.open && c.close < p.close && p.close < pp.close);
  }


// Helper lấy thông tin gốc từ History
bool GetInitialTradeInfo(ulong ticketPos, double &outSL, double &outVol)
  {
   if(!HistorySelectByPosition(ticketPos)) return false;
   int deals = HistoryDealsTotal();
   
   // Tìm Deal đầu tiên (Deal In)
   for(int i=0; i<deals; i++)
     {
      ulong ticketDeal = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticketDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
        {
         // Deal IN chưa chắc chứa SL (thường SL ở Order). Nhưng ta lấy Order từ Deal.
         ulong orderTicket = HistoryDealGetInteger(ticketDeal, DEAL_ORDER);
         if(HistoryOrderSelect(orderTicket))
           {
            outSL = HistoryOrderGetDouble(orderTicket, ORDER_SL);
            outVol = HistoryOrderGetDouble(orderTicket, ORDER_VOLUME_INITIAL);
            return true;
           }
        }
     }
   // Fallback: Thử tìm lệnh pending nếu có (nhưng Kathus vào market)
   return false;
  }


//+------------------------------------------------------------------+
//| HELPERS: Trend Validation & Risk                                |
//+------------------------------------------------------------------+

// Logic: Giá > EMA200 và MACD > 0
bool IsUptrend(bool isHTF)
  {
   int handleEMA = isHTF ? hEMA200_HTF : hEMA200;
   int handleMACD = isHTF ? hMACD_HTF : hMACD;
   
   double ema[], macd[];
   if(CopyBuffer(handleEMA, 0, 0, 1, ema) < 1) return false;
   if(CopyBuffer(handleMACD, 0, 0, 1, macd) < 1) return false;
   
   double close = iClose(_Symbol, isHTF ? InpHTF : InpTimeframe, 0);
   
   return (close > ema[0] && macd[0] > 0);
  }

bool IsDowntrend(bool isHTF)
  {
   int handleEMA = isHTF ? hEMA200_HTF : hEMA200;
   int handleMACD = isHTF ? hMACD_HTF : hMACD;
   
   double ema[], macd[];
   if(CopyBuffer(handleEMA, 0, 0, 1, ema) < 1) return false;
   if(CopyBuffer(handleMACD, 0, 0, 1, macd) < 1) return false;
   
   double close = iClose(_Symbol, isHTF ? InpHTF : InpTimeframe, 0);
   
   return (close < ema[0] && macd[0] < 0);
  }

// Swing High/Low cho SL
double GetSwingStopLoss(int dir)
  {
   int bars = 20;
   int shift = 1;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(dir == 1) // Buy -> Tìm đáy thấp nhất (Swing Low)
     {
      int lowest = iLowest(_Symbol, InpTimeframe, MODE_LOW, bars, shift);
      if(lowest == -1) return SymbolInfoDouble(_Symbol, SYMBOL_BID) - 100 * point;
      return iLow(_Symbol, InpTimeframe, lowest) - 10 * point; // Buffer nhẹ
     }
   else // Sell -> Tìm đỉnh cao nhất (Swing High)
     {
      int highest = iHighest(_Symbol, InpTimeframe, MODE_HIGH, bars, shift);
      if(highest == -1) return SymbolInfoDouble(_Symbol, SYMBOL_ASK) + 100 * point;
      return iHigh(_Symbol, InpTimeframe, highest) + 10 * point; // Buffer nhẹ
     }
  }

double CalculateRiskLot(double slDistance)
  {
   if(slDistance <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPerTrade / 100.0;
   
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickVal == 0 || tickSize == 0 || point == 0) return 0.01;
   
   // Công thức chuẩn: Lot = Money / (StopLossPoints * TickValuePerPoint)
   // StopLossPoints = slDistance / point
   // TickValuePerPoint = TickValue / (TickSize / Point)
   
   double lossPerLot = (slDistance / tickSize) * tickVal; // Loss tiền trên 1 lot
   if(lossPerLot == 0) return 0.01;
   
   double lot = riskMoney / lossPerLot;
   
   return NormalizeLot(lot);
  }

double NormalizeLot(double lot)
  {
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(step > 0) lot = MathFloor(lot / step) * step;
   if(lot < min) lot = min;
   if(lot > max) lot = max;
   return lot;
  }

double GetIndicatorValue(int handle, int shift)
  {
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0;
   return buf[0];
  }

bool IsNewBar()
  {
   static datetime last = 0;
   datetime curr = iTime(_Symbol, InpTimeframe, 0);
   if(curr != last) { last = curr; return true; }
   return false;
  }

bool IsDrawdownExceeded()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return false;
   return ((balance - equity)/balance * 100.0) >= InpMaxDrawdownPct;
  }

int CountMyOrders()
  {
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) count++;
   return count;
}
