"""Pruebas de extremo a extremo de la PWA en Chromium (Playwright).

Uso:  ADMIN_PASSWORD='...' python3 tests/e2e.py [URL]   (por defecto http://localhost:8765/)

Parte de una aplicación VACÍA (sin datos de prueba) y recorre: registro de un
ciudadano, creación de reportes con foto y GPS, código único, detección de
duplicados, mapa y filtros, notificaciones, perfil, ingreso del administrador
(con su clave secreta), dashboard, cambio de estado, observaciones, decisión
sobre duplicados, usuarios, categorías, copia de seguridad, recuperación de
clave, rutas, persistencia, móvil, escritorio y PWA (manifest, service worker,
instalabilidad, funcionamiento sin conexión).
"""
import json, os, re, sys
from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:8765/'
ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@riesgos-santamarta.co')
ADMIN_PASSWORD = os.environ['ADMIN_PASSWORD']
PHOTO = os.environ.get('PHOTO', '/tmp/claude-0/-home-claude/3da1a12a-8012-5de3-abf8-18503a148062/scratchpad/hueco.jpg')
SHOTS = os.environ.get('SHOTS', '/tmp/claude-0/-home-claude/3da1a12a-8012-5de3-abf8-18503a148062/scratchpad/shots')
os.makedirs(SHOTS, exist_ok=True)
results, errors = [], []

def ok(name, cond=True, detail=''):
    results.append((name, bool(cond), detail))
    print(('✔ ' if cond else '✘ ') + name + (f' — {detail}' if detail else ''), flush=True)

def logout(page):
    page.goto(URL + '#/profile'); page.wait_for_selector('#p-logout')
    page.click('#p-logout'); page.click('.sheet .btn.danger'); page.wait_for_selector('#login-email')

def login(page, email, password):
    page.fill('#login-email', email); page.fill('#login-pass', password); page.click('#login-submit')

def register(page, name, email, password):
    page.goto(URL + '#/register'); page.wait_for_selector('#reg-name')
    page.fill('#reg-name', name); page.fill('#reg-email', email)
    page.fill('#reg-pass', password); page.fill('#reg-pass2', password)
    page.check('#reg-accept'); page.click('#reg-submit')

def new_report(page, title, desc, address, photo=True):
    page.goto(URL + '#/home'); page.wait_for_selector('#home-report'); page.click('#home-report')
    page.wait_for_selector('#r-title')
    page.fill('#r-title', title); page.fill('#r-desc', desc)
    page.wait_for_selector('#r-suggest', timeout=5000); page.click('#r-suggest')
    page.locator('.sev-opt').nth(3).click()
    page.fill('#r-address', address)
    if photo:
        page.set_input_files('#r-gallery', PHOTO); page.wait_for_selector('.photo-sel img', timeout=8000)
    page.click('#r-review'); page.wait_for_selector('#r-send')
    page.click('#r-send'); page.wait_for_selector('#r-code', timeout=10000)
    return page.locator('#r-code').inner_text().strip()

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(args=['--no-sandbox'])
        ctx = browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2, is_mobile=True, has_touch=True,
                                  geolocation={'latitude': 11.2366, 'longitude': -74.1947}, permissions=['geolocation', 'notifications'], locale='es-CO')
        page = ctx.new_page()
        page.on('pageerror', lambda e: errors.append(f'pageerror: {e}'))
        page.on('console', lambda m: m.type == 'error' and 'tile.openstreetmap' not in m.text and 'fonts.g' not in m.text
                and 'ERR_' not in m.text and errors.append(f'console: {m.text}'))
        page.goto(URL); page.wait_for_selector('#login-email', timeout=15000)
        ok('Abre en la pantalla de inicio de sesión')
        body = page.locator('body').inner_text()
        ok('No muestra cuentas ni claves', not any(s in body.lower() for s in ['demo', 'admin2026', 'ciudadano2026', ADMIN_EMAIL, ADMIN_PASSWORD.lower()]))
        src = page.evaluate("fetch('app.js').then(r=>r.text())") + page.evaluate("fetch('config.js').then(r=>r.text())")
        ok('La clave del administrador no está en el código publicado', ADMIN_PASSWORD not in src)

        # --- PWA
        man = page.evaluate("fetch('manifest.webmanifest').then(r=>r.json())")
        ok('manifest.json válido', man['name'] == 'Registro de Riesgos Santa Marta' and man['display'] == 'standalone'
           and any(i['sizes'] == '512x512' for i in man['icons']) and any(i.get('purpose') == 'maskable' for i in man['icons']))
        ok('Service worker activo', page.evaluate("navigator.serviceWorker.ready.then(r=>!!r.active)"))
        inst = ctx.new_cdp_session(page).send('Page.getInstallabilityErrors')
        ok('Instalable como aplicación', not inst['installabilityErrors'], json.dumps(inst['installabilityErrors']))

        # --- Ciudadano nuevo, app vacía
        register(page, 'Ana Ciudadana', 'ana@correo.co', 'MiClave2026')
        page.wait_for_selector('.hero', timeout=8000)
        ok('Registro de ciudadano con su propio correo y clave')
        page.wait_for_selector('.stat b')
        ok('La aplicación empieza sin datos', page.locator('.stat b').first.inner_text() == '0')
        ok('Sin datos de prueba visibles', 'PRUEBA' not in page.locator('body').inner_text())
        page.goto(URL + '#/profile'); page.wait_for_selector('#p-logout')
        ok('La cuenta nueva es de ciudadano (sin panel)', page.locator('#open-admin').count() == 0)
        page.goto(URL + '#/admin'); page.wait_for_timeout(400)
        ok('Ruta admin bloqueada para ciudadano', '#/home' in page.url)
        page.screenshot(path=f'{SHOTS}/01-home-vacio.png')

        # --- Reportes reales
        page.goto(URL + '#/report/new'); page.wait_for_selector('#r-title'); page.click('#r-review')
        ok('Validación: impide enviar el formulario vacío', page.locator('.field-error:not(:empty)').count() >= 2)
        code1 = new_report(page, 'Hueco grande en la Avenida Libertador', 'Hay un hueco enorme y peligroso en la avenida libertador frente al parque.', 'Av. Libertador, frente al parque')
        year = __import__('datetime').date.today().year
        ok('Primer reporte con código RSM-AAAA-000001', code1 == f'RSM-{year}-000001', code1)
        ok('Estado inicial RECIBIDO', 'Recibido' in page.locator('.success').inner_text())
        code2 = new_report(page, 'Hueco peligroso en Avenida Libertador', 'Hueco peligroso en la avenida libertador, casi frente al parque, ya hubo accidentes.', 'Av. Libertador', photo=False)
        ok('Segundo reporte con código consecutivo', code2 == f'RSM-{year}-000002', code2)
        page.goto(URL + '#/my-reports'); page.wait_for_selector('.report-card')
        lst = page.locator('.list').inner_text()
        ok('Mis reportes muestra los dos reportes', code1 in lst and code2 in lst)
        ok('Detecta posible duplicado', 'Posible duplicado' in lst)
        page.locator('.report-card', has_text=code1).click(); page.wait_for_selector('.timeline')
        ok('Detalle con foto e historial', page.locator('.photo.wide img').count() == 1 and 'Recibido' in page.locator('.timeline').inner_text())
        page.goto(URL + '#/map'); page.wait_for_selector('.sev-mk', timeout=8000)
        ok('Mapa con los reportes ingresados', page.locator('.sev-mk').count() == 2)
        page.goto(URL + '#/notifications'); page.wait_for_selector('.notif')
        ok('Notificación de reporte recibido', 'Reporte recibido' in page.locator('.list').inner_text())
        page.screenshot(path=f'{SHOTS}/02-mis-reportes.png')

        # --- Correo del administrador reservado y admin protegido
        logout(page)
        register(page, 'Intruso', ADMIN_EMAIL, 'OtraClave2026')
        page.wait_for_selector('.toast'); ok('No se puede registrar el correo del administrador', 'reservado' in page.locator('.toast').last.inner_text())
        page.goto(URL + '#/login'); page.wait_for_selector('#login-email')
        login(page, ADMIN_EMAIL, 'ClaveIncorrecta1')
        try: page.wait_for_selector('.toast:has-text("incorrectos")', timeout=8000); rejected = '#/login' in page.url
        except Exception: rejected = False
        ok('Clave incorrecta del administrador rechazada', rejected)
        page.goto(URL + '#/forgot'); page.wait_for_selector('#fp-email'); page.fill('#fp-email', ADMIN_EMAIL); page.click('#fp-send')
        page.wait_for_timeout(500)
        ok('La clave del administrador no se puede recuperar desde la app', page.locator('#fp-demo-code').count() == 0)

        # --- Administrador
        page.goto(URL + '#/login'); page.wait_for_selector('#login-email')
        login(page, ADMIN_EMAIL, ADMIN_PASSWORD); page.wait_for_selector('.hero', timeout=10000)
        ok('Ingreso del administrador con su clave')
        page.goto(URL + '#/profile'); page.wait_for_selector('#open-admin'); page.click('#open-admin'); page.wait_for_selector('.kpi', timeout=8000)
        ok('Dashboard con datos reales', page.locator('.kpi b').first.inner_text() == '2')
        ok('Sin botón de datos de prueba', page.locator('#a-seed').count() == 0)
        page.screenshot(path=f'{SHOTS}/03-dashboard.png', full_page=True)
        page.goto(URL + '#/admin/reports'); page.wait_for_selector('.report-card')
        page.fill('#a-search', code2); page.wait_for_timeout(500)
        ok('Búsqueda por código', page.locator('.report-card').count() == 1)
        page.locator('.report-card').first.click(); page.wait_for_selector('#a-status-btn')
        ok('Datos del ciudadano visibles para el administrador', 'Ana Ciudadana' in page.locator('.page').inner_text())
        ok('Posible duplicado para decidir', page.locator('.dup-card').count() == 1)
        page.click('#a-status-btn'); page.locator('.status-opt[data-code="validado"]').click()
        page.fill('#s-note', 'Se verificó en campo.'); page.click('#s-save'); page.wait_for_timeout(500)
        ok('Cambio de estado con responsable', 'Recibido → Validado' in page.locator('.timeline').inner_text() and 'Por: Administración' in page.locator('.timeline').inner_text())
        page.click('#a-obs-btn'); page.fill('#o-body', 'Cuadrilla programada.'); page.click('#o-save'); page.wait_for_timeout(400)
        ok('Observación agregada', 'Cuadrilla programada' in page.locator('.timeline').inner_text())
        page.locator('[id^="dup-yes-"]').first.click(); page.wait_for_timeout(400)
        ok('Duplicado confirmado manualmente', 'confirmado' in page.locator('.dup-card').inner_text())
        page.goto(URL + '#/admin/users'); page.wait_for_selector('.user-row')
        ok('Gestión de usuarios', page.locator('.user-row').count() == 2)
        page.goto(URL + '#/admin/categories'); page.wait_for_selector('.cat-row')
        ok('Gestión de categorías', page.locator('.cat-row').count() == 14)
        page.goto(URL + '#/admin'); page.wait_for_selector('#a-export')
        with page.expect_download() as dl:
            page.click('#a-export')
        data = json.loads(open(dl.value.path()).read())
        ok('Copia de seguridad descargable', len(data['tables']['reports']) == 2 and len(data['photos']) == 1)
        page.goto(URL + '#/profile/edit'); page.wait_for_selector('#e-pass'); page.fill('#e-pass', 'NuevaClave2026'); page.locator('form').nth(1).locator('button').click()
        page.wait_for_selector('.toast'); ok('La clave del administrador no se cambia desde la app', 'config.js' in page.locator('.toast').last.inner_text())

        # --- Ciudadano ve la actualización
        logout(page); login(page, 'ana@correo.co', 'MiClave2026'); page.wait_for_selector('.hero')
        page.goto(URL + '#/notifications'); page.wait_for_selector('.notif')
        ok('Ciudadano notificado del cambio de estado', 'Reporte validado' in page.locator('.list').inner_text())
        page.goto(URL + '#/map'); page.wait_for_selector('.sev-mk')
        ok('El duplicado confirmado sale del mapa público', page.locator('.sev-mk').count() == 1)

        # --- Recuperación de clave de un ciudadano
        logout(page); page.goto(URL + '#/forgot'); page.wait_for_selector('#fp-email')
        page.fill('#fp-email', 'ana@correo.co'); page.click('#fp-send'); page.wait_for_selector('#fp-demo-code')
        page.fill('#fp-code', page.locator('#fp-demo-code').inner_text()); page.fill('#fp-pass', 'ClaveNueva2026'); page.click('#fp-reset')
        page.wait_for_selector('.hero', timeout=8000); ok('Recuperación de clave del ciudadano')

        # --- Rutas, persistencia, escritorio, sin conexión
        for r in ['/home', '/map', '/report/new', '/my-reports', '/notifications', '/profile', '/profile/edit', '/legal/privacidad', '/legal/terminos', '/ruta-inexistente']:
            page.goto(URL + '#' + r); page.wait_for_timeout(200)
            ok(f'Ruta {r}', page.locator('#app').inner_text().strip() != '')
        page.reload(); page.wait_for_selector('.shell')
        page.goto(URL + '#/my-reports'); page.wait_for_selector('.report-card')
        ok('Los datos y la sesión persisten al recargar', page.locator('.report-card').count() == 2)
        ok('Sin desplazamiento horizontal en móvil', page.evaluate('document.documentElement.scrollWidth <= window.innerWidth + 1'))
        page2 = browser.new_page(viewport={'width': 1366, 'height': 860})
        page2.goto(URL); page2.wait_for_selector('#login-email')
        ok('Diseño de escritorio', page2.locator('.auth').count() == 1)
        ctx.set_offline(True); page.reload(); page.wait_for_selector('.shell', timeout=10000); ok('Abre sin conexión'); ctx.set_offline(False)
        browser.close()

run()
real = [e for e in errors if 'Failed to load resource' not in e]
ok('Sin errores de JavaScript', not real, '; '.join(real[:5]))
failed = [r for r in results if not r[1]]
print(f'\n{len(results) - len(failed)}/{len(results)} pruebas superadas')
sys.exit(1 if failed else 0)
