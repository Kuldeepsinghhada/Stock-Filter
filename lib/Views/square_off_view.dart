import 'package:flutter/material.dart';

class SquareOffView extends StatelessWidget {
  const SquareOffView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: Color(0xff0E2A38),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Text(
        "Long press on any of position to square off multiple positions at market price.",
        style: TextStyle(
          color: Colors.white30,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
