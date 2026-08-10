class ServerSettings {
  final double maxTradeAmount;
  final String squareOffTime;
  final bool enableTelegramAlert;
  final bool enableAutoTrading;
  final bool enableScreenerSync;
  final String? updatedAt;

  ServerSettings({
    required this.maxTradeAmount,
    required this.squareOffTime,
    required this.enableTelegramAlert,
    required this.enableAutoTrading,
    required this.enableScreenerSync,
    this.updatedAt,
  });

  factory ServerSettings.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      final str = val.toString().toLowerCase().trim();
      return str == 'true' || str == '1' || str == 'yes' || str == 'success';
    }

    return ServerSettings(
      maxTradeAmount: parseDouble(json['maxTradeAmount'] ?? json['max_trade_amount']),
      squareOffTime:
          (json['squareOffTime'] ?? json['square_off_time'] ?? "15:15")
              .toString(),
      enableTelegramAlert: parseBool(
          json['enableTelegramAlert'] ?? json['enable_telegram_alert']),
      enableAutoTrading:
          parseBool(json['enableAutoTrading'] ?? json['enable_auto_trading']),
      enableScreenerSync: parseBool(
          json['enableScreenerSync'] ?? json['enable_screener_sync']),
      updatedAt: (json['updatedAt'] ?? json['updated_at'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "max_trade_amount": maxTradeAmount,
      "square_off_time": squareOffTime,
      "enable_telegram_alert": enableTelegramAlert,
      "enable_auto_trading": enableAutoTrading,
      "enable_screener_sync": enableScreenerSync,
    };
  }

  ServerSettings copyWith({
    double? maxTradeAmount,
    String? squareOffTime,
    bool? enableTelegramAlert,
    bool? enableAutoTrading,
    bool? enableScreenerSync,
    String? updatedAt,
  }) {
    return ServerSettings(
      maxTradeAmount: maxTradeAmount ?? this.maxTradeAmount,
      squareOffTime: squareOffTime ?? this.squareOffTime,
      enableTelegramAlert: enableTelegramAlert ?? this.enableTelegramAlert,
      enableAutoTrading: enableAutoTrading ?? this.enableAutoTrading,
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

    // Check 'success' field (e.g. {"success": true, ...})
    if (json['success'] != null) {
      if (json['success'] is bool) {
        success = json['success'] as bool;
      } else {
        final str = json['success'].toString().toLowerCase().trim();
        success = str == 'true' || str == 'success' || str == '1';
      }
    }
    // Check 'status' field (e.g. {"status": "success", ...})
    else if (json['status'] != null) {
      final str = json['status'].toString().toLowerCase().trim();
      success = str == 'success' || str == 'true' || str == '1';
    }

    return ServerSettingsResponse(
      isSuccess: success,
      status: json['status']?.toString() ?? (success ? 'success' : 'error'),
      message: json['message']?.toString() ?? '',
      data: json['data'] != null && json['data'] is Map<String, dynamic>
          ? ServerSettings.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}
