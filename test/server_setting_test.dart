import 'package:flutter_test/flutter_test.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/server_setting_model.dart';

void main() {
  group('ServerSettings and ServerSettingsResponse Tests', () {
    test('Parse new server response successfully with maxTradePerDay and swingProduct', () {
      final jsonResponse = {
        "status": true,
        "message": "Settings retrieved successfully",
        "data": {
          "maxTradeAmountIntraday": 20000.0,
          "enableAutoTradingIntraday": false,
          "maxTradePerDay": 3,
          "maxTradeAmountSwing": 8000.0,
          "enableAutoTradingSwing": false,
          "swingProduct": "MTF",
          "squareOffTime": "15:15",
          "enableTelegramAlert": true,
          "enableScreenerSync": true,
        }
      };

      final response = ServerSettingsResponse.fromJson(jsonResponse);

      expect(response.isSuccess, isTrue);
      expect(response.message, equals("Settings retrieved successfully"));
      expect(response.data, isNotNull);

      final settings = response.data!;
      expect(settings.maxTradeAmountIntraday, equals(20000.0));
      expect(settings.enableAutoTradingIntraday, isFalse);
      expect(settings.maxTradePerDay, equals(3));
      expect(settings.maxTradeAmountSwing, equals(8000.0));
      expect(settings.enableAutoTradingSwing, isFalse);
      expect(settings.swingProduct, equals("MTF"));
      expect(settings.squareOffTime, equals("15:15"));
      expect(settings.enableTelegramAlert, isTrue);
      expect(settings.enableScreenerSync, isTrue);
    });

    test('Parse snake_case max_trade_per_day and swing_product fallback', () {
      final jsonResponse = {
        "status": true,
        "message": "Settings retrieved successfully",
        "data": {
          "maxTradeAmountIntraday": 20000.0,
          "enableAutoTradingIntraday": false,
          "max_trade_per_day": 2,
          "maxTradeAmountSwing": 8000.0,
          "enableAutoTradingSwing": false,
          "swing_product": "CNC",
          "squareOffTime": "15:15",
          "enableTelegramAlert": true,
          "enableScreenerSync": true,
        }
      };

      final response = ServerSettingsResponse.fromJson(jsonResponse);
      expect(response.data!.maxTradePerDay, equals(2));
      expect(response.data!.swingProduct, equals("CNC"));
    });

    test('toJson generates correct payload including maxTradePerDay and swingProduct', () {
      final settings = ServerSettings(
        maxTradeAmountIntraday: 25000.0,
        enableAutoTradingIntraday: true,
        maxTradePerDay: 4,
        maxTradeAmountSwing: 10000.0,
        enableAutoTradingSwing: false,
        swingProduct: "MTF",
        squareOffTime: "15:20",
        enableTelegramAlert: true,
        enableScreenerSync: false,
      );

      final json = settings.toJson();

      expect(json['maxTradeAmountIntraday'], equals(25000.0));
      expect(json['enableAutoTradingIntraday'], isTrue);
      expect(json['maxTradePerDay'], equals(4));
      expect(json['maxTradeAmountSwing'], equals(10000.0));
      expect(json['enableAutoTradingSwing'], isFalse);
      expect(json['swingProduct'], equals("MTF"));
      expect(json['squareOffTime'], equals("15:20"));
      expect(json['enableTelegramAlert'], isTrue);
      expect(json['enableScreenerSync'], isFalse);
    });

    test('parseSessionIsActive returns false when token is missing or expired (data: null)', () {
      final payload = {
        "status": "success",
        "message": "No session saved currently",
        "data": null
      };

      final isActive = BackendOrderService.parseSessionIsActive(payload);
      expect(isActive, isFalse);
    });

    test('parseSessionIsActive returns true when valid session token exists', () {
      final payload = {
        "status": "success",
        "message": "Current Session",
        "data": {
          "accessTokenMasked": "h3aEBx...cL4M",
          "refreshToken": null,
          "kiteApiKey": "2f6a...",
          "updatedAt": "2026-10-23T01:49:35.645411Z"
        }
      };

      final isActive = BackendOrderService.parseSessionIsActive(payload);
      expect(isActive, isTrue);
    });
  });
}
