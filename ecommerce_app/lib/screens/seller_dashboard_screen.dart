import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../providers/auth_provider.dart';
import '../models/product_model.dart';
import '../widgets/seller_orders_dialog.dart';
import '../widgets/edit_product_dialog.dart';
import 'seller_analytics_screen.dart';
import 'seller_wallet_screen.dart';


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
                                              showDialog(
                                                context: context,
                                                builder: (context) => EditProductDialog(
                                                  productId: productId,
                                                  productData: productData,
                                                ),
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
      backgroundColor: Colors.grey[100], // Increased contrast from white cards
      appBar: AppBar(
        title: const Text('Seller Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Header
            _buildWelcomeHeader(user),
            const SizedBox(height: 24),

            // 2. Key Stats Grid
            const Text(
              'Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(user),
            const SizedBox(height: 24),

            // 3. Quick Actions Grid
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildQuickActionsGrid(context, user),
            const SizedBox(height: 24),

            // 4. Low Stock Alert (Horizontal Scroll)
            StreamBuilder<QuerySnapshot>(
              stream: _lowStockStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                         const SizedBox(width: 8),
                         Text(
                          'Low Stock Alert (${snapshot.data!.docs.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: data['imageUrl'] != null 
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(data['imageUrl'], fit: BoxFit.cover, width: double.infinity),
                                      )
                                    : Container(color: Colors.grey[200]),
                                ),
                                const SizedBox(height: 8),
                                Text(data['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('Stock: ${data['stock']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // 5. Recent Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton(
                  onPressed: () => _showViewOrdersDialog(context, user),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentOrdersList(user),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[800]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: 28,
                color: Colors.blue[800],
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
                  'Welcome back,',
                  style: TextStyle(color: Colors.blue[100], fontSize: 14),
                ),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('SELLER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AppUser user) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _deliveredOrdersStream,
                builder: (context, snapshot) {
                  double totalRevenue = 0;
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
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
                  }
                  return _buildModernStatCard('Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee, Colors.green, Colors.green[50]!);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _ordersStream,
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                     for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final items = data['items'] as List<dynamic>? ?? [];
                        if (items.any((item) => item['sellerId'] == user.uid)) {
                          count++;
                        }
                     }
                  }
                  return _buildModernStatCard('Total Orders', '$count', Icons.shopping_bag, Colors.blue, Colors.blue[50]!);
                },
              ),
            ),
            const SizedBox(width: 12),
             Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  int count = snapshot.data?.docs.length ?? 0;
                  return _buildModernStatCard('Products', '$count', Icons.inventory_2, Colors.purple, Colors.purple[50]!);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, AppUser user) {
    final actions = [
      {
        'title': 'Add Product',
        'icon': Icons.add_box,
        'color': Colors.blue,
        'onTap': () => _showAddProductDialog(context, user),
      },
      {
        'title': 'Manage Products',
        'icon': Icons.edit_note,
        'color': Colors.orange,
        'onTap': () => _showManageProductsDialog(context, user),
      },
      {
        'title': 'My Orders',
        'icon': Icons.list_alt,
        'color': Colors.teal,
        'onTap': () => _showViewOrdersDialog(context, user),
      },
      {
        'title': 'Analytics',
        'icon': Icons.analytics,
        'color': Colors.purple,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerAnalyticsScreen(user: user))),
      },
      {
        'title': 'My Wallet',
        'icon': Icons.account_balance_wallet,
        'color': Colors.indigo,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerWalletScreen(user: user))),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, 
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (action['color'] as Color).withOpacity(0.1),
                    ),
                    child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 28),
                 ),
                 const SizedBox(height: 8),
                 Text(
                   action['title'] as String,
                   textAlign: TextAlign.center,
                   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                 ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrdersList(AppUser user) {
     return StreamBuilder<QuerySnapshot>(
        stream: _recentActivityStream,
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
           
           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                 child: const Center(child: Text('No recent activity', style: TextStyle(color: Colors.grey))),
              );
           }

           // Filter for relevant orders using a more manual approach since we can't filter the stream easily by array contains object field
           final relevantDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final items = data['items'] as List<dynamic>? ?? [];
              return items.any((item) => item['sellerId'] == user.uid);
           }).take(3).toList(); // Show max 3
           
           if (relevantDocs.isEmpty) {
              return Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                 child: const Center(child: Text('No orders yet', style: TextStyle(color: Colors.grey))),
              );
           }

           return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relevantDocs.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                 final data = relevantDocs[index].data() as Map<String, dynamic>;
                 final orderId = relevantDocs[index].id;
                 final status = data['status'] ?? 'pending';
                 final items = data['items'] as List<dynamic>? ?? [];
                 
                 // Calculate value for this seller
                 double orderValue = 0;
                 int itemCount = 0;
                 for(var item in items) {
                    if (item['sellerId'] == user.uid) {
                       orderValue += ((item['price'] as num) * (item['quantity'] as num)).toDouble();
                       itemCount++;
                    }
                 }

                 Color statusColor = Colors.grey;
                 if (status == 'pending') statusColor = Colors.orange;
                 if (status == 'confirmed') statusColor = Colors.blue;
                 if (status == 'delivered') statusColor = Colors.green;
                 if (status == 'cancelled') statusColor = Colors.red;

                 return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       border: Border(
                         left: BorderSide(color: statusColor, width: 4),
                         top: BorderSide(color: Colors.grey.withOpacity(0.3)),
                         right: BorderSide(color: Colors.grey.withOpacity(0.3)),
                         bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
                       ),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                       children: [
                          Expanded(
                             child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text('Order #${orderId.substring(0,8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                   const SizedBox(height: 4),
                                   Text('$itemCount items • ₹${orderValue.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                             ),
                          ),
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                             decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                             child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                       ],
                    ),
                 );
              },
           );
        },
     );
  }
}
