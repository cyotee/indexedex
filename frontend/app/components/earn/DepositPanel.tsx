'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  erc20Abi,
  formatUnits,
  parseUnits,
  type PublicClient,
} from 'viem'
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from 'wagmi'

import { useApprovalFlow } from '../../lib/hooks/useApprovalFlow'
import { getAddressArtifacts } from '../../lib/addressArtifacts'
import { useDeploymentEnvironment } from '../../lib/deploymentEnvironment'
import { swapExactInAbi } from '../../lib/swapAbis'
import {
  buildStrategyVaultDepositArgs,
  buildStrategyVaultWithdrawArgs,
} from '../../lib/earn/buildVaultSwapArgs'
import type { EarnProduct } from '../../lib/earn/types'
import { Button } from '../ui/Button'
import { Card } from '../ui/Card'
import { TxSteps } from '../ui/TxSteps'

const vaultTokensAbi = [
  {
    type: 'function',
    name: 'tokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'vaultTokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
] as const

type Mode = 'deposit' | 'withdraw'

/**
 * Strategy vault deposit/withdraw via Standard Exchange Router (same path as Swap vault deposit).
 * pool = vault, tokenOut (deposit) or tokenIn (withdraw) = vault share token.
 */
export function DepositPanel({
  product,
  chainId,
}: {
  product: EarnProduct
  chainId: number
}) {
  const { address, isConnected } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const publicClient = usePublicClient({ chainId }) as PublicClient | undefined
  const { writeContractAsync, isPending } = useWriteContract()

  const [mode, setMode] = useState<Mode>('deposit')
  const [tokenIn, setTokenIn] = useState<`0x${string}` | ''>('')
  const [amount, setAmount] = useState('')
  const [status, setStatus] = useState('')
  const [txPhase, setTxPhase] = useState<'idle' | 'approve' | 'submit' | 'done' | 'error'>('idle')
  const [successHash, setSuccessHash] = useState<string | null>(null)

  const platform = useMemo(() => {
    try {
      return getAddressArtifacts(chainId, environment).platform as {
        balancerV3StandardExchangeRouter?: `0x${string}`
        permit2?: `0x${string}`
      }
    } catch {
      return {}
    }
  }, [chainId, environment])

  const routerAddress = platform.balancerV3StandardExchangeRouter ?? null
  const permit2Address = platform.permit2 ?? null
  const vaultAddress = product.address

  const { data: vaultTokensLegacy } = useReadContract({
    address: vaultAddress,
    abi: vaultTokensAbi,
    functionName: 'tokens',
    chainId,
    query: { enabled: product.productType === 'strategy' },
  })
  const { data: vaultTokensMulti } = useReadContract({
    address: vaultAddress,
    abi: vaultTokensAbi,
    functionName: 'vaultTokens',
    chainId,
    query: { enabled: product.productType === 'strategy' },
  })

  const underlyingTokens = useMemo(() => {
    const raw = Array.isArray(vaultTokensMulti)
      ? vaultTokensMulti
      : Array.isArray(vaultTokensLegacy)
        ? vaultTokensLegacy
        : []
    return (raw as unknown[]).filter((t): t is `0x${string}` => typeof t === 'string' && t.startsWith('0x'))
  }, [vaultTokensLegacy, vaultTokensMulti])

  useEffect(() => {
    if (mode === 'deposit' && underlyingTokens[0] && !tokenIn) {
      setTokenIn(underlyingTokens[0])
    }
    if (mode === 'withdraw') {
      setTokenIn(vaultAddress)
    }
  }, [mode, underlyingTokens, tokenIn, vaultAddress])

  const assetForBalance =
    mode === 'deposit' ? (tokenIn as `0x${string}` | undefined) : vaultAddress

  const { data: decimals } = useReadContract({
    address: assetForBalance,
    abi: erc20Abi,
    functionName: 'decimals',
    chainId,
    query: { enabled: !!assetForBalance },
  })

  const { data: symbol } = useReadContract({
    address: assetForBalance,
    abi: erc20Abi,
    functionName: 'symbol',
    chainId,
    query: { enabled: !!assetForBalance },
  })

  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: assetForBalance,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!assetForBalance && !!address },
  })

  const dec = typeof decimals === 'number' ? decimals : 18
  const parsedAmount = useMemo(() => {
    if (!amount) return undefined
    try {
      return parseUnits(amount, dec)
    } catch {
      return undefined
    }
  }, [amount, dec])

  const approval = useApprovalFlow({
    tokenAddress: mode === 'deposit' ? (tokenIn as `0x${string}`) || null : vaultAddress,
    permit2Address,
    routerAddress,
    publicClient: publicClient ?? null,
    address: address ?? null,
    writeContractAsync: writeContractAsync as any,
    effectiveApprovalMode: 'explicit',
    resolvedChainId: chainId,
    routerHasBytecode: routerAddress ? true : null,
    effectiveAmount: parsedAmount,
  })

  const withdrawTokenOut = underlyingTokens[0] as `0x${string}` | undefined

  const runDeposit = useCallback(async () => {
    if (!routerAddress || !publicClient || !address || !parsedAmount || parsedAmount <= BigInt(0)) {
      setStatus('Connect wallet, select amount, and ensure router is configured.')
      return
    }
    if (mode === 'deposit' && !tokenIn) {
      setStatus('Select an underlying token to deposit.')
      return
    }
    if (mode === 'withdraw' && !withdrawTokenOut) {
      setStatus('Vault underlying tokens unavailable for withdraw.')
      return
    }

    try {
      setStatus('')
      setSuccessHash(null)
      setTxPhase('approve')

      // Real approval path: Token → Permit2 → Router (same helper as Swap / staking mint).
      if (approval.needsTokenApproval || approval.needsPermit2Approval) {
        await approval.handleApproval()
      }

      setTxPhase('submit')
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200)
      const minOut = BigInt(0) // honest min; user can refine via Swap for slippage control

      // Args match proven Swap Strategy Vault Deposit / Withdrawal routes (routeMatcher).
      const args =
        mode === 'deposit'
          ? buildStrategyVaultDepositArgs({
              vault: vaultAddress,
              tokenIn: tokenIn as `0x${string}`,
              amountIn: parsedAmount,
              minAmountOut: minOut,
              deadline,
            })
          : buildStrategyVaultWithdrawArgs({
              vault: vaultAddress,
              tokenOut: withdrawTokenOut as `0x${string}`,
              amountIn: parsedAmount,
              minAmountOut: minOut,
              deadline,
            })

      const hash = await writeContractAsync({
        address: routerAddress,
        abi: swapExactInAbi,
        functionName: 'swapSingleTokenExactIn',
        args: [...args],
        chainId,
      })

      await publicClient.waitForTransactionReceipt({ hash })
      setSuccessHash(hash)
      setTxPhase('done')
      setStatus(mode === 'deposit' ? 'Position live.' : 'Withdraw complete.')
      setAmount('')
      void refetchBalance()
      void approval.refetchAllowance()
      void approval.refetchPermit2Allowance()
    } catch (e: any) {
      setTxPhase('error')
      setStatus(e?.shortMessage || e?.message || 'Transaction failed')
    }
  }, [
    routerAddress,
    publicClient,
    address,
    parsedAmount,
    mode,
    tokenIn,
    withdrawTokenOut,
    approval,
    writeContractAsync,
    vaultAddress,
    chainId,
    refetchBalance,
  ])

  if (product.productType !== 'strategy') {
    return (
      <Card>
        <h3 className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Deposit via DETF flows</h3>
        <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
          Protocol and seigniorage DETFs use mint / bond / sell rather than a single vault share deposit.
          Use the DETF actions below, or open the full workspace.
        </p>
        <div className="mt-3">
          <Link href={`/staking?detf=${product.address}`}>
            <Button variant="secondary" size="sm">
              Open DETF workspace
            </Button>
          </Link>
        </div>
      </Card>
    )
  }

  if (!isConnected) {
    return (
      <Card>
        <p className="text-sm text-[var(--text-muted,#9aa3b2)]">Connect your wallet to deposit.</p>
      </Card>
    )
  }

  const steps = [
    {
      id: 'approve',
      label: 'Approve tokens',
      status:
        txPhase === 'approve'
          ? ('active' as const)
          : txPhase === 'submit' || txPhase === 'done'
            ? ('done' as const)
            : txPhase === 'error'
              ? ('error' as const)
              : ('pending' as const),
    },
    {
      id: 'submit',
      label: mode === 'deposit' ? 'Deposit via router' : 'Withdraw via router',
      status:
        txPhase === 'submit'
          ? ('active' as const)
          : txPhase === 'done'
            ? ('done' as const)
            : txPhase === 'error'
              ? ('error' as const)
              : ('pending' as const),
    },
  ]

  return (
    <Card>
      <div className="flex gap-2 mb-4">
        <Button
          data-testid="earn-mode-deposit"
          size="sm"
          variant={mode === 'deposit' ? 'primary' : 'secondary'}
          onClick={() => {
            setMode('deposit')
            setTokenIn(underlyingTokens[0] || '')
            setTxPhase('idle')
            setStatus('')
          }}
        >
          Deposit
        </Button>
        <Button
          data-testid="earn-mode-withdraw"
          size="sm"
          variant={mode === 'withdraw' ? 'primary' : 'secondary'}
          onClick={() => {
            setMode('withdraw')
            setTokenIn(vaultAddress)
            setTxPhase('idle')
            setStatus('')
          }}
        >
          Withdraw
        </Button>
      </div>

      {mode === 'deposit' && underlyingTokens.length > 0 ? (
        <label className="block text-xs text-[var(--text-muted,#9aa3b2)] mb-3">
          Asset
          <select
            data-testid="earn-deposit-asset"
            className="mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]"
            value={tokenIn}
            onChange={(e) => setTokenIn(e.target.value as `0x${string}`)}
          >
            {underlyingTokens.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </label>
      ) : null}

      <label className="block text-xs text-[var(--text-muted,#9aa3b2)]">
        Amount {symbol ? `(${String(symbol)})` : ''}
        <div className="mt-1 flex gap-2">
          <input
            data-testid="earn-deposit-amount"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
            className="flex-1 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 font-mono text-sm tabular-nums text-[var(--text-primary,#EDEDED)]"
          />
          <Button
            size="sm"
            variant="secondary"
            onClick={() => {
              if (typeof balance === 'bigint') setAmount(formatUnits(balance, dec))
            }}
          >
            Max
          </Button>
        </div>
      </label>

      <p className="mt-2 text-[11px] text-[var(--text-muted,#9aa3b2)]">
        Balance:{' '}
        <span className="font-mono">
          {typeof balance === 'bigint' ? formatUnits(balance, dec) : '—'}
        </span>
      </p>
      <p className="mt-1 text-[11px] text-[var(--text-muted,#9aa3b2)]">
        Fees: protocol/router fees apply on-chain. Use Swap for advanced slippage.
      </p>

      {!routerAddress ? (
        <p className="mt-3 text-sm text-red-300">Router not configured for this environment.</p>
      ) : null}

      <div className="mt-4">
        <TxSteps steps={steps} />
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <Button
          data-testid="earn-deposit-submit"
          loading={isPending || txPhase === 'approve' || txPhase === 'submit'}
          disabled={!routerAddress || !parsedAmount}
          onClick={() => void runDeposit()}
        >
          {mode === 'deposit' ? 'Deposit' : 'Withdraw'}
        </Button>
        {txPhase === 'done' ? (
          <Link href="/portfolio">
            <Button variant="secondary">View portfolio</Button>
          </Link>
        ) : null}
        <Link
          href={`/swap?tokenOut=${vaultAddress}`}
          className="inline-flex items-center text-xs text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
        >
          Advanced via Swap →
        </Link>
      </div>

      {status ? (
        <p
          data-testid="earn-deposit-status"
          className={`mt-3 text-sm ${txPhase === 'error' ? 'text-red-300' : 'text-[var(--accent,#4FD44B)]'}`}
        >
          {status}
        </p>
      ) : null}
      {successHash ? (
        <p
          data-testid="earn-deposit-tx-hash"
          className="mt-1 font-mono text-[10px] text-[var(--text-muted,#9aa3b2)] break-all"
        >
          {successHash}
        </p>
      ) : null}
    </Card>
  )
}

export default DepositPanel
