//+------------------------------------------------------------------+
//|                                                   phoenix.mq5    |
//|               Phoenix V3 - Ichimoku Trend DCA Bot                |
//|                     Copyright 2026, DaiViet                      |
//|                                                                  |
//| Chiến lược: DCA tại các mức Ichimoku (Tenkan/Kijun/Kumo)        |
//| Entry: Sanyaku Kouten/Gyakuten (Ch.3)                            |
//| DCA: Pullback tới các mức Han-ne (Ch.4-6, 10-12)                |
//| Exit: Basket TP - Chốt sạch khi tổng lãi >= Target              |
//| Không SL, không Grid, không Hedge. DCA thuần túy.                |
//| Triết lý: "Luôn tuyến tính dương" - mỗi chu kỳ đều profit.     |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, DaiViet"
#property version     "3.00"
#property strict
#property description "Ichimoku Trend DCA - Based on 15 Chapters of Hosoda Theory"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| SECTION 1: ENUMERATIONS                                          |
//+------------------------------------------------------------------+
// Trạng thái thị trường theo Ichimoku (Ch.13)
enum ENUM_ICHI_STATE {
   ICHI_STRONG_UP    = 2,    // Xu hướng tăng mạnh (Giá > TK > KJ > Kumo)
   ICHI_WEAK_UP      = 1,    // Xu hướng tăng yếu
   ICHI_RANGE        = 0,    // Đi ngang / Tích lũy (Ch.8-9: fake cross)
   ICHI_WEAK_DOWN    = -1,   // Xu hướng giảm yếu
   ICHI_STRONG_DOWN  = -2    // Xu hướng giảm mạnh
};

// Mức DCA dựa trên Ichimoku (Ch.5, 6, 12)
enum ENUM_DCA_LEVEL {
   DCA_NONE      = 0,   // Chưa DCA
   DCA_TENKAN    = 1,   // Pullback tới Tenkan (Ch.5: bệ đỡ đầu tiên)
   DCA_KIJUN     = 2,   // Pullback tới Kijun (Ch.6: cân bằng trung hạn)
   DCA_KUMO      = 3,   // Pullback vào Kumo (Ch.12: vùng cản mạnh)
   DCA_KUMO_DEEP = 4    // Pullback tới Senkou Span 2 (Ch.10: phòng tuyến cuối)
};

enum ENUM_MTF_MODE {
   MTF_SINGLE = 0,   // 1 khung thời gian (nhanh nhất)
   MTF_TRIPLE = 1    // 3 khung (M5+M15+H1, chuẩn)
};

enum ENUM_EXEC_SPEED {
   EXEC_BAR_CLOSE = 0,   // Chờ đóng nến (an toàn, tránh fake)
   EXEC_EVERY_TICK = 1   // Mỗi tick (nhanh, rủi ro nhiễu)
};

//+------------------------------------------------------------------+
//| SECTION 2: INPUT PARAMETERS                                      |
//+------------------------------------------------------------------+
input group "========= CORE ========="
input ENUM_EXEC_SPEED InpExecSpeed     = EXEC_BAR_CLOSE;
input ENUM_MTF_MODE   InpMTFMode       = MTF_TRIPLE;
input ENUM_TIMEFRAMES InpBaseTF        = PERIOD_M5;
input ENUM_TIMEFRAMES InpMidTF         = PERIOD_M15;
input ENUM_TIMEFRAMES InpHighTF        = PERIOD_H1;
input int             InpMagicNumber   = 888999;

input group "========= ICHIMOKU (Ch.1-6) ========="
input int    InpTenkanPeriod     = 9;       // Tenkan Period (Ch.5)
input int    InpKijunPeriod      = 26;      // Kijun Period (Ch.6)
input int    InpSenkouPeriod     = 52;      // Senkou Period (Ch.10)
input int    InpKijunFlatBars    = 5;       // Số nến Kijun phẳng = Range (Ch.8)
input double InpMinKumoThick    = 10.0;    // Bề dày Kumo tối thiểu để xác nhận (Ch.12)

input group "========= DCA STRATEGY ========="
input double InpEntryLot         = 0.01;    // Lot cố định cho lệnh Entry
input string InpDCATPs           = "10,15,20,30";          // TP pips mỗi tầng DCA
input double InpDCARiskPct       = 2.0;     // Max % equity cho mỗi DCA
input int    InpDCACooldownBars  = 3;       // Chờ tối thiểu N nến giữa các DCA
input double InpMinDCAGap        = 5.0;     // Khoảng cách tối thiểu  DCA (pips)

input group "========= PYRAMID DCA (Thuận Trend) ========="
input bool   InpEnablePyramid    = true;    // Bật Pyramid DCA dương
input double InpMinPyramidGap    = 5.0;     // Khoảng cách tối thiểu giữa các lệnh Pyramid
input bool   InpPyramidTrailingKijun = true; // Trailing SL theo Kijun

input group "========= HÒA VỐN (Breakeven) ========="
input bool   InpEnableBE         = true;    // Bật chế độ hòa vốn
input int    InpBEAfterDCA       = 2;       // Kích hoạt hòa vốn sau DCA level X
input double InpBEPips           = 5.0;     // Mức lợi nhuận (pips) để đóng hòa vốn

input group "========= TỈA LỆNH & HEDGE ========="
input bool   InpEnableTrim       = true;    // Bật tỉa lệnh Z-Score
input bool   InpEnableHedgeMode  = true;    // Bật Hedge đảo chiều (Sanyaku)
input bool   InpHedgeWaitKumoBreak = true;  // Hedge chờ giá thoát mây HighTF
input bool   InpEnableTrimTotalBE= true;    // Tính Lot tỉa để Gồng Hòa Vốn Tổng
input bool   InpHedgeMergeVolume = false;   // Gộp số lượng lệnh Hedge và Chính lấy mốc Tỉa
input int    InpTrimAfterDCA     = 2;       // Tỉa sau DCA level X
input string InpTrimDCATPs       = "15,20,30,40";           // TP pips rổ tỉa
input int    InpTrimZPeriod      = 50;      // Chu kỳ Z-Score
input double InpTrimZThreshold   = 2.0;     // Mức Z-Score kích hoạt tỉa
input int    InpTrimBEAfterDCA   = 2;       // Kích hòa vốn tỉa sau DCA level X
input double InpTrimBEPips       = 5.0;     // Mức hòa vốn (pips) rổ tỉa

input group "========= GỘP TP (Merged TP) ========="
input bool   InpEnableMergedTP   = true;    // Bật gộp TP rổ chính
input int    InpMergedTPLevel    = 3;       // Lấy TP của DCA level này để đóng hết
input bool   InpEnableTrimMTP    = true;    // Bật gộp TP rổ tỉa
input int    InpTrimMTPLevel     = 2;       // Lấy TP của tỉa level này để đóng rổ tỉa

input group "========= ADVANCED EXIT ========="
input bool   InpCloseOnHighTFReversal = true; // Đóng toàn bộ lệnh khi khung lớn (HighTF) đảo chiều

input group "========= PROPFIRM COMPLIANCE ========="
input bool   InpPropFirmMode     = false;   // Bật chế độ PropFirm (set SL giả)
input double InpFakeSLPips       = 500.0;   // SL giả (pips) - đặt xa không để chạm
input double InpDailyLossPct     = 5.0;     // Giới hạn lỗ tối đa trong ngày (%)
input double InpMaxDrawdownPct   = 10.0;    // Giới hạn Drawdown tối đa (%)

input group "========= SESSION & TIME ========="
input bool   InpUseTimeFilter    = true;
input string InpTokyo            = "00:00-09:00";
input string InpLondon           = "07:00-16:00";
input string InpNewYork          = "13:00-22:00";
input bool   InpCloseOnFriday    = true;
input int    InpFridayCloseHour  = 22;
input bool   InpUseNewsFilter    = false;  // Lọc tin tức (không vào L0 khi có tin)
input int    InpNewsMinutes      = 30;     // Phút tránh tin trước/sau

input group "========= RSI FILTER ========="
input bool   InpEnableRSIFilter  = true;    // Bật lọc RSI (chỉ lọc L0 entry)
input bool   InpFilterHighKumo   = true;    // Bật lọc mây khung lớn nhất cho lệnh đầu
input ENUM_TIMEFRAMES InpRSITimeframe = PERIOD_M15; // Khung thời gian RSI
input int    InpRSIPeriod        = 14;      // Chu kỳ RSI
input double InpRSIOverbought    = 70.0;    // Vùng quá mua (Cấm BUY L0)
input double InpRSIOversold      = 30.0;    // Vùng quá bán (Cấm SELL L0)

input group "========= GUI ========="
input bool   InpShowGUI          = true;
input color  InpGUIBG            = C'15,20,30';
input color  InpGUIText          = C'200,200,200';

input int    InpMaxSpread        = 50;      // Spread tối đa (points)

//+------------------------------------------------------------------+
//| SECTION 3: GLOBAL OBJECTS & STATE                                |
//+------------------------------------------------------------------+
CTrade      m_trade;
CSymbolInfo m_symbol;
int         m_rsiHandle = INVALID_HANDLE;

// Trạng thái DCA
int      g_direction     = 0;      // 1=BUY, -1=SELL, 0=chờ tín hiệu
int      g_dcaLevel      = 0;      // Tầng DCA hiện tại (0=entry, 1-N=DCA)
datetime g_lastDCATime   = 0;      // Thời gian DCA gần nhất
datetime g_lastPyramidTime = 0;    // Thời gian Pyramid DCA gần nhất
int      g_cycleWins     = 0;      // Số chu kỳ thắng
double   g_cycleProfit   = 0;      // Tổng profit tích lũy

// Parsed DCA arrays
double   g_dcaTP[];                // TP pips mỗi tầng rổ chính
double   g_trimDcaTP[];            // TP pips mỗi tầng rổ tỉa

// Trim tracking
bool     g_trimActive    = false;  // Có rổ tỉa đang hoạt động
int      g_trimDirection = 0;      // Hướng của rổ tỉa (1=BUY, -1=SELL)
int      g_trimDcaLevel  = 0;      // Tầng DCA của rổ tỉa
datetime g_lastTrimTime  = 0;      // Thời gian DCA của rổ tỉa

// PropFirm tracking
double   g_dayStartBalance = 0;
int      g_lastDay = 0;
double   g_initialBalance = 0;
bool     g_propFirmLocked = false; // Khóa giao dịch khi vượt giới hạn

// Ichimoku state
ENUM_ICHI_STATE g_ichiState = ICHI_RANGE;
double   g_point    = 0;
double   g_p2p      = 1;           // Point to Pip multiplier
datetime g_lastBar  = 0;

// Matrix scoring (dùng để confirm tín hiệu)
int g_scoreBuy  = 0;
int g_scoreSell = 0;
int g_scoreNet  = 0;

//+------------------------------------------------------------------+
//| SECTION 4: ICHIMOKU MTF DATA ENGINE (Ch.15)                      |
//| Triết lý: "Phân tích trục dọc" - nhìn cùng lúc nhiều khung      |
//+------------------------------------------------------------------+
struct S_IchiData {
   double tenkan;    // Tenkan sen (Ch.5)
   double kijun;     // Kijun sen (Ch.6)
   double ssa;       // Senkou Span A (Ch.11)
   double ssb;       // Senkou Span B (Ch.10)
   double chikou;    // Chikou span (Ch.14)
};

class C_Ichimoku {
private:
   int m_handle;
public:
   C_Ichimoku() { m_handle = INVALID_HANDLE; }
   ~C_Ichimoku() { if(m_handle != INVALID_HANDLE) IndicatorRelease(m_handle); }
   
   bool Init(string sym, ENUM_TIMEFRAMES tf, int t, int k, int s) {
      m_handle = iIchimoku(sym, tf, t, k, s);
      return (m_handle != INVALID_HANDLE);
   }
   
   bool Get(int shift, S_IchiData &d) {
      double buf[1];
      if(CopyBuffer(m_handle, 0, shift, 1, buf) < 1) return false; d.tenkan = buf[0];
      if(CopyBuffer(m_handle, 1, shift, 1, buf) < 1) return false; d.kijun  = buf[0];
      if(CopyBuffer(m_handle, 2, shift, 1, buf) < 1) return false; d.ssa    = buf[0];
      if(CopyBuffer(m_handle, 3, shift, 1, buf) < 1) return false; d.ssb    = buf[0];
      if(CopyBuffer(m_handle, 4, shift, 1, buf) < 1) return false; d.chikou = buf[0];
      return true;
   }
   
   double KumoTop(S_IchiData &d)    { return MathMax(d.ssa, d.ssb); }
   double KumoBottom(S_IchiData &d) { return MathMin(d.ssa, d.ssb); }
   double KumoThick(S_IchiData &d)  { return MathAbs(d.ssa - d.ssb) / (g_point * g_p2p); }
};

C_Ichimoku m_ichiBase, m_ichiMid, m_ichiHigh;

//+------------------------------------------------------------------+
//| SECTION 5: SESSION & TIME MANAGER                                |
//+------------------------------------------------------------------+
class C_Session {
private:
   int ParseHour(string s, bool start) {
      string parts[];
      if(StringSplit(s, '-', parts) == 2) {
         string hm[];
         if(StringSplit(start ? parts[0] : parts[1], ':', hm) == 2)
            return (int)StringToInteger(hm[0]);
      }
      return 0;
   }
public:
   bool CanTrade() {
      if(!InpUseTimeFilter) return true;
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      if(InpCloseOnFriday && dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour) return false;
      
      bool ok = false;
      if(dt.hour >= ParseHour(InpTokyo,true) && dt.hour < ParseHour(InpTokyo,false)) ok = true;
      if(dt.hour >= ParseHour(InpLondon,true) && dt.hour < ParseHour(InpLondon,false)) ok = true;
      if(dt.hour >= ParseHour(InpNewYork,true) && dt.hour < ParseHour(InpNewYork,false)) ok = true;
      return ok;
   }
   
   bool IsFridayClose() {
      if(!InpCloseOnFriday) return false;
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      return (dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour);
   }
   
   bool IsNewsTime() {
      if(!InpUseNewsFilter) return false;
      datetime now = TimeCurrent();
      MqlCalendarValue v[];
      if(!CalendarValueHistory(v, now - InpNewsMinutes*60, now + InpNewsMinutes*60)) return false;
      string b = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
      string q = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
      if(b == "") { b = StringSubstr(_Symbol, 0, 3); q = StringSubstr(_Symbol, 3, 3); }
      for(int i = 0; i < ArraySize(v); i++) {
         MqlCalendarEvent e; MqlCalendarCountry c;
         if(CalendarEventById(v[i].event_id, e) && CalendarCountryById(e.country_id, c))
            if(e.importance == CALENDAR_IMPORTANCE_HIGH && (c.currency == b || c.currency == q))
               return true;
      }
      return false;
   }
};

C_Session m_session;

//+------------------------------------------------------------------+
//| SECTION 6: SAKATA PATTERNS (Ch.1 Extension)                      |
//| Triết lý: Đọc nến Nhật - xác nhận thêm cho tín hiệu Ichimoku   |
//+------------------------------------------------------------------+
enum ENUM_SAKATA {
   SAK_NONE = 0,
   SAK_BULL_ENGULF = 1,  SAK_BEAR_ENGULF = -1,
   SAK_MORNING     = 2,  SAK_EVENING     = -2,
   SAK_HAMMER      = 3,  SAK_SHOOTING    = -3,
   SAK_3SOLDIERS   = 4,  SAK_3CROWS      = -4,
   SAK_DOJI        = 5,
   SAK_MARUBOZU_B  = 7,  SAK_MARUBOZU_S  = -7
};

class C_Sakata {
private:
   double O[], H[], L[], C[];
   double Body(int i)  { return MathAbs(O[i]-C[i]); }
   double UShadow(int i) { return H[i] - MathMax(O[i],C[i]); }
   double LShadow(int i) { return MathMin(O[i],C[i]) - L[i]; }
   bool   Bull(int i)  { return C[i] > O[i]; }
   bool   Bear(int i)  { return C[i] < O[i]; }
public:
   C_Sakata() {
      ArrayResize(O,5); ArrayResize(H,5); ArrayResize(L,5); ArrayResize(C,5);
      ArraySetAsSeries(O,true); ArraySetAsSeries(H,true);
      ArraySetAsSeries(L,true); ArraySetAsSeries(C,true);
   }
   
   ENUM_SAKATA Detect(ENUM_TIMEFRAMES tf) {
      if(CopyOpen(_Symbol,tf,1,5,O)<5) return SAK_NONE;
      if(CopyHigh(_Symbol,tf,1,5,H)<5) return SAK_NONE;
      if(CopyLow(_Symbol,tf,1,5,L)<5)  return SAK_NONE;
      if(CopyClose(_Symbol,tf,1,5,C)<5) return SAK_NONE;
      
      double b0=Body(0), b1=Body(1), b2=Body(2);
      double avg = (b0+b1+b2)/3.0;
      
      if(b0 <= (H[0]-L[0])*0.05) return SAK_DOJI;
      if(Bull(0) && Bear(1) && C[0]>O[1] && O[0]<C[1]) return SAK_BULL_ENGULF;
      if(Bear(0) && Bull(1) && C[0]<O[1] && O[0]>C[1]) return SAK_BEAR_ENGULF;
      if(Bull(0) && b1<avg*0.3 && Bear(2) && b0>avg*1.5 && C[0]>(O[2]+C[2])/2) return SAK_MORNING;
      if(Bear(0) && b1<avg*0.3 && Bull(2) && b0>avg*1.5 && C[0]<(O[2]+C[2])/2) return SAK_EVENING;
      if(b0>0 && LShadow(0)>b0*2 && UShadow(0)<b0*0.2) return SAK_HAMMER;
      if(b0>0 && UShadow(0)>b0*2 && LShadow(0)<b0*0.2) return SAK_SHOOTING;
      if(Bull(0)&&Bull(1)&&Bull(2) && C[0]>H[1] && C[1]>H[2]) return SAK_3SOLDIERS;
      if(Bear(0)&&Bear(1)&&Bear(2) && C[0]<L[1] && C[1]<L[2]) return SAK_3CROWS;
      if(Bull(0) && b0>avg*2 && UShadow(0)<b0*0.05 && LShadow(0)<b0*0.05) return SAK_MARUBOZU_B;
      if(Bear(0) && b0>avg*2 && UShadow(0)<b0*0.05 && LShadow(0)<b0*0.05) return SAK_MARUBOZU_S;
      return SAK_NONE;
   }
   
   int Score(ENUM_SAKATA p) {
      switch(p) {
         case SAK_3SOLDIERS:   return 150;  case SAK_3CROWS:     return -150;
         case SAK_MORNING:     return 120;  case SAK_EVENING:    return -120;
         case SAK_BULL_ENGULF: return 100;  case SAK_BEAR_ENGULF:return -100;
         case SAK_MARUBOZU_B:  return 80;   case SAK_MARUBOZU_S: return -80;
         case SAK_HAMMER:      return 60;   case SAK_SHOOTING:   return -60;
         default: return 0;
      }
   }
};

C_Sakata m_sakata;

//+------------------------------------------------------------------+
//| SECTION 7: ICHIMOKU ANALYZER (Ch.3-15)                           |
//| Triết lý: Phân tích cấu trúc Ichimoku toàn diện                 |
//| Mỗi hàm map 1:1 với một chương trong sách                       |
//+------------------------------------------------------------------+

// ==========================================
// 7.1: Kijun Flatness - Phát hiện Range (Ch.8)
// "Khi Kijun phẳng = thị trường đi ngang = fake cross"
// ==========================================
bool IsKijunFlat(C_Ichimoku &ichi, int periods) {
   S_IchiData d0;
   if(!ichi.Get(0, d0)) return false;
   int flat = 0;
   for(int i=1; i<=periods; i++) {
      S_IchiData di;
      if(!ichi.Get(i, di)) continue;
      if(MathAbs(d0.kijun - di.kijun) <= 2.0 * g_point * g_p2p)
         flat++;
   }
   return (flat >= periods - 1);
}

// ==========================================
// 7.2: Kijun Slope - Authentic Cross (Ch.7)
// "Gold Cross: Kijun PHẢI dốc lên hoặc ngang"
// "Dead Cross: Kijun PHẢI dốc xuống hoặc ngang"
// Returns: +1 (lên), 0 (ngang), -1 (xuống)
// ==========================================
int KijunSlope(C_Ichimoku &ichi) {
   S_IchiData d0, d2;
   if(!ichi.Get(0, d0) || !ichi.Get(2, d2)) return 0;
   double diff = d0.kijun - d2.kijun;
   if(diff > 2.0 * g_point * g_p2p) return 1;
   if(diff < -2.0 * g_point * g_p2p) return -1;
   return 0;
}

// ==========================================
// 7.3: Overextended - Giá quá xa Tenkan (Ch.5)
// "Giá quá xa Tenkan = quá nóng, sẽ bị hút lại"
// ==========================================
bool IsOverextended(C_Ichimoku &ichi, double price, double maxPips) {
   S_IchiData d;
   if(!ichi.Get(0, d)) return false;
   return (MathAbs(price - d.tenkan) > maxPips * g_point * g_p2p);
}

// ==========================================
// 7.4: Chikou Momentum (Ch.14)
// "Chikou > giá 26 bars trước = Momentum dương"
// Returns pips of momentum
// ==========================================
double ChikouMomentum(C_Ichimoku &ichi, ENUM_TIMEFRAMES tf) {
   double chikouVal = iClose(_Symbol, tf, 0);
   double pastPrice = iClose(_Symbol, tf, InpKijunPeriod);
   return (chikouVal - pastPrice) / (g_point * g_p2p);
}

// ==========================================
// 7.5: Sanyaku State (Ch.3)
// "Ba tín hiệu xác nhận đồng thời"
// Trả về: 1 (Sanyaku Kouten), -1 (Gyakuten), 0 (không có)
// ==========================================
int SanyakuState(C_Ichimoku &ichi, double price, ENUM_TIMEFRAMES tf) {
   S_IchiData d0, d1;
   if(!ichi.Get(0, d0) || !ichi.Get(1, d1)) return 0;
   
   double kumoTop = MathMax(d0.ssa, d0.ssb);
   double kumoBot = MathMin(d0.ssa, d0.ssb);
   
   // Chikou = Close[0] so với giá 26 nến trước
   // KHÔNG dùng buffer 4 vì tại shift=0 nó trả về EMPTY_VALUE
   double chikouVal  = iClose(_Symbol, tf, 0);
   double pastPrice  = iClose(_Symbol, tf, InpKijunPeriod);
   
   // === Sanyaku Kouten (BUY) ===
   // 1. Tenkan > Kijun (TK Golden Cross - Ch.7)
   // 2. Giá > Kumo top (Phá mây lên - Ch.12)
   // 3. Chikou > giá quá khứ (Momentum dương - Ch.14)
   // 4. Kijun không dốc xuống (Authentic - Ch.7)
   if(d0.tenkan > d0.kijun && price > kumoTop && chikouVal > pastPrice) {
      if(d0.kijun >= d1.kijun) return 1;
   }
   
   // === Sanyaku Gyakuten (SELL) ===
   // 1. Tenkan < Kijun (TK Dead Cross)
   // 2. Giá < Kumo bot (Phá mây xuống)
   // 3. Chikou < giá quá khứ (Momentum âm)
   // 4. Kijun không dốc lên
   if(d0.tenkan < d0.kijun && price < kumoBot && chikouVal < pastPrice) {
      if(d0.kijun <= d1.kijun) return -1;
   }
   
   return 0;
}

// ==========================================
// 7.6: Market State (Ch.13, 8-9)
// Xác định trạng thái tổng thể
// ==========================================
ENUM_ICHI_STATE GetMarketState(C_Ichimoku &ichi, double price, ENUM_TIMEFRAMES tf) {
   S_IchiData d;
   if(!ichi.Get(0, d)) return ICHI_RANGE;
   
   // Range Detection (Ch.8)
   if(IsKijunFlat(ichi, InpKijunFlatBars)) return ICHI_RANGE;
   
   double kumoTop = MathMax(d.ssa, d.ssb);
   double kumoBot = MathMin(d.ssa, d.ssb);
   
   // Giá trong mây = tích lũy (Ch.12)
   if(price >= kumoBot && price <= kumoTop) return ICHI_RANGE;
   
   // Strong trend: Thứ tự hoàn hảo (Ch.13)
   // Uptrend: Giá > Tenkan > Kijun > Kumo
   if(price > d.tenkan && d.tenkan > d.kijun && d.kijun > kumoTop) return ICHI_STRONG_UP;
   // Downtrend: Giá < Tenkan < Kijun < Kumo
   if(price < d.tenkan && d.tenkan < d.kijun && d.kijun < kumoBot) return ICHI_STRONG_DOWN;
   
   // Weak trend
   if(price > kumoTop) return ICHI_WEAK_UP;
   if(price < kumoBot) return ICHI_WEAK_DOWN;
   
   return ICHI_RANGE;
}

// ==========================================
// 7.7: DCA Level Check (Ch.5, 6, 10, 12)
// Xác định giá đang pullback tới mức Ichimoku nào
// Returns: DCA level mà giá đang chạm
// ==========================================
ENUM_DCA_LEVEL CheckPullbackLevel(C_Ichimoku &ichi, double price, int dir) {
   S_IchiData d;
   if(!ichi.Get(0, d)) return DCA_NONE;
   
   double kumoTop = MathMax(d.ssa, d.ssb);
   double kumoBot = MathMin(d.ssa, d.ssb);
   
   if(dir == 1) { // BUY direction: pullback = giá giảm
      // Ch.10: "Senkou Span 2 = giới hạn thoái lui 1/2, phòng tuyến cuối"
      if(price <= d.ssb) return DCA_KUMO_DEEP;
      // Ch.12: "Giá vào trong mây = đà ngắn-trung hạn suy yếu"
      if(price <= kumoBot) return DCA_KUMO;
      // Ch.6: "Kijun = mức cân bằng trung hạn, pullback chuẩn"
      if(price <= d.kijun) return DCA_KIJUN;
      // Ch.5: "Tenkan = bệ đỡ đầu tiên, trend rất mạnh nếu bounce ở đây"
      if(price <= d.tenkan) return DCA_TENKAN;
   }
   else if(dir == -1) { // SELL direction: pullback = giá tăng
      if(price >= d.ssb) return DCA_KUMO_DEEP;
      if(price >= kumoTop) return DCA_KUMO;
      if(price >= d.kijun) return DCA_KIJUN;
      if(price >= d.tenkan) return DCA_TENKAN;
   }
   
   return DCA_NONE;
}

//+------------------------------------------------------------------+
//| SECTION 8: MATRIX SCORING (Confirmation Layer)                   |
//| Tổng hợp tất cả module Ichimoku thành điểm -1000 tới +1000     |
//+------------------------------------------------------------------+
void UpdateMatrixScore() {
   double price = m_symbol.Bid();
   S_IchiData d;
   if(!m_ichiBase.Get(0, d)) return;
   
   int bS = 0, sS = 0; // Buy/Sell scores
   
   // Han-ne Equilibrium (Ch.4-6): Giá vs Kijun
   if(price > d.kijun) bS += 200; else sS -= 200;
   
   // Overextended check (Ch.5)
   if(IsOverextended(m_ichiBase, price, 45)) {
      if(price > d.tenkan) bS -= 100; else sS += 100;
   }
   
   // Range punishment (Ch.8)
   if(IsKijunFlat(m_ichiBase, InpKijunFlatBars)) {
      bS /= 2; sS /= 2;
   }
   
   // Authentic Cross (Ch.7)
   int slope = KijunSlope(m_ichiBase);
   if(d.tenkan > d.kijun) {
      if(slope >= 0) bS += 250; else bS -= 125;
   } else if(d.tenkan < d.kijun) {
      if(slope <= 0) sS -= 250; else sS += 125;
   }
   
   // Chikou Momentum (Ch.14)
   double cMom = ChikouMomentum(m_ichiBase, InpBaseTF);
   if(cMom > 10.0) bS += 150; else if(cMom < -10.0) sS -= 150;
   
   // Kumo strength (Ch.12)
   double kThick = m_ichiBase.KumoThick(d);
   double kumoTop = MathMax(d.ssa, d.ssb);
   double kumoBot = MathMin(d.ssa, d.ssb);
   if(price > kumoTop && kThick >= InpMinKumoThick) bS += 300;
   else if(price < kumoBot && kThick >= InpMinKumoThick) sS -= 300;
   
   // MTF Alignment (Ch.15)
   if(InpMTFMode == MTF_TRIPLE) {
      S_IchiData mid, hgh;
      if(m_ichiMid.Get(0, mid) && m_ichiHigh.Get(0, hgh)) {
         if(price > mid.tenkan && price > hgh.tenkan) bS += 100;
         if(price < mid.tenkan && price < hgh.tenkan) sS -= 100;
      }
   }
   
   // Sakata Patterns
   int sakScore = m_sakata.Score(m_sakata.Detect(InpBaseTF));
   if(sakScore > 0) bS += sakScore; else sS += sakScore;
   
   g_scoreBuy  = MathMax(0, bS);
   g_scoreSell = MathMin(0, sS);
   g_scoreNet  = bS + sS;
}

//+------------------------------------------------------------------+
//| SECTION 9: POSITION HELPERS                                      |
//+------------------------------------------------------------------+
int CountPositions(int dir=0, bool isTrim=false) {
   int c = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos != isTrim) continue;
      
      if(dir==0) { c++; continue; }
      if(dir==1 && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) c++;
      if(dir==-1 && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL) c++;
   }
   return c;
}

double GetBasketProfit(bool isTrim=false) {
   double total = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos != isTrim) continue;
      
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

double GetTotalLots(bool isTrim=false) {
   double total = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos != isTrim) continue;
      
      total += PositionGetDouble(POSITION_VOLUME);
   }
   return total;
}

double GetLastEntryPrice(bool isTrim=false) {
   double p = 0; datetime t = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos != isTrim) continue;
      
      datetime tt = (datetime)PositionGetInteger(POSITION_TIME);
      if(tt > t) { t = tt; p = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return p;
}

double GetExtremeEntryPrice(bool isTrim=false) {
   double extreme = 0;
   int dir = isTrim ? g_trimDirection : g_direction;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos != isTrim) continue;
      
      double p = PositionGetDouble(POSITION_PRICE_OPEN);
      if(extreme == 0) { extreme = p; continue; }
      
      if(dir == 1 && p > extreme) extreme = p;
      if(dir == -1 && p < extreme) extreme = p;
   }
   return extreme;
}

void CloseBasket(bool isTrim) {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol) {
         bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
         if(isTrimPos == isTrim) m_trade.PositionClose(tk);
      }
   }
}

void CloseAllPositions() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol)
         m_trade.PositionClose(tk);
   }
}

double AdjustLots(double vol) {
   double mn = m_symbol.LotsMin(), mx = m_symbol.LotsMax(), st = m_symbol.LotsStep();
   vol = MathMax(mn, MathMin(mx, vol));
   return MathRound(vol / st) * st;
}

//+------------------------------------------------------------------+
//| SECTION 10: HELPER PARSERS & INDICATORS                          |
//+------------------------------------------------------------------+
double GetZScore(int period, ENUM_TIMEFRAMES tf) {
   double close[];
   if(CopyClose(_Symbol, tf, 0, period, close) < period) return 0;
   
   double mean = 0;
   for(int i=0; i<period; i++) mean += close[i];
   mean /= period;
   
   double variance = 0;
   for(int i=0; i<period; i++) variance += MathPow(close[i] - mean, 2);
   variance /= period;
   
   double stdDev = MathSqrt(variance);
   if(stdDev == 0) return 0;
   
   return (close[period-1] - mean) / stdDev;
}

// Parse "0.02,0.03,0.05" → double array
int ParseDoubleList(string str, double &arr[]) {
   string parts[];
   int count = StringSplit(str, StringGetCharacter(",",0), parts);
   ArrayResize(arr, count);
   for(int i=0; i<count; i++) {
      StringTrimLeft(parts[i]); StringTrimRight(parts[i]);
      arr[i] = StringToDouble(parts[i]);
   }
   return count;
}

// Giá trung bình gia quyền (weighted average price)
double GetAvgPrice(bool isTrim=false) {
   double totalCost = 0, totalVol = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos != isTrim) continue;
      
      double v = PositionGetDouble(POSITION_VOLUME);
      double p = PositionGetDouble(POSITION_PRICE_OPEN);
      totalCost += p * v;
      totalVol  += v;
   }
   return (totalVol > 0) ? totalCost / totalVol : 0;
}

// Lấy giá Entry ban đầu của rổ
double GetInitialEntryPrice(bool isTrim=false) {
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol) {
         string comment = PositionGetString(POSITION_COMMENT);
         bool isTrimPos = (StringFind(comment, "TRIM") >= 0);
         if(isTrimPos != isTrim) continue;
         
         if(StringFind(comment, isTrim ? "TRIM ENTRY" : "ENTRY") >= 0) {
            return PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }
   return GetAvgPrice(isTrim); // Fallback
}

// Tính Lot động để kéo TP về mức hòa vốn 1 rổ hoặc hòa vốn tổng (Total BE)
double CalculateRecoveryLot(bool isTrim, double srLevel, double tpPips) {
    double vSelf = GetTotalLots(isTrim);
    
    int mainCount = CountPositions(0, false);
    int trimCount = CountPositions(0, true);
    bool useHedgeMerge = (InpHedgeMergeVolume && mainCount > 0 && trimCount > 0);
    
    if(useHedgeMerge && ArraySize(g_trimDcaTP) > 0) {
        tpPips = g_trimDcaTP[0];
    }
    
    double tpDistPrice = tpPips * g_point * g_p2p;
    
    // NGĂN CHẶN TÍNH LOT RECOVERY QUÁ SỚM (chỉ tính khi chuẩn bị đạt mốc Cầu Hòa)
    if(useHedgeMerge) {
        int totalPos = mainCount + trimCount;
        if(totalPos < InpTrimBEAfterDCA - 1) return 0.0;
    } else if(InpEnableTrimTotalBE && trimCount > 0) {
        int totalPos = mainCount + trimCount;
        if(totalPos < InpBEAfterDCA - 1) return 0.0;
    } else {
        int posCount = (isTrim ? trimCount : mainCount);
        int threshold = isTrim ? InpTrimBEAfterDCA : InpBEAfterDCA;
        if(InpHedgeMergeVolume) threshold = InpTrimBEAfterDCA; // Áp dụng threshold tỉa cho cả main nếu bật InpHedgeMergeVolume
        if(posCount < threshold - 1) return 0.0;
    }
    
    if(!InpEnableTrimTotalBE && !useHedgeMerge) {
        // Rổ nào tính rổ đó (Basic recovery)
        if(vSelf == 0) return 0;
        double avgSelf = GetAvgPrice(isTrim);
        int dirSelf = isTrim ? g_trimDirection : g_direction;
        if(dirSelf == 0) return 0;
        
        double recovery = 0;
        if(dirSelf == 1) recovery = (avgSelf - srLevel - tpDistPrice) * vSelf / tpDistPrice;
        else recovery = (srLevel - avgSelf - tpDistPrice) * vSelf / tpDistPrice;
        return MathMax(0.0, recovery);
    }
    
    // Total Breakeven Logic (Cầu hòa chung 2 rổ)
    double vOther = GetTotalLots(!isTrim);
    if(vOther == 0) {
        // Rổ kia không có lệnh -> Tính như Basic recovery
        if(vSelf == 0) return 0;
        double avgSelf = GetAvgPrice(isTrim);
        int dirSelf = isTrim ? g_trimDirection : g_direction;
        if(dirSelf == 0) return 0;
        
        double recovery = 0;
        if(dirSelf == 1) recovery = (avgSelf - srLevel - tpDistPrice) * vSelf / tpDistPrice;
        else recovery = (srLevel - avgSelf - tpDistPrice) * vSelf / tpDistPrice;
        return MathMax(0.0, recovery);
    }
    
    // Có cả 2 rổ -> Giải phương trình bậc 2 tìm Lot X
    double avgSelf = GetAvgPrice(isTrim);
    double avgOther = GetAvgPrice(!isTrim);
    int dirSelf = isTrim ? g_trimDirection : g_direction;
    if(dirSelf == 0) return 0;
    
    // Tự động triệt tiêu đệ quy của mức giá TB mới và mức giá TP mới
    double A = tpDistPrice;
    double B = 2.0 * vSelf * tpDistPrice - vOther * dirSelf * (srLevel + dirSelf * tpDistPrice - avgOther);
    double C = vSelf * vSelf * tpDistPrice - vSelf * vOther * dirSelf * (avgSelf + dirSelf * tpDistPrice - avgOther);
    
    if(C >= 0) return 0.0; // Đã đủ Lot hòa vốn tổng nếu giá chạm mức TP mới, không cần thêm Lot
    
    double delta = B * B - 4.0 * A * C;
    if(delta < 0) return 0.0; // Không thể hòa vốn tổng bằng DCA
    
    double x = (-B + MathSqrt(delta)) / (2.0 * A);
    return MathMax(0.0, x);
}

// Quét các mức Kijun/SSB đi ngang trong quá khứ làm S/R tĩnh
int GetHistoricalSRLevels(C_Ichimoku &ichi, double refPrice, int dir, double &outLevels[], int maxLevels=20) {
   double rawLevels[];
   int rawCount = 0;
   
   // Quét 300 nến quá khứ
   for(int i = 1; i <= 300; i++) {
      S_IchiData d1, d2, d3, d4;
      if(!ichi.Get(i, d1) || !ichi.Get(i+1, d2) || !ichi.Get(i+2, d3) || !ichi.Get(i+3, d4)) break;
      
      // KIJUN phẳng 4 nến
      if(d1.kijun == d2.kijun && d2.kijun == d3.kijun && d3.kijun == d4.kijun) {
         ArrayResize(rawLevels, rawCount+1);
         rawLevels[rawCount++] = d1.kijun;
      }
      
      // SSB phẳng 4 nến
      if(d1.ssb == d2.ssb && d2.ssb == d3.ssb && d3.ssb == d4.ssb) {
         ArrayResize(rawLevels, rawCount+1);
         rawLevels[rawCount++] = d1.ssb;
      }
   }
   
   // Filter & Remove duplicates
   double validLevels[];
   int validCount = 0;
   
   for(int i=0; i<rawCount; i++) {
      double lvl = rawLevels[i];
      
      // Lọc hướng: S/R phải cách refPrice ít nhất MinDCAGap
      double minGap = InpMinDCAGap * g_point * g_p2p;
      if(dir == 1 && lvl > refPrice - minGap) continue;  // S/R cho BUY phải nằm dưới (Support)
      if(dir == -1 && lvl < refPrice + minGap) continue; // S/R cho SELL phải nằm trên (Resistance)
      
      // Remove trùng lặp (nếu khoảng cách < 3 pips thì gộp)
      bool isDup = false;
      for(int j=0; j<validCount; j++) {
         if(MathAbs(validLevels[j] - lvl) < 3.0 * g_point * g_p2p) {
            isDup = true; break;
         }
      }
      
      if(!isDup) {
         ArrayResize(validLevels, validCount+1);
         validLevels[validCount++] = lvl;
      }
   }
   
   ArraySort(validLevels);
   // Đảo ngược mảng nếu BUY (đang giảm dần => cần từ cao xuống thấp)
   if(dir == 1) {
      for(int i=0; i<validCount/2; i++) {
         double temp = validLevels[i];
         validLevels[i] = validLevels[validCount - 1 - i];
         validLevels[validCount - 1 - i] = temp;
      }
   }
   
   int copied = MathMin(validCount, maxLevels);
   ArrayResize(outLevels, copied);
   for(int i=0; i<copied; i++) outLevels[i] = validLevels[i];
   
   return copied;
}


//+------------------------------------------------------------------+
//| SECTION 11: 3 CHẾ ĐỘ QUẢN LÝ                                   |
//+------------------------------------------------------------------+

bool ManageBreakeven() {
   if(!InpEnableBE) return false;
   
   int mainCount = CountPositions(0, false);
   int trimCount = CountPositions(0, true);
   int totalCount = mainCount + trimCount;
   
   if(totalCount == 0) return false;
   
   // ============================================================
   // Có lệnh TRIM/HEDGE đang mở → BẮT BUỘC dùng Total BE (gộp cả 2 rổ)
   // Dù g_trimActive = false (đã bị reset vì đảo chiều lần 2), lệnh TRIM vẫn còn!
   // ============================================================
   if(trimCount > 0) {
      int threshold = InpBEAfterDCA;
      if(InpHedgeMergeVolume) threshold = InpTrimBEAfterDCA;
      
      if(totalCount < threshold) return false; // Tổng lệnh (SELL+BUY) chưa đủ threshold
      
      double profit = GetBasketProfit(false) + GetBasketProfit(true);
      if(profit > 0) {
         double lots = GetTotalLots(false) + GetTotalLots(true);
         double pipValue = m_symbol.TickValue() * g_p2p;
         
         double targetProfit = InpBEPips * pipValue * lots;
         if(InpHedgeMergeVolume) targetProfit = InpTrimBEPips * pipValue * lots;
         
         if(profit >= targetProfit) {
            CloseAllPositions(); // ĐÓNG TẤT CẢ: cả main + trim
            g_cycleWins++;
            g_cycleProfit += profit;
            PrintFormat("⚖️ HÒA VỐN TỔNG #%d: %.2f USD | %d pos (Main:%d + Trim:%d) | %.2f lot | Tổng: +%.2f",
               g_cycleWins, profit, totalCount, mainCount, trimCount, lots, g_cycleProfit);
            
            g_direction=0; g_dcaLevel=0; g_lastDCATime=0; g_lastPyramidTime=0;
            g_trimActive=false; g_trimDirection=0; g_trimDcaLevel=0; g_lastTrimTime=0;
            return true;
         }
      }
      return false; // Có TRIM nhưng chưa đủ → cấm đóng riêng lẻ
   }
   
   // ============================================================
   // Chỉ có rổ chính (không có TRIM) → Logic Breakeven riêng lẻ bình thường
   // ============================================================
   if(g_dcaLevel < InpBEAfterDCA) return false;
   
   double profit = GetBasketProfit(false);
   double avgPrice = GetAvgPrice(false);
   double currentPrice = (g_direction == 1) ? m_symbol.Bid() : m_symbol.Ask();
   double pips = 0;
   if(g_direction == 1) pips = (currentPrice - avgPrice) / (g_point * g_p2p);
   else if(g_direction == -1) pips = (avgPrice - currentPrice) / (g_point * g_p2p);
   
   if(pips >= InpBEPips) {
      double lots = GetTotalLots(false);
      CloseBasket(false);
      g_cycleWins++;
      g_cycleProfit += profit;
      PrintFormat("⚖️ HÒA VỐN CHÍNH #%d: %.1f pips (%.2f USD) | L%d | %d pos %.2f lot | Tổng: +%.2f",
         g_cycleWins, pips, profit, g_dcaLevel, mainCount, lots, g_cycleProfit);
      g_direction=0; g_dcaLevel=0; g_lastDCATime=0; g_lastPyramidTime=0;
      return true;
   }
   return false;
}


bool ManageTrimBreakeven() {
   if(!InpEnableTrim) return false;
   if(g_trimDcaLevel < InpTrimBEAfterDCA) return false;
   
   double profit = GetBasketProfit(true);
   double avgPrice = GetAvgPrice(true);
   double currentPrice = (g_trimDirection == 1) ? m_symbol.Bid() : m_symbol.Ask();
   double pips = 0;
   if(g_trimDirection == 1) pips = (currentPrice - avgPrice) / (g_point * g_p2p);
   else if(g_trimDirection == -1) pips = (avgPrice - currentPrice) / (g_point * g_p2p);
   
   if(pips >= InpTrimBEPips) {
      double lots = GetTotalLots(true);
      int count = CountPositions(0, true);
      CloseBasket(true);
      g_cycleProfit += profit;
      PrintFormat("⚖️ HÒA VỐN TỈA: %.1f pips (%.2f USD) | L%d | %d pos %.2f lot | Tổng: +%.2f",
         pips, profit, g_trimDcaLevel, count, lots, g_cycleProfit);
      g_trimActive = false; g_trimDirection = 0; g_trimDcaLevel = 0; g_lastTrimTime = 0;
      return true;
   }
   return false;
}

// ==========================================
// 11.1.5: PROPFIRM COMPLIANCE
// Set SL giả (rất xa) để đáp ứng yêu cầu PropFirm
// Kiểm tra giới hạn lỗ hàng ngày và Max Drawdown
// ==========================================
double GetPropFirmSL(int dir, double entryPrice) {
   if(!InpPropFirmMode) return 0; // Không bật PropFirm -> không cần SL
   double slDist = InpFakeSLPips * g_point * g_p2p;
   double sl = 0;
   if(dir == 1)  sl = entryPrice - slDist; // BUY: SL dưới giá vào
   if(dir == -1) sl = entryPrice + slDist; // SELL: SL trên giá vào
   return NormalizeDouble(sl, (int)m_symbol.Digits());
}

bool ManagePropFirmLimits() {
   if(!InpPropFirmMode) return false;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // 1. Kiểm tra lỗ trong ngày
   double dailyLoss = g_dayStartBalance - equity;
   double dailyLimit = g_dayStartBalance * InpDailyLossPct / 100.0;
   if(dailyLoss >= dailyLimit) {
      if(!g_propFirmLocked) {
         PrintFormat("🚨 PROPFIRM: Lỗ trong ngày %.2f USD vượt giới hạn %.1f%% (%.2f USD). ĐÓNG TẤT CẢ LỆNH!",
            dailyLoss, InpDailyLossPct, dailyLimit);
         CloseAllPositions();
         g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0; g_lastPyramidTime = 0;
         g_trimActive = false; g_trimDirection = 0; g_trimDcaLevel = 0; g_lastTrimTime = 0;
         g_propFirmLocked = true;
      }
      return true; // Block
   }
   
   // 2. Kiểm tra Max Drawdown từ số dư ban đầu
   double totalLoss = g_initialBalance - equity;
   double ddLimit = g_initialBalance * InpMaxDrawdownPct / 100.0;
   if(totalLoss >= ddLimit) {
      if(!g_propFirmLocked) {
         PrintFormat("🚨 PROPFIRM: Drawdown %.2f USD vượt giới hạn %.1f%% (%.2f USD). ĐÓNG TẤT CẢ LỆNH!",
            totalLoss, InpMaxDrawdownPct, ddLimit);
         CloseAllPositions();
         g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0; g_lastPyramidTime = 0;
         g_trimActive = false; g_trimDirection = 0; g_trimDcaLevel = 0; g_lastTrimTime = 0;
         g_propFirmLocked = true;
      }
      return true; // Block
   }
   
   return false;
}

// ==========================================
// 11.2: TỈA LỆNH (Trim Z-Score DCA)
// Khi rổ chính bị kẹt (DCA sâu), kích hoạt rổ tỉa ngược chiều.
// Entry bằng Z-Score, DCA bằng S/R ngược chiều của rổ chính.
// TP được tính bằng Pips giống DCA logic nhưng không có SL.
// ==========================================
void ManageTrim() {
   if(!InpEnableTrim && !InpEnableHedgeMode) return;
   
   // Tự reset nếu lệnh tỉa chạm mức TP rổ chính và đóng tự động
   if(g_trimActive && CountPositions(0, true) == 0) {
      g_trimActive = false; g_trimDirection = 0; g_trimDcaLevel = 0; g_lastTrimTime = 0;
   }
   
   int trimCount = CountPositions(0, true);
   
   // Ưu tiên 1: Hòa vốn Trim
   if(trimCount > 0 && ManageTrimBreakeven()) return;
   
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   
   // Lấy TP Pips từ cấu hình DCA rổ tỉa
   int tpSize = ArraySize(g_trimDcaTP);
   double tpPips = (tpSize > 0) ? g_trimDcaTP[MathMin(g_trimDcaLevel, tpSize-1)] : 15;
   
   int mainCount = CountPositions(0, false);
   
   if(InpHedgeMergeVolume && mainCount > 0 && trimCount > 0 && tpSize > 0) {
       tpPips = g_trimDcaTP[0];
   }
   
   double tpDist = tpPips * g_point * g_p2p;
   
   if(!g_trimActive) {
      bool trigger = false;
      double z = 0;
      string triggerSource = "Z-SCORE";
      
      // 1. Kiểm tra Hedge Mode (Sanyaku Reversal)
      if(InpEnableHedgeMode) {
         double price = iClose(_Symbol, InpBaseTF, 1);
         if(!IsKijunFlat(m_ichiBase, InpKijunFlatBars) && !m_session.IsNewsTime()) {
            int sanyaku = SanyakuState(m_ichiBase, price, InpBaseTF);
            if(g_direction == 1 && sanyaku == -1) {
               g_trimDirection = -1; trigger = true; triggerSource = "HEDGE";
            } else if(g_direction == -1 && sanyaku == 1) {
               g_trimDirection = 1; trigger = true; triggerSource = "HEDGE";
            }
         }
         
         // Lọc mây HighTF: Nếu giá đang NẰM TRONG MÂY khung lớn -> Chờ thoát mây
         if(trigger && InpHedgeWaitKumoBreak) {
            S_IchiData hd;
            if(m_ichiHigh.Get(0, hd)) {
               double kumoTop = m_ichiHigh.KumoTop(hd);
               double kumoBot = m_ichiHigh.KumoBottom(hd);
               double curPrice = m_symbol.Bid();
               if(curPrice >= kumoBot && curPrice <= kumoTop) {
                  trigger = false; // Giá trong mây HighTF -> Không mở Hedge
               }
            }
         }
      }
      
      // 2. Chế độ Z-Score (chỉ định kích hoạt khi rổ chính rơi vào vòng nguy hiểm DCA đủ sâu)
      if(!trigger && InpEnableTrim && g_dcaLevel >= InpTrimAfterDCA) {
         z = GetZScore(InpTrimZPeriod, InpBaseTF);
         if(g_direction == 1 && z >= InpTrimZThreshold) {
            // Lệnh chính BUY kẹt nhưng có nhịp hồi ngắn hạn (Z-Score đỉnh) -> Bắt nhịp hồi độ cao này để Tỉa SELL
            g_trimDirection = -1; trigger = true;
         }
         else if(g_direction == -1 && z <= -InpTrimZThreshold) {
            // Lệnh chính SELL kẹt nhưng có nhịp giảm ngắn hạn (Z-Score đáy) -> Bắt nhịp hồi độ sâu này để Tỉa BUY
            g_trimDirection = 1; trigger = true;
         }
      }

      // Đảm bảo rổ chính đang LỖ thực sự thì mới kích hoạt Tỉa (tránh kích hoạt oan khi đang Pyramid lãi)
      if(trigger) {
         double mainAvg = GetAvgPrice(false);
         if(g_direction == 1 && ask >= mainAvg) trigger = false; // Đang lãi -> Không tỉa
         if(g_direction == -1 && bid <= mainAvg) trigger = false; // Đang lãi -> Không tỉa
      }
      
      if(trigger) {
         double price = (g_trimDirection == 1) ? ask : bid;
         // Lấy Lot đầu tiên dựa theo hàm phục hồi tổng hợp (nếu có TotalBE) hoặc Lot gốc
         double recoveryLot = CalculateRecoveryLot(true, price, tpPips);
         double initLot = AdjustLots(MathMax(recoveryLot, InpEntryLot));
         // Phải lấy TP cách điểm vào lệnh chuẩn tpDist Price
         double tp = (g_trimDirection == 1) ? ask + tpDist : bid - tpDist;
         string comment = "PX TRIM ENTRY L1";
         
         bool ok = false;
         if(g_trimDirection == 1) ok = m_trade.Buy(initLot, _Symbol, ask, GetPropFirmSL(1, ask), tp, comment);
         else ok = m_trade.Sell(initLot, _Symbol, bid, GetPropFirmSL(-1, bid), tp, comment);
         
         if(ok) {
            g_trimActive = true; g_trimDcaLevel = 1; g_lastTrimTime = TimeCurrent();
            if(triggerSource == "HEDGE") {
               PrintFormat("⚖️ HEDGE ENTRY [%s]: %.2f lot @ %.5f | TP: %.5f",
                  (g_trimDirection==1)?"BUY":"SELL", initLot, price, tp);
            } else {
               PrintFormat("✂️ TRIM ENTRY [%s]: %.2f lot @ %.5f | TP: %.5f (Z=%.2f)",
                  (g_trimDirection==1)?"BUY":"SELL", initLot, price, tp, z);
            }
         }
      }
   }
   else {
      // Đã có lệnh tỉa -> Tự DCA rổ tỉa theo Ichimoku S/R của HƯỚNG TỈA
      long periodSec = PeriodSeconds(InpBaseTF);
      if(periodSec > 0 && (TimeCurrent() - g_lastTrimTime) < InpDCACooldownBars * periodSec) return;
      
      double price = iClose(_Symbol, InpBaseTF, 1);
      
      // HEDGE DCA CONSTRAINT: Nếu đang bật Hedge, chỉ cho phép DCA rổ Hedge 
      // nếu xu hướng Ichimoku hiện tại (Sanyaku) ĐỒNG THUẬN với rổ Hedge.
      if(InpEnableHedgeMode) {
         int sanyaku = SanyakuState(m_ichiBase, price, InpBaseTF);
         if(g_trimDirection == 1 && sanyaku == -1) return; // Trend đổi sang Sell, khóa DCA Hedge Buy
         if(g_trimDirection == -1 && sanyaku == 1) return; // Trend đổi sang Buy, khóa DCA Hedge Sell
      }
      
      double initPrice = GetInitialEntryPrice(true);
      if(initPrice <= 0) return;
      
      // Quét cản tĩnh nhưng với hướng của g_trimDirection
      double srLevels[];
      int numLevels = GetHistoricalSRLevels(m_ichiBase, initPrice, g_trimDirection, srLevels, 20);
      
      int nextLvl = g_trimDcaLevel;
      double srLevel = 0; string srName = ""; bool touched = false;
      price = iClose(_Symbol, InpBaseTF, 1); // Đã khai báo ở trên
      double lastPrice = GetLastEntryPrice(true);
      
      if(nextLvl < numLevels) {
         srLevel = srLevels[nextLvl]; srName = "T_FLAT_SR" + IntegerToString(nextLvl+1);
         if(lastPrice > 0) {
            double gap = MathAbs(price - lastPrice) / (g_point * g_p2p);
            if(gap < InpMinDCAGap) return;
         }
         double prevPrice = iClose(_Symbol, InpBaseTF, 2);
         if(g_trimDirection == 1) touched = (price <= srLevel && prevPrice > srLevel);
         if(g_trimDirection == -1) touched = (price >= srLevel && prevPrice < srLevel);
      } else {
         srLevel = price; srName = "T_GAP_L" + IntegerToString(nextLvl+1);
         if(lastPrice > 0) {
            double gap = MathAbs(price - lastPrice) / (g_point * g_p2p);
            if(gap >= InpMinDCAGap * 2.0) {
               if(g_trimDirection == 1 && price < lastPrice) touched = true;
               if(g_trimDirection == -1 && price > lastPrice) touched = true;
            }
         }
      }
      
      if(!touched) return;
      
      // Lấy Recovery Lot
      double recoveryLot = CalculateRecoveryLot(true, srLevel, tpPips);
      
      // HEDGE BE VOLUME LOGIC: Nếu đang Hedge và tổng lệnh đạt số lượng Cầu Hòa,
      // BẮT BUỘC ưu tiên sử dụng volume Cầu Hòa (recoveryLot) để thoát thay vì MinLot
      bool forceRecovery = false;
      if(InpEnableHedgeMode && (InpEnableTrimTotalBE || InpHedgeMergeVolume)) {
         int totalPos = CountPositions(0, false) + CountPositions(0, true);
         int forceThreshold = InpHedgeMergeVolume ? InpTrimBEAfterDCA : InpBEAfterDCA;
         if(totalPos >= forceThreshold) forceRecovery = true;
      }
      
      // Không bị cap bởi Equity gắt gao như rổ chính, nhưng cũng không cho phình quá to
      double minLot = InpEntryLot;
      if(forceRecovery) minLot = recoveryLot;
      
      double dcaLot = AdjustLots(MathMax(recoveryLot, minLot));
      
      bool ok = false; string comment = "PX TRIM DCA" + IntegerToString(nextLvl+1);
      if(g_trimDirection == 1) {
         double tp = (tpPips > 0) ? ask + tpDist : 0;
         ok = m_trade.Buy(dcaLot, _Symbol, ask, GetPropFirmSL(1, ask), tp, comment);
      } else if(g_trimDirection == -1) {
         double tp = (tpPips > 0) ? bid - tpDist : 0;
         ok = m_trade.Sell(dcaLot, _Symbol, bid, GetPropFirmSL(-1, bid), tp, comment);
      }
      
      if(ok) {
         g_trimDcaLevel = nextLvl + 1; g_lastTrimTime = TimeCurrent();
         double newAvg = GetAvgPrice(true);
         double sharedTP = 0;
         
         if(tpPips > 0) {
            if(g_trimDirection == 1) sharedTP = newAvg + tpDist;
            else if(g_trimDirection == -1) sharedTP = newAvg - tpDist;
            
            for(int i = 0; i < PositionsTotal(); i++) {
               ulong tk = PositionGetTicket(i);
               if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
                  if(StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0) {
                     double sl = PositionGetDouble(POSITION_SL);
                     double tp = PositionGetDouble(POSITION_TP);
                     if(MathAbs(tp - sharedTP) > 0.00001) {
                        m_trade.PositionModify(tk, sl, sharedTP);
                     }
                  }
               }
            }
         }
         PrintFormat("✂️ TRIM DCA L%d [%s]: %.2f lot @ %.5f | TP: %.5f", g_trimDcaLevel, srName, dcaLot, (g_trimDirection==1)?ask:bid, sharedTP);
      }
   }
}

// ==========================================
// 11.3: GỘP TP (Merged TP)
// ==========================================
void UpdateMergedTP(bool isTrim) {
   bool enabled = isTrim ? InpEnableTrimMTP : InpEnableMergedTP;
   int targetLevel = isTrim ? InpTrimMTPLevel : InpMergedTPLevel;
   string prefix = isTrim ? "PX TRIM DCA" : "PX DCA";
   int activeLevel = isTrim ? g_trimDcaLevel : g_dcaLevel;
   int dir = isTrim ? g_trimDirection : g_direction;
   
   if(!enabled) return;
   if(activeLevel < targetLevel) return; // Chưa đủ level
   if(CountPositions(0, isTrim) < 2) return;
   
   // Lấy TP pips của level chỉ định
   double tpPips = 0;
   if(isTrim) {
      int tpIdx = targetLevel - 1;
      if(tpIdx >= ArraySize(g_trimDcaTP)) return;
      tpPips = g_trimDcaTP[tpIdx];
   } else {
      int tpIdx = targetLevel - 1;
      if(tpIdx >= ArraySize(g_dcaTP)) return;
      tpPips = g_dcaTP[tpIdx];
   }
   
   string targetComment = prefix + IntegerToString(targetLevel);
   double refPrice = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool isTrimPos = (StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0);
      if(isTrimPos == isTrim && PositionGetString(POSITION_COMMENT) == targetComment) {
         refPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         break;
      }
   }
   if(refPrice <= 0) return;
   
   double tpDist = tpPips * g_point * g_p2p;
   double mergedTP = 0;
   if(dir == 1) mergedTP = refPrice + tpDist;
   else if(dir == -1) mergedTP = refPrice - tpDist;
   else return;
   
   double price = (dir == 1) ? m_symbol.Bid() : m_symbol.Ask();
   bool tpHit = (dir == 1 && price >= mergedTP) || (dir == -1 && price <= mergedTP);
   
   if(tpHit) {
      double profit = GetBasketProfit(isTrim);
      int count = CountPositions(0, isTrim);
      CloseBasket(isTrim);
      g_cycleProfit += profit;
      
      if(!isTrim) {
         g_cycleWins++;
         PrintFormat("🎯 GỘP TP CHÍNH L%d #%d: %.2f USD | %d pos | Tổng: +%.2f", targetLevel, g_cycleWins, profit, count, g_cycleProfit);
         g_direction=0; g_dcaLevel=0; g_lastDCATime=0; g_lastPyramidTime=0;
      } else {
         PrintFormat("🎯 GỘP TP TỈA L%d: %.2f USD | %d pos | Tổng: +%.2f", targetLevel, profit, count, g_cycleProfit);
         g_trimActive=false; g_trimDirection=0; g_trimDcaLevel=0; g_lastTrimTime=0;
      }
   }
}

// ==========================================
// 11.4: PYRAMID DCA (DCA thuận trend)
// Nhồi vol đều khi giá tiếp tục thuận lợi,
// tại điểm breakout cản Ichimoku chiều ngược lại.
// ==========================================
void ManagePyramidDCA() {
   if(!InpEnablePyramid) return;
   if(g_direction == 0) return;
   if(g_dcaLevel < 1) return; // Chưa có DCA nào → chưa nhồi Pyramid
   
   // Không Pyramid khi đang ở chế độ cầu hòa (có lệnh TRIM/HEDGE)
   if(CountPositions(0, true) > 0) return;
   
   // Cooldown
   long periodSec = PeriodSeconds(InpBaseTF);
   if(periodSec > 0 && (TimeCurrent() - g_lastPyramidTime) < InpDCACooldownBars * periodSec) return;
   
   double lastPrice = GetExtremeEntryPrice(false);
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double price = (g_direction == 1) ? ask : bid;
   
   // Chỉ nhồi khi giá thuận trend (vượt qua đỉnh cực đại của rổ lệnh)
   if(g_direction == 1 && price <= lastPrice) return;
   if(g_direction == -1 && price >= lastPrice) return;
   
   double initPrice = GetInitialEntryPrice(false);
   if(initPrice <= 0) return;
   
   // Quét cản tĩnh ngược chiều để tìm đỉnh/đáy hỗ trợ cho việc nhồi lệnh
   double srLevels[];
   int numLevels = GetHistoricalSRLevels(m_ichiBase, initPrice, -g_direction, srLevels, 50);
   
   bool touched = false;
   double srLevel = 0;
   string srName = "";
   
   for(int i = 0; i < numLevels; i++) {
      double lvl = srLevels[i];
      if (g_direction == 1 && lvl <= lastPrice) continue;
      if (g_direction == -1 && lvl >= lastPrice) continue;
      
      // Found the first valid level ahead
      double gap = MathAbs(lvl - lastPrice) / (g_point * g_p2p);
      if(gap < InpMinPyramidGap) continue; // Bỏ qua nếu quá gần lệnh mới vào
      
      // Chạm hoặc vượt mức cản -> Kích hoạt Nhồi dương ngay
      if (g_direction == 1 && price >= lvl) {
         touched = true; srLevel = lvl; srName = "PYR_SR" + IntegerToString(i+1);
      }
      if (g_direction == -1 && price <= lvl) {
         touched = true; srLevel = lvl; srName = "PYR_SR" + IntegerToString(i+1);
      }
      break; 
   }
   
   // Cứu cánh bằng Gap nếu hết cản:
   if (!touched) {
      double gap = MathAbs(price - lastPrice) / (g_point * g_p2p);
      if (gap >= InpMinPyramidGap) {
         if (g_direction == 1 && price > lastPrice) {
            touched = true; srLevel = price; srName = "PYR_GAP";
         }
         if (g_direction == -1 && price < lastPrice) {
            touched = true; srLevel = price; srName = "PYR_GAP";
         }
      }
   }
   
   if(touched) {
      double vol = AdjustLots(InpEntryLot); // Lấy Lot gốc L0
      double tpPips = (ArraySize(g_dcaTP) > 0) ? g_dcaTP[0] : 10;
      double tpDist = tpPips * g_point * g_p2p;
      string comment = "PX PYRAMID " + ((g_direction==1)?"BUY":"SELL");
      
      // Coi như L0 -> Shared TP = entry mới lập + tpPips (Kéo TP của cả dàn lên theo lệnh nhồi)
      double sharedTP = (g_direction == 1) ? ask + tpDist : bid - tpDist;
      
      bool ok = false;
      if(g_direction == 1) ok = m_trade.Buy(vol, _Symbol, ask, GetPropFirmSL(1, ask), sharedTP, comment);
      else ok = m_trade.Sell(vol, _Symbol, bid, GetPropFirmSL(-1, bid), sharedTP, comment);
      
      if(ok) {
         g_lastPyramidTime = TimeCurrent();
         for(int i=0; i<PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               if(StringFind(PositionGetString(POSITION_COMMENT), "TRIM") < 0) {
                  double sl = PositionGetDouble(POSITION_SL);
                  double tp = PositionGetDouble(POSITION_TP);
                  if(MathAbs(tp - sharedTP) > 0.00001) {
                     m_trade.PositionModify(tk, sl, sharedTP);
                  }
               }
            }
         }
         PrintFormat("🔺 PYRAMID DCA [%s]: %.3f lot @ %.5f | Set TP toàn rổ: %.5f (Cách %.0f pips L0)", 
             (g_direction==1)?"BUY":"SELL", vol, price, sharedTP, tpPips);
      }
   }
}

//+------------------------------------------------------------------+
//| SECTION 12: CORE DCA STRATEGY                                    |
//| ============================================================     |
//| Flow:                                                            |
//| 1. Không có lệnh → Chờ Sanyaku State (Ch.3)                     |
//| 2. Entry → DCA theo khoảng cách tùy chỉnh (InpDCADistances)     |
//| 3. Lot mỗi tầng tùy chỉnh (InpDCALots)                         |
//| 4. Hòa vốn khi DCA sâu + Tỉa lệnh + Gộp TP                    |
//| 5. Basket TP → chốt sạch → chu kỳ mới                           |
//+------------------------------------------------------------------+
void ManageDCA() {
   int posCount = CountPositions(0, false);
   
   // Tự reset trạng thái nếu MT5 đã tự động đóng hết lệnh chính (VD: hit TP)
   if(posCount == 0 && g_direction != 0) {
      g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0; g_lastPyramidTime = 0;
      Print("🔄 Trạng thái CHÍNH đã được reset do không còn lệnh nào.");
   }
   
   // ===========================================================
   // STEP 0: HÒA VỐN - Ưu tiên cao nhất khi DCA sâu
   // ===========================================================
   if(posCount > 0 && ManageBreakeven()) return;
   
   // ===========================================================
   // STEP 1: GỘP TP - Đóng tất cả khi TP của level chỉ định hit
   // ===========================================================
   if(posCount > 0) UpdateMergedTP(false);
   if(CountPositions(0, true) > 0) UpdateMergedTP(true);
   
   // Cập nhật lại posCount sau khi có thể đã đóng lệnh
   posCount = CountPositions(0, false);
   if(posCount == 0 && g_direction != 0) {
      g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0; g_lastPyramidTime = 0;
   }
   
   // ===========================================================
   // STEP 1.5: TỈA LỆNH
   // ===========================================================
   if(posCount > 0) ManageTrim();
   
   // ===========================================================
   // STEP 1.8: PYRAMID DCA 
   // ===========================================================
   if(posCount > 0) ManagePyramidDCA();
   
   // Nếu session không cho phép → chỉ quản lý exits
   if(!m_session.CanTrade()) return;
   if((int)m_symbol.Spread() > InpMaxSpread) return;
   
   // Lấy dữ liệu Ichimoku
   S_IchiData d0, d1;
   if(!m_ichiBase.Get(0, d0) || !m_ichiBase.Get(1, d1)) return;
   
   double price = iClose(_Symbol, InpBaseTF, 1);
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   
   // ===========================================================
   // STEP 2: ENTRY - Mở lệnh đầu tiên khi Sanyaku xác nhận
   // ===========================================================
   if(posCount == 0) {
      if(IsKijunFlat(m_ichiBase, InpKijunFlatBars)) return;
      if(m_session.IsNewsTime()) return; // Không vào L0 khi có tin High-Impact
      
      // Filter High Timeframe Cloud
      if(InpFilterHighKumo && InpMTFMode == MTF_TRIPLE) {
         S_IchiData dHigh;
         if(m_ichiHigh.Get(0, dHigh)) {
            double kumoTopH = MathMax(dHigh.ssa, dHigh.ssb);
            double kumoBotH = MathMin(dHigh.ssa, dHigh.ssb);
            double priceH = iClose(_Symbol, InpHighTF, 1);
            if(priceH >= kumoBotH && priceH <= kumoTopH) return; // Không vào lệnh khi giá trong mây H1+
         }
      }
      
      int sanyaku = SanyakuState(m_ichiBase, price, InpBaseTF);
      
      // RSI Filter Check
      bool rsiAllowBuy = true;
      bool rsiAllowSell = true;
      if(InpEnableRSIFilter && m_rsiHandle != INVALID_HANDLE) {
         double rsiVal[1];
         if(CopyBuffer(m_rsiHandle, 0, 1, 1, rsiVal) > 0) {
            if(rsiVal[0] > InpRSIOverbought) rsiAllowBuy = false;
            if(rsiVal[0] < InpRSIOversold) rsiAllowSell = false;
         }
      }
      
      if(sanyaku == 1 && rsiAllowBuy) {
         double entryTPpips = (ArraySize(g_dcaTP) > 0) ? g_dcaTP[0] : 10;
         double vol = AdjustLots(InpEntryLot);
         double entryTP = ask + entryTPpips * g_point * g_p2p;
         if(m_trade.Buy(vol, _Symbol, ask, GetPropFirmSL(1, ask), entryTP, "PX ENTRY BUY")) {
            g_direction = 1; g_dcaLevel = 0; g_lastDCATime = TimeCurrent(); g_lastPyramidTime = TimeCurrent();
            PrintFormat("🟢 ENTRY BUY: %.3f lot @ %.5f | TP: %.5f (%.0f pips)", vol, ask, entryTP, entryTPpips);
         }
      }
      else if(sanyaku == -1 && rsiAllowSell) {
         double entryTPpips = (ArraySize(g_dcaTP) > 0) ? g_dcaTP[0] : 10;
         double vol = AdjustLots(InpEntryLot);
         double entryTP = bid - entryTPpips * g_point * g_p2p;
         if(m_trade.Sell(vol, _Symbol, bid, GetPropFirmSL(-1, bid), entryTP, "PX ENTRY SELL")) {
            g_direction = -1; g_dcaLevel = 0; g_lastDCATime = TimeCurrent(); g_lastPyramidTime = TimeCurrent();
            PrintFormat("🔴 ENTRY SELL: %.3f lot @ %.5f | TP: %.5f (%.0f pips)", vol, bid, entryTP, entryTPpips);
         }
      }
      return;
   }
   
   // ===========================================================
   // STEP 3: DCA THEO CẢN TĨNH LỊCH SỬ (Historical Flat S/R)
   // Lấy giá Entry ban đầu làm mốc. Quét tìm các Kijun/SSB đi ngang 
   // trong quá khứ làm các mốc cản cứng rải dọc theo trend.
   // Ít bị "kéo theo giá" như Tenkan/Kijun hiện tại.
   // ===========================================================
   
   // Cooldown
   long periodSec = PeriodSeconds(InpBaseTF);
   if(periodSec > 0 && (TimeCurrent() - g_lastDCATime) < InpDCACooldownBars * periodSec) return;
   
   // HEDGE DCA CONSTRAINT: Nếu đang bật Hedge và rổ Hedge đang có lệnh, chỉ cho phép DCA rổ CHÍNH 
   // nếu xu hướng Ichimoku hiện tại (Sanyaku) ĐỒNG THUẬN với rổ chính.
   if(InpEnableHedgeMode && g_trimActive && CountPositions(0, true) > 0) {
      int sanyaku = SanyakuState(m_ichiBase, price, InpBaseTF);
      if(g_direction == 1 && sanyaku == -1) return; // Trend đổi sang Sell, khóa DCA Buy
      if(g_direction == -1 && sanyaku == 1) return; // Trend đổi sang Buy, khóa DCA Sell
   }
   
   double initPrice = GetInitialEntryPrice();
   if(initPrice <= 0) return;
   
   double srLevels[];
   int numLevels = GetHistoricalSRLevels(m_ichiBase, initPrice, g_direction, srLevels, 50); // Tối đa 50 cản
   
   int nextLevel = g_dcaLevel;
   double srLevel = 0;
   string srName = "";
   bool touched = false;
   double lastPrice = GetLastEntryPrice();
   
   if(nextLevel < numLevels) {
      srLevel = srLevels[nextLevel];
      srName  = "FLAT_SR" + IntegerToString(nextLevel+1);
      
      // Phải có khoảng cách tối thiểu từ lệnh cuối
      if(lastPrice > 0) {
         double gap = MathAbs(price - lastPrice) / (g_point * g_p2p);
         if(gap < InpMinDCAGap) return;
      }
      
      // Fresh cross: nến trước (bar 2) chưa qua, nến đóng (bar 1) vượt qua
      double prevPrice = iClose(_Symbol, InpBaseTF, 2);
      if(g_direction == 1) {
         touched = (price <= srLevel && prevPrice > srLevel);
      }
      if(g_direction == -1) {
         touched = (price >= srLevel && prevPrice < srLevel);
      }
   }
   else {
      // Hết cản tĩnh -> Vẫn cho phép DCA dự phòng bằng khoảng cách Gap
      // NHƯNG nhân đôi Gap để giãn xa đề phòng trend quá mạnh
      srLevel = price;
      srName  = "GAP_L" + IntegerToString(nextLevel+1);
      
      if(lastPrice > 0) {
         double gap = MathAbs(price - lastPrice) / (g_point * g_p2p);
         if(gap >= InpMinDCAGap * 2.0) { // Gap x2 khi hết cản S/R tĩnh
            if(g_direction == 1 && price < lastPrice) touched = true;
            if(g_direction == -1 && price > lastPrice) touched = true;
         }
      }
   }
   
   if(!touched) return;
   
   // ============================================================
   // TÍNH LOT ĐỘNG dựa trên Recovery Formula + % Equity
   //
   // Mục tiêu: Khi giá bounce TP_pips từ mức S/R, basket = LÃI
   //
   // Công thức (BUY):
   //   avg_old = giá TB cũ (weighted)
   //   total_old = tổng lot cũ
   //   sr = giá mức S/R (đang chạm)
   //   tp_dist = TP pips của tầng này
   //   bounce_target = sr + tp_dist  (mức giá cần đạt để lãi)
   //
   //   Ta cần: new_avg <= sr + tp_dist  (TP từ S/R = đủ lãi)
   //   new_avg = (avg_old * total_old + sr * dca_lot) / (total_old + dca_lot)
   //   => dca_lot = (avg_old - sr - tp_dist) * total_old / tp_dist
   //
   // Nếu âm (không cần recovery) → dùng lot tối thiểu % equity
   // Cap: Max InpDCARiskPct % equity
   // TP: lấy từ list, nếu hết list → lấy giá trị cuối
   int tpSize = ArraySize(g_dcaTP);
   double tpPips = (tpSize > 0) ? g_dcaTP[MathMin(nextLevel, tpSize-1)] : 10;
   
   int mainCount = CountPositions(0, false);
   int trimCount = CountPositions(0, true);
   if(InpHedgeMergeVolume && mainCount > 0 && trimCount > 0 && ArraySize(g_trimDcaTP) > 0) {
      tpPips = g_trimDcaTP[0];
   }
   
   double tpDist = tpPips * g_point * g_p2p;
   
   double avgOld = GetAvgPrice();
   double totalOld = GetTotalLots(false);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Recovery lot (đơn vị = lots)
   // Tự động tính Total Breakeven nếu bật, nếu không thì tính bình thường rổ chính
   double recoveryLot = CalculateRecoveryLot(false, srLevel, tpPips);
   
   // HEDGE BE VOLUME LOGIC: Nếu đang Hedge và tổng lệnh đạt số lượng Cầu Hòa,
   // BẮT BUỘC ưu tiên sử dụng volume Cầu Hòa (recoveryLot) để thoát thay vì MinLot
   bool forceRecovery = false;
   if(InpEnableHedgeMode && (InpEnableTrimTotalBE || InpHedgeMergeVolume) && g_trimActive) {
      int totalPos = CountPositions(0, false) + CountPositions(0, true);
      int forceThreshold = InpHedgeMergeVolume ? InpTrimBEAfterDCA : InpBEAfterDCA;
      if(totalPos >= forceThreshold) forceRecovery = true;
   }
   
   // Pip value = giá trị 1 pip cho 1 lot
   double pipValue = m_symbol.TickValue() * g_p2p;
   
   // Min lot = entry lot (nhỏ, fallback)
   double minLot = InpEntryLot;
   if(forceRecovery) minLot = recoveryLot; // Ép mức tối thiểu phải bằng Cầu Hòa
   if(minLot < m_symbol.LotsMin()) minLot = m_symbol.LotsMin();

   
   // Max lot = % equity cap (dùng TP pips làm risk distance)
   double maxRiskLot = m_symbol.LotsMax();
   if(pipValue > 0 && InpDCARiskPct < 999) {
      maxRiskLot = (equity * InpDCARiskPct / 100.0) / (tpPips * pipValue);
   }
   if(maxRiskLot < m_symbol.LotsMin()) maxRiskLot = m_symbol.LotsMin();
   
   // Chọn lot: MAX(recovery, min) nhưng CAP bởi maxRisk
   double dcaLot = AdjustLots(MathMin(MathMax(recoveryLot, minLot), maxRiskLot));
   
   bool ok = false;
   string comment = "PX DCA" + IntegerToString(nextLevel+1);
   if(g_direction == 1) {
      double tp = (tpPips > 0) ? ask + tpDist : 0;
      ok = m_trade.Buy(dcaLot, _Symbol, ask, GetPropFirmSL(1, ask), tp, comment);
   } else if(g_direction == -1) {
      double tp = (tpPips > 0) ? bid - tpDist : 0;
      ok = m_trade.Sell(dcaLot, _Symbol, bid, GetPropFirmSL(-1, bid), tp, comment);
   }
   
   if(ok) {
      g_dcaLevel = nextLevel + 1;
      g_lastDCATime = TimeCurrent();
      double newAvg = GetAvgPrice();
      
      // Tính TP chung cho cả rổ dựa trên giá trung bình mới
      double sharedTP = 0;
      if(tpPips > 0) {
         if(g_direction == 1) sharedTP = newAvg + tpDist;
         else if(g_direction == -1) sharedTP = newAvg - tpDist;
         
         for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               if(StringFind(PositionGetString(POSITION_COMMENT), "TRIM") >= 0) continue; // Bỏ qua lệnh tỉa
               double sl = PositionGetDouble(POSITION_SL);
               double tp = PositionGetDouble(POSITION_TP);
               if(MathAbs(tp - sharedTP) > 0.00001) {
                  m_trade.PositionModify(tk, sl, sharedTP);
               }
            }
         }
      }
      
      string dir = (g_direction==1) ? "BUY" : "SELL";
      PrintFormat("📊 DCA %s L%d [%s]: %.3f lot @ %.5f | SR: %.5f | TP: %.5f (%.0f pips) | Avg: %.5f | %d pos",
         dir, g_dcaLevel, srName, dcaLot, (g_direction==1)?ask:bid,
         srLevel, sharedTP, tpPips, newAvg, CountPositions());
   }
}

// ===========================================================
// High TF Reversal Close
// ===========================================================
void ManageHighTFReversal() {
   if(!InpCloseOnHighTFReversal) return;
   if(g_direction == 0 && !g_trimActive) return;
   
   double price = m_symbol.Bid();
   ENUM_ICHI_STATE highState = GetMarketState(m_ichiHigh, price, InpHighTF);
   
   bool reverse = false;
   int currentDir = (g_direction != 0) ? g_direction : g_trimDirection;
   
   if(currentDir == 1 && (highState == ICHI_STRONG_DOWN || highState == ICHI_WEAK_DOWN)) {
      reverse = true;
   } else if(currentDir == -1 && (highState == ICHI_STRONG_UP || highState == ICHI_WEAK_UP)) {
      reverse = true;
   }
   
   if(reverse) {
      double profit = GetBasketProfit(false) + GetBasketProfit(true);
      PrintFormat("⚠️ KHUNG LỚN ĐẢO CHIỀU (State: %d) -> ĐÓNG TOÀN BỘ LỆNH! Profit: %.2f", highState, profit);
      CloseAllPositions();
      g_cycleProfit += profit;
      g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0; g_lastPyramidTime = 0;
      g_trimActive = false; g_trimDirection = 0; g_trimDcaLevel = 0; g_lastTrimTime = 0;
   }
}

// ===========================================================
// Pyramid Kijun Trailing
// ===========================================================
void ManagePyramidTrailing() {
   if(!InpPyramidTrailingKijun || !InpEnablePyramid) return;
   if(!InpPropFirmMode) return; // Không trail SL nếu tắt PropFirm để tránh dính SL giả
   if(g_direction == 0) return;
   
   S_IchiData d;
   if(!m_ichiBase.Get(0, d)) return;
   double kijun = d.kijun;
   
   double minGap = MathMax(m_symbol.StopsLevel() * g_point, (m_symbol.Ask() - m_symbol.Bid()) * 2.0);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, "PYRAMID") >= 0) {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            
            if(g_direction == 1) { // BUY
               if(kijun < m_symbol.Bid() - minGap) {
                  if(sl == 0.0 || kijun > sl) {
                     m_trade.PositionModify(tk, kijun, tp);
                  }
               }
            } else if(g_direction == -1) { // SELL
               if(kijun > m_symbol.Ask() + minGap) {
                  if(sl == 0.0 || kijun < sl) {
                     m_trade.PositionModify(tk, kijun, tp);
                  }
               }
            }
         }
      }
   }
}

// ===========================================================
// Friday Close: Đóng sạch trước weekend
// ===========================================================
void ManageFridayClose() {
   if(!m_session.IsFridayClose()) return;
   int c = CountPositions();
   if(c > 0) {
      double profit = GetBasketProfit();
      CloseAllPositions();
      if(profit > 0) { g_cycleWins++; g_cycleProfit += profit; }
      PrintFormat("📅 FRIDAY CLOSE: %d pos | P/L: %.2f USD | Cycles: %d | Total: +%.2f",
         c, profit, g_cycleWins, g_cycleProfit);
      g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0; g_lastPyramidTime = 0;
   }
}

//+------------------------------------------------------------------+
//| SECTION 11: OnInit / OnDeinit / OnTick                           |
//+------------------------------------------------------------------+
int OnInit() {
   Print("═══ PHOENIX V3: Ichimoku Trend DCA ═══");
   
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();
   
   g_point = m_symbol.Point();
   g_p2p = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10.0 : 1.0;
   
   // Parse DCA arrays
   int nTP = ParseDoubleList(InpDCATPs, g_dcaTP);
   int nTrimTP = ParseDoubleList(InpTrimDCATPs, g_trimDcaTP);
   
   Print("DCA Config MAIN: UNLIMITED (Ichimoku S/R + Gap) | Dynamic Lot");
   string lvlName[4] = {"Tenkan","Kijun","KumoTop","KumoBot"};
   for(int i=0; i<nTP; i++)
      PrintFormat("  L%d%s: TP %g pips",
         i+1, (i<4)?" ["+lvlName[i]+"]":" [GAP]", g_dcaTP[i]);
   if(nTP > 0) PrintFormat("  L%d+: TP %g pips (last value)", nTP+1, g_dcaTP[nTP-1]);
   
   Print("DCA Config TRIM: UNLIMITED (Z-Score Entry + Reverse Ichimoku S/R)");
   for(int i=0; i<nTrimTP; i++)
      PrintFormat("  TRIM L%d: TP %g pips", i+1, g_trimDcaTP[i]);
   if(nTrimTP > 0) PrintFormat("  TRIM L%d+: TP %g pips (last value)", nTrimTP+1, g_trimDcaTP[nTrimTP-1]);
   
   Print("Entry: ", InpEntryLot, " lot | DCA cap: ", InpDCARiskPct, "% eq | MinGap: ", InpMinDCAGap, " pips");
   
   if(!m_ichiBase.Init(_Symbol, InpBaseTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod))
      return INIT_FAILED;
      
   m_rsiHandle = iRSI(_Symbol, InpRSITimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(m_rsiHandle == INVALID_HANDLE) {
      Print("Failed to create RSI handle!");
      return INIT_FAILED;
   }
   
   if(InpMTFMode == MTF_TRIPLE) {
      if(!m_ichiMid.Init(_Symbol, InpMidTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod)) return INIT_FAILED;
      if(!m_ichiHigh.Init(_Symbol, InpHighTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod)) return INIT_FAILED;
   }
   
   m_gui.Init();
   
   // PropFirm init
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBalance = g_initialBalance;
   MqlDateTime dtInit; TimeToStruct(TimeCurrent(), dtInit);
   g_lastDay = dtInit.day;
   g_propFirmLocked = false;
   
   Print("PHOENIX V3 Ready.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
   ObjectsDeleteAll(0, "PX3_");
   PrintFormat("PHOENIX V3 Stopped. Cycles: %d | Total Profit: +%.2f USD", g_cycleWins, g_cycleProfit);
}

void OnTick() {
   // New bar check
   datetime curBar = iTime(_Symbol, InpBaseTF, 0);
   bool newBar = (curBar != g_lastBar);
   if(newBar) g_lastBar = curBar;
   
   if(InpExecSpeed == EXEC_BAR_CLOSE && !newBar) return;
   
   m_symbol.RefreshRates();
   
   // Update analysis
   g_ichiState = GetMarketState(m_ichiBase, m_symbol.Bid(), InpBaseTF);
   UpdateMatrixScore();
   
   // PropFirm daily/drawdown guard
   if(InpPropFirmMode) {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      if(dt.day != g_lastDay) {
         g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         g_lastDay = dt.day;
         g_propFirmLocked = false;
      }
      if(ManagePropFirmLimits()) return;
   }
   
   // Core strategy
   ManageHighTFReversal();
   ManagePyramidTrailing();
   ManageDCA();
   ManageFridayClose();
   
   // GUI
   m_gui.Update();
}

//+------------------------------------------------------------------+
//| SECTION 12: GUI DASHBOARD                                        |
//+------------------------------------------------------------------+
class C_GUI {
private:
   string px;
   
   void Rect(string n, int x, int y, int w, int h, color bg, color border) {
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,border);
   }
   
   void Label(string n, string text, int x, int y, color c, int sz) {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
      ObjectSetString(0,n,OBJPROP_FONT,"Consolas"); ObjectSetString(0,n,OBJPROP_TEXT,text);
   }
   
public:
   C_GUI() { px = "PX3_"; }
   
   void Init() {
      if(!InpShowGUI) return;
      Rect(px+"BG1", 20, 40, 380, 300, InpGUIBG, C'255,150,0');
      Label(px+"T1", "PHOENIX V3: TREND DCA", 30, 50, C'255,150,0', 10);
      for(int i=0;i<7;i++) Label(px+"L"+IntegerToString(i), "", 30, 82+i*18, InpGUIText, 7);
      
      Rect(px+"BG2", 410, 40, 480, 300, InpGUIBG, C'0,200,100');
      Label(px+"T2", "📊 DCA STATUS", 420, 50, C'0,200,100', 10);
      for(int i=0;i<7;i++) Label(px+"R"+IntegerToString(i), "", 420, 82+i*18, InpGUIText, 7);
   }
   
   void Update() {
      
      string st;
      switch(g_ichiState) {
         case ICHI_STRONG_UP:   st="STRONG ▲"; break;
         case ICHI_WEAK_UP:     st="WEAK ▲"; break;
         case ICHI_STRONG_DOWN: st="STRONG ▼"; break;
         case ICHI_WEAK_DOWN:   st="WEAK ▼"; break;
         default:               st="RANGE ═"; break;
      }
      
      ObjectSetString(0,px+"L0",OBJPROP_TEXT,"State : "+st);
      ObjectSetString(0,px+"L1",OBJPROP_TEXT,"Score : "+IntegerToString(g_scoreNet)+" / 1000");
      ObjectSetString(0,px+"L2",OBJPROP_TEXT,"BUY   : +"+IntegerToString(g_scoreBuy));
      ObjectSetString(0,px+"L3",OBJPROP_TEXT,"SELL  : "+IntegerToString(g_scoreSell));
      ObjectSetString(0,px+"L4",OBJPROP_TEXT,"Sakata: "+IntegerToString(m_sakata.Detect(InpBaseTF)));
      
      double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
      double dd = (bal>0) ? (bal-eq)/bal*100 : 0;
      ObjectSetString(0,px+"L5",OBJPROP_TEXT,"DD    : "+DoubleToString(dd,1)+"%");
      ObjectSetString(0,px+"L6",OBJPROP_TEXT,"Equity: "+DoubleToString(eq,2));
      
      // DCA Panel
      string dir = (g_direction==1)?"BUY":(g_direction==-1)?"SELL":"---";
      ObjectSetString(0,px+"R0",OBJPROP_TEXT,"Dir   : "+dir+" | DCA L"+IntegerToString(g_dcaLevel)+" (no limit)");
      ObjectSetString(0,px+"R1",OBJPROP_TEXT,"Pos   : "+IntegerToString(CountPositions())+" | Lots: "+DoubleToString(GetTotalLots(),2));
      ObjectSetString(0,px+"R2",OBJPROP_TEXT,"P/L   : "+DoubleToString(GetBasketProfit(),2)+" USD | Avg: "+DoubleToString(GetAvgPrice(),5));
      ObjectSetString(0,px+"R3",OBJPROP_TEXT,"BE: "+(InpEnableBE?"ON":"OFF")+" | Trim: "+(g_trimActive?"ACT":"---")+" | MTP "+IntegerToString(InpMergedTPLevel)+"/"+IntegerToString(InpTrimMTPLevel));
      ObjectSetString(0,px+"R4",OBJPROP_TEXT,"Lot   : Entry "+DoubleToString(InpEntryLot,2)+" | DCA max "+DoubleToString(InpDCARiskPct,1)+"%");
      ObjectSetString(0,px+"R5",OBJPROP_TEXT,"Wins  : "+IntegerToString(g_cycleWins)+" | +"+DoubleToString(g_cycleProfit,1)+" USD");
      ObjectSetString(0,px+"R6",OBJPROP_TEXT,"Wins  : "+IntegerToString(g_cycleWins)+" | +"+DoubleToString(g_cycleProfit,1)+" USD");
      
      ChartRedraw(0);
   }
};

C_GUI m_gui;
// End of Phoenix V3
//+------------------------------------------------------------------+
 