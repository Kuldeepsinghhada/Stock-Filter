import 'package:stock_demo/model/stock_model.dart';

class DataManager {
  DataManager._privateConstructor();

  static final DataManager instance = DataManager._privateConstructor();

  String apiKey = "ddjw8yq0ow1zd9ds";
  String apiSecret = "xuvrpjx0agkro10uznz3ppxfuto5sb8w";
  String redirectUrl = "https://127.0.0.1";

  List<StockModel> stocksList = [];
}
