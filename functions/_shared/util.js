// Fonctions pures partagées (testées dans tests/util.test.mjs).
export const enc = new TextEncoder();

export const b64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
export const unb64u = (s) => { s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '='; return Uint8Array.from(atob(s), (c) => c.charCodeAt(0)); };
export const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
export const hkey = (secret) => crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);

export async function signJwt(payload, secret) {
  const h = b64u(enc.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const p = b64u(enc.encode(JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + 7 * 86400 })));
  const sig = await crypto.subtle.sign('HMAC', await hkey(secret), enc.encode(`${h}.${p}`));
  return `${h}.${p}.${b64u(sig)}`;
}
export async function verifyJwt(token, secret) {
  try {
    const [h, p, s] = token.split('.');
    if (!(await crypto.subtle.verify('HMAC', await hkey(secret), unb64u(s), enc.encode(`${h}.${p}`)))) return null;
    const payload = JSON.parse(new TextDecoder().decode(unb64u(p)));
    return payload.exp > Date.now() / 1000 ? payload : null;
  } catch { return null; }
}
export async function hashPassword(pw, saltB64) {
  const salt = saltB64 ? unb64u(saltB64) : crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey('raw', enc.encode(pw), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' }, key, 256);
  return `${b64u(salt)}.${b64u(bits)}`;
}
export const checkPassword = async (pw, stored) => (await hashPassword(pw, stored.split('.')[0])) === stored;


// ---------- 2FA TOTP (RFC 6238) ----------
const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
export const b32enc = (bytes) => {
  let bits = '', out = '';
  for (const b of bytes) bits += b.toString(2).padStart(8, '0');
  for (let i = 0; i < bits.length; i += 5) out += B32[parseInt(bits.slice(i, i + 5).padEnd(5, '0'), 2)];
  return out;
};
export const b32dec = (str) => {
  let bits = '';
  for (const c of str.replace(/=+$/, '').toUpperCase()) bits += B32.indexOf(c).toString(2).padStart(5, '0');
  const out = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) out.push(parseInt(bits.slice(i, i + 8), 2));
  return new Uint8Array(out);
};
export async function totp(secret, t = Date.now()) {
  const counter = Math.floor(t / 30000);
  const buf = new ArrayBuffer(8);
  const dv = new DataView(buf);
  dv.setUint32(0, Math.floor(counter / 2 ** 32));
  dv.setUint32(4, counter >>> 0);
  const key = await crypto.subtle.importKey('raw', b32dec(secret), { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
  const h = new Uint8Array(await crypto.subtle.sign('HMAC', key, buf));
  const o = h[19] & 15;
  const code = (((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3]) % 1000000;
  return String(code).padStart(6, '0');
}
export async function totpCheck(secret, code) {
  const c = String(code || '').trim();
  for (const d of [-1, 0, 1]) if ((await totp(secret, Date.now() + d * 30000)) === c) return true;
  return false;
}

// Comparaison en temps constant (secrets, signatures).
export function timingSafeEq(a, b) {
  const x = enc.encode(String(a ?? '')), y = enc.encode(String(b ?? ''));
  let d = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) d |= (x[i] || 0) ^ (y[i] || 0);
  return d === 0;
}

// Chiffrement applicatif AES-GCM des données sensibles (clé : env.DATA_KEY). Préfixe enc1: ; texte clair si pas de clé.
const dkey = async (secret) => crypto.subtle.importKey('raw', await crypto.subtle.digest('SHA-256', enc.encode(`doktanet:data:${secret}`)), 'AES-GCM', false, ['encrypt', 'decrypt']);
export async function encData(secret, text) {
  const t = String(text ?? '');
  if (!secret) return t;
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await dkey(secret), enc.encode(t));
  return `enc1:${b64u(iv)}.${b64u(ct)}`;
}
export async function decData(secret, text) {
  const t = String(text ?? '');
  if (!t.startsWith('enc1:')) return t;
  if (!secret) return '[chiffré]';
  try {
    const [iv, ct] = t.slice(5).split('.');
    const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64u(iv) }, await dkey(secret), unb64u(ct));
    return new TextDecoder().decode(pt);
  } catch { return '[illisible]'; }
}

export const sha256hex = async (s) => hex(await crypto.subtle.digest('SHA-256', enc.encode(String(s))));
export const randToken = (n = 32) => b64u(crypto.getRandomValues(new Uint8Array(n)));

export const DOC_RE = /^data:(image\/(?:jpeg|png|webp)|application\/pdf);base64,[A-Za-z0-9+/=]+$/;
export const isRated = (n) => Number.isInteger(n) && n >= 1 && n <= 5;
export const limited = (count, max) => Number(count) >= max;
export const validEmail = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || '')) && String(e).length <= 254;
export const validPhone = (p) => /^\+?\d{8,15}$/.test(String(p || '').replace(/\s/g, ''));

// Lit un flux SSE "chat.completions" (stream:true). Appelle onToken pour chaque fragment de texte.
// Retourne { content, toolCalls } avec les appels d'outils reconstitués à partir des fragments.
export async function readChatStream(body, onToken = () => {}) {
  const reader = body.getReader();
  const dec = new TextDecoder();
  let buf = '', content = '';
  const calls = [];
  const handle = (line) => {
    line = line.trim();
    if (!line.startsWith('data:')) return;
    const data = line.slice(5).trim();
    if (!data || data === '[DONE]') return;
    let j;
    try { j = JSON.parse(data); } catch { return; }
    const d = j.choices?.[0]?.delta;
    if (!d) return;
    if (d.content) { content += d.content; onToken(d.content); }
    for (const tc of d.tool_calls || []) {
      const k = tc.index ?? 0;
      calls[k] ??= { id: '', type: 'function', function: { name: '', arguments: '' } };
      if (tc.id) calls[k].id = tc.id;
      if (tc.function?.name) calls[k].function.name += tc.function.name;
      if (tc.function?.arguments) calls[k].function.arguments += tc.function.arguments;
    }
  };
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    let i;
    while ((i = buf.indexOf('\n')) >= 0) { handle(buf.slice(0, i)); buf = buf.slice(i + 1); }
  }
  if (buf) handle(buf);
  return { content, toolCalls: calls.filter(Boolean) };
}

// Un PDF commence toujours par %PDF- ; une image par son en-tête propre (anti faux types MIME).
export function docMagicOk(dataUrl) {
  const m = /^data:([^;]+);base64,(.*)$/s.exec(String(dataUrl || ''));
  if (!m) return false;
  const head = m[2].slice(0, 12);
  switch (m[1]) {
    case 'application/pdf': return head.startsWith('JVBERi');
    case 'image/png': return head.startsWith('iVBORw0KGgo');
    case 'image/jpeg': return head.startsWith('/9j/');
    case 'image/webp': return head.startsWith('UklGR');
    default: return false;
  }
}
