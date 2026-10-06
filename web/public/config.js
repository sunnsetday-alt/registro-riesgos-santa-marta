// Configuración de la aplicación web (se puede editar SIN volver a compilar).
//
// - Deja SUPABASE_URL y SUPABASE_ANON_KEY vacíos para el MODO DEMOSTRACIÓN:
//   los datos se guardan en el dispositivo y hay cuentas de prueba.
// - Completa ambos valores (Supabase → Project Settings → API) para usar el
//   backend real compartido con la app Android. La llave "anon" es pública
//   por diseño; la seguridad la dan las reglas RLS de la base de datos.
window.RSM_CONFIG = {
  SUPABASE_URL: '',
  SUPABASE_ANON_KEY: '',
  MAP_TILE_URL: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  MAP_ACCESS_TOKEN: '',
  MAP_ATTRIBUTION: '© colaboradores de OpenStreetMap',
};
