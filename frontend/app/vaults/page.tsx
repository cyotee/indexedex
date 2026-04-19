'use client'

import { useAccount } from 'wagmi'
import { useReadContract } from 'wagmi'
import { useState, useMemo } from 'react'
import { createUseReadContract } from 'wagmi/codegen'
import DebugPanel from '../components/DebugPanel'

// Token list helpers
import { getStrategyVaultTokensForChain } from '../lib/tokenlists'
import { useSelectedNetwork } from '../lib/networkSelection'

// Define the interfaces we'll be using
const IStandardVaultABI = [
  {
    type: 'function',
    name: 'vaultTypes',
    inputs: [],
    outputs: [{ name: 'vaultTypes_', type: 'bytes4[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'tokens',
    inputs: [],
    outputs: [{ name: 'tokens_', type: 'address[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'vaultConfig',
    inputs: [],
    outputs: [{
      name: 'vaultConfig_',
      type: 'tuple',
      components: [
        { name: 'vaultTypes', type: 'bytes4[]' },
        { name: 'tokens', type: 'address[]' }
      ]
    }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'reserveOfToken',
    inputs: [{ name: 'token', type: 'address' }],
    outputs: [{ name: 'reserve_', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'reserves',
    inputs: [],
    outputs: [{ name: 'reserves_', type: 'uint256[]' }],
    stateMutability: 'view'
  }
] as const

const IConstantProductStrategyVaultABI = [
  {
    type: 'function',
    name: 'yieldToken',
    inputs: [],
    outputs: [{ name: 'yieldToken_', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'opposingToken',
    inputs: [{ name: 'token', type: 'address' }],
    outputs: [{ name: 'opposingToken_', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'yieldReserveOfToken',
    inputs: [{ name: 'token', type: 'address' }],
    outputs: [{ name: 'reserve_', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

const IUniswapV2PairABI = [
  {
    type: 'function',
    name: 'token0',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'token1',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getReserves',
    inputs: [],
    outputs: [
      { name: '_reserve0', type: 'uint112' },
      { name: '_reserve1', type: 'uint112' },
      { name: '_blockTimestampLast', type: 'uint32' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'kLast',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'totalSupply',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

const IERC20ABI = [
  {
    type: 'function',
    name: 'name',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'symbol',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'decimals',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view'
  }
] as const

// Create the hook
const useReadStrategyVault = createUseReadContract({
  abi: IStandardVaultABI,
})

const useReadConstantProductStrategyVault = createUseReadContract({
  abi: IConstantProductStrategyVaultABI,
})

const useReadUniswapV2Pair = createUseReadContract({
  abi: IUniswapV2PairABI,
})

const useReadERC20 = createUseReadContract({
  abi: IERC20ABI,
})

interface VaultInfo {
  name: string
  address: string
  yieldToken?: string
  token0?: string
  token1?: string
  reserves?: {
    reserve0: bigint
    reserve1: bigint
    blockTimestampLast: number
  }
  kLast?: bigint
  totalSupply?: bigint
  vaultReserves?: bigint[]
  tokenReserves?: {
    [token: string]: bigint
  }
}

export default function VaultsPage() {
  const { address, isConnected } = useAccount()
  const { selectedChainId } = useSelectedNetwork()
  const resolvedChainId = selectedChainId || 11155111
  const [selectedVault, setSelectedVault] = useState<string>('')

  // Get vault options from token list (strategy vault share tokens)
  const vaultOptions = useMemo(() => {
    return getStrategyVaultTokensForChain(resolvedChainId).map((t) => ({
      label: t.display || t.name || t.symbol,
      value: t.address as `0x${string}`
    }))
  }, [resolvedChainId])

  // Read vault tokens
  const { data: vaultTokens } = useReadStrategyVault({
    address: selectedVault as `0x${string}`,
    functionName: 'tokens',
    query: {
      enabled: !!selectedVault
    }
  })

  const vaultTokensList = useMemo(() => {
    return Array.isArray(vaultTokens) ? vaultTokens : undefined
  }, [vaultTokens])

  // Read yield token
  const { data: yieldToken } = useReadConstantProductStrategyVault({
    address: selectedVault as `0x${string}`,
    functionName: 'yieldToken',
    query: {
      enabled: !!selectedVault
    }
  })

  // Read vault reserves
  const { data: vaultReserves } = useReadStrategyVault({
    address: selectedVault as `0x${string}`,
    functionName: 'reserves',
    query: {
      enabled: !!selectedVault
    }
  })

  const vaultReservesList = useMemo(() => {
    if (!vaultReserves || !Array.isArray(vaultReserves)) return undefined
    if (!vaultReserves.every((v) => typeof v === 'bigint')) return undefined
    return vaultReserves as readonly bigint[]
  }, [vaultReserves])

  // Read underlying pool info from the yield token (which is the same as the pool)
  const { data: token0 } = useReadUniswapV2Pair({
    address: yieldToken as `0x${string}`,
    functionName: 'token0',
    query: {
      enabled: !!yieldToken
    }
  })

  const { data: token1 } = useReadUniswapV2Pair({
    address: yieldToken as `0x${string}`,
    functionName: 'token1',
    query: {
      enabled: !!yieldToken
    }
  })

  const { data: poolReserves } = useReadUniswapV2Pair({
    address: yieldToken as `0x${string}`,
    functionName: 'getReserves',
    query: {
      enabled: !!yieldToken
    }
  })

  const poolReservesTuple = useMemo(() => {
    if (!Array.isArray(poolReserves)) return undefined
    const [reserve0, reserve1, blockTimestampLast] = poolReserves as unknown[]
    if (typeof reserve0 !== 'bigint' || typeof reserve1 !== 'bigint') return undefined
    if (typeof blockTimestampLast !== 'number') return undefined
    return [reserve0, reserve1, blockTimestampLast] as const
  }, [poolReserves])

  const { data: kLast } = useReadUniswapV2Pair({
    address: yieldToken as `0x${string}`,
    functionName: 'kLast',
    query: {
      enabled: !!yieldToken
    }
  })

  const { data: totalSupply } = useReadUniswapV2Pair({
    address: yieldToken as `0x${string}`,
    functionName: 'totalSupply',
    query: {
      enabled: !!yieldToken
    }
  })

  // Read token names
  const { data: token0Name } = useReadERC20({
    address: token0 as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!token0
    }
  })

  const { data: token1Name } = useReadERC20({
    address: token1 as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!token1
    }
  })

  const { data: yieldTokenName } = useReadERC20({
    address: yieldToken as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!yieldToken
    }
  })

  // Read individual token reserves
  const { data: token0Reserve } = useReadStrategyVault({
    address: selectedVault as `0x${string}`,
    functionName: 'reserveOfToken',
    args: [token0 as `0x${string}`],
    query: {
      enabled: !!selectedVault && !!token0
    }
  })

  const { data: token1Reserve } = useReadStrategyVault({
    address: selectedVault as `0x${string}`,
    functionName: 'reserveOfToken',
    args: [token1 as `0x${string}`],
    query: {
      enabled: !!selectedVault && !!token1
    }
  })

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Strategy Vaults</h1>
          <p className="text-gray-300 mt-2">Connect your wallet to view vault information</p>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 max-w-6xl">
      <h1 className="text-3xl font-bold text-white text-center py-8">Strategy Vaults</h1>
      
      <div className="bg-gray-800 rounded-lg p-6 mb-6">
        <h2 className="text-xl font-semibold text-white mb-4">Select Vault</h2>
        <select
          value={selectedVault}
          onChange={(e) => setSelectedVault(e.target.value)}
          className="w-full p-3 bg-gray-700 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2 focus-visible:ring-offset-gray-800"
        >
          <option value="">Select a Strategy Vault</option>
          {vaultOptions.map((vault) => (
            <option key={vault.value} value={vault.value}>
              {vault.label}
            </option>
          ))}
        </select>
      </div>

      {selectedVault && (
        <div className="space-y-6">
          {/* Vault Overview */}
          <div className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-white mb-4">Vault Overview</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Vault Address</label>
                <p className="text-white font-mono text-sm break-all">{selectedVault}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Yield Token</label>
                <p className="text-white">
                  {yieldTokenName || 'Loading...'} 
                  {yieldToken && (
                    <span className="text-gray-400 text-sm ml-2">({yieldToken})</span>
                  )}
                </p>
              </div>
            </div>
          </div>

          {/* Underlying Pool Information */}
          {yieldToken && (
            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-xl font-semibold text-white mb-4">Underlying Pool Information</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">Pool Address (Same as Yield Token)</label>
                  <p className="text-white font-mono text-sm break-all">{yieldToken}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">Total Supply</label>
                  <p className="text-white">
                    {totalSupply !== undefined ? totalSupply.toString() : 'Loading...'}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">Token 0</label>
                  <p className="text-white">
                    {token0Name || 'Loading...'} 
                    {token0 && (
                      <span className="text-gray-400 text-sm ml-2">({token0})</span>
                    )}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">Token 1</label>
                  <p className="text-white">
                    {token1Name || 'Loading...'} 
                    {token1 && (
                      <span className="text-gray-400 text-sm ml-2">({token1})</span>
                    )}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Pool Reserves */}
          {poolReservesTuple && (
            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-xl font-semibold text-white mb-4">Pool Reserves</h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">Reserve 0</label>
                  <p className="text-white font-mono">
                    {poolReservesTuple[0].toString()}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">Reserve 1</label>
                  <p className="text-white font-mono">
                    {poolReservesTuple[1].toString()}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">K Last</label>
                  <p className="text-white font-mono">
                    {kLast !== undefined ? kLast.toString() : 'Loading...'}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Vault Reserves */}
          {vaultReservesList && (
            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-xl font-semibold text-white mb-4">Vault Reserves</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">All Reserves</label>
                  <div className="space-y-2">
                    {vaultReservesList.map((reserve, index) => (
                      <p key={index} className="text-white font-mono text-sm">
                        Reserve {index}: {reserve.toString()}
                      </p>
                    ))}
                  </div>
                </div>
                {token0Reserve !== undefined && (
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      {token0Name} Reserve
                    </label>
                    <p className="text-white font-mono">{(token0Reserve as bigint).toString()}</p>
                  </div>
                )}
                {token1Reserve !== undefined && (
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      {token1Name} Reserve
                    </label>
                    <p className="text-white font-mono">{(token1Reserve as bigint).toString()}</p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Debug Information */}
          <DebugPanel title="Vault Debug Information">
            <div>Vault Tokens: {vaultTokensList ? vaultTokensList.length : 'Loading...'}</div>
            <div>Yield Token (Pool): {yieldToken || 'Loading...'}</div>
            <div>Token 0: {token0 || 'Loading...'}</div>
            <div>Token 1: {token1 || 'Loading...'}</div>
          </DebugPanel>
        </div>
      )}
    </div>
  )
}
