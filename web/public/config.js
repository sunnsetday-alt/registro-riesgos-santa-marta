// Configuración de la aplicación web (se puede editar SIN volver a compilar).
//
// - Con SUPABASE_URL y SUPABASE_ANON_KEY vacíos la app funciona en MODO LOCAL:
//   los datos se guardan en el dispositivo de cada persona.
// - Completa ambos valores (Supabase → Project Settings → API) para usar el
//   backend real compartido con la app Android. La llave "anon" es pública
//   por diseño; la seguridad la dan las reglas RLS de la base de datos.
window.RSM_CONFIG = {
  SUPABASE_URL: '',
  SUPABASE_ANON_KEY: '',
  MAP_TILE_URL: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  MAP_ACCESS_TOKEN: '',
  MAP_ATTRIBUTION: '© colaboradores de OpenStreetMap',

  // Cuenta administradora del modo local. Solo se guarda una huella cifrada
  // (PBKDF2-SHA256) de la clave: la clave NO está en este archivo.
  // Para cambiarla: node tools/admin-hash.mjs "NuevaClave"  y pega el resultado.
  ADMIN_ACCOUNT: {
    email: 'admin@riesgos-santamarta.co',
    name: 'Administración',
    salt: '1391ffd658c50b72eead16311e575601',
    iterations: 310000,
    hash: '5ab27f63e315e87b9b895262f057689cca1aed139daf5e3ad65657f529cc90e8',
  },
};
