import { useCallback, useEffect, useMemo, useState } from 'react'
import type { PublicClient } from 'viem'
import { erc20Abi } from 'viem'

// Local alias for the minimal writeContractAsync shape used by Wagmi's useWriteContract
export type WriteContractAsync = (args: {
  address: `0x${string}` | string
  abi: any
  functionName: string
  args?: any[]
  value?: bigint | undefined
}) => Promise<`0x${string}`>

const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as `0x${string}`
export const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)

const PERMIT2_APPROVE_ABI = [
  {
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' },
    ],
    name: 'approve',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  }
] as const

export type Permit2Allowance = readonly [bigint, number, number]

export type UseApprovalFlowConfig = {
  tokenAddress?: `0x${string}` | null
  permit2Address?: `0x${string}` | null
  routerAddress?: `0x${string}` | null
  publicClient: PublicClient | null
  address?: `0x${string}` | null
  writeContractAsync: WriteContractAsync
  effectiveApprovalMode: 'explicit' | 'signed'
  // Optional environment checks (best-effort)
  rpcChainId?: number | null
  resolvedChainId?: number | null
  routerHasBytecode?: boolean | null
  // Effective amount to check against (effectiveAmountIn)
  effectiveAmount?: bigint | undefined
}

export function useApprovalFlow(config: UseApprovalFlowConfig) {
  const {
    tokenAddress,
    permit2Address,
    routerAddress,
    publicClient,
    address,
    writeContractAsync,
    effectiveApprovalMode,
    rpcChainId,
    resolvedChainId,
    routerHasBytecode,
    effectiveAmount,
  } = config

  const [approvalState, setApprovalState] = useState<'idle' | 'approving' | 'success' | 'error'>('idle')
  const [approvalError, setApprovalError] = useState<string>('')
  const [allowancesReady, setAllowancesReady] = useState<boolean>(false)

  const [tokenAllowance, setTokenAllowanceState] = useState<bigint | undefined>(undefined)
  const [permit2Allowance, setPermit2AllowanceState] = useState<Permit2Allowance | undefined>(undefined)

  // Refetchers
  const refetchAllowance = useCallback(async () => {
    if (!publicClient) return undefined
    if (!tokenAddress || !address || !permit2Address) return undefined
    try {
      const data = (await publicClient.readContract({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [address, permit2Address]
      })) as bigint
      setTokenAllowanceState(data)
      return { data }
    } catch (e) {
      return undefined
    }
  }, [publicClient, tokenAddress, address, permit2Address])

  const refetchPermit2Allowance = useCallback(async () => {
    if (!publicClient) return undefined
    if (!permit2Address || !tokenAddress || !address || !routerAddress) return undefined
    try {
      const data = (await publicClient.readContract({
        address: permit2Address,
        abi: [
          {
            inputs: [
              { name: 'owner', type: 'address' },
              { name: 'token', type: 'address' },
              { name: 'spender', type: 'address' }
            ],
            name: 'allowance',
            outputs: [
              { name: 'amount', type: 'uint160' },
              { name: 'expiration', type: 'uint48' },
              { name: 'nonce', type: 'uint48' }
            ],
            stateMutability: 'view',
            type: 'function'
          }
        ],
        functionName: 'allowance',
        args: [address, tokenAddress, routerAddress]
      })) as Permit2Allowance
      setPermit2AllowanceState(data)
      return { data }
    } catch (e) {
      return undefined
    }
  }, [publicClient, permit2Address, tokenAddress, address, routerAddress])

  // Initialize allowances when inputs change
  useEffect(() => {
    void refetchAllowance()
    void refetchPermit2Allowance()
    setAllowancesReady(false)
  }, [tokenAddress, permit2Address, routerAddress, address, effectiveApprovalMode, refetchAllowance, refetchPermit2Allowance])

  const needsTokenApproval = useMemo(() => {
    if (!effectiveAmount || effectiveAmount <= BigInt(0)) return false
    if (tokenAllowance === undefined || tokenAllowance === null) return false
    return tokenAllowance < effectiveAmount
  }, [effectiveAmount, tokenAllowance])

  const needsPermit2Approval = useMemo(() => {
    if (!effectiveAmount || effectiveAmount <= BigInt(0)) return false
    if (permit2Allowance === undefined || permit2Allowance === null) return false
    return permit2Allowance[0] < effectiveAmount
  }, [effectiveAmount, permit2Allowance])

  // Helper: set token allowance with reset-to-zero fallback
  const setTokenAllowance = useCallback(async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
    const client = publicClient
    if (!client) throw new Error('RPC client unavailable')
    if (!writeContractAsync) throw new Error('writeContractAsync unavailable')

    // Try direct approve first
    try {
      const hash = await writeContractAsync({ address: token, abi: erc20Abi, functionName: 'approve', args: [spender, amount] })
      await client.waitForTransactionReceipt({ hash })
      return
    } catch (e) {
      // fallthrough to reset-to-zero flow
    }

    const hash0 = await writeContractAsync({ address: token, abi: erc20Abi, functionName: 'approve', args: [spender, BigInt(0)] })
    await client.waitForTransactionReceipt({ hash: hash0 })
    const hash1 = await writeContractAsync({ address: token, abi: erc20Abi, functionName: 'approve', args: [spender, amount] })
    await client.waitForTransactionReceipt({ hash: hash1 })
  }, [publicClient, writeContractAsync])

  // Helper: set Permit2 allowance with reset-to-zero fallback
  const setPermit2Allowance = useCallback(async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
    const client = publicClient
    if (!client) throw new Error('RPC client unavailable')
    if (!writeContractAsync) throw new Error('writeContractAsync unavailable')
    if (!permit2Address) throw new Error('Permit2 not deployed')

    const threeDaysSecs = 3 * 24 * 60 * 60
    const expiration = Math.floor(Date.now() / 1000) + threeDaysSecs

    // Try direct approve first
    try {
      const hash = await writeContractAsync({ address: permit2Address, abi: PERMIT2_APPROVE_ABI, functionName: 'approve', args: [token, spender, amount, expiration] })
      await client.waitForTransactionReceipt({ hash })
      return
    } catch (e) {
      // fallthrough
    }

    const hash0 = await writeContractAsync({ address: permit2Address, abi: PERMIT2_APPROVE_ABI, functionName: 'approve', args: [token, spender, BigInt(0), expiration] })
    await client.waitForTransactionReceipt({ hash: hash0 })
    const hash1 = await writeContractAsync({ address: permit2Address, abi: PERMIT2_APPROVE_ABI, functionName: 'approve', args: [token, spender, amount, expiration] })
    await client.waitForTransactionReceipt({ hash: hash1 })
  }, [publicClient, writeContractAsync, permit2Address])

  // High-level orchestrator - similar semantics to swap page's handleApproval
  const handleApproval = useCallback(async () => {
    if (!effectiveAmount || effectiveAmount <= BigInt(0)) return
    if (!publicClient) {
      setApprovalState('error')
      setApprovalError('RPC client unavailable')
      return
    }
    if (!tokenAddress || !address) return
    if (!permit2Address) {
      setApprovalState('error')
      setApprovalError('Permit2 not deployed')
      return
    }
    if (!routerAddress || routerHasBytecode !== true) {
      setApprovalState('error')
      setApprovalError('Router not deployed')
      return
    }
    if (rpcChainId !== null && rpcChainId !== undefined && resolvedChainId !== undefined && rpcChainId !== resolvedChainId) {
      setApprovalState('error')
      setApprovalError(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      return
    }

    setApprovalState('approving')
    setApprovalError('')
    setAllowancesReady(false)

    try {
      // Signed mode: only Token -> Permit2
      if (effectiveApprovalMode === 'signed') {
        if (needsTokenApproval) {
          await setTokenAllowance(tokenAddress, permit2Address, MAX_UINT160)
        }
      } else {
        // Explicit: Token -> Permit2 then Permit2 -> Router
        if (needsTokenApproval) {
          await setTokenAllowance(tokenAddress, permit2Address, MAX_UINT160)
        }

        if (needsPermit2Approval) {
          const current = permit2Allowance?.[0] ?? BigInt(0)
          const amount = effectiveAmount > current ? effectiveAmount : current
          await setPermit2Allowance(tokenAddress, routerAddress, amount)
        }
      }

      // Verification loop (3 tries, 1s apart)
      let tokenOk = false
      let p2Ok = false
      for (let attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) await new Promise((r) => setTimeout(r, 1000))
        const [a1, a2] = await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
        const ta = (a1?.data ?? tokenAllowance ?? BigInt(0)) as bigint
        const p2 = (a2?.data?.[0] ?? permit2Allowance?.[0] ?? BigInt(0)) as bigint
        tokenOk = ta >= effectiveAmount
        p2Ok = p2 >= effectiveAmount
        const ok = effectiveApprovalMode === 'signed' ? tokenOk : tokenOk && p2Ok
        if (ok) break
      }

      const ok = effectiveApprovalMode === 'signed' ? tokenOk : tokenOk && p2Ok
      setAllowancesReady(ok)

      if (!ok) {
        // log only - transactions were submitted and receipts awaited in helpers
        // keep success UX similar to swap page: mark success but log warning
      }

      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (err) {
      setApprovalState('error')
      setApprovalError(err instanceof Error ? err.message : String(err))
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [
    effectiveAmount,
    publicClient,
    tokenAddress,
    address,
    permit2Address,
    routerAddress,
    routerHasBytecode,
    rpcChainId,
    resolvedChainId,
    effectiveApprovalMode,
    needsTokenApproval,
    needsPermit2Approval,
    permit2Allowance,
    setTokenAllowance,
    setPermit2Allowance,
    refetchAllowance,
    refetchPermit2Allowance,
    tokenAllowance
  ])

  const handleIssuePermit2Approval = useCallback(async (amount?: bigint) => {
    if (!publicClient) {
      setApprovalError('RPC client unavailable')
      return
    }
    if (!tokenAddress || !address) return
    if (!permit2Address) {
      setApprovalError('Permit2 not deployed')
      return
    }

    const to = amount ?? MAX_UINT160
    setApprovalState('approving')
    setApprovalError('')
    try {
      await setTokenAllowance(tokenAddress, permit2Address, to)
      await refetchAllowance()
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (e) {
      setApprovalState('error')
      setApprovalError(e instanceof Error ? e.message : String(e))
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [publicClient, tokenAddress, address, permit2Address, setTokenAllowance, refetchAllowance])

  const handleIssueRouterApproval = useCallback(async (amount?: bigint) => {
    if (!publicClient) {
      setApprovalError('RPC client unavailable')
      return
    }
    if (!tokenAddress || !address) return
    if (!routerAddress || routerHasBytecode !== true) {
      setApprovalError('Router not deployed')
      return
    }
    if (rpcChainId !== null && rpcChainId !== undefined && resolvedChainId !== undefined && rpcChainId !== resolvedChainId) {
      setApprovalError(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      return
    }

    const to = amount ?? (effectiveAmount ?? MAX_UINT160)
    setApprovalState('approving')
    setApprovalError('')
    try {
      await setPermit2Allowance(tokenAddress, routerAddress, to)
      await refetchPermit2Allowance()
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (e) {
      setApprovalState('error')
      setApprovalError(e instanceof Error ? e.message : String(e))
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [publicClient, tokenAddress, address, routerAddress, routerHasBytecode, rpcChainId, resolvedChainId, effectiveAmount, setPermit2Allowance, refetchPermit2Allowance])

  return {
    approvalState,
    approvalError,
    needsTokenApproval,
    needsPermit2Approval,
    tokenAllowance,
    permit2Allowance,
    handleApproval,
    handleIssuePermit2Approval,
    handleIssueRouterApproval,
    setTokenAllowance,
    setPermit2Allowance,
    refetchAllowance,
    refetchPermit2Allowance,
    allowancesReady,
  } as const
}

export default useApprovalFlow
