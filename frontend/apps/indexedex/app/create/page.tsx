import Link from 'next/link'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { CREATE_DETF_TYPES } from './detfTypes'

import '../landing.css'

export const metadata = {
  title: 'Create a DETF — IndexedEx',
  description: 'Pick a basket shape, then create your DETF.',
}

export default function CreatePickerPage() {
  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <div className="landing-lab__content space-y-12">
        <section>
          <p className="landing-lab__eyebrow">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1 mt-4">
            Pick the
            <br />
            <span className="landing-lab__h1-accent">basket shape.</span>
          </h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            Make a DETF. One token. One basket. The basket works in other apps. You get a bond you
            cannot cash out. Bond later to turn it on.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/learn">
              <Button size="lg" variant="secondary">
                How DETFs work
              </Button>
            </Link>
            <Link href="/explore">
              <Button size="lg" variant="ghost">
                Use one already live
              </Button>
            </Link>
          </div>
        </section>

        <section>
          <p className="landing-section-label">The four types</p>
          <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
            Match the type to the basket.
          </h2>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {CREATE_DETF_TYPES.map((t, i) => (
              <Link key={t.id} href={t.href} className="group block h-full">
                {i === 0 ? (
                  <div className="landing-feature-hero h-full rounded-xl p-6">
                    <p className="landing-section-label">{t.kicker}</p>
                    <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                      {t.title}
                    </h3>
                    <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                      {t.blurb}
                    </p>
                    <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">Open this type →</p>
                  </div>
                ) : (
                  <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
                    <p className="landing-section-label">{t.kicker}</p>
                    <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                      {t.title}
                    </h3>
                    <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                      {t.blurb}
                    </p>
                    <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">Open this type →</p>
                  </Card>
                )}
              </Link>
            ))}
          </div>
        </section>

        <p className="pb-4 text-xs text-[var(--text-muted,#9aa3b2)]">
          Create forms for each type are still being wired. The shape you pick is the one that will
          deploy.
        </p>
      </div>
    </div>
  )
}
