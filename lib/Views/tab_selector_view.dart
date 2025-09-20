import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/app_colors.dart';

class TabSelector extends StatelessWidget {
  final String selected;
  final int badgeCount;
  const TabSelector({
    super.key,
    required this.selected,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return Container(
      decoration: BoxDecoration(color: lightBGColor),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text(
                      'INVESTMENTS',
                      style: textStyle.copyWith(color: greyColor),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'POSITIONS',
                          style: textStyle.copyWith(
                            color: blueColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            " ${badgeCount.toString()} ",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: SizedBox()),
              Expanded(child: Container(height: 2, color: blueColor)),
            ],
          ),
        ],
      ),
    );
  }
}
