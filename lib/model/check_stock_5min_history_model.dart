class CheckStock5MinHistoryResponse {
  final bool success;
  final String message;
  final Stock5MinHistoryData? data;

  CheckStock5MinHistoryResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CheckStock5MinHistoryResponse.fromJson(Map<String, dynamic> json) {
    return CheckStock5MinHistoryResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null && json['data'] is Map<String, dynamic>
          ? Stock5MinHistoryData.fromJson(json['data'])
          : null,
    );
  }
}

class Stock5MinHistoryData {
  final String symbol;
  final dynamic token;
  final String targetDate;
  final bool overallPassed;
  final int total5MinCandles;
  final int passed5MinCandlesCount;
  final int failed5MinCandlesCount;
  final List<String> overallFailureReasons;
  final DailyTimeframeDetail? dailyTimeframe;
  final List<DailyCandleItem> dailyCandles;
  final List<FiveMinCandleItem> fiveMinCandles;

  Stock5MinHistoryData({
    required this.symbol,
    this.token,
    required this.targetDate,
    required this.overallPassed,
    required this.total5MinCandles,
    required this.passed5MinCandlesCount,
    required this.failed5MinCandlesCount,
    required this.overallFailureReasons,
    this.dailyTimeframe,
    required this.dailyCandles,
    required this.fiveMinCandles,
  });

  factory Stock5MinHistoryData.fromJson(Map<String, dynamic> json) {
    var failReasonsJson = json['overallFailureReasons'] as List? ?? [];
    List<String> failReasons = failReasonsJson.map((e) => e.toString()).toList();

    var dCandlesJson = json['dailyCandles'] as List? ?? [];
    List<DailyCandleItem> dCandles = dCandlesJson
        .whereType<Map<String, dynamic>>()
        .map((e) => DailyCandleItem.fromJson(e))
        .toList();

    var fCandlesJson = json['fiveMinCandles'] as List? ?? [];
    List<FiveMinCandleItem> fCandles = fCandlesJson
        .whereType<Map<String, dynamic>>()
        .map((e) => FiveMinCandleItem.fromJson(e))
        .toList();

    return Stock5MinHistoryData(
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      targetDate: json['targetDate']?.toString() ?? '',
      overallPassed: json['overallPassed'] == true,
      total5MinCandles: json['total5MinCandles'] is num
          ? (json['total5MinCandles'] as num).toInt()
          : 0,
      passed5MinCandlesCount: json['passed5MinCandlesCount'] is num
          ? (json['passed5MinCandlesCount'] as num).toInt()
          : 0,
      failed5MinCandlesCount: json['failed5MinCandlesCount'] is num
          ? (json['failed5MinCandlesCount'] as num).toInt()
          : 0,
      overallFailureReasons: failReasons,
      dailyTimeframe: json['dailyTimeframe'] != null &&
              json['dailyTimeframe'] is Map<String, dynamic>
          ? DailyTimeframeDetail.fromJson(json['dailyTimeframe'])
          : null,
      dailyCandles: dCandles,
      fiveMinCandles: fCandles,
    );
  }
}

class DailyTimeframeDetail {
  final bool passed;
  final String symbol;
  final dynamic token;
  final double? stockPrice;
  final double? previousDailySupertrend;
  final double? ema20;
  final double? ema50;
  final double? ema200;
  final double? nearestResistancePrice;
  final int? nearestResistanceTouches;
  final double? distanceToResistancePercent;
  final List<String> reasons;
  final Map<String, dynamic>? checks;
  final List<dynamic> topResistances;
  final List<dynamic> topSupports;

  DailyTimeframeDetail({
    required this.passed,
    required this.symbol,
    this.token,
    this.stockPrice,
    this.previousDailySupertrend,
    this.ema20,
    this.ema50,
    this.ema200,
    this.nearestResistancePrice,
    this.nearestResistanceTouches,
    this.distanceToResistancePercent,
    required this.reasons,
    this.checks,
    required this.topResistances,
    required this.topSupports,
  });

  factory DailyTimeframeDetail.fromJson(Map<String, dynamic> json) {
    var rJson = json['reasons'] as List? ?? [];
    List<String> reasonList = rJson.map((e) => e.toString()).toList();

    return DailyTimeframeDetail(
      passed: json['passed'] == true,
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      stockPrice: json['stockPrice'] is num ? (json['stockPrice'] as num).toDouble() : null,
      previousDailySupertrend: json['previousDailySupertrend'] is num
          ? (json['previousDailySupertrend'] as num).toDouble()
          : null,
      ema20: json['ema20'] is num ? (json['ema20'] as num).toDouble() : null,
      ema50: json['ema50'] is num ? (json['ema50'] as num).toDouble() : null,
      ema200: json['ema200'] is num ? (json['ema200'] as num).toDouble() : null,
      nearestResistancePrice: json['nearestResistancePrice'] is num
          ? (json['nearestResistancePrice'] as num).toDouble()
          : null,
      nearestResistanceTouches: json['nearestResistanceTouches'] is num
          ? (json['nearestResistanceTouches'] as num).toInt()
          : null,
      distanceToResistancePercent: json['distanceToResistancePercent'] is num
          ? (json['distanceToResistancePercent'] as num).toDouble()
          : null,
      reasons: reasonList,
      checks: json['checks'] is Map<String, dynamic> ? json['checks'] : null,
      topResistances: json['topResistances'] as List? ?? [],
      topSupports: json['topSupports'] as List? ?? [],
    );
  }
}

class DailyCandleItem {
  final String? time;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? ema20;
  final double? supertrend;

  DailyCandleItem({
    this.time,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.ema20,
    this.supertrend,
  });

  factory DailyCandleItem.fromJson(Map<String, dynamic> json) {
    return DailyCandleItem(
      time: json['time']?.toString(),
      open: json['open'] is num ? (json['open'] as num).toDouble() : null,
      high: json['high'] is num ? (json['high'] as num).toDouble() : null,
      low: json['low'] is num ? (json['low'] as num).toDouble() : null,
      close: json['close'] is num ? (json['close'] as num).toDouble() : null,
      volume: json['volume'] is num ? (json['volume'] as num).toDouble() : null,
      ema20: json['ema20'] is num ? (json['ema20'] as num).toDouble() : null,
      supertrend: json['supertrend'] is num ? (json['supertrend'] as num).toDouble() : null,
    );
  }
}

class FiveMinCandleItem {
  final String? time;
  final String? timeIst;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? ema20;
  final double? supertrend;
  final double? rsi;
  final double? atr;
  final double? adx;
  final double? plusDI;
  final double? minusDI;
  final double? vwap;
  final bool passed;
  final List<String> failureReasons;
  final Map<String, dynamic>? checks;

  FiveMinCandleItem({
    this.time,
    this.timeIst,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.ema20,
    this.supertrend,
    this.rsi,
    this.atr,
    this.adx,
    this.plusDI,
    this.minusDI,
    this.vwap,
    required this.passed,
    required this.failureReasons,
    this.checks,
  });

  factory FiveMinCandleItem.fromJson(Map<String, dynamic> json) {
    var fReasonsJson = json['failureReasons'] as List? ?? [];
    List<String> fReasons = fReasonsJson.map((e) => e.toString()).toList();

    return FiveMinCandleItem(
      time: json['time']?.toString(),
      timeIst: json['timeIst']?.toString(),
      open: json['open'] is num ? (json['open'] as num).toDouble() : null,
      high: json['high'] is num ? (json['high'] as num).toDouble() : null,
      low: json['low'] is num ? (json['low'] as num).toDouble() : null,
      close: json['close'] is num ? (json['close'] as num).toDouble() : null,
      volume: json['volume'] is num ? (json['volume'] as num).toDouble() : null,
      ema20: json['ema20'] is num ? (json['ema20'] as num).toDouble() : null,
      supertrend: json['supertrend'] is num ? (json['supertrend'] as num).toDouble() : null,
      rsi: json['rsi'] is num ? (json['rsi'] as num).toDouble() : null,
      atr: json['atr'] is num ? (json['atr'] as num).toDouble() : null,
      adx: json['adx'] is num ? (json['adx'] as num).toDouble() : null,
      plusDI: json['plusDI'] is num ? (json['plusDI'] as num).toDouble() : null,
      minusDI: json['minusDI'] is num ? (json['minusDI'] as num).toDouble() : null,
      vwap: json['vwap'] is num ? (json['vwap'] as num).toDouble() : null,
      passed: json['passed'] == true,
      failureReasons: fReasons,
      checks: json['checks'] is Map<String, dynamic> ? json['checks'] : null,
    );
  }
}
