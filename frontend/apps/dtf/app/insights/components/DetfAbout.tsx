import type { DetfProfile } from '../lib/detfProfiles'

export function DetfAbout({
  profile,
  protocolFee,
}: {
  profile: DetfProfile | undefined
  protocolFee: boolean
}) {
  if (!profile) {
    return (
      <section data-testid="insights-about">
        <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">About</p>
        <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          This listing has no write-up yet. A DETF is a Decentralized ETF: one token over a basket
          that works in other apps. Live fields below are reads from the contract when the RPC can
          see it.
        </p>
      </section>
    )
  }

  return (
    <section data-testid="insights-about">
      <p className="text-[11px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">
        {protocolFee ? 'Protocol DETF' : profile.kicker}
      </p>
      <p className="mt-2 text-sm leading-relaxed text-[var(--text-primary,#EDEDED)]">{profile.blurb}</p>
      <dl className="mt-4 grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
        <div>
          <dt className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Shape</dt>
          <dd className="mt-0.5 text-[var(--text-primary,#EDEDED)]">{profile.shape}</dd>
        </div>
        <div>
          <dt className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Mint and burn</dt>
          <dd className="mt-0.5 text-[var(--text-primary,#EDEDED)]">
            {profile.mintBurn === 'open' ? 'Open' : 'Policy'}
          </dd>
        </div>
        {profile.firstBonded ? (
          <div className="sm:col-span-2">
            <dt className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">First bond</dt>
            <dd className="mt-0.5 text-[var(--text-primary,#EDEDED)]">{profile.openedHow}</dd>
          </div>
        ) : null}
      </dl>
    </section>
  )
}
