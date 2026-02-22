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
   MARTINGALE_MODE_SMART,  // Smart (Đóng hòa vốn ngay khi về 0)
   MARTINGALE_MODE_NONE    // Không Martingale (Chỉ đánh 1 lệnh, dùng SL/TP)
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
input int    InpTakeProfitPips = 100;     // Chốt lời lệnh đầu tiên (points)
input int    InpStopLossPips   = 100;     // Cắt lỗ lệnh đầu tiên (points) - Khi không DCA
input int    InpRSIPeriod      = 14;      // RSI Period

input group "=== MARTINGALE DCA ==="
input ENUM_MARTINGALE_MODE InpMartMode = MARTINGALE_MODE_SMART; // Chế độ Smart hay Normal
input double InpMartMultiplier = 2.0;     // Hệ số nhân Martingale
input int    InpMartGridPips   = 300;     // Khoảng cách giữa các tầng (points)
input int    InpMartClosePips  = 50;      // Lãi tối thiểu để đóng normal hedge (points)
input int    InpSmartThresholdPips = 50;  // Ngưỡng an toàn sau khi đóng hòa vốn (points)


input group "=== INTRADAY & TIN TỨC ==="
input bool   InpEnableTimeManagement = true; // Bật tắt quản lý thời gian (Trade Intraday)
input int    InpStartHour      = 8;       // Giờ bắt đầu giao chiến
input int    InpEndHour        = 22;      // Giờ ngừng mở lệnh mới
input int    InpCloseHour      = 23;      // Giờ đóng lệnh
input bool   InpForceCloseAtEOD = false;  // Đóng hết lệnh cuối ngày (Bất kể Lời/Lỗ)
input bool   InpTradeWeekends  = false;   // Giao dịch cuối tuần (T6, T7, CN)
input int    InpNewsBufferMins = 60;      // Né bão tin tức (phút trước/sau)

input group "=== ENDURANCE (Sức bền) ==="
input int    InpMaxLossesPerDay = 5;       // Số lần thua tối đa/ngày -> Ngất xỉu

input group "=== GIAO DIỆN (UI) ==="
input bool   InpShowDashboard   = true;    // Hiển thị bảng điều khiển
input bool   InpShowIchimoku    = true;    // Hiển thị Ichimoku Indicator
input bool   InpShowForecast    = true;    // Hiển thị Dự báo chu kỳ thời gian (Kihon Suchi)

input int    InpMagic           = 202611;  // Magic Number (Ichimoku)

//+------------------------------------------------------------------+
//| BIẾN TOÀN CỤC                                                   |
//+------------------------------------------------------------------+
CTrade         Trade;
int            handleRSI;
int            handleIchi;        // Handle cho Ichimoku
int            dailyLosses;       // Đếm số lần thua trong ngày
datetime       lastBarTime;       // Kiểm soát chỉ trade 1 lần/nến
int            martingaleLevel;   // Tầng Martingale hiện tại
double         initialBalance;    // Vốn ban đầu

string         lastPatternDetected = "None"; // Lưu mô hình nến gần nhất
int            barsFromHigh = 0;             // Lưu số nến từ đỉnh gần nhất
int            barsFromLow = 0;              // Lưu số nến từ đáy gần nhất

// Global variables for Smart Hedge
double         lastBreakEvenClosePrice = 0.0; // Giá đóng hòa vốn gần nhất

// Forward declarations for Sakata Bottom Models
bool IsAkaSanpei(MqlRates &c1, MqlRates &c2, MqlRates &c3);
bool IsSashikomisen(MqlRates &c1, MqlRates &c2);
bool IsHanareGoteZoko(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5);
bool IsHanareShichiteZoko(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5, MqlRates &c6, MqlRates &c7);
bool IsKaiDakisen(MqlRates &c1, MqlRates &c2);
bool IsSaigoDakisenBuy(MqlRates &c1, MqlRates &c2);
bool IsInInHarami(MqlRates &c1, MqlRates &c2);
bool IsKaiYoInHarami(MqlRates &c1, MqlRates &c2);

// Forward declarations for Sakata Top Models
bool IsSanbaGarasu(MqlRates &c1, MqlRates &c2, MqlRates &c3);
bool IsSanteHanareYoseSen(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4);
bool IsKabuse(MqlRates &c1, MqlRates &c2);
bool IsSutegoSen(MqlRates &c1, MqlRates &c2, MqlRates &c3);
bool IsJouiDakisen(MqlRates &c1, MqlRates &c2);
bool IsSaigoDakisenSell(MqlRates &c1, MqlRates &c2);
bool IsYoYoHarami(MqlRates &c1, MqlRates &c2);
bool IsJouiYoInHarami(MqlRates &c1, MqlRates &c2);

// Forward declarations for other Helpers
int GetDailyDirection();
double GetRSI();
bool IsNewBar();
void ResetDailyCounters();
bool IsCoreStable();
bool IsWithinTradingHours();
bool IsNewsStorm();
void ExecuteEntry(int direction);
double CalculateLot(int level);
void ManageMartingale();
int CountMyOrders();
double GetTotalFloatingProfit();
double GetTotalLots();
double GetLastEntryPrice();
int GetMartingaleDirection();
void CloseAllOrders();
void ManageIntradayExit();
void ManageDrawdownProtection();


//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   Trade.SetExpertMagicNumber(InpMagic);
   
   handleRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   handleIchi = iIchimoku(_Symbol, InpTimeframe, 9, 26, 52); // Mặc định 9-26-52
   
   if(handleRSI == INVALID_HANDLE || handleIchi == INVALID_HANDLE)
     {
      Print("Chronos: Lỗi khởi tạo Indicators.");
      return INIT_FAILED;
     }
     
   if(InpShowIchimoku) {
      ChartIndicatorAdd(0, 0, handleIchi);
   }
   
   dailyLosses     = 0;
   lastBarTime      = 0;
   martingaleLevel  = 0;
   initialBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(InpShowDashboard) DrawDashboard();
   if(InpShowForecast) DrawKihonSuchiForecasts();
   
   Print("Chronos: Hệ thống Price Action Mở Rộng sẵn sàng (16 Models).");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleIchi);
   if(InpShowDashboard) RemoveDashboard();
   if(InpShowForecast) RemoveForecasts();
   Print("Chronos: Rời vòng tròn. Reason: ", reason);
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
      
   // Cập nhật lại UI sau mỗi tick
   if(InpShowDashboard) DrawDashboard();
   if(IsNewBar() && InpShowForecast) DrawKihonSuchiForecasts();
  }

//+------------------------------------------------------------------+
//| SIGNAL: RSI + D1 + Ichimoku Time + 13 PA Models                 |
//+------------------------------------------------------------------+
bool IsIchimokuCycle(int bars) {
   int ichiNumbers[] = {9, 17, 26, 33, 42, 51, 65, 76, 83, 97, 101, 129, 172, 200, 257};
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
   
   barsFromHigh = highestIdx;
   barsFromLow = lowestIdx;
   
   bool isCycleFromHigh = IsIchimokuCycle(highestIdx); // Đang ở chu kỳ tính từ đỉnh (Kỳ vọng tạo đáy/đảo chiều lên)
   bool isCycleFromLow = IsIchimokuCycle(lowestIdx);   // Đang ở chu kỳ tính từ đáy (Kỳ vọng tạo đỉnh/đảo chiều xuống)
   
   if(!isCycleFromHigh && !isCycleFromLow) return 0; // Chưa tới điểm rơi thời gian
   
   // 4. Price Action Check (Cần 7 nến cho mẫu hình Sakata)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 1, 7, rates) < 7) return 0;
   
   // Kiểm tra 16 mẫu hình Sakata
   bool isBuy = false;
   bool isSell = false;
   
   // --- KÍCH HOẠT BUY (8 Mẫu Tạo Đáy) ---
   if(IsAkaSanpei(rates[0], rates[1], rates[2])) { isBuy = true; lastPatternDetected = "Aka Sanpei (Đáy)"; }
   if(IsSashikomisen(rates[0], rates[1])) { isBuy = true; lastPatternDetected = "Sashikomisen (Đáy)"; }
   if(IsHanareGoteZoko(rates[0], rates[1], rates[2], rates[3], rates[4])) { isBuy = true; lastPatternDetected = "Hanare Gote Zoko (Đáy)"; }
   if(IsHanareShichiteZoko(rates[0], rates[1], rates[2], rates[3], rates[4], rates[5], rates[6])) { isBuy = true; lastPatternDetected = "Hanare Shichite Zoko (Đáy)"; }
   if(IsKaiDakisen(rates[0], rates[1])) { isBuy = true; lastPatternDetected = "Kai Dakisen (Đáy)"; }
   if(IsSaigoDakisenBuy(rates[0], rates[1])) { isBuy = true; lastPatternDetected = "Saigo Dakisen (Đáy)"; }
   if(IsInInHarami(rates[0], rates[1])) { isBuy = true; lastPatternDetected = "In In Harami (Đáy)"; }
   if(IsKaiYoInHarami(rates[0], rates[1])) { isBuy = true; lastPatternDetected = "Kai Yo In Harami (Đáy)"; }
   
   // --- KÍCH HOẠT SELL (8 Mẫu Tạo Đỉnh) ---
   if(IsSanbaGarasu(rates[0], rates[1], rates[2])) { isSell = true; lastPatternDetected = "Sanba Garasu (Đỉnh)"; }
   if(IsSanteHanareYoseSen(rates[0], rates[1], rates[2], rates[3])) { isSell = true; lastPatternDetected = "Sante Hanare (Đỉnh)"; }
   if(IsKabuse(rates[0], rates[1])) { isSell = true; lastPatternDetected = "Kabuse (Đỉnh)"; }
   if(IsSutegoSen(rates[0], rates[1], rates[2])) { isSell = true; lastPatternDetected = "Sutego Sen (Đỉnh)"; }
   if(IsJouiDakisen(rates[0], rates[1])) { isSell = true; lastPatternDetected = "Joui Dakisen (Đỉnh)"; }
   if(IsSaigoDakisenSell(rates[0], rates[1])) { isSell = true; lastPatternDetected = "Saigo Dakisen (Đỉnh)"; }
   if(IsYoYoHarami(rates[0], rates[1])) { isSell = true; lastPatternDetected = "Yo Yo Harami (Đỉnh)"; }
   if(IsJouiYoInHarami(rates[0], rates[1])) { isSell = true; lastPatternDetected = "Joui Yo In Harami (Đỉnh)"; }
   
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
//| SAKATA BOTTOM MODELS (BUY)                                       |
//+------------------------------------------------------------------+
bool IsAkaSanpei(MqlRates &c1, MqlRates &c2, MqlRates &c3) { // 3 Chàng lính trắng
   return (c3.close > c3.open && c2.close > c2.open && c1.close > c1.open &&
           c1.close > c2.close && c2.close > c3.close &&
           c1.high > c2.high && c2.high > c3.high);
}

bool IsSashikomisen(MqlRates &c1, MqlRates &c2) { // Hai đường đâm xuyên
   return (c2.close < c2.open && 
           c1.close > c1.open && 
           c1.open < c2.low &&
           c1.close > (c2.open + c2.close)/2 && c1.close < c2.open); 
}

bool IsHanareGoteZoko(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5) { // Breakaway 5 nến đáy
   return (c5.close < c5.open &&
           c4.close < c4.open && c4.open < c5.close &&
           c3.close <= c3.open && c2.close <= c2.open &&
           c1.close > c1.open && c1.close > c4.open);
}

bool IsHanareShichiteZoko(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4, MqlRates &c5, MqlRates &c6, MqlRates &c7) { // Breakaway 7 nến đáy
   return (c7.close < c7.open &&
           c6.close < c6.open && c6.open < c7.close &&
           c5.high < c7.open && c4.high < c7.open && c3.high < c7.open && c2.high < c7.open &&
           MathAbs(c2.close-c2.open) < (c7.open-c7.close)*0.5 &&
           c1.close > c1.open && c1.close > c6.open);
}

bool IsKaiDakisen(MqlRates &c1, MqlRates &c2) { // Nhấn chìm tăng
   return (c2.close < c2.open && c1.close > c1.open && c1.close > c2.open && c1.open < c2.close);
}

bool IsSaigoDakisenBuy(MqlRates &c1, MqlRates &c2) { // Nhấn chìm tăng cuối cùng đáy
   return (c2.close < c2.open && c1.close > c1.open && 
           c1.close > c2.high && c1.open < c2.low);
}

bool IsInInHarami(MqlRates &c1, MqlRates &c2) { // Đen bồng Đen
   return (c2.close < c2.open && c1.close < c1.open && 
           c1.open < c2.open && c1.close > c2.close && 
           MathAbs(c1.open-c1.close) < MathAbs(c2.open-c2.close)*0.3);
}

bool IsKaiYoInHarami(MqlRates &c1, MqlRates &c2) { // Đen bồng Trắng
   return (c2.close < c2.open && c1.close > c1.open &&
           c1.close < c2.open && c1.open > c2.close &&
           MathAbs(c1.close-c1.open) < MathAbs(c2.open-c2.close)*0.3);
}

//+------------------------------------------------------------------+
//| SAKATA TOP MODELS (SELL)                                         |
//+------------------------------------------------------------------+
bool IsSanbaGarasu(MqlRates &c1, MqlRates &c2, MqlRates &c3) { // 3 Con quạ đen
   return (c3.close < c3.open && c2.close < c2.open && c1.close < c1.open &&
           c1.close < c2.close && c2.close < c3.close &&
           c1.low < c2.low && c2.low < c3.low);
}

bool IsSanteHanareYoseSen(MqlRates &c1, MqlRates &c2, MqlRates &c3, MqlRates &c4) { // Quạ xa tổ (4 nến đỉnh)
   return (c4.close > c4.open && 
           c3.close > c3.open && c2.close > c2.open && 
           c2.high < c4.high + (c4.high-c4.low) && // mấp mé trên đỉnh
           c1.close < c1.open && c1.close < c3.low);
}

bool IsKabuse(MqlRates &c1, MqlRates &c2) { // Mây đen bao phủ
   return (c2.close > c2.open && 
           c1.close < c1.open && 
           c1.open > c2.high &&
           c1.close < (c2.open + c2.close)/2 && c1.close > c2.open);
}

bool IsSutegoSen(MqlRates &c1, MqlRates &c2, MqlRates &c3) { // Đứa trẻ bị bỏ rơi ở đỉnh
   double c2Body = MathAbs(c2.open - c2.close);
   return (c3.close > c3.open && 
           c2Body < (c2.high - c2.low)*0.1 && c2.low > c3.high &&
           c1.close < c1.open && c1.high < c2.low);
}

bool IsJouiDakisen(MqlRates &c1, MqlRates &c2) { // Nhấn chìm giảm
   return (c2.close > c2.open && c1.close < c1.open && c1.open > c2.close && c1.close < c2.open);
}

bool IsSaigoDakisenSell(MqlRates &c1, MqlRates &c2) { // Nhấn chìm giảm cuối cùng đỉnh
   return (c2.close > c2.open && c1.close < c1.open && 
           c1.open > c2.high && c1.close < c2.low);
}

bool IsYoYoHarami(MqlRates &c1, MqlRates &c2) { // Trắng bồng Trắng
   return (c2.close > c2.open && c1.close > c1.open && 
           c1.open > c2.open && c1.close < c2.close && 
           MathAbs(c1.close-c1.open) < MathAbs(c2.close-c2.open)*0.3);
}

bool IsJouiYoInHarami(MqlRates &c1, MqlRates &c2) { // Trắng bồng Đen
   return (c2.close > c2.open && c1.close < c1.open &&
           c1.open < c2.close && c1.close > c2.open &&
           MathAbs(c1.open-c1.close) < MathAbs(c2.close-c2.open)*0.3);
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
   if(!InpEnableTimeManagement) return true; // Cày 24/7 nếu tắt Time Management
   
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
   string comment = StringFormat("Chronos PA L%d", martingaleLevel);
   if(direction == 1) Trade.Buy(lot, _Symbol, 0, 0, 0, comment);
   else Trade.Sell(lot, _Symbol, 0, 0, 0, comment);
   Print("Chronos: Ra đòn PA (Ext)! Dir=", direction, " Lot=", lot);
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
   
   // Tính Break-even Price trung bình của cụm lệnh hiện tại
   double totalLots = GetTotalLots();
   double minProfit = 0.0;
   if(InpMartClosePips > 0 && totalLots > 0) {
      double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
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
         Print("Chronos: Chuỗi Martingale HÒA VỐN (Smart Mode)! P/L=", totalProfit);
         martingaleLevel = 0;
         return;
      }
   }
   
   if(totalProfit >= minProfit && martingaleLevel > 0) {
      CloseAllOrders();
      Print("Chronos: Chuỗi Martingale THẮNG! P/L=", totalProfit, " (Target P/L=", minProfit, ")");
      martingaleLevel = 0;
      return;
   }

   if(dir == 0) return;
   
   // Take profit cho lệnh đầu tiên
   if(martingaleLevel == 0 && InpTakeProfitPips > 0) {
      double distTP = (dir == 1) ? (currentPrice - lastPrice) : (lastPrice - currentPrice);
      distTP = distTP / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(distTP >= InpTakeProfitPips) {
         CloseAllOrders();
         Print("Chronos: TAKE PROFIT lệnh đầu! P/L=", totalProfit);
         return;
      }
   }
   
   // Stop loss cho lệnh đầu tiên (Chỉ dùng khi trade 1 lệnh KHÔNG DCA)
   if(InpMartMode == MARTINGALE_MODE_NONE && martingaleLevel == 0 && InpStopLossPips > 0) {
      double distSL = (dir == 1) ? (lastPrice - currentPrice) : (currentPrice - lastPrice);
      distSL = distSL / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(distSL >= InpStopLossPips) {
         CloseAllOrders();
         Print("Chronos: STOP LOSS lệnh đầu! P/L=", totalProfit);
         return;
      }
   }
   
   double dist = MathAbs(currentPrice - lastPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   bool isAgainst = (dir == 1 && currentPrice < lastPrice) || (dir == -1 && currentPrice > lastPrice);
   
   if(isAgainst && dist >= InpMartGridPips) {
      if(InpMartMode == MARTINGALE_MODE_NONE) return; // Nếu chọn chế độ Không DCA thì ngồi chờ SL/TP
      
      martingaleLevel++;
      double lot = CalculateLot(martingaleLevel);
      
      bool res;
      string comment = StringFormat("Chronos PA L%d", martingaleLevel);
      
      // Đánh cùng chiều với lệnh L0 (DCA)
      if(dir == 1) res = Trade.Buy(lot, _Symbol, 0, 0, 0, comment);
      else res = Trade.Sell(lot, _Symbol, 0, 0, 0, comment);
      
      if(res) Print("Chronos: Bồi đòn DCA! Tầng=", martingaleLevel, " Lot=", lot);
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
   if(!InpEnableTimeManagement) return; // Bỏ qua nếu tắt Time Management
   
   MqlDateTime dt; TimeCurrent(dt);
   if(dt.hour >= InpCloseHour) {
      // Logic cũ: Chỉ đóng khi lời
      // Logic mới: Nếu Force Close thì đóng hết
      
      double p = GetTotalFloatingProfit();
      
      if(InpForceCloseAtEOD)
        {
         CloseAllOrders();
         martingaleLevel = 0;
         Print("Chronos: Force Close cuối ngày. P/L=", p);
        }
      else
        {
         if(p > 0) { // Chỉ đóng khi LỜI
            CloseAllOrders();
            martingaleLevel = 0;
            Print("Chronos: Đóng cuối ngày (TP). P/L=", p);
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
         Print("Chronos: EMERGENCY STOP! Drawdown Limit Reached (", DoubleToString(ddPct, 2), "%). Closing ALL.");
      }
   }
}

//+------------------------------------------------------------------+
//| GIAO DIỆN HIỂN THỊ (DASHBOARD)                                   |
//+------------------------------------------------------------------+
void AddCustomLabel(string name, string text, int x, int y, color clr, int fontSize = 10, string fontName = "Arial") {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
}

void DrawDashboard() {
   int xStart = 20;
   int yStart = 20;
   int yStep = 25; // Tăng khoảng cách giữa các dòng
   int row = 0;
   
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (bal > 0) ? ((bal - eq) / bal * 100.0) : 0;
   
   // Header
   AddCustomLabel("chronos_title", "CHRONOS BOT - TỬ CHIẾN (Sakata + Kihon Suchi)", xStart, yStart + row*yStep, clrGold, 12, "Arial Bold");
   row++;
   AddCustomLabel("chronos_separator", "--------------------------------------------------------", xStart, yStart + row*yStep, clrGray);
   row++;
   
   // Account Stats
   string accText = StringFormat("Balance: $%.2f | Equity: $%.2f", bal, eq);
   AddCustomLabel("chronos_acc", accText, xStart, yStart + row*yStep, clrWhite);
   row++;
   
   string ddText = StringFormat("Current Drawdown: %.2f%% (Max Limit: %.2f%%)", dd, InpMaxDrawdownPct);
   color ddClr = (dd > InpMaxDrawdownPct * 0.8) ? clrRed : clrLightGreen;
   AddCustomLabel("chronos_dd", ddText, xStart, yStart + row*yStep, ddClr);
   row++;
   
   // Operations Stats
   string martText = StringFormat("Trade State: %d Orders | Martingale Level: L%d", CountMyOrders(), martingaleLevel);
   AddCustomLabel("chronos_mart", martText, xStart, yStart + row*yStep, clrTurquoise);
   row++;
   
   double pl = GetTotalFloatingProfit();
   string plText = StringFormat("Floating P/L: $%.2f", pl);
   color plClr = (pl >= 0) ? clrLightGreen : clrRed;
   AddCustomLabel("chronos_pl", plText, xStart, yStart + row*yStep, plClr);
   row++;
   
   string lossText = StringFormat("Daily Losses: %d / %d", dailyLosses, InpMaxLossesPerDay);
   AddCustomLabel("chronos_loss", lossText, xStart, yStart + row*yStep, clrOrange);
   row++;
   
   // Analytics
   AddCustomLabel("chronos_separator2", "--------------------------------------------------------", xStart, yStart + row*yStep, clrGray);
   row++;
   
   string ptnText = "Last PA Pattern: " + lastPatternDetected;
   AddCustomLabel("chronos_pattern", ptnText, xStart, yStart + row*yStep, clrYellow);
   row++;
   
   string ichiText = StringFormat("Kihon Suchi: %d bars from High | %d bars from Low", barsFromHigh, barsFromLow);
   AddCustomLabel("chronos_ichi", ichiText, xStart, yStart + row*yStep, clrLightBlue);
   
   ChartRedraw();
}

void RemoveDashboard() {
   ObjectsDeleteAll(0, "chronos_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| VẼ DỰ BÁO TƯƠNG LAI KIHON SUCHI Y GIAO DIỆN                      |
//+------------------------------------------------------------------+
void DrawKihonSuchiForecasts() {
   RemoveForecasts(); // Xóa cũ trước khi vẽ mới
   
   int highestIdx = iHighest(_Symbol, InpTimeframe, MODE_HIGH, InpScanBars, 1);
   int lowestIdx = iLowest(_Symbol, InpTimeframe, MODE_LOW, InpScanBars, 1);
   
   if(highestIdx < 0 || lowestIdx < 0) return;
   
   // Chọn đỉnh hoặc đáy gần nhất làm tâm điểm
   int originIdx = (highestIdx < lowestIdx) ? highestIdx : lowestIdx;
   datetime originTime = iTime(_Symbol, InpTimeframe, originIdx);
   bool isHigh = (originIdx == highestIdx);
   
   int ichiNumbers[] = {9, 17, 26, 33, 42, 51, 65, 76, 83, 97, 101, 129, 172, 200, 257};
   
   for(int i = 0; i < ArraySize(ichiNumbers); i++) {
      int targetBars = ichiNumbers[i];
      int barsElapsed = originIdx; 
      
      // Nếu chu kỳ tương lai chưa tới (Số nến cần > Số nến đã chạy)
      if(targetBars > barsElapsed) {
         int futureBars = targetBars - barsElapsed;
         datetime futureTime = originTime + futureBars * PeriodSeconds(InpTimeframe); // Ước tính thời gian
         
         string objName = "chronos_fc_" + IntegerToString(targetBars);
         ObjectCreate(0, objName, OBJ_VLINE, 0, futureTime, 0);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, (isHigh) ? clrDodgerBlue : clrHotPink);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); // Chìm ra sau nến
         ObjectSetString(0, objName, OBJPROP_TEXT, "Cycle " + IntegerToString(targetBars));
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, "\n"); // Disable tooltip for clean look
         
         // Thêm nhãn chữ (Text) bên trên Line
         string labelName = "chronos_lbl_" + IntegerToString(targetBars);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, futureTime, 0); // 0 price for now, we will position it
         
         // Đẩy chữ lên cạnh trên của chart
         double maxPrice = ChartGetDouble(0, CHART_PRICE_MAX);
         ObjectMove(0, labelName, 0, futureTime, maxPrice); 
         ObjectSetString(0, labelName, OBJPROP_TEXT, IntegerToString(targetBars));
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, (isHigh) ? clrDodgerBlue : clrHotPink);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
      }
   }
   ChartRedraw();
}

void RemoveForecasts() {
   ObjectsDeleteAll(0, "chronos_fc_");
   ObjectsDeleteAll(0, "chronos_lbl_");
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
                 Print("Chronos: Thua lệnh. Daily Loss Counter = ", dailyLosses);
             }
         }
      }
   }
}