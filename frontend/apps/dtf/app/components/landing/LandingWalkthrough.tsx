'use client'

import { useState } from 'react'

const STEPS = [
  {
    id: 'mint',
    n: '01',
    label: 'Mint',
    title: 'You buy in with one token',
    body: 'You send stablecoins and get back one DETF token. That single token stands for everything inside the basket. You never open the individual positions yourself.',
    youDo: 'Send stables, receive one token',
    basketDoes: 'Puts your deposit to work across its positions',
    example: [
      { left: 'Your wallet', right: '1 DETF token', tone: 'mint' as const },
      { left: 'Stable lending position', right: 'Funded', tone: 'ok' as const },
      { left: 'ETH liquidity position', right: 'Funded', tone: 'ok' as const },
    ],
  },
  {
    id: 'hold',
    n: '02',
    label: 'Hold',
    title: 'It keeps working for you',
    body: 'The basket stays active in other apps: trading pools, lending books, vaults, and staking. You do not move anything. There is no manager and no promised return.',
    youDo: 'Hold the DETF token',
    basketDoes: 'Keeps the positions working in other apps',
    example: [
      { left: 'Your wallet', right: '1 DETF token', tone: 'mint' as const },
      { left: 'Stable lending position', right: 'Working', tone: 'ok' as const },
      { left: 'ETH liquidity position', right: 'Working', tone: 'ok' as const },
    ],
  },
  {
    id: 'bond',
    n: '03',
    label: 'Bond',
    title: 'Or lock in for more',
    body: 'Bond means locking money in. The first bond is also what switches a brand-new DETF on. You may receive more of the DETF token over time. Amounts are not guaranteed.',
    youDo: 'Lock money in a bond',
    basketDoes: 'Goes live on the first bond. Later bonds add protocol-owned depth.',
    example: [
      { left: 'Bond', right: 'Locked', tone: 'mint' as const },
      { left: 'DETF', right: 'Live', tone: 'ok' as const },
      { left: 'Extra token over time', right: 'Not a promise', tone: 'ok' as const },
    ],
  },
] as const

export function LandingWalkthrough() {
  const [active, setActive] = useState<(typeof STEPS)[number]['id']>('mint')
  const step = STEPS.find((s) => s.id === active) ?? STEPS[0]

  return (
    <div className="dtf-landing__walk">
      <div className="dtf-landing__tabs" role="tablist" aria-label="Mint, hold, or bond">
        {STEPS.map((s) => (
          <button
            key={s.id}
            type="button"
            role="tab"
            aria-selected={s.id === active}
            className={s.id === active ? 'dtf-landing__tab is-active' : 'dtf-landing__tab'}
            onClick={() => setActive(s.id)}
          >
            <span className="dtf-landing__tab-n">{s.n}</span> {s.label}
          </button>
        ))}
      </div>

      <div className="dtf-landing__walk-grid">
        <div>
          <h3 className="dtf-landing__walk-title">{step.title}</h3>
          <p className="dtf-landing__walk-body">{step.body}</p>
          <div className="dtf-landing__do-row">
            <div className="dtf-landing__do">
              <p className="dtf-landing__kicker">You do</p>
              <p>{step.youDo}</p>
            </div>
            <div className="dtf-landing__do">
              <p className="dtf-landing__kicker">Basket does</p>
              <p>{step.basketDoes}</p>
            </div>
          </div>
        </div>

        <div className="dtf-landing__example" aria-label="Illustrative example basket">
          <div className="dtf-landing__example-head">
            <span>Example basket</span>
            <span className="dtf-landing__example-tag">{step.label}</span>
          </div>
          <ul>
            {step.example.map((row) => (
              <li key={row.left}>
                <span>
                  <i className={row.tone === 'mint' ? 'dot-mint' : 'dot-purple'} aria-hidden />
                  {row.left}
                </span>
                <strong>{row.right}</strong>
              </li>
            ))}
          </ul>
          <p className="dtf-landing__example-note">
            Illustrative only. No figures here represent past or expected performance.
          </p>
        </div>
      </div>
    </div>
  )
}
