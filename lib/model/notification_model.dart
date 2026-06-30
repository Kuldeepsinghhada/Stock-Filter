class NotificationModel {
  String? stocksNameList;
  String? time;
  double? volumeX;
  double? initialAvgVolume;
  double? target;
  double? stoploss;
  double? price;

  NotificationModel({
    this.stocksNameList,
    this.time,
    this.volumeX,
    this.initialAvgVolume,
    this.target,
    this.stoploss,
    this.price,
  });

  NotificationModel.fromJson(Map<String, dynamic> json) {
    stocksNameList = json['stocksNameList'];
    time = json['time'];
    volumeX = (json['volumeX'] as num?)?.toDouble();
    initialAvgVolume = (json['initialAvgVolume'] as num?)?.toDouble();
    target = (json['target'] as num?)?.toDouble();
    stoploss = (json['stoploss'] as num?)?.toDouble();
    price = (json['price'] as num?)?.toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stocksNameList'] = stocksNameList;
    data['time'] = time;
    data['volumeX'] = volumeX;
    data['initialAvgVolume'] = initialAvgVolume;
    data['target'] = target;
    data['stoploss'] = stoploss;
    data['price'] = price;
    return data;
  }
}