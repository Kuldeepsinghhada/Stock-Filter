class InvestmentResponse {
  final bool success;
  final String message;
  final InvestmentData? data;

  InvestmentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory InvestmentResponse.fromJson(Map<String, dynamic> json) {
    return InvestmentResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null ? InvestmentData.fromJson(json['data']) : null,
    );
  }
}

class InvestmentSummary {
  final int totalTrades;
  final int wins;
  final int losses;
  final int open;
  final String accuracy;
  final String totalPnlPercent;

  InvestmentSummary({
    required this.totalTrades,
    required this.wins,
    required this.losses,
    this.open = 0,
    required this.accuracy,
    required this.totalPnlPercent,
  });

  factory InvestmentSummary.fromJson(Map<String, dynamic> json) {
    return InvestmentSummary(
      totalTrades:
          json['totalTrades'] is num ? (json['totalTrades'] as num).toInt() : 0,
      wins: json['wins'] is num ? (json['wins'] as num).toInt() : 0,
      losses: json['losses'] is num ? (json['losses'] as num).toInt() : 0,
      open: json['open'] is num ? (json['open'] as num).toInt() : 0,
      accuracy: json['accuracy']?.toString() ?? '0%',
      totalPnlPercent: json['totalPnlPercent']?.toString() ?? '0%',
    );
  }
}

class InvestmentData {
  final int count;
  final double minAccuracyRequired;
  final String timeframe;
  final String strategy;
  final String strategyVersion;
  final bool? fromCache;
  final bool? isDaily;
  final String? cachedAt;
  final String? startDate;
  final String? endDate;
  final InvestmentSummary? summary;
  final List<InvestmentRecommendation> recommendations;
  final int? targetHitCount;
  final double? accuracyPercent;
  final double? totalProfit;

  InvestmentData({
    required this.count,
    required this.minAccuracyRequired,
    required this.timeframe,
    required this.strategy,
    required this.strategyVersion,
    this.fromCache,
    this.isDaily,
    this.cachedAt,
    this.startDate,
    this.endDate,
    this.summary,
    required this.recommendations,
    this.targetHitCount,
    this.accuracyPercent,
    this.totalProfit,
  });

  factory InvestmentData.fromJson(Map<String, dynamic> json) {
    var rawList = json['trades'] ?? json['recommendations'];
    var list = rawList is List ? rawList : [];
    List<InvestmentRecommendation> recs =
        list.map((r) => InvestmentRecommendation.fromJson(r)).toList();

    InvestmentSummary? summaryObj = json['summary'] != null
        ? InvestmentSummary.fromJson(json['summary'])
        : null;

    int totalCount = summaryObj?.totalTrades ??
        (json['count'] is num ? (json['count'] as num).toInt() : recs.length);

    int? targetWins = summaryObj?.wins ??
        (json['targetHitCount'] is num
            ? (json['targetHitCount'] as num).toInt()
            : json['targetCount'] is num
                ? (json['targetCount'] as num).toInt()
                : null);

    double? accPct;
    if (summaryObj?.accuracy != null) {
      final cleanAcc = summaryObj!.accuracy.replaceAll('%', '').trim();
      accPct = double.tryParse(cleanAcc);
    }
    accPct ??= json['accuracyPercent'] is num
        ? (json['accuracyPercent'] as num).toDouble()
        : json['accuracy'] is num
            ? (json['accuracy'] as num).toDouble()
            : null;

    double? totProf;
    if (summaryObj?.totalPnlPercent != null) {
      final cleanPnl = summaryObj!.totalPnlPercent.replaceAll('%', '').trim();
      totProf = double.tryParse(cleanPnl);
    }
    totProf ??= json['totalProfit'] is num
        ? (json['totalProfit'] as num).toDouble()
        : json['totalPnl'] is num
            ? (json['totalPnl'] as num).toDouble()
            : null;

    String stratVersionStr = json['strategyVersion']?.toString() ??
        json['strategy']?.toString() ??
        'Pure Daily EOD Backtest';

    return InvestmentData(
      count: totalCount,
      minAccuracyRequired: json['minAccuracyRequired'] is num
          ? (json['minAccuracyRequired'] as num).toDouble()
          : 0.0,
      timeframe: json['timeframe']?.toString() ?? 'Daily',
      strategy: stratVersionStr,
      strategyVersion: stratVersionStr,
      fromCache: json['fromCache'] is bool ? json['fromCache'] as bool : null,
      isDaily: json['isDaily'] is bool ? json['isDaily'] as bool : null,
      cachedAt: json['cachedAt']?.toString(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      summary: summaryObj,
      recommendations: recs,
      targetHitCount: targetWins,
      accuracyPercent: accPct,
      totalProfit: totProf,
    );
  }
}

class InvestmentRecommendation {
  final String symbol;
  final String? stockName;
  final dynamic token;
  final double entryPrice;
  final double targetPrice;
  final double stopLossPrice;
  final double? supportPrice;
  final double? supportDistPct;
  final double targetPercent;
  final double stopLossPercent;
  final double riskRewardRatio;
  final double accuracy;
  final String accuracyPercentage;
  final String timeframe;
  final String recommendationType;
  final String holdingPeriod;
  final String status;
  final String? exitReason;
  final String? winLoss;
  final double? exitPrice;
  final String? exitTime;
  final String? exitDate;
  final double? realizedPnlPercent;
  final String? realizedPnlPercentage;
  final String? patterns;
  final double? volumeMultiplier;
  final double? rsi;
  final double? ema20;
  final double? supertrend;
  final double? atr;
  final num? volume;
  final String? setupGrade;
  final int? holdingDays;
  final List<String> reasons;
  final InvestmentIndicators? indicators;
  final String createdAt;
  final String? date;
  final String? entryDate;
  final String? tradeDate;

  InvestmentRecommendation({
    required this.symbol,
    this.stockName,
    required this.token,
    required this.entryPrice,
    required this.targetPrice,
    required this.stopLossPrice,
    this.supportPrice,
    this.supportDistPct,
    required this.targetPercent,
    required this.stopLossPercent,
    required this.riskRewardRatio,
    required this.accuracy,
    required this.accuracyPercentage,
    required this.timeframe,
    required this.recommendationType,
    required this.holdingPeriod,
    required this.status,
    this.exitReason,
    this.winLoss,
    this.exitPrice,
    this.exitTime,
    this.exitDate,
    this.realizedPnlPercent,
    this.realizedPnlPercentage,
    this.patterns,
    this.volumeMultiplier,
    this.rsi,
    this.ema20,
    this.supertrend,
    this.atr,
    this.volume,
    this.setupGrade,
    this.holdingDays,
    required this.reasons,
    this.indicators,
    required this.createdAt,
    this.date,
    this.entryDate,
    this.tradeDate,
  });

  factory InvestmentRecommendation.fromJson(Map<String, dynamic> json) {
    var reasonsList = json['reasons'] as List? ?? [];
    List<String> parsedReasons = reasonsList.map((e) => e.toString()).toList();

    final entryP = json['entryPrice'] is num
        ? (json['entryPrice'] as num).toDouble()
        : 0.0;
    final targetP = json['targetPrice'] is num
        ? (json['targetPrice'] as num).toDouble()
        : json['target'] is num
            ? (json['target'] as num).toDouble()
            : 0.0;
    final stopLossP = json['stopLossPrice'] is num
        ? (json['stopLossPrice'] as num).toDouble()
        : json['stoploss'] is num
            ? (json['stoploss'] as num).toDouble()
            : 0.0;

    double targetPct = json['targetPercent'] is num
        ? (json['targetPercent'] as num).toDouble()
        : 0.0;
    if (targetPct == 0.0 && entryP > 0 && targetP > 0) {
      targetPct = ((targetP - entryP) / entryP * 100).abs();
    }

    double stopLossPct = json['stopLossPercent'] is num
        ? (json['stopLossPercent'] as num).toDouble()
        : 0.0;
    if (stopLossPct == 0.0 && entryP > 0 && stopLossP > 0) {
      stopLossPct = ((entryP - stopLossP) / entryP * 100).abs();
    }

    double rrRatio = json['riskRewardRatio'] is num
        ? (json['riskRewardRatio'] as num).toDouble()
        : 0.0;
    if (rrRatio == 0.0 && stopLossPct > 0) {
      rrRatio = double.parse((targetPct / stopLossPct).toStringAsFixed(2));
    }

    final realizedPnl = json['pnlPercent'] is num
        ? (json['pnlPercent'] as num).toDouble()
        : json['realizedPnlPercent'] is num
            ? (json['realizedPnlPercent'] as num).toDouble()
            : null;

    final realizedPnlStr = json['realizedPnlPercentage']?.toString() ??
        (realizedPnl != null
            ? '${realizedPnl >= 0 ? "+" : ""}${realizedPnl.toStringAsFixed(2)}%'
            : null);

    final String statusStr = json['status']?.toString() ??
        json['exitReason']?.toString() ??
        json['winLoss']?.toString() ??
        '';

    final String dateStr = json['date']?.toString() ??
        json['entryDate']?.toString() ??
        json['tradeDate']?.toString() ??
        json['targetDate']?.toString() ??
        '';

    final rsiVal = json['rsi'] is num ? (json['rsi'] as num).toDouble() : null;
    final ema20Val =
        json['ema20'] is num ? (json['ema20'] as num).toDouble() : null;
    final stVal = json['supertrend'] is num
        ? (json['supertrend'] as num).toDouble()
        : null;
    final atrVal = json['atr'] is num ? (json['atr'] as num).toDouble() : null;
    final volVal = json['volume'] is num ? (json['volume'] as num) : null;
    final volMultVal = json['volumeMultiplier'] is num
        ? (json['volumeMultiplier'] as num).toDouble()
        : null;
    final supPriceVal = json['supportPrice'] is num
        ? (json['supportPrice'] as num).toDouble()
        : null;
    final supDistVal = json['supportDistPct'] is num
        ? (json['supportDistPct'] as num).toDouble()
        : null;

    InvestmentIndicators? indObj;
    if (json['indicators'] != null) {
      indObj = InvestmentIndicators.fromJson(json['indicators']);
    } else if (rsiVal != null ||
        ema20Val != null ||
        stVal != null ||
        atrVal != null ||
        volMultVal != null ||
        supPriceVal != null) {
      indObj = InvestmentIndicators(
        symbol: json['symbol']?.toString() ?? '',
        token: json['token'],
        entryPrice: entryP,
        rsi: rsiVal,
        ema20: ema20Val,
        supertrend: stVal,
        atr: atrVal,
        volume: volVal,
        volumeRatio: volMultVal,
      );
    }

    return InvestmentRecommendation(
      symbol: json['symbol']?.toString() ?? json['stockName']?.toString() ?? '',
      stockName: json['stockName']?.toString(),
      token: json['token'],
      entryPrice: entryP,
      targetPrice: targetP,
      stopLossPrice: stopLossP,
      supportPrice: supPriceVal,
      supportDistPct: supDistVal,
      targetPercent: targetPct,
      stopLossPercent: stopLossPct,
      riskRewardRatio: rrRatio,
      accuracy: json['accuracy'] is num
          ? (json['accuracy'] as num).toDouble()
          : 0.0,
      accuracyPercentage: json['accuracyPercentage']?.toString() ?? '',
      timeframe: json['timeframe']?.toString() ?? 'Daily',
      recommendationType: json['recommendationType']?.toString() ??
          json['setupGrade']?.toString() ??
          'BUY',
      holdingPeriod: json['holdingPeriod']?.toString() ?? 'EOD Daily',
      status: statusStr,
      exitReason: json['exitReason']?.toString(),
      winLoss: json['winLoss']?.toString(),
      exitPrice: json['exitPrice'] is num
          ? (json['exitPrice'] as num).toDouble()
          : null,
      exitTime: json['exitTime']?.toString(),
      exitDate: json['exitDate']?.toString() ?? json['exitTime']?.toString(),
      realizedPnlPercent: realizedPnl,
      realizedPnlPercentage: realizedPnlStr,
      patterns: json['patterns']?.toString(),
      volumeMultiplier: volMultVal,
      rsi: rsiVal,
      ema20: ema20Val,
      supertrend: stVal,
      atr: atrVal,
      volume: volVal,
      setupGrade: json['setupGrade']?.toString(),
      holdingDays:
          json['holdingDays'] is num ? (json['holdingDays'] as num).toInt() : null,
      reasons: parsedReasons,
      indicators: indObj,
      createdAt: json['createdAt']?.toString() ?? dateStr,
      date: dateStr,
      entryDate: json['entryDate']?.toString(),
      tradeDate: json['tradeDate']?.toString(),
    );
  }
}

class InvestmentIndicators {
  final String symbol;
  final dynamic token;
  final double entryPrice;
  final double? ema20;
  final double? ema50;
  final double? ema200;
  final double? supertrend;
  final double? rsi;
  final double? atr;
  final double? adx;
  final double? plusDI;
  final double? minusDI;
  final num? volume;
  final num? avgVolume20;
  final double? volumeRatio;
  final double? computedStopLoss;
  final double? computedTarget;
  final double? stopLossPercent;
  final double? targetPercent;
  final double? riskRewardRatio;
  final double? confidenceScore;
  final bool? isShort;

  InvestmentIndicators({
    required this.symbol,
    required this.token,
    required this.entryPrice,
    this.ema20,
    this.ema50,
    this.ema200,
    this.supertrend,
    this.rsi,
    this.atr,
    this.adx,
    this.plusDI,
    this.minusDI,
    this.volume,
    this.avgVolume20,
    this.volumeRatio,
    this.computedStopLoss,
    this.computedTarget,
    this.stopLossPercent,
    this.targetPercent,
    this.riskRewardRatio,
    this.confidenceScore,
    this.isShort,
  });

  factory InvestmentIndicators.fromJson(Map<String, dynamic> json) {
    return InvestmentIndicators(
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      entryPrice: json['entryPrice'] is num ? (json['entryPrice'] as num).toDouble() : 0.0,
      ema20: json['ema20'] is num ? (json['ema20'] as num).toDouble() : null,
      ema50: json['ema50'] is num ? (json['ema50'] as num).toDouble() : null,
      ema200: json['ema200'] is num ? (json['ema200'] as num).toDouble() : null,
      supertrend: json['supertrend'] is num ? (json['supertrend'] as num).toDouble() : null,
      rsi: json['rsi'] is num ? (json['rsi'] as num).toDouble() : null,
      atr: json['atr'] is num ? (json['atr'] as num).toDouble() : null,
      adx: json['adx'] is num ? (json['adx'] as num).toDouble() : null,
      plusDI: json['plusDI'] is num ? (json['plusDI'] as num).toDouble() : null,
      minusDI: json['minusDI'] is num ? (json['minusDI'] as num).toDouble() : null,
      volume: json['volume'] is num ? (json['volume'] as num) : null,
      avgVolume20: json['avgVolume20'] is num ? (json['avgVolume20'] as num) : null,
      volumeRatio: json['volumeRatio'] is num ? (json['volumeRatio'] as num).toDouble() : null,
      computedStopLoss: json['computedStopLoss'] is num ? (json['computedStopLoss'] as num).toDouble() : null,
      computedTarget: json['computedTarget'] is num ? (json['computedTarget'] as num).toDouble() : null,
      stopLossPercent: json['stopLossPercent'] is num ? (json['stopLossPercent'] as num).toDouble() : null,
      targetPercent: json['targetPercent'] is num ? (json['targetPercent'] as num).toDouble() : null,
      riskRewardRatio: json['riskRewardRatio'] is num ? (json['riskRewardRatio'] as num).toDouble() : null,
      confidenceScore: json['confidenceScore'] is num ? (json['confidenceScore'] as num).toDouble() : null,
      isShort: json['isShort'] is bool ? json['isShort'] as bool : null,
    );
  }
}
