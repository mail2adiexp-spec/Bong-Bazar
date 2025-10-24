import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Commerce Home'),
        actions: [
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
      body: GridView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: _products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 products per row
          childAspectRatio: 2 / 3, // Adjust for better card shape
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (ctx, i) => ProductCard(product: _products[i]),
      ),
    );
  }
}
