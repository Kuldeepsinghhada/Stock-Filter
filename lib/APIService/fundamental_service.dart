import 'dart:convert';
import 'package:http/http.dart' as http;

class FundamentalService {
  FundamentalService._();
  static final FundamentalService instance = FundamentalService._();

  // Example method to demonstrate functionality
  Future<Map<String, dynamic>> fetchFundamentals(List<String> symbols) async {
    final batch = symbols.join(',.NS');
    final url = Uri.parse(
      "https://api.twelvedata.com/quote?symbol=$batch&apikey=1d326deceeaa4af786847acb74b1384e",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Error: ${response.statusCode}");
    }
  }
}
