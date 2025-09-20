//──────────────────────── MODEL ──────────────────────────────────────────────
class Position {
  final String symbol;
  final String orderType;
  final double pnl;
  final double ltp;
  const Position({
    required this.symbol,
    required this.orderType,
    required this.pnl,
    required this.ltp,
  });
}