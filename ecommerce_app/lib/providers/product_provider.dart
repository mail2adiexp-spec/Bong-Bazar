import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Product> _products = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  bool get isLoading => _isLoading;
  List<Product> get products => [..._products];

  void startListening() {
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    print(' Starting realtime listener for products...');
    _sub = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _products
              ..clear()
              ..addAll(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return Product(
                    id: doc.id,
                    name: data['name'] ?? '',
                    price: (data['price'] ?? 0).toDouble(),
                    imageUrl: data['imageUrl'] ?? '',
                    description: data['description'] ?? '',
                    imageUrls: data['imageUrls'] != null
                        ? List<String>.from(data['imageUrls'])
                        : null,
                    category: data['category'],
                    unit: data['unit'],
                  );
                }),
              );
            _isLoading = false;
            notifyListeners();
            print(' Realtime update: ${_products.length} products');
          },
          onError: (e) {
            _isLoading = false;
            notifyListeners();
            print(' Realtime listener error: $e');
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Product? findById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      print(' ProductProvider: Adding product ${product.name} to Firestore');
      await _firestore.collection('products').doc(product.id).set({
        'name': product.name,
        'price': product.price,
        'imageUrl': product.imageUrl,
        'description': product.description,
        'imageUrls': product.imageUrls,
        'category': product.category,
        'unit': product.unit,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print(' Product added successfully');
    } catch (e) {
      print(' Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String id, Product updatedProduct) async {
    try {
      print(' ProductProvider: Updating product $id in Firestore');
      await _firestore.collection('products').doc(id).update({
        'name': updatedProduct.name,
        'price': updatedProduct.price,
        'imageUrl': updatedProduct.imageUrl,
        'description': updatedProduct.description,
        'imageUrls': updatedProduct.imageUrls,
        'category': updatedProduct.category,
        'unit': updatedProduct.unit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print(' Product updated successfully');
    } catch (e) {
      print(' Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      print(' ProductProvider: Deleting product $id from Firestore');
      await _firestore.collection('products').doc(id).delete();
      print(' Product deleted successfully');
    } catch (e) {
      print(' Error deleting product: $e');
      rethrow;
    }
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return products;
    final lowerQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
          product.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<Product> getProductsByCategory(String category) {
    return _products.where((p) => p.category == category).toList();
  }
}
