import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../utils/currency.dart';

class ProductDetailScreen extends StatelessWidget {
  static const routeName = '/product';

  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
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
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image, size: 56)),
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
              formatINR(product.price),
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
    );
  }
}
