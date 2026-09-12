'use client'

import Link from 'next/link'
import { useEffect, useRef, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useConnectModal } from '@rainbow-me/rainbowkit'
import { useAccount, usePublicClient, useSwitchChain, useWriteContract } from 'wagmi'
import { erc20Abi, type Hash } from 'viem'

import { CHAIN_ID_ROBINHOOD, getAddressArtifacts } from '@indexedex/protocol/addressArtifacts'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { AmountField } from '../ui/AmountField'
import { Button } from '../ui/Button'
import { Stat } from '../ui/Stat'
import { tokenStakingAbi, TOKEN_STAKING_PHASE } from '../../lib/tokenStaking/abi'
import { formatTokenAmount, migrationLabel, parsePositiveAmount } from '../../lib/tokenStaking/display'
import { DTF_TOKEN, resolveTokenStakingAddress } from '../../lib/tokenStaking/resolveAddress'
import { parseContractError } from '../../lib/tx/parseContractError'
import { appPath } from '../../lib/siteOrigins'

export function TokenStakingOverlay() {
  const wallet = useAccount()
  const [visible, setVisible] = useState(true)
  if (!visible) return null
  return <StakingForm key={`${wallet.address}:${wallet.chainId}:${wallet.connector?.uid}`} onDismiss={() => setVisible(false)} />
}

function StakingForm({ onDismiss }: { onDismiss: () => void }) {
  const { address, chainId, isConnected, connector } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const client = usePublicClient({ chainId: CHAIN_ID_ROBINHOOD })
  const { openConnectModal, connectModalOpen } = useConnectModal()
  const { switchChainAsync, isPending: switching } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const dialogRef = useRef<HTMLDialogElement>(null)
  const submitting = useRef(false)
  const [amount, setAmount] = useState('')
  const [pending, setPending] = useState(false)
  const [receiptHash, setReceiptHash] = useState<Hash>()
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const wrongNetwork = isConnected && chainId !== CHAIN_ID_ROBINHOOD
  const connected = isConnected && !wrongNetwork && !!address
  let staking: `0x${string}` | undefined
  try {
    staking = resolveTokenStakingAddress(getAddressArtifacts(CHAIN_ID_ROBINHOOD, environment).platform, process.env.NEXT_PUBLIC_TOKEN_STAKING)
  } catch {
    staking = resolveTokenStakingAddress(null, process.env.NEXT_PUBLIC_TOKEN_STAKING)
  }

  // RainbowKit renders its own modal outside this dialog. Temporarily release
  // the native modal while connecting so its wallet choices remain interactive.
  useEffect(() => {
    if (connectModalOpen) return
    const dialog = dialogRef.current
    dialog?.showModal()
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { dialog?.close(); document.body.style.overflow = previousOverflow }
  }, [connectModalOpen])

  const position = useQuery({
    queryKey: ['temporary-dtf-staking', staking, environment, address, chainId, connector?.uid, isConnected],
    enabled: !!staking && !!client && !wrongNetwork,
    retry: false, staleTime: 0, refetchInterval: 15_000,
    queryFn: async () => {
      const blockNumber = await client!.getBlockNumber({ cacheTime: 0 })
      const legacy = { address: staking!, abi: tokenStakingAbi, blockNumber } as const
      const token = { address: DTF_TOKEN, abi: erc20Abi, blockNumber } as const
      const [phase, stakingToken, reserve, stake, earned, balance, allowance] = await Promise.all([
        client!.readContract({ ...legacy, functionName: 'phase' }),
        client!.readContract({ ...legacy, functionName: 'stakingToken' }),
        client!.readContract({ ...legacy, functionName: 'rewardReserve' }),
        address ? client!.readContract({ ...legacy, functionName: 'balanceOf', args: [address] }) : undefined,
        address ? client!.readContract({ ...legacy, functionName: 'earned', args: [address] }) : undefined,
        address ? client!.readContract({ ...token, functionName: 'balanceOf', args: [address] }) : undefined,
        address ? client!.readContract({ ...token, functionName: 'allowance', args: [address, staking!] }) : undefined,
      ])
      if (stakingToken.toLowerCase() !== DTF_TOKEN.toLowerCase()) throw new Error('This staking contract does not accept DTF.')
      return { phase, reserve, stake, earned, balance, allowance }
    },
  })
  const data = position.isError ? undefined : position.data
  const canStake = data?.phase === TOKEN_STAKING_PHASE.Staking
  const wrapped = data?.phase === TOKEN_STAKING_PHASE.Wrapped
  const value = parsePositiveAmount(amount, 18)
  const validAmount = !!value && value <= (data?.balance ?? 0n)
  const needsApproval = !!value && (data?.allowance ?? 0n) < value
  const busy = pending || !!receiptHash

  async function confirm(hash: Hash) {
    if (!client) return
    setPending(true); setError('')
    try {
      const receipt = await client.waitForTransactionReceipt({ hash, timeout: 90_000,
        onReplaced: ({ transaction }) => setReceiptHash(transaction.hash),
      })
      setReceiptHash(undefined)
      if (receipt.status !== 'success') throw new Error('The transaction reverted.')
      await position.refetch()
      setStatus('Transaction confirmed.')
    } catch (cause) {
      setError(parseContractError(cause))
    } finally { setPending(false) }
  }

  async function submit(kind: 'approve' | 'stake' | 'reward' | 'withdraw') {
    if (submitting.current || busy || !connected || !client || !staking || !address || !canStake) return
    if ((kind === 'approve' || kind === 'stake') && !validAmount) return
    if (kind === 'withdraw' && !data?.stake) return
    if (kind === 'reward' && !data?.earned) return
    submitting.current = true; setPending(true); setError(''); setStatus('Confirm in your wallet.')
    try {
      const phase = await client.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'phase' })
      if (phase !== TOKEN_STAKING_PHASE.Staking) throw new Error('Staking migration has started. Refresh your position.')
      let hash: Hash
      if (kind === 'approve') {
        const simulation = await client.simulateContract({ account: address, address: DTF_TOKEN, abi: erc20Abi, functionName: 'approve', args: [staking, value!] })
        hash = await writeContractAsync({ ...simulation.request, chainId: CHAIN_ID_ROBINHOOD })
      } else if (kind === 'reward') {
        const simulation = await client.simulateContract({ account: address, address: staking, abi: tokenStakingAbi, functionName: 'getReward' })
        hash = await writeContractAsync({ ...simulation.request, chainId: CHAIN_ID_ROBINHOOD })
      } else {
        const simulation = await client.simulateContract({ account: address, address: staking, abi: tokenStakingAbi,
          functionName: kind === 'stake' ? 'stake' : 'withdraw', args: [kind === 'stake' ? value! : data!.stake!] })
        hash = await writeContractAsync({ ...simulation.request, chainId: CHAIN_ID_ROBINHOOD })
      }
      setReceiptHash(hash); setStatus('Transaction submitted. Waiting for confirmation…')
      await confirm(hash)
    } catch (cause) { setError(parseContractError(cause)); setStatus('') }
    finally { submitting.current = false; setPending(false) }
  }

  return (
    <dialog ref={dialogRef} className="dtf-landing__stake-panel dtf-landing__migration-dialog"
      aria-labelledby="token-staking-title" aria-describedby="token-staking-description"
      onCancel={event => { event.preventDefault(); onDismiss() }} data-testid="token-staking-overlay">
      <button type="button" className="dtf-landing__migration-close" aria-label="Close staking overlay" onClick={onDismiss}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
      </button>
      <p className="dtf-landing__kicker">Temporary $DTF stake</p>
      <h2 id="token-staking-title">Stake $DTF</h2>
      <p id="token-staking-description" className="dtf-landing__stake-lede">
        Stake $DTF while we prepare the protocol DETF. Your deposits and remaining reward reserves will migrate together when it is ready.
      </p>
      <div className="dtf-landing__stake-wallet">
        {!isConnected ? <Button variant="primary" onClick={openConnectModal} disabled={!openConnectModal} data-testid="token-staking-connect">Connect wallet</Button>
          : wrongNetwork ? <Button variant="primary" loading={switching} data-testid="token-staking-switch" onClick={async () => {
            try { await switchChainAsync({ chainId: CHAIN_ID_ROBINHOOD }); setError('') } catch (cause) { setError(parseContractError(cause)) }
          }}>Switch to Robinhood</Button>
          : <p className="dtf-landing__stake-connected" title={address}>{address?.slice(0, 6)}…{address?.slice(-4)}</p>}
      </div>
      <div className="dtf-landing__stake-stats">
        <Stat label="Reward reserve" value={data ? `${formatTokenAmount(data.reserve)} $DTF` : '—'} />
        <Stat label="Your stake" value={data?.stake !== undefined ? `${formatTokenAmount(data.stake)} $DTF` : '—'} />
        <Stat label="$DTF rewards" value={data?.earned !== undefined ? `${formatTokenAmount(data.earned)} $DTF` : '—'} />
        <Stat label="Migration" value={data ? migrationLabel(data.phase) : '—'} />
      </div>
      {!staking ? <p className="dtf-landing__stake-note">Staking is not configured for this network.</p>
        : position.isError ? <p role="alert" className="dtf-landing__stake-error">Could not load staking. Check your wallet network and try again.</p>
        : !connected ? null
        : canStake ? <>
          <AmountField label="Amount" symbol="$DTF" value={amount} onChange={setAmount} decimals={18} balance={data?.balance} data-testid="token-staking-amount" />
          <Button className="dtf-landing__stake-cta" data-testid="token-staking-cta" data-gate={!validAmount ? 'disabled' : needsApproval ? 'approve' : 'execute'}
            disabled={busy || !validAmount} loading={pending} onClick={() => submit(needsApproval ? 'approve' : 'stake')}>
            {needsApproval ? 'Approve' : 'Stake'}
          </Button>
          <div className="dtf-landing__stake-secondary">
            {!!data?.earned && <Button variant="secondary" size="sm" disabled={busy} onClick={() => submit('reward')}>Take $DTF rewards</Button>}
            {!!data?.stake && <Button variant="ghost" size="sm" disabled={busy} onClick={() => submit('withdraw')}>Unstake</Button>}
          </div>
        </> : wrapped ? <Link href={appPath('/staking')} className="dtf-landing__btn dtf-landing__btn--primary">View migrated staking</Link>
          : <p className="dtf-landing__stake-note">{data ? 'Migration is in progress. Staking and withdrawals are paused.' : 'Loading staking…'}</p>}
      {receiptHash && !pending && <Button variant="secondary" onClick={() => confirm(receiptHash)}>Check transaction</Button>}
      {status && <p className="dtf-landing__stake-note" role="status">{status}</p>}
      {error && <p className="dtf-landing__stake-error" role="alert">{error}</p>}
    </dialog>
  )
}
