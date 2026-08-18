import Link from 'next/link'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { CREATE_DETF_TYPES, type CreateDetfTypeId } from './detfTypes'

import '../landing.css'

export function CreateTypePlaceholder({ typeId }: { typeId: CreateDetfTypeId }) {
  const type = CREATE_DETF_TYPES.find((t) => t.id === typeId)
  if (!type) return null

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <div className="landing-lab__content space-y-10">
        <section>
          <Link
            href="/create"
            className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
          >
            Create
          </Link>
          <p className="landing-lab__eyebrow mt-5">{type.kicker}</p>
          <h1 className="landing-lab__h1 mt-4">{type.title}</h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            {type.blurb} You get a bond you cannot cash out. Bond later to turn the DETF on.
          </p>
        </section>

        <Card className="max-w-2xl">
          <p className="landing-section-label">Not wired yet</p>
          <h2 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
            Create form coming next
          </h2>
          <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            This page is the home for this DETF type. The deploy steps will land here. They are
            being built separately. We will not invent a form that cannot deploy.
          </p>
          <div className="mt-5 flex flex-wrap gap-3">
            <Link href="/create">
              <Button>Back to types</Button>
            </Link>
            <Link href="/learn">
              <Button variant="secondary">How DETFs work</Button>
            </Link>
            <Link href="/explore">
              <Button variant="ghost">Use one already live</Button>
            </Link>
          </div>
        </Card>
      </div>
    </div>
  )
}
