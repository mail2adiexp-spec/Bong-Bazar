import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/join_partner_screen.dart';

Future<void> showMoreBottomSheet(BuildContext context) {
  final theme = Theme.of(context);
  // Keep a reference to the parent page context so we can navigate after closing the sheet
  final parentContext = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return DraggableScrollableSheet(
        // Initial height increased to show more content
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        // Smooth snapping between useful sizes
        snap: true,
        snapSizes: const [0.5, 0.65, 0.95],
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: _MoreSheetContent(
              scrollController: scrollController,
              rootContext: parentContext,
            ),
          );
        },
      );
    },
  );
}

class _MoreSheetContent extends StatelessWidget {
  final ScrollController scrollController;
  // Context of the page that opened the sheet
  final BuildContext rootContext;
  const _MoreSheetContent({
    required this.scrollController,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.currentUser != null;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        // No close icon; tap outside to dismiss
        // Content list
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              // Menu buttons (Notifications removed, aligned in two columns)
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth =
                      (constraints.maxWidth - 8) /
                      2; // 2 columns with 8px spacing
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () => _openSheet(
                            context,
                            'Settings',
                            _settingsContent(context),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.security,
                          label: 'Privacy & Security',
                          onTap: () => _openSheet(
                            context,
                            'Privacy & Security',
                            _privacyContent(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.assignment_return,
                          label: 'Return Policy',
                          onTap: () => _openSheet(
                            context,
                            'Return Policy',
                            _returnPolicyContent(),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.info_outline,
                          label: 'About Us',
                          onTap: () =>
                              _openSheet(context, 'About Us', _aboutContent()),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Join as Seller/Service Provider button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Close the sheet, then navigate using the parent page context
                    Navigator.of(context).pop();
                    Future.microtask(() {
                      Navigator.of(
                        rootContext,
                      ).pushNamed(JoinPartnerScreen.routeName);
                    });
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Join as Seller/Service Provider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              // Logout button - full width
              if (isLoggedIn) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
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
                        await context.read<AuthProvider>().signOut();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Content sections (kept concise, matching MoreScreen content)
  // replaced with detailed version below

  // Helpers
  Widget _infoSection(String title, String content) {
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

  // FAQ item helper removed as Help Center is removed

  Widget _settingTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {},
    );
  }

  // Detailed content (mirrors MoreScreen)
  Widget _aboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Center(
          child: Icon(Icons.shopping_bag, size: 80, color: Colors.deepPurple),
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Bong Bazar',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text('Version 1.3.3', style: TextStyle(color: Colors.grey)),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _privacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoSection(
          'Data Collection',
          'We collect personal information such as name, email, phone number, and address to process your orders and provide better services.',
        ),
        _infoSection(
          'Data Usage',
          'Your data is used to:\n• Process orders and payments\n• Provide customer support\n• Send order updates and notifications\n• Improve our services',
        ),
        _infoSection(
          'Data Security',
          'We implement industry-standard security measures to protect your personal information. All payment transactions are encrypted and secure.',
        ),
        _infoSection(
          'Third-Party Sharing',
          'We do not sell your personal data to third parties. We may share data with payment processors and delivery partners only to fulfill your orders.',
        ),
        _infoSection(
          'Your Rights',
          'You have the right to:\n• Access your personal data\n• Request data correction\n• Request data deletion\n• Opt-out of marketing communications',
        ),
        _infoSection(
          'Cookies',
          'We use cookies to improve your browsing experience and remember your preferences. You can disable cookies in your browser settings.',
        ),
      ],
    );
  }

  Widget _returnPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoSection(
          'Return Window',
          'You can return most items within 7 days of delivery for a full refund or exchange.',
        ),
        _infoSection(
          'Eligible Items',
          'Items must be:\n• Unused and in original condition\n• In original packaging with tags\n• Accompanied by invoice/receipt\n• Not damaged or altered',
        ),
        _infoSection(
          'Non-Returnable Items',
          '• Perishable goods (food, beverages)\n• Personal care items\n• Intimate apparel\n• Customized or personalized items\n• Gift cards',
        ),
        _infoSection(
          'Return Process',
          '1. Contact customer support within 7 days\n2. Provide order details and reason\n3. Pack item securely in original packaging\n4. Schedule pickup or drop-off\n5. Refund processed within 7-10 business days',
        ),
        _infoSection(
          'Refund Method',
          'Refunds will be credited to the original payment method. Processing time varies by bank/payment provider.',
        ),
        _infoSection(
          'Exchange',
          'If you want to exchange an item, return the original item and place a new order for the desired product.',
        ),
      ],
    );
  }

  Widget _settingsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingTile(
          'Notifications',
          'Manage app notifications',
          Icons.notifications_outlined,
        ),
        _settingTile('Language', 'English', Icons.language),
        _settingTile('Theme', 'Auto (System default)', Icons.palette_outlined),
        _settingTile('Data & Storage', 'Manage cache and data', Icons.storage),
        _settingTile('Payment Methods', 'Manage saved cards', Icons.payment),
        _settingTile(
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
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
          },
          icon: const Icon(Icons.cached),
          label: const Text('Clear Cache'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  // Help Center content removed per request

  // Notifications content removed per request
}
