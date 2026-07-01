import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/data_manager.dart';

class KiteApiClient {
  final String baseUrl = 'https://api.kite.trade';
  
  KiteApiClient();

  Future<Map<String, String>> get _headers async {
    final token = await SharedPreferenceHelper.instance.getToken();
    final apiKey = DataManager.instance.apiKey;
    return {
      'X-Kite-Version': '3',
      'Authorization': 'token $apiKey:$token',
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  /// Performs a GET request to the Kite Connect API
  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    developer.log('GET $uri', name: 'KiteApiClient');
    
    try {
      final headers = await _headers;
      final response = await http.get(uri, headers: headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      developer.log('GET $endpoint failed: $e', name: 'KiteApiClient', error: e);
      rethrow;
    }
  }

  /// Performs a POST request to the Kite Connect API
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    developer.log('POST $uri with body: $body', name: 'KiteApiClient');
    
    try {
      final headers = await _headers;
      final response = await http.post(uri, headers: headers, body: body);
      return _handleResponse(response, endpoint);
    } catch (e) {
      developer.log('POST $endpoint failed: $e', name: 'KiteApiClient', error: e);
      rethrow;
    }
  }

  /// Performs a PUT request to the Kite Connect API
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    developer.log('PUT $uri with body: $body', name: 'KiteApiClient');
    
    try {
      final headers = await _headers;
      final response = await http.put(uri, headers: headers, body: body);
      return _handleResponse(response, endpoint);
    } catch (e) {
      developer.log('PUT $endpoint failed: $e', name: 'KiteApiClient', error: e);
      rethrow;
    }
  }
  
  /// Performs a DELETE request to the Kite Connect API
  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    developer.log('DELETE $uri', name: 'KiteApiClient');
    
    try {
      final headers = await _headers;
      final response = await http.delete(uri, headers: headers, body: body);
      return _handleResponse(response, endpoint);
    } catch (e) {
      developer.log('DELETE $endpoint failed: $e', name: 'KiteApiClient', error: e);
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response, String endpoint) {
    developer.log('Response from $endpoint: ${response.statusCode}', name: 'KiteApiClient');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['status'] == 'success') {
        return jsonResponse['data'];
      } else {
        developer.log('API Error: ${jsonResponse['message']}', name: 'KiteApiClient', error: jsonResponse);
        throw Exception(jsonResponse['message'] ?? 'Unknown API Error');
      }
    } else {
      String message = 'HTTP ${response.statusCode}';
      try {
        final jsonResponse = jsonDecode(response.body);
        message = jsonResponse['message'] ?? message;
      } catch (_) {}
      developer.log('HTTP Error: $message', name: 'KiteApiClient', error: response.body);
      throw Exception(message);
    }
  }
}
