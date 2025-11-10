import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/more_bottom_sheet.dart';

class CategoryProductsScreen extends StatefulWidget {
  static const routeName = '/category-products';

  const CategoryProductsScreen({super.key});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  String? _selectedGiftFilter;
  final int _currentNavIndex = 0;

  // Gift filters
  final List<Map<String, dynamic>> _giftFilters = [
    {'label': 'All Gifts', 'value': null, 'icon': Icons.card_giftcard},
    {'label': 'Birthday', 'value': 'Birthday', 'icon': Icons.cake},
    {'label': 'Anniversary', 'value': 'Anniversary', 'icon': Icons.favorite},
    {'label': 'Wedding', 'value': 'Wedding', 'icon': Icons.celebration},
    {'label': 'Kids', 'value': 'Kids', 'icon': Icons.child_care},
    {'label': 'Corporate', 'value': 'Corporate', 'icon': Icons.business_center},
  ];

  void _onNavTapped(int index) async {
    if (index == 3) {
      // Show More bottom sheet
      await showMoreBottomSheet(context);
      return;
    }
    // For other tabs, just navigate back to home and switch tab
    if (index != _currentNavIndex) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the category name from route arguments
    final categoryName = ModalRoute.of(context)!.settings.arguments as String;
    final isGiftCategory = categoryName == 'Gifts';

    return Scaffold(
      appBar: AppBar(
        // Left: Back button (default)
        // Center: Category name
        title: const Text(
          'Bong Bazar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // Right: Theme toggle + Cart
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.pushNamed(context, CartScreen.routeName);
                },
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
              ),
              Positioned(
                right: 8,
                top: 10,
                child: Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    final count = cart.itemCount;
                    return count > 0
                        ? Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Gift filters (only for Gifts category)
          if (isGiftCategory)
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _giftFilters.length,
                itemBuilder: (ctx, index) {
                  final filter = _giftFilters[index];
                  final isSelected = _selectedGiftFilter == filter['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedGiftFilter = filter['value'] as String?;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            filter['icon'] as IconData,
                            size: 24,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            filter['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // Products grid
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                // Filter products by category
                var categoryProducts = productProvider.products
                    .where((product) => product.category == categoryName)
                    .toList();

                // Apply gift filter if selected
                if (isGiftCategory && _selectedGiftFilter != null) {
                  categoryProducts = categoryProducts
                      .where(
                        (product) =>
                            product.description.toLowerCase().contains(
                              _selectedGiftFilter!.toLowerCase(),
                            ) ||
                            product.name.toLowerCase().contains(
                              _selectedGiftFilter!.toLowerCase(),
                            ),
                      )
                      .toList();
                }

                if (productProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (categoryProducts.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
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
                            'No products in this category',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categoryProducts.length,
                  itemBuilder: (ctx, index) {
                    final product = categoryProducts[index];
                    return ProductCard(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.design_services_outlined),
            activeIcon: Icon(Icons.design_services),
            label: 'SERVICES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_page_outlined),
            activeIcon: Icon(Icons.contact_page),
            label: 'CONTACT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.menu),
            label: 'MORE',
          ),
        ],
      ),
    );
  }
}
