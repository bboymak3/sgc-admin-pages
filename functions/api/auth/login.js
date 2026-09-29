// ============================================
// SGC ADMIN - Auth: Login
// POST /api/auth/login  body: { username, password }
// ============================================

import { createToken, verifyPassword, hashPassword, json } from '../../lib/auth.js';

async function throttled(request, username) {
  if (typeof caches === 'undefined' || !caches.default) return false;
  const key = new Request(`https://throttle.internal/admin/${encodeURIComponent(username)}/${request.headers.get('CF-Connecting-IP') || 'x'}`);
  return !!(await caches.default.match(key));
}
async function markFailure(request, username) {
  if (typeof caches === 'undefined' || !caches.default) return;
  const key = new Request(`https://throttle.internal/admin/${encodeURIComponent(username)}/${request.headers.get('CF-Connecting-IP') || 'x'}`);
  await caches.default.put(key, new Response('1', { headers: { 'Cache-Control': 'max-age=3' } }));
}

export async function onRequestPost(context) {
  const { request, env } = context;
  try {
    if (!env.JWT_SECRET) return json({ success: false, error: 'Servidor sin configurar (JWT_SECRET)' }, 503);
    const { username, password } = await request.json().catch(() => ({}));
    if (!username || !password) return json({ success: false, error: 'Usuario y contraseña requeridos' }, 400);
    if (await throttled(request, username)) return json({ success: false, error: 'Demasiados intentos, espera unos segundos' }, 429);

    const user = await env.ORDENES_DB.prepare(
      'SELECT id, username, password_hash, nombre, rol, activo FROM sgc_cit_AdminUsers WHERE username = ?'
    ).bind(username).first();
    const check = user && user.activo === 1 ? await verifyPassword(password, user.password_hash) : { ok: false };
    if (!check.ok) {
      await markFailure(request, username);
      return json({ success: false, error: 'Credenciales inválidas' }, 401);
    }

    const newHash = check.legacy ? await hashPassword(password) : null;
    await env.ORDENES_DB.prepare(
      "UPDATE sgc_cit_AdminUsers SET ultimo_login = datetime('now', '-3 hours')" + (newHash ? ', password_hash = ?' : '') + ' WHERE id = ?'
    ).bind(...(newHash ? [newHash, user.id] : [user.id])).run();

    const token = await createToken({ uid: user.id, username: user.username, nombre: user.nombre, rol: user.rol }, env.JWT_SECRET, 12);
    return json({
      success: true,
      token,
      user: { id: user.id, username: user.username, nombre: user.nombre, rol: user.rol },
      debe_cambiar_password: password === 'admin123'
    }, 200, { 'Set-Cookie': `sgc_token=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=43200` });
  } catch (e) {
    console.error('Error login:', e);
    return json({ success: false, error: 'Error interno' }, 500);
  }
}

export async function onRequestGet() {
  return json({ success: true, message: 'SGC Admin - Auth endpoint', version: '1.1.0' });
}
