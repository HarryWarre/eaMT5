//+------------------------------------------------------------------+
//|                                          THOR BOT - Thần Sấm    |
//|                           Triết lý: High Winrate (SL = 3 * TP)   |
//|                                  Copyright 2026, DaiViet         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DaiViet"
#property version   "2.00" // High Winrate Version
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT - Luật chơi                                                |
//+------------------------------------------------------------------+
input group "=== CHIẾN THUẬT HIGH WINRATE ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15; // Khung thực thi
input double InpTakeProfitPips = 20.0;    // Take Profit (Pips)
input double InpStopLossPips   = 60.0;    // Stop Loss (Pips) - SL = 3 * TP

input group "=== MARTINGALE KHAI THÁC CHUỖI THUA ==="
input double InpBaseLot        = 0.01;    // Lot khởi điểm
input double InpMartMultiplier = 4.0;     // Hệ số nhân (x4 để thắng 1 lệnh bù được 3 lệnh thua + lãi)

input group "=== TÍN HIỆU (ODIN CORE) ==="
input int    InpRSIPeriod      = 14;      // RSI Period
input double InpPinBarRatio    = 2.0;     // Tỉ lệ râu/thân nến tối thiểu

input group "=== INTRADAY & QUẢN LÝ ==="
input int    InpStartHour      = 8;       // Giờ bắt đầu
input int    InpEndHour        = 22;      // Giờ kết thúc vào lệnh
input int    InpCloseHour      = 23;      // Giờ đóng lệnh lời
input int    InpNewsBufferMins = 60;      // Né bão (phút)
input int    InpMagic          = 202604;  // Magic Number Thor

//+------------------------------------------------------------------+
//| BIẾN TOÀN CỤC                                                   |
//+------------------------------------------------------------------+
CTrade         Trade;
int            handleRSI;
int            lossStreak;        // Đếm chuỗi thua liên tiếp hiện tại
double         currentLot;        // Lot hiện tại (tăng theo Martingale)

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   Trade.SetExpertMagicNumber(InpMagic);
   
   handleRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE) return INIT_FAILED;
   
   lossStreak = 0;
   currentLot = InpBaseLot;
   
   Print("Thor: High Winrate Mode (SL=3TP). Chấp nhận rủi ro để chiến thắng.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleRSI);
  }

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Quản lý Intraday: Đóng lệnh lời cuối ngày
   ManageIntradayExit();
   
   // Chỉ xử lý khi có nến mới
   if(!IsNewBar()) return;
   
   // Kiểm tra giờ giao dịch
   if(!IsWithinTradingHours()) return;
   
   // Kiểm tra bão tin tức
   if(IsNewsStorm()) return;
   
   // Chỉ vào lệnh nếu chưa có lệnh nào (Thor đánh từng lệnh một)
   if(CountMyOrders() > 0) return;
   
   // Nếu chuỗi thua dài -> Không reset, tiếp tục chiến đấu (Infinite Martingale)
   // Bỏ qua check InpMaxLossStreak theo yêu cầu "Martingale liên tục"
   
   // Quét tín hiệu (Odin Core: PA + RSI + D1)
   int signal = CheckPASignal();
   
   if(signal != 0)
      ExecuteEntry(signal);
  }

//+------------------------------------------------------------------+
//| SIGNAL: RSI + D1 + Price Action (Odin Core)                     |
//+------------------------------------------------------------------+
int CheckPASignal()
  {
   // 1. D1 Trend
   int d1Dir = GetDailyDirection();
   if(d1Dir == 0) return 0;
   
   // 2. RSI Filter
   double rsi = GetRSI();
   
   // 3. Price Action
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpTimeframe, 1, 2, rates) < 2) return 0;
   
   bool isPinBuy  = IsPinBar(rates[0], 1);
   bool isPinSell = IsPinBar(rates[0], -1);
   bool isEngBuy  = IsEngulfing(rates[0], rates[1], 1);
   bool isEngSell = IsEngulfing(rates[0], rates[1], -1);

   // BUY Signal
   if(d1Dir == 1 && rsi > 50.0)
     {
      if(isPinBuy || isEngBuy) return 1;
     }
   
   // SELL Signal
   if(d1Dir == -1 && rsi < 50.0)
     {
      if(isPinSell || isEngSell) return -1;
     }
   
   return 0;
  }

//+------------------------------------------------------------------+
//| EXECUTE: Vào lệnh với High Winrate Setup                         |
//+------------------------------------------------------------------+
void ExecuteEntry(int direction)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double price = (direction == 1) ? ask : bid;
   
   // Tính SL/TP theo Pips
   double slDist = InpStopLossPips * point * 10; // Convert pips to points (x10 for 5-digit broker)
   double tpDist = InpTakeProfitPips * point * 10;
   
   // Nếu broker 4 số thì bỏ x10
   if(_Digits == 2 || _Digits == 4)
     {
      slDist = InpStopLossPips * point;
      tpDist = InpTakeProfitPips * point;
     }
   
   double sl = (direction == 1) ? price - slDist : price + slDist;
   double tp = (direction == 1) ? price + tpDist : price - tpDist;
   
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   string comment = StringFormat("Thor Streak %d", lossStreak);
   
   if(direction == 1)
      Trade.Buy(currentLot, _Symbol, price, sl, tp, comment);
   else
      Trade.Sell(currentLot, _Symbol, price, sl, tp, comment);
      
   Print("Thor: Ra đòn! Dir=", direction, " Lot=", currentLot, " Streak=", lossStreak);
  }

//+------------------------------------------------------------------+
//| TRADE EVENT: Xử lý kết quả lệnh (Thắng/Thua)                    |
//+------------------------------------------------------------------+
void OnTrade()
  {
   if(HistorySelect(0, TimeCurrent())) // Có thể tối ưu bằng cách chỉ select history gần nhất
     {
      int total = HistoryDealsTotal();
      if(total > 0)
        {
         ulong ticket = HistoryDealGetTicket(total - 1);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagic &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
           {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            // Nếu lệnh vừa đóng là THUA (Profit < 0)
            if(profit < 0)
              {
               lossStreak++; // Tăng chuỗi thua
               
               // Tính Lot dựa trên Streak (An toàn hơn tích lũy)
               // Lot = Base * Multiplier^Streak
               double rawLot = InpBaseLot * MathPow(InpMartMultiplier, lossStreak);
               
               // Chuẩn hóa lot
               double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
               double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
               double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
               
               if(stepLot > 0)
                 {
                  // Thêm epsilon để tránh lỗi làm tròn xuống (ví dụ 3.999 -> 3)
                  double steps = MathRound(rawLot / stepLot);
                  currentLot = steps * stepLot;
                 }
               else
                  currentLot = rawLot;
                  
               if(currentLot < minLot) currentLot = minLot;
               if(currentLot > maxLot) currentLot = maxLot;
               
               currentLot = NormalizeDouble(currentLot, 2);
               
               Print("Thor: Thua lệnh! Tăng streak lên ", lossStreak, ". Lot sau (calculated): ", currentLot);
              }
            // Nếu lệnh vừa đóng là THẮNG (Profit > 0)
            else
              {
               lossStreak = 0; // Reset chuỗi thua
               currentLot = InpBaseLot; // Reset về lot cơ bản
               Print("Thor: Thắng lệnh! Reset streak. Lot sau: ", currentLot);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS (Kế thừa Odin)                                 |
//+------------------------------------------------------------------+
bool IsNewBar() {
   static datetime lastBar = 0;
   datetime current = iTime(_Symbol, InpTimeframe, 0);
   if(current != lastBar) { lastBar = current; return true; }
   return false;
}

int GetDailyDirection() {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, rates) < 1) return 0;
   return (rates[0].close > rates[0].open) ? 1 : (rates[0].close < rates[0].open ? -1 : 0);
}

double GetRSI() {
   double buf[]; ArraySetAsSeries(buf, true);
   return (CopyBuffer(handleRSI, 0, 0, 1, buf) < 1) ? 50.0 : buf[0];
}

bool IsPinBar(MqlRates &c, int d) {
   double body = MathAbs(c.close - c.open);
   double u = c.high - MathMax(c.open, c.close);
   double l = MathMin(c.open, c.close) - c.low;
   if(body==0) body=_Point;
   return (d==1) ? (l >= body*InpPinBarRatio && u < l*0.5) : (u >= body*InpPinBarRatio && l < u*0.5);
}

bool IsEngulfing(MqlRates &c, MqlRates &p, int d) {
   return (d==1) ? (c.close > c.open && c.close > p.high && c.open < p.low) : 
                   (c.close < c.open && c.close < p.low && c.open > p.high);
}

bool IsWithinTradingHours() {
   MqlDateTime dt; TimeCurrent(dt);
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

bool IsNewsStorm() { return false; } // Placeholder

int CountMyOrders() {
   int count=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) count++;
   return count;
}

void ManageIntradayExit() {
   MqlDateTime dt; TimeCurrent(dt);
   if(dt.hour >= InpCloseHour) {
      double profit=0;
      for(int i=PositionsTotal()-1; i>=0; i--)
         if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
            profit += PositionGetDouble(POSITION_PROFIT);
      
      // Chỉ đóng nếu LỜI. Nếu LỖ -> Gồng qua đêm (vì SL xa)
      if(profit > 0) {
         for(int i=PositionsTotal()-1; i>=0; i--)
            if(PositionGetSymbol(i)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
               Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
      }
   }
}
