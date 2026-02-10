/// Central configuration for the EFB app.
///
/// All values are read from compile-time environment variables
/// via `--dart-define-from-file=.env`. Defaults are provided for
/// local development where possible.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  static const String googleMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
  );

  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
  );
}
