import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/permission_checker.dart';
import 'login_screen.dart';

class CoreStaffDashboardScreen extends StatefulWidget {
  static const routeName = '/core-staff-dashboard';

  const CoreStaffDashboardScreen({super.key});

  @override
  State<CoreStaffDashboardScreen> createState() => _CoreStaffDashboardScreenState();
}

class _CoreStaffDashboardScreenState extends State<CoreStaffDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PermissionChecker? _permissionChecker;
  bool _isLoading = true;
  List<Widget> _tabs = [];
  List<Widget> _tabViews = [];

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _permissionChecker = PermissionChecker.fromDocument(doc);
          _setupTabs();
        }
      }
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupTabs() {
    _tabs = [];
    _tabViews = [];

    // Always add Dashboard Home
    _tabs.add(const Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'));
    _tabViews.add(_buildDashboardHome());

    if (_permissionChecker?.canViewProducts == true) {
      _tabs.add(const Tab(icon: Icon(Icons.inventory), text: 'Products'));
      _tabViews.add(const Center(child: Text('Products Management (Coming Soon)')));
    }

    if (_permissionChecker?.canViewOrders == true) {
      _tabs.add(const Tab(icon: Icon(Icons.shopping_bag), text: 'Orders'));
      _tabViews.add(const Center(child: Text('Orders Management (Coming Soon)')));
    }
    
    if (_permissionChecker?.canViewUsers == true) {
      _tabs.add(const Tab(icon: Icon(Icons.people), text: 'Users'));
      _tabViews.add(const Center(child: Text('User Management (Coming Soon)')));
    }

    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    if (_tabs.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_permissionChecker == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading profile or permissions.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _logout, child: const Text('Logout')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: _tabs.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _tabs,
              )
            : null,
      ),
      body: _tabs.isEmpty
          ? const Center(child: Text('No access to any modules.'))
          : TabBarView(
              controller: _tabController,
              children: _tabViews,
            ),
    );
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Staff Member',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard(
                title: 'Products',
                value: 'Loading...', // Would fetch real count
                icon: Icons.inventory,
                color: Colors.blue,
              ),
              _buildMetricCard(
                title: 'Orders',
                value: 'Loading...',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              _buildMetricCard(
                title: 'Users',
                value: 'Loading...',
                icon: Icons.people,
                color: Colors.green,
              ),
              _buildMetricCard(
                title: 'Revenue',
                value: '₹0',
                icon: Icons.currency_rupee,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
