import 'historical_data_model.dart';

class Ohlc {
  final double? open;
  final double? high;
  final double? low;
  final double? close;

  Ohlc({this.open, this.high, this.low, this.close});

  factory Ohlc.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Ohlc();
    return Ohlc(
      open: (map['open'] as num?)?.toDouble(),
      high: (map['high'] as num?)?.toDouble(),
      low: (map['low'] as num?)?.toDouble(),
      close: (map['close'] as num?)?.toDouble(),
    );
  }
}

class StockModel {
  final String? symbol;
  final String? name;
  final dynamic token;
  final String? sector;
  final String? link;
  final String? timestamp;
  final String? lastTradeTime;
  final double? lastPrice;
  final int? lastQuantity;
  final int? buyQuantity;
  final int? sellQuantity;
  final int? volume;
  final double? averagePrice;
  final int? oi;
  final int? oiDayHigh;
  final int? oiDayLow;
  final double? netChange;
  final double? lowerCircuitLimit;
  final double? upperCircuitLimit;
  final Ohlc? ohlc;
  final List<HistoricalDataModel>? historyFiveMin;
  final List<HistoricalDataModel>? historyFifteenMin;
  final List<HistoricalDataModel>? history30Min;
  final List<HistoricalDataModel>? historyOneHour;

  StockModel({
    this.symbol,
    this.name,
    this.link,
    this.token,
    this.sector,
    this.timestamp,
    this.lastTradeTime,
    this.lastPrice,
    this.lastQuantity,
    this.buyQuantity,
    this.sellQuantity,
    this.volume,
    this.averagePrice,
    this.oi,
    this.oiDayHigh,
    this.oiDayLow,
    this.netChange,
    this.lowerCircuitLimit,
    this.upperCircuitLimit,
    this.ohlc,
    this.historyFiveMin,
    this.historyFifteenMin,
    this.history30Min,
    this.historyOneHour,
  });

  factory StockModel.fromMap(Map<String, dynamic> map) {
    return StockModel(
      symbol: map['symbol']?.toString(),
      name: map['name']?.toString(),
      link: map['link']?.toString(),
      token: map['token'],
      timestamp: map['timestamp']?.toString(),
      lastTradeTime: map['last_trade_time']?.toString(),
      lastPrice: (map['last_price'] as num?)?.toDouble(),
      lastQuantity: map['last_quantity'] as int?,
      buyQuantity: map['buy_quantity'] as int?,
      sellQuantity: map['sell_quantity'] as int?,
      volume: map['volume'] as int?,
      averagePrice: (map['average_price'] as num?)?.toDouble(),
      oi: map['oi'] as int?,
      oiDayHigh: map['oi_day_high'] as int?,
      oiDayLow: map['oi_day_low'] as int?,
      netChange: (map['net_change'] as num?)?.toDouble(),
      lowerCircuitLimit: (map['lower_circuit_limit'] as num?)?.toDouble(),
      upperCircuitLimit: (map['upper_circuit_limit'] as num?)?.toDouble(),
      ohlc: Ohlc.fromMap(map['ohlc'] as Map<String, dynamic>?),
      historyFiveMin: map['historicalData'] as List<HistoricalDataModel>?,
      historyFifteenMin:
          map['historicalData15Min'] as List<HistoricalDataModel>?,
      history30Min: map['historicalData30Min'] as List<HistoricalDataModel>?,
      historyOneHour: map['historicalData1Hour'] as List<HistoricalDataModel>?,
    );
  }
}
