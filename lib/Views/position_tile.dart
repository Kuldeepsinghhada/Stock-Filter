import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/app_colors.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/model/position_model.dart';

class PositionTile extends StatelessWidget {
  final Position position;
  const PositionTile({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    final isPositive = position.pnl >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '0 SHARES',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  position.symbol,
                  style: TextStyle(
                    fontSize: 14,
                    //fontWeight: FontWeight.w500,
                    color: darkGreyColor,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'NSE • AVG ',
                        style: TextStyle(
                          color: greyColor, // Grey color for "LTP"
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: "0.00",
                        style: TextStyle(
                          color: Colors.white, // White color for number
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                position.orderType,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                (position.pnl > 0 ? "+" : "") +
                    Utilities.formatIndianNumber(
                      double.parse(position.pnl.toStringAsFixed(2)),
                    ),
                style: TextStyle(
                  fontSize: 14,
                  //fontWeight: FontWeight.w500,
                  color: darkGreyColor,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'LTP ',
                      style: TextStyle(
                        color: greyColor, // Grey color for "LTP"
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: position.ltp.toStringAsFixed(2),
                      style: TextStyle(
                        color: Colors.white, // White color for number
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
