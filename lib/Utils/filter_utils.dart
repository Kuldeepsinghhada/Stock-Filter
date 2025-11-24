import 'dart:developer';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/indicator_status.dart';
import 'package:stock_demo/model/stock_model.dart';

class FilterUtils {
  /// 🔹 Checks if all core indicator filters are passed
  static bool passesFilter(List<HistoricalDataModel> candles, String token) {
    // Run all indicators
    IndicatorStatus aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20);
    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 60, max: 90);
    bool atrOk = IndicatorUtils.isAtrHealthy5Min(candles);
    bool aboveVwap = IndicatorUtils.isCloseAboveVWAP(candles);
    bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 9,
      multiplier: 3,
    );
    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    List<int> volumes = candles.map((e) => e.volume).toList();
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);

    final isWorkingDay =
        lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    int? volumeToCheck;
    if (volumes.isNotEmpty) {
      if (isWorkingDay) {
        volumeToCheck = volumes.last;
      } else {
        final lastWC = candles.lastWhere((c) {
          final ts = c.timestamp.toLocal();
          return ts.year == lastWorking.year &&
              ts.month == lastWorking.month &&
              ts.day == lastWorking.day;
        }, orElse: () => candles.last);
        volumeToCheck = lastWC.volume;
      }
    }

    // bool isVolumeOk = (volumeToCheck != null) ? (volumeToCheck > 30000) : false;
    bool isVolumeBreakOut = IndicatorUtils.isVolumeBreakout(candles);
    bool isPivotOK = IndicatorUtils.isPriceAboveR1(candles);
    bool is2PcChange =
        IndicatorUtils.isCloseAboveYesterdayCloseByPctAndYesterdayBullish(
          candles,
        );
    bool isStrongCandle = IndicatorUtils.isStrongCandle(candles.last);

    // 🔥 PRINT REASONS
    // if (!isVolumeOk) {
    //   print("❌ FAIL: Volume too low → $volumeToCheck (Required > 30000)");
    // }
    if (!aboveEma20.status) {
      print("❌ FAIL: Close is below EMA20");
    }
    if (!rsiOk) {
      // final rsi = IndicatorUtils.getLastRsi(candles, 14);
      print("❌ FAIL: RSI not between 60–90 → RSI");
    }
    if (!aboveVwap) {
      print("❌ FAIL: Close is below VWAP");
    }
    if (!aboveSupertrend) {
      print("❌ FAIL: Close is not above SuperTrend");
    }
    if (!adxRes) {
      // final adx = IndicatorUtils.getLastAdx(candles, 14);
      print("❌ FAIL: ADX not bullish → ADX");
    }
    if (!atrOk) {
      print("❌ FAIL: ATR condition failed");
    }
    if (!isStrongCandle) {
      print("❌ FAIL: Not Strong Candle");
    }
    if (!isPivotOK) {
      print("❌ FAIL: Pivot Not Pass");
    }
    // FINAL RESULT
    bool result =
        //isVolumeOk &&
        aboveEma20.status &&
        rsiOk &&
        aboveVwap &&
        aboveSupertrend &&
        adxRes &&
        atrOk &&
        isStrongCandle &&
        isVolumeBreakOut;
        //isPivotOK;
    //is2PcChange;

    if (result) {
      print("✅ PASSED: ALL CONDITIONS OK for $token");
    } else {
      print("⚠ FAILED: Some conditions failed for $token");
    }

    return result;
  }

  /// 🔹 Main multi-timeframe validation
  static Future<bool> isPassAllTimeFrame(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
  ) async {
    if (historyCandles == null || historyCandles.isEmpty) {
      log("❌ No candles found for ${stock.symbol}");
      return false;
    }

    // 5 MIN
    final is5MinPass = await isPassHistoryChart(historyCandles, stock, 5);
    if (!is5MinPass) {
      log("❌ FAILED on 5 min → ${stock.symbol}");
      return false;
    }

    // 15 MIN
    final candles15 = Utilities.resampleCandles(
      historyCandles,
      Duration(minutes: 15),
    );
    final is15MinPass = await isPassHistoryChart(candles15, stock, 15);
    if (!is15MinPass) {
      log("❌ FAILED on 15 min → ${stock.symbol}");
      return false;
    }

    // 30 MIN
    final candles30 = Utilities.resampleCandles(
      historyCandles,
      Duration(minutes: 30),
    );
    final is30MinPass = await isPassHistoryChart(candles30, stock, 30);
    if (!is30MinPass) {
      log("❌ FAILED on 30 min → ${stock.symbol}");
      return false;
    }

    // 1 HOUR
    final candles1H = Utilities.resampleCandles(
      historyCandles,
      Duration(minutes: 60),
    );
    final is1HourPass = await isPassHistoryChart(candles1H, stock, 60);
    if (!is1HourPass) {
      log("❌ FAILED on 1 hour → ${stock.symbol}");
      return false;
    }

    // DAILY
    final daily = Utilities.convertToDaily(historyCandles);
    final isDayPass = await isPassHistoryChart(daily, stock, 1);
    if (!isDayPass) {
      log("❌ FAILED on Daily → ${stock.symbol}");
      return false;
    }

    log("✅ Stock Passed All Timeframes: ${stock.symbol}");
    return true;
  }

  /// 🔹 Handles individual timeframe logic
  static Future<bool> isPassHistoryChart(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
    int timeFrame,
  ) async {
    if (historyCandles == null || historyCandles.isEmpty) return false;

    switch (timeFrame) {
      case 5:
        bool isPass = passesFilter(historyCandles, stock.token.toString());
        return isPass;
      case 15:
      case 30:
        var isTrendBullish = IndicatorUtils.isTrendBullish(historyCandles);
        return isTrendBullish;
      case 60:
        var isTrendBullish = IndicatorUtils.isTrendBullish(historyCandles);
        var isADXBullish = IndicatorUtils.isAdxBullish(historyCandles);
        return isTrendBullish && isADXBullish;
      case 1:
        bool isDailyBullish = IndicatorUtils.isDailyBullishAdvanced(
          historyCandles,
        );
        return isDailyBullish;
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

    if (lastPrice <= 95 || lastPrice >= 2000) return false;
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;
    if (lastPrice <= close) return false;
    if (percentChange <= 1.5) return false;

    // Only enforce the volume threshold on working days.
    // If today is a weekend or a holiday (Utilities.getLastWorkingDay shifts back),
    // skip the volume check.
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay =
        lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume <= 10000) return true;
    }
    return true;
  }

  static bool isReadyForInvestment(StockModel stock) {
    final lastPrice = stock.lastPrice;
    final ohlc = stock.ohlc;

    if (lastPrice == null ||
        ohlc?.open == null ||
        ohlc?.close == null ||
        stock.lowerCircuitLimit == null ||
        stock.upperCircuitLimit == null ||
        stock.volume == null) {
      return false;
    }

    // price filter
    if (lastPrice < 95 || lastPrice > 200) return false;

    // red candle check
    // return ohlc!.close! < ohlc.open!;
    return true;
  }

  /// 🔹 Checks if all core indicator filters are passed
  static bool checkForDay(List<HistoricalDataModel> candles, String token) {
    if (candles.length < 250) return false;

    // 1. Take last 250 candles
    final List<HistoricalDataModel> last250 = candles.sublist(
      candles.length - 250,
    );

    final int lastIndex = last250.length - 1; // 249
    final int firstIndex = lastIndex - 19; // 249 - 9 = 240

    // 2. Loop in REVERSE order: 249 → 240
    for (int i = lastIndex; i >= firstIndex; i--) {
      // Slice candles only till "i"
      final slice = last250.sublist(0, i + 1);

      // 3. Check filter
      if (passesInvestmentFilter(slice, token)) {
        return true; // Any candle passes = success
      }
    }
    return false; // None passed
  }

  static bool passesInvestmentFilter(
    List<HistoricalDataModel> candles,
    String token,
  ) {
    List<String> failReasons = [];

    IndicatorStatus aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20);
    if (!aboveEma20.status) failReasons.add("Failed: Close not above EMA20");

    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 50, max: 80);
    if (!rsiOk) failReasons.add("Failed: RSI not between 60–90");

    bool atrOk = IndicatorUtils.isAtrHealthyInvestment(candles);
    if (!atrOk) failReasons.add("Failed: ATR not greater than adaptive ATR");

    // bool aboveVwap =
    //     isInvestmentCheck ? true : IndicatorUtils.isCloseAboveVWAP(candles);
    // if (!aboveVwap) failReasons.add("Failed: Close not above VWAP");

    bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 10,
      multiplier: 3,
    );
    if (!aboveSupertrend) failReasons.add("Failed: Close not above Supertrend");

    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) failReasons.add("Failed: ADX not bullish");

    // ----- Volume Logic -----
    List<int> volumes = candles.map((e) => e.volume).toList();
    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);

    bool isWorkingDay =
        now.year == lastWorking.year &&
        now.month == lastWorking.month &&
        now.day == lastWorking.day;

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

    bool isVolumeOk = (volumeToCheck != null) ? (volumeToCheck > 30000) : false;
    if (!isVolumeOk) {
      failReasons.add("Failed: Volume $volumeToCheck is below 30,000");
    }

    // Yesterday % change check
    bool is2PcChange =
        IndicatorUtils.isCloseAboveYesterdayCloseByPctAndYesterdayBullish(
          candles,
          pct: 0.01,
        );
    if (!is2PcChange) {
      failReasons.add("Failed: Didn't close above yesterday close % condition");
    }

    bool isVolumeBreakout = IndicatorUtils.isVolumeBreakout(candles, factor: 3);

    // Final Result
    final result =
        isVolumeOk &&
        aboveEma20.status &&
        rsiOk &&
        isVolumeBreakout &&
        aboveSupertrend &&
        is2PcChange &&
        adxRes &&
        atrOk;
    // is2PcChange;

    // 🔥 Print Failure Summary
    if (!result) {
      print("----- $token FAILED FILTER -----");
      for (var reason in failReasons) {
        print(reason);
      }
      print("----------------------------------");
    }

    return result;
  }

  static bool dayBreakOutFilter(
    List<HistoricalDataModel> candles,
    String token,
  ) {
    List<String> failures = [];

    IndicatorStatus aboveEma200 = IndicatorUtils.isCloseAboveEMA(candles, 200);
    if (!aboveEma200.status) failures.add("❌ Close NOT above 200 EMA");

    bool isGoldenCross = IndicatorUtils.isEma50Above200(candles);
    if (!isGoldenCross) failures.add("❌ 50 EMA is NOT above 200 EMA");

    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 55, max: 85);
    if (!rsiOk) failures.add("❌ RSI not in range 55–85");

    bool volumeBreakOut = IndicatorUtils.isVolumeBreakoutOnDay(
      candles,
      factor: 2.0,
    );
    if (!volumeBreakOut) failures.add("❌ Volume breakout FAILED");

    bool atrOk = IndicatorUtils.isAtrHealthyInvestment(candles);
    if (!atrOk) failures.add("❌ ATR unhealthy (low volatility)");

    bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 10,
      multiplier: 3,
    );
    if (!aboveSupertrend) failures.add("❌ Close below Supertrend");

    bool adxRes = IndicatorUtils.isAdxBullish(candles, minAdx: 25);
    if (!adxRes) failures.add("❌ ADX < 25 (trend weak)");

    bool is2PcChange =
        IndicatorUtils.isCloseAboveYesterdayCloseByPctAndYesterdayBullish(
          candles,
          pct: 0.001,
        );
    if (!is2PcChange) failures.add("❌ Today not > Yesterday close + bullish");

    // ---------- Volume Handling ----------
    List<int> volumes = candles.map((e) => e.volume).toList();

    final now = DateTime.now();
    final lastWorking = Utilities.getLastWorkingDay(now);
    final isWorkingDay =
        lastWorking.year == now.year &&
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

    // bool isVolumeOk = (volumeToCheck != null) ? (volumeToCheck > 30000) : false;
    // if (!isVolumeOk) failures.add("❌ Volume < 30,000");

    // ---------- FINAL RESULT ----------
    bool result =
        volumeBreakOut &&
        aboveEma200.status &&
        isGoldenCross &&
        rsiOk &&
        aboveSupertrend &&
        adxRes &&
        is2PcChange &&
        atrOk;

    // PRINT FAILURE REASONS
    if (!result) {
      print("⛔ DAY BREAKOUT FAILED for $token");
      print("Reasons: ${failures.length}");
      for (var fail in failures) {
        print(fail);
      }
    } else {
      print("✅ DAY BREAKOUT PASSED for $token");
    }

    return result;
  }
}
