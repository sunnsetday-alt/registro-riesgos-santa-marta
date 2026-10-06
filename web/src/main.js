// Punto de entrada de la aplicación web (PWA) "Registro de Riesgos Santa Marta".
import { app } from './app.js';
import { ArtifactAuth, LocalAuth } from './data/auth.js';
import { EngineBackend } from './data/engine-backend.js';
import { ArtifactStore, LocalStore } from './data/stores.js';
import { SupabaseBackend } from './data/supabase-backend.js';
import { systemNotify } from './device.js';
import * as A from './screens/admin.js';
import { forgotScreen, legalScreen, loginScreen, registerScreen } from './screens/auth.js';
import * as C from './screens/citizen.js';
import { confirmScreen, newReportScreen, successScreen } from './screens/report-form.js';
import { h, loading, toast } from './ui.js';

const cfg = globalThis.RSM_CONFIG || {};

/**
 * Elige dónde se guardan los datos:
 *  1. Supabase, si config.js tiene SUPABASE_URL y SUPABASE_ANON_KEY (producción).
 *  2. La base compartida del enlace de demostración en claude.ai, si existe.
 *  3. Este dispositivo (modo demostración sin servidor).
 */
async function createBackend() {
  if (cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY) return new SupabaseBackend({ url: cfg.SUPABASE_URL, anonKey: cfg.SUPABASE_ANON_KEY });
  if (globalThis.claude?.use) {
    const db = await globalThis.claude.use('db').catch(() => null);
    if (db) {
      const user = await globalThis.claude.use('user').catch(() => null);
      return new EngineBackend(new ArtifactStore(db), new ArtifactAuth(user), 'artifact');
    }
  }
  return new EngineBackend(new LocalStore(), new LocalAuth(), 'local');
}

function routes() {
  const r = app.route.bind(app);
  r('/login', loginScreen, { public: true, authOnly: true, title: 'Iniciar sesión' });
  r('/register', registerScreen, { public: true, authOnly: true, title: 'Crear cuenta' });
  r('/forgot', forgotScreen, { public: true, authOnly: true, title: 'Recuperar contraseña' });
  r('/legal/:doc', legalScreen, { public: true, title: 'Información legal' });
  r('/home', C.homeScreen, { shell: 'citizen', nav: 'home', title: 'Inicio' });
  r('/map', (ctx) => C.mapScreen(ctx), { shell: 'citizen', nav: 'map', title: 'Mapa de Riesgos' });
  r('/report/new', newReportScreen, { shell: 'citizen', nav: 'report', title: 'Reportar problemática' });
  r('/report/confirm', confirmScreen, { shell: 'citizen', nav: 'report', title: 'Confirmar reporte' });
  r('/report/success', successScreen, { shell: 'citizen', nav: 'report', title: 'Reporte enviado' });
  r('/my-reports', C.myReportsScreen, { shell: 'citizen', nav: 'mine', title: 'Mis reportes' });
  r('/my-reports/:id', C.reportDetailScreen, { shell: 'citizen', nav: 'mine', title: 'Detalle del reporte' });
  r('/notifications', C.notificationsScreen, { shell: 'citizen', nav: 'home', title: 'Notificaciones' });
  r('/profile', C.profileScreen, { shell: 'citizen', nav: 'profile', title: 'Perfil' });
  r('/profile/edit', C.editProfileScreen, { shell: 'citizen', nav: 'profile', title: 'Editar perfil' });
  r('/admin', A.dashboardScreen, { shell: 'admin', nav: 'dash', admin: true, title: 'Dashboard' });
  r('/admin/reports', A.adminReportsScreen, { shell: 'admin', nav: 'reports', admin: true, title: 'Reportes' });
  r('/admin/reports/:id', A.adminReportScreen, { shell: 'admin', nav: 'reports', admin: true, title: 'Gestionar reporte' });
  r('/admin/map', (ctx) => C.mapScreen(ctx, true), { shell: 'admin', nav: 'map', admin: true, title: 'Mapa completo' });
  r('/admin/users', A.usersScreen, { shell: 'admin', nav: 'users', admin: true, title: 'Usuarios' });
  r('/admin/categories', A.categoriesScreen, { shell: 'admin', nav: 'cats', admin: true, title: 'Categorías' });
}

/** Avisa de notificaciones nuevas (cambios de estado de mis reportes). */
async function watchNotifications() {
  if (!app.me) return;
  let seen;
  try { seen = new Set(JSON.parse(localStorage.getItem('rsm:seen') || '[]')); } catch { seen = new Set(); }
  const first = !localStorage.getItem('rsm:seen');
  const list = await app.backend.notifications().catch(() => []);
  for (const n of list) {
    if (seen.has(n.id)) continue;
    seen.add(n.id);
    if (!first && !n.read_at) { toast(`${n.title}: ${n.body}`, 'ok'); systemNotify(n.title, n.body); }
  }
  try { localStorage.setItem('rsm:seen', JSON.stringify([...seen].slice(-300))); } catch {}
}

async function boot() {
  const root = document.getElementById('app');
  root.replaceChildren(h('div', { class: 'boot' }, loading('Cargando Registro de Riesgos…')));
  try {
    app.backend = await createBackend();
    await app.backend.init();
    await app.refreshMe();
  } catch (e) {
    root.replaceChildren(h('div', { class: 'center-card' }, h('h1', null, 'No se pudo iniciar'), h('p', null, e.message),
      h('button', { class: 'btn primary', onclick: () => location.reload() }, 'Reintentar')));
    return;
  }
  document.documentElement.dataset.mode = app.backend.mode;
  routes();
  window.addEventListener('hashchange', () => app.render());
  let timer;
  app.backend.onChange(() => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      await app.refreshMe();
      app.current?.update?.();
      watchNotifications();
    }, 200);
  });
  window.addEventListener('online', () => { toast('Conexión recuperada.', 'ok'); app.syncQueue(); });
  window.addEventListener('offline', () => toast('Sin conexión. Puedes seguir reportando: se enviará después.', 'info'));
  await app.render();
  watchNotifications();
  app.syncQueue();
}

// Instalación como aplicación (PWA).
window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); globalThis.__installPrompt = e; });
if ('serviceWorker' in navigator && location.protocol !== 'file:' && !globalThis.claude) {
  window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
}

boot();
