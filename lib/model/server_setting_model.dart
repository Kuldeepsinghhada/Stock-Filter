class ServerSettings {
  final double maxTradeAmountIntraday;
  final bool enableAutoTradingIntraday;
  final int maxTradePerDay;
  final double maxTradeAmountSwing;
  final bool enableAutoTradingSwing;
  final String squareOffTime;
  final bool enableTelegramAlert;
  final bool enableScreenerSync;
  final String? updatedAt;

  // Backwards compatibility getters
  double get maxTradeAmount => maxTradeAmountIntraday;
  bool get enableAutoTrading => enableAutoTradingIntraday;

  ServerSettings({
    double? maxTradeAmountIntraday,
    double? maxTradeAmount,
    bool? enableAutoTradingIntraday,
    bool? enableAutoTrading,
    int? maxTradePerDay,
    required this.maxTradeAmountSwing,
    required this.enableAutoTradingSwing,
    required this.squareOffTime,
    required this.enableTelegramAlert,
    required this.enableScreenerSync,
    this.updatedAt,
  })  : maxTradeAmountIntraday =
            maxTradeAmountIntraday ?? maxTradeAmount ?? 20000.0,
        enableAutoTradingIntraday =
            enableAutoTradingIntraday ?? enableAutoTrading ?? false,
        maxTradePerDay = maxTradePerDay ?? 1;

  factory ServerSettings.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    int parseInt(dynamic val, [int defaultVal = 1]) {
      if (val == null) return defaultVal;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? defaultVal;
    }

    bool parseBool(dynamic val, [bool defaultVal = false]) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      final str = val.toString().toLowerCase().trim();
      return str == 'true' || str == '1' || str == 'yes' || str == 'success';
    }

    return ServerSettings(
      maxTradeAmountIntraday: parseDouble(
        json['maxTradeAmountIntraday'] ??
            json['max_trade_amount_intraday'] ??
            json['maxTradeAmount'] ??
            json['max_trade_amount'],
        20000.0,
      ),
      enableAutoTradingIntraday: parseBool(
        json['enableAutoTradingIntraday'] ??
            json['enable_auto_trading_intraday'] ??
            json['enableAutoTrading'] ??
            json['enable_auto_trading'],
        false,
      ),
      maxTradePerDay: parseInt(
        json['maxTradePerDay'] ?? json['max_trade_per_day'],
        1,
      ),
      maxTradeAmountSwing: parseDouble(
        json['maxTradeAmountSwing'] ??
            json['max_trade_amount_swing'],
        8000.0,
      ),
      enableAutoTradingSwing: parseBool(
        json['enableAutoTradingSwing'] ??
            json['enable_auto_trading_swing'],
        false,
      ),
      squareOffTime: (json['squareOffTime'] ??
              json['square_off_time'] ??
              "15:15")
          .toString(),
      enableTelegramAlert: parseBool(
        json['enableTelegramAlert'] ??
            json['enable_telegram_alert'],
        true,
      ),
      enableScreenerSync: parseBool(
        json['enableScreenerSync'] ??
            json['enable_screener_sync'],
        true,
      ),
      updatedAt: (json['updatedAt'] ?? json['updated_at'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "maxTradeAmountIntraday": maxTradeAmountIntraday,
      "enableAutoTradingIntraday": enableAutoTradingIntraday,
      "maxTradePerDay": maxTradePerDay,
      "maxTradeAmountSwing": maxTradeAmountSwing,
      "enableAutoTradingSwing": enableAutoTradingSwing,
      "squareOffTime": squareOffTime,
      "enableTelegramAlert": enableTelegramAlert,
      "enableScreenerSync": enableScreenerSync,
    };
  }

  ServerSettings copyWith({
    double? maxTradeAmountIntraday,
    bool? enableAutoTradingIntraday,
    int? maxTradePerDay,
    double? maxTradeAmountSwing,
    bool? enableAutoTradingSwing,
    String? squareOffTime,
    bool? enableTelegramAlert,
    bool? enableScreenerSync,
    String? updatedAt,
  }) {
    return ServerSettings(
      maxTradeAmountIntraday:
          maxTradeAmountIntraday ?? this.maxTradeAmountIntraday,
      enableAutoTradingIntraday:
          enableAutoTradingIntraday ?? this.enableAutoTradingIntraday,
      maxTradePerDay: maxTradePerDay ?? this.maxTradePerDay,
      maxTradeAmountSwing: maxTradeAmountSwing ?? this.maxTradeAmountSwing,
      enableAutoTradingSwing:
          enableAutoTradingSwing ?? this.enableAutoTradingSwing,
      squareOffTime: squareOffTime ?? this.squareOffTime,
      enableTelegramAlert: enableTelegramAlert ?? this.enableTelegramAlert,
      enableScreenerSync: enableScreenerSync ?? this.enableScreenerSync,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ServerSettingsResponse {
  final bool isSuccess;
  final String status;
  final String message;
  final ServerSettings? data;

  ServerSettingsResponse({
    required this.isSuccess,
    required this.status,
    required this.message,
    this.data,
  });

  factory ServerSettingsResponse.fromJson(Map<String, dynamic> json) {
    bool success = false;

    // Check 'status' field (e.g. {"status": true, ...})
    if (json['status'] != null) {
      if (json['status'] is bool) {
        success = json['status'] as bool;
      } else {
        final str = json['status'].toString().toLowerCase().trim();
        success = str == 'true' || str == 'success' || str == '1';
      }
    }
    // Check 'success' field (e.g. {"success": true, ...})
    else if (json['success'] != null) {
      if (json['success'] is bool) {
        success = json['success'] as bool;
      } else {
        final str = json['success'].toString().toLowerCase().trim();
        success = str == 'true' || str == 'success' || str == '1';
      }
    }

    return ServerSettingsResponse(
      isSuccess: success,
      status: json['status']?.toString() ?? (success ? 'true' : 'false'),
      message: json['message']?.toString() ?? '',
      data: json['data'] != null && json['data'] is Map<String, dynamic>
          ? ServerSettings.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}
