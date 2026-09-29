# SGC Admin Pages

Panel de administración del sistema SGC para gestión de citas, órdenes de trabajo, técnicos y calendario.

## 🏗️ Arquitectura

- **Hosting**: Cloudflare Pages
- **Functions**: Pages Functions en `/functions/api/`
- **DB**: Cloudflare D1 (tablas `sgc_cit_*` y `sgc_ord_*`)
- **Auth**: JWT con hash SHA256

## 📋 Estructura

```
.
├── index.html              # Login + dashboard
├── css/admin.css           # Estilos
├── js/
│   ├── app.js              # App principal
│   ├── auth.js             # Autenticación
│   ├── dashboard.js        # KPIs y gráficos
│   ├── citas.js            # Gestión de citas
│   ├── ordenes.js          # Gestión de órdenes
│   ├── tecnicos.js         # Gestión de técnicos
│   └── calendario.js       # Calendario
├── functions/
│   └── api/
│       ├── _middleware.js  # Auth middleware
│       ├── auth/login.js   # Login
│       ├── dashboard/      # KPIs
│       ├── citas/          # CRUD citas
│       ├── ordenes/        # CRUD órdenes
│       ├── tecnicos/       # CRUD técnicos
│       └── calendario/     # CRUD agenda
└── wrangler.toml
```

## 🔧 Configuración

### Variables (en wrangler.toml)
- `JWT_SECRET`: Secreto para firmar tokens JWT
- `ADMIN_USERNAME`: Usuario admin
- `ADMIN_PASSWORD_HASH`: Hash SHA256 del password
- `CITAS_WORKER_URL`: URL del Worker sgc-citas
- `ORDENES_PAGES_URL`: URL del Pages sgc-ordenes

### Bindings
- `CITAS_DB`: D1 database `citas`
- `ORDENES_DB`: D1 database `citas` (mismo)

## 🚀 Deploy

```bash
wrangler pages deploy . --project-name=sgc-admin --branch=main
```

## 🔐 Login default

- Usuario: `admin`
- Password: `admin123`

⚠️ Cambia el password antes de producción.
