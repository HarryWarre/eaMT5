#property copyright "Copyright 2026, DaiVietQuant"
#property link      "https://t.me/Ph_Viet"
#property version   "3.10"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayString.mqh>
CTrade trade;

// --- INPUTS ---
input group "Cài đặt Agent"
input int    InpAgentCount   = 5;         // Số lượng Agent chạy song song (Hiệu lực khi Multi-Agent)
input int    InpMagic        = 123456;    // Magic Number Cơ sở (Cộng thêm ID)

input group "Cài đặt Chiến thuật"
enum ENUM_LOT_MODE {
   LOT_MODE_MARTINGALE, // (Martingale)
   LOT_MODE_FIBONACCI   // Fibonacci
};

input string InpSymbols      = "EURUSD,GBPUSD,XAUUSD,USDJPY"; // Danh sách Cặp tiền (Phân cách dấu phẩy)
input ENUM_LOT_MODE InpLotMode = LOT_MODE_MARTINGALE; // Chế độ Quản lý vốn
input double InpBaseLot      = 0.01;      // Khối lượng Khởi điểm
input double InpMultiplier   = 2.0;       // Hệ số Nhân lạnh (Martingale)
input int    InpTP           = 300;       // Chốt lời (Points)
input int    InpSL           = 150;       // Cắt lỗ (Points)

input int    InpCooldown     = 10;        // Thời gian nghỉ giữa các lệnh (Giây)

input group "Phantom & Neural"
input int    InpPhantomDepth = 2;         // Số lệnh ảo thua trước khi vào thật (0 = Tắt)
input bool   InpUseNeural    = true;      // Sử dụng Neural chọn cặp tiền
input bool   InpUsePreTrain  = true;      // Huấn luyện Dữ liệu Quá khứ?
input int    InpTrainDays    = 365;       // Số ngày huấn luyện (Warm-up)
input bool   InpAutoRetrain  = true;      // Tự động huấn luyện lại mỗi tuần?
input double InpWeightWin    = 10.0;     // Trọng số Tăng khi Thắng
input double InpWeightLoss   = 5.0;      // Trọng số Giảm khi Thua
input double InpMinWeight    = 10.0;     // Trọng số Tối thiểu
input double InpMaxWeight    = 500.0;    // Trọng số Tối đa

input group "== THỜI GIAN GIAO DỊCH (GIỜ VN GMT+7) =="
input bool   InpUseTimeSlot      = true;     // Kích hoạt Bộ lọc Thời gian?
input string InpT1Start          = "09:00";  // Khung 1: Bắt đầu
input string InpT1End            = "17:00";  // Khung 1: Kết thúc
input string InpT2Start          = "22:00";  // Khung 2: Bắt đầu
input string InpT2End            = "03:00";  // Khung 2: Kết thúc

input group "== THỜI GIAN NGHỈ (GIỜ VN GMT+7) =="
input bool   InpUseNoTimeSlot    = false;    // Kích hoạt Thời gian NGHỈ?
input string InpNT1Start         = "17:00";  // Nghỉ 1: Bắt đầu
input string InpNT1End           = "21:00";  // Nghỉ 1: Kết thúc
input string InpNT2Start         = "03:00";  // Nghỉ 2: Bắt đầu
input string InpNT2End           = "09:00";  // Nghỉ 2: Kết thúc
input int    InpServerGMTOffset  = 2;        // Múi giờ Server (VD: IC Markets=2)

input group "Bộ lọc & Bảo vệ"
input bool   InpUseUseNewsFilter = false;    // Lọc Tin tức Mạnh (High Impact)
input int    InpNewsMinutes      = 30;       // Số phút tránh tin (Trước/Sau)
input double InpBattleRoyaleLoss = 50.0; // Giới hạn Thua lỗ Agent ($) -> Ban 24h

input group "Poker: General"
input bool   InpUsePoker         = true;     // Kích hoạt Poker Mode
input int    InpFlopProb         = 20;       // Tỷ lệ Flop (%)

input group "Poker: Multipliers"
input double InpRaiseElder       = 2.0;      // Raise: Elder System
input double InpRaiseBB          = 1.5;      // Raise: BB Blast
input double InpRaisePullback    = 1.5;      // Raise: RSI Pullback
input double InpRaiseTrendRSI    = 1.2;      // Raise: Trend RSI
input double InpRaiseTrendMACD   = 1.2;      // Raise: Trend MACD

input group "Poker: Indicators"
input int    InpPokerRSIPeriod   = 14;       // Chu kỳ RSI
input int    InpPokerBBPeriod    = 20;       // Chu kỳ BB
input double InpPokerBBDev       = 2.0;      // Độ lệch BB
input int    InpPokerEMAPeriod   = 13;       // Chu kỳ EMA (Elder)

// --- UTILS FORWARD DECLARATION ---
bool CheckTime();
bool InTimeRange(int h, int m, string start, string end);
bool IsNewsTime(string sym);
double CheckVolume(string sym, double vol);
double GetFibonacci(int n);
double GetPokerMultiplier(string sym, ENUM_ORDER_TYPE dir, int& outHandID, int shift=0); 
void TrainNetwork(int days);
// bool IsPokerHand(string sym, ENUM_ORDER_TYPE dir); // Deprecated
int SelectNextSymbol(bool allowFlop); 
void UpdateStatus(string txt, color clr=clrGray);
void CreatePanel();
void UpdatePanel();
void CreateLabel(string name, string text, int x, int y, color clr, int sz);
void UpdateLabel(string name, string text, color clr);
void StartVirtualTrade();
void CheckVirtualResult();
void CheckRealResult();
void CheckLastResultLegacy();
void ResetChain();
void AdvanceChain(bool wasReal);
void OpenRealTrade(string sym);
int SelectNextSymbol();
void UpdateWeights(int idx, bool win);
void LogDailyStats();
int CountPositions();

// --- GLOBALS ---
string g_Symbols[];
double g_Weights[];         
double g_NetProfit[];       // Battle Royale Profit Tracker
datetime g_BanUntil[];      // Battle Royale Ban Timer
int    g_SymbolIdx = 0;     // Current Symbol Index
double g_CurrentLot;        // Current Lot Size (Simulated or Real)
ENUM_ORDER_TYPE g_NextDir;  // Next Direction
datetime g_LastDealTime = 0;
int    g_WinStreak = 0;     // Consecutive Wins Counter
int    g_FibIndex = 0;      // Fibonacci Sequence Index
int    g_RSIHandles[];      // RSI Indicator Handles for each symbol
int    g_BBHandles[];       // Bollinger Bands Handles 
int    g_EMAHandles[];      // EMA Handles (Elder)
int    g_MACDHandles[];     // MACD Handles (Elder/Light)

datetime g_LastTrainTime = 0; // Last Training Time

// Phantom Logic
int    g_CurrentChainLength = 0; // How many losses in a row (Virtual + Real)
bool   g_IsVirtualActive = false;
string g_VirtSym;
ENUM_ORDER_TYPE g_VirtType;
double g_VirtOpenPrice, g_VirtSL, g_VirtTP;

int OnInit() {
   trade.SetExpertMagicNumber(InpMagic);
   
   // Parse Symbols
   string sep = ",";
   ushort u_sep = StringGetCharacter(sep, 0);
   int s = StringSplit(InpSymbols, u_sep, g_Symbols);
   
   if(s == 0) { Print("Error: No symbols defined!"); return INIT_FAILED; }
   
   ArrayResize(g_Weights, s);
   ArrayResize(g_NetProfit, s);
   ArrayResize(g_BanUntil, s);
   ArrayResize(g_RSIHandles, s);
   ArrayResize(g_BBHandles, s);
   ArrayResize(g_EMAHandles, s);
   ArrayResize(g_MACDHandles, s);
   
   for(int i=0; i<s; i++) {
      StringTrimLeft(g_Symbols[i]); StringTrimRight(g_Symbols[i]);
      if(!SymbolSelect(g_Symbols[i], true)) Print("Failed to select ", g_Symbols[i]);
      g_Weights[i] = 100.0; // Initial Weight
      g_NetProfit[i] = 0.0;
      g_BanUntil[i] = 0;
      
      // Init RSI Handle
      g_RSIHandles[i] = iRSI(g_Symbols[i], PERIOD_CURRENT, InpPokerRSIPeriod, PRICE_CLOSE);
      if(g_RSIHandles[i] == INVALID_HANDLE) Print("Error creating RSI handle for ", g_Symbols[i]);
      
      
      // Init BB Handle
      g_BBHandles[i] = iBands(g_Symbols[i], PERIOD_CURRENT, InpPokerBBPeriod, 0, InpPokerBBDev, PRICE_CLOSE);
      if(g_BBHandles[i] == INVALID_HANDLE) Print("Error creating BB handle for ", g_Symbols[i]);
      
      // Init EMA Handle (Elder)
      g_EMAHandles[i] = iMA(g_Symbols[i], PERIOD_CURRENT, InpPokerEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_EMAHandles[i] == INVALID_HANDLE) Print("Error creating EMA handle for ", g_Symbols[i]);
      
      // Init MACD Handle (Elder/Light)
      g_MACDHandles[i] = iMACD(g_Symbols[i], PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
      if(g_MACDHandles[i] == INVALID_HANDLE) Print("Error creating MACD handle for ", g_Symbols[i]);
   }
   
   // Initialize State
   g_CurrentLot = InpBaseLot;
   g_FibIndex = 0;
   g_SymbolIdx = 0;
   g_NextDir = ORDER_TYPE_BUY; 
   g_CurrentChainLength = 0;
   g_IsVirtualActive = false;
   
   // Sync Last Deal Time
   HistorySelect(0, TimeCurrent());
   bool found = false;
   int total = HistoryDealsTotal();
   for(int i=total-1; i>=0; i--) {
       ulong t = HistoryDealGetTicket(i);
       long magic = HistoryDealGetInteger(t, DEAL_MAGIC);
       if(magic >= InpMagic && magic <= InpMagic + 10 && HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
           g_LastDealTime = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
           found = true;
           break;
       }
   }
   if(!found) g_LastDealTime = TimeCurrent(); 

   CreatePanel();
   EventSetTimer(1); 
   
   // Pre-Train
   if(InpUsePreTrain) {
       Print("Starting Historical Training (", InpTrainDays, " days)...");
       TrainNetwork(InpTrainDays);
       g_LastTrainTime = TimeCurrent();
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   ObjectsDeleteAll(0, "CB_");
   for(int i=0; i<ArraySize(g_RSIHandles); i++) IndicatorRelease(g_RSIHandles[i]);
   for(int i=0; i<ArraySize(g_BBHandles); i++) IndicatorRelease(g_BBHandles[i]);
   for(int i=0; i<ArraySize(g_EMAHandles); i++) IndicatorRelease(g_EMAHandles[i]);
   for(int i=0; i<ArraySize(g_MACDHandles); i++) IndicatorRelease(g_MACDHandles[i]);
}

void OnTimer() {
   // 1. Check Virtual Trade (if active)
   if(g_IsVirtualActive) {
      CheckVirtualResult();
      UpdateStatus("Phantom Mode (" + (string)g_CurrentChainLength + "/" + (string)InpPhantomDepth + ")");
      return; 
   }
   
   // 1b. Check Retraining (Weekly)
   if(InpAutoRetrain && TimeCurrent() - g_LastTrainTime > 7 * 24 * 3600) {
       Print("Weekly Retraining...");
       TrainNetwork(7); // Retrain on last week
       g_LastTrainTime = TimeCurrent();
   }

   // 2. Check Real Open Positions
   int posCount = CountPositions();
   if(posCount > 0) {
      UpdateStatus("Real Trade Active");
      return; 
   }
   
   // 3. Check Result of Last REAL Trade
   if(InpPhantomDepth > 0) CheckRealResult(); 
   else CheckLastResultLegacy(); 
   
   // 4. Cooldown Check
   if(TimeCurrent() - g_LastDealTime < InpCooldown) {
       UpdateStatus("Cooldown: " + IntegerToString(InpCooldown - (int)(TimeCurrent() - g_LastDealTime)) + "s", clrOrange);
       return;
   }
   
   // 5. Check Filters
   if(!CheckTime()) { UpdateStatus("Time Filter", clrRed); return; }
   if(IsNewsTime(g_Symbols[g_SymbolIdx])) { UpdateStatus("News Filter (" + g_Symbols[g_SymbolIdx] + ")", clrRed); return; }

   // 6. Execution Logic
   if(g_CurrentChainLength < InpPhantomDepth) {
      StartVirtualTrade();
   } else {
      string sym = g_Symbols[g_SymbolIdx];
      OpenRealTrade(sym);
   }
}

// --- VIRTUAL TRADING ENGINE ---
void StartVirtualTrade() {
   string sym = g_Symbols[g_SymbolIdx];
   g_VirtSym = sym;
   g_VirtType = g_NextDir;
   
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   g_VirtOpenPrice = (g_NextDir == ORDER_TYPE_BUY) ? ask : bid;
   g_VirtSL = (g_NextDir == ORDER_TYPE_BUY) ? g_VirtOpenPrice - InpSL*pt : g_VirtOpenPrice + InpSL*pt;
   g_VirtTP = (g_NextDir == ORDER_TYPE_BUY) ? g_VirtOpenPrice + InpTP*pt : g_VirtOpenPrice - InpTP*pt;
   
   g_IsVirtualActive = true;
   Print("[PHANTOM] Opened Virtual ", (g_NextDir==ORDER_TYPE_BUY?"BUY":"SELL"), " on ", sym);
   UpdatePanel();
}

void CheckVirtualResult() {
   double bid = SymbolInfoDouble(g_VirtSym, SYMBOL_BID);
   double ask = SymbolInfoDouble(g_VirtSym, SYMBOL_ASK);
   
   bool closed = false;
   bool win = false;
   
   if(g_VirtType == ORDER_TYPE_BUY) {
      if(bid >= g_VirtTP) { closed=true; win=true; }
      if(bid <= g_VirtSL) { closed=true; win=false; }
   } else {
      if(ask <= g_VirtTP) { closed=true; win=true; }
      if(ask >= g_VirtSL) { closed=true; win=false; }
   }
   
   if(closed) {
      g_IsVirtualActive = false;
      g_LastDealTime = TimeCurrent(); 
      
      if(win) {
         Print("[PHANTOM] WIN on ", g_VirtSym, ". Chain Reset.");
         ResetChain(); 
      } else {
         Print("[PHANTOM] LOSS on ", g_VirtSym, ". Chain Depth: ", g_CurrentChainLength + 1);
         g_CurrentChainLength++;
         AdvanceChain(false); 
      }
      UpdatePanel();
   }
}

// --- REAL TRADING LOGIC ---
void CheckRealResult() {
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   if(total == 0) return;
   
   for(int i=total-1; i>=0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(magic >= InpMagic && magic <= InpMagic + 10 && 
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         
         long dealTime = HistoryDealGetInteger(ticket, DEAL_TIME);
         if(dealTime <= g_LastDealTime) break; 
         
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         g_LastDealTime = (datetime)dealTime;
         
         // Battle Royale Tracker
         g_NetProfit[g_SymbolIdx] += profit;
         if(g_NetProfit[g_SymbolIdx] < -InpBattleRoyaleLoss) {
             Print("Battle Royale: ", g_Symbols[g_SymbolIdx], " BANNED (24h). Loss: ", g_NetProfit[g_SymbolIdx]);
             g_BanUntil[g_SymbolIdx] = TimeCurrent() + 24 * 3600; 
             g_NetProfit[g_SymbolIdx] = 0; 
         }
         
         if(profit > 0) {
            Print("[REAL] WIN on ", HistoryDealGetString(ticket, DEAL_SYMBOL), " Profit: ", profit, ". Chain Reset.");
            UpdateWeights(g_SymbolIdx, true);
            ResetChain();
         } else {
            Print("[REAL] LOSS on ", HistoryDealGetString(ticket, DEAL_SYMBOL), " Profit: ", profit, ". Escalating.");
            UpdateWeights(g_SymbolIdx, false);
            g_CurrentChainLength++; 
            AdvanceChain(true); 
         }
         UpdatePanel();
         break;
      }
   }
}

void OpenRealTrade(string sym) {
   double price = (g_NextDir == ORDER_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double sl = (g_NextDir == ORDER_TYPE_BUY) ? price - InpSL*pt : price + InpSL*pt;
   double tp = (g_NextDir == ORDER_TYPE_BUY) ? price + InpTP*pt : price - InpTP*pt;
   
   bool res = false;
   double finalLot = g_CurrentLot;
   
   // POKER RAISE MECHANIC
   int handID = 0;
   double pokerMult = GetPokerMultiplier(sym, g_NextDir, handID);
   
   if(InpUsePoker && pokerMult > 1.0) {
       Print(">>> POKER HAND (x", pokerMult, ") DETECTED on ", sym, "!");
       finalLot = CheckVolume(sym, g_CurrentLot * pokerMult);
   }
   
   trade.SetExpertMagicNumber(InpMagic + handID); // Encode Strategy ID
   res = (g_NextDir == ORDER_TYPE_BUY) ? trade.Buy(finalLot, sym, price, sl, tp) : trade.Sell(finalLot, sym, price, sl, tp);
   trade.SetExpertMagicNumber(InpMagic); // Reset
   
   if(res) {
      Print("[REAL] Opened ", (g_NextDir==ORDER_TYPE_BUY?"BUY":"SELL"), " on ", sym, " Lot: ", finalLot, " Magic: ", InpMagic + handID);
      UpdatePanel();
   } else {
      Print("[REAL] FAIL! Lot: ", finalLot, " Err: ", trade.ResultRetcode());
   }
}

void CheckLastResultLegacy() {
   CheckRealResult();
}


// --- CHAIN MANAGEMENT ---
void ResetChain() {
   g_WinStreak++;
   
   g_SymbolIdx = SelectNextSymbol(true); 
   g_NextDir = ORDER_TYPE_BUY; 

   if(InpLotMode == LOT_MODE_MARTINGALE) {
       g_CurrentChainLength = 0; 
       if(g_WinStreak >= 3) {
           Print("Lucky Streak! Wins: ", g_WinStreak, ". Boosting Lot.");
           g_CurrentLot = g_CurrentLot * InpMultiplier; 
       } else {
           g_CurrentLot = InpBaseLot;
       }
   }
   else if(InpLotMode == LOT_MODE_FIBONACCI) {
       int oldIdx = g_FibIndex;
       g_FibIndex -= 2;
       if(g_FibIndex < 0) {
           g_FibIndex = 0;
           g_CurrentChainLength = 0; 
       } else {
           Print("Fibonacci Step Back: ", oldIdx, " -> ", g_FibIndex);
       }
       g_CurrentLot = InpBaseLot * GetFibonacci(g_FibIndex);
   }
   
   g_CurrentLot = CheckVolume(g_Symbols[g_SymbolIdx], g_CurrentLot);
}

void AdvanceChain(bool wasReal) {
   g_WinStreak = 0; 
   
   if(wasReal) {
       if(InpLotMode == LOT_MODE_MARTINGALE) {
           g_CurrentLot = g_CurrentLot * InpMultiplier;
       }
       else if(InpLotMode == LOT_MODE_FIBONACCI) {
           g_FibIndex++;
           g_CurrentLot = InpBaseLot * GetFibonacci(g_FibIndex);
       }
   }
   
   // Rotate Logic (Recovery -> Must Play -> No Flop)
   g_SymbolIdx = SelectNextSymbol(false);
   g_NextDir = (g_NextDir == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   g_CurrentLot = CheckVolume(g_Symbols[g_SymbolIdx], g_CurrentLot);
   
   Print("[AdvanceChain] New Sym: ", g_Symbols[g_SymbolIdx], " New Lot: ", g_CurrentLot);
}

// --- NEURAL SELECTION ---
int SelectNextSymbol(bool allowFlop) {
   int selected = -1;
   int available = 0;
   
   for(int i=0; i<ArraySize(g_Symbols); i++) {
       if(g_BanUntil[i] > TimeCurrent()) continue; 
       available++;
   }
   
   if(available == 0) {
       Print("Battle Royale: ALL SYMBOLS ELIMINATED! Resetting bans.");
       for(int i=0; i<ArraySize(g_BanUntil); i++) g_BanUntil[i] = 0;
   }
   
   if(!InpUseNeural) {
       selected = g_SymbolIdx; 
       int attempts = 0;
       do {
           selected = (selected + 1) % ArraySize(g_Symbols);
           attempts++;
       } while(g_BanUntil[selected] > TimeCurrent() && attempts < ArraySize(g_Symbols));
   } else {
       double totalWeight = 0;
       for(int i=0; i<ArraySize(g_Weights); i++) {
           if(g_BanUntil[i] <= TimeCurrent()) totalWeight += g_Weights[i];
       }
       
       double rand = MathRand() / 32767.0 * totalWeight;
       double sum = 0;
       selected = 0; 
       for(int i=0; i<ArraySize(g_Weights); i++) {
           if(g_BanUntil[i] > TimeCurrent()) continue; 
           
           sum += g_Weights[i];
           if(rand <= sum) { selected = i; break; }
       }
   }
   
   // Flop (Fold) Mechanic
   // Only apply if allowFlop is true AND Hand is NOT Poker Hand
   if(allowFlop && InpFlopProb > 0) {
       // Estimate Next Dir (ResetChain sets BUY, but let's assume default BUY for New Game)
       // Check if ANY raise condition is met (Multiplier > 1.0)
       int dummyID = 0;
       double mult = GetPokerMultiplier(g_Symbols[selected], ORDER_TYPE_BUY, dummyID);
       
       if(mult > 1.0) {
           // Poker Hand! Always Play!
           // Print("Poker Hand Found: ", g_Symbols[selected], ". No Flop.");
       } else {
           // Weak Hand -> Check Flop
           int roll = MathRand() % 100;
           if(roll < InpFlopProb) {
               Print("Flop (Weak Hand): Folded ", g_Symbols[selected], ". Picking another...");
               int fallback = -1;
               int attempts = 0;
               do {
                   fallback = MathRand() % ArraySize(g_Symbols);
                   attempts++;
               } while((fallback == selected || g_BanUntil[fallback] > TimeCurrent()) && attempts < 20);
               
               if(fallback != -1) selected = fallback;
           }
       }
   }
   
   return selected;
}

void UpdateWeights(int idx, bool win) {
   if(!InpUseNeural) return;
   
   if(win) g_Weights[idx] += InpWeightWin;
   else g_Weights[idx] -= InpWeightLoss;
   
   if(g_Weights[idx] < InpMinWeight) g_Weights[idx] = InpMinWeight;
   if(g_Weights[idx] > InpMaxWeight) g_Weights[idx] = InpMaxWeight;
   
   LogDailyStats();
}

void LogDailyStats() {
    double total = 0;
    string out = "Neural Stats: ";
    for(int i=0; i<ArraySize(g_Weights); i++) total += g_Weights[i];
    
    for(int i=0; i<ArraySize(g_Symbols); i++) {
        double prob = (total > 0) ? (g_Weights[i] / total * 100.0) : 0;
        out += g_Symbols[i] + "[" + DoubleToString(g_Weights[i], 0) + "|" + DoubleToString(prob, 1) + "%] ";
    }
    Print(out);
}


// --- UTILS ---
int CountPositions() {
   int cnt = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
       ulong ticket = PositionGetTicket(i);
       long magic = PositionGetInteger(POSITION_MAGIC);
       if(ticket > 0 && magic >= InpMagic && magic <= InpMagic + 10) cnt++;
   }
   return cnt;
}

// --- POKER LOGIC (TIERED) ---
// Added 'shift' parameter for Training Mode
double GetPokerMultiplier(string sym, ENUM_ORDER_TYPE dir, int& outHandID, int shift=0) {
    outHandID = 0; // Default = Normal
    if(!InpUsePoker) return 1.0;
    
    // 1. Check Daily Candle (D1 Shift 1 relative to 'shift')
    // Get Time of the 'shift' candle on CURRENT TF
    datetime barTime = iTime(sym, PERIOD_CURRENT, shift);
    
    // Find corresponding D1 bar index
    int d1Idx = iBarShift(sym, PERIOD_D1, barTime);
    // We want "Yesterday" relative to that time, so d1Idx + 1
    
    double d1Close = iClose(sym, PERIOD_D1, d1Idx+1);
    double d1Open = iOpen(sym, PERIOD_D1, d1Idx+1);
    
    bool isBull = (d1Close > d1Open);
    bool isBear = (d1Close < d1Open);
    
    // 2. Get Handles
    int hRSI = INVALID_HANDLE, hBB = INVALID_HANDLE, hEMA = INVALID_HANDLE, hMACD = INVALID_HANDLE;
    for(int i=0; i<ArraySize(g_Symbols); i++) {
        if(g_Symbols[i] == sym) {
            hRSI = g_RSIHandles[i]; hBB = g_BBHandles[i]; hEMA = g_EMAHandles[i]; hMACD = g_MACDHandles[i];
            break;
        }
    }
    if(hRSI == INVALID_HANDLE) return 1.0; 
    
    // 3. Get Data (RSI, BB, EMA, MACD) at 'shift'
    double rsiVal[1]; 
    if(CopyBuffer(hRSI, 0, shift, 1, rsiVal)!=1) return 1.0; 
    double rsi = rsiVal[0];
    
    // BB (Need 2 for cross: shift and shift+1)
    double up[2], low[2]; 
    // Note: To check crossover at 'shift', we need value at shift and shift+1
    bool hasBB = (CopyBuffer(hBB, 1, shift, 2, up)==2 && CopyBuffer(hBB, 2, shift, 2, low)==2);
    
    // EMA & MACD (Need 2 for trend/slope)
    double ema[2], macdMain[2], macdSig[2];
    bool hasEMA = (CopyBuffer(hEMA, 0, shift, 2, ema)==2);
    bool hasMACD = (CopyBuffer(hMACD, 0, shift, 2, macdMain)==2 && CopyBuffer(hMACD, 1, shift, 2, macdSig)==2);
    
    // Price at 'shift' (Close price used for history)
    double price = iClose(sym, PERIOD_CURRENT, shift);
    if(shift == 0) {
        price = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
    }
    
    // --- STRATEGY 1: ELDER SYSTEM (Priority 1) ---
    // Buy: D1 Bullish AND Price > EMA(13) AND MACD Hist Increasing
    if(hasEMA && hasMACD) {
        double hist0 = macdMain[0] - macdSig[0]; // Current Hist (at shift)
        double hist1 = macdMain[1] - macdSig[1]; // Previous Hist (at shift+1)
        
        if(dir == ORDER_TYPE_BUY) {
            if(isBull && price > ema[0] && hist0 > hist1) { outHandID=1; return InpRaiseElder; }
        } else {
            if(isBear && price < ema[0] && hist0 < hist1) { outHandID=1; return InpRaiseElder; }
        }
    }

    // --- STRATEGY 2: BB BLAST (Priority 2) ---
    // Buy: Current < Lower + RSI < 30 + Previous Candle Crossed LOWER
    if(hasBB) {
        if(dir == ORDER_TYPE_BUY) {
            // "Cần nến trước đó cắt lên" -> Previous Candle was Bullish
            double pClose = iClose(sym, PERIOD_CURRENT, shift+1);
            double pOpen = iOpen(sym, PERIOD_CURRENT, shift+1);
            bool prevBull = (pClose > pOpen);
            
            if(rsi < 30 && price < low[0] && prevBull) { outHandID=2; return InpRaiseBB; }
        } else {
            double pClose = iClose(sym, PERIOD_CURRENT, shift+1);
            double pOpen = iOpen(sym, PERIOD_CURRENT, shift+1);
            bool prevBear = (pClose < pOpen);
            // Sell: Price > Upper + RSI > 70 + PrevCandle Bearish (Cut Down)
            if(rsi > 70 && price > up[0] && prevBear) { outHandID=2; return InpRaiseBB; }
        }
    }

    // --- STRATEGY 3: RSI PULLBACK (Priority 3) ---
    // Buy: D1 Bull + RSI < 30
    if(dir == ORDER_TYPE_BUY) {
        if(isBull && rsi < 30) { outHandID=3; return InpRaisePullback; }
    } else {
        if(isBear && rsi > 70) { outHandID=3; return InpRaisePullback; }
    }

    // --- STRATEGY 4: TREND RSI (Priority 4) ---
    // Buy: D1 Bull + RSI > 50
    if(dir == ORDER_TYPE_BUY) {
        if(isBull && rsi > 50) { outHandID=4; return InpRaiseTrendRSI; }
    } else {
        if(isBear && rsi < 50) { outHandID=4; return InpRaiseTrendRSI; }
    }
    
    // --- STRATEGY 5: TREND MACD (Priority 5) ---
    // Buy: D1 Bull + MACD > 0
    if(hasMACD) {
        if(dir == ORDER_TYPE_BUY) {
            if(isBull && macdMain[0] > 0) { outHandID=5; return InpRaiseTrendMACD; }
        } else {
            if(isBear && macdMain[0] < 0) { outHandID=5; return InpRaiseTrendMACD; }
        }
    }
    
    return 1.0; // No Raise
}

void TrainNetwork(int days) {
    if(days <= 0) return;
    int bars = days; 
    
    for(int s=0; s<ArraySize(g_Symbols); s++) {
        string sym = g_Symbols[s];
        // Use Period D1 bars for loop count
        int d1Bars = iBars(sym, PERIOD_D1);
        if(bars > d1Bars) bars = d1Bars - 2;

        for(int i=bars; i>=1; i--) {
            // 1. Map D1 index 'i' to Current TF shift
            datetime t = iTime(sym, PERIOD_D1, i);
            int shift = iBarShift(sym, PERIOD_CURRENT, t);
            if(shift == -1) continue;
            
            int dummyID=0;
            // 2. Check Signals
            double multBuy = GetPokerMultiplier(sym, ORDER_TYPE_BUY, dummyID, shift);
            double multSell = GetPokerMultiplier(sym, ORDER_TYPE_SELL, dummyID, shift);
            
            // 3. Check Outcome (Next Day Close)
            // Next day is i-1
            double nextClose = iClose(sym, PERIOD_D1, i-1);
            double nextOpen = iOpen(sym, PERIOD_D1, i-1);
            bool isBullNext = (nextClose > nextOpen);
            
            if(multBuy > 1.0) {
                 if(isBullNext) UpdateWeights(s, true); else UpdateWeights(s, false);
            }
            if(multSell > 1.0) {
                 if(!isBullNext) UpdateWeights(s, true); else UpdateWeights(s, false);
            }
        }
    }
    LogDailyStats();
}




double CheckVolume(string sym, double vol) {
   double min = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   vol = MathFloor(vol / step) * step;
   if(vol < min) vol = min; if(vol > max) vol = max;
   return vol;
}

// GUI & FILTERS
bool CheckTime() {
   datetime vnTime = TimeCurrent() - (InpServerGMTOffset * 3600) + (7 * 3600);
   MqlDateTime dt; TimeToStruct(vnTime, dt); 
   int h = dt.hour, m = dt.min;
   if(InpUseNoTimeSlot && (InTimeRange(h,m,InpNT1Start,InpNT1End) || InTimeRange(h,m,InpNT2Start,InpNT2End))) return false;
   if(InpUseTimeSlot) return (InTimeRange(h,m,InpT1Start,InpT1End) || InTimeRange(h,m,InpT2Start,InpT2End));
   return true;
}
bool InTimeRange(int h, int m, string start, string end) {
   int sh=(int)StringToInteger(StringSubstr(start,0,2)), sm=(int)StringToInteger(StringSubstr(start,3,2));
   int eh=(int)StringToInteger(StringSubstr(end,0,2)), em=(int)StringToInteger(StringSubstr(end,3,2));
   int now=h*60+m, s=sh*60+sm, e=eh*60+em;
   return (s<=e) ? (now>=s && now<e) : (now>=s || now<e);
}
bool IsNewsTime(string sym) {
   if(!InpUseUseNewsFilter) return false;
   datetime now = TimeCurrent(); MqlCalendarValue v[];
   if(!CalendarValueHistory(v, now - InpNewsMinutes * 60, now + InpNewsMinutes * 60)) return false;
   string b = SymbolInfoString(sym, SYMBOL_CURRENCY_BASE), q = SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT);
   if(b == "") { b = StringSubstr(sym, 0, 3); q = StringSubstr(sym, 3, 3); }
   for(int i=0; i<ArraySize(v); i++) {
      MqlCalendarEvent e; MqlCalendarCountry c;
      if(CalendarEventById(v[i].event_id, e) && CalendarCountryById(e.country_id, c)) {
         if(e.importance == CALENDAR_IMPORTANCE_HIGH && (c.currency == b || c.currency == q)) return true;
      }
   }
   return false;
}

void CreatePanel() {
   int x=20, y=50; CreateLabel("CB_HEAD", "CERBERUS PHANTOM", x, y, clrPurple, 12);
   y+=25; CreateLabel("CB_STATUS", "Idle", x, y, clrGray, 10);
   y+=20; CreateLabel("CB_CHAIN", "Chain: 0", x, y, clrWhite, 10);
   y+=20; CreateLabel("CB_NEXT", "Next: --", x, y, clrGold, 10);
   UpdatePanel();
}
void UpdateStatus(string txt, color clr=clrGray) { UpdateLabel("CB_STATUS", txt, clr); }
void UpdatePanel() {
   UpdateLabel("CB_CHAIN", "Chain: " + (string)g_CurrentChainLength + (g_IsVirtualActive?" (Virt)":""), g_CurrentChainLength>=InpPhantomDepth ? clrLime : clrGray);
   if(ArraySize(g_Symbols) > g_SymbolIdx)
      UpdateLabel("CB_NEXT", g_Symbols[g_SymbolIdx] + " " + (g_NextDir==ORDER_TYPE_BUY?"B":"S") + " " + DoubleToString(g_CurrentLot,2), clrGold);
}
void CreateLabel(string name, string text, int x, int y, color clr, int sz) {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz); ObjectSetString(0, name, OBJPROP_TEXT, text);
}
void UpdateLabel(string name, string text, color clr) { ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); }

// --- LOT SIZING HELPERS ---
double GetFibonacci(int n) {
    if(n <= 0) return 1.0;
    if(n == 1) return 1.0;
    
    double a = 1.0;
    double b = 1.0;
    for(int i=2; i<=n; i++) {
        double temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}
