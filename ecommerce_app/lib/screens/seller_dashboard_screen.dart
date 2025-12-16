import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../providers/auth_provider.dart';
import '../models/product_model.dart';
import '../widgets/seller_orders_dialog.dart';


class SellerDashboardScreen extends StatefulWidget {
  static const routeName = '/seller-dashboard';
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  Stream<QuerySnapshot>? _productsStream;
  Stream<QuerySnapshot>? _lowStockStream;
  Stream<QuerySnapshot>? _recentActivityStream;
  Stream<QuerySnapshot>? _ordersStream;
  Stream<QuerySnapshot>? _deliveredOrdersStream;
  Stream<QuerySnapshot>? _manageProductsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user != null && _productsStream == null) {
      _initializeStreams(user.uid);
    }
  }

  void _initializeStreams(String userId) {
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .snapshots();

    _lowStockStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .where('stock', isLessThan: 10)
        .snapshots();

    _recentActivityStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .limit(5)
        .snapshots();

    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .snapshots();

    _deliveredOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .snapshots();

    _manageProductsStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  
  // Add Product Dialog
  void _showAddProductDialog(BuildContext context, AppUser user) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    
    String selectedCategory = ProductCategory.dailyNeeds;
    String selectedUnit = 'Pic';
    bool isLoading = false;
    List<Uint8List> selectedImages = [];
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
          final List<Uint8List> imageBytes = [];
          for (var image in images.take(6)) { // Maximum 6 images
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            selectedImages = imageBytes;
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking images: $e')),
          );
        }
      }
    }

    Future<List<String>> uploadImages(String productId) async {
      final List<String> imageUrls = [];
      for (int i = 0; i < selectedImages.length; i++) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('products')
              .child(productId)
              .child('image_$i.jpg');
          await ref.putData(selectedImages[i]);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        } catch (e) {
          print('Error uploading image $i: $e');
        }
      }
      return imageUrls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Picker
                    InkWell(
                      onTap: () => pickImages(setState),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: selectedImages.isEmpty
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tap to add images (max 6)'),
                                ],
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(8),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: selectedImages.length,
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      selectedImages[index],
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Product Name
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price and Stock
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixText: '₹',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Required';
                              final price = double.tryParse(v!);
                              if (price == null || price <= 0) return 'Invalid price';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: stockController,
                            decoration: const InputDecoration(
                              labelText: 'Stock *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return 'Required';
                              final stock = int.tryParse(v!);
                              if (stock == null || stock < 0) return 'Invalid stock';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Category and Unit
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: ProductCategory.all
                                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedCategory = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm']
                                .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedUnit = val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      if (selectedImages.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please add at least one image')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Create product ID
                        final productId = FirebaseFirestore.instance.collection('products').doc().id;
                        
                        // Upload images
                        final imageUrls = await uploadImages(productId);
                        
                        if (imageUrls.isEmpty) {
                          throw Exception('Failed to upload images');
                        }

                        // Create product document
                        await FirebaseFirestore.instance.collection('products').doc(productId).set({
                          'id': productId,
                          'sellerId': user.uid,
                          'name': nameController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'price': double.parse(priceController.text),
                          'stock': int.parse(stockController.text),
                          'category': selectedCategory,
                          'unit': selectedUnit,
                          'imageUrl': imageUrls.first,
                          'imageUrls': imageUrls,
                          'createdAt': FieldValue.serverTimestamp(),
                          'rating': 0.0,
                          'reviewCount': 0,
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Product added successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding product: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  // Manage Products Dialog
  void _showManageProductsDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
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
                    'My Products',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _manageProductsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final products = snapshot.data?.docs ?? [];

                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No products yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAddProductDialog(context, user);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Your First Product'),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final productData = products[index].data() as Map<String, dynamic>;
                        final productId = products[index].id;
                        final name = productData['name'] ?? 'Unknown';
                        final price = (productData['price'] as num?)?.toDouble() ?? 0;
                        final stock = (productData['stock'] as num?)?.toInt() ?? 0;
                        final imageUrl = productData['imageUrl'] as String?;

                        return Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                  child: imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.inventory_2, size: 40),
                                ),
                              ),
                              // Product Details
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Stock: $stock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: stock > 0 ? Colors.blue : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Action Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              // TODO: Implement edit
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Edit feature coming soon!')),
                                              );
                                            },
                                            icon: const Icon(Icons.edit, size: 16),
                                            label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogCtx) => AlertDialog(
                                                title: const Text('Delete Product'),
                                                content: Text('Delete "$name"?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection('products')
                                                    .doc(productId)
                                                    .delete();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Product deleted'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
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
        ),
      ),
    );
  }

  // View Orders Dialog
  void _showViewOrdersDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SellerOrdersDialog(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final userRole = user?.role ?? 'user';

    if (user == null || (userRole != 'seller' && userRole != 'admin')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seller Dashboard')),
        body: const Center(child: Text('Access denied: Sellers only')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Dashboard'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.green,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user.name}!',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Seller Account',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats Cards with Real Data
            Text(
              'Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _productsStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return _buildStatCard(
                        context,
                        'Products',
                        '$count',
                        Icons.inventory_2,
                        Colors.blue,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                  stream: _ordersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildStatCard(
                          context,
                          'Orders',
                          '0',
                          Icons.shopping_cart,
                          Colors.orange,
                          isLoading: true,
                        );
                      }
                      
                      // Filter orders that contain seller's products
                      int sellerOrderCount = 0;
                      for (var doc in snapshot.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        final items = data['items'] as List<dynamic>? ?? [];
                        for (var item in items) {
                          if (item['sellerId'] == user.uid) {
                            sellerOrderCount++;
                            break; // Count order once if any item belongs to seller
                          }
                        }
                      }
                      
                      return _buildStatCard(
                        context,
                        'Orders',
                        '$sellerOrderCount',
                        Icons.shopping_cart,
                        Colors.orange,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                  stream: _deliveredOrdersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildStatCard(
                          context,
                          'Revenue',
                          '₹0',
                          Icons.currency_rupee,
                          Colors.green,
                          isLoading: true,
                        );
                      }
                      
                      // Calculate total revenue from delivered orders
                      double totalRevenue = 0;
                      for (var doc in snapshot.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        final items = data['items'] as List<dynamic>? ?? [];
                        for (var item in items) {
                          if (item['sellerId'] == user.uid) {
                            final price = (item['price'] as num?)?.toDouble() ?? 0;
                            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                            totalRevenue += price * quantity;
                          }
                        }
                      }
                      
                      return _buildStatCard(
                        context,
                        'Revenue',
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        Icons.currency_rupee,
                        Colors.green,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _productsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildStatCard(
                          context,
                          'Rating',
                          '0.0',
                          Icons.star,
                          Colors.amber,
                          isLoading: true,
                        );
                      }
                      
                      // Calculate average rating
                      double totalRating = 0;
                      int ratedProductsCount = 0;
                      
                      for (var doc in snapshot.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rating = (data['rating'] as num?)?.toDouble();
                        if (rating != null && rating > 0) {
                          totalRating += rating;
                          ratedProductsCount++;
                        }
                      }
                      
                      final averageRating = ratedProductsCount > 0 
                          ? (totalRating / ratedProductsCount)
                          : 0.0;
                      
                      return _buildStatCard(
                        context,
                        'Rating',
                        averageRating.toStringAsFixed(1),
                        Icons.star,
                        Colors.amber,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                    title: const Text('Add New Product'),
                    subtitle: const Text('List a new product for sale'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_add_product')) {
                        _showAddProductDialog(context, user);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to add products.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.inventory, color: Colors.white),
                    ),
                    title: const Text('Manage Products'),
                    subtitle: const Text('View and edit your products'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_manage_products')) {
                        _showManageProductsDialog(context, user);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to manage products.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.receipt_long, color: Colors.white),
                    ),
                    title: const Text('View Orders'),
                    subtitle: const Text('Check your pending orders'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_view_orders')) {
                        _showViewOrdersDialog(context, user);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to view orders.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.analytics, color: Colors.white),
                    ),
                    title: const Text('Analytics'),
                    subtitle: const Text('View sales analytics'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_view_analytics')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analytics feature coming soon!'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to view analytics.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Activity with Real Data
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _recentActivityStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                // Filter orders containing seller's products
                final relevantOrders = <QueryDocumentSnapshot>[];
                for (var doc in snapshot.data?.docs ?? []) {
                  final data = doc.data() as Map<String, dynamic>;
                  final items = data['items'] as List<dynamic>? ?? [];
                  for (var item in items) {
                    if (item['sellerId'] == user.uid) {
                      relevantOrders.add(doc);
                      break;
                    }
                  }
                }

                if (relevantOrders.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recent activity',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: relevantOrders.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final orderData = relevantOrders[index].data() as Map<String, dynamic>;
                      final orderId = relevantOrders[index].id;
                      final status = orderData['status'] ?? 'pending';
                      final items = orderData['items'] as List<dynamic>? ?? [];
                      
                      // Find seller's items
                      final sellerItems = items.where((item) => item['sellerId'] == user.uid).toList();
                      final itemCount = sellerItems.length;
                      
                      // Calculate seller's portion of order
                      double sellerOrderValue = 0;
                      for (var item in sellerItems) {
                        final price = (item['price'] as num?)?.toDouble() ?? 0;
                        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                        sellerOrderValue += price * quantity;
                      }

                      Color statusColor;
                      IconData statusIcon;
                      switch (status.toLowerCase()) {
                        case 'delivered':
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle;
                          break;
                        case 'pending':
                          statusColor = Colors.orange;
                          statusIcon = Icons.pending;
                          break;
                        case 'cancelled':
                          statusColor = Colors.red;
                          statusIcon = Icons.cancel;
                          break;
                        default:
                          statusColor = Colors.blue;
                          statusIcon = Icons.local_shipping;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        title: Text(
                          'Order #${orderId.substring(0, 8)}...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$itemCount item(s) • ₹${sellerOrderValue.toStringAsFixed(0)}'),
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
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            isLoading
                ? SizedBox(
                    height: 32,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
