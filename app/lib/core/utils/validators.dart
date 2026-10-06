/// Validaciones de formularios. Coinciden con las restricciones CHECK de la
/// base de datos para dar errores claros antes de enviar.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _phone = RegExp(r'^[0-9+ ()-]{7,20}$');

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
    if (!_email.hasMatch(v.trim())) return 'Correo no válido';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
      return 'Debe contener letras y números';
    }
    return null;
  }

  static String? required(String? v, {String message = 'Campo obligatorio'}) =>
      (v == null || v.trim().isEmpty) ? message : null;

  static String? fullName(String? v) {
    if (v == null || v.trim().length < 3) return 'Ingresa tu nombre';
    if (v.trim().length > 120) return 'Máximo 120 caracteres';
    return null;
  }

  static String? phoneOptional(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _phone.hasMatch(v.trim()) ? null : 'Teléfono no válido';
  }

  static String? reportTitle(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 5) return 'El título debe tener al menos 5 caracteres';
    if (t.length > 120) return 'Máximo 120 caracteres';
    return null;
  }

  static String? reportDescription(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 10) return 'Describe la problemática (mínimo 10 caracteres)';
    if (t.length > 2000) return 'Máximo 2000 caracteres';
    return null;
  }

  static String? address(String? v) =>
      (v != null && v.trim().length > 250) ? 'Máximo 250 caracteres' : null;
}
