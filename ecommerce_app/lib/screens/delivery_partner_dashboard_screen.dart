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
  String? _servicePincode;
  bool _isLoadingPincode = true;

  @override
  void initState() {
    super.initState();
    _fetchServicePincode();
  }

  Future<void> _fetchServicePincode() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (mounted) {
        setState(() {
          _servicePincode = doc.data()?['service_pincode'];
          _isLoadingPincode = false;
        });
      }
    } catch (e) {
      print('Error fetching pincode: $e');
      if (mounted) {
        setState(() => _isLoadingPincode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final deliveryPartnerId = auth.currentUser?.uid;

    if (deliveryPartnerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Dashboard')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delivery Partner Dashboard'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Available Orders', icon: Icon(Icons.notifications_active)),
              Tab(text: 'My Deliveries', icon: Icon(Icons.local_shipping)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchServicePincode();
                setState(() {});
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAvailableOrdersTab(deliveryPartnerId),
            _buildMyDeliveriesTab(deliveryPartnerId),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableOrdersTab(String partnerId) {
    if (_isLoadingPincode) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_servicePincode == null || _servicePincode!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Service Area Not Set',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please contact Admin to set your Service Pincode\nto receive order broadcasts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue[50],
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing orders in Pincode: $_servicePincode',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryPincode', isEqualTo: _servicePincode)
                .where('deliveryPartnerId', isNull: true)
                // Note: This requires a composite index. If it fails, we might need to filter client-side
                // or just query by pincode and filter in builder.
                // For now, let's try client-side filtering for partnerId to avoid index issues immediately
                // .where('status', whereIn: ['confirmed', 'packed']) // Optional: only show ready orders
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Client-side filter for unassigned orders (if query index is missing)
              final docs = snapshot.data?.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['deliveryPartnerId'] == null || 
                       data['deliveryPartnerId'] == '';
              }).toList() ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No new orders in your area',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  return _buildBroadcastOrderCard(order, partnerId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBroadcastOrderCard(OrderModel order, String partnerId) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW REQUEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Order #${order.id.substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptOrder(order.id, partnerId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'ACCEPT ORDER',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOrder(String orderId, String partnerId) async {
    try {
      // Use transaction to prevent race conditions
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw Exception("Order does not exist!");
        }

        final data = orderDoc.data() as Map<String, dynamic>;
        if (data['deliveryPartnerId'] != null && data['deliveryPartnerId'] != '') {
          throw Exception("Order already taken by another partner!");
        }

        transaction.update(orderRef, {
          'deliveryPartnerId': partnerId,
          'status': 'confirmed', // Ensure it's in a valid state for delivery
          'statusHistory.assigned': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order Accepted Successfully! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMyDeliveriesTab(String partnerId) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('assigned', 'Active'),
                const SizedBox(width: 8),
                _buildFilterChip('shipped', 'Picked'),
                const SizedBox(width: 8),
                _buildFilterChip('out_for_delivery', 'Out for Delivery'),
                const SizedBox(width: 8),
                _buildFilterChip('delivered', 'Delivered'),
              ],
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getOrdersStream(partnerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
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
                        'No ${_selectedFilter == 'assigned' ? 'active' : _selectedFilter} deliveries',
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final hasPermission = user?.hasPermission('can_update_status') ?? false;

    final statusColor = _getStatusColor(order.status);
    final canUpdateStatus = _canUpdateStatus(order.status) && hasPermission;

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
                    'Order #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
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
              'Date',
              DateFormat('dd-MM-yyyy HH:mm').format(order.orderDate),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.shopping_bag,
              'Items',
              '${order.items.length} items',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.currency_rupee,
              'Total',
              '₹${order.totalAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on,
              'Address',
              order.deliveryAddress,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'Phone', order.phoneNumber),

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

            // Release Order Button (Only if not yet picked up)
            if (order.status == 'confirmed' || order.status == 'packed') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _releaseOrder(orderId),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Release / Reject Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],

            // View Details Button
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showOrderDetails(order, orderId),
              icon: const Icon(Icons.info_outline),
              label: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _releaseOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release Order?'),
        content: const Text(
          'Are you sure you want to release this order? It will be made available to other delivery partners.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Release'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'deliveryPartnerId': null, // Remove assignment
            'status': 'confirmed', // Reset status if needed
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order released successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        return 'Mark as Picked';
      case 'shipped':
        return 'Start Delivery';
      case 'out_for_delivery':
        return 'Mark Delivered';
      default:
        return 'Update';
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
            content: Text('Status updated: ${_getStatusLabel(nextStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'shipped':
        return 'Picked';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
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
                      'Order Details',
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
                    'Order #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
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
                            'Customer Info',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Address'),
                            subtitle: Text(order.deliveryAddress),
                            contentPadding: EdgeInsets.zero,
                          ),
                          ListTile(
                            leading: const Icon(Icons.phone),
                            title: const Text('Phone'),
                            subtitle: Text(order.phoneNumber),
                            contentPadding: EdgeInsets.zero,
                            trailing: IconButton(
                              icon: const Icon(Icons.call),
                              onPressed: () {},
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
                            'Order Items',
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
                              subtitle: Text('Qty: ${item.quantity}'),
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
                                'Total Amount',
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
