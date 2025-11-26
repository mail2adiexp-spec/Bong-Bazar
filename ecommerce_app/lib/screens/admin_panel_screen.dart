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
import 'package:printing/printing.dart';

import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/service_category_model.dart';
import '../models/featured_section_model.dart';
import '../models/partner_request_model.dart';
import '../models/gift_model.dart';
import '../models/delivery_partner_model.dart';
import '../models/payout_model.dart';
import '../services/payout_service.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/service_category_provider.dart';
import '../providers/featured_section_provider.dart';
import '../providers/gift_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/invoice_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/role_management_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  static const routeName = '/admin-panel';
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, pending, approved, rejected
  
  // Search and Filter State
  String _productSearchQuery = '';
  String? _selectedProductCategory;
  String _serviceSearchQuery = '';
  String? _selectedServiceCategory;
  String _selectedServiceAvailability = 'All';
  
  int _selectedIndex = 0;
  
  // Bulk Operations State
  Set<String> _selectedProductIds = {};
  Set<String> _selectedServiceIds = {};
  bool _isProductSelectionMode = false;
  bool _isServiceSelectionMode = false;
  
  // Advanced Product Filters
  double? _minProductPrice;
  double? _maxProductPrice;
  String _stockFilter = 'All'; // All, Low, Out, InStock
  Set<String> _selectedProductCategories = {};
  String _featuredFilter = 'All'; // All, Featured, NonFeatured
  DateTime? _productStartDate;
  DateTime? _productEndDate;
  
  
  // Advanced Service Filters
  double? _minServicePrice;
  double? _maxServicePrice;
  Set<String> _selectedServiceCategories = {};
  String _pricingModelFilter = 'All'; // All, fixed, range, hourly
  DateTime? _serviceStartDate;
  DateTime? _serviceEndDate;

  final List<String> _menuTitles = [
    'Dashboard',           // First
    'Users',              // 5
    'Gifts',              // 5
    'Orders',             // 6
    'Sellers',            // 7
    'Products',           // 8
    'Services',           // 8
    'Categories',         // 10
    'Core Staff',         // 10
    'Permissions',        // 11
    'Payout Requests',    // 15
    'Featured Sections',  // 17
    'Delivery Partners',  // 17
    'Service Categories', // 18
    'Service Providers',  // 18
  ];

  final Map<int, int> _sortedToOriginalIndex = {
    0: 0,  // Dashboard
    1: 6,  // Users
    2: 7,  // Gifts
    3: 8,  // Orders
    4: 11, // Sellers
    5: 1,  // Products
    6: 3,  // Services
    7: 2,  // Categories
    8: 9,  // Core Staff
    9: 10, // Permissions
    10: 13, // Payout Requests
    11: 4,  // Featured Sections
    12: 5,  // Delivery Partners
    13: 14, // Service Categories
    14: 12, // Service Providers
  };

  final List<IconData> _menuIcons = [
    Icons.dashboard,           // Dashboard
    Icons.person,              // Users
    Icons.card_giftcard,       // Gifts
    Icons.receipt_long,        // Orders
    Icons.store,               // Sellers
    Icons.inventory_2,         // Products
    Icons.home_repair_service, // Services
    Icons.category,            // Categories
    Icons.group,               // Core Staff
    Icons.security,            // Permissions
    Icons.payment,             // Payout Requests
    Icons.star,                // Featured Sections
    Icons.delivery_dining,     // Delivery Partners
    Icons.miscellaneous_services, // Service Categories
    Icons.handyman,            // Service Providers
  ];

  @override
  Widget build(BuildContext context) {
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
                        _buildProductsTab(), // 1
                        _buildCategoriesTab(), // 2
                        _buildServicesTab(), // 3
                        _buildFeaturedSectionsTab(isAdmin: isAdmin), // 4
                        _buildDeliveryPartnersTab(), // 5
                        _buildUsersTab(), // 6
                        _buildGiftsTab(), // 7
                        _buildOrdersTab(), // 8
                        _buildCoreStaffTab(), // 9
                        _buildPermissionsTab(), // 10
                        _buildRoleBasedUsersTab('seller'), // 11
                        _buildRoleBasedUsersTab('service_provider'), // 12
                        _buildPayoutRequestsTab(), // 13
                        _buildServiceCategoriesTab(isAdmin: isAdmin), // 14
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

  Widget _buildProductsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var products = snapshot.data?.docs ?? [];

        // Filter products
        if (_productSearchQuery.isNotEmpty) {
          products = products.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            return name.contains(_productSearchQuery.toLowerCase());
          }).toList();
        }

        if (_selectedProductCategory != null) {
          products = products.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] == _selectedProductCategory;
          }).toList();
        }
        
        // Advanced Filters
        products = products.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Price Range Filter
          if (_minProductPrice != null) {
            final price = (data['price'] as num?)?.toDouble() ?? 0;
            if (price < _minProductPrice!) return false;
          }
          if (_maxProductPrice != null) {
            final price = (data['price'] as num?)?.toDouble() ?? 0;
            if (price > _maxProductPrice!) return false;
          }
          
          // Stock Filter
          final stock = (data['stock'] as num?)?.toInt() ?? 0;
          if (_stockFilter == 'Low' && stock >= 10) return false;
          if (_stockFilter == 'Out' && stock != 0) return false;
          if (_stockFilter == 'InStock' && stock <= 0) return false;
          
          // Multi-Category Filter
          if (_selectedProductCategories.isNotEmpty) {
            final category = data['category'] as String?;
            if (category == null || !_selectedProductCategories.contains(category)) {
              return false;
            }
          }
          
          // Featured Filter
          final isFeatured = data['isFeatured'] as bool? ?? false;
          if (_featuredFilter == 'Featured' && !isFeatured) return false;
          if (_featuredFilter == 'NonFeatured' && isFeatured) return false;
          
          // Date Range Filter
          if (_productStartDate != null || _productEndDate != null) {
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null) {
              if (_productStartDate != null && createdAt.isBefore(_productStartDate!)) {
                return false;
              }
              if (_productEndDate != null && createdAt.isAfter(_productEndDate!.add(const Duration(days: 1)))) {
                return false;
              }
            }
          }
          
          return true;
        }).toList();

        return Column(
          children: [
            // Header with Search and Add Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Products: ${products.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (!_isProductSelectionMode)
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isProductSelectionMode = true;
                                });
                              },
                              icon: const Icon(Icons.check_box_outlined),
                              label: const Text('Select Mode'),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _showAddProductDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Bulk Operations Toolbar
                  if (_isProductSelectionMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selectedProductIds.length == products.length && products.isNotEmpty,
                            tristate: true,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedProductIds = products.map((p) => p.id).toSet();
                                } else {
                                  _selectedProductIds.clear();
                                }
                              });
                            },
                          ),
                          Text(
                            _selectedProductIds.isEmpty
                                ? 'Select All'
                                : '${_selectedProductIds.length} selected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Bulk Edit',
                            onPressed: _selectedProductIds.isEmpty
                                ? null
                                : () => _showBulkEditProductsDialog(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Bulk Delete',
                            onPressed: _selectedProductIds.isEmpty
                                ? null
                                : () => _bulkDeleteProducts(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Exit Selection Mode',
                            onPressed: () {
                              setState(() {
                                _isProductSelectionMode = false;
                                _selectedProductIds.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Search and Filter Row
                  Row(
                    children: [
                      // Search Bar
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _productSearchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Category Filter
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          value: _selectedProductCategory,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ...ProductCategory.all.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedProductCategory = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Advanced Filters Panel
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 20),
                        const SizedBox(width: 8),
                        const Text('Advanced Filters'),
                        if (_minProductPrice != null || 
                            _maxProductPrice != null ||
                            _stockFilter != 'All' ||
                            _selectedProductCategories.isNotEmpty ||
                            _featuredFilter != 'All') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price Range
                            const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Min Price',
                                      prefixText: '₹',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setState(() => _minProductPrice = double.tryParse(v)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Max Price',
                                      prefixText: '₹',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setState(() => _maxProductPrice = double.tryParse(v)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Stock Filter
                            const Text('Stock Status', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _stockFilter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Low', child: Text('Low Stock (< 10)')),
                                DropdownMenuItem(value: 'Out', child: Text('Out of Stock')),
                                DropdownMenuItem(value: 'InStock', child: Text('In Stock')),
                              ],
                              onChanged: (v) => setState(() => _stockFilter = v!),
                            ),
                            const SizedBox(height: 16),
                            
                            // Multi-Category Filter
                            const Text('Categories (Multi-select)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ProductCategory.all.map((cat) {
                                return FilterChip(
                                  label: Text(cat),
                                  selected: _selectedProductCategories.contains(cat),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedProductCategories.add(cat);
                                      } else {
                                        _selectedProductCategories.remove(cat);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            
                            // Featured Filter
                            const Text('Featured Status', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _featuredFilter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Featured', child: Text('Featured Only')),
                                DropdownMenuItem(value: 'NonFeatured', child: Text('Non-Featured')),
                              ],
                              onChanged: (v) => setState(() => _featuredFilter = v!),
                            ),
                            const SizedBox(height: 16),
                            
                            // Clear All Filters Button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _minProductPrice = null;
                                    _maxProductPrice = null;
                                    _stockFilter = 'All';
                                    _selectedProductCategories.clear();
                                    _featuredFilter = 'All';
                                  });
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Clear All Filters'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Products Grid
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final data = product.data() as Map<String, dynamic>;
                        final images = data['images'] as List<dynamic>? ?? [];
                        final imageUrl = images.isNotEmpty ? images[0] : null;

                        return Stack(
                          children: [
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: _isProductSelectionMode && _selectedProductIds.contains(product.id)
                                    ? const BorderSide(color: Colors.blue, width: 3)
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                onTap: _isProductSelectionMode
                                    ? () {
                                        setState(() {
                                          if (_selectedProductIds.contains(product.id)) {
                                            _selectedProductIds.remove(product.id);
                                          } else {
                                            _selectedProductIds.add(product.id);
                                          }
                                        });
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Image
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: imageUrl != null
                                            ? ClipRRect(
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(12),
                                                  topRight: Radius.circular(12),
                                                ),
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) =>
                                                      const Icon(
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
                                      data['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(data['price'] ?? 0),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          data['isFeatured'] == true
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Stock: ${data['stock'] ?? 0}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _showEditProductDialog(
                                              product.id,
                                              data,
                                            );
                                          },
                                          color: Colors.blue,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Delete Product',
                                                ),
                                                content: Text(
                                                  'Delete "${data['name']}"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection('products')
                                                    .doc(product.id)
                                                    .delete();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Product deleted successfully',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          color: Colors.red,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Checkbox Overlay
                      if (_isProductSelectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Checkbox(
                              value: _selectedProductIds.contains(product.id),
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedProductIds.add(product.id);
                                  } else {
                                    _selectedProductIds.remove(product.id);
                                  }
                                });
                              },
                              shape: const CircleBorder(),
                            ),
                          ),
                        ),
                    ],
                  );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServicesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var services = snapshot.data?.docs ?? [];

        // Filter services
        if (_serviceSearchQuery.isNotEmpty) {
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            return name.contains(_serviceSearchQuery.toLowerCase());
          }).toList();
        }

        if (_selectedServiceCategory != null) {
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] == _selectedServiceCategory;
          }).toList();
        }
        
        if (_selectedServiceAvailability != 'All') {
             final isAvailable = _selectedServiceAvailability == 'Available';
             services = services.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isAvailable'] == isAvailable;
             }).toList();
        }
        
        // Advanced Filters
        services = services.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Price Range Filter
          if (_minServicePrice != null) {
            final price = (data['basePrice'] as num?)?.toDouble() ?? 0;
            if (price < _minServicePrice!) return false;
          }
          if (_maxServicePrice != null) {
            final price = (data['basePrice'] as num?)?.toDouble() ?? 0;
            if (price > _maxServicePrice!) return false;
          }
          
          // Multi-Category Filter
          if (_selectedServiceCategories.isNotEmpty) {
            final category = data['category'] as String?;
            if (category == null || !_selectedServiceCategories.contains(category)) {
              return false;
            }
          }
          
          // Pricing Model Filter
          if (_pricingModelFilter != 'All') {
            final pricingModel = data['pricingModel'] as String?;
            if (pricingModel != _pricingModelFilter) return false;
          }
          
          return true;
        }).toList();

        return Column(
          children: [
             // Header with Search
             Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Services: ${services.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (!_isServiceSelectionMode)
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isServiceSelectionMode = true;
                                });
                              },
                              icon: const Icon(Icons.check_box_outlined),
                              label: const Text('Select Mode'),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showAddServiceDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Bulk Operations Toolbar
                  if (_isServiceSelectionMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selectedServiceIds.length == services.length && services.isNotEmpty,
                            tristate: true,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedServiceIds = services.map((s) => s.id).toSet();
                                } else {
                                  _selectedServiceIds.clear();
                                }
                              });
                            },
                          ),
                          Text(
                            _selectedServiceIds.isEmpty
                                ? 'Select All'
                                : '${_selectedServiceIds.length} selected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Bulk Edit',
                            onPressed: _selectedServiceIds.isEmpty
                                ? null
                                : () => _showBulkEditServicesDialog(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Bulk Delete',
                            onPressed: _selectedServiceIds.isEmpty
                                ? null
                                : () => _bulkDeleteServices(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Exit Selection Mode',
                            onPressed: () {
                              setState(() {
                                _isServiceSelectionMode = false;
                                _selectedServiceIds.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Search and Filter Row
                  Row(
                    children: [
                      // Search Bar
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search services...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _serviceSearchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Category Filter
                      Expanded(
                        flex: 1,
                        child: Consumer<ServiceCategoryProvider>(
                            builder: (context, provider, _) {
                                return DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    hintText: 'Category',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  value: _selectedServiceCategory,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Categories'),
                                    ),
                                    ...provider.serviceCategories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat.name,
                                        child: Text(cat.name),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedServiceCategory = value;
                                    });
                                  },
                                );
                            }
                        ),
                      ),
                       const SizedBox(width: 16),
                      // Availability Filter
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: 'Availability',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          value: _selectedServiceAvailability,
                          items: ['All', 'Available', 'Unavailable'].map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedServiceAvailability = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Advanced Filters Panel
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 20),
                        const SizedBox(width: 8),
                        const Text('Advanced Filters'),
                        if (_minServicePrice != null || 
                            _maxServicePrice != null ||
                            _selectedServiceCategories.isNotEmpty ||
                            _pricingModelFilter != 'All') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price Range
                            const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Min Price',
                                      prefixText: 'â‚¹',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setState(() => _minServicePrice = double.tryParse(v)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Max Price',
                                      prefixText: 'â‚¹',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setState(() => _maxServicePrice = double.tryParse(v)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Pricing Model Filter
                            const Text('Pricing Model', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _pricingModelFilter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'fixed', child: Text('Fixed Price')),
                                DropdownMenuItem(value: 'range', child: Text('Price Range')),
                                DropdownMenuItem(value: 'hourly', child: Text('Hourly Rate')),
                              ],
                              onChanged: (v) => setState(() => _pricingModelFilter = v!),
                            ),
                            const SizedBox(height: 16),
                            
                            // Multi-Category Filter
                            const Text('Categories (Multi-select)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Consumer<ServiceCategoryProvider>(
                              builder: (context, provider, _) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: provider.serviceCategories.map((cat) {
                                    return FilterChip(
                                      label: Text(cat.name),
                                      selected: _selectedServiceCategories.contains(cat.name),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedServiceCategories.add(cat.name);
                                          } else {
                                            _selectedServiceCategories.remove(cat.name);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Clear All Filters Button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _minServicePrice = null;
                                    _maxServicePrice = null;
                                    _selectedServiceCategories.clear();
                                    _pricingModelFilter = 'All';
                                  });
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Clear All Filters'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Services List
            Expanded(
              child: services.isEmpty
                  ? const Center(child: Text('No services found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final service = services[index];
                        final data = service.data() as Map<String, dynamic>;
                        
                        return Stack(
                          children: [
                            Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: _isServiceSelectionMode && _selectedServiceIds.contains(service.id)
                                    ? const BorderSide(color: Colors.green, width: 3)
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                onTap: _isServiceSelectionMode
                                    ? () {
                                        setState(() {
                                          if (_selectedServiceIds.contains(service.id)) {
                                            _selectedServiceIds.remove(service.id);
                                          } else {
                                            _selectedServiceIds.add(service.id);
                                          }
                                        });
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: data['imageUrl'] != null 
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                  data['imageUrl'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c,e,s) => const Icon(Icons.home_repair_service),
                                              ),
                                          )
                                          : const Icon(Icons.home_repair_service),
                                  ),
                                  title: Text(
                                      data['name'] ?? 'Unknown Service',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          const SizedBox(height: 4),
                                          Text('${data['category']} â€¢ ${data['pricingModel']}'),
                                          const SizedBox(height: 4),
                                          Text(
                                              NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(data['basePrice'] ?? 0),
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                              ),
                                          ),
                                      ],
                                  ),
                                  trailing: _isServiceSelectionMode
                                      ? null
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                              IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                  onPressed: () => _showEditServiceDialog(service.id, data),
                                              ),
                                              IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () async {
                                                      final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                              title: const Text('Delete Service'),
                                                              content: Text('Delete "${data['name']}"?'),
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
                                                      
                                                      if (confirm == true) {
                                                          await FirebaseFirestore.instance.collection('services').doc(service.id).delete();
                                                      }
                                                  },
                                              ),
                                          ],
                                      ),
                                ),
                              ),
                            ),
                            // Checkbox Overlay
                            if (_isServiceSelectionMode)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Checkbox(
                                    value: _selectedServiceIds.contains(service.id),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedServiceIds.add(service.id);
                                        } else {
                                          _selectedServiceIds.remove(service.id);
                                        }
                                      });
                                    },
                                    shape: const CircleBorder(),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
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
                            'Total: â‚¹${total.toStringAsFixed(2)}',
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
                                      Text('â‚¹${gift.price.toStringAsFixed(2)}'),
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
                                  Text('Total: â‚¹${total.toStringAsFixed(2)}'),
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
                      labelText: 'Price (â‚¹)',
                      prefixText: 'â‚¹ ',
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
                                  'Base Price: â‚¹${category.basePrice.toStringAsFixed(0)}',
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
                      labelText: 'Base Price (â‚¹) *',
                      hintText: 'Starting price for this service',
                      border: OutlineInputBorder(),
                      prefixText: 'â‚¹ ',
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

  Widget _buildPayoutRequestsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Payout Requests',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PayoutModel>>(
            stream: PayoutService().getAllPayouts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final payouts = snapshot.data ?? [];

              if (payouts.isEmpty) {
                return const Center(child: Text('No payout requests found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payouts.length,
                itemBuilder: (context, index) {
                  final payout = payouts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: payout.status == PayoutStatus.pending
                            ? Colors.orange.withOpacity(0.2)
                            : payout.status == PayoutStatus.approved
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                        child: Icon(
                          payout.status == PayoutStatus.pending
                              ? Icons.pending
                              : payout.status == PayoutStatus.approved
                                  ? Icons.check
                                  : Icons.close,
                          color: payout.status == PayoutStatus.pending
                              ? Colors.orange
                              : payout.status == PayoutStatus.approved
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      title: Text(
                        '₹${payout.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User ID: ${payout.userId}'),
                          Text('Date: ${DateFormat('MMM d, yyyy').format(payout.requestDate)}'),
                          Text('Details: ${payout.paymentDetails}'),
                        ],
                      ),
                      trailing: payout.status == PayoutStatus.pending
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _handlePayoutAction(payout, true),
                                  tooltip: 'Approve',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _handlePayoutAction(payout, false),
                                  tooltip: 'Reject',
                                ),
                              ],
                            )
                          : _getStatusChip(payout.status.name),
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

  Future<void> _handlePayoutAction(PayoutModel payout, bool approve) async {
    try {
      await PayoutService().updatePayoutStatus(
        payout.id,
        approve ? PayoutStatus.approved : PayoutStatus.rejected,
        adminNote: approve ? 'Approved by Admin' : 'Rejected by Admin',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout ${approve ? 'Approved' : 'Rejected'}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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
      onViewDashboard: (id, data) {
        _showDeliveryPartnerDashboard(id, data);
      },
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
          'Are you sure you want to delete this user?\n\nEmail: $email\n\nThis will:\nâ€¢ Delete Firebase Auth account\nâ€¢ Delete Firestore user document\nâ€¢ Delete related partner requests\nâ€¢ Delete from pending_sellers (if exists)\n\nThis action CANNOT be undone!',
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
            content: Text('âœ… Sample users added successfully! Check Permissions tab.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('âŒ Error adding sample users: $e'),
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

  Widget _buildFinancialTab(String userId, String role) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.indigo,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Available Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'â‚¹12,450.00', // Mocked balance
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBalanceAction(Icons.arrow_upward, 'Withdraw'),
                      _buildBalanceAction(Icons.history, 'History'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Payout Stats
          const Text(
            'Payout Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Payouts',
                  'â‚¹45,000',
                  Icons.payments,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  'â‚¹2,450',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Transactions
          const Text(
            'Recent Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index % 2 == 0 ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(
                      index % 2 == 0 ? Icons.arrow_downward : Icons.arrow_upward,
                      color: index % 2 == 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(index % 2 == 0 ? 'Order Payment' : 'Payout Withdrawal'),
                  subtitle: Text('Oct ${20 - index}, 2024'),
                  trailing: Text(
                    index % 2 == 0 ? '+â‚¹1,200' : '-â‚¹5,000',
                    style: TextStyle(
                      color: index % 2 == 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryPartnerDashboard(
    String partnerId,
    Map<String, dynamic> partnerData,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: partnerData['photoURL'] != null
                            ? NetworkImage(partnerData['photoURL'])
                            : null,
                        child: partnerData['photoURL'] == null
                            ? Text(
                                (partnerData['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partnerData['name'] ?? 'Unknown Partner',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Partner ID: $partnerId',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.purple,
                  unselectedLabelColor: Colors.grey,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: 'Profile'),
                    Tab(icon: Icon(Icons.motorcycle), text: 'Vehicle'),
                    Tab(icon: Icon(Icons.account_balance), text: 'Financials'),
                    Tab(icon: Icon(Icons.dashboard), text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Full Name', partnerData['name'] ?? '-'),
                            _buildInfoRow('Email', partnerData['email'] ?? '-'),
                            _buildInfoRow('Phone', partnerData['phone'] ?? '-'),
                            _buildInfoRow('Address', partnerData['address'] ?? '-'),
                            _buildInfoRow('Status', partnerData['status'] ?? '-'),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vehicle Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Vehicle Type', partnerData['vehicleType'] ?? '-'),
                            _buildInfoRow('Vehicle Number', partnerData['vehicleNumber'] ?? '-'),
                          ],
                        ),
                      ),
                      _buildFinancialTab(partnerId, 'delivery_partner'),
                      SingleChildScrollView(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .where('deliveryPartnerId', isEqualTo: partnerId)
                              .snapshots(),
                          builder: (context, orderSnapshot) {
                            final orders = orderSnapshot.data?.docs ?? [];
                            final totalDeliveries = orders.length;
                            
                            final completedDeliveries = orders.where((o) {
                              final d = o.data() as Map<String, dynamic>;
                              return d['status'] == 'delivered';
                            }).length;

                            final pendingDeliveries = orders.where((o) {
                              final d = o.data() as Map<String, dynamic>;
                              return ['shipped', 'out_for_delivery'].contains(d['status']);
                            }).length;

                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              padding: const EdgeInsets.all(16),
                              children: [
                                _buildStatCard(
                                  'Total Deliveries',
                                  totalDeliveries.toString(),
                                  Icons.local_shipping,
                                  Colors.purple,
                                ),
                                _buildStatCard(
                                  'Completed',
                                  completedDeliveries.toString(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                                _buildStatCard(
                                  'Pending',
                                  pendingDeliveries.toString(),
                                  Icons.pending,
                                  Colors.orange,
                                ),
                                _buildStatCard(
                                  'Earnings',
                                  'â‚¹${(completedDeliveries * 50).toString()}', // Mock calculation: â‚¹50 per delivery
                                  Icons.account_balance_wallet,
                                  Colors.blue,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBasedUsersTab(String role) {
    return RoleManagementTab(
      collection: 'users',
      role: role,
      requestRole: role == 'seller' ? 'Seller' : 'Service Provider',
      onEdit: _editUser,
      onDelete: _deleteUser,
      onRequestAction: _updateRequestStatus,
      onViewDashboard: (id, data) {
        if (role == 'seller') {
          _showSellerDashboard(id, data);
        } else if (role == 'service_provider') {
          _showServiceProviderDashboard(id, data);
        }
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'packed':
        return Colors.indigo;
      case 'shipped':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSellerOrdersTab(String sellerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final orders = snapshot.data?.docs ?? [];
        final sellerOrders = orders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          return items.any((item) => item['sellerId'] == sellerId);
        }).toList();

        if (sellerOrders.isEmpty) {
          return const Center(child: Text('No orders found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sellerOrders.length,
          itemBuilder: (context, index) {
            final order = sellerOrders[index];
            final data = order.data() as Map<String, dynamic>;
            final address = data['address'] as Map<String, dynamic>? ?? {};
            final addressString = '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text('Order #${order.id.substring(0, 8)}'),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy').format(
                    (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  ),
                ),
                trailing: Chip(
                  label: Text(
                    data['status'] ?? 'Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(data['status']),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Customer Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.content_copy, size: 20),
                                  tooltip: 'Copy Address',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: addressString));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Address copied to clipboard')),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.description, size: 20),
                                  tooltip: 'View Invoice',
                                  onPressed: () => _showInvoiceDialog(data, sellerId),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Name: ${address['name'] ?? 'N/A'}'),
                        Text('Phone: ${address['phone'] ?? 'N/A'}'),
                        Text('Address: $addressString'),
                        const Divider(height: 24),
                        const Text(
                          'Items',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...(data['items'] as List<dynamic>? ?? [])
                            .where((item) => item['sellerId'] == sellerId)
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item['name']} x${item['quantity']}'),
                                      Text('â‚¹${item['price']}'),
                                    ],
                                  ),
                                ))
                            .toList(),
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

  Future<void> _showInvoiceDialog(
    Map<String, dynamic> orderData,
    String sellerId,
  ) async {
    // Fetch seller data
    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .get();
    final sellerData = sellerDoc.data() ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Generation'),
        content: const Text('Invoice generation feature is temporarily unavailable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSellerDashboard(String sellerId, Map<String, dynamic> sellerData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: sellerData['photoURL'] != null
                            ? NetworkImage(sellerData['photoURL'])
                            : null,
                        child: sellerData['photoURL'] == null
                            ? Text(
                                (sellerData['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerData['name'] ?? 'Unknown Seller',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Seller ID: $sellerId',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: 'Profile'),
                    Tab(icon: Icon(Icons.store), text: 'Products'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
                    Tab(icon: Icon(Icons.account_balance), text: 'Financials'),
                    Tab(icon: Icon(Icons.dashboard), text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Full Name', sellerData['name'] ?? '-'),
                            _buildInfoRow('Email', sellerData['email'] ?? '-'),
                            _buildInfoRow('Phone', sellerData['phone'] ?? '-'),
                          ],
                        ),
                      ),
                      _buildSellerProductsTab(sellerId),
                      _buildSellerOrdersTab(sellerId),
                      _buildFinancialTab(sellerId, 'seller'),
                      SingleChildScrollView(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('products')
                              .where('sellerId', isEqualTo: sellerId)
                              .snapshots(),
                          builder: (context, productSnapshot) {
                            final productCount =
                                productSnapshot.data?.docs.length ?? 0;

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('orders')
                                  .snapshots(),
                              builder: (context, orderSnapshot) {
                                final orders = orderSnapshot.data?.docs ?? [];
                                final sellerOrders = orders.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final items =
                                      data['items'] as List<dynamic>? ?? [];
                                  return items.any(
                                      (item) => item['sellerId'] == sellerId);
                                }).toList();

                                final orderCount = sellerOrders.length;

                                double totalRevenue = 0;
                                for (var order in sellerOrders) {
                                  final data =
                                      order.data() as Map<String, dynamic>;
                                  final items =
                                      data['items'] as List<dynamic>? ?? [];
                                  for (var item in items) {
                                    if (item['sellerId'] == sellerId) {
                                      totalRevenue += (item['price'] ?? 0) *
                                          (item['quantity'] ?? 1);
                                    }
                                  }
                                }

                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    _buildStatCard(
                                      'Total Products',
                                      productCount.toString(),
                                      Icons.inventory_2,
                                      Colors.blue,
                                    ),
                                    _buildStatCard(
                                      'Total Orders',
                                      orderCount.toString(),
                                      Icons.shopping_bag,
                                      Colors.orange,
                                    ),
                                    _buildStatCard(
                                      'Total Revenue',
                                      'â‚¹${totalRevenue.toStringAsFixed(0)}',
                                      Icons.currency_rupee,
                                      Colors.green,
                                    ),
                                    _buildStatCard(
                                      'Pending Orders',
                                      sellerOrders.where((o) {
                                        final d =
                                            o.data() as Map<String, dynamic>;
                                        return d['status'] == 'pending';
                                      }).length.toString(),
                                      Icons.pending_actions,
                                      Colors.red,
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServiceProviderDashboard(
    String providerId,
    Map<String, dynamic> providerData,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: providerData['photoURL'] != null
                            ? NetworkImage(providerData['photoURL'])
                            : null,
                        child: providerData['photoURL'] == null
                            ? Text(
                                (providerData['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              providerData['name'] ?? 'Unknown Provider',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Provider ID: $providerId',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: 'Profile'),
                    Tab(icon: Icon(Icons.handyman), text: 'Services'),
                    Tab(icon: Icon(Icons.account_balance), text: 'Financials'),
                    Tab(icon: Icon(Icons.dashboard), text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoRow('Full Name', providerData['name'] ?? '-'),
                            _buildInfoRow('Email', providerData['email'] ?? '-'),
                            _buildInfoRow('Phone', providerData['phone'] ?? '-'),
                          ],
                        ),
                      ),
                      const Center(child: Text('Services coming soon')),
                      _buildFinancialTab(providerId, 'service_provider'),
                      SingleChildScrollView(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('services')
                              .where('providerId', isEqualTo: providerId)
                              .snapshots(),
                          builder: (context, serviceSnapshot) {
                            final serviceCount =
                                serviceSnapshot.data?.docs.length ?? 0;

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('service_requests')
                                  .where('providerId', isEqualTo: providerId)
                                  .snapshots(),
                              builder: (context, requestSnapshot) {
                                final requestCount =
                                    requestSnapshot.data?.docs.length ?? 0;
                                final requests =
                                    requestSnapshot.data?.docs ?? [];

                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    _buildStatCard(
                                      'Total Services',
                                      serviceCount.toString(),
                                      Icons.handyman,
                                      Colors.orange,
                                    ),
                                    _buildStatCard(
                                      'Total Requests',
                                      requestCount.toString(),
                                      Icons.assignment,
                                      Colors.blue,
                                    ),
                                    _buildStatCard(
                                      'Pending Requests',
                                      requests.where((r) {
                                        final d =
                                            r.data() as Map<String, dynamic>;
                                        return d['status'] == 'pending';
                                      }).length.toString(),
                                      Icons.pending_actions,
                                      Colors.red,
                                    ),
                                    _buildStatCard(
                                      'Completed Requests',
                                      requests.where((r) {
                                        final d =
                                            r.data() as Map<String, dynamic>;
                                        return d['status'] == 'completed';
                                      }).length.toString(),
                                      Icons.task_alt,
                                      Colors.green,
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderServicesTab(String providerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: providerId)
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handyman, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No services yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Services will appear here once added',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Services: ${services.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Services List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  final data = service.data() as Map<String, dynamic>;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Service Image
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: data['imageUrl'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      data['imageUrl'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.handyman,
                                        size: 30,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.handyman, size: 30),
                          ),
                          const SizedBox(width: 12),
                          // Service Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['name'] ?? 'Unknown Service',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: data['isAvailable'] == true
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        data['isAvailable'] == true
                                            ? 'Available'
                                            : 'Unavailable',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Category: ${data['category'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'â‚¹${data['basePrice'] ?? 0} ${data['pricingModel'] == 'range' ? '- â‚¹${data['maxPrice'] ?? 0}' : ''}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (data['description'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    data['description'],
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Actions
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  _showEditServiceDialog(service.id, data);
                                },
                                color: Colors.blue,
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Service'),
                                      content: Text(
                                        'Delete "${data['name']}"?',
                                      ),
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
                                      await FirebaseFirestore.instance
                                          .collection('services')
                                          .doc(service.id)
                                          .delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Service deleted successfully',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                color: Colors.red,
                                visualDensity: VisualDensity.compact,
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

  Widget _buildSellerProductsTab(String sellerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final products = snapshot.data?.docs ?? [];

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No products yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Product'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with Add Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Products: ${products.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Products Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final data = product.data() as Map<String, dynamic>;
                  final images = data['images'] as List<dynamic>? ?? [];
                  final imageUrl = images.isNotEmpty ? images[0] : null;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: imageUrl != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
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
                                data['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'â‚¹${data['price'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    data['isFeatured'] == true
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Stock: ${data['stock'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () {
                                      _showEditProductDialog(product.id, data);
                                    },
                                    color: Colors.blue,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Product'),
                                          content: Text(
                                            'Delete "${data['name']}"?',
                                          ),
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
                                          await FirebaseFirestore.instance
                                              .collection('products')
                                              .doc(product.id)
                                              .delete();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Product deleted successfully',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    color: Colors.red,
                                    visualDensity: VisualDensity.compact,
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
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditProductDialog(String productId, Map<String, dynamic> productData) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: productData['name']);
    final descCtrl = TextEditingController(text: productData['description']);
    final priceCtrl = TextEditingController(text: productData['price'].toString());
    final stockCtrl = TextEditingController(text: productData['stock'].toString());
    
    String selectedCategory = productData['category'] ?? ProductCategory.dailyNeeds;
    String selectedUnit = productData['unit'] ?? 'Pic';
    bool isFeatured = productData['isFeatured'] ?? false;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Product',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Product Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price and Stock
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixText: 'â‚¹',
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
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
                            items: ProductCategory.all.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (val) => setState(() => selectedCategory = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedUnit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Featured Toggle
                    SwitchListTile(
                      title: const Text('Featured Product'),
                      value: isFeatured,
                      onChanged: (val) => setState(() => isFeatured = val),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('products')
                                        .doc(productId)
                                        .update({
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'price': double.parse(priceCtrl.text),
                                      'stock': int.parse(stockCtrl.text),
                                      'category': selectedCategory,
                                      'unit': selectedUnit,
                                      'isFeatured': isFeatured,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Product updated successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditServiceDialog(String serviceId, Map<String, dynamic> serviceData) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: serviceData['name']);
    final descCtrl = TextEditingController(text: serviceData['description']);
    final basePriceCtrl = TextEditingController(text: serviceData['basePrice'].toString());
    final maxPriceCtrl = TextEditingController(
      text: serviceData['maxPrice']?.toString() ?? '',
    );
    
    String selectedCategory = serviceData['category'] ?? 'Cleaning';
    String pricingModel = serviceData['pricingModel'] ?? 'fixed';
    bool isAvailable = serviceData['isAvailable'] ?? true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Service',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Service Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Pricing Model and Category
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: pricingModel,
                            decoration: const InputDecoration(
                              labelText: 'Pricing Model',
                              border: OutlineInputBorder(),
                            ),
                            items: ['fixed', 'range', 'hourly']
                                .map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase())))
                                .toList(),
                            onChanged: (val) => setState(() => pricingModel = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 'Other']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedCategory = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Base Price and Max Price (conditional)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: basePriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Base Price *',
                              border: OutlineInputBorder(),
                              prefixText: 'â‚¹',
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
                        if (pricingModel == 'range') ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: maxPriceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Price',
                                border: OutlineInputBorder(),
                                prefixText: 'â‚¹',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Available Toggle
                    SwitchListTile(
                      title: const Text('Service Available'),
                      value: isAvailable,
                      onChanged: (val) => setState(() => isAvailable = val),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    final updateData = {
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'basePrice': double.parse(basePriceCtrl.text),
                                      'category': selectedCategory,
                                      'pricingModel': pricingModel,
                                      'isAvailable': isAvailable,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    
                                    if (pricingModel == 'range' && maxPriceCtrl.text.isNotEmpty) {
                                      updateData['maxPrice'] = double.parse(maxPriceCtrl.text);
                                    }
                                    
                                    await FirebaseFirestore.instance
                                        .collection('services')
                                        .doc(serviceId)
                                        .update(updateData);
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Service updated successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    
    String selectedCategory = ProductCategory.dailyNeeds;
    String selectedUnit = 'Pic';
    bool isFeatured = false;
    bool isLoading = false;
    List<Uint8List> selectedImages = [];
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty && images.length <= 6) {
          final List<Uint8List> imageBytes = [];
          for (var image in images) {
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            selectedImages = imageBytes;
          });
        } else if (images.length > 6) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 6 images allowed')),
            );
          }
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
      List<String> imageUrls = [];
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Product',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Product Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (v!.length < 3) return 'Minimum 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price and Stock
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixText: 'â‚¹',
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
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
                            items: ProductCategory.all.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (val) => setState(() => selectedCategory = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedUnit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Featured Toggle
                    SwitchListTile(
                      title: const Text('Featured Product'),
                      value: isFeatured,
                      onChanged: (val) => setState(() => isFeatured = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Upload
                    OutlinedButton.icon(
                      onPressed: () => pickImages(setState),
                      icon: const Icon(Icons.image),
                      label: Text(selectedImages.isEmpty 
                          ? 'Select Images (Max 6)' 
                          : '${selectedImages.length} image(s) selected'),
                    ),
                    if (selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Image.memory(
                                    selectedImages[index],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          selectedImages.removeAt(index);
                                        });
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(24, 24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    // Create product document
                                    final docRef = await FirebaseFirestore.instance
                                        .collection('products')
                                        .add({
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'price': double.parse(priceCtrl.text),
                                      'stock': int.parse(stockCtrl.text),
                                      'category': selectedCategory,
                                      'unit': selectedUnit,
                                      'isFeatured': isFeatured,
                                      'sellerId': 'admin',
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                    
                                    // Upload images if any
                                    if (selectedImages.isNotEmpty) {
                                      final imageUrls = await uploadImages(docRef.id);
                                      await docRef.update({'images': imageUrls});
                                    }
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Product added successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add Product'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddServiceDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final basePriceCtrl = TextEditingController();
    final maxPriceCtrl = TextEditingController();
    final serviceAreaCtrl = TextEditingController();
    
    String selectedCategory = 'Cleaning';
    String pricingModel = 'fixed';
    bool isAvailable = true;
    bool isLoading = false;
    Uint8List? selectedImage;
    final ImagePicker picker = ImagePicker();

    Future<void> pickImage(StateSetter setState) async {
      try {
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            selectedImage = bytes;
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
    }

    Future<String?> uploadImage(String serviceId) async {
      if (selectedImage == null) return null;
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('services')
            .child(serviceId)
            .child('image.jpg');
        await ref.putData(selectedImage!);
        return await ref.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        return null;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Service',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Service Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (v!.length < 3) return 'Minimum 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Pricing Model and Category
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: pricingModel,
                            decoration: const InputDecoration(
                              labelText: 'Pricing Model',
                              border: OutlineInputBorder(),
                            ),
                            items: ['fixed', 'range', 'hourly']
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text(m.toUpperCase())))
                                .toList(),
                            onChanged: (val) => setState(() => pricingModel = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Consumer<ServiceCategoryProvider>(
                            builder: (context, provider, _) {
                              if (provider.serviceCategories.isEmpty) {
                                return DropdownButtonFormField<String>(
                                  value: selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: ['Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 'Other']
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (val) => setState(() => selectedCategory = val!),
                                );
                              }
                              return DropdownButtonFormField<String>(
                                value: provider.serviceCategories
                                        .any((cat) => cat.name == selectedCategory)
                                    ? selectedCategory
                                    : provider.serviceCategories.first.name,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: provider.serviceCategories
                                    .map((cat) => DropdownMenuItem(
                                        value: cat.name, child: Text(cat.name)))
                                    .toList(),
                                onChanged: (val) => setState(() => selectedCategory = val!),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Base Price and Max Price (conditional)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: basePriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Base Price *',
                              border: OutlineInputBorder(),
                              prefixText: 'â‚¹',
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
                        if (pricingModel == 'range') ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: maxPriceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Price',
                                border: OutlineInputBorder(),
                                prefixText: 'â‚¹',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty == true) return null;
                                final maxPrice = double.tryParse(v!);
                                final basePrice = double.tryParse(basePriceCtrl.text);
                                if (maxPrice != null && basePrice != null && maxPrice <= basePrice) {
                                  return 'Must be > Base Price';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Service Area
                    TextFormField(
                      controller: serviceAreaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Area / Pincode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Available Toggle
                    SwitchListTile(
                      title: const Text('Service Available'),
                      value: isAvailable,
                      onChanged: (val) => setState(() => isAvailable = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Upload
                    OutlinedButton.icon(
                      onPressed: () => pickImage(setState),
                      icon: const Icon(Icons.image),
                      label: Text(selectedImage == null 
                          ? 'Select Image' 
                          : 'Image selected'),
                    ),
                    if (selectedImage != null) ...[
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Image.memory(
                            selectedImage!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  selectedImage = null;
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    final serviceData = {
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'category': selectedCategory,
                                      'pricingModel': pricingModel,
                                      'basePrice': double.parse(basePriceCtrl.text),
                                      'serviceArea': serviceAreaCtrl.text,
                                      'isAvailable': isAvailable,
                                      'providerId': 'admin',
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    
                                    if (pricingModel == 'range' && maxPriceCtrl.text.isNotEmpty) {
                                      serviceData['maxPrice'] = double.parse(maxPriceCtrl.text);
                                    }
                                    
                                    // Create service document
                                    final docRef = await FirebaseFirestore.instance
                                        .collection('services')
                                        .add(serviceData);
                                    
                                    // Upload image if any
                                    if (selectedImage != null) {
                                      final imageUrl = await uploadImage(docRef.id);
                                      if (imageUrl != null) {
                                        await docRef.update({'imageUrl': imageUrl});
                                      }
                                    }
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Service added successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add Service'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bulk Operations Methods
  Future<void> _bulkDeleteProducts() async {
    final count = _selectedProductIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Product${count > 1 ? 's' : ''}?'),
        content: const Text(
          'This action cannot be undone. All selected products will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleting $count product${count > 1 ? 's' : ''}...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Batch delete
        final batch = FirebaseFirestore.instance.batch();
        for (var id in _selectedProductIds) {
          batch.delete(
            FirebaseFirestore.instance.collection('products').doc(id),
          );
        }
        await batch.commit();

        // Clear selection and exit selection mode
        setState(() {
          _selectedProductIds.clear();
          _isProductSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count product${count > 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting products: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBulkEditProductsDialog() {
    final count = _selectedProductIds.length;
    
    // Edit options
    String editType = 'price'; // price, stock, category, featured
    String priceAction = 'add_percent'; // add_percent, subtract_percent, set_fixed
    String stockAction = 'add'; // add, subtract, set
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String? selectedCategory;
    bool? setFeatured;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulk Edit $count Product${count > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Edit Type Selection
                  DropdownButtonFormField<String>(
                    value: editType,
                    decoration: const InputDecoration(
                      labelText: 'What to Edit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'price', child: Text('Price')),
                      DropdownMenuItem(value: 'stock', child: Text('Stock')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'featured', child: Text('Featured Status')),
                    ],
                    onChanged: (val) => setState(() => editType = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price Edit Options
                  if (editType == 'price') ...[
                    DropdownButtonFormField<String>(
                      value: priceAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'add_percent', child: Text('Increase by %')),
                        DropdownMenuItem(value: 'subtract_percent', child: Text('Decrease by %')),
                        DropdownMenuItem(value: 'set_fixed', child: Text('Set to Fixed Value')),
                      ],
                      onChanged: (val) => setState(() => priceAction = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: InputDecoration(
                        labelText: priceAction == 'set_fixed' ? 'New Price' : 'Percentage',
                        border: const OutlineInputBorder(),
                        prefixText: priceAction == 'set_fixed' ? 'â‚¹' : '',
                        suffixText: priceAction != 'set_fixed' ? '%' : '',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  
                  // Stock Edit Options
                  if (editType == 'stock') ...[
                    DropdownButtonFormField<String>(
                      value: stockAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'add', child: Text('Add to Stock')),
                        DropdownMenuItem(value: 'subtract', child: Text('Subtract from Stock')),
                        DropdownMenuItem(value: 'set', child: Text('Set to Value')),
                      ],
                      onChanged: (val) => setState(() => stockAction = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Stock Value',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  
                  // Category Edit
                  if (editType == 'category') ...[
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'New Category',
                        border: OutlineInputBorder(),
                      ),
                      items: ProductCategory.all.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                  ],
                  
                  // Featured Edit
                  if (editType == 'featured') ...[
                    DropdownButtonFormField<bool>(
                      value: setFeatured,
                      decoration: const InputDecoration(
                        labelText: 'Featured Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Set as Featured')),
                        DropdownMenuItem(value: false, child: Text('Remove from Featured')),
                      ],
                      onChanged: (val) => setState(() => setFeatured = val),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          try {
                            final batch = FirebaseFirestore.instance.batch();
                            
                            for (var productId in _selectedProductIds) {
                              final docRef = FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(productId);
                              
                              if (editType == 'price' && priceCtrl.text.isNotEmpty) {
                                final value = double.tryParse(priceCtrl.text);
                                if (value != null) {
                                  if (priceAction == 'set_fixed') {
                                    batch.update(docRef, {'price': value});
                                  } else {
                                    // Get current price
                                    final doc = await docRef.get();
                                    final currentPrice = (doc.data()?['price'] as num?)?.toDouble() ?? 0;
                                    double newPrice;
                                    if (priceAction == 'add_percent') {
                                      newPrice = currentPrice * (1 + value / 100);
                                    } else {
                                      newPrice = currentPrice * (1 - value / 100);
                                    }
                                    batch.update(docRef, {'price': newPrice});
                                  }
                                }
                              } else if (editType == 'stock' && stockCtrl.text.isNotEmpty) {
                                final value = int.tryParse(stockCtrl.text);
                                if (value != null) {
                                  if (stockAction == 'set') {
                                    batch.update(docRef, {'stock': value});
                                  } else {
                                    final doc = await docRef.get();
                                    final currentStock = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
                                    final newStock = stockAction == 'add'
                                        ? currentStock + value
                                        : currentStock - value;
                                    batch.update(docRef, {'stock': newStock.clamp(0, 999999)});
                                  }
                                }
                              } else if (editType == 'category' && selectedCategory != null) {
                                batch.update(docRef, {'category': selectedCategory});
                              } else if (editType == 'featured' && setFeatured != null) {
                                batch.update(docRef, {'isFeatured': setFeatured});
                              }
                            }
                            
                            await batch.commit();
                            
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('$count product${count > 1 ? 's' : ''} updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            
                            this.setState(() {
                              _selectedProductIds.clear();
                              _isProductSelectionMode = false;
                            });
                          } catch (e) {
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bulk Service Operations
  Future<void> _bulkDeleteServices() async {
    final count = _selectedServiceIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Service${count > 1 ? 's' : ''}?'),
        content: const Text(
          'This action cannot be undone. All selected services will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleting $count service${count > 1 ? 's' : ''}...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        final batch = FirebaseFirestore.instance.batch();
        for (var id in _selectedServiceIds) {
          batch.delete(
            FirebaseFirestore.instance.collection('services').doc(id),
          );
        }
        await batch.commit();

        setState(() {
          _selectedServiceIds.clear();
          _isServiceSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count service${count > 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting services: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBulkEditServicesDialog() {
    final count = _selectedServiceIds.length;
    
    String editType = 'price'; // price, category, availability
    String priceAction = 'add_percent';
    final priceCtrl = TextEditingController();
    String? selectedCategory;
    bool? setAvailability;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulk Edit $count Service${count > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Edit Type Selection
                  DropdownButtonFormField<String>(
                    value: editType,
                    decoration: const InputDecoration(
                      labelText: 'What to Edit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'price', child: Text('Base Price')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'availability', child: Text('Availability')),
                    ],
                    onChanged: (val) => setState(() => editType = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price Edit Options
                  if (editType == 'price') ...[
                    DropdownButtonFormField<String>(
                      value: priceAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'add_percent', child: Text('Increase by %')),
                        DropdownMenuItem(value: 'subtract_percent', child: Text('Decrease by %')),
                        DropdownMenuItem(value: 'set_fixed', child: Text('Set to Fixed Value')),
                      ],
                      onChanged: (val) => setState(() => priceAction = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: InputDecoration(
                        labelText: priceAction == 'set_fixed' ? 'New Price' : 'Percentage',
                        border: const OutlineInputBorder(),
                        prefixText: priceAction == 'set_fixed' ? 'â‚¹' : '',
                        suffixText: priceAction != 'set_fixed' ? '%' : '',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  
                  // Category Edit
                  if (editType == 'category') ...[
                    Consumer<ServiceCategoryProvider>(
                      builder: (context, provider, _) {
                        return DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'New Category',
                            border: OutlineInputBorder(),
                          ),
                          items: provider.serviceCategories.map((cat) {
                            return DropdownMenuItem(value: cat.name, child: Text(cat.name));
                          }).toList(),
                          onChanged: (val) => setState(() => selectedCategory = val),
                        );
                      },
                    ),
                  ],
                  
                  // Availability Edit
                  if (editType == 'availability') ...[
                    DropdownButtonFormField<bool>(
                      value: setAvailability,
                      decoration: const InputDecoration(
                        labelText: 'Availability Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Set as Available')),
                        DropdownMenuItem(value: false, child: Text('Set as Unavailable')),
                      ],
                      onChanged: (val) => setState(() => setAvailability = val),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          try {
                            final batch = FirebaseFirestore.instance.batch();
                            
                            for (var serviceId in _selectedServiceIds) {
                              final docRef = FirebaseFirestore.instance
                                  .collection('services')
                                  .doc(serviceId);
                              
                              if (editType == 'price' && priceCtrl.text.isNotEmpty) {
                                final value = double.tryParse(priceCtrl.text);
                                if (value != null) {
                                  if (priceAction == 'set_fixed') {
                                    batch.update(docRef, {'basePrice': value});
                                  } else {
                                    final doc = await docRef.get();
                                    final currentPrice = (doc.data()?['basePrice'] as num?)?.toDouble() ?? 0;
                                    double newPrice;
                                    if (priceAction == 'add_percent') {
                                      newPrice = currentPrice * (1 + value / 100);
                                    } else {
                                      newPrice = currentPrice * (1 - value / 100);
                                    }
                                    batch.update(docRef, {'basePrice': newPrice});
                                  }
                                }
                              } else if (editType == 'category' && selectedCategory != null) {
                                batch.update(docRef, {'category': selectedCategory});
                              } else if (editType == 'availability' && setAvailability != null) {
                                batch.update(docRef, {'isAvailable': setAvailability});
                              }
                            }
                            
                            await batch.commit();
                            
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('$count service${count > 1 ? 's' : ''} updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            
                            this.setState(() {
                              _selectedServiceIds.clear();
                              _isServiceSelectionMode = false;
                            });
                          } catch (e) {
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

