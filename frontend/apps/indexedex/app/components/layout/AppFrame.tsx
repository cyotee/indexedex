'use client'

import { usePathname } from 'next/navigation'
import type { ReactNode } from 'react'

import { AppShell } from '../ui/AppShell'
import { LaunchBanner } from '../ui/LaunchBanner'
import { Footer } from './Footer'
import { Header } from './Header'

export function AppFrame({ children }: { children: ReactNode }) {
  const pathname = usePathname()
  const isLanding = pathname === '/'

  if (isLanding) {
    return <div className="min-h-screen bg-[var(--surface-0,#050c1d)]">{children}</div>
  }

  return (
    <div className="min-h-screen flex flex-col bg-[var(--surface-0,#0a0a0a)]">
      <LaunchBanner />
      <Header />
      <main className="flex-1 py-6 md:py-8">
        <AppShell wide>{children}</AppShell>
      </main>
      <Footer />
    </div>
  )
}

export default AppFrame
