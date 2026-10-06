// Panel administrativo: dashboard, reportes, gestión, usuarios y categorías.
import { CATEGORY_ICONS, PRIORITY_LEVELS, ROLES, SEVERITIES, STATUSES, statusOf } from '../data/catalog.js';
import { donut, hbars, line, vbars } from '../charts.js';
import { MapView } from '../map.js';
import {
  button, confirmDialog, emptyState, field, fmt, h, icon, loading, priorityBadge, sectionTitle, sheet, statusChip, timeline, toast,
} from '../ui.js';
import { V } from '../validators.js';
import { reportCard, reportInfo } from './citizen.js';

const head = (title, ...extra) => h('header', { class: 'page-head' }, h('h1', null, title), ...extra);

// ------------------------------------------------------------------ DASHBOARD
export async function dashboardScreen({ app }) {
  const body = h('div', { class: 'stack' }, loading());
  const ranges = h('div', { class: 'chips' });
  const renderRanges = () => ranges.replaceChildren(...[[7, '7 días'], [30, '30 días'], [90, '90 días'], [null, 'Todo']].map(([d, l]) =>
    h('button', { type: 'button', class: `chip-btn${app.state.dashDays === d ? ' on' : ''}`, onclick: () => { app.state.dashDays = d; renderRanges(); update(); } }, l)));
  renderRanges();

  const openList = (f) => { app.state.adminFilter = { orderBy: 'priority_score', ...f }; app.go('/admin/reports'); };
  const update = async () => {
    let s;
    try { s = await app.backend.dashboard(app.state.dashDays); } catch (e) { body.replaceChildren(h('p', null, e.message)); return; }
    const st = (code) => s.by_status.find((x) => x.code === code)?.count || 0;
    const kpi = (label, n, ic, color, f) => h('button', { type: 'button', class: 'kpi', style: { '--c': color }, onclick: () => openList(f) },
      h('span', { class: 'kpi-ic' }, icon(ic, 22)), h('b', { class: 'num' }, String(n)), h('span', null, label));
    const card = (title, sub, content) => h('section', { class: 'card chart-card' }, h('h3', null, title), sub ? h('p', { class: 'muted small' }, sub) : null, content);
    const hotMap = h('div', { class: 'map-box small' });
    body.replaceChildren(
      h('div', { class: 'kpis' },
        kpi('Total de reportes', s.total, 'assignment', 'var(--ocean)', {}),
        kpi('Recibidos', st('recibido'), 'inbox', statusOf('recibido').color, { statuses: ['recibido'] }),
        kpi('En revisión', st('en_revision'), 'manage_search', statusOf('en_revision').color, { statuses: ['en_revision'] }),
        kpi('Críticos abiertos', s.critical_open, 'crisis_alert', 'var(--bad)', { severities: [5] }),
        kpi('En proceso', st('en_proceso'), 'engineering', statusOf('en_proceso').color, { statuses: ['en_proceso'] }),
        kpi('Atendidos', st('atendido'), 'task_alt', statusOf('atendido').color, { statuses: ['atendido'] }),
        kpi('Cerrados', st('cerrado'), 'lock', statusOf('cerrado').color, { statuses: ['cerrado'] }),
        kpi('Posibles duplicados', s.possible_duplicates, 'content_copy', '#7C3AED', { duplicates: true })),
      h('div', { class: 'charts' },
        card('Reportes por fecha', 'Reportes creados por día', line(s.by_date)),
        card('Reportes por categoría', null, hbars(s.by_category.map((c) => ({ label: c.name, value: c.count, color: c.color })))),
        card('Reportes por nivel de importancia', null, vbars(s.by_severity.map((x) => {
          const sv = SEVERITIES[x.severity - 1];
          return { label: `${sv.level} ${sv.label}`, value: x.count, color: sv.color };
        }))),
        card('Reportes por estado', null, donut(s.by_status.map((x) => ({ label: x.name, value: x.count, color: x.color })))),
        card('Reportes por sector', 'Zonas con mayor concentración de problemáticas', hbars(s.by_sector.map((x) => ({ label: x.name, value: x.count, color: 'var(--turq)' })))),
        card('Prioridad de reportes abiertos', null, hbars(s.by_priority.map((x) => ({ label: PRIORITY_LEVELS[x.level].label, value: x.count, color: PRIORITY_LEVELS[x.level].color })))),
        card('Zonas críticas', 'Puntos con 2 o más reportes abiertos a menos de ~110 m', h('div', { class: 'stack' }, hotMap,
          s.hotspots.length ? h('ul', { class: 'hot-list' }, s.hotspots.slice(0, 5).map((x) => h('li', null,
            h('b', { class: 'hot-n' }, String(x.count)), h('span', null, x.sector || 'Sin sector', h('small', { class: 'muted block' }, `Importancia promedio ${x.avg_severity}`)))))
            : h('p', { class: 'muted' }, 'No hay concentraciones de reportes abiertos.')))),
      h('section', { class: 'card stack' }, h('h3', null, 'Herramientas y datos'),
        h('div', { class: 'row wrap' },
          button('Recalcular prioridades', { kind: 'ghost', ic: 'calculate', id: 'a-recalc', onClick: async () => {
            try { const n = await app.backend.recalculatePriorities(); toast(`Prioridad recalculada en ${n} reportes abiertos`, 'ok'); update(); } catch (e) { toast(e.message, 'error'); }
          } }),
          app.backend.hasTestData() ? button('Eliminar datos de prueba', { kind: 'danger-ghost', ic: 'delete', id: 'a-clear', onClick: async () => {
            if (!(await confirmDialog('Se eliminarán todos los reportes marcados como datos de prueba. ¿Continuar?', { ok: 'Eliminar', danger: true }))) return;
            try { const n = await app.backend.clearTestData(); toast(`${n} reportes de prueba eliminados`, 'ok'); update(); } catch (e) { toast(e.message, 'error'); }
          } }) : null,
          app.backend.mode === 'local' ? button('Descargar copia de seguridad', { kind: 'ghost', ic: 'download', id: 'a-export', onClick: async () => {
            try {
              const data = await app.backend.exportData();
              const blob = new Blob([JSON.stringify(data)], { type: 'application/json' });
              const a = h('a', { href: URL.createObjectURL(blob), download: `registro-riesgos-${new Date().toISOString().slice(0, 10)}.json` });
              document.body.append(a); a.click(); a.remove();
              toast('Copia de seguridad descargada', 'ok');
            } catch (e) { toast(e.message, 'error'); }
          } }) : null,
          app.backend.mode === 'local' ? h('label', { class: 'btn ghost', for: 'a-import' }, icon('upload', 19), h('span', null, 'Restaurar copia')) : null,
          app.backend.mode === 'local' ? h('input', { type: 'file', id: 'a-import', accept: 'application/json,.json', class: 'sr-only', onchange: async (e) => {
            const f = e.target.files?.[0]; e.target.value = '';
            if (!f) return;
            try { const n = await app.backend.importData(JSON.parse(await f.text())); toast(`Copia restaurada: ${n} reportes`, 'ok'); update(); }
            catch (err) { toast(err.message || 'No se pudo leer el archivo.', 'error'); }
          } }) : null),
        app.backend.mode === 'local' ? h('p', { class: 'muted small' }, 'Los datos se guardan en este navegador. Descarga una copia de seguridad con regularidad para no perderlos si cambias de equipo o borras los datos del navegador.') : null),
    );
    requestAnimationFrame(() => {
      const m = new MapView(hotMap, { zoom: 12 });
      m.setCircles(s.hotspots.map((x) => ({ lat: x.lat, lng: x.lng, radiusM: 60 + 25 * x.count, color: SEVERITIES[Math.round(x.avg_severity) - 1].color })));
    });
  };
  update();
  return { el: h('div', { class: 'page wide' }, head('Dashboard'), ranges, body), update };
}

// ------------------------------------------------------------------ LISTADO
export async function adminReportsScreen({ app }) {
  const f = app.state.adminFilter;
  const list = h('div', { class: 'list' }, loading());
  const search = h('input', { type: 'search', id: 'a-search', placeholder: 'Buscar por código, título, dirección…', value: f.search || '' });
  const status = h('select', { id: 'a-status', 'aria-label': 'Estado' }, h('option', { value: '' }, 'Todos los estados'), STATUSES.map((s) => h('option', { value: s.code }, s.name)));
  status.value = f.statuses?.length === 1 ? f.statuses[0] : '';
  const cat = h('select', { id: 'a-cat', 'aria-label': 'Categoría' }, h('option', { value: '' }, 'Todas las categorías'), app.categories(true).map((c) => h('option', { value: String(c.id) }, c.name)));
  cat.value = f.categories?.length === 1 ? String(f.categories[0]) : '';
  const sev = h('select', { id: 'a-sev', 'aria-label': 'Importancia' }, h('option', { value: '' }, 'Toda importancia'), SEVERITIES.map((s) => h('option', { value: String(s.level) }, `${s.level} ${s.label}`)));
  sev.value = f.severities?.length === 1 ? String(f.severities[0]) : '';
  const sort = h('div', { class: 'chips' });
  const renderSort = () => sort.replaceChildren(
    h('button', { type: 'button', class: `chip-btn${f.orderBy === 'priority_score' ? ' on' : ''}`, onclick: () => { f.orderBy = 'priority_score'; renderSort(); update(); } }, 'Mayor prioridad'),
    h('button', { type: 'button', class: `chip-btn${f.orderBy === 'created_at' ? ' on' : ''}`, onclick: () => { f.orderBy = 'created_at'; renderSort(); update(); } }, 'Más recientes'),
    h('button', { type: 'button', class: `chip-btn${f.duplicates ? ' on' : ''}`, onclick: () => { f.duplicates = !f.duplicates; renderSort(); update(); } }, 'Posibles duplicados'));
  renderSort();
  let t;
  search.addEventListener('input', () => { clearTimeout(t); t = setTimeout(() => { f.search = search.value; update(); }, 300); });
  status.onchange = () => { f.statuses = status.value ? [status.value] : []; update(); };
  cat.onchange = () => { f.categories = cat.value ? [Number(cat.value)] : []; update(); };
  sev.onchange = () => { f.severities = sev.value ? [Number(sev.value)] : []; update(); };
  const update = async () => {
    try {
      const rows = await app.backend.adminReports(f);
      list.replaceChildren(h('p', { class: 'muted small' }, `${rows.length} reporte(s)`),
        ...(rows.length ? rows.map((r) => reportCard(app, r, { showPriority: true, onClick: () => app.go(`/admin/reports/${r.id}`) }))
          : [emptyState('search_off', 'Sin resultados', 'Ajusta la búsqueda o los filtros.')]));
    } catch (e) { list.replaceChildren(h('p', null, e.message)); }
  };
  update();
  return { el: h('div', { class: 'page wide' }, head('Reportes'), h('div', { class: 'filters' }, search, status, cat, sev), sort, list), update };
}

// ------------------------------------------------------------------ GESTIÓN
export async function adminReportScreen({ app, params }) {
  const body = h('div', { class: 'stack' }, loading());
  const update = async () => {
    const r = await app.backend.report(params.id);
    if (!r) { body.replaceChildren(emptyState('search_off', 'Reporte no encontrado')); return; }
    const [hist, obs, dups, who] = await Promise.all([
      app.backend.history(r.id), app.backend.observations(r.id), app.backend.duplicates(r.id), r.user_id ? app.backend.reporter(r.user_id) : null,
    ]);
    body.replaceChildren(
      h('section', { class: 'card actions-card stack' },
        h('div', { class: 'row wrap' }, h('strong', null, 'Estado actual: '), statusChip(r.status)),
        h('div', { class: 'row wrap' },
          button('Cambiar estado', { ic: 'swap_horiz', id: 'a-status-btn', onClick: () => statusSheet(app, r, update) }),
          button('Observación', { kind: 'ghost', ic: 'add_comment', id: 'a-obs-btn', onClick: () => observationSheet(app, r, update) }),
          button('Modificar', { kind: 'ghost', ic: 'edit', id: 'a-edit-btn', onClick: () => editSheet(app, r, update) }))),
      h('div', { class: 'two-col' },
        h('div', { class: 'stack' }, reportInfo(app, r)),
        h('div', { class: 'stack' },
          h('section', { class: 'card stack' }, h('h3', null, 'Índice de prioridad'),
            h('div', { class: 'row' }, priorityBadge(r.priority_level, r.priority_score)),
            h('div', { class: 'meter', role: 'meter', 'aria-valuenow': String(Math.round(r.priority_score)), 'aria-valuemin': '0', 'aria-valuemax': '100' },
              h('span', { style: { width: `${r.priority_score}%`, background: PRIORITY_LEVELS[r.priority_level].color } })),
            h('p', { class: 'muted small' }, 'Calculado con importancia, reportes similares, antigüedad, categoría y concentración geográfica.'),
            r.admin_notes ? h('div', null, h('strong', null, 'Notas administrativas'), h('p', null, r.admin_notes)) : null),
          dups.length ? duplicatesCard(app, dups, update) : null,
          who ? h('section', { class: 'card stack' }, h('h3', null, 'Ciudadano (información privada)'),
            h('div', { class: 'row' }, icon('lock_person', 22), h('div', null, h('strong', { class: 'block' }, who.full_name || 'Sin nombre'),
              who.phone ? h('span', { class: 'block' }, who.phone) : null, who.email ? h('span', { class: 'block muted' }, who.email) : null)),
            h('p', { class: 'muted small' }, 'Uso exclusivo para la gestión del reporte.')) : null,
          h('section', { class: 'card stack' }, h('h3', null, 'Historial de estados y observaciones'), timeline(hist, obs, true)))));
  };
  update().catch((e) => body.replaceChildren(h('p', null, e.message)));
  return {
    el: h('div', { class: 'page wide' }, h('header', { class: 'page-head' },
      h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Volver', onclick: () => app.go('/admin/reports') }, icon('arrow_back', 22)),
      h('h1', null, 'Gestionar reporte')), body),
    update,
  };
}

function duplicatesCard(app, dups, update) {
  const decide = async (d, decision) => {
    try { await app.backend.resolveDuplicate(d.id, decision); toast(decision === 'confirmado' ? 'Marcado como duplicado' : 'Coincidencia descartada', 'ok'); update(); }
    catch (e) { toast(e.message, 'error'); }
  };
  return h('section', { class: 'card stack dup-card' }, h('h3', null, 'Posibles duplicados'),
    dups.map((d) => h('div', { class: 'dup-item stack' },
      h('strong', null, `${d.candidate_code} · ${d.candidate_title}`),
      h('small', { class: 'muted' }, `A ${Math.round(d.distance_m)} m · similitud de texto ${Math.round(d.text_similarity * 100)}% · puntaje ${Math.round(d.score * 100)}% · decisión: ${d.decision}`),
      h('div', { class: 'row wrap' },
        button('Ver original', { kind: 'link', onClick: () => app.go(`/admin/reports/${d.candidate_id}`) }),
        d.decision !== 'confirmado' ? button('Es duplicado', { kind: 'ghost', id: `dup-yes-${d.id}`, onClick: () => decide(d, 'confirmado') }) : null,
        d.decision !== 'descartado' ? button('No es duplicado', { kind: 'ghost', id: `dup-no-${d.id}`, onClick: () => decide(d, 'descartado') }) : null))),
    h('p', { class: 'muted small' }, 'Ningún reporte se elimina automáticamente. Confirmar un duplicado lo vincula al original y lo oculta del mapa público.'));
}

function statusSheet(app, r, done) {
  const note = h('textarea', { id: 's-note', rows: 3, maxlength: '2000', placeholder: 'Ej.: Se verificó en campo. Se requiere intervención vial.' });
  let chosen = null;
  const opts = h('div', { class: 'stack tight', role: 'radiogroup' }, STATUSES.filter((s) => s.code !== r.status).map((s) => {
    const b = h('button', { type: 'button', role: 'radio', class: 'status-opt', 'aria-checked': 'false', 'data-code': s.code, style: { '--c': s.color } }, icon(s.icon, 18), s.name);
    b.onclick = () => { chosen = s.code; opts.querySelectorAll('.status-opt').forEach((x) => { x.classList.toggle('on', x === b); x.setAttribute('aria-checked', String(x === b)); }); };
    return b;
  }));
  sheet((api) => h('div', { class: 'stack' }, opts,
    field('Observación (visible para el ciudadano)', note, { optional: true }),
    h('p', { class: 'muted small' }, 'Se registrará: estado anterior, nuevo estado, fecha y administrador responsable.'),
    h('div', { class: 'row end' }, button('Cancelar', { kind: 'ghost', onClick: api.close }),
      button('Guardar', { id: 's-save', onClick: async () => {
        if (!chosen) { toast('Selecciona el nuevo estado.', 'error'); return; }
        try { await app.backend.changeStatus(r.id, chosen, note.value); toast(`Estado cambiado a ${statusOf(chosen).name}`, 'ok'); api.close(); done(); }
        catch (e) { toast(e.message, 'error'); }
      } }))), { title: 'Cambiar estado' });
}

function observationSheet(app, r, done) {
  const body = h('textarea', { id: 'o-body', rows: 4, maxlength: '2000' });
  const pub = h('input', { type: 'checkbox', id: 'o-public', checked: true });
  sheet((api) => h('div', { class: 'stack' }, field('Observación', body),
    h('label', { class: 'check' }, pub, h('span', null, 'Visible para el ciudadano (se le notificará)')),
    h('div', { class: 'row end' }, button('Cancelar', { kind: 'ghost', onClick: api.close }),
      button('Agregar', { id: 'o-save', onClick: async () => {
        try { await app.backend.addObservation(r.id, body.value, pub.checked); toast('Observación agregada', 'ok'); api.close(); done(); }
        catch (e) { toast(e.message, 'error'); }
      } }))), { title: 'Agregar observación' });
}

function editSheet(app, r, done) {
  const title = h('input', { id: 'm-title', type: 'text', value: r.title, maxlength: '120' });
  const desc = h('textarea', { id: 'm-desc', rows: 4, maxlength: '2000' }); desc.value = r.description;
  const cat = h('select', { id: 'm-cat' }, app.categories(true).map((c) => h('option', { value: String(c.id) }, c.name))); cat.value = String(r.category_id);
  const sev = h('select', { id: 'm-sev' }, SEVERITIES.map((s) => h('option', { value: String(s.level) }, `${s.level} ${s.label}`))); sev.value = String(r.severity);
  const addr = h('input', { id: 'm-addr', type: 'text', value: r.address || '', maxlength: '250' });
  const notes = h('textarea', { id: 'm-notes', rows: 3 }); notes.value = r.admin_notes || '';
  const fT = field('Título', title); const fD = field('Descripción', desc);
  sheet((api) => h('div', { class: 'stack' }, fT, fD, field('Categoría', cat), field('Nivel de importancia', sev),
    field('Dirección / referencia', addr, { optional: true }), field('Notas administrativas (internas)', notes, { optional: true }),
    h('div', { class: 'row end' }, button('Cancelar', { kind: 'ghost', onClick: api.close }),
      button('Guardar cambios', { id: 'm-save', onClick: async () => {
        fT.setError(V.title(title.value)); fD.setError(V.description(desc.value));
        if (V.title(title.value) || V.description(desc.value)) return;
        try {
          await app.backend.updateReport(r.id, {
            title: title.value.trim(), description: desc.value.trim(), category_id: Number(cat.value), severity: Number(sev.value),
            address: addr.value.trim() || null, admin_notes: notes.value.trim() || null,
          });
          toast('Reporte actualizado', 'ok'); api.close(); done();
        } catch (e) { toast(e.message, 'error'); }
      } }))), { title: 'Modificar información' });
}

// ------------------------------------------------------------------ USUARIOS
export async function usersScreen({ app }) {
  const list = h('div', { class: 'list' }, loading());
  const search = h('input', { type: 'search', id: 'u-search', placeholder: 'Buscar por nombre' });
  const update = async () => {
    try {
      const rows = await app.backend.users(search.value);
      list.replaceChildren(...rows.map((u) => {
        const role = h('select', { 'aria-label': `Rol de ${u.full_name}`, disabled: !app.isAdmin || u.id === app.me.id || !app.backend.features.userAdmin },
          Object.entries(ROLES).map(([k, v]) => h('option', { value: k }, v)));
        role.value = u.role;
        role.onchange = async () => {
          try { await app.backend.updateUser(u.id, { role: role.value }); toast('Rol actualizado', 'ok'); } catch (e) { toast(e.message, 'error'); role.value = u.role; }
        };
        const active = h('button', { type: 'button', class: 'btn ghost small', disabled: !app.isAdmin || u.id === app.me.id || !app.backend.features.userAdmin,
          onclick: async () => { try { await app.backend.updateUser(u.id, { is_active: !u.is_active }); update(); } catch (e) { toast(e.message, 'error'); } } },
          u.is_active === false ? 'Activar' : 'Desactivar');
        return h('div', { class: 'card user-row' },
          h('span', { class: 'avatar small' }, (u.full_name || '?')[0].toUpperCase()),
          h('div', { class: 'grow' }, h('strong', { class: 'block' }, u.full_name || '(sin nombre)'),
            h('small', { class: 'muted' }, [u.email, u.is_active === false ? 'INACTIVO' : null, u.created_at ? `desde ${fmt.short(u.created_at)}` : null].filter(Boolean).join(' · '))),
          role, active);
      }));
    } catch (e) { list.replaceChildren(h('p', null, e.message)); }
  };
  let t;
  search.addEventListener('input', () => { clearTimeout(t); t = setTimeout(update, 300); });
  update();
  const note = !app.backend.features.userAdmin ? h('p', { class: 'notice' }, 'En el enlace de demostración compartido los permisos se administran con el botón Compartir de claude.ai: quien tenga rol Editor es administrador.') : null;
  return { el: h('div', { class: 'page wide' }, head('Usuarios'), note, search, list), update };
}

// ------------------------------------------------------------------ CATEGORÍAS
export async function categoriesScreen({ app }) {
  const list = h('div', { class: 'list' });
  const render = () => list.replaceChildren(...app.categories(true).map((c) => h('button', { type: 'button', class: 'card cat-row', onclick: () => app.isAdmin && categorySheet(app, c, render) },
    h('span', { class: 'cat-ic big', style: { '--c': c.color } }, icon(c.icon, 22)),
    h('div', { class: 'grow' }, h('strong', { class: 'block', style: { textDecoration: c.active ? 'none' : 'line-through' } }, c.name),
      h('small', { class: 'muted' }, `Peso de prioridad ${Number(c.weight).toFixed(2)} · ${c.keywords.length} palabras clave${c.active ? '' : ' · inactiva'}`)),
    app.isAdmin ? icon('edit', 18) : null)));
  render();
  return {
    el: h('div', { class: 'page wide' }, head('Categorías', app.isAdmin ? button('Nueva', { ic: 'add', id: 'c-new', onClick: () => categorySheet(app, null, render) }) : null), list),
    update: render,
  };
}

function categorySheet(app, c, done) {
  const name = h('input', { id: 'c-name', type: 'text', value: c?.name || '', maxlength: '60' });
  const code = h('input', { id: 'c-code', type: 'text', value: c?.code || '', disabled: !!c });
  const color = h('input', { id: 'c-color', type: 'color', value: c?.color || '#0077B6' });
  const weight = h('input', { id: 'c-weight', type: 'range', min: '0.5', max: '1.5', step: '0.05', value: String(c?.weight ?? 1) });
  const wLabel = h('output', null, Number(weight.value).toFixed(2));
  weight.oninput = () => { wLabel.textContent = Number(weight.value).toFixed(2); };
  const kw = h('textarea', { id: 'c-kw', rows: 3 }); kw.value = (c?.keywords || []).join(', ');
  const active = h('input', { type: 'checkbox', id: 'c-active', checked: c ? c.active : true });
  let ic = c?.icon || 'report';
  const icons = h('div', { class: 'chips' }, CATEGORY_ICONS.map((n) => {
    const b = h('button', { type: 'button', class: `chip-btn icon-only${n === ic ? ' on' : ''}`, 'aria-label': n }, icon(n, 20));
    b.onclick = () => { ic = n; icons.querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b)); };
    return b;
  }));
  const fName = field('Nombre', name); const fCode = field('Código interno (a-z y _)', code);
  sheet((api) => h('div', { class: 'stack' }, fName, fCode, field('Color', color), h('h4', null, 'Ícono'), icons,
    field('Peso en el índice de prioridad', h('div', { class: 'row' }, weight, wLabel)),
    field('Palabras clave (separadas por coma)', kw, { hint: 'Se usan para sugerir automáticamente esta categoría.' }),
    h('label', { class: 'check' }, active, h('span', null, 'Categoría activa')),
    h('div', { class: 'row end' }, button('Cancelar', { kind: 'ghost', onClick: api.close }),
      button('Guardar', { id: 'c-save', onClick: async () => {
        fName.setError(name.value.trim().length < 2 ? 'Nombre requerido' : '');
        fCode.setError(/^[a-z_]{2,40}$/.test(code.value.trim()) ? '' : 'Solo minúsculas y _');
        if (name.value.trim().length < 2 || !/^[a-z_]{2,40}$/.test(code.value.trim())) return;
        try {
          await app.backend.saveCategory({
            id: c?.id, code: code.value.trim(), name: name.value.trim(), color: color.value.toUpperCase(), icon: ic,
            weight: Number(weight.value), keywords: kw.value.split(',').map((x) => x.trim().toLowerCase()).filter(Boolean),
            active: active.checked, order: c?.order ?? 50,
          });
          toast('Categoría guardada', 'ok'); api.close(); done();
        } catch (e) { toast(e.message, 'error'); }
      } }))), { title: c ? 'Editar categoría' : 'Nueva categoría' });
}
