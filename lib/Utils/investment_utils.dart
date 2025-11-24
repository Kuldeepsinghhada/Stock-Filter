import 'dart:developer';

import 'package:stock_demo/Utils/indicators.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/indicator_status.dart';
import 'package:stock_demo/model/stock_model.dart';

class InvestmentFilterModule {

  /// 🔹 Checks if all core indicator filters are passed
  static bool checkForDay(List<HistoricalDataModel> candles, StockModel model) {
    if (candles.length < 55) return false;

    // 1. Take last 250 candles
    final List<HistoricalDataModel> last250 = candles.sublist(
      candles.length - 55,
    );

    final int lastIndex = last250.length - 1; // 249
    final int firstIndex = lastIndex - 19; // 249 - 9 = 240

    // 2. Loop in REVERSE order: 249 → 240
    for (int i = lastIndex; i >= firstIndex; i--) {
      // Slice candles only till "i"
      final slice = last250.sublist(0, i + 1);

      // 3. Check filter
      if (isInvestmentCandidate(slice, model)) {
        return true; // Any candle passes = success
      }
    }
    return false; // None passed
  }


  /// MAIN: Pass all timeframes for Investment (Swing 3–15 days)
  static bool isInvestmentCandidate(
    List<HistoricalDataModel> historyCandles,
    StockModel stock,
  ) {
    if (historyCandles.isEmpty) return false;

    // Create required timeframe candles
    final candles15 = Utilities.resampleCandles(
      historyCandles,
      Duration(minutes: 15),
    );
    final candles30 = Utilities.resampleCandles(
      historyCandles,
      Duration(minutes: 30),
    );
    final candles60 = Utilities.resampleCandles(
      historyCandles,
      Duration(minutes: 60),
    );
    final daily = Utilities.convertToDaily(historyCandles);

    // ---------- TIMEFRAME VALIDATIONS ----------
    if (!is15mBullish(candles15)) {
      log("❌ 15m Trend Weak → ${stock.symbol}");
      return false;
    }

    if (!is30mTrendValid(candles30)) {
      log("❌ 30m Trend Weak → ${stock.symbol}");
      return false;
    }

    if (!is60mStrongTrend(candles60)) {
      log("❌ 60m Trend/ADX Weak → ${stock.symbol}");
      return false;
    }

    if (!isDailyBullish(daily)) {
      log("❌ Daily Trend Weak → ${stock.symbol}");
      return false;
    }
    //
    if (!hasDailyVolumeBreakout(candles60)) {
      log("❌ No Daily Volume Push → ${stock.symbol}");
      return false;
    }

    // if (!isAtrSafe(daily)) {
    //   log("❌ ATR too high (risky stock) → ${stock.symbol}");
    //   return false;
    // }

    log("✅ Investment Candidate: ${stock.symbol}");
    return true;
  }

  // -----------------------------------------------------
  // ------------ TIMEFRAME LEVEL CHECKS -----------------
  // -----------------------------------------------------

  /// 15m: Early trend confirmation
  static bool is15mBullish(List<HistoricalDataModel> candles) {
    var isAboveEMA = IndicatorUtils.isCloseAboveEMA(candles, 20);
    var isAboveSuperTrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 10,
    );
    return isAboveEMA.status && isAboveSuperTrend;
  }

  /// 30m: Optional mid-trend; just basic trend check
  static bool is30mTrendValid(List<HistoricalDataModel> candles) {
    var isAboveEMA = IndicatorUtils.isCloseAboveEMA(candles, 20);
    return isAboveEMA.status;
  }

  /// 60m: MOST IMPORTANT in swing trading
  static bool is60mStrongTrend(List<HistoricalDataModel> candles) {
    IndicatorStatus ema = IndicatorUtils.isCloseAboveEMA(candles, 20);
    return ema.status;
  }

  /// DAILY: Strong bullish structure for investment
  static bool isDailyBullish(List<HistoricalDataModel> candles) {
    var ema20 = IndicatorUtils.isCloseAboveEMA(candles, 20);
    var ema50 = IndicatorUtils.isCloseAboveEMA(candles, 50);
    var aboveSuperTrend = IndicatorUtils.isCloseAboveSupertrend(
      candles,
      atrPeriod: 10,
    );
    var dailyBullish = IndicatorUtils.isDailyCandleBullish(candles);
    var rsi = IndicatorUtils.isRsiBetween(candles, 14, min: 50, max: 70);
    bool adx = IndicatorUtils.isAdxBullish(candles, minAdx: 20);

    return ema20.status &&
        ema50.status &&
        aboveSuperTrend &&
        dailyBullish &&
        rsi && adx; // avoid overbought
  }

  /// Daily volume breakout
  static bool hasDailyVolumeBreakout(List<HistoricalDataModel> candles) {
    return IndicatorUtils.isVolumeBreakout(candles,factor: 1.3);
  }

  /// ATR risk check (swing safe zone)
  static bool isAtrSafe(List<HistoricalDataModel> candles) {
    return IndicatorUtils.isAtrHealthy(
      candles,
      atrPeriod: 14,
      minAtrPct: 0.004, // 0.4%
      maxAtrPct: 0.03, // 3%
    );
  }
}
