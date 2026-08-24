'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { usePathname, useRouter, useSearchParams } from 'next/navigation'
import type { Address } from 'viem'
import { useReadContracts } from 'wagmi'

import { getBaseTokensForChain, getStrategyVaultTokensForChain, type TokenListEntry } from '@indexedex/protocol/tokenlists'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import {
  CREATE_DETF_TYPES,
  CREATE_SE_HOSTS,
  isComingSoonCreateType,
  isOfferedCreateType,
  seHostMeta,
  seHostNameTag,
  seHostSymbolTag,
  type CreateDetfTypeId,
  type CreateSeHostId,
} from './detfTypes'
import { DetfDeployPanel } from './DetfDeployPanel'
import { SeVaultSlot } from './SeVaultSlot'
import {
  applyType,
  bondNameFrom,
  bondSymbolFrom,
  burnPriceFromBand,
  canLeaveStep,
  claimNameFrom,
  claimSymbolFrom,
  concatDetfName,
  concatDetfSymbol,
  concatWeightedDetfName,
  concatWeightedDetfSymbol,
  CREATE_STEP_LABEL,
  emptyPlan,
  stepsFor,
  evenWeightedSplit,
  loadStoredPlan,
  maxVaults,
  minVaults,
  mintPriceFromBand,
  nextStep,
  parseStep,
  planReady,
  prevStep,
  saveStoredPlan,
  resolvedBondName,
  resolvedBondSymbol,
  resolvedClaimName,
  resolvedClaimSymbol,
  serializePlan,
  type CreatePlan,
  type CreateStepId,
  typeMeta,
  weightedWeightTotal,
  weightsSumToHundred,
  withPriceLegs,
} from './lib/createPlan'
import { ERC20_META_ABI, VAULT_TOKENS_ABI } from './lib/seAbi'

import '../landing.css'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)] placeholder:text-[var(--text-muted,#9aa3b2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent,#4FD44B)]'

const STEP_TITLE: Record<CreateStepId, { lead: string; accent: string }> = {
  shape: { lead: 'How many', accent: 'strategies?' },
  venue: { lead: 'Where does', accent: 'this strategy work?' },
  name: { lead: 'Name the', accent: 'DETF token.' },
  basket: { lead: 'Fill the', accent: 'basket.' },
  gates: { lead: 'Set mint', accent: 'and burn.' },
  review: { lead: 'Review the', accent: 'plan.' },
}

const STEP_LEDE: Record<CreateStepId, string> = {
  shape:
    'A strategy is one working position in another app. Pick one, several, or a small set of stablecoins. That choice picks the rest of the steps.',
  venue: 'Pick a Uniswap V3 pool, a Uniswap V4 pool, or a Morpho market. The strategy vault sits on the one you pick.',
  name: 'Names start from the tokens in the SE vault. You can edit them. Blank bond or claim fields use the default.',
  basket:
    'Pick listed SE vaults, or build one from the market you chose. Create the pool if it is missing. Deploy the vault if that market has none.',
  gates: 'Set the peg price, the opening price, and whether mint and burn use Policy or Open.',
  review: 'Check the mix, basket, names, peg price, opening price, mint and burn.',
}

function firstStepAfterShape(typeId: CreateDetfTypeId | ''): CreateStepId {
  return typeId === 'one-vault' ? 'venue' : 'basket'
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
  const [step, setStep] = useState<CreateStepId>(() => {
    if (searchParams.get('step')) return parseStep(searchParams.get('step'))
    return initialTypeId ? firstStepAfterShape(initialTypeId) : 'shape'
  })
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
      const offered = initialTypeId && isOfferedCreateType(initialTypeId) ? initialTypeId : null
      if (offered) next = applyType(next, offered)
      else if (next.typeId && isComingSoonCreateType(next.typeId)) next = applyType(next, '')
      else if (next.typeId && !isOfferedCreateType(next.typeId)) next = applyType(next, 'one-vault')
      return next
    })
    if (searchParams.get('step')) setStep(qStep)
    else setStep(initialTypeId ? firstStepAfterShape(initialTypeId) : 'shape')
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
    if (isComingSoonCreateType(typeId)) return
    const next = applyType(plan, typeId)
    setPlan(next)
    saveStoredPlan(next)
    setError(null)
  }

  const continueNext = () => {
    const blocked = canLeaveStep(step, plan)
    if (blocked) {
      setError(blocked)
      return
    }
    const nxt = nextStep(step, plan)
    if (nxt) go(nxt)
  }

  const back = () => {
    const prev = prevStep(step, plan)
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
    const steps = stepsFor(plan)
    const from = steps.indexOf(step)
    const to = steps.indexOf(target)
    if (to < 0) return
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
      const id = steps[i]!
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

  const pickHost = (seHost: CreateSeHostId) => {
    const next = { ...plan, seHost }
    setPlan(next)
    saveStoredPlan(next)
    setError(null)
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
            {step === 'name' && plan.typeId === 'weighted'
              ? 'Names start from the tokens in the basket, the strategies you picked, and the weights. DETF token first, then each strategy. You can edit them.'
              : step === 'basket' && plan.typeId === 'weighted'
                ? 'Pick listed SE vaults, or build one per strategy. The reserve also holds the DETF token. Give that token a weight too.'
                : STEP_LEDE[step]}
          </p>
          {type && step !== 'shape' ? (
            <p className="mt-3 text-sm text-[var(--accent,#4FD44B)]">
              {type.title}
              {plan.seHost && step !== 'venue' ? ` · ${seHostMeta(plan.seHost)?.title}` : ''}
            </p>
          ) : null}
        </section>

        <Stepper steps={stepsFor(plan)} step={step} onJump={jumpTo} />

        <form
          data-testid={`create-step-${step}`}
          onSubmit={(e) => {
            e.preventDefault()
            if (step !== 'review') continueNext()
          }}
        >
          {step === 'shape' ? <StepShape plan={plan} onPick={pickType} /> : null}
          {step === 'venue' ? <StepVenue plan={plan} onPick={pickHost} /> : null}
          {step === 'name' ? <StepName plan={plan} setPlan={setPlan} tokens={tokens} /> : null}
          {step === 'basket' ? (
            <StepBasket plan={plan} setPlan={setPlan} vaults={vaults} tokens={tokens} />
          ) : null}
          {step === 'gates' ? (
            <StepGates plan={plan} setPlan={setPlan} vaults={vaults} tokens={tokens} />
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
              <Button
                type="submit"
                data-testid="create-next"
                disabled={
                  (step === 'shape' && (!plan.typeId || isComingSoonCreateType(plan.typeId))) ||
                  (step === 'venue' && !plan.seHost)
                }
              >
                {step === 'shape' || step === 'venue'
                  ? 'Continue'
                  : `Continue to ${CREATE_STEP_LABEL[nextStep(step, plan)!]}`}
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

function Stepper({
  steps,
  step,
  onJump,
}: {
  steps: CreateStepId[]
  step: CreateStepId
  onJump: (s: CreateStepId) => void
}) {
  const current = steps.indexOf(step)
  return (
    <ol className="flex flex-wrap gap-2" aria-label="Create steps">
      {steps.map((id, i) => {
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
      <p className="landing-section-label">Include</p>
      <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
        What goes in the basket.
      </h2>
      <div className="grid max-w-5xl grid-cols-1 gap-4 md:grid-cols-3">
        {CREATE_DETF_TYPES.map((t) => {
          const soon = !!t.comingSoon
          const selected = !soon && plan.typeId === t.id
          const inner = (
            <>
              <p className="landing-section-label">{t.kicker}</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">{t.title}</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">{t.blurb}</p>
              {!soon ? (
                <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">
                  {selected ? 'Selected' : 'Include this'}
                </p>
              ) : null}
            </>
          )
          return (
            <div key={t.id} className="relative h-full">
              <button
                type="button"
                onClick={() => onPick(t.id)}
                disabled={soon}
                data-testid={`create-type-${t.id}`}
                aria-pressed={selected}
                aria-disabled={soon || undefined}
                className={[
                  'group h-full w-full text-left',
                  soon ? 'cursor-not-allowed' : '',
                ].join(' ')}
              >
                {selected ? (
                  <div className="landing-feature-hero h-full rounded-xl p-6">{inner}</div>
                ) : (
                  <Card
                    className={[
                      'h-full',
                      soon
                        ? 'opacity-40 grayscale'
                        : 'transition-colors group-hover:border-[var(--border-accent,rgba(79,212,75,0.45))]',
                    ].join(' ')}
                  >
                    {inner}
                  </Card>
                )}
              </button>
              {soon ? (
                <div
                  className="pointer-events-none absolute inset-0 flex items-center justify-center"
                  data-testid={`create-type-${t.id}-soon`}
                >
                  <span className="rounded-md bg-[var(--surface-0,#0a0a0a)]/85 px-3 py-1.5 text-sm font-semibold tracking-wide text-[var(--text-primary,#EDEDED)]">
                    Coming Soon
                  </span>
                </div>
              ) : null}
            </div>
          )
        })}
      </div>
    </section>
  )
}

function StepVenue({
  plan,
  onPick,
}: {
  plan: CreatePlan
  onPick: (id: CreateSeHostId) => void
}) {
  return (
    <section>
      <p className="landing-section-label">Market</p>
      <h2 className="mt-2 mb-5 text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)]">
        Uniswap or Morpho.
      </h2>
      <div className="grid max-w-5xl grid-cols-1 gap-4 md:grid-cols-3">
        {CREATE_SE_HOSTS.map((h) => {
          const selected = plan.seHost === h.id
          const inner = (
            <>
              <p className="landing-section-label">{h.kicker}</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">{h.title}</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">{h.blurb}</p>
              <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]">
                {selected ? 'Selected' : 'Use this'}
              </p>
            </>
          )
          return (
            <button
              key={h.id}
              type="button"
              onClick={() => onPick(h.id)}
              data-testid={`create-host-${h.id}`}
              aria-pressed={selected}
              className="group h-full text-left"
            >
              {selected ? (
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

function StepName({
  plan,
  setPlan,
  tokens,
}: {
  plan: CreatePlan
  setPlan: (p: CreatePlan) => void
  tokens: TokenListEntry[]
}) {
  const { selectedChainId } = useSelectedNetwork()
  const weighted = plan.typeId === 'weighted'
  const vaults = plan.vaults
  const vaultKey = vaults.join(',').toLowerCase()
  const hostKey = weighted ? plan.seHosts.slice(0, vaults.length).join(',') : plan.seHost
  const weightKey = weighted
    ? [plan.detfWeight, ...plan.weights.slice(0, vaults.length)].join(',')
    : ''
  const lastApplied = useRef({ vault: '', host: '', weight: '', name: '', symbol: '' })

  const { data: vaultTokenResults } = useReadContracts({
    contracts: vaults.map((address) => ({
      address,
      abi: VAULT_TOKENS_ABI,
      functionName: 'vaultTokens' as const,
      chainId: selectedChainId,
    })),
    query: { enabled: vaults.length > 0 },
  })

  const addrs = useMemo(() => {
    const out: Address[] = []
    const seen = new Set<string>()
    for (const r of vaultTokenResults ?? []) {
      if (r.status !== 'success' || !r.result) continue
      for (const a of r.result as Address[]) {
        if (!a) continue
        const k = a.toLowerCase()
        if (seen.has(k)) continue
        seen.add(k)
        out.push(a)
      }
    }
    return out
  }, [vaultTokenResults])

  const { data: onchainMeta } = useReadContracts({
    contracts: addrs.flatMap((address) => [
      { address, abi: ERC20_META_ABI, functionName: 'name' as const, chainId: selectedChainId },
      { address, abi: ERC20_META_ABI, functionName: 'symbol' as const, chainId: selectedChainId },
    ]),
    query: { enabled: addrs.length > 0 },
  })

  const suggested = useMemo(() => {
    const rows = addrs.map((address, i) => {
      const known = findToken(tokens, address)
      const nameResult = onchainMeta?.[i * 2]
      const symbolResult = onchainMeta?.[i * 2 + 1]
      const onchainName = nameResult?.status === 'success' ? String(nameResult.result) : ''
      const onchainSymbol = symbolResult?.status === 'success' ? String(symbolResult.result) : ''
      return {
        name: known?.name || onchainName,
        symbol: known?.symbol || onchainSymbol,
      }
    })
    if (weighted) {
      const input = {
        tokens: rows,
        strategySymbols: plan.seHosts.slice(0, plan.vaults.length).map((h) => seHostSymbolTag(h)),
        detfWeightPct: plan.detfWeight,
        pairWeightPcts: plan.weights.slice(0, plan.vaults.length),
      }
      return {
        name: concatWeightedDetfName(input),
        symbol: concatWeightedDetfSymbol(input),
      }
    }
    const hint = {
      strategyName: seHostNameTag(plan.seHost),
      strategySymbol: seHostSymbolTag(plan.seHost),
    }
    return {
      name: concatDetfName(rows, hint),
      symbol: concatDetfSymbol(rows, hint),
    }
  }, [
    addrs,
    onchainMeta,
    tokens,
    weighted,
    plan.seHost,
    plan.seHosts,
    plan.vaults.length,
    plan.detfWeight,
    plan.weights,
  ])

  useEffect(() => {
    if (vaults.length === 0 || (!suggested.name && !suggested.symbol)) return
    if (weighted && addrs.length === 0) return
    const vaultChanged = lastApplied.current.vault !== vaultKey
    const hostChanged = lastApplied.current.host !== hostKey
    const weightChanged = lastApplied.current.weight !== weightKey
    const nameUnlocked = !plan.name.trim() || plan.name === lastApplied.current.name
    const symbolUnlocked = !plan.symbol.trim() || plan.symbol === lastApplied.current.symbol
    if (!vaultChanged && !hostChanged && !weightChanged && !nameUnlocked && !symbolUnlocked) return
    const nextName =
      vaultChanged || hostChanged || weightChanged || nameUnlocked ? suggested.name : plan.name
    const nextSymbol =
      vaultChanged || hostChanged || weightChanged || symbolUnlocked ? suggested.symbol : plan.symbol
    lastApplied.current = {
      vault: vaultKey,
      host: hostKey,
      weight: weightKey,
      name: suggested.name,
      symbol: suggested.symbol,
    }
    if (nextName === plan.name && nextSymbol === plan.symbol) return
    setPlan({ ...plan, name: nextName, symbol: nextSymbol })
  }, [
    plan,
    setPlan,
    suggested.name,
    suggested.symbol,
    vaultKey,
    hostKey,
    weightKey,
    vaults.length,
    weighted,
    addrs.length,
  ])

  return (
    <div className="space-y-5">
      <Card>
        <p className="landing-section-label">DETF token</p>
        <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          {weighted
            ? 'Defaults use the tokens in each vault, the strategy on each slot (V3, V4, or Morpho Blue), and the weights with the DETF token first. Edit if you want a different DETF name.'
            : 'Defaults use the vault tokens plus the strategy you picked (Uniswap V3, Uniswap V4, or Morpho Blue). Edit if you want a different DETF name.'}
        </p>
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Name
            <input
              className={inputClass}
              value={plan.name}
              onChange={(e) => setPlan({ ...plan, name: e.target.value })}
              maxLength={40}
              autoComplete="off"
              data-testid="create-name"
              placeholder={suggested.name || 'Double Dollar DETF'}
            />
          </label>
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Symbol
            <input
              className={`${inputClass} font-mono uppercase`}
              value={plan.symbol}
              onChange={(e) => setPlan({ ...plan, symbol: e.target.value })}
              maxLength={20}
              autoComplete="off"
              data-testid="create-symbol"
              placeholder={suggested.symbol || '$$-DETF'}
            />
          </label>
        </div>
        <p className="mt-2 text-[11px] text-[var(--text-muted,#9aa3b2)]">
          Name 2–40 characters. Symbol 2–20 letters, numbers, $, or a hyphen. Those caps are from
          this form so names stay short in wallets.
          {weighted
            ? ' Defaults add strategies, DETF-first weights, and DETF.'
            : ' Defaults add the strategy and DETF.'}
        </p>
      </Card>

      <Card>
        <p className="landing-section-label">Bond NFT</p>
        <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          The creator bond. Blank uses the DETF name plus Bond, and the DETF symbol plus -BOND.
        </p>
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Bond name
            <input
              className={inputClass}
              value={plan.bondName}
              onChange={(e) => setPlan({ ...plan, bondName: e.target.value })}
              maxLength={40}
              autoComplete="off"
              data-testid="create-bond-name"
              placeholder={bondNameFrom(plan.name) || 'Double Dollar Bond'}
            />
          </label>
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Bond symbol
            <input
              className={`${inputClass} font-mono`}
              value={plan.bondSymbol}
              onChange={(e) => setPlan({ ...plan, bondSymbol: e.target.value })}
              maxLength={20}
              autoComplete="off"
              data-testid="create-bond-symbol"
              placeholder={bondSymbolFrom(plan.symbol) || '$$DETF-BOND'}
            />
          </label>
        </div>
      </Card>

      <Card>
        <p className="landing-section-label">Claim token</p>
        <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          The rebasing claim token. Blank uses the DETF name plus Claim, and the DETF symbol plus IR.
        </p>
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Claim name
            <input
              className={inputClass}
              value={plan.claimName}
              onChange={(e) => setPlan({ ...plan, claimName: e.target.value })}
              maxLength={40}
              autoComplete="off"
              data-testid="create-claim-name"
              placeholder={claimNameFrom(plan.name) || 'Double Dollar Claim'}
            />
          </label>
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Claim symbol
            <input
              className={`${inputClass} font-mono`}
              value={plan.claimSymbol}
              onChange={(e) => setPlan({ ...plan, claimSymbol: e.target.value })}
              maxLength={20}
              autoComplete="off"
              data-testid="create-claim-symbol"
              placeholder={claimSymbolFrom(plan.symbol) || '$$DETFIR'}
            />
          </label>
        </div>
      </Card>
    </div>
  )
}

function StepGates({
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
  const priced = withPriceLegs(plan)
  const mintLine = mintPriceFromBand(plan.mintBandPct)
  const burnLine = burnPriceFromBand(plan.burnBandPct)
  const pairLabel =
    plan.typeId === 'one-vault'
      ? findToken(tokens, plan.pairToken)?.symbol || 'pair token'
      : 'pair token'

  const setCreation = (index: number, value: string) => {
    const next = priced.creationPairPerDetf.slice()
    next[index] = value
    setPlan({ ...priced, creationPairPerDetf: next })
  }
  const setOpening = (index: number, value: string) => {
    const next = priced.openingPairPerDetf.slice()
    next[index] = value
    setPlan({ ...priced, openingPairPerDetf: next })
  }

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <button
          type="button"
          onClick={() => setPlan({ ...priced, mode: 'policy' })}
          data-testid="create-mode-policy"
          className="text-left"
        >
          {plan.mode === 'policy' ? (
            <div className="landing-feature-hero h-full rounded-xl p-6">
              <p className="landing-section-label">Default</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Policy</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Mint when the price index is above the mint line. Burn when it is below the burn line.
                Those lines sit around 1, not around the pair count.
              </p>
            </div>
          ) : (
            <Card className="h-full">
              <p className="landing-section-label">Restricted</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Policy</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Mint and burn wait on the price index.
              </p>
            </Card>
          )}
        </button>
        <button
          type="button"
          onClick={() => setPlan({ ...priced, mode: 'open' })}
          data-testid="create-mode-open"
          className="text-left"
        >
          {plan.mode === 'open' ? (
            <div className="landing-feature-hero h-full rounded-xl p-6">
              <p className="landing-section-label">No price gate</p>
              <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">Open</h3>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                No price restrictions on primary mint and burn. Fees can still apply.
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

      <Card>
        <p className="landing-section-label">Mint and burn</p>
        <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
          Peg price is pair tokens per DETF when the price index is 1. Opening price is pair tokens
          per DETF on the first bond. Blank opening uses the peg.
        </p>
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          {priced.creationPairPerDetf.map((value, i) => {
            const vault = findToken(vaults, plan.vaults[i] ?? '')
            const pegLabel =
              priced.creationPairPerDetf.length === 1
                ? `Peg price (${pairLabel} per DETF)`
                : `Peg price · ${vault?.symbol ?? `leg ${i + 1}`}`
            const openLabel =
              priced.openingPairPerDetf.length === 1
                ? 'Opening price (blank = peg)'
                : `Opening price · ${vault?.symbol ?? `leg ${i + 1}`}`
            return (
              <div key={`price-${i}`} className="contents">
                <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                  {pegLabel}
                  <input
                    className={`${inputClass} font-mono`}
                    inputMode="decimal"
                    value={value}
                    onChange={(e) => setCreation(i, e.target.value)}
                    data-testid={i === 0 ? 'create-peg' : `create-peg-${i}`}
                  />
                </label>
                <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                  {openLabel}
                  <input
                    className={`${inputClass} font-mono`}
                    inputMode="decimal"
                    value={priced.openingPairPerDetf[i] ?? ''}
                    onChange={(e) => setOpening(i, e.target.value)}
                    placeholder={value || '1'}
                    data-testid={i === 0 ? 'create-opening' : `create-opening-${i}`}
                  />
                </label>
              </div>
            )
          })}
        </div>
        {plan.mode === 'policy' ? (
          <>
            <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                Mint line (% above 1)
                <input
                  className={`${inputClass} font-mono`}
                  inputMode="decimal"
                  value={plan.mintBandPct}
                  onChange={(e) => setPlan({ ...priced, mintBandPct: e.target.value })}
                  data-testid="create-mint-band"
                />
              </label>
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                Burn line (% below 1)
                <input
                  className={`${inputClass} font-mono`}
                  inputMode="decimal"
                  value={plan.burnBandPct}
                  onChange={(e) => setPlan({ ...priced, burnBandPct: e.target.value })}
                  data-testid="create-burn-band"
                />
              </label>
            </div>
            <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
              {mintLine && burnLine
                ? `Mint above ${mintLine}. Burn below ${burnLine}. Default is 5% each.`
                : 'Enter 0–50 for each line.'}
            </p>
          </>
        ) : (
          <p className="mt-4 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            Open never pauses mint or burn for the price index. Peg price still sets pair tokens per
            DETF at 1.
          </p>
        )}
      </Card>
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
  const typeId = plan.typeId
  const min = minVaults(typeId)
  const max = maxVaults(typeId)
  const [openSlots, setOpenSlots] = useState(() =>
    Math.max(min, plan.vaults.length || (typeId === 'one-vault' ? 1 : min)),
  )

  useEffect(() => {
    setOpenSlots((n) => Math.max(n, min, plan.vaults.length, typeId === 'one-vault' ? 1 : 0))
  }, [min, plan.vaults.length, typeId])

  const slotCount = typeId === 'one-vault' ? 1 : Math.min(max, Math.max(openSlots, min, plan.vaults.length))

  const setVaultAt = (index: number, vault: `0x${string}` | '') => {
    if (typeId === 'one-vault') {
      const sameVault =
        !!vault && !!plan.vaults[0] && vault.toLowerCase() === plan.vaults[0].toLowerCase()
      setPlan(
        withPriceLegs({
          ...plan,
          vaults: vault ? [vault] : [],
          pairToken: sameVault ? plan.pairToken : '',
        }),
      )
      return
    }
    const next = plan.vaults.slice()
    const nextHosts = plan.seHosts.slice()
    const nextPairs = plan.pairTokens.slice()
    if (!vault) {
      if (index < next.length) {
        next.splice(index, 1)
        if (index < nextHosts.length) nextHosts.splice(index, 1)
        if (index < nextPairs.length) nextPairs.splice(index, 1)
      }
    } else if (index < next.length) {
      const changed = next[index]?.toLowerCase() !== vault.toLowerCase()
      next[index] = vault
      if (changed) {
        while (nextPairs.length < next.length) nextPairs.push('')
        nextPairs[index] = ''
      }
    } else {
      next.push(vault)
      while (nextHosts.length < next.length) nextHosts.push('')
      while (nextPairs.length < next.length) nextPairs.push('')
    }
    const split =
      typeId === 'weighted' && next.length !== plan.vaults.length
        ? evenWeightedSplit(next.length)
        : null
    setPlan(
      withPriceLegs({
        ...plan,
        vaults: next,
        seHosts: nextHosts.slice(0, next.length),
        pairTokens: nextPairs.slice(0, next.length),
        ...(split
          ? { detfWeight: split.detfWeight, weights: split.weights }
          : { weights: plan.weights }),
      }),
    )
  }

  const setWeight = (index: number, value: string) => {
    const weights = plan.weights.slice()
    while (weights.length < plan.vaults.length) weights.push('0')
    weights[index] = value
    setPlan({ ...plan, weights })
  }

  const setHostAt = (index: number, host: CreateSeHostId | '') => {
    const nextHosts = plan.seHosts.slice()
    while (nextHosts.length < Math.max(index + 1, plan.vaults.length)) nextHosts.push('')
    nextHosts[index] = host
    setPlan({ ...plan, seHosts: nextHosts })
  }

  const setPairAt = (index: number, pair: `0x${string}` | '') => {
    const nextPairs = plan.pairTokens.slice()
    while (nextPairs.length < Math.max(index + 1, plan.vaults.length)) nextPairs.push('')
    nextPairs[index] = pair
    setPlan({ ...plan, pairTokens: nextPairs })
  }

  const weightSum = weightedWeightTotal(plan)
  const weightsOk = weightsSumToHundred(weightSum)

  return (
    <div className="space-y-5">
      <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
        {typeId === 'one-vault' && plan.seHost === 'morpho'
          ? 'Pick a lending token and a collateral token. If that Morpho market is not on this network yet, create it, then deploy the strategy vault.'
          : typeId === 'one-vault'
          ? 'Pick a listed SE vault or build one from the pool type you chose. Then pick the pair token from that vault.'
          : typeId === 'stables'
            ? `Pick ${min}–${max} dollar vaults. Each one can be listed or built from a pool.`
            : typeId === 'weighted'
              ? `Pick ${min}–${max} strategy vaults. The reserve also holds the DETF token, so it needs a weight too. DETF plus strategies must add to 100%. Each at least 1%.`
              : `Pick ${min}–${max} strategy vaults. Each vault can be listed or built from a pool.`}
      </p>

      {typeId === 'weighted' ? (
        <>
          <div data-testid="create-weight-total">
            <p className="text-sm text-[var(--text-primary,#EDEDED)]">
              Weights total {weightSum}%
            </p>
            {weightsOk ? null : (
              <p
                className="mt-1 text-sm text-[var(--danger,#E6386A)]"
                role="alert"
                data-testid="create-weight-warning"
              >
                Weights must add to 100%.
              </p>
            )}
          </div>
          <Card>
            <p className="landing-section-label">DETF token</p>
            <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
              The weighted reserve holds the DETF token plus each strategy pair. Set how much of
              the reserve is the DETF token. If 100% does not split evenly, the leftover goes here.
            </p>
            <label className="mt-4 flex items-center gap-2 text-sm text-[var(--text-primary,#EDEDED)]">
              Weight %
              <input
                className="w-20 rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-2 py-1 font-mono text-sm"
                value={plan.detfWeight}
                onChange={(e) => setPlan({ ...plan, detfWeight: e.target.value })}
                inputMode="decimal"
                data-testid="create-detf-weight"
              />
            </label>
          </Card>
        </>
      ) : null}

      {Array.from({ length: slotCount }, (_, i) => (
        <Card key={`slot-${i}`}>
          {slotCount > 1 ? (
            <p className="landing-section-label">
              {typeId === 'stables' ? `Stablecoin ${i + 1}` : `Strategy ${i + 1}`}
            </p>
          ) : null}
          <div className={slotCount > 1 ? 'mt-4' : undefined}>
            <SeVaultSlot
              listedVaults={
                typeId === 'one-vault' && plan.seHost && plan.seHost !== 'uniswap-v4' ? [] : vaults
              }
              tokens={tokens}
              seHost={typeId === 'one-vault' ? plan.seHost : (plan.seHosts[i] ?? '')}
              hostPerSlot={typeId === 'weighted'}
              selectedVault={plan.vaults[i] ?? ''}
              pairToken={
                typeId === 'one-vault' && i === 0
                  ? plan.pairToken
                  : typeId === 'weighted'
                    ? (plan.pairTokens[i] ?? '')
                    : ''
              }
              persistPair={(typeId === 'one-vault' && i === 0) || typeId === 'weighted'}
              weight={plan.weights[i]}
              showWeight={typeId === 'weighted'}
              onSelectVault={(vault) => setVaultAt(i, vault)}
              onSelectPair={(pairToken) => {
                if (typeId === 'one-vault' && i === 0) setPlan({ ...plan, pairToken })
                if (typeId === 'weighted') setPairAt(i, pairToken)
              }}
              onSelectHost={typeId === 'weighted' ? (host) => setHostAt(i, host) : undefined}
              onWeight={typeId === 'weighted' ? (value) => setWeight(i, value) : undefined}
              testIdPrefix={`create-slot-${i}`}
            />
          </div>
        </Card>
      ))}

      {typeId !== 'one-vault' && slotCount < max ? (
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => setOpenSlots((n) => Math.min(max, n + 1))}
          data-testid="create-add-vault-slot"
        >
          {typeId === 'stables' ? 'Add another stablecoin' : 'Add another strategy'}
        </Button>
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
  const priced = withPriceLegs(plan)
  const openingDisplay = priced.openingPairPerDetf
    .map((v, i) => v.trim() || priced.creationPairPerDetf[i] || 'peg')
    .join(' / ')
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
            <Row k="Include" v={type ? type.title : '—'} />
            {plan.typeId === 'one-vault' ? (
              <Row k="Market" v={seHostMeta(plan.seHost)?.title ?? '—'} />
            ) : null}
            <Row k="Claim token" v={`${resolvedClaimName(plan) || '—'} · ${resolvedClaimSymbol(plan) || '—'}`} />
            <Row k="Bond NFT" v={`${resolvedBondName(plan) || '—'} · ${resolvedBondSymbol(plan) || '—'}`} />
          </dl>
        </Card>
        <Card>
          <p className="landing-section-label">Mint and burn</p>
          <h3 className="mt-2 text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
            {plan.mode === 'open' ? 'Open' : 'Policy'}
          </h3>
          <dl className="mt-4 space-y-2 text-sm">
            <Row k="Peg price" v={priced.creationPairPerDetf.join(' / ') || '—'} />
            <Row k="Opening price" v={openingDisplay || 'peg'} />
            <Row
              k="Mint / burn"
              v={
                plan.mode === 'open'
                  ? 'No price restrictions'
                  : `Mint above ${mintLine || '—'}. Burn below ${burnLine || '—'}.`
              }
            />
          </dl>
        </Card>
      </div>

      <Card>
        <p className="landing-section-label">Basket</p>
        <ul className="mt-3 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]">
          {plan.typeId === 'weighted' ? (
            <li className="flex flex-wrap items-center justify-between gap-2 py-3 text-sm">
              <div>
                <div className="text-[var(--text-primary,#EDEDED)]">DETF token</div>
                <div className="text-[11px] text-[var(--text-muted,#9aa3b2)]">DETF token in the reserve</div>
              </div>
              <span className="font-mono text-[var(--text-muted,#9aa3b2)]">{plan.detfWeight || '0'}%</span>
            </li>
          ) : null}
          {plan.vaults.map((addr, i) => {
            const v = findToken(vaults, addr)
            const w = plan.typeId === 'weighted' ? plan.weights[i] : null
            const host = plan.typeId === 'weighted' ? seHostMeta(plan.seHosts[i] ?? '')?.title : null
            const pair = plan.typeId === 'weighted' ? plan.pairTokens[i] : null
            const pairMeta = pair ? findToken(tokens, pair) : null
            return (
              <li key={addr} className="flex flex-wrap items-center justify-between gap-2 py-3 text-sm">
                <div>
                  <div className="text-[var(--text-primary,#EDEDED)]">{v?.symbol ?? shortAddr(addr)}</div>
                  <div className="text-[11px] text-[var(--text-muted,#9aa3b2)]">
                    {host ? `${host} · ` : ''}
                    {pairMeta?.symbol ? `Pair ${pairMeta.symbol} · ` : pair ? `Pair ${shortAddr(pair)} · ` : ''}
                    {v?.name ?? addr}
                  </div>
                </div>
                {w != null ? <span className="font-mono text-[var(--text-muted,#9aa3b2)]">{w}%</span> : null}
              </li>
            )
          })}
        </ul>
        {plan.typeId === 'one-vault' ? (
          <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
            Pair token: {findToken(tokens, plan.pairToken)?.symbol ?? (plan.pairToken || '—')}
          </p>
        ) : null}
        {plan.typeId === 'cash-buffer' ? (
          <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
            Cash token: {findToken(tokens, plan.cashToken)?.symbol ?? (plan.cashToken || '—')}
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

      <DetfDeployPanel plan={plan} ready={ready} />
      <div className="flex flex-wrap gap-3">
        <Button type="button" onClick={onCopy} disabled={!ready} data-testid="create-copy-plan">
          {copied ? 'Copied' : 'Copy plan'}
        </Button>
        <Link href="/explore">
          <Button type="button" variant="secondary">
            Use one already live
          </Button>
        </Link>
      </div>
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
