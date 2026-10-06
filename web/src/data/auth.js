// Autenticación para los modos sin servidor.
import { AppError } from './engine-backend.js';
import { uuid } from './stores.js';

async function sha256(text) {
  if (globalThis.crypto?.subtle) {
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
  }
  // Contexto inseguro (http): hash simple de respaldo, solo para demostración.
  let h = 2166136261;
  for (const ch of text) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return `fnv${(h >>> 0).toString(16)}`;
}

export const DEMO_ACCOUNTS = {
  admin: { email: 'admin@demo.co', password: 'Admin2026', name: 'Administración Distrital (demo)' },
  citizen: { email: 'ciudadano@demo.co', password: 'Ciudadano2026', name: 'Ciudadano de prueba' },
};

/** Cuentas guardadas en este dispositivo (modo demostración local). */
export class LocalAuth {
  passwordAuth = true;
  canManageUsers = true;
  demoAdminId = 'demo-admin';
  demoCitizenId = 'demo-ciudadano';

  async init(store) {
    this.store = store;
    if (!store.get('users', this.demoAdminId)) {
      await this._create(this.demoAdminId, DEMO_ACCOUNTS.admin, 'admin');
      await this._create(this.demoCitizenId, DEMO_ACCOUNTS.citizen, 'citizen');
    }
  }
  async _create(id, { email, password, name, phone = null }, role = 'citizen') {
    const salt = uuid();
    await this.store.put('users', {
      id, email: email.toLowerCase(), full_name: name, phone, role, is_active: true,
      salt, pass_hash: await sha256(salt + password), created_at: new Date().toISOString(),
    });
  }
  _strip(u) {
    if (!u) return null;
    const { pass_hash, salt, recovery, ...rest } = u;
    return rest;
  }
  async current() {
    let id = null;
    try { id = localStorage.getItem('rsm:session'); } catch {}
    return this._strip(id ? this.store.get('users', id) : null);
  }
  async signIn(email, password) {
    const u = this.store.list('users').find((x) => x.email === email.trim().toLowerCase());
    if (!u || u.pass_hash !== (await sha256(u.salt + password))) throw new AppError('Correo o contraseña incorrectos.');
    if (!u.is_active) throw new AppError('Tu cuenta está inactiva.');
    localStorage.setItem('rsm:session', u.id);
    return this._strip(u);
  }
  async signUp({ email, password, full_name, phone }) {
    if (this.store.list('users').some((x) => x.email === email.trim().toLowerCase())) {
      throw new AppError('Ya existe una cuenta con este correo.');
    }
    const id = uuid();
    await this._create(id, { email: email.trim(), password, name: full_name.trim(), phone: phone?.trim() || null });
    localStorage.setItem('rsm:session', id);
    return { session: true };
  }
  async signOut() { localStorage.removeItem('rsm:session'); }
  async sendRecovery(email) {
    const u = this.store.list('users').find((x) => x.email === email.trim().toLowerCase());
    const code = String(Math.floor(100000 + Math.random() * 900000));
    if (u) await this.store.put('users', { ...u, recovery: { code, exp: Date.now() + 15 * 60000 } });
    // Sin servidor de correo: en modo demostración el código se muestra en pantalla.
    return { demoCode: u ? code : null };
  }
  async resetWithCode(email, code, password) {
    const u = this.store.list('users').find((x) => x.email === email.trim().toLowerCase());
    if (!u || !u.recovery || u.recovery.code !== code.trim() || u.recovery.exp < Date.now()) {
      throw new AppError('El código no es válido o ya expiró.');
    }
    const salt = uuid();
    await this.store.put('users', { ...u, salt, pass_hash: await sha256(salt + password), recovery: null });
    localStorage.setItem('rsm:session', u.id);
  }
  async updateProfile({ full_name, phone }) {
    const u = this.store.get('users', (await this.current())?.id);
    if (!u) throw new AppError('Sesión no iniciada.');
    await this.store.put('users', { ...u, full_name: full_name.trim(), phone: phone?.trim() || null });
  }
  async changePassword(password) {
    const u = this.store.get('users', (await this.current())?.id);
    if (!u) throw new AppError('Sesión no iniciada.');
    const salt = uuid();
    await this.store.put('users', { ...u, salt, pass_hash: await sha256(salt + password) });
  }
  async nameOf(id) { return this.store.get('users', id)?.full_name || null; }
  async profileOf(id) { return this._strip(this.store.get('users', id)); }
  async listUsers(search) {
    const q = (search || '').toLowerCase();
    return this.store.list('users').filter((u) => !q || u.full_name.toLowerCase().includes(q) || u.email.includes(q))
      .map((u) => this._strip(u)).sort((a, b) => b.created_at.localeCompare(a.created_at));
  }
  async updateUser(id, patch) {
    const u = this.store.get('users', id);
    if (!u) throw new AppError('Usuario no encontrado.');
    await this.store.put('users', { ...u, ...('role' in patch ? { role: patch.role } : {}), ...('is_active' in patch ? { is_active: patch.is_active } : {}) });
  }
}

/** Identidad de claude.ai en el enlace de demostración compartido. */
export class ArtifactAuth {
  passwordAuth = false;
  canManageUsers = false;
  demoCitizenId = 'demo-ciudadano';
  demoAdminId = null;

  constructor(user) { this.user = user; }
  async init() {
    if (!this.user) { this.meCache = null; return; }
    const me = await this.user.me();
    this.meCache = {
      id: me.id,
      full_name: me.name || 'Usuario',
      email: me.email,
      phone: null,
      role: me.canEdit || me.isOwner ? 'admin' : 'citizen',
      is_active: true,
      created_at: new Date().toISOString(),
    };
    this.demoAdminId = me.id;
  }
  async current() { return this.meCache?.id ? this.meCache : null; }
  async nameOf(id) {
    if (!id) return null;
    if (id === 'demo-ciudadano') return 'Ciudadano de prueba';
    if (id === 'demo-admin') return 'Administración (datos de prueba)';
    const ps = await this.user.profiles([id]);
    return ps[id]?.name || 'Persona del equipo';
  }
  async profileOf(id) {
    return { id, full_name: await this.nameOf(id), phone: null, role: id === this.meCache.id ? this.meCache.role : 'citizen', is_active: true, created_at: null };
  }
  async listUsers(search, ids) {
    const all = [...new Set([this.meCache.id, ...ids].filter(Boolean))];
    const out = [];
    for (const id of all) out.push(await this.profileOf(id));
    const q = (search || '').toLowerCase();
    return out.filter((u) => !q || (u.full_name || '').toLowerCase().includes(q));
  }
  async updateUser() {
    throw new AppError('En el enlace de demostración los permisos se administran desde el botón Compartir de claude.ai (Editor = administrador).');
  }
  // No aplican en este modo (la sesión es la de claude.ai):
  async signIn() {} async signUp() {} async signOut() {}
  async sendRecovery() { return {}; } async resetWithCode() {} async changePassword() {}
  async updateProfile() { throw new AppError('Tu nombre proviene de tu cuenta de claude.ai.'); }
}
