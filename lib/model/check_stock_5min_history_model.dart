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
  final String? previousTradingDate;
  final bool overallPassed;
  final int total5MinCandles;
  final int passed5MinCandlesCount;
  final int failed5MinCandlesCount;
  final double? prevDayAvg5MinVolume;
  final List<String> overallFailureReasons;
  final DailyContextDetail? dailyContext;
  final List<DailyCandleItem> dailyCandles;
  final List<FiveMinCandleItem> fiveMinCandles;

  Stock5MinHistoryData({
    required this.symbol,
    this.token,
    required this.targetDate,
    this.previousTradingDate,
    required this.overallPassed,
    required this.total5MinCandles,
    required this.passed5MinCandlesCount,
    required this.failed5MinCandlesCount,
    this.prevDayAvg5MinVolume,
    required this.overallFailureReasons,
    this.dailyContext,
    required this.dailyCandles,
    required this.fiveMinCandles,
  });

  factory Stock5MinHistoryData.fromJson(Map<String, dynamic> json) {
    var dContextJson = json['dailyContext'] ?? json['dailyTimeframe'];
    DailyContextDetail? dContext = dContextJson is Map<String, dynamic>
        ? DailyContextDetail.fromJson(dContextJson)
        : null;

    var dCandlesJson = json['dailyCandles'] as List? ?? [];
    List<DailyCandleItem> dCandles = dCandlesJson
        .whereType<Map<String, dynamic>>()
        .map((e) => DailyCandleItem.fromJson(e))
        .toList();

    var fCandlesJson = json['candles'] ?? json['fiveMinCandles'];
    List<FiveMinCandleItem> fCandles = [];
    if (fCandlesJson is List) {
      fCandles = fCandlesJson
          .whereType<Map<String, dynamic>>()
          .map((e) => FiveMinCandleItem.fromJson(e))
          .toList();
    }

    int passedCount = json['passed5MinCandlesCount'] is num
        ? (json['passed5MinCandlesCount'] as num).toInt()
        : fCandles.where((c) => c.passed).length;

    int failedCount = json['failed5MinCandlesCount'] is num
        ? (json['failed5MinCandlesCount'] as num).toInt()
        : fCandles.where((c) => !c.passed).length;

    bool passedRoot = json.containsKey('overallPassed')
        ? json['overallPassed'] == true
        : (passedCount > 0 && (dContext?.dailyPassedFilter ?? true));

    var failReasonsJson = json['overallFailureReasons'] as List? ?? [];
    List<String> failReasons = failReasonsJson.map((e) => e.toString()).toList();
    if (failReasons.isEmpty && dContext != null && dContext.dailyReasons.isNotEmpty) {
      failReasons.addAll(dContext.dailyReasons);
    }

    return Stock5MinHistoryData(
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      targetDate: json['targetDate']?.toString() ?? '',
      previousTradingDate: json['previousTradingDate']?.toString(),
      overallPassed: passedRoot,
      total5MinCandles: json['total5MinCandles'] is num
          ? (json['total5MinCandles'] as num).toInt()
          : fCandles.length,
      passed5MinCandlesCount: passedCount,
      failed5MinCandlesCount: failedCount,
      prevDayAvg5MinVolume: json['prevDayAvg5MinVolume'] is num
          ? (json['prevDayAvg5MinVolume'] as num).toDouble()
          : null,
      overallFailureReasons: failReasons,
      dailyContext: dContext,
      dailyCandles: dCandles,
      fiveMinCandles: fCandles,
    );
  }
}

class ResistanceSupportItem {
  final double price;
  final int touches;
  final double? strengthScore;

  ResistanceSupportItem({
    required this.price,
    required this.touches,
    this.strengthScore,
  });

  factory ResistanceSupportItem.fromJson(Map<String, dynamic> json) {
    return ResistanceSupportItem(
      price: json['price'] is num ? (json['price'] as num).toDouble() : 0.0,
      touches: json['touches'] is num ? (json['touches'] as num).toInt() : 0,
      strengthScore: json['strengthScore'] is num
          ? (json['strengthScore'] as num).toDouble()
          : null,
    );
  }
}

class DailyContextDetail {
  final bool dailyPassedFilter;
  final String symbol;
  final dynamic token;
  final double? stockPrice;
  final double? latestDailyClose;
  final String? previousDayDate;
  final double? previousDayVolume;
  final double? previousDayOpen;
  final double? previousDayHigh;
  final double? previousDayLow;
  final double? previousDayClose;
  final double? dailyEma20;
  final double? dailyEma50;
  final double? dailyEma200;
  final double? dailySupertrend;
  final double? previousDailySupertrend;
  final double? nearestResistancePrice;
  final int? nearestResistanceTouches;
  final double? distanceToResistancePercent;
  final List<String> dailyReasons;
  final List<ResistanceSupportItem> topResistances;
  final List<ResistanceSupportItem> topSupports;
  final Map<String, dynamic>? checks;

  DailyContextDetail({
    required this.dailyPassedFilter,
    required this.symbol,
    this.token,
    this.stockPrice,
    this.latestDailyClose,
    this.previousDayDate,
    this.previousDayVolume,
    this.previousDayOpen,
    this.previousDayHigh,
    this.previousDayLow,
    this.previousDayClose,
    this.dailyEma20,
    this.dailyEma50,
    this.dailyEma200,
    this.dailySupertrend,
    this.previousDailySupertrend,
    this.nearestResistancePrice,
    this.nearestResistanceTouches,
    this.distanceToResistancePercent,
    required this.dailyReasons,
    required this.topResistances,
    required this.topSupports,
    this.checks,
  });

  factory DailyContextDetail.fromJson(Map<String, dynamic> json) {
    var dReasonsJson = json['dailyReasons'] ?? json['reasons'];
    List<String> reasonList = [];
    if (dReasonsJson is List) {
      reasonList = dReasonsJson.map((e) => e.toString()).toList();
    }

    var topResJson = json['topResistances'] as List? ?? [];
    List<ResistanceSupportItem> topRes = topResJson
        .whereType<Map<String, dynamic>>()
        .map((e) => ResistanceSupportItem.fromJson(e))
        .toList();

    var topSupJson = json['topSupports'] as List? ?? [];
    List<ResistanceSupportItem> topSup = topSupJson
        .whereType<Map<String, dynamic>>()
        .map((e) => ResistanceSupportItem.fromJson(e))
        .toList();

    bool passedVal = json.containsKey('dailyPassedFilter')
        ? json['dailyPassedFilter'] == true
        : json['passed'] == true;

    return DailyContextDetail(
      dailyPassedFilter: passedVal,
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      stockPrice: json['stockPrice'] is num
          ? (json['stockPrice'] as num).toDouble()
          : (json['latestDailyClose'] is num ? (json['latestDailyClose'] as num).toDouble() : null),
      latestDailyClose: json['latestDailyClose'] is num ? (json['latestDailyClose'] as num).toDouble() : null,
      previousDayDate: json['previousDayDate']?.toString(),
      previousDayVolume: json['previousDayVolume'] is num ? (json['previousDayVolume'] as num).toDouble() : null,
      previousDayOpen: json['previousDayOpen'] is num ? (json['previousDayOpen'] as num).toDouble() : null,
      previousDayHigh: json['previousDayHigh'] is num ? (json['previousDayHigh'] as num).toDouble() : null,
      previousDayLow: json['previousDayLow'] is num ? (json['previousDayLow'] as num).toDouble() : null,
      previousDayClose: json['previousDayClose'] is num ? (json['previousDayClose'] as num).toDouble() : null,
      dailyEma20: json['dailyEma20'] is num
          ? (json['dailyEma20'] as num).toDouble()
          : (json['ema20'] is num ? (json['ema20'] as num).toDouble() : null),
      dailyEma50: json['dailyEma50'] is num
          ? (json['dailyEma50'] as num).toDouble()
          : (json['ema50'] is num ? (json['ema50'] as num).toDouble() : null),
      dailyEma200: json['dailyEma200'] is num
          ? (json['dailyEma200'] as num).toDouble()
          : (json['ema200'] is num ? (json['ema200'] as num).toDouble() : null),
      dailySupertrend: json['dailySupertrend'] is num
          ? (json['dailySupertrend'] as num).toDouble()
          : (json['supertrend'] is num ? (json['supertrend'] as num).toDouble() : null),
      previousDailySupertrend: json['previousDailySupertrend'] is num
          ? (json['previousDailySupertrend'] as num).toDouble()
          : null,
      nearestResistancePrice: json['nearestResistancePrice'] is num
          ? (json['nearestResistancePrice'] as num).toDouble()
          : null,
      nearestResistanceTouches: json['nearestResistanceTouches'] is num
          ? (json['nearestResistanceTouches'] as num).toInt()
          : null,
      distanceToResistancePercent: json['distanceToResistancePercent'] is num
          ? (json['distanceToResistancePercent'] as num).toDouble()
          : null,
      dailyReasons: reasonList,
      topResistances: topRes,
      topSupports: topSup,
      checks: json['checks'] is Map<String, dynamic> ? json['checks'] : null,
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
  final double? ema50;
  final double? ema200;
  final String? emaAlignment;
  final double? supertrend;
  final String? supertrendSignal;
  final double? rsi;
  final String? rsiState;
  final double? atr;
  final double? adx;
  final double? plusDI;
  final double? minusDI;
  final double? vwap;
  final String? priceVsVwap;
  final double? avgVolume20;
  final double? prevDayAvg5MinVolume;
  final double? volumeMultiplierVsPrevDayAvg;
  final bool? isVolume4xPlus;
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
    this.ema50,
    this.ema200,
    this.emaAlignment,
    this.supertrend,
    this.supertrendSignal,
    this.rsi,
    this.rsiState,
    this.atr,
    this.adx,
    this.plusDI,
    this.minusDI,
    this.vwap,
    this.priceVsVwap,
    this.avgVolume20,
    this.prevDayAvg5MinVolume,
    this.volumeMultiplierVsPrevDayAvg,
    this.isVolume4xPlus,
    required this.passed,
    required this.failureReasons,
    this.checks,
  });

  factory FiveMinCandleItem.fromJson(Map<String, dynamic> json) {
    var fReasonsJson = json['reasons'] ?? json['failureReasons'];
    List<String> fReasons = [];
    if (fReasonsJson is List) {
      fReasons = fReasonsJson.map((e) => e.toString()).toList();
    }

    double? pDI = json['plus_di'] is num
        ? (json['plus_di'] as num).toDouble()
        : (json['plusDI'] is num ? (json['plusDI'] as num).toDouble() : null);

    double? mDI = json['minus_di'] is num
        ? (json['minus_di'] as num).toDouble()
        : (json['minusDI'] is num ? (json['minusDI'] as num).toDouble() : null);

    return FiveMinCandleItem(
      time: json['time']?.toString(),
      timeIst: json['timeIst']?.toString(),
      open: json['open'] is num ? (json['open'] as num).toDouble() : null,
      high: json['high'] is num ? (json['high'] as num).toDouble() : null,
      low: json['low'] is num ? (json['low'] as num).toDouble() : null,
      close: json['close'] is num ? (json['close'] as num).toDouble() : null,
      volume: json['volume'] is num ? (json['volume'] as num).toDouble() : null,
      ema20: json['ema20'] is num ? (json['ema20'] as num).toDouble() : null,
      ema50: json['ema50'] is num ? (json['ema50'] as num).toDouble() : null,
      ema200: json['ema200'] is num ? (json['ema200'] as num).toDouble() : null,
      emaAlignment: json['emaAlignment']?.toString(),
      supertrend: json['supertrend'] is num ? (json['supertrend'] as num).toDouble() : null,
      supertrendSignal: json['supertrendSignal']?.toString(),
      rsi: json['rsi'] is num ? (json['rsi'] as num).toDouble() : null,
      rsiState: json['rsiState']?.toString(),
      atr: json['atr'] is num ? (json['atr'] as num).toDouble() : null,
      adx: json['adx'] is num ? (json['adx'] as num).toDouble() : null,
      plusDI: pDI,
      minusDI: mDI,
      vwap: json['vwap'] is num ? (json['vwap'] as num).toDouble() : null,
      priceVsVwap: json['priceVsVwap']?.toString(),
      avgVolume20: json['avgVolume20'] is num ? (json['avgVolume20'] as num).toDouble() : null,
      prevDayAvg5MinVolume: json['prevDayAvg5MinVolume'] is num
          ? (json['prevDayAvg5MinVolume'] as num).toDouble()
          : null,
      volumeMultiplierVsPrevDayAvg: json['volumeMultiplierVsPrevDayAvg'] is num
          ? (json['volumeMultiplierVsPrevDayAvg'] as num).toDouble()
          : null,
      isVolume4xPlus: json['isVolume4xPlus'] is bool ? json['isVolume4xPlus'] : null,
      passed: json['passed'] == true,
      failureReasons: fReasons,
      checks: json['checks'] is Map<String, dynamic> ? json['checks'] : null,
    );
  }
}
