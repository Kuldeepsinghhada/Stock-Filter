import 'package:flutter_test/flutter_test.dart';
import 'package:stock_demo/model/server_setting_model.dart';

void main() {
  group('ServerSettings and ServerSettingsResponse Tests', () {
    test('Parse new server response successfully with maxTradePerDay', () {
      final jsonResponse = {
        "status": true,
        "message": "Settings retrieved successfully",
        "data": {
          "maxTradeAmountIntraday": 20000.0,
          "enableAutoTradingIntraday": false,
          "maxTradePerDay": 3,
          "maxTradeAmountSwing": 8000.0,
          "enableAutoTradingSwing": false,
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
      expect(settings.squareOffTime, equals("15:15"));
      expect(settings.enableTelegramAlert, isTrue);
      expect(settings.enableScreenerSync, isTrue);
    });

    test('Parse snake_case max_trade_per_day fallback', () {
      final jsonResponse = {
        "status": true,
        "message": "Settings retrieved successfully",
        "data": {
          "maxTradeAmountIntraday": 20000.0,
          "enableAutoTradingIntraday": false,
          "max_trade_per_day": 2,
          "maxTradeAmountSwing": 8000.0,
          "enableAutoTradingSwing": false,
          "squareOffTime": "15:15",
          "enableTelegramAlert": true,
          "enableScreenerSync": true,
        }
      };

      final response = ServerSettingsResponse.fromJson(jsonResponse);
      expect(response.data!.maxTradePerDay, equals(2));
    });

    test('toJson generates correct payload including maxTradePerDay', () {
      final settings = ServerSettings(
        maxTradeAmountIntraday: 25000.0,
        enableAutoTradingIntraday: true,
        maxTradePerDay: 4,
        maxTradeAmountSwing: 10000.0,
        enableAutoTradingSwing: false,
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
      expect(json['squareOffTime'], equals("15:20"));
      expect(json['enableTelegramAlert'], isTrue);
      expect(json['enableScreenerSync'], isFalse);
    });
  });
}
