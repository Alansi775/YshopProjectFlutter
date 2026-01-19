import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

/// Enhanced Auth Manager with Firebase + Backend Integration
class AuthManager with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthManager() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Handle auth state changes
  Future<void> _onAuthStateChanged(User? user) async {
    _currentUser = user;

    if (user != null) {
      // Do not automatically sync every Firebase auth event to backend.
      // Syncing should be explicit where needed (e.g., after customer signup,
      // or when an admin approves a store owner). This avoids creating
      // backend `users` rows for store owner requests before approval.
      // Attempt to fetch profile (may fail if not yet synced) — errors are caught.
      await _fetchUserProfile();
    } else {
      _userProfile = null;
    }

    notifyListeners();
  }

  /// Sync user data with backend after Firebase auth
  Future<void> _syncUserWithBackend(User user) async {
    try {
      await ApiService.syncUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    } catch (e) {
      debugPrint('Error syncing user with backend: $e');
      // Not critical, user can still use the app
    }
  }

  /// Register new user with Firebase
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      //  CRITICAL: Clear ALL old cache before signing in a NEW user
      ApiService.clearCache();
      ApiService.clearAuthCache();

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Sign in failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign out - Comprehensive cleanup
  Future<void> signOut() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      //  CRITICAL: Clear ALL API caches BEFORE signing out
      ApiService.clearCache();
      //  CRITICAL: Clear auth tokens
      ApiService.clearAuthCache();
      //  CRITICAL: Admin logout (clears SharedPreferences)
      ApiService.adminLogout();
      
      //  Then sign out from Firebase
      await _auth.signOut();

      _currentUser = null;
      _userProfile = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Sign out failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to reset password: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch user profile from backend
  Future<void> _fetchUserProfile() async {
    if (!isAuthenticated) return;

    try {
      _userProfile = await ApiService.getUserProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      // Not critical, allow user to proceed
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? phone,
    String? address,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _userProfile = await ApiService.updateUserProfile(
        displayName: displayName,
        phone: phone,
        address: address,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Update failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Check if email is verified
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _currentUser?.sendEmailVerification();
    } catch (e) {
      _errorMessage = 'Failed to send verification email: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Reload user data
  Future<void> reloadUser() async {
    try {
      await _currentUser?.reload();
      _currentUser = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reload user: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get Firebase error message
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Invalid password';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}