'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { erc20Abi, formatUnits, parseUnits, type Address } from 'viem'
import {
  useAccount,
  useConnect,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import { getBaseTokensForChain, getStrategyVaultTokensForChain } from '@indexedex/protocol/tokenlists'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { rememberCreatedDetf } from '../lib/detf/createdDetfs'
import { parseContractError } from '../lib/tx/parseContractError'
import {
  asBondLockTerms,
  clampLockDays,
  lockRangeFromBondTerms,
  lockSecondsFromDays,
} from './lib/bondLock'
import {
  defaultFirstBondToken,
  firstBondTokenAddresses,
  firstBondTokenOptionLabel,
  isNonZeroAddress,
  resolveVaultShare,
  sameAddress,
} from './lib/bondTokens'
import { loadStoredPlan } from './lib/createPlan'
import { DETF_BOND_ABI, FEE_ORACLE_BOND_ABI, WEIGHTED_BOND_ABI, WEIGHTED_DETF_INFO_ABI } from './lib/detfAbi'
import { VAULT_TOKENS_ABI } from './lib/seAbi'
import { resolveSePlatform } from './lib/sePlatform'

import '../landing.css'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

function shortBondAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function FirstBondClient() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const raw = searchParams.get('detf') ?? ''
  const detf = /^0x[0-9a-fA-F]{40}$/.test(raw) ? (raw as Address) : null
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const { connect, connectors } = useConnect()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient({ chainId: selectedChainId })
  const platform = useMemo(
    () => resolveSePlatform(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const [amount, setAmount] = useState('')
  const [tokenIn, setTokenIn] = useState<`0x${string}` | ''>('')
  const [legAmounts, setLegAmounts] = useState<Record<string, string>>({})
  const [capitalToken, setCapitalToken] = useState<`0x${string}` | ''>('')
  const [lockDays, setLockDays] = useState('30')
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState<'approve' | 'bond' | null>(null)
  const didInitLock = useRef(false)
  const didPickToken = useRef(false)

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

  const listedTokens = useMemo(
    () => [
      ...getBaseTokensForChain(selectedChainId, environment),
      ...getStrategyVaultTokensForChain(selectedChainId, environment),
    ],
    [selectedChainId, environment],
  )
  const [isWeighted, setIsWeighted] = useState(false)
  useEffect(() => {
    if (!detf || !publicClient) {
      setIsWeighted(false)
      return
    }
    let cancelled = false
    void publicClient
      .readContract({
        address: detf,
        abi: WEIGHTED_DETF_INFO_ABI,
        functionName: 'm',
      })
      .then((m) => {
        if (!cancelled) setIsWeighted(Number(m) >= 1)
      })
      .catch(() => {
        if (!cancelled) setIsWeighted(false)
      })
    return () => {
      cancelled = true
    }
  }, [detf, publicClient])

  const { data: weightedPairs } = useReadContract({
    address: detf ?? undefined,
    abi: WEIGHTED_DETF_INFO_ABI,
    functionName: 'pairTokens',
    chainId: selectedChainId,
    query: { enabled: !!detf && isWeighted },
  })
  const weightedPairList = useMemo(
    () => ((weightedPairs as Address[] | undefined) ?? []).filter(isNonZeroAddress),
    [weightedPairs],
  )
  const weightedReady = isWeighted && weightedPairList.length > 0

  const { data: pairToken } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'pairToken',
    chainId: selectedChainId,
    query: { enabled: !!detf && !weightedReady },
  })
  const { data: seVault } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'standardExchangeVault',
    chainId: selectedChainId,
    query: { enabled: !!detf && !weightedReady },
  })
  const { data: vaultShareRaw } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'standardExchangeVaultShare',
    chainId: selectedChainId,
    query: { enabled: !!detf && !weightedReady },
  })
  const { data: live } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'isReserveLive',
    chainId: selectedChainId,
    query: { enabled: !!detf },
  })
  const { data: seVaultTokens, isFetched: seTokensFetched } = useReadContract({
    address: isNonZeroAddress(seVault) ? seVault : undefined,
    abi: VAULT_TOKENS_ABI,
    functionName: 'vaultTokens',
    chainId: selectedChainId,
    query: { enabled: isNonZeroAddress(seVault) },
  })

  const vaultShare = resolveVaultShare(seVault, vaultShareRaw)
  const bondTokens = useMemo(() => {
    if (weightedReady) return weightedPairList
    const listed = firstBondTokenAddresses({
      seVault,
      vaultShare: vaultShareRaw,
      seVaultTokens,
      detf,
    })
    if (listed.length > 0) return listed
    return isNonZeroAddress(pairToken) ? [pairToken] : []
  }, [weightedReady, weightedPairList, seVault, vaultShareRaw, seVaultTokens, detf, pairToken])

  const seTokensKnown = !isNonZeroAddress(seVault) || seTokensFetched

  useEffect(() => {
    if (!seTokensKnown) return
    if (bondTokens.length === 0) return
    const stillValid = tokenIn && bondTokens.some((t) => sameAddress(t, tokenIn))
    if (didPickToken.current && stillValid) return
    const next = defaultFirstBondToken(bondTokens, pairToken)
    if (!next) return
    if (tokenIn && sameAddress(tokenIn, next)) return
    setTokenIn(next)
  }, [seTokensKnown, bondTokens, pairToken, tokenIn])

  const { data: tokenMeta } = useReadContracts({
    contracts: bondTokens.flatMap((address) => [
      { address, abi: erc20Abi, functionName: 'symbol' as const, chainId: selectedChainId },
      { address, abi: erc20Abi, functionName: 'decimals' as const, chainId: selectedChainId },
    ]),
    query: { enabled: bondTokens.length > 0 },
  })

  const tokenOptions = useMemo(
    () =>
      bondTokens.map((address, i) => {
        const known = listedTokens.find((t) => sameAddress(t.address, address))
        const symbolResult = tokenMeta?.[i * 2]
        const decimalsResult = tokenMeta?.[i * 2 + 1]
        const onchainSymbol =
          symbolResult?.status === 'success' ? String(symbolResult.result) : undefined
        const decimals =
          decimalsResult?.status === 'success' ? Number(decimalsResult.result) : 18
        return {
          address,
          symbol: known?.symbol || onchainSymbol,
          decimals: Number.isFinite(decimals) ? decimals : 18,
        }
      }),
    [bondTokens, listedTokens, tokenMeta],
  )

  const selected = tokenOptions.find((t) => tokenIn && sameAddress(t.address, tokenIn))

  const { data: weightedAllowances, refetch: refetchWeightedAllowances } = useReadContracts({
    contracts:
      address && detf
        ? weightedPairList.map((token) => ({
            address: token,
            abi: erc20Abi,
            functionName: 'allowance' as const,
            args: [address, detf] as const,
            chainId: selectedChainId,
          }))
        : [],
    query: { enabled: weightedReady && !live && !!address && !!detf && weightedPairList.length > 0 },
  })
  const { data: weightedBalances } = useReadContracts({
    contracts: address
      ? weightedPairList.map((token) => ({
          address: token,
          abi: erc20Abi,
          functionName: 'balanceOf' as const,
          args: [address] as const,
          chainId: selectedChainId,
        }))
      : [],
    query: { enabled: weightedReady && !live && !!address && weightedPairList.length > 0 },
  })

  useEffect(() => {
    if (!weightedReady || weightedPairList.length === 0) return
    if (capitalToken && weightedPairList.some((a) => sameAddress(a, capitalToken))) return
    setCapitalToken(weightedPairList[0]!)
  }, [weightedReady, weightedPairList, capitalToken])

  const parsedLegs = useMemo(() => {
    return tokenOptions.map((leg) => {
      const raw = (legAmounts[leg.address.toLowerCase()] ?? '').trim()
      if (!raw) return { ...leg, parsed: null as bigint | null }
      try {
        return { ...leg, parsed: parseUnits(raw, leg.decimals) }
      } catch {
        return { ...leg, parsed: null as bigint | null }
      }
    })
  }, [tokenOptions, legAmounts])

  const allLegsFunded =
    weightedReady && parsedLegs.length > 0 && parsedLegs.every((l) => l.parsed != null && l.parsed > 0n)

  const weightedNeedApprove = weightedReady
    ? parsedLegs.find((leg, i) => {
        if (leg.parsed == null || leg.parsed === 0n) return false
        const result = weightedAllowances?.[i]
        const allowanceWad = result?.status === 'success' ? (result.result as bigint) : 0n
        return allowanceWad < leg.parsed
      })
    : undefined
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenIn || undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf && tokenIn ? [address, detf] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!tokenIn && !!address && !!detf },
  })
  const { data: balance } = useReadContract({
    address: tokenIn || undefined,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!tokenIn && !!address },
  })
  const { data: oracleTerms } = useReadContract({
    address: platform.feeOracle ?? undefined,
    abi: FEE_ORACLE_BOND_ABI,
    functionName: 'bondTermsOfVault',
    args: detf ? [detf] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!detf && !!platform.feeOracle },
  })

  const { minDays, maxDays } = useMemo(
    () => lockRangeFromBondTerms(asBondLockTerms(oracleTerms)),
    [oracleTerms],
  )

  useEffect(() => {
    if (didInitLock.current) return
    if (oracleTerms == null && !platform.feeOracle) {
      didInitLock.current = true
      return
    }
    if (oracleTerms == null) return
    didInitLock.current = true
    const n = Number(lockDays)
    if (!Number.isFinite(n) || n < minDays || n > maxDays) {
      setLockDays(String(minDays))
    }
  }, [oracleTerms, platform.feeOracle, lockDays, minDays, maxDays])

  const sliderDays = clampLockDays(lockDays, minDays, maxDays) ?? minDays
  const lockDaysValid = clampLockDays(lockDays, minDays, maxDays)

  const dec = selected?.decimals ?? 18
  const parsed = useMemo(() => {
    const t = amount.trim()
    if (!t) return null
    try {
      return parseUnits(t, dec)
    } catch {
      return null
    }
  }, [amount, dec])
  const lockSeconds = lockSecondsFromDays(lockDaysValid ?? minDays)
  const needsApprove = parsed != null && (allowance == null || allowance < parsed)

  const writeOnWallet = async (params: Parameters<typeof writeContractAsync>[0]) => {
    const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
    if (typeof walletChainId === 'number' && walletChainId !== selectedChainId && !localWallet) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = params as typeof params & {
      chainId?: number
      chain?: unknown
    }
    return writeContractAsync(rest)
  }

  const waitMined = async (hash: `0x${string}`) => {
    if (!publicClient) throw new Error('No RPC client.')
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    if (receipt.status === 'reverted') throw new Error('Transaction reverted')
    return receipt
  }

  const connectWallet = () => {
    const connector =
      connectors.find((c) => c.id === 'metaMask' || c.id === 'metaMaskSDK') ??
      connectors.find((c) => c.id === 'injected') ??
      connectors[0]
    if (connector) connect({ connector })
  }

  const approve = async () => {
    const weightedFirst = weightedReady && !live
    const token = weightedFirst ? weightedNeedApprove?.address : tokenIn
    const amt = weightedFirst ? weightedNeedApprove?.parsed : parsed
    if (!token || !detf || amt == null) return
    setStatus(null)
    setPending('approve')
    try {
      const hash = await writeOnWallet({
        address: token,
        abi: erc20Abi,
        functionName: 'approve',
        args: [detf, amt],
      })
      await waitMined(hash)
      if (weightedFirst) await refetchWeightedAllowances()
      else await refetchAllowance()
      setStatus('Approved. Bond next.')
    } catch (err) {
      setStatus(parseContractError(err))
    } finally {
      setPending(null)
    }
  }

  const bond = async () => {
    if (!detf || !address) return
    if (lockDaysValid == null) {
      setStatus(`Lock must be ${minDays} to ${maxDays} days.`)
      return
    }
    const weightedFirst = weightedReady && !live
    if (weightedFirst) {
      if (!allLegsFunded || !capitalToken) {
        setStatus('Enter an amount for every pair token.')
        return
      }
    } else if (!tokenIn || parsed == null) {
      return
    }
    setStatus(null)
    setPending('bond')
    try {
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)
      const hash = weightedFirst
        ? await writeOnWallet({
            address: detf,
            abi: WEIGHTED_BOND_ABI,
            functionName: 'bond',
            args: [
              parsedLegs.map((l) => l.address),
              parsedLegs.map((l) => l.parsed ?? 0n),
              capitalToken,
              lockSeconds,
              address,
              false,
              deadline,
            ],
          })
        : await writeOnWallet({
            address: detf,
            abi: DETF_BOND_ABI,
            functionName: 'bond',
            args: [tokenIn, parsed, lockSeconds, address, false, deadline],
          })
      await waitMined(hash)
      setStatus('Bonded. The DETF is live.')
      router.push(`/insights?detf=${detf}`)
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
            {weightedReady && !live
              ? 'The DETF stays off until someone bonds. First bond funds every pair in the reserve. This issues a bond NFT you cannot cash out.'
              : 'The DETF stays off until someone bonds. Bond with a token the strategy vault lists, or with the vault token itself. This issues a bond NFT you cannot cash out.'}
          </p>
          <p className="mt-2 font-mono text-xs text-[var(--text-muted,#9aa3b2)]">{detf}</p>
          {live ? (
            <p className="mt-2 text-sm text-[var(--accent,#4FD44B)]">Reserve is live.</p>
          ) : null}
        </section>

        <Card>
          <p className="landing-section-label">First bond</p>
          {weightedReady && !live ? (
            <>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                Enter an amount for each pair. Extra on any pair is refunded so the join matches the
                opening prices.
              </p>
              {tokenOptions.map((leg, i) => {
                const balResult = weightedBalances?.[i]
                const bal = balResult?.status === 'success' ? (balResult.result as bigint) : null
                return (
                  <label
                    key={leg.address}
                    className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]"
                  >
                    {leg.symbol ?? shortBondAddr(leg.address)} amount
                    <input
                      className={inputClass}
                      value={legAmounts[leg.address.toLowerCase()] ?? ''}
                      onChange={(e) =>
                        setLegAmounts((prev) => ({
                          ...prev,
                          [leg.address.toLowerCase()]: e.target.value,
                        }))
                      }
                      inputMode="decimal"
                      data-testid={`first-bond-amount-${i}`}
                    />
                    {bal != null ? (
                      <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                        Balance {formatUnits(bal, leg.decimals)} {leg.symbol ?? ''}
                      </span>
                    ) : null}
                  </label>
                )
              })}
              <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
                Capital token
                <select
                  className={inputClass}
                  value={capitalToken}
                  onChange={(e) => setCapitalToken((e.target.value as `0x${string}`) || '')}
                  data-testid="first-bond-capital"
                >
                  {tokenOptions.map((t) => (
                    <option key={t.address} value={t.address}>
                      {t.symbol ?? shortBondAddr(t.address)}
                    </option>
                  ))}
                </select>
              </label>
              <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                The bond records this pair as capital. Pick one of the reserve pairs.
              </p>
            </>
          ) : (
            <>
              <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
                Token
                <select
                  className={inputClass}
                  value={tokenIn}
                  onChange={(e) => {
                    didPickToken.current = true
                    setTokenIn((e.target.value as `0x${string}`) || '')
                    setStatus(null)
                  }}
                  disabled={tokenOptions.length === 0}
                  data-testid="first-bond-token"
                >
                  {tokenOptions.length === 0 ? (
                    <option value="">Reading vault tokens…</option>
                  ) : (
                    tokenOptions.map((t) => (
                      <option key={t.address} value={t.address}>
                        {firstBondTokenOptionLabel({
                          address: t.address,
                          symbol: t.symbol,
                          vaultShare,
                        })}
                      </option>
                    ))
                  )}
                </select>
              </label>
              <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                These are the tokens the strategy vault lists, plus the vault token.
              </p>
              <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
                {selected?.symbol ?? 'Token'} amount
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
                  Balance {formatUnits(balance, dec)} {selected?.symbol ?? 'token'}
                </p>
              ) : null}
            </>
          )}
          <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
            Lock (days)
            <input
              className={inputClass}
              value={lockDays}
              onChange={(e) => setLockDays(e.target.value)}
              inputMode="numeric"
              data-testid="first-bond-lock-days"
            />
            <input
              type="range"
              className="mt-3 w-full accent-[var(--accent,#4FD44B)]"
              min={minDays}
              max={maxDays}
              step={1}
              value={sliderDays}
              onChange={(e) => setLockDays(e.target.value)}
              aria-label="Lock days"
              data-testid="first-bond-lock-slider"
            />
          </label>
          <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
            Minimum {minDays} days. Maximum {maxDays} days. Set by the vault fee oracle. You cannot
            cash the bond principal until it matures.
          </p>
          <div className="mt-5 flex flex-wrap gap-3">
            {!isConnected ? (
              <Button type="button" onClick={connectWallet}>
                Connect wallet
              </Button>
            ) : weightedReady && !live && weightedNeedApprove ? (
              <Button
                type="button"
                onClick={() => void approve()}
                disabled={pending != null}
                loading={pending === 'approve'}
                data-testid="first-bond-approve"
              >
                Approve {weightedNeedApprove.symbol ?? 'token'}
              </Button>
            ) : weightedReady && !live ? (
              <Button
                type="button"
                onClick={() => void bond()}
                disabled={!allLegsFunded || !capitalToken || lockDaysValid == null || pending != null}
                loading={pending === 'bond'}
                data-testid="first-bond-cta"
              >
                Bond to turn it on
              </Button>
            ) : needsApprove ? (
              <Button
                type="button"
                onClick={() => void approve()}
                disabled={!tokenIn || parsed == null || pending != null}
                loading={pending === 'approve'}
                data-testid="first-bond-approve"
              >
                Approve {selected?.symbol ?? 'token'}
              </Button>
            ) : (
              <Button
                type="button"
                onClick={() => void bond()}
                disabled={!tokenIn || parsed == null || lockDaysValid == null || pending != null}
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
          <Link href={`/insights?detf=${detf}`}>
            <Button variant="secondary">Open this DETF</Button>
          </Link>
          <Link href="/create/one-vault">
            <Button variant="ghost">Create another</Button>
          </Link>
        </div>
      </div>
    </div>
  )
}
