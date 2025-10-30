# E-Commerce App

A Flutter e-commerce app with Firebase integration: realtime product catalog from Firestore, multi-image uploads to Storage via an Admin Panel, and cart/checkout using Provider for state management.

## Features

- Home screen shows realtime products from Firestore
- Category filter chips and search by name/description
- Admin Panel to add products with 4–6 images (uploads to Firebase Storage)
- Product details page with images, description, and INR price
- Add to Cart from product cards or details
- Cart screen with quantity controls (+/−), remove item, and total amount
- Checkout screen with basic address fields and “Place Order” flow (clears cart)

## Tech

- Flutter (Material 3)
- Firebase (Core, Auth, Firestore, Storage)
- Provider for app state (`CartProvider`, `ProductProvider`) with SharedPreferences persistence

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

- `lib/models/product_model.dart` – Product data model (multi-image, categories, unit)
- `lib/providers/cart_provider.dart` – Cart state (items, qty, totals)
- `lib/providers/product_provider.dart` – Firestore realtime products + CRUD
- `lib/widgets/product_card.dart` – Product tile with Add to Cart
- `lib/screens/home_screen.dart` – Product grid and Cart badge
- `lib/screens/product_detail_screen.dart` – Product details and Add to Cart
- `lib/screens/cart_screen.dart` – Cart list, qty controls, total
- `lib/screens/checkout_screen.dart` – Checkout summary and place order
 - `lib/screens/admin_panel_screen.dart` – Admin Panel to add/edit products

## Changelog

- v1.2.1
	- Home wired to Firestore-backed products via ProductProvider
	- Category filter chips and live search on Home
- v1.2.0
	- Admin Panel added with multi-image product upload (min 4 images)
	- Firestore integration for products with categories and units
	- Firebase Storage uploads and rules updates

Feel free to extend this app with real APIs, authentication, payments, and persistence.
