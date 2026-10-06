# Genera las capturas que usa el manifest (instalación enriquecida en Android/escritorio).
import sys
from playwright.sync_api import sync_playwright
URL = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:8765/'
with sync_playwright() as p:
    b = p.chromium.launch(args=['--no-sandbox'])
    for name, vp, scale, route in [('screenshot-mobile.png', (270, 585), 2, '#/home'), ('screenshot-wide.png', (1280, 800), 1, '#/admin')]:
        ctx = b.new_context(viewport={'width': vp[0], 'height': vp[1]}, device_scale_factor=scale)
        pg = ctx.new_page(); pg.goto(URL); pg.wait_for_selector('#login-email')
        pg.evaluate("sessionStorage.setItem('rsm:banner-local','1')")
        pg.click('text=Administrador' if 'admin' in route else 'text=Ciudadano'); pg.click('#login-submit'); pg.wait_for_selector('.shell')
        pg.goto(URL + route); pg.wait_for_timeout(1200)
        pg.screenshot(path=f'public/icons/{name}')
        ctx.close()
    b.close()
