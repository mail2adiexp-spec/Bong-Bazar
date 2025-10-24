# E-Commerce App

A simple Flutter e-commerce demo showcasing a product catalog, product details, cart management, and checkout flow using Provider for state management.

## Features

- Product grid on Home screen with sample products
- Product details page with image, description, and price
- Add to Cart from product cards or details
- Cart screen with quantity controls (+/−), remove item, and total amount
- Checkout screen with basic address fields and “Place Order” flow (clears cart)

## Tech

- Flutter (Material 3)
- Provider for app state (`CartProvider`) with SharedPreferences persistence

## Run locally

1. Install Flutter SDK and set it on your PATH.
2. From the project folder run:

```powershell
flutter pub get
flutter run
```

To run tests:

```powershell
flutter test
```

If you see a Flutter SDK not found error on Windows, add Flutter to PATH (Control Panel → System → Advanced System Settings → Environment Variables) and restart your terminal.

## Project structure

- `lib/models/product_model.dart` – Product data model
- `lib/providers/cart_provider.dart` – Cart state (items, qty, totals)
- `lib/widgets/product_card.dart` – Product tile with Add to Cart
- `lib/screens/home_screen.dart` – Product grid and Cart badge
- `lib/screens/product_detail_screen.dart` – Product details and Add to Cart
- `lib/screens/cart_screen.dart` – Cart list, qty controls, total
- `lib/screens/checkout_screen.dart` – Checkout summary and place order

Feel free to extend this app with real APIs, authentication, payments, and persistence.
