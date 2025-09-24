class FinalStockModel {
  String? dateTime;
  String? stockSymbol;
  int? token;
  double? lastPrice;
  double? open;
  double? close;

  FinalStockModel({
    this.dateTime,
    this.stockSymbol,
    this.token,
    this.lastPrice,
    this.open,
    this.close,
  });

  FinalStockModel.fromJson(Map<String, dynamic> json) {
    dateTime = json['dateTime'];
    stockSymbol = json['stockSymbol'];
    token = json['token'];
    lastPrice = json['lastPrice'];
    open = json['open'];
    close = json['close'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['dateTime'] = dateTime;
    data['stockSymbol'] = stockSymbol;
    data['token'] = token;
    data['lastPrice'] = lastPrice;
    data['open'] = open;
    data['close'] = close;
    return data;
  }
}
