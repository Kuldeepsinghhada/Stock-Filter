//──────────────────────── MODEL ──────────────────────────────────────────────
import 'package:stock_demo/model/position_model.dart';

class DataModel {
  final String niftyPrice;
  final String niftyChange;
  final String niftyPercent;
  final String sensexPrice;
  final String sensexChange;
  final String sensexPercent;
  final List<Position> positions;

  const DataModel({
    required this.niftyPrice,
    required this.niftyChange,
    required this.niftyPercent,
    required this.sensexPrice,
    required this.sensexChange,
    required this.sensexPercent,
    required this.positions
  });
}