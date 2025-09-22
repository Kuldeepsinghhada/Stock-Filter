import 'package:stock_demo/model/historical_data_model.dart';

class IndicatorUtils {
// ---------- EMA ----------
  static bool isAboveEMA(List<double> prices, int period) {
    if (prices.length < period) return false;

    double multiplier = 2 / (period + 1);

    // Initial EMA = SMA of first 'period' prices
    double ema = prices.sublist(0, period).reduce((a, b) => a + b) / period;

    // Continue EMA calculation for the rest of the prices
    for (int i = period; i < prices.length; i++) {
      ema = ((prices[i] - ema) * multiplier) + ema;
    }

    return prices.last > ema;
  }

// ---------- SMA ----------
  static bool isAboveSMA(List<double> prices, int period) {
    if (prices.length < period) return false;

    // Simple Moving Average = average of last 'period' prices
    double sma = prices.sublist(prices.length - period).reduce((a, b) => a + b) / period;

    return prices.last > sma;
  }

  static bool isRsiBetween(
      List<double> prices,
      int period,
      double min,
      double max,
      ) {
    if (prices.length < period + 1) return false;

    // --- Step 1: price changes
    List<double> deltas = [];
    for (int i = 1; i < prices.length; i++) {
      deltas.add(prices[i] - prices[i - 1]);
    }

    // --- Step 2: initial average gain/loss over first `period`
    double avgGain = 0.0;
    double avgLoss = 0.0;
    for (int i = 0; i < period; i++) {
      double delta = deltas[i];
      if (delta > 0) {
        avgGain += delta;
      } else {
        avgLoss += -delta;
      }
    }
    avgGain /= period;
    avgLoss /= period;

    // --- Step 3: Wilder’s smoothing for the rest of deltas
    for (int i = period; i < deltas.length; i++) {
      double delta = deltas[i];
      double gain = delta > 0 ? delta : 0;
      double loss = delta < 0 ? -delta : 0;

      avgGain = ((avgGain * (period - 1)) + gain) / period;
      avgLoss = ((avgLoss * (period - 1)) + loss) / period;
    }

    // --- Step 4: RSI
    double rs = avgLoss == 0 ? double.infinity : avgGain / avgLoss;
    double rsi = 100 - (100 / (1 + rs));

    // --- Step 5: check
    return rsi >= min && rsi <= max;
  }

  static double calculateATR(
      List<double> high,
      List<double> low,
      List<double> close,
      int period,
      ) {
    if (close.length < period + 1) return 0.0;

    final start = close.length - (period + 1);
    final lastHigh = high.sublist(start);
    final lastLow = low.sublist(start);
    final lastClose = close.sublist(start);

    List<double> tr = [];
    for (int i = 1; i < lastClose.length; i++) {
      double hL = lastHigh[i] - lastLow[i];
      double hC = (lastHigh[i] - lastClose[i - 1]).abs();
      double lC = (lastLow[i] - lastClose[i - 1]).abs();
      tr.add([hL, hC, lC].reduce((a, b) => a > b ? a : b));
    }

    return tr.reduce((a, b) => a + b) / period;
  }

  static bool isAtrGreaterThan(
      List<double> high,
      List<double> low,
      List<double> close,
      int period,
      double value,
      ) {
    return calculateATR(high, low, close, period) > value;
  }

// ---------- VWAP (Session-based like TradingView/Fyers) ----------
  static bool isCloseAboveVWAP(
      List<double> high,
      List<double> low,
      List<double> close,
      List<int> volume,
      ) {
    if (close.isEmpty || volume.isEmpty) return false;

    double tpVolSum = 0, volSum = 0;

    // Use ALL candles of the session (not just last N)
    for (int i = 0; i < close.length; i++) {
      double tp = (high[i] + low[i] + close[i]) / 3; // Typical price
      tpVolSum += tp * volume[i];
      volSum += volume[i];
    }

    double vwap = tpVolSum / volSum;

    return close.last >= vwap;
  }

  // ---------- ADX ----------
  static Map<String, bool> adxConditions(
      List<double> high,
      List<double> low,
      List<double> close,
      int period,
      double minAdx,
      ) {
    if (close.length < period + 1) {
      return {"adxOk": false, "plusGreater": false};
    }

    List<double> plusDM = [];
    List<double> minusDM = [];
    List<double> tr = [];

    // --- Step 1: Calculate DM and TR for whole history ---
    for (int i = 1; i < close.length; i++) {
      double upMove = high[i] - high[i - 1];
      double downMove = low[i - 1] - low[i];

      plusDM.add((upMove > downMove && upMove > 0) ? upMove : 0);
      minusDM.add((downMove > upMove && downMove > 0) ? downMove : 0);

      double trVal = [
        high[i] - low[i],
        (high[i] - close[i - 1]).abs(),
        (low[i] - close[i - 1]).abs(),
      ].reduce((a, b) => a > b ? a : b);

      tr.add(trVal);
    }

    // --- Step 2: Wilder’s smoothing for TR, +DM, -DM ---
    double atr = tr.take(period).reduce((a, b) => a + b) / period;
    double smoothPlusDM = plusDM.take(period).reduce((a, b) => a + b) / period;
    double smoothMinusDM = minusDM.take(period).reduce((a, b) => a + b) / period;

    for (int i = period; i < tr.length; i++) {
      atr = ((atr * (period - 1)) + tr[i]) / period;
      smoothPlusDM = ((smoothPlusDM * (period - 1)) + plusDM[i]) / period;
      smoothMinusDM = ((smoothMinusDM * (period - 1)) + minusDM[i]) / period;
    }

    // --- Step 3: Calculate DI ---
    double plusDI = 100 * (smoothPlusDM / atr);
    double minusDI = 100 * (smoothMinusDM / atr);

    // --- Step 4: DX (last value) ---
    double dx = 100 * (plusDI - minusDI).abs() / (plusDI + minusDI);

    // --- Step 5: ADX (smoothing DX series) ---
    // To match TradingView/Fyers we should smooth DX too,
    // but since we only need last value condition, we use this.
    // For full ADX line, we’d maintain DX list and smooth it similarly.

    return {"adxOk": dx > minAdx, "plusGreater": plusDI > minusDI};
  }

  // ---------- Supertrend ----------
  static bool isCloseAboveSupertrend(
      List<double> high,
      List<double> low,
      List<double> close,
      int atrPeriod,
      double multiplier,
      ) {
    if (close.length < atrPeriod + 1) return false;

    int len = close.length;

    // --- Step 1: True Range ---
    List<double> tr = [];
    for (int i = 0; i < len; i++) {
      if (i == 0) {
        tr.add(high[i] - low[i]);
      } else {
        tr.add([
          high[i] - low[i],
          (high[i] - close[i - 1]).abs(),
          (low[i] - close[i - 1]).abs(),
        ].reduce((a, b) => a > b ? a : b));
      }
    }

    // --- Step 2: Wilder’s ATR ---
    List<double> atr = List.filled(len, 0.0);
    atr[atrPeriod - 1] = tr.take(atrPeriod).reduce((a, b) => a + b) / atrPeriod;

    for (int i = atrPeriod; i < len; i++) {
      atr[i] = ((atr[i - 1] * (atrPeriod - 1)) + tr[i]) / atrPeriod;
    }

    // --- Step 3: Bands + Supertrend line ---
    List<double> upperBand = List.filled(len, 0.0);
    List<double> lowerBand = List.filled(len, 0.0);
    List<double> supertrend = List.filled(len, 0.0);

    for (int i = 0; i < len; i++) {
      double hl2 = (high[i] + low[i]) / 2;
      upperBand[i] = hl2 + (multiplier * atr[i]);
      lowerBand[i] = hl2 - (multiplier * atr[i]);

      if (i == 0) {
        supertrend[i] = upperBand[i]; // initialize
      } else {
        // Carry forward bands
        upperBand[i] = (upperBand[i] < upperBand[i - 1] || close[i - 1] > upperBand[i - 1])
            ? upperBand[i]
            : upperBand[i - 1];

        lowerBand[i] = (lowerBand[i] > lowerBand[i - 1] || close[i - 1] < lowerBand[i - 1])
            ? lowerBand[i]
            : lowerBand[i - 1];

        // Supertrend decision
        if (supertrend[i - 1] == upperBand[i - 1]) {
          supertrend[i] = (close[i] <= upperBand[i]) ? upperBand[i] : lowerBand[i];
        } else {
          supertrend[i] = (close[i] >= lowerBand[i]) ? lowerBand[i] : upperBand[i];
        }
      }
    }

    // --- Step 4: Final check ---
    return close.last >= supertrend.last;
  }

  /// Check if latest volume > EMA(volume,20) * 1.2
  static bool isVolumeBreakout(List<HistoricalDataModel> candles) {
    if (candles.length < 20) return false;

    // get volume list
    final volumes = candles.map((c) => c.volume).toList();

    // calculate EMA20 on volume
    final ema20 = ema(volumes, 20);

    // align because ema list is shorter
    final latestVolume = volumes.last;
    final latestEma = ema20.last;

    return latestVolume > latestEma * 1.3;
  }

  /// Calculate EMA on given values
  static List<double> ema(List<int> values, int period) {
    if (values.isEmpty) return [];

    final emaValues = <double>[];
    final k = 2 / (period + 1);

    // start with SMA for first EMA
    double sma = values.take(period).reduce((a, b) => a + b) / period;
    emaValues.add(sma);

    for (int i = period; i < values.length; i++) {
      double prevEma = emaValues.last;
      double nextEma = values[i] * k + prevEma * (1 - k);
      emaValues.add(nextEma);
    }
    return emaValues;
  }

}