//+------------------------------------------------------------------+
//|                                     UNUS - Ichimoku Single Bot   |
//|                    Triết lý: Ichimoku Kinko Hyo Master System    |
//|                         Copyright 2026, DaiViet                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DaiViet"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_MODE { SIG_SANYAKU=0, SIG_GOLD_CROSS=1, SIG_PULLBACK=2, SIG_ALL=3 };
enum ENUM_DCA_METHOD  { DCA_CLASSIC=0, DCA_2PHASE=1 };
enum ENUM_TP_METHOD   { TP_FIXED_PIPS=0, TP_DYNAMIC_PIPS=1, TP_TARGET_MONEY=2 };
enum ENUM_LOT_MODE    { LOT_PERCENT=0, LOT_FIXED=1 };

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== ICHIMOKU SETTINGS ==="
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_M15;  // Khung thực thi
input int    InpTenkan       = 9;       // Tenkan-sen Period
input int    InpKijun        = 26;      // Kijun-sen Period
input int    InpSenkou       = 52;      // Senkou Span B Period
input ENUM_SIGNAL_MODE InpSignalMode = SIG_ALL; // Chế độ tín hiệu
input int    InpMinStrength  = 3;       // Sức mạnh tín hiệu tối thiểu (1-5)
input bool   InpUseTrendD1   = true;    // Lọc xu hướng D1 (Ichimoku)
input double InpMinKumoWidth = 0;       // Độ dày Kumo tối thiểu % (0-100, 0=Tắt)

input group "=== QUẢN LÝ VỐN ==="
input ENUM_LOT_MODE InpLotMode = LOT_FIXED; // Chế độ Lot
input double InpBaseVol      = 0.01;    // Lot cơ bản
input double InpBaseRisk     = 1.0;     // Rủi ro (%) cho Risk Mode
input int    InpMaxOrders    = 20;      // Số lệnh tối đa
input double InpMaxDrawdownPct = 50.0;  // Drawdown tối đa (%)

input group "=== GRID & DCA ==="
input ENUM_DCA_METHOD InpDcaMethod = DCA_CLASSIC; // DCA Method
input int    InpGridDist     = 100;     // Khoảng cách Grid (pips)
input bool   InpUseATR       = false;   // Grid động theo ATR
input int    InpATRPeriod    = 14;      // ATR chu kỳ
input double InpATRMult      = 1.0;     // ATR hệ số nhân
input int    InpPhase1Orders = 10;      // [2Phase] Số lệnh GĐ 1
input int    InpPhase1Dist   = 100;     // [2Phase] Khoảng cách GĐ 1
input int    InpPhase2Dist   = 150;     // [2Phase] Khoảng cách GĐ 2

input group "=== MARTINGALE (3 Levels) ==="
input int    InpMartStart1   = 4;       // Level 1: Từ lệnh N
input double InpMartMult1    = 1.1;     // Level 1: Hệ số
input int    InpMartStart2   = 8;       // Level 2: Từ lệnh N
input double InpMartMult2    = 1.2;     // Level 2: Hệ số
input int    InpMartStart3   = 12;      // Level 3: Từ lệnh N
input double InpMartMult3    = 1.5;     // Level 3: Hệ số

input group "=== SL & TP ==="
input int    InpStopLoss     = 500;     // Stop Loss (pips, 0=Tắt)
input int    InpFirstTP      = 200;     // TP lệnh đầu tiên (pips, 0=Tắt)
input ENUM_TP_METHOD InpTPMethod = TP_FIXED_PIPS; // Phương pháp TP (Gộp)
input int    InpSingleTP     = 300;     // TP đơn (pips) khi <MergeStart
input int    InpMergeStart   = 3;       // Gộp từ lệnh N
input int    InpMergeDist    = 10;      // Gộp: Lợi nhuận (pips)
input double InpTargetMoney  = 10.0;    // Gộp: Lợi nhuận ($)
input int    InpBreakevenStart = 0;     // Hòa vốn từ lệnh N (0=Tắt)
input int    InpBreakevenPips  = 10;    // Hòa vốn: Pips lợi nhuận

input group "=== BỘ LỌC & BẢO VỆ ==="
input double InpDailyProfitTarget = 1.0; // Mục tiêu lợi nhuận ngày (%)
input bool   InpUseDayFilter = true;    // Lọc ngày (T2-T6)
input bool   InpTradeFriday  = false;   // Giao dịch thứ 6
input bool   InpCloseAtEndDay = false;  // Đóng lệnh cuối ngày
input int    InpEndDayHour   = 23;      // Giờ đóng cuối ngày
input int    InpEndDayMinute = 50;      // Phút đóng cuối ngày
input bool   InpUseNewsFilter = false;  // Lọc tin tức
input int    InpNewsMinutes  = 30;      // Phút tránh tin
input int    InpSLAfterLast  = 0;       // SL sau lệnh cuối (pips, 0=Tắt)

input group "=== TIME TRADING (VIETNAM GMT+7) ==="
input bool   InpUseTimeSlot  = true;    // Sử dụng khung giờ
input string InpT1Start      = "09:00"; // Slot 1: Bắt đầu
input string InpT1End        = "17:00"; // Slot 1: Kết thúc
input string InpT2Start      = "22:00"; // Slot 2: Bắt đầu
input string InpT2End        = "03:00"; // Slot 2: Kết thúc
input bool   InpUseNoTimeSlot = false;  // Khung giờ nghỉ
input string InpNT1Start     = "17:00"; // Nghỉ 1: Bắt đầu
input string InpNT1End       = "21:00"; // Nghỉ 1: Kết thúc
input int    InpServerGMTOffset = 2;    // Múi giờ Server

input int    InpMagic        = 226100;  // Magic Number

//+------------------------------------------------------------------+
//| BIẾN TOÀN CỤC                                                   |
//+------------------------------------------------------------------+
CTrade Trade;
int    hIchi, hIchiD1, hATR;
bool   g_stoppedToday = false;
int    g_lastDay = -1;
int    g_lastDealCount = 0;
double g_lastDayProfit = 0;
double g_pt, g_p2p;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   Trade.SetExpertMagicNumber(InpMagic);
   
   hIchi   = iIchimoku(_Symbol, InpTimeframe, InpTenkan, InpKijun, InpSenkou);
   hIchiD1 = iIchimoku(_Symbol, PERIOD_D1, InpTenkan, InpKijun, InpSenkou);
   hATR    = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   
   if(hIchi==INVALID_HANDLE || hIchiD1==INVALID_HANDLE || hATR==INVALID_HANDLE) {
      Print("Unus: Lỗi khởi tạo indicator!"); return INIT_FAILED;
   }
   
   g_pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_p2p = (digits==3 || digits==5) ? 10.0 : 1.0;
   
   CreatePanel();
   Print("Unus: Ichimoku Bot sẵn sàng trên ", _Symbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   IndicatorRelease(hIchi); IndicatorRelease(hIchiD1); IndicatorRelease(hATR);
   ObjectsDeleteAll(0, "UN_");
   Print("Unus: Thoát. Reason=", reason);
}

//+------------------------------------------------------------------+
//| GET ICHIMOKU VALUES                                              |
//+------------------------------------------------------------------+
bool GetIchi(int handle, int shift, double &tenkan, double &kijun, double &sa, double &sb, double &chikou) {
   double t[1],k[1],a[1],b[1],c[1];
   if(CopyBuffer(handle,0,shift,1,t)<1) return false;
   if(CopyBuffer(handle,1,shift,1,k)<1) return false;
   if(CopyBuffer(handle,2,shift,1,a)<1) return false;
   if(CopyBuffer(handle,3,shift,1,b)<1) return false;
   if(CopyBuffer(handle,4,shift,1,c)<1) return false;
   tenkan=t[0]; kijun=k[0]; sa=a[0]; sb=b[0]; chikou=c[0];
   return true;
}

//+------------------------------------------------------------------+
//| SIGNAL STRENGTH (1-5)                                            |
//+------------------------------------------------------------------+
int CalcStrength(bool isBuy) {
   double t,k,sa,sb,ch;
   if(!GetIchi(hIchi,0,t,k,sa,sb,ch)) return 0;
   double price = iClose(_Symbol, InpTimeframe, 0);
   double price26 = iClose(_Symbol, InpTimeframe, InpKijun);
   double kumoW = MathAbs(sa-sb);
   double kumoWidthPct = (price>0) ? (kumoW/price)*100.0 : 0; // % of price
   int s=0;
   if(isBuy) {
      if(t>k) s++;
      if(ch>price26) s++;
      if(price>MathMax(sa,sb)) s++;
      if(kumoWidthPct>=InpMinKumoWidth) s++;
      if(ch>t && t>k && k>sa && sa>sb) s++;
   } else {
      if(t<k) s++;
      if(ch<price26) s++;
      if(price<MathMin(sa,sb)) s++;
      if(kumoWidthPct>=InpMinKumoWidth) s++;
      if(ch<t && t<k && k<sa && sa<sb) s++;
   }
   return s;
}

//+------------------------------------------------------------------+
//| SANYAKU KOUTEN / GYAKUTEN                                        |
//+------------------------------------------------------------------+
int CheckSanyaku() {
   double t0,k0,sa0,sb0,ch0;
   if(!GetIchi(hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
   double price = iClose(_Symbol, InpTimeframe, 0);
   double price26 = iClose(_Symbol, InpTimeframe, InpKijun);
   if(t0>k0 && ch0>price26 && price>MathMax(sa0,sb0)) return 1;
   if(t0<k0 && ch0<price26 && price<MathMin(sa0,sb0)) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| GOLD / DEAD CROSS                                                |
//+------------------------------------------------------------------+
int CheckCross() {
   double t0,k0,sa0,sb0,ch0, t1,k1,sa1,sb1,ch1;
   if(!GetIchi(hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
   if(!GetIchi(hIchi,1,t1,k1,sa1,sb1,ch1)) return 0;
   if(t0>k0 && t1<=k1) return 1;   // Gold Cross
   if(t0<k0 && t1>=k1) return -1;  // Dead Cross
   return 0;
}

//+------------------------------------------------------------------+
//| PULLBACK                                                         |
//+------------------------------------------------------------------+
int CheckPullback() {
   double t0,k0,sa0,sb0,ch0;
   if(!GetIchi(hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
   double price = iClose(_Symbol, InpTimeframe, 0);
   double price1 = iClose(_Symbol, InpTimeframe, 1);
   double tol = 20*g_pt;
   double kumoTop=MathMax(sa0,sb0), kumoBot=MathMin(sa0,sb0);
   if(price>kumoTop && t0>k0) {
      if(price1<=t0+tol && price>t0) return 1;
      if(price1<=k0+tol && price>k0 && price1>kumoTop) return 1;
   }
   if(price<kumoBot && t0<k0) {
      if(price1>=t0-tol && price<t0) return -1;
      if(price1>=k0-tol && price<k0 && price1<kumoBot) return -1;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| KUMO BREAKOUT                                                    |
//+------------------------------------------------------------------+
int CheckKumoBreak() {
   double t0,k0,sa0,sb0,ch0;
   if(!GetIchi(hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
   double p0=iClose(_Symbol,InpTimeframe,0), p1=iClose(_Symbol,InpTimeframe,1);
   double top=MathMax(sa0,sb0), bot=MathMin(sa0,sb0);
   if(p0>top && p1<=top) return 1;
   if(p0<bot && p1>=bot) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| RANGE MARKET DETECTION                                           |
//+------------------------------------------------------------------+
bool IsRange() {
   double t0,k0,sa0,sb0,ch0, t1,k1,sa1,sb1,ch1, t2,k2,sa2,sb2,ch2;
   if(!GetIchi(hIchi,0,t0,k0,sa0,sb0,ch0)) return true;
   if(!GetIchi(hIchi,1,t1,k1,sa1,sb1,ch1)) return true;
   if(!GetIchi(hIchi,2,t2,k2,sa2,sb2,ch2)) return true;
   bool flat = MathAbs(k0-k1)<5*g_pt && MathAbs(k1-k2)<5*g_pt;
   bool xback = (t0>k0 && t2<k2) || (t0<k0 && t2>k2);
   return (flat && xback);
}

//+------------------------------------------------------------------+
//| D1 TREND FILTER                                                  |
//+------------------------------------------------------------------+
int GetD1Trend() {
   if(!InpUseTrendD1) return 0;
   double t0,k0,sa0,sb0,ch0;
   if(!GetIchi(hIchiD1,0,t0,k0,sa0,sb0,ch0)) return 0;
   double price = iClose(_Symbol, PERIOD_D1, 0);
   if(price>MathMax(sa0,sb0) && t0>k0) return 1;
   if(price<MathMin(sa0,sb0) && t0<k0) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| MASTER SIGNAL                                                    |
//+------------------------------------------------------------------+
int GetSignal() {
   if(IsRange()) return 0;
   int d1=GetD1Trend(), sig=0;
   
   if(InpSignalMode==SIG_SANYAKU || InpSignalMode==SIG_ALL) {
      sig=CheckSanyaku();
      if(sig!=0 && CalcStrength(sig>0)>=InpMinStrength && (d1==0||d1==sig)) return sig;
   }
   if(InpSignalMode==SIG_GOLD_CROSS || InpSignalMode==SIG_ALL) {
      sig=CheckCross();
      if(sig!=0 && CalcStrength(sig>0)>=InpMinStrength && (d1==0||d1==sig)) return sig;
   }
   if(InpSignalMode==SIG_PULLBACK || InpSignalMode==SIG_ALL) {
      sig=CheckPullback();
      if(sig!=0 && CalcStrength(sig>0)>=InpMinStrength && (d1==0||d1==sig)) return sig;
   }
   if(InpSignalMode==SIG_ALL) {
      sig=CheckKumoBreak();
      if(sig!=0 && CalcStrength(sig>0)>=MathMax(InpMinStrength,3) && (d1==0||d1==sig)) return sig;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| OnTick - Xử lý chính                                             |
//+------------------------------------------------------------------+
void OnTick() {
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   // Reset ngày
   datetime now=TimeCurrent(); MqlDateTime dt; TimeToStruct(now,dt);
   if(dt.day!=g_lastDay) { g_stoppedToday=false; g_lastDay=dt.day; g_lastDealCount=0; g_lastDayProfit=0; }
   CheckNewDeals();
   if(g_stoppedToday) return;
   
   // End of day
   if(InpCloseAtEndDay && dt.hour==InpEndDayHour && dt.min>=InpEndDayMinute) { CloseAll(); return; }
   
   // Drawdown
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal>0 && (bal-eq)/bal*100.0>=InpMaxDrawdownPct) { CloseAll(); g_stoppedToday=true; Print("Unus: EMERGENCY STOP! DD=",(bal-eq)/bal*100.0,"%"); return; }
   
   // Đếm vị thế
   int bCnt=0, sCnt=0; double bVol=0,sVol=0,bProd=0,sProd=0,lowBuy=0,highSell=0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk=PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) {
         double v=PositionGetDouble(POSITION_VOLUME), op=PositionGetDouble(POSITION_PRICE_OPEN);
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) { bCnt++; bVol+=v; bProd+=op*v; if(lowBuy==0||op<lowBuy) lowBuy=op; }
         else { sCnt++; sVol+=v; sProd+=op*v; if(highSell==0||op>highSell) highSell=op; }
      }
   }
   
   // SL After Last
   if(InpSLAfterLast>0) {
      if((bCnt>0 && ask<lowBuy-InpSLAfterLast*g_p2p*g_pt) || (sCnt>0 && bid>highSell+InpSLAfterLast*g_p2p*g_pt)) {
         CloseAll(); g_stoppedToday=true; Print("Unus: SL After Last hit!"); return;
      }
   }
   
   // Quản lý TP
   ManageTP(POSITION_TYPE_BUY, bCnt, bVol, bProd);
   ManageTP(POSITION_TYPE_SELL, sCnt, sVol, sProd);
   
   // Bộ lọc thời gian
   bool hasPos=(bCnt+sCnt>0);
   if(!CheckTime(hasPos,dt) || !CheckDailyProfit(hasPos)) return;
   
   // DCA entries
   double bDist=GetGridDist(bCnt), sDist=GetGridDist(sCnt);
   double slDist = (InpStopLoss>0) ? InpStopLoss*g_p2p*g_pt : 0;
   if(bCnt>0 && bCnt<InpMaxOrders && ask<(lowBuy-bDist*g_p2p*g_pt)) {
      double sl = (slDist>0) ? ask-slDist : 0;
      Trade.Buy(GetVol(bCnt+1,bVol), _Symbol, 0, sl, 0, "Unus DCA B"+(string)(bCnt+1));
   }
   if(sCnt>0 && sCnt<InpMaxOrders && bid>(highSell+sDist*g_p2p*g_pt)) {
      double sl = (slDist>0) ? bid+slDist : 0;
      Trade.Sell(GetVol(sCnt+1,sVol), _Symbol, 0, sl, 0, "Unus DCA S"+(string)(sCnt+1));
   }
   
   // First entry
   if(bCnt==0 && sCnt==0) {
      int sig = GetSignal();
      if(sig==0) { UpdatePanel(0,bCnt,sCnt,0); return; }
      int str = CalcStrength(sig>0);
      double tpDist = (InpFirstTP>0) ? InpFirstTP*g_p2p*g_pt : 0;
      if(sig==1) {
         double sl = (slDist>0) ? ask-slDist : 0;
         double tp = (tpDist>0) ? ask+tpDist : 0;
         Trade.Buy(InpBaseVol, _Symbol, 0, sl, tp, "Unus BUY S"+IntegerToString(str));
         Print("Unus: BUY Strength=", str, " SL=", sl, " TP=", tp);
      }
      else if(sig==-1) {
         double sl = (slDist>0) ? bid+slDist : 0;
         double tp = (tpDist>0) ? bid-tpDist : 0;
         Trade.Sell(InpBaseVol, _Symbol, 0, sl, tp, "Unus SELL S"+IntegerToString(str));
         Print("Unus: SELL Strength=", str, " SL=", sl, " TP=", tp);
      }
   }
   
   // Update panel
   double pnl=0;
   for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==InpMagic) pnl+=PositionGetDouble(POSITION_PROFIT); }
   UpdatePanel(GetD1Trend(), bCnt, sCnt, pnl);
}

//+------------------------------------------------------------------+
//| TAKE PROFIT                                                      |
//+------------------------------------------------------------------+
void ManageTP(long type, int cnt, double vol, double prod) {
   if(cnt==0) return;
   double price=(type==POSITION_TYPE_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double avg=prod/vol;
   
   // Breakeven
   if(InpBreakevenStart>0 && cnt>=InpBreakevenStart) {
      double pp=(type==POSITION_TYPE_BUY)?(price-avg)/(g_pt*g_p2p):(avg-price)/(g_pt*g_p2p);
      if(pp>=InpBreakevenPips) { CloseByType(type); Print("Unus: Hòa vốn ",type==POSITION_TYPE_BUY?"BUY":"SELL"," +",DoubleToString(pp,1),"pips"); return; }
   }
   
   // Merge TP
   if(cnt>=InpMergeStart) {
      double tpPips=InpMergeDist;
      if(InpTPMethod==TP_DYNAMIC_PIPS) tpPips=MathMax(2.0,InpMergeDist/(double)cnt);
      else if(InpTPMethod==TP_TARGET_MONEY) {
         double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         if(tv>0 && vol>0) tpPips=MathMax(2.0,(InpTargetMoney/(vol*tv))*ts/g_pt/g_p2p);
      }
      double tp=(type==POSITION_TYPE_BUY)?avg+tpPips*g_p2p*g_pt:avg-tpPips*g_p2p*g_pt;
      for(int i=PositionsTotal()-1;i>=0;i--) {
         ulong tk=PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_TYPE)==type)
            if(MathAbs(PositionGetDouble(POSITION_TP)-tp)>g_pt) Trade.PositionModify(tk, PositionGetDouble(POSITION_SL), tp);
      }
   } else {
      for(int i=PositionsTotal()-1;i>=0;i--) {
         ulong tk=PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_TYPE)==type) {
            double op=PositionGetDouble(POSITION_PRICE_OPEN);
            double trg=(type==POSITION_TYPE_BUY)?op+InpSingleTP*g_p2p*g_pt:op-InpSingleTP*g_p2p*g_pt;
            if(MathAbs(PositionGetDouble(POSITION_TP)-trg)>g_pt) Trade.PositionModify(tk, PositionGetDouble(POSITION_SL), trg);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| HELPERS                                                          |
//+------------------------------------------------------------------+
void CloseByType(long type) {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong tk=PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetInteger(POSITION_TYPE)==type)
         Trade.PositionClose(tk);
   }
}

void CloseAll() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong tk=PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         Trade.PositionClose(tk);
   }
}

double GetGridDist(int cnt) {
   if(InpDcaMethod==DCA_2PHASE) return (cnt<InpPhase1Orders)?InpPhase1Dist:InpPhase2Dist;
   if(InpUseATR) {
      double atr[]; if(CopyBuffer(hATR,0,0,1,atr)>0) return (atr[0]/(g_pt*g_p2p))*InpATRMult;
   }
   return InpGridDist;
}

double CheckVolume(double vol) {
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   vol=MathFloor(vol/st)*st; if(vol<mn) vol=mn; if(vol>mx) vol=mx; return vol;
}

double GetVol(int ord, double sumVol) {
   double m=1.0;
   if(ord>=InpMartStart3) m=InpMartMult3; else if(ord>=InpMartStart2) m=InpMartMult2; else if(ord>=InpMartStart1) m=InpMartMult1; else return InpBaseVol;
   return CheckVolume(sumVol*m);
}

bool CheckDailyProfit(bool hasPos) {
   if(InpDailyProfitTarget<=0 || hasPos) return true;
   double base=AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_lastDayProfit>=base*(InpDailyProfitTarget/100.0)) return false;
   return true;
}

void CheckNewDeals() {
   HistorySelect(iTime(_Symbol,PERIOD_D1,0), TimeCurrent());
   int total=HistoryDealsTotal();
   if(total>g_lastDealCount) {
      for(int i=g_lastDealCount; i<total; i++) {
         ulong tk=HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(tk,DEAL_MAGIC)==InpMagic && HistoryDealGetString(tk,DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(tk,DEAL_ENTRY)==DEAL_ENTRY_OUT)
            g_lastDayProfit+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
      }
      g_lastDealCount=total;
   }
}

bool InTimeRange(int h, int m, string start, string end) {
   if(StringLen(start)<5||StringLen(end)<5) return false;
   int sh=(int)StringToInteger(StringSubstr(start,0,2)), sm=(int)StringToInteger(StringSubstr(start,3,2));
   int eh=(int)StringToInteger(StringSubstr(end,0,2)), em=(int)StringToInteger(StringSubstr(end,3,2));
   int now=h*60+m, s=sh*60+sm, e=eh*60+em;
   return (s<=e)?(now>=s && now<e):(now>=s || now<e);
}

bool CheckTime(bool hasPos, MqlDateTime &dt) {
   int dow=dt.day_of_week;
   if(InpUseDayFilter && (dow==0||dow==6)) return false;
   if(hasPos) return true;
   if(!InpTradeFriday && dow==5) return false;
   if(InpUseNewsFilter && IsNewsTime()) return false;
   int h=dt.hour, m=dt.min;
   if(InpUseNoTimeSlot && InTimeRange(h,m,InpNT1Start,InpNT1End)) return false;
   if(InpUseTimeSlot) return InTimeRange(h,m,InpT1Start,InpT1End)||InTimeRange(h,m,InpT2Start,InpT2End);
   return true;
}

bool IsNewsTime() {
   if(!InpUseNewsFilter) return false;
   datetime now=TimeCurrent(); MqlCalendarValue v[];
   if(!CalendarValueHistory(v, now-InpNewsMinutes*60, now+InpNewsMinutes*60)) return false;
   string b=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE), q=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT);
   if(b=="") { b=StringSubstr(_Symbol,0,3); q=StringSubstr(_Symbol,3,3); }
   for(int i=0; i<ArraySize(v); i++) {
      MqlCalendarEvent e; MqlCalendarCountry c;
      if(CalendarEventById(v[i].event_id,e) && CalendarCountryById(e.country_id,c))
         if(e.importance==CALENDAR_IMPORTANCE_HIGH && (c.currency==b||c.currency==q)) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| GUI PANEL                                                        |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int sz, bool center=false) {
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,sz);
   ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI Semibold");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR, center?ANCHOR_UPPER:ANCHOR_LEFT_UPPER);
}

void CreatePanel() {
   int x=10, y=30, w=220, h=110;
   ObjectCreate(0,"UN_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"UN_BG",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,"UN_BG",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,"UN_BG",OBJPROP_XSIZE,w);
   ObjectSetInteger(0,"UN_BG",OBJPROP_YSIZE,h);
   ObjectSetInteger(0,"UN_BG",OBJPROP_BGCOLOR,C'20,22,30');
   ObjectSetInteger(0,"UN_BG",OBJPROP_BORDER_COLOR,C'60,130,200');
   ObjectSetInteger(0,"UN_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"UN_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   
   CreateLabel("UN_TITLE","⛩ UNUS v1.0",x+w/2,y+6,C'100,180,255',11,true);
   CreateLabel("UN_SYM",  _Symbol,       x+10, y+28, clrWhite, 10);
   CreateLabel("UN_TREND","▬ --",         x+10, y+50, clrGray, 10);
   CreateLabel("UN_ORDERS","B:0 / S:0",   x+10, y+70, clrGray, 9);
   CreateLabel("UN_PNL",  "P/L: 0.00",    x+10, y+88, clrGray, 9);
}

void UpdatePanel(int trend, int bCnt, int sCnt, double pnl) {
   string tText = (trend>0)?"▲ UPTREND":(trend<0)?"▼ DOWNTREND":"▬ NEUTRAL";
   color  tClr  = (trend>0)?C'0,200,120':(trend<0)?C'255,80,80':clrGray;
   
   ObjectSetString(0,"UN_TREND",OBJPROP_TEXT,tText);
   ObjectSetInteger(0,"UN_TREND",OBJPROP_COLOR,tClr);
   ObjectSetString(0,"UN_ORDERS",OBJPROP_TEXT,"B:"+IntegerToString(bCnt)+" / S:"+IntegerToString(sCnt));
   ObjectSetString(0,"UN_PNL",OBJPROP_TEXT,"P/L: "+DoubleToString(pnl,2));
   ObjectSetInteger(0,"UN_PNL",OBJPROP_COLOR,(pnl>=0)?C'0,200,120':C'255,80,80');
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
