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

class InvestmentData {
  final int count;
  final double minAccuracyRequired;
  final String timeframe;
  final String strategy;
  final List<InvestmentRecommendation> recommendations;
  final int? targetHitCount;
  final double? accuracyPercent;
  final double? totalProfit;

  InvestmentData({
    required this.count,
    required this.minAccuracyRequired,
    required this.timeframe,
    required this.strategy,
    required this.recommendations,
    this.targetHitCount,
    this.accuracyPercent,
    this.totalProfit,
  });

  factory InvestmentData.fromJson(Map<String, dynamic> json) {
    var list = json['recommendations'] as List? ?? [];
    List<InvestmentRecommendation> recs =
        list.map((r) => InvestmentRecommendation.fromJson(r)).toList();

    return InvestmentData(
      count: json['count'] is num ? (json['count'] as num).toInt() : recs.length,
      minAccuracyRequired: json['minAccuracyRequired'] is num
          ? (json['minAccuracyRequired'] as num).toDouble()
          : 0.0,
      timeframe: json['timeframe']?.toString() ?? '',
      strategy: json['strategy']?.toString() ?? '',
      recommendations: recs,
      targetHitCount: json['targetHitCount'] is num
          ? (json['targetHitCount'] as num).toInt()
          : json['targetCount'] is num
              ? (json['targetCount'] as num).toInt()
              : null,
      accuracyPercent: json['accuracyPercent'] is num
          ? (json['accuracyPercent'] as num).toDouble()
          : json['accuracy'] is num
              ? (json['accuracy'] as num).toDouble()
              : null,
      totalProfit: json['totalProfit'] is num
          ? (json['totalProfit'] as num).toDouble()
          : json['totalPnl'] is num
              ? (json['totalPnl'] as num).toDouble()
              : null,
    );
  }
}

class InvestmentRecommendation {
  final String symbol;
  final dynamic token;
  final double entryPrice;
  final double targetPrice;
  final double stopLossPrice;
  final double targetPercent;
  final double stopLossPercent;
  final double riskRewardRatio;
  final double accuracy;
  final String accuracyPercentage;
  final String timeframe;
  final String recommendationType;
  final String holdingPeriod;
  final String status;
  final double? exitPrice;
  final String? exitDate;
  final double? realizedPnlPercent;
  final String? realizedPnlPercentage;
  final int? holdingDays;
  final List<String> reasons;
  final InvestmentIndicators? indicators;
  final String createdAt;
  final String? date;

  InvestmentRecommendation({
    required this.symbol,
    required this.token,
    required this.entryPrice,
    required this.targetPrice,
    required this.stopLossPrice,
    required this.targetPercent,
    required this.stopLossPercent,
    required this.riskRewardRatio,
    required this.accuracy,
    required this.accuracyPercentage,
    required this.timeframe,
    required this.recommendationType,
    required this.holdingPeriod,
    required this.status,
    this.exitPrice,
    this.exitDate,
    this.realizedPnlPercent,
    this.realizedPnlPercentage,
    this.holdingDays,
    required this.reasons,
    this.indicators,
    required this.createdAt,
    this.date,
  });

  factory InvestmentRecommendation.fromJson(Map<String, dynamic> json) {
    var reasonsList = json['reasons'] as List? ?? [];
    List<String> parsedReasons = reasonsList.map((e) => e.toString()).toList();

    return InvestmentRecommendation(
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      entryPrice: json['entryPrice'] is num ? (json['entryPrice'] as num).toDouble() : 0.0,
      targetPrice: json['targetPrice'] is num ? (json['targetPrice'] as num).toDouble() : 0.0,
      stopLossPrice: json['stopLossPrice'] is num ? (json['stopLossPrice'] as num).toDouble() : 0.0,
      targetPercent: json['targetPercent'] is num ? (json['targetPercent'] as num).toDouble() : 0.0,
      stopLossPercent: json['stopLossPercent'] is num ? (json['stopLossPercent'] as num).toDouble() : 0.0,
      riskRewardRatio: json['riskRewardRatio'] is num ? (json['riskRewardRatio'] as num).toDouble() : 0.0,
      accuracy: json['accuracy'] is num ? (json['accuracy'] as num).toDouble() : 0.0,
      accuracyPercentage: json['accuracyPercentage']?.toString() ?? '',
      timeframe: json['timeframe']?.toString() ?? '',
      recommendationType: json['recommendationType']?.toString() ?? '',
      holdingPeriod: json['holdingPeriod']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      exitPrice: json['exitPrice'] is num ? (json['exitPrice'] as num).toDouble() : null,
      exitDate: json['exitDate']?.toString(),
      realizedPnlPercent: json['realizedPnlPercent'] is num ? (json['realizedPnlPercent'] as num).toDouble() : null,
      realizedPnlPercentage: json['realizedPnlPercentage']?.toString(),
      holdingDays: json['holdingDays'] is num ? (json['holdingDays'] as num).toInt() : null,
      reasons: parsedReasons,
      indicators: json['indicators'] != null ? InvestmentIndicators.fromJson(json['indicators']) : null,
      createdAt: json['createdAt']?.toString() ?? '',
      date: json['date']?.toString() ?? json['targetDate']?.toString(),
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
