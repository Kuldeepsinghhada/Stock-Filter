import 'dart:math';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/indicator_status.dart';
import 'candle_utils.dart';
import 'math_utils.dart';

/// Main utilities (refactored). Methods are defensive and parameterized.
class IndicatorUtils {
  /// ---------- EMA / SMA ----------
  static IndicatorStatus isCloseAboveEMA(
    List<HistoricalDataModel> candles,
    int period,
  ) {
    if (candles.length < period) {
      return IndicatorStatus(status: false, data: null);
    }
    CandleUtils.sortByTime(candles);
    final closes = CandleUtils.toArrays(candles)['close']!.cast<double>();
    final ema = MathUtils.emaAligned(closes, period);
    final lastEma = ema.isNotEmpty ? ema.last : null;
    if (lastEma == null) return IndicatorStatus(status: false, data: lastEma);
    return IndicatorStatus(status: closes.last > lastEma, data: lastEma);
  }

  /// ---------- RSI (Wilder's) ----------
  static bool isRsiBetween(
    List<HistoricalDataModel> candles,
    int period, {
    required double min,
    required double max,
  }) {
    final closes = CandleUtils.toArrays(candles)['close']!.cast<double>();
    if (closes.length < period + 1) return false;

    final deltas = <double>[];
    for (int i = 1; i < closes.length; i++) {
      deltas.add(closes[i] - closes[i - 1]);
    }

    double avgGain = 0.0, avgLoss = 0.0;
    for (int i = 0; i < period; i++) {
      final d = deltas[i];
      if (d > 0) {
        avgGain += d;
      } else {
        avgLoss += -d;
      }
    }
    avgGain /= period;
    avgLoss /= period;

    for (int i = period; i < deltas.length; i++) {
      final d = deltas[i];
      final gain = d > 0 ? d : 0.0;
      final loss = d < 0 ? -d : 0.0;
      avgGain = ((avgGain * (period - 1)) + gain) / period;
      avgLoss = ((avgLoss * (period - 1)) + loss) / period;
    }

    final rs = (avgLoss == 0) ? double.infinity : (avgGain / avgLoss);
    final rsi = 100 - (100 / (1 + rs));
    return rsi >= min && rsi <= max;
  }

  static bool isTrendBullish(List<HistoricalDataModel> candles) {
    if (candles.length < 50) return false;

    final last = candles.last;

    final ema20 = isCloseAboveEMA(candles, 20);
    final ema50 = isCloseAboveEMA(candles, 50);
    final vwapOk = isCloseAboveVWAP(candles);
    final superOk = isCloseAboveSupertrend(candles);
    final rsi = isRsiBetween(candles, 14, min: 50, max: 85);

    if (ema20.data == null || ema50.data == null) return false;
    return last.close > ema20.data &&
        ema20.data > ema50.data &&
        vwapOk &&
        superOk &&
        rsi;
  }

  static bool isDailyBullishAdvanced(
      List<HistoricalDataModel> candles, {
        double minBodyPct = 0.003, // 0.3%
        double minVolumeFactor = 0.5, // 50% of avg
      }) {
    if (candles.length < 20) return false;

    final last = candles.last;

    final open = last.open;
    final close = last.close;
    final volume = last.volume;

    // must be bullish
    if (close <= open) return false;

    final body = (close - open).abs();
    final bodyPct = body / open;

    if (bodyPct < minBodyPct) return false;

    // Compare with last 20 days average volume
    final avgVolume = candles
        .take(candles.length - 1)
        .take(20)
        .map((c) => c.volume ?? 0)
        .fold(0.0, (a, b) => a + b) /
        20;

    if (volume < avgVolume * minVolumeFactor) return false;

    return true;
  }

  /// ---------- ATR ----------
  /// returns ATR for last candle or null if not enough data
  static double? atrLast(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    required int period,
  }) {
    final n = closes.length;
    if (n < period + 1 || highs.length != n || lows.length != n) return null;

    List<double> tr = [];
    for (int i = 1; i < n; i++) {
      final hL = highs[i] - lows[i];
      final hC = (highs[i] - closes[i - 1]).abs();
      final lC = (lows[i] - closes[i - 1]).abs();
      tr.add(max(hL, max(hC, lC)));
    }

    // Wilder smoothing: initial ATR = average of first 'period' TRs (use tr[0..period-1])
    if (tr.length < period) return null;
    double atr = 0.0;
    for (int i = 0; i < period; i++) {
      atr += tr[i];
    }
    atr /= period;
    for (int i = period; i < tr.length; i++) {
      atr = ((atr * (period - 1)) + tr[i]) / period;
    }
    return atr;
  }

  /// Check if current price is trading above Pivot R1
  static bool isPriceAboveR1(List<HistoricalDataModel> candles) {
    if (candles.length < 100) return false; // approx 2 days 5m candles

    CandleUtils.sortByTime(candles);

    // Group candles by date
    final grouped = CandleUtils.groupByDate(candles);
    final dates = grouped.keys.toList()..sort();

    if (dates.length < 2) return false;

    // Yesterday = second last trading day
    final yesterday = dates[dates.length - 2];
    final yCandles = grouped[yesterday];

    if (yCandles == null || yCandles.isEmpty) return false;

    final yHigh = yCandles.map((c) => c.high).reduce(max).toDouble();
    final yLow = yCandles.map((c) => c.low).reduce(min).toDouble();
    final yClose = yCandles.last.close.toDouble();

    // Classic Pivot formula
    final pivot = (yHigh + yLow + yClose) / 3;
    final r1 = (2 * pivot) - yLow;

    // Latest candle
    final lastClose = candles.last.close.toDouble();

    return lastClose > r1;
  }

  /// Adaptive ATR threshold check
  static bool isAtrHealthy(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 14,
    double minAtrPct = 0.003, // 0.3%
    double maxAtrPct = 0.08, // 8%
  }) {
    if (candles.length < atrPeriod + 5) return false;

    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final atrList = atrSeries(highs, lows, closes, period: atrPeriod);
    if (atrList.isEmpty) return false;

    final atr = atrList.last;
    final lastClose = closes.last;

    // ATR as percentage
    final atrPct = atr / lastClose;

    // ATR must be in reasonable bounds
    if (atrPct < minAtrPct || atrPct > maxAtrPct) return false;

    return true;
  }

  static bool isAtrHealthy5Min(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 7,
    double minAtrPct = 0.0005, // 0.05%
    double maxAtrPct = 0.01, // 1%
  }) {
    if (candles.length < atrPeriod + 5) return false;

    CandleUtils.sortByTime(candles);

    final arr = CandleUtils.toArrays(candles);
    final highs = arr['high']!.cast<double>();
    final lows = arr['low']!.cast<double>();
    final closes = arr['close']!.cast<double>();

    final atrList = atrSeries(highs, lows, closes, period: atrPeriod);
    if (atrList.isEmpty) return false;

    final atr = atrList.last;
    final lastClose = closes.last;

    final atrPct = atr / lastClose;

    return atrPct >= minAtrPct && atrPct <= maxAtrPct;
  }

  static bool isAtrHealthyInvestment(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 14,
    double minAtrPct = 0.003, // 0.3%
    double maxAtrPct = 0.025, // 2.5%
  }) {
    if (candles.length < atrPeriod + 5) return false;

    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final atrList = atrSeries(highs, lows, closes, period: atrPeriod);
    if (atrList.isEmpty) return false;

    final atr = atrList.last;
    final lastClose = closes.last;

    final atrPct = atr / lastClose;

    if (atrPct < minAtrPct || atrPct > maxAtrPct) return false;

    return true;
  }

  /// 🔥 Checks if the last daily candle is strongly bullish
  static bool isDailyCandleBullish(List<HistoricalDataModel> candles) {
    if (candles.length < 2) return false;

    final c = candles.last;

    final double open = c.open.toDouble();
    final double close = c.close.toDouble();
    final double high = c.high.toDouble();
    final double low = c.low.toDouble();

    // 1️⃣ Must be bullish candle
    if (close <= open) return false;

    final double body = (close - open).abs();
    final double range = (high - low).abs();

    // Avoid division by zero
    if (range == 0) return false;

    // 2️⃣ Body % must be at least 40% of total candle
    if (body / range < 0.40) return false;

    // 3️⃣ Candle must not be doji / extremely small body
    double bodyPct = body / open;
    if (bodyPct < 0.002) return false; // less than 0.2%

    // 4️⃣ Close should be near the high (strong closing)
    bool closeNearHigh = close >= high - (range * 0.25);

    if (!closeNearHigh) return false;

    return true;
  }

  /// ---------- VWAP ----------
  /// If sessionBased = true, calculates VWAP for the session of the last candle only.
  static bool isCloseAboveVWAP(
    List<HistoricalDataModel> candles, {
    bool sessionBased = true,
  }) {
    if (candles.isEmpty) return false;
    CandleUtils.sortByTime(candles);

    if (!sessionBased) {
      // simple whole-list VWAP
      double tpVol = 0.0, volSum = 0.0;
      for (var c in candles) {
        final tp = (c.high + c.low + c.close) / 3.0;
        tpVol += tp * c.volume;
        volSum += c.volume;
      }
      if (volSum == 0) return false;
      final vwap = tpVol / volSum;
      return candles.last.close >= vwap;
    } else {
      // session-based: find last trading day's candles and compute VWAP for them
      final grouped = CandleUtils.groupByDate(candles);
      final dates = grouped.keys.toList()..sort();
      final lastDate = dates.last;
      final sessionCandles = grouped[lastDate]!;
      double tpVol = 0.0, volSum = 0.0;
      for (var c in sessionCandles) {
        final tp = (c.high + c.low + c.close) / 3.0;
        tpVol += tp * c.volume;
        volSum += c.volume;
      }
      if (volSum == 0) return false;
      final vwap = tpVol / volSum;
      return sessionCandles.last.close >= vwap;
    }
  }

  /// ---------- ADX (14,14) ----------
  static bool isAdxBullish(
    List<HistoricalDataModel> candles, {
    int diPeriod = 10,
    int adxSmoothing = 8,
    double minAdx = 18.0,
  }) {
    if (candles.length < diPeriod + adxSmoothing + 2) return false;

    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();
    final n = highs.length;

    final tr = <double>[];
    final plusDM = <double>[];
    final minusDM = <double>[];

    // Step 1️⃣ Calculate TR, +DM, -DM
    for (int i = 1; i < n; i++) {
      final upMove = highs[i] - highs[i - 1];
      final downMove = lows[i - 1] - lows[i];
      tr.add(
        max(
          highs[i] - lows[i],
          max(
            (highs[i] - closes[i - 1]).abs(),
            (lows[i] - closes[i - 1]).abs(),
          ),
        ),
      );
      plusDM.add((upMove > downMove && upMove > 0) ? upMove : 0.0);
      minusDM.add((downMove > upMove && downMove > 0) ? downMove : 0.0);
    }

    if (tr.length < diPeriod + adxSmoothing) return false;

    // Step 2️⃣ Wilder’s smoothing initialization
    double atr = tr.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;
    double pdm = plusDM.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;
    double mdm =
        minusDM.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;

    final dxList = <double>[];

    // Step 3️⃣ Compute DX values
    for (int i = diPeriod; i < tr.length; i++) {
      atr = ((atr * (diPeriod - 1)) + tr[i]) / diPeriod;
      pdm = ((pdm * (diPeriod - 1)) + plusDM[i]) / diPeriod;
      mdm = ((mdm * (diPeriod - 1)) + minusDM[i]) / diPeriod;

      final plusDI = 100 * (pdm / (atr + 1e-9));
      final minusDI = 100 * (mdm / (atr + 1e-9));
      final dx = 100 * ((plusDI - minusDI).abs() / ((plusDI + minusDI) + 1e-9));
      dxList.add(dx);
    }

    if (dxList.length < adxSmoothing + 1) return false;

    // Step 4️⃣ ADX smoothing
    double adx =
        dxList.sublist(0, adxSmoothing).reduce((a, b) => a + b) / adxSmoothing;
    final adxSeries = <double>[adx];

    for (int i = adxSmoothing; i < dxList.length; i++) {
      adx = ((adx * (adxSmoothing - 1)) + dxList[i]) / adxSmoothing;
      adxSeries.add(adx);
    }

    final adxLast = adxSeries.last;
    final adxPrev = adxSeries[adxSeries.length - 2];

    // Step 5️⃣ Compute final +DI and -DI again
    atr = tr.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;
    pdm = plusDM.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;
    mdm = minusDM.sublist(0, diPeriod).reduce((a, b) => a + b) / diPeriod;

    for (int i = diPeriod; i < tr.length; i++) {
      atr = ((atr * (diPeriod - 1)) + tr[i]) / diPeriod;
      pdm = ((pdm * (diPeriod - 1)) + plusDM[i]) / diPeriod;
      mdm = ((mdm * (diPeriod - 1)) + minusDM[i]) / diPeriod;
    }

    final plusDIFinal = 100 * (pdm / (atr + 1e-9));
    final minusDIFinal = 100 * (mdm / (atr + 1e-9));

    final bullish = adxLast > minAdx && plusDIFinal > minusDIFinal;
    final adxRising = adxLast > adxPrev;

    final result = bullish && adxRising;

    return result;
  }

  // is Strong Candle
  static bool isStrongCandle(HistoricalDataModel c) {
    final body = (c.close - c.open).abs();
    final range = (c.high - c.low).abs();
    return range != 0 && (body / range) > 0.6;
  }

  /// ---------- Supertrend ----------
  /// Returns true if last close >= supertrend (bullish)
  static bool isCloseAboveSupertrend(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 9,
    double multiplier = 3.0,
  }) {
    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final n = closes.length;
    if (n < atrPeriod + 1) return false;

    // ---- TR ----
    final tr = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      if (i == 0) {
        tr[i] = highs[i] - lows[i];
      } else {
        tr[i] = max(
          highs[i] - lows[i],
          max(
            (highs[i] - closes[i - 1]).abs(),
            (lows[i] - closes[i - 1]).abs(),
          ),
        );
      }
    }

    // ---- ATR Wilder ----
    final atr = List<double>.filled(n, 0.0);
    double initialAtr = 0.0;
    for (int i = 0; i < atrPeriod; i++) {
      initialAtr += tr[i];
    }
    initialAtr /= atrPeriod;
    atr[atrPeriod - 1] = initialAtr;

    for (int i = atrPeriod; i < n; i++) {
      atr[i] = ((atr[i - 1] * (atrPeriod - 1)) + tr[i]) / atrPeriod;
    }

    final upperBand = List<double>.filled(n, 0.0);
    final lowerBand = List<double>.filled(n, 0.0);
    final supertrend = List<double>.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      final hl2 = (highs[i] + lows[i]) / 2;

      upperBand[i] = hl2 + multiplier * atr[i];
      lowerBand[i] = hl2 - multiplier * atr[i];

      if (i == 0) {
        // FIX: Base trend from close position
        supertrend[i] = closes[i] >= hl2 ? lowerBand[i] : upperBand[i];
        continue;
      }

      // Carry-forward upper
      if (!(upperBand[i] < upperBand[i - 1] ||
          closes[i - 1] > upperBand[i - 1])) {
        upperBand[i] = upperBand[i - 1];
      }

      // Carry-forward lower
      if (!(lowerBand[i] > lowerBand[i - 1] ||
          closes[i - 1] < lowerBand[i - 1])) {
        lowerBand[i] = lowerBand[i - 1];
      }

      // Trend logic
      if (supertrend[i - 1] == upperBand[i - 1]) {
        supertrend[i] = closes[i] <= upperBand[i] ? upperBand[i] : lowerBand[i];
      } else {
        supertrend[i] = closes[i] >= lowerBand[i] ? lowerBand[i] : upperBand[i];
      }
    }

    return closes.last >= supertrend.last;
  }

  /// ---------- Volume Breakout ----------
  /// checks latest volume > EMA(volume, period) * factor
  static bool isVolumeBreakout(
    List<HistoricalDataModel> candles, {
    int emaPeriod = 20,
    double factor = 1.5,
  }) {
    if (candles.length < emaPeriod) return false;
    CandleUtils.sortByTime(candles);
    final volumes =
        CandleUtils.toArrays(
          candles,
        )['volume']!.map((e) => e.toDouble()).toList();
    final emaVol = MathUtils.emaAligned(volumes, emaPeriod);
    final latestVol = volumes.last;
    final latestEma = emaVol.last;
    if (latestEma == null) return false;
    return latestVol > latestEma * factor;
  }

  static bool isVolumeBreakoutOnDay(
    List<HistoricalDataModel> candles, {
    int emaPeriod = 20,
    double factor = 1.5,
  }) {
    if (candles.length < emaPeriod + 5) return false;

    CandleUtils.sortByTime(candles);

    final arr = CandleUtils.toArrays(candles);
    final volumes = arr['volume']!.map((e) => e.toDouble()).toList();

    final emaVol = MathUtils.emaAligned(volumes, emaPeriod);

    // Ignore unstable EMA
    final latestEma = emaVol.last;

    if (latestEma! <= 0) return false;

    final latestVol = volumes.last;

    // Final condition
    return latestVol > (latestEma * factor);
  }

  /// ---------- Day-specific checks ----------
  /// true if today's close > highest high of previous N trading days (skips weekends)
  static bool isCloseAboveLastNDaysHigh(
    List<HistoricalDataModel> candles, {
    int lastDays = 5,
  }) {
    CandleUtils.sortByTime(candles);
    final grouped = CandleUtils.groupByDate(candles);
    final dates = grouped.keys.toList()..sort();
    if (dates.length < lastDays + 1) return false; // need today + lastDays

    final lastDate = dates.last;
    final todayCandles = grouped[lastDate]!;
    final todayClose = todayCandles.last.close;

    final prevDates = <DateTime>[];
    for (int i = dates.length - 2; i >= 0 && prevDates.length < lastDays; i--) {
      final d = dates[i];
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
        continue;
      prevDates.add(d);
    }
    if (prevDates.length < lastDays) return false;

    double highest = double.negativeInfinity;
    for (var d in prevDates) {
      final hh = grouped[d]!.map((c) => c.high).reduce(max);
      if (hh > highest) highest = hh;
    }
    return todayClose > highest;
  }

  /// today close >= yesterday high * (1 + pct)
  static bool isCloseAboveYesterdayHighByPct(
    List<HistoricalDataModel> candles, {
    double pct = 0.02,
  }) {
    CandleUtils.sortByTime(candles);
    final grouped = CandleUtils.groupByDate(candles);
    final dates = grouped.keys.toList()..sort();
    if (dates.length < 2) return false;
    final lastDate = dates.last;
    final todayClose = grouped[lastDate]!.last.close;

    // find last working day before today
    DateTime? yesterday;
    for (int i = dates.length - 2; i >= 0; i--) {
      final d = dates[i];
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
        continue;
      yesterday = d;
      break;
    }
    if (yesterday == null) return false;
    final yHigh = grouped[yesterday]!.map((c) => c.high).reduce(max);
    return todayClose >= yHigh * (1.0 + pct);
  }

  /// today close >= yesterday close * (1 + pct) AND yesterday was bullish (open < close)
  static bool isCloseAboveYesterdayCloseByPctAndYesterdayBullish(
    List<HistoricalDataModel> candles, {
    double pct = 0.01,
  }) {
    CandleUtils.sortByTime(candles);
    final grouped = CandleUtils.groupByDate(candles);
    final dates = grouped.keys.toList()..sort();
    if (dates.length < 2) return false;
    final lastDate = dates.last;
    final todayClose = grouped[lastDate]!.last.close;

    DateTime? yesterday;
    for (int i = dates.length - 2; i >= 0; i--) {
      final d = dates[i];
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
        continue;
      yesterday = d;
      break;
    }
    if (yesterday == null) return false;
    final yCandles = grouped[yesterday]!;
    final yOpen = yCandles.first.open;
    final yClose = yCandles.last.close;
    return todayClose >= yClose * (1.0 + pct) && (yOpen < yClose);
  }

  /// Returns ATR series aligned with input length.
  /// - The returned list has length == closes.length.
  /// - Entries before index (period-1) are 0.0.
  /// - atr[period-1] = initial ATR (simple average of first `period` TRs).
  /// - Subsequent atr[i] use Wilder smoothing.
  static List<double> atrSeries(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    int period = 14,
  }) {
    final n = closes.length;
    if (n < 2 || highs.length != n || lows.length != n) return [];

    // Build TR list (length n) matching Supertrend earlier: tr[0] = high0-low0
    final tr = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      if (i == 0) {
        tr[i] = highs[i] - lows[i];
      } else {
        tr[i] = max(
          highs[i] - lows[i],
          max(
            (highs[i] - closes[i - 1]).abs(),
            (lows[i] - closes[i - 1]).abs(),
          ),
        );
      }
    }

    if (n < period) return []; // not enough data to compute ATR series

    final atr = List<double>.filled(n, 0.0);

    // initial ATR at index period-1 = average of tr[0..period-1]
    double initialAtr = 0.0;
    for (int i = 0; i < period; i++) {
      initialAtr += tr[i];
    }
    initialAtr /= period;
    atr[period - 1] = initialAtr;

    // Wilder smoothing for subsequent ATR values
    for (int i = period; i < n; i++) {
      atr[i] = ((atr[i - 1] * (period - 1)) + tr[i]) / period;
    }

    return atr;
  }

  static bool isCloseWithinSupertrendRange(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 9,
    double multiplier = 3.0,
    double pct = 0.05, // +5% range
  }) {
    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final n = closes.length;
    if (n < atrPeriod + 1) return false;

    // ===== TR =====
    final tr = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      if (i == 0) {
        tr[i] = highs[i] - lows[i];
      } else {
        tr[i] = max(
          highs[i] - lows[i],
          max(
            (highs[i] - closes[i - 1]).abs(),
            (lows[i] - closes[i - 1]).abs(),
          ),
        );
      }
    }

    // ===== ATR (Wilder) =====
    final atr = List<double>.filled(n, 0.0);
    double initialAtr = 0.0;
    for (int i = 0; i < atrPeriod; i++) {
      initialAtr += tr[i];
    }
    initialAtr /= atrPeriod;
    atr[atrPeriod - 1] = initialAtr;

    for (int i = atrPeriod; i < n; i++) {
      atr[i] = ((atr[i - 1] * (atrPeriod - 1)) + tr[i]) / atrPeriod;
    }

    // ===== SuperTrend =====
    final upperBand = List<double>.filled(n, 0.0);
    final lowerBand = List<double>.filled(n, 0.0);
    final supertrend = List<double>.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      final hl2 = (highs[i] + lows[i]) / 2;
      upperBand[i] = hl2 + multiplier * atr[i];
      lowerBand[i] = hl2 - multiplier * atr[i];

      if (i == 0) {
        supertrend[i] = upperBand[i];
      } else {
        if (!(upperBand[i] < upperBand[i - 1] ||
            closes[i - 1] > upperBand[i - 1])) {
          upperBand[i] = upperBand[i - 1];
        }

        if (!(lowerBand[i] > lowerBand[i - 1] ||
            closes[i - 1] < lowerBand[i - 1])) {
          lowerBand[i] = lowerBand[i - 1];
        }

        if (supertrend[i - 1] == upperBand[i - 1]) {
          supertrend[i] =
              (closes[i] <= upperBand[i]) ? upperBand[i] : lowerBand[i];
        } else {
          supertrend[i] =
              (closes[i] >= lowerBand[i]) ? lowerBand[i] : upperBand[i];
        }
      }
    }

    // ===== Check range ABOVE SuperTrend only =====
    final lastClose = closes.last;
    final lastST = supertrend.last;

    final upperLimit = lastST * (1 + pct); // ST + 3%

    return lastClose >= lastST && lows.last <= upperLimit;
  }

  static bool isCloseNearEMA(
    List<HistoricalDataModel> candles, {
    int period = 20,
    double tolerancePct = 0.01, // 1%
  }) {
    if (candles.length < period) return false;

    // Sort candles
    CandleUtils.sortByTime(candles);

    // Extract closes
    final closes = CandleUtils.toArrays(candles)['close']!.cast<double>();

    // Calculate EMA
    final emaList = MathUtils.emaAligned(closes, period);
    if (emaList.isEmpty) return false;

    final lastClose = closes.last;
    final lastEma = emaList.last;

    // ±1% range
    final lower = lastEma! * (1 - tolerancePct);
    final upper = lastEma * (1 + tolerancePct);

    return lastClose >= lower && lastClose <= upper;
  }

  static bool isEma50Above200(List<HistoricalDataModel> candles) {
    const int period50 = 50;
    const int period200 = 200;

    // Need at least 200 candles for EMA200
    if (candles.length < period200) return false;

    CandleUtils.sortByTime(candles);

    final closes = CandleUtils.toArrays(candles)['close']!.cast<double>();

    // --- EMA 50 ---
    final ema50List = MathUtils.emaAligned(closes, period50);
    final ema50 = ema50List.isNotEmpty ? ema50List.last : null;
    if (ema50 == null) return false;

    // --- EMA 200 ---
    final ema200List = MathUtils.emaAligned(closes, period200);
    final ema200 = ema200List.isNotEmpty ? ema200List.last : null;
    if (ema200 == null) return false;

    // Final condition
    return ema50 > ema200;
  }
}
