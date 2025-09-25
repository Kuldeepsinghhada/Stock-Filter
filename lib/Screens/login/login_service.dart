import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:stock_demo/APIService/api_service.dart';
import 'package:stock_demo/APIService/end_point.dart';
import 'package:stock_demo/Utils/data_manager.dart';
import 'package:stock_demo/Utils/enums.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/model/api_response.dart';

class LoginService {
  // Private constructor
  LoginService._internal();

  // Singleton instance
  static final LoginService instance = LoginService._internal();

  Future<APIResponse> doLogin(String requestToken) async {
    // Generate checksum
    final checksum =
        sha256
            .convert(
              utf8.encode(
                "${DataManager.instance.apiKey}$requestToken${DataManager.instance.apiSecret}",
              ),
            )
            .toString();
    final checksuj =
        sha256
            .convert(
              utf8.encode(
                "${DataManager.instance.apiKey}$requestToken${DataManager.instance.apiSecret}",
              ),
            )
            .toString();

    // Prepare request body
    Map<String, dynamic> body = {
      "api_key": DataManager.instance.apiKey,
      "request_token": requestToken,
      "checksum": checksum,
    };

    // Make API call
    APIResponse response = await ApiService.instance
        .apiCall(APIEndPoint.login, HttpRequestType.post, {
          "api_key": DataManager.instance.apiKey,
          "request_token": requestToken,
          "checksum": checksum,
        });
    if (response.status) {
      final token = response.data["data"]["access_token"];
      log("🎯 Access Token: $token");
      // Save token and expiry (midnight)
      await SharedPreferenceHelper.instance.clearNotifications();
      await SharedPreferenceHelper.instance.setToken(token);
      await SharedPreferenceHelper.instance.setTokenExpiryToken();
    }
    return response;
  }
}
