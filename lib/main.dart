import 'package:flutter/material.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_screen.dart';
import 'package:stock_demo/Screens/Investment/investment_screen.dart';
import 'package:stock_demo/Screens/login/login_screen.dart';
import 'package:stock_demo/Services/notification_service.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Utils/utilities.dart';
import 'package:stock_demo/trading/trading_manager.dart';

Widget initialRoute = const ZerodhaLoginPage();

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await Utilities.loadStocksList();
  await TradingManager.instance.init();

  var isLogin = await checkUserLoggedIn();
  if (isLogin) {
    initialRoute = const DashboardScreen();
  }
  runApp(const TradingPrototype());
}

Future<bool> checkUserLoggedIn() async {
  final token = await SharedPreferenceHelper.instance.getToken();
  final expiry = await SharedPreferenceHelper.instance.getTokenExpiry();
  final now = DateTime.now().millisecondsSinceEpoch;
  if (token != null && expiry != null && now < expiry) {
    return true;
  }
  return false;
}

class TradingPrototype extends StatelessWidget {
  const TradingPrototype({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: initialRoute,
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/investments': (context) => const InvestmentScreen(),
      },
    );
  }
}
