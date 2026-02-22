# Tài Liệu Kỹ Thuật: Medusa (Viper Multi-Bot) EA

## 1. Tổng Quan
**Medusa (Viper Multi-Bot)** là một Expert Advisor (EA) giao dịch đa cặp tiền (Multi-Currency) và đa chiến thuật. Bot được thiết kế theo kiến trúc Hướng đối tượng (OOP), trong đó mỗi cặp tiền được quản lý bởi một đối tượng `CViperBot` riêng biệt nhưng hoạt động song song trong cùng một EA.

*   **Phiên bản**: 1.15
*   **Nền tảng**: MT5
*   **Kiến trúc**: Multi-Agent (Mỗi Symbol là 1 Agent độc lập), quản lý Global Profit tập trung.

## 2. Chiến Lược Giao Dịch (Entry Strategy)
Bot hỗ trợ 2 chế độ vào lệnh chính qua tham số `InpEntryMode`:

### A. Chiến lược Theo Khoảng Cách D1 (`ENTRY_DISTANCE_D1`)
Dựa trên giá đóng cửa của nến Ngày hôm qua (`D1 Close`).
*   **BUY**: Khi giá hiện tại giảm xuống thấp hơn (`D1 Close` - `InpEntryRange` pips).
    *   *Tư duy*: Bắt đáy khi giá đã giảm sâu so với ngày hôm trước (Mean Reversion).
*   **SELL**: Khi giá hiện tại tăng lên cao hơn (`D1 Close` + `InpEntryRange` pips).
    *   *Tư duy*: Bắt đỉnh khi giá đã tăng mạnh.

### B. Chiến lược Hộp Box (`ENTRY_BOX_GRID`)
Dựa trên vùng giá cao nhất/thấp nhất trong khoảng thời gian `InpBoxPeriod`.
*   **BUY**: Khi giá nằm ở vùng 25% dưới của hộp (Gần đáy cũ).
*   **SELL**: Khi giá nằm ở vùng 25% trên của hộp (Gần đỉnh cũ).

### C. Điều Kiện Lọc (Filters)
Lệnh đầu tiên chỉ được mở nếu thỏa mãn các bộ lọc:
1.  **RSI Filter (`InpUseRSIEntry`)**:
    *   **2-Way**: Chỉ vào lệnh nếu RSI nằm trong vùng an toàn (VD: 30-70).
    *   **1-Way**: Chặn mua nếu RSI quá cao, chặn bán nếu RSI quá thấp.
2.  **RSI Multi-Timeframe (`InpUseRSICustom`)**: Lọc thêm bằng RSI của khung thời gian lớn hơn (VD: H4).
3.  **Hedge Mode (`InpHedgeMode`)**:
    *   Cho phép mở lệnh ngược chiều (Buy và Sell cùng lúc) nếu thỏa mãn điều kiện.
    *   Nếu tắt, Bot chỉ mở lệnh mới nếu chưa có lệnh nào hoặc hướng đó đang trống.

## 3. Quản Lý Vốn & DCA (Dollar Cost Averaging)
Khi lệnh đi ngược xu hướng, Bot sử dụng cơ chế DCA để trung bình giá.

### A. Phương pháp DCA (`InpDcaMethod`)
1.  **Classic**: Khoảng cách Grid cố định (`InpGridDist`).
2.  **2-Phase**: Chia làm 2 giai đoạn.
    *   Giai đoạn đầu (VD: 10 lệnh đầu): Dùng khoảng cách ngắn (`InpPhase1Dist`).
    *   Giai đoạn sau: Dùng khoảng cách xa hơn (`InpPhase2Dist`) để gồng lỗ tốt hơn.
3.  **Trend Cover**: Cơ chế đặc biệt.
    *   Nếu số lệnh đạt mức `InpCoverStart` (VD: 5 lệnh Sell đang lỗ), Bot sẽ mở một lệnh **BUY** khối lượng lớn (`Tổng Sell * InpCoverMult`) để cân bằng (Hedge) hoặc khóa lỗ tạm thời.
4.  **ATR Grid (`InpUseATR`)**: Khoảng cách DCA không cố định mà co giãn theo biến động thị trường (ATR). Biến động mạnh -> Giãn Grid.

### B. Martingale (Gấp thếp)
Khối lượng lệnh DCA tăng dần theo 3 cấp độ (3 Levels):
*   **Level 1** (Từ lệnh `InpMartingaleStart1`): Hệ số nhân `InpMartingaleMult1` (VD: 1.1).
*   **Level 2** (Từ lệnh `InpMartingaleStart2`): Hệ số nhân `InpMartingaleMult2` (VD: 1.2).
*   **Level 3** (Từ lệnh `InpMartingaleStart3`): Hệ số nhân `InpMartingaleMult3` (VD: 1.5).
-> Giúp thoát lệnh nhanh ở các vòng đầu, nhưng tăng rủi ro (hoặc thoát cực nhanh) nếu gồng quá sâu.

## 4. Chiến Lược Thoát Lệnh (Exit Strategy)

### A. Take Profit (Chốt lời)
Hỗ trợ 3 cách tính TP qua `InpTPMethod`:
1.  **Fixed Pips**: Chốt lời cố định (VD: 10 pips trung bình giá).
2.  **Dynamic Pips**: TP giảm dần khi số lệnh tăng lên (VD: Lệnh 1 cần 10 pips, Lệnh 10 chỉ cần 2 pips để về bờ).
3.  **Target Money**: Chốt lời theo số tiền USD cụ thể (VD: Lãi $10 thì đóng).

### B. Cơ chế Đặc biệt
*   **Breakeven (`InpBreakevenStart`)**: Khi số lệnh đạt mức nào đó, chỉ cần giá quay về điểm hòa vốn + 1 chút lãi (`InpBreakevenPips`) là đóng lệnh để bảo toàn vốn.
*   **SL After Last (`InpSLAfterLast`)**: Đặt Stop Loss cứng sau lệnh DCA cuối cùng một khoảng cách định sẵn. Chấp nhận cắt lỗ nếu giá đi quá xa.

## 5. Quản Lý Rủi Ro & Thời Gian
*   **Mục Tiêu Lợi Nhuận Ngày (`InpDailyProfitTarget`)**: Nếu tổng lợi nhuận của tất cả các cặp tiền trong ngày đạt % vốn định sẵn (VD: 1%), Bot sẽ dừng trading trong ngày đó (`m_gStoppedToday`).
*   **Bộ lọc Thời gian**:
    *   **Time Slots**: Chỉ trade trong các khung giờ cho phép (T1, T2).
    *   **No Trade Time**: Tránh các khung giờ rủi ro (NT1, NT2).
    *   **Ngày giao dịch**: Có thể tắt trade Thứ 6, Ngày Đầu/Cuối tháng.
*   **Tin Tức (`InpUseNewsFilter`)**: Tự động ngừng vào lệnh trước và sau tin tức mạnh (High Impact).

## 6. Cấu Trúc Code
*   **`CViperBot`**: Class xử lý logic cho 1 cặp tiền.
    *   `Processing()`: Hàm chính chạy mỗi tick/giây.
    *   `CheckNewDeals()`: Theo dõi lịch sử để tính lợi nhuận ngày.
*   **`OnInit`**: Khởi tạo mảng các Bot dựa trên danh sách `InpSymbols`.
*   **`OnTimer`**:
    *   Gọi `CalcGlobalProfit()`: Tính tổng lãi ngày của tất cả Bot.
    *   Gọi `Processing()` cho từng Bot.
*   **Expiration**: Bot có hạn sử dụng cứng đến `30/06/2026`.

## 7. Inputs Quan Trọng Cần Lưu Ý
| Tham số | Ý nghĩa | Lời khuyên |
| :--- | :--- | :--- |
| `InpEntryMode` | Cách vào lệnh | Dùng `DISTANCE_D1` cho thị trường Sideway biên độ rộng. |
| `InpDcaMethod` | Cách DCA | Dùng `CLASSIC` cho đơn giản, `2PHASE` để tối ưu vùng giá. |
| `InpMartingaleStart3` | Gấp lệnh mạnh | Cẩn thận với hệ số nhân lớn ở Level 3. |
| `InpDailyProfitTarget`| Chốt lãi ngày | Nên để 1-2% để bảo toàn thành quả. |
| `InpHedgeMode` | Đánh 2 đầu | Chỉ bật nếu tài khoản đủ Margin chịu được 2 chiều. |
