const CACHE = 'louis-star-bank-v1';
const ASSETS = ['/', '/index.html', '/manifest.json', '/icon.png'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS))
  );
});

self.addEventListener('fetch', e => {
  e.respondWith(
    fetch(e.request)
      .catch(() => caches.match(e.request))
  );
});