import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../utils/currency.dart';

class CheckoutScreen extends StatelessWidget {
  static const routeName = '/checkout';

  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, __) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Items: ${cart.itemCount}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: ${formatINR(cart.totalAmount)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Shipping Address',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Full Name',
                ),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Address Line',
                ),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'City',
                ),
              ),
              const SizedBox(height: 8),
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Postal Code',
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cart.isEmpty
                      ? null
                      : () async {
                          // Simulate placing order
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Order Placed'),
                              content: const Text(
                                'Thank you for your purchase!',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          cart.clear();
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                  child: const Text('Place Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
