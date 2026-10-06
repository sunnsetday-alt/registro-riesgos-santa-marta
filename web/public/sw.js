// Service worker de Registro de Riesgos Santa Marta.
// - Precarga la aplicación para que abra sin conexión.
// - Teselas del mapa: caché de respaldo (se ven las zonas ya visitadas sin red).
// - Fuentes: caché tras la primera carga.
// - API de Supabase: siempre red (nunca se sirven datos viejos desde caché).
const VERSION = '__VERSION__';
const APP_CACHE = `rsm-app-${VERSION}`;
const RUNTIME = 'rsm-runtime-v1';
const APP_FILES = __FILES__;

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(APP_CACHE).then((c) => c.addAll(APP_FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k.startsWith('rsm-app-') && k !== APP_CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

async function trimRuntime(max = 600) {
  const c = await caches.open(RUNTIME);
  const keys = await c.keys();
  for (let i = 0; i < keys.length - max; i++) await c.delete(keys[i]);
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (/supabase\.co$|supabase\.in$/.test(url.hostname) || url.pathname.includes('/rest/v1/') || url.pathname.includes('/auth/v1/')) return;

  // Aplicación propia: caché primero, actualizando en segundo plano.
  if (url.origin === self.location.origin) {
    e.respondWith((async () => {
      const cache = await caches.open(APP_CACHE);
      const hit = await cache.match(req, { ignoreSearch: true });
      const net = fetch(req).then((res) => { if (res.ok && url.pathname.endsWith('config.js')) cache.put(req, res.clone()); return res; }).catch(() => null);
      if (hit) { e.waitUntil(net); return hit; }
      const res = await net;
      if (res) return res;
      if (req.mode === 'navigate') return (await cache.match('./index.html')) || Response.error();
      return Response.error();
    })());
    return;
  }

  // Teselas del mapa y fuentes: red primero, caché como respaldo.
  if (/tile|basemaps|mapbox|fonts\.(googleapis|gstatic)\.com/.test(url.hostname)) {
    e.respondWith((async () => {
      const cache = await caches.open(RUNTIME);
      try {
        const res = await fetch(req);
        if (res.ok || res.type === 'opaque') { cache.put(req, res.clone()); e.waitUntil(trimRuntime()); }
        return res;
      } catch {
        return (await cache.match(req)) || Response.error();
      }
    })());
  }
});

// Abrir la app al tocar una notificación.
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (all[0]) return all[0].focus();
    return self.clients.openWindow('./#/notifications');
  })());
});
