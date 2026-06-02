class HistoryModel {
  DateTime? dateTime;
  double? price;
  bool? isPassed;
  bool? isBuyAlert;

  HistoryModel({this.dateTime, this.price, this.isPassed, this.isBuyAlert});

  HistoryModel.fromJson(Map<String, dynamic> json) {
    dateTime = json['dateTime'];
    price = json['stockSymbol'];
    isPassed = json['token'];
    isBuyAlert = json['isBuyAlert'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateTime'] = dateTime;
    data['price'] = price;
    data['isPassed'] = isPassed;
    data['isBuyAlert'] = isBuyAlert;
    return data;
  }
}
