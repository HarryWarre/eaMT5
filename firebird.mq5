//+------------------------------------------------------------------+
//|                                                  firebird.mq5    |
//|               Firebird - Ichimoku Single Trade Analyst Bot       |
//|                     Copyright 2026, DaiViet                      |
//|                                                                  |
//| Chiến lược: Thuận xu hướng Ichimoku (H4 / D1)                    |
//| Entry: Sanyaku Kouten/Gyakuten (Ch.3) trên H4 + D1 Alignment     |
//| Khối lượng: Tính theo % Risk, hoặc Lot cố định                   |
//| Cắt lỗ (SL): Kijun-sen hoặc Tenkan-sen (theo lựa chọn)           |
//| Chốt lời (TP): Tìm đỉnh/đáy Chikou Span cũ trong lịch sử         |
//| ĐẶC ĐIỂM: SINGLE TRADE - MỖI LẦN CHỈ 1 LỆNH DUY NHẤT             |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, DaiViet"
#property version     "4.00"
#property strict
#property description "Ichimoku Single Trade - Based on Professional Analyst Strategy"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

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

enum ENUM_EXEC_SPEED {
   EXEC_BAR_CLOSE = 0,   // Chờ đóng nến (an toàn, tránh fake)
   EXEC_EVERY_TICK = 1   // Mỗi tick (nhanh, rủi ro nhiễu)
};

enum ENUM_TP_MODE {
   TP_MODE_PREV_CHIKOU = 0, // Đỉnh/Đáy cũ của Chikou Span
   TP_MODE_RR_1_1      = 1, // Tỷ lệ Risk:Reward 1:1
   TP_MODE_RR_1_2      = 2  // Tỷ lệ Risk:Reward 1:2
};

enum ENUM_SL_MODE {
   SL_MODE_KIJUN  = 0,      // Cắt lỗ tại Kijun-sen
   SL_MODE_TENKAN = 1       // Cắt lỗ tại Tenkan-sen
};

enum ENUM_RISK_MODE {
   RISK_MODE_FIXED = 0,     // Đi lot cố định
   RISK_MODE_PCT   = 1      // Tính lot theo % tài khoản dựa trên khoảng cách SL
};

//+------------------------------------------------------------------+
//| SECTION 2: INPUT PARAMETERS                                      |
//+------------------------------------------------------------------+
input group "========= CORE ========="
input ENUM_EXEC_SPEED InpExecSpeed     = EXEC_BAR_CLOSE;
input ENUM_TIMEFRAMES InpBaseTF        = PERIOD_H4;
input ENUM_TIMEFRAMES InpTrendTF       = PERIOD_D1;
input int             InpMagicNumber   = 888999;

input group "========= ICHIMOKU ========="
input int    InpTenkanPeriod     = 9;       // Tenkan Period 
input int    InpKijunPeriod      = 26;      // Kijun Period 
input int    InpSenkouPeriod     = 52;      // Senkou Period 
input int    InpKijunFlatBars    = 5;       // Số nến Kijun phẳng = Range 
input double InpMinKumoThick    = 10.0;    // Bề dày Kumo tối thiểu để xác nhận 
input bool   InpUseDailyFilter   = true;    // Lọc cùng chiều với khung Daily

input group "========= QUẢN TRỊ RỦI RO & DCA ========="
input ENUM_RISK_MODE InpRiskMode         = RISK_MODE_PCT;
input double         InpRiskValue        = 2.0;               // % Risk hoặc Lots
input double         InpMinDCAGap        = 200;               // Khoảng cách Point Tối thiểu nhồi DCA
input int            InpMaxDCA           = 5;                 // Số lệnh nhồi tối đa
input int            InpHLLookback       = 50;                // Số nến quá khứ dò tìm Đỉnh/Đáy Chikou làm TP
input bool           InpEnableBE         = true;              // Bật: Cầu hòa sớm khi kẹt lệnh
input int            InpBEAfterDCA       = 3;                 // Kích hoạt cầu hòa sau lệnh DCA thứ mấy
input bool           InpKumoReverseCut   = true;              // Bật: Cắt 100% lệnh nếu Mây Kumo đảo chiều

input group "========= SESSION & TIME ========="
input bool   InpUseTimeFilter    = true;
input string InpTokyo            = "00:00-09:00";
input string InpLondon           = "07:00-16:00";
input string InpNewYork          = "13:00-22:00";
input bool   InpCloseOnFriday    = true;
input int    InpFridayCloseHour  = 22;
input bool   InpUseNewsFilter    = false;  // Lọc tin tức 
input int    InpNewsMinutes      = 30;     // Phút tránh tin trước/sau

input group "========= GUI ========="
input bool   InpShowGUI          = true;
input color  InpGUIBG            = C'15,20,30';
input color  InpGUIText          = C'200,200,200';

input int    InpMaxSpread        = 0;       // Spread tối đa (0 = Tắt, BTC/Indices nên để 0)

//+------------------------------------------------------------------+
//| SECTION 3: GLOBAL OBJECTS & STATE                                |
//+------------------------------------------------------------------+
CTrade      m_trade;
CSymbolInfo m_symbol;
CAccountInfo m_account;

// Ichimoku state
ENUM_ICHI_STATE g_ichiState = ICHI_RANGE;
double   g_point    = 0;
double   g_p2p      = 1;           // Point to Pip multiplier
datetime g_lastBar  = 0;
datetime g_lastTradeBar = 0;       // Đánh dấu nến đã trade để tránh mở nhiều lệnh 1 nến

// Matrix scoring (dùng để confirm tín hiệu hiển thị)
int g_scoreBuy  = 0;
int g_scoreSell = 0;
int g_scoreNet  = 0;

//+------------------------------------------------------------------+
//| SECTION 4: ICHIMOKU MTF DATA ENGINE                              |
//+------------------------------------------------------------------+
struct S_IchiData {
   double tenkan;    
   double kijun;     
   double ssa;       
   double ssb;       
   double chikou;    
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

C_Ichimoku m_ichiBase, m_ichiTrend;

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
//| SECTION 6: SAKATA PATTERNS (Phụ trợ)                              |
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
//| SECTION 7: ICHIMOKU ANALYZER                                     |
//+------------------------------------------------------------------+

// Range check dựa trên Kijun phẳng
bool IsKijunFlat(C_Ichimoku &ichi, int periods) {
   S_IchiData d0;
   if(!ichi.Get(1, d0)) return false; // Luôn dùng bar 1 để xác nhận
   int flat = 0;
   for(int i=2; i<=periods+1; i++) {
      S_IchiData di;
      if(!ichi.Get(i, di)) continue;
      if(MathAbs(d0.kijun - di.kijun) <= 2.0 * g_point * g_p2p)
         flat++;
   }
   return (flat >= periods - 1);
}

// --- TK Cross Entry & Kumo Reverse Logic ---
int SanyakuState(C_Ichimoku &ichiBase, C_Ichimoku &ichiTrend, double price, ENUM_TIMEFRAMES tf) {
   S_IchiData d1, d2;
   if(!ichiBase.Get(1, d1) || !ichiBase.Get(2, d2)) return 0;
   
   // --- DAILY FILTER ---
   bool dailyUp = true, dailyDn = true;
   if(InpUseDailyFilter) {
      S_IchiData dTrend;
      if(ichiTrend.Get(1, dTrend)) {
         double dailyKumoTop = MathMax(dTrend.ssa, dTrend.ssb);
         double dailyKumoBot = MathMin(dTrend.ssa, dTrend.ssb);
         double pTrend1 = iClose(_Symbol, InpTrendTF, 1);
         dailyUp = (pTrend1 > dTrend.kijun) && (pTrend1 > dailyKumoTop) && (dTrend.tenkan > dTrend.kijun);
         dailyDn = (pTrend1 < dTrend.kijun) && (pTrend1 < dailyKumoBot) && (dTrend.tenkan < dTrend.kijun);
      }
   }
   
   double kumoTop = MathMax(d1.ssa, d1.ssb);
   double kumoBot = MathMin(d1.ssa, d1.ssb);
   
   // **Golden Cross:** Nến 1 Tenkan > Kijun, Nến 2 Tenkan <= Kijun
   bool goldenCross = (d1.tenkan > d1.kijun) && (d2.tenkan <= d2.kijun);
   // **Death Cross:** Nến 1 Tenkan < Kijun, Nến 2 Tenkan >= Kijun
   bool deathCross  = (d1.tenkan < d1.kijun) && (d2.tenkan >= d2.kijun);
   
   if(goldenCross && dailyUp && price > kumoTop) return 1;
   if(deathCross && dailyDn && price < kumoBot) return -1;
   
   return 0;
}

// Hàm kiểm tra Mây Kumo đổi màu để cắt lỗ (Dùng d1)
int CheckKumoReversal(C_Ichimoku &ichiBase) {
   if(!InpKumoReverseCut) return 0;
   S_IchiData d1, d2;
   if(!ichiBase.Get(1, d1) || !ichiBase.Get(2, d2)) return 0;
   
   // Kumo Tăng: SSA > SSB. Kumo Giảm: SSA < SSB
   bool kumoBullTwist = (d1.ssa > d1.ssb) && (d2.ssa <= d2.ssb);
   bool kumoBearTwist = (d1.ssa < d1.ssb) && (d2.ssa >= d2.ssb);
   
   if(kumoBullTwist) return 1;  // Lệnh Sell cần đóng do Mây Kumo đảo sang Tăng
   if(kumoBearTwist) return -1; // Lệnh Buy cần đóng do Mây Kumo đảo sang Giảm
   return 0;
}

// market state hiển thị GUI
ENUM_ICHI_STATE GetMarketState(C_Ichimoku &ichi, double price, ENUM_TIMEFRAMES tf) {
   S_IchiData d;
   if(!ichi.Get(1, d)) return ICHI_RANGE; // Use bar 1 to avoid future peeking
   double kumoTop = MathMax(d.ssa, d.ssb);
   double kumoBot = MathMin(d.ssa, d.ssb);
   if(IsKijunFlat(ichi, InpKijunFlatBars)) return ICHI_RANGE;
   if(price >= kumoBot && price <= kumoTop) return ICHI_RANGE;
   if(price > d.tenkan && d.tenkan > d.kijun && d.kijun > kumoTop) return ICHI_STRONG_UP;
   if(price < d.tenkan && d.tenkan < d.kijun && d.kijun < kumoBot) return ICHI_STRONG_DOWN;
   if(price > kumoTop) return ICHI_WEAK_UP;
   if(price < kumoBot) return ICHI_WEAK_DOWN;
   return ICHI_RANGE;
}

// Score matrix hiển thị GUI
void UpdateMatrixScore() {
   double price = iClose(_Symbol, InpBaseTF, 1); // Use bar 1 close price
   S_IchiData d;
   if(!m_ichiBase.Get(1, d)) return; // Use bar 1 data
   
   int bS = 0, sS = 0; 
   if(price > d.kijun) bS += 200; else sS -= 200;
   if(IsKijunFlat(m_ichiBase, InpKijunFlatBars)) { bS /= 2; sS /= 2; }
   
   if(d.tenkan > d.kijun) bS += 250; else sS -= 250;
   
   double chikouVal = iClose(_Symbol, InpBaseTF, 1);
   double pastPrice = iClose(_Symbol, InpBaseTF, InpKijunPeriod + 1);
   if(chikouVal > pastPrice) bS += 150; else sS -= 150;
   
   double kumoTop = MathMax(d.ssa, d.ssb);
   double kumoBot = MathMin(d.ssa, d.ssb);
   if(price > kumoTop) bS += 300; else if(price < kumoBot) sS -= 300;
   
   int sakScore = m_sakata.Score(m_sakata.Detect(InpBaseTF));
   if(sakScore > 0) bS += sakScore; else sS += sakScore;
   
   g_scoreBuy  = MathMax(0, bS);
   g_scoreSell = MathMin(0, sS);
   g_scoreNet  = bS + sS;
}

//+------------------------------------------------------------------+
//| SECTION 8: POSITION HELPERS TÍNH LOT & TP/SL                     |
//+------------------------------------------------------------------+

double g_basketLot = 0.0;
double g_basketPrice = 0.0;
int g_basketType = -1; // 0=Buy, 1=Sell

int CountPositionsAndOrders() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         count++;
      }
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong tk = OrderGetTicket(i);
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol) {
         count++;
      }
   }
   return count;
}

void CloseAllPositionsAndOrders() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         m_trade.PositionClose(tk);
      }
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong tk = OrderGetTicket(i);
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol) {
         m_trade.OrderDelete(tk);
      }
   }
}

// Tính Lot Size dựa trên Risk % và SL khoảng cách (hoặc xài Lot cố định)
double CalculateLotSize(double sl_distance_price) {
   double lot = InpRiskValue;
   
   if(InpRiskMode == RISK_MODE_PCT) {
      double equity = m_account.Equity();
      double risk_amount = equity * (InpRiskValue / 100.0);
      double tick_value = m_symbol.TickValue();
      double tick_size = m_symbol.TickSize();
      
      if(sl_distance_price > 0 && tick_size > 0 && tick_value > 0) {
         double sl_in_ticks = sl_distance_price / tick_size;
         lot = risk_amount / (sl_in_ticks * tick_value);
      }
   }
   
   // Normalize lot
   double min_lot = m_symbol.LotsMin();
   double max_lot = m_symbol.LotsMax();
   double lot_step = m_symbol.LotsStep();
   
   lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return lot;
}

// Lấy đỉnh/đáy Chikou bằng cách dò tìm Close price quá khứ
// Lấy đỉnh/đáy Chikou cũ để đặt TP gộp
double GetPreviousChikouLevel(int direction) {
   double closeArr[];
   if(CopyClose(_Symbol, InpBaseTF, 1, InpHLLookback, closeArr) < InpHLLookback) return 0.0;
   
   int target_idx = -1;
   if(direction == 1) { // BUY -> Đỉnh cũ => MAX
      target_idx = ArrayMaximum(closeArr, 0, InpHLLookback);
   } else {             // SELL -> Đáy cũ => MIN
      target_idx = ArrayMinimum(closeArr, 0, InpHLLookback);
   }
   
   if(target_idx >= 0) return closeArr[target_idx];
   return 0.0;
}

// Lấy Lot cho tất cả các lệnh (Lot Đều / Same Lot)
double GetBasketSharedLot() {
   // Nếu đang có lệnh, lấy y hệt Lot lệnh đầu để nhồi
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         return PositionGetDouble(POSITION_VOLUME);
      }
   }
   
   // Không có lệnh -> Tính Lot Entry mới
   double lot = InpRiskValue;
   if(InpRiskMode == RISK_MODE_PCT) {
       double equity = m_account.Equity();
       double risk_amt = equity * (InpRiskValue / 100.0);
       lot = risk_amt / 1000.0; // Lot tĩnh tương đương sl 100 pip ratio
   }
   
   double min_lot = m_symbol.LotsMin();
   double max_lot = m_symbol.LotsMax();
   double step    = m_symbol.LotsStep();
   
   lot = MathFloor(lot / step) * step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   return lot;
}

// Lấy giá trị xa nhất của Rổ lệnh
double GetBasketLastPrice(int type) {
   double last = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         double pOption = PositionGetDouble(POSITION_PRICE_OPEN);
         if(last == 0) last = pOption;
         if(type == 0 && pOption < last) last = pOption; // Buy -> Giá thấp nhất
         if(type == 1 && pOption > last) last = pOption; // Sell -> Giá cao nhất
      }
   }
   return last;
}

// Lấy giá Entry ban đầu của rổ
double GetInitialEntryPrice() {
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         if(StringFind(PositionGetString(POSITION_COMMENT), "Entry") >= 0) {
            return PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }
   return g_basketPrice; // Fallback
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
      double minGap = InpMinDCAGap * m_symbol.Point();
      if(dir == 1 && lvl > refPrice - minGap) continue;  // S/R cho BUY phải nằm dưới (Support)
      if(dir == -1 && lvl < refPrice + minGap) continue; // S/R cho SELL phải nằm trên (Resistance)
      
      // Remove trùng lặp (nếu khoảng cách < 3 pips thì gộp)
      bool isDup = false;
      for(int j=0; j<validCount; j++) {
         if(MathAbs(validLevels[j] - lvl) < 30.0 * m_symbol.Point()) {
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

// Lấy BreakEven Price của Rổ
void CalcBasketBreakEven() {
   g_basketLot = 0;
   double totalCost = 0;
   g_basketType = -1;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         double pVol = PositionGetDouble(POSITION_VOLUME);
         double pPri = PositionGetDouble(POSITION_PRICE_OPEN);
         
         g_basketLot += pVol;
         totalCost += (pVol * pPri);
         g_basketType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 0 : 1;
      }
   }
   
   if(g_basketLot > 0) g_basketPrice = totalCost / g_basketLot;
   else g_basketPrice = 0;
}

// Cập nhật TP của toàn bộ Rổ bằng Chikou cũ, hoặc Cầu Hòa (Break-Even)
void UpdateBasketTP(int posCount) {
   if(g_basketLot <= 0) return;
   
   double newTP = 0;
   double chikouTP = 0;
   
   // Lấy giá trị Đỉnh hoặc Đáy Chikou làm cản cứng
   if(g_basketType == 0) { // Lệnh Buy => Tìm đỉnh Chikou
      chikouTP = GetPreviousChikouLevel(1);
   } else { // Sinh SELL => Tìm đáy Chikou
      chikouTP = GetPreviousChikouLevel(-1);
   }
   
   // Xử lý Cầu hòa (Break-Even Mode)
   if(InpEnableBE && posCount >= InpBEAfterDCA) {
       // Dời sát giá vốn luôn, + 5 points phí giao dịch
       if(g_basketType == 0) newTP = g_basketPrice + 5.0 * m_symbol.Point();
       else newTP = g_basketPrice - 5.0 * m_symbol.Point();
       PrintFormat("⚖️ CẦU HÒA ACTIVED: Chuyển TP về %f", newTP);
   } else {
       newTP = chikouTP;
       // Fallback an toàn nếu Chikou bị ngược với giá trung bình (đã quá lỗ)
       if(g_basketType == 0 && newTP <= g_basketPrice) newTP = g_basketPrice + 50.0 * m_symbol.Point();
       if(g_basketType == 1 && newTP >= g_basketPrice) newTP = g_basketPrice - 50.0 * m_symbol.Point();
   }
   
   if(newTP == 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         double sl   = PositionGetDouble(POSITION_SL);
         double tp   = PositionGetDouble(POSITION_TP);
         if(MathAbs(tp - newTP) > m_symbol.Point() * 2) {
            m_trade.PositionModify(tk, sl, newTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SECTION 9: CORE DCA & CROSS CUT STRATEGY                         |
//+------------------------------------------------------------------+
void ManageTrades() {
   CalcBasketBreakEven();
   int posCount = CountPositionsAndOrders();
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   
   // --- KUMO REVERSAL CUT LOGIC ---
   if(posCount > 0 && InpKumoReverseCut) {
       int rev = CheckKumoReversal(m_ichiBase);
       if(g_basketType == 0 && rev == -1) { // Đang Buy mà Kumo thủng xuống => Cắt
           Print("🔄 Mây Kumo Giảm xuất hiện (Twist). Đóng sạch BUY Positions để quản trị Rủi ro.");
           CloseAllPositionsAndOrders();
           return;
       }
       if(g_basketType == 1 && rev == 1) { // Đang Sell mà Kumo ngóc lên => Cắt
           Print("🔄 Mây Kumo Tăng xuất hiện (Twist). Đóng sạch SELL Positions để quản trị Rủi ro.");
           CloseAllPositionsAndOrders();
           return;
       }
   }

   if(!m_session.CanTrade()) return;
   if(InpMaxSpread > 0 && (int)m_symbol.Spread() > InpMaxSpread) return;
   if(m_session.IsNewsTime()) return;
   
   // --- DCA PHƯƠNG PHÁP CẢN TĨNH LỊCH SỬ ---
   if(posCount > 0 && posCount < InpMaxDCA) {
       double initPrice = GetInitialEntryPrice();
       if(initPrice <= 0) return;
       
       // Định nghĩa hướng Trade: Buy = 1, Sell = -1
       int dir = (g_basketType == 0) ? 1 : -1;
       
       double srLevels[];
       int numLevels = GetHistoricalSRLevels(m_ichiBase, initPrice, dir, srLevels, 50);
       
       int nextLevel = posCount - 1; // DCA 1 => Index 0
       double srLevel = 0;
       bool touched = false;
       double lastPrice = GetBasketLastPrice(g_basketType);
       double currentPrice = (dir == 1) ? ask : bid;
       
       if(nextLevel < numLevels) {
          srLevel = srLevels[nextLevel];
          
          if(lastPrice > 0) {
             double gap = MathAbs(currentPrice - lastPrice) / m_symbol.Point();
             if(gap < InpMinDCAGap) return;
          }
          
          // Fresh cross: nến trước chưa qua, nến hiện tại vượt qua
          double price = iClose(_Symbol, InpBaseTF, 1);
          double prevPrice = iClose(_Symbol, InpBaseTF, 2);
          if(dir == 1) touched = (price <= srLevel && prevPrice > srLevel);
          if(dir == -1) touched = (price >= srLevel && prevPrice < srLevel);
       }
       else {
          // Hết cản tĩnh -> Vẫn cho phép DCA dự phòng bằng khoảng cách Gap x2
          srLevel = currentPrice;
          
          if(lastPrice > 0) {
             double gap = MathAbs(currentPrice - lastPrice) / m_symbol.Point();
             if(gap >= InpMinDCAGap * 2.0) { 
                if(dir == 1 && currentPrice < lastPrice) touched = true;
                if(dir == -1 && currentPrice > lastPrice) touched = true;
             }
          }
       }
       
       if(touched) {
           double lot = GetBasketSharedLot();
           if(dir == 1) { // Buy DCA
               if(m_trade.Buy(lot, _Symbol, ask, 0, 0, "FB_DCA_BUY")) {
                  CalcBasketBreakEven();
                  UpdateBasketTP(posCount + 1);
               }
           } else { // Sell DCA
               if(m_trade.Sell(lot, _Symbol, bid, 0, 0, "FB_DCA_SELL")) {
                  CalcBasketBreakEven();
                  UpdateBasketTP(posCount + 1);
               }
           }
       }
       return;
   }
   
   // --- FIRST ENTRY LOGIC (TK CROSS) ---
   if(posCount == 0) {
       double price1 = iClose(_Symbol, InpBaseTF, 1);
       int sanyaku = SanyakuState(m_ichiBase, m_ichiTrend, price1, InpBaseTF);
       if(sanyaku == 0) return;
       
       double lot = GetBasketSharedLot();
       
       if(sanyaku == 1) {
          if(m_trade.Buy(lot, _Symbol, ask, 0, 0, "FB_Entry_BUY")) {
             g_lastTradeBar = iTime(_Symbol, InpBaseTF, 1);
             CalcBasketBreakEven();
             UpdateBasketTP(1);
          }
       } else if(sanyaku == -1) {
          if(m_trade.Sell(lot, _Symbol, bid, 0, 0, "FB_Entry_SELL")) {
             g_lastTradeBar = iTime(_Symbol, InpBaseTF, 1);
             CalcBasketBreakEven();
             UpdateBasketTP(1);
          }
       }
   }
}

void ManageFridayClose() {
   if(!m_session.IsFridayClose()) return;
   if(CountPositionsAndOrders() > 0) {
      CloseAllPositionsAndOrders();
      Print("📅 FRIDAY CLOSE - Đã đóng tất cả các lệnh trước cuối tuần.");
   }
}

//+------------------------------------------------------------------+
//| SECTION 10: GUI DASHBOARD VÀ MAIN LOOP                           |
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
   C_GUI() { px = "FB_"; }
   
   void Init() {
      if(!InpShowGUI) return;
      Rect(px+"BG1", 20, 40, 380, 200, InpGUIBG, C'255,150,0');
      Label(px+"T1", "FIREBIRD: SINGLE ICHI 🦅", 30, 50, C'255,150,0', 10);
      for(int i=0;i<5;i++) Label(px+"L"+IntegerToString(i), "", 30, 82+i*18, InpGUIText, 7);
      
      Rect(px+"BG2", 410, 40, 480, 200, InpGUIBG, C'0,200,100');
      Label(px+"T2", "🚀 TRADE STATUS", 420, 50, C'0,200,100', 10);
      for(int i=0;i<5;i++) Label(px+"R"+IntegerToString(i), "", 420, 82+i*18, InpGUIText, 7);
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
      ObjectSetString(0,px+"L2",OBJPROP_TEXT,"Sakata: "+IntegerToString(m_sakata.Detect(InpBaseTF)));
      
      double eq=m_account.Equity();
      ObjectSetString(0,px+"L3",OBJPROP_TEXT,"Equity: "+DoubleToString(eq,2));
      
      // Panel 2
      string modeRisk = (InpRiskMode == RISK_MODE_PCT) ? "PCT %" : "FIXED Lot";
      ObjectSetString(0,px+"R0",OBJPROP_TEXT,"Risk  : "+modeRisk+" -> Val: "+DoubleToString(InpRiskValue,2));
      string beStat = (InpEnableBE) ? "BE On(" + IntegerToString(InpBEAfterDCA) + ")" : "BE Off";
      ObjectSetString(0,px+"R1",OBJPROP_TEXT,"DCA   : Max "+IntegerToString(InpMaxDCA)+" / MinGap "+DoubleToString(InpMinDCAGap,0)+" / "+beStat);
      ObjectSetString(0,px+"R2",OBJPROP_TEXT,"Pos   : "+IntegerToString(CountPositionsAndOrders())+" lệnh | Vol: "+DoubleToString(g_basketLot,2));
      ObjectSetString(0,px+"R3",OBJPROP_TEXT,"Cut   : KumoRev Cut = "+(InpKumoReverseCut?"ON":"OFF"));
      
      ChartRedraw(0);
   }
};

C_GUI m_gui;

//+------------------------------------------------------------------+
//| SECTION 11: MAIN MT5 EVENTS                                      |
//+------------------------------------------------------------------+
int OnInit() {
   Print("═══ FIREBIRD: Ichimoku Single Trade ═══");
   
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();
   
   g_point = m_symbol.Point();
   g_p2p = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10.0 : 1.0;
   
   if(!m_ichiBase.Init(_Symbol, InpBaseTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod))
      return INIT_FAILED;
      
   if(InpUseDailyFilter) {
      if(!m_ichiTrend.Init(_Symbol, InpTrendTF, InpTenkanPeriod, InpKijunPeriod, InpSenkouPeriod))
         return INIT_FAILED;
   }
   
   m_gui.Init();
   Print("FIREBIRD V4 Ready.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "FB_");
   Print("FIREBIRD V4 Stopped.");
}

void OnTick() {
   datetime curBar = iTime(_Symbol, InpBaseTF, 0);
   bool newBar = (curBar != g_lastBar);
   if(newBar) g_lastBar = curBar;
   
   if(InpExecSpeed == EXEC_BAR_CLOSE && !newBar) return;
   
   // Bỏ qua nến chứa lệnh vừa mở để đợi nến tiếp theo mới tìm tín hiệu cờ mới
   if(g_lastTradeBar == curBar) return;
   
   m_symbol.RefreshRates();
   
   g_ichiState = GetMarketState(m_ichiBase, iClose(_Symbol, InpBaseTF, 1), InpBaseTF); // Use bar 1 close price
   UpdateMatrixScore();
   
   ManageTrades();
   ManageFridayClose();
   
   m_gui.Update();
}
//+------------------------------------------------------------------+
