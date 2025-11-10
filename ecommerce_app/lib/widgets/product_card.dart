import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/product_detail_screen.dart';
import '../utils/currency.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final String? heroTagPrefix;

  const ProductCard({super.key, required this.product, this.heroTagPrefix});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          ProductDetailScreen.routeName,
          arguments: product,
        );
      },
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  topRight: Radius.circular(10.0),
                ),
                child: Hero(
                  tag: '${heroTagPrefix ?? ''}product-image-${product.id}',
                  child: Image.network(
                    (product.imageUrls != null && product.imageUrls!.isNotEmpty)
                        ? product.imageUrls!.first
                        : product.imageUrl,
                    fit: BoxFit.cover,
                    // Basic error handling for images
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _formatPriceWithUnit(product),
                style: TextStyle(fontSize: 14.0, color: Colors.grey[800]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  context.read<CartProvider>().addProduct(product);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} added to cart'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('Add to Cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPriceWithUnit(Product p) {
  final price = formatINR(p.price);
  if (p.unit == null || p.unit!.isEmpty) return price;
  return '$price / ${p.unit}';
}
