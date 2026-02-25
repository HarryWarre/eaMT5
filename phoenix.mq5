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
input double InpEntryRiskPct     = 0.5;     // % equity cho lệnh Entry
input string InpDCATPs           = "10,15,20,30";          // TP pips mỗi tầng DCA
input double InpDCARiskPct       = 2.0;     // Max % equity cho mỗi DCA
input int    InpDCACooldownBars  = 3;       // Chờ tối thiểu N nến giữa các DCA
input double InpMinDCAGap        = 5.0;     // Khoảng cách tối thiểu  DCA (pips)

input group "========= HÒA VỐN (Breakeven) ========="
input bool   InpEnableBE         = true;    // Bật chế độ hòa vốn
input int    InpBEAfterDCA       = 2;       // Kích hoạt hòa vốn sau DCA level X

input group "========= TỈA LỆNH (Trim) ========="
input bool   InpEnableTrim       = true;    // Bật chế độ tỉa lệnh
input int    InpTrimAfterDCA     = 2;       // Tỉa sau DCA level X
input double InpTrimSLPips       = 10.0;    // SL cho lệnh tỉa (pips)
input double InpTrimTPPips       = 15.0;    // TP cho lệnh tỉa (pips)

input group "========= GỘP TP (Merged TP) ========="
input bool   InpEnableMergedTP   = true;    // Bật gộp TP
input int    InpMergedTPLevel    = 3;       // Lấy TP của DCA level này để đóng hết

input group "========= SESSION & TIME ========="
input bool   InpUseTimeFilter    = true;
input string InpTokyo            = "00:00-09:00";
input string InpLondon           = "07:00-16:00";
input string InpNewYork          = "13:00-22:00";
input bool   InpCloseOnFriday    = true;
input int    InpFridayCloseHour  = 22;

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

// Trạng thái DCA
int      g_direction     = 0;      // 1=BUY, -1=SELL, 0=chờ tín hiệu
int      g_dcaLevel      = 0;      // Tầng DCA hiện tại (0=entry, 1-N=DCA)
datetime g_lastDCATime   = 0;      // Thời gian DCA gần nhất
int      g_cycleWins     = 0;      // Số chu kỳ thắng
double   g_cycleProfit   = 0;      // Tổng profit tích lũy

// Parsed DCA arrays
double   g_dcaTP[];                // TP pips mỗi tầng (parsed, extends with last value)

// Trim tracking
ulong    g_trimTicket    = 0;      // Ticket của lệnh tỉa đang mở
bool     g_trimActive    = false;  // Có lệnh tỉa đang hoạt động

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
int CountPositions(int dir=0) {
   int c = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(dir==0) { c++; continue; }
      if(dir==1 && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) c++;
      if(dir==-1 && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL) c++;
   }
   return c;
}

double GetBasketProfit() {
   double total = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

double GetTotalLots() {
   double total = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      total += PositionGetDouble(POSITION_VOLUME);
   }
   return total;
}

double GetLastEntryPrice() {
   double p = 0; datetime t = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      datetime tt = (datetime)PositionGetInteger(POSITION_TIME);
      if(tt > t) { t = tt; p = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return p;
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
//| SECTION 10: HELPER PARSERS                                       |
//+------------------------------------------------------------------+
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
double GetAvgPrice() {
   double totalCost = 0, totalVol = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "TRIM") >= 0) continue; // Bỏ qua lệnh tỉa
      double v = PositionGetDouble(POSITION_VOLUME);
      double p = PositionGetDouble(POSITION_PRICE_OPEN);
      totalCost += p * v;
      totalVol  += v;
   }
   return (totalVol > 0) ? totalCost / totalVol : 0;
}

// Lấy giá Entry của chu kỳ hiện tại
double GetInitialEntryPrice() {
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol) {
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, "ENTRY") >= 0) {
            return PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }
   return GetAvgPrice(); // Fallback
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

// ==========================================
// 11.1: HÒA VỐN (Breakeven)
// Khi DCA sâu (>= InpBEAfterDCA), canh P/L >= 0 → chốt sạch
// Vol DCA lớn nên chỉ cần giá bounce nhẹ là về hòa vốn
// ==========================================
bool ManageBreakeven() {
   if(!InpEnableBE) return false;
   if(g_dcaLevel < InpBEAfterDCA) return false;
   
   double profit = GetBasketProfit();
   if(profit >= 0) {
      double lots = GetTotalLots();
      int count = CountPositions();
      CloseAllPositions();
      g_cycleWins++;
      g_cycleProfit += profit;
      PrintFormat("⚖️ HÒA VỐN #%d: %.2f USD | L%d | %d pos %.2f lot | Tổng: +%.2f",
         g_cycleWins, profit, g_dcaLevel, count, lots, g_cycleProfit);
      g_direction=0; g_dcaLevel=0; g_lastDCATime=0; g_trimActive=false;
      return true;
   }
   return false;
}

// ==========================================
// 11.2: TỈA LỆNH (Trim)
// Mở lệnh ngược chiều DCA để cắt bớt exposure
// Lệnh tỉa có SL chặt - nếu tỉa hụt thì cắt bỏ ngay
// Khi lệnh tỉa lãi, đóng nó + đóng 1 lệnh DCA lỗ nhiều nhất
// ==========================================
void ManageTrim() {
   if(!InpEnableTrim) return;
   if(g_dcaLevel < InpTrimAfterDCA) return;
   
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double slDist = InpTrimSLPips * g_point * g_p2p;
   double tpDist = InpTrimTPPips * g_point * g_p2p;
   
   // Kiểm tra lệnh tỉa đang mở
   if(g_trimActive) {
      bool found = false;
      for(int i=0; i<PositionsTotal(); i++) {
         ulong tk = PositionGetTicket(i);
         if(tk == g_trimTicket) { found = true; break; }
      }
      if(!found) {
         // Lệnh tỉa đã đóng (SL/TP hit)
         g_trimActive = false;
         g_trimTicket = 0;
         
         // Nếu lệnh tỉa thắng (TP hit) → tìm và đóng 1 lệnh DCA lỗ nhất
         // (MT5 đã đóng lệnh tỉa, giờ tìm DCA lỗ nhất để đóng)
         double worstProfit = 0;
         ulong worstTicket = 0;
         for(int i=0; i<PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
            double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(p < worstProfit) { worstProfit = p; worstTicket = tk; }
         }
         if(worstTicket > 0 && CountPositions() > 1) {
            m_trade.PositionClose(worstTicket);
            g_dcaLevel = MathMax(0, g_dcaLevel - 1);
            PrintFormat("✂️ TỈA: Đóng DCA lỗ nhất #%llu (%.2f USD) | DCA còn L%d",
               worstTicket, worstProfit, g_dcaLevel);
         }
      }
      return; // Đang có lệnh tỉa → không mở thêm
   }
   
   // Mở lệnh tỉa mới: ngược chiều DCA, lot nhỏ, SL/TP chặt
   // Chỉ mở khi có tín hiệu Ichimoku ngược chiều (Sanyaku đảo)
   S_IchiData d0, d1;
   if(!m_ichiBase.Get(0, d0) || !m_ichiBase.Get(1, d1)) return;
   
   // Lot tỉa = nhỏ, dùng % equity giống entry
   double trimEq = AccountInfoDouble(ACCOUNT_EQUITY);
   double trimTV = m_symbol.TickValue();
   double trimLot = m_symbol.LotsMin();
   if(trimTV > 0) trimLot = (trimEq * InpEntryRiskPct / 100.0) / (InpTrimSLPips * trimTV / m_symbol.TickSize() * g_point * g_p2p);
   trimLot = AdjustLots(trimLot);
   bool trimSignal = false;
   
   if(g_direction == 1) {
      // DCA BUY → tỉa = SELL
      // Tín hiệu: TK Dead Cross hoặc giá dưới Kijun
      if(d0.tenkan < d0.kijun && d1.tenkan >= d1.kijun) trimSignal = true;
      if(trimSignal) {
         double sl = bid + slDist;
         double tp = bid - tpDist;
         if(m_trade.Sell(trimLot, _Symbol, bid, sl, tp, "PX TRIM SELL")) {
            g_trimTicket = m_trade.ResultOrder();
            g_trimActive = true;
            PrintFormat("✂️ TRIM SELL: %.2f lot @ %.5f | SL: %.5f | TP: %.5f", trimLot, bid, sl, tp);
         }
      }
   }
   else if(g_direction == -1) {
      // DCA SELL → tỉa = BUY
      if(d0.tenkan > d0.kijun && d1.tenkan <= d1.kijun) trimSignal = true;
      if(trimSignal) {
         double sl = ask - slDist;
         double tp = ask + tpDist;
         if(m_trade.Buy(trimLot, _Symbol, ask, sl, tp, "PX TRIM BUY")) {
            g_trimTicket = m_trade.ResultOrder();
            g_trimActive = true;
            PrintFormat("✂️ TRIM BUY: %.2f lot @ %.5f | SL: %.5f | TP: %.5f", trimLot, ask, sl, tp);
         }
      }
   }
}

// ==========================================
// 11.3: GỘP TP (Merged TP)
// Gộp TP: Lấy TP của DCA level chỉ định để đóng tất cả
// Ví dụ: InpMergedTPLevel=3, TP của L3=30 pips
// → Khi giá chạm TP của L3, đóng toàn bộ lệnh
// ==========================================
void UpdateMergedTP() {
   if(!InpEnableMergedTP) return;
   if(g_dcaLevel < InpMergedTPLevel) return; // Chưa đủ level
   if(CountPositions() < 2) return;
   
   // Lấy TP pips của level chỉ định
   int tpIdx = InpMergedTPLevel - 1; // 0-based
   if(tpIdx >= ArraySize(g_dcaTP)) return;
   double tpPips = g_dcaTP[tpIdx];
   
   // Tìm giá entry của DCA level đó
   // Lệnh DCA level X có comment "PX DCAX"
   string targetComment = "PX DCA" + IntegerToString(InpMergedTPLevel);
   double refPrice = 0;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetString(POSITION_COMMENT) == targetComment) {
         refPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         break;
      }
   }
   if(refPrice <= 0) return;
   
   // Tính TP từ giá entry của level chỉ định
   double tpDist = tpPips * g_point * g_p2p;
   double mergedTP = 0;
   if(g_direction == 1) mergedTP = refPrice + tpDist;
   else if(g_direction == -1) mergedTP = refPrice - tpDist;
   else return;
   
   // Kiểm tra: khi giá chạm mergedTP → đóng tất cả
   double price = (g_direction == 1) ? m_symbol.Bid() : m_symbol.Ask();
   bool tpHit = (g_direction == 1 && price >= mergedTP) || (g_direction == -1 && price <= mergedTP);
   
   if(tpHit) {
      double profit = GetBasketProfit();
      int count = CountPositions();
      CloseAllPositions();
      g_cycleWins++;
      g_cycleProfit += profit;
      PrintFormat("🎯 GỘP TP L%d #%d: %.2f USD | %d pos | Tổng: +%.2f",
         InpMergedTPLevel, g_cycleWins, profit, count, g_cycleProfit);
      g_direction=0; g_dcaLevel=0; g_lastDCATime=0; g_trimActive=false;
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
   int posCount = CountPositions();
   double basketProfit = GetBasketProfit();
   
   // Tự reset trạng thái nếu MT5 đã tự động đóng hết lệnh (VD: hit TP)
   if(posCount == 0 && g_direction != 0) {
      g_direction = 0;
      g_dcaLevel = 0;
      g_lastDCATime = 0;
      g_trimActive = false;
      Print("🔄 Trạng thái đã được reset do không còn lệnh nào (Hit TP/SL).");
   }
   
   // ===========================================================
   // STEP 0: HÒA VỐN - Ưu tiên cao nhất khi DCA sâu
   // ===========================================================
   if(posCount > 0 && ManageBreakeven()) return;
   
   // ===========================================================
   // STEP 1: GỘP TP - Đóng tất cả khi TP của level chỉ định hit
   // ===========================================================
   if(posCount > 0) UpdateMergedTP();
   
   // Cập nhật lại posCount sau khi có thể đã đóng lệnh
   posCount = CountPositions();
   if(posCount == 0 && g_direction != 0) {
      g_direction = 0;
      g_dcaLevel = 0;
      g_lastDCATime = 0;
      g_trimActive = false;
   }
   
   // ===========================================================
   // STEP 1.5: TỈA LỆNH
   // ===========================================================
   if(posCount > 0) ManageTrim();
   
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
      
      int sanyaku = SanyakuState(m_ichiBase, price, InpBaseTF);
      
      if(sanyaku == 1) {
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         double pv = m_symbol.TickValue() * g_p2p; // pip value per lot
         double entryTPpips = (ArraySize(g_dcaTP) > 0) ? g_dcaTP[0] : 10;
         double vol = m_symbol.LotsMin();
         if(pv > 0) vol = (eq * InpEntryRiskPct / 100.0) / (entryTPpips * pv);
         vol = AdjustLots(vol);
         double entryTP = ask + entryTPpips * g_point * g_p2p;
         if(m_trade.Buy(vol, _Symbol, ask, 0, entryTP, "PX ENTRY BUY")) {
            g_direction = 1; g_dcaLevel = 0; g_lastDCATime = TimeCurrent();
            PrintFormat("🟢 ENTRY BUY: %.3f lot @ %.5f | TP: %.5f (%.0f pips)", vol, ask, entryTP, entryTPpips);
         }
      }
      else if(sanyaku == -1) {
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         double pv = m_symbol.TickValue() * g_p2p;
         double entryTPpips = (ArraySize(g_dcaTP) > 0) ? g_dcaTP[0] : 10;
         double vol = m_symbol.LotsMin();
         if(pv > 0) vol = (eq * InpEntryRiskPct / 100.0) / (entryTPpips * pv);
         vol = AdjustLots(vol);
         double entryTP = bid - entryTPpips * g_point * g_p2p;
         if(m_trade.Sell(vol, _Symbol, bid, 0, entryTP, "PX ENTRY SELL")) {
            g_direction = -1; g_dcaLevel = 0; g_lastDCATime = TimeCurrent();
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
   double tpDist = tpPips * g_point * g_p2p;
   
   double avgOld = GetAvgPrice();
   double totalOld = GetTotalLots();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Recovery lot (đơn vị = lots)
   // Formula: lot cần để kéo avg price về sr + tp_dist
   double recoveryLot = 0;
   if(avgOld > 0 && totalOld > 0 && tpDist > 0) {
      if(g_direction == 1)
         recoveryLot = (avgOld - srLevel - tpDist) * totalOld / tpDist;
      else
         recoveryLot = (srLevel - avgOld - tpDist) * totalOld / tpDist;
   }
   if(recoveryLot < 0) recoveryLot = 0;
   
   // Pip value = giá trị 1 pip cho 1 lot
   double pipValue = m_symbol.TickValue() * g_p2p;
   
   // Min lot = entry risk (nhỏ, fallback)
   double minLot = m_symbol.LotsMin();
   if(pipValue > 0) {
      minLot = (equity * InpEntryRiskPct / 100.0) / (tpPips * pipValue);
   }
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
      ok = m_trade.Buy(dcaLot, _Symbol, ask, 0, tp, comment);
   } else if(g_direction == -1) {
      double tp = (tpPips > 0) ? bid - tpDist : 0;
      ok = m_trade.Sell(dcaLot, _Symbol, bid, 0, tp, comment);
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
         
         // Cập nhật TP cho TẤT CẢ các lệnh đang mở để đóng cùng lúc
         for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               double sl = PositionGetDouble(POSITION_SL);
               m_trade.PositionModify(tk, sl, sharedTP);
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
      g_direction = 0; g_dcaLevel = 0; g_lastDCATime = 0;
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
   
   Print("DCA Config: UNLIMITED (Ichimoku S/R + Gap) | Dynamic Lot");
   string lvlName[4] = {"Tenkan","Kijun","KumoTop","KumoBot"};
   for(int i=0; i<nTP; i++)
      PrintFormat("  L%d%s: TP %g pips",
         i+1, (i<4)?" ["+lvlName[i]+"]":" [GAP]", g_dcaTP[i]);
   if(nTP > 0) PrintFormat("  L%d+: TP %g pips (last value)", nTP+1, g_dcaTP[nTP-1]);
   Print("Entry: ", InpEntryRiskPct, "% eq | DCA cap: ", InpDCARiskPct, "% eq | MinGap: ", InpMinDCAGap, " pips");
   
   if(!m_ichiBase.Init(_Symbol, InpBaseTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod))
      return INIT_FAILED;
   
   if(InpMTFMode == MTF_TRIPLE) {
      if(!m_ichiMid.Init(_Symbol, InpMidTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod)) return INIT_FAILED;
      if(!m_ichiHigh.Init(_Symbol, InpHighTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod)) return INIT_FAILED;
   }
   
   m_gui.Init();
   Print("PHOENIX V3 Ready.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
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
   
   // Core strategy
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
      Rect(px+"BG1", 20, 40, 280, 200, InpGUIBG, C'255,150,0');
      Label(px+"T1", "🔥 PHOENIX V3: TREND DCA", 30, 50, C'255,150,0', 10);
      for(int i=0;i<7;i++) Label(px+"L"+IntegerToString(i), "", 30, 72+i*18, InpGUIText, 9);
      
      Rect(px+"BG2", 310, 40, 280, 200, InpGUIBG, C'0,200,100');
      Label(px+"T2", "📊 DCA STATUS", 320, 50, C'0,200,100', 10);
      for(int i=0;i<7;i++) Label(px+"R"+IntegerToString(i), "", 320, 72+i*18, InpGUIText, 9);
   }
   
   void Update() {
      if(!InpShowGUI) return;
      
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
      ObjectSetString(0,px+"R3",OBJPROP_TEXT,"BE: "+(InpEnableBE?"ON":"OFF")+" | Trim: "+(g_trimActive?"ACT":"---")+" | MTP L"+IntegerToString(InpMergedTPLevel));
      ObjectSetString(0,px+"R4",OBJPROP_TEXT,"Risk  : Entry "+DoubleToString(InpEntryRiskPct,1)+"% | DCA "+DoubleToString(InpDCARiskPct,1)+"%");
      ObjectSetString(0,px+"R5",OBJPROP_TEXT,"Wins  : "+IntegerToString(g_cycleWins)+" | +"+DoubleToString(g_cycleProfit,1)+" USD");
      ObjectSetString(0,px+"R6",OBJPROP_TEXT,"Wins  : "+IntegerToString(g_cycleWins)+" | +"+DoubleToString(g_cycleProfit,1)+" USD");
      
      ChartRedraw(0);
   }
};

C_GUI m_gui;
// End of Phoenix V3
//+------------------------------------------------------------------+
