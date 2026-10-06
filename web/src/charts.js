// Gráficos SVG del dashboard (escala única, colores del tema).
import { h } from './ui.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

/** Barras horizontales: [{label, value, color}] */
export function hbars(items, max = 10) {
  const list = items.slice(0, max);
  if (!list.length) return h('p', { class: 'muted' }, 'Sin datos');
  const top = Math.max(1, ...list.map((i) => i.value));
  return h('div', { class: 'hbars' }, list.map((i) => h('div', { class: 'hbar' },
    h('span', { class: 'hbar-label', title: i.label }, i.label),
    h('span', { class: 'hbar-track' }, h('span', { class: 'hbar-fill', style: { width: `${(i.value / top) * 100}%`, background: i.color } })),
    h('b', { class: 'num' }, String(i.value)))));
}

/** Dona: [{label, value, color}] */
export function donut(items) {
  const total = items.reduce((a, i) => a + i.value, 0);
  if (!total) return h('p', { class: 'muted' }, 'Sin datos');
  const r = 52;
  const C = 2 * Math.PI * r;
  let off = 0;
  const arcs = items.filter((i) => i.value > 0).map((i) => {
    const len = (i.value / total) * C;
    const s = `<circle cx="70" cy="70" r="${r}" fill="none" stroke="${esc(i.color)}" stroke-width="22" stroke-dasharray="${len} ${C - len}" stroke-dashoffset="${-off}" transform="rotate(-90 70 70)"><title>${esc(i.label)}: ${i.value}</title></circle>`;
    off += len;
    return s;
  }).join('');
  const svg = h('div', { class: 'donut', html: `<svg viewBox="0 0 140 140" role="img" aria-label="Reportes por estado">${arcs}<text x="70" y="68" text-anchor="middle" class="donut-n">${total}</text><text x="70" y="86" text-anchor="middle" class="donut-l">total</text></svg>` });
  const legend = h('ul', { class: 'legend' }, items.map((i) => h('li', null, h('i', { style: { background: i.color } }), `${i.label} `, h('b', { class: 'num' }, String(i.value)))));
  return h('div', { class: 'donut-wrap' }, svg, legend);
}

/** Barras verticales: [{label, value, color}] */
export function vbars(items) {
  const W = 320; const H = 170; const pad = 26;
  const top = Math.max(1, ...items.map((i) => i.value));
  const bw = (W - pad) / items.length;
  const bars = items.map((it, k) => {
    const bh = ((H - 50) * it.value) / top;
    const x = pad / 2 + k * bw + bw * 0.18;
    const y = H - 34 - bh;
    return `<rect x="${x}" y="${y}" width="${bw * 0.64}" height="${Math.max(bh, 1.5)}" rx="6" fill="${esc(it.color)}"><title>${esc(it.label)}: ${it.value}</title></rect>`
      + `<text x="${x + bw * 0.32}" y="${y - 6}" text-anchor="middle" class="ch-val">${it.value}</text>`
      + `<text x="${x + bw * 0.32}" y="${H - 16}" text-anchor="middle" class="ch-lbl">${esc(it.label)}</text>`;
  }).join('');
  return h('div', { class: 'chart', html: `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Gráfico de barras">${bars}</svg>` });
}

/** Línea diaria: [{date:'YYYY-MM-DD', count}] */
export function line(points) {
  if (!points.length) return h('p', { class: 'muted' }, 'Sin datos');
  const W = 340; const H = 170; const L = 26; const B = 26; const T = 12; const R = 8;
  const max = Math.max(1, ...points.map((p) => p.count));
  const yMax = Math.ceil(max * 1.15) || 1;
  const x = (i) => L + (i * (W - L - R)) / Math.max(1, points.length - 1);
  const y = (v) => T + (H - T - B) * (1 - v / yMax);
  const path = points.map((p, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(p.count).toFixed(1)}`).join('');
  const area = `${path}L${x(points.length - 1)},${y(0)}L${x(0)},${y(0)}Z`;
  const ticks = [0, Math.round(yMax / 2), yMax].map((v) =>
    `<line x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}" class="ch-grid"/><text x="${L - 6}" y="${y(v) + 4}" text-anchor="end" class="ch-lbl">${v}</text>`).join('');
  const step = Math.max(1, Math.ceil(points.length / 5));
  const xl = points.map((p, i) => (i % step === 0 || i === points.length - 1)
    ? `<text x="${x(i)}" y="${H - 6}" text-anchor="middle" class="ch-lbl">${+p.date.slice(8)}/${+p.date.slice(5, 7)}</text>` : '').join('');
  const last = points[points.length - 1];
  return h('div', { class: 'chart', html: `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Reportes por día">${ticks}<path d="${area}" class="ch-area"/><path d="${path}" class="ch-line"/><circle cx="${x(points.length - 1)}" cy="${y(last.count)}" r="4" class="ch-dot"/>${xl}</svg>` });
}
