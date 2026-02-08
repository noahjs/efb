/// Central configuration for the EFB app.
///
/// Change [apiHost] when testing on a physical device
/// (e.g. to your machine's LAN IP like '192.168.1.109').
class AppConfig {
  AppConfig._();

  static const String apiHost = 'localhost';
  static const int apiPort = 3001;
  static const String apiBaseUrl = 'http://$apiHost:$apiPort';
}
