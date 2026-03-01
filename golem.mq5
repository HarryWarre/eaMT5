//+------------------------------------------------------------------+
//|                                                        golem.mq5 |
//|                                  Copyright 2026, Hoang Viet      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hoang Viet"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

CTrade         trade;
CPositionInfo  posInfo;
CSymbolInfo    symInfo;
CAccountInfo   accInfo;

//--- Enumerations
enum ENUM_TP_MODE
  {
   TP_MODE_RR_1_1 = 0, // Risk:Reward 1:1
   TP_MODE_RR_1_2 = 1, // Risk:Reward 1:2
   TP_MODE_PREV_CHIKOU = 2 // Previous Chikou (Close) High/Low
  };

enum ENUM_RISK_MODE
  {
   RISK_MODE_FIXED = 0, // Cố định Lot (Fixed Lot)
   RISK_MODE_PCT   = 1  // % Tài khoản (% of Equity)
  };

//--- Input parameters
input string               InpGeneralSeparator  = "==== Cài Đặt Chung ===="; // -------------------------
input ulong                InpMagicNumber       = 123456;                    // Magic Number
input ENUM_TIMEFRAMES      InpH4Timeframe       = PERIOD_H4;                 // Khung Thời Gian Chính (H4)
input ENUM_TIMEFRAMES      InpDailyTimeframe    = PERIOD_D1;                 // Khung Thời Gian Xác Nhận (Daily)

input string               InpIchimokuSeparator = "==== Cài Đặt Ichimoku ===="; // -------------------------
input int                  InpTenkan            = 9;                         // Tenkan-sen
input int                  InpKijun             = 26;                        // Kijun-sen
input int                  InpSenkouB           = 52;                        // Senkou Span B

input string               InpRiskSeparator     = "==== Quản Trị Rủi Ro ===="; // -------------------------
input ENUM_RISK_MODE       InpRiskMode          = RISK_MODE_FIXED;           // Phương thức tính Lot
input double               InpRiskValue         = 0.01;                      // Lot cố định (hoặc % rủi ro)
input ENUM_TP_MODE         InpTPMode            = TP_MODE_PREV_CHIKOU;       // Chế độ Take Profit (Chốt lời)
input int                  InpHLLookback        = 50;                        // Số nến dò tìm đỉnh/đáy cũ Chikou
input bool                 InpUseDailyFilter    = false;                     // Sử dụng bộ lọc Khung Daily

//--- Global Variables
int    handle_ichi_h4;
int    handle_ichi_daily;

double tenkan_h4[], kijun_h4[], spanA_h4[], spanB_h4[];
double tenkan_d1[], kijun_d1[], spanA_d1[], spanB_d1[];
double close_h4[], high_h4[], low_h4[];
double close_d1[];

datetime last_bar_time = 0;
datetime last_trade_bar_time = 0; // Lưu thời gian đóng của nến đã dùng để vào lệnh

//+------------------------------------------------------------------+
//| Khởi tạo EA (Expert initialization function)                     |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Khởi tạo Symbol
   if(!symInfo.Name(_Symbol))
     {
      Print("SymbolInfo initialization failed!");
      return(INIT_FAILED);
     }
   symInfo.RefreshRates();

//--- Khởi tạo Trade parameters
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);

//--- Khởi tạo cờ cho mảng buffer
   ArraySetAsSeries(tenkan_h4, true); ArraySetAsSeries(kijun_h4, true); ArraySetAsSeries(spanA_h4, true); ArraySetAsSeries(spanB_h4, true);
   ArraySetAsSeries(tenkan_d1, true); ArraySetAsSeries(kijun_d1, true); ArraySetAsSeries(spanA_d1, true); ArraySetAsSeries(spanB_d1, true);
   ArraySetAsSeries(close_h4, true);  ArraySetAsSeries(high_h4, true);  ArraySetAsSeries(low_h4, true);
   ArraySetAsSeries(close_d1, true);

//--- Khởi tạo Ichimoku Handle cho H4 và Daily
   handle_ichi_h4 = iIchimoku(_Symbol, InpH4Timeframe, InpTenkan, InpKijun, InpSenkouB);
   if(handle_ichi_h4 == INVALID_HANDLE)
     {
      Print("Failed to create handle of iIchimoku H4. Error: ", GetLastError());
      return(INIT_FAILED);
     }

   handle_ichi_daily = iIchimoku(_Symbol, InpDailyTimeframe, InpTenkan, InpKijun, InpSenkouB);
   if(handle_ichi_daily == INVALID_HANDLE)
     {
      Print("Failed to create handle of iIchimoku Daily. Error: ", GetLastError());
      return(INIT_FAILED);
     }

//--- Add Indicator to Chart (Mặc định iIchimoku chỉ nằm trong memory, phải Add mới nhìn thấy trên Chart Tester)
   ChartIndicatorAdd(0, 0, handle_ichi_h4);

   Print("EA Khởi tạo thành công!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Dọn dẹp EA (Expert deinitialization function)                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handle_ichi_h4);
   IndicatorRelease(handle_ichi_daily);
   Print("EA đã dừng hoạt động.");
  }

//+------------------------------------------------------------------+
//| Vòng lặp chính của EA mỗi Tick (Expert tick function)            |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Chỉ chạy khi có nến mới trên khung H4
   datetime current_bar_time = iTime(_Symbol, InpH4Timeframe, 0);
   if(current_bar_time == last_bar_time) return;

// Cập nhật giá trị các bộ đệm (Buffers)
   if(!UpdateBuffers()) return;

   symInfo.RefreshRates();

//--- KIỂM TRA TRAILING STOP TẠM TẮT (Theo yêu cầu SL chỉ set 1 lần)
/*
   if(PositionsTotal() > 0)
     {
      CheckTrailingStop();
     }
*/

//--- Nếu đang có lệnh mở, không mở thêm lệnh mới
   if(CountOpenPositions() > 0) return;

//--- Kiểm tra điều kiện BUY (Chỉ xét nếu nến 1 hiện tại chưa từng mở lệnh)
   datetime signal_bar_time = iTime(_Symbol, InpH4Timeframe, 1);
   if(signal_bar_time != last_trade_bar_time)
     {
      if(CheckBuyConditions())
        {
         ExecuteBuy();
         last_bar_time = current_bar_time;
         return;
        }

//--- Kiểm tra điều kiện SELL
      if(CheckSellConditions())
        {
         ExecuteSell();
         last_bar_time = current_bar_time;
         return;
        }
     }
  }

//+------------------------------------------------------------------+
//| Update Buffers                                                   |
//+------------------------------------------------------------------+
bool UpdateBuffers()
  {
   int copied = 0;
//--- Copy Ichimoku H4 (lấy 30 nến để dễ kiểm tra Chikou)
   copied = CopyBuffer(handle_ichi_h4, 0, 0, 30, tenkan_h4); if(copied<=0) return false;
   copied = CopyBuffer(handle_ichi_h4, 1, 0, 30, kijun_h4);  if(copied<=0) return false;
   copied = CopyBuffer(handle_ichi_h4, 2, 0, 30, spanA_h4);  if(copied<=0) return false;
   copied = CopyBuffer(handle_ichi_h4, 3, 0, 30, spanB_h4);  if(copied<=0) return false;

//--- Copy Ichimoku Daily
   copied = CopyBuffer(handle_ichi_daily, 0, 0, 3, tenkan_d1); if(copied<=0) return false;
   copied = CopyBuffer(handle_ichi_daily, 1, 0, 3, kijun_d1);  if(copied<=0) return false;
   copied = CopyBuffer(handle_ichi_daily, 2, 0, 3, spanA_d1);  if(copied<=0) return false;
   copied = CopyBuffer(handle_ichi_daily, 3, 0, 3, spanB_d1);  if(copied<=0) return false;

//--- Copy Price H4 (lấy 60 nến để phục vụ Tìm Đỉnh/Đáy và Chikou)
   copied = CopyClose(_Symbol, InpH4Timeframe, 0, 60, close_h4); if(copied<=0) return false;
   copied = CopyHigh(_Symbol, InpH4Timeframe, 0, 60, high_h4);  if(copied<=0) return false;
   copied = CopyLow(_Symbol, InpH4Timeframe, 0, 60, low_h4);   if(copied<=0) return false;

//--- Copy Price Daily
   copied = CopyClose(_Symbol, InpDailyTimeframe, 0, 3, close_d1); if(copied<=0) return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Kiểm tra điều kiện BUY                                           |
//+------------------------------------------------------------------+
bool CheckBuyConditions()
  {
// Sử dụng nến 1 (Nến H4 vừa đóng) để xác nhận tín hiệu vững chắc
   int shift = 1;

// 1. Daily Confirmation: Giá Daily phải nằm trên đường Kijun HOẶC trên mây Kumo
   if(InpUseDailyFilter)
     {
      double daily_kumo_max = MathMax(spanA_d1[shift], spanB_d1[shift]);
      bool daily_condition = (close_d1[shift] > kijun_d1[shift]) || (close_d1[shift] > daily_kumo_max);
      if(!daily_condition) return false;
     }

// 2. H4 Entry
   double h4_kumo_max = MathMax(spanA_h4[shift], spanB_h4[shift]);

// Vị thế: Giá đóng cửa trên cả Tenkan-sen và Kijun-sen
   bool position_cond = (close_h4[shift] > tenkan_h4[shift]) && (close_h4[shift] > kijun_h4[shift]);

// Giao cắt & Động lượng: Tenkan-sen (9) nằm trên Kijun-sen (26) VÀ Tenkan-sen hướng lên hoặc đi ngang
   bool cross_cond = (tenkan_h4[shift] > kijun_h4[shift]);
   bool direction_cond = (tenkan_h4[shift] >= tenkan_h4[shift + 1]);

// Chikou Span: Giá lùi 26 phiên nằm trên giá quá khứ.
// MQL5 Chikou là đường giá lùi về sau. Nến hiện tại so với 26 nến trước (shift + 26)
   bool chikou_cond = (close_h4[shift] > close_h4[shift + 26]);

// Giá và Mây: Giá phải nằm trên mây Kumo
   bool cloud_cond = (close_h4[shift] > h4_kumo_max);

   return (position_cond && cross_cond && direction_cond && chikou_cond && cloud_cond);
  }

//+------------------------------------------------------------------+
//| Kiểm tra điều kiện SELL                                          |
//+------------------------------------------------------------------+
bool CheckSellConditions()
  {
// Sử dụng nến 1 (Nến H4 vừa đóng) để xác nhận tín hiệu vững chắc
   int shift = 1;

// 1. Daily Confirmation: Giá Daily phải nằm dưới đường Kijun HOẶC dưới mây Kumo
   if(InpUseDailyFilter)
     {
      double daily_kumo_min = MathMin(spanA_d1[shift], spanB_d1[shift]);
      bool daily_condition = (close_d1[shift] < kijun_d1[shift]) || (close_d1[shift] < daily_kumo_min);
      if(!daily_condition) return false;
     }

// 2. H4 Entry
   double h4_kumo_min = MathMin(spanA_h4[shift], spanB_h4[shift]);

// Vị thế: Giá đóng cửa dưới cả Tenkan-sen và Kijun-sen
   bool position_cond = (close_h4[shift] < tenkan_h4[shift]) && (close_h4[shift] < kijun_h4[shift]);

// Giao cắt & Động lượng: Tenkan-sen nằm dưới Kijun-sen VÀ Tenkan-sen hướng xuống hoặc đi ngang
   bool cross_cond = (tenkan_h4[shift] < kijun_h4[shift]);
   bool direction_cond = (tenkan_h4[shift] <= tenkan_h4[shift + 1]);

// Chikou Span: Giá đóng cửa hiện tại nhỏ hơn giá đóng cửa 26 nến trước
   bool chikou_cond = (close_h4[shift] < close_h4[shift + 26]);

// Giá và Mây: Giá phải nằm dưới mây Kumo
   bool cloud_cond = (close_h4[shift] < h4_kumo_min);

   return (position_cond && cross_cond && direction_cond && chikou_cond && cloud_cond);
  }

//+------------------------------------------------------------------+
//| Đếm số lệnh đang mở cho cặp tiền và Magic này                    |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Tính toán Lot Size Dựa Trên Rủi Ro                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss_distance)
  {
   double lot = InpRiskValue;

   if(InpRiskMode == RISK_MODE_PCT)
     {
      double equity = accInfo.Equity();
      double risk_amount = equity * (InpRiskValue / 100.0);
      double tick_value = symInfo.TickValue();
      double tick_size = symInfo.TickSize();

      if(stop_loss_distance > 0 && tick_size > 0 && tick_value > 0)
        {
         double sl_in_ticks = stop_loss_distance / tick_size;
         lot = risk_amount / (sl_in_ticks * tick_value);
        }
     }

// Chuẩn hóa Lot (Normalize)
   double min_lot = symInfo.LotsMin();
   double max_lot = symInfo.LotsMax();
   double lot_step = symInfo.LotsStep();

   lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return lot;
  }

//+------------------------------------------------------------------+
//| Tìm Giá Trị Đỉnh Của Chikou (Close Giá Quá Khứ)                  |
//+------------------------------------------------------------------+
double GetPreviousChikouHigh()
  {
   int highest_idx = ArrayMaximum(close_h4, 1, InpHLLookback);
   if(highest_idx >= 0) return close_h4[highest_idx];
   return 0; // Nghĩa là không tìm được
  }

//+------------------------------------------------------------------+
//| Tìm Giá Trị Đáy Của Chikou (Close Giá Quá Khứ)                   |
//+------------------------------------------------------------------+
double GetPreviousChikouLow()
  {
   int lowest_idx = ArrayMinimum(close_h4, 1, InpHLLookback);
   if(lowest_idx >= 0) return close_h4[lowest_idx];
   return 0;
  }

//+------------------------------------------------------------------+
//| Mở lệnh BUY                                                      |
//+------------------------------------------------------------------+
void ExecuteBuy()
  {
   double ask = symInfo.Ask();

// Tính Stop Loss (Dựa vào Kijun-sen nến đóng 1)
   double sl = kijun_h4[1];

// Nếu SL quá sát giá vào lệnh, hoặc lỗi tính toán, hủy lệnh
   if(ask <= sl)
     {
      Print("BUY Error: Giá Ask (", ask, ") bé hơn hoặc bằng SL (", sl, ")");
      return;
     }

   double sl_distance = ask - sl;
   double tp = 0;

// Tính Take Profit
   if(InpTPMode == TP_MODE_RR_1_1)
     {
      tp = ask + sl_distance; // Tỷ lệ R:R = 1:1
     }
   else if(InpTPMode == TP_MODE_RR_1_2)
     {
      tp = ask + (sl_distance * 2.0); // Tỷ lệ R:R = 1:2
     }
   else if(InpTPMode == TP_MODE_PREV_CHIKOU)
     {
      tp = GetPreviousChikouHigh();
      // Nếu không tìm được High hoạc High thấp hơn giá Ask thì chỉnh fallback qua 1:2
      if(tp == 0 || tp <= ask)
         tp = ask + (sl_distance * 2.0);
     }

   double lot = CalculateLotSize(sl_distance);

   if(trade.Buy(lot, _Symbol, ask, sl, tp, "Golem_Buy"))
     {
      Print("Đã Mở Lệnh BUY thành công. Ticket: ", trade.ResultOrder());
      last_trade_bar_time = iTime(_Symbol, InpH4Timeframe, 1); // Đánh dấu nến này đã mở lệnh
     }
   else
     {
      Print("Mở lệnh BUY thất bại! Error: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Mở lệnh SELL                                                     |
//+------------------------------------------------------------------+
void ExecuteSell()
  {
   double bid = symInfo.Bid();

// Tính Stop Loss (Dựa vào Kijun-sen nến đóng 1)
   double sl = kijun_h4[1];

   if(bid >= sl)
     {
      Print("SELL Error: Giá Bid (", bid, ") lớn hơn hoặc bằng SL (", sl, ")");
      return;
     }

   double sl_distance = sl - bid;
   double tp = 0;

// Tính Take Profit
   if(InpTPMode == TP_MODE_RR_1_1)
     {
      tp = bid - sl_distance; // Tỷ lệ R:R = 1:1
     }
   else if(InpTPMode == TP_MODE_RR_1_2)
     {
      tp = bid - (sl_distance * 2.0); // Tỷ lệ R:R = 1:2
     }
   else if(InpTPMode == TP_MODE_PREV_CHIKOU)
     {
      tp = GetPreviousChikouLow();
      // Nếu không tìm được Low hoạc Low cao hơn giá Bid thì chỉnh fallback qua 1:2
      if(tp == 0 || tp >= bid)
         tp = bid - (sl_distance * 2.0);
     }

   double lot = CalculateLotSize(sl_distance);

   if(trade.Sell(lot, _Symbol, bid, sl, tp, "Golem_Sell"))
     {
      Print("Đã Mở Lệnh SELL thành công. Ticket: ", trade.ResultOrder());
      last_trade_bar_time = iTime(_Symbol, InpH4Timeframe, 1); // Đánh dấu nến này đã mở lệnh
     }
   else
     {
      Print("Mở lệnh SELL thất bại! Error: ", GetLastError());
     }
  }

/* TRẠNG THÁI: Tính năng Trailing Stop đang được Vô hiệu hóa
//+------------------------------------------------------------------+
//| Trailing Stop Theo Đường Kijun-sen H4                            |
//+------------------------------------------------------------------+
void CheckTrailingStop()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            double new_sl = kijun_h4[1]; // Lấy Kijun nến 1
            double current_sl = posInfo.StopLoss();
            double open_price = posInfo.PriceOpen();

            if(posInfo.PositionType() == POSITION_TYPE_BUY)
              {
               // Lệnh Buy - Dời SL lên khi Kijun mới cao hơn SL cũ và giá trần (Bid) > new_sl
               if((current_sl == 0 || new_sl > current_sl) && symInfo.Bid() > new_sl)
                 {
                  if(!trade.PositionModify(posInfo.Ticket(), new_sl, posInfo.TakeProfit()))
                    {
                     Print("Lỗi Trailing Stop BUY! Code: ", GetLastError());
                    }
                  else
                    {
                     Print("Trails SL lệnh BUY tiến lên Kijun: ", new_sl);
                    }
                 }
              }
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
              {
               // Lệnh Sell - Dời SL xuống khi Kijun mới thấp hơn SL cũ và giá đáy (Ask) < new_sl
               if((current_sl == 0 || new_sl < current_sl) && symInfo.Ask() < new_sl)
                 {
                  if(!trade.PositionModify(posInfo.Ticket(), new_sl, posInfo.TakeProfit()))
                    {
                     Print("Lỗi Trailing Stop SELL! Code: ", GetLastError());
                    }
                  else
                    {
                     Print("Trails SL lệnh SELL lùi xuống Kijun: ", new_sl);
                    }
                 }
              }
           }
        }
     }
  }
*/
//+------------------------------------------------------------------+
