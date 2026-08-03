class PassedDailyResponse {
  final bool success;
  final String message;
  final PassedDailyData? data;

  PassedDailyResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PassedDailyResponse.fromJson(Map<String, dynamic> json) {
    return PassedDailyResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null ? PassedDailyData.fromJson(json['data']) : null,
    );
  }
}

class PassedDailyData {
  final String targetDate;
  final String checkedTillDate;
  final int totalEvaluated;
  final int totalPassed;
  final List<PassedDailyStockModel> passedStocks;

  PassedDailyData({
    required this.targetDate,
    required this.checkedTillDate,
    required this.totalEvaluated,
    required this.totalPassed,
    required this.passedStocks,
  });

  factory PassedDailyData.fromJson(Map<String, dynamic> json) {
    var stocksJson = json['passedStocks'] as List? ?? [];
    List<PassedDailyStockModel> stocks =
        stocksJson.map((s) => PassedDailyStockModel.fromJson(s)).toList();

    return PassedDailyData(
      targetDate: json['targetDate']?.toString() ?? '',
      checkedTillDate: json['checkedTillDate']?.toString() ?? '',
      totalEvaluated: json['totalEvaluated'] is num ? (json['totalEvaluated'] as num).toInt() : 0,
      totalPassed: json['totalPassed'] is num ? (json['totalPassed'] as num).toInt() : 0,
      passedStocks: stocks,
    );
  }
}

class PassedDailyStockModel {
  final String symbol;
  final dynamic token;
  final double stockPrice;
  final String priceSource;
  final double? previousDailySupertrend;
  final String? lastCompletedDailyDate;
  final double? nearestResistancePrice;
  final int? nearestResistanceTouches;
  final double? distanceToResistancePercent;
  final bool passed;
  final List<String> reasons;
  final PassedStockChecks? checks;

  PassedDailyStockModel({
    required this.symbol,
    required this.token,
    required this.stockPrice,
    required this.priceSource,
    this.previousDailySupertrend,
    this.lastCompletedDailyDate,
    this.nearestResistancePrice,
    this.nearestResistanceTouches,
    this.distanceToResistancePercent,
    required this.passed,
    required this.reasons,
    this.checks,
  });

  factory PassedDailyStockModel.fromJson(Map<String, dynamic> json) {
    var reasonsJson = json['reasons'] as List? ?? [];
    List<String> reasonList = reasonsJson.map((r) => r.toString()).toList();

    return PassedDailyStockModel(
      symbol: json['symbol']?.toString() ?? '',
      token: json['token'],
      stockPrice: json['stockPrice'] is num ? (json['stockPrice'] as num).toDouble() : 0.0,
      priceSource: json['priceSource']?.toString() ?? '',
      previousDailySupertrend: json['previousDailySupertrend'] is num
          ? (json['previousDailySupertrend'] as num).toDouble()
          : null,
      lastCompletedDailyDate: json['lastCompletedDailyDate']?.toString(),
      nearestResistancePrice: json['nearestResistancePrice'] is num
          ? (json['nearestResistancePrice'] as num).toDouble()
          : null,
      nearestResistanceTouches: json['nearestResistanceTouches'] is num
          ? (json['nearestResistanceTouches'] as num).toInt()
          : null,
      distanceToResistancePercent: json['distanceToResistancePercent'] is num
          ? (json['distanceToResistancePercent'] as num).toDouble()
          : null,
      passed: json['passed'] == true,
      reasons: reasonList,
      checks: json['checks'] != null ? PassedStockChecks.fromJson(json['checks']) : null,
    );
  }
}

class PassedStockChecks {
  final SupertrendCheck? supertrend;
  final ResistanceCheck? resistance;

  PassedStockChecks({
    this.supertrend,
    this.resistance,
  });

  factory PassedStockChecks.fromJson(Map<String, dynamic> json) {
    return PassedStockChecks(
      supertrend: json['supertrend'] != null
          ? SupertrendCheck.fromJson(json['supertrend'])
          : null,
      resistance: json['resistance'] != null
          ? ResistanceCheck.fromJson(json['resistance'])
          : null,
    );
  }
}

class SupertrendCheck {
  final bool passed;
  final double? previousDailySupertrend;

  SupertrendCheck({
    required this.passed,
    this.previousDailySupertrend,
  });

  factory SupertrendCheck.fromJson(Map<String, dynamic> json) {
    return SupertrendCheck(
      passed: json['passed'] == true,
      previousDailySupertrend: json['previousDailySupertrend'] is num
          ? (json['previousDailySupertrend'] as num).toDouble()
          : null,
    );
  }
}

class ResistanceCheck {
  final bool passed;
  final bool? isNearResistance;

  ResistanceCheck({
    required this.passed,
    this.isNearResistance,
  });

  factory ResistanceCheck.fromJson(Map<String, dynamic> json) {
    return ResistanceCheck(
      passed: json['passed'] == true,
      isNearResistance: json['isNearResistance'] is bool ? json['isNearResistance'] : null,
    );
  }
}
