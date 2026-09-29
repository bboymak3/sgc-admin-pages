-- ============================================================
-- Esquema de la base D1 "citas" (compartida por los 5 repos SGC)
-- Snapshot de producción tomado el 2026-09-29, SIN las migraciones de
-- worker/migrations aplicadas. Para un entorno nuevo:
--   wrangler d1 execute <db> --file=schema/schema.sql
--   wrangler d1 migrations apply <db>
-- Las tablas legacy sin prefijo (AdminUsers, Clientes, ...) se omiten:
-- estaban vacías y la migración 0004 las elimina.
-- ============================================================

CREATE TABLE IF NOT EXISTS tenants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  business_name TEXT NOT NULL,
  business_phone TEXT,
  whatsapp_number TEXT,
  email TEXT,
  rubro TEXT DEFAULT 'taller',
  plan TEXT DEFAULT 'free',
  status TEXT DEFAULT 'pending_approval',
  evolution_instance TEXT,
  ai_tone TEXT DEFAULT 'default',
  created_at TEXT DEFAULT (datetime('now','-3 hours')),
  approved_at TEXT,
  active_at TEXT
);

CREATE TABLE IF NOT EXISTS admin_commands (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  command TEXT NOT NULL,
  slug TEXT,
  admin_phone TEXT NOT NULL,
  result TEXT,
  executed_at TEXT DEFAULT (datetime('now','-3 hours'))
);

-- ---------------- sgc_cit_* (citas / bot) ----------------

CREATE TABLE IF NOT EXISTS sgc_cit_AdminUsers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL DEFAULT 'admin',
  activo INTEGER DEFAULT 1,
  ultimo_login TEXT,
  fecha_creacion TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_cit_Citas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente_id INTEGER,
  fecha_cita TEXT,
  hora_cita TEXT,
  servicio TEXT,
  estado TEXT DEFAULT 'Pendiente',
  patente TEXT, marca TEXT, modelo TEXT, anio INTEGER,
  nombre_cliente TEXT, telefono TEXT, email TEXT,
  duracion_minutos INTEGER DEFAULT 60,
  observaciones TEXT,
  canal TEXT DEFAULT 'chat',
  notificada_negocio INTEGER DEFAULT 0,
  notificada_cliente INTEGER DEFAULT 0,
  recordatorio_enviado INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  orden_enviada INTEGER DEFAULT 0,
  numero_orden_sgc TEXT,
  apellido TEXT, color TEXT, direccion TEXT, referencia_direccion TEXT,
  tipo_atencion TEXT DEFAULT 'taller',
  estado_aprobacion TEXT DEFAULT 'pendiente',
  motivo_rechazo TEXT,
  tenant_id INTEGER DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_citas_estado ON sgc_cit_Citas(estado);
CREATE INDEX IF NOT EXISTS idx_citas_fecha ON sgc_cit_Citas(fecha_cita);
CREATE INDEX IF NOT EXISTS idx_citas_patente ON sgc_cit_Citas(patente);
CREATE INDEX IF NOT EXISTS idx_citas_telefono ON sgc_cit_Citas(telefono);
CREATE INDEX IF NOT EXISTS idx_sgc_cit_Citas_tenant ON sgc_cit_Citas(tenant_id);

CREATE TABLE IF NOT EXISTS sgc_cit_WhatsApp_conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL UNIQUE,
  contact_name TEXT,
  last_message_at TEXT DEFAULT (datetime('now','-3 hours')),
  last_user_message TEXT,
  last_bot_message TEXT,
  client_context TEXT,
  total_messages INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active',
  created_at TEXT DEFAULT (datetime('now','-3 hours')),
  tenant_id INTEGER DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_wa_conv_phone ON sgc_cit_WhatsApp_conversations(phone);
CREATE INDEX IF NOT EXISTS idx_sgc_cit_WhatsApp_conversations_tenant ON sgc_cit_WhatsApp_conversations(tenant_id);

CREATE TABLE IF NOT EXISTS sgc_cit_WhatsApp_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL,
  direction TEXT NOT NULL,
  content TEXT NOT NULL,
  tool_used TEXT,
  tool_input TEXT,
  tool_result TEXT,
  created_at TEXT DEFAULT (datetime('now','-3 hours')),
  tenant_id INTEGER DEFAULT 1,
  FOREIGN KEY (conversation_id) REFERENCES sgc_cit_WhatsApp_conversations(id)
);
CREATE INDEX IF NOT EXISTS idx_wa_msg_conv ON sgc_cit_WhatsApp_messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sgc_cit_WhatsApp_messages_tenant ON sgc_cit_WhatsApp_messages(tenant_id);

CREATE TABLE IF NOT EXISTS sgc_cit_bloqueos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL UNIQUE,
  motivo TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_cit_config (
  clave TEXT PRIMARY KEY,
  valor TEXT NOT NULL,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_cit_horarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dia_semana TEXT NOT NULL,
  hora_apertura TEXT NOT NULL DEFAULT '08:00',
  hora_cierre TEXT NOT NULL DEFAULT '18:00',
  intervalo_minutos INTEGER DEFAULT 30,
  activo INTEGER DEFAULT 1,
  tenant_id INTEGER DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_sgc_cit_horarios_tenant ON sgc_cit_horarios(tenant_id);

CREATE TABLE IF NOT EXISTS sgc_cit_servicios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  icono TEXT DEFAULT 'wrench',
  duracion_minutos INTEGER DEFAULT 60,
  precio_min TEXT,
  activo INTEGER DEFAULT 1,
  orden INTEGER DEFAULT 0,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_cit_servicios_unificados (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  descripcion TEXT DEFAULT '',
  categoria TEXT DEFAULT 'General',
  precio INTEGER DEFAULT 0,
  duracion_minutos INTEGER DEFAULT 60,
  activo INTEGER DEFAULT 1,
  origen TEXT DEFAULT 'manual',
  orden INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  tenant_id INTEGER DEFAULT 1,
  requiere_vehiculo INTEGER DEFAULT 1,
  es_domicilio INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sgc_cit_servicios_unificados_tenant ON sgc_cit_servicios_unificados(tenant_id);

-- ---------------- sgc_ord_* (órdenes de trabajo) ----------------

CREATE TABLE IF NOT EXISTS sgc_ord_AdminUsers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL DEFAULT 'admin',
  activo INTEGER DEFAULT 1,
  ultimo_login TEXT,
  fecha_creacion TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_SesionesAdmin (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  expira DATETIME NOT NULL,
  fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_Clientes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  telefono TEXT,
  email TEXT,
  rut TEXT,
  direccion TEXT,
  fecha_registro TEXT DEFAULT (datetime('now', '-3 hours')),
  apellido TEXT DEFAULT NULL,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_Tecnicos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  apellido TEXT DEFAULT '',
  telefono TEXT,
  email TEXT,
  especialidad TEXT,
  zona_cobertura TEXT,
  activo INTEGER DEFAULT 1,
  comision_porcentaje REAL NOT NULL DEFAULT 40,
  fecha_registro TEXT DEFAULT (datetime('now', '-3 hours')),
  pin TEXT,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_Vehiculos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patente_placa TEXT NOT NULL UNIQUE,
  marca TEXT,
  modelo TEXT,
  anio INTEGER,
  cilindrada TEXT,
  combustible TEXT,
  kilometraje TEXT,
  color TEXT DEFAULT NULL,
  cliente_id INTEGER,
  fecha_registro TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1,
  FOREIGN KEY (cliente_id) REFERENCES sgc_ord_Clientes(id)
);

CREATE TABLE IF NOT EXISTS sgc_ord_OrdenesTrabajo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_orden INTEGER,
  token TEXT,
  cliente_id INTEGER,
  vehiculo_id INTEGER,
  patente_placa TEXT, marca TEXT, modelo TEXT, anio INTEGER,
  cilindrada TEXT, combustible TEXT, kilometraje TEXT,
  fecha_ingreso TEXT, hora_ingreso TEXT, recepcionista TEXT, direccion TEXT,
  trabajo_frenos INTEGER DEFAULT 0, detalle_frenos TEXT,
  trabajo_luces INTEGER DEFAULT 0, detalle_luces TEXT,
  trabajo_tren_delantero INTEGER DEFAULT 0, detalle_tren_delantero TEXT,
  trabajo_correas INTEGER DEFAULT 0, detalle_correas TEXT,
  trabajo_componentes INTEGER DEFAULT 0, detalle_componentes TEXT,
  nivel_combustible TEXT,
  check_paragolfe_delantero_der INTEGER DEFAULT 0,
  check_puerta_delantera_der INTEGER DEFAULT 0,
  check_puerta_trasera_der INTEGER DEFAULT 0,
  check_paragolfe_trasero_izq INTEGER DEFAULT 0,
  check_otros_carroceria TEXT,
  monto_total REAL DEFAULT 0, monto_abono REAL DEFAULT 0, monto_restante REAL DEFAULT 0,
  metodo_pago TEXT,
  estado TEXT DEFAULT 'Enviada',
  estado_trabajo TEXT DEFAULT 'Pendiente',
  firma_imagen TEXT,
  fecha_creacion TEXT DEFAULT (datetime('now', '-3 hours')),
  fecha_completado TEXT,
  cliente_nombre TEXT, cliente_telefono TEXT, cliente_apellido TEXT DEFAULT '',
  aprobado_por TEXT,
  color TEXT DEFAULT NULL,
  servicios_seleccionados TEXT, diagnostico_checks TEXT, diagnostico_observaciones TEXT,
  referencia_direccion TEXT,
  distancia_km REAL DEFAULT 0, cargo_domicilio REAL DEFAULT 0,
  domicilio_modo_cobro TEXT DEFAULT 'no_cobrar',
  fecha_programada TEXT, hora_programada TEXT,
  es_express INTEGER DEFAULT 0,
  tecnico_asignado_id INTEGER,
  origen TEXT DEFAULT 'admin',
  cliente_lat REAL DEFAULT 0, cliente_lng REAL DEFAULT 0,
  tipo_atencion TEXT DEFAULT 'taller',
  fecha_aprobacion TEXT, completo TEXT, comision_porcentaje TEXT,
  tiene_cargo_domicilio TEXT, tiene_diag_checks TEXT, tiene_diag_obs TEXT,
  tiene_distancia_km TEXT, tiene_domicilio_modo_cobro TEXT, tiene_fecha_completado TEXT,
  tiene_servicios TEXT, total_costos_adicionales TEXT, total_costos_mano_obra TEXT,
  tenant_id INTEGER DEFAULT 1,
  FOREIGN KEY (cliente_id) REFERENCES sgc_ord_Clientes(id),
  FOREIGN KEY (vehiculo_id) REFERENCES sgc_ord_Vehiculos(id),
  FOREIGN KEY (tecnico_asignado_id) REFERENCES sgc_ord_Tecnicos(id)
);
CREATE INDEX IF NOT EXISTS idx_sgc_ord_OrdenesTrabajo_tenant ON sgc_ord_OrdenesTrabajo(tenant_id);

CREATE TABLE IF NOT EXISTS sgc_ord_AdelantosTecnico (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tecnico_id INTEGER NOT NULL,
  monto REAL NOT NULL,
  fecha_adelanto TEXT DEFAULT (datetime('now', '-3 hours')),
  observaciones TEXT,
  registrado_por TEXT,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_AgendaTecnicos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tecnico_id INTEGER NOT NULL,
  orden_id INTEGER,
  titulo TEXT NOT NULL,
  tipo_servicio TEXT NOT NULL DEFAULT 'taller',
  fecha_inicio TEXT NOT NULL,
  fecha_fin TEXT NOT NULL,
  color TEXT DEFAULT '#0d6efd',
  observaciones TEXT,
  estado TEXT DEFAULT 'pendiente',
  creado_por TEXT DEFAULT 'admin',
  fecha_creacion TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_ConfigKV (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_Configuracion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  clave TEXT,
  valor TEXT,
  ultimo_numero_orden INTEGER DEFAULT 1,
  ultramsg_instance TEXT,
  ultramsg_token TEXT,
  business_name TEXT DEFAULT 'SGC',
  business_phone TEXT DEFAULT '56939026185',
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_CostosAdicionales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  concepto TEXT NOT NULL,
  monto REAL NOT NULL,
  fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
  registrado_por TEXT,
  categoria TEXT NOT NULL DEFAULT 'Mano de Obra',
  tecnico_id INTEGER,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_FotosTrabajo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  tecnico_id INTEGER NOT NULL,
  tipo_foto TEXT NOT NULL,
  r2_key TEXT NOT NULL DEFAULT '',
  url_imagen TEXT NOT NULL,
  tamano_bytes INTEGER DEFAULT 0,
  descripcion TEXT,
  fecha_subida TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_GastosNegocio (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  concepto TEXT NOT NULL,
  categoria TEXT NOT NULL DEFAULT 'Otros',
  monto REAL NOT NULL,
  fecha_gasto DATE NOT NULL,
  observaciones TEXT,
  registrado_por TEXT,
  fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_LiquidacionCanceladas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  tecnico_id INTEGER,
  monto REAL NOT NULL,
  motivo TEXT,
  fecha TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_LiquidacionOrden (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  tecnico_id INTEGER NOT NULL,
  porcentaje_comision REAL NOT NULL DEFAULT 40,
  base_comisionable REAL NOT NULL DEFAULT 0,
  monto_comision REAL NOT NULL DEFAULT 0,
  monto_domicilio REAL DEFAULT 0,
  observaciones TEXT,
  fecha_liquidacion TEXT DEFAULT (datetime('now', '-3 hours')),
  estado TEXT DEFAULT 'pendiente',
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_ModelosVehiculo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL UNIQUE,
  fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_NotasTrabajo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  tecnico_id INTEGER NOT NULL,
  nota TEXT NOT NULL,
  fecha_nota TEXT DEFAULT (datetime('now', '-3 hours')),
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_NotificacionesWhatsApp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  telefono TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  tipo_evento TEXT NOT NULL,
  enviada INTEGER DEFAULT 0,
  fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_Pagos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  orden_id INTEGER NOT NULL,
  monto REAL NOT NULL,
  metodo_pago TEXT NOT NULL,
  fecha_pago DATETIME DEFAULT CURRENT_TIMESTAMP,
  observaciones TEXT,
  tenant_id INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sgc_ord_ServiciosCatalogo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL UNIQUE,
  precio_sugerido REAL NOT NULL DEFAULT 0,
  categoria TEXT NOT NULL DEFAULT 'Mantenimiento',
  tipo_comision TEXT NOT NULL DEFAULT 'mano_obra',
  activo INTEGER DEFAULT 1,
  fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
  tenant_id INTEGER DEFAULT 1
);

-- ---------------- sgc_rec_* (recordatorios) ----------------

CREATE TABLE IF NOT EXISTS sgc_rec_recordatorios_revision (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  telefono TEXT NOT NULL,
  patente TEXT NOT NULL,
  ultimo_caracter TEXT DEFAULT '',
  mes_revision INTEGER NOT NULL,
  es_manual INTEGER DEFAULT 0,
  fecha_registro TEXT DEFAULT (datetime('now', '-4 hours')),
  ultimo_aviso_enviado TEXT DEFAULT '',
  activo INTEGER DEFAULT 1,
  tenant_id INTEGER DEFAULT 1
);
