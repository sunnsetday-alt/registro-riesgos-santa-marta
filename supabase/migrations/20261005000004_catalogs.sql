-- =====================================================================
-- Registro de Riesgos Santa Marta
-- Migración 4: Catálogos iniciales (roles, estados, categorías, sectores,
--              entidades de ejemplo y parámetros de prioridad)
-- =====================================================================

insert into public.roles (code, name, description, is_staff) values
  ('citizen',      'Ciudadano',              'Crea y consulta sus reportes; ve el mapa público.', false),
  ('official',     'Funcionario',            'Gestiona reportes (estados y observaciones).',      true),
  ('entity_admin', 'Administrador de entidad','Gestiona reportes de su entidad (preparado para multi-entidad).', true),
  ('admin',        'Administrador',          'Acceso total: reportes, usuarios, categorías, parámetros.', true)
on conflict (code) do nothing;

insert into public.report_statuses (code, name, description, color, sort_order, is_open, notify_citizen) values
  ('recibido',    'Recibido',    'El reporte llegó al sistema.',                        '#0EA5E9', 1, true,  false),
  ('en_revision', 'En revisión', 'Un funcionario está revisando la información.',       '#8B5CF6', 2, true,  false),
  ('validado',    'Validado',    'La problemática fue verificada.',                      '#14B8A6', 3, true,  true),
  ('en_proceso',  'En proceso',  'Se está atendiendo la problemática.',                  '#F59E0B', 4, true,  true),
  ('atendido',    'Atendido',    'La entidad responsable atendió la problemática.',      '#22C55E', 5, false, true),
  ('cerrado',     'Cerrado',     'El caso fue cerrado.',                                 '#475569', 6, false, true),
  ('rechazado',   'Rechazado',   'El reporte no procede (información insuficiente, falso o duplicado).', '#EF4444', 7, false, true)
on conflict (code) do nothing;

-- Entidades de EJEMPLO: ajustar a la estructura real de la Alcaldía.
insert into public.entities (name, kind) values
  ('Alcaldía Distrital de Santa Marta (ejemplo)',        'alcaldia'),
  ('Secretaría de Infraestructura (ejemplo)',            'secretaria'),
  ('Secretaría de Movilidad (ejemplo)',                  'secretaria'),
  ('Empresa de servicios públicos (ejemplo)',            'servicios_publicos'),
  ('Oficina de Gestión del Riesgo (ejemplo)',            'gestion_riesgo'),
  ('Secretaría de Seguridad (ejemplo)',                  'secretaria'),
  ('Autoridad ambiental (ejemplo)',                      'otra')
on conflict (name) do nothing;

insert into public.categories (code, name, icon, color, priority_weight, sort_order, keywords, responsible_entity_id) values
  ('vias', 'Vías', 'road', '#E76F51', 1.20, 1,
   array['hueco','huecos','bache','baches','via','vias','calle','carretera','pavimento','asfalto','grieta','hundimiento','avenida','troncal','carrera'],
   (select id from public.entities where name like 'Secretaría de Infraestructura%')),
  ('movilidad', 'Movilidad', 'traffic', '#F4A261', 1.00, 2,
   array['trancon','trafico','semaforo','congestion','bus','transporte','parqueo','mal parqueado','ciclovia','moto','peatonal'],
   (select id from public.entities where name like 'Secretaría de Movilidad%')),
  ('agua', 'Agua', 'water', '#0096C7', 1.20, 3,
   array['agua','acueducto','fuga','tuberia','sin agua','escape','presion','potable','carrotanque','tubo'],
   (select id from public.entities where name like 'Empresa de servicios%')),
  ('alcantarillado', 'Alcantarillado', 'plumbing', '#6D597A', 1.25, 4,
   array['alcantarilla','alcantarillado','desague','aguas negras','rebosamiento','manjol','tapa','cloaca','olor','sumidero','aguas residuales'],
   (select id from public.entities where name like 'Empresa de servicios%')),
  ('alumbrado', 'Alumbrado público', 'lightbulb', '#E9C46A', 0.90, 5,
   array['luz','luminaria','alumbrado','poste','lampara','bombillo','oscuro','oscuridad','apagado','foco'],
   (select id from public.entities where name like 'Alcaldía Distrital%')),
  ('basuras', 'Basuras', 'delete', '#8D6E63', 0.95, 6,
   array['basura','basuras','residuos','escombros','desechos','botadero','acumulacion','recoleccion','reciclaje','olores'],
   (select id from public.entities where name like 'Empresa de servicios%')),
  ('seguridad', 'Seguridad', 'shield', '#D62828', 1.30, 7,
   array['robo','inseguridad','atraco','peligro','vandalismo','hurto','sospechoso','pelea','riña'],
   (select id from public.entities where name like 'Secretaría de Seguridad%')),
  ('medio_ambiente', 'Medio ambiente', 'eco', '#2A9D8F', 1.00, 8,
   array['contaminacion','quema','humo','ruido','playa','mar','rio','manglar','fauna','tala','incendio forestal','vertimiento'],
   (select id from public.entities where name like 'Autoridad ambiental%')),
  ('infraestructura', 'Infraestructura', 'apartment', '#264653', 1.15, 9,
   array['puente','muro','edificio','estructura','colapso','grieta','derrumbe','andén','anden','baranda','escalera'],
   (select id from public.entities where name like 'Secretaría de Infraestructura%')),
  ('espacio_publico', 'Espacio público', 'park', '#90BE6D', 0.85, 10,
   array['parque','anden','invasion','espacio publico','plaza','vendedores','cancha','banca','zona verde'],
   (select id from public.entities where name like 'Alcaldía Distrital%')),
  ('senalizacion', 'Señalización', 'signpost', '#F77F00', 1.00, 11,
   array['senal','señal','señalizacion','pare','cebra','pintura','demarcacion','transito','aviso','letrero'],
   (select id from public.entities where name like 'Secretaría de Movilidad%')),
  ('inundaciones', 'Inundaciones', 'flood', '#1D4ED8', 1.40, 12,
   array['inundacion','inundado','anegado','lluvia','arroyo','creciente','desbordamiento','aguacero','encharcamiento','agua estancada'],
   (select id from public.entities where name like 'Oficina de Gestión del Riesgo%')),
  ('arboles', 'Árboles en riesgo', 'forest', '#386641', 1.25, 13,
   array['arbol','arboles','rama','ramas','caido','caer','inclinado','tronco','poda','raiz'],
   (select id from public.entities where name like 'Oficina de Gestión del Riesgo%')),
  ('otros', 'Otros', 'more', '#64748B', 0.80, 99, array[]::text[], null)
on conflict (code) do nothing;

-- Sectores APROXIMADOS (centro y radio). Ajustar con la cartografía oficial.
insert into public.sectors (name, center_lat, center_lng, radius_m) values
  ('Centro Histórico',      11.2420, -74.2110, 900),
  ('Pescaíto',              11.2505, -74.2075, 700),
  ('Bastidas',              11.2470, -74.2000, 800),
  ('Taganga',               11.2670, -74.1905, 1200),
  ('Manzanares',            11.2300, -74.1975, 800),
  ('Pando',                 11.2345, -74.1890, 800),
  ('Once de Noviembre',     11.2385, -74.1790, 900),
  ('Los Almendros',         11.2230, -74.1880, 900),
  ('Mamatoco',              11.2290, -74.1720, 1200),
  ('Bonda',                 11.2345, -74.1290, 1800),
  ('Gaira',                 11.1930, -74.2190, 1300),
  ('El Rodadero',           11.2060, -74.2280, 1100),
  ('Pozos Colorados',       11.1640, -74.2280, 1800),
  ('Bureche',               11.2300, -74.1560, 1200),
  ('Avenida del Ferrocarril', 11.2380, -74.2010, 600)
on conflict (name) do nothing;

insert into public.priority_settings (key, value, description) values
  ('w_severity',              0.40, 'Peso del nivel de importancia reportado (1-5)'),
  ('w_similar',               0.15, 'Peso de la cantidad de reportes similares/duplicados'),
  ('w_age',                   0.15, 'Peso de la antigüedad del reporte sin resolver'),
  ('w_category',              0.10, 'Peso de la categoría (priority_weight de categories)'),
  ('w_geo',                   0.20, 'Peso de la concentración geográfica de reportes abiertos'),
  ('similar_cap',             3,    'Cantidad de reportes similares que satura el componente (=1)'),
  ('age_cap_days',            30,   'Días abiertos que saturan el componente de antigüedad'),
  ('geo_radius_m',            300,  'Radio (m) para medir concentración geográfica'),
  ('geo_cap',                 5,    'Reportes cercanos que saturan el componente geográfico'),
  ('geo_window_days',         90,   'Ventana de días considerada para concentración geográfica'),
  ('critical_severity_floor', 55,   'Puntaje mínimo cuando la severidad es 5 (Crítica)'),
  ('threshold_media',         35,   'Puntaje mínimo para prioridad media'),
  ('threshold_alta',          55,   'Puntaje mínimo para prioridad alta'),
  ('threshold_critica',       75,   'Puntaje mínimo para prioridad crítica'),
  ('dup_radius_m',            150,  'Distancia máxima (m) para considerar posible duplicado'),
  ('dup_same_category_radius_m', 50, 'Distancia (m) bajo la cual misma categoría = posible duplicado'),
  ('dup_text_threshold',      0.35, 'Similitud de texto (0-1, trigramas) para posible duplicado'),
  ('dup_window_days',         60,   'Días hacia atrás para buscar duplicados'),
  ('max_reports_per_day',     20,   'Límite de reportes por ciudadano en 24 horas (anti-abuso)')
on conflict (key) do nothing;
