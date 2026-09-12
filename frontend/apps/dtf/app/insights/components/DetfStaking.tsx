'use client'

import { useEffect, useMemo, useState } from 'react'
import { erc20Abi, parseUnits } from 'viem'
import { useAccount, useBalance, usePublicClient, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'
import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'

import { AddressLink } from '../../components/ui/AddressLink'
import { AmountField } from '../../components/ui/AmountField'
import { Button } from '../../components/ui/Button'
import { Tabs, TabPanel } from '../../components/ui/Tabs'
import { ETH_PAY, WETH9_DEPOSIT_ABI, type EthWrapWrite, isEthPay, settlePayToken, withEthPayOption } from '../../lib/ethPay'
import { parseContractError } from '../../lib/tx/parseContractError'
import { actionTokenOptionLabel, type ActionToken } from '../lib/actionTokens'
import { insightsViewAbi, rebasingClaimAbi, standardizedYieldDiscoveryAbi } from '../lib/insightsAbi'
import { collectStakeTokenAddresses, formatTokenAmount, stakingExchangeRoute } from '../lib/claimMint'

const inputClass = 'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

export function DetfStaking({ detf, detfSymbol, claimToken, claimSymbol, pairTokens, vaultShare, weth, chainId, reserveLive }: {
  detf?: `0x${string}`
  detfSymbol: string
  claimToken?: `0x${string}`
  claimSymbol: string
  pairTokens: ActionToken[]
  vaultShare?: `0x${string}` | null
  weth?: `0x${string}` | null
  chainId: number
  reserveLive?: boolean
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

  const { data: stakingSY } = useReadContract({
    address: detf, abi: standardizedYieldDiscoveryAbi, functionName: 'stakingSY',
    query: { enabled: !!detf },
  })
  const { data: acceptedInputs } = useReadContract({
    address: stakingSY, abi: standardizedYieldDiscoveryAbi, functionName: 'getTokensIn',
    query: { enabled: !!stakingSY },
  })
  const { data: claimName } = useReadContract({ chainId, address: claimToken, abi: rebasingClaimAbi, functionName: 'name', query: { enabled: !!claimToken } })
  const { data: claimOnchainSymbol } = useReadContract({ chainId, address: claimToken, abi: rebasingClaimAbi, functionName: 'symbol', query: { enabled: !!claimToken } })
  const { data: claimDecimals } = useReadContract({ chainId, address: claimToken, abi: erc20Abi, functionName: 'decimals', query: { enabled: !!claimToken } })
  const { data: claimSupply, refetch: refreshSupply } = useReadContract({ chainId, address: claimToken, abi: rebasingClaimAbi, functionName: 'totalSupply', query: { enabled: !!claimToken, refetchInterval: 15_000 } })
  const { data: claimBalance, refetch: refreshClaimBalance } = useReadContract({ chainId, address: claimToken, abi: rebasingClaimAbi, functionName: 'balanceOf', args: address ? [address] : undefined, query: { enabled: !!claimToken && !!address, refetchInterval: 15_000 } })
  const claimLabel = claimOnchainSymbol || (claimSymbol && claimSymbol !== 'claim' ? claimSymbol : 'sDETF')
  const stakeTokens = useMemo(() => {
    const listed = collectStakeTokenAddresses({ detf, stakingToken: claimToken, acceptedInputs }).map((addr): ActionToken => {
      if (addr.toLowerCase() === detf?.toLowerCase()) return { address: addr, symbol: detfSymbol }
      return pairTokens.find((t) => t.address.toLowerCase() === addr.toLowerCase()) ?? { address: addr, symbol: addr.slice(0, 6) }
    })
    return withEthPayOption(listed, weth, { address: ETH_PAY, symbol: 'ETH' })
  }, [detf, claimToken, acceptedInputs, detfSymbol, pairTokens, weth])

  useEffect(() => {
    if (!stakeTokens.some((t) => t.address.toLowerCase() === token.toLowerCase())) setToken(stakeTokens[0]?.address ?? '')
  }, [stakeTokens, token])
  const tokenAddr = (token || stakeTokens[0]?.address || '') as `0x${string}` | ''
  const tokenMeta = stakeTokens.find((t) => t.address.toLowerCase() === tokenAddr.toLowerCase())
  const payEth = tab === 'stake' && isEthPay(tokenAddr)
  const settledIn = settlePayToken(tokenAddr, weth)
  const route = stakingExchangeRoute({ detf, stakingToken: claimToken, tokenIn: settledIn || undefined, unstake: tab === 'unstake' })
  const spendToken = route?.tokenIn
  const { data: tokenDecimals } = useReadContract({ chainId, address: spendToken, abi: erc20Abi, functionName: 'decimals', query: { enabled: !!spendToken && !payEth } })
  const decimals = payEth ? 18 : tokenDecimals
  let parsed: bigint | undefined
  try { if (amount.trim() && decimals != null) parsed = parseUnits(amount.trim(), Number(decimals)) } catch { /* Await valid native units. */ }
  const { data: ethBalance, refetch: refreshEthBalance } = useBalance({ address, chainId, query: { enabled: payEth && !!address } })
  const { data: tokenBalance, refetch: refreshTokenBalance } = useReadContract({ chainId, address: spendToken, abi: erc20Abi, functionName: 'balanceOf', args: address ? [address] : undefined, query: { enabled: !!spendToken && !!address && !payEth } })
  const balance = payEth ? ethBalance?.value : tokenBalance
  const { data: allowance, refetch: refreshAllowance } = useReadContract({
    address: spendToken, abi: erc20Abi, functionName: 'allowance',
    args: address && route ? [address, route.target] : undefined,
    query: { enabled: !!spendToken && !!address && !!route?.needsAllowance },
  })
  const { data: preview, refetch: refreshPreview } = useReadContract({
    address: route?.target, abi: insightsViewAbi, functionName: 'previewExchangeIn',
    args: route && parsed != null && parsed > 0n ? [route.tokenIn, parsed, route.tokenOut] : undefined,
    query: { enabled: !!route && parsed != null && parsed > 0n, retry: 0, refetchInterval: 15_000 },
  })
  const needApprove = !payEth && route?.needsAllowance && parsed != null && parsed > 0n && (allowance ?? 0n) < parsed
  const blockedCopy = !isConnected ? 'Connect a wallet to sign.'
    : !walletMatches ? `Switch the wallet to chain ${chainId}.`
      : !claimToken ? 'Reading the staking token…'
        : reserveLive === false && route?.requiresLiveReserve ? 'Payment-token staking opens after the first bond. Direct DETF staking remains available.'
          : null
  const ready = !blockedCopy && !!route && !!address && pendingLeg == null && parsed != null && parsed > 0n && preview != null && preview > 0n && balance != null && balance >= parsed

  async function writeOnWallet(params: Parameters<typeof writeContractAsync>[0] | EthWrapWrite) {
    if (typeof walletChainId === 'number' && walletChainId !== chainId && !localWallet) await switchChainAsync({ chainId })
    const { chain: _chain, chainId: _cid, ...rest } = params as typeof params & { chain?: unknown; chainId?: number }
    return writeContractAsync((localWallet ? rest : params) as Parameters<typeof writeContractAsync>[0])
  }
  async function wait(hash: `0x${string}`, label: string) {
    setStatus(`${label} submitted.`)
    if (!publicClient) throw new Error('Connection unavailable while waiting for confirmation')
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    if (receipt.status === 'reverted') throw new Error('Transaction reverted')
    setStatus(`${label} confirmed.`)
  }
  async function approve() {
    if (!route || !spendToken || parsed == null || parsed <= 0n || !address) return
    setPendingLeg('approve')
    try {
      const hash = await writeOnWallet({ account: address, address: spendToken, abi: erc20Abi, functionName: 'approve', args: [route.target, parsed] })
      await wait(hash, 'Approve')
      await refreshAllowance()
    } catch (error) { setStatus(parseContractError(error)) } finally { setPendingLeg(null) }
  }
  async function exchange() {
    if (!ready || !route || !spendToken || parsed == null || !address || !publicClient) return
    setPendingLeg(tab === 'unstake' ? 'unstake' : 'stake')
    try {
      if (payEth && weth) {
        const hash = await writeOnWallet({ account: address, address: weth, abi: WETH9_DEPOSIT_ABI, functionName: 'deposit', value: parsed })
        await wait(hash, 'Wrap')
      }
      if (route.needsAllowance) {
        const current = await publicClient.readContract({ address: spendToken, abi: erc20Abi, functionName: 'allowance', args: [address, route.target] })
        if (current < parsed) {
          const hash = await writeOnWallet({ account: address, address: spendToken, abi: erc20Abi, functionName: 'approve', args: [route.target, parsed] })
          await wait(hash, 'Approve')
        }
      }
      const quoted = await publicClient.readContract({ address: route.target, abi: insightsViewAbi, functionName: 'previewExchangeIn', args: [route.tokenIn, parsed, route.tokenOut] })
      if (quoted <= 0n) throw new Error('No positive staking quote is available')
      const minimum = route.requiresLiveReserve ? (quoted * 99n / 100n || 1n) : quoted
      const hash = await writeOnWallet({
        account: address, address: route.target, abi: insightsViewAbi, functionName: 'exchangeIn',
        args: [route.tokenIn, parsed, route.tokenOut, minimum, address, false, BigInt(Math.floor(Date.now() / 1000) + 20 * 60)],
      })
      await wait(hash, tab === 'unstake' ? 'Unstake' : 'Stake')
      await Promise.allSettled([refreshSupply(), refreshClaimBalance(), refreshTokenBalance(), refreshEthBalance(), refreshAllowance(), refreshPreview()])
    } catch (error) { setStatus(parseContractError(error)) } finally { setPendingLeg(null) }
  }

  if (!detf) return null
  return (
    <div data-testid="detf-staking">
      <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
        Stake {detfSymbol} to receive an equal amount of {claimLabel}. Rewards add to your staked balance when they are funded.
        Unstake one {claimLabel} for one {detfSymbol}. You can also pay with a supported token using the quote below.
      </p>
      {claimToken ? (
        <div className="mt-4 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] p-3" data-testid="insights-claim-card">
          <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Staking token</p>
          <p className="mt-1 text-sm">{claimLabel}{claimName ? ` · ${claimName}` : ''}</p>
          <p className="mt-2 font-mono text-[11px] text-[var(--text-muted,#9aa3b2)]">
            Supply {formatTokenAmount(claimSupply, claimDecimals ?? 9)} · You hold {claimBalance != null ? formatTokenAmount(claimBalance, claimDecimals ?? 9) : isConnected ? '0' : 'Connect to see'} ·{' '}
            <span data-testid="insights-claim-address"><AddressLink chainId={chainId} address={claimToken} display="full" /></span>
          </p>
        </div>
      ) : <p className="mt-3 text-sm" data-testid="insights-claim-card">Reading the staking token…</p>}
      <div className="mt-4"><Tabs tabs={[{ id: 'stake', label: 'Stake' }, { id: 'unstake', label: 'Unstake' }]} active={tab} onChange={setTab} /></div>
      <TabPanel when="stake" active={tab}>
        <label className="block text-sm">Pay with
          <select className={inputClass} value={tokenAddr} onChange={(event) => setToken(event.target.value)} data-testid="detf-stake-token">
            {stakeTokens.map((item) => <option key={item.address} value={item.address}>{isEthPay(item.address) ? 'ETH' : item.address.toLowerCase() === detf.toLowerCase() ? item.symbol : actionTokenOptionLabel(item, vaultShare)}</option>)}
          </select>
        </label>
        <AmountField className="mt-4" label="Pay" symbol={tokenMeta?.symbol} value={amount} onChange={setAmount} decimals={decimals ?? 9} balance={balance} data-testid="detf-stake-amount" />
        <p className="mt-2 text-xs">Preview: {tab === 'stake' && preview != null ? `${formatTokenAmount(preview, claimDecimals ?? 9)} ${claimLabel}` : 'Enter an amount for a quote.'}</p>
        {blockedCopy ? <p className="mt-2 text-sm">{blockedCopy}</p> : null}
        <div className="mt-4">
          {needApprove ? <Button type="button" onClick={() => void approve()} disabled={!ready} loading={pendingLeg === 'approve'} data-testid="detf-stake-approve">Approve {tokenMeta?.symbol ?? 'token'}</Button>
            : <Button type="button" onClick={() => void exchange()} disabled={!ready} loading={pendingLeg === 'stake'} data-testid="detf-stake">Stake {claimLabel}</Button>}
        </div>
      </TabPanel>
      <TabPanel when="unstake" active={tab}>
        <AmountField className="mt-4" label="Unstake" symbol={claimLabel} value={amount} onChange={setAmount} decimals={claimDecimals ?? 9} balance={claimBalance} data-testid="detf-unstake-amount" />
        <p className="mt-2 text-xs">Preview: {tab === 'unstake' && preview != null ? `${formatTokenAmount(preview, 9)} ${detfSymbol}` : 'Enter an amount for a quote.'}</p>
        {blockedCopy ? <p className="mt-2 text-sm">{blockedCopy}</p> : null}
        <Button type="button" className="mt-4" onClick={() => void exchange()} disabled={!ready} loading={pendingLeg === 'unstake'} data-testid="detf-unstake">Unstake {claimLabel}</Button>
      </TabPanel>
      {status ? <p className="mt-3 text-xs" data-testid="detf-staking-status">{status}</p> : null}
    </div>
  )
}

export default DetfStaking
