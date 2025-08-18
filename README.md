# LitStop - Ride-Along Companion App

LitStop is a mobile application built with Flutter and Dart, designed to help rideshare and taxi drivers maximize their efficiency and earnings through data-driven insights and smart route planning.

## Features

- **Live Map Dashboard**
  - Real-time location tracking
  - Highlighted high-demand zones
  - Session start/stop and rest mode controls

- **Smart Route Suggestions**
  - Zone-based pickup recommendations
  - Heatmap visualization of rider density
  - Alternate route suggestions

- **Demand Forecast**
  - Hourly demand predictions
  - Peak hour identification
  - Zone-specific analytics

- **Rest & Refuel Helper**
  - Nearby rest area suggestions
  - Gas station locations
  - Fatigue alerts

- **Session Management**
  - Session duration tracking
  - Earnings calculation
  - Performance metrics
  - Historical session data

## Tech Stack

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Maps**: Google Maps Flutter
- **Charts**: fl_chart
- **Local Storage**: Shared Preferences, SQLite
- **Location Services**: Geolocator
- **Notifications**: flutter_local_notifications

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode
- Google Maps API key

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/litstop.git
   cd litstop
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Google Maps:
   - Get a Google Maps API key
   - Add the key to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   └── session_history_screen.dart
├── widgets/
│   ├── demand_forecast_panel.dart
│   └── rest_stop_helper.dart
├── providers/
│   ├── location_provider.dart
│   └── session_provider.dart
├── models/
├── services/
└── utils/
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Google Maps for location services
- All contributors and maintainers
