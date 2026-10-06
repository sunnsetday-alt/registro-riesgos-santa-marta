// Pantallas del ciudadano: Inicio, Mapa, Mis reportes, Detalle, Notificaciones, Perfil.
import { ROLES, SEVERITIES, STATUSES, severityOf } from '../data/catalog.js';
import { distanceM } from '../data/engine.js';
import { locate, queue } from '../device.js';
import { MapView, severityMarker } from '../map.js';
import {
  button, categoryLabel, confirmDialog, emptyState, field, fmt, h, icon, loading, photo, priorityBadge,
  sectionTitle, severityBadge, sheet, statusChip, testBadge, timeline, toast,
} from '../ui.js';
import { V } from '../validators.js';

/** Tarjeta de reporte reutilizable. */
export function reportCard(app, r, { onClick, showPriority = false } = {}) {
  const cat = app.cat(r.category_id);
  return h('button', { type: 'button', class: 'report-card', onclick: onClick },
    photo(app.backend, r),
    h('div', { class: 'rc-body' },
      h('div', { class: 'rc-top' }, h('span', { class: 'code' }, r.code), statusChip(r.status, true)),
      h('h3', null, r.title),
      categoryLabel(cat),
      h('div', { class: 'rc-meta' },
        severityBadge(r.severity),
        showPriority ? priorityBadge(r.priority_level, r.priority_score) : null,
        r.possible_duplicate && !r.duplicate_of ? h('span', { class: 'chip dup' }, icon('content_copy', 13), 'Posible duplicado') : null,
        r.is_test_data ? testBadge() : null,
        h('small', { class: 'muted' }, fmt.relative(r.created_at)))));
}

// ------------------------------------------------------------------ INICIO
export async function homeScreen({ app }) {
  const first = (app.me?.full_name || '').split(' ')[0];
  const statsBox = h('div', { class: 'stats' }, loading());
  const recentBox = h('div', { class: 'list' }, loading());
  const nearBox = h('div', { class: 'near' }, h('p', { class: 'muted' }, 'Buscando tu ubicación…'));
  const pendingBox = h('div');
  const bell = h('a', { href: '#/notifications', class: 'icon-btn on-dark', 'aria-label': 'Notificaciones' }, icon('notifications', 22));

  const update = async () => {
    try {
      const [s, recent, notifs, pend] = await Promise.all([
        app.backend.publicStats(), app.backend.recentPublic(6), app.backend.notifications(), queue.all(),
      ]);
      const tile = (label, n, ic, cls) => h('div', { class: `stat ${cls}` }, icon(ic, 22), h('b', { class: 'num' }, String(n ?? 0)), h('span', null, label));
      statsBox.replaceChildren(
        tile('Reportes', s.total, 'assignment', 'c-ocean'), tile('Abiertos', s.open, 'pending_actions', 'c-warn'),
        tile('Atendidos', s.resolved, 'task_alt', 'c-ok'), tile('Críticos', s.critical_open, 'crisis_alert', 'c-bad'));
      recentBox.replaceChildren(...(recent.length ? recent.map((r) => reportCard(app, r, { onClick: () => openPublicReport(app, r) }))
        : [emptyState('inbox', 'Todavía no hay reportes', 'Sé el primero en reportar una problemática.')]));
      const unread = notifs.filter((n) => !n.read_at).length;
      bell.replaceChildren(icon('notifications', 22), unread ? h('span', { class: 'badge' }, String(unread)) : '');
      pendingBox.replaceChildren(pend.length ? h('a', { href: '#/my-reports', class: 'card warn-card row' }, icon('cloud_off', 22),
        h('span', null, `${pend.length} reporte(s) pendiente(s) de envío. Se enviarán al recuperar la conexión.`)) : '');
    } catch (e) {
      statsBox.replaceChildren(h('p', { class: 'muted' }, `No se pudieron cargar los datos: ${e.message}`));
      recentBox.replaceChildren();
    }
  };
  update();
  locate().then(async (loc) => {
    if (loc.error) { nearBox.replaceChildren(h('p', { class: 'muted' }, 'Activa la ubicación para ver problemáticas cerca de ti.')); return; }
    try {
      const list = await app.backend.nearby(loc.lat, loc.lng, 1500);
      nearBox.replaceChildren(...(list.length ? list.map((r) => h('button', { type: 'button', class: 'near-card', onclick: () => openPublicReport(app, r) },
        h('div', { class: 'row between' }, severityBadge(r.severity, false), h('b', { class: 'accent' }, fmt.distance(r.distance ?? distanceM(loc.lat, loc.lng, r.latitude, r.longitude))), statusChip(r.status, true)),
        h('strong', null, r.title), categoryLabel(app.cat(r.category_id))))
        : [h('p', { class: 'muted' }, 'No hay reportes a menos de 1,5 km de tu ubicación.')]));
    } catch { nearBox.replaceChildren(h('p', { class: 'muted' }, 'No se pudieron cargar las problemáticas cercanas.')); }
  });

  const el = h('div', { class: 'home' },
    h('header', { class: 'hero' },
      h('div', { class: 'hero-top' }, h('span', { class: 'hello' }, first ? `Hola, ${first}` : 'Hola'), bell),
      h('h1', null, 'Registro de Riesgos Santa Marta'),
      h('p', null, 'Reporta una problemática de tu ciudad y ayúdanos a identificar dónde se necesita atención.'),
      button('Reportar problemática', { kind: 'coral', ic: 'add_location_alt', id: 'home-report', onClick: () => { app.state.draft = null; app.go('/report/new'); } })),
    h('div', { class: 'page' },
      pendingBox,
      sectionTitle('Estadísticas generales'), statsBox,
      h('a', { href: '#/map', class: 'card map-access' }, h('span', { class: 'ma-ic' }, icon('map', 24)),
        h('span', null, h('strong', null, 'Mapa de Riesgos'), h('small', { class: 'muted block' }, 'Mira dónde se concentran las problemáticas de la ciudad.')), icon('chevron_right', 22)),
      sectionTitle('Problemáticas cercanas', h('a', { href: '#/map', class: 'link' }, 'Ver mapa')), nearBox,
      sectionTitle('Reportes recientes'), recentBox));
  return { el, update };
}

/** Ficha pública de un reporte (sin datos personales). */
export function openPublicReport(app, r, { admin = false } = {}) {
  sheet(() => h('div', { class: 'stack' },
    (r.has_photo || r.photo_url) ? photo(app.backend, r, 'wide') : null,
    h('div', { class: 'row between wrap' }, statusChip(r.status), r.is_test_data ? testBadge() : null, h('span', { class: 'code' }, r.code)),
    h('h2', { class: 'title-lg' }, r.title),
    h('div', { class: 'row wrap' }, categoryLabel(app.cat(r.category_id)), severityBadge(r.severity), admin ? priorityBadge(r.priority_level, r.priority_score) : null),
    h('p', null, r.description),
    h('div', { class: 'kvs' },
      kv('event', fmt.dateTime(r.created_at)), r.address ? kv('place', r.address) : null,
      r.sector_name ? kv('map', `Sector: ${r.sector_name}`) : null, kv('my_location', fmt.coords(r.latitude, r.longitude)),
      kv(severityOf(r.severity).icon, severityOf(r.severity).text)),
    admin ? button('Gestionar reporte', { ic: 'admin_panel_settings', full: true, onClick: () => { document.querySelector('.overlay')?.remove(); app.go(`/admin/reports/${r.id}`); } }) : null),
  { title: 'Reporte' });
}
const kv = (ic, text) => h('div', { class: 'kv-line' }, icon(ic, 18), h('span', null, text));

// ------------------------------------------------------------------ MAPA
export async function mapScreen({ app }, admin = false) {
  const key = admin ? 'adminMapFilter' : 'mapFilter';
  const box = h('div', { class: 'map-full' });
  const count = h('small', { class: 'muted' }, 'Cargando…');
  const filterBtn = h('button', { type: 'button', class: 'icon-btn glass', 'aria-label': 'Filtros', id: 'map-filters' }, icon('tune', 22));
  let map;
  let me = null;
  let selected = null;
  let fitNext = false;

  const load = async () => {
    const f = app.state[key];
    const n = Object.values(f).filter((v) => (Array.isArray(v) ? v.length : v)).length;
    filterBtn.replaceChildren(icon('tune', 22), n ? h('span', { class: 'badge' }, String(n)) : '');
    try {
      const list = admin ? await app.backend.adminReports({ ...f, orderBy: 'created_at' }) : await app.backend.publicReports(f);
      count.textContent = `${list.length} reportes`;
      if (fitNext && list.length) map.fit(list.map((r) => ({ lat: r.latitude, lng: r.longitude })));
      fitNext = false;
      const sorted = [...list].sort((a, b) => a.severity - b.severity);
      map.setMarkers([
        ...sorted.map((r) => {
          const s = severityOf(r.severity);
          return {
            lat: r.latitude, lng: r.longitude, z: r.severity,
            label: `${r.title}. Importancia ${s.label}`,
            el: severityMarker(s.color, app.cat(r.category_id)?.icon || 'report', r.severity >= 5 ? 44 : r.severity === 4 ? 38 : 32, r.id === selected),
            onClick: () => { selected = r.id; openPublicReport(app, r, { admin }); load(); },
          };
        }),
        ...(me ? [{ lat: me.lat, lng: me.lng, z: 9, el: h('span', { class: 'me-dot' }) }] : []),
      ]);
    } catch (e) { count.textContent = e.message; }
  };

  const el = h('div', { class: 'map-screen' }, box,
    h('div', { class: 'map-top' },
      h('div', { class: 'glass title-box' }, icon('map', 22), h('div', null, h('strong', null, admin ? 'Mapa completo' : 'Mapa de Riesgos'), h('br'), count)),
      filterBtn),
    h('div', { class: 'legend-box glass', 'aria-label': 'Leyenda de niveles de importancia' },
      [...SEVERITIES].reverse().map((s) => h('div', { class: 'row tight' }, h('i', { class: 'dot', style: { background: s.color } }), `${s.level} ${s.label}`))),
    h('button', {
      type: 'button', class: 'fab', 'aria-label': 'Ir a mi ubicación', id: 'map-locate',
      onclick: async () => {
        const l = await locate();
        if (l.error) { toast(l.error, 'error'); return; }
        me = l; map.setView(l, 15); load();
      },
    }, icon('my_location', 24)));
  filterBtn.onclick = () => openFilters(app, key, admin, () => { fitNext = true; load(); });
  requestAnimationFrame(() => {
    map = new MapView(box, { zoom: 13 });
    load();
  });
  return { el, update: load, destroy: () => map?.destroy() };
}

function openFilters(app, key, admin, onApply) {
  const f = JSON.parse(JSON.stringify(app.state[key] || {}));
  const toggle = (arr, v) => (arr?.includes(v) ? arr.filter((x) => x !== v) : [...(arr || []), v]);
  const chips = (items, field, label, color, ic) => h('div', { class: 'chips' }, items.map((it) => {
    const b = h('button', { type: 'button', class: `chip-btn${f[field]?.includes(it.v) ? ' on' : ''}`, style: { '--c': color(it) }, 'aria-pressed': String(!!f[field]?.includes(it.v)) },
      ic ? icon(ic(it), 16) : null, label(it));
    b.onclick = () => { f[field] = toggle(f[field], it.v); b.classList.toggle('on'); b.setAttribute('aria-pressed', String(f[field].includes(it.v))); };
    return b;
  }));
  const from = h('input', { type: 'date', id: 'f-from', value: f.from ? f.from.slice(0, 10) : '' });
  const to = h('input', { type: 'date', id: 'f-to', value: f.to ? new Date(Date.parse(f.to) - 86400000).toISOString().slice(0, 10) : '' });
  const sector = h('select', { id: 'f-sector' }, h('option', { value: '' }, 'Todos los sectores'),
    app.backend.sectors().map((s) => h('option', { value: String(s.id) }, s.name)));
  sector.value = f.sector ? String(f.sector) : '';
  const preset = (days) => {
    from.value = days ? new Date(Date.now() - days * 86400000).toISOString().slice(0, 10) : '';
    to.value = '';
  };
  sheet((api) => h('div', { class: 'stack' },
    h('h4', null, 'Categoría'),
    chips(app.categories().map((c) => ({ v: c.id, c })), 'categories', (i) => i.c.name, (i) => i.c.color, (i) => i.c.icon),
    h('h4', null, 'Nivel de importancia'),
    chips(SEVERITIES.map((s) => ({ v: s.level, s })), 'severities', (i) => `${i.s.level} ${i.s.label}`, (i) => i.s.color),
    h('h4', null, 'Estado'),
    chips(STATUSES.filter((s) => admin || s.code !== 'rechazado').map((s) => ({ v: s.code, s })), 'statuses', (i) => i.s.name, (i) => i.s.color, (i) => i.s.icon),
    h('h4', null, 'Fecha'),
    h('div', { class: 'chips' }, [['Todas', 0], ['7 días', 7], ['30 días', 30], ['90 días', 90]].map(([l, d]) => h('button', { type: 'button', class: 'chip-btn', onclick: () => preset(d) }, l))),
    h('div', { class: 'grid2' }, field('Desde', from), field('Hasta', to)),
    h('h4', null, 'Sector'), sector,
    h('div', { class: 'row end sticky-actions' },
      button('Limpiar', { kind: 'ghost', id: 'f-clear', onClick: () => { app.state[key] = {}; api.close(); onApply(); } }),
      button('Aplicar filtros', { id: 'f-apply', onClick: () => {
        f.from = from.value ? new Date(`${from.value}T00:00:00`).toISOString() : null;
        f.to = to.value ? new Date(Date.parse(`${to.value}T00:00:00`) + 86400000).toISOString() : null;
        f.sector = sector.value ? Number(sector.value) : null;
        app.state[key] = f; api.close(); onApply();
      } }))), { title: 'Filtros' });
}

// ------------------------------------------------------------------ MIS REPORTES
export async function myReportsScreen({ app }) {
  const list = h('div', { class: 'list' }, loading());
  const pend = h('div');
  const update = async () => {
    const [rows, queued] = await Promise.all([app.backend.myReports(), queue.all()]);
    pend.replaceChildren(queued.length ? h('div', { class: 'card warn-card stack' },
      h('div', { class: 'row' }, icon('cloud_off', 22), h('strong', null, `${queued.length} reporte(s) guardado(s) sin conexión`)),
      h('p', null, 'Reporte guardado. Se enviará automáticamente cuando recuperes la conexión.'),
      queued.map((q) => h('small', { class: 'muted block' }, `• ${q.title}`)),
      button('Enviar ahora', { kind: 'ghost', onClick: () => app.syncQueue() })) : '');
    list.replaceChildren(...(rows.length ? rows.map((r) => reportCard(app, r, { onClick: () => app.go(`/my-reports/${r.id}`) }))
      : [emptyState('assignment', 'Aún no tienes reportes', 'Cuando reportes una problemática podrás seguir su estado aquí.',
        button('Reportar problemática', { ic: 'add', onClick: () => { app.state.draft = null; app.go('/report/new'); } }))]));
  };
  update().catch((e) => list.replaceChildren(h('p', { class: 'muted' }, e.message)));
  return { el: h('div', { class: 'page' }, h('header', { class: 'page-head' }, h('h1', null, 'Mis reportes')), pend, list), update };
}

// ------------------------------------------------------------------ DETALLE
export function reportInfo(app, r) {
  const cat = app.cat(r.category_id);
  const mini = h('div', { class: 'map-box small' });
  requestAnimationFrame(() => {
    const m = new MapView(mini, { center: { lat: r.latitude, lng: r.longitude }, zoom: 16, interactive: false });
    m.setMarkers([{ lat: r.latitude, lng: r.longitude, el: h('span', { class: 'pin-mk', style: { color: severityOf(r.severity).color } }, icon('location_on', 42)) }]);
  });
  return h('div', { class: 'stack' },
    (r.has_photo || r.photo_url) ? photo(app.backend, r, 'wide') : null,
    h('div', { class: 'row between wrap' }, h('span', { class: 'code' }, r.code), r.is_test_data ? testBadge() : null, statusChip(r.status)),
    h('h2', { class: 'title-lg' }, r.title),
    h('div', { class: 'row wrap' }, categoryLabel(cat), severityBadge(r.severity)),
    h('section', { class: 'card stack' },
      h('h3', null, 'Descripción'), h('p', null, r.description), h('hr'),
      kv('priority_high', `Importancia: ${severityOf(r.severity).label}`),
      kv('event', `Reportado: ${fmt.dateTime(r.created_at)}`),
      r.resolved_at ? kv('task_alt', `Resuelto: ${fmt.dateTime(r.resolved_at)}`) : null,
      r.address ? kv('place', r.address) : null,
      r.sector_name ? kv('map', `Sector: ${r.sector_name}`) : null,
      kv('my_location', fmt.coords(r.latitude, r.longitude))),
    mini);
}

export async function reportDetailScreen({ app, params }) {
  const body = h('div', { class: 'stack' }, loading());
  const update = async () => {
    const r = await app.backend.report(params.id);
    if (!r) { body.replaceChildren(emptyState('search_off', 'Reporte no encontrado')); return; }
    const [hist, obs] = await Promise.all([app.backend.history(r.id), app.backend.observations(r.id)]);
    body.replaceChildren(reportInfo(app, r), sectionTitle('Historial y actualizaciones'), h('section', { class: 'card' }, timeline(hist, obs)));
  };
  update().catch((e) => body.replaceChildren(h('p', null, e.message)));
  return {
    el: h('div', { class: 'page' }, h('header', { class: 'page-head' },
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Volver', onclick: () => app.go('/my-reports') }, icon('arrow_back', 22)),
      h('h1', null, 'Detalle del reporte')), body),
    update,
  };
}

// ------------------------------------------------------------------ NOTIFICACIONES
export async function notificationsScreen({ app }) {
  const list = h('div', { class: 'list' }, loading());
  const update = async () => {
    const rows = await app.backend.notifications();
    list.replaceChildren(...(rows.length ? rows.map((n) => {
      const st = STATUSES.find((s) => s.code === n.type);
      return h('button', { type: 'button', class: `notif${n.read_at ? '' : ' unread'}`, onclick: () => n.report_id && app.go(`/my-reports/${n.report_id}`) },
        h('span', { class: 'notif-ic', style: { '--c': st?.color || 'var(--turq)' } }, icon(st?.icon || 'chat', 20)),
        h('span', null, h('strong', null, n.title), h('span', { class: 'block' }, n.body), h('small', { class: 'muted' }, fmt.relative(n.created_at))));
    }) : [emptyState('notifications', 'Sin notificaciones')]));
  };
  update();
  return {
    el: h('div', { class: 'page' }, h('header', { class: 'page-head' },
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Volver', onclick: () => history.back() }, icon('arrow_back', 22)),
      h('h1', null, 'Notificaciones'),
      button('Marcar leídas', { kind: 'ghost', id: 'n-read', onClick: async () => { await app.backend.markAllRead(); update(); } })), list),
    update,
  };
}

// ------------------------------------------------------------------ PERFIL
export async function profileScreen({ app }) {
  const p = app.me;
  const initials = (p.full_name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((x) => x[0].toUpperCase()).join('');
  const tile = (ic, text, onClick, id) => h('button', { type: 'button', class: 'tile', onclick: onClick, id }, icon(ic, 22), h('span', null, text), icon('chevron_right', 20));
  const notifState = 'Notification' in window ? Notification.permission : 'unsupported';
  return h('div', { class: 'page' },
    h('header', { class: 'page-head' }, h('h1', null, 'Perfil')),
    h('section', { class: 'card row' },
      h('span', { class: 'avatar' }, initials),
      h('div', null, h('strong', { class: 'block' }, p.full_name || 'Ciudadano'), h('span', { class: 'muted block' }, p.email || ''),
        h('span', { class: 'chip' }, ROLES[p.role] || p.role))),
    app.isStaff ? h('a', { href: '#/admin', class: 'card admin-entry row', id: 'open-admin' }, icon('admin_panel_settings', 24), h('strong', null, 'Abrir panel administrativo'), icon('chevron_right', 22)) : null,
    sectionTitle('Cuenta'),
    app.backend.features.passwordAuth ? tile('edit', 'Editar perfil', () => app.go('/profile/edit'), 'p-edit') : null,
    tile('notifications', 'Notificaciones', () => app.go('/notifications')),
    notifState === 'default' ? tile('notifications_active', 'Activar avisos en este dispositivo', async () => {
      const r = await Notification.requestPermission();
      toast(r === 'granted' ? 'Avisos activados.' : 'No se activaron los avisos.', r === 'granted' ? 'ok' : 'info');
    }) : null,
    sectionTitle('Información'),
    tile('privacy_tip', 'Política de privacidad', () => app.go('/legal/privacidad')),
    tile('description', 'Términos y condiciones', () => app.go('/legal/terminos')),
    tile('install_mobile', 'Instalar la aplicación', () => installHelp()),
    app.backend.features.passwordAuth ? button('Cerrar sesión', { kind: 'danger-ghost', ic: 'logout', full: true, id: 'p-logout', onClick: async () => {
      if (!(await confirmDialog('¿Deseas cerrar tu sesión?', { ok: 'Cerrar sesión', danger: true }))) return;
      await app.backend.auth.signOut(); app.me = null; app.go('/login');
    } }) : null,
    h('p', { class: 'center muted small' }, 'Registro de Riesgos Santa Marta · v1.0.0'));
}

export function installHelp() {
  const prompt = globalThis.__installPrompt;
  sheet(() => h('div', { class: 'stack' },
    prompt ? button('Instalar ahora', { ic: 'install_mobile', full: true, onClick: async () => { prompt.prompt(); await prompt.userChoice; globalThis.__installPrompt = null; } }) : null,
    h('p', null, h('strong', null, 'Android (Chrome): '), 'menú ⋮ → “Instalar aplicación” o “Agregar a pantalla principal”.'),
    h('p', null, h('strong', null, 'iPhone (Safari): '), 'botón Compartir → “Agregar a pantalla de inicio”.'),
    h('p', null, h('strong', null, 'Computador (Chrome/Edge): '), 'ícono de instalar en la barra de direcciones.')), { title: 'Instalar la aplicación' });
}

export async function editProfileScreen({ app }) {
  const name = h('input', { id: 'e-name', type: 'text', value: app.me.full_name || '', maxlength: '120' });
  const phone = h('input', { id: 'e-phone', type: 'tel', value: app.me.phone || '', maxlength: '20' });
  const pass = h('input', { id: 'e-pass', type: 'password', autocomplete: 'new-password' });
  const fName = field('Nombre completo', name); const fPhone = field('Teléfono', phone, { optional: true });
  const fPass = field('Nueva contraseña', pass, { hint: 'Mínimo 8 caracteres, con letras y números.' });
  return h('div', { class: 'page narrow' },
    h('header', { class: 'page-head' },
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Volver', onclick: () => app.go('/profile') }, icon('arrow_back', 22)),
      h('h1', null, 'Editar perfil')),
    h('form', { class: 'stack card', novalidate: true, onsubmit: async (e) => {
      e.preventDefault();
      fName.setError(V.fullName(name.value)); fPhone.setError(V.phone(phone.value));
      if (V.fullName(name.value) || V.phone(phone.value)) return;
      try { await app.backend.auth.updateProfile({ full_name: name.value, phone: phone.value }); await app.refreshMe(); toast('Perfil actualizado', 'ok'); app.go('/profile'); }
      catch (err) { toast(err.message, 'error'); }
    } }, fName, fPhone, button('Guardar cambios', { type: 'submit', full: true, id: 'e-save' })),
    sectionTitle('Cambiar contraseña'),
    h('form', { class: 'stack card', novalidate: true, onsubmit: async (e) => {
      e.preventDefault();
      fPass.setError(V.password(pass.value));
      if (V.password(pass.value)) return;
      try { await app.backend.auth.changePassword(pass.value); pass.value = ''; toast('Contraseña actualizada', 'ok'); }
      catch (err) { toast(err.message, 'error'); }
    } }, fPass, button('Actualizar contraseña', { type: 'submit', kind: 'ghost', full: true })),
    h('p', { class: 'muted small' }, 'Tu nombre, correo y teléfono son privados: solo los ve el personal autorizado y nunca aparecen en el mapa público.'));
}
