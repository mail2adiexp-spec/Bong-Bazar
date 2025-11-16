import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';

class DeliveryPartnerDashboardScreen extends StatefulWidget {
  static const routeName = '/delivery-dashboard';
  const DeliveryPartnerDashboardScreen({super.key});

  @override
  State<DeliveryPartnerDashboardScreen> createState() =>
      _DeliveryPartnerDashboardScreenState();
}

class _DeliveryPartnerDashboardScreenState
    extends State<DeliveryPartnerDashboardScreen> {
  String _selectedFilter = 'assigned'; // assigned, in_progress, completed

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final deliveryPartnerId = auth.currentUser?.uid;

    if (deliveryPartnerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('डिलीवरी डैशबोर्ड')),
        body: const Center(child: Text('कृपया लॉगिन करें')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('डिलीवरी पार्टनर डैशबोर्ड'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'रिफ्रेश करें',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('assigned', 'नए ऑर्डर'),
                  const SizedBox(width: 8),
                  _buildFilterChip('shipped', 'पिक किए गए'),
                  const SizedBox(width: 8),
                  _buildFilterChip('out_for_delivery', 'डिलीवरी में'),
                  const SizedBox(width: 8),
                  _buildFilterChip('delivered', 'पूर्ण'),
                ],
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(deliveryPartnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('त्रुटि: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delivery_dining,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'कोई ऑर्डर नहीं मिला',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final order = OrderModel.fromMap(data, doc.id);

                    return _buildOrderCard(order, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String deliveryPartnerId) {
    var query = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryPartnerId', isEqualTo: deliveryPartnerId);

    // Filter by status
    if (_selectedFilter == 'assigned') {
      // Show orders that are confirmed or packed (ready to pick)
      query = query.where('status', whereIn: ['confirmed', 'packed']);
    } else {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.orderBy('orderDate', descending: true).snapshots();
  }

  Widget _buildOrderCard(OrderModel order, String orderId) {
    final statusColor = _getStatusColor(order.status);
    final canUpdateStatus = _canUpdateStatus(order.status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ऑर्डर #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    order.getStatusText(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Order Details
            _buildDetailRow(
              Icons.calendar_today,
              'दिनांक',
              DateFormat('dd-MM-yyyy HH:mm').format(order.orderDate),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.shopping_bag,
              'आइटम',
              '${order.items.length} आइटम',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.currency_rupee,
              'कुल',
              '₹${order.totalAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.location_on, 'पता', order.deliveryAddress),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'फोन', order.phoneNumber),

            if (canUpdateStatus) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateOrderStatus(orderId, order.status),
                      icon: const Icon(Icons.check_circle),
                      label: Text(_getNextActionLabel(order.status)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // View Details Button
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showOrderDetails(order, orderId),
              icon: const Icon(Icons.info_outline),
              label: const Text('विवरण देखें'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'packed':
        return Colors.orange;
      case 'shipped':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _canUpdateStatus(String currentStatus) {
    return currentStatus == 'confirmed' ||
        currentStatus == 'packed' ||
        currentStatus == 'shipped' ||
        currentStatus == 'out_for_delivery';
  }

  String _getNextActionLabel(String currentStatus) {
    switch (currentStatus) {
      case 'confirmed':
      case 'packed':
        return 'पिक किया';
      case 'shipped':
        return 'डिलीवरी शुरू करें';
      case 'out_for_delivery':
        return 'डिलीवर किया';
      default:
        return 'अपडेट करें';
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'confirmed':
      case 'packed':
        return 'shipped';
      case 'shipped':
        return 'out_for_delivery';
      case 'out_for_delivery':
        return 'delivered';
      default:
        return currentStatus;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    final nextStatus = _getNextStatus(currentStatus);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'status': nextStatus,
            'statusHistory.$nextStatus': FieldValue.serverTimestamp(),
            if (nextStatus == 'delivered')
              'actualDelivery': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('स्टेटस अपडेट हुआ: ${_getStatusLabel(nextStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'shipped':
        return 'पिक किया गया';
      case 'out_for_delivery':
        return 'डिलीवरी में';
      case 'delivered':
        return 'डिलीवर किया गया';
      default:
        return status;
    }
  }

  void _showOrderDetails(OrderModel order, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  bottomSheetContext,
                ).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ऑर्डर विवरण',
                      style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'ऑर्डर #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ग्राहक जानकारी',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('पता'),
                            subtitle: Text(order.deliveryAddress),
                            contentPadding: EdgeInsets.zero,
                          ),
                          ListTile(
                            leading: const Icon(Icons.phone),
                            title: const Text('फोन'),
                            subtitle: Text(order.phoneNumber),
                            contentPadding: EdgeInsets.zero,
                            trailing: IconButton(
                              icon: const Icon(Icons.call),
                              onPressed: () {
                                // TODO: Implement phone call
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Items
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ऑर्डर आइटम',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ...order.items.map(
                            (item) => ListTile(
                              leading: item.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.imageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.shopping_bag),
                                    ),
                              title: Text(item.productName),
                              subtitle: Text('मात्रा: ${item.quantity}'),
                              trailing: Text(
                                '₹${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'कुल राशि',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
