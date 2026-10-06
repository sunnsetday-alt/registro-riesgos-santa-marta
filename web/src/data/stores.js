// Almacenes de tablas para los modos sin servidor.
//  - LocalStore: datos en este dispositivo (localStorage + IndexedDB para fotos).
//  - ArtifactStore: base de datos compartida del enlace de demostración en
//    claude.ai (capacidad `db`), en tiempo real entre quienes lo usan.

export const TABLES = ['reports', 'history', 'observations', 'duplicates', 'notifications', 'categories', 'users'];

export function uuid() {
  if (globalThis.crypto?.randomUUID) return crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

// ------------------------------------------------------------ IndexedDB mini
function idb() {
  return new Promise((resolve, reject) => {
    if (!globalThis.indexedDB) return reject(new Error('IndexedDB no disponible'));
    const req = indexedDB.open('rsm', 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore('photos');
      req.result.createObjectStore('queue');
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
export async function idbOp(store, mode, fn) {
  const db = await idb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(store, mode);
    const req = fn(tx.objectStore(store));
    tx.oncomplete = () => resolve(req?.result);
    tx.onerror = () => reject(tx.error);
  });
}

// ------------------------------------------------------------ LocalStore
export class LocalStore {
  constructor(prefix = 'rsm') {
    this.prefix = prefix;
    this.data = {};
    this.listeners = new Set();
    this.memPhotos = new Map();
  }
  _key(t) { return `${this.prefix}:${t}`; }
  async init() {
    for (const t of TABLES) {
      try { this.data[t] = JSON.parse(localStorage.getItem(this._key(t)) || '[]'); } catch { this.data[t] = []; }
    }
    try { this.meta = JSON.parse(localStorage.getItem(this._key('meta')) || '{}'); } catch { this.meta = {}; }
    // Sincroniza pestañas abiertas del mismo navegador.
    addEventListener('storage', (e) => {
      if (e.key?.startsWith(`${this.prefix}:`)) { this.init().then(() => this._emit()); }
    });
  }
  get isEmpty() { return !this.meta.seeded; }
  list(t) { return this.data[t] || []; }
  get(t, id) { return this.list(t).find((r) => r.id === id) || null; }
  _save(t) {
    try { localStorage.setItem(this._key(t), JSON.stringify(this.data[t])); }
    catch (e) { throw new Error('No hay espacio en el almacenamiento del navegador. Libera espacio o elimina datos de prueba.'); }
  }
  async put(t, row) {
    const arr = this.list(t);
    const i = arr.findIndex((r) => r.id === row.id);
    if (i >= 0) arr[i] = row; else arr.push(row);
    this.data[t] = arr;
    this._save(t);
    this._emit();
  }
  async putMany(t, rows) {
    for (const row of rows) {
      const arr = this.list(t);
      const i = arr.findIndex((r) => r.id === row.id);
      if (i >= 0) arr[i] = row; else arr.push(row);
      this.data[t] = arr;
    }
    this._save(t);
    this._emit();
  }
  async remove(t, id) {
    this.data[t] = this.list(t).filter((r) => r.id !== id);
    this._save(t);
    this._emit();
  }
  async setMeta(patch) {
    this.meta = { ...this.meta, ...patch };
    localStorage.setItem(this._key('meta'), JSON.stringify(this.meta));
  }
  async nextCounter(year) {
    const k = `counter_${year}`;
    const n = (this.meta[k] || 0) + 1;
    await this.setMeta({ [k]: n });
    return n;
  }
  async getPhoto(id) {
    try { return (await idbOp('photos', 'readonly', (s) => s.get(id))) || this.memPhotos.get(id) || null; }
    catch { return this.memPhotos.get(id) || null; }
  }
  async putPhoto(id, dataUrl) {
    try { await idbOp('photos', 'readwrite', (s) => s.put(dataUrl, id)); }
    catch { this.memPhotos.set(id, dataUrl); }
  }
  async deletePhoto(id) {
    try { await idbOp('photos', 'readwrite', (s) => s.delete(id)); } catch { this.memPhotos.delete(id); }
  }
  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  _emit() { for (const fn of this.listeners) fn(); }
}

// ------------------------------------------------------------ ArtifactStore
const SHARED = ['reports', 'history', 'observations', 'duplicates', 'notifications', 'categories'];

export class ArtifactStore {
  constructor(db) {
    this.db = db;
    this.data = { users: [] };
    this.meta = {};
    this.listeners = new Set();
    this.photoCache = new Map();
    this._emitTimer = null;
  }
  async init() {
    // Primera carga completa y luego suscripción en vivo a cada colección.
    await Promise.all(SHARED.map(async (t) => {
      const snap = await this.db.collection(t).limit(1000).get();
      this.data[t] = snap.docs.map((d) => d.data());
    }));
    const meta = await this.db.doc('meta/settings').get();
    this.meta = meta.exists ? { ...meta.data() } : {};
    for (const t of SHARED) {
      this.db.collection(t).limit(1000).onSnapshot(
        (snap) => { this.data[t] = snap.docs.map((d) => d.data()); this._emitSoon(); },
        () => {},
      );
    }
    this.db.doc('meta/settings').onSnapshot((s) => { this.meta = s.exists ? { ...s.data() } : {}; this._emitSoon(); }, () => {});
  }
  get isEmpty() { return !(this.data.categories || []).length; }
  list(t) { return this.data[t] || []; }
  get(t, id) { return this.list(t).find((r) => r.id === id) || null; }
  _apply(t, row, del = false) {
    const arr = (this.data[t] || []).filter((r) => r.id !== row.id);
    this.data[t] = del ? arr : arr.concat(row);
  }
  async put(t, row) {
    this._apply(t, row);
    this._emitSoon();
    await this.db.collection(t).doc(String(row.id)).set(JSON.parse(JSON.stringify(row)));
  }
  async putMany(t, rows) { for (const r of rows) await this.put(t, r); }
  async remove(t, id) {
    this._apply(t, { id }, true);
    this._emitSoon();
    await this.db.collection(t).doc(String(id)).delete();
  }
  async setMeta(patch) {
    this.meta = { ...this.meta, ...patch };
    await this.db.doc('meta/settings').set(this.meta);
  }
  async nextCounter(year) {
    const ref = this.db.doc(`meta/counter_${year}`);
    for (let i = 0; i < 8; i++) {
      const lease = await ref.acquire({ holder: uuid(), ttlMs: 5000 });
      if (lease.acquired) {
        const snap = await ref.get();
        const n = ((snap.exists && snap.data().value) || 0) + 1;
        await ref.set({ value: n });
        return n;
      }
      await new Promise((r) => setTimeout(r, 300 + Math.random() * 500));
    }
    throw new Error('No se pudo generar el código del reporte. Intenta de nuevo.');
  }
  async getPhoto(id) {
    if (this.photoCache.has(id)) return this.photoCache.get(id);
    const s = await this.db.doc(`photos/${id}`).get();
    const url = s.exists ? s.data().data : null;
    this.photoCache.set(id, url);
    return url;
  }
  async putPhoto(id, dataUrl) {
    this.photoCache.set(id, dataUrl);
    await this.db.doc(`photos/${id}`).set({ data: dataUrl });
  }
  async deletePhoto(id) { this.photoCache.delete(id); await this.db.doc(`photos/${id}`).delete(); }
  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  _emitSoon() {
    clearTimeout(this._emitTimer);
    this._emitTimer = setTimeout(() => { for (const fn of this.listeners) fn(); }, 120);
  }
}
