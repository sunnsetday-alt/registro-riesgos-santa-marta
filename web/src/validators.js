// Validaciones de formularios (coinciden con los CHECK de la base de datos).
export const V = {
  email: (v) => (!v?.trim() ? 'Ingresa tu correo' : /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.trim()) ? '' : 'Correo no válido'),
  password: (v) => (!v || v.length < 8 ? 'Mínimo 8 caracteres'
    : !/[A-Za-z]/.test(v) || !/[0-9]/.test(v) ? 'Debe contener letras y números' : ''),
  fullName: (v) => (!v || v.trim().length < 3 ? 'Ingresa tu nombre' : v.trim().length > 120 ? 'Máximo 120 caracteres' : ''),
  phone: (v) => (!v?.trim() ? '' : /^[0-9+ ()-]{7,20}$/.test(v.trim()) ? '' : 'Teléfono no válido'),
  title: (v) => { const t = (v || '').trim(); return t.length < 5 ? 'El título debe tener al menos 5 caracteres' : t.length > 120 ? 'Máximo 120 caracteres' : ''; },
  description: (v) => { const t = (v || '').trim(); return t.length < 10 ? 'Describe la problemática (mínimo 10 caracteres)' : t.length > 2000 ? 'Máximo 2000 caracteres' : ''; },
  address: (v) => ((v || '').trim().length > 250 ? 'Máximo 250 caracteres' : ''),
};
