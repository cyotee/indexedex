export const APP_HOST = 'app.downto.finance'
export const MARKETING_HOSTS = ['downto.finance', 'www.downto.finance'] as const

export type HostNav = { type: 'next' } | { type: 'redirect'; location: string }

function hostname(host: string): string {
  return host.split(':')[0]?.toLowerCase() ?? ''
}

export function isAppHost(host: string): boolean {
  return hostname(host) === APP_HOST
}

export function isMarketingHost(host: string): boolean {
  return (MARKETING_HOSTS as readonly string[]).includes(hostname(host))
}

/** Absolute app origin in production; empty locally and on preview so paths stay same-origin. */
export function appOrigin(): string {
  return (process.env.NEXT_PUBLIC_APP_ORIGIN ?? '').replace(/\/$/, '')
}

export function appPath(path: string): string {
  const p = path.startsWith('/') ? path : `/${path}`
  const origin = appOrigin()
  return origin ? `${origin}${p}` : p
}

export function resolveHostNavigation(host: string, pathname: string, search = ''): HostNav {
  if (isAppHost(host)) {
    if (pathname === '/' || pathname === '') {
      return { type: 'redirect', location: `/explore${search}` }
    }
    return { type: 'next' }
  }
  if (isMarketingHost(host) && pathname !== '/' && pathname !== '') {
    return { type: 'redirect', location: `https://${APP_HOST}${pathname}${search}` }
  }
  return { type: 'next' }
}
