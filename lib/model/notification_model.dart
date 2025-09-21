class NotificationModel {
  String? stocksNameList;
  String? time;

  NotificationModel({this.stocksNameList, this.time});

  NotificationModel.fromJson(Map<String, dynamic> json) {
    stocksNameList = json['stocksNameList'];
    time = json['time'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data =  <String, dynamic>{};
    data['stocksNameList'] = stocksNameList;
    data['time'] = time;
    return data;
  }
}