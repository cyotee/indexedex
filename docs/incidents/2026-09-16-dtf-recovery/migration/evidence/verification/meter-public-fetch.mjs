// Transport-only instrumentation. Rate limiting is not test synchronization.
// Receipts and fork readiness still use explicit mining and readiness events.
import { setTimeout as delay } from "node:timers/promises";
const originalFetch = globalThis.fetch;
let nextSlot = 0;
globalThis.fetch = async function meteredFetch(input, init) {
  const url = typeof input === "string" ? new URL(input)
    : input instanceof URL ? input : new URL(input.url);
  const local = url.hostname === "127.0.0.1" || url.hostname === "localhost";
  if (!local && init?.method === "POST") {
    const reserved = Math.max(Date.now(), nextSlot);
    nextSlot = reserved + 1200;
    const remaining = reserved - Date.now();
    if (remaining > 0) await delay(remaining);
  }
  return originalFetch(input, init);
};
