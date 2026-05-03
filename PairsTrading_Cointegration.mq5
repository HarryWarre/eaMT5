//+------------------------------------------------------------------+
//|                                                         main.mq5 |
//|                                     Pairs Trading Cointegration  |
//|               Copyright 2026, DaiViet Quant                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DaiViet Quant"
#property version   "3.00"
#property strict

//+------------------------------------------------------------------+
//|                                                       Inputs.mqh |
//|                                     Pairs Trading Cointegration  |
//+------------------------------------------------------------------+
#property strict

//--- Input Group: Main Settings
input group "=== PAIRS TRADING SETTINGS ==="
input string    InpBaseSymbol  = "EURUSD";      // Base Symbol (e.g. EURUSD)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // Execution Timeframe
input ENUM_TIMEFRAMES InpScanTimeframe = PERIOD_D1; // Correlation Scan Timeframe

//--- Input Group: Dynamic Matrix
input group "=== MATRIX SCANNER ==="
input string    InpScanUniverse = "GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURJPY,EURGBP,EURAUD,EURNZD,EURCAD,EURCHF"; // Symbols to scan (comma separated)
input double    InpMinCorrelation = 0.50;       // Minimum Abs Correlation (|r|)
input double    InpMaxCorrelation = 0.80;       // Maximum Abs Correlation (|r|)
input int       InpMaxPairsLimit  = 5;          // Maximum Simultaneous Pairs traded

//--- Input Group: Execution & Risk Management
input group "=== RISK & EXECUTION ==="
input double    InpBaseLotSize = 0.01;          // Base Lot Size
input double    InpZScoreEntry = 2.0;           // Z-Score Entry Threshold
input double    InpZScoreSL    = 4.0;           // Z-Score Hard Stop Loss Threshold (0=disabled)
input int       InpMinLookback = 50;            // Minimum Lookback Period
input int       InpMaxLookback = 500;           // Maximum Lookback Limit
input int       InpMagicNumber = 123456;        // EA Magic Number
input bool      InpCloseEOM    = true;          // Close all positions at End of Month

//--- Input Group: DCA Grid (Per-Leg, Point-Based)
input group "=== DCA GRID (PER LEG) ==="
input int       InpDCAStepPoints   = 500;       // DCA Step in Points (e.g. 500 = 50 pips on 5-digit)
input int       InpDCAMaxLevels    = 5;         // Max DCA Levels per Leg
input double    InpDCALotMultiplier = 1.5;      // DCA Lot Multiplier (Martingale)
input double    InpBreakevenUSD    = 5.0;       // Breakeven Target per Leg ($)
input double    InpBasketSL_USD    = 100.0;     // Max Loss per Leg in USD (0 = disabled)
input int       InpLegSL_Points    = 0;         // Hard SL per individual order in Points (0 = disabled)

//--- Input Group: Advanced Modes (ON/OFF)
input group "=== ADVANCED MODES ==="
input bool      InpUseTrailingTP    = true;      // [1] Trailing Profit (Chimera Style)
input double    InpTrailPullback    = 0.20;      // Trailing Pullback Ratio (0.20 = 20%)
input bool      InpUseCrossRecovery = true;      // [2] Cross-Matrix Recovery (cứu hộ chéo)
input bool      InpCloseWinOnZero   = true;      // [3] Close winning leg when Z=0 (keep losing leg for DCA)

//--- Fixed Settings
int    CONST_D1_LOOKBACK = 252; // Lookback window for D1
double CONST_ADF_THRESHOLD = -2.86; // ADF Critical value for p < 0.05

//+------------------------------------------------------------------+
//|                                                     MathStat.mqh |
//|                                     Pairs Trading Cointegration  |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| OLS Linear Regression: Y = beta * X + alpha                      |
//+------------------------------------------------------------------+
bool MathOLS(const double &X[], const double &Y[], int length, double &beta, double &alpha) {
   if(length < 2 || ArraySize(X) < length || ArraySize(Y) < length) return false;
   
   double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
   for(int i = 0; i < length; i++) {
      sumX += X[i];
      sumY += Y[i];
      sumXY += X[i] * Y[i];
      sumXX += X[i] * X[i];
   }
   
   double n = (double)length;
   double denominator = n * sumXX - sumX * sumX;
   
   if(denominator == 0.0) return false;
   
   beta = (n * sumXY - sumX * sumY) / denominator;
   alpha = (sumY - beta * sumX) / n;
   
   return true;
}

//+------------------------------------------------------------------+
//| Ornstein-Uhlenbeck Process: Calculate Half-Life                  |
//| dSpread = theta * (mu - Spread) dt + sigma dW                    |
//| Using linear regression: Spread[i] - Spread[i-1] ~ Spread[i-1]   |
//+------------------------------------------------------------------+
bool MathOUProcess(const double &Spread[], int length, double &halfLife) {
   if(length < 3 || ArraySize(Spread) < length) return false;
   
   // We need to regress dS on S_lag
   // S_lag = Spread[i-1]
   // dS = Spread[i] - Spread[i-1]
   // Array size: length-1
   
   double dS[];
   double SLag[];
   ArrayResize(dS, length - 1);
   ArrayResize(SLag, length - 1);
   
   for(int i = 1; i < length; i++) {
      dS[i-1] = Spread[i] - Spread[i-1];
      SLag[i-1] = Spread[i-1];
   }
   
   double beta = 0, alpha = 0;
   if(!MathOLS(SLag, dS, length - 1, beta, alpha)) return false;
   
   // Mean reversion speed = -beta
   if(beta >= 0) {
      // Not mean-reverting
      halfLife = 999999;
      return true;
   }
   
   halfLife = -MathLog(2.0) / beta;
   return true;
}

//+------------------------------------------------------------------+
//| Dickey-Fuller Test (0-lag ADF)                                   |
//| Computes the t-statistic of gamma for regression:                |
//| dY_t = c + gamma * Y_{t-1} + e_t                                 |
//+------------------------------------------------------------------+
bool MathADFTest(const double &Spread[], int length, double &tStatistic) {
   if(length < 4 || ArraySize(Spread) < length) return false;
   
   double dY[];
   double YLag[];
   ArrayResize(dY, length - 1);
   ArrayResize(YLag, length - 1);
   
   double sumYlag = 0;
   for(int i = 1; i < length; i++) {
      double diff = Spread[i] - Spread[i-1];
      dY[i-1] = diff;
      YLag[i-1] = Spread[i-1];
      sumYlag += Spread[i-1];
   }
   
   int n = length - 1;
   double gamma = 0, c = 0;
   if(!MathOLS(YLag, dY, n, gamma, c)) return false;
   
   double meanYlag = sumYlag / n;
   double ssx = 0;
   for(int i = 0; i < n; i++) {
      double dev = YLag[i] - meanYlag;
      ssx += dev * dev;
   }
   
   if(ssx == 0) return false;
   
   // Residuals and standard error
   double sse = 0;
   for(int i = 0; i < n; i++) {
      double e_i = dY[i] - (gamma * YLag[i] + c);
      sse += e_i * e_i;
   }
   
   // Degrees of freedom for simple regression is n-2
   double mse = sse / (n - 2);
   
   double se_gamma = MathSqrt(mse / ssx);
   
   if(se_gamma == 0) return false;
   
   tStatistic = gamma / se_gamma;
   return true;
}

//+------------------------------------------------------------------+
//| Mean and Standard Deviation                                      |
//+------------------------------------------------------------------+
bool MathZScore(const double &data[], int length, double &zscore, double &meanOut, double &stdevOut) {
   if(length < 2 || ArraySize(data) < length) return false;
   
   double sum = 0;
   for(int i = 0; i < length; i++) {
      sum += data[i];
   }
   double mean = sum / length;
   
   double sumSq = 0;
   for(int i = 0; i < length; i++) {
      double dev = data[i] - mean;
      sumSq += dev * dev;
   }
   double stdev = MathSqrt(sumSq / (length - 1));
   
   if(stdev == 0) return false;
   
   meanOut = mean;
   stdevOut = stdev;
   zscore = (data[length - 1] - mean) / stdev; // Last value against the window
   return true;
}

//+------------------------------------------------------------------+
//| Pearson Correlation Coefficient (r)                              |
//+------------------------------------------------------------------+
bool MathCorrelation(const double &X[], const double &Y[], int length, double &r) {
   if(length < 2 || ArraySize(X) < length || ArraySize(Y) < length) return false;
   
   double sumX = 0, sumY = 0;
   for(int i = 0; i < length; i++) {
      sumX += X[i];
      sumY += Y[i];
   }
   double meanX = sumX / length;
   double meanY = sumY / length;
   
   double num = 0, denX = 0, denY = 0;
   for(int i = 0; i < length; i++) {
      double dx = X[i] - meanX;
      double dy = Y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
   }
   
   double den = MathSqrt(denX * denY);
   if(den == 0) return false;
   
   r = num / den;
   return true;
}

//+------------------------------------------------------------------+
//|                                                      Scanner.mqh |
//|                                     Pairs Trading Cointegration  |
//+------------------------------------------------------------------+
#property strict




struct SPairCandidate {
   string symbolB;
   double correlation;
};

class CScanner {
private:
   SPairCandidate m_candidates[];
   int            m_count;
   datetime       m_lastScanTime;

   bool FetchScanPrices(string sym, double &outLogPrices[]) {
      double prices[];
      if(CopyClose(sym, InpScanTimeframe, 1, CONST_D1_LOOKBACK, prices) < CONST_D1_LOOKBACK) return false;
      
      ArraySetAsSeries(prices, false);
      ArrayResize(outLogPrices, CONST_D1_LOOKBACK);
      
      for(int i = 0; i < CONST_D1_LOOKBACK; i++) {
         if(prices[i] <= 0) return false;
         outLogPrices[i] = MathLog(prices[i]);
      }
      return true;
   }

public:
   CScanner() {
      m_count = 0;
      m_lastScanTime = 0;
   }

   bool Scan() {
      Print("----- DEBUG SCANNER: BẮT ĐẦU QUÉT -----");
      Print("Scanner: Initiating Market Watch Correlation Scan on ", EnumToString(InpScanTimeframe));
      
      int totalSymbols = SymbolsTotal(true);
      Print("DEBUG: Tổng số symbol đang có trên Mảng Market Watch (SymbolsTotal=true) là: ", totalSymbols);
      if(totalSymbols <= 1) {
         Print("CẢNH BÁO: Trong Market Watch hoặc Strategy Tester hiện tại CHỈ CÓ 1 SYMBOL. Bạn cần mở Market Watch -> Show All, hoặc trong Tester phải config nạp thêm các cặp tiền phụ!");
      }

      double baseLogPrices[];
      if(!FetchScanPrices(InpBaseSymbol, baseLogPrices)) {
         Print("DEBUG LỖI: Failed to fetch base symbol prices: ", InpBaseSymbol, ". Khả năng cặp này đang thiếu nến lịch sử D1.");
         return false;
      }
      Print("DEBUG: Đã tải thành công dữ liệu lịch sử gốc cho: ", InpBaseSymbol);

      m_count = 0;
      ArrayResize(m_candidates, InpMaxPairsLimit * 2); // Buffer space
      
      for(int i = 0; i < totalSymbols; i++) {
         string candSym = SymbolName(i, true);
         if(candSym == InpBaseSymbol) continue;
         
         double candLogPrices[];
         if(!FetchScanPrices(candSym, candLogPrices)) {
            Print("DEBUG BỎ QUA: [", candSym, "] -> Không tải được đủ ", CONST_D1_LOOKBACK, " nến lịch sử. (Vui lòng mở chart tay một lần để tải nến)");
            continue;
         }
         
         double r = 0;
         if(MathCorrelation(baseLogPrices, candLogPrices, CONST_D1_LOOKBACK, r)) {
            double absR = MathAbs(r);
            PrintFormat("DEBUG PHÂN TÍCH: So sánh [%s] vs [%s] -> Correlation (r) = %.4f | Tuyệt đối (|r|) = %.4f", InpBaseSymbol, candSym, r, absR);
            
            if(absR >= InpMinCorrelation && absR <= InpMaxCorrelation) {
               PrintFormat("  >> HỢP LỆ: Đưa [%s] vào danh sách giao dịch vì nằm trong dải %.2f -> %.2f", candSym, InpMinCorrelation, InpMaxCorrelation);
               
               if(m_count < ArraySize(m_candidates)) {
                  m_candidates[m_count].symbolB = candSym;
                  m_candidates[m_count].correlation = r;
                  m_count++;
               }
               
               if(m_count >= InpMaxPairsLimit) {
                  Print("Scanner: Max Pairs limit reached (", InpMaxPairsLimit, "). Dừng vòng lặp quét sớm để tiết kiệm CPU.");
                  break;
               }
            } else {
               // PrintFormat("  >> LOẠI YẾU: Bỏ qua [%s] vì độ tương quan không nằm trong dải lọc.", candSym);
            }
         }
      }
      
      ArrayResize(m_candidates, m_count);
      m_lastScanTime = TimeCurrent();
      Print("----- DEBUG SCANNER: KẾT THÚC QUÉT | CÁC CẶP ĐÃ TÌM THẤY: ", m_count, " -----");
      return true;
   }
   
   int GetCount() const { return m_count; }
   string GetCandidateSymbol(int index) const {
      if(index >= 0 && index < m_count) return m_candidates[index].symbolB;
      return "";
   }
};

//+------------------------------------------------------------------+
//|                                                Cointegration.mqh |
//|                                     Pairs Trading Cointegration  |
//+------------------------------------------------------------------+
#property strict




class CCointegration {
private:
   string         m_symA;
   string         m_symB;
   
   double         m_pricesA[];
   double         m_pricesB[];
   double         m_logPricesA[];
   double         m_logPricesB[];
   double         m_spread[];
   
   int            m_currentLookback;
   double         m_currentBeta;
   double         m_currentZScore;
   bool           m_isCointegrated;
   double         m_halfLife;

   bool FetchPrices(int maxBars) {
      if(CopyClose(m_symA, InpTimeframe, 1, maxBars, m_pricesA) < maxBars) return false;
      if(CopyClose(m_symB, InpTimeframe, 1, maxBars, m_pricesB) < maxBars) return false;
      
      ArraySetAsSeries(m_pricesA, false);
      ArraySetAsSeries(m_pricesB, false);
      
      ArrayResize(m_logPricesA, maxBars);
      ArrayResize(m_logPricesB, maxBars);
      
      for(int i = 0; i < maxBars; i++) {
         if(m_pricesA[i] <= 0 || m_pricesB[i] <= 0) return false;
         m_logPricesA[i] = MathLog(m_pricesA[i]);
         m_logPricesB[i] = MathLog(m_pricesB[i]);
      }
      return true;
   }

public:
   CCointegration() {
      m_currentLookback = InpMinLookback;
      m_currentBeta = 1.0;
      m_currentZScore = 0.0;
      m_isCointegrated = false;
      m_halfLife = 0;
   }
   
   void Init(string symA, string symB) {
      m_symA = symA;
      m_symB = symB;
   }

   bool Update() {
      int initialLookback = InpMaxLookback;
      if(!FetchPrices(initialLookback)) return false;

      // 1. Initial Beta over full max window to find broad relationship
      double alpha = 0;
      if(!MathOLS(m_logPricesB, m_logPricesA, initialLookback, m_currentBeta, alpha)) return false;

      // 2. Compute spread over initial window
      ArrayResize(m_spread, initialLookback);
      for(int i = 0; i < initialLookback; i++) {
         m_spread[i] = m_logPricesA[i] - m_currentBeta * m_logPricesB[i];
      }

      // 3. Calculate Half-Life via OU Process
      if(!MathOUProcess(m_spread, initialLookback, m_halfLife)) return false;

      // 4. Dynamic Lookback Calculation (4.32 * tau for H1, or fixed 252 for D1)
      if(InpTimeframe == PERIOD_D1) {
         m_currentLookback = CONST_D1_LOOKBACK;
      } else {
         m_currentLookback = (int)MathRound(4.32 * m_halfLife);
      }
      
      // Bound lookback
      if(m_currentLookback < InpMinLookback) m_currentLookback = InpMinLookback;
      if(m_currentLookback > InpMaxLookback) m_currentLookback = InpMaxLookback;

      // 5. Re-evaluate Beta and Spread over the Dynamic Lookback
      int startIndex = initialLookback - m_currentLookback;
      double windowLogA[];
      double windowLogB[];
      ArrayResize(windowLogA, m_currentLookback);
      ArrayResize(windowLogB, m_currentLookback);
      
      for(int i = 0; i < m_currentLookback; i++) {
         windowLogA[i] = m_logPricesA[startIndex + i];
         windowLogB[i] = m_logPricesB[startIndex + i];
      }

      if(!MathOLS(windowLogB, windowLogA, m_currentLookback, m_currentBeta, alpha)) return false;

      double windowSpread[];
      ArrayResize(windowSpread, m_currentLookback);
      for(int i = 0; i < m_currentLookback; i++) {
         windowSpread[i] = windowLogA[i] - m_currentBeta * windowLogB[i];
      }

      // 6. ADF Test strictly on the dynamic window
      double adfTStat = 0;
      m_isCointegrated = false;
      if(MathADFTest(windowSpread, m_currentLookback, adfTStat)) {
         if(adfTStat < CONST_ADF_THRESHOLD) { // 5% P-Value roughly translated
            m_isCointegrated = true;
         }
      }

      // 7. Z-Score Standardization
      double mean = 0, stdev = 0;
      if(!MathZScore(windowSpread, m_currentLookback, m_currentZScore, mean, stdev)) return false;

      return true;
   }

   double GetZScore()        const { return m_currentZScore; }
   double GetBeta()          const { return m_currentBeta; }
   bool   IsCointegrated()   const { return m_isCointegrated; }
   double GetHalfLife()      const { return m_halfLife; }
   int    GetLookback()      const { return m_currentLookback; }
};

//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
//|                 Independent Leg Management Architecture          |
//|                      CLegManager + CPairManager                  |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>




//====================================================================
// CLegManager: Quản lý 1 chân (symbol) ĐỘC LẬP như một mini Grid EA
//====================================================================
class CLegManager {
private:
   string         m_symbol;
   int            m_magic;
   int            m_direction;    // 1 = Buy, -1 = Sell
   bool           m_isActive;
   int            m_gridCount;
   double         m_baseLot;
   
   CTrade         m_trade;
   CPositionInfo  m_position;
   
   // Trailing
   bool           m_trailingActive;
   double         m_trailingMaxProfit;

public:
   CLegManager() {
      m_isActive = false;
      m_gridCount = 0;
      m_direction = 0;
      m_baseLot = 0.01;
      m_trailingActive = false;
      m_trailingMaxProfit = 0;
   }

   void Init(string symbol, int magic, double baseLot) {
      m_symbol = symbol;
      m_magic = magic;
      m_baseLot = baseLot;
      m_trade.SetExpertMagicNumber(m_magic);
   }
   
   string GetSymbol()    const { return m_symbol; }
   int    GetMagic()     const { return m_magic; }
   bool   IsActive()     const { return m_isActive; }
   int    GetDirection()  const { return m_direction; }

   //--- Count positions belonging to this leg
   void Refresh() {
      m_gridCount = 0;
      m_isActive = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol) {
               m_gridCount++;
               m_isActive = true;
               m_direction = (m_position.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
            }
         }
      }
   }

   //--- Get total floating profit for this leg
   double GetFloatingProfit() {
      double profit = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol) {
               profit += m_position.Profit() + m_position.Swap() + m_position.Commission();
            }
         }
      }
      return profit;
   }

   //--- Open initial entry
   bool OpenEntry(int direction, double lot) {
      if(m_isActive) return false;
      
      bool ok = false;
      if(direction == 1)
         ok = m_trade.Buy(lot, m_symbol, 0, 0, 0, "L0");
      else
         ok = m_trade.Sell(lot, m_symbol, 0, 0, 0, "L0");
      
      if(ok) {
         m_isActive = true;
         m_direction = direction;
         m_gridCount = 1;
         m_trailingActive = false;
         m_trailingMaxProfit = 0;
      }
      return ok;
   }

   //--- DCA Grid by Point distance (Chimera ManageGrid style)
   void ManageDCA() {
      if(!m_isActive) return;
      if(m_gridCount >= InpDCAMaxLevels) return;
      if(GetFloatingProfit() >= 0) return; // Only DCA when losing
      
      // Find worst price (furthest from current)
      double lastPrice = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol) {
               double p = m_position.PriceOpen();
               if(lastPrice == 0) lastPrice = p;
               // For Buy: find lowest open price (worst). For Sell: find highest.
               if(m_direction == 1) { if(p < lastPrice) lastPrice = p; }
               else { if(p > lastPrice) lastPrice = p; }
            }
         }
      }
      if(lastPrice == 0) return;
      
      double currentPrice = (m_direction == 1) ? 
                             SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                             SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double dist = (m_direction == 1) ? 
                     (lastPrice - currentPrice) : 
                     (currentPrice - lastPrice);
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double requiredDist = InpDCAStepPoints * point;
      
      if(dist >= requiredDist) {
         // Martingale: lot × multiplier^level
         double mult = MathPow(InpDCALotMultiplier, m_gridCount);
         double dcaLot = NormalizeDouble(m_baseLot * mult, 2);
         if(dcaLot < 0.01) dcaLot = 0.01;
         
         string comment = "DCA_L" + IntegerToString(m_gridCount);
         bool ok = false;
         
         if(m_direction == 1)
            ok = m_trade.Buy(dcaLot, m_symbol, 0, 0, 0, comment);
         else
            ok = m_trade.Sell(dcaLot, m_symbol, 0, 0, 0, comment);
         
         if(ok) {
            m_gridCount++;
            PrintFormat("DCA %s [%s]: Level %d, Lot=%.2f, Dist=%.1f pts", 
                        comment, m_symbol, m_gridCount, dcaLot, dist/point);
         }
      }
   }

   //--- Check exit conditions (Breakeven / Trailing)
   bool CheckExit() {
      if(!m_isActive) return false;
      
      double profit = GetFloatingProfit();
      
      // Basket SL per leg
      if(InpBasketSL_USD > 0 && profit <= -InpBasketSL_USD) {
         CloseAll("Leg Basket SL ($" + DoubleToString(InpBasketSL_USD,0) + " hit)");
         return true;
      }
      
      if(InpUseTrailingTP) {
         // Trailing Profit mode
         double target = InpBreakevenUSD * m_gridCount; // Scale target with grid depth
         if(target < InpBreakevenUSD) target = InpBreakevenUSD;
         
         if(!m_trailingActive) {
            if(profit >= target) {
               m_trailingActive = true;
               m_trailingMaxProfit = profit;
               PrintFormat("TRAILING ON [%s]: Profit=%.2f Target=%.2f Grid=%d", 
                           m_symbol, profit, target, m_gridCount);
            }
            // Breakeven rescue: DCA'd and profit back to breakeven
            else if(profit >= InpBreakevenUSD && m_gridCount > 1) {
               PrintFormat("BREAKEVEN [%s]: Profit=%.2f Grid=%d", m_symbol, profit, m_gridCount);
               CloseAll("Breakeven Recovery (DCA Success)");
               return true;
            }
         } else {
            if(profit > m_trailingMaxProfit) m_trailingMaxProfit = profit;
            
            double step = target * InpTrailPullback;
            
            if(profit < m_trailingMaxProfit - step && profit >= 0) {
               PrintFormat("TRAILING TP [%s]: Max=%.2f Closed=%.2f", m_symbol, m_trailingMaxProfit, profit);
               CloseAll("Trailing Take Profit");
               return true;
            }
            if(profit < 0) {
               m_trailingActive = false;
               m_trailingMaxProfit = 0;
            }
         }
      } else {
         // Simple breakeven mode
         if(profit >= InpBreakevenUSD) {
            PrintFormat("BREAKEVEN TP [%s]: Profit=%.2f >= $%.2f", m_symbol, profit, InpBreakevenUSD);
            CloseAll("Breakeven Target Reached");
            return true;
         }
      }
      
      return false;
   }

   //--- Close all positions for this leg
   void CloseAll(string reason) {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == m_symbol) {
               m_trade.PositionClose(m_position.Ticket());
            }
         }
      }
      m_isActive = false;
      m_gridCount = 0;
      m_direction = 0;
      m_trailingActive = false;
      m_trailingMaxProfit = 0;
      PrintFormat("LEG CLOSED [%s]: %s", m_symbol, reason);
   }
};


//====================================================================
// CPairManager: Quản lý 1 cặp Hedge (2 CLegManager độc lập)
//====================================================================
class CPairManager {
private:
   CLegManager    m_legA;
   CLegManager    m_legB;
   string         m_symA;
   string         m_symB;
   bool           m_entryFired;  // Has the initial hedge been opened?

public:
   CPairManager() {
      m_entryFired = false;
   }
   
   void Init(string symA, string symB) {
      m_symA = symA;
      m_symB = symB;
      
      // Unique magic per leg per pair via hash
      int hashA = 0, hashB = 0;
      for(int k = 0; k < StringLen(symA); k++) hashA += StringGetCharacter(symA, k);
      for(int k = 0; k < StringLen(symB); k++) hashB += StringGetCharacter(symB, k);
      int pairHash = hashA + hashB * 2; // Combine both symbols for uniqueness
      
      m_legA.Init(symA, InpMagicNumber + pairHash + 1, InpBaseLotSize);
      m_legB.Init(symB, InpMagicNumber + pairHash + 2, InpBaseLotSize);
   }
   
   bool HasAnyActive() {
      return m_legA.IsActive() || m_legB.IsActive();
   }
   
   double GetTotalFloating() {
      return m_legA.GetFloatingProfit() + m_legB.GetFloatingProfit();
   }
   
   void CloseAll(string reason) {
      if(m_legA.IsActive()) m_legA.CloseAll(reason);
      if(m_legB.IsActive()) m_legB.CloseAll(reason);
      m_entryFired = false;
   }

   void Manage(CCointegration &coint) {
      m_legA.Refresh();
      m_legB.Refresh();
      
      double zScore = coint.GetZScore();
      double beta = coint.GetBeta();
      bool isCointegrated = coint.IsCointegrated();
      
      bool legAActive = m_legA.IsActive();
      bool legBActive = m_legB.IsActive();
      
      // =====================================================
      // ENTRY: Both legs inactive → Open Hedge if signal
      // =====================================================
      if(!legAActive && !legBActive) {
         m_entryFired = false;
         if(!isCointegrated) return;
         
         if(zScore >= InpZScoreEntry) {
            // Short Spread: Sell A, Buy B
            double lotB = NormalizeDouble(MathAbs(InpBaseLotSize * beta), 2);
            if(lotB < 0.01) lotB = 0.01;
            int dirB = (beta >= 0) ? 1 : -1; // Inverted for hedge
            
            PrintFormat("HEDGE ENTRY [%s-%s]: Z=%.2f, Short A + Long B", m_symA, m_symB, zScore);
            bool okA = m_legA.OpenEntry(-1, InpBaseLotSize);
            bool okB = m_legB.OpenEntry(dirB, lotB);
            
            if(okA && okB) m_entryFired = true;
            else {
               // Cleanup partial
               if(okA) m_legA.CloseAll("Partial entry cleanup");
               if(okB) m_legB.CloseAll("Partial entry cleanup");
            }
         } 
         else if(zScore <= -InpZScoreEntry) {
            // Long Spread: Buy A, Sell B
            double lotB = NormalizeDouble(MathAbs(InpBaseLotSize * beta), 2);
            if(lotB < 0.01) lotB = 0.01;
            int dirB = (beta >= 0) ? -1 : 1;
            
            PrintFormat("HEDGE ENTRY [%s-%s]: Z=%.2f, Long A + Short B", m_symA, m_symB, zScore);
            bool okA = m_legA.OpenEntry(1, InpBaseLotSize);
            bool okB = m_legB.OpenEntry(dirB, lotB);
            
            if(okA && okB) m_entryFired = true;
            else {
               if(okA) m_legA.CloseAll("Partial entry cleanup");
               if(okB) m_legB.CloseAll("Partial entry cleanup");
            }
         }
         return;
      }
      
      // =====================================================
      // MANAGEMENT: At least one leg is active
      // =====================================================
      
      // DCA Grid for each active leg independently
      if(legAActive) m_legA.ManageDCA();
      if(legBActive) m_legB.ManageDCA();
      
      // Refresh active state after DCA (grid count may have changed)
      legAActive = m_legA.IsActive();
      legBActive = m_legB.IsActive();
      
      bool bothLegsActive = (legAActive && legBActive);
      bool oneLegOnly = (legAActive != legBActive); // XOR: only one is active
      
      // =======================================================
      // SCENARIO A: BOTH legs still active (full hedge)
      // =======================================================
      if(bothLegsActive) {
         bool zNearZero = (MathAbs(zScore) < 0.5);
         
         if(zNearZero) {
            double totalPnL = m_legA.GetFloatingProfit() + m_legB.GetFloatingProfit();
            
            // Priority: If total hedge is positive at Z~0, close BOTH (always take profit)
            if(totalPnL > 0) {
               PrintFormat("Z~0 HEDGE TP [%s-%s]: Z=%.2f TotalPnL=+%.2f -> Close Both", m_symA, m_symB, zScore, totalPnL);
               m_legA.CloseAll("Z~0: Hedge Take Profit (Total > 0)");
               m_legB.CloseAll("Z~0: Hedge Take Profit (Total > 0)");
               m_entryFired = false;
               return;
            }
            
            // Total is negative at Z~0
            if(InpUseTrailingTP) {
               // Trailing ON: close winning leg, keep losing leg for DCA
               if(InpCloseWinOnZero) {
                  double profitA = m_legA.GetFloatingProfit();
                  double profitB = m_legB.GetFloatingProfit();
                  
                  if(profitA > 0) m_legA.CloseAll("Z~0: Close winning Leg A ($" + DoubleToString(profitA,2) + ")");
                  if(profitB > 0) m_legB.CloseAll("Z~0: Close winning Leg B ($" + DoubleToString(profitB,2) + ")");
               }
            } else {
               // Trailing OFF: Classic — close both regardless
               PrintFormat("Z~0 CLASSIC EXIT [%s-%s]: Z=%.2f TotalPnL=%.2f", m_symA, m_symB, zScore, totalPnL);
               m_legA.CloseAll("Z~0: Classic Spread Close");
               m_legB.CloseAll("Z~0: Classic Spread Close");
               m_entryFired = false;
               return;
            }
         }
      }
      
      // =======================================================
      // SCENARIO B: Only ONE leg active (orphaned after Z~0 close)
      // This leg must DCA+breakeven itself to close profitably
      // =======================================================
      if(oneLegOnly) {
         if(legAActive) m_legA.CheckExit();
         if(legBActive) m_legB.CheckExit();
      }
      
      // =======================================================
      // SCENARIO C: Both legs active — per-leg breakeven check
      // =======================================================
      if(bothLegsActive) {
         if(legAActive) m_legA.CheckExit();
         if(legBActive) m_legB.CheckExit();
      }
      
      // --- Emergency Z-Score SL ---
      if(InpZScoreSL > 0 && MathAbs(zScore) >= InpZScoreSL) {
         if(m_legA.IsActive() && m_legA.GetFloatingProfit() < 0) {
            m_legA.CloseAll("EMERGENCY: Z-Score Extreme");
         }
         if(m_legB.IsActive() && m_legB.GetFloatingProfit() < 0) {
            m_legB.CloseAll("EMERGENCY: Z-Score Extreme");
         }
      }
   }
};


CScanner          g_scanner;
CCointegration*   g_cointInstances[];
CPairManager*     g_pairInstances[];

datetime g_lastBarMs = 0;
int      g_lastScanDay = 0;
int      g_lastMonth = 0;

void CleanInstances() {
   int count = ArraySize(g_cointInstances);
   for(int i = 0; i < count; i++) {
      if(CheckPointer(g_cointInstances[i]) != POINTER_INVALID) delete g_cointInstances[i];
      if(CheckPointer(g_pairInstances[i]) != POINTER_INVALID) delete g_pairInstances[i];
   }
   ArrayResize(g_cointInstances, 0);
   ArrayResize(g_pairInstances, 0);
}

bool RebuildMatrix() {
   if(!g_scanner.Scan()) return false;
   
   CleanInstances();
   
   int count = g_scanner.GetCount();
   if(count == 0) return false;
   
   ArrayResize(g_cointInstances, count);
   ArrayResize(g_pairInstances, count);
   
   for(int i = 0; i < count; i++) {
      string candSym = g_scanner.GetCandidateSymbol(i);
      
      SymbolSelect(candSym, true);
      
      g_cointInstances[i] = new CCointegration();
      g_cointInstances[i].Init(InpBaseSymbol, candSym);
      
      g_pairInstances[i] = new CPairManager();
      g_pairInstances[i].Init(InpBaseSymbol, candSym);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Cross-Matrix Recovery (Toggle [2])                               |
//| Use profit from winning pairs to rescue losing pairs             |
//+------------------------------------------------------------------+
void CheckRecovery() {
   int count = ArraySize(g_pairInstances);
   if(count < 2) return;
   
   double totalFloating = 0;
   int worstIdx = -1;
   double worstProfit = 0;
   
   for(int i = 0; i < count; i++) {
      if(CheckPointer(g_pairInstances[i]) == POINTER_INVALID) continue;
      if(!g_pairInstances[i].HasAnyActive()) continue;
      
      double pnl = g_pairInstances[i].GetTotalFloating();
      totalFloating += pnl;
      
      if(pnl < worstProfit) {
         worstProfit = pnl;
         worstIdx = i;
      }
   }
   
   if(worstIdx >= 0 && totalFloating > 0 && worstProfit < 0) {
      if(totalFloating >= MathAbs(worstProfit) + 0.50) {
         PrintFormat("Recovery: Total Float=%.2f | Worst idx=%d Loss=%.2f -> CLOSING", totalFloating, worstIdx, worstProfit);
         g_pairInstances[worstIdx].CloseAll("Recovery: Cross-Matrix Rescue (Net Positive)");
      }
   }
}

int OnInit() {
   Print("=== PAIRS TRADING v3: INDEPENDENT LEG MANAGEMENT ===");
   
   SymbolSelect(InpBaseSymbol, true);
   
   // Inject scan universe into Market Watch
   string pairs[];
   StringSplit(InpScanUniverse, ',', pairs);
   
   string suffix = "";
   if(StringLen(InpBaseSymbol) > 6) {
      suffix = StringSubstr(InpBaseSymbol, 6);
   }

   for(int i = 0; i < ArraySize(pairs); i++) {
      string sym = pairs[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(StringLen(sym) > 0) {
         if(StringLen(suffix) > 0 && StringFind(sym, suffix) == -1) {
            sym = sym + suffix;
         }
         SymbolSelect(sym, true);
      }
   }
   
   // Initial Matrix Build
   RebuildMatrix();
   
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   g_lastScanDay = dt.day;
   g_lastMonth = 0; // Will be set on first bar tick to avoid init/bar month mismatch
   
   PrintFormat("Init: Base=[%s] TF=%s ScanTF=%s DCA=%d pts BreakEven=$%.2f MaxGrid=%d Mult=%.2f", 
               InpBaseSymbol, EnumToString(InpTimeframe), EnumToString(InpScanTimeframe),
               InpDCAStepPoints, InpBreakevenUSD, InpDCAMaxLevels, InpDCALotMultiplier);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   CleanInstances();
   Print("EA Stopped and Memory Cleaned.");
}

void OnTick() {
   datetime currentBarTs = iTime(InpBaseSymbol, InpTimeframe, 0);
   if(currentBarTs != g_lastBarMs) {
      g_lastBarMs = currentBarTs;
      
      MqlDateTime dt; TimeToStruct(currentBarTs, dt);
      
      // 0. End of Month
      if(InpCloseEOM && g_lastMonth != 0 && dt.mon != g_lastMonth) {
         Print("*** END OF MONTH: Đóng toàn bộ ***");
         int countEOM = ArraySize(g_pairInstances);
         for(int i = 0; i < countEOM; i++) {
            if(CheckPointer(g_pairInstances[i]) != POINTER_INVALID) {
               g_pairInstances[i].CloseAll("End Of Month");
            }
         }
      }
      // Always update month tracking (including first bar)
      if(g_lastMonth != dt.mon) g_lastMonth = dt.mon;
      
      // 1. Daily rescan
      if(dt.day != g_lastScanDay) {
         Print("New day. Rebuilding Matrix...");
         RebuildMatrix();
         g_lastScanDay = dt.day;
      }
      
      // 2. Manage all pairs
      int count = ArraySize(g_cointInstances);
      for(int i = 0; i < count; i++) {
         if(CheckPointer(g_cointInstances[i]) != POINTER_INVALID && 
            CheckPointer(g_pairInstances[i]) != POINTER_INVALID) {
            
            if(g_cointInstances[i].Update()) {
               g_pairInstances[i].Manage(g_cointInstances[i]);
            }
         }
      }
      
      // 3. Cross-Matrix Recovery (Toggle [2])
      if(InpUseCrossRecovery) CheckRecovery();
   }
}
