import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionChecker {
  final Map<String, dynamic> permissions;
  final String role;

  PermissionChecker({
    required this.permissions,
    required this.role,
  });

  factory PermissionChecker.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final role = data?['role'] as String? ?? 'user';
    final permissions = data?['permissions'] as Map<String, dynamic>? ?? {};
    return PermissionChecker(permissions: permissions, role: role);
  }

  factory PermissionChecker.fromMap(Map<String, dynamic> data) {
    final role = data['role'] as String? ?? 'user';
    final permissions = data['permissions'] as Map<String, dynamic>? ?? {};
    return PermissionChecker(permissions: permissions, role: role);
  }

  bool get isAdmin => role == 'admin' || role == 'administrator';
  bool get isCoreStaff => role == 'core_staff';

  // Dashboard Access
  bool get canViewDashboard => isAdmin || (isCoreStaff && _hasPermission('can_view_dashboard'));

  // Products
  bool get canViewProducts => isAdmin || (isCoreStaff && (_hasPermission('can_view_products') || _hasPermission('can_manage_products')));
  bool get canManageProducts => isAdmin || (isCoreStaff && _hasPermission('can_manage_products'));

  // Orders
  bool get canViewOrders => isAdmin || (isCoreStaff && (_hasPermission('can_view_orders') || _hasPermission('can_manage_orders')));
  bool get canManageOrders => isAdmin || (isCoreStaff && _hasPermission('can_manage_orders'));

  // Users
  bool get canViewUsers => isAdmin || (isCoreStaff && (_hasPermission('can_view_users') || _hasPermission('can_manage_users')));
  bool get canManageUsers => isAdmin || (isCoreStaff && _hasPermission('can_manage_users'));
  
  // Services
  bool get canViewServices => isAdmin || (isCoreStaff && (_hasPermission('can_view_services') || _hasPermission('can_manage_services')));
  bool get canManageServices => isAdmin || (isCoreStaff && _hasPermission('can_manage_services'));

  // Core Staff Management (Admin only usually, or specific permission)
  bool get canManageCoreStaff => isAdmin || (isCoreStaff && _hasPermission('can_manage_core_staff'));

  bool _hasPermission(String key) {
    return permissions[key] == true;
  }
}
