class AppConfig {
  AppConfig._();

  // En el emulador Android, el host se ve como 10.0.2.2.
  // En dispositivo físico: --dart-define=API_URL=http://192.168.1.x:4000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );
}
