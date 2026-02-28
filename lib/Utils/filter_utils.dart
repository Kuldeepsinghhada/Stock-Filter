import 'dart:developer';
import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class FilterUtils {
  /// 🔹 Checks if all core indicator filters are passed
  static bool passesFilter(List<HistoricalDataModel> candles, String token) {
    List<String> failedReasons = [];

    // bool yesGreen = IndicatorUtils.wasYesterdayGreenFrom5Min(candles);
    // if(!yesGreen) failedReasons.add("Yesterday NOT Green from 5Min");

    bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed;
    if (!aboveEma20) failedReasons.add("Close NOT above EMA20");

    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 60, max: 95);
    if (!rsiOk) failedReasons.add("RSI not between 60–95");

    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(candles);
    if (!atrOk) failedReasons.add("ATR not greater than adaptive threshold");

    bool aboveVwap = IndicatorUtils.isCloseAboveVWAP(candles);
    if (!aboveVwap) failedReasons.add("Close NOT above VWAP");

    bool aboveSupertrend =
        IndicatorUtils.isCloseAboveSupertrend(
          candles,
          atrPeriod: 10,
          multiplier: 3,
        ).isPassed;
    if (!aboveSupertrend) failedReasons.add("Close NOT above Supertrend");

    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) failedReasons.add("ADX NOT bullish");

    bool isVolumeOk = IndicatorUtils.isVolumeOk(candles);
    if (!isVolumeOk) {
      failedReasons.add("Volume NOT > 15000 (vol=$isVolumeOk)");
    }

    // bool isYesterdayAvgVolumeOk = IndicatorUtils.isYesterdayAverageVolumeAbove(
    //   candles,token
    // );
    // if (!isYesterdayAvgVolumeOk) {
    //   failedReasons.add("Yesterday Volume Not Enough");
    // }

    bool isVolumeBreakout = IndicatorUtils.isVolumeBreakoutStrong(candles);
    if (!isVolumeBreakout) failedReasons.add("Volume breakout weak");

    bool is2PcChange =
        IndicatorUtils.isCloseAboveYesterdayHighByPctAndYesterdayBullish(
          candles,
        );
    if (!is2PcChange) failedReasons.add("2% Up + Yesterday Bullish failed");

    // FINAL RESULT
    bool result =
        isVolumeOk &&
        aboveEma20 &&
        rsiOk &&
        aboveVwap &&
        aboveSupertrend &&
        adxRes &&
        atrOk &&
        is2PcChange &&
        isVolumeBreakout;

    // 🔥 Print only when exactly ONE condition failed
    if (failedReasons.length == 1) {
      log(
        "⚠️ $token — Only 1 Less Failed: ${failedReasons} : ${candles.last.timestamp}",
      );
    }
    return result;
  }

  /// 🔹 Main multi-timeframe validation
  static Future<bool> isPassAllTimeFrame(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
  ) async {
    final is5MinPass = await isPassHistoryChart(historyCandles, stock, 5);
    if (!is5MinPass) return false;

    final is15MinPass = await isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 15),
      ),
      stock,
      15,
    );
    if (!is15MinPass) return false;

    final is30MinPass = await isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 30),
      ),
      stock,
      30,
    );
    if (!is30MinPass) return false;

    final is1HourPass = await isPassHistoryChart(
      Utilities.resampleCandles(
        historyCandles ?? [],
        const Duration(minutes: 60),
      ),
      stock,
      60,
    );
    if (!is1HourPass) return false;

    final isDayPass = await isPassHistoryChart(
      Utilities.convertToDaily(historyCandles ?? []),
      stock,
      1,
    );
    if (!isDayPass) return false;

    // final isMeetPercent = IndicatorUtils.isCloseAboveYesterdayCloseByPctAndYesterdayBullish(
    //   historyCandles ?? [],
    // );
    // if (!isMeetPercent) return false;

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
      case 60:
        bool isEma20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        return isEma20;

      case 1:
        bool isEMA20 =
            IndicatorUtils.isCloseAboveEMA(historyCandles, 20).isPassed;
        bool aboveSupertrend =
            IndicatorUtils.isCloseAboveSupertrend(
              historyCandles,
              atrPeriod: 10,
            ).isPassed;
        bool rsiOk = IndicatorUtils.isRsiBetween(
          historyCandles,
          14,
          min: 50,
          max: 70,
        );
        return isEMA20 && aboveSupertrend && rsiOk;

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

    if (lastPrice <= 20 || lastPrice >= 2500) return false;
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
      if (volume <= 15000) return false;
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
    final isWorkingDay =
        lastWorking.year == now.year &&
        lastWorking.month == now.month &&
        lastWorking.day == now.day;

    if (isWorkingDay) {
      if (volume <= 15000) return false;
    }

    return true;
  }

  static bool passedDayFilter(List<HistoricalDataModel> candles, String token) {
    List<String> failedReasons = [];

    bool aboveEma20 = IndicatorUtils.isCloseAboveEMA(candles, 20).isPassed;
    if (!aboveEma20) failedReasons.add("Close NOT above EMA20");

    bool rsiOk = IndicatorUtils.isRsiBetween(candles, 14, min: 55, max: 95);
    if (!rsiOk) failedReasons.add("RSI not between 60–95");

    bool atrOk = IndicatorUtils.isAtrGreaterThanAdaptive(candles);
    if (!atrOk) failedReasons.add("ATR not greater than adaptive threshold");

    bool aboveVwap = IndicatorUtils.isCloseAboveVWAP(candles);
    if (!aboveVwap) failedReasons.add("Close NOT above VWAP");

    bool aboveSupertrend =
        IndicatorUtils.isCloseAboveSupertrend(
          candles,
          atrPeriod: 10,
          multiplier: 3,
        ).isPassed;
    if (!aboveSupertrend) failedReasons.add("Close NOT above Supertrend");

    bool adxRes = IndicatorUtils.isAdxBullish(candles);
    if (!adxRes) failedReasons.add("ADX NOT bullish");

    // bool isVolumeOk = IndicatorUtils.isVolumeOk(candles);
    // if (!isVolumeOk) {
    //   failedReasons.add("Volume NOT > 15000 (vol=$isVolumeOk)");
    // }

    // bool isNearBuyingZone = IndicatorUtils.isNearEMA20OrSupertrendAutoForDay(
    //   candles,
    // );
    // if (!isNearBuyingZone) {
    //   failedReasons.add("Not near EMA20 or Supertrend for Day");
    // }

    bool isVolumeBreakout = IndicatorUtils.isVolumeBreakoutStrong(candles);
    if (!isVolumeBreakout) failedReasons.add("Volume breakout weak");

    // bool is2PcChange =
    //     IndicatorUtils.isCloseAboveYesterdayHighByPctAndYesterdayBullish(
    //       candles,
    //     );
    // if (!is2PcChange) failedReasons.add("2% Up + Yesterday Bullish failed");

    // FINAL RESULT
    bool result = aboveEma20 && rsiOk && aboveSupertrend && adxRes && atrOk;
    isVolumeBreakout;
    return result;
  }

  static bool isDayTradable(StockModel stock) {
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

    if (lastPrice <= 20 || lastPrice >= 200) return false;
    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) return false;
    if (lastPrice <= close) return false;

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
      if (volume <= 4000000) return false;
    }
    return true;
  }
}
