import 'dart:developer';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:stock_demo/Utils/bullish_pattern_detector.dart';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'candle_utils.dart';
import 'math_utils.dart';

class FilterUtils {
  // Static cached variables to avoid querying SharedPreferences repetitively
  static double cachedLastMultiplier = 15.0;
  static double cachedOtherMultiplier = 10.0;
  static bool cachedIsVolAvgEnabled = true;
  static bool cachedIsPatternEnabled = true;
  static bool cachedIsSupertrendEnabled = true;
  static bool cachedIsEma20Enabled = true;
  static bool cachedIsVolBreakoutEnabled = true;

  /// Loads and caches the settings from SharedPreferences
  static Future<void> cacheFilterSettings() async {
    final prefs = SharedPreferenceHelper.instance;
    cachedLastMultiplier = await prefs.getLastCandleMultiplier();
    cachedOtherMultiplier = await prefs.getOtherCandlesMultiplier();
    cachedIsVolAvgEnabled = await prefs.getVolumeAverageEnabled();
    cachedIsPatternEnabled = await prefs.getPatternEnabled();
    cachedIsSupertrendEnabled = await prefs.getSupertrendEnabled();
    cachedIsEma20Enabled = await prefs.getEma20Enabled();
    cachedIsVolBreakoutEnabled = await prefs.getVolumeBreakoutEnabled();
  }

  static bool passesFilter(List<HistoricalDataModel> candles, String token) {
    final timeStr =
        candles.isNotEmpty ? candles.last.timestamp.toString() : "Unknown Time";

    // bool isVolumeAverageOK = IndicatorUtils.isEveryCandleVolumeStrong(
    //     candles, 0,
    //     lastMultiplier: 10, otherMultiplier: 10);
    //
    // return isVolumeAverageOK;

    // 1. Not above 5% check (very fast)
    bool isNotAbove5Percent = IndicatorUtils.isNotAbove5Percent(candles);
    if (!isNotAbove5Percent) {
      debugPrint("Failed: $token at $timeStr - Reason: Above 5% Change");
      return false;
    }

    // 2. EMA20 Check
    if (cachedIsEma20Enabled) {
      bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed;
      if (!aboveEma20) {
        debugPrint("Failed: $token at $timeStr - Reason: Below EMA20");
        return false;
      }
    }

    // 3. Supertrend Check
    if (cachedIsSupertrendEnabled) {
      bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
        candles,
        atrPeriod: 10,
        multiplier: 3,
      ).isPassed;
      if (!aboveSupertrend) {
        debugPrint("Failed: $token at $timeStr - Reason: Below Supertrend");
        return false;
      }
    }

    // // 4. Volume Breakout Check
    // if (cachedIsVolBreakoutEnabled) {
    //   bool isVolumeBreakout = IndicatorUtils.isVolumeBreakoutStrong(candles);
    //   if (!isVolumeBreakout) {
    //     debugPrint("Failed: $token at $timeStr - Reason: Weak Volume Breakout");
    //     return false;
    //   }
    // }

    // 5. ATR Check
    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(candles);
    if (!atrOk) {
      debugPrint("Failed: $token at $timeStr - Reason: Low ATR");
      return false;
    }

    // 6. ADX Check
    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) {
      debugPrint("Failed: $token at $timeStr - Reason: ADX Not Bullish");
      return false;
    }

    // 7. Score Check (getSmartPriceActionScore)
    int score = getSmartPriceActionScore(candles);
    if (score < 70) {
      debugPrint(
          "Failed: $token at $timeStr - Reason: Low Smart Score ($score)");
      return false;
    }

    // 8. Volume Avg Check
    if (cachedIsVolAvgEnabled) {
      bool isVolumeAverageOK = IndicatorUtils.isEveryCandleVolumeStrong(
          candles, 0,
          lastMultiplier: cachedLastMultiplier,
          otherMultiplier: cachedOtherMultiplier);
      if (!isVolumeAverageOK) {
        debugPrint(
            "Failed: $token at $timeStr - Reason: Volume Average Not OK");
        return false;
      }
    }

    // 9. Day Pass Check (requires converting to daily, slightly heavier)
    final dailyCandles = Utilities.convertToDaily(candles);
    final isDayPass = isPassHistoryChart(dailyCandles, token, 1);
    if (!isDayPass) {
      debugPrint(
          "Failed: $token at $timeStr - Reason: Day History Chart Failed");
      return false;
    }

    // 10. Pattern Check (requires daily candles)
    // if (cachedIsPatternEnabled) {
    //   var isPattern = BullishPatternDetector.detect(dailyCandles);
    //   if (!isPattern.found) {
    //     debugPrint("Failed: $token at $timeStr - Reason: No Bullish Pattern");
    //     return false;
    //   }
    // }
    print("Passed : $token");
    return true;
  }

  /// 🔹 Plan B logic
  static bool passesPlanB(List<HistoricalDataModel> candles, StockModel stock) {
    if (candles.isEmpty || stock.lastPrice == null) {
      debugPrint(
          "PlanB Failed: ${stock.symbol} - No candles or lastPrice is null");
      return false;
    }

    // Last candle volume check
    // if (candles.last.volume < 5000) {
    //   debugPrint(
    //       "PlanB Failed: ${stock.symbol} - Last candle volume (${candles.last.volume}) < 10000");
    //   return false;
    // }

    // 1. Price > 30
    if (stock.lastPrice! <= 30) {
      debugPrint(
          "PlanB Failed: ${stock.symbol} - Price (${stock.lastPrice}) <= 30");
      return false;
    }

    // 2. 5-min timeframe check: Today any candle volume is 50x yesterday's avg and > 50000
    final groupedByDate = CandleUtils.groupByDate(candles);
    final sortedDates = groupedByDate.keys.toList()..sort();
    if (sortedDates.length < 2) {
      return false;
    }

    final todayDate = sortedDates.last;
    final todayCandles = groupedByDate[todayDate]!;

    final yesterdayDate = sortedDates[sortedDates.length - 2];
    final yesterdayCandles = groupedByDate[yesterdayDate]!;

    if (yesterdayCandles.isEmpty) {
      return false;
    }

    final prevAvg =
        yesterdayCandles.map((e) => e.volume).reduce((a, b) => a + b) /
            yesterdayCandles.length;

    bool volumeSpikeMet = false;
    for (int i = 0; i < todayCandles.length; i++) {
      var currentCandle = todayCandles[i];
      if (currentCandle.volume >= 50000 &&
          currentCandle.volume >= (prevAvg * 30)) {
        volumeSpikeMet = true;
        break;
      }
    }
    if (!volumeSpikeMet) {
      return false;
    }

    // 3. Daily Timeframe check (Heavy, so done last): Stock close above 20 EMA and Above Supertrend
    final dailyCandles = Utilities.convertToDaily(candles);
    if (dailyCandles.length < 20) {
      return false;
    }

    bool aboveEma20Daily =
        IndicatorUtils.isCloseAboveEMA(dailyCandles, 20).isPassed;
    if (!aboveEma20Daily) return false;

    bool aboveSupertrendDaily = IndicatorUtils.isCloseAboveSupertrend(
      dailyCandles,
      atrPeriod: 10,
      multiplier: 3,
    ).isPassed;
    if (!aboveSupertrendDaily) return false;

    return true;
  }

  /// 🔹 Check if stock is near 20EMA or Supertrend on 5m (Buying zone)
  static bool isNearBuyingZone5Min(List<HistoricalDataModel> candles,
      {double threshold = 0.0050}) {
    if (candles.length < 20) return false;

    // Must be a green candle
    if (candles.last.close <= candles.last.open) return false;

    final currentLow = candles.last.low;

    // EMA 20 calculation
    final closes = candles.map((e) => e.close).toList();
    final ema20List = MathUtils.emaAligned(closes, 20);
    if (ema20List.isNotEmpty) {
      final ema20 = ema20List.last!;
      final distanceToEma = ((currentLow - ema20).abs() / ema20);
      if (distanceToEma <= threshold) return true;
    }

    // Supertrend calculation
    final stRes = IndicatorUtils.isCloseAboveSupertrend(candles,
        atrPeriod: 10, multiplier: 3);
    if (stRes.value != null && stRes.value! > 0) {
      final stValue = stRes.value!;
      final distanceToSt = ((currentLow - stValue).abs() / stValue);
      if (distanceToSt <= threshold) return true;
    }

    return false;
  }

  /// 🔹 Main multi-timeframe validation
  static Future<bool> isPassAllTimeFrame(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
  ) async {
    final is5MinPass =
        isPassHistoryChart(historyCandles, stock.token.toString(), 5);
    if (!is5MinPass) return false;

    final is15MinPass = isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 15),
      ),
      stock.token.toString(),
      15,
    );
    if (!is15MinPass) return false;

    final is30MinPass = isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 30),
      ),
      stock.token.toString(),
      30,
    );
    if (!is30MinPass) return false;

    final is1HourPass = isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 60),
      ),
      stock.token.toString(),
      60,
    );
    if (!is1HourPass) return false;

    // final isDayPass = await isPassHistoryChart(
    //   Utilities.convertToDaily(historyCandles ?? []),
    //   stock,
    //   1,
    // );
    // if (!isDayPass) return false;
    final isPattern = BullishPatternDetector.detect(
        Utilities.convertToDaily(historyCandles ?? []));
    debugPrint(isPattern.name);
    if (!isPattern.found) {
      return false;
    }
    debugPrint("✅ Stock Passed All Timeframes: ${stock.symbol}");
    return true;
  }

  /// 🔹 Handles individual timeframe logic
  static bool isPassHistoryChart(
    List<HistoricalDataModel>? historyCandles,
    String token,
    int timeFrame,
  ) {
    if (historyCandles == null || historyCandles.isEmpty) return false;

    switch (timeFrame) {
      case 5:
        bool isPass = passesFilter(historyCandles, token.toString());
        return isPass;

      case 15:
      case 30:
      case 60:
        bool isEma20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        return isEma20;

      case 1:
        bool isEMA20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
          historyCandles,
          atrPeriod: 10,
        ).isPassed;
        return isEMA20 || aboveSupertrend;

      default:
        return false;
    }
  }

  /// 🔹 Final tradability rule check (price, circuit, volume etc.)
  static bool isTradable(StockModel stock) {
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;

    final close = ohlc?.close;
    final open = ohlc?.open;
    final high = ohlc?.high;
    final low = ohlc?.low;

    final volume = stock.volume;

    if (lastPrice == null ||
        close == null ||
        open == null ||
        high == null ||
        low == null ||
        lowerLimit == null ||
        upperLimit == null ||
        volume == null) {
      return false;
    }

    final percentChange = ((lastPrice - open) / open) * 100;
    final rangePercent = ((high - low) / open) * 100;

    // ✅ Price range filter
    if (lastPrice < 30 || lastPrice > 5000) return false;

    // ✅ Avoid circuit stocks
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;

    // ✅ Must be green today
    if (lastPrice <= open) return false;

    // ✅ Momentum required
    if (percentChange < 1.2) return false;

    // ✅ Must have movement
    if (rangePercent < 1) return false;

    // ✅ Liquidity filter
    if (volume < 15000) return false;

    // ✅ Working day volume check
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);

    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume < 15000) return false;
    }
    return true;
  }

  static bool isBreakDownTradable(StockModel stock) {
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;
    final open = ohlc?.open;
    final close = ohlc?.close;
    final volume = stock.volume;

    if (lastPrice == null ||
        open == null ||
        close == null ||
        lowerLimit == null ||
        upperLimit == null ||
        volume == null) {
      return false;
    }

    // Price range filter
    if (lastPrice <= 20 || lastPrice >= 500) return false;

    // Avoid circuit stocks
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;

    // 🔴 Breakdown condition: price below previous close
    if (lastPrice >= close) return false;

    // % change calculation (negative expected)
    final percentChange = ((lastPrice - open) / open) * 100;

    // Strong red candle only
    if (percentChange >= -1.5) return false;

    // Volume check – only on working day
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume <= 15000) return false;
    }

    return true;
  }

  static bool passedDayFilter(List<HistoricalDataModel> candles, String token) {
    if (!IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed) return false;
    if (!IndicatorUtils.isRsiBetween(candles, 14, min: 55, max: 95))
      return false;
    if (!IndicatorUtils.isCloseAboveSupertrend(candles,
            atrPeriod: 10, multiplier: 3)
        .isPassed) return false;
    if (!IndicatorUtils.isAdxBullish(candles)) return false;
    if (!IndicatorUtils.isAtrGreaterThanAdaptive(candles)) return false;
    if (!IndicatorUtils.isVolumeBreakoutStrong(candles)) return false;
    return true;
  }

  static bool isDayTradable(StockModel stock) {
    final symbol = stock.symbol!.toLowerCase();
    // remove ETF / BEES / gold / silver
    if (symbol.contains("etf") ||
        symbol.contains("bees") ||
        symbol.contains("gold") ||
        symbol.contains("silver")) {
      return false;
    }
    return true;
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;
    final close = ohlc?.close;
    final volume = stock.volume;
    final percentChange =
        ((stock.lastPrice! - stock.ohlc!.open!) / stock.ohlc!.open!) * 100;

    if (lastPrice == null ||
        close == null ||
        lowerLimit == null ||
        upperLimit == null ||
        volume == null) {
      return false;
    }

    if (lastPrice <= 50) return false;
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;

    // Only enforce the volume threshold on working days.
    // If today is a weekend or a holiday (Utilities.getLastWorkingDay shifts back),
    // skip the volume check.
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay = lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume <= 100000) return false;
    }
    return true;
  }

  /// 🔥 DAILY INSTITUTIONAL TREND FILTER
  ///
  /// Purpose:
  /// Find strong trending stocks
  /// with healthy pullback structure
  /// before intraday entry.
  ///
  /// Use this FIRST.
  /// Then run 5min strategy only
  /// on shortlisted symbols.

  static bool isStrongDailyTrendSetup(
    List<HistoricalDataModel> candles,
  ) {
    if (candles.length < 200) {
      return false;
    }

    CandleUtils.sortByTime(candles);

    final daily = Utilities.convertToDaily(candles);

    final closes = daily.map((e) => e.close).toList();

    final ema20List = MathUtils.emaAligned(
      closes,
      20,
    );

    if (ema20List.isEmpty) {
      return false;
    }

    final ema20 = ema20List.last!;

    /// =========================================
    /// DAILY SUPERTREND
    /// =========================================

    /// =========================================
    /// DAILY RSI HEALTHY
    /// =========================================

    final rsiOk = IndicatorUtils.isRsiBetween(
      daily,
      14,
      min: 52,
      max: 75,
    );

    if (!rsiOk) {
      return false;
    }

    /// =========================================
    /// DAILY VOLUME PARTICIPATION
    /// =========================================

    final dailyVolumes = daily.map((e) => e.volume.toDouble()).toList();

    final avg10Volume = dailyVolumes
            .sublist(
              dailyVolumes.length - 10,
            )
            .reduce((a, b) => a + b) /
        10;

    final currentVolume = dailyVolumes.last;

    if (currentVolume < avg10Volume * 0.8) {
      return false;
    }

    /// =========================================
    /// RECENT MOMENTUM
    /// =========================================

    final currentClose = daily.last.close;

    final oldClose = daily[daily.length - 10].close;

    final movePct = ((currentClose - oldClose) / oldClose) * 100;

    if (movePct < 5) {
      return false;
    }

    /// =========================================
    /// NOT OVEREXTENDED
    /// =========================================

    final distanceFromEMA20 = ((currentClose - ema20) / ema20) * 100;

    if (distanceFromEMA20 > 10) {
      return false;
    }

    /// =========================================
    /// DAILY GREEN CANDLE
    /// =========================================

    final lastDaily = daily.last;

    if (lastDaily.close <= lastDaily.open) {
      return false;
    }

    /// =========================================
    /// CONTROLLED PULLBACK
    /// =========================================

    final recent = daily.sublist(
      daily.length - 5,
    );

    int redCount = 0;

    for (final c in recent) {
      if (c.close < c.open) {
        redCount++;
      }
    }

    if (redCount > 4) {
      return false;
    }

    /// =========================================
    /// VOLUME DRY-UP
    /// =========================================

    final previousTrendCandles = daily.sublist(
      daily.length - 15,
      daily.length - 5,
    );

    final previousAvgVolume =
        previousTrendCandles.map((e) => e.volume).reduce((a, b) => a + b) /
            previousTrendCandles.length;

    final recentAvgVolume =
        recent.map((e) => e.volume).reduce((a, b) => a + b) / recent.length;

    final dryUp = recentAvgVolume < previousAvgVolume * 0.8;

    if (!dryUp) {
      return false;
    }

    /// =========================================
    /// HOLDING EMA20
    /// =========================================

    final nearEMA20 = currentClose >= ema20 * 0.97;

    if (!nearEMA20) {
      return false;
    }

    /// =========================================
    /// RECLAIM CANDLE
    /// =========================================

    final last = daily.last;

    final candleRange = last.high - last.low;

    if (candleRange <= 0) {
      return false;
    }

    final candleBody = (last.close - last.open).abs();

    final bullish = last.close > last.open;

    final closeNearHigh = ((last.high - last.close) / candleRange) < 0.35;

    final upperWick = last.high -
        max(
          last.open,
          last.close,
        );

    final lowUpperWick = upperWick < candleBody * 0.8;

    if (!bullish || !closeNearHigh || !lowUpperWick) {
      return false;
    }

    /// =========================================
    /// AVOID PARABOLIC STOCKS
    /// =========================================

    if (movePct > 30) {
      return false;
    }

    debugPrint(
      "🔥 DAILY STRONG TREND SETUP => "
      "${candles.last.timestamp}",
    );

    return true;
  }

  static double getVolumeMultiplication(List<HistoricalDataModel> candles) {
    final daily = Utilities.convertToDaily(candles);
    if (daily.length < 10) return 0.0;

    final recent5 = daily.sublist(daily.length - 5);
    final prev5 = daily.sublist(
      daily.length - 10,
      daily.length - 5,
    );

    final recentAvgVolume =
        recent5.map((e) => e.volume).reduce((a, b) => a + b) / recent5.length;

    final prevAvgVolume =
        prev5.map((e) => e.volume).reduce((a, b) => a + b) / prev5.length;

    if (prevAvgVolume == 0) return 0.0;
    return recentAvgVolume / prevAvgVolume;
  }

  static int getSmartPriceActionScore(
    List<HistoricalDataModel> candles,
  ) {
    if (candles.isEmpty) return 0;

    final groupedByDate = CandleUtils.groupByDate(candles);
    final sortedDates = groupedByDate.keys.toList()..sort();
    if (sortedDates.isNotEmpty) {
      final todayCandles = groupedByDate[sortedDates.last]!;
      for (var c in todayCandles) {
        if (c.volume <= 5000) {
          return 0;
        }
      }
    }

    // =========================================================
    // 5 MIN → DAILY
    // =========================================================

    final daily = Utilities.convertToDaily(candles);

    if (daily.length < 20) {
      return 0;
    }

    CandleUtils.sortByTime(daily);

    int score = 0;

    final previousDayVolume = daily[daily.length - 2].volume;

    final volume1Lakh = previousDayVolume >= 100000;

    if (!volume1Lakh) {
      return 0;
    }

    final last = daily.last;

    final close = last.close;
    final open = last.open;
    final high = last.high;
    final low = last.low;

    // =========================================================
    // 1️⃣ CLOSE NEAR DAY HIGH
    // Strong closing = institutions buying
    // =========================================================

    final closeNearHigh = close >= high * 0.985;

    if (closeNearHigh) {
      score += 15;
    }

    // =========================================================
    // 2️⃣ LOW UPPER WICK
    // Avoid profit booking candles
    // =========================================================

    final body = (close - open).abs();

    final upperWick = high - max(open, close);

    final lowUpperWick = body > 0 && upperWick <= body * 0.6;

    if (lowUpperWick) {
      score += 10;
    }

    // =========================================================
    // 3️⃣ STRONG GREEN CANDLE
    // =========================================================

    final candlePct = ((close - open).abs() / open) * 100;

    final strongGreen = close > open && candlePct >= 1.2;

    if (strongGreen) {
      score += 15;
    }

    // =========================================================
    // 4️⃣ VOLUME EXPANSION
    // Real momentum
    // =========================================================

    final recent5 = daily.sublist(daily.length - 5);

    final prev5 = daily.sublist(
      daily.length - 10,
      daily.length - 5,
    );

    final recentAvgVolume =
        recent5.map((e) => e.volume).reduce((a, b) => a + b) / recent5.length;

    final prevAvgVolume =
        prev5.map((e) => e.volume).reduce((a, b) => a + b) / prev5.length;

    final volumeExpansion = recentAvgVolume > prevAvgVolume * 1.4;

    if (volumeExpansion) {
      score += 20;
    }

    // =========================================================
    // 5️⃣ SMOOTH STRUCTURE
    // Remove operator/choppy stocks
    // =========================================================

    int badWickCount = 0;

    final recentCandles = daily.sublist(daily.length - 10);

    for (final c in recentCandles) {
      final cBody = (c.close - c.open).abs();

      final cUpperWick = c.high - max(c.open, c.close);

      final cLowerWick = min(c.open, c.close) - c.low;

      final totalWick = cUpperWick + cLowerWick;

      if (cBody > 0 && totalWick > cBody * 1.5) {
        badWickCount++;
      }
    }

    final smoothStructure = badWickCount <= 1;

    if (smoothStructure) {
      score += 20;
    }

    // =========================================================
    // 6️⃣ TIGHT CONSOLIDATION
    // Strong stocks move cleanly
    // =========================================================

    double recentHigh = 0;
    double recentLow = double.infinity;

    for (int i = daily.length - 5; i < daily.length; i++) {
      if (daily[i].high > recentHigh) {
        recentHigh = daily[i].high;
      }

      if (daily[i].low < recentLow) {
        recentLow = daily[i].low;
      }
    }

    final rangePct = ((recentHigh - recentLow) / recentLow) * 100;

    final tightStructure = rangePct <= 4.5;

    if (tightStructure) {
      score += 15;
    }

    // =========================================================
    // 7️⃣ BREAKOUT QUALITY
    // Fresh breakout only
    // =========================================================

    double highestHigh = 0;

    for (int i = daily.length - 20; i < daily.length - 1; i++) {
      if (daily[i].high > highestHigh) {
        highestHigh = daily[i].high;
      }
    }

    final breakout = close > highestHigh * 1.002;

    if (breakout) {
      score += 20;
    }

    // =========================================================
    // 8️⃣ HEALTHY PULLBACK
    // Avoid weak structures
    // =========================================================

    int redCount = 0;

    final last7 = daily.sublist(daily.length - 7);

    for (final c in last7) {
      if (c.close < c.open) {
        redCount++;
      }
    }

    final healthyPullback = redCount <= 2;

    if (healthyPullback) {
      score += 10;
    }

    // =========================================================
    // 9️⃣ AVOID PARABOLIC MOVE
    // Retail trap removal
    // =========================================================

    final tenDayAgoClose = daily[daily.length - 10].close;

    final runUpPct = ((close - tenDayAgoClose) / tenDayAgoClose) * 100;

    final notOverExtended = runUpPct <= 18;

    if (notOverExtended) {
      score += 10;
    }

    // =========================================================
    // 🔟 NO BIG GAP-UP
    // Late entries avoid
    // =========================================================

    final gapPct = ((open - daily[daily.length - 2].close) /
            daily[daily.length - 2].close) *
        100;

    final controlledGap = gapPct <= 2.5;

    if (controlledGap) {
      score += 10;
    }

    // =========================================================
    // FINAL
    // =========================================================

    // final nearBuyingZone = IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(
    //   daily,
    //   tolerancePercent: 5,
    // );
    //
    // if (!nearBuyingZone) {
    //   return false;
    // }
    //
    final passed = score >= 70;

    // bool isVolumeAverageOK = IndicatorUtils.isEveryCandleVolumeStrong(
    //     candles, 0,
    //     lastMultiplier: 1, otherMultiplier: 1);

    // if(!isVolumeAverageOK){
    //   return false;
    // }

    print(
      "${candles.last.timestamp}\n"
      "Smart Price Action Score: $score\n"
      "CloseNearHigh: $closeNearHigh\n"
      "LowUpperWick: $lowUpperWick\n"
      "StrongGreen: $strongGreen\n"
      "VolumeExpansion: $volumeExpansion\n"
      "SmoothStructure: $smoothStructure\n"
      "TightStructure: $tightStructure\n"
      "Breakout: $breakout\n"
      "HealthyPullback: $healthyPullback\n"
      "NotOverExtended: $notOverExtended\n"
      "ControlledGap: $controlledGap",
    );
    return score;
  }
}
