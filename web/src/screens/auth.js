// Inicio de sesión, registro, recuperación de contraseña y textos legales.
import privacidad from '../../../app/assets/legal/privacidad.md';
import terminos from '../../../app/assets/legal/terminos.md';
import { DEMO_ACCOUNTS } from '../data/auth.js';
import { button, field, h, icon, toast } from '../ui.js';
import { V } from '../validators.js';

function authLayout(title, subtitle, ...content) {
  return h('div', { class: 'auth' },
    h('header', { class: 'auth-hero' },
      h('div', { class: 'auth-mark' }, icon('waves', 30)),
      h('p', { class: 'eyebrow' }, 'Santa Marta · Participación ciudadana'),
      h('h1', null, title),
      h('p', null, subtitle)),
    h('div', { class: 'auth-body' }, ...content));
}

const input = (id, type, attrs = {}) => h('input', { id, name: id, type, ...attrs });

function busy(btn, on) {
  btn.disabled = on;
  btn.classList.toggle('busy', on);
}

export async function loginScreen({ app }) {
  const email = input('login-email', 'email', { autocomplete: 'email', required: true, inputmode: 'email' });
  const pass = input('login-pass', 'password', { autocomplete: 'current-password', required: true });
  const fEmail = field('Correo electrónico', email);
  const fPass = field('Contraseña', pass);
  const submit = button('Iniciar sesión', { type: 'submit', full: true, id: 'login-submit' });
  const form = h('form', { class: 'stack', novalidate: true }, fEmail, fPass,
    h('a', { href: '#/forgot', class: 'link right' }, '¿Olvidaste tu contraseña?'), submit,
    h('p', { class: 'center muted' }, '¿No tienes cuenta? ', h('a', { href: '#/register', class: 'link' }, 'Crear cuenta')));
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    fEmail.setError(V.email(email.value));
    fPass.setError(pass.value ? '' : 'Ingresa tu contraseña');
    if (V.email(email.value) || !pass.value) return;
    busy(submit, true);
    try {
      await app.backend.auth.signIn(email.value, pass.value);
      await app.refreshMe();
      app.syncQueue();
      app.go('/home');
    } catch (err) { toast(err.message, 'error'); } finally { busy(submit, false); }
  });

  const demo = app.backend.mode === 'local' ? h('div', { class: 'demo-box' },
    h('strong', null, 'Cuentas de demostración'),
    demoRow('Administrador', DEMO_ACCOUNTS.admin, email, pass),
    demoRow('Ciudadano', DEMO_ACCOUNTS.citizen, email, pass)) : null;

  return authLayout('Registro de Riesgos Santa Marta', 'Ingresa para reportar y seguir las problemáticas de tu ciudad.', form, demo);
}

function demoRow(label, acc, email, pass) {
  return h('button', {
    type: 'button', class: 'demo-row',
    onclick: () => { email.value = acc.email; pass.value = acc.password; email.dispatchEvent(new Event('input')); },
  }, h('span', null, label), h('code', null, `${acc.email} / ${acc.password}`), icon('login', 18));
}

export async function registerScreen({ app }) {
  const name = input('reg-name', 'text', { autocomplete: 'name', maxlength: '120' });
  const email = input('reg-email', 'email', { autocomplete: 'email' });
  const phone = input('reg-phone', 'tel', { autocomplete: 'tel', maxlength: '20' });
  const pass = input('reg-pass', 'password', { autocomplete: 'new-password' });
  const pass2 = input('reg-pass2', 'password', { autocomplete: 'new-password' });
  const accept = h('input', { type: 'checkbox', id: 'reg-accept' });
  const f = {
    name: field('Nombre completo', name), email: field('Correo electrónico', email),
    phone: field('Teléfono', phone, { optional: true }), pass: field('Contraseña', pass, { hint: 'Mínimo 8 caracteres, con letras y números.' }),
    pass2: field('Confirmar contraseña', pass2),
  };
  const submit = button('Crear cuenta', { type: 'submit', full: true, id: 'reg-submit' });
  const form = h('form', { class: 'stack', novalidate: true }, ...Object.values(f),
    h('label', { class: 'check' }, accept, h('span', null, 'Acepto la ',
      h('a', { href: '#/legal/privacidad', class: 'link' }, 'política de privacidad'), ' y los ',
      h('a', { href: '#/legal/terminos', class: 'link' }, 'términos y condiciones'), '.')),
    submit, h('p', { class: 'center muted' }, '¿Ya tienes cuenta? ', h('a', { href: '#/login', class: 'link' }, 'Iniciar sesión')));
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const errs = {
      name: V.fullName(name.value), email: V.email(email.value), phone: V.phone(phone.value),
      pass: V.password(pass.value), pass2: pass2.value !== pass.value ? 'Las contraseñas no coinciden' : '',
    };
    for (const k in errs) f[k].setError(errs[k]);
    if (Object.values(errs).some(Boolean)) return;
    if (!accept.checked) { toast('Debes aceptar la política de privacidad y los términos.', 'error'); return; }
    busy(submit, true);
    try {
      const r = await app.backend.auth.signUp({ email: email.value, password: pass.value, full_name: name.value, phone: phone.value });
      if (r.session) { await app.refreshMe(); toast('Cuenta creada. ¡Bienvenido!', 'ok'); app.go('/home'); }
      else { toast('Te enviamos un correo para confirmar tu cuenta. Confírmala y luego inicia sesión.', 'ok'); app.go('/login'); }
    } catch (err) { toast(err.message, 'error'); } finally { busy(submit, false); }
  });
  return authLayout('Crear cuenta', 'Tus datos personales no se publican en el mapa.', form);
}

export async function forgotScreen({ app }) {
  const email = input('fp-email', 'email', { autocomplete: 'email' });
  const code = input('fp-code', 'text', { inputmode: 'numeric', maxlength: '8', autocomplete: 'one-time-code' });
  const pass = input('fp-pass', 'password', { autocomplete: 'new-password' });
  const fEmail = field('Correo electrónico', email);
  const fCode = field('Código recibido', code);
  const fPass = field('Nueva contraseña', pass, { hint: 'Mínimo 8 caracteres, con letras y números.' });
  const step2 = h('div', { class: 'stack', hidden: true }, fCode, fPass);
  const note = h('div', { class: 'demo-box', hidden: true });
  const sendBtn = button('Enviar código', { full: true, id: 'fp-send' });
  const resetBtn = button('Cambiar contraseña', { full: true, id: 'fp-reset' });
  resetBtn.hidden = true;
  sendBtn.onclick = async () => {
    fEmail.setError(V.email(email.value));
    if (V.email(email.value)) return;
    busy(sendBtn, true);
    try {
      const r = await app.backend.auth.sendRecovery(email.value);
      step2.hidden = false; resetBtn.hidden = false; sendBtn.hidden = true; email.readOnly = true;
      if (r?.demoCode) {
        note.hidden = false;
        note.replaceChildren(h('strong', null, 'Modo demostración'), h('span', null, `No hay servidor de correo en este modo. Tu código es: `), h('code', { id: 'fp-demo-code' }, r.demoCode));
      } else toast('Si el correo está registrado, recibirás un código.', 'ok');
    } catch (err) { toast(err.message, 'error'); } finally { busy(sendBtn, false); }
  };
  resetBtn.onclick = async () => {
    fCode.setError(code.value.trim().length >= 6 ? '' : 'Ingresa el código');
    fPass.setError(V.password(pass.value));
    if (code.value.trim().length < 6 || V.password(pass.value)) return;
    busy(resetBtn, true);
    try {
      await app.backend.auth.resetWithCode(email.value, code.value, pass.value);
      await app.refreshMe();
      toast('Contraseña actualizada.', 'ok');
      app.go('/home');
    } catch (err) { toast(err.message, 'error'); } finally { busy(resetBtn, false); }
  };
  return authLayout('Recuperar contraseña', 'Te enviaremos un código a tu correo.',
    h('div', { class: 'stack' }, fEmail, note, step2, sendBtn, resetBtn, h('a', { href: '#/login', class: 'link center' }, 'Volver')));
}

/** Render mínimo de Markdown seguro (títulos, viñetas, negritas). */
export function markdown(md) {
  const out = h('div', { class: 'prose' });
  for (const raw of md.split('\n')) {
    const t = raw.trimEnd();
    const rich = (s) => s.split(/\*\*(.+?)\*\*/g).map((part, i) => (i % 2 ? h('strong', null, part) : part));
    if (t.startsWith('# ')) out.append(h('h1', null, t.slice(2)));
    else if (t.startsWith('## ')) out.append(h('h2', null, t.slice(3)));
    else if (t.startsWith('- ')) {
      let ul = out.lastElementChild;
      if (ul?.tagName !== 'UL') { ul = h('ul'); out.append(ul); }
      ul.append(h('li', null, rich(t.slice(2))));
    } else if (t) out.append(h('p', null, rich(t)));
  }
  return out;
}

export async function legalScreen({ params }) {
  const doc = params.doc === 'terminos' ? terminos : privacidad;
  return h('div', { class: 'page narrow' },
    h('button', { type: 'button', class: 'link back', onclick: () => history.back() }, icon('arrow_back', 18), 'Volver'),
    h('div', { class: 'notice warn' }, 'TEXTO PRELIMINAR: debe ser revisado por un abogado antes de un lanzamiento oficial.'),
    markdown(doc));
}
