class Product {
  final String id;
  final String sellerId;
  final String name;
  final String description;
  final double price;
  final String imageUrl; // Primary image
  final List<String>? imageUrls; // Multiple images (minimum 4)
  final String? category; // Product category
  final String? unit; // Unit: Kg, Ltr, Pic, Pkt, Grm

  Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.imageUrls,
    this.category,
    this.unit,
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'category': category,
      'unit': unit,
    };
  }

  // Create Product from Firestore Map
  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      sellerId: map['sellerId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
      category: map['category'],
      unit: map['unit'],
    );
  }
}

// Product Categories
class ProductCategory {
  static const String snacks = 'Snacks';
  static const String dailyNeeds = 'Daily Needs';
  static const String customerChoice = 'Customer Choice';
  static const String hotDeals = 'Hot Deals';
  static const String gifts = 'Gifts';
  static const String riceAta = 'Rice & Ata';
  static const String cookingOils = 'Cooking Oils';
  static const String fastFood = 'Fast Food';
  static const String coldDrinks = 'Cold Drinks';

  static const List<String> all = [
    snacks,
    dailyNeeds,
    customerChoice,
    hotDeals,
    gifts,
    riceAta,
    cookingOils,
    fastFood,
    coldDrinks,
  ];
}
