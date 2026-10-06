// Backend de producción: Supabase (el MISMO esquema que usa la app Flutter,
// ver supabase/migrations). Usa directamente la API REST de Supabase
// (Auth, PostgREST, Storage), sin librerías externas.
import { AppError } from './engine-backend.js';
import { SECTORS } from './catalog.js';
import { uuid } from './stores.js';

const ICON_FROM_DB = { road: 'add_road', water: 'water_drop', more: 'more_horiz' };
const ICON_TO_DB = { add_road: 'road', water_drop: 'water', more_horiz: 'more' };
const SESSION_KEY = 'rsm:sb-session';

function mapCategory(c) {
  return {
    id: c.id, code: c.code, name: c.name, color: c.color, icon: ICON_FROM_DB[c.icon] || c.icon,
    weight: Number(c.priority_weight), keywords: c.keywords || [], active: c.is_active, order: c.sort_order,
  };
}
function mapReport(r) {
  return {
    ...r,
    sector_name: r.sector_name ?? r.sectors?.name ?? null,
    priority_score: Number(r.priority_score || 0),
    has_photo: !!r.photo_url,
  };
}
const inList = (arr) => `in.(${arr.map((x) => (typeof x === 'number' ? x : `"${String(x).replace(/"/g, '')}"`)).join(',')})`;

export class SupabaseBackend {
  mode = 'supabase';
  label = '';

  constructor({ url, anonKey }) {
    this.url = url.replace(/\/$/, '');
    this.key = anonKey;
    this.listeners = new Set();
    this.cats = [];
    this.secs = SECTORS;
    this.profile = null;
  }
  get features() { return { passwordAuth: true, userAdmin: true, photosInline: true }; }

  // ------------------------------------------------------------- HTTP
  _session() { try { return JSON.parse(localStorage.getItem(SESSION_KEY)); } catch { return null; } }
  _setSession(s) {
    if (s?.access_token) {
      localStorage.setItem(SESSION_KEY, JSON.stringify({
        access_token: s.access_token, refresh_token: s.refresh_token,
        expires_at: s.expires_at || Math.floor(Date.now() / 1000) + (s.expires_in || 3600), user: s.user,
      }));
    } else localStorage.removeItem(SESSION_KEY);
  }
  async _token() {
    let s = this._session();
    if (!s) return null;
    if (s.expires_at - 60 < Date.now() / 1000) {
      try {
        const res = await this._raw('POST', '/auth/v1/token?grant_type=refresh_token', { refresh_token: s.refresh_token }, { auth: false });
        this._setSession(res);
        s = this._session();
      } catch (e) {
        if (!(e instanceof TypeError)) { this._setSession(null); return null; }
      }
    }
    return s.access_token;
  }
  async _raw(method, path, body, { auth = true, headers = {}, raw = false } = {}) {
    const token = auth ? await this._token() : null;
    const res = await fetch(this.url + path, {
      method,
      headers: {
        apikey: this.key,
        Authorization: `Bearer ${token || this.key}`,
        ...(body !== undefined && !(body instanceof Blob) ? { 'Content-Type': 'application/json' } : {}),
        ...headers,
      },
      body: body === undefined ? undefined : body instanceof Blob ? body : JSON.stringify(body),
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = text; }
    if (!res.ok) {
      const msg = data?.msg || data?.message || data?.error_description || data?.error || `Error ${res.status}`;
      const code = data?.code;
      if (code === '42501' || res.status === 403) throw new AppError('No tienes permisos para realizar esta acción.');
      if (/invalid login/i.test(msg)) throw new AppError('Correo o contraseña incorrectos.');
      if (/email not confirmed/i.test(msg)) throw new AppError('Debes confirmar tu correo antes de ingresar.');
      if (/already registered/i.test(msg)) throw new AppError('Ya existe una cuenta con este correo.');
      if (/expired|invalid.*token|otp/i.test(msg)) throw new AppError('El código no es válido o ya expiró.');
      throw new AppError(msg);
    }
    return raw ? res : data;
  }
  _get(path) { return this._raw('GET', `/rest/v1/${path}`); }
  _rpc(fn, params = {}) { return this._raw('POST', `/rest/v1/rpc/${fn}`, params); }

  async init() {
    try {
      const [cats, secs] = await Promise.all([
        this._get('categories?select=*&order=sort_order.asc'),
        this._get('sectors?select=*&is_active=eq.true&order=name.asc'),
      ]);
      this.cats = cats.map(mapCategory);
      this.secs = secs.map((s) => ({ id: s.id, name: s.name, lat: s.center_lat, lng: s.center_lng, r: s.radius_m }));
      localStorage.setItem('rsm:sb-catalog', JSON.stringify({ cats: this.cats, secs: this.secs }));
    } catch (e) {
      // Sin conexión: usa el último catálogo descargado.
      try {
        const c = JSON.parse(localStorage.getItem('rsm:sb-catalog'));
        this.cats = c.cats; this.secs = c.secs;
      } catch { throw e; }
    }
    await this._loadProfile();
    // Actualización periódica (notificaciones y cambios de estado).
    setInterval(() => { if (document.visibilityState === 'visible') this._emit(); }, 30000);
  }
  async _loadProfile() {
    const s = this._session();
    if (!s?.user) { this.profile = null; return; }
    try {
      const rows = await this._get(`profiles?id=eq.${s.user.id}&select=*`);
      this.profile = rows[0] ? { ...rows[0], email: s.user.email } : null;
      localStorage.setItem('rsm:sb-profile', JSON.stringify(this.profile));
    } catch {
      try { this.profile = JSON.parse(localStorage.getItem('rsm:sb-profile')); } catch { this.profile = null; }
    }
  }
  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  _emit() { for (const fn of this.listeners) fn(); }

  // ------------------------------------------------------------- auth
  auth = {
    passwordAuth: true,
    signIn: async (email, password) => {
      const s = await this._raw('POST', '/auth/v1/token?grant_type=password', { email: email.trim(), password }, { auth: false });
      this._setSession(s);
      await this._loadProfile();
    },
    signUp: async ({ email, password, full_name, phone }) => {
      const s = await this._raw('POST', '/auth/v1/signup', {
        email: email.trim(), password, data: { full_name: full_name.trim(), phone: phone?.trim() || null, accepted_terms: true },
      }, { auth: false });
      if (s?.access_token) { this._setSession(s); await this._loadProfile(); return { session: true }; }
      return { session: false };
    },
    signOut: async () => {
      try { await this._raw('POST', '/auth/v1/logout', {}); } catch {}
      this._setSession(null);
      this.profile = null;
    },
    sendRecovery: async (email) => { await this._raw('POST', '/auth/v1/recover', { email: email.trim() }, { auth: false }); return {}; },
    resetWithCode: async (email, code, password) => {
      const s = await this._raw('POST', '/auth/v1/verify', { type: 'recovery', email: email.trim(), token: code.trim() }, { auth: false });
      this._setSession(s);
      await this._raw('PUT', '/auth/v1/user', { password });
      await this._loadProfile();
    },
    changePassword: async (password) => { await this._raw('PUT', '/auth/v1/user', { password }); },
    updateProfile: async ({ full_name, phone }) => {
      await this._raw('PATCH', `/rest/v1/profiles?id=eq.${this.profile.id}`, { full_name: full_name.trim(), phone: phone?.trim() || null });
      await this._loadProfile();
    },
  };
  async me() { return this.profile; }

  // ------------------------------------------------------------- catálogos
  categories(includeInactive = false) { return this.cats.filter((c) => includeInactive || c.active); }
  sectors() { return this.secs; }
  photoUrl(r) { return Promise.resolve(r.photo_url || null); }

  _filterQuery(f = {}) {
    const q = [];
    if (f.categories?.length) q.push(`category_id=${inList(f.categories)}`);
    if (f.severities?.length) q.push(`severity=${inList(f.severities)}`);
    if (f.statuses?.length) q.push(`status=${inList(f.statuses)}`);
    if (f.sector) q.push(`sector_id=eq.${f.sector}`);
    if (f.from) q.push(`created_at=gte.${encodeURIComponent(new Date(f.from).toISOString())}`);
    if (f.to) q.push(`created_at=lt.${encodeURIComponent(new Date(f.to).toISOString())}`);
    if (f.duplicates) q.push('possible_duplicate=eq.true', 'duplicate_of=is.null');
    if (f.search) {
      const s = f.search.replace(/[,()*%]/g, ' ').trim();
      if (s) q.push(`or=(${['code', 'title', 'description', 'address'].map((c) => `${c}.ilike.*${encodeURIComponent(s)}*`).join(',')})`);
    }
    const order = f.orderBy === 'priority_score' ? 'priority_score.desc,created_at.desc' : 'created_at.desc';
    q.push(`order=${order}`);
    return q.join('&');
  }

  // ------------------------------------------------------------- público
  async publicReports(f = {}) {
    return (await this._get(`public_reports?select=*&${this._filterQuery(f)}&limit=500`)).map(mapReport);
  }
  async recentPublic(n = 6) { return (await this._get(`public_reports?select=*&order=created_at.desc&limit=${n}`)).map(mapReport); }
  async nearby(lat, lng, radius = 1500) {
    const rows = await this._rpc('nearby_reports', { p_lat: lat, p_lng: lng, p_radius_m: radius, p_limit: 10 });
    return rows.map(mapReport);
  }
  async publicStats() { return this._rpc('get_public_stats'); }

  // ------------------------------------------------------------- ciudadano
  async myReports() {
    if (!this.profile) return [];
    return (await this._get(`reports?select=*,sectors(name)&user_id=eq.${this.profile.id}&order=created_at.desc`)).map(mapReport);
  }
  async report(id) {
    const rows = await this._get(`reports?select=*,sectors(name)&id=eq.${id}`);
    if (rows[0]) return mapReport(rows[0]);
    const pub = await this._get(`public_reports?select=*&id=eq.${id}`);
    return pub[0] ? mapReport(pub[0]) : null;
  }
  async history(id) {
    return (await this._get(`status_history?select=*,profiles(full_name)&report_id=eq.${id}&order=created_at.asc`))
      .map((h) => ({ ...h, changed_by_name: h.profiles?.full_name || null }));
  }
  async observations(id) {
    return (await this._get(`observations?select=*,profiles(full_name)&report_id=eq.${id}&order=created_at.asc`))
      .map((o) => ({ ...o, author_name: o.profiles?.full_name || null }));
  }
  async createReport(d) {
    if (!this.profile) throw new AppError('Debes iniciar sesión para reportar.');
    const uid = this.profile.id;
    const prev = await this._get(`reports?select=*,sectors(name)&client_uuid=eq.${d.client_uuid}`);
    if (prev[0]) return mapReport(prev[0]);
    let photoUrl = null;
    let path = null;
    if (d.photo) {
      path = `${uid}/${d.client_uuid}.jpg`;
      const blob = await (await fetch(d.photo)).blob();
      await this._raw('POST', `/storage/v1/object/report-photos/${path}`, blob, { headers: { 'Content-Type': 'image/jpeg', 'x-upsert': 'true' } });
      photoUrl = `${this.url}/storage/v1/object/public/report-photos/${path}`;
    }
    const [row] = await this._raw('POST', '/rest/v1/reports', {
      user_id: uid, client_uuid: d.client_uuid, title: d.title.trim(), description: d.description.trim(),
      category_id: d.category_id, severity: d.severity, latitude: d.latitude, longitude: d.longitude,
      address: d.address?.trim() || null, photo_url: photoUrl, reported_at: d.reported_at,
    }, { headers: { Prefer: 'return=representation' } });
    if (path) {
      await this._raw('POST', '/rest/v1/report_photos', { report_id: row.id, storage_path: path, public_url: photoUrl, uploaded_by: uid });
    }
    return this.report(row.id); // los triggers calcularon código, sector y prioridad
  }
  async notifications() {
    if (!this.profile) return [];
    return this._get('notifications?select=*&order=created_at.desc&limit=100');
  }
  async markAllRead() {
    await this._raw('PATCH', `/rest/v1/notifications?user_id=eq.${this.profile.id}&read_at=is.null`, { read_at: new Date().toISOString() });
  }

  // ------------------------------------------------------------- administración
  async adminReports(f = {}) {
    return (await this._get(`reports?select=*,sectors(name)&${this._filterQuery({ orderBy: 'priority_score', ...f })}&limit=300`)).map(mapReport);
  }
  async changeStatus(id, status, note) { await this._rpc('change_report_status', { p_report_id: id, p_status: status, p_note: note || null }); }
  async addObservation(id, body, isPublic = true) {
    await this._raw('POST', '/rest/v1/observations', { report_id: id, body: body.trim(), is_public: !!isPublic });
  }
  async updateReport(id, changes) { await this._raw('PATCH', `/rest/v1/reports?id=eq.${id}`, changes); }
  async duplicates(id) {
    const rows = await this._get(`duplicate_candidates?select=*,candidate:reports!duplicate_candidates_candidate_id_fkey(code,title)&report_id=eq.${id}&order=score.desc`);
    return rows.map((d) => ({ ...d, candidate_code: d.candidate?.code || '', candidate_title: d.candidate?.title || '',
      distance_m: Number(d.distance_m), text_similarity: Number(d.text_similarity), score: Number(d.score) }));
  }
  async resolveDuplicate(candId, decision) { await this._rpc('resolve_duplicate', { p_candidate_id: candId, p_decision: decision }); }
  async recalculatePriorities() { return this._rpc('recalculate_all_priorities'); }
  async dashboard(days) {
    let from = null;
    if (days) { from = new Date(Date.now() - (days - 1) * 86400000); from.setHours(0, 0, 0, 0); }
    return this._rpc('get_dashboard_stats', { p_from: from ? from.toISOString() : null, p_to: null });
  }
  async reporter(userId) { return (await this._get(`profiles?id=eq.${userId}&select=*`))[0] || null; }
  async users(search = '') {
    const s = search.replace(/[,()*%]/g, '').trim();
    return this._get(`profiles?select=*${s ? `&full_name=ilike.*${encodeURIComponent(s)}*` : ''}&order=created_at.desc&limit=200`);
  }
  async updateUser(id, patch) { await this._raw('PATCH', `/rest/v1/profiles?id=eq.${id}`, patch); }
  async saveCategory(cat) {
    const body = {
      code: cat.code, name: cat.name, icon: ICON_TO_DB[cat.icon] || cat.icon, color: cat.color,
      priority_weight: cat.weight, keywords: cat.keywords, is_active: cat.active, sort_order: cat.order ?? 50,
    };
    if (cat.id) await this._raw('PATCH', `/rest/v1/categories?id=eq.${cat.id}`, body);
    else await this._raw('POST', '/rest/v1/categories', body);
    this.cats = (await this._get('categories?select=*&order=sort_order.asc')).map(mapCategory);
  }
  async seedTestData() { return this._rpc('seed_test_data', { p_user: this.profile.id }); }
  async clearTestData() { return this._rpc('clear_test_data'); }
}
export { uuid };
