import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/indicator_result.dart';
import 'candle_utils.dart';
import 'math_utils.dart';

/// Main utilities (refactored). Methods are defensive and parameterized.
class IndicatorUtils {
  /// ---------- EMA / SMA ----------
  static IndicatorResult isCloseAboveEMA(
    List<HistoricalDataModel> candles,
    int period,
  ) {
    if (candles.length < period) {
      return IndicatorResult(isPassed: false, value: null);
    }
    CandleUtils.sortByTime(candles);
    final closes = CandleUtils.toArrays(candles)['close']!.cast<double>();
    final ema = MathUtils.emaAligned(closes, period);
    final lastEma = ema.isNotEmpty ? ema.last : null;
    if (lastEma == null) return IndicatorResult(isPassed: false, value: null);
    //print("EMA$period: $lastEma");
    return IndicatorResult(isPassed: closes.last > lastEma, value: lastEma);
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
    // print("RSI: $rsi");
    return rsi >= min && rsi <= max;
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

  /// Adaptive ATR threshold check
  /// ✅ Smart Adaptive ATR Check
  /// Combines price-based adaptive threshold + ATR rising trend detection.
  static bool isAtrGreaterThanAdaptive(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 7,
    double lowPriceMinPct = 0.004,
    double lowPriceMaxPct = 0.04,
    double highPriceMinPct = 0.004,
    double highPriceMaxPct = 0.03,
    double priceThreshold = 200.0,
  }) {
    if (candles.length < atrPeriod + 2) return false;
    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final atrList = atrSeries(highs, lows, closes, period: atrPeriod);
    if (atrList.isEmpty) return false;

    final atr = atrList.last;
    final prevAtr = atrList[atrList.length - 2];
    final lastClose = closes.last;

    // ATR as % of price
    final atrPct = atr / lastClose;

    // Adaptive range based on price bracket
    final minPct =
        lastClose < priceThreshold ? lowPriceMinPct : highPriceMinPct;
    final maxPct =
        lastClose < priceThreshold ? lowPriceMaxPct : highPriceMaxPct;

    // ✅ Condition: ATR within ideal range + rising
    final inRange = atrPct >= minPct && atrPct <= maxPct;
    final rising = atr > prevAtr;

    final result = inRange && rising;

    return result;
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
    double minAdx = 20.0,
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

  /// ---------- Supertrend ----------
  /// Returns true if last close >= supertrend (bullish)
  static IndicatorResult isCloseAboveSupertrend(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 10,
    double multiplier = 3.0,
  }) {
    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final n = closes.length;
    if (n < atrPeriod + 1) return IndicatorResult(isPassed: false, value: null);

    // TR
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

    // ATR (Wilder) aligned (fill zeros until index atrPeriod-1)
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
      upperBand[i] = hl2 + (multiplier * atr[i]);
      lowerBand[i] = hl2 - (multiplier * atr[i]);

      if (i == 0) {
        supertrend[i] = upperBand[i];
      } else {
        // carry forward
        if (upperBand[i] < upperBand[i - 1] ||
            closes[i - 1] > upperBand[i - 1]) {
          // keep current upperBand
        } else {
          upperBand[i] = upperBand[i - 1];
        }

        if (lowerBand[i] > lowerBand[i - 1] ||
            closes[i - 1] < lowerBand[i - 1]) {
          // keep current lowerBand
        } else {
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
    return IndicatorResult(
      isPassed: closes.last >= supertrend.last,
      value: supertrend.last,
    );
  }

  /// ---------- Supertrend Series for Charting ----------
  /// Returns List of supertrend values matching candle indices
  static List<double> supertrendSeries(
    List<HistoricalDataModel> candles, {
    int atrPeriod = 10,
    double multiplier = 3.0,
  }) {
    if (candles.isEmpty) return [];

    CandleUtils.sortByTime(candles);
    final arrs = CandleUtils.toArrays(candles);
    final highs = arrs['high']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final closes = arrs['close']!.cast<double>();

    final n = closes.length;
    if (n < atrPeriod + 1) return List<double>.filled(n, 0.0);

    // TR
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

    // ATR (Wilder) aligned
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
      upperBand[i] = hl2 + (multiplier * atr[i]);
      lowerBand[i] = hl2 - (multiplier * atr[i]);

      if (i == 0) {
        supertrend[i] = upperBand[i];
      } else {
        if (upperBand[i] < upperBand[i - 1] ||
            closes[i - 1] > upperBand[i - 1]) {
          // keep current upperBand
        } else {
          upperBand[i] = upperBand[i - 1];
        }

        if (lowerBand[i] > lowerBand[i - 1] ||
            closes[i - 1] < lowerBand[i - 1]) {
          // keep current lowerBand
        } else {
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
    return supertrend;
  }

  /// ---------- Volume Breakout ----------
  /// checks latest volume > EMA(volume, period) * factor
  static bool isVolumeBreakoutStrong(List<HistoricalDataModel> candles) {
    if (candles.length < 30) return false;

    if (candles.last.timestamp.hour == 01 &&
        candles.last.timestamp.minute == 05) {
      debugPrint("Checking Volume Breakout for ${candles.last.timestamp}");
    }

    CandleUtils.sortByTime(candles);
    final volumes = candles.map((e) => e.volume.toDouble()).toList();
    final last = volumes.last;

    // EMA20
    final emaVol = MathUtils.emaAligned(volumes, 20);
    final ema20 = emaVol.last;

    // Avg20
    final avg20 =
        volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20;

    // Avg5
    final avg5 =
        volumes.sublist(volumes.length - 5).reduce((a, b) => a + b) / 5;

    return last > ema20! * 1.5 && last > avg20 * 1.5 && last > avg5 * 1.5;
  }

  static bool isVolumeBreakoutStrongNew(List<HistoricalDataModel> candles) {
    if (candles.length < 30) return false;

    CandleUtils.sortByTime(candles);

    final volumes = candles.map((e) => e.volume.toDouble()).toList();
    final lastVol = volumes.last;

    // EMA 20 Volume
    final emaVol = MathUtils.emaAligned(volumes, 20);
    final ema20 = emaVol.last!;

    // AVG 20 Volume
    final avg20 =
        volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20;

    // AVG 5 Volume
    final avg5 =
        volumes.sublist(volumes.length - 5).reduce((a, b) => a + b) / 5;

    // Relative Volume
    final rvol = lastVol / avg20;

    // Price confirmation (avoid sell-volume candle)
    final lastCandle = candles.last;
    if (lastCandle.close < lastCandle.open) return false;

    return lastVol > ema20 * 1.5 && // Trend-based expansion
        lastVol > avg20 * 1.5 && // Real participation
        lastVol > avg5 * 1.2 && // Continuation allowed
        rvol > 1.5 &&
        rvol < 4; // Algo spike protection
  }

  static bool isVolumeBreakoutStrongMore(
    List<HistoricalDataModel> candles, {
    double emaMultiplier = 1.4,
    double avgYesMultiplier = 1.4,
    double avgAllMultiplier = 1.2,
    double avg5Multiplier = 1.5,
    double prevMultiplier = 1.1, // previous candle check
  }) {
    if (candles.length < 30) return false;

    CandleUtils.sortByTime(candles);
    final volumes = candles.map((e) => e.volume.toDouble()).toList();
    final last = volumes.last;
    final prevVol = volumes[volumes.length - 2]; // previous candle

    final now = DateTime.now();
    final yesterday = Utilities.getLastWorkingDay(
      now,
    ).subtract(Duration(days: 1));

    // Yesterday volumes
    final yesterdayVolumes = candles
        .where((c) {
          final ts = c.timestamp.toLocal();
          return ts.year == yesterday.year &&
              ts.month == yesterday.month &&
              ts.day == yesterday.day;
        })
        .map((c) => c.volume.toDouble())
        .toList();

    if (yesterdayVolumes.isEmpty) return false;

    // EMA20 of all candles (could switch to yesterdayVolumes if preferred)
    final emaVol = MathUtils.emaAligned(volumes, 20);
    final ema20 = emaVol.last;

    // Averages
    final avgYes20 =
        yesterdayVolumes.reduce((a, b) => a + b) / yesterdayVolumes.length;
    final avg20 = volumes.reduce((a, b) => a + b) / volumes.length;
    final avg5 =
        volumes.sublist(volumes.length - 5).reduce((a, b) => a + b) / 5;

    // --- Conditions ---
    return last > ema20! * emaMultiplier &&
        last > avgYes20 * avgYesMultiplier &&
        last > avg20 * avgAllMultiplier &&
        last > avg5 * avg5Multiplier &&
        last > prevVol * prevMultiplier; // ✅ Previous candle check
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
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        continue;
      }
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
  /// today close >= yesterday high * (1 + pct)
  /// AND yesterday was bullish (open < close)
  static bool isCloseAboveYesterdayHighByPctAndYesterdayBullish(
    List<HistoricalDataModel> candles, {
    double pct = 0.01, // 1%
  }) {
    CandleUtils.sortByTime(candles);
    final grouped = CandleUtils.groupByDate(candles);
    final dates = grouped.keys.toList()..sort();
    if (dates.length < 2) return false;

    // Today
    final todayDate = dates.last;
    final todayClose = grouped[todayDate]!.last.close;

    // Find previous working day
    DateTime? yesterday;
    for (int i = dates.length - 2; i >= 0; i--) {
      final d = dates[i];
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        continue;
      }
      yesterday = d;
      break;
    }
    if (yesterday == null) return false;

    final yCandles = grouped[yesterday]!;

    final yOpen = yCandles[1].open;
    final yClose = yCandles.last.close;

    // 🔑 Yesterday HIGH
    final yHigh = yCandles.map((c) => c.high).reduce((a, b) => a > b ? a : b);

    // Yesterday bullish?
    final isYesterdayBullish = yClose > yOpen;

    // Breakout condition
    final breakoutLevel = yHigh * (1.0 + pct);
    return todayClose >= breakoutLevel;
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

  static bool isYesterdayAverageVolumeAbove(
    List<HistoricalDataModel> candles,
    String token, {
    int avgVolumeThreshold = 3000,
  }) {
    /// 🔥 NEW: Yesterday average volume > 5k
    final now = DateTime.now();
    final yesterday = Utilities.getLastWorkingDay(now);

    final yesterdayVolumes = candles
        .where((c) {
          final ts = c.timestamp.toLocal();
          return ts.year == yesterday.year &&
              ts.month == yesterday.month &&
              ts.day == yesterday.day;
        })
        .map((c) => c.volume.toDouble())
        .toList();

    if (yesterdayVolumes.isEmpty) return false;
    final yesterdayAvg =
        yesterdayVolumes.reduce((a, b) => a + b) / yesterdayVolumes.length;

    if (yesterdayAvg < avgVolumeThreshold) {
      return false;
    }
    return true;
  }

  static bool isNearEMA20OrSupertrendAuto(
    List<HistoricalDataModel> candles, {
    double tolerancePercent = 0.25, // ±0.10%
    int emaPeriod = 20,
    int atrPeriod = 10,
    double supertrendMultiplier = 3.0,
  }) {
    if (candles.length < 30) return false;

    CandleUtils.sortByTime(candles);

    final tolerance = tolerancePercent / 100;

    // -------- EMA 20 --------
    final closes = CandleUtils.toArrays(candles)['close']!.cast<double>();
    final emaList = MathUtils.emaAligned(closes, emaPeriod);
    final ema20 = emaList.isNotEmpty ? emaList.last : null;
    if (ema20 == null || ema20 == 0) return false;

    // -------- Supertrend --------
    final stResult = isCloseAboveSupertrend(
      candles,
      atrPeriod: atrPeriod,
      multiplier: supertrendMultiplier,
    );
    final supertrend = stResult.value;
    if (supertrend == null || supertrend == 0) return false;

    // -------- Latest price --------
    final price = closes.last;

    final nearEMA20 =
        price >= ema20 * (1 - tolerance) && price <= ema20 * (1 + tolerance);

    final nearSupertrend = price >= supertrend * (1 - tolerance) &&
        price <= supertrend * (1 + tolerance);

    return nearEMA20 || nearSupertrend;
  }

  static bool isVolumeOk(List<HistoricalDataModel> candles) {
    // Volume check
    List<int> volumes = candles.map((e) => e.volume).toList();

    // ❌ NEW RULE:
    // If ANY of last 8 candles has volume <= 2000 → reject
    final last8 = volumes.sublist(volumes.length - 20);
    if (last8.any((v) => v <= 2000)) {
      return false;
    }

    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    int? volumeToCheck;
    if (volumes.isNotEmpty) {
      if (isWorkingDay) {
        volumeToCheck = volumes.last;
      } else {
        final lastWorkDayCandle = candles.lastWhere((c) {
          final ts = c.timestamp.toLocal();
          return ts.year == lastWorking.year &&
              ts.month == lastWorking.month &&
              ts.day == lastWorking.day;
        }, orElse: () => candles.last);
        volumeToCheck = lastWorkDayCandle.volume;
      }
    }
    bool isVolumeOk = (volumeToCheck != null) ? (volumeToCheck > 15000) : false;
    return isVolumeOk;
  }

  static bool breakoutRetestBuyEntry({
    required List<HistoricalDataModel> candles,
    // Indicator params
    int emaPeriod = 20,
    int atrPeriod = 10,
    double supertrendMultiplier = 3.0,
    double rsiMin = 55,
    double tolerancePercent = 0.25, // EMA/ST proximity
  }) {
    if (candles.length < 30) return false;

    CandleUtils.sortByTime(candles);

    final arrs = CandleUtils.toArrays(candles);
    final closes = arrs['close']!.cast<double>();
    final lows = arrs['low']!.cast<double>();
    final opens = arrs['open']!.cast<double>();
    final volumes = arrs['volume']!.cast<int>();

    final lastClose = closes.last;
    final lastLow = lows.last;
    final lastOpen = opens.last;
    final lastVolume = volumes.last;

    // ---------------- EMA 20 ----------------
    final emaList = MathUtils.emaAligned(closes, emaPeriod);
    if (emaList.isEmpty) return false;
    final ema20 = emaList.last;

    // ---------------- Supertrend ----------------
    final stResult = isCloseAboveSupertrend(
      candles,
      atrPeriod: atrPeriod,
      multiplier: supertrendMultiplier,
    );
    final supertrend = stResult.value;
    if (supertrend == null) return false;

    final tolerance = tolerancePercent / 100;

    // ---------------- Retest zone ----------------
    final emaRetest = lastLow <= ema20! * (1 + tolerance) && lastClose >= ema20;

    final stRetest =
        lastLow <= supertrend * (1 + tolerance) && lastClose >= supertrend;

    final retest = emaRetest || stRetest;
    if (!retest) return false;

    // ---------------- RSI ----------------
    final rsiOk = isRsiBetween(candles, 14, min: rsiMin, max: 80);
    if (!rsiOk) return false;

    // ---------------- Volume confirmation ----------------
    final avgVol =
        volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20;

    final volumeOk = lastVolume > avgVol;
    if (!volumeOk) return false;

    // ---------------- Bullish confirmation candle ----------------
    final bullishCandle = lastClose > lastOpen && lastClose > ema20;

    if (!bullishCandle) return false;
    return true;
  }

  static bool isNearEMA20OrSupertrendAutoForDay(
    List<HistoricalDataModel> candles, {
    double tolerancePercent = 2.0,
    int emaPeriod = 20,
    int atrPeriod = 10,
    double supertrendMultiplier = 3.0,
  }) {
    if (candles.length < 60) return false;

    CandleUtils.sortByTime(candles);

    final tolerance = tolerancePercent / 100;

    final closeList = CandleUtils.toArrays(candles)['close']!.cast<double>();

    final emaList = MathUtils.emaAligned(closeList, emaPeriod);
    if (emaList.isEmpty) return false;

    final ema20 = emaList.last;
    if (ema20 == 0) return false;

    final stResult = isCloseAboveSupertrend(
      candles,
      atrPeriod: atrPeriod,
      multiplier: supertrendMultiplier,
    );

    final supertrend = stResult.value;
    if (supertrend == null || supertrend == 0) return false;

    final latest = candles.last;

    final low = latest.low;
    final close = latest.close;
    final open = latest.open;

    // ===== Green Candle =====
    final isGreen = close > open;

    // ===== EMA Pullback =====
    final nearEMA20 = low >= ema20! * (1 - tolerance) &&
        low <= ema20 * (1 + tolerance) &&
        close > ema20 &&
        isGreen;

    // ===== Supertrend Pullback =====
    final nearSupertrend = low >= supertrend * (1 - tolerance) &&
        low <= supertrend * (1 + tolerance) &&
        close > supertrend &&
        isGreen;

    return nearEMA20 || nearSupertrend;
  }

  static bool wasYesterdayGreenFrom5Min(List<HistoricalDataModel> candles) {
    if (candles.isEmpty) return false;

    CandleUtils.sortByTime(candles);

    final now = candles.last.timestamp;
    final yesterdayDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    final yCandles = candles.where((c) {
      final t = c.timestamp;
      return t.year == yesterdayDate.year &&
          t.month == yesterdayDate.month &&
          t.day == yesterdayDate.day;
    }).toList();

    if (yCandles.length < 10) return false; // half-day / holiday protection

    final open = yCandles.first.open;
    final close = yCandles.last.close;

    return close > open;
  }
}

class RetestEntryState {
  bool waitingForRetest = false;
  bool buyTriggered = false;
}
