# 🌍 Multi-Symbol Trading Guide

## RSI S&R DCA + Hedge EA

---

## 📋 Tổng Quan

EA này hỗ trợ **giao dịch nhiều cặp tiền** từ **1 chart duy nhất**. Bạn chỉ cần attach EA lên 1 chart bất kỳ, EA sẽ tự động giao dịch tất cả các cặp tiền được cấu hình.

---

## ⚙️ Cấu Hình Multi-Symbol

### 🔧 **Input Parameters**

```
=== MULTI SYMBOL TRADING ===
useMultiSymbol = true                    // Bật Multi-Symbol
tradingSymbols = "EURUSD,GBPUSD,USDJPY"  // Danh sách cặp tiền
maxSymbolsActive = 3                     // Số cặp tiền active tối đa
```

### 📊 **Danh Sách Symbols**

**Format:** Phân cách bằng dấu phẩy, KHÔNG có khoảng trắng (hoặc có cũng được, EA tự trim)

```
✅ ĐÚNG:
"EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"
"EURUSD, GBPUSD, USDJPY"  // có space cũng OK

❌ SAI:
"EURUSD GBPUSD USDJPY"    // thiếu dấu phẩy
"EUR/USD,GBP/USD"         // format sai
```

### 🎯 **Recommended Symbol Lists**

#### **Conservative (3-4 pairs)**

```
EURUSD,GBPUSD,USDJPY,AUDUSD
```

- Thanh khoản cao
- Spread thấp
- Ít rủi ro

#### **Balanced (6-8 pairs)**

```
EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,NZDUSD,EURGBP,EURJPY
```

- Đa dạng hóa tốt
- Cân bằng rủi ro/lợi nhuận

#### **Aggressive (10+ pairs)**

```
EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,NZDUSD,EURJPY,GBPJPY,EURGBP,EURAUD,GBPAUD,AUDJPY
```

- Nhiều cơ hội giao dịch
- Quản lý drawdown phức tạp hơn

---

## 🚀 Cách Sử Dụng

### **Bước 1: Chuẩn Bị Symbols**

1. **Mở Market Watch** (Ctrl + M)
2. **Thêm tất cả symbols** vào Market Watch:
   - Right-click → `Show All`
   - Hoặc nhấn `Ctrl + U` → tích chọn symbols cần trade
3. **Đảm bảo symbols có data:**
   - Mở chart từng symbol một lần để tải lịch sử

### **Bước 2: Attach EA**

1. Chọn **1 chart bất kỳ** (ví dụ: EURUSD M15)
2. Drag & Drop EA lên chart
3. Cấu hình input parameters:
   ```
   useMultiSymbol = true
   tradingSymbols = "EURUSD,GBPUSD,USDJPY,AUDUSD"
   maxSymbolsActive = 3
   ```
4. Nhấn **OK**

### **Bước 3: Kiểm Tra**

Xem log trong tab **Experts**:

```
========================================
🚀 RSI S&R DCA+Hedge EA Starting...
========================================
🌍 Initializing Multi-Symbol Trading...
📊 Found 4 symbols to trade
✅ Initialized: EURUSD
✅ Initialized: GBPUSD
✅ Initialized: USDJPY
✅ Initialized: AUDUSD
```

---

## 📊 Cơ Chế Hoạt Động

### **Multi-Symbol Logic**

```
┌─────────────────────────────────────┐
│  1 EA trên 1 Chart                  │
│  ↓                                  │
│  Quét tất cả symbols được config   │
│  ↓                                  │
│  Từng symbol:                       │
│    - Tính RSI riêng                │
│    - Phát hiện S/R riêng          │
│    - DCA sequence riêng           │
│    - Hedge riêng                  │
│  ↓                                  │
│  Max Active Symbols: 3             │
│  (Chỉ 3 symbols có positions)     │
└─────────────────────────────────────┘
```

### **Max Active Symbols**

- **Giới hạn:** Chỉ `maxSymbolsActive` symbols có thể có positions đồng thời
- **Ví dụ:** Nếu set `maxSymbolsActive = 3`:
  - EURUSD: Có 2 DCA levels (active)
  - GBPUSD: Có 1 hedge (active)
  - USDJPY: Có 3 DCA levels (active)
  - AUDUSD: **KHÔNG mở** vì đã đủ 3 symbols active

### **Symbol Priority**

EA ưu tiên symbols theo:

1. **RSI điều kiện tốt nhất** (càng oversold/overbought càng tốt)
2. **Chạm S/R level gần nhất**
3. **Theo thứ tự trong danh sách** nếu điều kiện bằng nhau

---

## 💰 Risk Management

### **Lot Size Calculation**

```
Base Lot = (Account Balance / accountPer500) × 0.01
```

**Ví dụ:**

- Balance: $5,000
- accountPer500 = 500
- Base Lot = (5000 / 500) × 0.01 = **0.10 lot**

**Với 4 symbols active:**

- Mỗi symbol: 0.10 lot × 5 DCA levels = 0.50 lot max
- Tổng: 0.50 lot × 4 symbols = **2.0 lots max**

### **Drawdown Protection**

```
useMaxDrawdown = true
maxDrawdownPct = 20%
```

- Khi drawdown đạt 20% → **Đóng tất cả positions** của tất cả symbols
- Reset và chờ điều kiện mới

### **Recommended Settings**

| Account Size | accountPer500 | Max Symbols | Max Drawdown |
| ------------ | ------------- | ----------- | ------------ |
| $500         | 500           | 2           | 15%          |
| $1,000       | 500           | 3           | 18%          |
| $5,000       | 500           | 4           | 20%          |
| $10,000      | 1000          | 6           | 20%          |

---

## 🎯 Chiến Lược Tối Ưu

### **Timeframe Recommendations**

| Timeframe | Số Symbols | Phong Cách               |
| --------- | ---------- | ------------------------ |
| M5        | 2-3        | Scalping, nhiều tín hiệu |
| M15       | 3-5        | Intraday, cân bằng       |
| H1        | 4-8        | Swing, ít signals        |
| H4        | 6-10       | Position, hold lâu       |

### **Symbol Pairs Strategy**

**Phân tán rủi ro:**

```
Group 1 (USD base): EURUSD, GBPUSD, AUDUSD
Group 2 (JPY quote): USDJPY, EURJPY, GBPJPY
Group 3 (Cross): EURGBP, EURAUD, GBPAUD
```

Chọn **1-2 symbols từ mỗi group** để tránh correlation cao.

---

## 🔧 Troubleshooting

### ❌ **Symbol not found**

```
❌ Symbol EURUSD not found in Market Watch
```

**Solution:**

1. Mở Market Watch (Ctrl + M)
2. Right-click → `Show All` hoặc `Symbol` → tìm và show symbol

### ❌ **Failed to create RSI**

```
❌ Failed to create RSI for GBPUSD
```

**Solution:**

1. Mở chart symbol đó một lần
2. Chờ tải xong historical data
3. Restart EA

### ❌ **No signals**

```
📊 Found 4 symbols to trade
... (không có BUY/SELL signal)
```

**Solution:**

- Đợi RSI vào vùng oversold (<30) hoặc overbought (>70)
- Giảm `confirmBars` từ 2 → 1
- Tăng `srTouchPips` từ 5.0 → 10.0
- Hoặc tắt `usePriceTouch = false` để không cần confirm S/R

---

## 📈 Performance Monitoring

### **Theo Dõi Từng Symbol**

Mỗi symbol có magic number riêng:

```
EURUSD: Magic 999777_001
GBPUSD: Magic 999777_002
USDJPY: Magic 999777_003
```

Xem comment của positions:

```
RSI_SR_L1     // DCA Level 1
RSI_SR_L2     // DCA Level 2
RSI_SR_HEDGE  // Hedge position
```

### **Statistics**

EA tự động track:

- Total sequences per symbol
- Win rate per symbol
- Total profit per symbol
- Drawdown per symbol

---

## 🎮 Quick Start Template

### **Copy & Paste Settings**

```
// CONSERVATIVE
useMultiSymbol = true
tradingSymbols = "EURUSD,GBPUSD,USDJPY"
maxSymbolsActive = 2
dcaMaxLevel = 3
dcaStepPips = 30.0
individualTPPips = 40.0
useMaxDrawdown = true
maxDrawdownPct = 15.0

// BALANCED
useMultiSymbol = true
tradingSymbols = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"
maxSymbolsActive = 3
dcaMaxLevel = 5
dcaStepPips = 20.0
individualTPPips = 50.0
useMaxDrawdown = true
maxDrawdownPct = 20.0

// AGGRESSIVE
useMultiSymbol = true
tradingSymbols = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,NZDUSD,EURJPY,GBPJPY"
maxSymbolsActive = 5
dcaMaxLevel = 5
dcaStepPips = 15.0
individualTPPips = 60.0
useMaxDrawdown = true
maxDrawdownPct = 25.0
```

---

## 🚀 Advanced Tips

1. **VPS Recommended:** Multi-symbol EA chạy 24/7 cần VPS
2. **Spread Filter:** Chỉ trade khi spread < 2.0 pips
3. **News Filter:** Tránh trade 15 phút trước/sau news quan trọng
4. **Correlation Check:** Tránh các cặp correlation > 0.8
5. **Backtest từng symbol** trước khi thêm vào danh sách

---

## 📞 Support

Nếu có vấn đề:

1. Check tab **Experts** trong MT5
2. Xem log messages
3. Screenshot và báo lỗi

**Happy Multi-Symbol Trading! 🚀💰**
