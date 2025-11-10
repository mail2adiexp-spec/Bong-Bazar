import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/currency.dart';
import '../screens/cart_screen.dart';
import '../widgets/more_bottom_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  static const routeName = '/product';

  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  int _currentNavIndex = 0;

  List<String> get _images {
    final imgs = widget.product.imageUrls;
    if (imgs != null && imgs.isNotEmpty) return imgs;
    return [widget.product.imageUrl];
  }

  void _onNavTapped(int index) async {
    if (index == 3) {
      // Show More bottom sheet
      await showMoreBottomSheet(context);
      return;
    }
    // For other tabs, navigate back to home
    if (index != _currentNavIndex) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bong Bazar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: 'product-image-${product.id}',
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _images.length,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemBuilder: (context, index) {
                          return Image.network(
                            _images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(Icons.broken_image, size: 56),
                                ),
                          );
                        },
                      ),
                      if (_images.length > 1)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: _currentIndex == i ? 10 : 6,
                                height: _currentIndex == i ? 10 : 6,
                                decoration: BoxDecoration(
                                  color: _currentIndex == i
                                      ? Colors.white
                                      : Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _formatPriceWithUnit(product),
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(product.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<CartProvider>().addProduct(product);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to cart'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
              ),
            ),
          ],
        ),
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

  String _formatPriceWithUnit(Product p) {
    final price = formatINR(p.price);
    if (p.unit == null || p.unit!.isEmpty) return price;
    return '$price / ${p.unit}';
  }
}
