import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('More'), centerTitle: true),
      body: ListView(
        children: [
          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isLoggedIn ? authProvider.currentUser!.email : 'Guest User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoggedIn)
                  const Text(
                    'Premium Member',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Settings Section
          _buildSectionTitle('Settings'),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () => _showBottomSheet(
              context,
              'Notifications',
              _getNotificationsContent(),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () =>
                _showBottomSheet(context, 'Settings', _getSettingsContent()),
          ),
          _buildMenuItem(
            context,
            icon: Icons.security,
            title: 'Privacy & Security',
            onTap: () => _showBottomSheet(
              context,
              'Privacy & Security',
              _getPrivacyContent(),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.assignment_return,
            title: 'Return Policy',
            onTap: () => _showBottomSheet(
              context,
              'Return Policy',
              _getReturnPolicyContent(),
            ),
          ),
          const Divider(),

          // Support Section
          _buildSectionTitle('Support'),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () => _showBottomSheet(
              context,
              'Help Center',
              _getHelpCenterContent(),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'About Us',
            onTap: () =>
                _showBottomSheet(context, 'About Us', _getAboutContent()),
          ),
          const Divider(),

          // Logout
          if (isLoggedIn)
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              iconColor: Colors.red,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await authProvider.signOut();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
                }
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showBottomSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getAboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Icon(Icons.shopping_bag, size: 80, color: Colors.deepPurple),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Bong Bazar',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Version 1.3.3', style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your trusted e-commerce platform for quality products and services.',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildInfoSection(
          'Our Mission',
          'To provide the best shopping experience with quality products, reliable services, and excellent customer support.',
        ),
        _buildInfoSection(
          'What We Offer',
          '• Wide range of products\n• Professional services\n• Secure payments\n• Fast delivery\n• 24/7 customer support',
        ),
        _buildInfoSection(
          'Contact Us',
          'Email: support@bongbazar.com\nPhone: +91 7479223366\nAddress: Kolkata, West Bengal, India',
        ),
      ],
    );
  }

  Widget _getPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(
          'Data Collection',
          'We collect personal information such as name, email, phone number, and address to process your orders and provide better services.',
        ),
        _buildInfoSection(
          'Data Usage',
          'Your data is used to:\n• Process orders and payments\n• Provide customer support\n• Send order updates and notifications\n• Improve our services',
        ),
        _buildInfoSection(
          'Data Security',
          'We implement industry-standard security measures to protect your personal information. All payment transactions are encrypted and secure.',
        ),
        _buildInfoSection(
          'Third-Party Sharing',
          'We do not sell your personal data to third parties. We may share data with payment processors and delivery partners only to fulfill your orders.',
        ),
        _buildInfoSection(
          'Your Rights',
          'You have the right to:\n• Access your personal data\n• Request data correction\n• Request data deletion\n• Opt-out of marketing communications',
        ),
        _buildInfoSection(
          'Cookies',
          'We use cookies to improve your browsing experience and remember your preferences. You can disable cookies in your browser settings.',
        ),
      ],
    );
  }

  Widget _getReturnPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(
          'Return Window',
          'You can return most items within 7 days of delivery for a full refund or exchange.',
        ),
        _buildInfoSection(
          'Eligible Items',
          'Items must be:\n• Unused and in original condition\n• In original packaging with tags\n• Accompanied by invoice/receipt\n• Not damaged or altered',
        ),
        _buildInfoSection(
          'Non-Returnable Items',
          '• Perishable goods (food, beverages)\n• Personal care items\n• Intimate apparel\n• Customized or personalized items\n• Gift cards',
        ),
        _buildInfoSection(
          'Return Process',
          '1. Contact customer support within 7 days\n2. Provide order details and reason\n3. Pack item securely in original packaging\n4. Schedule pickup or drop-off\n5. Refund processed within 7-10 business days',
        ),
        _buildInfoSection(
          'Refund Method',
          'Refunds will be credited to the original payment method. Processing time varies by bank/payment provider.',
        ),
        _buildInfoSection(
          'Exchange',
          'If you want to exchange an item, return the original item and place a new order for the desired product.',
        ),
      ],
    );
  }

  Widget _getSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingTile(
          'Notifications',
          'Manage app notifications',
          Icons.notifications_outlined,
        ),
        _buildSettingTile('Language', 'English', Icons.language),
        _buildSettingTile(
          'Theme',
          'Auto (System default)',
          Icons.palette_outlined,
        ),
        _buildSettingTile(
          'Data & Storage',
          'Manage cache and data',
          Icons.storage,
        ),
        _buildSettingTile(
          'Payment Methods',
          'Manage saved cards',
          Icons.payment,
        ),
        _buildSettingTile(
          'Addresses',
          'Manage delivery addresses',
          Icons.location_on_outlined,
        ),
        const SizedBox(height: 16),
        const Text(
          'App Version',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text('Bong Bazar v1.3.3'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.cached),
          label: const Text('Clear Cache'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Widget _getHelpCenterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection('Frequently Asked Questions', ''),
        _buildFAQItem(
          'How do I track my order?',
          'Go to "My Orders" and click on your order to see tracking details.',
        ),
        _buildFAQItem(
          'How can I cancel my order?',
          'You can cancel within 24 hours of placing the order from the "My Orders" section.',
        ),
        _buildFAQItem(
          'What payment methods do you accept?',
          'We accept credit/debit cards, UPI, net banking, and cash on delivery.',
        ),
        _buildFAQItem(
          'How long does delivery take?',
          'Standard delivery takes 3-5 business days. Express delivery is available in select areas.',
        ),
        _buildFAQItem(
          'Do you charge delivery fees?',
          'Free delivery on orders above ₹500. Below that, a nominal fee applies.',
        ),
        const SizedBox(height: 24),
        _buildInfoSection(
          'Still Need Help?',
          'Contact our support team:\n📧 support@bongbazar.com\n📞 +91 7479223366\n\nSupport Hours: 9 AM - 9 PM (Mon-Sat)',
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q: $question',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'A: $answer',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {},
    );
  }

  Widget _getNotificationsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(
          'Push Notifications',
          'Get instant updates about your orders, offers, and new arrivals.',
        ),
        SwitchListTile(
          title: const Text('Order Updates'),
          subtitle: const Text('Get notified about order status changes'),
          value: true,
          onChanged: (value) {},
        ),
        SwitchListTile(
          title: const Text('Promotional Offers'),
          subtitle: const Text('Receive exclusive deals and discounts'),
          value: true,
          onChanged: (value) {},
        ),
        SwitchListTile(
          title: const Text('New Arrivals'),
          subtitle: const Text('Be the first to know about new products'),
          value: false,
          onChanged: (value) {},
        ),
        SwitchListTile(
          title: const Text('Price Drops'),
          subtitle: const Text('Get alerts when items in wishlist go on sale'),
          value: false,
          onChanged: (value) {},
        ),
        const SizedBox(height: 16),
        _buildInfoSection(
          'Email Notifications',
          'Receive important updates via email.',
        ),
        SwitchListTile(
          title: const Text('Order Confirmations'),
          subtitle: const Text('Email receipts for your purchases'),
          value: true,
          onChanged: (value) {},
        ),
        SwitchListTile(
          title: const Text('Newsletter'),
          subtitle: const Text('Weekly digest of offers and updates'),
          value: false,
          onChanged: (value) {},
        ),
      ],
    );
  }
}
