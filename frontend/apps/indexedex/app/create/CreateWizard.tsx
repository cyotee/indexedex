'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { usePathname, useRouter, useSearchParams } from 'next/navigation'

import { getBaseTokensForChain, getStrategyVaultTokensForChain, type TokenListEntry } from '@indexedex/protocol/tokenlists'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { EmptyState } from '../components/ui/EmptyState'
import { CREATE_DETF_TYPES, type CreateDetfTypeId } from './detfTypes'
import {
  applyType,
  bondSymbolFrom,
  burnPriceFromBand,
  canLeaveStep,
  claimSymbolFrom,
  CREATE_STEP_LABEL,
  CREATE_STEPS,
  emptyPlan,
  evenWeightPercents,
  loadStoredPlan,
  maxVaults,
  minVaults,
  mintPriceFromBand,
  nextStep,
  parseStep,
  planReady,
  prevStep,
  saveStoredPlan,
  serializePlan,
  type CreatePlan,
  type CreateStepId,
  typeMeta,
  weightTotal,
} from './lib/createPlan'

import '../landing.css'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)] placeholder:text-[var(--text-muted,#9aa3b2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent,#4FD44B)]'

const STEP_TITLE: Record<CreateStepId, { lead: string; accent: string }> = {
  shape: { lead: 'Pick the', accent: 'basket shape.' },
  name: { lead: 'Name the', accent: 'DETF token.' },
  gates: { lead: 'Set mint', accent: 'and burn.' },
  basket: { lead: 'Fill the', accent: 'basket.' },
  review: { lead: 'Review the', accent: 'plan.' },
}

const STEP_LEDE: Record<CreateStepId, string> = {
  shape: 'Make a DETF. One token. One basket. The basket works in other apps. You get a bond you cannot cash out. Bond later to turn it on.',
  name: 'People hold this token. A claim token is issued if a bond is sold after it matures. The creator bond cannot be cashed out.',
  gates: 'Policy pauses mint and burn when the synthetic price is inside a band around 1. Open never does. Fees can still apply.',
  basket: 'Pick listed vault shares on this network. Those are the working positions behind the token.',
  review: 'Check the shape, names, mint and burn, and basket. Creating issues a bond you cannot cash out. Amounts are not guaranteed.',
}

function shortAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function isClaim(t: TokenListEntry): boolean {
  return (t.tags ?? []).some((tag) => tag.toLowerCase() === 'claim')
}

function findToken(list: TokenListEntry[], addr: string): TokenListEntry | undefined {
  const key = addr.toLowerCase()
  return list.find((t) => t.address.toLowerCase() === key)
}

function hrefForType(typeId: CreateDetfTypeId | '', step: CreateStepId): string {
  if (!typeId) return step === 'shape' ? '/create' : `/create?step=${step}`
  return `/create/${typeId}?step=${step}`
}

export function CreateWizard({ initialTypeId }: { initialTypeId?: CreateDetfTypeId }) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const [plan, setPlan] = useState<CreatePlan>(() => {
    const base = emptyPlan()
    return initialTypeId ? applyType(base, initialTypeId) : base
  })
  const [step, setStep] = useState<CreateStepId>(() => (initialTypeId ? 'name' : 'shape'))
  const [error, setError] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
  const [hydrated, setHydrated] = useState(false)

  const vaults = useMemo(
    () => getStrategyVaultTokensForChain(selectedChainId, environment).filter((t) => !isClaim(t)),
    [selectedChainId, environment],
  )
  const tokens = useMemo(
    () => getBaseTokensForChain(selectedChainId, environment).filter((t) => !isClaim(t)),
    [selectedChainId, environment],
  )

  useEffect(() => {
    const stored = loadStoredPlan()
    const qStep = parseStep(searchParams.get('step'))
    setPlan((prev) => {
      let next = stored ? { ...emptyPlan(), ...stored } : prev
      if (initialTypeId) next = applyType(next, initialTypeId)
      return next
    })
    if (searchParams.get('step')) setStep(qStep)
    else setStep(initialTypeId ? 'name' : 'shape')
    setHydrated(true)
    // URL + type on first paint only. Later step changes write the URL themselves.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!hydrated) return
    saveStoredPlan(plan)
  }, [plan, hydrated])

  const go = useCallback(
    (next: CreateStepId, nextPlan = plan) => {
      setError(null)
      setStep(next)
      const href = hrefForType(nextPlan.typeId, next)
      const pathOnly = href.split('?')[0] ?? href
      if (pathOnly !== pathname) router.push(href, { scroll: false })
      else router.replace(href, { scroll: false })
    },
    [plan, pathname, router],
  )

  const pickType = (typeId: CreateDetfTypeId) => {
    const next = applyType(plan, typeId)
    setPlan(next)
    saveStoredPlan(next)
    go('name', next)
  }

  const continueNext = () => {
    const blocked = canLeaveStep(step, plan)
    if (blocked) {
      setError(blocked)
      return
    }
    const nxt = nextStep(step)
    if (nxt) go(nxt)
  }

  const back = () => {
    const prev = prevStep(step)
    if (!prev) return
    if (prev === 'shape') {
      setError(null)
      setStep('shape')
      router.replace('/create?step=shape', { scroll: false })
      return
    }
    go(prev)
  }

  const jumpTo = (target: CreateStepId) => {
    const from = CREATE_STEPS.indexOf(step)
    const to = CREATE_STEPS.indexOf(target)
    if (to <= from) {
      if (target === 'shape') {
        setError(null)
        setStep('shape')
        router.replace('/create?step=shape', { scroll: false })
        return
      }
      go(target)
      return
    }
    for (let i = 0; i < to; i++) {
      const id = CREATE_STEPS[i]!
      const blocked = canLeaveStep(id, plan)
      if (blocked) {
        setError(blocked)
        setStep(id)
        router.replace(hrefForType(plan.typeId, id), { scroll: false })
        return
      }
    }
    go(target)
  }

  const copyPlan = async () => {
    try {
      await navigator.clipboard.writeText(serializePlan(plan))
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      setError('Could not copy. Select the plan text instead.')
    }
  }

  const type = typeMeta(plan.typeId)
  const ready = planReady(plan)

  return (
    <div className="landing-lab" data-testid="create-wizard">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
        <div className="landing-lab__glow landing-lab__glow--secondary" />
      </div>

      <div className="landing-lab__content space-y-8">
        <section>
          <p className="landing-lab__eyebrow">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1 mt-4">
            {STEP_TITLE[step].lead}{' '}
            <br />
            <span className="landing-lab__h1-accent">{STEP_TITLE[step].accent}</span>
          </h1>
          <p className="mt-5 max-w-2xl text-base md:text-lg leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            {STEP_LEDE[step]}
          </p>
          {type && step !== 'shape' ? (
            <p className="mt-3 text-sm text-[var(--accent,#4FD44B)]">
              {type.kicker}: {type.title}
            </p>
          ) : null}
        </section>

        <Stepper step={step} onJump={jumpTo} />

        <form
          data-testid={`create-step-${step}`}
          onSubmit={(e) => {
            e.preventDefault()
            if (step !== 'review') continueNext()
          }}
        >
          {step === 'shape' ? <StepShape plan={plan} onPick={pickType} /> : null}
          {step === 'name' ? <StepName plan={plan} setPlan={setPlan} /> : null}
          {step === 'gates' ? <StepGates plan={plan} setPlan={setPlan} /> : null}
          {step === 'basket' ? (
            <StepBasket plan={plan} setPlan={setPlan} vaults={vaults} tokens={tokens} />
          ) : null}
          {step === 'review' ? (
            <StepReview
              plan={plan}
              vaults={vaults}
              tokens={tokens}
              copied={copied}
              ready={ready}
              onCopy={copyPlan}
            />
          ) : null}

          {error ? (
            <p className="mt-4 text-sm text-[var(--danger,#E6386A)]" role="alert" data-testid="create-error">
              {error}
            </p>
          ) : null}

          <div className="mt-8 flex flex-wrap items-center gap-3">
            {step !== 'shape' ? (
              <Button type="button" variant="secondary" onClick={back} data-testid="create-back">
                Back
              </Button>
            ) : null}
            {step !== 'review' ? (
              <Button type="submit" data-testid="create-next">
                {step === 'shape' ? 'Continue' : `Continue to ${CREATE_STEP_LABEL[nextStep(step)!]}`}
              </Button>
            ) : null}
            <Link href="/learn">
              <Button type="button" variant="ghost">
                How DETFs work
              </Button>
            </Link>
            {step === 'shape' ? (
              <Link href="/explore">
                <Button type="button" variant="ghost">
                  Use one already live
                </Button>
              </Link>
            ) : null}
          </div>
        </form>
      </div>
    </div>
  )
}

function Stepper({ step, onJump }: { step: CreateStepId; onJump: (s: CreateStepId) => void }) {
  const current = CREATE_STEPS.indexOf(step)
  return (
    <ol className="flex flex-wrap gap-2" aria-label="Create steps">
      {CREATE_STEPS.map((id, i) => {
        const active = id === step
        const done = i < current
        return (
          <li key={id}>
            <button
              type="button"
              onClick={() => onJump(id)}
              aria-current={active ? 'step' : undefined}
              className={[
                'rounded-full border px-3 py-1 text-xs tracking-wide',
                active
                  ? 'border-[var(--accent,#4FD44B)] bg-[color-mix(in_srgb,var(--accent,#4FD44B)_12%,transparent)] text-[var(--text-primary,#EDEDED)]'
                  : done
                    ? 'border-[var(--border-accent,rgba(79,212,75,0.45))] text-[var(--text-primary,#EDEDED)]'
                    : 'border-[var(--border-subtle,rgba(255,255,255,0.08))] text-[var(--text-muted,#9aa3b2)]',
              ].join(' ')}
            >
              <span className="font-mono">{String(i + 1).padStart(2, '0')}</span>{' '}
              {CREATE_STEP_LABEL[id]}
            </button>
          </li>
        )
      })}
    </ol>
  )
}

function StepShape({
  plan,
  onPick,
}: {
  plan: CreatePlan
  onPick: (id: CreateDetfTypeId) => void
}) {
  return (
    <section>
      <p className="landing-section-label">The four types</p>
      <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
        Match the type to the basket.
      </h2>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {CREATE_DETF_TYPES.map((t, i) => {
          const selected = plan.typeId === t.id
          const inner = (
            <>
              <p className="landing-section-label">{t.kicker}</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">{t.title}</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">{t.blurb}</p>
              <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">
                {selected ? 'Selected' : 'Use this type'}
              </p>
            </>
          )
          return (
            <button
              key={t.id}
              type="button"
              onClick={() => onPick(t.id)}
              data-testid={`create-type-${t.id}`}
              className="group h-full text-left"
            >
              {i === 0 || selected ? (
                <div className="landing-feature-hero h-full rounded-xl p-6">{inner}</div>
              ) : (
                <Card className="h-full transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]">
                  {inner}
                </Card>
              )}
            </button>
          )
        })}
      </div>
    </section>
  )
}

function StepName({ plan, setPlan }: { plan: CreatePlan; setPlan: (p: CreatePlan) => void }) {
  const claim = claimSymbolFrom(plan.symbol)
  const bond = bondSymbolFrom(plan.symbol)
  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,1fr)_18rem]">
      <Card>
        <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
          Name
          <input
            className={inputClass}
            value={plan.name}
            onChange={(e) => setPlan({ ...plan, name: e.target.value })}
            maxLength={40}
            autoComplete="off"
            data-testid="create-name"
            placeholder="Double Dollar"
          />
        </label>
        <p className="mt-1 text-[11px] text-[var(--text-muted,#9aa3b2)]">2–40 characters. This is the DETF token name.</p>
        <label className="mt-5 block text-sm text-[var(--text-primary,#EDEDED)]">
          Symbol
          <input
            className={`${inputClass} font-mono uppercase`}
            value={plan.symbol}
            onChange={(e) => setPlan({ ...plan, symbol: e.target.value })}
            maxLength={12}
            autoComplete="off"
            data-testid="create-symbol"
            placeholder="$$DETF"
          />
        </label>
        <p className="mt-1 text-[11px] text-[var(--text-muted,#9aa3b2)]">
          2–12 letters, numbers, $, or a hyphen. Example: $$DETF.
        </p>
      </Card>
      <Card>
        <p className="landing-section-label">Also created</p>
        <dl className="mt-4 space-y-3 text-sm">
          <div>
            <dt className="text-[var(--text-muted,#9aa3b2)]">Claim token</dt>
            <dd className="font-mono text-[var(--text-primary,#EDEDED)]">{claim || '—'}</dd>
          </div>
          <div>
            <dt className="text-[var(--text-muted,#9aa3b2)]">Creator bond</dt>
            <dd className="font-mono text-[var(--text-primary,#EDEDED)]">{bond || '—'}</dd>
          </div>
        </dl>
        <p className="mt-4 text-xs leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          The bond can collect a cut of new DETF minted to bond holders. You cannot cash the bond out.
        </p>
      </Card>
    </div>
  )
}

function StepGates({ plan, setPlan }: { plan: CreatePlan; setPlan: (p: CreatePlan) => void }) {
  const mintLine = mintPriceFromBand(plan.mintBandPct)
  const burnLine = burnPriceFromBand(plan.burnBandPct)
  return (
    <div className="space-y-5">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <button
          type="button"
          onClick={() => setPlan({ ...plan, mode: 'policy' })}
          data-testid="create-mode-policy"
          className="text-left"
        >
          {plan.mode === 'policy' ? (
            <div className="landing-feature-hero h-full rounded-xl p-6">
              <p className="landing-section-label">Default</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Policy</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Mint is allowed when the synthetic price is above the mint line. Burn is allowed when it is
                below the burn line.
              </p>
            </div>
          ) : (
            <Card className="h-full">
              <p className="landing-section-label">Restricted</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Policy</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Mint and burn wait on the synthetic price.
              </p>
            </Card>
          )}
        </button>
        <button
          type="button"
          onClick={() => setPlan({ ...plan, mode: 'open' })}
          data-testid="create-mode-open"
          className="text-left"
        >
          {plan.mode === 'open' ? (
            <div className="landing-feature-hero h-full rounded-xl p-6">
              <p className="landing-section-label">No price gate</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Open</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                No price restrictions on primary mint and burn. Fees can still apply. This does not promise a
                stable price.
              </p>
            </div>
          ) : (
            <Card className="h-full">
              <p className="landing-section-label">No price gate</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Open</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Mint and burn with no price restrictions.
              </p>
            </Card>
          )}
        </button>
      </div>

      {plan.mode === 'policy' ? (
        <Card>
          <p className="landing-section-label">Band around 1.0</p>
          <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
            <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
              Mint band (%)
              <input
                className={`${inputClass} font-mono`}
                inputMode="decimal"
                value={plan.mintBandPct}
                onChange={(e) => setPlan({ ...plan, mintBandPct: e.target.value })}
                data-testid="create-mint-band"
              />
            </label>
            <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
              Burn band (%)
              <input
                className={`${inputClass} font-mono`}
                inputMode="decimal"
                value={plan.burnBandPct}
                onChange={(e) => setPlan({ ...plan, burnBandPct: e.target.value })}
                data-testid="create-burn-band"
              />
            </label>
          </div>
          <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
            {mintLine && burnLine
              ? `Mint above ${mintLine}. Burn below ${burnLine}. Typical start is 5% each.`
              : 'Enter 0–50 for each band.'}
          </p>
        </Card>
      ) : (
        <Card>
          <p className="text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            Open does not collapse a deadband. Mint and burn are allowed regardless of synthetic price. Fees
            can still apply.
          </p>
        </Card>
      )}
    </div>
  )
}

function StepBasket({
  plan,
  setPlan,
  vaults,
  tokens,
}: {
  plan: CreatePlan
  setPlan: (p: CreatePlan) => void
  vaults: TokenListEntry[]
  tokens: TokenListEntry[]
}) {
  const [query, setQuery] = useState('')
  const typeId = plan.typeId
  const min = minVaults(typeId)
  const max = maxVaults(typeId)
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return vaults
    return vaults.filter(
      (v) =>
        v.symbol.toLowerCase().includes(q) ||
        v.name.toLowerCase().includes(q) ||
        v.address.toLowerCase().includes(q),
    )
  }, [vaults, query])

  const toggle = (addr: `0x${string}`) => {
    const selected = plan.vaults.includes(addr)
    if (typeId === 'one-vault') {
      setPlan({ ...plan, vaults: [addr] })
      return
    }
    if (selected) {
      const vaultsNext = plan.vaults.filter((v) => v !== addr)
      setPlan({
        ...plan,
        vaults: vaultsNext,
        weights: typeId === 'weighted' ? evenWeightPercents(vaultsNext.length) : plan.weights,
      })
      return
    }
    if (plan.vaults.length >= max) return
    const vaultsNext = [...plan.vaults, addr]
    setPlan({
      ...plan,
      vaults: vaultsNext,
      weights: typeId === 'weighted' ? evenWeightPercents(vaultsNext.length) : plan.weights,
    })
  }

  const setWeight = (index: number, value: string) => {
    const weights = plan.weights.slice()
    while (weights.length < plan.vaults.length) weights.push('0')
    weights[index] = value
    setPlan({ ...plan, weights })
  }

  if (vaults.length === 0) {
    return (
      <EmptyState
        title="No vault shares listed on this network"
        body="Switch to a network that has strategy vaults, or use a DETF already live."
        action={
          <div className="flex flex-wrap justify-center gap-2">
            <Link href="/earn">
              <Button>Browse vaults</Button>
            </Link>
            <Link href="/explore">
              <Button variant="secondary">Use one already live</Button>
            </Link>
          </div>
        }
      />
    )
  }

  return (
    <div className="space-y-5">
      <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
        {typeId === 'one-vault'
          ? 'Pick one vault share. Then pick the pair token this DETF will mint against.'
          : `Pick ${min}–${max} vault shares. ${typeId === 'weighted' ? 'Weights must add to 100%.' : ''}`}
      </p>
      <input
        className={inputClass}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search vaults"
        data-testid="create-vault-search"
        aria-label="Search vaults"
      />
      <ul className="space-y-2" data-testid="create-vault-list">
        {filtered.map((v) => {
          const on = plan.vaults.includes(v.address)
          const idx = plan.vaults.indexOf(v.address)
          return (
            <li key={v.address}>
              <div
                className={[
                  'flex flex-wrap items-center gap-3 rounded-xl border px-4 py-3',
                  on
                    ? 'border-[var(--border-accent,rgba(79,212,75,0.45))] bg-[color-mix(in_srgb,var(--accent,#4FD44B)_8%,transparent)]'
                    : 'border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)]',
                ].join(' ')}
              >
                <button
                  type="button"
                  onClick={() => toggle(v.address)}
                  className="min-w-0 flex-1 text-left"
                  data-testid={`create-vault-${v.symbol}`}
                >
                  <span className="block font-medium text-[var(--text-primary,#EDEDED)]">{v.symbol}</span>
                  <span className="block truncate text-[11px] text-[var(--text-muted,#9aa3b2)]">
                    {v.name} · {shortAddr(v.address)}
                  </span>
                </button>
                {on && typeId === 'weighted' && idx >= 0 ? (
                  <label className="flex items-center gap-2 text-xs text-[var(--text-muted,#9aa3b2)]">
                    Weight %
                    <input
                      className="w-20 rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-2 py-1 font-mono text-sm text-[var(--text-primary,#EDEDED)]"
                      value={plan.weights[idx] ?? ''}
                      onChange={(e) => setWeight(idx, e.target.value)}
                      inputMode="decimal"
                      aria-label={`Weight for ${v.symbol}`}
                    />
                  </label>
                ) : null}
              </div>
            </li>
          )
        })}
      </ul>
      {filtered.length === 0 ? (
        <p className="text-sm text-[var(--text-muted,#9aa3b2)]">No vaults match that search.</p>
      ) : null}
      {typeId === 'weighted' && plan.vaults.length > 0 ? (
        <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
          Weights total {weightTotal(plan.weights.slice(0, plan.vaults.length))}%. Need 100%.
        </p>
      ) : null}

      {typeId === 'one-vault' ? (
        <TokenPick
          label="Pair token"
          help="The other token in the reserve market. Mint and bond settle against the rate asset; this is the pair."
          value={plan.pairToken}
          tokens={tokens}
          testId="create-pair-token"
          onChange={(pairToken) => setPlan({ ...plan, pairToken })}
        />
      ) : null}
      {typeId === 'cash-buffer' ? (
        <TokenPick
          label="Cash token"
          help="Burns return this cash token. Vaults in the basket should take and give the same cash."
          value={plan.cashToken}
          tokens={tokens}
          testId="create-cash-token"
          onChange={(cashToken) => setPlan({ ...plan, cashToken })}
        />
      ) : null}
    </div>
  )
}

function TokenPick({
  label,
  help,
  value,
  tokens,
  onChange,
  testId,
}: {
  label: string
  help: string
  value: string
  tokens: TokenListEntry[]
  onChange: (addr: `0x${string}` | '') => void
  testId: string
}) {
  return (
    <Card>
      <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
        {label}
        <select
          className={inputClass}
          value={value}
          onChange={(e) => onChange((e.target.value as `0x${string}`) || '')}
          data-testid={testId}
        >
          <option value="">Select a token</option>
          {tokens.map((t) => (
            <option key={t.address} value={t.address}>
              {t.symbol} · {t.name}
            </option>
          ))}
        </select>
      </label>
      <p className="mt-2 text-xs leading-relaxed text-[var(--text-muted,#9aa3b2)]">{help}</p>
    </Card>
  )
}

function StepReview({
  plan,
  vaults,
  tokens,
  copied,
  ready,
  onCopy,
}: {
  plan: CreatePlan
  vaults: TokenListEntry[]
  tokens: TokenListEntry[]
  copied: boolean
  ready: boolean
  onCopy: () => void
}) {
  const type = typeMeta(plan.typeId)
  const mintLine = mintPriceFromBand(plan.mintBandPct)
  const burnLine = burnPriceFromBand(plan.burnBandPct)
  return (
    <div className="space-y-5">
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <p className="landing-section-label">Token</p>
          <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
            {plan.symbol.trim() || '—'}
          </h3>
          <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">{plan.name.trim() || '—'}</p>
          <dl className="mt-4 space-y-2 text-sm">
            <Row k="Shape" v={type ? type.title : '—'} />
            <Row k="Claim token" v={claimSymbolFrom(plan.symbol) || '—'} />
            <Row k="Creator bond" v={bondSymbolFrom(plan.symbol) || '—'} />
          </dl>
        </Card>
        <Card>
          <p className="landing-section-label">Mint and burn</p>
          <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
            {plan.mode === 'open' ? 'Open' : 'Policy'}
          </h3>
          <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            {plan.mode === 'open'
              ? 'No price restrictions on primary mint and burn. Fees can still apply.'
              : `Mint above ${mintLine || '—'}. Burn below ${burnLine || '—'}.`}
          </p>
        </Card>
      </div>

      <Card>
        <p className="landing-section-label">Basket</p>
        <ul className="mt-3 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]">
          {plan.vaults.map((addr, i) => {
            const v = findToken(vaults, addr)
            const w = plan.typeId === 'weighted' ? plan.weights[i] : null
            return (
              <li key={addr} className="flex flex-wrap items-center justify-between gap-2 py-3 text-sm">
                <div>
                  <div className="text-[var(--text-primary,#EDEDED)]">{v?.symbol ?? shortAddr(addr)}</div>
                  <div className="text-[11px] text-[var(--text-muted,#9aa3b2)]">{v?.name ?? addr}</div>
                </div>
                {w != null ? <span className="font-mono text-[var(--text-muted,#9aa3b2)]">{w}%</span> : null}
              </li>
            )
          })}
        </ul>
        {plan.typeId === 'one-vault' ? (
          <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
            Pair token: {findToken(tokens, plan.pairToken)?.symbol ?? plan.pairToken || '—'}
          </p>
        ) : null}
        {plan.typeId === 'cash-buffer' ? (
          <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
            Cash token: {findToken(tokens, plan.cashToken)?.symbol ?? plan.cashToken || '—'}
          </p>
        ) : null}
      </Card>

      <div className="landing-lab__panel p-6">
        <p className="landing-section-label">Creator bond</p>
        <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          Creating a DETF issues a bond to you that you cannot cash out. It can collect a cut of DETF minted
          to bond holders. On Policy it can also collect from regular supply expansion. Amounts are not
          guaranteed. The DETF stays off until someone bonds.
        </p>
      </div>

      <Card>
        <p className="landing-section-label">On-chain create</p>
        <h3 className="mt-2 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Not wired in this wizard yet</h3>
        <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          A DETF deploys through a package registered on this network. Uniswap v4 DETFs also need a mined
          hook nonce. This page will not pretend to send that transaction. Copy the plan, or use a DETF
          already live.
        </p>
        <div className="mt-5 flex flex-wrap gap-3">
          <Button type="button" onClick={onCopy} disabled={!ready} data-testid="create-copy-plan">
            {copied ? 'Copied' : 'Copy plan'}
          </Button>
          <Link href="/explore">
            <Button type="button" variant="secondary">
              Use one already live
            </Button>
          </Link>
          <Link href="/insights">
            <Button type="button" variant="ghost">
              See live DETFs
            </Button>
          </Link>
        </div>
      </Card>
    </div>
  )
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <dt className="text-[var(--text-muted,#9aa3b2)]">{k}</dt>
      <dd className="font-mono text-[var(--text-primary,#EDEDED)]">{v}</dd>
    </div>
  )
}
