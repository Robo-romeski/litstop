import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'providers/journey_provider.dart';
import 'services/api_service.dart';
import 'services/journey_geocoder.dart';
import 'services/place_service.dart';
import 'services/provider_status_service.dart';
import 'services/routes_service.dart';
import 'services/busy_zone_selector.dart';
import 'services/constraint_poi.dart';
import 'services/journey_store.dart';
import 'config/maps_config.dart';
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
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue without Firebase for demo purposes
  }
  runApp(const MyApp());
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
          final tts = FlutterTts();
          return JourneyProvider(
            locator: PlaceStopLocator(places: PlaceService()),
            router: MapsConfig.hasKey ? RoutesService() : null,
            zoneSupplier: () {
              final heatmap = context.read<HeatmapProvider>();
              final events = context.read<EventProvider>();
              final position = context.read<LocationProvider>().currentPosition;
              return buildPredictedBusyZones(
                now: DateTime.now(),
                hotspots: heatmap.hotspots,
                eventLocations: [
                  for (final event in events.events)
                    if (event.location != null) event.location!,
                ],
                fallbackCenter: position == null
                    ? null
                    : LatLng(position.latitude, position.longitude),
              );
            },
            speak: (text) async {
              try {
                await tts.setLanguage('en-US');
                await tts.speak(text);
              } catch (_) {}
            },
            store: SharedPreferencesJourneyStore(),
            autoTick: const Duration(seconds: 30),
            needsRest: () =>
                context.read<FatigueMonitoringProvider>().shouldTakeBreak,
            findConstraint: (kind, from) async {
              final poi = context.read<POIProvider>();
              return pickConstraintPoi(
                kind: kind,
                from: from,
                pois: poi.pois,
                stations: poi.gasStations,
              );
            },
          );
        }),
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
