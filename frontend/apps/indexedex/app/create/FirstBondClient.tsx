'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'
import { erc20Abi, formatUnits, parseUnits, type Address } from 'viem'
import { useAccount, useConnect, usePublicClient, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { rememberCreatedDetf } from '../lib/detf/createdDetfs'
import { parseContractError } from '../lib/tx/parseContractError'
import { DETF_BOND_ABI } from './lib/detfAbi'
import { loadStoredPlan } from './lib/createPlan'

import '../landing.css'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

const THIRTY_DAYS = 30 * 24 * 60 * 60

export function FirstBondClient() {
  const searchParams = useSearchParams()
  const raw = searchParams.get('detf') ?? ''
  const detf = /^0x[0-9a-fA-F]{40}$/.test(raw) ? (raw as Address) : null
  const { selectedChainId } = useSelectedNetwork()
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const { connect, connectors } = useConnect()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient({ chainId: selectedChainId })
  const [amount, setAmount] = useState('')
  const [lockDays, setLockDays] = useState('30')
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState<'approve' | 'bond' | null>(null)

  useEffect(() => {
    if (!detf) return
    const plan = loadStoredPlan()
    rememberCreatedDetf({
      chainId: selectedChainId,
      address: detf,
      name: plan?.name.trim() || 'DETF',
      symbol: plan?.symbol.trim() || 'DETF',
      decimals: 18,
    })
  }, [detf, selectedChainId])

  const { data: pairToken } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'pairToken',
    chainId: selectedChainId,
    query: { enabled: !!detf },
  })
  const { data: live } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'isReserveLive',
    chainId: selectedChainId,
    query: { enabled: !!detf },
  })
  const { data: symbol } = useReadContract({
    address: pairToken,
    abi: erc20Abi,
    functionName: 'symbol',
    chainId: selectedChainId,
    query: { enabled: !!pairToken },
  })
  const { data: decimals } = useReadContract({
    address: pairToken,
    abi: erc20Abi,
    functionName: 'decimals',
    chainId: selectedChainId,
    query: { enabled: !!pairToken },
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: pairToken,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf ? [address, detf] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!pairToken && !!address && !!detf },
  })
  const { data: balance } = useReadContract({
    address: pairToken,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!pairToken && !!address },
  })

  const dec = typeof decimals === 'number' ? decimals : 18
  const parsed = useMemo(() => {
    const t = amount.trim()
    if (!t) return null
    try {
      return parseUnits(t, dec)
    } catch {
      return null
    }
  }, [amount, dec])
  const lockSeconds = BigInt(Math.max(1, Math.floor(Number(lockDays) || 30)) * 24 * 60 * 60 || THIRTY_DAYS)
  const needsApprove = parsed != null && (allowance == null || allowance < parsed)
  const pairLabel = symbol ?? 'pair token'

  const writeOnAppNetwork = async (params: Parameters<typeof writeContractAsync>[0]) => {
    const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
    if (typeof walletChainId === 'number' && walletChainId !== selectedChainId && !localWallet) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = params as typeof params & { chainId?: number; chain?: unknown }
    return writeContractAsync(rest)
  }

  const connectWallet = () => {
    const connector =
      connectors.find((c) => c.id === 'metaMask' || c.id === 'metaMaskSDK') ??
      connectors.find((c) => c.id === 'injected') ??
      connectors[0]
    if (connector) connect({ connector })
  }

  const approve = async () => {
    if (!pairToken || !detf || parsed == null) return
    setStatus(null)
    setPending('approve')
    try {
      const hash = await writeOnAppNetwork({
        address: pairToken,
        abi: erc20Abi,
        functionName: 'approve',
        args: [detf, parsed],
      })
      await publicClient?.waitForTransactionReceipt({ hash })
      await refetchAllowance()
      setStatus('Approved. Bond next.')
    } catch (err) {
      setStatus(parseContractError(err))
    } finally {
      setPending(null)
    }
  }

  const bond = async () => {
    if (!detf || !pairToken || !address || parsed == null) return
    setStatus(null)
    setPending('bond')
    try {
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)
      const hash = await writeOnAppNetwork({
        address: detf,
        abi: DETF_BOND_ABI,
        functionName: 'bond',
        args: [pairToken, parsed, lockSeconds, address, false, deadline],
      })
      await publicClient?.waitForTransactionReceipt({ hash })
      setStatus('Bonded. The DETF is live.')
    } catch (err) {
      setStatus(parseContractError(err))
    } finally {
      setPending(null)
    }
  }

  if (!detf) {
    return (
      <div className="landing-lab">
        <div className="landing-lab__content space-y-4">
          <p className="landing-lab__eyebrow">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1">Missing DETF address.</h1>
          <Link href="/create/one-vault">
            <Button>Back to create</Button>
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="landing-lab">
      <div className="landing-lab__atmosphere" aria-hidden="true">
        <div className="landing-lab__grid" />
        <div className="landing-lab__glow" />
      </div>
      <div className="landing-lab__content space-y-8">
        <section>
          <p className="landing-lab__eyebrow">DETF means Decentralized ETF</p>
          <h1 className="landing-lab__h1 mt-4">
            Bond to turn it <span className="landing-lab__h1-accent">on.</span>
          </h1>
          <p className="mt-5 max-w-2xl text-base leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            The DETF stays off until someone bonds. This first bond uses the pair token and issues a bond NFT you
            cannot cash out.
          </p>
          <p className="mt-2 font-mono text-xs text-[var(--text-muted,#9aa3b2)]">{detf}</p>
          {live ? (
            <p className="mt-2 text-sm text-[var(--accent,#4FD44B)]">Reserve is live.</p>
          ) : null}
        </section>

        <Card>
          <p className="landing-section-label">First bond</p>
          <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
            {pairLabel} amount
            <input
              className={inputClass}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              inputMode="decimal"
              data-testid="first-bond-amount"
            />
          </label>
          {balance != null ? (
            <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Balance {formatUnits(balance, dec)} {pairLabel}
            </p>
          ) : null}
          <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
            Lock (days)
            <input
              className={inputClass}
              value={lockDays}
              onChange={(e) => setLockDays(e.target.value)}
              inputMode="numeric"
            />
          </label>
          <div className="mt-5 flex flex-wrap gap-3">
            {!isConnected ? (
              <Button type="button" onClick={connectWallet}>
                Connect wallet
              </Button>
            ) : needsApprove ? (
              <Button
                type="button"
                onClick={() => void approve()}
                disabled={parsed == null || pending != null}
                loading={pending === 'approve'}
                data-testid="first-bond-approve"
              >
                Approve {pairLabel}
              </Button>
            ) : (
              <Button
                type="button"
                onClick={() => void bond()}
                disabled={parsed == null || pending != null}
                loading={pending === 'bond'}
                data-testid="first-bond-cta"
              >
                Bond to turn it on
              </Button>
            )}
          </div>
          {status ? <p className="mt-3 text-sm text-[var(--text-primary,#EDEDED)]">{status}</p> : null}
        </Card>

        <div className="flex flex-wrap gap-3">
          <Link href={`/you?detf=${detf}`}>
            <Button variant="secondary">View bond</Button>
          </Link>
          <Link href={`/staking?detf=${detf}`}>
            <Button variant="secondary">Open full DETF page</Button>
          </Link>
          <Link href="/create/one-vault">
            <Button variant="ghost">Create another</Button>
          </Link>
        </div>
      </div>
    </div>
  )
}
