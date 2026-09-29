// ============================================
// SGC ADMIN - JWT (HS256) y contraseñas
// El secreto se lee de env.JWT_SECRET (wrangler pages secret put JWT_SECRET).
// Sin secreto configurado no se emiten ni aceptan tokens (falla cerrado).
// ============================================

const enc = new TextEncoder();

function b64url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64urlJson(obj) {
  return b64url(enc.encode(JSON.stringify(obj)));
}
function b64urlDecode(s) {
  const pad = s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4);
  return new TextDecoder().decode(Uint8Array.from(atob(pad), (c) => c.charCodeAt(0)));
}

export function safeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function hmac(message, secret) {
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64url(new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(message))));
}

export async function createToken(payload, secret, expiresInHours = 12) {
  if (!secret) throw new Error('JWT_SECRET no configurado');
  const now = Math.floor(Date.now() / 1000);
  const data = b64urlJson({ alg: 'HS256', typ: 'JWT' }) + '.' + b64urlJson({ ...payload, iat: now, exp: now + expiresInHours * 3600 });
  return data + '.' + (await hmac(data, secret));
}

export async function verifyToken(token, secret) {
  if (!token || !secret) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const header = JSON.parse(b64urlDecode(parts[0]));
    if (header.alg !== 'HS256') return null;
    if (!safeEqual(await hmac(parts[0] + '.' + parts[1], secret), parts[2])) return null;
    const payload = JSON.parse(b64urlDecode(parts[1]));
    if (!payload.exp || Date.now() > payload.exp * 1000) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

export async function sha256(text) {
  const buf = await crypto.subtle.digest('SHA-256', enc.encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Contraseñas: pbkdf2$<iter>$<salt hex>$<hash hex>; SHA-256 sin salt (legacy) se migra al entrar
const PBKDF2_ITER = 100000;
const toHex = (buf) => Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
const fromHex = (hex) => new Uint8Array(hex.match(/.{2}/g).map((h) => parseInt(h, 16)));

async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  return toHex(await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations }, key, 256));
}

export async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  return `pbkdf2$${PBKDF2_ITER}$${toHex(salt)}$${await pbkdf2(password, salt, PBKDF2_ITER)}`;
}

export async function verifyPassword(password, stored) {
  if (!stored) return { ok: false };
  if (stored.startsWith('pbkdf2$')) {
    const [, iter, saltHex, hash] = stored.split('$');
    return { ok: safeEqual(await pbkdf2(password, fromHex(saltHex), parseInt(iter, 10)), hash), legacy: false };
  }
  return { ok: safeEqual(await sha256(password), stored), legacy: true };
}

export function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json', ...headers } });
}
