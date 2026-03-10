import re

with open('/Users/hoangviet/Documents/DaiVietmt5/firebird.mq5', 'r') as f:
    text = f.read()

# Replacement for Buy Logic
buy_logic_old = """      // --- BUY ---
      sl = (InpSLMode == SL_MODE_KIJUN) ? d1.kijun : d1.tenkan;
      
      // Safety SL margin (lùi SL xuống 1 chút qua Kijun)
      sl = sl - (m_symbol.Spread() * m_symbol.Point()); 
      
      if(ask <= sl) {
         PrintFormat("BUY Bỏ qua: Ask (%.5f) <= SL (%.5f)", ask, sl); return;
      }
      
      sl_distance = ask - sl;
      
      // Xác định TP
      if(InpTPMode == TP_MODE_RR_1_1) tp = ask + sl_distance;
      else if(InpTPMode == TP_MODE_RR_1_2) tp = ask + (sl_distance * 2.0);
      else if(InpTPMode == TP_MODE_PREV_CHIKOU) {
         tp = GetPreviousChikouLevel(1); // Tìm Max Close
         // Fallback về RR 1:2 nếu lỗi hoặc Đỉnh lịch sử thấp hơn giá hiện tại
         if(tp <= ask) tp = ask + (sl_distance * 2.0);
      }
      
      lot = CalculateLotSize(sl_distance);
      
      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, "FB_Single_BUY")) {
         g_lastTradeBar = iTime(_Symbol, InpBaseTF, 1); // Mark nến đã vào lệnh
         PrintFormat("🟢 BUY OPEN: %.3f lot @ %.5f | SL: %.5f | TP: %.5f", lot, ask, sl, tp);
      }"""

buy_logic_new = """      // --- BUY LIMIT ---
      sl = (InpSLMode == SL_MODE_KIJUN) ? d1.kijun : d1.tenkan;
      
      // Vị trí Entry = Chính là mức SL (Tenkan hoặc Kijun) cộng thêm Spread để Cắn lệnh + Margin
      double entry_price = sl + (m_symbol.Spread() * m_symbol.Point()) * 2.0; 
      
      // Safety SL margin (lùi SL xuống 1 chút qua Kijun)
      sl = sl - (m_symbol.Spread() * m_symbol.Point()); 
      
      if(ask <= entry_price) {
         // Nếu giá hiện tại đã quá sát hoặc thấp hơn mức entry dự kiến -> Bỏ qua hoặc Buy luôn
         PrintFormat("BUY LIMIT Bỏ qua: Ask (%.5f) <= Entry Price (%.5f)", ask, entry_price); return;
      }
      
      sl_distance = entry_price - sl;
      
      // Xác định TP
      if(InpTPMode == TP_MODE_RR_1_1) tp = entry_price + sl_distance;
      else if(InpTPMode == TP_MODE_RR_1_2) tp = entry_price + (sl_distance * 2.0);
      else if(InpTPMode == TP_MODE_PREV_CHIKOU) {
         tp = GetPreviousChikouLevel(1); // Tìm Max Close
         // Fallback về RR 1:2 nếu lỗi hoặc Đỉnh lịch sử thấp hơn giá chờ
         if(tp <= entry_price) tp = entry_price + (sl_distance * 2.0);
      }
      
      lot = CalculateLotSize(sl_distance);
      
      if(m_trade.BuyLimit(lot, entry_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "FB_Single_BUY_LIMIT")) {
         g_lastTradeBar = iTime(_Symbol, InpBaseTF, 1); // Mark nến đã vào lệnh
         PrintFormat("🟢 BUY LIMIT PLACED: %.3f lot @ %.5f | SL: %.5f | TP: %.5f", lot, entry_price, sl, tp);
      }"""

# Replacement for Sell Logic
sell_logic_old = """      // --- SELL ---
      sl = (InpSLMode == SL_MODE_KIJUN) ? d1.kijun : d1.tenkan;
      
      // Safety SL margin
      sl = sl + (m_symbol.Spread() * m_symbol.Point()); 
      
      if(bid >= sl) {
         PrintFormat("SELL Bỏ qua: Bid (%.5f) >= SL (%.5f)", bid, sl); return;
      }
      
      sl_distance = sl - bid;
      
      // Xác định TP
      if(InpTPMode == TP_MODE_RR_1_1) tp = bid - sl_distance;
      else if(InpTPMode == TP_MODE_RR_1_2) tp = bid - (sl_distance * 2.0);
      else if(InpTPMode == TP_MODE_PREV_CHIKOU) {
         tp = GetPreviousChikouLevel(-1); // Tìm Min Close
         // Fallback
         if(tp >= bid || tp == 0) tp = bid - (sl_distance * 2.0);
      }
      
      lot = CalculateLotSize(sl_distance);
      
      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, "FB_Single_SELL")) {
         g_lastTradeBar = iTime(_Symbol, InpBaseTF, 1);
         PrintFormat("🔴 SELL OPEN: %.3f lot @ %.5f | SL: %.5f | TP: %.5f", lot, bid, sl, tp);
      }"""

sell_logic_new = """      // --- SELL LIMIT ---
      sl = (InpSLMode == SL_MODE_KIJUN) ? d1.kijun : d1.tenkan;
      
      // Vị trí Entry = Chính là mức SL (Tenkan hoặc Kijun) trừ đi Spread để Cắn lệnh
      double entry_price = sl - (m_symbol.Spread() * m_symbol.Point()) * 2.0;
      
      // Safety SL margin
      sl = sl + (m_symbol.Spread() * m_symbol.Point()); 
      
      if(bid >= entry_price) {
         PrintFormat("SELL LIMIT Bỏ qua: Bid (%.5f) >= Entry Price (%.5f)", bid, entry_price); return;
      }
      
      sl_distance = sl - entry_price;
      
      // Xác định TP
      if(InpTPMode == TP_MODE_RR_1_1) tp = entry_price - sl_distance;
      else if(InpTPMode == TP_MODE_RR_1_2) tp = entry_price - (sl_distance * 2.0);
      else if(InpTPMode == TP_MODE_PREV_CHIKOU) {
         tp = GetPreviousChikouLevel(-1); // Tìm Min Close
         // Fallback
         if(tp >= entry_price || tp == 0) tp = entry_price - (sl_distance * 2.0);
      }
      
      lot = CalculateLotSize(sl_distance);
      
      if(m_trade.SellLimit(lot, entry_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "FB_Single_SELL_LIMIT")) {
         g_lastTradeBar = iTime(_Symbol, InpBaseTF, 1);
         PrintFormat("🔴 SELL LIMIT PLACED: %.3f lot @ %.5f | SL: %.5f | TP: %.5f", lot, entry_price, sl, tp);
      }"""

text = text.replace(buy_logic_old, buy_logic_new)
text = text.replace(sell_logic_old, sell_logic_new)

with open('/Users/hoangviet/Documents/DaiVietmt5/firebird.mq5', 'w') as f:
    f.write(text)

print("Done")
