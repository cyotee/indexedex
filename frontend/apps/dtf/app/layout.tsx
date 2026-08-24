import './globals.css'
import type { Metadata } from 'next'
import { Inter, JetBrains_Mono } from 'next/font/google'
import { type ReactNode } from 'react'

import { Providers } from './providers'
import { AppFrame } from './components/layout/AppFrame'
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
          <AppFrame>{children}</AppFrame>
        </Providers>
      </body>
    </html>
  )
}
