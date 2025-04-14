import './globals.css'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { type ReactNode } from 'react'

import { Providers } from './providers'
import { Header } from './components/layout/Header'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Pachira - Composed Indexed Liquidity',
  description: 'DeFi protocol for composed indexed liquidity',
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function(){
                try {
                  var saved = localStorage.getItem('style-theme');
                  var theme = saved === 'current' ? 'current' : 'pachira';
                  document.documentElement.setAttribute('data-theme', theme);
                } catch (e) {
                  document.documentElement.setAttribute('data-theme', 'pachira');
                }
              })();
            `,
          }}
        />
        <Providers>
          <div className="min-h-screen bg-gray-900">
            <Header />
            <main className="py-8">
              {children}
            </main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
