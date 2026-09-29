// ============================================
// SGC ADMIN - Auth middleware para /api/*
// Valida el JWT del header Authorization o de la cookie sgc_token.
// ============================================

import { verifyToken, json } from '../lib/auth.js';

export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);

  if (url.pathname === '/api/auth/login' || url.pathname === '/api/health') {
    return context.next();
  }
  if (!env.JWT_SECRET) {
    console.error('JWT_SECRET no configurado: API deshabilitada');
    return json({ success: false, error: 'Servidor sin configurar (JWT_SECRET)' }, 503);
  }

  let token = null;
  const authHeader = request.headers.get('Authorization') || '';
  if (authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  } else {
    const match = (request.headers.get('Cookie') || '').match(/sgc_token=([^;]+)/);
    if (match) token = match[1];
  }

  const payload = await verifyToken(token, env.JWT_SECRET);
  if (!payload) return json({ success: false, error: 'No autorizado' }, 401);

  context.data.user = payload;
  return context.next();
}
