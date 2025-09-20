import 'package:flutter/material.dart';
import 'package:stock_demo/Utils/app_colors.dart';
import 'package:stock_demo/Views/action_bar.dart';
import 'package:stock_demo/Views/index_header.dart';
import 'package:stock_demo/Views/position_tile.dart';
import 'package:stock_demo/Views/profit_loss_view.dart';
import 'package:stock_demo/Views/square_off_view.dart';
import 'package:stock_demo/Views/tab_selector_view.dart';
import 'package:stock_demo/model/data_model.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({required this.dataModel, super.key});
  final DataModel dataModel;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  var profit = 0.0;

  @override
  void initState() {
    calculateProfit();
    super.initState();
  }

  calculateProfit() {
    for (var item in widget.dataModel.positions) {
      profit += item.pnl;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(),
      backgroundColor: lightBGColor,
      bottomNavigationBar: const _BottomNavBar(),
      body: SafeArea(
        child: Container(
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IndexHeader(dataModel: widget.dataModel),
              TabSelector(
                selected: 'POSITIONS',
                badgeCount: widget.dataModel.positions.length,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ProfitLossHeader(pnl: profit),
                      ActionBar(),
                      Container(
                        color: lightBGColor,
                        child: ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: widget.dataModel.positions.length,
                          separatorBuilder:
                              (_, __) => Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                          itemBuilder:
                              (context, index) => PositionTile(
                                position: widget.dataModel.positions[index],
                              ),
                        ),
                      ),
                      SquareOffView(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//──────────────────────── BOTTOM NAV BAR ────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      unselectedItemColor: Colors.grey,
      selectedItemColor: Colors.blueAccent,
      currentIndex: 3, // Portfolio selected
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border),
          label: 'Watchlist',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Portfolio',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Invest'),
      ],
    );
  }
}
