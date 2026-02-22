//+------------------------------------------------------------------+
//|                                     ICHIMOKU PA BOT - Tử Chiến   |
//|               Triết lý: Định thời gian (Kihon Suchi) + Đảo chiều |
//|                                  Copyright 2026, DaiViet         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DaiViet"
#property version   "1.00" // Ichimoku + 13 PA Models
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT - Luật chơi                                                |
//+------------------------------------------------------------------+

enum ENUM_LOT_MODE
  {
   LOT_MODE_PERCENT, // Risk Percentage
   LOT_MODE_FIXED    // Fixed Lot
  };

enum ENUM_MARTINGALE_MODE
  {
   MARTINGALE_MODE_NORMAL, // Bình thường (Chờ Lãi Ròng)
   MARTINGALE_MODE_SMART   // Smart (Đóng hòa vốn ngay khi về 0)
  };

input group "=== QUẢN LÝ VỐN (Money Management) ==="
input ENUM_LOT_MODE InpLotMode = LOT_MODE_PERCENT; // Chế độ tính Lot
input double InpBaseRisk       = 1.0;              // Rủi ro cơ bản (%) (Cho Risk%)
input double InpFixedLot       = 0.01;             // Lot cố định (Cho Fixed Lot)
input double InpMaxDrawdownPct = 50.0;             // Sụt giảm tối đa (%) - Chế độ phòng thủ


input group "=== CHIẾN THUẬT ICHIMOKU + PA ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15; // Khung thực thi
input int    InpScanBars       = 100;     // Quét X nến gần nhất tìm Đỉnh/Đáy
input int    InpToleranceBars  = 1;       // Dung sai đếm nến (±1 nến)
input int    InpRSIPeriod      = 14;      // RSI Period

input group "=== MARTINGALE DCA ==="
input ENUM_MARTINGALE_MODE InpMartMode = MARTINGALE_MODE_SMART; // Chế độ Smart hay Normal
input double InpMartMultiplier = 2.0;     // Hệ số nhân Martingale
input int    InpMartGridPips   = 300;     // Khoảng cách giữa các tầng (points)
input int    InpMartClosePips  = 50;      // Lãi tối thiểu để đóng normal hedge (points)
input int    InpSmartThresholdPips = 50;  // Ngưỡng an toàn sau khi đóng hòa vốn (points)


input group "=== INTRADAY & TIN TỨC ==="
input int    InpStartHour      = 8;       // Giờ bắt đầu giao chiến
input int    InpEndHour        = 22;      // Giờ ngừng mở lệnh mới
input int    InpCloseHour      = 23;      // Giờ đóng lệnh
input bool   InpForceCloseAtEOD = false;  // Đóng hết lệnh cuối ngày (Bất kể Lời/Lỗ)
input bool   InpTradeWeekends  = false;   // Giao dịch cuối tuần (T6, T7, CN)
input int    InpNewsBufferMins = 60;      // Né bão tin tức (phút trước/sau)

input group "=== ENDURANCE (Sức bền) ==="
input int    InpMaxLossesPerDay = 5;       // Số lần thua tối đa/ngày -> Ngất xỉu

input int    InpMagic           = 202611;  // Magic Number (Ichimoku)

//+------------------------------------------------------------------+
//| BIẾN TOÀN CỤC                                                   |
//+------------------------------------------------------------------+
CTrade         Trade;
int            handleRSI;
int            dailyLosses;       // Đếm số lần thua trong ngày
datetime       lastBarTime;       // Kiểm soát chỉ trade 1 lần/nến
int            martingaleLevel;   // Tầng Martingale hiện tại
double         initialBalance;    // Vốn ban đầu

// Global variables for Smart Hedge
double         lastBreakEvenClosePrice = 0.0; // Giá đóng hòa vốn gần nhất


//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   Trade.SetExpertMagicNumber(InpMagic);
   
   handleRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   
   if(handleRSI == INVALID_HANDLE)
     {
      Print("Odin: Lỗi khởi tạo RSI.");
      return INIT_FAILED;
     }
   
   dailyLosses     = 0;
   lastBarTime      = 0;
   martingaleLevel  = 0;
   initialBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
   
   Print("Odin: Hệ thống Price Action Mở Rộng sẵn sàng (13 Models).");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleRSI);
   Print("Odin: Rời vòng tròn. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| TICK - Mỗi nhịp thở thị trường                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Reset counter khi sang ngày mới
   ResetDailyCounters();
   
   // Quản lý Intraday
   ManageIntradayExit();
   
   // Quản lý Martingale (Bồi lệnh)
   ManageMartingale();

   // Quản lý rủi ro (Cắt lỗ khẩn cấp)
   ManageDrawdownProtection();
   
   // Filter nến mới
   if(!IsNewBar()) return;
   
   // Các bộ lọc điều kiện
   if(dailyLosses >= InpMaxLossesPerDay) return; // Ngất xỉu
   if(!IsCoreStable()) return;                   // Cháy
   if(!IsWithinTradingHours()) return;           // Giờ nghỉ
   if(IsNewsStorm()) return;                     // Bão
   if(CountMyOrders() > 0) return;               // Đang có lệnh
   
   // Quét tín hiệu Ichimoku Time + 13 PA
   int signal = CheckIchimokuSignal();
   if(signal != 0)
      ExecuteEntry(signal);
  }

//+------------------------------------------------------------------+
//| SIGNAL: RSI + D1 + Ichimoku Time + 13 PA Models                 |
//+------------------------------------------------------------------+
bool IsIchimokuCycle(int bars) {
   int ichiNumbers[] = {9, 17, 26, 33, 42, 65, 76, 129, 226};
   for(int i = 0; i < ArraySize(ichiNumbers); i++) {
      if(MathAbs(bars - ichiNumbers[i]) <= InpToleranceBars) return true;
   }
   return false;
}

int CheckIchimokuSignal()
  {
   // 1. D1 Trend
   int d1Dir = GetDailyDirection();
   if(d1Dir == 0) return 0;
   
   // 2. RSI Filter
   double rsi = GetRSI();
   
   // 3. Ichimoku Time Theory (Kihon Suchi) Check
   int highestIdx = iHighest(_Symbol, InpTimeframe, MODE_HIGH, InpScanBars, 1);
   int lowestIdx = iLowest(_Symbol, InpTimeframe, MODE_LOW, InpScanBars, 1);
   
   bool isCycleFromHigh = IsIchimokuCycle(highestIdx); // Đang ở chu kỳ tính từ đỉnh (Kỳ vọng tạo đáy/đảo chiều lên)
   bool isCycleFromLow = IsIchimokuCycle(lowestIdx);   // Đang ở chu kỳ tính từ đáy (Kỳ vọng tạo đỉnh/đảo chiều xuống)
   
   if(!isCycleFromHigh && !isCycleFromLow) return 0; // Chưa tới điểm rơi thời gian
   
   // 4. Price Action Check (Cần 6 nến cho mẫu hình 5 nến + shift)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 1, 6, rates) < 6) return 0;
   
   // Kiểm tra tất cả 13 mẫu hình
   bool isBuy = false;
   bool isSell = false;
   
   // --- 1. Piercing Line / Dark Cloud Cover (2 nến) ---
   if(IsPiercing(rates[0], rates[1])) isBuy = true;
   if(IsDarkCloud(rates[0], rates[1])) isSell = true;
   
   // --- 2. Kicking (2 nến) ---
   if(IsKickingBull(rates[0], rates[1])) isBuy = true;
   if(IsKickingBear(rates[0], rates[1])) isSell = true;
   
   // --- 3. Abandoned Baby (3 nến) ---
   if(IsAbandonedBabyBull(rates[0], rates[1], rates[2])) isBuy = true;
   if(IsAbandonedBabyBear(rates[0], rates[1], rates[2])) isSell = true;
   
   // --- 4. Morning Doji Star / Evening Doji Star (3 nến) ---
   if(IsMorningDojiStar(rates[0], rates[1], rates[2])) isBuy = true;
   if(IsEveningDojiStar(rates[0], rates[1], rates[2])) isSell = true;
   
   // --- 5. Morning Star / Evening Star (3 nến) ---
   if(IsMorningStar(rates[0], rates[1], rates[2])) isBuy = true;
   if(IsEveningStar(rates[0], rates[1], rates[2])) isSell = true;
   
   // --- 6. Three Inside Up / Down (3 nến) ---
   if(IsThreeInsideUp(rates[0], rates[1], rates[2])) isBuy = true;
   if(IsThreeInsideDown(rates[0], rates[1], rates[2])) isSell = true;
   
   // --- 7. Three Outside Up / Down (3 nến) ---
   if(IsThreeOutsideUp(rates[0], rates[1], rates[2])) isBuy = true;
   if(IsThreeOutsideDown(rates[0], rates[1], rates[2])) isSell = true;
   
   // --- 8. Three White Soldiers / Three Black Crows (3 nến) ---
   if(IsThreeSoldiers(rates[0], rates[1], rates[2])) isBuy = true;
   if(IsThreeCrows(rates[0], rates[1], rates[2])) isSell = true;
   
   // --- 9. Engulfing (2 nến) ---
   if(IsEngulfing(rates[0], rates[1], 1)) isBuy = true;
   if(IsEngulfing(rates[0], rates[1], -1)) isSell = true;
   
   // --- 10. Breakaway (5 nến) ---
   if(IsBreakawayBull(rates[0], rates[1], rates[2], rates[3], rates[4])) isBuy = true;
   if(IsBreakawayBear(rates[0], rates[1], rates[2], rates[3], rates[4])) isSell = true;
   
   // --- 11. Mat Hold (5 nến) ---
   if(IsMatHoldBull(rates[0], rates[1], rates[2], rates[3], rates[4])) isBuy = true;
   if(IsMatHoldBear(rates[0], rates[1], rates[2], rates[3], rates[4])) isSell = true;
   
   // --- 12. Rising Three Methods / Falling Three Methods (5 nến) ---
   if(IsRisingThreeMethods(rates[0], rates[1], rates[2], rates[3], rates[4])) isBuy = true;
   if(IsFallingThreeMethods(rates[0], rates[1], rates[2], rates[3], rates[4])) isSell = true;
   
   // --- 13. Ladder Bottom / Ladder Top (5 nến) ---
   if(IsLadderBottom(rates[0], rates[1], rates[2], rates[3], rates[4])) isBuy = true;
   if(IsLadderTop(rates[0], rates[1], rates[2], rates[3], rates[4])) isSell = true;
   
   // Hợp lưu BUY: Thời gian từ Đỉnh + D1 Xanh + RSI > 50 + PA Buy
   if(isCycleFromHigh && d1Dir == 1 && rsi > 50.0 && isBuy) {
      if(lastBreakEvenClosePrice > 0) {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double dist = MathAbs(currentPrice - lastBreakEvenClosePrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(dist < InpSmartThresholdPips) return 0; // Chưa qua vùng nguy hiểm
      }
      return 1;
   }
   
   // Hợp lưu SELL: Thời gian từ Đáy + D1 Đỏ + RSI < 50 + PA Sell
   if(isCycleFromLow && d1Dir == -1 && rsi < 50.0 && isSell) {
      if(lastBreakEvenClosePrice > 0) {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double dist = MathAbs(currentPrice - lastBreakEvenClosePrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(dist < InpSmartThresholdPips) return 0; // Chưa qua vùng nguy hiểm
      }
      return -1;
   }
   
   return 0;
  }

//+------------------------------------------------------------------+
//| 1. Piercing Line / Dark Cloud Cover (2 nến)                      |
//+------------------------------------------------------------------+
bool IsPiercing(MqlRates &c, MqlRates &p) // Buy
  {
   return (p.close < p.open && // Nến trước đỏ
           c.close > c.open && // Nến này xanh
           c.open < p.low &&   // Mở cửa Gap down
           c.close > (p.open + p.close)/2); // Đóng cửa trên 50% nến trước
  }

bool IsDarkCloud(MqlRates &c, MqlRates &p) // Sell
  {
   return (p.close > p.open && // Nến trước xanh
           c.close < c.open && // Nến này đỏ
           c.open > p.high &&  // Mở cửa Gap up
           c.close < (p.open + p.close)/2); // Đóng cửa dưới 50% nến trước
  }

//+------------------------------------------------------------------+
//| 2. Kicking (2 nến) - Marubozu đảo chiều                          |
//+------------------------------------------------------------------+
bool IsKickingBull(MqlRates &c, MqlRates &p) // Buy
  {
   double pBody = MathAbs(p.close - p.open);
   double pRange = p.high - p.low;
   double cBody = MathAbs(c.close - c.open);
   double cRange = c.high - c.low;
   if(pRange == 0 || cRange == 0) return false;
   
   return (p.close < p.open &&          // Nến trước đỏ (Marubozu)
           pBody > pRange * 0.8 &&       // Thân > 80% range (gần Marubozu)
           c.close > c.open &&           // Nến này xanh (Marubozu)
           cBody > cRange * 0.8 &&       // Thân > 80% range
           c.open > p.close);            // Gap up (mở cửa trên đóng cửa nến trước)
  }

bool IsKickingBear(MqlRates &c, MqlRates &p) // Sell
  {
   double pBody = MathAbs(p.close - p.open);
   double pRange = p.high - p.low;
   double cBody = MathAbs(c.close - c.open);
   double cRange = c.high - c.low;
   if(pRange == 0 || cRange == 0) return false;
   
   return (p.close > p.open &&          // Nến trước xanh (Marubozu)
           pBody > pRange * 0.8 &&       // Thân > 80% range
           c.close < c.open &&           // Nến này đỏ (Marubozu)
           cBody > cRange * 0.8 &&       // Thân > 80% range
           c.open < p.close);            // Gap down
  }

//+------------------------------------------------------------------+
//| 3. Abandoned Baby (3 nến) - Doji gap cách ly                     |
//+------------------------------------------------------------------+
bool IsAbandonedBabyBull(MqlRates &c, MqlRates &m, MqlRates &p) // Buy
  {
   double mBody = MathAbs(m.close - m.open);
   double mRange = m.high - m.low;
   if(mRange == 0) return false;
   
   return (p.close < p.open &&           // Nến 1 đỏ dài
           mBody < mRange * 0.1 &&        // Nến 2 Doji (thân < 10% range)
           m.high < p.low &&              // Gap down giữa nến 1 và Doji
           c.close > c.open &&            // Nến 3 xanh
           c.low > m.high);               // Gap up giữa Doji và nến 3
  }

bool IsAbandonedBabyBear(MqlRates &c, MqlRates &m, MqlRates &p) // Sell
  {
   double mBody = MathAbs(m.close - m.open);
   double mRange = m.high - m.low;
   if(mRange == 0) return false;
   
   return (p.close > p.open &&           // Nến 1 xanh dài
           mBody < mRange * 0.1 &&        // Nến 2 Doji
           m.low > p.high &&              // Gap up giữa nến 1 và Doji
           c.close < c.open &&            // Nến 3 đỏ
           c.high < m.low);               // Gap down giữa Doji và nến 3
  }

//+------------------------------------------------------------------+
//| 4. Morning Doji Star / Evening Doji Star (3 nến)                 |
//+------------------------------------------------------------------+
bool IsMorningDojiStar(MqlRates &c, MqlRates &m, MqlRates &p) // Buy
  {
   double mBody = MathAbs(m.close - m.open);
   double mRange = m.high - m.low;
   double pBody = MathAbs(p.close - p.open);
   if(mRange == 0) return false;
   
   return (p.close < p.open &&           // Nến 1 đỏ dài
           pBody > (p.high-p.low)*0.5 &&  // Thân nến 1 lớn
           mBody < mRange * 0.1 &&        // Nến 2 Doji chính xác
           m.high < p.low &&              // Doji gap down
           c.close > c.open &&            // Nến 3 xanh
           c.close > (p.open + p.close)/2); // Đóng trên 50% nến 1
  }

bool IsEveningDojiStar(MqlRates &c, MqlRates &m, MqlRates &p) // Sell
  {
   double mBody = MathAbs(m.close - m.open);
   double mRange = m.high - m.low;
   double pBody = MathAbs(p.close - p.open);
   if(mRange == 0) return false;
   
   return (p.close > p.open &&           // Nến 1 xanh dài
           pBody > (p.high-p.low)*0.5 &&  // Thân nến 1 lớn
           mBody < mRange * 0.1 &&        // Nến 2 Doji chính xác
           m.low > p.high &&              // Doji gap up
           c.close < c.open &&            // Nến 3 đỏ
           c.close < (p.open + p.close)/2); // Đóng dưới 50% nến 1
  }

//+------------------------------------------------------------------+
//| 5. Morning Star / Evening Star (3 nến)                           |
//+------------------------------------------------------------------+
bool IsMorningStar(MqlRates &c, MqlRates &m, MqlRates &p)
  {
   return (p.close < p.open && // 1. Nến đỏ dài
           MathAbs(m.close - m.open) < (p.high-p.low)*0.3 && // 2. Nến giữa nhỏ (Star)
           c.close > c.open && // 3. Nến xanh
           c.close > (p.open + p.close)/2); // Đóng trên 50% nến 1
  }

bool IsEveningStar(MqlRates &c, MqlRates &m, MqlRates &p)
  {
   return (p.close > p.open && // 1. Nến xanh dài
           MathAbs(m.close - m.open) < (p.high-p.low)*0.3 && // 2. Nến giữa nhỏ
           c.close < c.open && // 3. Nến đỏ
           c.close < (p.open + p.close)/2); // Đóng dưới 50% nến 1
  }

//+------------------------------------------------------------------+
//| 6. Three Inside Up / Three Inside Down (3 nến)                   |
//+------------------------------------------------------------------+
bool IsThreeInsideUp(MqlRates &c, MqlRates &m, MqlRates &p) // Buy
  {
   return (p.close < p.open &&           // Nến 1 đỏ dài
           m.close > m.open &&            // Nến 2 xanh
           m.high < p.high &&             // Nến 2 nằm trong nến 1 (Inside Bar)
           m.low > p.low &&
           m.close > (p.open + p.close)/2 && // Đóng trên 50% nến 1
           c.close > c.open &&            // Nến 3 xanh
           c.close > p.open);             // Nến 3 đóng trên đỉnh nến 1
  }

bool IsThreeInsideDown(MqlRates &c, MqlRates &m, MqlRates &p) // Sell
  {
   return (p.close > p.open &&           // Nến 1 xanh dài
           m.close < m.open &&            // Nến 2 đỏ
           m.high < p.high &&             // Nến 2 nằm trong nến 1 (Inside Bar)
           m.low > p.low &&
           m.close < (p.open + p.close)/2 && // Đóng dưới 50% nến 1
           c.close < c.open &&            // Nến 3 đỏ
           c.close < p.open);             // Nến 3 đóng dưới đáy nến 1
  }

//+------------------------------------------------------------------+
//| 7. Three Outside Up / Three Outside Down (3 nến)                 |
//+------------------------------------------------------------------+
bool IsThreeOutsideUp(MqlRates &c, MqlRates &m, MqlRates &p) // Buy
  {
   return (p.close < p.open &&           // Nến 1 đỏ
           m.close > m.open &&            // Nến 2 xanh (Engulfing)
           m.close > p.open &&            // Nến 2 đóng trên open nến 1
           m.open < p.close &&            // Nến 2 mở dưới close nến 1
           c.close > c.open &&            // Nến 3 xanh
           c.close > m.close);            // Nến 3 đóng cao hơn nến 2
  }

bool IsThreeOutsideDown(MqlRates &c, MqlRates &m, MqlRates &p) // Sell
  {
   return (p.close > p.open &&           // Nến 1 xanh
           m.close < m.open &&            // Nến 2 đỏ (Engulfing)
           m.close < p.open &&            // Nến 2 đóng dưới open nến 1
           m.open > p.close &&            // Nến 2 mở trên close nến 1
           c.close < c.open &&            // Nến 3 đỏ
           c.close < m.close);            // Nến 3 đóng thấp hơn nến 2
  }

//+------------------------------------------------------------------+
//| 8. Three White Soldiers / Three Black Crows (3 nến)              |
//+------------------------------------------------------------------+
bool IsThreeSoldiers(MqlRates &c, MqlRates &p, MqlRates &pp)
  {
   return (c.close > c.open && p.close > p.open && pp.close > pp.open && // 3 nến xanh
           c.close > p.close && p.close > pp.close && // Đóng cửa cao dần
           c.high > p.high && p.high > pp.high); // Đỉnh cao dần (lực mạnh)
  }

bool IsThreeCrows(MqlRates &c, MqlRates &p, MqlRates &pp)
  {
   return (c.close < c.open && p.close < p.open && pp.close < pp.open && // 3 nến đỏ
           c.close < p.close && p.close < pp.close && // Đóng cửa thấp dần
           c.low < p.low && p.low < pp.low); // Đáy thấp dần
  }

//+------------------------------------------------------------------+
//| 9. Engulfing (2 nến)                                             |
//+------------------------------------------------------------------+
bool IsEngulfing(MqlRates &c, MqlRates &p, int dir)
  {
   if(dir==1) return (c.close > c.open && c.close > p.high && c.open < p.low); // Bullish
   if(dir==-1) return (c.close < c.open && c.close < p.low && c.open > p.high); // Bearish
   return false;
  }

//+------------------------------------------------------------------+
//| 10. Breakaway (5 nến) - Gap mạnh rồi đảo chiều                  |
//+------------------------------------------------------------------+
bool IsBreakawayBull(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Buy
  {
   // c5=nến cũ nhất, c1=nến mới nhất
   return (c5.close < c5.open &&          // Nến 1 đỏ dài
           c4.close < c4.open &&           // Nến 2 đỏ gap down
           c4.open < c5.close &&
           c3.close < c3.open &&           // Nến 3 đỏ (hoặc nhỏ)
           c2.close < c2.open &&           // Nến 4 đỏ nhỏ (giảm momentum)
           MathAbs(c2.close-c2.open) < MathAbs(c5.close-c5.open)*0.5 &&
           c1.close > c1.open &&           // Nến 5 xanh dài đảo chiều
           c1.close > c4.open);            // Đóng trên gap
  }

bool IsBreakawayBear(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Sell
  {
   return (c5.close > c5.open &&          // Nến 1 xanh dài
           c4.close > c4.open &&           // Nến 2 xanh gap up
           c4.open > c5.close &&
           c3.close > c3.open &&           // Nến 3 xanh (hoặc nhỏ)
           c2.close > c2.open &&           // Nến 4 xanh nhỏ
           MathAbs(c2.close-c2.open) < MathAbs(c5.close-c5.open)*0.5 &&
           c1.close < c1.open &&           // Nến 5 đỏ dài đảo chiều
           c1.close < c4.open);            // Đóng dưới gap
  }

//+------------------------------------------------------------------+
//| 11. Mat Hold (5 nến) - Continuation sau pullback                 |
//+------------------------------------------------------------------+
bool IsMatHoldBull(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Buy
  {
   // c5=nến cũ nhất, c1=nến mới nhất
   return (c5.close > c5.open &&          // Nến 1 xanh dài
           MathAbs(c5.close-c5.open) > (c5.high-c5.low)*0.5 &&
           c4.close < c4.open &&           // Nến 2 đỏ nhỏ (pullback)
           c4.low > c5.low &&              // Không phá đáy nến 1
           c3.close < c3.open &&           // Nến 3 đỏ nhỏ
           c3.low > c5.low &&
           c2.close < c2.open &&           // Nến 4 đỏ nhỏ
           c2.low > c5.low &&
           c1.close > c1.open &&           // Nến 5 xanh dài
           c1.close > c5.close);           // Đóng trên đỉnh nến 1
  }

bool IsMatHoldBear(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Sell
  {
   return (c5.close < c5.open &&          // Nến 1 đỏ dài
           MathAbs(c5.close-c5.open) > (c5.high-c5.low)*0.5 &&
           c4.close > c4.open &&           // Nến 2 xanh nhỏ (pullback)
           c4.high < c5.high &&
           c3.close > c3.open &&           // Nến 3 xanh nhỏ
           c3.high < c5.high &&
           c2.close > c2.open &&           // Nến 4 xanh nhỏ
           c2.high < c5.high &&
           c1.close < c1.open &&           // Nến 5 đỏ dài
           c1.close < c5.close);           // Đóng dưới đáy nến 1
  }

//+------------------------------------------------------------------+
//| 12. Rising Three Methods / Falling Three Methods (5 nến)         |
//+------------------------------------------------------------------+
bool IsRisingThreeMethods(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Buy
  {
   // c5=xanh dài -> c4,c3,c2=3 nến nhỏ pullback -> c1=xanh dài
   return (c5.close > c5.open &&          // Nến 1 xanh dài
           MathAbs(c5.close-c5.open) > (c5.high-c5.low)*0.5 &&
           c4.close < c4.open &&           // Nến 2 đỏ nhỏ
           c3.close < c3.open &&           // Nến 3 đỏ nhỏ
           c2.close < c2.open &&           // Nến 4 đỏ nhỏ
           c4.high < c5.high &&            // Không vượt đỉnh nến 1
           c3.high < c5.high &&
           c2.high < c5.high &&
           c2.low > c5.low &&              // Không phá đáy nến 1
           c1.close > c1.open &&           // Nến 5 xanh dài
           c1.close > c5.close);           // Đóng trên đỉnh nến 1
  }

bool IsFallingThreeMethods(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Sell
  {
   // c5=đỏ dài -> c4,c3,c2=3 nến nhỏ pullback lên -> c1=đỏ dài
   return (c5.close < c5.open &&          // Nến 1 đỏ dài
           MathAbs(c5.close-c5.open) > (c5.high-c5.low)*0.5 &&
           c4.close > c4.open &&           // Nến 2 xanh nhỏ
           c3.close > c3.open &&           // Nến 3 xanh nhỏ
           c2.close > c2.open &&           // Nến 4 xanh nhỏ
           c4.low > c5.low &&              // Không phá đáy nến 1
           c3.low > c5.low &&
           c2.low > c5.low &&
           c2.high < c5.high &&            // Không vượt đỉnh nến 1
           c1.close < c1.open &&           // Nến 5 đỏ dài
           c1.close < c5.close);           // Đóng dưới đáy nến 1
  }

//+------------------------------------------------------------------+
//| 13. Ladder Bottom / Ladder Top (5 nến)                           |
//+------------------------------------------------------------------+
bool IsLadderBottom(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Buy
  {
   // c5,c4,c3 = 3 nến đỏ giảm dần -> c2 = nến đỏ có râu trên dài -> c1 = xanh gap up
   return (c5.close < c5.open &&          // Nến 1 đỏ
           c4.close < c4.open &&           // Nến 2 đỏ
           c3.close < c3.open &&           // Nến 3 đỏ
           c4.close < c5.close &&          // Đóng cửa thấp dần
           c3.close < c4.close &&
           c2.close < c2.open &&           // Nến 4 đỏ nhưng có râu trên dài (hesitation)
           (c2.high - MathMax(c2.open,c2.close)) > MathAbs(c2.close-c2.open) &&
           c1.close > c1.open &&           // Nến 5 xanh
           c1.open > c2.open);             // Gap up hoặc mở cao hơn
  }

bool IsLadderTop(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) // Sell
  {
   // c5,c4,c3 = 3 nến xanh tăng dần -> c2 = nến xanh có râu dưới dài -> c1 = đỏ gap down
   return (c5.close > c5.open &&          // Nến 1 xanh
           c4.close > c4.open &&           // Nến 2 xanh
           c3.close > c3.open &&           // Nến 3 xanh
           c4.close > c5.close &&          // Đóng cửa cao dần
           c3.close > c4.close &&
           c2.close > c2.open &&           // Nến 4 xanh có râu dưới dài (hesitation)
           (MathMin(c2.open,c2.close) - c2.low) > MathAbs(c2.close-c2.open) &&
           c1.close < c1.open &&           // Nến 5 đỏ
           c1.open < c2.open);             // Gap down hoặc mở thấp hơn
  }


//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                |
//+------------------------------------------------------------------+

int GetDailyDirection() {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, rates) < 1) return 0;
   return (rates[0].close > rates[0].open) ? 1 : (rates[0].close < rates[0].open ? -1 : 0);
}

double GetRSI() {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handleRSI, 0, 0, 1, buf) < 1) return 50.0;
   return buf[0];
}

bool IsNewBar() {
   datetime current = iTime(_Symbol, InpTimeframe, 0);
   if(current == lastBarTime) return false;
   lastBarTime = current;
   return true;
}

void ResetDailyCounters() {
   static int lastDay = 0;
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day != lastDay) {
      lastDay = dt.day;
      dailyLosses = 0;
      martingaleLevel = 0;
      initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

bool IsCoreStable() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return false;
   return ((balance - equity) / balance * 100.0) < InpMaxDrawdownPct;
}


bool IsWithinTradingHours() {
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Weekend Filter (Friday, Saturday, Sunday)
   if(!InpTradeWeekends && (dt.day_of_week == 5 || dt.day_of_week == 6 || dt.day_of_week == 0)) return false;
   
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

bool IsNewsStorm() {
   // Placeholder logic
   return false; 
}

void ExecuteEntry(int direction) {
   double lot = CalculateLot(0);
   martingaleLevel = 0;
   string comment = StringFormat("Odin PA L%d", martingaleLevel);
   if(direction == 1) Trade.Buy(lot, _Symbol, 0, 0, 0, comment);
   else Trade.Sell(lot, _Symbol, 0, 0, 0, comment);
   Print("Odin: Ra đòn PA (Ext)! Dir=", direction, " Lot=", lot);
}

double CalculateLot(int level) { 
   double baseLot = 0.0;
   
   if(InpLotMode == LOT_MODE_PERCENT)
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (InpBaseRisk / 100.0);
      
      double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(tickVal==0 || point==0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      
      baseLot = riskAmount / (InpMartGridPips * (tickVal / tickSize) * point);
     }
   else
     {
      baseLot = InpFixedLot;
     }

   double lot = baseLot * MathPow(InpMartMultiplier, level);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(stepLot > 0) lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot) lot = minLot; 
   if(lot > maxLot) lot = maxLot;
   
   return lot;
}

void ManageMartingale() {
   if(CountMyOrders() == 0) return;
   
   double totalProfit = GetTotalFloatingProfit();
   
   // Tính mức lãi tối thiểu (chuyển từ points sang tiền)
   double minProfit = 0.0;
   if(InpMartClosePips > 0) {
      double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double totalLots = GetTotalLots();
      if(tickSize > 0 && point > 0)
         minProfit = InpMartClosePips * point * (tickVal / tickSize) * totalLots;
   }
   
   double lastPrice = GetLastEntryPrice();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int dir = GetMartingaleDirection();
   
   if(InpMartMode == MARTINGALE_MODE_SMART && martingaleLevel > 0) {
      if(totalProfit >= 0) {
         lastBreakEvenClosePrice = currentPrice;
         CloseAllOrders();
         Print("Odin: Chuỗi Martingale HÒA VỐN (Smart Mode)! P/L=", totalProfit);
         martingaleLevel = 0;
         return;
      }
   }
   
   if(totalProfit >= minProfit && martingaleLevel > 0) {
      CloseAllOrders();
      Print("Odin: Chuỗi Martingale THẮNG! P/L=", totalProfit, " (Min=", DoubleToString(minProfit,2), ")");
      martingaleLevel = 0;
      return;
   }

   if(dir == 0) return;
   
   double dist = MathAbs(currentPrice - lastPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   bool isAgainst = (dir == 1 && currentPrice < lastPrice) || (dir == -1 && currentPrice > lastPrice);
   
   if(isAgainst && dist >= InpMartGridPips) {
      martingaleLevel++;
      double lot = CalculateLot(martingaleLevel);
      
      bool res;
      string comment = StringFormat("Odin PA L%d", martingaleLevel);
      
      // Đánh cùng chiều với lệnh L0 (DCA)
      if(dir == 1) res = Trade.Buy(lot, _Symbol, 0, 0, 0, comment);
      else res = Trade.Sell(lot, _Symbol, 0, 0, 0, comment);
      
      if(res) Print("Odin: Bồi đòn DCA! Tầng=", martingaleLevel, " Lot=", lot);
   }
}

int CountMyOrders() {
   int count=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) count++;
   return count;
}

double GetTotalFloatingProfit() {
   double total=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         total += PositionGetDouble(POSITION_PROFIT);
   return total;
}

double GetTotalLots() {
   double total=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         total += PositionGetDouble(POSITION_VOLUME);
   return total;
}

double GetLastEntryPrice() {
   double p=0; datetime t=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) {
         datetime time = (datetime)PositionGetInteger(POSITION_TIME);
         if(time > t) { t=time; p=PositionGetDouble(POSITION_PRICE_OPEN); }
      }
   return p;
}

int GetMartingaleDirection() {
   datetime t=D'2099.01.01'; int d=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) {
         datetime time = (datetime)PositionGetInteger(POSITION_TIME);
         if(time < t) { t=time; d=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1; }
      }
   return d;
}

void CloseAllOrders() {
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
}

void ManageIntradayExit() {
   MqlDateTime dt; TimeCurrent(dt);
   if(dt.hour >= InpCloseHour) {
      // Logic cũ: Chỉ đóng khi lời
      // Logic mới: Nếu Force Close thì đóng hết
      
      double p = GetTotalFloatingProfit();
      
      if(InpForceCloseAtEOD)
        {
         CloseAllOrders();
         martingaleLevel = 0;
         Print("Odin: Force Close cuối ngày. P/L=", p);
        }
      else
        {
         if(p > 0) { // Chỉ đóng khi LỜI
            CloseAllOrders();
            martingaleLevel = 0;
            Print("Odin: Đóng cuối ngày (TP). P/L=", p);
         }
        }
   }
}

//+------------------------------------------------------------------+
//| DRAWDOWN PROTECTION: Cắt lỗ khẩn cấp                            |
//+------------------------------------------------------------------+
void ManageDrawdownProtection() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return;
   
   double ddPct = (balance - equity) / balance * 100.0;
   
   // Nếu Drawdown vượt quá giới hạn cho phép
   if(ddPct >= InpMaxDrawdownPct) {
      if(CountMyOrders() > 0) {
         CloseAllOrders();
         martingaleLevel = 0;
         Print("Odin: EMERGENCY STOP! Drawdown Limit Reached (", DoubleToString(ddPct, 2), "%). Closing ALL.");
      }
   }
}

//+------------------------------------------------------------------+
//| TRADE EVENT: Đếm lệnh thua                                      |
//+------------------------------------------------------------------+
void OnTrade() {
   if(HistorySelect(0, TimeCurrent())) {
      int total = HistoryDealsTotal();
      if(total > 0) {
         ulong ticket = HistoryDealGetTicket(total-1);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC)==InpMagic && 
            HistoryDealGetInteger(ticket, DEAL_ENTRY)==DEAL_ENTRY_OUT) {
             
             double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
             if(profit < 0) {
                 dailyLosses++;
                 Print("Odin: Thua lệnh. Daily Loss Counter = ", dailyLosses);
             }
         }
      }
   }
}
