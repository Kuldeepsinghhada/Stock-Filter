import 'dart:async';
import 'dart:developer' as developer;
import 'models.dart';
import 'order_service.dart';

class OrderMonitor {
  final OrderService orderService;

  OrderMonitor({required this.orderService});

  /// Polls the order status until it reaches a terminal state (COMPLETE, REJECTED, CANCELLED)
  /// or until the timeout is reached.
  /// Returns the final [OrderDetails] if a terminal state is reached, or null if it timed out.
  Future<OrderDetails?> pollOrderStatus({
    required String orderId,
    required Duration pollingInterval,
    required Duration timeout,
  }) async {
    final startTime = DateTime.now();
    developer.log('Starting to poll order $orderId with timeout ${timeout.inSeconds}s', name: 'OrderMonitor');

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final orderDetails = await orderService.getOrderHistory(orderId);
        
        developer.log('Order $orderId status: ${orderDetails.status}', name: 'OrderMonitor');

        if (orderDetails.isComplete || orderDetails.isRejected || orderDetails.isCancelled) {
          return orderDetails;
        }

        // Wait for the polling interval before the next check
        await Future.delayed(pollingInterval);
      } catch (e) {
        developer.log('Error while polling order $orderId: $e', name: 'OrderMonitor');
        // We might want to continue polling even if there's a transient network error,
        // so we just delay and try again.
        await Future.delayed(pollingInterval);
      }
    }

    developer.log('Timeout reached while polling order $orderId', name: 'OrderMonitor');
    return null; // Timed out
  }
}
