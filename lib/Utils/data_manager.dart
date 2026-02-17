import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/historical_data_model.dart';
import 'package:stock_demo/model/stock_model.dart';

class DataManager {
  DataManager._privateConstructor();

  static final DataManager instance = DataManager._privateConstructor();

  String apiKey = "ddjw8yq0ow1zd9ds";
  String apiSecret = "xuvrpjx0agkro10uznz3ppxfuto5sb8w";
  // String mayurKey = "2f6a1b7e8zjjlpld";
  // String mayurSecret = "uufgb81yfkfnrnzw89sany1zwa0qdeng";
  String redirectUrl = "https://127.0.0.1";

  List<StockModel> preFilteredStocksList = [];
  List<StockModel> stocksList = [];
}
