import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stock_demo/model/executed_order.dart';
import 'package:stock_demo/model/api_backtest_model.dart';

class BackendOrderService {
  static const String baseUrl = 'http://200.97.163.130:8080';
  // LOCAL:  http://localhost:8080
  // LIVE http://200.97.163.130:8080
  /// Health Check
  /// Verifies if the backend is running.
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Save Zerodha Session
  /// Updates or inserts your Zerodha Access Token into the PostgreSQL database.
  static Future<bool> saveZerodhaSession(
      String accessToken, String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "accessToken": accessToken,
          "kiteApiKey": DataManager.instance.apiKey,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Get Zerodha Session
  /// Performs a GET request to verify the session tokens on the backend.
  static Future<void> getSession() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/session'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Backend Session Data: $data");
      } else {
        print("Failed to get session: ${response.statusCode}");
      }
    } catch (e) {
      print("Error getting session: $e");
    }
  }

  /// Place Stock Order on custom backend
  static Future<void> placeStockOrder({
    required String symbol,
    required String exchange,
    required String transactionType,
    required int quantity,
    required String product,
    required double buyingPrice,
    required double stopLoss,
    required double target,
  }) async {
    final url = Uri.parse('$baseUrl/placeOrder');

    final headers = {
      'Content-Type': 'application/json',
      'X-Backend-Key': 'my_super_secret_key', // Ensure this is stored securely
    };

    // Round to nearest 0.05 (NSE Tick size)
    final double roundedSL = (stopLoss * 20).round() / 20.0;
    final double roundedTarget = (target * 20).round() / 20.0;

    final body = jsonEncode({
      "symbol":
          symbol.replaceAll("NSE:", "").replaceAll("BSE:", ""), // Clean symbol
      "exchange": exchange,
      "transactionType": transactionType,
      "quantity": quantity,
      "product": product,
      "buyingPrice": buyingPrice,
      "stopLoss": roundedSL,
      "target": roundedTarget,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Order Placed Successfully!");
        print(responseData); // This will contain your order IDs
        Fluttertoast.showToast(msg: "Order Placed: ${symbol}");
      } else {
        print("Failed to place order: ${response.statusCode}");
        print(response.body);
        String errorMessage = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['message'] != null) {
            errorMessage = decoded['message'];
          }
        } catch (_) {}
        Fluttertoast.showToast(msg: "Order Failed: $errorMessage");
      }
    } catch (e) {
      print("Error calling API: $e");
      Fluttertoast.showToast(msg: "Order API Error: $e");
    }
  }

  /// Test function to easily verify the API call with mock data
  static Future<void> testPlaceStockOrder() async {
    print("Testing BackendOrderService.placeStockOrder...");
    await placeStockOrder(
      symbol: "COMSYN",
      exchange: "NSE",
      transactionType: "BUY",
      quantity: 1,
      product: "MIS",
      buyingPrice: 1050.0,
      stopLoss: 1000.0,
      target: 1100.0,
    );
  }

  /// Auto Trail SL
  /// Trigger the backend to run its trailing stop-loss logic.
  static Future<bool> autoTrailSL() async {
    final url = Uri.parse('$baseUrl/autoTrailSL');
    final headers = {
      'Content-Type': 'application/json',
      'X-Backend-Key': 'my_super_secret_key',
    };

    log("Attempting to call backend API: POST $url",
        name: "BackendOrderService");

    try {
      final response = await http
          .post(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        log("Auto Trail SL Successful on Backend!",
            name: "BackendOrderService");
        return true;
      } else {
        log("Failed to auto trail SL on Backend: ${response.statusCode}, Body: ${response.body}",
            name: "BackendOrderService");
        return false;
      }
    } catch (e) {
      log("Error calling autoTrailSL API: $e",
          name: "BackendOrderService", error: e);
      return false;
    }
  }

  /// Get Executed Orders
  static Future<List<ExecutedOrder>> getExecutedOrders() async {
    final url = Uri.parse('$baseUrl/executedOrders');
    final headers = {
      'Content-Type': 'application/json',
      'X-Backend-Key': 'my_super_secret_key',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          List<dynamic> dataList = decoded['data'];
          return dataList.map((e) => ExecutedOrder.fromJson(e)).toList();
        }
      } else {
        print("Failed to get executed orders: ${response.statusCode}");
      }
    } catch (e) {
      print("Error calling getExecutedOrders API: $e");
    }
    return [];
  }

  /// Run Backtest via Backend API
  static Future<ApiBacktestResponse?> runBacktest(
      String startDate, String endDate) async {
    final url = Uri.parse(
        '$baseUrl/api/backtest?start_date=$startDate&end_date=$endDate');
    final headers = {
      'Content-Type': 'application/json',
      'X-Backend-Key': 'my_super_secret_key',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return ApiBacktestResponse.fromJson(jsonDecode(response.body));
      } else {
        print("Failed to run backtest: ${response.statusCode}");
      }
    } catch (e) {
      print("Error calling backtest API: $e");
    }
    return null;
  }
}
