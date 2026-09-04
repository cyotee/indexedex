'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { erc20Abi, type PublicClient } from 'viem'
import {
  useAccount,
  useChainId,
  useConnect,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'

import { CHAIN_ID_ROBINHOOD, getAddressArtifacts } from '@indexedex/protocol/addressArtifacts'
import { AmountField, parseAmountFieldValue } from '../ui/AmountField'
import { Button } from '../ui/Button'
import { Stat } from '../ui/Stat'
import { parseContractError } from '../../lib/tx/parseContractError'
import { resolveWalletGate, type PendingLeg } from '../../lib/tx/actionState'
import { resolveWalletProvider, waitForCreateReceipt } from '../../create/lib/seTx'
import { TOKEN_STAKING_PHASE, tokenStakingAbi } from '../../lib/tokenStaking/abi'
import {
  claimAfterWrapDisplay,
  formatTokenAmount,
  migrationLabel,
} from '../../lib/tokenStaking/display'
import { DTF_TOKEN, resolveTokenStakingAddress } from '../../lib/tokenStaking/resolveAddress'
import { connectInjectedWallet } from '../../lib/wallet/connectInjected'

const DECIMALS = 18

export function TokenStakingOverlay() {
  const { address, isConnected } = useAccount()
  const walletChainId = useChainId()
  const { connectAsync, connectors, isPending: isConnectPending } = useConnect()
  const { switchChainAsync, isPending: isSwitchPending } = useSwitchChain()
  const publicClient = usePublicClient({ chainId: CHAIN_ID_ROBINHOOD }) as PublicClient | undefined
  const { writeContractAsync } = useWriteContract()

  const stakingAddress = useMemo(() => {
    try {
      const platform = getAddressArtifacts(CHAIN_ID_ROBINHOOD, 'anvil_robinhood_main').platform as
        | Record<string, unknown>
        | undefined
      return resolveTokenStakingAddress(platform, process.env.NEXT_PUBLIC_TOKEN_STAKING)
    } catch {
      return resolveTokenStakingAddress(null, process.env.NEXT_PUBLIC_TOKEN_STAKING)
    }
  }, [])

  const enabled = !!stakingAddress
  const accountEnabled = enabled && !!address

  const { data: rewardReserve, refetch: refetchReserve } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: stakingAddress,
    abi: tokenStakingAbi,
    functionName: 'rewardReserve',
    query: { enabled },
  })
  const { data: phase } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: stakingAddress,
    abi: tokenStakingAbi,
    functionName: 'phase',
    query: { enabled },
  })
  const { data: stakeBal, refetch: refetchStake } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: stakingAddress,
    abi: tokenStakingAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: accountEnabled },
  })
  const { data: earned, refetch: refetchEarned } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: stakingAddress,
    abi: tokenStakingAbi,
    functionName: 'earned',
    args: address ? [address] : undefined,
    query: { enabled: accountEnabled },
  })
  const { data: previewClaim, refetch: refetchPreview } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: stakingAddress,
    abi: tokenStakingAbi,
    functionName: 'previewClaim',
    args: address && stakeBal != null ? [address, stakeBal] : undefined,
    query: { enabled: accountEnabled && stakeBal != null && Number(phase) === TOKEN_STAKING_PHASE.Wrapped },
  })
  const { data: dtfBal, refetch: refetchDtf } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: DTF_TOKEN,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: accountEnabled },
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    chainId: CHAIN_ID_ROBINHOOD,
    address: DTF_TOKEN,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && stakingAddress ? [address, stakingAddress] : undefined,
    query: { enabled: accountEnabled && !!stakingAddress },
  })

  const phaseNum = typeof phase === 'number' ? phase : phase != null ? Number(phase) : undefined
  const canStake = phaseNum === TOKEN_STAKING_PHASE.Staking
  const wrapped = phaseNum === TOKEN_STAKING_PHASE.Wrapped

  const [amount, setAmount] = useState('')
  const [status, setStatus] = useState('')
  const [pendingLeg, setPendingLeg] = useState<PendingLeg>(null)
  /** Last on-receipt allowance so Approve does not stick while the read refetches. */
  const [receiptAllowance, setReceiptAllowance] = useState(0n)

  useEffect(() => {
    setReceiptAllowance(0n)
  }, [address])

  const parsedAmount = useMemo(() => parseAmountFieldValue(amount, DECIMALS), [amount])
  const amountValid = parsedAmount != null && parsedAmount > 0n
  const knownAllowance =
    allowance != null && allowance > receiptAllowance ? allowance : receiptAllowance
  const needsApproval = canStake && amountValid && parsedAmount != null && knownAllowance < parsedAmount
  const isWrongNetwork = isConnected && walletChainId !== CHAIN_ID_ROBINHOOD

  const gate = resolveWalletGate({
    isConnected,
    isWrongNetwork,
    amountValid: canStake ? amountValid : true,
    hasPreview: true,
    needsTokenApproval: canStake && needsApproval,
    needsPermit2Approval: false,
    signedMode: true,
    executeLabel: 'Stake',
  })

  const refetchAll = useCallback(async () => {
    await Promise.all([
      refetchReserve(),
      refetchStake(),
      refetchEarned(),
      refetchPreview(),
      refetchDtf(),
      refetchAllowance(),
    ])
  }, [refetchAllowance, refetchDtf, refetchEarned, refetchPreview, refetchReserve, refetchStake])

  const waitTx = useCallback(
    async (hash: `0x${string}`) => {
      const walletProvider = await resolveWalletProvider()
      await waitForCreateReceipt({
        hash,
        readClient: publicClient ?? null,
        walletProvider,
        timeoutMs: 90_000,
      })
    },
    [publicClient],
  )

  const handleConnect = useCallback(async () => {
    setStatus('')
    try {
      await connectInjectedWallet({ connectAsync, connectors })
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [connectAsync, connectors])

  const handleSwitch = useCallback(async () => {
    try {
      setStatus('')
      await switchChainAsync?.({ chainId: CHAIN_ID_ROBINHOOD })
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [switchChainAsync])

  const handleApprove = useCallback(async () => {
    if (!stakingAddress || !parsedAmount) return
    setPendingLeg('approve-token-permit2')
    setStatus('')
    try {
      const hash = await writeContractAsync({
        address: DTF_TOKEN,
        abi: erc20Abi,
        functionName: 'approve',
        args: [stakingAddress, parsedAmount],
        chainId: CHAIN_ID_ROBINHOOD,
      })
      await waitTx(hash)
      setReceiptAllowance(parsedAmount)
      try {
        await refetchAllowance()
      } catch {
        /* Receipt already landed; the button can move to Stake. */
      }
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [parsedAmount, refetchAllowance, stakingAddress, waitTx, writeContractAsync])

  const handleStake = useCallback(async () => {
    if (!stakingAddress || !parsedAmount) return
    setPendingLeg('execute')
    setStatus('')
    try {
      const hash = await writeContractAsync({
        address: stakingAddress,
        abi: tokenStakingAbi,
        functionName: 'stake',
        args: [parsedAmount],
        chainId: CHAIN_ID_ROBINHOOD,
      })
      await waitTx(hash)
      try {
        await refetchAll()
      } catch {
        /* Stats retry on the next read; do not hide a confirmed stake. */
      }
      setReceiptAllowance(0n)
      setAmount('')
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [parsedAmount, refetchAll, stakingAddress, waitTx, writeContractAsync])

  const handleGetReward = useCallback(async () => {
    if (!stakingAddress) return
    setStatus('')
    try {
      const hash = await writeContractAsync({
        address: stakingAddress,
        abi: tokenStakingAbi,
        functionName: 'getReward',
        chainId: CHAIN_ID_ROBINHOOD,
      })
      await waitTx(hash)
      await refetchAll()
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [refetchAll, stakingAddress, waitTx, writeContractAsync])

  const handleUnstake = useCallback(async () => {
    if (!stakingAddress || stakeBal == null || stakeBal === 0n) return
    setStatus('')
    try {
      const hash = await writeContractAsync({
        address: stakingAddress,
        abi: tokenStakingAbi,
        functionName: 'withdraw',
        args: [stakeBal],
        chainId: CHAIN_ID_ROBINHOOD,
      })
      await waitTx(hash)
      await refetchAll()
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [refetchAll, stakeBal, stakingAddress, waitTx, writeContractAsync])

  const handleWithdrawClaim = useCallback(async () => {
    if (!stakingAddress || stakeBal == null || stakeBal === 0n) return
    setStatus('')
    try {
      const hash = await writeContractAsync({
        address: stakingAddress,
        abi: tokenStakingAbi,
        functionName: 'withdrawClaim',
        args: [stakeBal],
        chainId: CHAIN_ID_ROBINHOOD,
      })
      await waitTx(hash)
      await refetchAll()
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [refetchAll, stakeBal, stakingAddress, waitTx, writeContractAsync])

  const ctaPending: PendingLeg = isConnectPending
    ? 'connect'
    : isSwitchPending
      ? 'switch'
      : pendingLeg

  return (
    <div className="dtf-landing__stake-overlay" data-testid="token-staking-overlay">
      <div className="dtf-landing__stake-dim" aria-hidden="true" />
      <div
        className="dtf-landing__stake-panel"
        role="dialog"
        aria-labelledby="token-staking-title"
        aria-modal="true"
      >
        <p className="dtf-landing__kicker">Temporary $DTF stake</p>
        <h2 id="token-staking-title">Stake $DTF</h2>
        <p className="dtf-landing__stake-lede">
          Short program until the protocol DETF is live. After the wrap, your stake converts to
          the rebasing claim token.
        </p>

        <div className="dtf-landing__stake-wallet">
          {!isConnected ? (
            <Button
              variant="primary"
              className="dtf-landing__stake-cta"
              loading={isConnectPending}
              onClick={handleConnect}
              data-testid="token-staking-connect"
            >
              Connect wallet
            </Button>
          ) : isWrongNetwork ? (
            <Button
              variant="primary"
              className="dtf-landing__stake-cta"
              loading={isSwitchPending}
              onClick={handleSwitch}
              data-testid="token-staking-switch"
            >
              Switch to Robinhood
            </Button>
          ) : (
            <p className="dtf-landing__stake-connected" title={address}>
              {address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'Connected'}
            </p>
          )}
        </div>

        <div className="dtf-landing__stake-stats">
          <Stat
            label="Reward reserve"
            value={rewardReserve != null ? `${formatTokenAmount(rewardReserve)} $DTF` : '—'}
          />
          <Stat
            label="Your stake"
            value={stakeBal != null ? `${formatTokenAmount(stakeBal)} $DTF` : '—'}
          />
          <Stat
            label="$DTF rewards"
            value={earned != null ? `${formatTokenAmount(earned)} $DTF` : '—'}
          />
          <Stat label="Migration" value={migrationLabel(phaseNum)} />
          <Stat
            label="Claim after wrap"
            value={claimAfterWrapDisplay(phaseNum, previewClaim)}
            hint="Rebasing claim token. Shows - until the wrap is done."
          />
        </div>

        {!stakingAddress ? (
          <p className="dtf-landing__stake-note">Staking is not live on this chain yet.</p>
        ) : !isConnected || isWrongNetwork ? null : canStake ? (
          <>
            <AmountField
              label="Amount"
              symbol="$DTF"
              value={amount}
              onChange={setAmount}
              decimals={DECIMALS}
              balance={typeof dtfBal === 'bigint' ? dtfBal : undefined}
              data-testid="token-staking-amount"
            />
            <Button
              className="dtf-landing__stake-cta"
              data-testid="token-staking-cta"
              data-gate={gate.kind}
              loading={
                ctaPending === 'approve-token-permit2' || ctaPending === 'execute'
              }
              disabled={
                gate.kind === 'disabled' ||
                (ctaPending != null &&
                  ctaPending !== 'approve-token-permit2' &&
                  ctaPending !== 'execute')
              }
              onClick={() => {
                if (gate.kind === 'approve') handleApprove()
                else if (gate.kind === 'execute') handleStake()
              }}
            >
              {ctaPending === 'approve-token-permit2'
                ? 'Approving'
                : ctaPending === 'execute'
                  ? 'Staking'
                  : gate.kind === 'approve'
                    ? 'Approve'
                    : 'Stake'}
            </Button>
            <div className="dtf-landing__stake-secondary">
              {earned != null && earned > 0n ? (
                <Button variant="secondary" size="sm" onClick={handleGetReward}>
                  Take $DTF rewards
                </Button>
              ) : null}
              {stakeBal != null && stakeBal > 0n ? (
                <Button variant="ghost" size="sm" onClick={handleUnstake}>
                  Unstake
                </Button>
              ) : null}
            </div>
          </>
        ) : wrapped ? (
          <Button
            variant="primary"
            className="dtf-landing__stake-cta"
            disabled={!stakeBal || stakeBal === 0n}
            onClick={handleWithdrawClaim}
            data-testid="token-staking-claim"
          >
            Take rebasing claim
          </Button>
        ) : (
          <p className="dtf-landing__stake-note">
            Wrap in progress. You cannot stake or unstake $DTF until it finishes.
          </p>
        )}

        {status ? (
          <p className="dtf-landing__stake-error" role="status">
            {status}
          </p>
        ) : null}
      </div>
    </div>
  )
}
