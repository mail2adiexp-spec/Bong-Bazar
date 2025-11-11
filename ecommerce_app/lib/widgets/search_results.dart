import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'product_card.dart';

class SearchResults extends StatelessWidget {
  final List<Product> products;
  final VoidCallback onClear;

  const SearchResults({
    super.key,
    required this.products,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear search'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(10.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => ProductCard(product: products[i]),
          childCount: products.length,
        ),
      ),
    );
  }
}
