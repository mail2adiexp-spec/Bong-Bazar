import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double totalAmount;
  final String deliveryAddress;
  final String phoneNumber;
  final DateTime orderDate;
  final String
  status; // 'pending', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled'
  final String? trackingNumber;
  final DateTime? estimatedDelivery;
  final DateTime? actualDelivery;
  final Map<String, DateTime>? statusHistory;
  final String? deliveryPartnerId;
  final String? deliveryPartnerName;
  final String? deliveryPincode;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.deliveryAddress,
    required this.phoneNumber,
    required this.orderDate,
    required this.status,
    this.trackingNumber,
    this.estimatedDelivery,
    this.actualDelivery,
    this.statusHistory,
    this.deliveryPartnerId,
    this.deliveryPartnerName,
    this.deliveryPincode,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime _parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return OrderModel(
      id: documentId,
      userId: map['userId'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      deliveryAddress: map['deliveryAddress'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      orderDate: _parseDate(map['orderDate']),
      status: map['status'] ?? 'pending',
      trackingNumber: map['trackingNumber'],
      estimatedDelivery: map['estimatedDelivery'] != null
          ? _parseDate(map['estimatedDelivery'])
          : null,
      actualDelivery: map['actualDelivery'] != null
          ? _parseDate(map['actualDelivery'])
          : null,
      statusHistory: map['statusHistory'] != null
          ? (map['statusHistory'] as Map).map<String, DateTime>(
              (key, value) => MapEntry(key as String, _parseDate(value)),
            )
          : null,
      deliveryPartnerId: map['deliveryPartnerId'],
      deliveryPartnerName: map['deliveryPartnerName'],
      deliveryPincode: map['deliveryPincode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'deliveryAddress': deliveryAddress,
      'phoneNumber': phoneNumber,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
      'trackingNumber': trackingNumber,
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
      'actualDelivery': actualDelivery?.toIso8601String(),
      'statusHistory': statusHistory?.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'deliveryPartnerId': deliveryPartnerId,
      'deliveryPartnerName': deliveryPartnerName,
      'deliveryPincode': deliveryPincode,
    };
  }

  String getStatusText() {
    switch (status) {
      case 'pending':
        return 'Order Received';
      case 'confirmed':
        return 'Order Confirmed';
      case 'packed':
        return 'Packing Complete';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.imageUrl,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
    };
  }
}
