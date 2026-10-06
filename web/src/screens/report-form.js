// "REPORTAR PROBLEMÁTICA": formulario A–H, confirmación y resultado.
import { SEVERITIES, CENTER, insideDistrict, severityOf } from '../data/catalog.js';
import { suggestCategory } from '../data/engine.js';
import { uuid } from '../data/stores.js';
import { compressImage, isNetworkError, locate, queue } from '../device.js';
import { MapView } from '../map.js';
import { button, field, fmt, h, icon, severityBadge, statusChip, toast } from '../ui.js';
import { V } from '../validators.js';

function newDraft() {
  return {
    client_uuid: uuid(), title: '', description: '', category_id: null, severity: null,
    latitude: CENTER.lat, longitude: CENTER.lng, accuracy: null, gps: false, address: '', photo: null,
    reported_at: new Date().toISOString(),
  };
}

const step = (letter, title, optional) => h('div', { class: 'step' },
  h('span', { class: 'step-n' }, letter), h('h2', null, title), optional ? h('em', null, 'opcional') : null);

export async function newReportScreen({ app }) {
  const d = app.state.draft || (app.state.draft = newDraft());
  const cats = app.categories();

  // A. Título
  const title = h('input', { id: 'r-title', type: 'text', maxlength: '120', value: d.title, placeholder: 'Ej.: Gran hueco en la Avenida Libertador' });
  const fTitle = field('Título', title);
  // B. Descripción
  const desc = h('textarea', { id: 'r-desc', rows: 5, maxlength: '2000', placeholder: 'Explica qué está ocurriendo, desde cuándo y a quién afecta.' });
  desc.value = d.description;
  const fDesc = field('Descripción', desc);
  // C. Categoría + sugerencia
  const suggestBox = h('div', { class: 'suggest', hidden: true });
  const catGrid = h('div', { class: 'chips', role: 'radiogroup', 'aria-label': 'Categoría' });
  const renderCats = () => catGrid.replaceChildren(...cats.map((c) => h('button', {
    type: 'button', role: 'radio', 'aria-checked': String(d.category_id === c.id),
    class: `chip-btn${d.category_id === c.id ? ' on' : ''}`, style: { '--c': c.color },
    onclick: () => { d.category_id = c.id; renderCats(); updateSuggestion(); },
  }, icon(c.icon, 18), c.name)));
  renderCats();
  // D. Importancia
  const sevExplain = h('div', { class: 'sev-explain', 'aria-live': 'polite' });
  const sevRow = h('div', { class: 'sev-row', role: 'radiogroup', 'aria-label': 'Nivel de importancia' });
  const renderSev = () => {
    sevRow.replaceChildren(...SEVERITIES.map((s) => h('button', {
      type: 'button', role: 'radio', 'aria-checked': String(d.severity === s.level),
      class: `sev-opt${d.severity === s.level ? ' on' : ''}`, style: { '--c': s.color },
      onclick: () => { d.severity = s.level; renderSev(); },
    }, h('b', null, String(s.level)), h('span', null, s.label))));
    const s = d.severity ? severityOf(d.severity) : null;
    sevExplain.replaceChildren(s ? h('div', { class: 'sev-note', style: { '--c': s.color } }, icon(s.icon, 22, s.color), h('span', null, h('strong', null, `${s.label}: `), s.text))
      : h('p', { class: 'muted' }, 'Selecciona qué tan grave es la problemática.'));
  };
  renderSev();
  // E. Ubicación
  const coords = h('span', { class: 'muted small' });
  const mapBox = h('div', { class: 'map-box picker' });
  const gpsBtn = button('Usar mi ubicación', { kind: 'ghost', ic: 'my_location', id: 'r-gps' });
  const showCoords = () => {
    coords.textContent = `${fmt.coords(d.latitude, d.longitude)}${d.accuracy ? ` (±${Math.round(d.accuracy)} m)` : ''}${d.gps ? ' · GPS' : ' · ajustada en el mapa'}`;
  };
  let map;
  const doLocate = async () => {
    gpsBtn.disabled = true;
    const r = await locate();
    gpsBtn.disabled = false;
    if (r.error) { toast(r.error, 'error'); return; }
    if (!insideDistrict(r.lat, r.lng)) { toast('Tu ubicación está fuera del Distrito de Santa Marta. Ubica el punto en el mapa.', 'error'); return; }
    Object.assign(d, { latitude: r.lat, longitude: r.lng, accuracy: r.accuracy, gps: true });
    map?.setView({ lat: r.lat, lng: r.lng }, 17);
    showCoords();
  };
  gpsBtn.onclick = doLocate;
  // F. Dirección
  const address = h('input', { id: 'r-address', type: 'text', maxlength: '250', value: d.address, placeholder: 'Ej.: Avenida Libertador, cerca de la entrada al barrio X' });
  const fAddress = field('Dirección o referencia', address, { optional: true });
  // G. Fotografía
  const preview = h('div', { class: 'photo-preview' });
  const cam = h('input', { type: 'file', accept: 'image/*', capture: 'environment', class: 'sr-only', id: 'r-camera' });
  const gal = h('input', { type: 'file', accept: 'image/*', class: 'sr-only', id: 'r-gallery' });
  const onFile = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try { d.photo = await compressImage(file); renderPhoto(); }
    catch (err) { toast(err.message, 'error'); }
  };
  cam.onchange = onFile; gal.onchange = onFile;
  const renderPhoto = () => {
    preview.replaceChildren(d.photo
      ? h('div', { class: 'photo-sel' }, h('img', { src: d.photo, alt: 'Vista previa de la fotografía' }),
        h('button', { type: 'button', class: 'icon-btn on-photo', 'aria-label': 'Quitar fotografía', onclick: () => { d.photo = null; renderPhoto(); } }, icon('delete', 20)))
      : h('div', { class: 'photo-pick' },
        h('label', { for: 'r-camera', class: 'pick' }, icon('photo_camera', 30), 'Tomar foto'),
        h('label', { for: 'r-gallery', class: 'pick' }, icon('photo_library', 30), 'Galería')));
  };
  renderPhoto();

  // Sugerencia automática de categoría y nivel (clasificador local).
  let tmr;
  const updateSuggestion = () => {
    const s = suggestCategory(title.value, desc.value, cats);
    if (!s || s.category.id === d.category_id) { suggestBox.hidden = true; return; }
    suggestBox.hidden = false;
    suggestBox.style.setProperty('--c', s.category.color);
    suggestBox.replaceChildren(icon('lightbulb', 20, s.category.color),
      h('div', null, h('strong', null, `¿Categoría "${s.category.name}"?`), h('small', { class: 'muted block' }, `Detectado: ${s.matched.slice(0, 3).join(', ')}`)),
      button('Usar', { kind: 'ghost', id: 'r-suggest', onClick: () => {
        d.category_id = s.category.id;
        if (!d.severity && s.severity) { d.severity = s.severity; renderSev(); }
        renderCats(); suggestBox.hidden = true;
      } }));
  };
  for (const el of [title, desc]) {
    el.addEventListener('input', () => {
      d.title = title.value; d.description = desc.value;
      clearTimeout(tmr); tmr = setTimeout(updateSuggestion, 450);
    });
  }
  address.addEventListener('input', () => { d.address = address.value; });

  const review = () => {
    const eT = V.title(title.value); const eD = V.description(desc.value); const eA = V.address(address.value);
    fTitle.setError(eT); fDesc.setError(eD); fAddress.setError(eA);
    let problem = eT || eD || eA;
    if (!problem && !d.category_id) problem = 'Selecciona una categoría.';
    if (!problem && !d.severity) problem = 'Selecciona el nivel de importancia.';
    if (!problem && !insideDistrict(d.latitude, d.longitude)) problem = 'La ubicación debe estar dentro del Distrito de Santa Marta.';
    if (problem) { toast(problem, 'error'); (eT ? title : eD ? desc : null)?.focus(); return; }
    d.title = title.value.trim(); d.description = desc.value.trim(); d.address = address.value.trim();
    app.go('/report/confirm');
  };

  const el = h('div', { class: 'page form-page' },
    h('header', { class: 'page-head' },
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Volver', onclick: () => history.length > 1 ? history.back() : app.go('/home') }, icon('arrow_back', 22)),
      h('h1', null, 'Reportar problemática')),
    h('form', { class: 'stack', novalidate: true, onsubmit: (e) => { e.preventDefault(); review(); } },
      step('A', 'Título'), fTitle,
      step('B', 'Descripción'), fDesc,
      step('C', 'Categoría'), suggestBox, catGrid,
      step('D', 'Nivel de importancia'), sevRow, sevExplain,
      step('E', 'Ubicación'),
      h('p', { class: 'muted small' }, 'Mueve el mapa o toca un punto para ajustar el marcador.'),
      mapBox, h('div', { class: 'row between wrap' }, coords, gpsBtn),
      step('F', 'Dirección o referencia', true), fAddress,
      step('G', 'Fotografía', true), cam, gal, preview,
      step('H', 'Fecha y hora'),
      h('p', { class: 'muted' }, icon('schedule', 16), ` Se registra automáticamente: ${fmt.dateTime(d.reported_at)}`),
      h('div', { class: 'sticky-actions' }, button('Revisar reporte', { type: 'submit', ic: 'fact_check', full: true, id: 'r-review' }))));

  requestAnimationFrame(() => {
    map = new MapView(mapBox, {
      center: { lat: d.latitude, lng: d.longitude }, zoom: d.gps ? 17 : 15, pin: true,
      onMove: (c) => { Object.assign(d, { latitude: c.lat, longitude: c.lng, accuracy: null, gps: false }); showCoords(); },
      onTap: (ll) => { map.setView(ll); Object.assign(d, { latitude: ll.lat, longitude: ll.lng, accuracy: null, gps: false }); showCoords(); },
    });
    showCoords();
    if (!d.gps && !d._located) { d._located = true; doLocate(); }
  });
  updateSuggestion();
  return { el, destroy: () => map?.destroy() };
}

export async function confirmScreen({ app }) {
  const d = app.state.draft;
  if (!d || !d.title) { app.go('/report/new'); return h('div'); }
  const cat = app.cat(d.category_id);
  const sev = severityOf(d.severity);
  const send = button('Enviar reporte', { kind: 'coral', ic: 'send', id: 'r-send' });
  const row = (ic, label, value) => h('div', { class: 'kv' }, icon(ic, 19), h('span', { class: 'k' }, label), h('span', { class: 'v' }, value));
  send.onclick = async () => {
    send.disabled = true; send.classList.add('busy');
    const draft = { ...d };
    delete draft._located;
    try {
      if (app.backend.mode !== 'local' && !navigator.onLine) throw new TypeError('offline');
      const r = await app.backend.createReport(draft);
      app.state.result = { queued: false, code: r.code, id: r.id };
    } catch (e) {
      if (isNetworkError(e) && app.backend.mode !== 'local') {
        await queue.add(draft);
        app.pending++;
        app.state.result = { queued: true };
      } else { toast(e.message, 'error'); send.disabled = false; send.classList.remove('busy'); return; }
    }
    app.state.draft = null;
    app.go('/report/success');
  };
  const mapBox = h('div', { class: 'map-box small' });
  const el = h('div', { class: 'page form-page' },
    h('header', { class: 'page-head' },
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Editar', onclick: () => app.go('/report/new') }, icon('arrow_back', 22)),
      h('h1', null, 'Confirmar reporte')),
    h('p', { class: 'muted' }, 'Revisa la información antes de enviarla.'),
    d.photo ? h('img', { class: 'confirm-photo', src: d.photo, alt: 'Fotografía del reporte' })
      : h('div', { class: 'card row' }, icon('no_photography', 22), 'Sin fotografía'),
    h('article', { class: 'card stack' },
      h('h2', { class: 'title-lg' }, d.title),
      h('p', null, d.description),
      h('hr'),
      row('category', 'Categoría', cat?.name || '—'),
      row('priority_high', 'Importancia', severityBadge(d.severity)),
      h('p', { class: 'muted small indent' }, sev.text),
      row('place', 'Dirección', d.address || 'No indicada'),
      row('my_location', 'Ubicación', fmt.coords(d.latitude, d.longitude)),
      row('event', 'Fecha', fmt.dateTime(d.reported_at))),
    mapBox,
    h('div', { class: 'sticky-actions row' }, button('Editar', { kind: 'ghost', onClick: () => app.go('/report/new') }), send));
  let map;
  requestAnimationFrame(() => {
    map = new MapView(mapBox, { center: { lat: d.latitude, lng: d.longitude }, zoom: 16, interactive: false });
    map.setMarkers([{ lat: d.latitude, lng: d.longitude, el: h('span', { class: 'pin-mk' }, icon('location_on', 40)) }]);
  });
  return { el, destroy: () => map?.destroy() };
}

export async function successScreen({ app }) {
  const r = app.state.result || { queued: true };
  return h('div', { class: 'page success' },
    h('div', { class: `success-ic ${r.queued ? 'queued' : ''}` }, icon(r.queued ? 'cloud_upload' : 'check_circle', 72)),
    h('h1', null, r.queued ? 'Reporte guardado' : 'Reporte enviado correctamente.'),
    r.queued
      ? h('p', null, 'Reporte guardado. Se enviará automáticamente cuando recuperes la conexión.')
      : h('div', { class: 'stack center' },
        h('p', { class: 'muted' }, 'Código de seguimiento'),
        h('button', {
          type: 'button', class: 'code-big', id: 'r-code', title: 'Copiar código',
          onclick: async () => { try { await navigator.clipboard.writeText(r.code); toast('Código copiado', 'ok'); } catch { toast(r.code); } },
        }, r.code, icon('content_copy', 18)),
        h('p', { class: 'row center' }, 'Estado inicial: ', statusChip('recibido'))),
    h('div', { class: 'stack actions' },
      !r.queued && r.id ? button('Ver mi reporte', { kind: 'ghost', full: true, onClick: () => app.go(`/my-reports/${r.id}`) }) : null,
      button('Volver al inicio', { full: true, onClick: () => app.go('/home') })));
}
