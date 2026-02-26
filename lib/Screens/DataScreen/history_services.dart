import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/model/api_response.dart';
import 'package:stock_demo/model/historical_data_model.dart';

class HistoryServices {
  HistoryServices._();
  static final HistoryServices instance = HistoryServices._();

  Future<APIResponse> getHistoricalData(
    String instrumentToken,
    String fromDate,
    String toDate,
  ) async {
    final endpoint =
        '${APIEndPoint.getHistoricalData}$instrumentToken/day?from=$fromDate&to=$toDate';

    final response = await ApiService.instance.apiCall(
      endpoint,
      HttpRequestType.get,
      null,
    );

    if (response.status && response.data != null) {
      if (response.data['data'] != null &&
          response.data['data']['candles'] != null) {
        try {
          List<dynamic> candles = response.data['data']['candles'];
          List<HistoricalDataModel> parsedData =
              candles.map((e) => HistoricalDataModel.fromList(e)).toList();
          return APIResponse(true, parsedData, response.error);
        } catch (e) {
          return APIResponse(false, null, "Failed to parse data");
        }
      } else {
        return APIResponse(false, null, "No historical data found.");
      }
    }

    return response;
  }
}
