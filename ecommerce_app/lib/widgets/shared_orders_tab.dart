import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SharedOrdersTab extends StatefulWidget {
  final bool canManage;
  final String? sellerId; // Optional: to filter orders for a specific seller
  final bool isDeliveryPartner; // Optional: for Delivery Partner dashboard specific view

  const SharedOrdersTab({
    Key? key, 
    this.canManage = true,
    this.sellerId,
    this.isDeliveryPartner = false,
  }) : super(key: key);

  @override
  State<SharedOrdersTab> createState() => _SharedOrdersTabState();
}

class _SharedOrdersTabState extends State<SharedOrdersTab> {
  final List<String> _statuses = const [
    'pending',
    'confirmed',
    'packed',
    'shipped',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load orders: ${snapshot.error}'),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final userId = data['userId'] as String? ?? '-';
                    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final status = data['status'] as String? ?? 'pending';
                    final orderDateStr = data['orderDate'] as String?;
                    DateTime? orderDate;
                    try {
                      if (orderDateStr != null) {
                        orderDate = DateTime.tryParse(orderDateStr);
                      }
                    } catch (_) {}

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('User: $userId'),
                                  const SizedBox(height: 2),
                                  Text('Total: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(total)}'),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Date: ${orderDate != null ? DateFormat('dd-MM-yyyy HH:mm').format(orderDate) : '-'}',
                                  ),
                                  if (data['deliveryPartnerName'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Runner: ${data['deliveryPartnerName']}',
                                        style: TextStyle(
                                          fontSize: 12, 
                                          color: Colors.blue[700], 
                                          fontWeight: FontWeight.w500
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (widget.canManage) ...[
                              DropdownButton<String>(
                                value: _statuses.contains(status) ? status : 'pending',
                                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                                onChanged: (val) async {
                                  if (val == null) return;
                                  try {
                                    final batch = FirebaseFirestore.instance.batch();
                                    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
                                    
                                    batch.update(orderRef, {
                                      'status': val,
                                      'statusHistory.$val': FieldValue.serverTimestamp(),
                                    });

                                    await batch.commit();

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${val.replaceAll('_', ' ')}')));
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                                    }
                                  }
                                },
                              ),
                              if (!widget.isDeliveryPartner) // Don't show assign button to delivery partners themselves generally, unless admin allows
                                IconButton(
                                  icon: const Icon(Icons.person_add),
                                  tooltip: 'Assign Delivery Partner',
                                  onPressed: () => _showAssignDeliveryPartnerDialog(orderId, data),
                                  color: Colors.blue,
                                ),
                            ] else ...[
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: _getStatusColor(status).withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(4),
                                   border: Border.all(color: _getStatusColor(status)),
                                 ),
                                 child: Text(
                                   status.toUpperCase().replaceAll('_', ' '),
                                   style: TextStyle(
                                     color: _getStatusColor(status),
                                     fontSize: 12,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ),
                            ],
                          ],
                        ),
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

  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = FirebaseFirestore.instance.collection('orders').orderBy('orderDate', descending: true);
    
    // Future: Apply filters if needed (e.g. sellerId) across "order items" subcollections or if sellerId is on main order.
    // Assuming sellerId is not on main order for now (multi-vendor orders usually split or complex).
    // If widget.sellerId is passed, we might need a different structure or query. 
    // Allowing default admin view (all orders) for now.
    
    if (widget.isDeliveryPartner) {
        // Implementation for delivery partner specific stream if needed
        // For now, core staff might see all or filter.
    }

    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'packed': return Colors.indigo;
      case 'shipped': return Colors.purple;
      case 'out_for_delivery': return Colors.teal;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _showAssignDeliveryPartnerDialog(String orderId, Map<String, dynamic> orderData) async {
    final deliveryPartnersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'delivery_partner')
        .get();

    if (!mounted) return;

    final deliveryPartners = deliveryPartnersSnapshot.docs;

    if (deliveryPartners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No delivery partners found')));
      return;
    }

    String? selectedPartnerId = orderData['deliveryPartnerId'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Delivery Partner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (orderData['deliveryPartnerName'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Currently assigned to: ${orderData['deliveryPartnerName']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              DropdownButtonFormField<String>(
                value: selectedPartnerId,
                decoration: const InputDecoration(labelText: 'Select Delivery Partner', border: OutlineInputBorder()),
                items: deliveryPartners.map((doc) {
                  final data = doc.data();
                  return DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? doc.id));
                }).toList(),
                onChanged: (value) => setState(() => selectedPartnerId = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            if (selectedPartnerId != null && orderData['deliveryPartnerId'] != null)
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                      'deliveryPartnerId': FieldValue.delete(),
                      'deliveryPartnerName': FieldValue.delete(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery partner unassigned')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Unassign', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: selectedPartnerId == null
                  ? null
                  : () async {
                      try {
                        final partnerDoc = deliveryPartners.firstWhere((doc) => doc.id == selectedPartnerId);
                        final partnerData = partnerDoc.data();
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                          'deliveryPartnerId': selectedPartnerId,
                          'deliveryPartnerName': partnerData['name'] ?? 'Unknown',
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery partner assigned successfully')));
                        }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}
