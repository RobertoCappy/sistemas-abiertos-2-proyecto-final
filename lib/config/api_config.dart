/// Dirección de la API que corre en el servidor Rocky Linux.
///
/// Si la IP de Rocky cambia, no hace falta tocar el código: se pasa al correr
/// la app con --dart-define=API_URL=http://NUEVA_IP:3000
///
/// Si se compila con --dart-define=API_URL= (vacío), la app usa la misma
/// dirección desde donde se abrió. Eso sirve cuando el servidor Rocky entrega
/// la app (por ejemplo, por internet con ngrok).
class ApiConfig {
  static const String _definida = String.fromEnvironment(
    'API_URL',
    // Dirección pública y fija del servidor Rocky (ngrok). Con esto, al
    // presionar Run en Android Studio o al crear el APK, la app ya se conecta
    // sin escribir nada más. Para usar otro servidor:
    // --dart-define=API_URL=http://IP:3000
    defaultValue: 'https://little-regain-coyness.ngrok-free.dev',
  );

  static String get baseUrl =>
      _definida.isEmpty ? Uri.base.origin : _definida;

  static const Duration timeout = Duration(seconds: 10);
}
