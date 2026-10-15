class AppConfig {
  AppConfig._();

  // API REST en producción (Vercel). Para desarrollo local:
  //   flutter run --dart-define=API_URL=http://10.0.2.2:4000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://colibriback-two.vercel.app',
  );

  // WebSocket de duelos. Vercel serverless no soporta WS, así que en
  // producción conviene apuntar a un host con WebSocket propio. Si no se
  // define, se deriva del API_URL (útil en desarrollo local).
  static const String wsBaseUrl = String.fromEnvironment('WS_URL');

  static String get wsBase => wsBaseUrl.isNotEmpty
      ? wsBaseUrl
      : apiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
}
