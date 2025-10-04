import 'dart:developer';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/stock_model.dart';
import 'indicators.dart';

class FilterUtils {
  static bool passesFilter(
    List<double> highs,
    List<double> lows,
    List<double> closes,
    List<int> volumes,
    String token,
  ) {
    bool aboveEma20 = IndicatorUtils.isAboveEMA(closes, 20);
    bool rsiOk = IndicatorUtils.isRsiBetween(closes, 14, 50, 85);

    bool atrOk = IndicatorUtils.isAtrGreaterThan(
      highs,
      lows,
      closes,
      14,
      closes.last * 0.003,
    );
    bool aboveVwap = IndicatorUtils.isCloseAboveVWAP(
      highs,
      lows,
      closes,
      volumes,
    );

    bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
      highs,
      lows,
      closes,
      9,
      3,
    );

    bool adxRes = IndicatorUtils.isADXConditions(highs, lows, closes);

    var isVolumeOk = volumes.isNotEmpty ? volumes.last > 30000 : false;

    return isVolumeOk &&
        aboveEma20 &&
        rsiOk &&
        atrOk &&
        //aboveVwap &&
        aboveSupertrend &&
        adxRes;
  }

  static Future<bool> isPassAllTimeFrame(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
  ) async {
    final is5MinPass = await isPassHistoryChart(historyCandles, stock, 5);
    if (!is5MinPass) return false;
    final is15MinPass = await isPassHistoryChart(
      Utilities.resampleCandles(historyCandles ?? [], Duration(minutes: 15)),
      stock,
      15,
    );
    if (!is15MinPass) return false;
    final is30MinPass = await isPassHistoryChart(
      Utilities.resampleCandles(historyCandles ?? [], Duration(minutes: 30)),
      stock,
      30,
    );
    if (!is30MinPass) return false;
    final is1HourPass = await isPassHistoryChart(
      Utilities.resampleCandles(historyCandles ?? [], Duration(minutes: 60)),
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

    final isMeetPercent = IndicatorUtils.checkAbove2PercentThenLastDayClose(
      historyCandles ?? [],
    );
    if (!isMeetPercent) return false;

    log("Stock Passed");
    return true;
  }

  static Future<bool> isPassHistoryChart(
    List<HistoricalDataModel>? historyCandles,
    StockModel stock,
    int timeFrame,
  ) async {
    // Parse highs, lows, closes, volumes from historicalData
    List<double> highs = historyCandles?.map((e) => e.high).toList() ?? [];
    List<double> lows = historyCandles?.map((e) => e.low).toList() ?? [];
    List<double> closes = historyCandles?.map((e) => e.close).toList() ?? [];
    List<int> volumes = historyCandles?.map((e) => e.volume).toList() ?? [];

    if (timeFrame == 5) {
      bool isPass = FilterUtils.passesFilter(
        highs,
        lows,
        closes,
        volumes,
        stock.token.toString(),
      );
      bool isVolumeBreakout = IndicatorUtils.isVolumeBreakout(
        historyCandles ?? [],
      );
      return isPass && isVolumeBreakout;
    } else if (timeFrame == 15) {
      // For 15 min, only check EMA and RSI
      bool isEma20 = IndicatorUtils.isAboveEMA(closes, 20);
      // bool isVolumeBreakout = IndicatorUtils.isVolumeBreakout(historyCandles ?? []);
      //bool isRsiOk = IndicatorUtils.isRsiBetween(closes, 14, 50, 85);
      //bool isPass = isEma20 && isRsiOk;
      return isEma20;
    } else if (timeFrame == 30) {
      // For 30 min, only check EMA and RSI
      bool isEma20 = IndicatorUtils.isAboveEMA(closes, 20);
      // bool isRsiOk = IndicatorUtils.isRsiBetween(closes, 14, 50, 85);
      // bool isPass = isEma20 && isRsiOk;
      return isEma20;
    } else if (timeFrame == 60) {
      // For 1 hour, only check EMA and RSI
      bool isEma20 = IndicatorUtils.isAboveEMA(closes, 20);
      // bool isRsiOk = IndicatorUtils.isRsiBetween(closes, 14, 50, 85);
      // bool isPass = isEma20 && isRsiOk;
      return isEma20;
    } else if (timeFrame == 1) {
      bool isEMA20 = IndicatorUtils.isAboveEMA(closes, 20);
      bool aboveSupertrend = IndicatorUtils.isCloseAboveSupertrend(
        highs,
        lows,
        closes,
        9,
        3,
      );
      return isEMA20 && aboveSupertrend;
    }
    return false;
  }

  static bool isTradable(StockModel stock) {
    final lastPrice = stock.lastPrice;
    final lowerLimit = stock.lowerCircuitLimit;
    final upperLimit = stock.upperCircuitLimit;
    final ohlc = stock.ohlc;
    final close = ohlc?.close;
    final volume = stock.volume;
    final percentChange =
        ((stock.lastPrice! - stock.ohlc!.open!) / stock.ohlc!.open!) * 100;

    // 🛑 Null checks
    if (lastPrice == null) {
      // debugPrint("Rejected: lastPrice is null for ${stock.symbol}");
      return false;
    }
    if (close == null) {
      // debugPrint("Rejected: close price is null for ${stock.symbol}");
      return false;
    }
    if (lowerLimit == null || upperLimit == null) {
      // debugPrint("Rejected: circuit limits missing for ${stock.symbol}");
      return false;
    }
    if (volume == null) {
      // debugPrint("Rejected: volume is null for ${stock.symbol}");
      return false;
    }

    // Rule-based checks
    if (lastPrice <= 95 || lastPrice >= 1000) {
      // debugPrint(
      //   "Rejected: price $lastPrice not in [95, 1000] for ${stock.symbol}",
      // );
      return false;
    }

    if (lastPrice <= lowerLimit || lastPrice >= upperLimit) {
      // debugPrint(
      //   "Rejected: price $lastPrice outside circuit limits [$lowerLimit, $upperLimit] for ${stock.symbol}",
      // );
      return false;
    }

    if (lastPrice <= close) {
      // debugPrint(
      //   "Rejected: price $lastPrice not greater than close $close for ${stock.symbol}",
      // );
      return false;
    }

    if (percentChange <= 1.0) {
      // debugPrint(
      //   "Rejected: percent change $percentChange ≤ 1% for ${stock.symbol}",
      // );
      return false;
    }

    if (volume <= 40000) {
      //debugPrint("Rejected: low volume $volume ≤ 50000 for ${stock.symbol}");
      return false;
    }

    // 🎯 Passed all checks
    return true;
  }
}
