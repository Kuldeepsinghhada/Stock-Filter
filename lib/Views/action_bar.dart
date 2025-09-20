import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/app_colors.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        //mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 10,
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: lightBGColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Row(
                children: [
                  //const Icon(Icons.search_sharp, size: 28, color: Colors.grey),
                  Image.asset("assets/search.png", scale: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search in positions',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: greyColor, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // const SizedBox(width: 8),
          _actionIcon(Icons.auto_graph_outlined, label: 'Analyze'),
          //const SizedBox(width: 8),
          _actionIcon(
            Icons.filter_list,
            color: blueColor,
            imageName: "assets/menu.png",
          ),
          //const SizedBox(width: 8),
          _actionIcon(Icons.more_vert, color: blueColor),
        ],
      ),
    );
  }

  Widget _actionIcon(
    IconData icon, {
    String? label,
    Color? color,
    String? imageName,
  }) {
    return Container(
      height: 36,
      padding:
          label != null
              ? const EdgeInsets.symmetric(horizontal: 18, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: lightBGColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Center(
        child:
            label == null
                ? imageName != null
                    ? Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2),
                      child: Image.asset(imageName, scale: 6.5),
                    )
                    : Icon(icon, color: color ?? greyColor)
                : Row(
                  children: [
                    Image.asset("assets/trend.png", scale: 7),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: greyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
