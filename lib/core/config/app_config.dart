class AppConfig {
  AppConfig._();

  // API REST + WebSocket de duelos en producción (Render soporta ambos).
  // Vercel no soporta WS, y cada host tiene su propio JWT_SECRET, así que
  // la app apunta a un solo host. Para desarrollo local:
  //   flutter run --dart-define=API_URL=http://10.0.2.2:4000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://colibri-back.onrender.com',
  );

  // WebSocket de duelos. Vercel serverless no soporta WS, así que en
  // producción conviene apuntar a un host con WebSocket propio. Si no se
  // define, se deriva del API_URL (útil en desarrollo local).
  static const String wsBaseUrl = String.fromEnvironment('WS_URL');

  static String get wsBase => wsBaseUrl.isNotEmpty
      ? wsBaseUrl
      : apiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
}
