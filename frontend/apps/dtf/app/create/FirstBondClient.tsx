'use client'

import { useConnectModal } from '@rainbow-me/rainbowkit'

import { useEffect, useMemo, useRef, useState } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { encodeFunctionData, erc20Abi, formatUnits, parseUnits, type Address } from 'viem'
import {
  useAccount,
  useBalance,
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
import {
  ETH_PAY,
  WETH9_DEPOSIT_ABI,
  type EthWrapWrite,
  isEthPay,
  settlePayToken,
  withEthPayOption,
} from '../lib/ethPay'
import { insightsDetfHref } from '../insights/lib/insightsHref'
import { parseContractError } from '../lib/tx/parseContractError'
import {
  asBondLockTerms,
  clampLockDays,
  lockRangeFromBondTerms,
  lockSecondsFromDays,
} from './lib/bondLock'
import {
  defaultFirstBondToken,
  isNonZeroAddress,
  sameAddress,
} from './lib/bondTokens'
import { loadStoredPlan } from './lib/createPlan'
import { DETF_BOND_ABI, FEE_ORACLE_BOND_ABI } from './lib/detfAbi'
import { FUNDED_BOND_ABI, fundedBondArgs, resolveBondRoute } from '../lib/detf/bondRoute'
import { composedFirstBondAmounts, readComposedOpening, type ComposedOpening, asFirstBondPayments, fundedBootstrapRequest, readBootstrapTokens, readFirstBondPayments, resolveBootstrapRoute, V4_FIRST_BOND_PAYMENTS_ABI, V4_FIRST_BOND_PAYMENTS_SELECTOR, type BootstrapKind } from '../lib/detf/firstBondBootstrap'
import { requireFundedBondSupport } from '../lib/detf/bondNftVault'
import { diamondLoupeAbi } from '../insights/lib/insightsAbi'
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
  const { openConnectModal } = useConnectModal()
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
  const [lockDays, setLockDays] = useState('30')
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState<'approve' | 'bond' | null>(null)
  const didInitLock = useRef(false)

  useEffect(() => {
    if (!detf) return
    const plan = loadStoredPlan()
    rememberCreatedDetf({
      chainId: selectedChainId,
      address: detf,
      name: plan?.name.trim() || 'DETF',
      symbol: plan?.symbol.trim() || 'DETF',
      decimals: 9,
    })
  }, [detf, selectedChainId])

  const listedTokens = useMemo(
    () => [
      ...getBaseTokensForChain(selectedChainId, environment),
      ...getStrategyVaultTokensForChain(selectedChainId, environment),
    ],
    [selectedChainId, environment],
  )
  const [bootstrap, setBootstrap] = useState<{ key: string; kind: BootstrapKind | null; tokens: Address[]; opening: ComposedOpening | null; v4: boolean; error: string | null } | null>(null)
  const routeKey = `${selectedChainId}:${detf ?? ''}`
  useEffect(() => {
    if (!detf || !publicClient) return
    let cancelled = false
    const load = async () => {
      await requireFundedBondSupport(publicClient, detf)
      const kind = await resolveBootstrapRoute((selector) => publicClient.readContract({
        address: detf, abi: diamondLoupeAbi, functionName: 'facetAddress', args: [selector],
      }))
      const tokens = kind ? await readBootstrapTokens(publicClient, detf, kind) : []
      const opening = kind === 'composed' ? await readComposedOpening(publicClient, detf) : null
      if (!kind) await resolveBondRoute((selector) => publicClient.readContract({
        address: detf, abi: diamondLoupeAbi, functionName: 'facetAddress', args: [selector],
      }))
      const v4 = !kind && isNonZeroAddress(await publicClient.readContract({
        address: detf, abi: diamondLoupeAbi, functionName: 'facetAddress', args: [V4_FIRST_BOND_PAYMENTS_SELECTOR],
      }))
      if (!cancelled) setBootstrap({ key: routeKey, kind, tokens, opening, v4, error: null })
    }
    void load().catch((error) => {
      if (!cancelled) setBootstrap({ key: routeKey, kind: null, tokens: [], opening: null, v4: false, error: parseContractError(error) })
    })
    return () => { cancelled = true }
  }, [detf, publicClient, routeKey])
  const routeReady = bootstrap?.key === routeKey && !bootstrap.error
  const bootstrapKind = routeReady ? bootstrap.kind : null
  const bootstrapTokenList = useMemo(() => routeReady ? bootstrap.tokens : [], [routeReady, bootstrap])

  const { data: acceptedTokens } = useReadContract({
    address: detf ?? undefined,
    abi: DETF_BOND_ABI,
    functionName: 'acceptedBondTokens',
    chainId: selectedChainId,
    query: { enabled: !!detf },
  })
  const unifiedBondList = useMemo(
    () =>
      ((acceptedTokens as Address[] | undefined) ?? []).filter(
        (a) => isNonZeroAddress(a) && (!detf || !sameAddress(a, detf)),
      ),
    [acceptedTokens, detf],
  )
  const { data: live } = useReadContract({
    address: detf ?? undefined, abi: DETF_BOND_ABI, functionName: 'isReserveLive',
    chainId: selectedChainId, query: { enabled: !!detf },
  })
  const bootstrapFirst = routeReady && !!bootstrapKind && live === false
  const v4First = routeReady && bootstrap.v4 && live === false
  const bondTokens = useMemo(() => bootstrapFirst ? bootstrapTokenList : unifiedBondList, [bootstrapFirst, bootstrapTokenList, unifiedBondList])

  useEffect(() => {
    if (!bondTokens.length) return
    const stillValid = tokenIn && (bondTokens.some((token) => sameAddress(token, tokenIn)) ||
      (isEthPay(tokenIn) && !!platform.weth && bondTokens.some((token) => sameAddress(token, platform.weth!))))
    if (stillValid) return
    setTokenIn(defaultFirstBondToken(bondTokens, null))
  }, [bondTokens, tokenIn, platform.weth])

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
          decimalsResult?.status === 'success' ? Number(decimalsResult.result) : null
        return {
          address,
          symbol: known?.symbol || onchainSymbol,
          decimals: decimals != null && Number.isInteger(decimals) && decimals >= 0 && decimals <= 255 ? decimals : null,
        }
      }),
    [bondTokens, listedTokens, tokenMeta],
  )

  const payOptions = useMemo(
    () =>
      withEthPayOption(tokenOptions.filter((token): token is typeof token & { decimals: number } => token.decimals != null), platform.weth, {
        address: ETH_PAY,
        symbol: 'ETH',
        decimals: 18,
      }),
    [tokenOptions, platform.weth],
  )

  const selected = payOptions.find((t) => tokenIn && sameAddress(t.address, tokenIn))
  const payEth = isEthPay(tokenIn)
  const spendToken = tokenIn ? settlePayToken(tokenIn, platform.weth) : null

  const composedOpening = routeReady && bootstrapKind === 'composed' ? bootstrap.opening : null
  const stableInput = tokenOptions[0] ? legAmounts[tokenOptions[0].address.toLowerCase()] ?? '' : ''
  useEffect(() => {
    if (!bootstrapFirst || !composedOpening || tokenOptions.length !== 2) return
    const [stable, common] = tokenOptions
    if (stable.decimals == null || common.decimals == null) return
    let value = ''
    try {
      const [, required] = composedFirstBondAmounts(parseUnits(stableInput.trim(), stable.decimals), composedOpening)
      value = formatUnits(required, common.decimals)
    } catch { /* An incomplete lead payment leaves its dependent payment empty. */ }
    setLegAmounts((previous) => previous[common.address.toLowerCase()] === value ? previous : { ...previous, [common.address.toLowerCase()]: value })
  }, [bootstrapFirst, composedOpening, stableInput, tokenOptions])

  const parsedLegs = useMemo(() => {
    return tokenOptions.map((leg) => {
      const raw = (legAmounts[leg.address.toLowerCase()] ?? '').trim()
      if (!raw || leg.decimals == null) return { ...leg, parsed: null as bigint | null }
      try {
        return { ...leg, parsed: parseUnits(raw, leg.decimals) }
      } catch {
        return { ...leg, parsed: null as bigint | null }
      }
    })
  }, [tokenOptions, legAmounts])

  const allLegsFunded =
    bootstrapFirst && parsedLegs.length > 0 && parsedLegs.every((l) => l.parsed != null && l.parsed > 0n)

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: spendToken || undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf && spendToken ? [address, detf] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!spendToken && !!address && !!detf },
  })
  const { data: ethBal } = useBalance({
    address,
    chainId: selectedChainId,
    query: { enabled: payEth && !!address },
  })
  const { data: erc20Bal } = useReadContract({
    address: payEth ? undefined : tokenIn || undefined,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!tokenIn && !!address && !payEth },
  })
  const balance = payEth ? ethBal?.value : erc20Bal
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
      const value = parseUnits(t, dec)
      return value > 0n ? value : null
    } catch {
      return null
    }
  }, [amount, dec])
  const lockSeconds = lockSecondsFromDays(lockDaysValid ?? minDays)
  const needsApprove = !payEth && parsed != null && (allowance == null || allowance < parsed)

  const v4PaymentsRead = useReadContract({
    address: detf ?? undefined, abi: V4_FIRST_BOND_PAYMENTS_ABI,
    functionName: 'previewFirstBondPayments', args: spendToken && parsed != null ? [spendToken, parsed] : undefined,
    chainId: selectedChainId, query: { enabled: v4First && !!spendToken && parsed != null },
  })
  const quotedV4Payments = useMemo(() => spendToken && parsed != null
    ? asFirstBondPayments(v4PaymentsRead.data, spendToken, parsed) : null,
    [spendToken, parsed, v4PaymentsRead.data])
  const fundingPayments = useMemo(() => {
    if (bootstrapFirst) return parsedLegs.map((leg) => ({ ...leg, amount: leg.parsed }))
    if (!v4First || !quotedV4Payments) return []
    return quotedV4Payments.map((payment) => ({ ...payment, ...tokenOptions.find((token) => sameAddress(token.address, payment.address)) }))
  }, [bootstrapFirst, parsedLegs, v4First, quotedV4Payments, tokenOptions])
  const v4FundingReady = !!quotedV4Payments && fundingPayments.every((payment) => payment.decimals != null)

  const { data: bootstrapAllowances, refetch: refetchBootstrapAllowances } = useReadContracts({
    contracts:
      address && detf
        ? fundingPayments.map(({ address: token }) => ({
            address: token,
            abi: erc20Abi,
            functionName: 'allowance' as const,
            args: [address, detf] as const,
            chainId: selectedChainId,
          }))
        : [],
    query: { enabled: (bootstrapFirst || v4First) && !!address && !!detf && fundingPayments.length > 0 },
  })
  const { data: bootstrapBalances } = useReadContracts({
    contracts: address
      ? fundingPayments.map(({ address: token }) => ({
          address: token,
          abi: erc20Abi,
          functionName: 'balanceOf' as const,
          args: [address] as const,
          chainId: selectedChainId,
        }))
      : [],
    query: { enabled: (bootstrapFirst || v4First) && !!address && fundingPayments.length > 0 },
  })

  const fundingNeedApprove = fundingPayments.find((payment, index) => {
    if (payment.amount == null || payment.amount <= 0n) return false
    const result = bootstrapAllowances?.[index]
    const allowed = result?.status === 'success' ? result.result as bigint : 0n
    return allowed < payment.amount
  })

  const writeOnWallet = async (
    params: Parameters<typeof writeContractAsync>[0] | EthWrapWrite,
  ) => {
    const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
    if (typeof walletChainId === 'number' && walletChainId !== selectedChainId && !localWallet) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = params as typeof params & {
      chainId?: number
      chain?: unknown
    }
    return writeContractAsync(rest as Parameters<typeof writeContractAsync>[0])
  }

  const waitMined = async (hash: `0x${string}`) => {
    if (!publicClient) throw new Error('No RPC client.')
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    if (receipt.status === 'reverted') throw new Error('Transaction reverted')
    return receipt
  }

  const connectWallet = () => openConnectModal?.()

  const readFacet = (selector: `0x${string}`) => {
    if (!publicClient || !detf) throw new Error('No RPC client or DETF address.')
    return publicClient.readContract({ address: detf, abi: diamondLoupeAbi, functionName: 'facetAddress', args: [selector] })
  }

  const requireCurrentRoute = async () => {
    if (!publicClient || !detf || !routeReady || live == null) throw new Error('Wait for the DETF bond route to load.')
    await requireFundedBondSupport(publicClient, detf)
    const isLive = await publicClient.readContract({ address: detf, abi: DETF_BOND_ABI, functionName: 'isReserveLive' })
    if (isLive !== live) throw new Error('The reserve state changed. Refresh before bonding.')
    if (bootstrapFirst && bootstrapKind) {
      const currentKind = await resolveBootstrapRoute(readFacet)
      if (currentKind !== bootstrapKind) throw new Error('The first-bond route changed. Refresh before bonding.')
      const tokens = await readBootstrapTokens(publicClient, detf, bootstrapKind)
      if (tokens.length !== bootstrapTokenList.length || tokens.some((token, index) => !sameAddress(token, bootstrapTokenList[index]))) {
        throw new Error('The first-bond payments changed. Refresh before bonding.')
      }
      if (bootstrapKind === 'composed') {
        const fresh = await readComposedOpening(publicClient, detf)
        if (!composedOpening || fresh.prices.some((value, i) => value !== composedOpening.prices[i]) ||
            fresh.seedAmounts.some((value, i) => value !== composedOpening.seedAmounts[i])) {
          throw new Error('The opening terms changed. Refresh before bonding.')
        }
      }
      return null
    }
    return resolveBondRoute(readFacet)
  }

  const fundedInput = async (token: Address, text: string) => {
    if (!publicClient) throw new Error('No RPC client.')
    const decimals = await publicClient.readContract({ address: token, abi: erc20Abi, functionName: 'decimals' })
    const value = parseUnits(text.trim(), decimals)
    if (value <= 0n) throw new Error('Enter a positive bond payment.')
    return value
  }

  const approve = async () => {
    const multiPayment = bootstrapFirst || v4First
    const token = multiPayment ? fundingNeedApprove?.address : spendToken
    const amt = multiPayment ? fundingNeedApprove?.amount : parsed
    if (!token || !detf || amt == null || !publicClient) return
    setStatus(null)
    setPending('approve')
    try {
      await requireCurrentRoute()
      const freshV4 = v4First && spendToken
        ? await readFirstBondPayments(publicClient, detf, spendToken, await fundedInput(spendToken, amount)) : null
      const fundedAmount = freshV4
        ? freshV4.find((payment) => sameAddress(payment.address, token))?.amount
        : await fundedInput(token, multiPayment ? legAmounts[token.toLowerCase()] ?? '' : amount)
      if (fundedAmount == null) throw new Error('The first-bond payments changed. Refresh before approving.')
      const hash = await writeOnWallet({
        address: token,
        abi: erc20Abi,
        functionName: 'approve',
        args: [detf, fundedAmount],
      })
      await waitMined(hash)
      if (multiPayment) await refetchBootstrapAllowances()
      else await refetchAllowance()
      setStatus('Approved. Bond next.')
    } catch (err) {
      setStatus(parseContractError(err))
    } finally {
      setPending(null)
    }
  }

  const bond = async () => {
    if (!detf || !address || !publicClient) return
    if (lockDaysValid == null) {
      setStatus(`Lock must be ${minDays} to ${maxDays} days.`)
      return
    }
    const multiPayment = bootstrapFirst
    if (multiPayment) {
      if (!allLegsFunded) {
        setStatus('Enter an amount for every reserve payment.')
        return
      }
    } else if (!spendToken || parsed == null) {
      return
    }
    setStatus(null)
    setPending('bond')
    try {
      const route = await requireCurrentRoute()
      const payment = multiPayment ? null : await fundedInput(spendToken as Address, amount)
      if (v4First && spendToken && payment != null) {
        const payments = await readFirstBondPayments(publicClient, detf, spendToken, payment)
        for (const required of payments) {
          const approved = await publicClient.readContract({ address: required.address, abi: erc20Abi, functionName: 'allowance', args: [address, detf] })
          if (approved < required.amount) throw new Error('Approve every first-bond payment before bonding.')
        }
      }
      const bootstrapAmounts = multiPayment
        ? await Promise.all(parsedLegs.map((leg) => fundedInput(leg.address, legAmounts[leg.address.toLowerCase()] ?? '')))
        : []
      if (multiPayment && bootstrapKind === 'composed' && composedOpening) {
        const required = composedFirstBondAmounts(bootstrapAmounts[0], composedOpening)
        if (required[1] !== bootstrapAmounts[1]) throw new Error('The reserve payments must match the configured proportions.')
      }
      if (!multiPayment && payEth && platform.weth && payment != null) {
        const wethSpend = spendToken ?? platform.weth
        const wrapHash = await writeOnWallet({
          address: platform.weth,
          abi: WETH9_DEPOSIT_ABI,
          functionName: 'deposit',
          value: payment,
        })
        await waitMined(wrapHash)
        setStatus('Wrapped ETH to WETH.')
        if (allowance == null || allowance < payment) {
          const appr = await writeOnWallet({
            address: wethSpend,
            abi: erc20Abi,
            functionName: 'approve',
            args: [detf, payment],
          })
          await waitMined(appr)
          await refetchAllowance()
        }
      }
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)
      const request = multiPayment
        ? { address: detf, ...fundedBootstrapRequest(bootstrapKind!, bootstrapAmounts, lockSeconds, address, deadline) }
        : { address: detf, abi: FUNDED_BOND_ABI, functionName: 'bond' as const,
            args: fundedBondArgs(route!, { token: spendToken as Address, amount: payment!, duration: lockSeconds, recipient: address, deadline }) }
      const data = request.functionName === 'bond'
        ? encodeFunctionData(request)
        : encodeFunctionData(request)
      await publicClient.call({ account: address, to: detf, data })
      const hash = await writeOnWallet(request)
      await waitMined(hash)
      setStatus('Bonded. The DETF is live.')
      router.push(insightsDetfHref(detf))
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
            {bootstrapFirst
              ? 'The first bond funds every required reserve asset and starts the reserve. Your purchased DETF is also funded and staked, with principal vesting steadily.'
              : 'The first bond starts the reserve. Buy with an accepted payment token; your purchased DETF is staked while principal vests. Claim principal and rewards as sDETF.'}
          </p>
          <p className="mt-2 font-mono text-xs text-[var(--text-muted,#9aa3b2)]">{detf}</p>
          {live ? (
            <p className="mt-2 text-sm text-[var(--accent,#4FD44B)]">Reserve is live.</p>
          ) : null}
        </section>

        <Card>
          <p className="landing-section-label">First bond</p>
          {bootstrap?.key === routeKey && bootstrap.error ? <p className="mt-3 text-sm" role="alert">{bootstrap.error}</p> : null}
          {bootstrapFirst ? (
            <>
              <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
                {composedOpening
                  ? 'Enter the first payment. The second follows this DETF’s configured reserve proportions.'
                  : 'Enter an amount for every required reserve asset.'} These payments fund the reserve and your separately staked principal.
              </p>
              {tokenOptions.map((leg, i) => {
                const balResult = bootstrapBalances?.[i]
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
                      readOnly={!!composedOpening && i === 1}
                      onChange={(e) =>
                        setLegAmounts((prev) => ({
                          ...prev,
                          [leg.address.toLowerCase()]: e.target.value,
                        }))
                      }
                      inputMode="decimal"
                      data-testid={`first-bond-amount-${i}`}
                    />
                    {bal != null && leg.decimals != null ? (
                      <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                        Balance {formatUnits(bal, leg.decimals)} {leg.symbol ?? ''}
                      </span>
                    ) : null}
                  </label>
                )
              })}

            </>
          ) : (
            <>
              <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
                Token
                <select
                  className={inputClass}
                  value={tokenIn}
                  onChange={(e) => {
                    setTokenIn((e.target.value as `0x${string}`) || '')
                    setStatus(null)
                  }}
                  disabled={tokenOptions.length === 0}
                  data-testid="first-bond-token"
                >
                  {payOptions.length === 0 ? (
                    <option value="">Reading vault tokens…</option>
                  ) : (
                    payOptions.map((t) => (
                      <option key={t.address} value={t.address}>
                        {isEthPay(t.address)
                          ? 'ETH'
                          : t.symbol ?? shortBondAddr(t.address)}
                      </option>
                    ))
                  )}
                </select>
              </label>
              <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                Use a payment token accepted by this DETF.
                {platform.weth ? ' ETH wraps to WETH first.' : ''}
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
          {v4First && parsed != null ? (
            <div className="mt-4 rounded-lg border border-[var(--border-subtle)] p-3 text-sm">
              <p>Required reserve payments</p>
              <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">Your chosen amount sets the other first-bond payments at the DETF’s opening rates. Approve each token before bonding.</p>
              {v4PaymentsRead.isError ? <p className="mt-2" role="alert">Unable to quote these first-bond payments.</p> : null}
              {fundingPayments.map((payment, index) => {
                const result = bootstrapBalances?.[index]
                const held = result?.status === 'success' ? result.result as bigint : null
                return <p className="mt-2" key={payment.address}>
                  {payment.amount != null && payment.decimals != null ? formatUnits(payment.amount, payment.decimals) : 'Reading…'} {payment.symbol ?? shortBondAddr(payment.address)}
                  {held != null && payment.decimals != null ? <span className="ml-2 text-xs text-[var(--text-muted,#9aa3b2)]">Balance {formatUnits(held, payment.decimals)}</span> : null}
                </p>
              })}
            </div>
          ) : null}
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
            Minimum {minDays} days. Maximum {maxDays} days. Set by the vault fee oracle. You can
            claim vested principal and staking rewards as sDETF during the vesting period.
          </p>
          <div className="mt-5 flex flex-wrap gap-3">
            {!isConnected ? (
              <Button type="button" onClick={connectWallet}>
                Connect wallet
              </Button>
            ) : (bootstrapFirst || v4First) && fundingNeedApprove ? (
              <Button
                type="button"
                onClick={() => void approve()}
                disabled={!publicClient || !routeReady || live == null || pending != null}
                loading={pending === 'approve'}
                data-testid="first-bond-approve"
              >
                Approve {fundingNeedApprove.symbol ?? 'token'}
              </Button>
            ) : bootstrapFirst ? (
              <Button
                type="button"
                onClick={() => void bond()}
                disabled={!publicClient || !routeReady || live == null || !allLegsFunded || lockDaysValid == null || pending != null}
                loading={pending === 'bond'}
                data-testid="first-bond-cta"
              >
                Bond to turn it on
              </Button>
            ) : needsApprove ? (
              <Button
                type="button"
                onClick={() => void approve()}
                disabled={!publicClient || !routeReady || live == null || !tokenIn || parsed == null || pending != null}
                loading={pending === 'approve'}
                data-testid="first-bond-approve"
              >
                Approve {selected?.symbol ?? 'token'}
              </Button>
            ) : (
              <Button
                type="button"
                onClick={() => void bond()}
                disabled={!publicClient || !routeReady || live == null || (v4First && !v4FundingReady) || !tokenIn || parsed == null || lockDaysValid == null || pending != null}
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
          <Link href={insightsDetfHref(detf)}>
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
