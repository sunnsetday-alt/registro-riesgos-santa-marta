// Mapa interactivo liviano (teselas Web Mercator), sin librerías externas.
// Arrastrar, tocar, rueda/pellizco para zoom, marcadores y círculos.
// Si las teselas no cargan (sin conexión o entorno restringido), muestra un
// plano esquemático con los sectores de Santa Marta para seguir ubicándose.
import { CENTER, SECTORS } from './data/catalog.js';
import { h, icon } from './ui.js';

const TILE = 256;
const cfg = () => globalThis.RSM_CONFIG || {};

function project(lat, lng, z) {
  const s = TILE * 2 ** z;
  const sin = Math.sin((Math.max(-85, Math.min(85, lat)) * Math.PI) / 180);
  return { x: ((lng + 180) / 360) * s, y: (0.5 - Math.log((1 + sin) / (1 - sin)) / (4 * Math.PI)) * s };
}
function unproject(x, y, z) {
  const s = TILE * 2 ** z;
  const lng = (x / s) * 360 - 180;
  const n = Math.PI - (2 * Math.PI * y) / s;
  return { lat: (180 / Math.PI) * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n))), lng };
}
/** Metros por píxel en una latitud y zoom. */
const mpp = (lat, z) => (156543.03392 * Math.cos((lat * Math.PI) / 180)) / 2 ** z;

export class MapView {
  constructor(el, opts = {}) {
    this.el = el;
    this.o = { minZoom: 10, maxZoom: 18, zoom: 13, center: CENTER, interactive: true, ...opts };
    this.z = this.o.zoom;
    this.c = { ...this.o.center };
    this.markers = [];
    this.circles = [];
    this.tiles = new Map();
    this.loaded = 0;
    this.failed = 0;
    el.classList.add('map');
    el.tabIndex = 0;
    el.setAttribute('role', 'application');
    el.setAttribute('aria-label', 'Mapa de Santa Marta. Arrastra para mover, usa + y − para acercar.');
    this.tileLayer = h('div', { class: 'map-tiles' });
    this.schemLayer = h('div', { class: 'map-schematic' });
    this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    this.svg.classList.add('map-svg');
    this.mkLayer = h('div', { class: 'map-markers' });
    const zoomIn = h('button', { class: 'map-btn', type: 'button', 'aria-label': 'Acercar', onclick: () => this.zoomBy(1) }, icon('add', 20));
    const zoomOut = h('button', { class: 'map-btn', type: 'button', 'aria-label': 'Alejar', onclick: () => this.zoomBy(-1) }, icon('remove', 20));
    this.controls = h('div', { class: 'map-controls' }, zoomIn, zoomOut);
    this.attr = h('div', { class: 'map-attr' }, cfg().MAP_ATTRIBUTION || '© colaboradores de OpenStreetMap');
    el.append(this.tileLayer, this.schemLayer, this.svg, this.mkLayer, this.controls, this.attr);
    if (this.o.pin) el.append(h('div', { class: 'map-pin', 'aria-hidden': 'true' }, icon('location_on', 46)));
    this._buildSchematic();
    this._bind();
    this._ro = new ResizeObserver(() => this.render());
    this._ro.observe(el);
    this.render();
  }

  get center() { return { ...this.c }; }
  get zoom() { return this.z; }

  setView(center, zoom = this.z) {
    this.c = { lat: center.lat, lng: center.lng };
    this.z = Math.max(this.o.minZoom, Math.min(this.o.maxZoom, Math.round(zoom)));
    this.render();
  }
  zoomBy(d, anchor) {
    const nz = Math.max(this.o.minZoom, Math.min(this.o.maxZoom, this.z + d));
    if (nz === this.z) return;
    if (anchor) {
      // Mantiene fijo el punto bajo el cursor/dedos.
      const before = this._toLatLng(anchor.x, anchor.y);
      this.z = nz;
      const p = project(before.lat, before.lng, nz);
      const w = this.el.clientWidth;
      const hh = this.el.clientHeight;
      this.c = unproject(p.x - (anchor.x - w / 2), p.y - (anchor.y - hh / 2), nz);
    } else this.z = nz;
    this.render();
    this.o.onMove?.(this.center, true);
  }
  fit(points) {
    if (!points.length) return;
    const lats = points.map((p) => p.lat);
    const lngs = points.map((p) => p.lng);
    const c = { lat: (Math.min(...lats) + Math.max(...lats)) / 2, lng: (Math.min(...lngs) + Math.max(...lngs)) / 2 };
    let z = this.o.maxZoom - 2;
    const w = this.el.clientWidth || 360;
    const hh = this.el.clientHeight || 360;
    while (z > this.o.minZoom) {
      const a = project(Math.max(...lats), Math.min(...lngs), z);
      const b = project(Math.min(...lats), Math.max(...lngs), z);
      if (b.x - a.x < w * 0.8 && b.y - a.y < hh * 0.8) break;
      z--;
    }
    this.setView(c, z);
  }
  setMarkers(list) { this.markers = list; this.render(); }
  setCircles(list) { this.circles = list; this.render(); }
  destroy() { this._ro.disconnect(); window.removeEventListener('pointermove', this._mv); window.removeEventListener('pointerup', this._up); }

  _toLatLng(px, py) {
    const p = project(this.c.lat, this.c.lng, this.z);
    return unproject(p.x + px - this.el.clientWidth / 2, p.y + py - this.el.clientHeight / 2, this.z);
  }
  _xy(lat, lng) {
    const p = project(lat, lng, this.z);
    const c = project(this.c.lat, this.c.lng, this.z);
    return { x: p.x - c.x + this.el.clientWidth / 2, y: p.y - c.y + this.el.clientHeight / 2 };
  }

  _buildSchematic() {
    this.schemItems = SECTORS.map((s) => ({ s, el: h('span', { class: 'schem-label' }, s.name) }));
    this.schemSea = h('span', { class: 'schem-sea' }, 'Mar Caribe');
    this.schemLayer.append(...this.schemItems.map((i) => i.el), this.schemSea);
  }

  render() {
    const w = this.el.clientWidth;
    const hh = this.el.clientHeight;
    if (!w || !hh) return;
    const cp = project(this.c.lat, this.c.lng, this.z);
    const left = cp.x - w / 2;
    const top = cp.y - hh / 2;
    // Teselas
    const n = 2 ** this.z;
    const want = new Set();
    const url = cfg().MAP_TILE_URL || 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    for (let tx = Math.floor(left / TILE); tx <= Math.floor((left + w) / TILE); tx++) {
      for (let ty = Math.floor(top / TILE); ty <= Math.floor((top + hh) / TILE); ty++) {
        if (ty < 0 || ty >= n) continue;
        const x = ((tx % n) + n) % n;
        const key = `${this.z}/${x}/${ty}`;
        want.add(key);
        let img = this.tiles.get(key);
        if (!img) {
          img = new Image();
          img.alt = '';
          img.draggable = false;
          img.decoding = 'async';
          img.className = 'tile';
          img.onload = () => { this.loaded++; img.classList.add('ok'); this.el.classList.remove('no-tiles'); };
          img.onerror = () => { this.failed++; img.remove(); if (!this.loaded) this.el.classList.add('no-tiles'); };
          img.src = url.replace('{z}', this.z).replace('{x}', x).replace('{y}', ty)
            .replace('{s}', 'abc'[(x + ty) % 3]).replace('{accessToken}', cfg().MAP_ACCESS_TOKEN || '');
          this.tiles.set(key, img);
          this.tileLayer.append(img);
        }
        img.style.transform = `translate(${tx * TILE - left}px, ${ty * TILE - top}px)`;
      }
    }
    for (const [k, img] of this.tiles) if (!want.has(k)) { img.remove(); this.tiles.delete(k); }

    // Plano esquemático (respaldo)
    for (const { s, el } of this.schemItems) {
      const p = this._xy(s.lat, s.lng);
      const r = s.r / mpp(s.lat, this.z);
      el.style.transform = `translate(${p.x}px, ${p.y}px)`;
      el.style.setProperty('--r', `${Math.max(18, r)}px`);
    }
    const sea = this._xy(11.23, -74.245);
    this.schemSea.style.transform = `translate(${sea.x}px, ${sea.y}px)`;

    // Círculos
    this.svg.setAttribute('width', w);
    this.svg.setAttribute('height', hh);
    this.svg.replaceChildren(...this.circles.map((c) => {
      const p = this._xy(c.lat, c.lng);
      const e = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      e.setAttribute('cx', p.x); e.setAttribute('cy', p.y);
      e.setAttribute('r', Math.max(8, c.radiusM / mpp(c.lat, this.z)));
      e.setAttribute('fill', c.color); e.setAttribute('fill-opacity', '0.35');
      e.setAttribute('stroke', c.color); e.setAttribute('stroke-width', '2');
      return e;
    }));

    // Marcadores
    const nodes = [];
    for (const m of this.markers) {
      const p = this._xy(m.lat, m.lng);
      if (p.x < -60 || p.y < -60 || p.x > w + 60 || p.y > hh + 60) continue;
      if (!m._el) {
        m._el = h('div', { class: 'mk', role: m.onClick ? 'button' : null, tabindex: m.onClick ? '0' : null, 'aria-label': m.label || null }, m.el);
        if (m.onClick) {
          m._el.addEventListener('click', (e) => { e.stopPropagation(); m.onClick(); });
          m._el.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); m.onClick(); } });
        }
      }
      m._el.style.transform = `translate(${p.x}px, ${p.y}px)`;
      m._el.style.zIndex = String(m.z || 1);
      nodes.push(m._el);
    }
    this.mkLayer.replaceChildren(...nodes);
  }

  _bind() {
    if (!this.o.interactive) { this.controls.hidden = true; return; }
    const el = this.el;
    const pts = new Map();
    let drag = null;
    let pinch = null;
    this._mv = (e) => {
      if (!pts.has(e.pointerId)) return;
      pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pts.size === 2) {
        const [a, b] = [...pts.values()];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (!pinch) pinch = d;
        const rect = el.getBoundingClientRect();
        const mid = { x: (a.x + b.x) / 2 - rect.left, y: (a.y + b.y) / 2 - rect.top };
        if (d / pinch > 1.45) { this.zoomBy(1, mid); pinch = d; }
        else if (d / pinch < 0.69) { this.zoomBy(-1, mid); pinch = d; }
        if (drag) drag.moved = 99;
        return;
      }
      if (!drag) return;
      const dx = e.clientX - drag.x;
      const dy = e.clientY - drag.y;
      drag.moved += Math.abs(dx) + Math.abs(dy);
      drag.x = e.clientX; drag.y = e.clientY;
      const p = project(this.c.lat, this.c.lng, this.z);
      this.c = unproject(p.x - dx, p.y - dy, this.z);
      this.render();
      this.o.onMove?.(this.center, true);
    };
    this._up = (e) => {
      if (!pts.has(e.pointerId)) return;
      pts.delete(e.pointerId);
      if (pts.size < 2) pinch = null;
      if (pts.size === 0) {
        if (drag && drag.moved < 6 && !e.target.closest?.('.mk,.map-btn')) {
          const rect = el.getBoundingClientRect();
          const ll = this._toLatLng(e.clientX - rect.left, e.clientY - rect.top);
          this.o.onTap?.(ll);
        }
        drag = null;
        el.classList.remove('dragging');
      }
    };
    el.addEventListener('pointerdown', (e) => {
      if (e.target.closest('.map-btn')) return;
      pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pts.size === 1) { drag = { x: e.clientX, y: e.clientY, moved: 0 }; el.classList.add('dragging'); }
    });
    window.addEventListener('pointermove', this._mv);
    window.addEventListener('pointerup', this._up);
    window.addEventListener('pointercancel', this._up);
    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      if (this._wheelLock) return;
      this._wheelLock = true;
      setTimeout(() => { this._wheelLock = false; }, 180);
      const rect = el.getBoundingClientRect();
      this.zoomBy(e.deltaY < 0 ? 1 : -1, { x: e.clientX - rect.left, y: e.clientY - rect.top });
    }, { passive: false });
    el.addEventListener('dblclick', (e) => {
      const rect = el.getBoundingClientRect();
      this.zoomBy(1, { x: e.clientX - rect.left, y: e.clientY - rect.top });
    });
    el.addEventListener('keydown', (e) => {
      const step = 80;
      const p = project(this.c.lat, this.c.lng, this.z);
      const moves = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] };
      if (moves[e.key]) {
        e.preventDefault();
        this.c = unproject(p.x + moves[e.key][0], p.y + moves[e.key][1], this.z);
        this.render();
        this.o.onMove?.(this.center, true);
      } else if (e.key === '+' || e.key === '=') this.zoomBy(1);
      else if (e.key === '-') this.zoomBy(-1);
    });
  }
}

/** Marcador redondo coloreado por nivel de importancia. */
export function severityMarker(color, iconName, size = 34, selected = false) {
  return h('span', { class: `sev-mk${selected ? ' sel' : ''}`, style: { '--c': color, '--s': `${size}px` } }, icon(iconName, Math.round(size * 0.5)));
}
