/// Configuración de entorno.
///
/// Los valores se inyectan en tiempo de compilación con:
///   flutter run --dart-define-from-file=env.json
///   flutter build apk --release --dart-define-from-file=env.json
///
/// No se incluyen claves en el código fuente. Ver `env.example.json`.
class Env {
  Env._();

  /// URL del proyecto Supabase (https://xxxx.supabase.co).
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Clave pública (anon). Es pública por diseño: la seguridad real la dan
  /// las políticas RLS de la base de datos.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Plantilla de teselas del mapa. Por defecto OpenStreetMap.
  /// Para Mapbox: https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}
  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Token del proveedor de mapas (solo si la plantilla lo requiere).
  static const mapAccessToken = String.fromEnvironment('MAP_ACCESS_TOKEN');

  /// Atribución que se muestra en el mapa.
  static const mapAttribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© colaboradores de OpenStreetMap',
  );

  /// Activa la sugerencia de categoría con IA (Edge Function classify-report).
  static const aiClassifierEnabled =
      bool.fromEnvironment('AI_CLASSIFIER_ENABLED', defaultValue: false);

  /// Identificador del paquete, usado como User-Agent de las teselas OSM.
  static const appPackage = 'co.santamarta.registroriesgos';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
