// import 'package:flutter/material.dart';
// import 'package:stock_demo/Utils/indicators.dart';
// import 'package:stock_demo/model/stock_model.dart';
//
// import '../../Utils/utilities.dart';
//
// class StockCheckScreen extends StatefulWidget {
//   const StockCheckScreen({super.key, required this.stock});
//   final StockModel stock;
//   @override
//   State<StockCheckScreen> createState() => _StockCheckScreenState();
// }
//
// class _StockCheckScreenState extends State<StockCheckScreen> {
//   StockModel? stock;
//   List<HistoryModel> historyList = [];
//   @override
//   void initState() {
//     super.initState();
//     stock = widget.stock;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       getStockSignal(stock!);
//     });
//   }
//
//   Future<void> _initialize() async {
//     Future.delayed(const Duration(milliseconds: 200), () async {
//       setState(() {
//        // isLoading = true;
//       });
//         var result = await Utilities.buildTodayHistory(
//           stock.historyFiveMin ?? [],
//           stock,
//         );
//         if (result.isNotEmpty) {
//           historyList.add(result);
//         }
//       setState(() {
//         //isLoading = false;
//       });
//     });
//   }
//
//   getStockSignal(StockModel stock) {
//     final history = stock.historyFiveMin;
//     if (history == null || history.length < 21) {
//       showDialog(
//         context: context,
//         builder:
//             (ctx) => AlertDialog(
//                   title: const Text('Indicator Check'),
//                   content: const Text('Not enough historical data.'),
//                   actions: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(ctx),
//                       child: const Text('OK'),
//                     ),
//                   ],
//                 ),
//       );
//       return;
//     }
//
//     // Parse arrays
//     final highs = history.map((e) => e.high).toList();
//     final lows = history.map((e) => e.low).toList();
//     final closes = history.map((e) => e.close).toList();
//     final volumes = history.map((e) => e.volume).toList();
//
//     // Indicator checks using new IndicatorUtils API
//     final emaPass = IndicatorUtils.isCloseAboveEMA(history, 20);
//
//     // SMA20 manual computation
//     bool smaPass = false;
//     double? smaValue;
//     if (closes.length >= 20) {
//       final last20 = closes.sublist(closes.length - 20);
//       smaValue = last20.reduce((a, b) => a + b) / last20.length;
//       smaPass = closes.last > smaValue;
//     }
//
//     final rsiPass = IndicatorUtils.isRsiBetween(history, 14, min: 60, max: 90);
//
//     final atrValue = IndicatorUtils.atrLast(highs, lows, closes, period: 14);
//     final atrPass = IndicatorUtils.isAtrGreaterThanAdaptive(history, atrPeriod: 14);
//
//     final vwapPass = IndicatorUtils.isCloseAboveVWAP(history);
//
//     final adxPass = IndicatorUtils.isAdxBullish(history);
//
//     final supertrendPass = IndicatorUtils.isCloseAboveSupertrend(history, atrPeriod: 9, multiplier: 3.0);
//
//     final volBreakout = IndicatorUtils.isVolumeBreakout(history, emaPeriod: 20, factor: 1.5);
//
//     final allPassed = emaPass && smaPass && rsiPass && atrPass && vwapPass && adxPass && supertrendPass && volBreakout;
//
//     showDialog(
//       context: context,
//       builder:
//           (ctx) => AlertDialog(
//                 title: const Text('Indicator Check'),
//                 content: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         allPassed ? 'All indicators passed.' : 'Not all indicators passed.',
//                       ),
//                       const SizedBox(height: 12),
//                       Text("EMA (20): ${emaPass ? 'Pass' : 'Fail'}"),
//                       Text("SMA (20): ${smaPass ? 'Pass' : 'Fail'}${smaValue != null ? ' (SMA=${smaValue.toStringAsFixed(2)})' : ''}"),
//                       Text("RSI (14) 60-90: ${rsiPass ? 'Pass' : 'Fail'}"),
//                       Text("ATR (14) adaptive: ${atrPass ? 'Pass' : 'Fail'}${atrValue != null ? ' (ATR=${atrValue.toStringAsFixed(4)})' : ''}"),
//                       Text("VWAP (session): ${vwapPass ? 'Pass' : 'Fail'}"),
//                       Text("ADX (bullish & rising): ${adxPass ? 'Pass' : 'Fail'}"),
//                       Text("Supertrend (9,3): ${supertrendPass ? 'Pass' : 'Fail'}"),
//                       Text("Volume Breakout (EMA20*1.5): ${volBreakout ? 'Pass' : 'Fail'}"),
//                     ],
//                   ),
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text('OK'),
//                   ),
//                 ],
//               ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Stock Check Screen')),
//       body: Container(),
//     );
//   }
// }
