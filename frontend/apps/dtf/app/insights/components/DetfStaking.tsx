'use client'

import { useEffect, useMemo, useState } from 'react'
import { erc20Abi, formatUnits, parseUnits } from 'viem'
import { useAccount, useBalance, usePublicClient, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'

import { AmountField } from '../../components/ui/AmountField'
import { Button } from '../../components/ui/Button'
import { Tabs, TabPanel } from '../../components/ui/Tabs'
import {
  ETH_PAY,
  WETH9_DEPOSIT_ABI,
  type EthWrapWrite,
  isEthPay,
  settlePayToken,
  withEthPayOption,
} from '../../lib/ethPay'
import { parseContractError } from '../../lib/tx/parseContractError'
import { actionTokenOptionLabel, type ActionToken } from '../lib/actionTokens'
import { diamondLoupeAbi, insightsViewAbi, rebasingClaimAbi } from '../lib/insightsAbi'
import {
  BUY_CLAIM_SELECTOR,
  DEPOSIT_CLAIM_SELECTOR,
  collectStakeTokenAddresses,
  formatTokenAmount,
  resolveClaimMintPath,
} from '../lib/claimMint'
import { shortAddr } from '../lib/tokenLabels'

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

export function DetfStaking({
  detf,
  detfSymbol,
  claimToken,
  claimSymbol,
  pairTokens,
  vaultShare,
  weth,
  chainId,
  reserveLive,
  explorer,
}: {
  detf?: `0x${string}`
  detfSymbol: string
  claimToken?: `0x${string}`
  claimSymbol: string
  pairTokens: ActionToken[]
  vaultShare?: `0x${string}` | null
  weth?: `0x${string}` | null
  chainId: number
  reserveLive?: boolean
  explorer?: string
}) {
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const publicClient = usePublicClient({ chainId })
  const { writeContractAsync } = useWriteContract()
  const { switchChainAsync } = useSwitchChain()
  const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
  const walletMatches = isConnected && (walletChainId === chainId || localWallet)

  const [tab, setTab] = useState('stake')
  const [token, setToken] = useState('')
  const [amount, setAmount] = useState('')
  const [status, setStatus] = useState('')
  const [pendingLeg, setPendingLeg] = useState<'approve' | 'stake' | 'unstake' | null>(null)
  const [approvedSpend, setApprovedSpend] = useState(0n)

  const { data: depositFacet } = useReadContract({
    address: detf,
    abi: diamondLoupeAbi,
    functionName: 'facetAddress',
    args: [DEPOSIT_CLAIM_SELECTOR],
    query: { enabled: !!detf, retry: 0 },
  })
  const { data: buyFacet } = useReadContract({
    address: detf,
    abi: diamondLoupeAbi,
    functionName: 'facetAddress',
    args: [BUY_CLAIM_SELECTOR],
    query: { enabled: !!detf, retry: 0 },
  })
  const { data: weightedM } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'm',
    query: { enabled: !!detf, retry: 0 },
  })
  const path = resolveClaimMintPath({
    depositClaimFacet: depositFacet,
    buyClaimFacet: buyFacet,
    weighted: (weightedM != null && Number(weightedM) >= 1) || pairTokens.length > 1,
  })

  const { data: claimName } = useReadContract({
    address: claimToken,
    abi: rebasingClaimAbi,
    functionName: 'name',
    query: { enabled: !!claimToken },
  })
  const { data: claimOnchainSymbol } = useReadContract({
    address: claimToken,
    abi: rebasingClaimAbi,
    functionName: 'symbol',
    query: { enabled: !!claimToken },
  })
  const { data: claimSupply } = useReadContract({
    address: claimToken,
    abi: rebasingClaimAbi,
    functionName: 'totalSupply',
    query: { enabled: !!claimToken, refetchInterval: 15_000 },
  })
  const { data: claimBalance } = useReadContract({
    address: claimToken,
    abi: rebasingClaimAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!claimToken && !!address, refetchInterval: 15_000 },
  })

  const liveClaimSymbol = claimOnchainSymbol || (claimSymbol && claimSymbol !== 'claim' ? claimSymbol : '')
  const claimLabel = liveClaimSymbol || 'claim token'

  const stakeAddrs = useMemo(
    () =>
      collectStakeTokenAddresses({
        path,
        detf,
        actionTokens: pairTokens.map((t) => t.address),
      }),
    [path, detf, pairTokens],
  )
  const stakeTokens: ActionToken[] = useMemo(() => {
    const listed = stakeAddrs.map((addr) => {
      if (detf && addr.toLowerCase() === detf.toLowerCase()) {
        return { address: addr, symbol: detfSymbol }
      }
      const known = pairTokens.find((t) => t.address.toLowerCase() === addr.toLowerCase())
      return known ?? { address: addr, symbol: addr.slice(0, 6) }
    })
    return path === 'depositClaim'
      ? withEthPayOption(listed, weth, { address: ETH_PAY, symbol: 'ETH' })
      : listed
  }, [stakeAddrs, detf, detfSymbol, pairTokens, path, weth])

  useEffect(() => {
    if (stakeTokens.length === 0) return
    const ok = stakeTokens.some((t) => t.address.toLowerCase() === token.toLowerCase())
    if (!ok) setToken(stakeTokens[0]!.address)
  }, [stakeTokens, token])

  const tokenAddr = (token || stakeTokens[0]?.address || '') as `0x${string}` | ''
  const tokenMeta = stakeTokens.find((t) => t.address.toLowerCase() === tokenAddr.toLowerCase()) ?? stakeTokens[0]
  const payEth = tab === 'stake' && isEthPay(tokenAddr)
  const settledIn = settlePayToken(tokenAddr, weth)

  useEffect(() => {
    setApprovedSpend(0n)
  }, [tokenAddr, detf, address, tab])

  const spendToken = tab === 'unstake' ? claimToken : payEth ? settledIn || undefined : tokenAddr || undefined
  const { data: tokenDecimals } = useReadContract({
    address: payEth ? undefined : spendToken,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: !!spendToken && !payEth },
  })
  const decimals = payEth || tokenDecimals == null ? 18 : Number(tokenDecimals)
  const parsed = parseAmount(amount, decimals)

  const { data: ethBal } = useBalance({
    address,
    chainId,
    query: { enabled: payEth && !!address },
  })
  const { data: erc20Bal } = useReadContract({
    address: payEth ? undefined : spendToken,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!spendToken && !!address && !payEth },
  })
  const balance = payEth ? ethBal?.value : erc20Bal
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: spendToken,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf ? [address, detf] : undefined,
    query: { enabled: tab === 'stake' && !!spendToken && !!address && !!detf },
  })
  const { data: previewBuy } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'previewBuyClaim',
    args: parsed && parsed > 0n ? [parsed] : undefined,
    query: {
      enabled: tab === 'stake' && path === 'buyClaim' && !!detf && parsed != null && parsed > 0n,
      retry: 0,
    },
  })
  const { data: previewRedeem } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'previewRedeemClaim',
    args: parsed && parsed > 0n && detf ? [parsed, detf] : undefined,
    query: {
      enabled: tab === 'unstake' && !!detf && parsed != null && parsed > 0n,
      retry: 0,
    },
  })

  const covered = allowance != null && allowance >= (parsed ?? 0n) ? allowance : approvedSpend
  const needApprove = !payEth && tab === 'stake' && parsed != null && parsed > 0n && covered < parsed
  const canSign = isConnected && walletMatches && !!detf && !!address && pendingLeg == null
  const inert = reserveLive === false
  const noClaim = !claimToken

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
      setStatus('Approved. Stake next.')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function stake() {
    if (!detf || !spendToken || parsed == null || !address) return
    setPendingLeg('stake')
    setStatus('')
    try {
      if (payEth && weth) {
        const wrapHash = await writeOnWallet({
          account: address,
          address: weth,
          abi: WETH9_DEPOSIT_ABI,
          functionName: 'deposit',
          value: parsed,
        })
        await wait(wrapHash, 'Wrap')
        const coveredNow = allowance != null && allowance >= parsed ? allowance : approvedSpend
        if (coveredNow < parsed) {
          const appr = await writeOnWallet({
            account: address,
            address: spendToken,
            abi: erc20Abi,
            functionName: 'approve',
            args: [detf, parsed],
          })
          await wait(appr, 'Approve')
          setApprovedSpend(parsed)
          await refetchAllowance()
        }
      }
      const minOut = previewBuy != null && previewBuy > 0n ? (previewBuy * 99n) / 100n : 0n
      const hash =
        path === 'buyClaim'
          ? await writeOnWallet({
              account: address,
              address: detf,
              abi: insightsViewAbi,
              functionName: 'buyClaim',
              args: [parsed, minOut, address, false, deadline()],
            })
          : await writeOnWallet({
              account: address,
              address: detf,
              abi: insightsViewAbi,
              functionName: 'depositClaim',
              args: [spendToken, parsed, minOut, address, false, deadline()],
            })
      await wait(hash, 'Stake')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }

  async function unstake() {
    if (!detf || parsed == null || !address) return
    setPendingLeg('unstake')
    setStatus('')
    try {
      const minOut = previewRedeem != null && previewRedeem > 0n ? (previewRedeem * 99n) / 100n : 0n
      const hash = await writeOnWallet({
        account: address,
        address: detf,
        abi: insightsViewAbi,
        functionName: 'redeemClaim',
        args: [parsed, detf, minOut, address, deadline()],
      })
      await wait(hash, 'Unstake')
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
      : inert
        ? 'Staking opens after the first bond. The reserve is still inert.'
        : noClaim
          ? 'This DETF has no claim token yet.'
          : null

  const buyClaimOnly = path === 'buyClaim'

  return (
    <div data-testid="detf-staking">
      <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
        Stake pays {buyClaimOnly ? detfSymbol : `a token this DETF accepts, or ${detfSymbol}`} and
        mints the rebasing claim token. That is not minting {detfSymbol}. Unstake burns claim and
        pays {detfSymbol}. Amounts are not guaranteed.
      </p>

      {claimToken ? (
        <div className="mt-4 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] p-3" data-testid="insights-claim-card">
          <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
            Claim token
          </p>
          <p className="mt-1 text-sm text-[var(--text-primary,#EDEDED)]">
            {claimLabel}
            {claimName ? <span className="text-[var(--text-muted,#9aa3b2)]"> · {claimName}</span> : null}
          </p>
          <p className="mt-2 font-mono text-[11px] text-[var(--text-muted,#9aa3b2)]">
            Supply {formatTokenAmount(claimSupply)}
            {' · '}
            You hold{' '}
            {claimBalance != null ? formatTokenAmount(claimBalance) : isConnected ? '0' : 'Connect to see'}
            {explorer ? (
              <>
                {' · '}
                <a
                  href={`${explorer}/address/${claimToken}`}
                  className="underline-offset-2 hover:underline"
                  target="_blank"
                  rel="noreferrer"
                  data-testid="insights-claim-address"
                >
                  {shortAddr(claimToken)}
                </a>
              </>
            ) : (
              <> · {shortAddr(claimToken)}</>
            )}
          </p>
        </div>
      ) : (
        <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="insights-claim-card">
          {inert ? 'Claim token appears after the first bond.' : 'This DETF has no claim token yet.'}
        </p>
      )}

      <div className="mt-4">
        <Tabs
          tabs={[
            { id: 'stake', label: 'Stake' },
            { id: 'unstake', label: 'Unstake' },
          ]}
          active={tab}
          onChange={setTab}
        />
      </div>

      <TabPanel when="stake" active={tab}>
        {buyClaimOnly ? (
          <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
            This DETF mints claim from {detfSymbol} only. Mint first if you hold a pair or vault
            token.
          </p>
        ) : (
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Pay with
            <select
              className={inputClass}
              value={tokenAddr}
              onChange={(e) => setToken(e.target.value)}
              data-testid="detf-stake-token"
            >
              {stakeTokens.length === 0 ? (
                <option value="">Reading tokens…</option>
              ) : (
                stakeTokens.map((t) => (
                  <option key={t.address} value={t.address}>
                    {isEthPay(t.address)
                      ? 'ETH'
                      : detf && t.address.toLowerCase() === detf.toLowerCase()
                        ? t.symbol
                        : actionTokenOptionLabel(t, vaultShare)}
                  </option>
                ))
              )}
            </select>
          </label>
        )}
        <AmountField
          className="mt-4"
          label="Pay"
          symbol={buyClaimOnly ? detfSymbol : tokenMeta?.symbol}
          value={amount}
          onChange={setAmount}
          decimals={decimals}
          balance={typeof balance === 'bigint' ? balance : undefined}
          data-testid="detf-stake-amount"
        />
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Preview:{' '}
          {previewBuy != null
            ? `${formatUnits(previewBuy, 18)} ${claimLabel}`
            : 'No quote. The contract mints claim after it joins the reserve.'}
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button
              type="button"
              onClick={() => void approve()}
              disabled={!canSign || parsed == null || inert || noClaim}
              loading={pendingLeg === 'approve'}
              data-testid="detf-stake-approve"
            >
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void stake()}
              disabled={!canSign || parsed == null || inert || noClaim}
              loading={pendingLeg === 'stake'}
              data-testid="detf-stake"
            >
              Stake {claimLabel}
            </Button>
          )}
        </div>
      </TabPanel>

      <TabPanel when="unstake" active={tab}>
        <AmountField
          className="mt-4"
          label="Burn"
          symbol={claimLabel}
          value={amount}
          onChange={setAmount}
          decimals={decimals}
          balance={typeof balance === 'bigint' ? balance : undefined}
          data-testid="detf-unstake-amount"
        />
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Preview:{' '}
          {previewRedeem != null
            ? `${formatUnits(previewRedeem, 18)} ${detfSymbol}`
            : `Pays ${detfSymbol}. No quote until the contract can read it.`}
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <Button
          type="button"
          className="mt-4"
          onClick={() => void unstake()}
          disabled={!canSign || parsed == null || inert || noClaim}
          loading={pendingLeg === 'unstake'}
          data-testid="detf-unstake"
        >
          Unstake {claimLabel}
        </Button>
      </TabPanel>

      {status ? (
        <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="detf-staking-status">
          {status}
        </p>
      ) : null}
    </div>
  )
}

export default DetfStaking
