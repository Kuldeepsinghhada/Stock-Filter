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

    Map<String, bool> adxRes = IndicatorUtils.adxConditions(
      highs,
      lows,
      closes,
      14,
      15,
    );

    var isVolumeOk = volumes.isNotEmpty ? volumes.last > 30000 : false;

    if (token == "1843201") {
      print("Above EMA 20: $aboveEma20");
      print("RSI OK: $rsiOk");
      print("ATR OK: $atrOk");
      print("Above VWAP: $aboveVwap");
      print("Above Supertrend: $aboveSupertrend");
      print("ADX +DI > -DI: ${adxRes["plusGreater"]}");
      var result =
          aboveEma20 &&
          rsiOk &&
          atrOk &&
          aboveVwap &&
          aboveSupertrend &&
          adxRes["plusGreater"]!;
      print(result.toString());
    }

    return isVolumeOk &&
        aboveEma20 &&
        rsiOk &&
        atrOk &&
        aboveVwap &&
        aboveSupertrend &&
        adxRes["plusGreater"]!;
  }
}


