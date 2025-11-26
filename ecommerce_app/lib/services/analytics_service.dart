import 'package:cloud_firestore/cloud_firestore.dart';

// Data Models for Analytics
class DailySales {
  final DateTime date;
  final double revenue;
  final int orderCount;

  DailySales({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });
}

class TopProduct {
  final String productId;
  final String name;
  final int salesCount;
  final double revenue;

  TopProduct({
    required this.productId,
    required this.name,
    required this.salesCount,
    required this.revenue,
  });
}

class UserGrowth {
  final DateTime date;
  final int newUsers;
  final int totalUsers;

  UserGrowth({
    required this.date,
    required this.newUsers,
    required this.totalUsers,
  });
}

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== REVENUE ANALYTICS ====================

  /// Get total revenue from all completed orders
  Future<double> getTotalRevenue() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      return snapshot.docs.fold<double>(
        0,
        (sum, doc) => sum + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0),
      );
    } catch (e) {
      print('Error getting total revenue: $e');
      return 0;
    }
  }

  /// Get revenue by date range
  Future<Map<String, double>> getRevenueByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      double productsRevenue = 0;
      double servicesRevenue = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final items = data['items'] as List? ?? [];

        // Check if order contains products or services
        bool hasProducts = items.any((item) => item['type'] == 'product');
        bool hasServices = items.any((item) => item['type'] == 'service');

        if (hasProducts) productsRevenue += amount;
        if (hasServices) servicesRevenue += amount;
      }

      return {
        'products': productsRevenue,
        'services': servicesRevenue,
      };
    } catch (e) {
      print('Error getting revenue by date range: $e');
      return {'products': 0, 'services': 0};
    }
  }

  /// Get daily sales for a date range
  Future<List<DailySales>> getDailySales(DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt')
          .get();

      // Group by date
      Map<String, DailySales> salesByDate = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day).toString();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;

        if (salesByDate.containsKey(dateKey)) {
          salesByDate[dateKey] = DailySales(
            date: salesByDate[dateKey]!.date,
            revenue: salesByDate[dateKey]!.revenue + amount,
            orderCount: salesByDate[dateKey]!.orderCount + 1,
          );
        } else {
          salesByDate[dateKey] = DailySales(
            date: DateTime(createdAt.year, createdAt.month, createdAt.day),
            revenue: amount,
            orderCount: 1,
          );
        }
      }

      return salesByDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print('Error getting daily sales: $e');
      return [];
    }
  }

  // ==================== ORDER ANALYTICS ====================

  /// Get total number of orders
  Future<int> getTotalOrders() async {
    try {
      final snapshot = await _firestore.collection('orders').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting total orders: $e');
      return 0;
    }
  }

  /// Get orders count by status
  Future<Map<String, int>> getOrdersByStatus() async {
    try {
      final snapshot = await _firestore.collection('orders').get();

      Map<String, int> statusCounts = {
        'pending': 0,
        'processing': 0,
        'delivered': 0,
        'returned': 0,
      };

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'pending';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      print('Error getting orders by status: $e');
      return {};
    }
  }

  // ==================== PRODUCT ANALYTICS ====================

  /// Get total number of products sold
  Future<int> getTotalProductsSold() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      int totalQuantity = 0;
      for (var doc in snapshot.docs) {
        final items = doc.data()['items'] as List? ?? [];
        for (var item in items) {
          if (item['type'] == 'product') {
            totalQuantity += (item['quantity'] as int?) ?? 0;
          }
        }
      }

      return totalQuantity;
    } catch (e) {
      print('Error getting total products sold: $e');
      return 0;
    }
  }

  /// Get top selling products
  Future<List<TopProduct>> getTopProducts(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      Map<String, TopProduct> productSales = {};

      for (var doc in snapshot.docs) {
        final items = doc.data()['items'] as List? ?? [];
        for (var item in items) {
          if (item['type'] == 'product') {
            final productId = item['id'] as String? ?? '';
            final productName = item['name'] as String? ?? 'Unknown';
            final quantity = (item['quantity'] as int?) ?? 0;
            final price = (item['price'] as num?)?.toDouble() ?? 0;

            if (productSales.containsKey(productId)) {
              productSales[productId] = TopProduct(
                productId: productId,
                name: productName,
                salesCount: productSales[productId]!.salesCount + quantity,
                revenue: productSales[productId]!.revenue + (price * quantity),
              );
            } else {
              productSales[productId] = TopProduct(
                productId: productId,
                name: productName,
                salesCount: quantity,
                revenue: price * quantity,
              );
            }
          }
        }
      }

      final sorted = productSales.values.toList()
        ..sort((a, b) => b.salesCount.compareTo(a.salesCount));

      return sorted.take(limit).toList();
    } catch (e) {
      print('Error getting top products: $e');
      return [];
    }
  }

  /// Get sales by product category
  Future<Map<String, int>> getSalesByCategory() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      Map<String, int> categorySales = {};

      for (var doc in snapshot.docs) {
        final items = doc.data()['items'] as List? ?? [];
        for (var item in items) {
          if (item['type'] == 'product') {
            final category = item['category'] as String? ?? 'Uncategorized';
            final quantity = (item['quantity'] as int?) ?? 0;
            categorySales[category] = (categorySales[category] ?? 0) + quantity;
          }
        }
      }

      return categorySales;
    } catch (e) {
      print('Error getting sales by category: $e');
      return {};
    }
  }

  // ==================== USER ANALYTICS ====================

  /// Get active users count
  Future<int> getActiveUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting active users: $e');
      return 0;
    }
  }

  /// Get user growth over time
  Future<List<UserGrowth>> getUserGrowth(DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt')
          .get();

      Map<String, UserGrowth> growthByDate = {};
      int cumulativeCount = 0;

      for (var doc in snapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day).toString();
        cumulativeCount++;

        if (growthByDate.containsKey(dateKey)) {
          growthByDate[dateKey] = UserGrowth(
            date: growthByDate[dateKey]!.date,
            newUsers: growthByDate[dateKey]!.newUsers + 1,
            totalUsers: cumulativeCount,
          );
        } else {
          growthByDate[dateKey] = UserGrowth(
            date: DateTime(createdAt.year, createdAt.month, createdAt.day),
            newUsers: 1,
            totalUsers: cumulativeCount,
          );
        }
      }

      return growthByDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print('Error getting user growth: $e');
      return [];
    }
  }

  /// Get users by role
  Future<Map<String, int>> getUsersByRole() async {
    try {
      final snapshot = await _firestore.collection('users').get();

      Map<String, int> roleCounts = {
        'user': 0,
        'seller': 0,
        'service_provider': 0,
        'admin': 0,
        'delivery_partner': 0,
      };

      for (var doc in snapshot.docs) {
        final role = doc.data()['role'] as String? ?? 'user';
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      return roleCounts;
    } catch (e) {
      print('Error getting users by role: $e');
      return {};
    }
  }
}
