class ExecutedOrder {
  final int id;
  final String stockName;
  final String mainOrderId;
  final String slOrderId;
  final String targetOrderId;
  final double buyingPrice;
  final double? exitPrice;
  final double? profitLossPercentage;
  final String status;
  final DateTime? createdAt;

  ExecutedOrder({
    required this.id,
    required this.stockName,
    required this.mainOrderId,
    required this.slOrderId,
    required this.targetOrderId,
    required this.buyingPrice,
    this.exitPrice,
    this.profitLossPercentage,
    required this.status,
    this.createdAt,
  });

  factory ExecutedOrder.fromJson(Map<String, dynamic> json) {
    return ExecutedOrder(
      id: json['id'] ?? 0,
      stockName: json['stockName'] ?? '',
      mainOrderId: json['mainOrderId'] ?? '',
      slOrderId: json['slOrderId'] ?? '',
      targetOrderId: json['targetOrderId'] ?? '',
      buyingPrice: (json['buyingPrice'] ?? 0).toDouble(),
      exitPrice: json['exitPrice'] != null ? (json['exitPrice'] as num).toDouble() : null,
      profitLossPercentage: json['profitLossPercentage'] != null ? (json['profitLossPercentage'] as num).toDouble() : null,
      status: json['status'] ?? 'UNKNOWN',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}
