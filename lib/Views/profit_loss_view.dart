import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/app_colors.dart';
import 'package:stock_demo/Utils/utilities.dart';

class ProfitLossHeader extends StatelessWidget {
  final double pnl;
  const ProfitLossHeader({super.key, required this.pnl});

  @override
  Widget build(BuildContext context) {
    final isPositive = pnl >= 0;
    return Container(
      color: lightBGColor,
      margin: EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(
            'Profit/Loss',
            style: TextStyle(
              color: darkGreyColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 12),
          Text(
            "${isPositive ? "+" : "-"}${formatIndianNumber(int.parse(pnl.toStringAsFixed(0))).replaceAll("-", "")}",
            style: TextStyle(
              color: isPositive ? greenColor : redColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded, color: blueColor),
        ],
      ),
    );
  }
}
