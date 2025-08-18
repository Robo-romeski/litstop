import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../utils/secure_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

enum AuthMethod {
  emailPassword,
  google,
  apple,
  biometric,
  none,
}

class AuthProvider with ChangeNotifier {
  // Set to false when you want to use real authentication
  final bool _forceDemoMode = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorage _secureStorage = SecureStorage();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isFirebaseInitialized = true;
  bool _rememberMe = false;
  bool _canUseBiometrics = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  bool get isFirebaseInitialized => _isFirebaseInitialized && !_forceDemoMode;
  bool get rememberMe => _rememberMe;
  bool get canUseBiometrics => _canUseBiometrics;
  bool get isEmailVerified => _user?.emailVerified ?? false;

  // Get current authentication method
  Future<AuthMethod> getCurrentAuthMethod() async {
    if (!isAuthenticated) {
      return AuthMethod.none;
    }

    final prefs = await SharedPreferences.getInstance();
    final authMethodString = prefs.getString('auth_method');

    if (authMethodString == null) {
      return AuthMethod.none;
    }

    try {
      // Convert string to enum value
      if (authMethodString.contains('google')) {
        return AuthMethod.google;
      } else if (authMethodString.contains('apple')) {
        return AuthMethod.apple;
      } else if (authMethodString.contains('biometric')) {
        return AuthMethod.biometric;
      } else if (authMethodString.contains('emailPassword')) {
        return AuthMethod.emailPassword;
      }
      return AuthMethod.none;
    } catch (e) {
      debugPrint("Error determining auth method: $e");
      return AuthMethod.none;
    }
  }

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Check if Firebase is properly initialized
    try {
      if (!_forceDemoMode) {
        // Load remember me preference
        await _loadRememberMePreference();

        // Check biometric support
        await _checkBiometricSupport();

        // Check if user is already authenticated
        debugPrint("Checking if Firebase auth is available...");
        _user = _auth.currentUser;
        debugPrint("Current Firebase user: ${_user?.email ?? 'None'}");

        // Try auto login if remember me is enabled
        if (_user == null && _rememberMe) {
          await _tryAutoLogin();
        }

        // Listen for auth state changes
        _auth.authStateChanges().listen((User? user) {
          debugPrint("Auth state changed: ${user?.email ?? 'logged out'}");
          _user = user;
          notifyListeners();
        });

        debugPrint("Firebase is properly initialized: $_isFirebaseInitialized");
      }
    } catch (e) {
      _isFirebaseInitialized = false;
      _setError("Firebase is not properly initialized: ${e.toString()}");
      debugPrint("Firebase initialization issue: $e");
      debugPrint("Stack trace: ${StackTrace.current}");
    }
  }

  // Check if device supports biometric authentication
  Future<void> _checkBiometricSupport() async {
    try {
      // Check if device supports biometric auth
      _canUseBiometrics = await _localAuth.canCheckBiometrics;

      if (_canUseBiometrics) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        debugPrint("Available biometrics: $availableBiometrics");

        // Update canUseBiometrics to check if at least one method is available
        _canUseBiometrics = availableBiometrics.isNotEmpty;
      }

      debugPrint("Biometric authentication available: $_canUseBiometrics");
    } on PlatformException catch (e) {
      _canUseBiometrics = false;
      debugPrint("Error checking biometric support: $e");
    }
  }

  // Load remember me preference
  Future<void> _loadRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rememberMe = prefs.getBool('remember_me') ?? false;
      debugPrint("Remember me preference loaded: $_rememberMe");
    } catch (e) {
      _rememberMe = false;
      debugPrint("Error loading remember me preference: $e");
    }
  }

  // Set remember me preference
  Future<void> setRememberMe(bool value) async {
    try {
      _rememberMe = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', value);
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving remember me preference: $e");
    }
  }

  // Try to auto login with stored credentials
  Future<void> _tryAutoLogin() async {
    try {
      // Check if we have stored credentials
      final hasCredentials = await _secureStorage.containsKey('auth_email') &&
          await _secureStorage.containsKey('auth_password');

      if (hasCredentials) {
        final email = await _secureStorage.readSecure('auth_email');
        final password = await _secureStorage.readSecure('auth_password');

        if (email != null && password != null) {
          debugPrint("Attempting auto login with stored credentials");
          await signInWithEmailPassword(email, password,
              rememberMe: true, autoLogin: true);
        }
      }
    } catch (e) {
      debugPrint("Error during auto login: $e");
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    if (!_canUseBiometrics) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access LitStop',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      debugPrint("Error using biometric authentication: $e");
      _setError("Biometric authentication failed: ${e.message}");
      return false;
    }
  }

  // Sign in with email/password and biometrics
  Future<User?> signInWithBiometrics() async {
    // Check if biometric auth is available and there are stored credentials
    if (!_canUseBiometrics || !_rememberMe) {
      _setError("Biometric login requires saved credentials");
      return null;
    }

    // First authenticate with biometrics
    final authenticated = await authenticateWithBiometrics();
    if (!authenticated) {
      _setError("Biometric authentication failed");
      return null;
    }

    try {
      // Check if we have stored credentials
      final hasCredentials = await _secureStorage.containsKey('auth_email') &&
          await _secureStorage.containsKey('auth_password');

      if (hasCredentials) {
        final email = await _secureStorage.readSecure('auth_email');
        final password = await _secureStorage.readSecure('auth_password');

        if (email != null && password != null) {
          return await signInWithEmailPassword(email, password,
              rememberMe: true, autoLogin: true);
        }
      }

      _setError("No stored credentials found for biometric login");
      return null;
    } catch (e) {
      debugPrint("Error in biometric sign in: $e");
      _setError("Biometric sign in failed: ${e.toString()}");
      return null;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    // For testing, always use demo auth
    if (_forceDemoMode || !_isFirebaseInitialized) {
      debugPrint(
          "Using demo auth mode for Google Sign-In, isFirebaseInitialized: $_isFirebaseInitialized, forceDemoMode: $_forceDemoMode");
      return await _handleDemoAuth();
    }

    debugPrint("Attempting real Google Sign-In");
    _setLoading(true);
    _clearError();

    try {
      debugPrint("Starting Google sign-in process");
      // Start the Google sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in process
        debugPrint("Google sign-in canceled by user");
        _setLoading(false);
        return null;
      }

      debugPrint("Google sign-in successful: ${googleUser.email}");

      // Get authentication details from Google
      debugPrint("Getting Google auth tokens");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint("Received Google auth tokens");
      debugPrint("Access token length: ${googleAuth.accessToken?.length ?? 0}");
      debugPrint("ID token length: ${googleAuth.idToken?.length ?? 0}");

      // Create Firebase credential with Google tokens
      debugPrint("Creating Firebase credential");
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      debugPrint("Signing in to Firebase with Google credential");
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      debugPrint("Firebase sign-in successful: ${userCredential.user?.uid}");
      _user = userCredential.user;

      // Save auth method to SharedPreferences
      await _saveAuthMethod(AuthMethod.google);

      _setLoading(false);
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint("Google sign-in error: $e");
      debugPrint("Error type: ${e.runtimeType}");
      debugPrint("Stack trace: ${StackTrace.current}");
      // Instead of falling back to demo mode, notify user of error
      _setError("Google Sign-in failed: ${e.toString()}");
      _setLoading(false);
      return null;
    }
  }

  // Generate a cryptographically secure random nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // Calculate the SHA-256 hash of the input string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Sign in with Apple
  Future<User?> signInWithApple() async {
    // For testing, always use demo auth
    if (_forceDemoMode || !_isFirebaseInitialized) {
      debugPrint(
          "Using demo auth mode for Apple Sign-In, isFirebaseInitialized: $_isFirebaseInitialized, forceDemoMode: $_forceDemoMode");
      return await _handleDemoAuth();
    }

    debugPrint("Attempting real Apple Sign-In");
    _setLoading(true);
    _clearError();

    try {
      // Generate a random nonce to prevent replay attacks
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      debugPrint("Starting Apple sign-in process");
      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      debugPrint("Apple sign-in successful");
      debugPrint("Getting Apple ID tokens");

      // Create Firebase credential with Apple ID tokens
      debugPrint("Creating Firebase credential");
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the Apple credential
      debugPrint("Signing in to Firebase with Apple credential");
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      debugPrint("Firebase sign-in successful: ${userCredential.user?.uid}");
      _user = userCredential.user;

      // Apple does not provide name and email after the first sign-in
      // So we need to store these when we first get them
      final displayName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();

      // If we received user information and the user does not have a display name
      if (displayName.isNotEmpty &&
          (_user?.displayName == null || _user?.displayName?.isEmpty == true)) {
        await _user?.updateDisplayName(displayName);
      }

      // Save auth method to SharedPreferences
      await _saveAuthMethod(AuthMethod.apple);

      _setLoading(false);
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint("Apple sign-in error: $e");
      debugPrint("Error type: ${e.runtimeType}");
      debugPrint("Stack trace: ${StackTrace.current}");
      // Instead of falling back to demo mode, notify user of error
      _setError("Apple Sign-in failed: ${e.toString()}");
      _setLoading(false);
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password,
      {bool rememberMe = false, bool autoLogin = false}) async {
    // For testing, always use demo auth
    if (_forceDemoMode || !_isFirebaseInitialized) {
      return await _handleDemoAuth(email: email);
    }

    if (!autoLogin) {
      _setLoading(true);
      _clearError();
    }

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      // Save auth method to SharedPreferences
      await _saveAuthMethod(AuthMethod.emailPassword);

      // Save credentials if remember me is enabled
      if (rememberMe) {
        await _secureStorage.writeSecure('auth_email', email);
        await _secureStorage.writeSecure('auth_password', password);
        await setRememberMe(true);
      } else if (!autoLogin) {
        // Clear saved credentials if remember me is disabled
        await _secureStorage.deleteSecure('auth_email');
        await _secureStorage.deleteSecure('auth_password');
        await setRememberMe(false);
      }

      if (!autoLogin) {
        _setLoading(false);
      }
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint("Email sign-in error: $e");
      // Instead of falling back to demo auth, show the actual error
      _setError("Login failed: ${e.toString()}");
      if (!autoLogin) {
        _setLoading(false);
      }
      return null;
    }
  }

  // Register with email and password
  Future<User?> registerWithEmailPassword(String email, String password) async {
    // For testing, always use demo auth
    if (_forceDemoMode || !_isFirebaseInitialized) {
      return await _handleDemoAuth(email: email);
    }

    _setLoading(true);
    _clearError();

    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      // Send email verification
      await sendEmailVerification();

      // Save auth method to SharedPreferences
      await _saveAuthMethod(AuthMethod.emailPassword);

      _setLoading(false);
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint("Registration error: $e");
      // Instead of falling back to demo auth, show the actual error
      _setError("Registration failed: ${e.toString()}");
      _setLoading(false);
      return null;
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    if (!_isFirebaseInitialized || _user == null) {
      _setError("Cannot send verification email: No user is logged in");
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      await _user!.sendEmailVerification();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError("Failed to send verification email: ${e.toString()}");
      _setLoading(false);
    }
  }

  // Reload user to check if email is verified
  Future<bool> reloadUser() async {
    if (!_isFirebaseInitialized || _user == null) {
      return false;
    }

    try {
      await _user!.reload();
      _user = _auth.currentUser; // Update the user after reload
      notifyListeners();
      return _user?.emailVerified ?? false;
    } catch (e) {
      debugPrint("Error reloading user: $e");
      return false;
    }
  }

  // Handle demo authentication when Firebase is not initialized
  Future<User?> _handleDemoAuth({String email = 'demo@litstop.com'}) async {
    _setLoading(true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Create a fake user for demo
    final demoUser = _DemoUser(
      uid: '12345',
      email: email,
      displayName: 'Demo User',
    );

    _user = demoUser;

    // Save demo auth method
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('demo_user_email', email);
    await prefs.setString('demo_user_name', 'Demo User');

    _setLoading(false);
    notifyListeners();
    return demoUser;
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      if (_isFirebaseInitialized && !_forceDemoMode) {
        // Sign out from Google if that was the auth method
        final prefs = await SharedPreferences.getInstance();
        final authMethodString = prefs.getString('auth_method');

        if (authMethodString == AuthMethod.google.toString()) {
          await _googleSignIn.signOut();
        }

        // Sign out from Firebase
        await _auth.signOut();
      }

      _user = null;

      // Only clear credentials if remember me is disabled
      if (!_rememberMe) {
        await _secureStorage.deleteSecure('auth_email');
        await _secureStorage.deleteSecure('auth_password');
      }

      // Clear auth method from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_method');
      await prefs.remove('demo_user_email');
      await prefs.remove('demo_user_name');

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError("Sign out failed: ${e.toString()}");
      _setLoading(false);
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    if (!_isFirebaseInitialized) {
      // Show a demo success message
      _setLoading(true);
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(false);
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _setLoading(false);
    } catch (e) {
      _setError("Password reset failed: ${e.toString()}");
      _setLoading(false);
    }
  }

  // Helper to save auth method to SharedPreferences
  Future<void> _saveAuthMethod(AuthMethod method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_method', method.toString());
  }

  // Helper to set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Helper to set error message
  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  // Helper to clear error message
  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

// Demo User class that implements User interface for demo mode
class _DemoUser implements User {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified = true; // Always true for demo user

  _DemoUser({
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // This returns a default value for any unimplemented method
    if (invocation.isGetter) {
      // For boolean getters
      if (invocation.memberName.toString().contains('isAnonymous')) {
        return false;
      }
      // For emailVerified getter
      if (invocation.memberName.toString().contains('emailVerified')) {
        return emailVerified;
      }
    }
    return null;
  }
}
