import 'package:flutter/material.dart';

class IndexEntryView extends StatefulWidget {
  const IndexEntryView({
    required this.title,
    required this.isPositive,
    required this.currentPriceController,
    required this.priceChangeController,
    required this.percentController,
    super.key,
    required this.updateSwitch,
  });
  final String title;
  final bool isPositive;
  final TextEditingController currentPriceController;
  final TextEditingController priceChangeController;
  final TextEditingController percentController;
  final Function(bool isPositive) updateSwitch;
  @override
  State<IndexEntryView> createState() => _IndexEntryViewState();
}

class _IndexEntryViewState extends State<IndexEntryView> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: widget.isPositive,
                inactiveThumbColor: Colors.red,
                activeColor: Colors.green,
                onChanged: (value) {
                  widget.updateSwitch(value);
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.currentPriceController,
                  decoration: InputDecoration(
                    labelText: 'Current Price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.priceChangeController,
                  decoration: InputDecoration(
                    labelText: 'Price Change',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.percentController,
                  decoration: InputDecoration(
                    labelText: 'Percentage',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
