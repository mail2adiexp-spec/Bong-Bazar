import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/screens/home_screen.dart';
import 'package:ecommerce_app/screens/cart_screen.dart';
import 'package:ecommerce_app/screens/checkout_screen.dart';
import 'package:ecommerce_app/screens/product_detail_screen.dart';
import 'package:ecommerce_app/screens/auth_screen.dart';
import 'package:ecommerce_app/screens/account_screen.dart';
import 'package:ecommerce_app/models/product_model.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'E-Commerce App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          CartScreen.routeName: (_) => const CartScreen(),
          CheckoutScreen.routeName: (_) => const CheckoutScreen(),
          AuthScreen.routeName: (ctx) => const AuthScreen(),
          AccountScreen.routeName: (ctx) => const AccountScreen(),
        },
        // For routes needing arguments
        onGenerateRoute: (settings) {
          if (settings.name == ProductDetailScreen.routeName) {
            final product = settings.arguments as Product;
            return MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            );
          }
          return null;
        },
      ),
    );
  }
}
