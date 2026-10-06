// Reglas de negocio en JavaScript, equivalentes a las funciones SQL de
// supabase/migrations/20261005000002_functions.sql. Se usan en los modos
// "local" y "compartido" (sin servidor Supabase). En modo Supabase estas
// reglas las ejecuta la base de datos.
import { SECTORS, SETTINGS, statusOf } from './catalog.js';

export const DAY = 86400000;

/** Distancia Haversine en metros (misma fórmula que distance_m). */
export function distanceM(lat1, lng1, lat2, lng2) {
  const rad = (d) => (d * Math.PI) / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** Minúsculas y sin tildes (normalize_text). */
export function normalize(s) {
  return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
}

/** Trigramas al estilo pg_trgm: cada palabra se rellena con "  " y " ". */
function trigrams(s) {
  const set = new Set();
  for (const w of normalize(s).split(/[^a-z0-9]+/).filter(Boolean)) {
    const p = `  ${w} `;
    for (let i = 0; i < p.length - 2; i++) set.add(p.slice(i, i + 3));
  }
  return set;
}

/** Similitud de trigramas (0..1), equivalente a similarity() de pg_trgm. */
export function similarity(a, b) {
  const A = trigrams(a);
  const B = trigrams(b);
  if (!A.size || !B.size) return 0;
  let inter = 0;
  for (const t of A) if (B.has(t)) inter++;
  return inter / (A.size + B.size - inter);
}

export function findSector(lat, lng, sectors = SECTORS) {
  let best = null;
  let bestD = Infinity;
  for (const s of sectors) {
    const d = distanceM(lat, lng, s.lat, s.lng);
    if (d <= s.r && d < bestD) { best = s; bestD = d; }
  }
  return best;
}

const isOpen = (r) => statusOf(r.status).open;

/**
 * Índice de prioridad 0–100 (ver docs/PRIORIZACION_Y_DUPLICADOS.md).
 * ctx = { reports, duplicates, categories, settings, now }
 */
export function computePriority(r, ctx) {
  const s = { ...SETTINGS, ...(ctx.settings || {}) };
  const now = ctx.now ?? Date.now();
  const similar =
    ctx.duplicates.filter((d) => (d.report_id === r.id || d.candidate_id === r.id) && d.decision !== 'descartado').length +
    ctx.reports.filter((o) => o.duplicate_of === r.id).length;
  const nearby = ctx.reports.filter((o) =>
    o.id !== r.id && isOpen(o) && !o.duplicate_of &&
    now - Date.parse(o.created_at) < s.geo_window_days * DAY &&
    distanceM(r.latitude, r.longitude, o.latitude, o.longitude) <= s.geo_radius_m).length;
  const end = r.resolved_at ? Date.parse(r.resolved_at) : now;
  const ageDays = Math.max(0, (end - Date.parse(r.created_at)) / DAY);
  const cat = ctx.categories.find((c) => c.id === r.category_id);
  const weight = cat ? cat.weight : 1;
  const sumW = s.w_severity + s.w_similar + s.w_age + s.w_category + s.w_geo || 1;
  let score = 100 * (
    s.w_severity * ((r.severity - 1) / 4) +
    s.w_similar * Math.min(similar / s.similar_cap, 1) +
    s.w_age * Math.min(ageDays / s.age_cap_days, 1) +
    s.w_category * Math.max(0, Math.min(1, (weight - 0.5) / 1)) +
    s.w_geo * Math.min(nearby / s.geo_cap, 1)
  ) / sumW;
  if (r.severity === 5) score = Math.max(score, s.critical_severity_floor);
  return Math.round(Math.min(100, Math.max(0, score)) * 100) / 100;
}

export function priorityLevel(score, settings = SETTINGS) {
  const s = { ...SETTINGS, ...settings };
  if (score >= s.threshold_critica) return 'critica';
  if (score >= s.threshold_alta) return 'alta';
  if (score >= s.threshold_media) return 'media';
  return 'baja';
}

/** Posibles duplicados de r entre reportes anteriores (detect_duplicates). */
export function detectDuplicates(r, reports, settings = SETTINGS) {
  const s = { ...SETTINGS, ...settings };
  const created = Date.parse(r.created_at);
  const out = [];
  for (const o of reports) {
    if (o.id === r.id || o.status === 'rechazado') continue;
    const oc = Date.parse(o.created_at);
    if (oc > created || created - oc > s.dup_window_days * DAY) continue;
    const dist = distanceM(r.latitude, r.longitude, o.latitude, o.longitude);
    if (dist > s.dup_radius_m) continue;
    const sim = Math.max(
      similarity(r.title, o.title),
      similarity(`${r.title} ${r.description}`, `${o.title} ${o.description}`),
    );
    if (sim >= s.dup_text_threshold || (o.category_id === r.category_id && dist <= s.dup_same_category_radius_m)) {
      out.push({
        candidate_id: o.id,
        distance_m: Math.round(dist * 10) / 10,
        text_similarity: Math.round(sim * 1000) / 1000,
        score: Math.round((0.5 * (1 - dist / s.dup_radius_m) + 0.5 * sim) * 1000) / 1000,
      });
    }
  }
  return out;
}

const dayKey = (d) => {
  const x = new Date(d);
  return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`;
};

/** Estadísticas del dashboard (get_dashboard_stats). */
export function dashboardStats(reports, categories, from) {
  const base = reports.filter((r) => !from || Date.parse(r.created_at) >= from.getTime());
  const count = (fn) => base.filter(fn).length;
  const group = (keyFn) => {
    const m = new Map();
    for (const r of base) {
      const k = keyFn(r);
      m.set(k, (m.get(k) || []).concat(r));
    }
    return m;
  };
  const start = from ? new Date(from) : new Date(Date.now() - 29 * DAY);
  start.setHours(0, 0, 0, 0);
  const byDate = [];
  for (let d = new Date(start); d <= new Date(); d = new Date(d.getTime() + DAY)) {
    const k = dayKey(d);
    byDate.push({ date: k, count: base.filter((r) => dayKey(r.created_at) === k).length });
  }
  const cells = new Map();
  for (const r of base.filter((x) => isOpen(x) && !x.duplicate_of)) {
    const k = `${r.latitude.toFixed(3)},${r.longitude.toFixed(3)}`;
    cells.set(k, (cells.get(k) || []).concat(r));
  }
  const hotspots = [...cells.values()].filter((g) => g.length >= 2).map((g) => ({
    lat: g.reduce((a, r) => a + r.latitude, 0) / g.length,
    lng: g.reduce((a, r) => a + r.longitude, 0) / g.length,
    count: g.length,
    avg_severity: Math.round((g.reduce((a, r) => a + r.severity, 0) / g.length) * 10) / 10,
    sector: g[0].sector_name || 'Sin sector',
  })).sort((a, b) => b.count - a.count || b.avg_severity - a.avg_severity).slice(0, 10);

  return {
    total: base.length,
    critical_open: count((r) => r.severity === 5 && isOpen(r)),
    priority_critical: count((r) => r.priority_level === 'critica' && isOpen(r)),
    possible_duplicates: count((r) => r.possible_duplicate && !r.duplicate_of),
    by_status: ['recibido', 'en_revision', 'validado', 'en_proceso', 'atendido', 'cerrado', 'rechazado']
      .map((code) => ({ code, name: statusOf(code).name, color: statusOf(code).color, count: count((r) => r.status === code) })),
    by_category: [...group((r) => r.category_id)].map(([id, rs]) => {
      const c = categories.find((x) => x.id === id) || { name: 'Otros', color: '#64748B' };
      return { name: c.name, color: c.color, count: rs.length };
    }).sort((a, b) => b.count - a.count),
    by_severity: [1, 2, 3, 4, 5].map((n) => ({ severity: n, count: count((r) => r.severity === n) })),
    by_priority: ['baja', 'media', 'alta', 'critica'].map((l) => ({ level: l, count: count((r) => r.priority_level === l && isOpen(r)) })),
    by_sector: [...group((r) => r.sector_name || 'Sin sector')].map(([name, rs]) => ({
      name, count: rs.length, open: rs.filter(isOpen).length,
      avg_priority: Math.round((rs.reduce((a, r) => a + (r.priority_score || 0), 0) / rs.length) * 10) / 10,
    })).sort((a, b) => b.count - a.count),
    by_date: byDate,
    hotspots,
  };
}

export function publicStats(publicReports) {
  const now = Date.now();
  return {
    total: publicReports.length,
    open: publicReports.filter(isOpen).length,
    resolved: publicReports.filter((r) => r.status === 'atendido' || r.status === 'cerrado').length,
    last_7_days: publicReports.filter((r) => now - Date.parse(r.created_at) < 7 * DAY).length,
    critical_open: publicReports.filter((r) => isOpen(r) && r.severity === 5).length,
  };
}

/** Código RSM-AAAA-NNNNNN. */
export const reportCode = (year, n) => `RSM-${year}-${String(n).padStart(6, '0')}`;

/** Clasificador local por palabras clave (sin conexión, explicable). */
const URGENT = ['peligro', 'peligroso', 'urgente', 'herido', 'heridos', 'muerte', 'colapso', 'derrumbe', 'cables',
  'electrocut', 'caer', 'caido', 'incendio', 'arrastr', 'ninos'];

export function suggestCategory(title, description, categories) {
  const text = ` ${normalize(`${title} ${description}`).replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ')} `;
  if (text.trim().length < 4) return null;
  let best = null;
  let bestScore = 0;
  let bestMatches = [];
  for (const c of categories) {
    if (!c.active || !c.keywords?.length) continue;
    let score = 0;
    const matches = [];
    for (const kw of c.keywords) {
      const k = normalize(kw).replace(/[^a-z0-9 ]/g, ' ').trim();
      if (!k) continue;
      if (text.includes(` ${k} `) || text.includes(` ${k}s `) || text.includes(` ${k}es `)) {
        matches.push(kw);
        score += k.includes(' ') ? 2 : 1;
      }
    }
    if (score > bestScore) { best = c; bestScore = score; bestMatches = matches; }
  }
  if (!best) return null;
  const urgent = URGENT.filter((t) => text.includes(t)).length;
  return {
    category: best,
    matched: bestMatches,
    severity: urgent >= 2 ? 5 : urgent === 1 ? 4 : null,
  };
}
