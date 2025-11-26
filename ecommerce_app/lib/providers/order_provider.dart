import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'auth_provider.dart';

class OrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider authProvider;

  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;

  OrderProvider(this.authProvider);

  Future<void> fetchUserOrders() async {
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      debugPrint('OrderProvider: No user logged in');
      _orders = [];
      notifyListeners();
      return;
    }

    debugPrint('OrderProvider: Fetching orders for user $userId');
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      debugPrint('OrderProvider: Found ${snapshot.docs.length} orders');
      _orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort orders by date in memory (temporary until Firebase index is created)
      _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      _orders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createOrder({
    required List<OrderItem> items,
    required double totalAmount,
    required String deliveryAddress,
    required String phoneNumber,
  }) async {
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      debugPrint('OrderProvider: Cannot create order - no user logged in');
      return null;
    }

    debugPrint('OrderProvider: Creating order for user $userId');
    debugPrint('OrderProvider: Items count: ${items.length}');
    debugPrint('OrderProvider: Total amount: $totalAmount');

    try {
      // Extract pincode from address
      final pincodeRegex = RegExp(r'\b\d{6}\b');
      final pincodeMatch = pincodeRegex.firstMatch(deliveryAddress);
      final deliveryPincode = pincodeMatch?.group(0);

      final orderData = {
        'userId': userId,
        'items': items.map((item) => item.toMap()).toList(),
        'totalAmount': totalAmount,
        'deliveryAddress': deliveryAddress,
        'phoneNumber': phoneNumber,
        'orderDate': DateTime.now().toIso8601String(),
        'status': 'pending',
        'statusHistory': {'pending': DateTime.now().toIso8601String()},
        'deliveryPincode': deliveryPincode,
      };

      final docRef = await _firestore.collection('orders').add(orderData);
      debugPrint('OrderProvider: Order created with ID: ${docRef.id}');

      // Increment orderCount for the user
      await _firestore.collection('users').doc(userId).update({
        'orderCount': FieldValue.increment(1),
      });

      await fetchUserOrders(); // Refresh orders
      debugPrint('OrderProvider: Orders refreshed, count: ${_orders.length}');

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating order: $e');
      return null;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'statusHistory.$newStatus': DateTime.now().toIso8601String(),
      });

      // Record transaction if order is delivered
      if (newStatus == 'delivered') {
        final orderDoc = await _firestore.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          await _processSellerTransactions(orderId, orderData, TransactionType.credit);
        }
      } 
      // Record debit transaction if order is returned
      else if (newStatus == 'returned') {
        final orderDoc = await _firestore.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          // Only debit if it was previously delivered (meaning they were credited)
          // or if we want to be strict, check status history.
          // For now, we assume 'returned' flow comes after 'delivered'.
          
          await _processSellerTransactions(orderId, orderData, TransactionType.debit);
        }
      }

      await fetchUserOrders();
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return OrderModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('Error fetching order: $e');
    }
    return null;
  }

  Future<void> _processSellerTransactions(
    String orderId, 
    Map<String, dynamic> orderData, 
    TransactionType type
  ) async {
    final items = (orderData['items'] as List<dynamic>?) ?? [];
    final Map<String, double> sellerAmounts = {};

    for (var item in items) {
      final sellerId = item['sellerId'] as String?;
      if (sellerId != null && sellerId.isNotEmpty) {
        final price = (item['price'] as num).toDouble();
        final quantity = (item['quantity'] as num).toInt();
        final total = price * quantity;
        sellerAmounts[sellerId] = (sellerAmounts[sellerId] ?? 0) + total;
      }
    }

    final transactionService = TransactionService();
    for (var entry in sellerAmounts.entries) {
      final sellerId = entry.key;
      final amount = entry.value;
      
      final description = type == TransactionType.credit 
          ? 'Earnings for Order #$orderId' 
          : 'Refund for Order #$orderId';

      final transaction = TransactionModel(
        id: '', // Firestore will generate ID
        userId: sellerId,
        amount: amount,
        type: type,
        description: description,
        status: TransactionStatus.completed,
        referenceId: orderId,
        createdAt: DateTime.now(),
      );

      await transactionService.recordTransaction(transaction);
    }
  }

  void clear() {
    _orders = [];
    notifyListeners();
  }
}
