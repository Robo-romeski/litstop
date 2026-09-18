class MapsConfig {
  static const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get hasKey => apiKey.isNotEmpty;
}
