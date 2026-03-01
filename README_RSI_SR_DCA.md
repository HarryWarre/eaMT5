# 🚀 RSI S&R DCA + Smart Hedge EA

## Complete Trading System with Individual TP & Trailing Stop

---

## ✨ Tính Năng Chính

### 📊 **RSI Support & Resistance Strategy**

- Phát hiện tự động S/R levels dựa trên RSI crossover
- 4 zones: Overbought (70), Bull (60), Bear (40), Oversold (30)
- Tính toán S/R từ `avgHigh = (high + close) / 2` và `avgLow = (low + close) / 2`
- Entry signal khi RSI confirm + giá chạm S/R level

### 💰 **DCA Martingale System**

- Mở thêm lệnh khi giá đi ngược (mỗi 20 pips)
- Tăng lot theo cấp số nhân 1.5x (martingale)
- Tối đa 5 levels
- Không có Stop Loss (no SL)

### 🛡️ **Smart Hedge Recovery**

- Tự động mở hedge khi đạt level 5
- Hedge volume = Total lots × 1.2x
- Đóng khi: Breakeven HOẶC RR 1:1

### 🎯 **Individual Take Profit**

- Mỗi lệnh DCA có TP riêng (50 pips mặc định)
- Lệnh nào đủ TP thì đóng, lệnh khác giữ
- Tối ưu hóa lợi nhuận từng position

### 📈 **Trailing Stop**

- Kích hoạt khi lời >= 20 pips
- Di chuyển SL theo giá, cách 10 pips
- Chỉ di chuyển khi vẫn ở vùng lời
- Bảo vệ lợi nhuận tự động

### 🛑 **Risk Protection**

- Max Drawdown: 20% → đóng tất cả
- Daily Target: $1000 (tùy chọn)
- Equity protection

---

## ⚙️ Cấu Hình Input Parameters

### 🔢 **BASIC SETTINGS**

```
MagicNumber = 999777
accountPer500 = 500
```

- `accountPer500`: Tài khoản $500 = 0.01 lot

### 📊 **RSI SETTINGS**

```
rsiLength = 14
rsiOverbought = 70
rsiBullZone = 60
rsiBearZone = 40
rsiOversold = 30
```

### ✅ **SIGNAL CONFIRMATION**

```
confirmBars = 2              // RSI phải ở oversold/overbought ít nhất 2 nến
usePriceTouch = true         // Phải chạm S/R level mới vào lệnh
srTouchPips = 5.0            // Khoảng cách chạm S/R (5 pips)
```

### 💰 **DCA + HEDGE SYSTEM**

```
dcaMaxLevel = 5              // Tối đa 5 lệnh DCA
dcaStepPips = 20.0           // Mỗi 20 pips mở 1 lệnh DCA
dcaMultiplier = 1.5          // Tăng lot 1.5x
hedgeAtLevel = 5             // Mở hedge tại level 5
hedgeMultiplier = 1.2        // Hedge = total × 1.2x
hedgeRRRatio = 1.0           // Tỷ lệ RR 1:1
useBreakeven = true          // Đóng khi breakeven
```

### 🎯 **TAKE PROFIT & TRAILING**

```
useIndividualTP = true       // Bật Individual TP
individualTPPips = 50.0      // TP cho mỗi lệnh
useTrailingStop = true       // Bật Trailing Stop
trailingStartPips = 20.0     // Bắt đầu trail khi +20 pips
trailingStepPips = 10.0      // SL cách giá 10 pips
```

### 🛑 **RISK PROTECTION**

```
useMaxDrawdown = true
maxDrawdownPct = 20.0
useDailyTarget = false
dailyTarget = 1000.0
```

---

## 🎮 Hướng Dẫn Sử Dụng

### **1. Cài Đặt**

1. Copy file `quantumRSI_SR_DCA.mq5` vào thư mục:

   ```
   C:\Users\[User]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\
   ```

2. Mở MetaEditor (F4 trong MT5)

3. Compile file (F7)

4. Kiểm tra không có lỗi compilation

### **2. Attach EA lên Chart**

1. Mở chart (ví dụ: EURUSD M15)

2. Kéo EA từ Navigator → Chart

3. Cài đặt parameters:
   - Nếu tài khoản $500 → `accountPer500 = 500`
   - Nếu tài khoản $1000 → `accountPer500 = 500` (0.02 lot base)
   - Nếu tài khoản $5000 → `accountPer500 = 500` (0.10 lot base)

4. Enable AutoTrading (Ctrl + E)

### **3. Multi-Symbol Trading**

Muốn trade nhiều cặp tiền:

**Option 1: Nhiều Chart (Khuyến nghị)**

- Mở 4-5 charts khác nhau (EURUSD, GBPUSD, USDJPY, AUDUSD)
- Attach EA vào mỗi chart
- Mỗi EA độc lập, dễ quản lý

**Option 2: Multi-Symbol (Beta)**

- Set `useMultiSymbol = true`
- Cấu hình `tradingSymbols = "EURUSD,GBPUSD,USDJPY"`
- **Lưu ý:** Tính năng này đang BETA, chưa hoàn thiện

---

## 📊 Ví Dụ Thực Tế

### **Scenario 1: Individual TP**

```
1. BUY EURUSD @ 1.10000 (0.01 lot) - Level 1
2. Giá xuống 1.09800 → BUY @ 1.09800 (0.015 lot) - Level 2
3. Giá xuống 1.09600 → BUY @ 1.09600 (0.023 lot) - Level 3
4. Giá lên 1.09650 → Level 3 hit TP 50 pips → ĐÓNG LEVEL 3 ✅
5. Giá lên 1.09850 → Level 2 hit TP 50 pips → ĐÓNG LEVEL 2 ✅
6. Giá lên 1.10050 → Level 1 hit TP 50 pips → ĐÓNG LEVEL 1 ✅
```

**Kết quả:** 3 lệnh đều lời, không cần chờ cả sequence breakeven

### **Scenario 2: Trailing Stop**

```
1. BUY EURUSD @ 1.10000 (0.01 lot)
2. Giá lên 1.10200 (+20 pips) → Trailing START
   - Đặt SL @ 1.10100 (cách giá 10 pips)
3. Giá lên 1.10300 (+30 pips) → Di chuyển SL
   - SL mới @ 1.10200 (+20 pips lời)
4. Giá lên 1.10500 (+50 pips) → Di chuyển SL
   - SL mới @ 1.10400 (+40 pips lời)
5. Giá rớt về 1.10400 → Hit SL → ĐÓNG LỜI +40 pips ✅
```

**Kết quả:** Bảo vệ lợi nhuận, không bị mất khi giá reverse

### **Scenario 3: DCA + Hedge**

```
1. SELL GBPUSD @ 1.30000 (0.01 lot) - RSI overbought
2. Giá lên 1.30200 → SELL @ 1.30200 (0.015 lot) - Level 2
3. Giá lên 1.30400 → SELL @ 1.30400 (0.023 lot) - Level 3
4. Giá lên 1.30600 → SELL @ 1.30600 (0.035 lot) - Level 4
5. Giá lên 1.30800 → SELL @ 1.30800 (0.053 lot) - Level 5
6. Level 5 → Mở HEDGE: BUY 0.15 lot @ 1.30800
7. Giá lên 1.31000:
   - Main SELL: -200 pips loss = -$300
   - Hedge BUY: +20 pips profit = +$300
   - Total P/L = $0 → ĐÓNG TẤT CẢ ✅
```

**Kết quả:** Hedge cứu vãn, đóng hòa vốn thay vì drawdown sâu

---

## 🎯 Chiến Lược Tối Ưu

### **Conservative (Bảo Toàn Vốn)**

```
dcaMaxLevel = 3
dcaStepPips = 30.0
individualTPPips = 40.0
trailingStartPips = 15.0
maxDrawdownPct = 15.0
```

- Ít risk, ít lệnh, TP nhanh

### **Balanced (Cân Bằng)**

```
dcaMaxLevel = 5
dcaStepPips = 20.0
individualTPPips = 50.0
trailingStartPips = 20.0
maxDrawdownPct = 20.0
```

- Setup mặc định, phù hợp đa số

### **Aggressive (Tối Đa Lợi Nhuận)**

```
dcaMaxLevel = 7
dcaStepPips = 15.0
individualTPPips = 60.0
trailingStartPips = 25.0
maxDrawdownPct = 25.0
```

- Nhiều lệnh, giữ lâu hơn, TP cao

---

## ⚠️ Lưu Ý Quan Trọng

### ✅ **DO's**

- ✅ Test trên Demo trước khi Live
- ✅ Dùng VPS để EA chạy 24/7
- ✅ Kiểm tra spread trước khi trade
- ✅ Backtest ít nhất 3 tháng
- ✅ Theo dõi Drawdown hàng ngày

### ❌ **DON'Ts**

- ❌ KHÔNG trade khi có news quan trọng
- ❌ KHÔNG tắt EA khi đang có positions
- ❌ KHÔNG thay đổi parameters giữa chừng
- ❌ KHÔNG trade khi spread > 3 pips
- ❌ KHÔNG dùng lot quá lớn

---

## 📞 Troubleshooting

### ❓ **Không có tín hiệu**

- Giảm `confirmBars` từ 2 → 1
- Tắt `usePriceTouch = false`
- Tăng `srTouchPips` từ 5 → 10

### ❓ **Quá nhiều lệnh**

- Giảm `dcaMaxLevel` từ 5 → 3
- Tăng `dcaStepPips` từ 20 → 30
- Giảm số symbols trade

### ❓ **Drawdown cao**

- Giảm `accountPer500` (giảm lot size)
- Giảm `dcaMaxLevel`
- Bật `useMaxDrawdown = true`
- Set `maxDrawdownPct = 15%`

### ❓ **Trailing Stop không hoạt động**

- Kiểm tra `useTrailingStop = true`
- Đảm bảo profit >= `trailingStartPips`
- Spread phải < 2 pips

---

## 📊 Performance Metrics

EA tự động track:

- **Total Sequences:** Số sequence đã đóng
- **Win Rate:** Tỷ lệ thắng %
- **Total Profit:** Tổng lợi nhuận $
- **Max Drawdown:** Drawdown tối đa %

Xem trong tab **Experts** của MT5.

---

## 🚀 Quick Start Checklist

- [ ] Compile EA không lỗi
- [ ] Test trên Demo account
- [ ] Cài đặt VPS (nếu trade 24/7)
- [ ] Cấu hình parameters phù hợp account size
- [ ] Bật AutoTrading
- [ ] Theo dõi 1 tuần đầu
- [ ] Backtest ít nhất 3 tháng
- [ ] Chuyển sang Live (nếu kết quả tốt)

---

## 📝 Version History

**v1.0 - Current**

- ✅ RSI S&R detection
- ✅ DCA Martingale system
- ✅ Smart Hedge recovery
- ✅ Individual Take Profit
- ✅ Trailing Stop
- ✅ Risk protection
- ⚠️ Multi-Symbol (Beta)

---

## 💡 Tips & Tricks

1. **Timeframe tốt nhất:** M15 hoặc H1
2. **Symbols tốt nhất:** Majors (EURUSD, GBPUSD, USDJPY)
3. **Giờ trade tốt:** London + New York session
4. **Tránh:** Asian session (spread cao, ít volatility)
5. **Backtest:** Ít nhất 1000 trades để đánh giá

---

## 📧 Support

Nếu có vấn đề:

1. Xem tab **Experts** trong MT5
2. Screenshot log messages
3. Báo lỗi với screenshot

**Happy Trading! 🚀💰📈**

Hiện tại có vấn đề, bot con trong quá trình trade tôi nghĩ nó bị âm quá mức vốn của nó và lấn sang bot mẹ, tôi cần cắt nếu tổng lệnh âm của bot đó > min tài khoản bot con, nó sẽ theo tick để xét chứ không phải đợi hết nến nếu vậy thì nó sẽ âm qua cả vốn của mẹ
