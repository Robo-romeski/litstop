import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../utils/page_transitions.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import '../providers/session_provider.dart';
import '../providers/auth_provider.dart';
import 'dart:io' show Platform;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();

    // Add demo credentials for easier testing
    _emailController.text = 'test@test.com';
    _passwordController.text = 'password123';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailPasswordAuth() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final sessionProvider = context.read<SessionProvider>();

      if (_isRegistering) {
        // Register new user
        final user = await authProvider.registerWithEmailPassword(
          _emailController.text,
          _passwordController.text,
        );

        if (user != null && mounted) {
          // Only proceed to home screen on successful authentication
          sessionProvider.setUser(
            id: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? 'User',
          );

          Navigator.of(context).pushReplacement(
            PageTransitions.fadeSlide(const HomeScreen()),
          );
        } else if (mounted) {
          // Only allow demo mode fallback if Firebase is explicitly not initialized
          if (!authProvider.isFirebaseInitialized) {
            // In demo mode, we'll just simulate a successful login
            sessionProvider.setUser(
              id: '12345',
              email: _emailController.text,
              name: 'Demo User',
            );

            Navigator.of(context).pushReplacement(
              PageTransitions.fadeSlide(const HomeScreen()),
            );
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.error ?? 'Registration failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Sign in existing user
        final user = await authProvider.signInWithEmailPassword(
          _emailController.text,
          _passwordController.text,
        );

        if (user != null && mounted) {
          // Only proceed to home screen on successful authentication
          sessionProvider.setUser(
            id: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? 'User',
          );

          Navigator.of(context).pushReplacement(
            PageTransitions.fadeSlide(const HomeScreen()),
          );
        } else if (mounted) {
          // Only allow demo mode fallback if Firebase is explicitly not initialized
          if (!authProvider.isFirebaseInitialized &&
              _emailController.text == 'test@test.com' &&
              _passwordController.text == 'password123') {
            // In demo mode with test credentials, simulate a successful login
            sessionProvider.setUser(
              id: '12345',
              email: _emailController.text,
              name: 'Demo User',
            );

            Navigator.of(context).pushReplacement(
              PageTransitions.fadeSlide(const HomeScreen()),
            );
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.error ?? 'Authentication failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();

    final user = await authProvider.signInWithGoogle();

    if (user != null && mounted) {
      // Only proceed to home screen on successful authentication
      sessionProvider.setUser(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'User',
      );

      Navigator.of(context).pushReplacement(
        PageTransitions.fadeSlide(const HomeScreen()),
      );
    } else if (mounted) {
      // Only allow demo mode fallback if Firebase is explicitly not initialized
      if (!authProvider.isFirebaseInitialized) {
        // In demo mode, we'll just simulate a successful login with Google
        sessionProvider.setUser(
          id: '12345',
          email: 'google@example.com',
          name: 'Google User',
        );

        Navigator.of(context).pushReplacement(
          PageTransitions.fadeSlide(const HomeScreen()),
        );
      } else if (authProvider.error != null) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error!),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Generic error when no specific error message is available
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();

    final user = await authProvider.signInWithApple();

    if (user != null && mounted) {
      // Only proceed to home screen on successful authentication
      sessionProvider.setUser(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'Apple User',
      );

      Navigator.of(context).pushReplacement(
        PageTransitions.fadeSlide(const HomeScreen()),
      );
    } else if (mounted) {
      // Only allow demo mode fallback if Firebase is explicitly not initialized
      if (!authProvider.isFirebaseInitialized) {
        // In demo mode, we'll just simulate a successful login with Apple
        sessionProvider.setUser(
          id: '12345',
          email: 'apple@example.com',
          name: 'Apple User',
        );

        Navigator.of(context).pushReplacement(
          PageTransitions.fadeSlide(const HomeScreen()),
        );
      } else if (authProvider.error != null) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error!),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Generic error when no specific error message is available
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple Sign-In failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and Title
                  const Icon(
                    Icons.directions_car,
                    size: 80,
                    color: Color(0xFF1E88E5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LitStop',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Ride-Along Companion',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Warning about demo mode if Firebase is not initialized
                  if (!authProvider.isFirebaseInitialized)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[700]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.amber[800]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Demo Mode Active',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Firebase is not properly configured. You can use test credentials (test@test.com / password123) to log in.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Sign in with Google button
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _handleGoogleSignIn,
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Image.asset(
                        'assets/images/google_logo.png',
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.g_mobiledata, size: 24);
                        },
                      ),
                    ),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black87
                                  : Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : Colors.grey[800],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign in with Apple button (iOS only)
                  if (Platform.isIOS)
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _handleAppleSignIn,
                      icon: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.apple,
                          size: 28,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : Colors.white,
                        ),
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Sign in with Apple',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.white
                                : Colors.grey[800],
                      ),
                    ),

                  if (Platform.isIOS) const SizedBox(height: 16),

                  // Divider with text
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.5),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.5),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isRegistering && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password link
                  if (!_isRegistering) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  PageTransitions.slideUp(
                                      const ForgotPasswordScreen()),
                                );
                              },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Login/Register Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleEmailPasswordAuth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isRegistering ? 'Register' : 'Login',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Switch between login and register
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              _isRegistering = !_isRegistering;
                            });
                          },
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Login'
                          : 'Don\'t have an account? Register',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
