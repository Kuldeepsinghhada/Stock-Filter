class HistoryModel {
  DateTime? dateTime;
  double? price;
  bool? isPassed;

  HistoryModel({this.dateTime, this.price, this.isPassed});

  HistoryModel.fromJson(Map<String, dynamic> json) {
    dateTime = json['dateTime'];
    price = json['stockSymbol'];
    isPassed = json['token'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateTime'] = dateTime;
    data['price'] = price;
    data['isPassed'] = isPassed;
    return data;
  }
}
