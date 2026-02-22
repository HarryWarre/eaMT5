#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.15"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayString.mqh>

enum ENUM_DCA_METHOD { DCA_CLASSIC=0, DCA_2PHASE=1, DCA_TREND_COVER=2 };
enum ENUM_RSI_MODE { RSI_2WAY=0, RSI_1WAY=1 }; // 2 chieu / 1 chieu
enum ENUM_TP_METHOD { TP_FIXED_PIPS=0, TP_DYNAMIC_PIPS=1, TP_TARGET_MONEY=2 }; // Fix=Pips co sinh | Dynamic=Pips/Order | Money=Profit $
enum ENUM_ENTRY_MODE { ENTRY_DISTANCE_D1=0, ENTRY_BOX_GRID=1 };

input group "Chien Luoc"
input string          InpSymbols         = "EURUSD,GBPUSD,XAUUSD"; // Danh sach cap (phan cach boi dau phay)
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

input int    InpMagicBase        = 123000;   // Base Magic Num

// --- CLASS CViperBot ---
class CViperBot {
private:
    string m_symbol;
    int    m_magic;
    CTrade m_trade;
    int    m_hATR, m_hRSI, m_hRSICustom;
    
    // State
    bool m_gAllowBuy;
    bool m_gAllowSell;
    bool m_gStoppedToday;
    int  m_gLastDealCount;
    double m_gLastDayProfit;
    
    int  m_lastDay;

public:
    CViperBot() {
        m_gAllowBuy = true;
        m_gAllowSell = true;
        m_gStoppedToday = false;
        m_gLastDealCount = 0;
        m_gLastDayProfit = 0;
        m_lastDay = -1;
        m_hATR = INVALID_HANDLE;
        m_hRSI = INVALID_HANDLE;
        m_hRSICustom = INVALID_HANDLE;
    }
    
    bool Init(string symbol, int magic) {
        m_symbol = symbol;
        m_magic = magic;
        m_trade.SetExpertMagicNumber(m_magic);
        
        m_hATR = iATR(m_symbol, PERIOD_CURRENT, InpATRPeriod);
        m_hRSI = iRSI(m_symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
        m_hRSICustom = iRSI(m_symbol, InpRSIC_Timeframe, InpRSIC_Period, PRICE_CLOSE);
        
        if(m_hATR == INVALID_HANDLE || m_hRSI == INVALID_HANDLE || m_hRSICustom == INVALID_HANDLE) {
            Print("Failed to create handles for ", m_symbol);
            return false;
        }
        return true;
    }
    
    void Deinit() {
        IndicatorRelease(m_hATR);
        IndicatorRelease(m_hRSI);
        IndicatorRelease(m_hRSICustom);
    }
    
    void Processing() {
        if(!SymbolInfoInteger(m_symbol, SYMBOL_SELECT)) {
             SymbolSelect(m_symbol, true);
        }
        
        double d1Close = iClose(m_symbol, PERIOD_D1, 1);
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double pt = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        double p2p = (digits==3 || digits==5) ? 10.0 : 1.0;
        
        // End Of Day Logic
        datetime now = TimeCurrent(); MqlDateTime dt; TimeToStruct(now, dt);
        if(dt.day != m_lastDay) {
           if(m_lastDay != -1) LogDailySummary(m_lastDay); 
           m_gStoppedToday = false; m_lastDay = dt.day;
           m_gLastDealCount = 0; m_gLastDayProfit = 0;
        }
        CheckNewDeals(); 
        
        if(m_gStoppedToday) return; 
        
        if(InpCloseAtEndDay && dt.hour == InpEndDayHour && dt.min >= InpEndDayMinute) {
            CloseAllPositions();
            return;
        }
        
        if(CheckRemoteKillSwitch()) {
           Print("[REMOTE] Kill Switch activated used for ", m_symbol);
           CloseAllPositions();
           m_gStoppedToday = true;
           return;
        }
        
        int bCnt=0, sCnt=0;
        double bVol=0, sVol=0, bProd=0, sProd=0, lowBuy=0, highSell=0;
        
        for(int i=PositionsTotal()-1; i>=0; i--) {
           ulong t = PositionGetTicket(i);
           if(PositionGetString(POSITION_SYMBOL)==m_symbol && PositionGetInteger(POSITION_MAGIC)==m_magic) {
              double v = PositionGetDouble(POSITION_VOLUME);
              double op = PositionGetDouble(POSITION_PRICE_OPEN);
              if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) {
                 bCnt++; bVol+=v; bProd+=op*v;
                 if(lowBuy==0 || op<lowBuy) lowBuy=op;
              } else {
                 sCnt++; sVol+=v; sProd+=op*v;
                 if(highSell==0 || op>highSell) highSell=op;
              }
           }
        }
        
        // SL After Last
        if(InpSLAfterLast > 0) {
           if((bCnt > 0 && ask < lowBuy - InpSLAfterLast*p2p*pt) || 
              (sCnt > 0 && bid > highSell + InpSLAfterLast*p2p*pt)) {
              Print("SL After Last Order hit for ", m_symbol); CloseAllPositions(); m_gStoppedToday = true; return;
           }
        }

        ManageTP(POSITION_TYPE_BUY, bCnt, bVol, bProd, pt, p2p);
        ManageTP(POSITION_TYPE_SELL, sCnt, sVol, sProd, pt, p2p);

        // Filter
        bool hasPositions = (bCnt + sCnt > 0);
        bool allowEntryTime = CheckTime(hasPositions, dt) && CheckDailyProfit(hasPositions);
        if(!allowEntryTime) return;

        bool allowBuy = m_gAllowBuy && (CountOrdersInCandle(POSITION_TYPE_BUY) < InpMaxOrdersCandle);
        bool allowSell = m_gAllowSell && (CountOrdersInCandle(POSITION_TYPE_SELL) < InpMaxOrdersCandle);

        // RSI
        double rsiVal = 50; 
        if(InpUseRSIEntry) { double r[]; if(CopyBuffer(m_hRSI,0,0,1,r)>0) rsiVal=r[0]; }
        
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
        
        if(InpUseRSICustom) {
           double rC[]; if(CopyBuffer(m_hRSICustom,0,0,1,rC)>0) {
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
                if(sCnt == 0 && allowSell) m_trade.Sell(CheckVolume((bVol+sVol)*InpCoverMult), m_symbol);
                else if(sCnt > 0 && bid > (highSell + InpCoverDist*p2p*pt) && allowBuy) m_trade.Buy(CheckVolume((bVol+sVol)*InpCoverMult), m_symbol);
            }
            if(sCnt >= InpCoverStart && bid > (highSell + InpCoverDist*p2p*pt)) {
                if(bCnt == 0 && allowBuy) m_trade.Buy(CheckVolume((sVol+bVol)*InpCoverMult), m_symbol);
                else if(bCnt > 0 && ask < (lowBuy - InpCoverDist*p2p*pt) && allowSell) m_trade.Sell(CheckVolume((sVol+bVol)*InpCoverMult), m_symbol); 
            }
        }
        
        // --- HEDGE ---
        if(InpHedgeMode) {
            if(sCnt>0 && bCnt==0 && allowBuy) { m_trade.Buy(InpBaseVol, m_symbol); if(allowSell) m_trade.Sell(GetVol(sCnt+1, sVol), m_symbol); return; }
            if(bCnt>0 && sCnt==0 && allowSell) { m_trade.Sell(InpBaseVol, m_symbol); if(allowBuy) m_trade.Buy(GetVol(bCnt+1, bVol), m_symbol); return; }
            if(bCnt==0 && sCnt==0) { 
                bool sigBuy=false, sigSell=false;
                if(InpEntryMode == ENTRY_DISTANCE_D1) {
                   if(ask < (d1Close - InpEntryRange*p2p*pt)) sigBuy=true;
                   if(bid > (d1Close + InpEntryRange*p2p*pt)) sigSell=true;
                } else {
                   double hh = iHigh(m_symbol, PERIOD_CURRENT, iHighest(m_symbol, PERIOD_CURRENT, MODE_HIGH, InpBoxPeriod, 1));
                   double ll = iLow(m_symbol, PERIOD_CURRENT, iLowest(m_symbol, PERIOD_CURRENT, MODE_LOW, InpBoxPeriod, 1));
                   double range = hh - ll;
                   if(ask < (ll + range*0.25)) sigBuy=true;
                   if(bid > (hh - range*0.25)) sigSell=true;
                }
                if(sigBuy && rsiBuy && allowBuy) m_trade.Buy(InpBaseVol, m_symbol); 
                if(sigSell && rsiSell && allowSell) m_trade.Sell(InpBaseVol, m_symbol); 
                return; 
            }
        }

        bool isCoverMode = (InpDcaMethod == DCA_TREND_COVER && ((bCnt>=InpCoverStart && sCnt>0) || (sCnt>=InpCoverStart && bCnt>0)));
        if(isCoverMode) return;

        double useBDist = GetGridDist(bCnt);
        double useSDist = GetGridDist(sCnt);

        if(allowBuy) {
            if(bCnt==0 && !InpHedgeMode) {
               bool sigBuy=false;
               if(InpEntryMode == ENTRY_DISTANCE_D1) {
                  if(ask < (d1Close - InpEntryRange*p2p*pt)) sigBuy=true;
               } else {
                  double ll = iLow(m_symbol, PERIOD_CURRENT, iLowest(m_symbol, PERIOD_CURRENT, MODE_LOW, InpBoxPeriod, 1));
                  double hh = iHigh(m_symbol, PERIOD_CURRENT, iHighest(m_symbol, PERIOD_CURRENT, MODE_HIGH, InpBoxPeriod, 1));
                  double range = hh - ll;
                  if(ask < (ll + range*0.25)) sigBuy=true;
               }
               if(sigBuy && rsiBuy) m_trade.Buy(InpBaseVol, m_symbol);
            } else if(bCnt < InpMaxOrders) {
                bool stopBuy = (InpDcaMethod == DCA_TREND_COVER && bCnt >= InpCoverStart);
                if(!stopBuy && ask < (lowBuy - useBDist*p2p*pt)) m_trade.Buy(GetVol(bCnt+1, bVol), m_symbol);
            }
        }

        if(allowSell) {
            if(sCnt==0 && !InpHedgeMode) {
               bool sigSell=false;
               if(InpEntryMode == ENTRY_DISTANCE_D1) {
                  if(bid > (d1Close + InpEntryRange*p2p*pt)) sigSell=true;
               } else {
                  double hh = iHigh(m_symbol, PERIOD_CURRENT, iHighest(m_symbol, PERIOD_CURRENT, MODE_HIGH, InpBoxPeriod, 1));
                  double ll = iLow(m_symbol, PERIOD_CURRENT, iLowest(m_symbol, PERIOD_CURRENT, MODE_LOW, InpBoxPeriod, 1));
                  double range = hh - ll;
                  if(bid > (hh - range*0.25)) sigSell=true;
               }
               if(sigSell && rsiSell) m_trade.Sell(InpBaseVol, m_symbol);
            } else if(sCnt < InpMaxOrders) {
                bool stopSell = (InpDcaMethod == DCA_TREND_COVER && sCnt >= InpCoverStart);
                if(!stopSell && bid > (highSell + useSDist*p2p*pt)) m_trade.Sell(GetVol(sCnt+1, sVol), m_symbol);
            }
        }
    }
    
    // --- Methods ---
    void ManageTP(long type, int cnt, double vol, double prod, double pt, double p2p) {
        if(cnt == 0) return;
        double price = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double avg = prod / vol;
        
        if(InpBreakevenStart > 0 && cnt >= InpBreakevenStart) {
           double profitPips = (type==POSITION_TYPE_BUY) ? (price - avg) / (pt * p2p) : (avg - price) / (pt * p2p);
           if(profitPips >= InpBreakevenPips) {
              ClosePositionsByType(type);
              Print("[HOA LENH] ", m_symbol, " ", (type==POSITION_TYPE_BUY)?"BUY":"SELL", " | Orders: ", cnt, " | Profit: ", DoubleToString(profitPips,1), " pips");
              return;
           }
        }
        
        bool forceMerge = (InpDcaMethod == DCA_TREND_COVER && cnt >= InpMergeStart);
        if(cnt >= InpMergeStart || forceMerge) {
           double targetPips = InpMergeDist;
           if(InpTPMethod == TP_DYNAMIC_PIPS) {
               targetPips = MathMax(2.0, InpMergeDist / (double)cnt); 
           }
           else if(InpTPMethod == TP_TARGET_MONEY) {
               double tickVal = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
               double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
               if(tickVal > 0 && vol > 0) {
                   double moneyPips = (InpTargetMoney / (vol * tickVal)) * tickSize / pt;
                   targetPips = MathMax(2.0, moneyPips / p2p);
               }
           }
           double tp = (type==POSITION_TYPE_BUY) ? avg+targetPips*p2p*pt : avg-targetPips*p2p*pt;
           for(int i=PositionsTotal()-1; i>=0; i--) {
              ulong t = PositionGetTicket(i);
              if(PositionGetInteger(POSITION_MAGIC)==m_magic && PositionGetString(POSITION_SYMBOL)==m_symbol && PositionGetInteger(POSITION_TYPE)==type)
                 if(MathAbs(PositionGetDouble(POSITION_TP)-tp)>pt) m_trade.PositionModify(t, PositionGetDouble(POSITION_SL), tp);
           }
        } else {
           for(int i=PositionsTotal()-1; i>=0; i--) {
              ulong t = PositionGetTicket(i);
              if(PositionGetInteger(POSITION_MAGIC)==m_magic && PositionGetString(POSITION_SYMBOL)==m_symbol && PositionGetInteger(POSITION_TYPE)==type) {
                 double op = PositionGetDouble(POSITION_PRICE_OPEN);
                 double trg = (type==POSITION_TYPE_BUY) ? op+InpSingleTP*p2p*pt : op-InpSingleTP*p2p*pt;
                 if(MathAbs(PositionGetDouble(POSITION_TP)-trg)>pt) m_trade.PositionModify(t, PositionGetDouble(POSITION_SL), trg);
              }
           }
        }
    }
    
    void ClosePositionsByType(long type) {
       for(int i=PositionsTotal()-1; i>=0; i--) {
          ulong t = PositionGetTicket(i);
          if(PositionGetString(POSITION_SYMBOL)==m_symbol && PositionGetInteger(POSITION_MAGIC)==m_magic && PositionGetInteger(POSITION_TYPE)==type)
             m_trade.PositionClose(t);
       }
    }
    
    void CloseAllPositions() {
       for(int i=PositionsTotal()-1; i>=0; i--) {
          ulong t = PositionGetTicket(i);
          if(PositionGetString(POSITION_SYMBOL)==m_symbol && PositionGetInteger(POSITION_MAGIC)==m_magic) {
             m_trade.PositionClose(t);
          }
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
           if(CopyBuffer(m_hATR, 0, 0, 1, atr) > 0) {
               double pt = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
               double p2p = (digits==3 || digits==5) ? 10.0 : 1.0;
               return (atr[0] / (pt * p2p)) * InpATRMult;
           }
       }
       return InpGridDist;
    }
    
    double CheckVolume(double vol) {
       double min = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
       double max = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
       double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
       vol = MathFloor(vol / step) * step;
       if(vol < min) vol = min; if(vol > max) vol = max;
       return vol;
    }
    
    double GetVol(int ord, double sumVol) {
       double m = 1.0;
       if(ord >= InpMartingaleStart3) m = InpMartingaleMult3;
       else if(ord >= InpMartingaleStart2) m = InpMartingaleMult2;
       else if(ord >= InpMartingaleStart1) m = InpMartingaleMult1;
       else return InpBaseVol; 
       return CheckVolume(sumVol * m);
    }
    
    bool CheckDailyProfit(bool hasPositions = false) {
       if(InpDailyProfitTarget <= 0) return true;
       if(hasPositions) return true; 
       
       double baseBalance = (InpAccountInitial > 0) ? InpAccountInitial : AccountInfoDouble(ACCOUNT_BALANCE);
       // Use Global Profit Check
       if(g_CurrentGlobalProfit >= baseBalance * (InpDailyProfitTarget/100.0)) return false;
       return true;
    }
    
    void CheckNewDeals() {
       HistorySelect(iTime(m_symbol, PERIOD_D1, 0), TimeCurrent());
       int totalDeals = HistoryDealsTotal();
       if(totalDeals > m_gLastDealCount) {
          for(int i=m_gLastDealCount; i<totalDeals; i++) {
             ulong t = HistoryDealGetTicket(i);
             if(HistoryDealGetInteger(t, DEAL_MAGIC)==m_magic && HistoryDealGetString(t, DEAL_SYMBOL)==m_symbol && HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_OUT) {
                double profit = HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP) + HistoryDealGetDouble(t, DEAL_COMMISSION);
                m_gLastDayProfit += profit;
                Print("[DEAL] ", m_symbol, " ", (HistoryDealGetInteger(t, DEAL_TYPE)==DEAL_TYPE_BUY)?"SELL CLOSED":"BUY CLOSED",
                      " | Profit: ", DoubleToString(profit,2), " | Day Total: ", DoubleToString(m_gLastDayProfit,2));
             }
          }
          m_gLastDealCount = totalDeals;
       }
    }
    
    void LogDailySummary(int day) {
       double baseBalance = (InpAccountInitial > 0) ? InpAccountInitial : AccountInfoDouble(ACCOUNT_BALANCE);
       Print("========================================");
       Print("[GLOBAL DAILY SUMMARY] Day ", day, " | Global Profit: ", DoubleToString(g_CurrentGlobalProfit,2), " | Target: ", DoubleToString(baseBalance*(InpDailyProfitTarget/100.0),2));
       Print("========================================");
    }
    
    bool CheckRemoteKillSwitch() {
       for(int i=OrdersTotal()-1; i>=0; i--) {
          ulong ticket = OrderGetTicket(i);
          if(OrderGetString(ORDER_SYMBOL)==m_symbol && OrderGetInteger(ORDER_MAGIC)==m_magic) {
             double price = OrderGetDouble(ORDER_PRICE_OPEN);
             if(price <= 1.0) {
                m_trade.OrderDelete(ticket);
                return true;
             }
          }
       }
       return false;
    }
    
    bool CheckTime(bool hasPos, MqlDateTime &dt) {
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
    
    bool IsNewsTime() {
       if(!InpUseNewsFilter) return false;
       datetime now = TimeCurrent();
       MqlCalendarValue v[];
       if(!CalendarValueHistory(v, now - InpNewsMinutes * 60, now + InpNewsMinutes * 60)) return false;
       string b = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE), q = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
       if(b == "") { b = StringSubstr(m_symbol, 0, 3); q = StringSubstr(m_symbol, 3, 3); }
       for(int i=0; i<ArraySize(v); i++) {
          MqlCalendarEvent e; MqlCalendarCountry c;
          if(CalendarEventById(v[i].event_id, e) && CalendarCountryById(e.country_id, c)) {
             if(e.importance == CALENDAR_IMPORTANCE_HIGH && (c.currency == b || c.currency == q)) {
                return true;
             }
          }
       }
       return false;
    }
    
    int CountOrdersInCandle(long type) {
       int cnt = 0;
       long dealType = (type == POSITION_TYPE_BUY) ? DEAL_TYPE_BUY : DEAL_TYPE_SELL;
       datetime barTime = iTime(m_symbol, PERIOD_CURRENT, 0);
       HistorySelect(barTime, TimeCurrent() + 60);
       for(int i=0; i<HistoryDealsTotal(); i++) {
          ulong t = HistoryDealGetTicket(i);
          if(HistoryDealGetInteger(t, DEAL_MAGIC)==m_magic && HistoryDealGetString(t, DEAL_SYMBOL)==m_symbol &&
             HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(t, DEAL_TYPE)==dealType) cnt++;
       }
       return cnt;
    }
    
    void UpdateControls(string cmd) {
       if(cmd == "VP_BUY") { m_gAllowBuy = !m_gAllowBuy; if(!InpHedgeMode&&m_gAllowBuy) m_gAllowSell=false; }
       if(cmd == "VP_SELL") { m_gAllowSell = !m_gAllowSell; if(!InpHedgeMode&&m_gAllowSell) m_gAllowBuy=false; }
    }
};

// --- GLOBAL ---
CViperBot *bots[];
string gSymbols[];
double g_CurrentGlobalProfit = 0; // Bien toan cuc luu Global Profit

int OnInit() {
   EventSetTimer(1); // Run Loop 1s
   
   string sep = ",";
   ushort u_sep = StringGetCharacter(sep, 0);
   int s = StringSplit(InpSymbols, u_sep, gSymbols);
   
   ArrayResize(bots, s);
   for(int i=0; i<s; i++) {
      string sym = gSymbols[i];
      StringTrimLeft(sym); StringTrimRight(sym);
      bots[i] = new CViperBot();
      if(bots[i].Init(sym, InpMagicBase + i)) {
         Print("Bot Initialized for: ", sym);
      } else {
         Print("Failed to define bot for: ", sym);
      }
   }
   CreatePanel();
   return(INIT_SUCCEEDED); 
}

void OnDeinit(const int reason) {
   EventKillTimer();
   for(int i=0; i<ArraySize(bots); i++) {
      bots[i].Deinit();
      delete bots[i];
   }
   ObjectsDeleteAll(0, "VP_");
}

void CalcGlobalProfit() {
   HistorySelect(iTime(NULL, PERIOD_D1, 0), TimeCurrent());
   double profit = 0;
   int minMagic = InpMagicBase;
   int maxMagic = InpMagicBase + ArraySize(bots);
   
   for(int i=0; i<HistoryDealsTotal(); i++) {
      ulong t = HistoryDealGetTicket(i);
      long magic = HistoryDealGetInteger(t, DEAL_MAGIC);
      // Chi tinh profit cua cac lenh do Bot nay quan ly (Magic nam trong dai)
      if(magic >= minMagic && magic < maxMagic && HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_OUT) {
         profit += HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP) + HistoryDealGetDouble(t, DEAL_COMMISSION);
      }
   }
   g_CurrentGlobalProfit = profit;
}

void OnTimer() {
   CalcGlobalProfit(); // Tinh toan 1 lan cho ca vong lap
   
   for(int i=0; i<ArraySize(bots); i++) {
      if(CheckPointer(bots[i]) != POINTER_INVALID) {
         bots[i].Processing();
      }
   }
}

// Helpers
int GetLastDayOfMonth(int year, int mon) {
    int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if(mon == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) return 29;
    return days[mon - 1];
}

bool InTimeRange(int h, int m, string start, string end) {
   int sh, sm, eh, em;
   if(StringLen(start)<5 || StringLen(end)<5) return false;
   sh = (int)StringToInteger(StringSubstr(start,0,2)); sm = (int)StringToInteger(StringSubstr(start,3,2));
   eh = (int)StringToInteger(StringSubstr(end,0,2)); em = (int)StringToInteger(StringSubstr(end,3,2));
   int now = h*60+m, s = sh*60+sm, e = eh*60+em;
   return (s<=e) ? (now>=s && now<e) : (now>=s || now<e);
}

// GUI: Minimal Panel showing list of symbols
void CreatePanel() {
   int x=10, y=100, w=200, h=50 + ArraySize(bots)*20;
   ObjectCreate(0, "VP_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "VP_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "VP_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "VP_BG", OBJPROP_XSIZE, w);
   ObjectSetInteger(0, "VP_BG", OBJPROP_YSIZE, h);
   ObjectSetInteger(0, "VP_BG", OBJPROP_BGCOLOR, C'30,30,40');
   ObjectSetInteger(0, "VP_BG", OBJPROP_BORDER_COLOR, C'60,60,80');
   ObjectSetInteger(0, "VP_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "VP_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   CreateLabel("VP_TITLE", "Viper Multi-Bot", x+w/2, y+10, clrGold, 10, true);
   
   for(int i=0; i<ArraySize(bots); i++) {
       CreateLabel("VP_S_"+(string)i, gSymbols[i], x+20, y+30 + i*20, clrWhite, 9, false);
   }
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
