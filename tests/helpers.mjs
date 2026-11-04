import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

export async function freshDb() {
  const db = new PGlite();
  globalThis.__pg = db;
  const stmts = readFileSync(resolve('schema.sql'), 'utf8')
    .split(/;\s*\n/)
    .map((s) => s.split('\n').filter((l) => !l.trim().startsWith('--')).join('\n').trim())
    .filter(Boolean);
  for (const s of stmts) await db.query(s);
  return db;
}

export async function loadApi() {
  // Import frais à chaque suite : réinitialise les drapeaux module (v2Ready, avatarReady).
  const url = pathToFileURL(resolve('functions/api/[[path]].js')).href + `?t=${Date.now()}${Math.random()}`;
  return (await import(url)).onRequest;
}

export function makeClient(onRequest, env, ip = '1.1.1.1') {
  return async (method, path, { body, token, headers = {} } = {}) => {
    const h = { 'content-type': 'application/json', 'cf-connecting-ip': ip, ...headers };
    if (token) h.authorization = `Bearer ${token}`;
    const r = await onRequest({
      request: new Request(`http://test.local/api${path}`, { method, headers: h, body: method === 'GET' ? undefined : JSON.stringify(body || {}) }),
      env,
    });
    const ct = r.headers.get('content-type') || '';
    const data = ct.includes('json') ? await r.json() : Buffer.from(await r.arrayBuffer());
    return { status: r.status, data, headers: r.headers };
  };
}
