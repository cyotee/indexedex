'use client'

import { useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAccount, useConfig, usePublicClient } from 'wagmi'
import { getWalletClient } from 'wagmi/actions'
import { formatUnits, type Address, type Hash, type PublicClient } from 'viem'
import { useConnectModal } from '@rainbow-me/rainbowkit'
import { AmountField } from '../../components/ui/AmountField'
import { Button } from '../../components/ui/Button'
import { AddressLink } from '../../components/ui/AddressLink'
import { tokenStakingAbi } from '../../lib/tokenStaking/abi'
import { parsePositiveAmount } from '../../lib/tokenStaking/display'
import { migrationRouteAbi, readMigrationPosition } from '../../lib/tokenStaking/migration'
import { parseContractError } from '../../lib/tx/parseContractError'

type Props = { chainId: number; staking: Address; detf: Address }

export default function MigrationClaimPanel(props: Props) {
  const wallet = useAccount()
  // Changing account, connector or chain discards inputs and previews.
  return <Position key={`${props.chainId}:${props.staking}:${props.detf}:${wallet.address}:${wallet.chainId}:${wallet.connector?.uid}:${wallet.status}`} {...props} />
}

function Position({ chainId, staking, detf }: Props) {
  const { address, chainId: walletChainId, isConnected, connector } = useAccount()
  const config = useConfig()
  const client = usePublicClient({ chainId }) as PublicClient | undefined
  const cache = useQueryClient()
  const { openConnectModal } = useConnectModal()
  const connected = isConnected && walletChainId === chainId && !!address
  const [claimInput, setClaimInput] = useState('')
  const [redeemInput, setRedeemInput] = useState('')
  const [pending, setPending] = useState(false)
  const submitting = useRef(false)
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [hash, setHash] = useState<Hash>()
  const [receiptToCheck, setReceiptToCheck] = useState<{ hash: Hash; kind: 'claim' | 'redeem' }>()
  const busy = pending || !!receiptToCheck
  const identity = [chainId, staking, detf, address, connector?.uid]
  const position = useQuery({
    queryKey: ['staking-migration', ...identity],
    queryFn: () => readMigrationPosition(client!, staking, detf, address!),
    enabled: connected && !!client, retry: false, staleTime: 0, refetchInterval: 15_000,
  })
  const data = position.data?.ready ? position.data : undefined
  const ready = connected && !!data && !position.isError
  const claimAmount = parsePositiveAmount(claimInput, data?.dtfDecimals ?? 18)
  const redeemAmount = parsePositiveAmount(redeemInput, data?.syDecimals ?? 9)
  const claimInRange = !!data && claimAmount !== undefined && claimAmount <= data.stake
  const redeemInRange = !!data && redeemAmount !== undefined && redeemAmount <= data.syBalance
  const claimQuote = useQuery({
    queryKey: ['staking-migration-claim-quote', ...identity, claimInput],
    queryFn: () => client!.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'previewClaim', args: [address!, claimAmount!] }),
    enabled: ready && claimInRange, retry: false, staleTime: 0, refetchInterval: 15_000,
  })
  const redeemQuote = useQuery({
    queryKey: ['staking-migration-redeem-quote', ...identity, data?.sy, redeemInput],
    queryFn: () => client!.readContract({ address: data!.sy, abi: migrationRouteAbi, functionName: 'previewRedeem', args: [data!.sdetf, redeemAmount!] }),
    enabled: ready && redeemInRange, retry: false, staleTime: 0, refetchInterval: 15_000,
  })
  const canClaim = ready && claimInRange && !claimQuote.isError && (claimQuote.data ?? 0n) > 0n
  const canRedeem = ready && redeemInRange && !redeemQuote.isError && (redeemQuote.data ?? 0n) > 0n

  function assertWallet() {
    const state = config.state
    const active = state.current ? state.connections.get(state.current) : undefined
    if (state.status !== 'connected' || active?.connector.uid !== connector?.uid ||
      active?.chainId !== chainId || active.accounts[0]?.toLowerCase() !== address?.toLowerCase()) {
      throw new Error('Wallet changed. Review the position before trying again.')
    }
  }

  async function submit(kind: 'claim' | 'redeem') {
    if (submitting.current || receiptToCheck || !client || !address || !(kind === 'claim' ? canClaim : canRedeem)) return
    submitting.current = true
    setPending(true); setError(''); setHash(undefined); setStatus('Checking your current position…')
    try {
      assertWallet()
      const fresh = await readMigrationPosition(client, staking, detf, address)
      if (!fresh.ready) throw new Error('Migration is not complete on this network.')
      const wallet = await getWalletClient(config, { chainId })
      if (await wallet.getChainId() !== chainId) throw new Error('Wallet network changed. Review the position before trying again.')
      let tx: Hash
      if (kind === 'claim') {
        if (!claimAmount || claimAmount > fresh.stake) throw new Error('The claim amount exceeds your remaining stake.')
        const quote = await client.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'previewClaim', args: [address, claimAmount] })
        if (quote === 0n) throw new Error('This amount rounds to zero staking SY. Increase the amount or use Max.')
        const simulation = await client.simulateContract({ account: address, address: staking, abi: tokenStakingAbi, functionName: 'withdrawClaim', args: [claimAmount] })
        if (simulation.result === 0n) throw new Error('This claim would return zero staking SY.')
        assertWallet(); setStatus('Confirm the staking SY claim in your wallet.')
        tx = await wallet.writeContract(simulation.request)
      } else {
        if (!redeemAmount || redeemAmount > fresh.syBalance) throw new Error('The redemption amount exceeds your staking SY balance.')
        const minimum = await client.readContract({ address: fresh.sy, abi: migrationRouteAbi, functionName: 'previewRedeem', args: [fresh.sdetf, redeemAmount] })
        if (minimum === 0n) throw new Error('This amount rounds to zero sDETF. Increase the amount or use Max.')
        const simulation = await client.simulateContract({ account: address, address: fresh.sy, abi: migrationRouteAbi,
          functionName: 'redeem', args: [address, redeemAmount, fresh.sdetf, minimum, false] })
        assertWallet(); setStatus('Confirm the sDETF redemption in your wallet.')
        tx = await wallet.writeContract(simulation.request)
      }
      setHash(tx); setStatus('Transaction submitted. Waiting for confirmation…')
      setReceiptToCheck({ hash: tx, kind })
      await confirmTransaction(tx, kind)
    } catch (cause) {
      setStatus(''); setError(parseContractError(cause))
    } finally {
      submitting.current = false; setPending(false)
    }
  }

  async function confirmTransaction(tx: Hash, kind: 'claim' | 'redeem') {
    if (!client || !address) return
    setPending(true); setError('')
    let received = false
    let confirmed = false
    let replaced = false
    try {
      assertWallet()
      const receipt = await client.waitForTransactionReceipt({ hash: tx, timeout: 60_000,
        onReplaced: ({ reason }) => { replaced = reason !== 'repriced' },
      })
      received = true
      setHash(receipt.transactionHash)
      setReceiptToCheck(undefined)
      if (replaced) throw new Error('Transaction was cancelled or replaced in your wallet. Refresh your position before trying again.')
      if (receipt.status !== 'success') throw new Error('Transaction reverted. Your position was not changed by this transaction.')
      confirmed = true
      if (kind === 'claim') setClaimInput('')
      else setRedeemInput('')
      setStatus(`${kind === 'claim' ? 'Claim' : 'Redemption'} confirmed. Refreshing your balances…`)
      assertWallet()
      // Do not re-enable Max with a balance from before the confirmed receipt.
      await cache.cancelQueries({ queryKey: ['staking-migration', ...identity] })
      const updated = await readMigrationPosition(client, staking, detf, address, receipt.blockNumber)
      assertWallet()
      cache.setQueryData(['staking-migration', ...identity], updated)
      setStatus(kind === 'claim' ? 'Claim confirmed. Your staking SY is ready to redeem below.' : 'Redemption confirmed. Your sDETF is in your wallet.')
      void cache.invalidateQueries()
    } catch (cause) {
      if (confirmed) {
        setStatus(`${kind === 'claim' ? 'Claim' : 'Redemption'} confirmed. Your balances could not be refreshed yet.`)
        void cache.resetQueries({ queryKey: ['staking-migration', ...identity] })
      } else if (!received) {
        setStatus('Transaction submitted. Confirmation could not be checked. Check confirmation before sending another transaction.')
      } else setStatus('')
      setError(parseContractError(cause))
    } finally {
      setPending(false)
    }
  }

  const amount = (value: bigint | undefined, decimals: number | undefined) =>
    value === undefined || decimals === undefined ? '—' : formatUnits(value, decimals)
  const muted = 'text-sm text-[var(--text-muted,#9aa3b2)]'
  const card = 'min-w-0 rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] p-4'

  return <section className="mt-6 rounded-2xl border border-[var(--accent,#4FD44B)]/30 bg-[var(--surface-1,#131820)] p-4 sm:p-6" aria-labelledby="migration-title" data-testid="migration-position">
    <h2 id="migration-title" className="text-xl font-semibold">Your migrated DTF stake</h2>
    <p className={`${muted} mt-2`}>Deposits and remaining staking rewards migrate together into DTF-DETF. After migration, claim staking SY, a receipt for your staked position, then redeem it for sDETF. You can redeem immediately or hold the SY for later.</p>
    {!isConnected ? <Button className="mt-4" onClick={openConnectModal}>Connect wallet to view your position</Button> : !connected ?
      <p role="status" className="mt-4">Switch your wallet to the selected network to view and claim your position.</p> :
      position.isError ? <div role="alert" className="mt-4"><p>Could not load the migrated position from your wallet’s network. Check its RPC connection and the deployed contracts.</p><Button variant="secondary" className="mt-2" onClick={() => void position.refetch()}>Retry</Button></div> :
      !position.data ? <p role="status" className="mt-4">Loading your migrated position…</p> :
      !data ? <p role="status" className="mt-4">Migration is {position.data.phase === 1 ? 'in progress' : 'not complete'} on this network. Claims become available when it finishes.</p> : <>
        <p className="mt-4 text-sm text-[var(--accent,#4FD44B)]" data-testid="migration-complete">Migration complete · Deposits and rewards included</p>
        <dl className="mt-4 grid gap-4 break-words sm:grid-cols-3">
          <div><dt className={muted}>Unclaimed staking SY</dt><dd className="mt-1 font-mono" data-testid="migration-claimable">{amount(data.claimableSY, data.syDecimals)}</dd></div>
          <div><dt className={muted}>sDETF value of unclaimed + wallet SY</dt><dd className="mt-1 font-mono" data-testid="migration-sdetf-value">{amount(data.sdetfValue, data.sdetfDecimals)}</dd></div>
          <div><dt className={muted}>sDETF in your wallet</dt><dd className="mt-1 font-mono" data-testid="migration-sdetf-balance">{amount(data.sdetfBalance, data.sdetfDecimals)}</dd></div>
        </dl>
        <p className={`${muted} mt-3`}>SY units stay fixed while their sDETF value can grow with funded rewards. Quotes update from your wallet’s network.</p>
        {data.stake === 0n && data.syBalance === 0n ? <p className="mt-4" data-testid="migration-empty">This wallet has no remaining migrated stake or staking SY to claim.</p> : null}
        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <div className={card}>
            <h3 className="mb-3 font-semibold">1. Claim staking SY</h3>
            <AmountField label="Unclaimed DTF stake" symbol="DTF" value={claimInput} onChange={setClaimInput} decimals={data.dtfDecimals} balance={data.stake} disabled={busy} data-testid="migration-claim-amount" />
            <p className={`${muted} mt-2`}>This is your original stake used to calculate your share of the migrated position, not a DTF withdrawal.</p>
            <p className="my-3 text-sm" data-testid="migration-claim-quote">Estimated receipt: {claimInRange && !claimQuote.isError ? amount(claimQuote.data, data.syDecimals) : '—'} staking SY</p>
            {claimInput && !claimInRange ? <p className={muted}>Enter a positive amount within your remaining stake, with up to {data.dtfDecimals} decimals.</p> : null}
            {claimInRange && claimQuote.data === 0n ? <p role="status" className={muted}>This amount rounds to zero staking SY. Increase it or use Max.</p> : null}
            {claimQuote.isError ? <p role="alert" className={muted}>Could not quote this claim. Check your wallet connection and try again.</p> : null}
            <Button className="mt-3 w-full" disabled={!canClaim || busy} onClick={() => void submit('claim')} data-testid="migration-claim">Claim staking SY</Button>
          </div>
          <div className={card}>
            <h3 className="mb-3 font-semibold">2. Redeem SY for sDETF</h3>
            <AmountField label="Staking SY to redeem" symbol="SY" value={redeemInput} onChange={setRedeemInput} decimals={data.syDecimals} balance={data.syBalance} disabled={busy} data-testid="migration-redeem-amount" />
            <p className={`${muted} mt-2`}>Redeem from your wallet. You can then use the staking controls below to unstake sDETF for DTF-DETF.</p>
            <p className="my-3 text-sm" data-testid="migration-redeem-quote">Quoted output: {redeemInRange && !redeemQuote.isError ? amount(redeemQuote.data, data.sdetfDecimals) : '—'} sDETF</p>
            <p className={muted}>The quote is refreshed before signing and set as the minimum output.</p>
            {redeemInput && !redeemInRange ? <p className={muted}>Enter a positive amount within your SY balance, with up to {data.syDecimals} decimals.</p> : null}
            {redeemInRange && redeemQuote.data === 0n ? <p role="status" className={muted}>This amount rounds to zero sDETF. Increase it or use Max.</p> : null}
            {redeemQuote.isError ? <p role="alert" className={muted}>Could not quote this redemption. Check your wallet connection and try again.</p> : null}
            <Button className="mt-3 w-full" disabled={!canRedeem || busy} onClick={() => void submit('redeem')} data-testid="migration-redeem">Redeem for sDETF</Button>
          </div>
        </div>
        <details className="mt-4 text-sm"><summary className="cursor-pointer">Migration contracts</summary>
          {([['Original staking', staking], ['Claim vault', data.claimVault], ['Staking SY', data.sy], ['sDETF', data.sdetf], ['DTF-DETF', detf]] as const)
            .map(([label, token]) => <div className="mt-2" key={label}>{label}: <AddressLink chainId={chainId} address={token} /></div>)}
        </details>
      </>}
    <div className="mt-3 break-words text-sm" role="status" aria-live="polite" data-testid="migration-status">{status}</div>
    {error ? <p role="alert" className="mt-2 break-words text-sm text-[var(--danger,#E6386A)]" data-testid="migration-error">{error}</p> : null}
    {receiptToCheck ? <Button className="mt-2" variant="secondary" disabled={pending} onClick={() => void confirmTransaction(receiptToCheck.hash, receiptToCheck.kind)} data-testid="migration-check-confirmation">Check confirmation</Button> : null}
    {hash ? <p className={`${muted} mt-2 break-all`} data-testid="migration-tx">Transaction: {hash}</p> : null}
  </section>
}
