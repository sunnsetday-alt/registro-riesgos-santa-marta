// Catálogos iniciales. Son los MISMOS valores que la migración
// supabase/migrations/20261005000004_catalogs.sql, para que la versión web en
// modo local/compartido se comporte igual que el backend Supabase.

export const STATUSES = [
  { code: 'recibido', name: 'Recibido', color: '#0EA5E9', icon: 'inbox', open: true, notify: false },
  { code: 'en_revision', name: 'En revisión', color: '#8B5CF6', icon: 'manage_search', open: true, notify: false },
  { code: 'validado', name: 'Validado', color: '#14B8A6', icon: 'verified', open: true, notify: true },
  { code: 'en_proceso', name: 'En proceso', color: '#F59E0B', icon: 'engineering', open: true, notify: true },
  { code: 'atendido', name: 'Atendido', color: '#22C55E', icon: 'task_alt', open: false, notify: true },
  { code: 'cerrado', name: 'Cerrado', color: '#64748B', icon: 'lock', open: false, notify: true },
  { code: 'rechazado', name: 'Rechazado', color: '#EF4444', icon: 'block', open: false, notify: true },
];
export const statusOf = (code) =>
  STATUSES.find((s) => s.code === code) || { code, name: code, color: '#64748B', icon: 'help', open: true };

export const SEVERITIES = [
  { level: 1, label: 'Muy baja', color: '#22C55E', icon: 'sentiment_satisfied', text: 'Molestia menor. No representa riesgo para las personas.' },
  { level: 2, label: 'Baja', color: '#84CC16', icon: 'info', text: 'Afecta la calidad de vida, pero puede esperar.' },
  { level: 3, label: 'Media', color: '#EAB308', icon: 'report', text: 'Afecta a varias personas o puede empeorar si no se atiende.' },
  { level: 4, label: 'Alta', color: '#F97316', icon: 'warning', text: 'Riesgo de accidentes, daños materiales o afectación grave del servicio.' },
  { level: 5, label: 'Crítica', color: '#DC2626', icon: 'crisis_alert', text: 'Peligro inmediato para la vida o la integridad. Requiere atención urgente.' },
];
export const severityOf = (n) => SEVERITIES[Math.min(5, Math.max(1, n | 0)) - 1];

export const PRIORITY_LEVELS = {
  baja: { label: 'Baja prioridad', color: '#64748B' },
  media: { label: 'Prioridad media', color: '#CA8A04' },
  alta: { label: 'Alta prioridad', color: '#EA580C' },
  critica: { label: 'Prioridad crítica', color: '#DC2626' },
};

export const ROLES = {
  citizen: 'Ciudadano',
  official: 'Funcionario',
  entity_admin: 'Administrador de entidad',
  admin: 'Administrador',
};
export const STAFF_ROLES = ['official', 'entity_admin', 'admin'];

export const CATEGORY_ICONS = [
  'add_road', 'traffic', 'water_drop', 'plumbing', 'lightbulb', 'delete', 'shield', 'eco',
  'apartment', 'park', 'signpost', 'flood', 'forest', 'more_horiz', 'report',
];

export const CATEGORIES = [
  { id: 1, code: 'vias', name: 'Vías', icon: 'add_road', color: '#E76F51', weight: 1.2, order: 1,
    keywords: ['hueco', 'huecos', 'bache', 'baches', 'via', 'vias', 'calle', 'carretera', 'pavimento', 'asfalto', 'grieta', 'hundimiento', 'avenida', 'troncal', 'carrera'] },
  { id: 2, code: 'movilidad', name: 'Movilidad', icon: 'traffic', color: '#F4A261', weight: 1.0, order: 2,
    keywords: ['trancon', 'trafico', 'semaforo', 'congestion', 'bus', 'transporte', 'parqueo', 'mal parqueado', 'ciclovia', 'moto', 'peatonal'] },
  { id: 3, code: 'agua', name: 'Agua', icon: 'water_drop', color: '#0096C7', weight: 1.2, order: 3,
    keywords: ['agua', 'acueducto', 'fuga', 'tuberia', 'sin agua', 'escape', 'presion', 'potable', 'carrotanque', 'tubo'] },
  { id: 4, code: 'alcantarillado', name: 'Alcantarillado', icon: 'plumbing', color: '#6D597A', weight: 1.25, order: 4,
    keywords: ['alcantarilla', 'alcantarillado', 'desague', 'aguas negras', 'rebosamiento', 'manjol', 'tapa', 'cloaca', 'olor', 'sumidero', 'aguas residuales'] },
  { id: 5, code: 'alumbrado', name: 'Alumbrado público', icon: 'lightbulb', color: '#D4A017', weight: 0.9, order: 5,
    keywords: ['luz', 'luminaria', 'alumbrado', 'poste', 'lampara', 'bombillo', 'oscuro', 'oscuridad', 'apagado', 'foco'] },
  { id: 6, code: 'basuras', name: 'Basuras', icon: 'delete', color: '#8D6E63', weight: 0.95, order: 6,
    keywords: ['basura', 'basuras', 'residuos', 'escombros', 'desechos', 'botadero', 'acumulacion', 'recoleccion', 'reciclaje', 'olores'] },
  { id: 7, code: 'seguridad', name: 'Seguridad', icon: 'shield', color: '#D62828', weight: 1.3, order: 7,
    keywords: ['robo', 'inseguridad', 'atraco', 'peligro', 'vandalismo', 'hurto', 'sospechoso', 'pelea', 'riña'] },
  { id: 8, code: 'medio_ambiente', name: 'Medio ambiente', icon: 'eco', color: '#2A9D8F', weight: 1.0, order: 8,
    keywords: ['contaminacion', 'quema', 'humo', 'ruido', 'playa', 'mar', 'rio', 'manglar', 'fauna', 'tala', 'incendio forestal', 'vertimiento'] },
  { id: 9, code: 'infraestructura', name: 'Infraestructura', icon: 'apartment', color: '#3D5A6C', weight: 1.15, order: 9,
    keywords: ['puente', 'muro', 'edificio', 'estructura', 'colapso', 'grieta', 'derrumbe', 'andén', 'anden', 'baranda', 'escalera'] },
  { id: 10, code: 'espacio_publico', name: 'Espacio público', icon: 'park', color: '#6A994E', weight: 0.85, order: 10,
    keywords: ['parque', 'anden', 'invasion', 'espacio publico', 'plaza', 'vendedores', 'cancha', 'banca', 'zona verde'] },
  { id: 11, code: 'senalizacion', name: 'Señalización', icon: 'signpost', color: '#F77F00', weight: 1.0, order: 11,
    keywords: ['senal', 'señal', 'señalizacion', 'pare', 'cebra', 'pintura', 'demarcacion', 'transito', 'aviso', 'letrero'] },
  { id: 12, code: 'inundaciones', name: 'Inundaciones', icon: 'flood', color: '#1D4ED8', weight: 1.4, order: 12,
    keywords: ['inundacion', 'inundado', 'anegado', 'lluvia', 'arroyo', 'creciente', 'desbordamiento', 'aguacero', 'encharcamiento', 'agua estancada'] },
  { id: 13, code: 'arboles', name: 'Árboles en riesgo', icon: 'forest', color: '#386641', weight: 1.25, order: 13,
    keywords: ['arbol', 'arboles', 'rama', 'ramas', 'caido', 'caer', 'inclinado', 'tronco', 'poda', 'raiz'] },
  { id: 14, code: 'otros', name: 'Otros', icon: 'more_horiz', color: '#64748B', weight: 0.8, order: 99, keywords: [] },
].map((c) => ({ ...c, active: true }));

// Sectores aproximados (centro y radio). Igual que en la base de datos.
export const SECTORS = [
  { id: 1, name: 'Centro Histórico', lat: 11.242, lng: -74.211, r: 900 },
  { id: 2, name: 'Pescaíto', lat: 11.2505, lng: -74.2075, r: 700 },
  { id: 3, name: 'Bastidas', lat: 11.247, lng: -74.2, r: 800 },
  { id: 4, name: 'Taganga', lat: 11.267, lng: -74.1905, r: 1200 },
  { id: 5, name: 'Manzanares', lat: 11.23, lng: -74.1975, r: 800 },
  { id: 6, name: 'Pando', lat: 11.2345, lng: -74.189, r: 800 },
  { id: 7, name: 'Once de Noviembre', lat: 11.2385, lng: -74.179, r: 900 },
  { id: 8, name: 'Los Almendros', lat: 11.223, lng: -74.188, r: 900 },
  { id: 9, name: 'Mamatoco', lat: 11.229, lng: -74.172, r: 1200 },
  { id: 10, name: 'Bonda', lat: 11.2345, lng: -74.129, r: 1800 },
  { id: 11, name: 'Gaira', lat: 11.193, lng: -74.219, r: 1300 },
  { id: 12, name: 'El Rodadero', lat: 11.206, lng: -74.228, r: 1100 },
  { id: 13, name: 'Pozos Colorados', lat: 11.164, lng: -74.228, r: 1800 },
  { id: 14, name: 'Bureche', lat: 11.23, lng: -74.156, r: 1200 },
  { id: 15, name: 'Avenida del Ferrocarril', lat: 11.238, lng: -74.201, r: 600 },
];

// Parámetros del índice de prioridad y de duplicados (tabla priority_settings).
export const SETTINGS = {
  w_severity: 0.4, w_similar: 0.15, w_age: 0.15, w_category: 0.1, w_geo: 0.2,
  similar_cap: 3, age_cap_days: 30, geo_radius_m: 300, geo_cap: 5, geo_window_days: 90,
  critical_severity_floor: 55, threshold_media: 35, threshold_alta: 55, threshold_critica: 75,
  dup_radius_m: 150, dup_same_category_radius_m: 50, dup_text_threshold: 0.35, dup_window_days: 60,
  max_reports_per_day: 20,
};

// Límites del Distrito de Santa Marta (iguales a los CHECK de la base de datos).
export const BOUNDS = { minLat: 10.8, maxLat: 11.45, minLng: -74.4, maxLng: -73.5 };
export const CENTER = { lat: 11.2408, lng: -74.199 };
export const insideDistrict = (lat, lng) =>
  lat >= BOUNDS.minLat && lat <= BOUNDS.maxLat && lng >= BOUNDS.minLng && lng <= BOUNDS.maxLng;

// Datos de prueba (los mismos 9 de la función seed_test_data). Todos marcados.
export const TEST_REPORTS = [
  ['[PRUEBA] Hueco en Avenida Libertador', 'Hay un hueco enorme en la Avenida Libertador, ocupa casi todo el carril derecho y ya han caído motos.', 'vias', 5, 11.23652, -74.1948, 'Avenida del Libertador, frente a la estación de servicio', 12, 'en_proceso', 'Se verificó en campo. Se programó intervención de infraestructura vial.'],
  ['[PRUEBA] Alcantarilla dañada en Mamatoco', 'La tapa de la alcantarilla está rota y hay rebosamiento de aguas negras sobre la calle principal.', 'alcantarillado', 4, 11.2291, -74.1733, 'Calle principal de Mamatoco, cerca de la iglesia', 8, 'validado', 'Problemática validada. Se remitió a la empresa de servicios públicos.'],
  ['[PRUEBA] Inundación en Bonda', 'Con cada aguacero el arroyo se desborda y la calle queda inundada, el agua entra a las casas.', 'inundaciones', 5, 11.2344, -74.1293, 'Bonda, sector del arroyo', 3, 'en_revision', null],
  ['[PRUEBA] Alumbrado público defectuoso', 'Cinco postes de luz apagados en la cuadra, la zona queda totalmente oscura en la noche.', 'alumbrado', 3, 11.2064, -74.2266, 'El Rodadero, carrera 2', 20, 'atendido', 'Se reemplazaron las luminarias. Favor confirmar funcionamiento.'],
  ['[PRUEBA] Acumulación de basura', 'Acumulación de basura y escombros en la esquina desde hace más de una semana, genera malos olores.', 'basuras', 3, 11.2423, -74.2079, 'Centro, cerca del mercado', 6, 'recibido', null],
  ['[PRUEBA] Señal de tránsito dañada', 'La señal de PARE de la intersección está caída en el suelo, los carros no se detienen.', 'senalizacion', 4, 11.1946, -74.2183, 'Gaira, intersección principal', 15, 'cerrado', 'Señal reinstalada por la Secretaría de Movilidad.'],
  ['[PRUEBA] Árbol en riesgo de caer', 'Árbol grande muy inclinado sobre la vía y cables eléctricos, las raíces están levantando el andén.', 'arboles', 4, 11.2235, -74.1876, 'Los Almendros, calle 29', 2, 'recibido', null],
  ['[PRUEBA] Daño en vía hacia Taganga', 'Hundimiento del pavimento en la curva de la vía a Taganga, peligroso para vehículos de noche.', 'vias', 4, 11.2601, -74.1931, 'Vía Santa Marta - Taganga, curva principal', 10, 'rechazado', 'Reporte de prueba rechazado para demostrar el estado.'],
  ['[PRUEBA] Hueco peligroso en la Avenida Libertador', 'Hay un hueco peligroso en la Avenida Libertador, casi frente a la estación de gasolina.', 'vias', 4, 11.2367, -74.19455, 'Av. Libertador', 1, 'recibido', null],
];
