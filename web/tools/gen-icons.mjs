// Genera src/icons.gen.js con los íconos de Material Design (Apache 2.0)
// usados por la app, extrayendo sus trazos SVG de react-icons/md.
// Uso: node tools/gen-icons.mjs <ruta a react-icons/md/index.js>
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const require = createRequire(import.meta.url);
const md = require(process.argv[2] || 'react-icons/md');
const SRC = new URL('../src/', import.meta.url).pathname;

// Equivalencias cuando el nombre de Material no existe en el paquete.
const ALIAS = { crisis_alert: 'MdReportProblem', signpost: 'MdSignpost', flood: 'MdFlood', lock_person: 'MdLockPerson' };
const FALLBACK = { crisis_alert: 'MdWarning', signpost: 'MdDirections', flood: 'MdWaves', lock_person: 'MdLock' };

const files = [];
(function walk(d) {
  for (const f of readdirSync(d)) {
    const p = join(d, f);
    if (statSync(p).isDirectory()) walk(p);
    else if (p.endsWith('.js') && !p.endsWith('icons.gen.js')) files.push(p);
  }
})(SRC);

const names = new Set(['help', 'close', 'image', 'add', 'remove', 'location_on']);
const strict = new Set();
for (const f of files) {
  const s = readFileSync(f, 'utf8');
  for (const m of s.matchAll(/(?:icon|kv|tile)\(\s*'([a-z][a-z0-9_]*)'/g)) { names.add(m[1]); strict.add(m[1]); }
  for (const m of s.matchAll(/\b(?:icon|ic):\s*'([a-z][a-z0-9_]*)'/g)) { names.add(m[1]); strict.add(m[1]); }
  for (const m of s.matchAll(/'([a-z][a-z0-9_]{2,})'/g)) names.add(m[1]);
}
// Íconos de categorías editables.
for (const m of readFileSync(join(SRC, 'data/catalog.js'), 'utf8').matchAll(/'([a-z][a-z_]+)'/g)) names.add(m[1]);

const pascal = (n) => `Md${n.split('_').map((p) => p[0].toUpperCase() + p.slice(1)).join('')}`;
function toSvg(node) {
  return (node.child || []).map((c) => {
    const attrs = Object.entries(c.attr || {}).map(([k, v]) => `${k.replace(/[A-Z]/g, (x) => `-${x.toLowerCase()}`)}="${v}"`).join(' ');
    return `<${c.tag} ${attrs}>${toSvg(c)}</${c.tag}>`;
  }).join('');
}
const out = {};
const missing = [];
for (const n of [...names].sort()) {
  let fn = md[ALIAS[n]] || md[pascal(n)] || md[FALLBACK[n]];
  if (!fn) { if (strict.has(n)) missing.push(n); continue; }
  const json = fn.toString().match(/GenIcon\((\{[\s\S]*\})\)\(props\)/);
  if (!json) { missing.push(n); continue; }
  const tree = JSON.parse(json[1]);
  out[n] = toSvg(tree).replace(/<path fill="none" d="M0 0h24v24H0z"><\/path>/g, '').replace(/<path fill="none" d="M0 0h24v24H0V0z"><\/path>/g, '');
}
if (missing.length) { console.error('Íconos no encontrados:', missing.join(', ')); process.exit(1); }
writeFileSync(join(SRC, 'icons.gen.js'),
  `// Generado por tools/gen-icons.mjs — Material Design Icons (Apache License 2.0).\nexport const ICONS = ${JSON.stringify(out, null, 0)};\n`);
console.log(`icons.gen.js: ${Object.keys(out).length} íconos`);
