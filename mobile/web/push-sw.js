// Service worker samo za obaveštenja (Web Push). Flutter ima svoj, ovaj je odvojen (scope ./push/).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) { data = { body: event.data && event.data.text() }; }
  const title = data.title || '25 Slova';
  event.waitUntil(self.registration.showNotification(title, {
    body: data.body || '',
    tag: data.tag || undefined,
    renotify: !!data.tag,
    icon: '../icons/Icon-192.png',
    badge: '../icons/Icon-192.png',
    data: { url: data.url || '' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL('../' + (event.notification.data && event.notification.data.url || ''), self.registration.scope).href;
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if (c.url.includes('/igra/') && 'focus' in c) return c.focus();
    }
    return self.clients.openWindow(target);
  })());
});
