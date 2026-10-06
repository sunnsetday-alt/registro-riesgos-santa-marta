// Compila la aplicación web en web/dist (PWA lista para publicar) y
// web/dist-artifact/index.html (un solo archivo, para el enlace de demostración).
// Uso:  node tools/build.mjs   (requiere esbuild; sharp es opcional para íconos)
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

const require = createRequire(import.meta.url);
const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
const tryRequire = (names) => { for (const n of names) { try { return require(n); } catch {} } return null; };
const esbuild = tryRequire(['esbuild', '/opt/npm-tools/node_modules/esbuild']);
const sharp = tryRequire(['sharp', '/opt/npm-tools/node_modules/sharp']);
if (!esbuild) { console.error('Falta esbuild: npm install esbuild'); process.exit(1); }

const VERSION = new Date().toISOString().replace(/\D/g, '').slice(0, 12);
rmSync(DIST, { recursive: true, force: true });
mkdirSync(join(DIST, 'icons'), { recursive: true });

await esbuild.build({
  entryPoints: [join(ROOT, 'src/main.js')], bundle: true, format: 'iife', target: ['es2020'], minify: true,
  loader: { '.md': 'text' }, outfile: join(DIST, 'app.js'), legalComments: 'none', logLevel: 'warning',
});
await esbuild.build({ entryPoints: [join(ROOT, 'src/styles.css')], bundle: true, minify: true, outfile: join(DIST, 'app.css'), logLevel: 'warning' });

// Íconos de la aplicación (PNG) a partir de un SVG.
const mark = (bg, pad) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#03256c"/><stop offset=".6" stop-color="#0077b6"/><stop offset="1" stop-color="#00b4d8"/></linearGradient></defs>
  ${bg}
  <g transform="translate(${pad} ${pad}) scale(${(512 - pad * 2) / 512})">
    <path d="M256 92c-62 0-112 50-112 112 0 84 112 196 112 196s112-112 112-196c0-62-50-112-112-112z" fill="#fff"/>
    <circle cx="256" cy="204" r="44" fill="#f2594b"/>
    <path d="M86 388c28-20 56-20 84 0s56 20 84 0 56-20 84 0 56 20 84 0" fill="none" stroke="#90e0ef" stroke-width="22" stroke-linecap="round"/>
    <path d="M86 436c28-20 56-20 84 0s56 20 84 0 56-20 84 0 56 20 84 0" fill="none" stroke="#fff" stroke-opacity=".55" stroke-width="22" stroke-linecap="round"/>
  </g></svg>`;
const rounded = mark('<rect width="512" height="512" rx="112" fill="url(#g)"/>', 40);
const full = mark('<rect width="512" height="512" fill="url(#g)"/>', 96);
writeFileSync(join(DIST, 'icons/icon.svg'), rounded);
if (sharp) {
  for (const [name, svg, size] of [
    ['icon-192.png', rounded, 192], ['icon-512.png', rounded, 512],
    ['maskable-192.png', full, 192], ['maskable-512.png', full, 512], ['apple-touch-icon.png', full, 180],
  ]) await sharp(Buffer.from(svg)).resize(size, size).png().toFile(join(DIST, 'icons', name));
} else console.log('sharp no disponible: se usan los íconos PNG de public/icons.');

// Archivos públicos (con versión) y capturas para el manifest.
for (const f of readdirSync(join(ROOT, 'public'))) {
  const src = join(ROOT, 'public', f);
  if (f === 'icons') { cpSync(src, join(DIST, 'icons'), { recursive: true }); continue; }
  let text = readFileSync(src, 'utf8').replaceAll('__VERSION__', VERSION);
  writeFileSync(join(DIST, f), text);
}
const precache = ['./', 'index.html', 'app.js', 'app.css', 'config.js', 'manifest.webmanifest',
  ...readdirSync(join(DIST, 'icons')).filter((f) => f.endsWith('.png') || f.endsWith('.svg')).map((f) => `icons/${f}`)];
writeFileSync(join(DIST, 'sw.js'), readFileSync(join(DIST, 'sw.js'), 'utf8').replace('__FILES__', JSON.stringify(precache)));
writeFileSync(join(DIST, '.nojekyll'), '');
writeFileSync(join(DIST, '404.html'), readFileSync(join(DIST, 'index.html'), 'utf8'));

// Versión de un solo archivo para el enlace de demostración en claude.ai.
const ART = join(ROOT, 'dist-artifact');
mkdirSync(ART, { recursive: true });
const css = readFileSync(join(DIST, 'app.css'), 'utf8');
const js = readFileSync(join(DIST, 'app.js'), 'utf8').replace(/<\/script/gi, '<\\/script');
const cfg = readFileSync(join(ROOT, 'public/config.js'), 'utf8');
writeFileSync(join(ART, 'index.html'), `<title>Registro de Riesgos Santa Marta</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=Bricolage+Grotesque:opsz,wght@12..96,600..800&display=swap">
<style>${css}</style>
<div id="app"></div>
<script>${cfg}</script>
<script>${js}</script>
`);
const kb = (p) => `${Math.round(readFileSync(p).length / 1024)} KB`;
console.log(`dist/ listo (versión ${VERSION}) · app.js ${kb(join(DIST, 'app.js'))} · app.css ${kb(join(DIST, 'app.css'))} · artifact ${kb(join(ART, 'index.html'))}`);
if (!existsSync(join(DIST, 'icons/icon-192.png'))) process.exitCode = 1;
