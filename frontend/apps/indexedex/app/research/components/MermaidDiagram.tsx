'use client'

import { useEffect, useId, useRef, useState } from 'react'

type Props = {
  chart: string
  caption?: string
  className?: string
}

type MermaidGlobal = {
  initialize: (config: Record<string, unknown>) => void
  render: (id: string, text: string) => Promise<{ svg: string }>
}

declare global {
  interface Window {
    mermaid?: MermaidGlobal
  }
}

let loadPromise: Promise<MermaidGlobal> | null = null

function ensureMermaid(): Promise<MermaidGlobal> {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Mermaid is browser-only'))
  }
  if (window.mermaid) return Promise.resolve(window.mermaid)
  if (loadPromise) return loadPromise

  loadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-mermaid-cdn]')
    if (existing) {
      existing.addEventListener('load', () => {
        if (window.mermaid) resolve(window.mermaid)
        else reject(new Error('Mermaid loaded without global'))
      })
      existing.addEventListener('error', () => reject(new Error('Mermaid script failed')))
      return
    }
    const script = document.createElement('script')
    script.src = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js'
    script.async = true
    script.dataset.mermaidCdn = '1'
    script.onload = () => {
      if (window.mermaid) resolve(window.mermaid)
      else reject(new Error('Mermaid loaded without global'))
    }
    script.onerror = () => reject(new Error('Mermaid script failed to load'))
    document.head.appendChild(script)
  })

  return loadPromise
}

/**
 * Client-side Mermaid renderer for research notes.
 * Product copy must never abbreviate constant-product as two letters — use ConstProd.
 */
export function MermaidDiagram({ chart, caption, className = '' }: Props) {
  const reactId = useId().replace(/:/g, '')
  const [svg, setSvg] = useState<string>('')
  const [error, setError] = useState<string | null>(null)
  const mounted = useRef(true)

  useEffect(() => {
    mounted.current = true
    ;(async () => {
      try {
        const mermaid = await ensureMermaid()
        mermaid.initialize({
          startOnLoad: false,
          theme: 'dark',
          securityLevel: 'loose',
          flowchart: {
            curve: 'basis',
            padding: 12,
            htmlLabels: true,
            nodeSpacing: 28,
            rankSpacing: 36,
            useMaxWidth: true,
          },
          themeVariables: {
            darkMode: true,
            background: 'transparent',
            primaryColor: '#1a2744',
            primaryTextColor: '#ededed',
            primaryBorderColor: '#5b8cff',
            secondaryColor: '#122a2a',
            tertiaryColor: '#151f33',
            lineColor: '#6b7a94',
            fontFamily: 'ui-sans-serif, system-ui, sans-serif',
            fontSize: '14px',
          },
        })
        const { svg: rendered } = await mermaid.render(`mmd-${reactId}`, chart.trim())
        if (mounted.current) {
          setSvg(rendered)
          setError(null)
        }
      } catch (e) {
        if (mounted.current) {
          setError(e instanceof Error ? e.message : 'Diagram failed to render')
        }
      }
    })()
    return () => {
      mounted.current = false
    }
  }, [chart, reactId])

  return (
    <figure
      className={`mt-6 overflow-x-auto rounded-2xl border border-[var(--border-accent,rgba(91,140,255,0.35))] bg-[var(--surface-2,#121a2b)] p-4 shadow-[0_16px_48px_rgba(0,0,0,0.35)] ${className}`}
    >
      {error ? (
        <pre className="whitespace-pre-wrap font-mono text-xs text-amber-200/90">{error}</pre>
      ) : svg ? (
        <div
          className="flex justify-center [&_svg]:max-w-full"
          dangerouslySetInnerHTML={{ __html: svg }}
        />
      ) : (
        <p className="py-8 text-center font-mono text-xs text-[var(--text-muted,#9aa3b2)]">
          Loading diagram…
        </p>
      )}
      {caption ? (
        <figcaption className="mt-4 border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] pt-3 text-xs leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          {caption}
        </figcaption>
      ) : null}
    </figure>
  )
}

export default MermaidDiagram
