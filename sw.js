/* Awesome Ninja Admins — Service Worker
 * Strategy:
 *   - Precache app shell on install
 *   - Same-origin GET requests: stale-while-revalidate (fast + fresh)
 *   - Cross-origin GETs (Three.js CDN, Google Fonts): cache-first with background refresh
 *   - Nav requests: network-first, fall back to cached shell (works offline)
 *   - New SW takes control immediately; page can prompt for refresh
 */
const VERSION = "v1.2.0";
const SHELL = "ninja-shell-" + VERSION;
const RUNTIME = "ninja-runtime-" + VERSION;

const SHELL_ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/maskable-512.png",
  "./icons/favicon-64.png",
  // Z.E.R.O. second-brain console — brain-data.js carries the whole graph,
  // so precaching these two makes the console fully usable offline.
  "./zero-brain/",
  "./zero-brain/index.html",
  "./zero-brain/brain-data.js",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL).then((cache) => cache.addAll(SHELL_ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== SHELL && k !== RUNTIME).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("message", (e) => {
  if (e.data === "SKIP_WAITING") self.skipWaiting();
});

function isNav(req) {
  return req.mode === "navigate" || (req.method === "GET" && req.headers.get("accept")?.includes("text/html"));
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  // Navigation → network-first, offline fallback to shell
  if (isNav(req)) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(RUNTIME).then((c) => c.put(req, copy));
          return res;
        })
        // Offline: prefer this page's own precached copy (so /zero-brain/
        // serves the console, not the landing page), then fall back to the shell.
        .catch(() =>
          caches
            .match(req, { ignoreSearch: true })
            .then((r) => r || caches.match("./index.html"))
            .then((r) => r || caches.match("./"))
        )
    );
    return;
  }

  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;

  if (sameOrigin) {
    // Stale-while-revalidate for same-origin static assets
    event.respondWith(
      caches.match(req).then((cached) => {
        const fetchPromise = fetch(req)
          .then((res) => {
            if (res && res.status === 200) {
              const copy = res.clone();
              caches.open(RUNTIME).then((c) => c.put(req, copy));
            }
            return res;
          })
          .catch(() => cached);
        return cached || fetchPromise;
      })
    );
  } else {
    // Cache-first for CDN assets (Three.js, Google Fonts)
    event.respondWith(
      caches.match(req).then((cached) => {
        if (cached) return cached;
        return fetch(req).then((res) => {
          if (res && (res.status === 200 || res.type === "opaque")) {
            const copy = res.clone();
            caches.open(RUNTIME).then((c) => c.put(req, copy));
          }
          return res;
        });
      })
    );
  }
});
