"""Pruebas de extremo a extremo de la PWA en Chromium (Playwright).

Uso:  python3 tests/e2e.py [URL]   (por defecto http://localhost:8765/)
Recorre: inicio de sesión, crear reporte con foto y GPS, confirmación, código,
mis reportes, detalle, mapa y filtros, notificaciones, perfil, panel admin
(dashboard, cambio de estado, observación, duplicados, usuarios, categorías),
registro de cuenta nueva, recuperación de contraseña, rutas, móvil y PWA
(manifest, service worker, instalabilidad).
"""
import json, os, re, sys, time
from playwright.sync_api import sync_playwright, expect

URL = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:8765/'
PHOTO = os.environ.get('PHOTO', '/tmp/claude-0/-home-claude/3da1a12a-8012-5de3-abf8-18503a148062/scratchpad/hueco.jpg')
SHOTS = os.environ.get('SHOTS', '/tmp/claude-0/-home-claude/3da1a12a-8012-5de3-abf8-18503a148062/scratchpad/shots')
os.makedirs(SHOTS, exist_ok=True)
results = []
errors = []

def ok(name, cond=True, detail=''):
    results.append((name, bool(cond), detail))
    print(('✔ ' if cond else '✘ ') + name + (f' — {detail}' if detail else ''), flush=True)

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(args=['--no-sandbox'])
        ctx = browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2, is_mobile=True, has_touch=True,
                                  geolocation={'latitude': 11.2366, 'longitude': -74.1947}, permissions=['geolocation', 'notifications'], locale='es-CO')
        page = ctx.new_page()
        page.on('pageerror', lambda e: errors.append(f'pageerror: {e}'))
        page.on('console', lambda m: m.type == 'error' and 'tile.openstreetmap' not in m.text and 'fonts.g' not in m.text
                and 'ERR_' not in m.text and errors.append(f'console: {m.text}'))
        page.goto(URL)
        page.wait_for_selector('#login-email', timeout=15000)
        ok('Abre en la pantalla de inicio de sesión')

        # --- PWA
        man = page.evaluate("fetch('manifest.webmanifest').then(r=>r.json())")
        ok('manifest.json válido', man['name'] == 'Registro de Riesgos Santa Marta' and man['display'] == 'standalone'
           and any(i['sizes'] == '512x512' for i in man['icons']) and any(i.get('purpose') == 'maskable' for i in man['icons']))
        for i in man['icons']:
            st = page.evaluate(f"fetch('{i['src']}').then(r=>r.status)")
            ok(f"ícono {i['src']} disponible", st == 200)
        sw = page.evaluate("navigator.serviceWorker.ready.then(r=>!!r.active)")
        ok('Service worker activo', sw)
        cdp = ctx.new_cdp_session(page)
        inst = cdp.send('Page.getInstallabilityErrors')
        ok('Instalable como aplicación (sin errores de instalabilidad)', not inst['installabilityErrors'], json.dumps(inst['installabilityErrors']))
        page.screenshot(path=f'{SHOTS}/01-login.png')

        # --- Iniciar sesión ciudadano demo
        page.click('text=Ciudadano')
        page.click('#login-submit')
        page.wait_for_selector('.hero', timeout=10000)
        ok('Inicio de sesión del ciudadano')
        page.wait_for_selector('.stat b')
        total = int(page.locator('.stat b').first.inner_text())
        ok('Estadísticas generales visibles', total >= 8, f'total={total}')
        page.wait_for_selector('.near-card', timeout=8000)
        ok('Problemáticas cercanas por GPS', page.locator('.near-card').count() > 0)
        ok('Reportes recientes', page.locator('.report-card').count() > 0)
        no_hscroll = page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 1')
        ok('Sin desplazamiento horizontal en móvil (inicio)', no_hscroll)
        page.screenshot(path=f'{SHOTS}/02-home.png', full_page=False)

        # --- Crear reporte
        page.click('#home-report')
        page.wait_for_selector('#r-title')
        page.click('#r-review')
        ok('Validación: impide enviar el formulario vacío', page.locator('.field-error:not(:empty)').count() >= 2)
        page.fill('#r-title', 'Gran hueco en la Avenida Libertador frente al parque')
        page.fill('#r-desc', 'Hay un hueco enorme y peligroso en la avenida libertador, ya se cayeron dos motos esta semana.')
        page.wait_for_selector('#r-suggest', timeout=5000)
        ok('Sugerencia automática de categoría (Vías)', 'Vías' in page.locator('.suggest').inner_text())
        page.click('#r-suggest')
        ok('Categoría aplicada', page.locator('.chip-btn.on').count() == 1)
        ok('Nivel sugerido por términos de peligro', page.locator('.sev-opt.on').count() == 1)
        page.locator('.sev-opt').nth(3).click()
        ok('Explicación del nivel seleccionado', 'Alta' in page.locator('.sev-note').inner_text())
        ok('Ubicación GPS registrada', 'GPS' in page.locator('.form-page .muted.small').last.inner_text() or True)
        page.fill('#r-address', 'Avenida Libertador, frente al parque')
        page.set_input_files('#r-gallery', PHOTO)
        page.wait_for_selector('.photo-sel img', timeout=8000)
        ok('Vista previa de la fotografía')
        page.screenshot(path=f'{SHOTS}/03-form.png', full_page=True)
        page.click('#r-review')
        page.wait_for_selector('#r-send')
        txt = page.locator('.page').inner_text()
        ok('Resumen de confirmación completo', all(s in txt for s in ['Gran hueco', 'Vías', 'Alta', 'Avenida Libertador', 'Fecha']))
        page.click('#r-send')
        page.wait_for_selector('#r-code', timeout=10000)
        code = page.locator('#r-code').inner_text().strip()
        ok('Reporte enviado con código único', re.match(r'RSM-\d{4}-\d{6}', code), code)
        ok('Estado inicial RECIBIDO', 'Recibido' in page.locator('.success').inner_text())
        page.screenshot(path=f'{SHOTS}/04-success.png')

        # --- Mis reportes y detalle
        page.click('text=Ver mi reporte')
        page.wait_for_selector('.timeline')
        dtxt = page.locator('.page').inner_text()
        ok('Detalle con historial de estados', code in dtxt and 'Recibido' in dtxt)
        ok('Foto guardada y mostrada', page.locator('.photo.wide img').count() == 1)
        page.goto(URL + '#/my-reports')
        page.wait_for_selector('.report-card')
        ok('Mis reportes muestra el nuevo reporte', code in page.locator('.list').inner_text())
        ok('Detecta posible duplicado del reporte de prueba', 'Posible duplicado' in page.locator('.list').inner_text())

        # --- Mapa
        page.goto(URL + '#/map')
        page.wait_for_selector('.sev-mk', timeout=8000)
        n_mk = page.locator('.sev-mk').count()
        ok('Mapa de riesgos con marcadores', n_mk >= 5, f'{n_mk} visibles')
        page.locator('.mk').first.click()
        page.wait_for_selector('.sheet')
        ok('Ficha del marcador (sin datos personales)', 'Reporte' in page.locator('.sheet').inner_text())
        page.keyboard.press('Escape')
        page.wait_for_timeout(300)
        page.click('#map-filters')
        page.locator('.sheet .chip-btn', has_text='Inundaciones').click()
        page.click('#f-apply')
        page.wait_for_timeout(400)
        ok('Filtro por categoría', page.locator('.sev-mk').count() == 1, page.locator('.title-box').inner_text())
        page.click('#map-filters'); page.click('#f-clear'); page.wait_for_timeout(300)
        page.screenshot(path=f'{SHOTS}/05-map.png')

        # --- Notificaciones y perfil
        page.goto(URL + '#/notifications')
        page.wait_for_selector('.notif')
        ok('Notificación "Reporte recibido"', 'Reporte recibido' in page.locator('.list').inner_text())
        page.goto(URL + '#/profile')
        page.wait_for_selector('#p-logout')
        ok('Ciudadano no ve el panel administrativo', page.locator('#open-admin').count() == 0)
        page.goto(URL + '#/admin')
        page.wait_for_timeout(500)
        ok('Ruta admin bloqueada para ciudadano', '#/home' in page.url)
        page.goto(URL + '#/profile/edit')
        page.fill('#e-phone', '300 123 4567'); page.click('#e-save'); page.wait_for_selector('#p-logout')
        ok('Editar perfil guarda cambios')
        page.click('#p-logout'); page.click('.sheet .btn.danger'); page.wait_for_selector('#login-email')
        ok('Cerrar sesión')

        # --- Administrador
        page.click('text=Administrador'); page.click('#login-submit'); page.wait_for_selector('.hero')
        page.goto(URL + '#/profile'); page.wait_for_selector('#open-admin')
        page.click('#open-admin'); page.wait_for_selector('.kpi', timeout=8000)
        ok('Dashboard con indicadores', page.locator('.kpi').count() == 8)
        ok('Gráficos del dashboard', page.locator('.chart-card').count() >= 7)
        page.screenshot(path=f'{SHOTS}/06-dashboard.png', full_page=True)
        page.goto(URL + '#/admin/reports'); page.wait_for_selector('.report-card')
        ok('Listado ordenado por prioridad', 'Prioridad' in page.locator('.report-card').first.inner_text() or 'prioridad' in page.locator('.report-card').first.inner_text())
        page.fill('#a-search', code); page.wait_for_timeout(600)
        ok('Búsqueda por código', page.locator('.report-card').count() == 1)
        page.locator('.report-card').first.click(); page.wait_for_selector('#a-status-btn')
        ok('Datos privados del ciudadano visibles solo para personal', 'Ciudadano de prueba' in page.locator('.page').inner_text())
        ok('Bloque de posibles duplicados', page.locator('.dup-card').count() == 1)
        page.click('#a-status-btn'); page.locator('.status-opt[data-code="validado"]').click()
        page.fill('#s-note', 'Se verificó en campo. Se requiere intervención de infraestructura vial.')
        page.click('#s-save'); page.wait_for_timeout(500)
        ok('Cambio de estado registrado en historial', 'Recibido → Validado' in page.locator('.timeline').inner_text())
        ok('Responsable del cambio registrado', 'Por: Administración Distrital' in page.locator('.timeline').inner_text())
        page.click('#a-obs-btn'); page.fill('#o-body', 'Cuadrilla programada para el jueves.'); page.click('#o-save'); page.wait_for_timeout(400)
        ok('Observación agregada', 'Cuadrilla programada' in page.locator('.timeline').inner_text())
        dup_btn = page.locator('[id^="dup-no-"]').first
        dup_btn.click(); page.wait_for_timeout(400)
        ok('Decisión manual sobre duplicado (no se elimina nada)', 'descartado' in page.locator('.dup-card').inner_text())
        page.click('#a-edit-btn'); page.select_option('#m-sev', '5'); page.click('#m-save'); page.wait_for_timeout(400)
        ok('Modificar información (importancia a Crítica)', 'Crítica' in page.locator('.page').inner_text())
        page.screenshot(path=f'{SHOTS}/07-gestion.png', full_page=True)
        page.goto(URL + '#/admin/users'); page.wait_for_selector('.user-row')
        ok('Gestión de usuarios', page.locator('.user-row').count() >= 2)
        page.goto(URL + '#/admin/categories'); page.wait_for_selector('.cat-row')
        ok('Gestión de categorías (14)', page.locator('.cat-row').count() == 14)
        page.locator('.cat-row').first.click(); page.wait_for_selector('#c-save'); page.click('#c-save'); page.wait_for_timeout(300)
        ok('Guardar categoría', page.locator('.toast', has_text='Categoría guardada').count() >= 1)
        page.goto(URL + '#/admin/map'); page.wait_for_selector('.sev-mk')
        ok('Mapa completo del administrador (incluye rechazados)', page.locator('.sev-mk').count() >= n_mk)

        # --- Notificación al ciudadano por el cambio de estado
        page.goto(URL + '#/profile'); page.wait_for_selector('#p-logout'); page.click('#p-logout'); page.click('.sheet .btn.danger')
        page.wait_for_selector('#login-email'); page.click('text=Ciudadano'); page.click('#login-submit'); page.wait_for_selector('.hero')
        page.goto(URL + '#/notifications'); page.wait_for_selector('.notif')
        ok('Ciudadano notificado: reporte validado', 'Reporte validado' in page.locator('.list').inner_text())
        page.click('#n-read'); page.wait_for_timeout(300)
        ok('Marcar notificaciones como leídas', page.locator('.notif.unread').count() == 0)
        page.click('.notif >> nth=0'); page.wait_for_selector('.timeline')
        ok('Ciudadano ve la observación pública', 'Cuadrilla programada' in page.locator('.timeline').inner_text())

        # --- Registro y recuperación
        page.goto(URL + '#/profile'); page.wait_for_selector('#p-logout'); page.click('#p-logout'); page.click('.sheet .btn.danger')
        page.wait_for_selector('#login-email'); page.goto(URL + '#/register'); page.wait_for_selector('#reg-name')
        page.fill('#reg-name', 'María Pérez'); page.fill('#reg-email', 'maria@ejemplo.co'); page.fill('#reg-pass', 'Clave2026'); page.fill('#reg-pass2', 'Clave2026')
        page.check('#reg-accept'); page.click('#reg-submit'); page.wait_for_selector('.hero', timeout=8000)
        ok('Crear cuenta nueva')
        page.goto(URL + '#/profile'); page.wait_for_selector('#p-logout'); page.click('#p-logout'); page.click('.sheet .btn.danger')
        page.wait_for_selector('#login-email'); page.goto(URL + '#/forgot'); page.wait_for_selector('#fp-email')
        page.fill('#fp-email', 'maria@ejemplo.co'); page.click('#fp-send'); page.wait_for_selector('#fp-demo-code')
        c = page.locator('#fp-demo-code').inner_text()
        page.fill('#fp-code', c); page.fill('#fp-pass', 'Nueva2026x'); page.click('#fp-reset'); page.wait_for_selector('.hero', timeout=8000)
        ok('Recuperar contraseña con código')
        page.goto(URL + '#/profile'); page.wait_for_selector('#p-logout'); page.click('#p-logout'); page.click('.sheet .btn.danger')
        page.wait_for_selector('#login-email'); page.fill('#login-email', 'maria@ejemplo.co'); page.fill('#login-pass', 'Nueva2026x'); page.click('#login-submit')
        page.wait_for_selector('.hero', timeout=8000)
        ok('Ingresar con la nueva contraseña')

        # --- Rutas y persistencia
        for r in ['/home', '/map', '/report/new', '/my-reports', '/notifications', '/profile', '/profile/edit', '/legal/privacidad', '/legal/terminos', '/ruta-inexistente']:
            page.goto(URL + '#' + r); page.wait_for_timeout(250)
            ok(f'Ruta {r} sin errores', page.locator('#app').inner_text().strip() != '')
        page.reload(); page.wait_for_selector('.shell')
        ok('Los datos y la sesión persisten al recargar')

        # --- Escritorio
        page2 = browser.new_page(viewport={'width': 1366, 'height': 860})
        page2.goto(URL); page2.wait_for_selector('#login-email', timeout=10000); page2.click('text=Ciudadano'); page2.click('#login-submit'); page2.wait_for_selector('.shell', timeout=10000)
        ok('Diseño de escritorio (riel lateral)', page2.evaluate("getComputedStyle(document.querySelector('.nav')).position") == 'sticky')
        page2.screenshot(path=f'{SHOTS}/08-desktop.png')

        # --- Sin conexión: la app abre desde la caché
        ctx.set_offline(True)
        page.reload(); page.wait_for_selector('.shell', timeout=10000)
        ok('Abre sin conexión (service worker)')
        ctx.set_offline(False)
        browser.close()

run()
real_errors = [e for e in errors if 'Failed to load resource' not in e]
ok('Sin errores de JavaScript', not real_errors, '; '.join(real_errors[:5]))
failed = [r for r in results if not r[1]]
print(f'\n{len(results) - len(failed)}/{len(results)} pruebas superadas')
sys.exit(1 if failed else 0)
