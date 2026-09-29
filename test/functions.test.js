import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { FakeD1 } from "./helpers/d1.js";
import { onRequest as middleware } from "../functions/api/_middleware.js";
import * as login from "../functions/api/auth/login.js";
import * as cambiarPassword from "../functions/api/auth/cambiar-password.js";
import * as citasIndex from "../functions/api/citas/index.js";
import * as citaId from "../functions/api/citas/[id].js";
import * as rechazar from "../functions/api/citas/[id]/rechazar.js";
import * as dashboard from "../functions/api/dashboard/index.js";
import * as calendario from "../functions/api/calendario/index.js";
import { createToken, verifyToken, sha256 } from "../functions/lib/auth.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SECRET = "jwt-secret-de-prueba";

async function makeEnv() {
  const db = new FakeD1();
  db.exec_(readFileSync(join(ROOT, "test/fixtures/schema.sql"), "utf8"));
  db.exec_(`
    INSERT INTO sgc_cit_AdminUsers (id, username, password_hash, nombre) VALUES (1, 'admin', '${await sha256("admin123")}', 'Admin');
    INSERT INTO sgc_cit_Citas (id, fecha_cita, hora_cita, servicio, nombre_cliente, estado, estado_aprobacion, tenant_id) VALUES
      (1, date('now','-3 hours'), '10:00', 'Frenos', 'Cliente SGC', 'confirmada', 'pendiente', 1),
      (2, date('now','-3 hours'), '11:00', 'Barba', 'Cliente Barbería', 'confirmada', 'pendiente', 2);
    INSERT INTO sgc_ord_Clientes (id, nombre, telefono) VALUES (1, 'Luis', '569');
    INSERT INTO sgc_ord_OrdenesTrabajo (id, numero_orden, cliente_id, fecha_programada, hora_programada, estado) VALUES (1, 1, 1, date('now','-3 hours'), '12:00', 'Aprobada');
  `);
  return { DB: db, CITAS_DB: db, ORDENES_DB: db, JWT_SECRET: SECRET };
}

const req = (method, path, { body, token } = {}) => new Request(`https://admin.test${path}`, {
  method,
  headers: { ...(body ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  body: body ? JSON.stringify(body) : undefined
});

async function mw(env, request) {
  const context = { request, env, data: {}, next: async () => new Response("NEXT") };
  const res = await middleware(context);
  return { status: res.status, passed: (await res.clone().text()) === "NEXT", context };
}

async function doLogin(env, password = "admin123") {
  const res = await login.onRequestPost({ request: req("POST", "/api/auth/login", { body: { username: "admin", password } }), env });
  return { status: res.status, data: await res.json(), cookie: res.headers.get("Set-Cookie") };
}

test("todos los módulos de functions/ cargan", async () => {
  const files = [];
  const walk = (d) => readdirSync(d).forEach((f) => { const p = join(d, f); statSync(p).isDirectory() ? walk(p) : p.endsWith(".js") && files.push(p); });
  walk(join(ROOT, "functions"));
  for (const f of files) await import(pathToFileURL(f).href).catch((e) => assert.fail(`${relative(ROOT, f)}: ${e.message}`));
});

test("JWT: el secreto viene de env; sin secreto no hay acceso (antes estaba en el código)", async () => {
  const env = await makeEnv();
  const token = await createToken({ uid: 1 }, SECRET);
  assert.ok((await mw(env, req("GET", "/api/citas", { token }))).passed);
  assert.equal((await mw(env, req("GET", "/api/citas"))).status, 401);
  const forged = await createToken({ uid: 1 }, "sgc-secret-key-change-in-production");
  assert.equal((await mw(env, req("GET", "/api/citas", { token: forged }))).status, 401, "el secreto viejo publicado en el repo ya no sirve");
  assert.equal((await mw({ ...env, JWT_SECRET: undefined }, req("GET", "/api/citas", { token }))).status, 503);
  assert.equal(await verifyToken(token.replace(/\.[^.]+$/, ".firmaFalsa"), SECRET), null);
  const alg = token.split(".");
  alg[0] = Buffer.from(JSON.stringify({ alg: "none" })).toString("base64url");
  assert.equal(await verifyToken(alg.join("."), SECRET), null, "rechaza alg distinto de HS256");
});

test("login: migra SHA-256 a PBKDF2, cookie estricta y aviso de contraseña por defecto", async () => {
  const env = await makeEnv();
  assert.equal((await doLogin(env, "mala")).status, 401);
  const ok = await doLogin(env);
  assert.equal(ok.status, 200);
  assert.equal(ok.data.debe_cambiar_password, true);
  assert.match(ok.cookie, /HttpOnly; Secure; SameSite=Strict/);
  assert.match(env.DB.row("SELECT password_hash FROM sgc_cit_AdminUsers").password_hash, /^pbkdf2\$/);
  assert.equal((await doLogin(env)).status, 200);
});

test("cambiar contraseña", async () => {
  const env = await makeEnv();
  const token = (await doLogin(env)).data.token;
  const run = async (body) => {
    const { context } = await mw(env, req("POST", "/api/auth/cambiar-password", { token, body }));
    const res = await cambiarPassword.onRequestPost({ ...context, request: req("POST", "/api/auth/cambiar-password", { token, body }) });
    return res.status;
  };
  assert.equal(await run({ actual: "admin123", nueva: "corta" }), 400);
  assert.equal(await run({ actual: "mala", nueva: "NuevaClave2026!" }), 401);
  assert.equal(await run({ actual: "admin123", nueva: "NuevaClave2026!" }), 200);
  assert.equal((await doLogin(env, "admin123")).status, 401);
  assert.equal((await doLogin(env, "NuevaClave2026!")).status, 200);
});

test("citas: el panel SGC solo ve y modifica citas del tenant 1", async () => {
  const env = await makeEnv();
  const list = await (await citasIndex.onRequestGet({ request: req("GET", "/api/citas"), env })).json();
  assert.deepEqual(list.citas.map((c) => c.id), [1]);

  assert.equal((await citaId.onRequestGet({ env, params: { id: "2" } })).status, 404);
  await citaId.onRequestPut({ request: req("PUT", "/api/citas/2", { body: { estado: "cancelada" } }), env, params: { id: "2" } });
  await citaId.onRequestDelete({ env, params: { id: "2" } });
  const r = await rechazar.onRequestPost({ request: req("POST", "/api/citas/2/rechazar", { body: { motivo: "x" } }), env, params: { id: "2" }, data: {} });
  assert.equal(r.status, 404);
  const c2 = env.DB.row("SELECT estado, estado_aprobacion FROM sgc_cit_Citas WHERE id = 2");
  assert.deepEqual(c2, { estado: "confirmada", estado_aprobacion: "pendiente" }, "la cita de la barbería no se tocó");

  const nueva = await (await citasIndex.onRequestPost({ request: req("POST", "/api/citas", { body: { fecha_cita: "2026-12-01", hora_cita: "10:00", servicio: "X" } }), env, data: {} })).json();
  assert.equal(nueva.cita.tenant_id, 1);
});

test("dashboard y calendario cuentan solo el tenant 1 y el calendario ya no falla por el JOIN a Clientes", async () => {
  const env = await makeEnv();
  const d = await (await dashboard.onRequestGet({ request: req("GET", "/api/dashboard"), env })).json();
  assert.equal(d.success, true, JSON.stringify(d));
  assert.equal(JSON.stringify(d).includes("Cliente Barbería"), false);
  const hoy = env.DB.row("SELECT date('now','-3 hours') AS h").h;
  const cal = await (await calendario.onRequestGet({ request: req("GET", `/api/calendario?inicio=${hoy}&fin=${hoy}`), env })).json();
  assert.equal(cal.success, true, JSON.stringify(cal));
  const txt = JSON.stringify(cal.eventos);
  assert.ok(!txt.includes("Cliente Barbería"));
  assert.ok(txt.includes("Luis"), "la OT muestra el nombre del cliente (sgc_ord_Clientes)");
});
