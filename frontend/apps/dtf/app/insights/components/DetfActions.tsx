'use client'

import { useEffect, useMemo, useState } from 'react'
import { erc20Abi, formatUnits, parseUnits } from 'viem'
import { useAccount, useBalance, usePublicClient, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'

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
import { ETH_PAY, WETH9_DEPOSIT_ABI, isEthPay, settlePayToken, withEthPayOption } from '../../lib/ethPay'
import { parseContractError } from '../../lib/tx/parseContractError'
import { bondNftAbi, insightsViewAbi } from '../lib/insightsAbi'
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
  initialTab,
  explorer,
}: {
  detf?: `0x${string}`
  detfSymbol: string
  pairTokens: ActionToken[]
  vaultShare?: `0x${string}` | null
  chainId: number
  claimToken?: `0x${string}`
  claimSymbol?: string
  reserveLive?: boolean
  initialTab?: string
  explorer?: string
}) {
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const publicClient = usePublicClient({ chainId })
  const { writeContractAsync } = useWriteContract()
  const { switchChainAsync } = useSwitchChain()
  const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
  const walletMatches = isConnected && (walletChainId === chainId || localWallet)
  const platform = useMemo(() => resolveSePlatform(chainId, environment), [chainId, environment])

  const [tab, setTab] = useState(() =>
    initialTab === 'stake' || initialTab === 'bond' || initialTab === 'claim' || initialTab === 'mint'
      ? initialTab
      : 'mint',
  )

  useEffect(() => {
    if (
      initialTab === 'stake' ||
      initialTab === 'bond' ||
      initialTab === 'claim' ||
      initialTab === 'mint'
    ) {
      setTab(initialTab)
    }
  }, [initialTab])
  const [token, setToken] = useState<string>(pairTokens[0]?.address ?? '')
  const [amount, setAmount] = useState('')
  const [lockDays, setLockDays] = useState(String(MIN_LOCK_DAYS))
  const [tokenId, setTokenId] = useState('')
  const [status, setStatus] = useState('')
  const [pendingLeg, setPendingLeg] = useState<'approve' | 'mint' | 'bond' | 'claim' | null>(null)
  const [approvedSpend, setApprovedSpend] = useState(0n)

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
  const parsedId = useMemo(() => {
    try {
      if (!tokenId.trim()) return undefined
      return BigInt(tokenId.trim())
    } catch {
      return undefined
    }
  }, [tokenId])

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
  const { data: bondVault } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'bondNftVault',
    query: { enabled: !!detf },
  })
  const { data: protocolVault } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'protocolNFTVault',
    query: { enabled: !!detf },
  })
  const nftVault =
    bondVault && !isZero(bondVault) ? bondVault : protocolVault && !isZero(protocolVault) ? protocolVault : undefined

  const { data: pendingRewards } = useReadContract({
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'pendingRewards',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: tab === 'claim' && !!nftVault && parsedId !== undefined },
  })
  const { data: ownerOf } = useReadContract({
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'ownerOf',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: tab === 'claim' && !!nftVault && parsedId !== undefined },
  })

  const covered = allowance != null && allowance >= (parsed ?? 0n) ? allowance : approvedSpend
  const needApprove = !payEth && parsed != null && parsed > 0n && covered < parsed
  const canSign = isConnected && walletMatches && !!detf && !!address && pendingLeg == null
  const oracleLock = lockSecondsFromNumber(clampLockDays(lockDays, minDays, maxDays) ?? minDays)

  async function writeOnWallet(params: Parameters<typeof writeContractAsync>[0]) {
    if (typeof walletChainId === 'number' && walletChainId !== chainId && !localWallet) {
      await switchChainAsync({ chainId })
    }
    const { chain: _chain, chainId: _cid, ...rest } = params as typeof params & {
      chain?: unknown
      chainId?: number
    }
    return writeContractAsync(localWallet ? rest : params)
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
    if (!detf || !spendToken || parsed == null || !address) return
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

  async function mint() {
    if (!detf || !spendToken || parsed == null || !address) return
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
    if (!detf || !spendToken || parsed == null || !address) return
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
    const target = nftVault ?? detf
    if (!target) return
    setPendingLeg('claim')
    setStatus('')
    try {
      const hash = await writeOnWallet({
        account: address,
        address: target,
        abi: bondNftAbi,
        functionName: 'claimRewards',
        args: [parsedId, address],
      })
      await wait(hash, 'Claim rewards')
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
      <h3 className="mt-1 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Mint, bond, stake, claim</h3>
      <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
        Mint pays a token this DETF accepts and receives {detfSymbol}. Bond locks from the same
        list. Stake mints the rebasing claim token. That is not minting {detfSymbol}. Claim takes
        DETF that accrued to a bond. Claiming is not cashing the bond out.
      </p>

      <div className="mt-4">
        <Tabs
          tabs={[
            { id: 'mint', label: 'Mint' },
            { id: 'bond', label: 'Bond' },
            { id: 'stake', label: 'Stake' },
            { id: 'claim', label: 'Claim rewards' },
          ]}
          active={tab}
          onChange={setTab}
        />
      </div>

      {tab === 'mint' || tab === 'bond' ? (
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          Pay with
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
            {platform.weth ? ' ETH wraps to WETH, then this DETF takes WETH.' : ''}
          </span>
        </label>
      ) : null}

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
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button
              type="button"
              onClick={() => void approve()}
              disabled={!canSign || parsed == null}
              loading={pendingLeg === 'approve'}
              data-testid="detf-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void mint()}
              disabled={!canSign || parsed == null || !spendToken}
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
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button
              type="button"
              onClick={() => void approve()}
              disabled={!canSign || parsed == null}
              loading={pendingLeg === 'approve'}
              data-testid="detf-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void bond()}
              disabled={!canSign || parsed == null || lock == null || !spendToken}
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
            explorer={explorer}
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
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Pending: {pendingRewards != null ? `${formatUnits(pendingRewards, 18)} ${detfSymbol}` : '—'}
          {ownerOf && address && ownerOf.toLowerCase() !== address.toLowerCase()
            ? '. This wallet does not own that bond.'
            : ''}
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <Button
          type="button"
          className="mt-4"
          onClick={() => void claim()}
          disabled={!canSign || parsedId === undefined}
          loading={pendingLeg === 'claim'}
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
