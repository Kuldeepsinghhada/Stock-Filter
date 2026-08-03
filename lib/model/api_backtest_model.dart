class ApiBacktestResponse {
  final bool success;
  final String message;
  final ApiBacktestData? data;

  ApiBacktestResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiBacktestResponse.fromJson(Map<String, dynamic> json) {
    return ApiBacktestResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? ApiBacktestData.fromJson(json['data']) : null,
    );
  }
}

class ApiBacktestData {
  final ApiBacktestSummary summary;
  final List<ApiBacktestTrade> trades;

  ApiBacktestData({
    required this.summary,
    required this.trades,
  });

  factory ApiBacktestData.fromJson(Map<String, dynamic> json) {
    var tradesList = json['trades'] as List? ?? [];
    return ApiBacktestData(
      summary: ApiBacktestSummary.fromJson(json['summary'] ?? {}),
      trades: tradesList.map((e) => ApiBacktestTrade.fromJson(e)).toList(),
    );
  }
}

class ApiBacktestSummary {
  final int totalTrades;
  final int wins;
  final int losses;
  final int targetHits;
  final int stoplossHits;
  final int squareOffHits;
  final String accuracy;
  final String totalPnlPercent;

  ApiBacktestSummary({
    required this.totalTrades,
    required this.wins,
    required this.losses,
    this.targetHits = 0,
    this.stoplossHits = 0,
    this.squareOffHits = 0,
    required this.accuracy,
    required this.totalPnlPercent,
  });

  factory ApiBacktestSummary.fromJson(Map<String, dynamic> json) {
    return ApiBacktestSummary(
      totalTrades: json['totalTrades'] ?? 0,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      targetHits: json['targetHits'] ?? json['target_hits'] ?? json['targetHitsCount'] ?? 0,
      stoplossHits: json['stoplossHits'] ?? json['stoploss_hits'] ?? json['stopLossHitsCount'] ?? 0,
      squareOffHits: json['squareOffHits'] ?? json['square_off_hits'] ?? json['squareOffHitsCount'] ?? 0,
      accuracy: json['accuracy'] ?? '0.00%',
      totalPnlPercent: json['totalPnlPercent'] ?? '0.00%',
    );
  }
}

class ApiBacktestTrade {
  final String token;
  final String stockName;
  final String date;
  final String? entryTime;
  final double entryPrice;
  final double target;
  final double stoploss;
  final String? exitTime;
  final double exitPrice;
  final String exitReason;
  final double pnlPercent;
  final bool niftyGreen;

  ApiBacktestTrade({
    required this.token,
    required this.stockName,
    required this.date,
    this.entryTime,
    required this.entryPrice,
    required this.target,
    required this.stoploss,
    this.exitTime,
    required this.exitPrice,
    required this.exitReason,
    required this.pnlPercent,
    required this.niftyGreen,
  });

  factory ApiBacktestTrade.fromJson(Map<String, dynamic> json) {
    return ApiBacktestTrade(
      token: json['token']?.toString() ?? '',
      stockName: json['stockName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      entryTime: json['entryTime']?.toString(),
      entryPrice: (json['entryPrice'] ?? 0.0).toDouble(),
      target: (json['target'] ?? 0.0).toDouble(),
      stoploss: (json['stoploss'] ?? 0.0).toDouble(),
      exitTime: json['exitTime']?.toString(),
      exitPrice: (json['exitPrice'] ?? 0.0).toDouble(),
      exitReason: json['exitReason']?.toString() ?? '',
      pnlPercent: (json['pnlPercent'] ?? 0.0).toDouble(),
      niftyGreen: json['niftyGreen'] ?? false,
    );
  }
}
