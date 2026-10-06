// Estado global, enrutador y estructura de navegación.
import { STAFF_ROLES } from './data/catalog.js';
import { isNetworkError, queue, systemNotify } from './device.js';
import { h, icon, toast } from './ui.js';

export const app = {
  backend: null,
  me: null,
  state: {
    mapFilter: {},
    adminMapFilter: {},
    adminFilter: { orderBy: 'priority_score' },
    dashDays: 30,
    draft: null,
    result: null,
  },
  routes: [],
  current: null,
  pending: 0,

  get isStaff() { return !!this.me && STAFF_ROLES.includes(this.me.role) && this.me.is_active !== false; },
  get isAdmin() { return !!this.me && this.me.role === 'admin' && this.me.is_active !== false; },
  categories(all = false) { return this.backend.categories(all); },
  cat(id) { return this.backend.categories(true).find((c) => c.id === id); },
  go(path) { if (location.hash !== `#${path}`) location.hash = path; else this.render(); },
  async refreshMe() { this.me = await this.backend.me(); },

  /** Registra una ruta: patrón '/my-reports/:id'. */
  route(pattern, screen, opts = {}) {
    const keys = [];
    const re = new RegExp(`^${pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; })}$`);
    this.routes.push({ pattern, re, keys, screen, ...opts });
  },

  async render() {
    const path = location.hash.replace(/^#/, '') || '/home';
    let match = null;
    let params = {};
    for (const r of this.routes) {
      const m = path.match(r.re);
      if (m) { match = r; r.keys.forEach((k, i) => { params[k] = decodeURIComponent(m[i + 1]); }); break; }
    }
    if (!match) { this.go('/home'); return; }
    if (!match.public && !this.me) {
      if (this.backend.features.passwordAuth) { this.go('/login'); return; }
      return this._mount(noIdentity(), null);
    }
    if (match.public && match.authOnly && this.me) { this.go('/home'); return; }
    if (match.admin && !this.isStaff) { toast('Esta sección es solo para el personal autorizado.', 'error'); this.go('/home'); return; }

    this.current?.destroy?.();
    const view = h('main', { id: 'view', class: `view ${match.shell || 'bare'}`, tabindex: '-1' });
    const res = await match.screen({ params, app: this });
    const node = res instanceof Node ? res : res.el;
    view.append(node);
    this.current = res instanceof Node ? null : res;
    this._mount(view, match);
    window.scrollTo(0, 0);
  },

  _mount(view, match) {
    const root = document.getElementById('app');
    const shell = match?.shell;
    const banner = this.backend.mode !== 'supabase' ? modeBanner(this.backend) : null;
    if (shell === 'citizen') root.replaceChildren(banner || '', citizenShell(view, match.nav));
    else if (shell === 'admin') root.replaceChildren(banner || '', adminShell(view, match.nav));
    else root.replaceChildren(banner || '', view);
    document.title = `${match?.title ? `${match.title} · ` : ''}Registro de Riesgos Santa Marta`;
  },

  /** Envía los reportes guardados sin conexión. */
  async syncQueue() {
    if (!this.me || this.backend.mode === 'local') return;
    const items = await queue.all();
    this.pending = items.length;
    for (const d of items) {
      try {
        const r = await this.backend.createReport(d);
        await queue.remove(d.client_uuid);
        this.pending--;
        toast(`Reporte enviado: ${r.code}`, 'ok');
        systemNotify('Reporte enviado', `Tu reporte "${r.title}" fue enviado con el código ${r.code}.`);
      } catch (e) {
        if (isNetworkError(e)) break;
      }
    }
    this.current?.update?.();
  },
};

function noIdentity() {
  return h('div', { class: 'center-card' },
    h('h1', null, 'Registro de Riesgos Santa Marta'),
    h('p', null, 'Para reportar y ver reportes necesitas abrir este enlace con tu sesión de claude.ai iniciada.'));
}

function modeBanner(backend) {
  const key = `rsm:banner-${backend.mode}`;
  let hidden = false;
  try { hidden = sessionStorage.getItem(key) === '1'; } catch {}
  if (hidden) return null;
  const el = h('div', { class: 'mode-banner', role: 'note' },
    icon('info', 16), h('span', null, backend.label),
    h('button', { class: 'icon-btn small', 'aria-label': 'Ocultar aviso', onclick: () => { try { sessionStorage.setItem(key, '1'); } catch {} el.remove(); } }, icon('close', 16)));
  return el;
}

const CITIZEN_NAV = [
  { key: 'home', label: 'Inicio', ic: 'home', path: '/home' },
  { key: 'map', label: 'Mapa', ic: 'map', path: '/map' },
  { key: 'report', label: 'Reportar', ic: 'add', path: '/report/new', main: true },
  { key: 'mine', label: 'Mis reportes', ic: 'assignment', path: '/my-reports' },
  { key: 'profile', label: 'Perfil', ic: 'person', path: '/profile' },
];

function citizenShell(view, active) {
  const nav = h('nav', { class: 'nav citizen-nav', 'aria-label': 'Navegación principal' },
    h('a', { class: 'brand', href: '#/home' }, h('span', { class: 'brand-mark' }, icon('waves', 20)), h('span', null, 'Riesgos', h('br'), 'Santa Marta')),
    CITIZEN_NAV.map((n) => h('a', {
      href: `#${n.path}`, class: `nav-item${n.main ? ' report-btn' : ''}${active === n.key ? ' active' : ''}`,
      'aria-current': active === n.key ? 'page' : null,
    }, h('span', { class: 'nav-ic' }, icon(n.ic, n.main ? 30 : 22)), h('span', { class: 'nav-label' }, n.label))));
  return h('div', { class: 'shell' }, nav, view);
}

const ADMIN_NAV = [
  { key: 'dash', label: 'Dashboard', ic: 'dashboard', path: '/admin' },
  { key: 'reports', label: 'Reportes', ic: 'assignment', path: '/admin/reports' },
  { key: 'map', label: 'Mapa', ic: 'map', path: '/admin/map' },
  { key: 'users', label: 'Usuarios', ic: 'group', path: '/admin/users' },
  { key: 'cats', label: 'Categorías', ic: 'category', path: '/admin/categories' },
];

function adminShell(view, active) {
  const nav = h('nav', { class: 'nav admin-nav', 'aria-label': 'Panel administrativo' },
    h('a', { class: 'brand', href: '#/admin' }, h('span', { class: 'brand-mark' }, icon('admin_panel_settings', 20)), h('span', null, 'Panel', h('br'), 'administrativo')),
    ADMIN_NAV.map((n) => h('a', { href: `#${n.path}`, class: `nav-item${active === n.key ? ' active' : ''}`, 'aria-current': active === n.key ? 'page' : null },
      h('span', { class: 'nav-ic' }, icon(n.ic, 22)), h('span', { class: 'nav-label' }, n.label))),
    h('a', { href: '#/profile', class: 'nav-item exit' }, h('span', { class: 'nav-ic' }, icon('logout', 22)), h('span', { class: 'nav-label' }, 'Salir')));
  return h('div', { class: 'shell admin' }, nav, view);
}
