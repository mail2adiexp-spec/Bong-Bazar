import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Category> _categories = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  bool get isLoading => _isLoading;
  List<Category> get categories => [..._categories];

  void startListening() {
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    print('🏷️ Starting realtime listener for categories...');
    _sub = _firestore
        .collection('categories')
        .orderBy('order')
        .snapshots()
        .listen(
          (snapshot) {
            _categories
              ..clear()
              ..addAll(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return Category(
                    id: doc.id,
                    name: data['name'] ?? '',
                    imageUrl: data['imageUrl'] ?? '',
                    order: data['order'] ?? 0,
                  );
                }),
              );
            _isLoading = false;
            notifyListeners();
            print('🏷️ Realtime update: ${_categories.length} categories');
          },
          onError: (e) {
            _isLoading = false;
            notifyListeners();
            print('🔴 Realtime listener error: $e');
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> addCategory(Category category) async {
    try {
      print('🏷️ Adding category ${category.name} to Firestore');
      await _firestore.collection('categories').doc(category.id).set({
        'name': category.name,
        'imageUrl': category.imageUrl,
        'order': category.order,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Category added successfully');
    } catch (e) {
      print('🔴 Error adding category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(String id, Category updatedCategory) async {
    try {
      print('🏷️ Updating category $id in Firestore');
      await _firestore.collection('categories').doc(id).update({
        'name': updatedCategory.name,
        'imageUrl': updatedCategory.imageUrl,
        'order': updatedCategory.order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Category updated successfully');
    } catch (e) {
      print('🔴 Error updating category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      print('🏷️ Deleting category $id from Firestore');
      await _firestore.collection('categories').doc(id).delete();
      print('✅ Category deleted successfully');
    } catch (e) {
      print('🔴 Error deleting category: $e');
      rethrow;
    }
  }
}
