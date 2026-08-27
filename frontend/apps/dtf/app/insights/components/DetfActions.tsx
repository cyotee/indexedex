'use client'

import { useEffect, useMemo, useState } from 'react'
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
import { isFunctionNotFound } from '../../lib/detf/bondNftVault'
import { parseContractError } from '../../lib/tx/parseContractError'
import { isArchivedDetf } from '../lib/archivedDetfs'
import { isInsightsActionTab } from '../lib/insightsHref'
import { bondNftAbi, insightsViewAbi } from '../lib/insightsAbi'
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
import { lockSecondsFromDays, MIN_LOCK_DAYS } from '../lib/lockSeconds'
import { actionTokenOptionLabel, type ActionToken } from '../lib/actionTokens'
import { DetfStaking } from './DetfStaking'

export type { ActionToken }

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

function deadline(): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + 20 * 60)
}

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
  burningAllowed,
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
  burningAllowed?: boolean
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
  const [lockDays, setLockDays] = useState(String(MIN_LOCK_DAYS))
  const [tokenId, setTokenId] = useState('')
  const [status, setStatus] = useState('')
  const [pendingLeg, setPendingLeg] = useState<'approve' | 'mint' | 'bond' | 'claim' | 'burn' | null>(null)
  const [approvedSpend, setApprovedSpend] = useState(0n)
  const [approvedDetfSpend, setApprovedDetfSpend] = useState(0n)

  const payTokens = useMemo(
    () =>
      withEthPayOption(pairTokens, platform.weth, { address: ETH_PAY, symbol: 'ETH' }),
    [pairTokens, platform.weth],
  )

  useEffect(() => {
    if (payTokens.length === 0) return
    const ok = payTokens.some((t) => t.address.toLowerCase() === token.toLowerCase())
    if (!ok) setToken(payTokens[0]!.address)
  }, [payTokens, token])

  const tokenAddr = (token || payTokens[0]?.address || '') as `0x${string}` | ''
  const tokenMeta = payTokens.find((t) => t.address.toLowerCase() === tokenAddr.toLowerCase()) ?? payTokens[0]
  const payEth = isEthPay(tokenAddr)
  const spendToken = settlePayToken(tokenAddr, platform.weth)

  useEffect(() => {
    setApprovedSpend(0n)
    setApprovedDetfSpend(0n)
  }, [tokenAddr, detf, address])

  const { data: tokenDecimals } = useReadContract({
    address: payEth ? undefined : tokenAddr || undefined,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: !!tokenAddr && !payEth },
  })
  const decimals = payEth || tokenDecimals == null ? 18 : Number(tokenDecimals)
  const parsed = parseAmount(amount, decimals)
  const lock = lockSecondsFromDays(lockDays)
  const parsedId = useMemo(() => parseBondTokenId(tokenId), [tokenId])

  const { data: ethBal } = useBalance({
    address,
    chainId,
    query: { enabled: payEth && !!address },
  })
  const { data: erc20Bal } = useReadContract({
    address: payEth ? undefined : tokenAddr || undefined,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!tokenAddr && !!address && !payEth },
  })
  const balance = payEth ? ethBal?.value : erc20Bal
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: spendToken || undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf && spendToken ? [address, detf] : undefined,
    query: { enabled: !!spendToken && !!address && !!detf },
  })
  const { data: oracleTerms } = useReadContract({
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

  useEffect(() => {
    const n = Number(lockDays)
    if (!Number.isFinite(n) || n < minDays || n > maxDays) {
      setLockDays(String(minDays))
    }
  }, [minDays, maxDays, lockDays])
  const { data: preview } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'previewExchangeIn',
    args: parsed && spendToken && detf ? [spendToken, parsed, detf] : undefined,
    query: { enabled: tab === 'mint' && !!detf && !!spendToken && parsed != null && parsed > BigInt(0) },
  })
  const { data: detfDecimalsRaw } = useReadContract({
    address: detf,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: !!detf },
  })
  const detfDecimals = detfDecimalsRaw == null ? 18 : Number(detfDecimalsRaw)
  const parsedBurn = parseAmount(burnAmount, detfDecimals)
  const burnLive = reserveLive !== false && burningAllowed !== false
  const { data: detfBal } = useReadContract({
    address: detf,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: tab === 'burn' && !!detf && !!address },
  })
  const { data: detfAllowance, refetch: refetchDetfAllowance } = useReadContract({
    address: detf,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf ? [address, detf] : undefined,
    query: { enabled: tab === 'burn' && !!detf && !!address },
  })
  const { data: burnPreview } = useReadContract({
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
  const { data: nextTokenIdRaw } = useReadContract({
    chainId,
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'nextTokenId',
    query: { enabled: tab === 'claim' && !!nftVault, retry: 0 },
  })
  const scanCount = bondIdScanCount(typeof nextTokenIdRaw === 'bigint' ? nextTokenIdRaw : undefined)
  const ownerScanContracts = useMemo(() => {
    if (tab !== 'claim' || !nftVault) return []
    return Array.from({ length: scanCount }, (_, i) => ({
      address: nftVault,
      abi: bondNftAbi,
      functionName: 'ownerOf' as const,
      args: [BigInt(i + 1)] as const,
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

  const claimReadsOn =
    tab === 'claim' && !!nftVault && parsedId !== undefined

  const { data: pendingRewards } = useReadContract({
    chainId,
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'pendingRewards',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: claimReadsOn, retry: 0 },
  })
  const { data: ownerOf, isError: ownerReadFailed, isFetching: ownerReading } = useReadContract({
    chainId,
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'ownerOf',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: claimReadsOn, retry: 0 },
  })
  const { data: unlockTime } = useReadContract({
    chainId,
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'unlockTimeOf',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: claimReadsOn, retry: 0 },
  })
  const ownerAddr = bondOwnerAddress(typeof ownerOf === 'string' ? ownerOf : undefined)
  const ownsBond = addressesMatch(ownerAddr, address)
  const unlock = bondUnlockState(
    typeof unlockTime === 'bigint' ? unlockTime : undefined,
    Math.floor(Date.now() / 1000),
  )
  const canClaim = claimRewardsButtonEnabled({
    canSign: isConnected && walletMatches && !!detf && !!address && pendingLeg == null,
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
  const canSign = isConnected && walletMatches && !!detf && !!address && pendingLeg == null
  const canMintOrBond = canSign && !archived
  const canBurn = canSign && burnLive
  const oracleLock = lockSecondsFromNumber(clampLockDays(lockDays, minDays, maxDays) ?? minDays)

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
    if (publicClient) {
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      if (receipt.status === 'reverted') throw new Error('Transaction reverted')
      setStatus(`${label} confirmed.`)
    }
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
    if (archived || !detf || !spendToken || parsed == null || !address) return
    setPendingLeg('approve')
    setStatus('')
    try {
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
    if (!detf || !spendToken || parsedBurn == null || !address) return
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
      const minOut =
        burnPreview != null && burnPreview > BigInt(0)
          ? (burnPreview * BigInt(99)) / BigInt(100)
          : BigInt(0)
      const args = [detf, parsedBurn, spendToken, minOut, address, false, deadline()] as const
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
    if (archived || !detf || !spendToken || parsed == null || !address) return
    setPendingLeg('mint')
    setStatus('')
    try {
      await wrapEth()
      if (payEth) await approveWethIfNeeded()
      const minOut =
        preview != null && preview > BigInt(0) ? (preview * BigInt(99)) / BigInt(100) : BigInt(0)
      const args = [spendToken, parsed, detf, minOut, address, false, deadline()] as const
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

  async function bond() {
    if (archived || !detf || !spendToken || parsed == null || !address) return
    setPendingLeg('bond')
    setStatus('')
    try {
      await wrapEth()
      if (payEth) await approveWethIfNeeded()
      const hash = await writeOnWallet({
        account: address,
        address: detf,
        abi: insightsViewAbi,
        functionName: 'bond',
        args: [spendToken, parsed, oracleLock, address, false, deadline()],
      })
      await wait(hash, 'Bond')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function claim() {
    if (!address || parsedId === undefined) return
    const attempts: { address: `0x${string}`; abi: typeof insightsViewAbi | typeof bondNftAbi }[] = []
    if (detf) attempts.push({ address: detf, abi: insightsViewAbi })
    if (nftVault && (!detf || nftVault.toLowerCase() !== detf.toLowerCase())) {
      attempts.push({ address: nftVault, abi: bondNftAbi })
    }
    if (attempts.length === 0) return
    setPendingLeg('claim')
    setStatus('')
    try {
      const args = [parsedId, address] as const
      let lastError: unknown
      for (let i = 0; i < attempts.length; i++) {
        const attempt = attempts[i]!
        try {
          if (publicClient) {
            await publicClient.simulateContract({
              account: address,
              address: attempt.address,
              abi: attempt.abi,
              functionName: 'claimRewards',
              args,
            })
          }
          const hash = await writeOnWallet({
            account: address,
            address: attempt.address,
            abi: attempt.abi,
            functionName: 'claimRewards',
            args,
          })
          await wait(hash, 'Claim rewards')
          lastError = undefined
          break
        } catch (e) {
          lastError = e
          if (i < attempts.length - 1 && isFunctionNotFound(e)) continue
          throw e
        }
      }
      if (lastError) throw lastError
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
          ? `Mint and bond are off on this archived DETF. Burn pays ${detfSymbol} and returns a token from the list. Stake mints the rebasing claim token. Claim takes DETF that accrued to a bond.`
          : `Mint pays a token this DETF accepts and receives ${detfSymbol}. Burn pays ${detfSymbol} and
        returns a token from that list. Bond locks from the same list. Stake mints the rebasing
        claim token. That is not minting ${detfSymbol}. Claim takes DETF that accrued to a bond.
        You can claim while the bond is still locked. Claiming is not cashing the bond out.`}
      </p>

      <div className="mt-4">
        <Tabs
          tabs={[
            { id: 'mint', label: 'Mint' },
            { id: 'burn', label: 'Burn' },
            { id: 'bond', label: 'Bond' },
            { id: 'stake', label: 'Stake' },
            { id: 'claim', label: 'Claim rewards' },
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
                  {isEthPay(t.address) ? 'ETH' : actionTokenOptionLabel(t, vaultShare)}
                </option>
              ))
            )}
          </select>
          <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
            Pair token, vault token, and the tokens in the vault.
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
          . Preview is a quote, not a guarantee the reserve can pay that token out.
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        {reserveLive === false ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            This DETF is inert until the first bond.
          </p>
        ) : burningAllowed === false ? (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            Burn is blocked. Policy burn is allowed when the contract price is below the burn line.
          </p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApproveDetf ? (
            <Button
              type="button"
              onClick={() => void approveDetf()}
              disabled={!canBurn || parsedBurn == null}
              loading={pendingLeg === 'approve'}
              data-testid="detf-burn-approve"
            >
              Approve {detfSymbol}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void burn()}
              disabled={!canBurn || parsedBurn == null || !spendToken}
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
          Preview: {preview != null ? `${formatUnits(preview, 18)} ${detfSymbol}` : '—'}
          . Preview is a quote, not a guarantee the reserve can take the token in.
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
              disabled={!canMintOrBond || parsed == null}
              loading={pendingLeg === 'approve'}
              data-testid="detf-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void mint()}
              disabled={!canMintOrBond || parsed == null || !spendToken}
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
            inputMode="numeric"
            data-testid="detf-bond-days"
          />
        </label>
        <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Minimum {minDays} days. Maximum {maxDays} days. Set by the vault fee oracle. You cannot cash
          the bond principal until it matures.
        </p>
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
              disabled={!canMintOrBond || parsed == null}
              loading={pendingLeg === 'approve'}
              data-testid="detf-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void bond()}
              disabled={!canMintOrBond || parsed == null || lock == null || !spendToken}
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
            claimSymbol={claimSymbol || 'claim'}
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
            placeholder="1"
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
            No bonds found for this wallet on this DETF.
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
          <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
            Pending:{' '}
            {pendingRewards != null ? `${formatUnits(pendingRewards, 18)} ${detfSymbol}` : '—'}
            . The owner can claim even if pending is 0.
          </p>
          <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
            {unlock.locked === true && typeof unlockTime === 'bigint'
              ? `Locked until ${new Date(Number(unlockTime) * 1000).toLocaleString()}. You can still claim rewards.`
              : unlock.locked === false && typeof unlockTime === 'bigint'
                ? `Unlocked ${new Date(Number(unlockTime) * 1000).toLocaleString()}.`
                : 'Lock time: —'}
          </p>
          {ownerAddr && address ? (
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
              {ownsBond ? 'This wallet owns this bond.' : 'This wallet does not own that bond.'}
            </p>
          ) : null}
        </div>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <Button
          type="button"
          className="mt-4"
          onClick={() => void claim()}
          disabled={!canClaim}
          loading={pendingLeg === 'claim'}
          title={claimBlocked ?? undefined}
          data-testid="detf-claim"
        >
          Claim rewards
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
