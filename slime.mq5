//+------------------------------------------------------------------+
//|                              SLIME MOTHERSHIP - Core Base        |
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
input group "=== SLIME MOTHERSHIP (CORE) ==="
input string InpSymbols      = "XAUUSD,EURUSD"; // Danh sách cặp Mẹ chạy (dấu phẩy)
input int    InpMagicBase    = 9000000;  // Base Magic Number
input double InpBaseVol      = 0.01;     // Lot cơ bản của Mẹ
input double InpSpawnThreshold = 1000.0; // Mốc LN để Mẹ đẻ 1 Slime ($)
input double InpChildCapital   = 100.0;  // Vốn cấp cho mỗi Slime con ($)
input double InpChildMinEquity = 20.0;   // Equity tối thiểu để Slime con tồn tại ($)
input double InpTaxRate        = 0.5;    // Thuế thu từ Slime Con (50%)
input int    InpMaxSlimes    = 10;       // Giới hạn max số Slime Con

input group "=== SLIME CHILD SETTINGS ==="
input string InpChildTimeframes = "M5,M15,H1"; // Danh sách TF cho Slime Con (dấu phẩy)
input double InpChildVol        = 0.01;        // Lot cơ bản của Slime Con
input int    InpChildMinGrid    = 20;          // Cự ly Grid Min (pips)
input int    InpChildMaxGrid    = 50;          // Cự ly Grid Max (pips)
input double InpChildTPRatio    = 1.0;         // Tỷ lệ TP so với Grid (VD: 1.0 = TP bằng Grid)

input group "=== MOTHERSHIP ICHIMOKU ==="
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_M15;  // Khung thực thi Mẹ
input int    InpTenkan       = 9;
input int    InpKijun        = 26;
input int    InpSenkou       = 52;
input ENUM_SIGNAL_MODE InpSignalMode = SIG_ALL;
input int    InpMinStrength  = 3;
input bool   InpUseTrendD1   = true;
input double InpMinKumoWidth = 0;

input group "=== QUẢN LÝ VỐN ==="
input ENUM_LOT_MODE InpLotMode = LOT_FIXED; // Chế độ Lot
input double InpBaseRisk     = 1.0;     // Rủi ro (%) cho Risk Mode
input int    InpMaxOrders    = 20;      // Số lệnh tối đa / cặp
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

//+------------------------------------------------------------------+
//| GLOBAL HELPERS                                                   |
//+------------------------------------------------------------------+
double g_GlobalProfit = 0;
double g_GlobalFloating = 0;

bool InTimeRange(int h, int m, string start, string end) {
   if(StringLen(start)<5||StringLen(end)<5) return false;
   int sh=(int)StringToInteger(StringSubstr(start,0,2)), sm=(int)StringToInteger(StringSubstr(start,3,2));
   int eh=(int)StringToInteger(StringSubstr(end,0,2)), em=(int)StringToInteger(StringSubstr(end,3,2));
   int now=h*60+m, s=sh*60+sm, e=eh*60+em;
   return (s<=e)?(now>=s && now<e):(now>=s || now<e);
}

//+------------------------------------------------------------------+
//| CLASS CShogunBot (per symbol)                                    |
//+------------------------------------------------------------------+
class CSlimeMotherBot {
private:
   string m_name;
   string m_symbol;
   int    m_magic;
   CTrade m_trade;
   int    m_hIchi, m_hIchiD1, m_hATR;
   double m_pt, m_p2p;
   
   // State
   bool   m_stoppedToday;
   int    m_lastDay, m_lastDealCount;
   
   // Stats / Log
   double m_dayProfit;       // Lợi nhuận hôm nay (đã đóng)
   int    m_dayWins;         // Số lần thắng hôm nay
   int    m_dayLosses;       // Số lần thua hôm nay
   int    m_totalTrades;     // Tổng trade
   int    m_totalWins;       // Tổng thắng
   double m_totalProfit;     // Tổng lợi nhuận
   // Bot Settings
   ENUM_TIMEFRAMES m_timeframe;
   double m_vol;
   double m_gridDistPips;
   double m_tpRatio;

public:
   CSlimeMotherBot() { m_stoppedToday=false; m_lastDay=-1; m_lastDealCount=0; m_dayProfit=0; m_dayWins=0; m_dayLosses=0; m_totalTrades=0; m_totalWins=0; m_totalProfit=0; m_hIchi=INVALID_HANDLE; m_hIchiD1=INVALID_HANDLE; m_hATR=INVALID_HANDLE; }
   
   bool Init(string name, string symbol, int magic, ENUM_TIMEFRAMES tf, double vol, double gridPips, double tpRatio) {
      m_name = name;
      m_symbol=symbol; m_magic=magic;
      m_timeframe = tf;
      m_vol = vol;
      m_gridDistPips = gridPips;
      m_tpRatio = tpRatio;
      
      m_trade.SetExpertMagicNumber(m_magic);
      if(!SymbolSelect(m_symbol,true)) { Print("[SLIME_MOTHERSHIP] Lỗi select ",m_symbol); return false; }
      
      m_hIchi  = iIchimoku(m_symbol, m_timeframe, InpTenkan, InpKijun, InpSenkou);
      m_hIchiD1= iIchimoku(m_symbol, PERIOD_D1, InpTenkan, InpKijun, InpSenkou);
      m_hATR   = iATR(m_symbol, m_timeframe, InpATRPeriod);
      
      if(m_hIchi==INVALID_HANDLE||m_hIchiD1==INVALID_HANDLE||m_hATR==INVALID_HANDLE) {
         Print("[SLIME_MOTHERSHIP] Lỗi tạo indicator cho ",m_symbol); return false;
      }
      m_pt  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int d = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_p2p = (d==3||d==5)?10.0:1.0;
      
      Print("[SLIME_MOTHERSHIP] ✓ ", m_symbol, " Magic=", m_magic, " Pt=", m_pt, " P2P=", m_p2p);
      return true;
   }
   
   void Deinit() { IndicatorRelease(m_hIchi); IndicatorRelease(m_hIchiD1); IndicatorRelease(m_hATR); }
   
   //--- ICHIMOKU HELPERS ---
   bool GetIchi(int handle, int shift, double &t, double &k, double &sa, double &sb, double &ch) {
      double tb[1],kb[1],ab[1],bb[1],cb[1];
      if(CopyBuffer(handle,0,shift,1,tb)<1) return false;
      if(CopyBuffer(handle,1,shift,1,kb)<1) return false;
      if(CopyBuffer(handle,2,shift,1,ab)<1) return false;
      if(CopyBuffer(handle,3,shift,1,bb)<1) return false;
      if(CopyBuffer(handle,4,shift,1,cb)<1) return false;
      t=tb[0]; k=kb[0]; sa=ab[0]; sb=bb[0]; ch=cb[0]; return true;
   }
   
   int CalcStrength(bool isBuy) {
      double t,k,sa,sb,ch;
      if(!GetIchi(m_hIchi,0,t,k,sa,sb,ch)) return 0;
      double price=iClose(m_symbol,m_timeframe,0), price26=iClose(m_symbol,m_timeframe,InpKijun);
      double kumoW=MathAbs(sa-sb), kumoWPct=(price>0)?(kumoW/price)*100.0:0;
      int s=0;
      if(isBuy) {
         if(t>k) s++; if(ch>price26) s++; if(price>MathMax(sa,sb)) s++;
         if(kumoWPct>=InpMinKumoWidth) s++;
         if(ch>t&&t>k&&k>sa&&sa>sb) s++;
      } else {
         if(t<k) s++; if(ch<price26) s++; if(price<MathMin(sa,sb)) s++;
         if(kumoWPct>=InpMinKumoWidth) s++;
         if(ch<t&&t<k&&k<sa&&sa<sb) s++;
      }
      return s;
   }
   
   int CheckSanyaku() {
      double t0,k0,sa0,sb0,ch0;
      if(!GetIchi(m_hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
      double price=iClose(m_symbol,m_timeframe,0), price26=iClose(m_symbol,m_timeframe,InpKijun);
      if(t0>k0&&ch0>price26&&price>MathMax(sa0,sb0)) return 1;
      if(t0<k0&&ch0<price26&&price<MathMin(sa0,sb0)) return -1;
      return 0;
   }
   
   int CheckCross() {
      double t0,k0,sa0,sb0,ch0, t1,k1,sa1,sb1,ch1;
      if(!GetIchi(m_hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
      if(!GetIchi(m_hIchi,1,t1,k1,sa1,sb1,ch1)) return 0;
      if(t0>k0&&t1<=k1) return 1;
      if(t0<k0&&t1>=k1) return -1;
      return 0;
   }
   
   int CheckPullback() {
      double t0,k0,sa0,sb0,ch0;
      if(!GetIchi(m_hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
      double p=iClose(m_symbol,m_timeframe,0), p1=iClose(m_symbol,m_timeframe,1);
      double tol=20*m_pt, top=MathMax(sa0,sb0), bot=MathMin(sa0,sb0);
      if(p>top&&t0>k0) { if(p1<=t0+tol&&p>t0) return 1; if(p1<=k0+tol&&p>k0&&p1>top) return 1; }
      if(p<bot&&t0<k0) { if(p1>=t0-tol&&p<t0) return -1; if(p1>=k0-tol&&p<k0&&p1<bot) return -1; }
      return 0;
   }
   
   int CheckKumoBreak() {
      double t0,k0,sa0,sb0,ch0;
      if(!GetIchi(m_hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
      double p0=iClose(m_symbol,m_timeframe,0), p1=iClose(m_symbol,m_timeframe,1);
      double top=MathMax(sa0,sb0), bot=MathMin(sa0,sb0);
      if(p0>top&&p1<=top) return 1;
      if(p0<bot&&p1>=bot) return -1;
      return 0;
   }
   
   bool IsRange() {
      double t0,k0,sa0,sb0,ch0, t1,k1,sa1,sb1,ch1, t2,k2,sa2,sb2,ch2;
      if(!GetIchi(m_hIchi,0,t0,k0,sa0,sb0,ch0)||!GetIchi(m_hIchi,1,t1,k1,sa1,sb1,ch1)||!GetIchi(m_hIchi,2,t2,k2,sa2,sb2,ch2)) return true;
      return (MathAbs(k0-k1)<5*m_pt && MathAbs(k1-k2)<5*m_pt && ((t0>k0&&t2<k2)||(t0<k0&&t2>k2)));
   }
   
   int GetD1Trend() {
      if(!InpUseTrendD1) return 0;
      double t0,k0,sa0,sb0,ch0;
      if(!GetIchi(m_hIchiD1,0,t0,k0,sa0,sb0,ch0)) return 0;
      double price=iClose(m_symbol,PERIOD_D1,0);
      if(price>MathMax(sa0,sb0)&&t0>k0) return 1;
      if(price<MathMin(sa0,sb0)&&t0<k0) return -1;
      return 0;
   }
   
   int GetSignal() {
      if(IsRange()) return 0;
      int d1=GetD1Trend(), sig=0;
      if(InpSignalMode==SIG_SANYAKU||InpSignalMode==SIG_ALL) { sig=CheckSanyaku(); if(sig!=0&&CalcStrength(sig>0)>=InpMinStrength&&(d1==0||d1==sig)) return sig; }
      if(InpSignalMode==SIG_GOLD_CROSS||InpSignalMode==SIG_ALL) { sig=CheckCross(); if(sig!=0&&CalcStrength(sig>0)>=InpMinStrength&&(d1==0||d1==sig)) return sig; }
      if(InpSignalMode==SIG_PULLBACK||InpSignalMode==SIG_ALL) { sig=CheckPullback(); if(sig!=0&&CalcStrength(sig>0)>=InpMinStrength&&(d1==0||d1==sig)) return sig; }
      if(InpSignalMode==SIG_ALL) { sig=CheckKumoBreak(); if(sig!=0&&CalcStrength(sig>0)>=MathMax(InpMinStrength,3)&&(d1==0||d1==sig)) return sig; }
      return 0;
   }
   
   //--- MAIN PROCESSING ---
   void Processing() {
      if(!SymbolInfoInteger(m_symbol,SYMBOL_SELECT)) SymbolSelect(m_symbol,true);
      
      datetime symTime = (datetime)SymbolInfoInteger(m_symbol, SYMBOL_TIME);
      datetime now = TimeCurrent();
      if(now - symTime > 120) return; // Bỏ qua nếu giá không cập nhật quá 2 phút (chợ đóng)
      
      double ask=SymbolInfoDouble(m_symbol,SYMBOL_ASK), bid=SymbolInfoDouble(m_symbol,SYMBOL_BID);
      
      // Day reset + Log
      MqlDateTime dt; TimeToStruct(now,dt);
      if(dt.day!=m_lastDay) {
         if(m_lastDay!=-1) LogDailySummary();
         m_stoppedToday=false; m_lastDay=dt.day; m_lastDealCount=0; m_dayProfit=0; m_dayWins=0; m_dayLosses=0;
      }
      CheckNewDeals();
      if(m_stoppedToday) return;
      
      // End of day
      if(InpCloseAtEndDay&&dt.hour==InpEndDayHour&&dt.min>=InpEndDayMinute) { CloseAll(); return; }
      
      // Drawdown
      double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
      if(bal>0&&(bal-eq)/bal*100.0>=InpMaxDrawdownPct) {
         CloseAll(); m_stoppedToday=true;
         Print("[SLIME_MOTHERSHIP][",m_symbol,"] 🛑 EMERGENCY STOP! DD=",DoubleToString((bal-eq)/bal*100.0,1),"%");
         return;
      }
      
      // Count positions
      int bCnt=0, sCnt=0; double bVol=0,sVol=0,bProd=0,sProd=0,lowBuy=0,highSell=0;
      for(int i=PositionsTotal()-1;i>=0;i--) {
         ulong tk=PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_MAGIC)==m_magic) {
            double v=PositionGetDouble(POSITION_VOLUME), op=PositionGetDouble(POSITION_PRICE_OPEN);
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) { bCnt++; bVol+=v; bProd+=op*v; if(lowBuy==0||op<lowBuy) lowBuy=op; }
            else { sCnt++; sVol+=v; sProd+=op*v; if(highSell==0||op>highSell) highSell=op; }
         }
      }
      
      // SL After Last
      if(InpSLAfterLast>0) {
         if((bCnt>0&&ask<lowBuy-InpSLAfterLast*m_p2p*m_pt)||(sCnt>0&&bid>highSell+InpSLAfterLast*m_p2p*m_pt)) {
            CloseAll(); m_stoppedToday=true; Print("[SLIME_MOTHERSHIP][",m_symbol,"] SL After Last hit!"); return;
         }
      }
      
      // Manage TP
      ManageTP(POSITION_TYPE_BUY, bCnt, bVol, bProd);
      ManageTP(POSITION_TYPE_SELL, sCnt, sVol, sProd);
      
      // Entry filters
      bool hasPos=(bCnt+sCnt>0);
      if(!CheckTime(hasPos,dt)||!CheckDailyProfit(hasPos)) return;
      
      // DCA
      double bDist=GetGridDist(bCnt), sDist=GetGridDist(sCnt);
      double slDist=(InpStopLoss>0)?InpStopLoss*m_p2p*m_pt:0;
      if(bCnt>0&&bCnt<InpMaxOrders&&ask<(lowBuy-bDist*m_p2p*m_pt)) {
         double sl=(slDist>0)?ask-slDist:0;
         m_trade.Buy(GetVol(bCnt+1,bVol), m_symbol, 0, sl, 0, m_name+" DCA B"+(string)(bCnt+1));
      }
      if(sCnt>0&&sCnt<InpMaxOrders&&bid>(highSell+sDist*m_p2p*m_pt)) {
         double sl=(slDist>0)?bid+slDist:0;
         m_trade.Sell(GetVol(sCnt+1,sVol), m_symbol, 0, sl, 0, m_name+" DCA S"+(string)(sCnt+1));
      }
      
      // First entry
      if(bCnt==0&&sCnt==0) {
         if(IsAnyOtherSymbolHavingPosition(m_symbol, m_magic)) return;
         int sig=GetSignal();
         if(sig==0) return;
         int str=CalcStrength(sig>0);
         double tpDist=(InpFirstTP>0)?InpFirstTP*m_p2p*m_pt:0;
         string sigName=(sig>0)?"BUY":"SELL";
         Print("[SLIME_MOTHERSHIP][",m_symbol,"] 📊 Signal=",sigName," Strength=",str,"/5 D1=",GetD1Trend());
         
         if(sig==1) {
            double sl=(slDist>0)?ask-slDist:0, tp=(tpDist>0)?ask+tpDist:0;
            m_trade.Buy(m_vol, m_symbol, 0, sl, tp, m_name+" "+sigName+" S"+IntegerToString(str));
            Print("[SLIME_MOTHERSHIP][",m_symbol,"] ✅ BUY @",DoubleToString(ask,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS))," SL=",DoubleToString(sl,2)," TP=",DoubleToString(tp,2));
         }
         else if(sig==-1) {
            double sl=(slDist>0)?bid+slDist:0, tp=(tpDist>0)?bid-tpDist:0;
            m_trade.Sell(m_vol, m_symbol, 0, sl, tp, m_name+" "+sigName+" S"+IntegerToString(str));
            Print("[SLIME_MOTHERSHIP][",m_symbol,"] ✅ SELL @",DoubleToString(bid,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS))," SL=",DoubleToString(sl,2)," TP=",DoubleToString(tp,2));
         }
      }
   }
   
   //--- TP MANAGEMENT ---
   void ManageTP(long type, int cnt, double vol, double prod) {
      if(cnt==0) return;
      double price=(type==POSITION_TYPE_BUY)?SymbolInfoDouble(m_symbol,SYMBOL_BID):SymbolInfoDouble(m_symbol,SYMBOL_ASK);
      double avg=prod/vol;
      if(InpBreakevenStart>0&&cnt>=InpBreakevenStart) {
         double pp=(type==POSITION_TYPE_BUY)?(price-avg)/(m_pt*m_p2p):(avg-price)/(m_pt*m_p2p);
         if(pp>=InpBreakevenPips) { CloseByType(type); Print("[SLIME_MOTHERSHIP][",m_symbol,"] 💰 Hòa vốn ",(type==POSITION_TYPE_BUY)?"BUY":"SELL"," +",DoubleToString(pp,1),"pips"); return; }
      }
      if(cnt>=InpMergeStart) {
         double tpPips = m_gridDistPips * m_tpRatio;
         double tp=(type==POSITION_TYPE_BUY)?avg+tpPips*m_p2p*m_pt:avg-tpPips*m_p2p*m_pt;
         for(int i=PositionsTotal()-1;i>=0;i--) {
            ulong tk=PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC)==m_magic&&PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==type)
               if(MathAbs(PositionGetDouble(POSITION_TP)-tp)>m_pt) m_trade.PositionModify(tk,PositionGetDouble(POSITION_SL),tp);
         }
      } else {
         for(int i=PositionsTotal()-1;i>=0;i--) {
            ulong tk=PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC)==m_magic&&PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==type) {
               double op=PositionGetDouble(POSITION_PRICE_OPEN);
               double tpPips = m_gridDistPips * m_tpRatio;
               double trg=(type==POSITION_TYPE_BUY)?op+tpPips*m_p2p*m_pt:op-tpPips*m_p2p*m_pt;
               if(MathAbs(PositionGetDouble(POSITION_TP)-trg)>m_pt) m_trade.PositionModify(tk,PositionGetDouble(POSITION_SL),trg);
            }
         }
      }
   }
   
   //--- DEAL TRACKING & LOGGING ---
   void CheckNewDeals() {
      HistorySelect(iTime(m_symbol,PERIOD_D1,0),TimeCurrent());
      int total=HistoryDealsTotal();
      if(total>m_lastDealCount) {
         for(int i=m_lastDealCount;i<total;i++) {
            ulong tk=HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(tk,DEAL_MAGIC)==m_magic&&HistoryDealGetString(tk,DEAL_SYMBOL)==m_symbol&&HistoryDealGetInteger(tk,DEAL_ENTRY)==DEAL_ENTRY_OUT) {
               double profit=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
               double vol=HistoryDealGetDouble(tk,DEAL_VOLUME);
               m_dayProfit+=profit; m_totalProfit+=profit; m_totalTrades++;
               if(profit>=0) { m_dayWins++; m_totalWins++; } else { m_dayLosses++; }
               string dtype=(HistoryDealGetInteger(tk,DEAL_TYPE)==DEAL_TYPE_BUY)?"SELL→CLOSE":"BUY→CLOSE";
               Print("[SLIME_MOTHERSHIP][",m_symbol,"] ",dtype," Vol=",DoubleToString(vol,2)," P/L=",DoubleToString(profit,2),
                     " | Day: W",m_dayWins,"/L",m_dayLosses," $",DoubleToString(m_dayProfit,2),
                     " | Total: ",m_totalTrades," trades WR=",GetWinRatePct(),"%");
            }
         }
         m_lastDealCount=total;
      }
   }
   
   void LogDailySummary() {
      int totalDay=m_dayWins+m_dayLosses;
      double wr=(totalDay>0)?(m_dayWins*100.0/totalDay):0;
      Print("═══════════════════════════════════════════════════");
      Print("[SLIME_MOTHERSHIP][",m_symbol,"] 📅 KẾT THÚC NGÀY ",m_lastDay);
      Print("  Trades: ",totalDay," | Wins: ",m_dayWins," | Losses: ",m_dayLosses," | WinRate: ",DoubleToString(wr,1),"%");
      Print("  P/L Ngày: $",DoubleToString(m_dayProfit,2)," | P/L Tổng: $",DoubleToString(m_totalProfit,2));
      Print("  Tổng trades: ",m_totalTrades," | WR Tổng: ",GetWinRatePct(),"%");
      Print("═══════════════════════════════════════════════════");
   }
   
   //--- HELPERS ---
   void CloseByType(long type) { for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_MAGIC)==m_magic&&PositionGetInteger(POSITION_TYPE)==type) m_trade.PositionClose(tk); } }
   void CloseAll() { for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_MAGIC)==m_magic) m_trade.PositionClose(tk); } }
   
   double GetGridDist(int cnt) {
      if(InpDcaMethod==DCA_2PHASE) return (cnt<InpPhase1Orders)?InpPhase1Dist:InpPhase2Dist;
      if(InpUseATR) { double atr[]; if(CopyBuffer(m_hATR,0,0,1,atr)>0) return (atr[0]/(m_pt*m_p2p))*InpATRMult; }
      return m_gridDistPips;
   }
   double CheckVolume(double vol) {
      double mn=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      vol=MathFloor(vol/st)*st; if(vol<mn)vol=mn; if(vol>mx)vol=mx; return vol;
   }
   double GetVol(int ord, double sumVol) {
      double m=1.0;
      if(ord>=InpMartStart3) m=InpMartMult3; else if(ord>=InpMartStart2) m=InpMartMult2; else if(ord>=InpMartStart1) m=InpMartMult1; else return m_vol;
      return CheckVolume(sumVol*m);
   }
   bool CheckDailyProfit(bool hasPos) {
      if(InpDailyProfitTarget<=0||hasPos) return true;
      double base=AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_GlobalProfit>=base*(InpDailyProfitTarget/100.0)) return false;
      return true;
   }
   bool CheckTime(bool hasPos, MqlDateTime &dt) {
      int dow=dt.day_of_week;
      if(InpUseDayFilter&&(dow==0||dow==6)) return false;
      if(hasPos) return true;
      if(!InpTradeFriday&&dow==5) return false;
      if(InpUseNewsFilter&&IsNewsTime()) return false;
      int h=dt.hour, m=dt.min;
      if(InpUseNoTimeSlot&&InTimeRange(h,m,InpNT1Start,InpNT1End)) return false;
      if(InpUseTimeSlot) return InTimeRange(h,m,InpT1Start,InpT1End)||InTimeRange(h,m,InpT2Start,InpT2End);
      return true;
   }
   bool IsNewsTime() {
      if(!InpUseNewsFilter) return false;
      datetime now=TimeCurrent(); MqlCalendarValue v[];
      if(!CalendarValueHistory(v,now-InpNewsMinutes*60,now+InpNewsMinutes*60)) return false;
      string b=SymbolInfoString(m_symbol,SYMBOL_CURRENCY_BASE),q=SymbolInfoString(m_symbol,SYMBOL_CURRENCY_PROFIT);
      if(b==""){b=StringSubstr(m_symbol,0,3);q=StringSubstr(m_symbol,3,3);}
      for(int i=0;i<ArraySize(v);i++){MqlCalendarEvent e;MqlCalendarCountry c;if(CalendarEventById(v[i].event_id,e)&&CalendarCountryById(e.country_id,c))if(e.importance==CALENDAR_IMPORTANCE_HIGH&&(c.currency==b||c.currency==q))return true;}
      return false;
   }
   
   // Panel getters
   string GetSymbol() { return m_symbol; }
   int GetBuyCount() { int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_MAGIC)==m_magic&&PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)c++;}return c; }
   int GetSellCount() { int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_MAGIC)==m_magic&&PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)c++;}return c; }
   double GetFloating() { double p=0; for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_MAGIC)==m_magic)p+=PositionGetDouble(POSITION_PROFIT);}return p; }
   string GetTrendText() { int d=GetD1Trend(); return (d>0)?"▲":(d<0)?"▼":"▬"; }
   string GetWinRatePct() { return (m_totalTrades>0)?DoubleToString(m_totalWins*100.0/m_totalTrades,0):"--"; }
   double GetDayProfit() { return m_dayProfit; }
   double GetTotalProfit() { return m_totalProfit; }
   int GetDayWins() { return m_dayWins; }
   int GetDayLosses() { return m_dayLosses; }
   int GetTotalTrades() { return m_totalTrades; }
};

//+------------------------------------------------------------------+
//| GLOBAL                                                           |
//+------------------------------------------------------------------+
CSlimeMotherBot *motherBots[];
CSlimeMotherBot *childBots[];
string gSymbols[];
string gChildTFs[];

int g_maxChildBots = 0;
double g_totalChildProfit = 0;

ENUM_TIMEFRAMES StrToTF(string s) {
   StringTrimLeft(s); StringTrimRight(s);
   if(s=="M1") return PERIOD_M1;
   if(s=="M5") return PERIOD_M5;
   if(s=="M15") return PERIOD_M15;
   if(s=="M30") return PERIOD_M30;
   if(s=="H1") return PERIOD_H1;
   if(s=="H4") return PERIOD_H4;
   if(s=="D1") return PERIOD_D1;
   return PERIOD_M15;
}

void CalcGlobalProfit() {
   HistorySelect(iTime(NULL,PERIOD_D1,0),TimeCurrent());
   double mp=0, cp=0; 
   int mn=InpMagicBase, mx=InpMagicBase+ArraySize(motherBots);
   int cMn=InpMagicBase+1000, cMx=InpMagicBase+1000+10000;
   
   for(int i=0;i<HistoryDealsTotal();i++){
      ulong t=HistoryDealGetTicket(i); long magic=HistoryDealGetInteger(t,DEAL_MAGIC);
      if(HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_OUT) {
         double pnl = HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_COMMISSION);
         if(magic>=mn&&magic<mx) mp+=pnl;
         else if(magic>=cMn&&magic<cMx) cp+=pnl;
      }
   }
   g_GlobalProfit=mp;
   g_totalChildProfit=cp;
   
   g_GlobalFloating=0;
   for(int i=0;i<ArraySize(motherBots);i++) if(CheckPointer(motherBots[i])!=POINTER_INVALID) g_GlobalFloating+=motherBots[i].GetFloating();
   for(int i=0;i<ArraySize(childBots);i++) if(CheckPointer(childBots[i])!=POINTER_INVALID) g_GlobalFloating+=childBots[i].GetFloating();
}

bool IsAnyOtherSymbolHavingPosition(string currentSymbol, int myMagic) {
   bool isMother = (myMagic >= InpMagicBase && myMagic < InpMagicBase + ArraySize(motherBots));
   bool isChild = (myMagic >= InpMagicBase+1000 && myMagic < InpMagicBase+1000+10000);
   
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong t=PositionGetTicket(i);
      long m=PositionGetInteger(POSITION_MAGIC);
      string sym=PositionGetString(POSITION_SYMBOL);
      
      if(sym != currentSymbol) {
         if(isMother && (m >= InpMagicBase && m < InpMagicBase + ArraySize(motherBots))) return true;
         if(isChild && (m >= InpMagicBase+1000 && m < InpMagicBase+1000+10000)) return true;
      }
   }
   return false;
}

void ManageSpawning() {
   int currentChildren = ArraySize(childBots);
   if(currentChildren > g_maxChildBots) g_maxChildBots = currentChildren;
   
   if(currentChildren < InpMaxSlimes) {
      static int totalSpawned = 0;
      // Dùng InpSpawnThreshold làm mốc đẻ. Tạm đẻ 1 con mỗi $InpSpawnThreshold lãi từ Mother
      if(g_GlobalProfit >= (totalSpawned + 1) * InpSpawnThreshold) {
         ArrayResize(childBots, currentChildren + 1);
         
         int tfIdx = MathRand() % ArraySize(gChildTFs);
         ENUM_TIMEFRAMES tf = StrToTF(gChildTFs[tfIdx]);
         double grid = InpChildMinGrid + MathRand() % (InpChildMaxGrid - InpChildMinGrid + 1);
         
         int symIdx = MathRand() % ArraySize(gSymbols);
         string chosenSymbol = gSymbols[symIdx];
         
         childBots[currentChildren] = new CSlimeMotherBot();
         int cMagic = InpMagicBase + 1000 + totalSpawned;
         childBots[currentChildren].Init("CHILD#"+(string)(totalSpawned+1), chosenSymbol, cMagic, tf, InpChildVol, grid, InpChildTPRatio);
         
         totalSpawned++;
         double totalAll = g_GlobalProfit + g_totalChildProfit;
         Print("[SLIME_MOTHERSHIP] 🐣 Đẻ Slime #", totalSpawned, " | Asset:", chosenSymbol, " | TF:", EnumToString(tf), " | Grid:", grid, "pips");
         Print("[STATISTICS] Active Slimes: ", currentChildren+1, " | Max Slimes: ", g_maxChildBots, " | Child PnL: $", DoubleToString(g_totalChildProfit,2), " | Mother PnL: $", DoubleToString(g_GlobalProfit,2), " | Total All: $", DoubleToString(totalAll,2));
      }
   }
}

void ManageChildrenHealth() {
   for(int i=ArraySize(childBots)-1; i>=0; i--) {
      if(CheckPointer(childBots[i])!=POINTER_INVALID) {
         double childEquity = InpChildCapital + childBots[i].GetTotalProfit() + childBots[i].GetFloating();
         
         // Thu hồi bot con nếu Equity dưới mức tối thiểu không đủ duy trì
         if(childEquity <= InpChildMinEquity) {
            Print("[SLIME_MOTHERSHIP] ♻️ Thu hồi Slime do Equity quá thấp ($", DoubleToString(childEquity, 2), "): Symbol ", childBots[i].GetSymbol());
            childBots[i].CloseAll();
            delete childBots[i];
            
            // Xóa khỏi array
            for(int j=i; j<ArraySize(childBots)-1; j++) childBots[j] = childBots[j+1];
            ArrayResize(childBots, ArraySize(childBots)-1);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ONINIT / ONDEINIT / ONTIMER                                      |
//+------------------------------------------------------------------+
int OnInit() {
   EventSetTimer(1);
   string sep=","; ushort u=StringGetCharacter(sep,0);
   int s=StringSplit(InpSymbols,u,gSymbols);
   ArrayResize(motherBots,s);
   
   int c=StringSplit(InpChildTimeframes,u,gChildTFs);
   
   Print("╔══════════════════════════════════════╗");
   Print("║    🟢 SLIME MOTHERSHIP v1.0        ║");
   Print("║    Mother Symbols: ",s,"                 ║");
   Print("╚══════════════════════════════════════╝");
   
   for(int i=0;i<s;i++) {
      StringTrimLeft(gSymbols[i]); StringTrimRight(gSymbols[i]);
      motherBots[i]=new CSlimeMotherBot();
      if(motherBots[i].Init("MOTHER", gSymbols[i],InpMagicBase+i, InpTimeframe, InpBaseVol, InpGridDist, 1.0)) Print("[SLIME_MOTHERSHIP] ✓ Bot [",gSymbols[i],"] ready");
      else Print("[SLIME_MOTHERSHIP] ✗ Bot [",gSymbols[i],"] FAILED");
   }
   CreatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   for(int i=0;i<ArraySize(motherBots);i++) { motherBots[i].Deinit(); delete motherBots[i]; }
   for(int i=0;i<ArraySize(childBots);i++) { childBots[i].Deinit(); delete childBots[i]; }
   ObjectsDeleteAll(0,"SG_");
}

void OnTimer() {
   CalcGlobalProfit();
   ManageSpawning();
   ManageChildrenHealth();
   
   for(int i=0;i<ArraySize(motherBots);i++) if(CheckPointer(motherBots[i])!=POINTER_INVALID) motherBots[i].Processing();
   for(int i=0;i<ArraySize(childBots);i++) if(CheckPointer(childBots[i])!=POINTER_INVALID) childBots[i].Processing();
   
   UpdatePanel();
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
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,center?ANCHOR_UPPER:ANCHOR_LEFT_UPPER);
}

void CreatePanel() {
   int x=10, y=30, w=360, h=140+ArraySize(motherBots)*22;
   ObjectCreate(0,"SG_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"SG_BG",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,"SG_BG",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,"SG_BG",OBJPROP_XSIZE,w);
   ObjectSetInteger(0,"SG_BG",OBJPROP_YSIZE,h);
   ObjectSetInteger(0,"SG_BG",OBJPROP_BGCOLOR,C'18,20,28');
   ObjectSetInteger(0,"SG_BG",OBJPROP_BORDER_COLOR,C'80,140,220');
   ObjectSetInteger(0,"SG_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"SG_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   
   CreateLabel("SG_TITLE","🟢 SLIME MOTHERSHIP",x+w/2,y+6,C'100,180,255',11,true);
   CreateLabel("SG_HDR","Symbol   D1  B/S    Float     Day W/L    WR",x+10,y+28,C'100,100,120',7);
   
   for(int i=0;i<ArraySize(motherBots);i++) {
      string p="SG_R"+(string)i;
      int ry=y+46+i*22;
      CreateLabel(p+"_SYM",gSymbols[i],    x+10,  ry, clrWhite, 8);
      CreateLabel(p+"_TRD","▬",            x+75,  ry, clrGray,  9);
      CreateLabel(p+"_CNT","0/0",          x+100, ry, clrGray,  8);
      CreateLabel(p+"_FLT","0.00",         x+145, ry, clrGray,  8);
      CreateLabel(p+"_DAY","0/0",          x+215, ry, clrGray,  8);
      CreateLabel(p+"_WR", "--%",          x+275, ry, clrGray,  8);
   }
   
   CreateLabel("SG_CHILD_HDR","--- CHILD SLIMES INFO ---",x+10,y+h-65,C'200,180,100',8);
   CreateLabel("SG_CHILD_STATS","",x+10,y+h-45,clrWhite,8);
   CreateLabel("SG_GLOBAL","Global: $0.00 | Float: $0.00",x+10,y+h-20,C'120,120,140',8);
}

void UpdatePanel() {
   for(int i=0;i<ArraySize(motherBots);i++) {
      if(CheckPointer(motherBots[i])==POINTER_INVALID) continue;
      string p="SG_R"+(string)i;
      string trend=motherBots[i].GetTrendText();
      int bc=motherBots[i].GetBuyCount(), sc=motherBots[i].GetSellCount();
      double flt=motherBots[i].GetFloating();
      int dw=motherBots[i].GetDayWins(), dl=motherBots[i].GetDayLosses();
      string wr=motherBots[i].GetWinRatePct()+"%";
      
      color tClr=(trend=="▲")?C'0,200,120':(trend=="▼")?C'255,80,80':clrGray;
      ObjectSetString(0,p+"_TRD",OBJPROP_TEXT,trend); ObjectSetInteger(0,p+"_TRD",OBJPROP_COLOR,tClr);
      ObjectSetString(0,p+"_CNT",OBJPROP_TEXT,(string)bc+"/"+(string)sc);
      ObjectSetString(0,p+"_FLT",OBJPROP_TEXT,DoubleToString(flt,2)); ObjectSetInteger(0,p+"_FLT",OBJPROP_COLOR,(flt>=0)?C'0,200,120':C'255,80,80');
      ObjectSetString(0,p+"_DAY",OBJPROP_TEXT,(string)dw+"/"+(string)dl);
      ObjectSetString(0,p+"_WR",OBJPROP_TEXT,wr);
   }
   
   string childStats = StringFormat("Active: %d | Max: %d | Profit: $%.2f", 
                                    ArraySize(childBots), g_maxChildBots, g_totalChildProfit);
   ObjectSetString(0,"SG_CHILD_STATS",OBJPROP_TEXT, childStats);
   
   double totalAll = g_GlobalProfit + g_totalChildProfit;
   ObjectSetString(0,"SG_GLOBAL",OBJPROP_TEXT,
      "Mother P/L: $"+DoubleToString(g_GlobalProfit,2)+" | Total PnL: $"+DoubleToString(totalAll,2)+" | All Float: $"+DoubleToString(g_GlobalFloating,2));
   ObjectSetInteger(0,"SG_GLOBAL",OBJPROP_COLOR,(totalAll+g_GlobalFloating>=0)?C'0,200,120':C'255,80,80');
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
