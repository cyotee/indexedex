import './globals.css'
import type { Metadata } from 'next'
import { Inter, JetBrains_Mono } from 'next/font/google'
import { type ReactNode } from 'react'

import { Providers } from './providers'
import { Header } from './components/layout/Header'
import { Footer } from './components/layout/Footer'
import { LaunchBanner } from './components/ui/LaunchBanner'
import { AppShell } from './components/ui/AppShell'
import { SITE } from './lib/site'

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' })
const jetbrains = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono' })

export const metadata: Metadata = {
  title: SITE.title,
  description: SITE.description,
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.variable} ${jetbrains.variable} ${inter.className}`}>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function(){
                var theme = ${JSON.stringify(SITE.id)};
                document.documentElement.setAttribute('data-theme', theme);
                document.documentElement.setAttribute('data-brand', theme);
              })();
            `,
          }}
        />
        <Providers>
          <div className="min-h-screen flex flex-col bg-[var(--surface-0,#0a0a0a)]">
            <LaunchBanner />
            <Header />
            <main className="flex-1 py-6 md:py-8">
              <AppShell wide>{children}</AppShell>
            </main>
            <Footer />
          </div>
        </Providers>
      </body>
    </html>
  )
}
