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
      print('🔄 Auth state changed for user: ${firebaseUser.uid}');
      print('📸 PhotoURL: ${firebaseUser.photoURL}');
      _currentUser = AppUser(
        email: firebaseUser.email ?? '',
        name:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'User',
        phoneNumber: firebaseUser.phoneNumber,
        photoURL: firebaseUser.photoURL,
      );
      print('✅ Current user updated with photoURL: ${_currentUser?.photoURL}');
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
      print('🔵 Starting image upload...');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user signed in');
        throw Exception('No user signed in');
      }
      print('✅ User authenticated: ${user.uid}');

      if (imageFile == null && imageBytes == null) {
        print('❌ No image provided');
        throw Exception('No image provided');
      }

      final imageSize = imageBytes?.length ?? await imageFile!.length();
      print('📦 Image size: ${(imageSize / 1024).toStringAsFixed(2)} KB');

      // Upload to Firebase Storage with explicit bucket
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final storageRef = storage
          .ref()
          .child('user_images')
          .child('${user.uid}.jpg');
      print('📁 Upload path: user_images/${user.uid}.jpg');
      print('🪣 Bucket: gs://bong-bazar-3659f.firebasestorage.app');

      // Decide content type from filename if available
      String contentType = 'image/jpeg';
      if (fileName != null) {
        final lower = fileName.toLowerCase();
        if (lower.endsWith('.png')) contentType = 'image/png';
        if (lower.endsWith('.webp')) contentType = 'image/webp';
      }
      print('📝 Content-Type: $contentType');

      // Upload based on platform
      UploadTask uploadTask;
      if (imageBytes != null) {
        print('🌐 Uploading via bytes (Web)...');
        uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=3600',
          ),
        );
      } else {
        print('📱 Uploading via file (Mobile/Desktop)...');
        uploadTask = storageRef.putFile(
          imageFile!,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=3600',
          ),
        );
      }

      print('⏳ Waiting for upload to complete...');
      final TaskSnapshot snapshot = await uploadTask;
      print('📊 Upload state: ${snapshot.state.name}');

      if (snapshot.state != TaskState.success) {
        print('❌ Upload failed with state: ${snapshot.state.name}');
        throw Exception('Upload failed: ${snapshot.state.name}');
      }

      print('✅ Upload successful! Getting download URL...');
      final downloadURL = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('❌ Download URL fetch timeout');
          throw Exception('Failed to get download URL: timeout');
        },
      );
      print('🔗 Download URL: $downloadURL');

      print('💾 Updating user profile with photo URL...');
      // Update the photo URL on Firebase Auth
      await user.updatePhotoURL(downloadURL);
      // Reload the user to get the latest data from Firebase
      await user.reload();
      print('✅ Profile updated successfully!');
      // Manually trigger the state change with the reloaded user object
      _onAuthStateChanged(_auth.currentUser);
      print('🔄 Auth state refreshed');
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      throw Exception('Firebase error: ${e.code} - ${e.message}');
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Image upload failed: $e');
    }
  }
}
