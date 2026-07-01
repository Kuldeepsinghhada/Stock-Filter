import 'dart:developer' as developer;
import 'kite_api_client.dart';
import 'models.dart';

class OrderService {
  final KiteApiClient apiClient;

  OrderService({required this.apiClient});

  /// Place an order.
  /// Returns the order_id as a String.
  Future<String> placeOrder({
    required String variety,
    required String exchange,
    required String tradingsymbol,
    required String transactionType, // BUY or SELL
    required int quantity,
    required String product, // MIS, CNC, NRML
    required String orderType, // MARKET, LIMIT, SL, SL-M
    double? price,
    double? triggerPrice,
  }) async {
    final Map<String, dynamic> payload = {
      'exchange': exchange,
      'tradingsymbol': tradingsymbol,
      'transaction_type': transactionType,
      'quantity': quantity.toString(),
      'product': product,
      'order_type': orderType,
    };

    if (price != null) {
      payload['price'] = price.toString();
    }
    if (triggerPrice != null) {
      payload['trigger_price'] = triggerPrice.toString();
    }

    try {
      final response = await apiClient.post('/orders/$variety', payload);
      if (response != null && response['order_id'] != null) {
        return response['order_id'];
      }
      throw Exception('Order ID not found in response: $response');
    } catch (e) {
      developer.log('Failed to place $transactionType order for $tradingsymbol', name: 'OrderService', error: e);
      rethrow;
    }
  }

  /// Get order details/history.
  /// The Kite API returns an array of order history. The last element is the current state.
  Future<OrderDetails> getOrderHistory(String orderId) async {
    try {
      final response = await apiClient.get('/orders/$orderId');
      if (response is List && response.isNotEmpty) {
        // The last item in the list contains the most recent status.
        final latestStatus = response.last as Map<String, dynamic>;
        return OrderDetails.fromJson(latestStatus);
      }
      throw Exception('Invalid order history response for $orderId: $response');
    } catch (e) {
      developer.log('Failed to fetch order history for $orderId', name: 'OrderService', error: e);
      rethrow;
    }
  }

  /// Cancel an open order.
  Future<String> cancelOrder(String orderId, {String variety = 'regular'}) async {
    try {
      final response = await apiClient.delete('/orders/$variety/$orderId');
      if (response != null && response['order_id'] != null) {
        return response['order_id'];
      }
      throw Exception('Failed to cancel order $orderId: $response');
    } catch (e) {
      developer.log('Failed to cancel order $orderId', name: 'OrderService', error: e);
      rethrow;
    }
  }
}
