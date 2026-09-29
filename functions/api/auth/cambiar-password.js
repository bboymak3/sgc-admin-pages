// ============================================
// SGC ADMIN - Cambiar contraseña
// POST /api/auth/cambiar-password  body: { actual, nueva }  (requiere JWT)
// ============================================

import { verifyPassword, hashPassword, json } from '../../lib/auth.js';

export async function onRequestPost(context) {
  const { request, env, data } = context;
  try {
    const { actual, nueva } = await request.json().catch(() => ({}));
    if (!nueva || String(nueva).length < 10) return json({ success: false, error: 'La nueva contraseña debe tener al menos 10 caracteres' }, 400);
    const user = await env.ORDENES_DB.prepare(
      'SELECT id, password_hash FROM sgc_cit_AdminUsers WHERE id = ? AND activo = 1'
    ).bind(data.user.uid).first();
    if (!user || !(await verifyPassword(String(actual || ''), user.password_hash)).ok) {
      return json({ success: false, error: 'La contraseña actual no es correcta' }, 401);
    }
    await env.ORDENES_DB.prepare('UPDATE sgc_cit_AdminUsers SET password_hash = ? WHERE id = ?')
      .bind(await hashPassword(String(nueva)), user.id).run();
    return json({ success: true, mensaje: 'Contraseña actualizada' });
  } catch (e) {
    console.error('Error cambiar-password:', e);
    return json({ success: false, error: 'Error interno' }, 500);
  }
}
