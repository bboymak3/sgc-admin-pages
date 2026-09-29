# SGC Admin Pages — Panel admin legacy (single-tenant SGC)

![Cloudflare Pages](https://img.shields.io/badge/Cloudflare-Pages-F38020?logo=cloudflare&logoColor=white)
![Pages Functions](https://img.shields.io/badge/Pages-Functions-F38020?logo=cloudflare&logoColor=white)
![Cloudflare D1](https://img.shields.io/badge/Cloudflare-D1%20(SQLite)-F38020?logo=cloudflare&logoColor=white)
![JWT](https://img.shields.io/badge/Auth-JWT%20(SHA256)-000000?logo=jsonwebtokens&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-vanilla-F7DF1E?logo=javascript&logoColor=black)
![HTML/CSS](https://img.shields.io/badge/HTML%2FCSS-Bootstrap%205.3-E34F26?logo=html5&logoColor=white)

Panel de administración **legacy single-tenant** para SGC (tenant_id=1). Gestiona citas, órdenes de trabajo, técnicos y calendario desde una sola interfaz. Deployado en Cloudflare Pages con Pages Functions como backend y Cloudflare D1 como base de datos.

- **URL producción**: https://sgc-admin-8yf.pages.dev
- **Login default**: `admin` / `admin123`

---

## ⚠️ Nota

> Este es el panel admin **legacy single-tenant** para SGC (tenant_id=1).
>
> Para multi-tenant usar el panel integrado en **`sgc-saas`** ([https://github.com/bboymak3/sgc-saas](https://github.com/bboymak3/sgc-saas)) en la ruta `/admin?t=<slug>`.

---

## 🏗️ Arquitectura

```
┌──────────────┐      ┌──────────────────────┐      ┌─────────────────────┐      ┌──────────────────┐
│   Browser    │ ───▶ │  Cloudflare Pages    │ ───▶ │  Pages Functions    │ ───▶ │   Cloudflare D1  │
│  (HTML/JS)   │ ◀─── │  (index.html + JS)   │ ◀─── │  (/functions/api/)  │ ◀─── │   database citas │
└──────────────┘      └──────────────────────┘      └─────────────────────┘      └──────────────────┘
                                                            │
                                                            ├── JWT en _middleware (HS256)
                                                            ├── POST /api/citas/:id/aprobar ──▶ sgc-ordenes (Pages)
                                                            └── POST /api/citas/:id/rechazar ──▶ sgc-citas (Worker) → WhatsApp
```

| Capa            | Tecnología                                  |
| --------------- | ------------------------------------------- |
| Hosting         | Cloudflare Pages                            |
| Backend         | Pages Functions (en `/functions/api/`)      |
| DB              | Cloudflare D1 (SQLite)                      |
| Auth            | JWT con hash SHA256 (HMAC-SHA256)           |
| Frontend        | HTML/CSS/JS vanilla (sin framework)         |
| UI              | Bootstrap 5.3 (CDN)                         |
| Charts          | Chart.js (CDN)                              |

---

## 🔌 APIs y Endpoints

Todas las rutas `/api/*` (excepto `/api/auth/login` y `/api/health`) requieren JWT en header `Authorization: Bearer <token>` o cookie `sgc_token`.

### Auth

| Método | Endpoint                 | Descripción                                           |
| ------ | ------------------------ | ----------------------------------------------------- |
| POST   | `/api/auth/login`        | Login con `username`/`password`, devuelve JWT + cookie |

### Dashboard

| Método | Endpoint           | Descripción                                                            |
| ------ | ------------------ | ---------------------------------------------------------------------- |
| GET    | `/api/dashboard`   | KPIs del dashboard (citas hoy, pendientes, órdenes, ingresos, etc.)    |

### Citas

| Método | Endpoint                          | Descripción                                                    |
| ------ | --------------------------------- | ------------------------------------------------------------- |
| GET    | `/api/citas`                      | Lista citas (filtros: `estado`, `desde`, `hasta`, `q`, `limit`)|
| POST   | `/api/citas`                      | Crear cita                                                     |
| PUT    | `/api/citas/:id`                  | Actualizar cita                                                |
| DELETE | `/api/citas/:id`                  | Eliminar cita                                                  |
| POST   | `/api/citas/:id/aprobar`          | Aprobar cita + crear orden de trabajo + enviar WhatsApp        |
| POST   | `/api/citas/:id/rechazar`         | Rechazar cita + enviar WhatsApp (body: `motivo`)               |

### Órdenes

| Método | Endpoint              | Descripción                                                          |
| ------ | --------------------- | -------------------------------------------------------------------- |
| GET    | `/api/ordenes`        | Lista órdenes (filtros: `estado`, `estado_trabajo`, `patente`, `tecnico_id`) |
| POST   | `/api/ordenes`        | Crear orden                                                          |
| PUT    | `/api/ordenes/:id`    | Actualizar orden (estado, técnico asignado, costos, etc.)            |

### Técnicos

| Método | Endpoint                | Descripción                                   |
| ------ | ----------------------- | --------------------------------------------- |
| GET    | `/api/tecnicos`         | Lista técnicos (con OTs activas por técnico)  |
| POST   | `/api/tecnicos`         | Crear técnico                                 |
| PUT    | `/api/tecnicos/:id`     | Actualizar técnico                            |
| DELETE | `/api/tecnicos/:id`     | Eliminar técnico (soft delete: `activo=0`)    |

### Calendario

| Método | Endpoint                | Descripción                                                          |
| ------ | ----------------------- | -------------------------------------------------------------------- |
| GET    | `/api/calendario`       | Eventos del calendario (params: `inicio`, `fin`, `tecnico_id`)       |
| POST   | `/api/calendario`       | Crear evento de agenda                                               |
| PUT    | `/api/calendario/:id`   | Actualizar evento                                                    |
| DELETE | `/api/calendario/:id`   | Eliminar evento                                                      |

### Conectores externos

| Conector                          | Variable de entorno   | Uso                                                              |
| --------------------------------- | --------------------- | ---------------------------------------------------------------- |
| Cloudflare D1 — `CITAS_DB`        | `CITAS_DB`            | Misma database `citas`, tablas `sgc_cit_*` (citas, clientes, etc.) |
| Cloudflare D1 — `ORDENES_DB`      | `ORDENES_DB`          | Misma database `citas`, tablas `sgc_ord_*` (órdenes, técnicos)    |
| Worker **sgc-citas**              | `CITAS_WORKER_URL`    | Enviar WhatsApp al aprobar/rechazar citas                        |
| Pages **sgc-ordenes**             | `ORDENES_PAGES_URL`   | Crear órdenes de trabajo asociadas al aprobar citas              |

---

## 🧩 Funciones principales (Pages Functions)

| Archivo                              | Función                                                                                              |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `functions/api/_middleware.js`       | Valida JWT en todas las rutas `/api/*` excepto `/auth/login` y `/health`. Provee `createToken`, `verifyToken`, `sha256`, `sha256Hmac`. |
| `functions/api/auth/login.js`        | Login. Verifica credenciales y genera JWT firmado con `JWT_SECRET` (expira en 24h).                  |
| `functions/api/dashboard/index.js`   | KPIs agregados: citas hoy, pendientes de aprobación, aprobadas, del mes; OT pendientes, completadas del mes, express, ingresos del mes; técnicos activos; últimas 10 citas; próximas 10 citas. |
| `functions/api/citas/index.js`       | CRUD de citas (listar con filtros + crear).                                                          |
| `functions/api/citas/[id].js`        | Detalle / actualizar / eliminar cita.                                                                |
| `functions/api/citas/[id]/aprobar.js`| Aprueba cita, crea orden de trabajo en `sgc-ordenes`, agenda al técnico y envía WhatsApp.             |
| `functions/api/citas/[id]/rechazar.js`| Rechaza cita (guarda `motivo_rechazo`) y envía WhatsApp.                                            |
| `functions/api/ordenes/index.js`     | CRUD de órdenes (listar con filtros + crear). Viaja a `ORDENES_DB`.                                   |
| `functions/api/ordenes/[id].js`      | Detalle / actualizar orden.                                                                          |
| `functions/api/tecnicos/index.js`    | CRUD de técnicos (listar con OTs activas + crear).                                                   |
| `functions/api/tecnicos/[id].js`     | Actualizar / eliminar (soft delete) técnico.                                                         |
| `functions/api/calendario/index.js`  | Lista eventos unificados (`AgendaTecnicos` + OT programadas + citas pendientes) y crea eventos.      |
| `functions/api/calendario/[id].js`   | Actualizar / eliminar evento de agenda.                                                              |

---

## 🖥️ Frontend (JS vanilla)

| Archivo              | Responsabilidad                                                        |
| -------------------- | --------------------------------------------------------------------- |
| `js/app.js`          | App principal, routing entre secciones, manejo del estado de auth.    |
| `js/auth.js`         | Login, logout, almacenamiento del JWT en `localStorage`.              |
| `js/dashboard.js`    | Render de KPIs y gráficos con Chart.js (citas por servicio, etc.).    |
| `js/citas.js`        | Gestión de citas con modal crear/editar + aprobar/rechazar.           |
| `js/ordenes.js`      | Gestión de órdenes de trabajo (listado + creación/edición).           |
| `js/tecnicos.js`     | Gestión de técnicos (CRUD completo).                                  |
| `js/calendario.js`   | Calendario interactivo (FullCalendar o similar) con eventos unificados.|

---

## 🗄️ Tablas D1 utilizadas

Todas las tablas viven en la misma D1 (`citas`, UUID `678b4adc-232d-43db-86ec-230828268161`), expuesta vía dos bindings (`CITAS_DB` y `ORDENES_DB`).

### Módulo Citas (`sgc_cit_*`)

- `sgc_cit_Citas`
- `sgc_cit_Clientes`
- `sgc_cit_servicios_unificados`
- `sgc_cit_horarios`

### Módulo Órdenes (`sgc_ord_*`)

- `sgc_ord_OrdenesTrabajo`
- `sgc_ord_Tecnicos`
- `sgc_ord_Vehiculos`
- `sgc_ord_AgendaTecnicos` (calendario)

> Todas con `tenant_id=1` (default, single-tenant).

---

## ⚙️ Configuración

### Variables (`wrangler.toml` → `[vars]`)

| Variable              | Descripción                              | Default                                          |
| --------------------- | ---------------------------------------- | ------------------------------------------------ |
| `JWT_SECRET`          | Secreto para firmar tokens JWT (HS256)   | `sgc-secret-key-change-in-production`            |
| `ADMIN_USERNAME`      | Usuario admin                            | `admin`                                          |
| `ADMIN_PASSWORD_HASH` | Hash SHA256 del password admin           | `240be518...` (sha256 de `admin123`)             |
| `CITAS_WORKER_URL`    | URL del Worker `sgc-citas` (WhatsApp)    | `https://sgc-citas.activo.workers.dev`           |
| `ORDENES_PAGES_URL`   | URL del Pages `sgc-ordenes`              | `https://sgc-ordenes-di7.pages.dev`              |

> ⚠️ Todas las variables son `plain_text` (no son secrets). En producción mover `JWT_SECRET` y `ADMIN_PASSWORD_HASH` a secrets con `wrangler pages secret put`.

### Bindings

| Binding       | D1 database | database_id                              | Tablas              |
| ------------- | ----------- | ---------------------------------------- | ------------------- |
| `CITAS_DB`    | `citas`     | `678b4adc-232d-43db-86ec-230828268161`   | `sgc_cit_*`         |
| `ORDENES_DB`  | `citas`     | `678b4adc-232d-43db-86ec-230828268161`   | `sgc_ord_*`         |

> Ambos bindings apuntan a la **misma** D1 `citas`.

---

## 🚀 Deploy

```bash
git clone https://github.com/bboymak3/sgc-admin-pages.git
cd sgc-admin-pages

# Editar wrangler.toml con tu JWT_SECRET y password hash
nano wrangler.toml

# (Opcional) Generar nuevo hash SHA256 para el password admin
echo -n "tu-nuevo-password" | sha256sum

# Deploy a Cloudflare Pages
wrangler pages deploy . --project-name=sgc-admin --branch=main
```

### Dev local

```bash
npm run dev   # npx wrangler pages dev . --port 3001
```

---

## 🔐 Login default

- **Usuario**: `admin`
- **Password**: `admin123`
- **Hash SHA256**: `240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9`

> ⚠️ **Cambiar antes de producción.** Generá un nuevo hash con `echo -n "nuevo-password" | sha256sum` y actualizá `ADMIN_PASSWORD_HASH` en `wrangler.toml`.

---

## 📚 Repos relacionados

| Repo                                             | Descripción                                  |
| ------------------------------------------------ | -------------------------------------------- |
| [sgc-saas](https://github.com/bboymak3/sgc-saas) | Panel admin multi-tenant nuevo (reemplaza este) |
| [sgc-citas-worker](https://github.com/bboymak3/sgc-citas-worker) | Bot WhatsApp con IA + envío de mensajes       |
| [sgc-ordenes-pages](https://github.com/bboymak3/sgc-ordenes-pages) | Sistema de órdenes de trabajo (Pages)        |
| [sgc-recordatorios-worker](https://github.com/bboymak3/sgc-recordatorios-worker) | Worker de recordatorios de citas            |

---

## 📄 Licencia

Propietario — **SGC**. Todos los derechos reservados.

---

## Seguridad y pruebas (2026-09-29)

- `JWT_SECRET` ya no está en el código ni en `wrangler.toml`: configúralo con
  `wrangler pages secret put JWT_SECRET --project-name sgc-admin` (sin él la API responde 503).
- Tokens de 12 h, firma verificada en tiempo constante y solo `alg: HS256`; cookie `SameSite=Strict`.
- Contraseñas PBKDF2 con salt (los hashes SHA-256 se migran al iniciar sesión); se quitó la pista `admin/admin123`
  del login y el panel pide cambiarla al entrar con la clave por defecto (`POST /api/auth/cambiar-password`).
- Este panel es del taller SGC: todas las consultas de citas filtran `tenant_id = 1`
  (antes mostraba y permitía editar/borrar citas de otros negocios del SaaS).
- Calendario: el JOIN usaba la tabla vacía `Clientes`; ahora `sgc_ord_Clientes`.

Pruebas: `npm test` (middleware JWT, login, cambio de contraseña, aislamiento por tenant, dashboard y calendario).
