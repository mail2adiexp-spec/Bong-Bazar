import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/service_category_model.dart';
import '../models/featured_section_model.dart';
import '../models/partner_request_model.dart';
import '../models/gift_model.dart';
import '../models/delivery_partner_model.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/service_category_provider.dart';
import '../providers/featured_section_provider.dart';
import '../providers/gift_provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatefulWidget {
  static const routeName = '/admin-panel';
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, pending, approved, rejected

  final List<String> _menuTitles = [
    'Users', // 5 chars - original index 7
    'Gifts', // 5 chars - original index 8
    'Orders', // 6 chars - original index 9
    'Products', // 8 chars - original index 1
    'Services', // 8 chars - original index 3
    'Dashboard', // 9 chars - original index 0
    'Categories', // 10 chars - original index 2
    'Core Staff', // 10 chars - original index 10
    'Permissions', // 11 chars - original index 11
    'Delivery Partners', // 17 chars - original index 6
    'Sellers', // Index 12
    'Service Providers', // Index 13
    'Featured Sections', // 17 chars - original index 4
  ];

  // Map: sorted index -> original index for getting content
  final Map<int, int> _sortedToOriginalIndex = {
    0: 6, // Users -> _buildUsersTab (index 6)
    1: 7, // Gifts -> _buildGiftsTab (index 7)
    2: 8, // Orders -> _buildOrdersTab (index 8)
    3: 1, // Products -> _buildProductsTab (index 1)
    4: 3, // Services -> _buildServiceCategoriesTab (index 3)
    5: 0, // Dashboard -> _buildDashboardTab (index 0)
    6: 2, // Categories -> _buildCategoriesTab (index 2)
    7: 9, // Core Staff -> _buildCoreStaffTab (index 9)
    8: 10, // Permissions -> _buildPermissionsTab (index 10)
    9: 5, // Delivery Partners -> _buildDeliveryPartnersTab (index 5)
    10: 11, // Sellers -> _buildRoleBasedUsersTab('seller') (index 11)
    11: 12, // Service Providers -> _buildRoleBasedUsersTab('service_provider') (index 12)
    12: 4, // Featured Sections -> _buildFeaturedSectionsTab (index 4)
  };

  final List<IconData> _menuIcons = [
    Icons.person, // Users
    Icons.card_giftcard, // Gifts
    Icons.receipt_long, // Orders
    Icons.inventory_2, // Products
    Icons.home_repair_service, // Services
    Icons.dashboard, // Dashboard
    Icons.category, // Categories
    Icons.group, // Core Staff
    Icons.security, // Permissions
    Icons.delivery_dining, // Delivery Partners
    Icons.store, // Sellers
    Icons.handyman, // Service Providers
    Icons.star, // Featured Sections
  ];

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    String? selectedCategory = ProductCategory.dailyNeeds;
    String? selectedUnit = 'Pic';
    final units = ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm'];

    // Image storage (up to 6 images)
    final List<Uint8List?> imageBytes = List.filled(6, null);
    final List<File?> imageFiles = List.filled(6, null);
    final List<String?> fileNames = List.filled(6, null);

    bool saving = false;

    Future<void> pickImage(int index, StateSetter setState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          fileNames[index] = pickedFile.name;
          if (kIsWeb) {
            imageBytes[index] = await pickedFile.readAsBytes();
          } else {
            imageFiles[index] = File(pickedFile.path);
          }
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }

    Future<List<String>> uploadImages(String productId) async {

      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final List<String> urls = [];

      for (int i = 0; i < 6; i++) {
        if (imageBytes[i] == null && imageFiles[i] == null) continue;

        try {
          final ref = storage
              .ref()
              .child('products')
              .child(productId)
              .child('img_$i.jpg');

          String contentType = 'image/jpeg';
          final name = fileNames[i]?.toLowerCase() ?? '';
          if (name.endsWith('.png')) contentType = 'image/png';
          if (name.endsWith('.webp')) contentType = 'image/webp';

          UploadTask task;
          if (imageBytes[i] != null) {
            task = ref.putData(
              imageBytes[i]!,
              SettableMetadata(
                contentType: contentType,
                cacheControl: 'public, max-age=3600',
              ),
            );
          } else {
            task = ref.putFile(
              imageFiles[i]!,
              SettableMetadata(
                contentType: contentType,
                cacheControl: 'public, max-age=3600',
              ),
            );
          }

          final snap = await task;
          if (snap.state == TaskState.success) {
            final url = await ref.getDownloadURL();
            urls.add(url);
          }
        } catch (e) {
        }
      }

      return urls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ProductCategory.all.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),

                  // Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: units.map((u) {
                      return DropdownMenuItem(value: u, child: Text(u));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedUnit = val),
                  ),
                  const SizedBox(height: 12),

                  // Image Pickers
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Product Images (minimum 4 required)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: 6,
                      itemBuilder: (gctx, i) {
                        Widget preview;
                        if (imageBytes[i] != null) {
                          preview = Image.memory(
                            imageBytes[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (imageFiles[i] != null && !kIsWeb) {
                          preview = Image.file(
                            imageFiles[i]!,
                            fit: BoxFit.cover,
                          );
                        } else {
                          preview = Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.grey[400],
                          );
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => pickImage(i, setState),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(child: preview),
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name and price are required!'),
                          ),
                        );
                        return;
                      }

                      // Count selected images
                      int imageCount = 0;
                      for (int i = 0; i < 6; i++) {
                        if (imageBytes[i] != null || imageFiles[i] != null) {
                          imageCount++;
                        }
                      }

                      if (imageCount < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Minimum 4 images required!'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);

                      try {
                        final productId =
                            'p${DateTime.now().millisecondsSinceEpoch}';
                        final urls = await uploadImages(productId);

                        if (urls.isEmpty) {
                          throw Exception('Failed to upload images');
                        }

                        final product = Product(
                          id: productId,
                          name: nameCtrl.text,
                          price: double.tryParse(priceCtrl.text) ?? 0,
                          imageUrl: urls.first,
                          description: descCtrl.text,
                          imageUrls: urls,
                          category: selectedCategory,
                          unit: selectedUnit,
                        );

                        await Provider.of<ProductProvider>(
                          context,
                          listen: false,
                        ).addProduct(product);

                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Product added successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.price.toString());
    final descCtrl = TextEditingController(text: product.description);

    String? selectedCategory = product.category ?? ProductCategory.dailyNeeds;
    String? selectedUnit = product.unit ?? 'Pic';
    final units = ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm'];

    // Image storage (up to 6 images)
    final List<Uint8List?> imageBytes = List.filled(6, null);
    final List<File?> imageFiles = List.filled(6, null);
    final List<String?> fileNames = List.filled(6, null);
    final List<String?> existingUrls = List.filled(6, null);

    // Load existing images
    if (product.imageUrls != null) {
      for (int i = 0; i < product.imageUrls!.length && i < 6; i++) {
        existingUrls[i] = product.imageUrls![i];
      }
    } else if (product.imageUrl.isNotEmpty) {
      existingUrls[0] = product.imageUrl;
    }

    bool saving = false;

    Future<void> pickImage(int index, StateSetter setState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          fileNames[index] = pickedFile.name;
          existingUrls[index] = null; // Clear existing URL if replacing
          if (kIsWeb) {
            imageBytes[index] = await pickedFile.readAsBytes();
          } else {
            imageFiles[index] = File(pickedFile.path);
          }
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }

    Future<List<String>> uploadImages(String productId) async {

      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final List<String> urls = [];

      for (int i = 0; i < 6; i++) {
        // If existing URL and no new image, keep existing
        if (existingUrls[i] != null &&
            imageBytes[i] == null &&
            imageFiles[i] == null) {
          urls.add(existingUrls[i]!);
          continue;
        }

        // If new image selected, upload it
        if (imageBytes[i] != null || imageFiles[i] != null) {
          try {

            final ref = storage
                .ref()
                .child('products')
                .child(productId)
                .child('img_$i.jpg');

            String contentType = 'image/jpeg';
            final name = fileNames[i]?.toLowerCase() ?? '';
            if (name.endsWith('.png')) contentType = 'image/png';
            if (name.endsWith('.webp')) contentType = 'image/webp';

            UploadTask task;
            if (imageBytes[i] != null) {
              task = ref.putData(
                imageBytes[i]!,
                SettableMetadata(
                  contentType: contentType,
                  cacheControl: 'public, max-age=3600',
                ),
              );
            } else {
              task = ref.putFile(
                imageFiles[i]!,
                SettableMetadata(
                  contentType: contentType,
                  cacheControl: 'public, max-age=3600',
                ),
              );
            }

            final snap = await task;
            if (snap.state == TaskState.success) {
              final url = await ref.getDownloadURL();
              urls.add(url);

            }
          } catch (e) {

          }
        }
      }

      return urls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Product'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ProductCategory.all.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),

                  // Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: units.map((u) {
                      return DropdownMenuItem(value: u, child: Text(u));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedUnit = val),
                  ),
                  const SizedBox(height: 12),

                  // Image Pickers
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Product Images (minimum 4 required)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: 6,
                      itemBuilder: (gctx, i) {
                        Widget preview;
                        if (imageBytes[i] != null) {
                          preview = Image.memory(
                            imageBytes[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (imageFiles[i] != null && !kIsWeb) {
                          preview = Image.file(
                            imageFiles[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (existingUrls[i] != null) {
                          preview = Image.network(
                            existingUrls[i]!,
                            fit: BoxFit.cover,
                          );
                        } else {
                          preview = Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.grey[400],
                          );
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => pickImage(i, setState),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(child: preview),
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name and price are required!'),
                          ),
                        );
                        return;
                      }

                      // Count selected images (existing + new)
                      int imageCount = 0;
                      for (int i = 0; i < 6; i++) {
                        if (existingUrls[i] != null ||
                            imageBytes[i] != null ||
                            imageFiles[i] != null) {
                          imageCount++;
                        }
                      }

                      if (imageCount < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Minimum 4 images required!'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);

                      try {
                        final urls = await uploadImages(product.id);

                        if (urls.isEmpty) {
                          throw Exception('Failed to upload images');
                        }

                        final updatedProduct = Product(
                          id: product.id,
                          name: nameCtrl.text,
                          price: double.tryParse(priceCtrl.text) ?? 0,
                          imageUrl: urls.first,
                          description: descCtrl.text,
                          imageUrls: urls,
                          category: selectedCategory,
                          unit: selectedUnit,
                        );

                        await Provider.of<ProductProvider>(
                          context,
                          listen: false,
                        ).updateProduct(product.id, updatedProduct);

                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Product updated successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Product'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final products = productProvider.products;
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.isAdmin;

    // Guard: Only admins can access this screen
    if (!isAdmin) {
      // Defer navigation pop and snackbar to after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Admins only'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(child: Text('Access denied: Admins only')),
      );
    }

    return Scaffold(
      body: SizedBox.expand(
        child: Column(
          children: [
            // Top Header Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Center: Bong Bazar
                  Center(
                    child: Text(
                      'Bong Bazar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  // Right: Logout button
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Main Content Area with Sidebar
            Expanded(
              child: Row(
                children: [
                  // Left Sidebar - Fixed
                  SizedBox(
                    width: 250,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Menu Items - Scrollable
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('partner_requests')
                                  .where('status', isEqualTo: 'pending')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final pendingCount = snapshot.hasData
                                    ? snapshot.data!.docs.length
                                    : 0;

                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: _menuTitles.length,
                                  itemBuilder: (context, listIndex) {
                                    final isSelected =
                                        _selectedIndex == listIndex;
                                    final isPartnerRequestsTab =
                                        listIndex ==
                                        7; // Position 7 in sorted menu is Partner Requests
                                    final showBadge =
                                        isPartnerRequestsTab &&
                                        pendingCount > 0;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Material(
                                        color: isSelected
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedIndex = listIndex;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: isSelected
                                                ? BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        width: 4,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _menuIcons[listIndex],
                                                  color: isSelected
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    _menuTitles[listIndex],
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.left,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                                if (showBadge) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      pendingCount.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          // Back to App Button
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_back,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Back to App',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right Content Area
                  Expanded(
                    child: IndexedStack(
                      index: _sortedToOriginalIndex[_selectedIndex] ?? 0,
                      children: [
                        _buildDashboardTab(), // 0
                        _buildProductsTab(productProvider, products), // 1
                        _buildCategoriesTab(), // 2
                        _buildServiceCategoriesTab(isAdmin: isAdmin), // 3
                        _buildFeaturedSectionsTab(isAdmin: isAdmin), // 4
                        _buildDeliveryPartnersTab(), // 5
                        _buildUsersTab(), // 6
                        _buildGiftsTab(), // 7
                        _buildOrdersTab(), // 8
                        _buildCoreStaffTab(), // 9
                        _buildPermissionsTab(), // 10
                        _buildRoleBasedUsersTab('seller'), // 11
                        _buildRoleBasedUsersTab('service_provider'), // 12
                      ],
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

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildDashboardCard(
                title: 'Total Service Providers',
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'service_provider')
                    .snapshots(),
                icon: Icons.home_repair_service,
                color: Colors.blue,
              ),
              _buildDashboardCard(
                title: 'Total Sellers',
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'seller')
                    .snapshots(),
                icon: Icons.store,
                color: Colors.green,
              ),
              _buildDashboardCard(
                title: 'Total Orders',
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .snapshots(),
                icon: Icons.receipt_long,
                color: Colors.orange,
              ),
              _buildDashboardCard(
                title: 'Total Users',
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                icon: Icons.person,
                color: Colors.purple,
              ),
              _buildDashboardCard(
                title: 'Pending Partners',
                stream: FirebaseFirestore.instance
                    .collection('partner_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                icon: Icons.people_outline,
                color: Colors.red,
              ),
              _buildDashboardCard(
                title: 'Total Sell',
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .snapshots(),
                icon: Icons.shopping_cart_checkout,
                color: Colors.indigo,
              ),
              _buildDashboardCard(
                title: 'Total Cancel',
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('status', isEqualTo: 'cancelled')
                    .snapshots(),
                icon: Icons.cancel,
                color: Colors.red,
              ),
              _buildDashboardCard(
                title: 'Total Return',
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('status', isEqualTo: 'returned')
                    .snapshots(),
                icon: Icons.assignment_return,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Top Selling Products',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildTopSellingProducts()),
          const SizedBox(height: 24),
          const Text(
            'Top Services',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildTopServices()),
          const SizedBox(height: 32),
          const Text(
            'Recent Orders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 500, child: _buildRecentOrdersList()),
          const SizedBox(height: 32),
          // Testing Tools Section
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Testing Tools',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Add sample users to test the permissions system',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addSampleUsers,
                    icon: const Icon(Icons.people_alt),
                    label: const Text('Add Sample Users (2 Sellers, 2 Service Providers, 2 Delivery Partners)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .snapshots(),
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
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

            Color statusColor = Colors.orange;
            if (status == 'delivered') statusColor = Colors.green;
            if (status == 'cancelled') statusColor = Colors.red;
            if (status == 'pending') statusColor = Colors.orange;

            return Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${orderId.substring(0, 8)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User: $userId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (orderDate != null)
                            Text(
                              'Date: ${orderDate.day}/${orderDate.month}/${orderDate.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopSellingProducts() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Count products from orders
        Map<String, int> productCount = {};
        final orders = snapshot.data?.docs ?? [];
        for (var order in orders) {
          final items = order['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            final productName = item['productName'] ?? 'Unknown';
            productCount[productName] = (productCount[productName] ?? 0) + 1;
          }
        }

        if (productCount.isEmpty) {
          return const Center(child: Text('No products sold yet'));
        }

        // Sort by count and get top 5
        final sortedProducts = productCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topProducts = sortedProducts.take(5).toList();

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: topProducts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final product = topProducts[index];
            return Container(
              width: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.7), Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    offset: const Offset(2, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopServices() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('service_categories')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final services = snapshot.data?.docs ?? [];
        if (services.isEmpty) {
          return const Center(child: Text('No services available'));
        }

        // Sort by name and get top 5
        final topServices = services.take(5).toList();

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: topServices.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final service = topServices[index];
            final serviceName = service['name'] ?? 'Unknown';
            final description = service['description'] ?? '';

            return Container(
              width: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withOpacity(0.7), Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    offset: const Offset(2, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.design_services, size: 36, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    serviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required Stream<QuerySnapshot> stream,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              offset: const Offset(4, 4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: color.withOpacity(0.1),
              offset: const Offset(-2, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: stream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 48,
                              width: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Text(
                              'Error',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return Text(
                            snapshot.data?.docs.length.toString() ?? '0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftsTab() {
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, _) {
        final gifts = giftProvider.gifts;
        return Column(
          children: [
            // Count + Add button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Gifts: ${gifts.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditGiftDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Gift'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Gifts list
            Expanded(
              child: giftProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : gifts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No gifts yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a gift item to get started!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: gifts.length,
                      itemBuilder: (ctx, index) {
                        final gift = gifts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Leading
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: gift.imageUrl != null
                                      ? Image.network(
                                          gift.imageUrl!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.card_giftcard,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Title and Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gift.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if ((gift.purpose ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.sell,
                                                size: 14,
                                                color: Colors.blueGrey,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  gift.purpose!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blueGrey,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Text('₹${gift.price.toStringAsFixed(2)}'),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6.0,
                                        runSpacing: 4.0,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Text('Active:'),
                                          Icon(
                                            gift.isActive
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: gift.isActive
                                                ? Colors.green
                                                : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text('Order: ${gift.displayOrder}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Trailing
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _showAddOrEditGiftDialog(
                                        context,
                                        existing: gift,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: ctx,
                                          builder: (d) => AlertDialog(
                                            title: const Text('Delete Gift'),
                                            content: Text(
                                              'Delete "${gift.name}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await Provider.of<GiftProvider>(
                                              context,
                                              listen: false,
                                            ).deleteGift(gift.id);
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Gift deleted successfully!',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
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
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    final statuses = const [
      'pending',
      'confirmed',
      'packed',
      'shipped',
      'out_for_delivery',
      'delivered',
      'cancelled',
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('orderDate', descending: true)
                  .snapshots(),
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
                    final data = doc.data();
                    final orderId = doc.id;
                    final userId = data['userId'] as String? ?? '-';
                    final total =
                        (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
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
                                  Text('Total: ₹${total.toStringAsFixed(2)}'),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Date: ${orderDate != null ? '${orderDate.day.toString().padLeft(2, '0')}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.year} ${orderDate.hour.toString().padLeft(2, '0')}:${orderDate.minute.toString().padLeft(2, '0')}' : '-'}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: statuses.contains(status)
                                  ? status
                                  : 'pending',
                              items: statuses
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.replaceAll('_', ' ')),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) async {
                                if (val == null) return;
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(orderId)
                                      .update({
                                        'status': val,
                                        'statusHistory.$val':
                                            FieldValue.serverTimestamp(),
                                      });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Status updated to ${val.replaceAll('_', ' ')}',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),

                            IconButton(
                              icon: const Icon(Icons.person_add),
                              tooltip: 'Assign Delivery Partner',
                              onPressed: () => _showAssignDeliveryPartnerDialog(
                                orderId,
                                data,
                              ),
                              color: Colors.blue,
                            ),
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

  Future<void> _showAssignDeliveryPartnerDialog(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    // Fetch all delivery partners
    final deliveryPartnersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'delivery_partner')
        .get();

    if (!mounted) return;

    final deliveryPartners = deliveryPartnersSnapshot.docs;

    if (deliveryPartners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No delivery partners found')),
      );
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
                decoration: const InputDecoration(
                  labelText: 'Select Delivery Partner',
                  border: OutlineInputBorder(),
                ),
                items: deliveryPartners.map((doc) {
                  final data = doc.data();
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(data['name'] ?? doc.id),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPartnerId = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (selectedPartnerId != null &&
                orderData['deliveryPartnerId'] != null)
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({
                          'deliveryPartnerId': FieldValue.delete(),
                          'deliveryPartnerName': FieldValue.delete(),
                        });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Delivery partner unassigned'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text(
                  'Unassign',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: selectedPartnerId == null
                  ? null
                  : () async {
                      try {
                        final partnerDoc = deliveryPartners.firstWhere(
                          (doc) => doc.id == selectedPartnerId,
                        );
                        final partnerData = partnerDoc.data();

                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .update({
                              'deliveryPartnerId': selectedPartnerId,
                              'deliveryPartnerName':
                                  partnerData['name'] ?? 'Unknown',
                            });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Delivery partner assigned successfully',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditGiftDialog(BuildContext context, {Gift? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );
    final orderCtrl = TextEditingController(
      text: existing?.displayOrder.toString() ?? '0',
    );
    bool isActive = existing?.isActive ?? true;

    // Multi-image storage (up to 6 images)
    final List<Uint8List?> imageBytes = List.filled(6, null);
    final List<File?> imageFiles = List.filled(6, null);
    final List<String?> fileNames = List.filled(6, null);
    final List<String?> existingUrls = List.filled(6, null);

    // Load existing images
    if (existing?.imageUrls != null) {
      for (int i = 0; i < existing!.imageUrls!.length && i < 6; i++) {
        existingUrls[i] = existing.imageUrls![i];
      }
    } else if (existing?.imageUrl != null && existing!.imageUrl!.isNotEmpty) {
      existingUrls[0] = existing.imageUrl;
    }

    bool saving = false;

    Future<void> pickImage(int index, StateSetter setState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          fileNames[index] = pickedFile.name;
          existingUrls[index] = null; // Clear existing URL if replacing
          if (kIsWeb) {
            imageBytes[index] = await pickedFile.readAsBytes();
          } else {
            imageFiles[index] = File(pickedFile.path);
          }
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }

    Future<List<String>> uploadGiftImages(String giftId) async {
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final List<String> urls = [];

      for (int i = 0; i < 6; i++) {
        // If existing URL and no new image, keep existing
        if (existingUrls[i] != null &&
            imageBytes[i] == null &&
            imageFiles[i] == null) {
          urls.add(existingUrls[i]!);
          continue;
        }

        // If new image selected, upload it
        if (imageBytes[i] != null || imageFiles[i] != null) {
          try {
            final ref = storage
                .ref()
                .child('gifts')
                .child(giftId)
                .child('img_$i.jpg');

            String contentType = 'image/jpeg';
            final name = fileNames[i]?.toLowerCase() ?? '';
            if (name.endsWith('.png')) contentType = 'image/png';

            UploadTask task;
            if (imageBytes[i] != null) {
              task = ref.putData(
                imageBytes[i]!,
                SettableMetadata(
                  contentType: contentType,
                  cacheControl: 'public, max-age=3600',
                ),
              );
            } else {
              task = ref.putFile(
                imageFiles[i]!,
                SettableMetadata(
                  contentType: contentType,
                  cacheControl: 'public, max-age=3600',
                ),
              );
            }

            final snap = await task;
            if (snap.state == TaskState.success) {
              final url = await ref.getDownloadURL();
              urls.add(url);
            }
          } catch (e) {

          }
        }
      }

      return urls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Gift' : 'Edit Gift'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gift Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
                    title: const Text('Active'),
                  ),
                  const SizedBox(height: 12),
                  // Multi-Image Grid
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gift Images (minimum 4 required)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: 6,
                      itemBuilder: (gctx, i) {
                        Widget preview;
                        if (imageBytes[i] != null) {
                          preview = Image.memory(
                            imageBytes[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (imageFiles[i] != null && !kIsWeb) {
                          preview = Image.file(
                            imageFiles[i]!,
                            fit: BoxFit.cover,
                          );
                        } else if (existingUrls[i] != null) {
                          preview = Image.network(
                            existingUrls[i]!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(
                              Icons.card_giftcard,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                          );
                        } else {
                          preview = Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.grey[400],
                          );
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => pickImage(i, setState),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(child: preview),
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name is required')),
                        );
                        return;
                      }

                      // Count selected images (existing + new)
                      int imageCount = 0;
                      for (int i = 0; i < 6; i++) {
                        if (existingUrls[i] != null ||
                            imageBytes[i] != null ||
                            imageFiles[i] != null) {
                          imageCount++;
                        }
                      }

                      if (imageCount < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Minimum 4 images required!'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);
                      try {
                        final giftId =
                            existing?.id ??
                            'g${DateTime.now().millisecondsSinceEpoch}';
                        final urls = await uploadGiftImages(giftId);

                        if (urls.isEmpty) {
                          throw Exception('Failed to upload images');
                        }

                        final gift = Gift(
                          id: giftId,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                          imageUrl: urls.first,
                          imageUrls: urls,
                          isActive: isActive,
                          displayOrder:
                              int.tryParse(orderCtrl.text.trim()) ?? 0,
                          createdAt: existing?.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        final provider = Provider.of<GiftProvider>(
                          context,
                          listen: false,
                        );
                        if (existing == null) {
                          await provider.addGift(gift);
                        } else {
                          await provider.updateGift(giftId, gift);
                        }
                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? 'Gift added successfully!'
                                    : 'Gift updated successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existing == null ? 'Add Gift' : 'Update Gift'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab(
    ProductProvider productProvider,
    List<Product> products,
  ) {
    return Column(
      children: [
        // Product count and Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Products: ${products.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Products list
        Expanded(
          child: productProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first product to get started!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (ctx, index) {
                    final product = products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹${product.price.toStringAsFixed(2)}'),
                            if (product.category != null)
                              Text(
                                product.category!,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              '${product.imageUrls?.length ?? 1} images',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditProductDialog(product),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Product'),
                                    content: Text('Delete "${product.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await productProvider.deleteProduct(
                                      product.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Product deleted successfully!',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, _) {
        final categories = categoryProvider.categories;
        return Column(
          children: [
            // Category count and Add button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Categories: ${categories.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Categories list
            Expanded(
              child: categoryProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first category to get started!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final item = categories.removeAt(oldIndex);
                        categories.insert(newIndex, item);
                        // Update order in Firestore
                        for (int i = 0; i < categories.length; i++) {
                          await categoryProvider.updateCategory(
                            categories[i].id,
                            Category(
                              id: categories[i].id,
                              name: categories[i].name,
                              imageUrl: categories[i].imageUrl,
                              order: i,
                            ),
                          );
                        }
                      },
                      itemBuilder: (ctx, index) {
                        final category = categories[index];
                        return Card(
                          key: ValueKey(category.id),
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                category.imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.category),
                                ),
                              ),
                            ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Order: ${category.order}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showAddCategoryDialog(category),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: Text(
                                          'Delete "${category.name}" category?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogCtx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await categoryProvider.deleteCategory(
                                          category.id,
                                        );
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Category deleted successfully!',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddCategoryDialog(Category? existingCategory) {
    final nameCtrl = TextEditingController(text: existingCategory?.name);
    final orderCtrl = TextEditingController(
      text: existingCategory?.order.toString() ?? '0',
    );

    Uint8List? imageBytes;
    File? imageFile;
    String? fileName;
    String? existingImageUrl = existingCategory?.imageUrl;

    bool saving = false;

    Future<void> pickImage(StateSetter setState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          fileName = pickedFile.name;
          if (kIsWeb) {
            imageBytes = await pickedFile.readAsBytes();
          } else {
            imageFile = File(pickedFile.path);
          }
          existingImageUrl = null; // Clear existing when new selected
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }

    Future<String?> uploadCategoryImage(String categoryId) async {
      if (imageBytes == null && imageFile == null) {
        return existingImageUrl; // Keep existing if no new image
      }

      try {

        final storage = FirebaseStorage.instanceFor(
          bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
        );
        final ref = storage.ref().child('categories').child('$categoryId.png');

        String contentType = 'image/png';
        final name = fileName?.toLowerCase() ?? '';
        if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
          contentType = 'image/jpeg';
        }

        UploadTask task;
        if (imageBytes != null) {
          task = ref.putData(
            imageBytes!,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public, max-age=3600',
            ),
          );
        } else {
          task = ref.putFile(
            imageFile!,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public, max-age=3600',
            ),
          );
        }

        final snapshot = await task;
        final url = await snapshot.ref.getDownloadURL();

        return url;
      } catch (e) {

        rethrow;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existingCategory == null ? 'Add Category' : 'Edit Category',
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Image picker
                  const Text(
                    'Category Icon (512x512 recommended)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => pickImage(setState),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageBytes != null
                            ? Image.memory(imageBytes!, fit: BoxFit.cover)
                            : imageFile != null && !kIsWeb
                            ? Image.file(imageFile!, fit: BoxFit.cover)
                            : existingImageUrl != null
                            ? Image.network(
                                existingImageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Category name is required!'),
                          ),
                        );
                        return;
                      }

                      if (imageBytes == null &&
                          imageFile == null &&
                          existingImageUrl == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Category image is required!'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);

                      try {
                        final categoryId =
                            existingCategory?.id ??
                            'cat${DateTime.now().millisecondsSinceEpoch}';
                        final imageUrl = await uploadCategoryImage(categoryId);

                        if (imageUrl == null) {
                          throw Exception('Failed to upload image');
                        }

                        final category = Category(
                          id: categoryId,
                          name: nameCtrl.text,
                          imageUrl: imageUrl,
                          order: int.tryParse(orderCtrl.text) ?? 0,
                        );

                        final categoryProvider = Provider.of<CategoryProvider>(
                          context,
                          listen: false,
                        );

                        if (existingCategory == null) {
                          await categoryProvider.addCategory(category);
                        } else {
                          await categoryProvider.updateCategory(
                            categoryId,
                            category,
                          );
                        }

                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existingCategory == null
                                    ? 'Category added successfully!'
                                    : 'Category updated successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existingCategory == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Service Categories Tab
  Widget _buildServiceCategoriesTab({required bool isAdmin}) {
    return Consumer<ServiceCategoryProvider>(
      builder: (context, serviceCategoryProvider, _) {
        final serviceCategories = serviceCategoryProvider.serviceCategories;

        return Column(
          children: [
            if (!isAdmin)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only access. Please contact an admin for changes.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            // Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: isAdmin
                    ? () => _showAddEditServiceCategoryDialog()
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add Service Category'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Service Categories List
            Expanded(
              child: serviceCategories.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No service categories yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: serviceCategories.length,
                      itemBuilder: (context, index) {
                        final category = serviceCategories[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading:
                                category.imageUrl != null &&
                                    category.imageUrl!.isNotEmpty
                                ? CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(
                                      category.imageUrl!,
                                    ),
                                    backgroundColor: Colors.grey[200],
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                          category.colorHex.replaceFirst(
                                            '#',
                                            '0xFF',
                                          ),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getIconFromName(category.iconName),
                                      color: Colors.white,
                                    ),
                                  ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(category.description),
                                const SizedBox(height: 4),
                                Text(
                                  'Base Price: ₹${category.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: isAdmin
                                      ? () => _showAddEditServiceCategoryDialog(
                                          category: category,
                                        )
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: isAdmin
                                      ? () => _deleteServiceCategory(category)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconFromName(String iconName) {
    final iconMap = {
      'plumbing': Icons.plumbing,
      'carpenter': Icons.carpenter,
      'electrical_services': Icons.electrical_services,
      'directions_car': Icons.directions_car,
      'cleaning_services': Icons.cleaning_services,
      'security': Icons.security,
      'home_repair_service': Icons.home_repair_service,
      'format_paint': Icons.format_paint,
      'ac_unit': Icons.ac_unit,
      'yard': Icons.yard,
      'pest_control': Icons.pest_control,
      'kitchen': Icons.kitchen,
      'miscellaneous_services': Icons.miscellaneous_services,
    };
    return iconMap[iconName] ?? Icons.miscellaneous_services;
  }

  void _showAddEditServiceCategoryDialog({ServiceCategory? category}) {
    final nameCtrl = TextEditingController(text: category?.name);
    final descCtrl = TextEditingController(text: category?.description);
    final priceCtrl = TextEditingController(
      text: category?.basePrice.toString() ?? '500',
    );

    String selectedIcon = category?.iconName ?? 'miscellaneous_services';
    String selectedColor = category?.colorHex ?? '#2196F3';
    String? imageUrl = category?.imageUrl;
    Uint8List? imageBytes;
    File? imageFile;

    final availableIcons = {
      'plumbing': Icons.plumbing,
      'carpenter': Icons.carpenter,
      'electrical_services': Icons.electrical_services,
      'directions_car': Icons.directions_car,
      'cleaning_services': Icons.cleaning_services,
      'security': Icons.security,
      'home_repair_service': Icons.home_repair_service,
      'format_paint': Icons.format_paint,
      'ac_unit': Icons.ac_unit,
      'yard': Icons.yard,
      'pest_control': Icons.pest_control,
      'kitchen': Icons.kitchen,
      'miscellaneous_services': Icons.miscellaneous_services,
    };

    final availableColors = {
      '#2196F3': 'Blue',
      '#F44336': 'Red',
      '#4CAF50': 'Green',
      '#FF9800': 'Orange',
      '#9C27B0': 'Purple',
      '#00BCD4': 'Cyan',
      '#795548': 'Brown',
      '#FFC107': 'Amber',
      '#8BC34A': 'Light Green',
      '#009688': 'Teal',
      '#3F51B5': 'Indigo',
      '#E91E63': 'Pink',
    };

    bool saving = false;

    Future<void> pickImage(StateSetter setState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        if (kIsWeb) {
          imageBytes = await pickedFile.readAsBytes();
        } else {
          imageFile = File(pickedFile.path);
        }
        setState(() {});
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            category == null ? 'Add Service Category' : 'Edit Service Category',
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Picker Section
                  const Text(
                    'Category Image (Optional):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => pickImage(setState),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child:
                          imageBytes != null ||
                              imageFile != null ||
                              imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageBytes != null
                                  ? Image.memory(imageBytes!, fit: BoxFit.cover)
                                  : imageFile != null
                                  ? Image.file(imageFile!, fit: BoxFit.cover)
                                  : Image.network(imageUrl!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add image',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (imageBytes != null ||
                      imageFile != null ||
                      imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            imageBytes = null;
                            imageFile = null;
                            imageUrl = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Remove Image',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      hintText: 'e.g., Plumber, Electrician',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Brief description of the service',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Base Price (₹) *',
                      hintText: 'Starting price for this service',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Icon (fallback if no image):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: availableIcons.length,
                      itemBuilder: (context, index) {
                        final iconName = availableIcons.keys.elementAt(index);
                        final icon = availableIcons[iconName]!;
                        final isSelected = selectedIcon == iconName;

                        return InkWell(
                          onTap: () {
                            setState(() => selectedIcon = iconName);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? Colors.white : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Color:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableColors.entries.map((entry) {
                      final isSelected = selectedColor == entry.key;
                      return InkWell(
                        onTap: () {
                          setState(() => selectedColor = entry.key);
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(entry.key.replaceFirst('#', '0xFF')),
                            ),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          descCtrl.text.trim().isEmpty ||
                          priceCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all required fields'),
                          ),
                        );
                        return;
                      }

                      final price = double.tryParse(priceCtrl.text.trim());
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid price'),
                          ),
                        );
                        return;
                      }

                      setState(() => saving = true);

                      try {
                        final serviceCategoryProvider =
                            Provider.of<ServiceCategoryProvider>(
                              context,
                              listen: false,
                            );

                        // Upload image if selected
                        String? uploadedImageUrl = imageUrl;
                        if (imageBytes != null || imageFile != null) {
                          final fileName =
                              '${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final ref = FirebaseStorage.instance
                              .ref()
                              .child('service_category_images')
                              .child(fileName);

                          if (kIsWeb) {
                            await ref.putData(imageBytes!);
                          } else {
                            await ref.putFile(imageFile!);
                          }
                          uploadedImageUrl = await ref.getDownloadURL();
                        }

                        final newCategory = ServiceCategory(
                          id: category?.id ?? '',
                          name: nameCtrl.text.trim(),
                          iconName: selectedIcon,
                          colorHex: selectedColor,
                          description: descCtrl.text.trim(),
                          basePrice: price,
                          imageUrl: uploadedImageUrl,
                          createdAt: category?.createdAt ?? DateTime.now(),
                        );

                        if (category == null) {
                          await serviceCategoryProvider.addServiceCategory(
                            newCategory,
                          );
                        } else {
                          await serviceCategoryProvider.updateServiceCategory(
                            newCategory,
                          );
                        }

                        if (mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                category == null
                                    ? 'Service category added successfully!'
                                    : 'Service category updated successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(category == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteServiceCategory(ServiceCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final serviceCategoryProvider = Provider.of<ServiceCategoryProvider>(
          context,
          listen: false,
        );
        await serviceCategoryProvider.deleteServiceCategory(category.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service category deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      }
    }
  }

  // Featured Sections Tab
  Widget _buildFeaturedSectionsTab({required bool isAdmin}) {
    return Consumer<FeaturedSectionProvider>(
      builder: (context, featuredProvider, _) {
        return Column(
          children: [
            if (!isAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only access. Please contact an admin for changes.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Featured Sections',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isAdmin
                        ? () => _showAddFeaturedSectionDialog(featuredProvider)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Section'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: featuredProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : featuredProvider.sections.isEmpty
                  ? const Center(
                      child: Text(
                        'No featured sections yet.\nAdd sections like "HOTS DEALS", "Daily Needs", etc.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: featuredProvider.sections.length,
                      itemBuilder: (ctx, i) {
                        final section = featuredProvider.sections[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${section.displayOrder}'),
                            ),
                            title: Text(
                              section.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Category: ${section.categoryName}\n'
                              'Status: ${section.isActive ? "Active" : "Inactive"}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: section.isActive,
                                  onChanged: isAdmin
                                      ? (val) => featuredProvider.toggleActive(
                                          section.id,
                                        )
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: isAdmin
                                      ? () => _showEditFeaturedSectionDialog(
                                          featuredProvider,
                                          section,
                                        )
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: isAdmin
                                      ? () => _confirmDeleteFeaturedSection(
                                          featuredProvider,
                                          section.id,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddFeaturedSectionDialog(FeaturedSectionProvider provider) {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Featured Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g., HOTS DEALS)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name (e.g., Hot Deals)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order (1, 2, 3...)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || categoryCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final section = FeaturedSection(
                id: '',
                title: titleCtrl.text.trim(),
                categoryName: categoryCtrl.text.trim(),
                displayOrder: int.tryParse(orderCtrl.text) ?? 1,
                isActive: true,
              );

              try {
                await provider.addSection(section);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Featured section added!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditFeaturedSectionDialog(
    FeaturedSectionProvider provider,
    FeaturedSection section,
  ) {
    final titleCtrl = TextEditingController(text: section.title);
    final categoryCtrl = TextEditingController(text: section.categoryName);
    final orderCtrl = TextEditingController(
      text: section.displayOrder.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Featured Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = section.copyWith(
                title: titleCtrl.text.trim(),
                categoryName: categoryCtrl.text.trim(),
                displayOrder:
                    int.tryParse(orderCtrl.text) ?? section.displayOrder,
              );

              try {
                await provider.updateSection(updated);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Featured section updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFeaturedSection(
    FeaturedSectionProvider provider,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section'),
        content: const Text(
          'Are you sure you want to delete this featured section?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteSection(id);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Featured section deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    // Filter out Firestore references and null values
    String displayValue = value.toString().trim();

    // Check if it's a Firestore reference or invalid data
    if (displayValue.contains('DocumentReference') ||
        displayValue.contains('projects/') ||
        displayValue.startsWith('/') ||
        displayValue == 'null') {
      return const SizedBox.shrink(); // Hide completely
    }

    // Show empty placeholder if value is empty
    if (displayValue.isEmpty) {
      displayValue = 'N/A';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      // First get the partner request details
      final requestDoc = await FirebaseFirestore.instance
          .collection('partner_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;

      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add approval message
      if (status == 'approved') {
        updateData['notificationMessage'] =
            'Congratulations! Your partner request has been approved. '
            'You can now login and start selling/providing services.';

        // Create/Update user account with seller role
        final email = requestData['email'];
        final phone = requestData['phone'];
        final name = requestData['name'];

        // Check if user with this email or phone already exists
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (usersQuery.docs.isNotEmpty) {
          // User exists, update role based on request
          final userId = usersQuery.docs.first.id;
          String assignedRole = 'seller'; // default

          // Map role from request to actual role
          if (requestData['role'] == 'Service Provider') {
            assignedRole = 'service_provider';
          } else if (requestData['role'] == 'Seller') {
            assignedRole = 'seller';
          } else if (requestData['role'] == 'Core Staff') {
            assignedRole = 'core_staff';
          } else if (requestData['role'] == 'Administrator') {
            assignedRole = 'administrator';
          } else if (requestData['role'] == 'Store Manager') {
            assignedRole = 'store_manager';
          } else if (requestData['role'] == 'Manager') {
            assignedRole = 'manager';
          } else if (requestData['role'] == 'Delivery Partner') {
            assignedRole = 'delivery_partner';
          } else if (requestData['role'] == 'Customer Care') {
            assignedRole = 'customer_care';
          }

          final updateData = {
            'role': assignedRole,
            'businessName': requestData['businessName'],
            'district': requestData['district'],
            'minCharge': requestData['minCharge'],
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // If service provider, copy category fields
          if (assignedRole == 'service_provider' &&
              requestData.containsKey('serviceCategoryId')) {
            updateData['serviceCategoryId'] = requestData['serviceCategoryId'];
            updateData['serviceCategoryName'] =
                requestData['serviceCategoryName'];
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update(updateData);
        } else {
          // User doesn't exist, create new user document (they'll complete signup later)
          // We'll create a placeholder that they can claim when they sign up
          await FirebaseFirestore.instance
              .collection('pending_sellers')
              .doc(email)
              .set({
                'email': email,
                'phone': phone,
                'name': name,
                'role': 'seller',
                'businessName': requestData['businessName'],
                'district': requestData['district'],
                'minCharge': requestData['minCharge'],
                'panNumber': requestData['panNumber'],
                'aadhaarNumber': requestData['aadhaarNumber'],
                'profilePicUrl': requestData['profilePicUrl'],
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } else if (status == 'rejected') {
        updateData['notificationMessage'] =
            'Your partner request has been rejected. '
            'Please contact support for more information.';
      }

      await FirebaseFirestore.instance
          .collection('partner_requests')
          .doc(requestId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Request approved! ${requestData['email']} can now login as seller.'
                  : 'Request $status successfully',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePartnerRequest(String requestId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this partner request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('partner_requests')
          .doc(requestId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPartnerRequest(PartnerRequest request) {
    final nameCtrl = TextEditingController(text: request.name);
    final phoneCtrl = TextEditingController(text: request.phone);
    final emailCtrl = TextEditingController(text: request.email);
    final districtCtrl = TextEditingController(text: request.district);
    final pincodeCtrl = TextEditingController(text: request.pincode);
    final businessCtrl = TextEditingController(text: request.businessName);
    final panCtrl = TextEditingController(text: request.panNumber);
    final aadhaarCtrl = TextEditingController(text: request.aadhaarNumber);
    final minChargeCtrl = TextEditingController(
      text: request.minCharge.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Partner Request'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: districtCtrl,
                  decoration: const InputDecoration(labelText: 'District'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pincodeCtrl,
                  decoration: const InputDecoration(labelText: 'PIN Code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: businessCtrl,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: panCtrl,
                  decoration: const InputDecoration(labelText: 'PAN Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aadhaarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minChargeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Charge',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('partner_requests')
                    .doc(request.id)
                    .update({
                      'name': nameCtrl.text,
                      'phone': phoneCtrl.text,
                      'email': emailCtrl.text,
                      'district': districtCtrl.text,
                      'pincode': pincodeCtrl.text,
                      'businessName': businessCtrl.text,
                      'panNumber': panCtrl.text,
                      'aadhaarNumber': aadhaarCtrl.text,
                      'minCharge': minChargeCtrl.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPartnersTab() {
    return RoleManagementTab(
      collection: 'delivery_partners',
      role: null,
      requestRole: 'Delivery Partner',
      onEdit: (id, name, email, phone, role, pincode) =>
          _editPartner(id, name, email, phone, pincode),
      onDelete: _deletePartner,
      onRequestAction: _updateRequestStatus,
    );
  }

  String _userFilter = 'All'; // All, Most Active, Active, Inactive

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Most Active', 'Active', 'Inactive'].map((filter) {
                final isSelected = _userFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _userFilter = filter);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.blue[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'user')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data?.docs ?? [];
              
              // Client-side filtering and sorting based on _userFilter
              if (_userFilter == 'Most Active') {
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCount = (aData['orderCount'] as num?)?.toInt() ?? 0;
                  final bCount = (bData['orderCount'] as num?)?.toInt() ?? 0;
                  return bCount.compareTo(aCount); // Descending
                });
              } else if (_userFilter == 'Active') {
                // Active: Logged in within last 30 days
                final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastLogin = data['lastLogin'] as Timestamp?;
                  if (lastLogin == null) return false;
                  return lastLogin.toDate().isAfter(thirtyDaysAgo);
                }).toList();
                // Sort by lastLogin descending
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['lastLogin'] as Timestamp?;
                  final bTime = bData['lastLogin'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              } else if (_userFilter == 'Inactive') {
                // Inactive: No login or older than 30 days
                final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastLogin = data['lastLogin'] as Timestamp?;
                  if (lastLogin == null) return true;
                  return lastLogin.toDate().isBefore(thirtyDaysAgo);
                }).toList();
                 // Sort by createdAt descending (newest inactive users first)
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              } else {
                // All: Sort by createdAt descending
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              }

              if (users.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No users found', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  final name = userData['name'] ?? 'N/A';
                  final email = userData['email'] ?? 'N/A';
                  final phone = userData['phone'] ?? 'N/A';
                  final role = userData['role'] ?? 'user';
                  final servicePincode = userData['service_pincode'] as String?;
                  final createdAt = userData['createdAt'] != null
                      ? (userData['createdAt'] as Timestamp).toDate()
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'admin'
                            ? Colors.red
                            : role == 'seller'
                            ? Colors.blue
                            : role == 'delivery_partner'
                            ? Colors.orange
                            : Colors.green,
                        child: Icon(
                          role == 'admin'
                              ? Icons.admin_panel_settings
                              : role == 'seller'
                              ? Icons.store
                              : role == 'delivery_partner'
                              ? Icons.delivery_dining
                              : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(email),
                      trailing: Chip(
                        label: Text(
                          role.toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: role == 'admin'
                            ? Colors.red[100]
                            : role == 'seller'
                            ? Colors.blue[100]
                            : role == 'delivery_partner'
                            ? Colors.orange[100]
                            : Colors.green[100],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('User ID', userId),
                              _buildInfoRow('Name', name),
                              _buildInfoRow('Email', email),
                              _buildInfoRow('Phone', phone),
                              _buildInfoRow('Role', role),
                              if (servicePincode != null)
                                _buildInfoRow('Service Pincode', servicePincode),
                              if (createdAt != null)
                                _buildInfoRow('Joined', _formatDate(createdAt)),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                alignment: WrapAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _editUser(
                                      userId,
                                      name,
                                      email,
                                      phone,
                                      role,
                                      servicePincode,
                                    ),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _changeUserRole(userId, role),
                                    icon: const Icon(Icons.swap_horiz),
                                    label: const Text('Change Role'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _deleteUser(userId, email),
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
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
    );
  }

  void _editUser(
    String userId,
    String name,
    String email,
    String phone,
    String role,
    String? servicePincode,
  ) {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone);
    final pincodeController = TextEditingController(text: servicePincode ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              if (role == 'delivery_partner')
                TextField(
                  controller: pincodeController,
                  decoration: const InputDecoration(labelText: 'Service Pincode'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updates = {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                };
                if (role == 'delivery_partner') {
                  updates['service_pincode'] = pincodeController.text.trim();
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update(updates);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeUserRole(String userId, String currentRole) {
    String? selectedRole = currentRole == 'admin' ? 'administrator' : currentRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                RadioListTile<String>(
                  title: const Text('User'),
                  value: 'user',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Seller'),
                  value: 'seller',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Service Provider'),
                  value: 'service_provider',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Core Staff'),
                  value: 'core_staff',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Administrator'),
                  value: 'administrator',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Store Manager'),
                  value: 'store_manager',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Manager'),
                  value: 'manager',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Delivery Partner'),
                  value: 'delivery_partner',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
                RadioListTile<String>(
                  title: const Text('Customer Care'),
                  value: 'customer_care',
                  groupValue: selectedRole,
                  onChanged: (value) => setState(() => selectedRole = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // If someone somehow still selects legacy 'admin', map to 'administrator'
                  final persistedRole = selectedRole == 'admin'
                      ? 'administrator'
                      : selectedRole;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({'role': persistedRole});

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Role changed to $persistedRole'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to change role: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User Completely'),
        content: Text(
          'Are you sure you want to delete this user?\n\nEmail: $email\n\nThis will:\n• Delete Firebase Auth account\n• Delete Firestore user document\n• Delete related partner requests\n• Delete from pending_sellers (if exists)\n\nThis action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Deleting user...'),
              ],
            ),
            duration: Duration(minutes: 1),
          ),
        );
      }

      // Call Cloud Function to delete user completely
      // Use default region where the function is deployed (us-central1 unless changed)
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('deleteUserAccount');

      final result = await callable.call({'userId': userId, 'email': email});

      // Hide loading
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (result.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted completely (Auth + Firestore)'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception(result.data['message'] ?? 'Unknown error');
      }
    } catch (e) {
      // Hide loading
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildPartnersList(String? status) {
    Query query = FirebaseFirestore.instance.collection('delivery_partners');

    if (status != null) {
      query = query.where('status', isEqualTo: status);
      query = query.orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No delivery partners available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        var partners = snapshot.data!.docs
            .map(
              (doc) => DeliveryPartnerModel.fromMap(
                doc.data() as Map<String, dynamic>,
              ),
            )
            .toList();

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          partners = partners
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_searchQuery) ||
                    p.phone.contains(_searchQuery) ||
                    p.email.toLowerCase().contains(_searchQuery),
              )
              .toList();
        }

        if (partners.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No ${status ?? 'available'} partners',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: partners.length,
          itemBuilder: (context, index) {
            final partner = partners[index];
            return this._buildPartnerCard(partner);
          },
        );
      },
    );
  }

  Widget _buildPartnerCard(DeliveryPartnerModel partner) {
    Color statusColor = Colors.orange;
    if (partner.status == 'approved') statusColor = Colors.green;
    if (partner.status == 'rejected') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(
          partner.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(partner.phone),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'approve') {
              _approvePartner(partner);
            } else if (value == 'reject') {
              _rejectPartner(partner);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'approve',
              child: Text('Approve'),
            ),
            const PopupMenuItem<String>(value: 'reject', child: Text('Reject')),
          ],
        ),
      ),
    );
  }

  Future<void> _approvePartner(DeliveryPartnerModel partner) async {
    try {
      final dpRef = FirebaseFirestore.instance
          .collection('delivery_partners')
          .doc(partner.id);

      // Check if document exists, if not create it
      final dpSnap = await dpRef.get();
      if (!dpSnap.exists) {
        // Create new delivery partner entry
        await dpRef.set({
          'id': partner.id,
          'name': partner.name,
          'phone': partner.phone,
          'email': partner.email,
          'address': partner.address,
          'vehicleType': partner.vehicleType,
          'vehicleNumber': partner.vehicleNumber ?? '',
          'status': 'approved',
          'createdAt': partner.createdAt,
          'approvedAt': FieldValue.serverTimestamp(),
          'rejectionReason': null,
        });
      } else {
        // Update existing entry
        await dpRef.update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${partner.name} approved successfully!'),
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

  Future<void> _rejectPartner(DeliveryPartnerModel partner) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${partner.name}\'s application?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('delivery_partners')
            .doc(partner.id)
            .update({
              'status': 'rejected',
              'rejectionReason': reasonController.text.trim().isEmpty
                  ? null
                  : reasonController.text.trim(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application rejected'),
              backgroundColor: Colors.red,
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
  }

  Future<void> _addTestDeliveryPartners() async {
    try {
      final now = DateTime.now();
      final testPartners = [
        {
          'id': 'partner_001',
          'name': 'Raj Kumar',
          'phone': '9876543210',
          'email': 'raj@delivery.com',
          'address': '123 Main Street, City',
          'vehicleType': 'bike',
          'vehicleNumber': 'DL-01-AB-1234',
          'status': 'approved',
          'createdAt': Timestamp.fromDate(now.subtract(Duration(days: 5))),
          'approvedAt': Timestamp.fromDate(now.subtract(Duration(days: 4))),
        },
        {
          'id': 'partner_002',
          'name': 'Priya Singh',
          'phone': '9876543211',
          'email': 'priya@delivery.com',
          'address': '456 Park Avenue, City',
          'vehicleType': 'car',
          'vehicleNumber': 'DL-02-CD-5678',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(now.subtract(Duration(days: 2))),
        },
        {
          'id': 'partner_003',
          'name': 'Amit Patel',
          'phone': '9876543212',
          'email': 'amit@delivery.com',
          'address': '789 Market Road, City',
          'vehicleType': 'bike',
          'vehicleNumber': 'DL-03-EF-9012',
          'status': 'approved',
          'createdAt': Timestamp.fromDate(now.subtract(Duration(days: 3))),
          'approvedAt': Timestamp.fromDate(now.subtract(Duration(days: 2))),
        },
        {
          'id': 'partner_004',
          'name': 'Sneha Gupta',
          'phone': '9876543213',
          'email': 'sneha@delivery.com',
          'address': '321 Commercial Zone, City',
          'vehicleType': 'bike',
          'vehicleNumber': 'DL-04-GH-3456',
          'status': 'rejected',
          'createdAt': Timestamp.fromDate(now.subtract(Duration(days: 7))),
          'rejectionReason': 'Vehicle documents not verified',
        },
      ];

      final batch = FirebaseFirestore.instance.batch();
      for (var partner in testPartners) {
        final docRef = FirebaseFirestore.instance
            .collection('delivery_partners')
            .doc(partner['id'] as String);
        batch.set(docRef, partner);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test delivery partners added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding test data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCoreStaffTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('core_staff').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final staffMembers = snapshot.data?.docs ?? [];

        return Column(
          children: [
            // Add Staff Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Staff Members: ${staffMembers.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCoreStaffDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Staff List
            Expanded(
              child: staffMembers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No staff members yet',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: staffMembers.length,
                      itemBuilder: (context, index) {
                        final doc = staffMembers[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'N/A';
                        final position = data['position'] ?? 'N/A';
                        final email = data['email'] ?? 'N/A';
                        final phone = data['phone'] ?? 'N/A';
                        final imageUrl = data['imageUrl'] as String?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: imageUrl != null
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Position: $position'),
                                Text('Email: $email'),
                                Text('Phone: $phone'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showAddCoreStaffDialog(
                                    staffId: doc.id,
                                    staffData: data,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteCoreStaff(doc.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddCoreStaffDialog({
    String? staffId,
    Map<String, dynamic>? staffData,
  }) {
    final nameCtrl = TextEditingController(text: staffData?['name'] ?? '');
    final positionCtrl = TextEditingController(
      text: staffData?['position'] ?? '',
    );
    final emailCtrl = TextEditingController(text: staffData?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: staffData?['phone'] ?? '');
    final bioCtrl = TextEditingController(text: staffData?['bio'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(staffId == null ? 'Add Staff Member' : 'Edit Staff Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: positionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Position (e.g., Manager, Developer)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                decoration: const InputDecoration(labelText: 'Bio/Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCoreStaff(
                nameCtrl.text,
                positionCtrl.text,
                emailCtrl.text,
                phoneCtrl.text,
                bioCtrl.text,
                staffId,
              );
              Navigator.pop(ctx);
            },
            child: Text(staffId == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCoreStaff(
    String name,
    String position,
    String email,
    String phone,
    String bio,
    String? staffId,
  ) async {
    try {
      final data = {
        'name': name,
        'position': position,
        'email': email,
        'phone': phone,
        'bio': bio,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (staffId == null) {
        await FirebaseFirestore.instance.collection('core_staff').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member added successfully!')),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('core_staff')
            .doc(staffId)
            .update(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCoreStaff(String staffId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Member'),
        content: const Text(
          'Are you sure you want to delete this staff member?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('core_staff')
            .doc(staffId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member deleted successfully!')),
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
  }

  // Method to add sample users for testing permissions
  Future<void> _addSampleUsers() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();

      // Sample Sellers
      final sellers = [
        {
          'name': 'Raj Kumar',
          'email': 'raj.seller@test.com',
          'phone': '+919876543210',
          'role': 'seller',
          'createdAt': now,
          'permissions': {
            'can_add_product': true,
            'can_manage_products': true,
            'can_view_orders': true,
            'can_view_analytics': true,
          },
        },
        {
          'name': 'Priya Sharma',
          'email': 'priya.seller@test.com',
          'phone': '+919876543211',
          'role': 'seller',
          'createdAt': now,
          'permissions': {
            'can_add_product': true,
            'can_manage_products': true,
            'can_view_orders': false, // Restricted for testing
            'can_view_analytics': true,
          },
        },
      ];

      // Sample Service Providers
      final serviceProviders = [
        {
          'name': 'Amit Electrician',
          'email': 'amit.service@test.com',
          'phone': '+919876543212',
          'role': 'service_provider',
          'createdAt': now,
          'permissions': {
            'can_manage_services': true,
          },
        },
        {
          'name': 'Neha Plumber',
          'email': 'neha.service@test.com',
          'phone': '+919876543213',
          'role': 'service_provider',
          'createdAt': now,
          'permissions': {
            'can_manage_services': false, // Restricted for testing
          },
        },
      ];

      // Sample Delivery Partners
      final deliveryPartners = [
        {
          'name': 'Suresh Delivery',
          'email': 'suresh.delivery@test.com',
          'phone': '+919876543214',
          'role': 'delivery_partner',
          'createdAt': now,
          'permissions': {
            'can_update_status': true,
          },
        },
        {
          'name': 'Kavita Delivery',
          'email': 'kavita.delivery@test.com',
          'phone': '+919876543215',
          'role': 'delivery_partner',
          'createdAt': now,
          'permissions': {
            'can_update_status': false, // Restricted for testing
          },
        },
      ];

      // Add all users to batch
      final allUsers = [...sellers, ...serviceProviders, ...deliveryPartners];
      for (int i = 0; i < allUsers.length; i++) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc('test_user_${DateTime.now().millisecondsSinceEpoch}_$i');
        batch.set(docRef, allUsers[i]);
      }

      // Commit batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sample users added successfully! Check Permissions tab.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error adding sample users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Permissions Tab
  String _selectedPermissionRole = 'seller';

  Widget _buildPermissionsTab() {
    return Column(
      children: [
        // Role Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Select Role:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Sellers'),
                    selected: _selectedPermissionRole == 'seller',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPermissionRole = 'seller');
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Service Providers'),
                    selected: _selectedPermissionRole == 'service_provider',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPermissionRole = 'service_provider');
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Delivery Partners'),
                    selected: _selectedPermissionRole == 'delivery_partner',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPermissionRole = 'delivery_partner');
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Admin Panel'),
                    selected: _selectedPermissionRole == 'administrator',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPermissionRole = 'administrator');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: _selectedPermissionRole)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final users = snapshot.data?.docs ?? [];

              if (users.isEmpty) {
                return const Center(child: Text('No users found for this role'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final permissions =
                      data['permissions'] as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['photoURL'] != null
                            ? NetworkImage(data['photoURL'])
                            : null,
                        child: data['photoURL'] == null
                            ? Text((data['name'] ?? 'U')[0].toUpperCase())
                            : null,
                      ),
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Text(data['email'] ?? 'No Email'),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.security),
                        label: const Text('Manage Permissions'),
                        onPressed: () =>
                            _showPermissionDialog(doc.id, data, permissions),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPermissionDialog(
    String userId,
    Map<String, dynamic> userData,
    Map<String, dynamic> currentPermissions,
  ) {
    final Map<String, String> availablePermissions = {};
    if (_selectedPermissionRole == 'seller') {
      // Product Management
      availablePermissions['can_add_product'] = 'Add New Products';
      availablePermissions['can_edit_product'] = 'Edit Products';
      availablePermissions['can_delete_product'] = 'Delete Products';
      availablePermissions['can_upload_product_images'] = 'Upload Product Images';
      availablePermissions['can_manage_inventory'] = 'Manage Inventory/Stock';
      availablePermissions['can_set_prices'] = 'Set Product Prices';
      availablePermissions['can_set_discounts'] = 'Set Discounts/Offers';
      
      // Order Management
      availablePermissions['can_view_orders'] = 'View Orders';
      availablePermissions['can_update_order_status'] = 'Update Order Status';
      availablePermissions['can_cancel_orders'] = 'Cancel Orders';
      availablePermissions['can_process_refunds'] = 'Process Refunds';
      
      // Analytics & Reports
      availablePermissions['can_view_analytics'] = 'View Sales Analytics';
      availablePermissions['can_view_reports'] = 'View Sales Reports';
      availablePermissions['can_export_data'] = 'Export Data';
      
      // Customer Interaction
      availablePermissions['can_view_reviews'] = 'View Customer Reviews';
      availablePermissions['can_respond_reviews'] = 'Respond to Reviews';
      availablePermissions['can_contact_customers'] = 'Contact Customers';
      
    } else if (_selectedPermissionRole == 'service_provider') {
      // Service Management
      availablePermissions['can_add_service'] = 'Add New Services';
      availablePermissions['can_edit_service'] = 'Edit Services';
      availablePermissions['can_delete_service'] = 'Delete Services';
      availablePermissions['can_upload_service_images'] = 'Upload Service Images';
      availablePermissions['can_set_service_pricing'] = 'Set Service Pricing';
      availablePermissions['can_set_service_area'] = 'Set Service Area/Location';
      
      // Service Request Management
      availablePermissions['can_view_requests'] = 'View Service Requests';
      availablePermissions['can_accept_requests'] = 'Accept Service Requests';
      availablePermissions['can_reject_requests'] = 'Reject Service Requests';
      availablePermissions['can_update_service_status'] = 'Update Service Status';
      availablePermissions['can_complete_service'] = 'Mark Service as Completed';
      availablePermissions['can_cancel_service'] = 'Cancel Service';
      
      // Schedule & Availability
      availablePermissions['can_manage_schedule'] = 'Manage Work Schedule';
      availablePermissions['can_set_availability'] = 'Set Availability Status';
      
      // Analytics & Customer
      availablePermissions['can_view_service_analytics'] = 'View Service Analytics';
      availablePermissions['can_view_ratings'] = 'View Customer Ratings';
      availablePermissions['can_respond_ratings'] = 'Respond to Ratings';
      availablePermissions['can_view_earnings'] = 'View Earnings';
      
    } else if (_selectedPermissionRole == 'delivery_partner') {
      // Delivery Management
      availablePermissions['can_view_deliveries'] = 'View Assigned Deliveries';
      availablePermissions['can_accept_delivery'] = 'Accept Delivery Requests';
      availablePermissions['can_reject_delivery'] = 'Reject Delivery Requests';
      
      // Status Updates
      availablePermissions['can_mark_picked'] = 'Mark as Picked Up';
      availablePermissions['can_mark_in_transit'] = 'Mark as In Transit';
      availablePermissions['can_mark_delivered'] = 'Mark as Delivered';
      availablePermissions['can_update_location'] = 'Update Current Location';
      
      // Order & Customer
      availablePermissions['can_view_order_details'] = 'View Order Details';
      availablePermissions['can_contact_customer'] = 'Contact Customer';
      availablePermissions['can_contact_seller'] = 'Contact Seller';
      availablePermissions['can_report_issue'] = 'Report Delivery Issues';
      
      // Availability & Earnings
      availablePermissions['can_set_availability'] = 'Set Availability Status';
      availablePermissions['can_view_delivery_history'] = 'View Delivery History';
      availablePermissions['can_view_earnings'] = 'View Earnings';
      availablePermissions['can_view_analytics'] = 'View Delivery Analytics';
      
    } else if (_selectedPermissionRole == 'administrator') {
      availablePermissions['can_manage_products'] = 'Manage Products';
      availablePermissions['can_manage_categories'] = 'Manage Categories';
      availablePermissions['can_manage_orders'] = 'Manage Orders';
      availablePermissions['can_manage_users'] = 'Manage Users';
      availablePermissions['can_manage_gifts'] = 'Manage Gifts';
      availablePermissions['can_manage_services'] = 'Manage Services';
      availablePermissions['can_manage_partners'] = 'Manage Partner Requests';
      availablePermissions['can_manage_deliveries'] = 'Manage Delivery Partners';
      availablePermissions['can_manage_core_staff'] = 'Manage Core Staff';
      availablePermissions['can_manage_featured'] = 'Manage Featured Sections';
      availablePermissions['can_view_dashboard'] = 'View Dashboard';
      availablePermissions['can_manage_permissions'] = 'Manage Permissions';
    }

    final Map<String, bool> tempPermissions = {};
    availablePermissions.forEach((key, _) {
      tempPermissions[key] = currentPermissions[key] != false;
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Permissions for ${userData['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availablePermissions.entries.map((entry) {
                return SwitchListTile(
                  title: Text(entry.value),
                  value: tempPermissions[entry.key] ?? true,
                  onChanged: (val) {
                    setState(() {
                      tempPermissions[entry.key] = val;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({'permissions': tempPermissions});

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permissions updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _editPartner(
    String partnerId,
    String name,
    String email,
    String phone,
    String? servicePincode,
  ) {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone);
    final pincodeController = TextEditingController(text: servicePincode ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Delivery Partner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: pincodeController,
                decoration: const InputDecoration(labelText: 'Service Pincode'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('delivery_partners')
                    .doc(partnerId)
                    .update({
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'service_pincode': pincodeController.text.trim(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Partner updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePartner(String partnerId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery Partner'),
        content: Text('Are you sure you want to delete $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('delivery_partners')
            .doc(partnerId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Partner deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildRoleBasedUsersTab(String role) {
    return RoleManagementTab(
      collection: 'users',
      role: role,
      requestRole: role == 'seller' ? 'Seller' : 'Service Provider',
      onEdit: _editUser,
      onDelete: _deleteUser,
      onRequestAction: _updateRequestStatus,
    );
  }
}

class RoleManagementTab extends StatefulWidget {
  final String collection;
  final String? role;
  final String? requestRole;
  final Function(String, String, String, String, String, String?) onEdit;
  final Function(String, String) onDelete;
  final Function(String, String)? onRequestAction;

  const RoleManagementTab({
    super.key,
    required this.collection,
    this.role,
    this.requestRole,
    required this.onEdit,
    required this.onDelete,
    this.onRequestAction,
  });

  @override
  State<RoleManagementTab> createState() => _RoleManagementTabState();
}

class _RoleManagementTabState extends State<RoleManagementTab> {
  String _searchQuery = '';
  String _selectedStatus = 'All';

  Stream<QuerySnapshot> _getStream() {
    if ((_selectedStatus == 'Requests' || _selectedStatus == 'Rejected') && widget.requestRole != null) {
      return FirebaseFirestore.instance
          .collection('partner_requests')
          .where('role', isEqualTo: widget.requestRole)
          .where('status', isEqualTo: _selectedStatus == 'Requests' ? 'pending' : 'rejected')
          .snapshots();
    } else {
      Query query = FirebaseFirestore.instance.collection(widget.collection);
      if (widget.role != null) {
        query = query.where('role', isEqualTo: widget.role);
      }
      // For delivery_partners, we can filter by status if needed, but 'All' usually means active/approved.
      // If we want 'Approved' filter to specifically show approved partners:
      if (widget.collection == 'delivery_partners' && _selectedStatus != 'All') {
         // If status is 'Approved', we can filter.
         // But if status is 'Pending'/'Rejected' and we are here (requestRole is null?), 
         // then we might be looking at delivery_partners collection's status.
         // However, we assumed requests are in partner_requests.
         // Let's assume delivery_partners collection only has 'approved' or 'active' partners.
         // So 'All' and 'Approved' are same.
      }
      return query.snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by name, email, or phone',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Approved', 'Requests', 'Rejected'].map((status) {
                    final isSelected = _selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedStatus = status);
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.blue[100],
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.blue[900] : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // User List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data?.docs ?? [];

              // Client-side filtering
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                
                // Search Filter
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(q) || email.contains(q) || phone.contains(q);
                }

                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.role == 'seller' ? Icons.store : 
                        widget.role == 'service_provider' ? Icons.handyman :
                        Icons.delivery_dining,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_selectedStatus == 'All' ? '' : _selectedStatus} ${widget.role == 'seller' ? 'Sellers' : widget.role == 'service_provider' ? 'Service Providers' : 'Delivery Partners'} found',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final name = data['name'] ?? 'N/A';
                  final email = data['email'] ?? 'N/A';
                  final phone = data['phone'] ?? 'N/A';
                  final servicePincode = data['service_pincode'] as String?;
                  final createdAt = data['createdAt'] != null
                      ? (data['createdAt'] as Timestamp).toDate()
                      : null;
                  
                  // Determine if it's a request or a user
                  final isRequest = _selectedStatus == 'Requests' || _selectedStatus == 'Rejected';
                  final status = isRequest ? (data['status'] as String? ?? 'pending') : 'approved';

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'approved': statusColor = Colors.green; break;
                    case 'pending': statusColor = Colors.orange; break;
                    case 'rejected': statusColor = Colors.red; break;
                    default: statusColor = Colors.grey;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Icon(
                          widget.role == 'seller' ? Icons.store : 
                          widget.role == 'service_provider' ? Icons.handyman :
                          Icons.delivery_dining,
                          color: statusColor,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(children: [const Icon(Icons.email, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(email)]),
                          const SizedBox(height: 2),
                          Row(children: [const Icon(Icons.phone, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(phone)]),
                          if (servicePincode != null)
                             Padding(
                               padding: const EdgeInsets.only(top: 2),
                               child: Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('Pincode: $servicePincode')]),
                             ),
                          if (createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Joined: ${DateFormat('MMM d, yyyy').format(createdAt)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRequest && widget.onRequestAction != null && status == 'pending') ...[
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => widget.onRequestAction!(id, 'approved'),
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => widget.onRequestAction!(id, 'rejected'),
                              tooltip: 'Reject',
                            ),
                          ] else if (!isRequest) ...[
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => widget.onEdit(
                                id,
                                name,
                                email,
                                phone,
                                widget.role ?? '',
                                servicePincode,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => widget.onDelete(id, email),
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
    );
  }
}
