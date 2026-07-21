const CACHE = 'ustobozor-web-v46';
const SHELL = ['/', '/index.html', '/manifest.json'];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

function isWebAsset(url) {
  const p = url.pathname;
  if (p.startsWith('/static/')) return true;
  if (p === '/' || p.startsWith('/app.') || p.startsWith('/icons.') || p.startsWith('/sw.js') || p.startsWith('/manifest.') || p.startsWith('/icon.')) return true;
  return false;
}

/** CSS/JS — только сеть, без кэша (чтобы сразу подхватывался новый дизайн). */
function networkOnly(request) {
  return fetch(request, { cache: 'no-store' });
}

self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  if (u.origin !== self.location.origin || !isWebAsset(u)) return;

  if (u.pathname.endsWith('.css') || u.pathname.endsWith('.js')) {
    e.respondWith(networkOnly(e.request));
    return;
  }

  if ((u.pathname === '/' || (!u.pathname.includes('.') && isWebAsset(u))) && !u.pathname.startsWith('/admin') && !u.pathname.startsWith('/static')) {
    e.respondWith(
      fetch('/index.html', { cache: 'no-store' })
        .catch(() => caches.match('/index.html'))
    );
    return;
  }

  e.respondWith(
    fetch(e.request, { cache: 'no-store' })
      .then((response) => {
        if (response && response.ok) {
          const clone = response.clone();
          caches.open(CACHE).then((cache) => cache.put(e.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(e.request))
  );
});
