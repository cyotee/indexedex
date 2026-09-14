'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { erc20Abi, formatUnits, parseUnits } from 'viem'
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
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'

import { AddressLink } from '../../components/ui/AddressLink'
import { AmountField } from '../../components/ui/AmountField'
import { Button } from '../../components/ui/Button'
import { Card } from '../../components/ui/Card'
import { Tabs, TabPanel } from '../../components/ui/Tabs'
import {
  asBondLockTerms,
  clampLockDays,
  FALLBACK_MIN_LOCK_DAYS,
  lockRangeFromBondTerms,
  lockSecondsFromDays as lockSecondsFromNumber,
} from '../../create/lib/bondLock'
import { FEE_ORACLE_BOND_ABI } from '../../create/lib/detfAbi'
import { resolveSePlatform } from '../../create/lib/sePlatform'
import {
  ETH_PAY,
  WETH9_DEPOSIT_ABI,
  WETH9_WITHDRAW_ABI,
  type EthWrapWrite,
  isEthPay,
  settlePayToken,
  withEthPayOption,
} from '../../lib/ethPay'
import { asBondClaim, asBondPosition, requireFundedBondSupport } from '../../lib/detf/bondNftVault'
import { FUNDED_BOND_ABI, V4_BOND_PREVIEW_ABI, fundedBondArgs, resolveBondRoute, smallerBondAmount } from '../../lib/detf/bondRoute'
import { chainDeadline } from '../../lib/tx/chainDeadline'
import { isPoolInputLimitError, parseContractError } from '../../lib/tx/parseContractError'
import { isArchivedDetf } from '../lib/archivedDetfs'
import { isInsightsActionTab } from '../lib/insightsHref'
import { bondNftAbi, diamondLoupeAbi, insightsViewAbi, standardizedYieldDiscoveryAbi } from '../lib/insightsAbi'
import {
  addressesMatch,
  bondIdScanCount,
  bondOwnerAddress,
  bondUnlockState,
  claimRewardsBlockedReason,
  claimRewardsButtonEnabled,
  ownedBondIdsFromOwnerReads,
  parseBondTokenId,
  walletCanSignOnChain,
} from '../lib/claimRewardsGate'
import { isZero } from '../lib/tokenLabels'
import { actionTokenOptionLabel, asAddr, tokensForStandardRoute, type ActionToken } from '../lib/actionTokens'
import { DetfStaking } from './DetfStaking'

export type { ActionToken }

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

function parseAmount(raw: string, decimals: number): bigint | undefined {
  if (!raw.trim()) return undefined
  try {
    return parseUnits(raw.trim(), decimals)
  } catch {
    return undefined
  }
}

export function DetfActions({
  detf,
  detfSymbol,
  pairTokens,
  vaultShare,
  chainId,
  claimToken,
  claimSymbol,
  reserveLive,
  archived: archivedProp,
  initialTab,
  nftVault: nftVaultProp,
}: {
  detf?: `0x${string}`
  detfSymbol: string
  pairTokens: ActionToken[]
  vaultShare?: `0x${string}` | null
  chainId: number
  claimToken?: `0x${string}`
  claimSymbol?: string
  reserveLive?: boolean
  archived?: boolean
  initialTab?: string
  nftVault?: `0x${string}`
}) {
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const publicClient = usePublicClient({ chainId })
  const { writeContractAsync } = useWriteContract()
  const { switchChainAsync } = useSwitchChain()
  const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
  const walletMatches = walletCanSignOnChain({
    isConnected,
    walletChainId,
    appChainId: chainId,
    localWallet,
  })
  const platform = useMemo(() => resolveSePlatform(chainId, environment), [chainId, environment])
  const archived = archivedProp || isArchivedDetf(detf)

  const [tab, setTab] = useState(() =>
    isInsightsActionTab(initialTab) ? initialTab : archived ? 'burn' : 'mint',
  )

  useEffect(() => {
    if (isInsightsActionTab(initialTab)) setTab(initialTab)
  }, [initialTab])
  const [token, setToken] = useState<string>(pairTokens[0]?.address ?? '')
  const [amount, setAmount] = useState('')
  const [burnAmount, setBurnAmount] = useState('')
  const [lockDays, setLockDays] = useState(String(FALLBACK_MIN_LOCK_DAYS))
  const [lockBlurred, setLockBlurred] = useState(false)
  const [tokenId, setTokenId] = useState('')
  const [status, setStatus] = useState('')
  const [findingBondAmount, setFindingBondAmount] = useState(false)
  const [pendingLeg, setPendingLeg] = useState<'approve' | 'mint' | 'bond' | 'claim' | 'burn' | null>(null)
  const [approvedSpend, setApprovedSpend] = useState(0n)
  const [approvedDetfSpend, setApprovedDetfSpend] = useState(0n)

  const { data: rawSYValue } = useReadContract({
    chainId, address: detf, abi: standardizedYieldDiscoveryAbi, functionName: 'rawSY',
    query: { enabled: !!detf, retry: 0 },
  })
  const rawSY = asAddr(rawSYValue) ?? undefined
  const { data: tokensIn } = useReadContract({
    chainId, address: rawSY, abi: standardizedYieldDiscoveryAbi, functionName: 'getTokensIn',
    query: { enabled: !!rawSY, retry: 0 },
  })
  const { data: tokensOut } = useReadContract({
    chainId, address: rawSY, abi: standardizedYieldDiscoveryAbi, functionName: 'getTokensOut',
    query: { enabled: !!rawSY, retry: 0 },
  })
  const { data: bondTokens } = useReadContract({
    chainId, address: detf, abi: insightsViewAbi, functionName: 'acceptedBondTokens',
    query: { enabled: !!detf, retry: 0 },
  })
  const { data: reserveLp } = useReadContract({
    chainId, address: detf, abi: insightsViewAbi, functionName: 'reservePool',
    query: { enabled: !!detf && tab === 'bond', retry: 0 },
  })
  const payTokens = useMemo(() => withEthPayOption(tokensForStandardRoute({
    discovered: tab === 'bond' ? bondTokens : tab === 'burn' ? tokensOut : tokensIn,
    labels: pairTokens,
    exclude: [detf, claimToken],
  }), platform.weth, { address: ETH_PAY, symbol: 'ETH' }), [tab, bondTokens, tokensOut, tokensIn, pairTokens, detf, claimToken, platform.weth])

  useEffect(() => {
    if (payTokens.length === 0) { setToken(''); return }
    const ok = payTokens.some((t) => t.address.toLowerCase() === token.toLowerCase())
    if (!ok) setToken(payTokens[0]!.address)
  }, [payTokens, token])

  const tokenAddr = (payTokens.some((item) => item.address.toLowerCase() === token.toLowerCase())
    ? token : payTokens[0]?.address ?? '') as `0x${string}` | ''
  const tokenMeta = payTokens.find((t) => t.address.toLowerCase() === tokenAddr.toLowerCase()) ?? payTokens[0]
  const payEth = isEthPay(tokenAddr)
  const spendToken = settlePayToken(tokenAddr, platform.weth)

  useEffect(() => {
    setApprovedSpend(0n)
    setApprovedDetfSpend(0n)
  }, [tokenAddr, detf, address])

  const { data: tokenDecimals } = useReadContract({
    chainId,
    address: payEth ? undefined : tokenAddr || undefined,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: !!tokenAddr && !payEth },
  })
  const decimals = payEth || tokenDecimals == null ? 18 : Number(tokenDecimals)
  const parsed = payEth || tokenDecimals != null ? parseAmount(amount, decimals) : undefined
  const parsedId = useMemo(() => parseBondTokenId(tokenId), [tokenId])

  const { data: ethBal } = useBalance({
    address,
    chainId,
    query: { enabled: payEth && !!address },
  })
  const { data: erc20Bal } = useReadContract({
    chainId,
    address: payEth ? undefined : tokenAddr || undefined,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!tokenAddr && !!address && !payEth },
  })
  const balance = payEth ? ethBal?.value : erc20Bal
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    chainId,
    address: spendToken || undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf && spendToken ? [address, detf] : undefined,
    query: { enabled: !!spendToken && !!address && !!detf },
  })
  const { data: oracleTerms } = useReadContract({
    chainId,
    address: platform.feeOracle ?? undefined,
    abi: FEE_ORACLE_BOND_ABI,
    functionName: 'bondTermsOfVault',
    args: detf ? [detf] : undefined,
    query: { enabled: !!detf && !!platform.feeOracle },
  })
  const { minDays, maxDays } = useMemo(
    () => lockRangeFromBondTerms(asBondLockTerms(oracleTerms)),
    [oracleTerms],
  )

  // Keep the draft intact while typing (including blank or partial numbers).
  // Invalid drafts cannot be quoted or submitted as a different duration.
  const validLockDays = clampLockDays(lockDays, minDays, maxDays)
  const oracleLock = validLockDays == null ? null : lockSecondsFromNumber(validLockDays)
  const bondInputKey = `${chainId}:${address}:${detf}:${tokenAddr}:${parsed}:${lockDays}`
  const currentBondInput = useRef(bondInputKey)
  currentBondInput.current = bondInputKey
  const { data: bondPreview, error: bondPreviewError, isFetching: bondPreviewFetching } = useReadContract({
    chainId, address: detf, abi: V4_BOND_PREVIEW_ABI, functionName: 'previewBond',
    args: spendToken && parsed != null && oracleLock != null ? [spendToken, parsed, oracleLock] : undefined,
    query: { enabled: tab === 'bond' && !!detf && !!spendToken && parsed != null && parsed > 0n && oracleLock != null, retry: 0, refetchInterval: 15_000 },
  })
  const bondQuoteReady = oracleLock != null && !!bondPreview && bondPreview[1] > 0n && !bondPreviewError && !bondPreviewFetching && !findingBondAmount
  const payingReserveLp = tab === 'bond' && addressesMatch(spendToken, reserveLp)
  const { data: preview } = useReadContract({
    chainId,
    address: detf,
    abi: insightsViewAbi,
    functionName: 'previewExchangeIn',
    args: parsed && spendToken && detf ? [spendToken, parsed, detf] : undefined,
    query: { enabled: tab === 'mint' && !!detf && !!spendToken && parsed != null && parsed > BigInt(0) },
  })
  const { data: detfDecimalsRaw } = useReadContract({
    chainId,
    address: detf,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: !!detf },
  })
  const detfDecimals = detfDecimalsRaw == null ? 9 : Number(detfDecimalsRaw)
  const parsedBurn = detfDecimalsRaw != null ? parseAmount(burnAmount, detfDecimals) : undefined
  const burnLive = reserveLive === true
  const { data: detfBal } = useReadContract({
    chainId,
    address: detf,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: tab === 'burn' && !!detf && !!address },
  })
  const { data: detfAllowance, refetch: refetchDetfAllowance } = useReadContract({
    chainId,
    address: detf,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf ? [address, detf] : undefined,
    query: { enabled: tab === 'burn' && !!detf && !!address },
  })
  const { data: burnPreview } = useReadContract({
    chainId,
    address: detf,
    abi: insightsViewAbi,
    functionName: 'previewExchangeIn',
    args: parsedBurn && spendToken && detf ? [detf, parsedBurn, spendToken] : undefined,
    query: {
      enabled:
        tab === 'burn' &&
        burnLive &&
        !!detf &&
        !!spendToken &&
        parsedBurn != null &&
        parsedBurn > BigInt(0),
    },
  })
  const skipNftLookup = !!nftVaultProp && !isZero(nftVaultProp)
  const { data: bondVault } = useReadContract({
    chainId,
    address: detf,
    abi: insightsViewAbi,
    functionName: 'bondNftVault',
    query: { enabled: !!detf && !skipNftLookup, retry: 0 },
  })
  const { data: protocolVault } = useReadContract({
    chainId,
    address: detf,
    abi: insightsViewAbi,
    functionName: 'protocolNFTVault',
    query: { enabled: !!detf && !skipNftLookup, retry: 0 },
  })
  const nftVault = skipNftLookup
    ? nftVaultProp
    : bondVault && !isZero(bondVault)
      ? bondVault
      : protocolVault && !isZero(protocolVault)
        ? protocolVault
        : undefined
  const scanCount = bondIdScanCount()
  const ownerScanContracts = useMemo(() => {
    if (tab !== 'claim' || !nftVault) return []
    return Array.from({ length: scanCount }, (_, i) => ({
      address: nftVault,
      abi: bondNftAbi,
      functionName: 'ownerOf' as const,
      args: [BigInt(i + 3)] as const,
      chainId,
    }))
  }, [tab, nftVault, scanCount, chainId])
  const ownerScan = useReadContracts({
    contracts: ownerScanContracts,
    allowFailure: true,
    query: { enabled: ownerScanContracts.length > 0 && !!address },
  })
  const ownedIds = useMemo(
    () => ownedBondIdsFromOwnerReads(ownerScan.data, address),
    [ownerScan.data, address],
  )

  useEffect(() => {
    if (tokenId.trim()) return
    if (ownedIds.length === 0) return
    setTokenId(ownedIds[0]!.toString())
  }, [ownedIds, tokenId])

  const [claimKind, setClaimKind] = useState<'claimBond' | 'claimPrincipal' | 'claimRewards'>('claimBond')

  const claimReadsOn =
    tab === 'claim' && !!nftVault && parsedId !== undefined

  const claimPreviewRead = useReadContract({
    chainId, address: nftVault, abi: bondNftAbi, functionName: 'previewClaim',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: claimReadsOn, retry: 0, refetchInterval: 15_000 },
  })
  const claimPreview = asBondClaim(claimPreviewRead.data)
  const pendingRewards = claimPreview?.rewardsDue
  const { data: ownerOf, isError: ownerReadFailed, isFetching: ownerReading } = useReadContract({
    chainId,
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'ownerOf',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: claimReadsOn, retry: 0 },
  })
  const positionRead = useReadContract({
    chainId, address: nftVault, abi: bondNftAbi, functionName: 'positionOf',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: claimReadsOn, retry: 0, refetchInterval: 15_000 },
  })
  const position = asBondPosition(positionRead.data)
  const unlockTime = position ? position.startTimestamp + position.vestingDuration : undefined
  const ownerAddr = bondOwnerAddress(typeof ownerOf === 'string' ? ownerOf : undefined)
  const ownsBond = addressesMatch(ownerAddr, address)
  const unlock = bondUnlockState(
    typeof unlockTime === 'bigint' ? unlockTime : undefined,
    Math.floor(Date.now() / 1000),
  )
  const canClaim = claimRewardsButtonEnabled({
    canSign: isConnected && walletMatches && !!nftVault && !!address && !!claimPreview && !!publicClient && pendingLeg == null,
    tokenId: parsedId,
    matured: unlock.locked === false,
    pendingRewards: typeof pendingRewards === 'bigint' ? pendingRewards : undefined,
    owner: ownerAddr,
    wallet: address,
  })
  const claimBlocked = claimRewardsBlockedReason({
    isConnected,
    walletMatches,
    appChainId: chainId,
    tokenId: parsedId,
  })

  const covered = allowance != null && allowance >= (parsed ?? 0n) ? allowance : approvedSpend
  const needApprove = !payEth && parsed != null && parsed > 0n && covered < parsed
  const detfCovered =
    detfAllowance != null && detfAllowance >= (parsedBurn ?? 0n) ? detfAllowance : approvedDetfSpend
  const needApproveDetf = parsedBurn != null && parsedBurn > 0n && detfCovered < parsedBurn
  const canSign = isConnected && walletMatches && !!detf && !!address && !!publicClient && pendingLeg == null
  const canMintOrBond = canSign && !archived
  const canBurn = canSign && burnLive

  async function writeOnWallet(params: Parameters<typeof writeContractAsync>[0] | EthWrapWrite) {
    if (typeof walletChainId === 'number' && walletChainId !== chainId && !localWallet) {
      await switchChainAsync({ chainId })
    }
    const { chain: _chain, chainId: _cid, ...rest } = params as typeof params & {
      chain?: unknown
      chainId?: number
    }
    const next = (localWallet ? rest : params) as Parameters<typeof writeContractAsync>[0]
    return writeContractAsync(next)
  }

  async function wait(hash: `0x${string}`, label: string) {
    setStatus(`${label} submitted.`)
    if (!publicClient) throw new Error('The selected network is unavailable.')
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    if (receipt.status === 'reverted') throw new Error('Transaction reverted')
    setStatus(`${label} confirmed.`)
  }

  async function wrapEth() {
    if (!payEth || !platform.weth || !address || parsed == null) return
    const hash = await writeOnWallet({
      account: address,
      address: platform.weth,
      abi: WETH9_DEPOSIT_ABI,
      functionName: 'deposit',
      value: parsed,
    })
    await wait(hash, 'Wrap')
  }

  async function approveWethIfNeeded() {
    if (!detf || !spendToken || !address || parsed == null) return
    const coveredNow = allowance != null && allowance >= parsed ? allowance : approvedSpend
    if (coveredNow >= parsed) return
    const hash = await writeOnWallet({
      account: address,
      address: spendToken,
      abi: erc20Abi,
      functionName: 'approve',
      args: [detf, parsed],
    })
    await wait(hash, 'Approve')
    setApprovedSpend(parsed)
    await refetchAllowance()
  }

  async function approve() {
    if (archived || !detf || !spendToken || parsed == null || parsed <= 0n || !address || !publicClient) return
    setPendingLeg('approve')
    setStatus('')
    try {
      if (tab === 'bond') {
        await readBondRoute()
        await freshBondQuote(parsed)
      }
      const hash = await writeOnWallet({
        account: address,
        address: spendToken,
        abi: erc20Abi,
        functionName: 'approve',
        args: [detf, parsed],
      })
      await wait(hash, 'Approve')
      setApprovedSpend(parsed)
      await refetchAllowance()
      setStatus('Approved. Bond or mint next.')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function approveDetf() {
    if (!detf || parsedBurn == null || !address) return
    setPendingLeg('approve')
    setStatus('')
    try {
      const hash = await writeOnWallet({
        account: address,
        address: detf,
        abi: erc20Abi,
        functionName: 'approve',
        args: [detf, parsedBurn],
      })
      await wait(hash, 'Approve')
      setApprovedDetfSpend(parsedBurn)
      await refetchDetfAllowance()
      setStatus('Approved. Burn next.')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function unwrapWeth(wad: bigint) {
    if (!payEth || !platform.weth || !address || wad <= BigInt(0)) return
    const hash = await writeOnWallet({
      account: address,
      address: platform.weth,
      abi: WETH9_WITHDRAW_ABI,
      functionName: 'withdraw',
      args: [wad],
    })
    await wait(hash, 'Unwrap')
  }

  async function burn() {
    if (!detf || !spendToken || parsedBurn == null || parsedBurn <= 0n || !address || !publicClient) return
    setPendingLeg('burn')
    setStatus('')
    try {
      const wethBefore =
        payEth && platform.weth && publicClient
          ? ((await publicClient.readContract({
              address: platform.weth,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [address],
            })) as bigint)
          : null
      const minOut = await freshMinimum(detf, parsedBurn, spendToken)
      const args = [detf, parsedBurn, spendToken, minOut, address, false, await chainDeadline(publicClient)] as const
      if (publicClient) {
        await publicClient.simulateContract({
          account: address,
          address: detf,
          abi: insightsViewAbi,
          functionName: 'exchangeIn',
          args,
        })
      }
      const hash = await writeOnWallet({
        account: address,
        address: detf,
        abi: insightsViewAbi,
        functionName: 'exchangeIn',
        args,
      })
      await wait(hash, 'Burn')
      if (wethBefore != null && platform.weth && publicClient) {
        const wethAfter = (await publicClient.readContract({
          address: platform.weth,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [address],
        })) as bigint
        if (wethAfter > wethBefore) await unwrapWeth(wethAfter - wethBefore)
      }
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function mint() {
    if (archived || !detf || !spendToken || parsed == null || parsed <= 0n || !address || !publicClient) return
    setPendingLeg('mint')
    setStatus('')
    try {
      await freshMinimum(spendToken, parsed, detf)
      await wrapEth()
      if (payEth) await approveWethIfNeeded()
      const minOut = await freshMinimum(spendToken, parsed, detf)
      const args = [spendToken, parsed, detf, minOut, address, false, await chainDeadline(publicClient)] as const
      if (publicClient) {
        await publicClient.simulateContract({
          account: address,
          address: detf,
          abi: insightsViewAbi,
          functionName: 'exchangeIn',
          args,
        })
      }
      const hash = await writeOnWallet({
        account: address,
        address: detf,
        abi: insightsViewAbi,
        functionName: 'exchangeIn',
        args,
      })
      await wait(hash, 'Mint')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function readBondRoute() {
    if (!publicClient || !detf) throw new Error('The selected DETF is unavailable.')
    await requireFundedBondSupport(publicClient, detf)
    return resolveBondRoute((selector) => publicClient.readContract({
      address: detf, abi: diamondLoupeAbi, functionName: 'facetAddress', args: [selector],
    }))
  }

  async function freshMinimum(tokenIn: `0x${string}`, amountIn: bigint, tokenOut: `0x${string}`) {
    if (!publicClient || !detf) throw new Error('The selected DETF is unavailable.')
    const quote = await publicClient.readContract({
      address: detf, abi: insightsViewAbi, functionName: 'previewExchangeIn', args: [tokenIn, amountIn, tokenOut],
    })
    if (quote <= 0n) throw new Error('No positive quote is available for this amount.')
    const minimum = quote * 99n / 100n
    return minimum > 0n ? minimum : 1n
  }

  async function freshBondQuote(amountIn: bigint) {
    if (!publicClient || !detf || !spendToken) throw new Error('The selected DETF is unavailable.')
    if (oracleLock == null) throw new Error(`Enter a whole number of days from ${minDays} to ${maxDays}.`)
    const quote = await publicClient.readContract({
      address: detf, abi: V4_BOND_PREVIEW_ABI, functionName: 'previewBond', args: [spendToken, amountIn, oracleLock],
    })
    if (quote[1] <= 0n) throw new Error('No positive bond quote is available for this amount.')
    return quote
  }

  async function findSmallerBond() {
    if (!parsed || findingBondAmount) return
    const inputKey = bondInputKey
    setFindingBondAmount(true)
    setStatus('Checking smaller bond amounts…')
    try {
      const candidate = await smallerBondAmount(parsed, freshBondQuote)
      if (currentBondInput.current !== inputKey) return
      setAmount(formatUnits(candidate, decimals))
      setStatus('Amount reduced to a current positive quote. Review it before buying; no bond has been submitted.')
    } catch (error) {
      if (currentBondInput.current === inputKey) setStatus(parseContractError(error))
    } finally {
      setFindingBondAmount(false)
    }
  }

  async function bond() {
    if (archived || !detf || !spendToken || parsed == null || parsed <= 0n || !address || !publicClient || oracleLock == null) return
    setPendingLeg('bond')
    setStatus('')
    try {
      const route = await readBondRoute()
      // previewBond applies the duration bonus and the reserve's input limit.
      // Check it before spending gas on wrapping or approving ETH payment.
      await freshBondQuote(parsed)
      await wrapEth()
      if (payEth) await approveWethIfNeeded()
      await freshBondQuote(parsed)
      const args = fundedBondArgs(route, { token: spendToken, amount: parsed, duration: oracleLock, recipient: address, deadline: await chainDeadline(publicClient) })
      await publicClient.simulateContract({ account: address, address: detf, abi: FUNDED_BOND_ABI, functionName: 'bond', args })
      const hash = await writeOnWallet({ account: address, address: detf, abi: FUNDED_BOND_ABI, functionName: 'bond', args })
      await wait(hash, 'Bond')
      await ownerScan.refetch()
    } catch (e) {
      setStatus(`${parseContractError(e)}${payEth ? ' If wrapping already confirmed, the WETH remains in your wallet. Select WETH to retry without wrapping again.' : ''}`)
    } finally {
      setPendingLeg(null)
    }
  }

  async function claim() {
    if (!address || parsedId === undefined || !nftVault || !publicClient || !canClaim) return
    setPendingLeg('claim')
    setStatus('')
    try {
      const args = [parsedId, address] as const
      await publicClient.simulateContract({ account: address, address: nftVault, abi: bondNftAbi, functionName: claimKind, args })
      const hash = await writeOnWallet({ account: address, address: nftVault, abi: bondNftAbi, functionName: claimKind, args })
      await wait(hash, 'Claim sDETF')
      await Promise.all([claimPreviewRead.refetch(), positionRead.refetch(), ownerScan.refetch()])
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  if (!detf) return null

  const blockedCopy = !isConnected
    ? 'Connect a wallet to sign.'
    : !walletMatches
      ? `Switch the wallet to chain ${chainId}.`
      : null

  return (
    <Card id="detf-actions" data-testid="detf-actions">
      <p className="text-[11px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">Use this DETF</p>
      <h3 className="mt-1 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">
        Mint, burn, bond, stake, claim
      </h3>
      <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
        {archived
          ? `New minting and bonds are off on this archived DETF. Existing funded positions can claim available sDETF and unstake it for DETF.`
          : `Exchange accepted tokens for ${detfSymbol}, or bond to purchase discounted DETF that stays staked while it vests. Claim vested principal and staking rewards as sDETF. Unstake sDETF for an equal amount of DETF.`}

      </p>

      <div className="mt-4">
        <Tabs
          tabs={[
            { id: 'mint', label: 'Mint' },
            { id: 'burn', label: 'Burn' },
            { id: 'bond', label: 'Bond' },
            { id: 'stake', label: 'Stake' },
            { id: 'claim', label: 'Claim bond' },
          ]}
          active={tab}
          onChange={(id) => {
            if (isInsightsActionTab(id)) setTab(id)
          }}
        />
      </div>

      {tab === 'mint' || tab === 'bond' || tab === 'burn' ? (
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          {tab === 'burn' ? 'Receive' : 'Pay with'}
          <select
            className={inputClass}
            value={tokenAddr}
            onChange={(e) => setToken(e.target.value)}
            data-testid="detf-action-token"
          >
            {payTokens.length === 0 ? (
              <option value="">Reading tokens…</option>
            ) : (
              payTokens.map((t) => (
                <option key={t.address} value={t.address}>
                  {isEthPay(t.address) ? 'ETH' : tab === 'bond' && addressesMatch(t.address, reserveLp) ? 'Reserve LP' : actionTokenOptionLabel(t, vaultShare)}
                </option>
              ))
            )}
          </select>
          <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
            Tokens supported by this route.
            {tab === 'burn'
              ? platform.weth
                ? ' ETH unwraps WETH after the burn.'
                : ''
              : platform.weth
                ? ' ETH wraps to WETH, then this DETF takes WETH.'
                : ''}
          </span>
        </label>
      ) : null}

      <TabPanel when="burn" active={tab}>
        <AmountField
          className="mt-4"
          label="Burn"
          symbol={detfSymbol}
          value={burnAmount}
          onChange={setBurnAmount}
          decimals={detfDecimals}
          balance={typeof detfBal === 'bigint' ? detfBal : undefined}
          data-testid="detf-burn-amount"
        />
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Preview:{' '}
          {burnPreview != null
            ? `${formatUnits(burnPreview, decimals)} ${payEth ? 'ETH' : tokenMeta?.symbol ?? ''}`
            : '—'}
          . The transaction uses a fresh quote with a 1% minimum-output allowance.
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        {reserveLive === false ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            This DETF is inert until the first bond.
          </p>
        ) : (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            When primary burning is outside its price threshold, this route swaps DETF through the reserve pool.
          </p>
        )}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApproveDetf ? (
            <Button
              type="button"
              onClick={() => void approveDetf()}
              disabled={!canBurn || parsedBurn == null || parsedBurn <= 0n}
              loading={pendingLeg === 'approve'}
              data-testid="detf-burn-approve"
            >
              Approve {detfSymbol}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void burn()}
              disabled={!canBurn || parsedBurn == null || parsedBurn <= 0n || !spendToken}
              loading={pendingLeg === 'burn'}
              data-testid="detf-burn"
            >
              Burn {detfSymbol}
            </Button>
          )}
        </div>
      </TabPanel>

      <TabPanel when="mint" active={tab}>
        <AmountField
          className="mt-4"
          label="Pay"
          symbol={tokenMeta?.symbol}
          value={amount}
          onChange={setAmount}
          decimals={decimals}
          balance={typeof balance === 'bigint' ? balance : undefined}
          data-testid="detf-mint-amount"
        />
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Preview: {preview != null ? `${formatUnits(preview, detfDecimals)} ${detfSymbol}` : '—'}
          . The transaction uses a fresh quote with a 1% minimum-output allowance.
        </p>
        {archived ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="detf-mint-archived">
            Mint is off on this archived DETF.
          </p>
        ) : blockedCopy ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button
              type="button"
              onClick={() => void approve()}
              disabled={!canMintOrBond || parsed == null || parsed <= 0n}
              loading={pendingLeg === 'approve'}
              data-testid="detf-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void mint()}
              disabled={!canMintOrBond || reserveLive !== true || parsed == null || parsed <= 0n || !spendToken}
              loading={pendingLeg === 'mint'}
              data-testid="detf-mint"
            >
              Mint {detfSymbol}
            </Button>
          )}
        </div>
      </TabPanel>

      <TabPanel when="bond" active={tab}>
        <AmountField
          className="mt-4"
          label="Lock"
          symbol={tokenMeta?.symbol}
          value={amount}
          onChange={setAmount}
          decimals={decimals}
          balance={typeof balance === 'bigint' ? balance : undefined}
          data-testid="detf-bond-amount"
        />
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          Lock (days)
          <input
            className={`${inputClass} font-mono`}
            value={lockDays}
            onChange={(e) => setLockDays(e.target.value)}
            onFocus={() => setLockBlurred(false)}
            onBlur={() => setLockBlurred(true)}
            aria-invalid={lockBlurred && oracleLock == null}
            inputMode="numeric"
            data-testid="detf-bond-days"
          />
        </label>
        {lockBlurred && oracleLock == null ? (
          <p className="mt-1 text-sm" role="alert" data-testid="detf-bond-lock-error">
            Enter a whole number of days from {minDays} to {maxDays}.
          </p>
        ) : null}
        <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Minimum {minDays} days. Maximum {maxDays} days. Principal unlocks continuously over the selected period.
          Staking rewards can be claimed while principal is still vesting.
        </p>
        {oracleLock != null && bondPreview && !bondPreviewError ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="detf-bond-preview">
            Purchase preview: {formatUnits(bondPreview[1], 9)} DETF, staked throughout the vesting period.
          </p>
        ) : null}
        {oracleLock != null && bondPreviewError ? (
          <div className="mt-2 text-sm" role="alert" data-testid="detf-bond-quote-error">
            <p>{parseContractError(bondPreviewError)}</p>
            {isPoolInputLimitError(bondPreviewError) ? (
              <Button type="button" onClick={() => void findSmallerBond()} loading={findingBondAmount}
                disabled={findingBondAmount || pendingLeg != null} data-testid="detf-bond-smaller">
                Find a smaller amount
              </Button>
            ) : null}
          </div>
        ) : null}
        {payEth ? (
          <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
            ETH payment requires wrapping, approval if needed, and a separate bond transaction. Only “Bond confirmed” means your bond was purchased.
          </p>
        ) : null}
        {payingReserveLp ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            The whole LP position stays in the reserve. Only its non-DETF assets determine your bond purchase;
            DETF already contained in the LP is excluded from the purchase price.
          </p>
        ) : null}
        {archived ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="detf-bond-archived">
            Bond is off on this archived DETF.
          </p>
        ) : blockedCopy ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button
              type="button"
              onClick={() => void approve()}
              disabled={!canMintOrBond || parsed == null || parsed <= 0n || !bondQuoteReady}
              loading={pendingLeg === 'approve'}
              data-testid="detf-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void bond()}
              disabled={!canMintOrBond || parsed == null || parsed <= 0n || oracleLock == null || !spendToken || !bondQuoteReady}
              loading={pendingLeg === 'bond'}
              data-testid="detf-bond"
            >
              Bond {tokenMeta?.symbol ?? ''}
            </Button>
          )}
        </div>
      </TabPanel>

      <TabPanel when="stake" active={tab}>
        <div className="mt-4">
          <DetfStaking
            detf={detf}
            detfSymbol={detfSymbol}
            claimToken={claimToken}
            claimSymbol={claimSymbol || 'sDETF'}
            pairTokens={pairTokens}
            vaultShare={vaultShare}
            weth={platform.weth}
            chainId={chainId}
            reserveLive={reserveLive}
          />
        </div>
      </TabPanel>

      <TabPanel when="claim" active={tab}>
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          Bond token ID
          <input
            className={`${inputClass} font-mono`}
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            placeholder="3"
            data-testid="detf-claim-id"
          />
        </label>
        {ownedIds.length > 0 ? (
          <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="detf-claim-owned">
            Your bonds:{' '}
            {ownedIds.map((id) => (
              <button
                key={id.toString()}
                type="button"
                className="mr-1 font-mono text-[var(--accent,#4FD44B)] underline-offset-2 hover:underline"
                onClick={() => setTokenId(id.toString())}
              >
                #{id.toString()}
              </button>
            ))}
          </p>
        ) : address && tab === 'claim' && ownerScan.isFetched ? (
          <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="detf-claim-owned">
            No owned bonds found in this scan. Enter a bond ID or use Portfolio to discover older positions.
          </p>
        ) : null}
        <div className="mt-3 space-y-1.5 text-sm text-[var(--text-primary,#EDEDED)]">
          <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1" data-testid="detf-claim-owner">
            <span className="text-[var(--text-muted,#9aa3b2)]">Owner</span>
            {parsedId === undefined ? (
              <span className="text-xs text-[var(--text-muted,#9aa3b2)]">Enter a bond token ID.</span>
            ) : ownerAddr ? (
              <AddressLink chainId={chainId} address={ownerAddr} display="full" />
            ) : ownerReading ? (
              <span className="text-xs text-[var(--text-muted,#9aa3b2)]">Reading…</span>
            ) : ownerReadFailed || !nftVault ? (
              <span className="text-xs text-[var(--text-muted,#9aa3b2)]">
                {nftVault ? 'No bond with that ID.' : 'Bond NFT vault not found on this DETF.'}
              </span>
            ) : (
              <span className="text-xs text-[var(--text-muted,#9aa3b2)]">No bond with that ID.</span>
            )}
          </div>
          {parsedId !== undefined && parsedId < 3n ? <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
            Fee and creator receipts arrive directly as sDETF in the NFT owner’s wallet when rewards are funded.
          </p> : <>
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
              Principal available: {claimPreview ? `${formatUnits(claimPreview.principalDue, 9)} sDETF` : '—'}
            </p>
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
              Staking rewards available: {pendingRewards != null ? `${formatUnits(pendingRewards, 9)} sDETF` : '—'}
            </p>
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
              {unlockTime != null && unlockTime > 0n
                ? `Vesting ends ${new Date(Number(unlockTime) * 1000).toLocaleString()}. Principal unlocks continuously; rewards can be claimed during vesting.`
                : 'Vesting details unavailable.'}
            </p>
            {claimPreviewRead.isError ? <p className="text-xs text-[var(--text-muted,#9aa3b2)]">Unable to read this funded bond’s claim amounts.</p> : null}
          </>}
          {ownerAddr && address ? (
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
              {ownsBond ? 'This wallet owns this bond.' : 'This wallet does not own that bond.'}
            </p>
          ) : null}
        </div>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <label className="mt-3 block text-sm text-[var(--text-primary,#EDEDED)]">
          Claim
          <select className={inputClass} value={claimKind}
            onChange={(event) => setClaimKind(event.target.value as typeof claimKind)}>
            <option value="claimBond">Available principal and rewards</option>
            <option value="claimPrincipal">Vested principal only</option>
            <option value="claimRewards">Staking rewards only</option>
          </select>
        </label>
        <Button
          type="button"
          className="mt-4"
          onClick={() => void claim()}
          disabled={!canClaim}
          loading={pendingLeg === 'claim'}
          title={claimBlocked ?? undefined}
          data-testid="detf-claim"
        >
          Claim sDETF
        </Button>
      </TabPanel>

      {status ? (
        <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="detf-action-status">
          {status}
        </p>
      ) : null}
    </Card>
  )
}
