// Service worker DoktaNet : l'application (HTML, JS, WASM, polices, images) fonctionne hors-ligne après une première visite.
// Stratégie "stale-while-revalidate" : réponse immédiate depuis le cache, mise à jour en arrière-plan.
// Une nouvelle version s'applique donc au chargement suivant. Jamais de mise en cache de /api/ (données privées).
const CACHE = 'doktanet-shell-v1';
const CDN = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k !== CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || req.headers.has('range')) return;
  const url = new URL(req.url);
  if (url.origin === self.location.origin) {
    if (url.pathname.startsWith('/api/')) return;
  } else if (!CDN.includes(url.hostname)) {
    return;
  }
  e.respondWith(staleWhileRevalidate(e, req));
});

async function staleWhileRevalidate(e, req) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(req, { ignoreSearch: req.mode === 'navigate' });
  const network = fetch(req)
    .then((res) => {
      if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
      return res;
    })
    .catch(() => null);
  if (hit) { e.waitUntil(network); return hit; }
  const res = await network;
  if (res) return res;
  if (req.mode === 'navigate') {
    const shell = await cache.match('/') || await cache.match('/index.html');
    if (shell) return shell;
  }
  return new Response('Hors ligne', { status: 503, headers: { 'content-type': 'text/plain; charset=utf-8' } });
}
