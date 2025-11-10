import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/service_category_provider.dart';
import '../models/service_category_model.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'book_service_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  ServiceCategory? _selectedCategory;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Left: User icon
        leading: Consumer<AuthProvider>(
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
                      key: ValueKey(user.photoURL),
                      backgroundColor: Colors.grey[200],
                    )
                  : const Icon(Icons.person),
            );
          },
        ),
        // Center: App name
        title: const Text(
          'Bong Bazar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // Right: Theme toggle + Cart
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search for services...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: Consumer<ServiceCategoryProvider>(
              builder: (context, serviceCategoryProvider, _) {
                final serviceCategories =
                    serviceCategoryProvider.serviceCategories;
                final isLoading = serviceCategoryProvider.isLoading;
                final error = serviceCategoryProvider.errorMessage;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (error != null) {
                  final isPermission =
                      error.toLowerCase().contains('permission') ||
                      error.toLowerCase().contains('insufficient');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPermission
                                ? 'Permission denied reading services'
                                : 'Error loading services',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isPermission
                                ? 'Please update Firestore rules to allow reads on service_categories, or sign in as admin.'
                                : error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (serviceCategories.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No services available yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back soon!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Service Categories Grid
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: serviceCategories.length,
                              itemBuilder: (context, index) {
                                final category = serviceCategories[index];
                                final isSelected =
                                    _selectedCategory?.id == category.id;
                                return _buildServiceCategoryCard(
                                  category: category,
                                  isSelected: isSelected,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Service Details/Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _selectedCategory != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available ${_selectedCategory!.name} Services',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  // Real service providers from Firestore
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .where(
                                          'role',
                                          isEqualTo: 'service_provider',
                                        )
                                        .where(
                                          'serviceCategoryId',
                                          isEqualTo: _selectedCategory!.id,
                                        )
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      if (snapshot.hasError) {
                                        return Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            'Error loading providers: ${snapshot.error}',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        );
                                      }

                                      final providers =
                                          snapshot.data?.docs ?? [];

                                      if (providers.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.person_off_outlined,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Koi ${_selectedCategory!.name} abhi available nahi hai',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Jald hi providers add honge!',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: providers.map((doc) {
                                          final data =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          final name =
                                              data['name'] ?? 'Unknown';
                                          final businessName =
                                              data['businessName'] ?? name;
                                          final minCharge =
                                              (data['minCharge'] ??
                                                      _selectedCategory!
                                                          .basePrice)
                                                  .toDouble();
                                          final district =
                                              data['district'] ?? '';
                                          final photoURL =
                                              data['photoURL'] as String?;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _buildServiceProviderCard(
                                              name: name,
                                              businessName: businessName,
                                              description: district.isNotEmpty
                                                  ? 'District: $district'
                                                  : _selectedCategory!
                                                        .description,
                                              price:
                                                  '₹${minCharge.toStringAsFixed(0)}/service',
                                              categoryName:
                                                  _selectedCategory!.name,
                                              photoURL: photoURL,
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        size: 64,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Select a service category to view available services',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCategoryCard({
    required ServiceCategory category,
    required bool isSelected,
  }) {
    final color = Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));
    final hasImage = category.imageUrl != null && category.imageUrl!.isNotEmpty;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? null : category;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          category.imageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.person, size: 40, color: color),
                            );
                          },
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person, size: 40, color: color),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceProviderCard({
    required String name,
    required String businessName,
    required String description,
    required String price,
    required String categoryName,
    String? photoURL,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          backgroundImage: photoURL != null && photoURL.isNotEmpty
              ? NetworkImage(photoURL)
              : null,
          child: photoURL == null || photoURL.isEmpty
              ? Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                )
              : null,
        ),
        title: Text(
          businessName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              BookServiceScreen.routeName,
              arguments: {
                'serviceName': categoryName,
                'providerName': businessName,
                'providerImage': photoURL,
              },
            );
          },
          child: const Text('Book'),
        ),
      ),
    );
  }
}
