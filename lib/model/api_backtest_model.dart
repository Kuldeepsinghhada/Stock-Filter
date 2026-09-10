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

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
    };
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
    List<ApiBacktestTrade> parsedTrades =
        tradesList.map((e) => ApiBacktestTrade.fromJson(e)).toList();

    Map<String, dynamic> summaryMap = {};
    if (json['summary'] is Map<String, dynamic>) {
      summaryMap.addAll(json['summary']);
    }
    for (var key in [
      'totalTrades',
      'total_trades',
      'wins',
      'losses',
      'open',
      'accuracy',
      'accuracyVal',
      'winRate',
      'win_rate',
      'accuracy_percent',
      'totalPnlPercent',
      'total_pnl_percent',
      'totalPnl',
      'total_pnl',
      'netPnL',
      'net_pnl',
      'pnl'
    ]) {
      if (!summaryMap.containsKey(key) && json.containsKey(key)) {
        summaryMap[key] = json[key];
      }
    }

    ApiBacktestSummary summary = ApiBacktestSummary.fromJson(
      summaryMap,
      trades: parsedTrades,
    );
    return ApiBacktestData(
      summary: summary,
      trades: parsedTrades,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary.toJson(),
      'trades': trades.map((t) => t.toJson()).toList(),
    };
  }
}

class ApiBacktestSummary {
  final int totalTrades;
  final int wins;
  final int losses;
  final int open;
  final int targetHits;
  final int stoplossHits;
  final int trailingSlHits;
  final int squareOffHits;
  final String accuracy;
  final String totalPnlPercent;

  ApiBacktestSummary({
    required this.totalTrades,
    required this.wins,
    required this.losses,
    this.open = 0,
    this.targetHits = 0,
    this.stoplossHits = 0,
    this.trailingSlHits = 0,
    this.squareOffHits = 0,
    required this.accuracy,
    required this.totalPnlPercent,
  });

  factory ApiBacktestSummary.fromJson(
    Map<String, dynamic> json, {
    List<ApiBacktestTrade>? trades,
  }) {
    int totalTrades = _toInt(json['totalTrades'] ?? json['total_trades']) ?? trades?.length ?? 0;
    int wins = _toInt(json['wins']) ?? 0;
    int losses = _toInt(json['losses']) ?? 0;
    int open = _toInt(json['open']) ?? 0;
    int targetHits =
        _toInt(json['targetHits'] ?? json['target_hits'] ?? json['targetHitsCount']) ?? 0;
    int stoplossHits =
        _toInt(json['stoplossHits'] ?? json['stoploss_hits'] ?? json['stopLossHitsCount']) ?? 0;
    int trailingSlHits =
        _toInt(json['trailingSlHits'] ?? json['trailing_sl_hits'] ?? json['trailingHits'] ?? json['trailingSlHitsCount']) ?? 0;
    int squareOffHits =
        _toInt(json['squareOffHits'] ?? json['square_off_hits'] ?? json['squareOffHitsCount']) ?? 0;

    if (trades != null && trades.isNotEmpty) {
      if (wins == 0 && losses == 0) {
        for (var t in trades) {
          if (t.pnlPercent > 0) wins++;
          if (t.pnlPercent < 0) losses++;
        }
      }
      if (targetHits == 0 && stoplossHits == 0 && squareOffHits == 0) {
        for (var t in trades) {
          String reason = t.exitReason.toLowerCase().trim();
          String status = (t.status ?? '').toLowerCase().trim();
          if (reason.contains('trailing') ||
              reason.contains('tsl') ||
              reason.contains('trail') ||
              status.contains('trailing') ||
              status.contains('tsl') ||
              status.contains('trail')) {
            trailingSlHits++;
          } else if (reason.contains('target') || reason.contains('tgt')) {
            targetHits++;
          } else if (reason.contains('stoploss') ||
              reason.contains('stop loss') ||
              reason.contains('sl')) {
            stoplossHits++;
          } else if (reason.contains('square') ||
              reason.contains('sqr') ||
              reason.contains('eod') ||
              reason.contains('time')) {
            squareOffHits++;
          } else {
            if (t.pnlPercent > 0) {
              targetHits++;
            } else if (t.pnlPercent < 0) {
              stoplossHits++;
            } else {
              squareOffHits++;
            }
          }
        }
      }
    }

    String? rawAccuracy;
    if (json['accuracy'] != null) {
      rawAccuracy = json['accuracy'].toString();
    } else if (json['accuracy_percent'] != null) {
      rawAccuracy = json['accuracy_percent'].toString();
    } else if (json['accuracyVal'] != null) {
      rawAccuracy = "${json['accuracyVal']}%";
    } else if (json['winRate'] != null) {
      rawAccuracy = "${json['winRate']}%";
    } else if (json['win_rate'] != null) {
      rawAccuracy = "${json['win_rate']}%";
    }

    if (rawAccuracy != null && !rawAccuracy.contains('%')) {
      rawAccuracy = "$rawAccuracy%";
    }

    String accuracy = rawAccuracy ??
        (wins + losses > 0
            ? "${((wins / (wins + losses)) * 100).toStringAsFixed(2)}%"
            : (totalTrades > 0
                ? "${((wins / totalTrades) * 100).toStringAsFixed(2)}%"
                : "0.00%"));

    String? rawPnl;
    if (json['totalPnlPercent'] != null) {
      rawPnl = json['totalPnlPercent'].toString();
    } else if (json['total_pnl_percent'] != null) {
      rawPnl = json['total_pnl_percent'].toString();
    } else if (json['totalPnl'] != null) {
      rawPnl = "${json['totalPnl']}%";
    } else if (json['total_pnl'] != null) {
      rawPnl = "${json['total_pnl']}%";
    } else if (json['netPnL'] != null) {
      rawPnl = "${json['netPnL']}%";
    } else if (json['net_pnl'] != null) {
      rawPnl = "${json['net_pnl']}%";
    } else if (json['pnl'] != null) {
      rawPnl = "${json['pnl']}%";
    }

    if (rawPnl != null && !rawPnl.contains('%')) {
      rawPnl = "$rawPnl%";
    }

    String totalPnlPercent = rawPnl ?? '0.00%';

    return ApiBacktestSummary(
      totalTrades: totalTrades,
      wins: wins,
      losses: losses,
      open: open,
      targetHits: targetHits,
      stoplossHits: stoplossHits,
      trailingSlHits: trailingSlHits,
      squareOffHits: squareOffHits,
      accuracy: accuracy,
      totalPnlPercent: totalPnlPercent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTrades': totalTrades,
      'wins': wins,
      'losses': losses,
      'open': open,
      'targetHits': targetHits,
      'stoplossHits': stoplossHits,
      'trailingSlHits': trailingSlHits,
      'squareOffHits': squareOffHits,
      'accuracy': accuracy,
      'totalPnlPercent': totalPnlPercent,
    };
  }
}

double? _toDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

int? _toInt(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    int? parsedInt = int.tryParse(val);
    if (parsedInt != null) return parsedInt;
    return double.tryParse(val)?.toInt();
  }
  return null;
}

class ApiBacktestTrade {
  final String token;
  final String stockName;
  final String date;
  final String? entryTime;
  final String? signalTime;
  final double entryPrice;
  final double target;
  final double stoploss;
  final String? exitTime;
  final double exitPrice;
  final String exitReason;
  final String? status;
  final String? winLoss;
  final double pnlPercent;
  final bool niftyGreen;
  final double? maxFavorableMove;
  final double? maxAdverseMove;

  // Technical Indicators (Intraday)
  final double? rsi;
  final double? rsiSlope;
  final double? ema20;
  final double? ema20Slope;
  final double? supertrend;
  final double? atr;
  final double? atrPercent;
  final double? adx;
  final double? volume;
  final double? volumeMultiplier;
  final double? previousVolume;
  final double? prevCandleVolume;
  final double? rangeExpansion;
  final double? priceChangePercent;
  final double? efficiencyRatio;
  final double? extensionScore;
  final double? resistanceDistance;
  final double? priceDistanceFromEma20;
  final double? distanceFromEma20;
  final double? priceDistanceFromSupertrend;
  final double? distanceFromSupertrend;
  final String? marketIndexCondition;
  final String? stockSector;

  // Technical Indicators (Daily Timeframe)
  final double? dailyClose;
  final double? dailyEma20;
  final double? dailyEma50;
  final double? dailyEma100;
  final double? dailyEma200;
  final double? dailyEma20Slope;
  final double? dailyEma50Slope;
  final double? dailyRsi;
  final double? dailyAtr;
  final double? dailyAtrPercent;
  final double? dailySupertrend;
  final double? dailyAdx;
  final double? dailyAvgVolume20;
  final double? currentDayVolumeVsAvg;
  final double? prevDayHigh;
  final double? prevDayLow;
  final double? distFrom52WeekHighPct;
  final double? dailyResistanceDistancePct;
  final double? dailySupportDistancePct;
  final double? dailyPriceChangePct;
  final double? gapUpGapDownPct;
  final String? dailyTrend;

  // Holding & Setup details
  final int? holdingDays;
  final String? holdingType;
  final String? setupGrade;
  final String? pathName;

  ApiBacktestTrade({
    required this.token,
    required this.stockName,
    required this.date,
    this.entryTime,
    this.signalTime,
    required this.entryPrice,
    required this.target,
    required this.stoploss,
    this.exitTime,
    required this.exitPrice,
    required this.exitReason,
    this.status,
    this.winLoss,
    required this.pnlPercent,
    required this.niftyGreen,
    this.maxFavorableMove,
    this.maxAdverseMove,
    this.holdingDays,
    this.holdingType,
    this.setupGrade,
    this.pathName,
    this.rsi,
    this.rsiSlope,
    this.ema20,
    this.ema20Slope,
    this.supertrend,
    this.atr,
    this.atrPercent,
    this.adx,
    this.volume,
    this.volumeMultiplier,
    this.previousVolume,
    this.prevCandleVolume,
    this.rangeExpansion,
    this.priceChangePercent,
    this.efficiencyRatio,
    this.extensionScore,
    this.resistanceDistance,
    this.priceDistanceFromEma20,
    this.distanceFromEma20,
    this.priceDistanceFromSupertrend,
    this.distanceFromSupertrend,
    this.marketIndexCondition,
    this.stockSector,
    this.dailyClose,
    this.dailyEma20,
    this.dailyEma50,
    this.dailyEma100,
    this.dailyEma200,
    this.dailyEma20Slope,
    this.dailyEma50Slope,
    this.dailyRsi,
    this.dailyAtr,
    this.dailyAtrPercent,
    this.dailySupertrend,
    this.dailyAdx,
    this.dailyAvgVolume20,
    this.currentDayVolumeVsAvg,
    this.prevDayHigh,
    this.prevDayLow,
    this.distFrom52WeekHighPct,
    this.dailyResistanceDistancePct,
    this.dailySupportDistancePct,
    this.dailyPriceChangePct,
    this.gapUpGapDownPct,
    this.dailyTrend,
  });

  factory ApiBacktestTrade.fromJson(Map<String, dynamic> json) {
    double pnl = _toDouble(
          json['pnlPercent'] ??
              json['pnlPct'] ??
              json['pnl_percent'] ??
              json['pnl_percentage'] ??
              json['pnl'] ??
              json['profit'] ??
              json['profit_loss_percentage'],
        ) ??
        0.0;

    return ApiBacktestTrade(
      token: json['token']?.toString() ??
          json['instrumentToken']?.toString() ??
          json['stockSymbol']?.toString() ??
          json['symbol']?.toString() ??
          json['stockName']?.toString() ??
          json['stock_name']?.toString() ??
          json['name']?.toString() ??
          json['tradingsymbol']?.toString() ??
          json['tradingSymbol']?.toString() ??
          '',
      stockName: json['stockName']?.toString() ??
          json['stock_name']?.toString() ??
          json['stockSymbol']?.toString() ??
          json['symbol']?.toString() ??
          json['name']?.toString() ??
          json['tradingsymbol']?.toString() ??
          json['tradingSymbol']?.toString() ??
          '',
      date: json['date']?.toString() ??
          json['entryDate']?.toString() ??
          json['tradeDate']?.toString() ??
          json['opportunityDate']?.toString() ??
          '',
      entryTime: json['entryTime']?.toString() ??
          json['entry_time']?.toString() ??
          json['entryTimestamp']?.toString() ??
          json['triggerTimestamp']?.toString(),
      signalTime: json['signalTime']?.toString() ??
          json['signal_time']?.toString() ??
          json['entryTimestamp']?.toString() ??
          json['triggerTimestamp']?.toString() ??
          json['entryTime']?.toString() ??
          json['entry_time']?.toString(),
      entryPrice: _toDouble(json['entryPrice'] ?? json['entry_price']) ?? 0.0,
      target: _toDouble(
            json['target'] ?? json['targetPrice'] ?? json['target_price'],
          ) ??
          0.0,
      stoploss: _toDouble(
            json['stoploss'] ??
                json['stopLoss'] ??
                json['stop_loss'] ??
                json['sl'] ??
                json['initialSL'] ??
                json['stopLossPrice'],
          ) ??
          0.0,
      exitTime: json['exitTime']?.toString() ??
          json['exit_time']?.toString() ??
          json['exitTimestamp']?.toString() ??
          json['exitDate']?.toString(),
      exitPrice: _toDouble(json['exitPrice'] ?? json['exit_price']) ?? 0.0,
      exitReason: json['exitReason']?.toString() ??
          json['exit_reason']?.toString() ??
          json['exitType']?.toString() ??
          json['dailyOutcome']?.toString() ??
          json['status']?.toString() ??
          '',
      status: json['status']?.toString() ??
          json['exitReason']?.toString() ??
          json['exit_reason']?.toString() ??
          json['exitType']?.toString() ??
          json['dailyOutcome']?.toString(),
      winLoss: json['winLoss']?.toString() ??
          json['win_loss']?.toString() ??
          (pnl > 0 ? 'WIN' : (pnl < 0 ? 'LOSS' : 'BREAKEVEN')),
      pnlPercent: pnl,
      niftyGreen: json['niftyGreen'] ?? false,
      maxFavorableMove: _toDouble(json['maxFavorableMove'] ?? json['MFE_R']),
      maxAdverseMove: _toDouble(json['maxAdverseMove'] ?? json['MAE_R']),
      holdingDays: _toInt(json['holdingDays'] ?? json['holding_days']),
      holdingType: json['holdingType']?.toString() ??
          json['holding_type']?.toString(),
      setupGrade: json['setupGrade']?.toString(),
      pathName: json['pathName']?.toString(),
      rsi: _toDouble(json['rsi']),
      rsiSlope: _toDouble(json['rsiSlope']),
      ema20: _toDouble(json['ema20']),
      ema20Slope: _toDouble(json['ema20Slope']),
      supertrend: _toDouble(json['supertrend']),
      atr: _toDouble(json['atr']),
      atrPercent: _toDouble(json['atrPercent']),
      adx: _toDouble(json['adx']),
      volume: _toDouble(json['volume']),
      volumeMultiplier: _toDouble(json['volumeMultiplier']),
      previousVolume: _toDouble(json['previousVolume']),
      prevCandleVolume: _toDouble(json['prevCandleVolume']),
      rangeExpansion: _toDouble(json['rangeExpansion']),
      priceChangePercent: _toDouble(json['priceChangePercent']),
      efficiencyRatio: _toDouble(json['efficiencyRatio']),
      extensionScore: _toDouble(json['extensionScore']),
      resistanceDistance: _toDouble(json['resistanceDistance']),
      priceDistanceFromEma20: _toDouble(json['priceDistanceFromEma20']),
      distanceFromEma20: _toDouble(json['distanceFromEma20']),
      priceDistanceFromSupertrend: _toDouble(json['priceDistanceFromSupertrend']),
      distanceFromSupertrend: _toDouble(json['distanceFromSupertrend']),
      marketIndexCondition: json['marketIndexCondition']?.toString(),
      stockSector: json['stockSector']?.toString(),
      dailyClose: _toDouble(json['dailyClose']),
      dailyEma20: _toDouble(json['dailyEma20']),
      dailyEma50: _toDouble(json['dailyEma50']),
      dailyEma100: _toDouble(json['dailyEma100']),
      dailyEma200: _toDouble(json['dailyEma200']),
      dailyEma20Slope: _toDouble(json['dailyEma20Slope']),
      dailyEma50Slope: _toDouble(json['dailyEma50Slope']),
      dailyRsi: _toDouble(json['dailyRsi']),
      dailyAtr: _toDouble(json['dailyAtr']),
      dailyAtrPercent: _toDouble(json['dailyAtrPercent']),
      dailySupertrend: _toDouble(json['dailySupertrend']),
      dailyAdx: _toDouble(json['dailyAdx']),
      dailyAvgVolume20: _toDouble(json['dailyAvgVolume20']),
      currentDayVolumeVsAvg: _toDouble(json['currentDayVolumeVsAvg']),
      prevDayHigh: _toDouble(json['prevDayHigh']),
      prevDayLow: _toDouble(json['prevDayLow']),
      distFrom52WeekHighPct: _toDouble(json['distFrom52WeekHighPct']),
      dailyResistanceDistancePct: _toDouble(json['dailyResistanceDistancePct']),
      dailySupportDistancePct: _toDouble(json['dailySupportDistancePct']),
      dailyPriceChangePct: _toDouble(json['dailyPriceChangePct']),
      gapUpGapDownPct: _toDouble(json['gapUpGapDownPct']),
      dailyTrend: json['dailyTrend']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'token': token,
      'stockName': stockName,
      'date': date,
      'entryTime': entryTime,
      'signalTime': signalTime,
      'entryPrice': entryPrice,
      'target': target,
      'stoploss': stoploss,
      'exitTime': exitTime,
      'exitPrice': exitPrice,
      'exitReason': exitReason,
      'status': status,
      'winLoss': winLoss,
      'pnlPercent': pnlPercent,
      'niftyGreen': niftyGreen,
    };

    if (holdingDays != null) data['holdingDays'] = holdingDays;
    if (holdingType != null) data['holdingType'] = holdingType;
    if (setupGrade != null) data['setupGrade'] = setupGrade;
    if (pathName != null) data['pathName'] = pathName;
    if (maxFavorableMove != null) data['maxFavorableMove'] = maxFavorableMove;
    if (maxAdverseMove != null) data['maxAdverseMove'] = maxAdverseMove;
    if (rsi != null) data['rsi'] = rsi;
    if (rsiSlope != null) data['rsiSlope'] = rsiSlope;
    if (ema20 != null) data['ema20'] = ema20;
    if (ema20Slope != null) data['ema20Slope'] = ema20Slope;
    if (supertrend != null) data['supertrend'] = supertrend;
    if (atr != null) data['atr'] = atr;
    if (atrPercent != null) data['atrPercent'] = atrPercent;
    if (adx != null) data['adx'] = adx;
    if (volume != null) data['volume'] = volume;
    if (volumeMultiplier != null) data['volumeMultiplier'] = volumeMultiplier;
    if (previousVolume != null) data['previousVolume'] = previousVolume;
    if (prevCandleVolume != null) data['prevCandleVolume'] = prevCandleVolume;
    if (rangeExpansion != null) data['rangeExpansion'] = rangeExpansion;
    if (priceChangePercent != null) data['priceChangePercent'] = priceChangePercent;
    if (efficiencyRatio != null) data['efficiencyRatio'] = efficiencyRatio;
    if (extensionScore != null) data['extensionScore'] = extensionScore;
    if (resistanceDistance != null) data['resistanceDistance'] = resistanceDistance;
    if (priceDistanceFromEma20 != null) data['priceDistanceFromEma20'] = priceDistanceFromEma20;
    if (distanceFromEma20 != null) data['distanceFromEma20'] = distanceFromEma20;
    if (priceDistanceFromSupertrend != null) data['priceDistanceFromSupertrend'] = priceDistanceFromSupertrend;
    if (distanceFromSupertrend != null) data['distanceFromSupertrend'] = distanceFromSupertrend;
    if (marketIndexCondition != null) data['marketIndexCondition'] = marketIndexCondition;
    if (stockSector != null) data['stockSector'] = stockSector;
    if (dailyClose != null) data['dailyClose'] = dailyClose;
    if (dailyEma20 != null) data['dailyEma20'] = dailyEma20;
    if (dailyEma50 != null) data['dailyEma50'] = dailyEma50;
    if (dailyEma100 != null) data['dailyEma100'] = dailyEma100;
    if (dailyEma200 != null) data['dailyEma200'] = dailyEma200;
    if (dailyEma20Slope != null) data['dailyEma20Slope'] = dailyEma20Slope;
    if (dailyEma50Slope != null) data['dailyEma50Slope'] = dailyEma50Slope;
    if (dailyRsi != null) data['dailyRsi'] = dailyRsi;
    if (dailyAtr != null) data['dailyAtr'] = dailyAtr;
    if (dailyAtrPercent != null) data['dailyAtrPercent'] = dailyAtrPercent;
    if (dailySupertrend != null) data['dailySupertrend'] = dailySupertrend;
    if (dailyAdx != null) data['dailyAdx'] = dailyAdx;
    if (dailyAvgVolume20 != null) data['dailyAvgVolume20'] = dailyAvgVolume20;
    if (currentDayVolumeVsAvg != null) data['currentDayVolumeVsAvg'] = currentDayVolumeVsAvg;
    if (prevDayHigh != null) data['prevDayHigh'] = prevDayHigh;
    if (prevDayLow != null) data['prevDayLow'] = prevDayLow;
    if (distFrom52WeekHighPct != null) data['distFrom52WeekHighPct'] = distFrom52WeekHighPct;
    if (dailyResistanceDistancePct != null) data['dailyResistanceDistancePct'] = dailyResistanceDistancePct;
    if (dailySupportDistancePct != null) data['dailySupportDistancePct'] = dailySupportDistancePct;
    if (dailyPriceChangePct != null) data['dailyPriceChangePct'] = dailyPriceChangePct;
    if (gapUpGapDownPct != null) data['gapUpGapDownPct'] = gapUpGapDownPct;
    if (dailyTrend != null) data['dailyTrend'] = dailyTrend;

    return data;
  }
}
