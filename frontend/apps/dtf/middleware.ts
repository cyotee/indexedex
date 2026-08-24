import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

import { resolveHostNavigation } from './app/lib/siteOrigins'

export function middleware(request: NextRequest) {
  const host = request.headers.get('host') ?? ''
  const { pathname, search } = request.nextUrl
  const nav = resolveHostNavigation(host, pathname, search)
  if (nav.type === 'redirect') {
    return NextResponse.redirect(new URL(nav.location, request.url))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\..*).*)'],
}
