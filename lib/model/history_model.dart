class HistoryModel {
  DateTime? dateTime;
  double? price;
  bool? isPassed;
  bool? isBuyAlert;
  double? volumeX;
  bool? apiPassed;
  String? apiReason;

  HistoryModel({
    this.dateTime,
    this.price,
    this.isPassed,
    this.isBuyAlert,
    this.volumeX,
    this.apiPassed,
    this.apiReason,
  });

  HistoryModel.fromJson(Map<String, dynamic> json) {
    dateTime = json['dateTime'];
    price = json['stockSymbol'];
    isPassed = json['token'];
    isBuyAlert = json['isBuyAlert'];
    volumeX = json['volumeX'];
    apiPassed = json['apiPassed'];
    apiReason = json['apiReason'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateTime'] = dateTime;
    data['price'] = price;
    data['isPassed'] = isPassed;
    data['isBuyAlert'] = isBuyAlert;
    data['volumeX'] = volumeX;
    data['apiPassed'] = apiPassed;
    data['apiReason'] = apiReason;
    return data;
  }
}
