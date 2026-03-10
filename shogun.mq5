//+------------------------------------------------------------------+
//|                              SHOGUN - Ichimoku Multi-Symbol Bot  |
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
input group "=== MULTI-SYMBOL ==="
input string InpSymbols      = "XAUUSD,EURUSD,GBPUSD"; // Danh sách cặp (dấu phẩy)
input int    InpMagicBase    = 227000;  // Base Magic Number
input bool   InpTradeOneSymbolOnly = false; // Chỉ 1 symbol có lệnh cùng lúc

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
class CShogunBot {
private:
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

public:
   CShogunBot() { m_stoppedToday=false; m_lastDay=-1; m_lastDealCount=0; m_dayProfit=0; m_dayWins=0; m_dayLosses=0; m_totalTrades=0; m_totalWins=0; m_totalProfit=0; m_hIchi=INVALID_HANDLE; m_hIchiD1=INVALID_HANDLE; m_hATR=INVALID_HANDLE; }
   
   bool Init(string symbol, int magic) {
      m_symbol=symbol; m_magic=magic;
      m_trade.SetExpertMagicNumber(m_magic);
      if(!SymbolSelect(m_symbol,true)) { Print("[SHOGUN] Lỗi select ",m_symbol); return false; }
      
      m_hIchi  = iIchimoku(m_symbol, InpTimeframe, InpTenkan, InpKijun, InpSenkou);
      m_hIchiD1= iIchimoku(m_symbol, PERIOD_D1, InpTenkan, InpKijun, InpSenkou);
      m_hATR   = iATR(m_symbol, InpTimeframe, InpATRPeriod);
      
      if(m_hIchi==INVALID_HANDLE||m_hIchiD1==INVALID_HANDLE||m_hATR==INVALID_HANDLE) {
         Print("[SHOGUN] Lỗi tạo indicator cho ",m_symbol); return false;
      }
      m_pt  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int d = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_p2p = (d==3||d==5)?10.0:1.0;
      
      Print("[SHOGUN] ✓ ", m_symbol, " Magic=", m_magic, " Pt=", m_pt, " P2P=", m_p2p);
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
      double price=iClose(m_symbol,InpTimeframe,0), price26=iClose(m_symbol,InpTimeframe,InpKijun);
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
      double price=iClose(m_symbol,InpTimeframe,0), price26=iClose(m_symbol,InpTimeframe,InpKijun);
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
      double p=iClose(m_symbol,InpTimeframe,0), p1=iClose(m_symbol,InpTimeframe,1);
      double tol=20*m_pt, top=MathMax(sa0,sb0), bot=MathMin(sa0,sb0);
      if(p>top&&t0>k0) { if(p1<=t0+tol&&p>t0) return 1; if(p1<=k0+tol&&p>k0&&p1>top) return 1; }
      if(p<bot&&t0<k0) { if(p1>=t0-tol&&p<t0) return -1; if(p1>=k0-tol&&p<k0&&p1<bot) return -1; }
      return 0;
   }
   
   int CheckKumoBreak() {
      double t0,k0,sa0,sb0,ch0;
      if(!GetIchi(m_hIchi,0,t0,k0,sa0,sb0,ch0)) return 0;
      double p0=iClose(m_symbol,InpTimeframe,0), p1=iClose(m_symbol,InpTimeframe,1);
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
      double ask=SymbolInfoDouble(m_symbol,SYMBOL_ASK), bid=SymbolInfoDouble(m_symbol,SYMBOL_BID);
      
      // Day reset + Log
      datetime now=TimeCurrent(); MqlDateTime dt; TimeToStruct(now,dt);
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
         Print("[SHOGUN][",m_symbol,"] 🛑 EMERGENCY STOP! DD=",DoubleToString((bal-eq)/bal*100.0,1),"%");
         return;
      }
      
      // Count positions
      int bCnt=0, sCnt=0; double bVol=0,sVol=0,bProd=0,sProd=0,lowBuy=0,highSell=0;
      for(int i=PositionsTotal()-1;i>=0;i--) {
         ulong tk=PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL)==m_symbol) {
            long m_magic_pos = PositionGetInteger(POSITION_MAGIC);
            string m_comment = PositionGetString(POSITION_COMMENT);
            if(m_magic_pos == m_magic || StringFind(m_comment, "SG ") == 0) {
               double v=PositionGetDouble(POSITION_VOLUME), op=PositionGetDouble(POSITION_PRICE_OPEN);
               if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) { bCnt++; bVol+=v; bProd+=op*v; if(lowBuy==0||op<lowBuy) lowBuy=op; }
               else { sCnt++; sVol+=v; sProd+=op*v; if(highSell==0||op>highSell) highSell=op; }
            }
         }
      }
      
      // SL After Last
      if(InpSLAfterLast>0) {
         if((bCnt>0&&ask<lowBuy-InpSLAfterLast*m_p2p*m_pt)||(sCnt>0&&bid>highSell+InpSLAfterLast*m_p2p*m_pt)) {
            CloseAll(); m_stoppedToday=true; Print("[SHOGUN][",m_symbol,"] SL After Last hit!"); return;
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
         m_trade.Buy(GetVol(bCnt+1,bVol), m_symbol, 0, sl, 0, "SG DCA B"+(string)(bCnt+1));
      }
      if(sCnt>0&&sCnt<InpMaxOrders&&bid>(highSell+sDist*m_p2p*m_pt)) {
         double sl=(slDist>0)?bid+slDist:0;
         m_trade.Sell(GetVol(sCnt+1,sVol), m_symbol, 0, sl, 0, "SG DCA S"+(string)(sCnt+1));
      }
      
      // First entry
      if(bCnt==0&&sCnt==0) {
         if(InpTradeOneSymbolOnly && IsAnyOtherSymbolHavingPosition(m_symbol)) return;
         int sig=GetSignal();
         if(sig==0) return;
         int str=CalcStrength(sig>0);
         double tpDist=(InpFirstTP>0)?InpFirstTP*m_p2p*m_pt:0;
         string sigName=(sig>0)?"BUY":"SELL";
         Print("[SHOGUN][",m_symbol,"] 📊 Signal=",sigName," Strength=",str,"/5 D1=",GetD1Trend());
         
         if(sig==1) {
            double sl=(slDist>0)?ask-slDist:0, tp=(tpDist>0)?ask+tpDist:0;
            m_trade.Buy(InpBaseVol, m_symbol, 0, sl, tp, "SG "+sigName+" S"+IntegerToString(str));
            Print("[SHOGUN][",m_symbol,"] ✅ BUY @",DoubleToString(ask,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS))," SL=",DoubleToString(sl,2)," TP=",DoubleToString(tp,2));
         }
         else if(sig==-1) {
            double sl=(slDist>0)?bid+slDist:0, tp=(tpDist>0)?bid-tpDist:0;
            m_trade.Sell(InpBaseVol, m_symbol, 0, sl, tp, "SG "+sigName+" S"+IntegerToString(str));
            Print("[SHOGUN][",m_symbol,"] ✅ SELL @",DoubleToString(bid,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS))," SL=",DoubleToString(sl,2)," TP=",DoubleToString(tp,2));
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
         if(pp>=InpBreakevenPips) { CloseByType(type); Print("[SHOGUN][",m_symbol,"] 💰 Hòa vốn ",(type==POSITION_TYPE_BUY)?"BUY":"SELL"," +",DoubleToString(pp,1),"pips"); return; }
      }
      if(cnt>=InpMergeStart) {
         double tpPips=InpMergeDist;
         if(InpTPMethod==TP_DYNAMIC_PIPS) tpPips=MathMax(2.0,InpMergeDist/(double)cnt);
         else if(InpTPMethod==TP_TARGET_MONEY) {
            double tv=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
            if(tv>0&&vol>0) tpPips=MathMax(2.0,(InpTargetMoney/(vol*tv))*ts/m_pt/m_p2p);
         }
         double tp=(type==POSITION_TYPE_BUY)?avg+tpPips*m_p2p*m_pt:avg-tpPips*m_p2p*m_pt;
         for(int i=PositionsTotal()-1;i>=0;i--) {
            ulong tk=PositionGetTicket(i);
            if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==type) {
               long m_magic_pos = PositionGetInteger(POSITION_MAGIC);
               string m_comment = PositionGetString(POSITION_COMMENT);
               if(m_magic_pos == m_magic || StringFind(m_comment, "SG ") == 0) {
                  if(MathAbs(PositionGetDouble(POSITION_TP)-tp)>m_pt) m_trade.PositionModify(tk,PositionGetDouble(POSITION_SL),tp);
               }
            }
         }
      } else {
         for(int i=PositionsTotal()-1;i>=0;i--) {
            ulong tk=PositionGetTicket(i);
            if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==type) {
               long m_magic_pos = PositionGetInteger(POSITION_MAGIC);
               string m_comment = PositionGetString(POSITION_COMMENT);
               if(m_magic_pos == m_magic || StringFind(m_comment, "SG ") == 0) {
                  double op=PositionGetDouble(POSITION_PRICE_OPEN);
                  double trg=(type==POSITION_TYPE_BUY)?op+InpSingleTP*m_p2p*m_pt:op-InpSingleTP*m_p2p*m_pt;
                  if(MathAbs(PositionGetDouble(POSITION_TP)-trg)>m_pt) m_trade.PositionModify(tk,PositionGetDouble(POSITION_SL),trg);
               }
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
               Print("[SHOGUN][",m_symbol,"] ",dtype," Vol=",DoubleToString(vol,2)," P/L=",DoubleToString(profit,2),
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
      Print("[SHOGUN][",m_symbol,"] 📅 KẾT THÚC NGÀY ",m_lastDay);
      Print("  Trades: ",totalDay," | Wins: ",m_dayWins," | Losses: ",m_dayLosses," | WinRate: ",DoubleToString(wr,1),"%");
      Print("  P/L Ngày: $",DoubleToString(m_dayProfit,2)," | P/L Tổng: $",DoubleToString(m_totalProfit,2));
      Print("  Tổng trades: ",m_totalTrades," | WR Tổng: ",GetWinRatePct(),"%");
      Print("═══════════════════════════════════════════════════");
   }
   
   //--- HELPERS ---
   void CloseByType(long type) { for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==type) { long mag=PositionGetInteger(POSITION_MAGIC); string cmt=PositionGetString(POSITION_COMMENT); if(mag==m_magic||StringFind(cmt,"SG ")==0) m_trade.PositionClose(tk); } } }
   void CloseAll() { for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(PositionGetString(POSITION_SYMBOL)==m_symbol) { long mag=PositionGetInteger(POSITION_MAGIC); string cmt=PositionGetString(POSITION_COMMENT); if(mag==m_magic||StringFind(cmt,"SG ")==0) m_trade.PositionClose(tk); } } }
   
   double GetGridDist(int cnt) {
      if(InpDcaMethod==DCA_2PHASE) return (cnt<InpPhase1Orders)?InpPhase1Dist:InpPhase2Dist;
      if(InpUseATR) { double atr[]; if(CopyBuffer(m_hATR,0,0,1,atr)>0) return (atr[0]/(m_pt*m_p2p))*InpATRMult; }
      return InpGridDist;
   }
   double CheckVolume(double vol) {
      double mn=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      vol=MathFloor(vol/st)*st; if(vol<mn)vol=mn; if(vol>mx)vol=mx; return vol;
   }
   double GetVol(int ord, double sumVol) {
      double m=1.0;
      if(ord>=InpMartStart3) m=InpMartMult3; else if(ord>=InpMartStart2) m=InpMartMult2; else if(ord>=InpMartStart1) m=InpMartMult1; else return InpBaseVol;
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
   int GetBuyCount() { int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ long mag=PositionGetInteger(POSITION_MAGIC); string cmt=PositionGetString(POSITION_COMMENT); if(mag==m_magic||StringFind(cmt,"SG ")==0) c++;}}return c; }
   int GetSellCount() { int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(PositionGetString(POSITION_SYMBOL)==m_symbol&&PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ long mag=PositionGetInteger(POSITION_MAGIC); string cmt=PositionGetString(POSITION_COMMENT); if(mag==m_magic||StringFind(cmt,"SG ")==0) c++;}}return c; }
   double GetFloating() { double p=0; for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(PositionGetString(POSITION_SYMBOL)==m_symbol){ long mag=PositionGetInteger(POSITION_MAGIC); string cmt=PositionGetString(POSITION_COMMENT); if(mag==m_magic||StringFind(cmt,"SG ")==0) p+=PositionGetDouble(POSITION_PROFIT);}}return p; }
   string GetTrendText() { int d=GetD1Trend(); return (d>0)?"▲":(d<0)?"▼":"▬"; }
   string GetWinRatePct() { return (m_totalTrades>0)?DoubleToString(m_totalWins*100.0/m_totalTrades,0):"--"; }
   double GetDayProfit() { return m_dayProfit; }
   int GetDayWins() { return m_dayWins; }
   int GetDayLosses() { return m_dayLosses; }
   int GetTotalTrades() { return m_totalTrades; }
};

//+------------------------------------------------------------------+
//| GLOBAL                                                           |
//+------------------------------------------------------------------+
CShogunBot *bots[];
string gSymbols[];

void CalcGlobalProfit() {
   HistorySelect(iTime(NULL,PERIOD_D1,0),TimeCurrent());
   double profit=0; int mn=InpMagicBase, mx=InpMagicBase+ArraySize(bots);
   for(int i=0;i<HistoryDealsTotal();i++){
      ulong t=HistoryDealGetTicket(i); long magic=HistoryDealGetInteger(t,DEAL_MAGIC);
      if(magic>=mn&&magic<mx&&HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_OUT)
         profit+=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_COMMISSION);
   }
   g_GlobalProfit=profit;
   g_GlobalFloating=0;
   for(int i=0;i<ArraySize(bots);i++) if(CheckPointer(bots[i])!=POINTER_INVALID) g_GlobalFloating+=bots[i].GetFloating();
}

bool IsAnyOtherSymbolHavingPosition(string currentSymbol) {
   int mn=InpMagicBase, mx=InpMagicBase+ArraySize(bots);
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong t=PositionGetTicket(i);
      long magic=PositionGetInteger(POSITION_MAGIC);
      if(magic>=mn && magic<mx) {
         if(PositionGetString(POSITION_SYMBOL)!=currentSymbol) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| ONINIT / ONDEINIT / ONTIMER                                      |
//+------------------------------------------------------------------+
int OnInit() {
   EventSetTimer(1);
   string sep=","; ushort u=StringGetCharacter(sep,0);
   int s=StringSplit(InpSymbols,u,gSymbols);
   ArrayResize(bots,s);
   
   Print("╔══════════════════════════════════════╗");
   Print("║    ⛩ SHOGUN Ichimoku Multi-Bot      ║");
   Print("║    Symbols: ",s,"                        ║");
   Print("╚══════════════════════════════════════╝");
   
   for(int i=0;i<s;i++) {
      StringTrimLeft(gSymbols[i]); StringTrimRight(gSymbols[i]);
      bots[i]=new CShogunBot();
      if(bots[i].Init(gSymbols[i],InpMagicBase+i)) Print("[SHOGUN] ✓ Bot [",gSymbols[i],"] ready");
      else Print("[SHOGUN] ✗ Bot [",gSymbols[i],"] FAILED");
   }
   CreatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   for(int i=0;i<ArraySize(bots);i++){bots[i].Deinit();delete bots[i];}
   ObjectsDeleteAll(0,"SG_");
}

void OnTimer() {
   CalcGlobalProfit();
   for(int i=0;i<ArraySize(bots);i++) if(CheckPointer(bots[i])!=POINTER_INVALID) bots[i].Processing();
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
   int x=10, y=30, w=360, h=90+ArraySize(bots)*22;
   ObjectCreate(0,"SG_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"SG_BG",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,"SG_BG",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,"SG_BG",OBJPROP_XSIZE,w);
   ObjectSetInteger(0,"SG_BG",OBJPROP_YSIZE,h);
   ObjectSetInteger(0,"SG_BG",OBJPROP_BGCOLOR,C'18,20,28');
   ObjectSetInteger(0,"SG_BG",OBJPROP_BORDER_COLOR,C'80,140,220');
   ObjectSetInteger(0,"SG_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"SG_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   
   CreateLabel("SG_TITLE","⛩ SHOGUN v1.0",x+w/2,y+6,C'100,180,255',11,true);
   CreateLabel("SG_HDR","Symbol   D1  B/S    Float     Day W/L    WR",x+10,y+28,C'100,100,120',7);
   CreateLabel("SG_GLOBAL","Global: $0.00 | Float: $0.00",x+10,y+h-18,C'120,120,140',7);
   
   for(int i=0;i<ArraySize(bots);i++) {
      string p="SG_R"+(string)i;
      int ry=y+46+i*22;
      CreateLabel(p+"_SYM",gSymbols[i],   x+10,  ry, clrWhite, 8);
      CreateLabel(p+"_TRD","▬",            x+75,  ry, clrGray,  9);
      CreateLabel(p+"_CNT","0/0",          x+100, ry, clrGray,  8);
      CreateLabel(p+"_FLT","0.00",         x+145, ry, clrGray,  8);
      CreateLabel(p+"_DAY","0/0",          x+215, ry, clrGray,  8);
      CreateLabel(p+"_WR", "--%",          x+275, ry, clrGray,  8);
   }
}

void UpdatePanel() {
   for(int i=0;i<ArraySize(bots);i++) {
      if(CheckPointer(bots[i])==POINTER_INVALID) continue;
      string p="SG_R"+(string)i;
      string trend=bots[i].GetTrendText();
      int bc=bots[i].GetBuyCount(), sc=bots[i].GetSellCount();
      double flt=bots[i].GetFloating();
      int dw=bots[i].GetDayWins(), dl=bots[i].GetDayLosses();
      string wr=bots[i].GetWinRatePct()+"%";
      
      color tClr=(trend=="▲")?C'0,200,120':(trend=="▼")?C'255,80,80':clrGray;
      ObjectSetString(0,p+"_TRD",OBJPROP_TEXT,trend); ObjectSetInteger(0,p+"_TRD",OBJPROP_COLOR,tClr);
      ObjectSetString(0,p+"_CNT",OBJPROP_TEXT,(string)bc+"/"+(string)sc);
      ObjectSetString(0,p+"_FLT",OBJPROP_TEXT,DoubleToString(flt,2)); ObjectSetInteger(0,p+"_FLT",OBJPROP_COLOR,(flt>=0)?C'0,200,120':C'255,80,80');
      ObjectSetString(0,p+"_DAY",OBJPROP_TEXT,(string)dw+"/"+(string)dl);
      ObjectSetString(0,p+"_WR",OBJPROP_TEXT,wr);
   }
   ObjectSetString(0,"SG_GLOBAL",OBJPROP_TEXT,
      "Global: $"+DoubleToString(g_GlobalProfit,2)+" | Float: $"+DoubleToString(g_GlobalFloating,2));
   ObjectSetInteger(0,"SG_GLOBAL",OBJPROP_COLOR,(g_GlobalProfit+g_GlobalFloating>=0)?C'0,200,120':C'255,80,80');
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
