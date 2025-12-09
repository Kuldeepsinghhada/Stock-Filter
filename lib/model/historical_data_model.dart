class HistoricalDataModel {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  HistoricalDataModel({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory HistoricalDataModel.fromList(List<dynamic> data) {
    return HistoricalDataModel(
      timestamp: DateTime.parse(data[0].toString().substring(0, 19)),
      open: (data[1] as num).toDouble(),
      high: (data[2] as num).toDouble(),
      low: (data[3] as num).toDouble(),
      close: (data[4] as num).toDouble(),
      volume: (data[5] as num).toInt(),
    );
  }

  /// ➕ Add this
  factory HistoricalDataModel.fromJson(Map<String, dynamic> json) {
    return HistoricalDataModel(
      timestamp: DateTime.parse(json['timestamp']),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: json['volume'] as int,
    );
  }

  /// ➕ Add this
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }
}

