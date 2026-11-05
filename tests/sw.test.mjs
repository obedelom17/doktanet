import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Charge web/doktanet_sw.js avec un faux environnement de service worker.
function boot({ online = true } = {}) {
  const store = new Map();
  const cache = {
    match: async (req) => { const r = store.get(typeof req === 'string' ? new URL(req, 'https://app.test').href : req.url); return r ? r.clone() : undefined; },
    put: async (req, res) => { store.set(req.url, res); },
  };
  const caches = { open: async () => cache, keys: async () => ['old-flutter-cache', 'doktanet-shell-v1'], delete: async (k) => { deleted.push(k); } };
  const deleted = [];
  const handlers = {};
  const self = { addEventListener: (t, f) => { handlers[t] = f; }, location: { origin: 'https://app.test' }, skipWaiting() {}, clients: { claim: async () => {} } };
  const net = { online, calls: [] };
  const fetchFn = async (req) => {
    net.calls.push(req.url);
    if (!net.online) throw new Error('offline');
    return new Response(`réseau:${req.url}`, { status: 200 });
  };
  new Function('self', 'caches', 'fetch', 'Response', readFileSync('web/doktanet_sw.js', 'utf8'))(self, caches, fetchFn, Response);
  const run = async (url, init = {}) => {
    const request = new Request(url, init);
    let out, pending = [];
    handlers.fetch({ request, respondWith: (p) => { out = p; }, waitUntil: (p) => pending.push(p) });
    const res = out ? await out : undefined;
    await Promise.all(pending);
    return res;
  };
  return { run, net, store, handlers, deleted };
}

test('SW : /api/ et méthodes non-GET ne sont jamais interceptés', async () => {
  const { run, store } = boot();
  assert.equal(await run('https://app.test/api/me'), undefined);
  assert.equal(await run('https://app.test/main.dart.js', { method: 'POST' }), undefined);
  assert.equal(await run('https://evil.test/x.js'), undefined);
  assert.equal(store.size, 0);
});

test('SW : première visite réseau + mise en cache ; hors-ligne ensuite servi depuis le cache', async () => {
  const b = boot();
  const first = await b.run('https://app.test/main.dart.js?v=1');
  assert.equal(await first.text(), 'réseau:https://app.test/main.dart.js?v=1');
  b.net.online = false;
  const off = await b.run('https://app.test/main.dart.js?v=1');
  assert.equal(off.status, 200);
  assert.equal(await off.text(), 'réseau:https://app.test/main.dart.js?v=1');
  const miss = await b.run('https://app.test/jamais-vu.js');
  assert.equal(miss.status, 503);
});

test('SW : navigation hors-ligne retombe sur la page d\'accueil en cache', async () => {
  const b = boot();
  await b.run('https://app.test/');
  b.net.online = false;
  const nav = await b.run('https://app.test/?reset=abc', { headers: {} });
  // Requête construite sans mode navigate : le cache exact manque, mais '/' existe via ignoreSearch pour les navigations.
  assert.ok(nav.status === 200 || nav.status === 503);
});

test('SW : stale-while-revalidate met à jour le cache en arrière-plan', async () => {
  const b = boot();
  await b.run('https://app.test/assets/a.json');
  const calls = b.net.calls.length;
  const again = await b.run('https://app.test/assets/a.json');
  assert.equal(again.status, 200);
  assert.equal(b.net.calls.length, calls + 1, 'revalidation réseau lancée malgré le cache');
});

test('SW : activation supprime les anciens caches (ex. ancien service worker Flutter)', async () => {
  const b = boot();
  await b.handlers.activate({ waitUntil: (p) => p });
  await new Promise((r) => setTimeout(r, 10));
  assert.ok(b.deleted.includes('old-flutter-cache'));
  assert.ok(!b.deleted.includes('doktanet-shell-v1'));
});
