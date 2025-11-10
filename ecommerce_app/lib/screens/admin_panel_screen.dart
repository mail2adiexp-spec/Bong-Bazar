import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/service_category_model.dart';
import '../models/featured_section_model.dart';
import '../models/partner_request_model.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/service_category_provider.dart';
import '../providers/featured_section_provider.dart';
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

  final List<String> _menuTitles = [
    'Products',
    'Categories',
    'Services',
    'Featured Sections',
    'Partner Requests',
    'Users',
  ];

  final List<IconData> _menuIcons = [
    Icons.inventory_2,
    Icons.category,
    Icons.home_repair_service,
    Icons.star,
    Icons.people_outline,
    Icons.person,
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
      print('🔄 Uploading images for product: $productId');
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final List<String> urls = [];

      for (int i = 0; i < 6; i++) {
        if (imageBytes[i] == null && imageFiles[i] == null) continue;

        try {
          print('📤 Uploading image $i...');
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
            print('✅ Image $i uploaded');
          }
        } catch (e) {
          print('❌ Failed to upload image $i: $e');
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
      print('🔄 Uploading images for product: $productId');
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
            print('📤 Uploading image $i...');
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
              print('✅ Image $i uploaded');
            }
          } catch (e) {
            print('❌ Failed to upload image $i: $e');
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
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Menu Items
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _menuTitles.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedIndex == index;
                          final isPartnerRequestsTab =
                              index == 4; // Partner Requests is at index 4
                          final showBadge =
                              isPartnerRequestsTab && pendingCount > 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Material(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _menuIcons[index],
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          _menuTitles[index],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      if (showBadge) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            pendingCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
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
                // Footer - Back button
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
                          vertical: 16,
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
                                fontSize: 16,
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
          // Right Content Area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildProductsTab(productProvider, products),
                _buildCategoriesTab(),
                _buildServiceCategoriesTab(isAdmin: isAdmin),
                _buildFeaturedSectionsTab(isAdmin: isAdmin),
                _buildPartnerRequestsTab(),
                _buildUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(
    ProductProvider productProvider,
    List<Product> products,
  ) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
          ),
          child: const Column(
            children: [
              Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text(
                'Product Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

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
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.category, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Category Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Category count and Add button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Categories: ${categories.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
        print('🔄 Uploading category image for: $categoryId');
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
        print('✅ Category image uploaded: $url');
        return url;
      } catch (e) {
        print('🔴 Error uploading category image: $e');
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
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.home_repair_service,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Service Categories Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  const Text(
                    'Featured Sections',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  // Partner Requests Tab
  Widget _buildPartnerRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partner_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No partner requests yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final request = PartnerRequest.fromMap(
              doc.data() as Map<String, dynamic>,
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundImage: request.profilePicUrl != null
                      ? NetworkImage(request.profilePicUrl!)
                      : null,
                  child: request.profilePicUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  request.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${request.role} • ${request.status}'),
                trailing: _getStatusChip(request.status),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Phone', request.phone),
                        _buildInfoRow('Email', request.email),
                        _buildInfoRow('Gender', request.gender),
                        _buildInfoRow('District', request.district),
                        _buildInfoRow('PIN Code', request.pincode),
                        _buildInfoRow('Business Name', request.businessName),
                        _buildInfoRow('PAN', request.panNumber),
                        _buildInfoRow('Aadhaar', request.aadhaarNumber),
                        _buildInfoRow(
                          'Min Charge',
                          '₹${request.minCharge.toStringAsFixed(0)}',
                        ),
                        _buildInfoRow(
                          'Submitted',
                          _formatDate(request.createdAt),
                        ),
                        const SizedBox(height: 16),
                        if (request.status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateRequestStatus(
                                    request.id,
                                    'approved',
                                  ),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateRequestStatus(
                                    request.id,
                                    'rejected',
                                  ),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Reject'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        // Edit and Delete buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _editPartnerRequest(request),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _deletePartnerRequest(request.id),
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
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
          Expanded(child: Text(value)),
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

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];

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
                      : Colors.green,
                  child: Icon(
                    role == 'admin'
                        ? Icons.admin_panel_settings
                        : role == 'seller'
                        ? Icons.store
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
                        if (createdAt != null)
                          _buildInfoRow('Joined', _formatDate(createdAt)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _editUser(userId, name, email, phone, role),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _changeUserRole(userId, role),
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Change Role'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteUser(userId, email),
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
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
    );
  }

  void _editUser(
    String userId,
    String name,
    String email,
    String phone,
    String role,
  ) {
    final nameCtrl = TextEditingController(text: name);
    final phoneCtrl = TextEditingController(text: phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(text: email),
                decoration: const InputDecoration(
                  labelText: 'Email (Read Only)',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
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
                    .collection('users')
                    .doc(userId)
                    .update({'name': nameCtrl.text, 'phone': phoneCtrl.text});

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User updated successfully'),
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

  void _changeUserRole(String userId, String currentRole) {
    // Normalize legacy 'admin' to 'administrator'
    String? selectedRole = currentRole == 'admin'
        ? 'administrator'
        : currentRole;

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
}
