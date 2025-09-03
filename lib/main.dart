import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'providers/location_provider.dart';
import 'providers/session_provider.dart';
import 'providers/forecast_provider.dart';
import 'providers/heatmap_provider.dart';
import 'providers/event_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/secure_data_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/route_suggestions_provider.dart';
import 'providers/fatigue_monitoring_provider.dart';
import 'providers/provider_status_provider.dart';
import 'services/api_service.dart';
import 'services/provider_status_service.dart';
import 'utils/secure_storage.dart';
import 'widgets/fatigue_alert_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize secure storage first
  final secureStorage = SecureStorage();
  await secureStorage.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    // Try to create test user in Firebase Auth
    try {
      await createTestUserIfNeeded();
    } catch (e) {
      print('Failed to create test user: $e');
    }
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue without Firebase for demo purposes
  }
  runApp(const MyApp());
}

// Create a test user in Firebase if it doesn't exist already
Future<void> createTestUserIfNeeded() async {
  try {
    final auth = firebase_auth.FirebaseAuth.instance;

    // Try to create a test user
    try {
      print('Attempting to create test user...');
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: 'test@test.com',
        password: 'password123',
      );
      print(
          'Test user created successfully with ID: ${userCredential.user?.uid}');
      await auth.signOut(); // Sign out after creation
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException &&
          e.code == 'email-already-in-use') {
        // User already exists, which is fine
        print('Test user already exists');
      } else {
        print('Error creating test user: $e');
        // We'll still continue even if this fails
      }
    }
  } catch (e) {
    print('Error in createTestUserIfNeeded: $e');
    // We catch but don't rethrow to ensure the app continues even if test user creation fails
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => ForecastProvider()),
        ChangeNotifierProvider(create: (_) => HeatmapProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) {
          // Initialize secure data provider
          final provider = SecureDataProvider();
          provider.initialize();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          // Initialize POI provider
          final provider = POIProvider(
            apiKeyPOI:
                'your-openrouteservice-api-key', // Replace with actual key
            apiKeyGas: 'your-zyla-api-key', // Replace with actual key
          );
          provider.initialize();
          return provider;
        }),
        ProxyProvider2<HeatmapProvider, LocationProvider,
            RouteSuggestionsProvider>(
          create: (context) => RouteSuggestionsProvider(
            heatmapProvider: context.read<HeatmapProvider>(),
            locationProvider: context.read<LocationProvider>(),
          ),
          update: (context, heatmapProvider, locationProvider, previous) =>
              previous ??
              RouteSuggestionsProvider(
                heatmapProvider: heatmapProvider,
                locationProvider: locationProvider,
              ),
        ),
        ChangeNotifierProvider(create: (_) => FatigueMonitoringProvider()),
        ChangeNotifierProvider(create: (context) {
          final provider = ProviderStatusProvider();
          // Configure backend proxy to celesti-nav.com and attach Firebase ID token
          final api =
              ApiService(baseUrl: 'https://celesti-nav.com', apiKey: null);
          provider.setService(ProviderStatusService(
            api: api,
            tokenSupplier: () async {
              final auth = context.read<AuthProvider>();
              return await auth.user?.getIdToken();
            },
          ));
          return provider;
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return FatigueAlertManager(
            child: MaterialApp(
              title: 'LitStop',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
