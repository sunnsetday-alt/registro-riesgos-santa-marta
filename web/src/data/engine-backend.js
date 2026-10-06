// Backend completo sin servidor: aplica en el cliente las mismas reglas que
// la base de datos Supabase (código, sector, prioridad, duplicados,
// historial, notificaciones, permisos por rol).
import {
  CATEGORIES, SECTORS, SETTINGS, STAFF_ROLES, insideDistrict, statusOf,
} from './catalog.js';
import {
  DAY, computePriority, dashboardStats, detectDuplicates, distanceM, findSector,
  priorityLevel, publicStats, reportCode,
} from './engine.js';
import { uuid } from './stores.js';

const nowIso = () => new Date().toISOString();

export class AppError extends Error {}

export function validateDraft(d, categories) {
  const title = (d.title || '').trim();
  const desc = (d.description || '').trim();
  if (title.length < 5 || title.length > 120) throw new AppError('El título debe tener entre 5 y 120 caracteres.');
  if (desc.length < 10 || desc.length > 2000) throw new AppError('La descripción debe tener entre 10 y 2000 caracteres.');
  if (!(d.severity >= 1 && d.severity <= 5)) throw new AppError('Selecciona el nivel de importancia.');
  if (!insideDistrict(d.latitude, d.longitude)) throw new AppError('La ubicación debe estar dentro del Distrito de Santa Marta.');
  if (!categories.find((c) => c.id === d.category_id && c.active)) throw new AppError('Categoría inválida o inactiva.');
  if (d.address && d.address.length > 250) throw new AppError('La dirección admite máximo 250 caracteres.');
}

export class EngineBackend {
  /**
   * @param store LocalStore | ArtifactStore
   * @param auth  LocalAuth | ArtifactAuth
   * @param mode  'local' | 'artifact'
   */
  constructor(store, auth, mode) {
    this.store = store;
    this.auth = auth;
    this.mode = mode;
  }

  get label() {
    return this.mode === 'artifact'
      ? 'Demostración compartida: los datos se guardan en línea y los ven quienes tengan el enlace.'
      : 'Los datos se guardan en este dispositivo.';
  }
  get features() {
    return { passwordAuth: this.auth.passwordAuth, userAdmin: this.auth.canManageUsers, photosInline: false };
  }

  async init() {
    await this.store.init();
    await this.auth.init(this.store);
    if (!this.store.list('categories').length && this.mode === 'local') {
      await this.store.putMany('categories', CATEGORIES);
    }
    // Versiones anteriores cargaban datos de prueba automáticamente: se eliminan.
    if (this.mode === 'local' && !this.store.meta?.cleanedV2) {
      await this._removeTestData();
      const reset = {};
      if (!this.store.list('reports').length) {
        for (const k of Object.keys(this.store.meta || {})) if (k.startsWith('counter_')) reset[k] = 0;
        for (const t of ['history', 'observations', 'duplicates', 'notifications']) {
          for (const row of this.store.list(t)) await this.store.remove(t, row.id);
        }
      }
      await this.store.setMeta({ ...reset, cleanedV2: true, seeded: true });
    }
    // Pide al navegador no borrar los datos guardados en este dispositivo.
    try { await navigator.storage?.persist?.(); } catch {}
  }
  onChange(fn) { return this.store.onChange(fn); }

  // ----------------------------------------------------------- utilidades
  get settings() { return { ...SETTINGS, ...(this.store.meta?.settings || {}) }; }
  categories(includeInactive = false) {
    const list = this.store.list('categories').length ? this.store.list('categories') : CATEGORIES;
    return [...list].filter((c) => includeInactive || c.active).sort((a, b) => a.order - b.order || a.name.localeCompare(b.name));
  }
  sectors() { return SECTORS; }
  async me() { return this.auth.current(); }
  async _requireUser() {
    const u = await this.auth.current();
    if (!u) throw new AppError('Debes iniciar sesión.');
    if (u.is_active === false) throw new AppError('Tu cuenta está inactiva.');
    return u;
  }
  async _requireStaff() {
    const u = await this._requireUser();
    if (!STAFF_ROLES.includes(u.role)) throw new AppError('No tienes permisos para realizar esta acción.');
    return u;
  }
  async _requireAdmin() {
    const u = await this._requireUser();
    if (u.role !== 'admin') throw new AppError('Solo un administrador puede realizar esta acción.');
    return u;
  }
  _ctx() {
    return {
      reports: this.store.list('reports'),
      duplicates: this.store.list('duplicates'),
      categories: this.categories(true),
      settings: this.settings,
    };
  }
  async _refreshPriority(id) {
    const r = this.store.get('reports', id);
    if (!r) return;
    const score = computePriority(r, this._ctx());
    const level = priorityLevel(score, this.settings);
    if (score !== r.priority_score || level !== r.priority_level) {
      await this.store.put('reports', { ...r, priority_score: score, priority_level: level });
    }
  }
  async _notify(userId, reportId, type, title, body) {
    await this.store.put('notifications', {
      id: uuid(), user_id: userId, report_id: reportId, type, title, body, read_at: null, created_at: nowIso(),
    });
  }
  _public(r) {
    const { user_id, admin_notes, client_uuid, ...rest } = r; // sin datos personales
    return rest;
  }
  photoUrl(r) {
    if (r.photo_url) return Promise.resolve(r.photo_url);
    return r.has_photo ? this.store.getPhoto(r.id) : Promise.resolve(null);
  }

  // ----------------------------------------------------------- lectura pública
  async publicReports(f = {}) {
    let list = this.store.list('reports').filter((r) => r.status !== 'rechazado' && !r.duplicate_of);
    list = applyFilter(list, f);
    return list.map((r) => this._public(r));
  }
  async recentPublic(n = 6) {
    return (await this.publicReports({ orderBy: 'created_at' })).slice(0, n);
  }
  async nearby(lat, lng, radius = 1500) {
    return (await this.publicReports())
      .map((r) => ({ ...r, distance: distanceM(lat, lng, r.latitude, r.longitude) }))
      .filter((r) => r.distance <= radius).sort((a, b) => a.distance - b.distance).slice(0, 10);
  }
  async publicStats() { return publicStats(await this.publicReports()); }

  // ----------------------------------------------------------- ciudadano
  async myReports() {
    const u = await this._requireUser();
    return this.store.list('reports').filter((r) => r.user_id === u.id).sort(byDate);
  }
  async report(id) {
    const u = await this._requireUser();
    const r = this.store.get('reports', id);
    if (!r) return null;
    if (r.user_id !== u.id && !STAFF_ROLES.includes(u.role)) return this._public(r);
    return r;
  }
  async history(id) {
    const u = await this._requireUser();
    const staff = STAFF_ROLES.includes(u.role);
    const rows = this.store.list('history').filter((h) => h.report_id === id).sort((a, b) => a.created_at.localeCompare(b.created_at));
    return Promise.all(rows.map(async (h) => ({ ...h, changed_by_name: staff ? await this.auth.nameOf(h.changed_by) : null })));
  }
  async observations(id) {
    const u = await this._requireUser();
    const staff = STAFF_ROLES.includes(u.role);
    const rows = this.store.list('observations')
      .filter((o) => o.report_id === id && (staff || o.is_public))
      .sort((a, b) => a.created_at.localeCompare(b.created_at));
    return Promise.all(rows.map(async (o) => ({ ...o, author_name: staff ? await this.auth.nameOf(o.author_id) : null })));
  }

  /** Crea un reporte. Idempotente por client_uuid. */
  async createReport(d, { asUser, createdAt, testData = false } = {}) {
    const u = asUser || (await this._requireUser());
    const existing = this.store.list('reports').find((r) => d.client_uuid && r.client_uuid === d.client_uuid);
    if (existing) return existing;
    validateDraft(d, this.categories(true));
    if (!asUser) {
      const today = this.store.list('reports').filter((r) => r.user_id === u.id && Date.now() - Date.parse(r.created_at) < DAY).length;
      if (today >= this.settings.max_reports_per_day) throw new AppError('Has alcanzado el límite diario de reportes.');
    }
    const created = createdAt || nowIso();
    const year = new Date(created).getFullYear();
    const n = await this.store.nextCounter(year);
    const sector = findSector(d.latitude, d.longitude);
    let reportedAt = d.reported_at || created;
    const diff = Date.parse(reportedAt) - Date.parse(created);
    if (Number.isNaN(diff) || diff > 5 * 60000 || diff < -30 * DAY) reportedAt = created;
    const id = uuid();
    if (d.photo) await this.store.putPhoto(id, d.photo);
    const report = {
      id,
      code: reportCode(year, n),
      user_id: u.id,
      title: d.title.trim(),
      description: d.description.trim(),
      category_id: d.category_id,
      severity: d.severity,
      priority_score: 0,
      priority_level: 'baja',
      status: 'recibido',
      latitude: d.latitude,
      longitude: d.longitude,
      address: d.address?.trim() || null,
      sector_id: sector?.id ?? null,
      sector_name: sector?.name ?? null,
      has_photo: !!d.photo,
      photo_url: null,
      possible_duplicate: false,
      duplicate_of: null,
      is_test_data: testData,
      client_uuid: d.client_uuid || null,
      reported_at: reportedAt,
      admin_notes: null,
      created_at: created,
      updated_at: created,
      resolved_at: null,
    };
    await this.store.put('reports', report);
    await this.store.put('history', {
      id: uuid(), report_id: id, from_status: null, to_status: 'recibido', changed_by: u.id,
      note: 'Reporte creado por el ciudadano', created_at: created,
    });
    await this._notify(u.id, id, 'recibido', 'Reporte recibido',
      `Tu reporte ${report.code} "${report.title}" fue recibido. Te avisaremos cuando cambie de estado.`);
    const cands = detectDuplicates(report, this.store.list('reports'), this.settings);
    for (const c of cands) {
      await this.store.put('duplicates', { id: uuid(), report_id: id, ...c, decision: 'pendiente', decided_by: null, decided_at: null, created_at: created });
    }
    if (cands.length) await this.store.put('reports', { ...this.store.get('reports', id), possible_duplicate: true });
    await this._refreshPriority(id);
    // La concentración geográfica de los reportes cercanos cambió.
    for (const o of this.store.list('reports')) {
      if (o.id !== id && statusOf(o.status).open && distanceM(o.latitude, o.longitude, report.latitude, report.longitude) <= this.settings.geo_radius_m) {
        await this._refreshPriority(o.id);
      }
    }
    return this.store.get('reports', id);
  }

  // ----------------------------------------------------------- notificaciones
  async notifications() {
    const u = await this.auth.current();
    if (!u) return [];
    return this.store.list('notifications').filter((n) => n.user_id === u.id).sort(byDate).slice(0, 100);
  }
  async markAllRead() {
    const u = await this._requireUser();
    for (const n of this.store.list('notifications').filter((x) => x.user_id === u.id && !x.read_at)) {
      await this.store.put('notifications', { ...n, read_at: nowIso() });
    }
  }

  // ----------------------------------------------------------- administración
  async adminReports(f = {}) {
    await this._requireStaff();
    return applyFilter(this.store.list('reports'), { orderBy: 'priority_score', ...f });
  }
  async changeStatus(id, status, note, { as } = {}) {
    const u = as || (await this._requireStaff());
    const r = this.store.get('reports', id);
    if (!r) throw new AppError('Reporte no encontrado.');
    if (r.status === status) throw new AppError('El reporte ya está en ese estado.');
    const st = statusOf(status);
    const clean = (note || '').trim() || null;
    const now = nowIso();
    let resolved = r.resolved_at;
    if (status === 'atendido' || status === 'cerrado') resolved = r.resolved_at || now;
    else if (st.open) resolved = null;
    await this.store.put('reports', { ...r, status, resolved_at: resolved, updated_at: now });
    await this.store.put('history', { id: uuid(), report_id: id, from_status: r.status, to_status: status, changed_by: u.id, note: clean, created_at: now });
    if (st.notify) {
      await this._notify(r.user_id, id, status, `Reporte ${st.name.toLowerCase()}`,
        `Tu reporte ${r.code} cambió a "${st.name}".${clean ? ` Observación: ${clean}` : ''}`);
    }
    if (clean) await this.store.put('observations', { id: uuid(), report_id: id, author_id: u.id, body: clean, is_public: true, created_at: now });
    await this._refreshPriority(id);
  }
  async addObservation(id, body, isPublic = true, { as } = {}) {
    const u = as || (await this._requireStaff());
    const text = (body || '').trim();
    if (text.length < 2) throw new AppError('Escribe la observación.');
    const r = this.store.get('reports', id);
    await this.store.put('observations', { id: uuid(), report_id: id, author_id: u.id, body: text, is_public: !!isPublic, created_at: nowIso() });
    if (isPublic && r) await this._notify(r.user_id, id, 'observacion', 'Nueva actualización de tu reporte', `${r.code}: ${text.slice(0, 180)}`);
  }
  async updateReport(id, changes) {
    await this._requireStaff();
    const r = this.store.get('reports', id);
    if (!r) throw new AppError('Reporte no encontrado.');
    const next = { ...r, ...changes, updated_at: nowIso() };
    validateDraft(next, this.categories(true));
    await this.store.put('reports', next);
    await this._refreshPriority(id);
  }
  async duplicates(id) {
    await this._requireStaff();
    return this.store.list('duplicates').filter((d) => d.report_id === id).map((d) => {
      const c = this.store.get('reports', d.candidate_id);
      return { ...d, candidate_code: c?.code || '', candidate_title: c?.title || '' };
    }).sort((a, b) => b.score - a.score);
  }
  async resolveDuplicate(candId, decision) {
    const u = await this._requireStaff();
    const d = this.store.get('duplicates', candId);
    if (!d) throw new AppError('Candidato no encontrado.');
    await this.store.put('duplicates', { ...d, decision, decided_by: u.id, decided_at: decision === 'pendiente' ? null : nowIso() });
    const r = this.store.get('reports', d.report_id);
    let dupOf = r.duplicate_of;
    if (decision === 'confirmado') dupOf = d.candidate_id;
    else if (r.duplicate_of === d.candidate_id) dupOf = null;
    const pending = this.store.list('duplicates').some((x) => x.report_id === r.id && x.decision === 'pendiente');
    await this.store.put('reports', { ...r, duplicate_of: dupOf, possible_duplicate: pending });
    await this._refreshPriority(d.report_id);
    await this._refreshPriority(d.candidate_id);
  }
  async recalculatePriorities() {
    await this._requireStaff();
    const open = this.store.list('reports').filter((r) => statusOf(r.status).open);
    for (const r of open) await this._refreshPriority(r.id);
    return open.length;
  }
  async dashboard(days) {
    await this._requireStaff();
    const from = days ? new Date(Date.now() - (days - 1) * DAY) : null;
    if (from) from.setHours(0, 0, 0, 0);
    return dashboardStats(this.store.list('reports'), this.categories(true), from);
  }
  async reporter(userId) {
    await this._requireStaff();
    return this.auth.profileOf(userId);
  }
  async users(search = '') {
    await this._requireStaff();
    const ids = new Set(this.store.list('reports').map((r) => r.user_id));
    return this.auth.listUsers(search, [...ids]);
  }
  async updateUser(id, patch) {
    const me = await this._requireAdmin();
    if (id === me.id) throw new AppError('No puedes modificar tu propia cuenta.');
    return this.auth.updateUser(id, patch);
  }
  async saveCategory(cat) {
    await this._requireAdmin();
    const list = this.categories(true);
    if (!/^[a-z_]{2,40}$/.test(cat.code)) throw new AppError('El código solo admite minúsculas y _.');
    if (!/^#[0-9A-Fa-f]{6}$/.test(cat.color)) throw new AppError('El color debe tener formato #RRGGBB.');
    if (!cat.id && list.some((c) => c.code === cat.code)) throw new AppError('Ya existe una categoría con ese código.');
    const id = cat.id || Math.max(0, ...list.map((c) => c.id)) + 1;
    if (!this.store.list('categories').length) await this.store.putMany('categories', CATEGORIES);
    await this.store.put('categories', { ...cat, id, order: cat.order ?? 50 });
  }

  // ----------------------------------------------------------- utilidades de datos
  async recalcSilently() {
    for (const r of this.store.list('reports')) await this._refreshPriority(r.id);
  }
  async clearTestData() {
    await this._requireAdmin();
    return this._removeTestData();
  }
  hasTestData() { return this.store.list('reports').some((r) => r.is_test_data); }
  async _removeTestData() {
    const ids = new Set(this.store.list('reports').filter((r) => r.is_test_data).map((r) => r.id));
    for (const t of ['history', 'observations', 'notifications']) {
      for (const row of this.store.list(t).filter((x) => ids.has(x.report_id))) await this.store.remove(t, row.id);
    }
    for (const row of this.store.list('duplicates').filter((x) => ids.has(x.report_id) || ids.has(x.candidate_id))) {
      await this.store.remove('duplicates', row.id);
    }
    for (const id of ids) { await this.store.remove('reports', id); await this.store.deletePhoto?.(id); }
    for (const u of this.store.list('users').filter((x) => x.id === 'demo-admin' || x.id === 'demo-ciudadano')) {
      await this.store.remove('users', u.id);
    }
    return ids.size;
  }

  // ----------------------------------------------------------- copia de seguridad
  async exportData() {
    await this._requireAdmin();
    const out = { app: 'registro-riesgos-santa-marta', version: 1, exported_at: nowIso(), tables: {}, photos: {} };
    for (const t of ['reports', 'history', 'observations', 'duplicates', 'notifications', 'categories']) out.tables[t] = this.store.list(t);
    out.tables.users = this.store.list('users').map(({ recovery, ...u }) => u);
    for (const r of this.store.list('reports').filter((x) => x.has_photo)) out.photos[r.id] = await this.store.getPhoto(r.id);
    out.meta = this.store.meta;
    return out;
  }
  async importData(data) {
    await this._requireAdmin();
    if (data?.app !== 'registro-riesgos-santa-marta' || !data.tables) throw new AppError('El archivo no es una copia de Registro de Riesgos.');
    for (const [t, rows] of Object.entries(data.tables)) if (Array.isArray(rows)) await this.store.putMany(t, rows);
    for (const [id, url] of Object.entries(data.photos || {})) if (url) await this.store.putPhoto(id, url);
    const counters = Object.fromEntries(Object.entries(data.meta || {}).filter(([k]) => k.startsWith('counter_')));
    const merged = {};
    for (const [k, v] of Object.entries(counters)) merged[k] = Math.max(v, this.store.meta?.[k] || 0);
    await this.store.setMeta(merged);
    return (data.tables.reports || []).length;
  }
}

const byDate = (a, b) => b.created_at.localeCompare(a.created_at);

/** Filtros comunes (mapa y panel). */
export function applyFilter(list, f = {}) {
  let out = list;
  if (f.categories?.length) out = out.filter((r) => f.categories.includes(r.category_id));
  if (f.severities?.length) out = out.filter((r) => f.severities.includes(r.severity));
  if (f.statuses?.length) out = out.filter((r) => f.statuses.includes(r.status));
  if (f.sector) out = out.filter((r) => r.sector_id === f.sector);
  if (f.from) out = out.filter((r) => Date.parse(r.created_at) >= Date.parse(f.from));
  if (f.to) out = out.filter((r) => Date.parse(r.created_at) < Date.parse(f.to));
  if (f.duplicates) out = out.filter((r) => r.possible_duplicate && !r.duplicate_of);
  if (f.search) {
    const q = f.search.toLowerCase();
    out = out.filter((r) => [r.code, r.title, r.description, r.address].some((x) => (x || '').toLowerCase().includes(q)));
  }
  const key = f.orderBy || 'created_at';
  return [...out].sort((a, b) => key === 'priority_score'
    ? (b.priority_score - a.priority_score) || b.created_at.localeCompare(a.created_at)
    : b.created_at.localeCompare(a.created_at));
}
