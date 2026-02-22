#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.14"

#include <Trade\Trade.mqh>
CTrade trade;

enum ENUM_DCA_METHOD { DCA_CLASSIC=0, DCA_2PHASE=1, DCA_TREND_COVER=2 };
enum ENUM_RSI_MODE { RSI_2WAY=0, RSI_1WAY=1 }; // 2 chieu / 1 chieu
enum ENUM_TP_METHOD { TP_FIXED_PIPS=0, TP_DYNAMIC_PIPS=1, TP_TARGET_MONEY=2 }; // Fix=Pips co sinh | Dynamic=Pips/Order | Money=Profit $

input group "Chien Luoc"
enum ENUM_ENTRY_MODE { ENTRY_DISTANCE_D1=0, ENTRY_BOX_GRID=1 };
input ENUM_ENTRY_MODE InpEntryMode       = ENTRY_DISTANCE_D1; // Chien luoc Vao Lenh
input int             InpBoxPeriod       = 365;      // [Box] Chu ky (So nen)
input bool            InpHedgeMode       = false;    // Che do Hedge (Mo 2 dau)
input int             InpEntryRange      = 200;      // [Dist] Khoang cach vao lenh (pips)
input ENUM_DCA_METHOD InpDcaMethod       = DCA_CLASSIC;// Phuong phap DCA

input group "Grid & ATR"
input int             InpGridDist        = 100;      // [Classic] Khoang cach (pips)
input bool            InpUseATR          = false;    // [ATR] Su dung Grid Dong theo ATR
input int             InpATRPeriod       = 14;       // [ATR] Chu ky
input double          InpATRMult         = 1.0;      // [ATR] He so nhan (Dist = ATR * Mult)
input int             InpMaxOrdersCandle = 5;        // Max lenh moi ben trong 1 nen
input int             InpRestOrder       = -1;       // [Rest] Lenh Nghi (Vd: 8). -1=Tat
input int             InpRestDist        = 500;      // [Rest] Khoang cach Nghi (pips)

input group "RSI Entry"
input bool            InpUseRSIEntry     = false;    // [RSI] Loc lenh dau tien
input ENUM_RSI_MODE   InpRSI_Mode        = RSI_2WAY; // [RSI] 2Way=Ngoai range | 1Way=Chan 1 chieu
input bool            InpRSI_Reverse     = false;    // [RSI] Dao nguoc (Trade trong 30-70)
input int             InpRSI_Period      = 14;       // [RSI] Chu ky
input int             InpRSI_LevelUp     = 70;       // [RSI] Qua mua (>70)
input int             InpRSI_LevelDown   = 30;       // [RSI] Qua ban (<30)

input group "RSI Custom Timeframe"
input bool            InpUseRSICustom    = false;    // [RSI TF] Loc lenh dau tien
input ENUM_RSI_MODE   InpRSIC_Mode       = RSI_2WAY; // [RSI TF] 2Way=Ngoai range | 1Way=Chan 1 chieu
input bool            InpRSIC_Reverse    = false;    // [RSI TF] Dao nguoc (Trade trong 30-70)
input ENUM_TIMEFRAMES InpRSIC_Timeframe  = PERIOD_H4;// [RSI TF] Khung gio
input int             InpRSIC_Period     = 14;       // [RSI TF] Chu ky
input int             InpRSIC_LevelUp    = 70;       // [RSI TF] Qua mua (>70)
input int             InpRSIC_LevelDown  = 30;       // [RSI TF] Qua ban (<30)

input group "2-Phase"
input int             InpPhase1Orders    = 10;       // So lenh Giai doan 1
input int             InpPhase1Dist      = 100;      // Khoang cach GD 1 (pips)
input int             InpPhase2Dist      = 150;      // Khoang cach GD 2 (pips)

input group "Trend Cover (Zone)"
input int             InpCoverStart      = 5;        // [Cover] Bat dau Cover tu lenh N
input int             InpCoverDist       = 200;      // [Cover] Khoang cach kich hoat (pips)
input double          InpCoverMult       = 1.5;      // [Cover] He so Cover Volume

input double InpBaseVol         = 0.01;     // Khoi luong co ban
input int    InpMaxOrders       = 20;       // So lenh toi da

input group "Martingale (3 Levels)"
input int    InpMartingaleStart1 = 4;       // [Level 1] Bat dau tu lenh N
input double InpMartingaleMult1  = 1.1;     // [Level 1] He so nhan
input int    InpMartingaleStart2 = 8;       // [Level 2] Bat dau tu lenh N
input double InpMartingaleMult2  = 1.2;     // [Level 2] He so nhan
input int    InpMartingaleStart3 = 12;      // [Level 3] Bat dau tu lenh N
input double InpMartingaleMult3  = 1.5;     // [Level 3] He so nhan

input group "Take Profit"
input ENUM_TP_METHOD InpTPMethod    = TP_FIXED_PIPS; // Phuong phap TP (Gop lenh)
input int    InpSingleTP        = 300;      // TP Don (pips) - Lenh rieng le
input int    InpMergeStart      = 3;        // [Gop] Tu lenh N: Dong tat ca khi cham TP
input int    InpMergeDist       = 10;       // [Gop] Loi nhuan (pips) [Fix/Dynamic]
input double InpTargetMoney     = 10.0;     // [Gop] Loi nhuan ($) [Target Money]
input int    InpBreakevenStart  = 0;        // [Hoa] Tu lenh N: Kich hoat Hoa lenh (0=Tat)
input int    InpBreakevenPips   = 10;       // [Hoa] Pips loi nhuan de dong (>0)

input group "Loc & Filter"
input double InpAccountInitial   = 0;        // Von ban dau (0=Dung Balance hien tai)
input double InpDailyProfitTarget = 1.0;    // Muc tieu loi nhuan Ngay (%) (0=Tat)
input bool   InpUseDayFilter    = true;     // Loc Ngay (Thu 2 - Thu 6)
input bool   InpNoTradeFirstDay = false;    // Khong trade ngay dau thang (1)
input bool   InpNoTradeLastDay  = false;    // Khong trade ngay cuoi thang (30/31)
input bool   InpCloseAtEndDay   = false;    // [EndDay] Dong het lenh cuoi ngay
input int    InpEndDayHour      = 23;       // [EndDay] Gio
input int    InpEndDayMinute    = 50;       // [EndDay] Phut
input bool   InpTradeFriday     = false;    // Giao dich Thu 6 (True=Yes, False=No)
input bool   InpPreFilterDay    = false;    // Xu ly lenh truoc ngay khong trade
input bool   InpUseNewsFilter   = false;    // Loc Tin Tuc (High Impact)
input int    InpNewsMinutes     = 30;       // Phut truoc/sau tin
input int    InpSLAfterLast     = 0;        // [SL] Pips sau lenh cuoi (0=Tat)


input group "== TIME TRADING (VIETNAM TIME GMT+7) =="
input bool   InpUseTimeSlot      = true;     // Co su dung thoi gian trading khong?
input string InpT1Start          = "09:00";  // Gio phut 1 bat dau tradding
input string InpT1End            = "17:00";  // Gio phut 1 ket thuc tradding
input string InpT2Start          = "22:00";  // Gio phut 2 bat dau tradding
input string InpT2End            = "03:00";  // Gio phut 2 ket thuc tradding

input group "== TIME NO TRADING (VIETNAM TIME GMT+7) =="
input bool   InpUseNoTimeSlot    = false;    // Co su dung thoi gian Robot Khong trading khong?
input string InpNT1Start         = "17:00";  // Gio phut 1 khong tradding
input string InpNT1End           = "21:00";  // Gio phut 1 ket thuc khong tradding
input string InpNT2Start         = "03:00";  // Gio phut 2 khong tradding
input string InpNT2End           = "09:00";  // Gio phut 2 ket thuc khong tradding

input group "== TIME SETTINGS =="
input int    InpServerGMTOffset  = 2;        // Mui gio Server (VD: IC Markets=2 hoac 3)

input int    InpMagic           = 123456;   // Magic Num

int hATR, hRSI, hRSICustom;
bool gAllowBuy = true, gAllowSell = true;
bool gStoppedToday = false;
int gLastDealCount = 0;
double gLastDayProfit = 0;

int OnInit() { 
   trade.SetExpertMagicNumber(InpMagic); 
   hATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   hRSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
   hRSICustom = iRSI(_Symbol, InpRSIC_Timeframe, InpRSIC_Period, PRICE_CLOSE);
   if(hATR == INVALID_HANDLE || hRSI == INVALID_HANDLE || hRSICustom == INVALID_HANDLE) return INIT_FAILED;
   CreatePanel();
   return(INIT_SUCCEEDED); 
}
void OnDeinit(const int reason) { IndicatorRelease(hATR); IndicatorRelease(hRSI); IndicatorRelease(hRSICustom); ObjectsDeleteAll(0, "VP_"); }

void CreatePanel() {
   int x=10, y=100, w=500, h=350;
   // Background
   ObjectCreate(0, "VP_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "VP_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "VP_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "VP_BG", OBJPROP_XSIZE, w);
   ObjectSetInteger(0, "VP_BG", OBJPROP_YSIZE, h);
   ObjectSetInteger(0, "VP_BG", OBJPROP_BGCOLOR, C'30,30,40');
   ObjectSetInteger(0, "VP_BG", OBJPROP_BORDER_COLOR, C'60,60,80');
   ObjectSetInteger(0, "VP_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "VP_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   // Header
   CreateLabel("VP_TITLE", "Viper v1.0.7", x+w/2, y+20, clrGold, 12, true);
   // Checkboxes
   CreateCheckbox("VP_BUY", "Only Buy", x+20, y+100, gAllowBuy, clrLime);
   CreateCheckbox("VP_SELL", "Only Sell", x+20, y+150, gAllowSell, clrTomato);
   // Footer
   CreateLabel("VP_F1", "zalo: 0767895876", x+w/2, y+220, clrDarkGray, 9, true);
   CreateLabel("VP_F2", "telegram: @Ph_Viet", x+w/2, y+250, clrDarkGray, 9, true);
   CreateLabel("VP_F3", "DaiVietQuant-2026 | v1.0.7", x+w/2, y+280, clrSlateGray, 8, true);
}
void CreateLabel(string name, string text, int x, int y, color clr, int sz, bool center) {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, center ? ANCHOR_UPPER : ANCHOR_LEFT_UPPER);
}
void CreateCheckbox(string name, string text, int x, int y, bool state, color clr) {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 16);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 16);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, state ? clr : clrGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetString(0, name, OBJPROP_TEXT, state ? "✓" : "");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   CreateLabel(name+"_LBL", text, x+22, y-10, clr, 9, false);
}
void UpdateCheckbox(string name, bool state, color clr) {
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, state ? clr : clrGray);
   ObjectSetString(0, name, OBJPROP_TEXT, state ? "✓" : "");
}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == "VP_BUY") {
         gAllowBuy = !gAllowBuy;
         if(!InpHedgeMode && gAllowBuy) { gAllowSell = false; UpdateCheckbox("VP_SELL", gAllowSell, clrTomato); }
         UpdateCheckbox("VP_BUY", gAllowBuy, clrLime);
         Print("BUY Order: ", gAllowBuy ? "ENABLED" : "DISABLED");
      }
      if(sparam == "VP_SELL") {
         gAllowSell = !gAllowSell;
         if(!InpHedgeMode && gAllowSell) { gAllowBuy = false; UpdateCheckbox("VP_BUY", gAllowBuy, clrLime); }
         UpdateCheckbox("VP_SELL", gAllowSell, clrTomato);
         Print("SELL Order: ", gAllowSell ? "ENABLED" : "DISABLED");
      }
   }
}

void OnTick()
  {
   double d1Close = iClose(_Symbol, PERIOD_D1, 1);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double p2p = (_Digits==3 || _Digits==5) ? 10.0 : 1.0;
   
   // Check End Of Day Close
   datetime now = TimeCurrent(); MqlDateTime dt; TimeToStruct(now, dt);
   static int lastDay = -1;
   if(dt.day != lastDay) {
      if(lastDay != -1) LogDailySummary(lastDay); // Tong ket ngay cu
      gStoppedToday = false; lastDay = dt.day;
      gLastDealCount = 0; gLastDayProfit = 0;
   }
   CheckNewDeals(); // Log moi lan chot lenh
   
   if(gStoppedToday) return; // Da bi SL, dung trade ngay hom nay
   
   if(InpCloseAtEndDay && dt.hour == InpEndDayHour && dt.min >= InpEndDayMinute) {
       CloseAllPositions();
       return;
   }
   
   // Remote Control: Pending order gia 1 = Kill Switch
   if(CheckRemoteKillSwitch()) {
      Print("[REMOTE] Kill Switch activated! Closing all positions...");
      CloseAllPositions();
      gStoppedToday = true;
      return;
   }
   
   int bCnt=0, sCnt=0;
   double bVol=0, sVol=0, bProd=0, sProd=0, lowBuy=0, highSell=0, lastBuy=0, lastSell=0;

   // 1. Dem lenh + Vol Tich Luy (Check ky Trend Cover)
   // Logic Martingale hien tai: Vol = Sum(Previous) * Mult.
   // Trend Cover: Vol = Sum(Current) * Mult.
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) {
         double v = PositionGetDouble(POSITION_VOLUME);
         double op = PositionGetDouble(POSITION_PRICE_OPEN);
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) {
            bCnt++; bVol+=v; bProd+=op*v;
            if(lowBuy==0 || op<lowBuy) lowBuy=op;
            if(lastBuy==0 || op<lastBuy) lastBuy=op; 
         } else {
            sCnt++; sVol+=v; sProd+=op*v;
            if(highSell==0 || op>highSell) highSell=op;
            if(lastSell==0 || op>lastSell) lastSell=op; 
         }
      }
   }
   
   // SL sau lenh cuoi
   if(InpSLAfterLast > 0) {
      if((bCnt > 0 && ask < lowBuy - InpSLAfterLast*p2p*pt) || 
         (sCnt > 0 && bid > highSell + InpSLAfterLast*p2p*pt)) {
         Print("SL After Last Order hit"); CloseAllPositions(); gStoppedToday = true; return;
      }
   }

   // 2. TP
   ManageTP(POSITION_TYPE_BUY, bCnt, bVol, bProd, pt, p2p);
   ManageTP(POSITION_TYPE_SELL, sCnt, sVol, sProd, pt, p2p);

   // 3. Filter
   bool hasPositions = (bCnt + sCnt > 0);
   bool allowEntryTime = CheckTime(hasPositions) && CheckDailyProfit(hasPositions);
   if(!allowEntryTime) return;

   bool allowBuy = gAllowBuy && (CountOrdersInCandle(POSITION_TYPE_BUY) < InpMaxOrdersCandle);
   bool allowSell = gAllowSell && (CountOrdersInCandle(POSITION_TYPE_SELL) < InpMaxOrdersCandle);

   // RSI
   double rsiVal = 50; 
   if(InpUseRSIEntry) { double r[]; if(CopyBuffer(hRSI,0,0,1,r)>0) rsiVal=r[0]; }
   
   bool rsiBuy=true, rsiSell=true;
   if(InpUseRSIEntry) {
      if(InpRSI_Mode == RSI_2WAY) {
         if(InpRSI_Reverse) {
            bool inside = (rsiVal >= InpRSI_LevelDown && rsiVal <= InpRSI_LevelUp);
            rsiBuy = inside; rsiSell = inside;
         } else {
            rsiBuy = (rsiVal < InpRSI_LevelDown);
            rsiSell = (rsiVal > InpRSI_LevelUp);
         }
      } else {
         rsiBuy = (rsiVal <= InpRSI_LevelUp);
         rsiSell = (rsiVal >= InpRSI_LevelDown);
      }
   }
   
   // RSI Custom Timeframe Filter
   if(InpUseRSICustom) {
      double rC[]; if(CopyBuffer(hRSICustom,0,0,1,rC)>0) {
         if(InpRSIC_Mode == RSI_2WAY) {
            if(InpRSIC_Reverse) {
               bool insideC = (rC[0] >= InpRSIC_LevelDown && rC[0] <= InpRSIC_LevelUp);
               rsiBuy = rsiBuy && insideC; rsiSell = rsiSell && insideC;
            } else {
               rsiBuy = rsiBuy && (rC[0] < InpRSIC_LevelDown);
               rsiSell = rsiSell && (rC[0] > InpRSIC_LevelUp);
            }
         } else {
            rsiBuy = rsiBuy && (rC[0] <= InpRSIC_LevelUp);
            rsiSell = rsiSell && (rC[0] >= InpRSIC_LevelDown);
         }
      }
   }

   // --- TREND COVER ---
   if(InpDcaMethod == DCA_TREND_COVER) {
       if(bCnt >= InpCoverStart && ask < (lowBuy - InpCoverDist*p2p*pt)) {
           if(sCnt == 0 && allowSell) trade.Sell(CheckVolume((bVol+sVol)*InpCoverMult), _Symbol);
           else if(sCnt > 0 && bid > (highSell + InpCoverDist*p2p*pt) && allowBuy) trade.Buy(CheckVolume((bVol+sVol)*InpCoverMult), _Symbol);
       }
       if(sCnt >= InpCoverStart && bid > (highSell + InpCoverDist*p2p*pt)) {
           if(bCnt == 0 && allowBuy) trade.Buy(CheckVolume((sVol+bVol)*InpCoverMult), _Symbol);
           else if(bCnt > 0 && ask < (lowBuy - InpCoverDist*p2p*pt) && allowSell) trade.Sell(CheckVolume((sVol+bVol)*InpCoverMult), _Symbol); 
       }
   }

   // --- HEDGE ---
   if(InpHedgeMode) {
       if(sCnt>0 && bCnt==0 && allowBuy) { trade.Buy(InpBaseVol, _Symbol); if(allowSell) trade.Sell(GetVol(sCnt+1, sVol), _Symbol); return; }
       if(bCnt>0 && sCnt==0 && allowSell) { trade.Sell(InpBaseVol, _Symbol); if(allowBuy) trade.Buy(GetVol(bCnt+1, bVol), _Symbol); return; }
       if(bCnt==0 && sCnt==0) { 
           bool sigBuy=false, sigSell=false;
           if(InpEntryMode == ENTRY_DISTANCE_D1) {
              if(ask < (d1Close - InpEntryRange*p2p*pt)) sigBuy=true;
              if(bid > (d1Close + InpEntryRange*p2p*pt)) sigSell=true;
           } else {
              double hh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpBoxPeriod, 1));
              double ll = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpBoxPeriod, 1));
              double range = hh - ll;
              if(ask < (ll + range*0.25)) sigBuy=true;
              if(bid > (hh - range*0.25)) sigSell=true;
           }
           if(sigBuy && rsiBuy && allowBuy) trade.Buy(InpBaseVol, _Symbol); 
           if(sigSell && rsiSell && allowSell) trade.Sell(InpBaseVol, _Symbol); 
           return; 
       }
   }

   bool isCoverMode = (InpDcaMethod == DCA_TREND_COVER && ((bCnt>=InpCoverStart && sCnt>0) || (sCnt>=InpCoverStart && bCnt>0)));
   if(isCoverMode) return;

   // --- DCA / ENTRY ---
   double useBDist = GetGridDist(bCnt);
   double useSDist = GetGridDist(sCnt);

   if(allowBuy) {
       if(bCnt==0 && !InpHedgeMode) {
          bool sigBuy=false;
          if(InpEntryMode == ENTRY_DISTANCE_D1) {
             if(ask < (d1Close - InpEntryRange*p2p*pt)) sigBuy=true;
          } else {
             double ll = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpBoxPeriod, 1));
             double hh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpBoxPeriod, 1));
             double range = hh - ll;
             if(ask < (ll + range*0.25)) sigBuy=true;
          }
          if(sigBuy && rsiBuy) trade.Buy(InpBaseVol, _Symbol);
       } else if(bCnt < InpMaxOrders) {
           // [Fix] Stop DCA if Trend Cover is active and Limit reached
           bool stopBuy = (InpDcaMethod == DCA_TREND_COVER && bCnt >= InpCoverStart);
           if(!stopBuy && ask < (lowBuy - useBDist*p2p*pt)) trade.Buy(GetVol(bCnt+1, bVol), _Symbol);
       }
   }

   if(allowSell) {
       if(sCnt==0 && !InpHedgeMode) {
          bool sigSell=false;
          if(InpEntryMode == ENTRY_DISTANCE_D1) {
             if(bid > (d1Close + InpEntryRange*p2p*pt)) sigSell=true;
          } else {
             double hh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpBoxPeriod, 1));
             double ll = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpBoxPeriod, 1));
             double range = hh - ll;
             if(bid > (hh - range*0.25)) sigSell=true;
          }
          if(sigSell && rsiSell) trade.Sell(InpBaseVol, _Symbol);
       } else if(sCnt < InpMaxOrders) {
           // [Fix] Stop DCA if Trend Cover is active and Limit reached
           bool stopSell = (InpDcaMethod == DCA_TREND_COVER && sCnt >= InpCoverStart);
           if(!stopSell && bid > (highSell + useSDist*p2p*pt)) trade.Sell(GetVol(sCnt+1, sVol), _Symbol);
       }
   }
  }

void ManageTP(long type, int cnt, double vol, double prod, double pt, double p2p) {
   if(cnt == 0) return;
   double price = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double avg = prod / vol;
   
   // 1. Hoa lenh: Tu lenh N, neu tong profit >= target pips -> dong tat ca
   if(InpBreakevenStart > 0 && cnt >= InpBreakevenStart) {
      double profitPips = (type==POSITION_TYPE_BUY) ? (price - avg) / (pt * p2p) : (avg - price) / (pt * p2p);
      if(profitPips >= InpBreakevenPips) {
         ClosePositionsByType(type);
         Print("[HOA LENH] ", (type==POSITION_TYPE_BUY)?"BUY":"SELL", " | Orders: ", cnt, " | Profit: ", DoubleToString(profitPips,1), " pips");
         return;
      }
   }
   
   // 2. Gop lenh: Tu lenh N
   bool forceMerge = (InpDcaMethod == DCA_TREND_COVER && cnt >= InpMergeStart);
   if(cnt >= InpMergeStart || forceMerge) {
      double targetPips = InpMergeDist;
      
      // Calculate Target Pips based on Method
      if(InpTPMethod == TP_DYNAMIC_PIPS) {
          targetPips = MathMax(2.0, InpMergeDist / (double)cnt); 
      }
      else if(InpTPMethod == TP_TARGET_MONEY) {
          double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
          double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
          if(tickVal > 0 && vol > 0) {
              double moneyPips = (InpTargetMoney / (vol * tickVal)) * tickSize / pt;
              // Chuyen doi ra pips chuan (10 points = 1 pip)
              targetPips = MathMax(2.0, moneyPips / p2p);
          }
      }
      
      double tp = (type==POSITION_TYPE_BUY) ? avg+targetPips*p2p*pt : avg-targetPips*p2p*pt;
      for(int i=PositionsTotal()-1; i>=0; i--) {
         ulong t = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_TYPE)==type)
            if(MathAbs(PositionGetDouble(POSITION_TP)-tp)>pt) trade.PositionModify(t, PositionGetDouble(POSITION_SL), tp);
      }
   } else {
      // TP Don cho tung lenh
      for(int i=PositionsTotal()-1; i>=0; i--) {
         ulong t = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_TYPE)==type) {
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            double trg = (type==POSITION_TYPE_BUY) ? op+InpSingleTP*p2p*pt : op-InpSingleTP*p2p*pt;
            if(MathAbs(PositionGetDouble(POSITION_TP)-trg)>pt) trade.PositionModify(t, PositionGetDouble(POSITION_SL), trg);
         }
      }
   }
}

void ClosePositionsByType(long type) {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetInteger(POSITION_TYPE)==type)
         trade.PositionClose(t);
   }
}

double GetGridDist(int cnt) {
   if(InpRestOrder > 0 && (cnt + 1) == InpRestOrder) return InpRestDist;

   if(InpDcaMethod == DCA_2PHASE) {
       if(cnt < InpPhase1Orders) return InpPhase1Dist;
       return InpPhase2Dist;
   }
   if(InpUseATR) {
       double atr[];
       if(CopyBuffer(hATR, 0, 0, 1, atr) > 0) {
           double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
           double p2p = (_Digits==3 || _Digits==5) ? 10.0 : 1.0;
           return (atr[0] / (pt * p2p)) * InpATRMult;
       }
   }
   return InpGridDist;
}

double CheckVolume(double vol) {
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   vol = MathFloor(vol / step) * step;
   if(vol < min) vol = min; if(vol > max) vol = max;
   return vol;
}
double GetVol(int ord, double sumVol) {
   // 3-Level Martingale Logic
   double m = 1.0;
   if(ord >= InpMartingaleStart3) m = InpMartingaleMult3;
   else if(ord >= InpMartingaleStart2) m = InpMartingaleMult2;
   else if(ord >= InpMartingaleStart1) m = InpMartingaleMult1;
   else return InpBaseVol; // Chua den Level 1 -> BaseVol
   
   return CheckVolume(sumVol * m);
}
bool CheckDailyProfit(bool hasPositions = false) {
   if(InpDailyProfitTarget <= 0) return true;
   if(hasPositions) return true; // Da co lenh -> cho phep DCA tiep
   HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
   double dayProf = 0;
   for(int i=0; i<HistoryDealsTotal(); i++) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC)==InpMagic && HistoryDealGetString(t, DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_OUT)
         dayProf += HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP) + HistoryDealGetDouble(t, DEAL_COMMISSION);
   }
   double baseBalance = (InpAccountInitial > 0) ? InpAccountInitial : AccountInfoDouble(ACCOUNT_BALANCE);
   if(dayProf >= baseBalance * (InpDailyProfitTarget/100.0)) return false;
   return true;
}

void CheckNewDeals() {
   HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   if(totalDeals > gLastDealCount) {
      for(int i=gLastDealCount; i<totalDeals; i++) {
         ulong t = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(t, DEAL_MAGIC)==InpMagic && HistoryDealGetString(t, DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_OUT) {
            double profit = HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP) + HistoryDealGetDouble(t, DEAL_COMMISSION);
            gLastDayProfit += profit;
            Print("[DEAL] ", (HistoryDealGetInteger(t, DEAL_TYPE)==DEAL_TYPE_BUY)?"SELL CLOSED":"BUY CLOSED",
                  " | Profit: ", DoubleToString(profit,2), " | Day Total: ", DoubleToString(gLastDayProfit,2));
         }
      }
      gLastDealCount = totalDeals;
   }
}

void LogDailySummary(int day) {
   double baseBalance = (InpAccountInitial > 0) ? InpAccountInitial : AccountInfoDouble(ACCOUNT_BALANCE);
   Print("========================================");
   Print("[DAILY SUMMARY] Day ", day, " | Total Profit: ", DoubleToString(gLastDayProfit,2), " | Target: ", DoubleToString(baseBalance*(InpDailyProfitTarget/100.0),2));
   Print("========================================");
}

bool CheckRemoteKillSwitch() {
   for(int i=OrdersTotal()-1; i>=0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL)==_Symbol) {
         double price = OrderGetDouble(ORDER_PRICE_OPEN);
         if(price <= 1.0) {
            trade.OrderDelete(ticket);
            return true;
         }
      }
   }
   return false;
}
bool CheckTime(bool hasPos = false) {
   // Convert Server Time to Vietnam Time (GMT+7)
   // Cong thuc: VN_Time = ServerTime - ServerOffset + 7
   datetime serverTime = TimeCurrent();
   datetime vnTime = serverTime - (InpServerGMTOffset * 3600) + (7 * 3600);
   
   MqlDateTime dt; TimeToStruct(vnTime, dt); // Use Converted Time
   int d = dt.day, dow = dt.day_of_week, lastD = GetLastDayOfMonth(dt.year, dt.mon);
   
   if(InpUseDayFilter && (dow==0 || dow==6)) return false;
   if(hasPos) return true;
   
   if(InpUseNewsFilter && IsNewsTime()) return false;
   if(!InpTradeFriday && (dow==5 || (InpPreFilterDay && dow==4))) return false;
   if(InpNoTradeFirstDay && (d==1 || (InpPreFilterDay && d==lastD))) return false;
   if(InpNoTradeLastDay && (d==lastD || (InpPreFilterDay && d==lastD-1))) return false;
   
   int h = dt.hour, m = dt.min;
   if(InpUseNoTimeSlot && (InTimeRange(h,m,InpNT1Start,InpNT1End) || InTimeRange(h,m,InpNT2Start,InpNT2End))) return false;
   if(InpUseTimeSlot) return (InTimeRange(h,m,InpT1Start,InpT1End) || InTimeRange(h,m,InpT2Start,InpT2End));
   return true;
}

bool InTimeRange(int h, int m, string start, string end) {
   int sh, sm, eh, em;
   if(StringLen(start)<5 || StringLen(end)<5) return false;
   sh = (int)StringToInteger(StringSubstr(start,0,2)); sm = (int)StringToInteger(StringSubstr(start,3,2));
   eh = (int)StringToInteger(StringSubstr(end,0,2)); em = (int)StringToInteger(StringSubstr(end,3,2));
   int now = h*60+m, s = sh*60+sm, e = eh*60+em;
   return (s<=e) ? (now>=s && now<e) : (now>=s || now<e);
}

// --- NEWS FILTER ---
bool IsNewsTime() {
   if(!InpUseNewsFilter) return false;
   datetime now = TimeCurrent();
   MqlCalendarValue v[];
   if(!CalendarValueHistory(v, now - InpNewsMinutes * 60, now + InpNewsMinutes * 60)) return false;

   string b = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE), q = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(b == "") { b = StringSubstr(_Symbol, 0, 3); q = StringSubstr(_Symbol, 3, 3); }

   for(int i=0; i<ArraySize(v); i++) {
      MqlCalendarEvent e; MqlCalendarCountry c;
      if(CalendarEventById(v[i].event_id, e) && CalendarCountryById(e.country_id, c)) {
         if(e.importance == CALENDAR_IMPORTANCE_HIGH && (c.currency == b || c.currency == q)) {
            Print("NEWS: ", e.name, " [", c.currency, "]");
            return true;
         }
      }
   }
   return false;
}
int CountOrdersInCandle(long type) {
   int cnt = 0;
   long dealType = (type == POSITION_TYPE_BUY) ? DEAL_TYPE_BUY : DEAL_TYPE_SELL;
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Count History Deals (Entry IN)
   HistorySelect(barTime, TimeCurrent() + 60);
   for(int i=0; i<HistoryDealsTotal(); i++) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC)==InpMagic && HistoryDealGetString(t, DEAL_SYMBOL)==_Symbol &&
         HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(t, DEAL_TYPE)==dealType) cnt++;
   }
   return cnt;
}

int GetLastDayOfMonth(int year, int mon) {
   int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
   if(mon == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) return 29;
   return days[mon - 1];
}

void CloseAllPositions() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) {
         trade.PositionClose(t);
      }
   }
}
