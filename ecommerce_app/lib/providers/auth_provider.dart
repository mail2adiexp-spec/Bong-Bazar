import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String email;
  final String name;

  AppUser({required this.email, required this.name});
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AppUser? _currentUser;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  void _onAuthStateChanged(User? firebaseUser) {
    if (firebaseUser != null) {
      _currentUser = AppUser(
        email: firebaseUser.email ?? '',
        name:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'User',
      );
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('The password provided is too weak');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('An account with this email already exists');
      } else {
        throw Exception(e.message ?? 'Sign up failed');
      }
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found for this email');
      } else if (e.code == 'wrong-password') {
        throw Exception('Invalid credentials');
      } else {
        throw Exception(e.message ?? 'Sign in failed');
      }
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
