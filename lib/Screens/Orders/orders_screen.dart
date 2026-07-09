import 'package:flutter/material.dart';
import 'package:stock_demo/APIService/backend_order_service.dart';
import 'package:stock_demo/model/executed_order.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late Future<List<ExecutedOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = BackendOrderService.getExecutedOrders();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = BackendOrderService.getExecutedOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff131722),
      appBar: AppBar(
        title: const Text('Executed Orders', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff1e222d),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<ExecutedOrder>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Error fetching orders", style: const TextStyle(color: Colors.white70)),
            );
          }

          final orders = snapshot.data;
          if (orders == null || orders.isEmpty) {
            return const Center(
              child: Text("No executed orders found.", style: TextStyle(color: Colors.white70)),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderTile(order);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderTile(ExecutedOrder order) {
    return Card(
      color: const Color(0xff1e222d),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.stockName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status.toUpperCase() == 'ACTIVE' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: order.status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: order.status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Buy Price', '₹${order.buyingPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            _buildInfoRow('Main Order ID', order.mainOrderId),
            const SizedBox(height: 6),
            _buildInfoRow('SL Order ID', order.slOrderId),
            const SizedBox(height: 6),
            _buildInfoRow('Target Order ID', order.targetOrderId),
            const SizedBox(height: 12),
            if (order.createdAt != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Executed on: ${order.createdAt!.toLocal().toString().split('.')[0]}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
