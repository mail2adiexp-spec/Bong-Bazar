import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Sample product data
  final List<Product> _products = [
    Product(
      id: 'p1',
      name: 'Laptop',
      description: 'A high-end gaming laptop.',
      price: 1200.00,
      imageUrl: 'https://picsum.photos/seed/p1/400/300',
    ),
    Product(
      id: 'p2',
      name: 'Smartphone',
      description: 'A latest model smartphone.',
      price: 800.00,
      imageUrl: 'https://picsum.photos/seed/p2/400/300',
    ),
    Product(
      id: 'p3',
      name: 'Headphones',
      description: 'Noise-cancelling headphones.',
      price: 150.00,
      imageUrl: 'https://picsum.photos/seed/p3/400/300',
    ),
    Product(
      id: 'p4',
      name: 'Keyboard',
      description: 'A mechanical keyboard.',
      price: 90.00,
      imageUrl: 'https://picsum.photos/seed/p4/400/300',
    ),
    Product(
      id: 'p5',
      name: 'Mouse',
      description: 'A wireless gaming mouse.',
      price: 60.00,
      imageUrl: 'https://picsum.photos/seed/p5/400/300',
    ),
    Product(
      id: 'p6',
      name: 'Monitor',
      description: 'A 27-inch 4K monitor.',
      price: 450.00,
      imageUrl: 'https://picsum.photos/seed/p6/400/300',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredProducts = () {
      final query = _searchController.text;
      if (query.isEmpty) {
        return _products;
      }
      return _products.where((product) {
        final lowerQuery = query.toLowerCase();
        return product.name.toLowerCase().contains(lowerQuery) ||
            product.description.toLowerCase().contains(lowerQuery);
      }).toList();
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Commerce Home'),
        // AppBar actions with profile icon and cart
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              return IconButton(
                tooltip: user != null ? 'Account (${user.name})' : 'Sign In',
                onPressed: () =>
                    Navigator.pushNamed(context, AccountScreen.routeName),
                icon: user?.photoURL != null
                    ? CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(user!.photoURL!),
                        // Force rebuild on URL change
                        key: ValueKey(user.photoURL),
                        backgroundColor: Colors.grey[200],
                      )
                    : const Icon(Icons.person),
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
              ),
              Positioned(
                right: 8,
                top: 10,
                child: Consumer<CartProvider>(
                  builder: (_, cart, __) => cart.itemCount == 0
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cart.itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          TextButton(
                            onPressed: () => _searchController.clear(),
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10.0),
                    itemCount: filteredProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemBuilder: (ctx, i) =>
                        ProductCard(product: filteredProducts[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
