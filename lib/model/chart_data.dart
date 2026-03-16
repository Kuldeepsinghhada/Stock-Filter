class ChartData {
  final DateTime x;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double? ema20;
  final double? supertrend;

  ChartData(
    this.x,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.ema20,
    this.supertrend,
  );
}
