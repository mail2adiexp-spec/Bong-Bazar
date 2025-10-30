import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_panel_screen.dart';

class AccountScreen extends StatelessWidget {
  static const routeName = '/account';
  const AccountScreen({super.key});

  Widget _buildNetworkAvatar(
    String imageUrl,
    String fallbackInitial,
    BuildContext context,
  ) {
    print('🖼️ Building avatar for URL: $imageUrl');
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('🔴 Avatar image load error: $error');
          print('📸 Failed URL: $imageUrl');
          print('Stack: $stackTrace');
          return Container(
            width: 100,
            height: 100,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Center(
              child: Text(
                fallbackInitial,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Avatar image loaded successfully!');
            return child;
          }
          final progress =
              loadingProgress.cumulativeBytesLoaded /
              (loadingProgress.expectedTotalBytes ?? 1);
          print('⏳ Loading avatar: ${(progress * 100).toStringAsFixed(0)}%');
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? progress
                  : null,
              strokeWidth: 2,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) => Scaffold(
        appBar: AppBar(title: const Text('My Profile'), elevation: 0),
        body: auth.isLoggedIn
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    // Header with gradient
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          // Avatar with error handling
                          CircleAvatar(
                            radius: 50,
                            key: ValueKey(auth.currentUser!.photoURL),
                            backgroundColor: Colors.white,
                            child: auth.currentUser!.photoURL != null
                                ? _buildNetworkAvatar(
                                    auth.currentUser!.photoURL!,
                                    auth.currentUser!.name.isNotEmpty
                                        ? auth.currentUser!.name[0]
                                              .toUpperCase()
                                        : 'U',
                                    context,
                                  )
                                : Text(
                                    auth.currentUser!.name.isNotEmpty
                                        ? auth.currentUser!.name[0]
                                              .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            auth.currentUser!.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.currentUser!.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          if (auth.currentUser!.phoneNumber != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              auth.currentUser!.phoneNumber!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Profile Options
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildProfileCard(
                            context: context,
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            subtitle: 'Update your name, email, phone & image',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                EditProfileScreen.routeName,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildProfileCard(
                            context: context,
                            icon: Icons.email_outlined,
                            title: 'Email',
                            subtitle: auth.currentUser!.email,
                            onTap: null,
                          ),
                          const SizedBox(height: 12),
                          _buildProfileCard(
                            context: context,
                            icon: Icons.shopping_bag_outlined,
                            title: 'My Orders',
                            subtitle: 'View your order history',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order history coming soon!'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildProfileCard(
                            context: context,
                            icon: Icons.admin_panel_settings,
                            title: 'Admin Panel',
                            subtitle: 'Manage products and inventory',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AdminPanelScreen.routeName,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildProfileCard(
                            context: context,
                            icon: Icons.favorite_outline,
                            title: 'Wishlist',
                            subtitle: 'Your favorite products',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Wishlist coming soon!'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          // Sign Out Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Sign Out'),
                                    content: const Text(
                                      'Are you sure you want to sign out?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Sign Out'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await context.read<AuthProvider>().signOut();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Signed out successfully'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign Out'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 100,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'You are not signed in',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to access your profile, orders, and more',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, AuthScreen.routeName);
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In / Sign Up'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
