import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_demo/Screens/Dashboard/dashboard_screen.dart';
import 'package:stock_demo/Screens/login/login_screen.dart';
import 'package:stock_demo/Utils/sharepreference_helper.dart';
import 'package:stock_demo/Views/home_view/index_entry_view.dart';
import 'package:stock_demo/model/data_model.dart';
import 'package:stock_demo/model/position_model.dart';
import 'package:stock_demo/portfolio_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stock_demo/Utils/utilities.dart';
import 'Screens/Notification/notification_screen.dart';
import 'Services/notification_service.dart';
import 'dart:io';

Widget initialRoute = ZerodhaLoginPage();

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }
  await NotificationService.initialize();
  await Utilities.loadStocksList();

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
        '/notifications': (context) => NotificationScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var niftyPriceController = TextEditingController();
  var niftyChangeController = TextEditingController();
  var niftyPercentController = TextEditingController();
  var isNiftyPositive = true;
  var sensexPriceController = TextEditingController();
  var sensexChangeController = TextEditingController();
  var sensexPercentController = TextEditingController();
  var isSensexPositive = true;
  List<Position> positions = [];

  @override
  void initState() {
    fetchPrices();
    super.initState();
  }

  /// API CALLS

  void fetchPrices() async {
    var nifty = await fetchNiftyPrice();
    var sensex = await fetchSensexPrice();
    print("Sensex: $sensex");
    print("Nifty: $nifty");
    //print("Sensex: $sensex");

    if (nifty != null) {
      niftyPriceController.text = nifty['last'].toString();
      niftyChangeController.text =
          nifty['variation'].toString().contains('-')
              ? nifty['variation'].toString()
              : "+${nifty['variation'].toString()}";
      niftyPercentController.text =
          nifty['percentChange'].toString().contains('-')
              ? nifty['percentChange'].toString()
              : "+${nifty['percentChange'].toString()}";
    }
    if (sensex != null) {
      sensexPriceController.text = sensex['ltp'].toString();
      sensexChangeController.text =
          sensex['chg'].toString().contains('-')
              ? sensex['chg'].toString()
              : "+${sensex['chg'].toString()}";
      sensexPercentController.text =
          sensex['perchg'].toString().contains('-')
              ? sensex['perchg'].toString()
              : "+${sensex['perchg'].toString()}";
    }
  }

  Future<dynamic> fetchNiftyPrice() async {
    final url = Uri.parse('https://www.nseindia.com/api/marketStatus');

    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.61 Safari/537.36',
      'Accept': 'application/json',
      'Referer': 'https://www.nseindia.com/',
    };

    final client = http.Client();

    try {
      final res = await client.get(url, headers: headers);
      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body);
        final nifty = jsonData['marketState'].firstWhere(
          (item) => item['index'] == 'NIFTY 50',
        );
        return nifty;
      }
    } catch (e) {
      print("Nifty fetch error: $e");
    }

    return null;
  }

  Future<dynamic> fetchSensexPrice() async {
    final url = Uri.parse(
      'https://api.bseindia.com/RealTimeBseIndiaAPI/api/GetSensexData/w?code=16',
    );

    final headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
      "Referer": "https://www.bseindia.com/",
      "Accept": "application/json, text/plain, */*",
      "Origin": "https://www.bseindia.com",
    };

    try {
      final res = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body);
        final sensex = jsonData.firstWhere(
          (item) => item['indxnm'] == 'SenSexValue',
        );
        return sensex;
      }
    } catch (e) {
      print("Sensex fetch error: $e");
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue),
      body: Column(
        children: [
          IndexEntryView(
            title: "Nifty",
            isPositive: isNiftyPositive,
            currentPriceController: niftyPriceController,
            priceChangeController: niftyChangeController,
            percentController: niftyPercentController,
            updateSwitch: (bool isPositive) {
              setState(() {
                isNiftyPositive = isPositive;
              });
            },
          ),
          IndexEntryView(
            title: "Sensex",
            isPositive: isSensexPositive,
            currentPriceController: sensexPriceController,
            priceChangeController: sensexChangeController,
            percentController: sensexPercentController,
            updateSwitch: (bool isPositive) {
              setState(() {
                isSensexPositive = isPositive;
              });
            },
          ),

          Container(
            color: Colors.white30,
            child: ListView.builder(
              itemCount: positions.length,
              padding: EdgeInsets.all(20),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, position) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        positions[position].symbol,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(positions[position].ltp.toString()),
                      Text(positions[position].orderType),
                      Text(positions[position].pnl.toString()),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            positions.removeAt(position);
                          });
                        },
                        icon: Icon(Icons.remove, color: Colors.red),
                      ),
                      // IconButton(
                      //   onPressed: () {
                      //     setState(() {
                      //       positions.removeAt(position);
                      //     });
                      //   },
                      //   icon: Icon(Icons.update, color: Colors.red),
                      // ),
                    ],
                  ),
                );
              },
            ),
          ),

          ElevatedButton(
            onPressed: () {
              showStockDialog(context);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Add Stock', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white30,
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Colors.green, // Set your custom background color here
            foregroundColor: Colors.white, // Optional: Text/Icon color
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            DataModel? dataModel;
            if (niftyPriceController.text.trim().isEmpty) {
              dataModel = DataModel(
                niftyPrice: "25212.40",
                niftyChange: "212.20",
                niftyPercent: "0.80",
                sensexPrice: "82408.17",
                sensexChange: "1046.30",
                sensexPercent: "1.29",
                positions: [
                  Position(
                    symbol: "MISDD",
                    orderType: "MIS",
                    pnl: 12000.94,
                    ltp: 1027.38,
                  ),
                  Position(
                    symbol: "AFBRL",
                    orderType: "COVER ORDER",
                    pnl: 8000.40,
                    ltp: 99.80,
                  ),
                  Position(
                    symbol: "POPIND",
                    orderType: "MIS",
                    pnl: 2000.30,
                    ltp: 339.40,
                  ),
                ],
              );
            } else {
              dataModel = DataModel(
                niftyPrice: niftyPriceController.text ?? "25212.40",
                niftyChange: niftyChangeController.text,
                niftyPercent: niftyPercentController.text,
                sensexPrice: sensexPriceController.text,
                sensexChange: sensexChangeController.text,
                sensexPercent: sensexPercentController.text,
                positions: positions,
              );
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PortfolioScreen(dataModel: dataModel!),
              ),
            );
          },
          child: Text("SUBMIT"),
        ),
      ),
    );
  }

  void showStockDialog(BuildContext context) async {
    final TextEditingController stockController = TextEditingController();
    final TextEditingController profitController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String orderType = 'COVER ORDER';

    var data = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Stock Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: stockController,
                      decoration: InputDecoration(labelText: 'Stock Name'),
                      onChanged: (value) {
                        stockController.text =
                            stockController.text.toUpperCase();
                      },
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: profitController,
                      decoration: InputDecoration(labelText: 'Profit'),
                      //keyboardType: TextInputType.numberWithOptions(signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(
                            r'^[-+]?\d*\.?\d*',
                          ), // Allows digits, optional + or -, and decimals
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(labelText: 'Current Price'),
                      keyboardType: TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(
                            r'^[-+]?\d*\.?\d*',
                          ), // Allows digits, optional + or -, and decimals
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: orderType,
                      items:
                          ['COVER ORDER', 'MIS']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          orderType = value!;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Order Type'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Do something with the input
                    Position position = Position(
                      symbol: stockController.text,
                      orderType: orderType,
                      pnl: double.parse(profitController.text),
                      ltp: double.parse(priceController.text),
                    );
                    Navigator.pop(context, position);
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    if (data is Position) {
      positions.add(data);
      setState(() {});
    }
  }
}
