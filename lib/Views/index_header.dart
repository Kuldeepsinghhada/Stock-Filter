import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/app_colors.dart';
import 'package:stock_demo/model/data_model.dart';

class IndexHeader extends StatelessWidget {
  const IndexHeader({required this.dataModel,super.key});
  final DataModel dataModel;
  @override
  Widget build(BuildContext context) {

    TextStyle value = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
    TextStyle changePos = TextStyle(
      color: dataModel.niftyChange.contains("-") ? redColor :greenColor,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return Container(
      color: lightBGColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(width: 12),
                  _indexItem(
                    title: 'NIFTY',
                    value: dataModel.niftyPrice,
                    change: '${dataModel.niftyChange} (${dataModel.niftyPercent}%)',
                    valueStyle: value,
                    changeStyle: changePos,
                  ),
                  SizedBox(width: 12),
                  _indexItem(
                    title: 'SENSEX',
                    value: dataModel.sensexPrice,
                    change: '${dataModel.sensexChange} (${dataModel.sensexPercent}%)',
                    valueStyle: value,
                    changeStyle: changePos,
                  ),
                  SizedBox(width: 12),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Image.asset("assets/down_arrow.png",scale: 4,),
          ),
        ],
      ),
    );
  }

  Widget _indexItem({
    required String title,
    required String value,
    required String change,
    required TextStyle valueStyle,
    required TextStyle changeStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            Text(value, style: valueStyle),
            SizedBox(width: 4),
            Text(change, style: changeStyle, overflow: TextOverflow.ellipsis),
          ],
        ),
      ],
    );
  }
}
