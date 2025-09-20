import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String apiKey = "ddjw8yq0ow1zd9ds";
const String apiSecret = "xuvrpjx0agkro10uznz3ppxfuto5sb8w";
const String redirectUrl = "https://127.0.0.1"; // Zerodha panel me ye hi set karo

class ZerodhaLoginPage extends StatefulWidget {
  const ZerodhaLoginPage({super.key});

  @override
  State<ZerodhaLoginPage> createState() => _ZerodhaLoginPageState();
}

class _ZerodhaLoginPageState extends State<ZerodhaLoginPage> {
  WebViewController? controller;
  String? accessToken;

  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.contains("request_token=")) {
              final uri = Uri.parse(request.url);
              final requestToken = uri.queryParameters["request_token"];
              log("✅ Request Token: $requestToken");
              if (requestToken != null) {
                getAccessToken(requestToken);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse("https://kite.zerodha.com/connect/login?v=3&api_key=$apiKey"),
      );
  }

  Future<void> _checkTokenAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final expiry = prefs.getInt('access_token_expiry');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (token != null && expiry != null && now < expiry) {
      setState(() {
        accessToken = token;
      });
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacementNamed(context, '/dashboard');
      });
    }
  }

  Future<void> getAccessToken(String requestToken) async {
    final url = Uri.parse("https://api.kite.trade/session/token");
    final checksum =
    sha256.convert(utf8.encode("$apiKey$requestToken$apiSecret")).toString();
    final response = await http.post(url, body: {
      "api_key": apiKey,
      "request_token": requestToken,
      "checksum": checksum,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data["data"]["access_token"];
      setState(() {
        accessToken = token;
      });
      log("🎯 Access Token: $accessToken");
      // Save token and expiry (midnight)
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
      await prefs.setString('access_token', token);
      await prefs.setInt('access_token_expiry', midnight);
      // Navigate to home screen
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacementNamed(context, '/dashboard');
      });
    } else {
      log("❌ Error: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Zerodha Login")),
      body: accessToken == null
          ? WebViewWidget(controller: controller!)
          : Center(
        child: SelectableText(
          "Access Token:\n$accessToken",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
