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
        title: const Text('Executed Orders',
            style: TextStyle(color: Colors.white)),
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
            return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Error fetching orders",
                  style: const TextStyle(color: Colors.white70)),
            );
          }

          final orders = snapshot.data;
          if (orders == null || orders.isEmpty) {
            return const Center(
              child: Text("No executed orders found.",
                  style: TextStyle(color: Colors.white70)),
            );
          }

          double totalPnlPercentage = 0.0;
          for (var o in orders) {
            if (o.profitLossPercentage != null) {
              totalPnlPercentage += o.profitLossPercentage!;
            }
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: Column(
              children: [
                _buildTotalPnlCard(totalPnlPercentage),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderTile(order);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalPnlCard(double totalPnl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xff1e222d),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: totalPnl >= 0
                ? Colors.green.withOpacity(0.5)
                : Colors.red.withOpacity(0.5),
            width: 1.5),
      ),
      child: Column(
        children: [
          const Text("Total P&L %",
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(2)}%',
            style: TextStyle(
              color: totalPnl >= 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status.toUpperCase() == 'ACTIVE'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: order.status.toUpperCase() == 'ACTIVE'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: order.status.toUpperCase() == 'ACTIVE'
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Buy Price', '₹${order.buyingPrice.toStringAsFixed(2)}'),
            if (order.exitPrice != null) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                  'Exit Price', '₹${order.exitPrice!.toStringAsFixed(2)}'),
            ],
            if (order.profitLossPercentage != null) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                'P&L %',
                '${order.profitLossPercentage! >= 0 ? '+' : ''}${order.profitLossPercentage!.toStringAsFixed(2)}%',
                valueColor: order.profitLossPercentage! >= 0
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ],
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
