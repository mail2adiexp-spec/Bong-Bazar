import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';

class AppUser {
  final String email;
  final String name;
  final String? phoneNumber;
  final String? photoURL;

  AppUser({
    required this.email,
    required this.name,
    this.phoneNumber,
    this.photoURL,
  });
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
        phoneNumber: firebaseUser.phoneNumber,
        photoURL: firebaseUser.photoURL,
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

  Future<void> updateProfile({required String name}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');
      await user.updateDisplayName(name.trim());
      await user.reload();
      // Trigger state change to update UI
      _onAuthStateChanged(_auth.currentUser);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Update failed');
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  Future<void> updateEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Re-authenticate user before email change
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Update email
      await user.verifyBeforeUpdateEmail(email.trim());
      throw Exception(
        'Verification email sent. Please check your new email and verify it.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email format');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password');
      }
      throw Exception(e.message ?? 'Email update failed');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> updatePhoneNumber({required String phoneNumber}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Note: Phone number verification requires SMS and platform-specific setup
      // For now, we'll store it in display name or use a custom solution
      // In production, use Firebase Phone Auth with proper verification

      // Since Firebase Auth doesn't directly support phone number updates without verification,
      // we'll need to implement this via Firestore or another database
      // For this demo, we'll throw a message
      throw Exception(
        'Phone number update requires additional setup. Coming soon!',
      );
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> updateProfileImage({
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      if (imageFile == null && imageBytes == null) {
        throw Exception('No image provided');
      }

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images')
          .child('${user.uid}.jpg');

      // Upload based on platform
      if (imageBytes != null) {
        // Web upload using bytes
        await storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (imageFile != null) {
        // Mobile/Desktop upload using File
        await storageRef.putFile(imageFile);
      }

      final downloadURL = await storageRef.getDownloadURL();

      // Update user profile
      await user.updatePhotoURL(downloadURL);
      await user.reload();
      _onAuthStateChanged(_auth.currentUser);
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Image upload failed');
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }
}
