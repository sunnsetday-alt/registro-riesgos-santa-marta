// Componentes de interfaz reutilizables (DOM puro, sin dependencias).
import { ICONS } from './icons.gen.js';
import { PRIORITY_LEVELS, severityOf, statusOf } from './data/catalog.js';

/** Crea un elemento: h('div', {class:'x', onclick}, hijos...) */
export function h(tag, props, ...children) {
  const el = tag === 'svg' || tag === 'path' ? document.createElementNS('http://www.w3.org/2000/svg', tag) : document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (v == null || v === false) continue;
      if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') {
        for (const [sk, sv] of Object.entries(v)) { if (sk.startsWith('--')) el.style.setProperty(sk, sv); else el.style[sk] = sv; }
      }
      else if (k === 'html') el.innerHTML = v;
      else if (k === 'value' || k === 'checked' || k === 'selected') el[k] = v;
      else if (k in el && typeof v !== 'string' && k !== 'list') el[k] = v;
      else el.setAttribute(k, v === true ? '' : v);
    }
  }
  append(el, children);
  return el;
}
function append(el, children) {
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
}

/** Ícono SVG de Material (Apache 2.0) incrustado. */
export function icon(name, size = 20, color) {
  const span = document.createElement('span');
  span.className = 'ic';
  span.setAttribute('aria-hidden', 'true');
  span.style.width = span.style.height = `${size}px`;
  if (color) span.style.color = color;
  span.innerHTML = `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="currentColor">${ICONS[name] || ICONS.help}</svg>`;
  return span;
}

// ------------------------------------------------------------ formato
const dtf = new Intl.DateTimeFormat('es-CO', { day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' });
const df = new Intl.DateTimeFormat('es-CO', { day: 'numeric', month: 'long', year: 'numeric' });
export const fmt = {
  dateTime: (d) => dtf.format(new Date(d)),
  date: (d) => df.format(new Date(d)),
  short: (d) => new Date(d).toLocaleDateString('es-CO'),
  relative(d) {
    const m = (Date.now() - new Date(d).getTime()) / 60000;
    if (m < 1) return 'hace un momento';
    if (m < 60) return `hace ${Math.floor(m)} min`;
    if (m < 1440) return `hace ${Math.floor(m / 60)} h`;
    const days = Math.floor(m / 1440);
    if (days < 30) return `hace ${days} ${days === 1 ? 'día' : 'días'}`;
    return fmt.short(d);
  },
  coords: (lat, lng) => `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
  distance: (m) => (m < 1000 ? `${Math.round(m)} m` : `${(m / 1000).toFixed(1)} km`),
};

// ------------------------------------------------------------ insignias
export function statusChip(code, dense = false) {
  const s = statusOf(code);
  return h('span', { class: `chip status${dense ? ' dense' : ''}`, style: { '--c': s.color } }, icon(s.icon, dense ? 13 : 15), s.name);
}
export function severityBadge(level, withLabel = true) {
  const s = severityOf(level);
  return h('span', { class: 'sev', style: { background: s.color }, title: s.text }, h('b', null, String(s.level)), withLabel ? s.label : null);
}
export function priorityBadge(level, score) {
  const p = PRIORITY_LEVELS[level] || PRIORITY_LEVELS.baja;
  return h('span', { class: 'prio', style: { '--c': p.color } }, `${p.label} · ${Math.round(score || 0)}`);
}
export function categoryLabel(cat) {
  if (!cat) return h('span', { class: 'cat' }, 'Sin categoría');
  return h('span', { class: 'cat', style: { '--c': cat.color } }, h('span', { class: 'cat-ic' }, icon(cat.icon, 15)), cat.name);
}
export const testBadge = () => h('span', { class: 'test-badge' }, 'DATO DE PRUEBA');

/** Foto de un reporte (carga diferida desde el backend). */
export function photo(backend, report, cls = 'thumb') {
  const box = h('div', { class: `photo ${cls}` }, icon('image', 28));
  if (report.has_photo || report.photo_url) {
    backend.photoUrl(report).then((url) => {
      if (!url) return;
      const img = h('img', { src: url, alt: `Fotografía del reporte ${report.code || ''}`, loading: 'lazy' });
      img.onerror = () => img.remove();
      box.replaceChildren(img);
    }).catch(() => {});
  }
  return box;
}

export function emptyState(ic, title, message, action) {
  return h('div', { class: 'empty' }, h('div', { class: 'empty-ic' }, icon(ic, 36)), h('h3', null, title), message ? h('p', null, message) : null, action || null);
}
export function loading(text = 'Cargando…') {
  return h('div', { class: 'loading' }, h('span', { class: 'spinner' }), text);
}
export function sectionTitle(text, action) {
  return h('div', { class: 'section-title' }, h('h2', null, text), action || null);
}
export function button(label, { kind = 'primary', ic, onClick, type = 'button', id, disabled, full } = {}) {
  return h('button', { class: `btn ${kind}${full ? ' full' : ''}`, type, id, disabled, onclick: onClick }, ic ? icon(ic, 19) : null, h('span', null, label));
}

// ------------------------------------------------------------ avisos
export function toast(message, kind = 'info') {
  let host = document.getElementById('toasts');
  if (!host) { host = h('div', { id: 'toasts', role: 'status', 'aria-live': 'polite' }); document.body.append(host); }
  const t = h('div', { class: `toast ${kind}` }, message);
  host.append(t);
  setTimeout(() => t.classList.add('out'), 3600);
  setTimeout(() => t.remove(), 4000);
}

/** Hoja inferior / diálogo modal. Devuelve {close}. */
export function sheet(build, { title, wide = false, onClose } = {}) {
  const prev = document.activeElement;
  const close = () => {
    overlay.classList.add('out');
    setTimeout(() => overlay.remove(), 180);
    document.removeEventListener('keydown', onKey);
    onClose?.();
    prev?.focus?.();
  };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  const panel = h('div', { class: `sheet${wide ? ' wide' : ''}`, role: 'dialog', 'aria-modal': 'true', 'aria-label': title || 'Diálogo' },
    h('div', { class: 'sheet-head' },
      h('span', { class: 'grip' }),
      title ? h('h3', null, title) : null,
      h('button', { class: 'icon-btn', 'aria-label': 'Cerrar', onclick: close }, icon('close', 22))),
  );
  const body = h('div', { class: 'sheet-body' });
  panel.append(body);
  const overlay = h('div', { class: 'overlay', onclick: (e) => { if (e.target === overlay) close(); } }, panel);
  document.body.append(overlay);
  document.addEventListener('keydown', onKey);
  const api = { close, body, panel };
  const content = build(api);
  if (content) body.append(content);
  setTimeout(() => panel.querySelector('input,select,textarea,button:not(.icon-btn)')?.focus?.(), 50);
  return api;
}

/** Confirmación dentro de la página (confirm() no funciona en todos los marcos). */
export function confirmDialog(message, { ok = 'Aceptar', danger = false } = {}) {
  return new Promise((resolve) => {
    let done = false;
    const s = sheet((api) => h('div', { class: 'stack' },
      h('p', null, message),
      h('div', { class: 'row end' },
        button('Cancelar', { kind: 'ghost', onClick: () => { done = true; resolve(false); api.close(); } }),
        button(ok, { kind: danger ? 'danger' : 'primary', onClick: () => { done = true; resolve(true); api.close(); } }))),
    { title: 'Confirmar', onClose: () => { if (!done) resolve(false); } });
    return s;
  });
}

/** Campo de formulario con etiqueta y error. */
export function field(labelText, control, { hint, optional } = {}) {
  const err = h('div', { class: 'field-error', role: 'alert' });
  const wrap = h('label', { class: 'field' },
    h('span', { class: 'field-label' }, labelText, optional ? h('em', null, ' (opcional)') : null),
    control, hint ? h('span', { class: 'field-hint' }, hint) : null, err);
  wrap.setError = (msg) => { err.textContent = msg || ''; wrap.classList.toggle('invalid', !!msg); };
  return wrap;
}

/** Línea de tiempo de estados y observaciones. */
export function timeline(history, observations, showAuthors = false) {
  const items = [
    ...history.map((x) => ({
      at: x.created_at, color: statusOf(x.to_status).color, ic: statusOf(x.to_status).icon,
      title: x.from_status ? `${statusOf(x.from_status).name} → ${statusOf(x.to_status).name}` : statusOf(x.to_status).name,
      body: x.note, by: x.changed_by_name,
    })),
    ...observations.map((o) => ({
      at: o.created_at, color: 'var(--turq)', ic: o.is_public ? 'chat' : 'lock',
      title: o.is_public ? 'Observación' : 'Nota interna', body: o.body, by: o.author_name,
    })),
  ].sort((a, b) => a.at.localeCompare(b.at));
  if (!items.length) return h('p', { class: 'muted' }, 'Sin actualizaciones todavía.');
  return h('ol', { class: 'timeline' }, items.map((i) => h('li', null,
    h('span', { class: 'tl-dot', style: { '--c': i.color } }, icon(i.ic, 15)),
    h('div', null,
      h('strong', null, i.title),
      i.body ? h('p', null, i.body) : null,
      showAuthors && i.by ? h('small', { class: 'muted' }, `Por: ${i.by}`) : null,
      h('small', { class: 'muted block' }, fmt.dateTime(i.at))))));
}
