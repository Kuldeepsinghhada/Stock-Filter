class TradeConfig {
  final String symbol;
  final String exchange;
  final int quantity;
  final double slPoints;
  final double targetPoints;
  final bool isPercentageBased; // If true, slPoints and targetPoints are percentages
  final Duration pollingInterval;
  final Duration timeout;
  final String slOrderType; // 'SL' or 'SL-M'
  final int instrumentToken;

  TradeConfig({
    required this.symbol,
    this.exchange = 'NSE',
    required this.quantity,
    required this.slPoints,
    required this.targetPoints,
    this.isPercentageBased = false,
    this.pollingInterval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 15),
    this.slOrderType = 'SL-M', // default to Stop-Loss Market
    this.instrumentToken = 0,
  });
}

class OrderDetails {
  final String orderId;
  final String status;
  final double averagePrice;
  final int filledQuantity;

  OrderDetails({
    required this.orderId,
    required this.status,
    required this.averagePrice,
    required this.filledQuantity,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    return OrderDetails(
      orderId: json['order_id'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      averagePrice: (json['average_price'] ?? 0.0).toDouble(),
      filledQuantity: json['filled_quantity'] ?? 0,
    );
  }

  bool get isComplete => status == 'COMPLETE';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isOpen => status == 'OPEN' || status == 'TRIGGER PENDING';
}
