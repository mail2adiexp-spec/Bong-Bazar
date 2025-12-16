
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class SellerOrdersDialog extends StatefulWidget {
  final AppUser user;

  const SellerOrdersDialog({super.key, required this.user});

  @override
  State<SellerOrdersDialog> createState() => _SellerOrdersDialogState();
}

class _SellerOrdersDialogState extends State<SellerOrdersDialog> {
  String _selectedStatus = 'All';
  late Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream only once
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 900,
      height: 700,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Orders',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          
          // Status Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'pending', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled']
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status == 'All' ? status : status.replaceAll('_', ' ').toUpperCase()),
                          selected: _selectedStatus == status,
                          onSelected: (selected) {
                            setState(() => _selectedStatus = status);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _ordersStream, // Use cached stream
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter orders containing seller's products
                final allOrders = snapshot.data?.docs ?? [];
                final relevantOrders = allOrders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final items = data['items'] as List<dynamic>? ?? [];
                  
                  // Check if order contains seller's products
                  bool hasSellersProduct = items.any((item) => item['sellerId'] == widget.user.uid);
                  if (!hasSellersProduct) return false;
                  
                  // Apply status filter
                  if (_selectedStatus != 'All') {
                    final orderStatus = data['status'] ?? 'pending';
                    return orderStatus == _selectedStatus;
                  }
                  return true;
                }).toList();

                if (relevantOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatus == 'All' ? 'No orders yet' : 'No $_selectedStatus orders',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: relevantOrders.length,
                  itemBuilder: (context, index) {
                    final orderData = relevantOrders[index].data() as Map<String, dynamic>;
                    final orderId = relevantOrders[index].id;
                    final status = orderData['status'] ?? 'pending';
                    final items = orderData['items'] as List<dynamic>? ?? [];
                    
                    // Filter only seller's items
                    final sellerItems = items.where((item) => item['sellerId'] == widget.user.uid).toList();
                    
                    // Calculate seller's portion
                    double sellerTotal = 0;
                    for (var item in sellerItems) {
                      final price = (item['price'] as num?)?.toDouble() ?? 0;
                      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                      sellerTotal += price * quantity;
                    }

                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'delivered':
                        statusColor = Colors.green;
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        break;
                      case 'pending':
                        statusColor = Colors.orange;
                        break;
                      default:
                        statusColor = Colors.blue;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(Icons.shopping_bag, color: statusColor),
                        ),
                        title: Text(
                          'Order #${orderId.substring(0, 8)}...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${sellerItems.length} item(s) • ₹${sellerTotal.toStringAsFixed(0)}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Items:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...sellerItems.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item['name']} x${item['quantity']}',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Text(
                                            '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '₹${sellerTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
