class NotificationModel {
  String? stocksNameList;
  String? time;
  double? volumeX;
  double? initialAvgVolume;

  NotificationModel({this.stocksNameList, this.time, this.volumeX, this.initialAvgVolume});

  NotificationModel.fromJson(Map<String, dynamic> json) {
    stocksNameList = json['stocksNameList'];
    time = json['time'];
    volumeX = json['volumeX'];
    initialAvgVolume = json['initialAvgVolume'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data =  <String, dynamic>{};
    data['stocksNameList'] = stocksNameList;
    data['time'] = time;
    data['volumeX'] = volumeX;
    data['initialAvgVolume'] = initialAvgVolume;
    return data;
  }
}