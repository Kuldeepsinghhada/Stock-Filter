class HistoryModel {
  DateTime? dateTime;
  double? price;
  bool? isPassed;
  bool? isBuyAlert;
  double? volumeX;

  HistoryModel({this.dateTime, this.price, this.isPassed, this.isBuyAlert, this.volumeX});

  HistoryModel.fromJson(Map<String, dynamic> json) {
    dateTime = json['dateTime'];
    price = json['stockSymbol'];
    isPassed = json['token'];
    isBuyAlert = json['isBuyAlert'];
    volumeX = json['volumeX'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateTime'] = dateTime;
    data['price'] = price;
    data['isPassed'] = isPassed;
    data['isBuyAlert'] = isBuyAlert;
    data['volumeX'] = volumeX;
    return data;
  }
}
