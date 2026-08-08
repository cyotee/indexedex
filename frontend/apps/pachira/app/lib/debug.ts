const DEBUG_ENABLED = process.env.NEXT_PUBLIC_DEBUG === 'true'

export function debugLog(...args: unknown[]) {
  if (!DEBUG_ENABLED) return
  // eslint-disable-next-line no-console
  console.log(...args)
}

export function debugWarn(...args: unknown[]) {
  if (!DEBUG_ENABLED) return
  // eslint-disable-next-line no-console
  console.warn(...args)
}

export function debugError(...args: unknown[]) {
  if (!DEBUG_ENABLED) return
  // eslint-disable-next-line no-console
  console.error(...args)
}
