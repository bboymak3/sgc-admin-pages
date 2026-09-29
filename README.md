# SGC Admin Pages

Panel de administración web para gestión de citas, órdenes de trabajo, técnicos y calendario. Multi-nicho: cualquier negocio basado en citas.

## 🏗️ Arquitectura

- **Hosting**: Cloudflare Pages (gratis)
- **Backend**: Pages Functions en `/functions/api/`
- **DB**: Cloudflare D1 (tablas `sgc_cit_*` y `sgc_ord_*`)
- **Auth**: JWT con hash SHA256

## ✨ Funcionalidades

### Dashboard
- KPIs en tiempo real: citas hoy, pendientes, aprobadas, órdenes express
- Citas por servicio (gráfico)
- Últimas 10 citas
- Próximas citas

### Gestión de citas
- Listado completo con filtros
- Aprobar / rechazar citas (con envío de WhatsApp al cliente)
- Crear cita manual
- Editar / eliminar cita
- Ver detalle completo

### Gestión de órdenes
- Listado de órdenes de trabajo
- Asignar técnico
- Cambiar estado
- Cargar costos adicionales
- Subir fotos

### Gestión de técnicos
- CRUD completo de técnicos
- Asignación de comisiones
- Agenda por técnico

### Calendario
- Vista mensual / semanal / diaria
- Drag & drop para reagendar
- Filtros por técnico / estado

## 📋 Estructura

```
.
├── index.html              # Login + dashboard
├── css/admin.css           # Estilos
├── js/
│   ├── app.js              # App principal
│   ├── auth.js             # Autenticación JWT
│   ├── dashboard.js        # KPIs y gráficos
│   ├── citas.js            # Gestión de citas
│   ├── ordenes.js          # Gestión de órdenes
│   ├── tecnicos.js         # Gestión de técnicos
│   └── calendario.js       # Calendario interactivo
├── functions/
│   └── api/
│       ├── _middleware.js  # Auth middleware (valida JWT)
│       ├── auth/login.js   # Login (devuelve JWT)
│       ├── dashboard/      # KPIs del dashboard
│       ├── citas/          # CRUD citas + aprobar/rechazar
│       ├── ordenes/        # CRUD órdenes
│       ├── tecnicos/       # CRUD técnicos
│       └── calendario/     # CRUD agenda
└── wrangler.toml           # Config de bindings
```

## 🔧 Configuración

### Variables (wrangler.toml)
| Variable | Descripción | Default |
|---|---|---|
| `JWT_SECRET` | Secreto para firmar tokens JWT | `sgc-secret-key-change-in-production` |
| `ADMIN_USERNAME` | Usuario admin | `admin` |
| `ADMIN_PASSWORD_HASH` | Hash SHA256 del password | (default: `admin123`) |
| `CITAS_WORKER_URL` | URL del Worker sgc-citas | - |
| `ORDENES_PAGES_URL` | URL del Pages sgc-ordenes | - |

### Bindings
- `CITAS_DB` — D1 database `citas` (tablas `sgc_cit_*`)
- `ORDENES_DB` — D1 database `citas` (tablas `sgc_ord_*`)

## 🚀 Deploy

```bash
git clone https://github.com/bboymak3/sgc-admin-pages.git
cd sgc-admin-pages

# Editar wrangler.toml con tus URLs y password
nano wrangler.toml

# Generar hash SHA256 del nuevo password
echo -n "tu-nuevo-password" | sha256sum

# Deploy
wrangler pages deploy . --project-name=sgc-admin --branch=main
```

## 🔐 Login default

- Usuario: `admin`
- Password: `admin123` (hash: `240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9`)

⚠️ **Cambia el password antes de producción** generando un nuevo hash SHA256.

## 📚 Repos relacionados

- [sgc-citas-worker](https://github.com/bboymak3/sgc-citas-worker) — Bot WhatsApp con IA
- [sgc-ordenes-pages](https://github.com/bboymak3/sgc-ordenes-pages) — Sistema de órdenes
- [sgc-recordatorios-worker](https://github.com/bboymak3/sgc-recordatorios-worker) — Recordatorios

## 🔄 Multi-tenant

Para usar este panel con múltiples negocios:

### Opción simple (1 cuenta por cliente)
- Deploya este repo en la cuenta Cloudflare de cada cliente
- Cada cliente tiene su propio URL: `sgc-admin-cliente1.pages.dev`
- Apunta `CITAS_DB` y `ORDENES_DB` a la D1 del cliente

### Opción escalable (1 sola cuenta tuya)
- 1 solo deploy en tu cuenta
- Agregar `tenant_id` a todas las queries SQL
- Login incluye selector de negocio
- Ver [MULTI-TENANT.md](MULTI-TENANT.md) para implementación detallada

## 💰 Costo mensual: $0

Cloudflare Pages: $0 con unlimited bandwidth, 500 builds/mes.

## 📄 Licencia

Propietario — SGC
