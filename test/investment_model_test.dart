import 'package:flutter_test/flutter_test.dart';
import 'package:stock_demo/model/investment_model.dart';

void main() {
  group('Swing Daily Backtest Model Tests', () {
    test('Correctly deserializes user API response payload', () {
      final jsonMap = {
        "success": true,
        "message": "Pure Daily EOD Backtest fetched from cache instantly",
        "data": {
          "totalTrades": 142,
          "wins": 115,
          "losses": 27,
          "accuracy": "80.99%",
          "winRate": 80.99,
          "totalPnlPercent": "+420.50%",
          "trades": [
            {
              "symbol": "TATAELEXI",
              "entryDate": "2026-09-15",
              "entryPrice": 6850.0,
              "exitDate": "2026-09-22",
              "exitPrice": 7329.5,
              "exitReason": "TARGET_HIT",
              "status": "WIN",
              "pnlPercent": 7.0
            }
          ]
        }
      };

      final response = InvestmentResponse.fromJson(jsonMap);

      expect(response.success, isTrue);
      expect(response.message,
          "Pure Daily EOD Backtest fetched from cache instantly");
      expect(response.data, isNotNull);

      final data = response.data!;
      expect(data.totalTrades, 142);
      expect(data.wins, 115);
      expect(data.losses, 27);
      expect(data.accuracyPercent, 80.99);
      expect(data.winRate, 80.99);
      expect(data.totalPnlPercent, "+420.50%");

      expect(data.summary, isNotNull);
      expect(data.summary!.totalTrades, 142);
      expect(data.summary!.wins, 115);
      expect(data.summary!.losses, 27);
      expect(data.summary!.accuracy, "80.99%");
      expect(data.summary!.winRate, 80.99);
      expect(data.summary!.totalPnlPercent, "+420.50%");

      expect(data.recommendations.length, 1);
      final trade = data.recommendations.first;
      expect(trade.symbol, "TATAELEXI");
      expect(trade.entryDate, "2026-09-15");
      expect(trade.entryPrice, 6850.0);
      expect(trade.exitDate, "2026-09-22");
      expect(trade.exitPrice, 7329.5);
      expect(trade.exitReason, "TARGET_HIT");
      expect(trade.status, "WIN");
      expect(trade.winLoss, "WIN");
      expect(trade.realizedPnlPercent, 7.0);
      expect(trade.realizedPnlPercentage, "+7.00%");
    });
  });
}
