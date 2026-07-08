import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stock_demo/Utils/data_manager.dart';

class BackendOrderService {
  static const String baseUrl = 'http://200.97.163.130:8080';

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
    required double stopLoss,
    required double target,
  }) async {
    final url = Uri.parse('$baseUrl/placeOrder');

    final headers = {
      'Content-Type': 'application/json',
      'X-Backend-Key': 'my_super_secret_key', // Ensure this is stored securely
    };

    final body = jsonEncode({
      "symbol":
          symbol.replaceAll("NSE:", "").replaceAll("BSE:", ""), // Clean symbol
      "exchange": exchange,
      "transactionType": transactionType,
      "quantity": quantity,
      "product": product,
      "stopLoss": stopLoss,
      "target": target,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Order Placed Successfully!");
        print(responseData); // This will contain your order IDs
      } else {
        print("Failed to place order: ${response.statusCode}");
        print(response.body);
      }
    } catch (e) {
      print("Error calling API: $e");
    }
  }

  /// Test function to easily verify the API call with mock data
  static Future<void> testPlaceStockOrder() async {
    print("Testing BackendOrderService.placeStockOrder...");
    await placeStockOrder(
      symbol: "INFY",
      exchange: "NSE",
      transactionType: "BUY",
      quantity: 1,
      product: "CNC",
      stopLoss: 1400.0,
      target: 1500.0,
    );
  }

  /// Update Active Stoploss
  /// Called when the 1-minute Supertrend trailing logic modifies the SL.
  static Future<void> updateActiveSL({
    required String symbol,
    required double triggerPrice,
  }) async {
    final url = Uri.parse('$baseUrl/updateActiveSL');

    final headers = {
      'Content-Type': 'application/json',
      'X-Backend-Key': 'my_super_secret_key',
    };

    final body = jsonEncode({
      "symbol": symbol.replaceAll("NSE:", "").replaceAll("BSE:", ""),
      "triggerPrice": triggerPrice,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        print("SL Updated Successfully on Backend! ($symbol -> $triggerPrice)");
      } else {
        print("Failed to update SL on Backend: ${response.statusCode}");
        print(response.body);
      }
    } catch (e) {
      print("Error calling updateActiveSL API: $e");
    }
  }
}
