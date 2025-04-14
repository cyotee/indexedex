'use client'

import { useAccount, useChainId } from 'wagmi'
import { useState, useMemo } from 'react'
import { createUseReadContract } from 'wagmi/codegen'
import DebugPanel from '../components/DebugPanel'

// Token list helpers
import { getBalancerPoolTokensForChain, getStrategyVaultTokensForChain } from '../lib/tokenlists'

// Define the interfaces we'll be using
const IPoolInfoABI = [
  {
    type: 'function',
    name: 'getTokens',
    inputs: [],
    outputs: [{ name: 'tokens', type: 'address[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getTokenInfo',
    inputs: [],
    outputs: [
      { name: 'tokens', type: 'address[]' },
      { name: 'tokenInfo', type: 'tuple[]', components: [
        { name: 'tokenType', type: 'uint8' },
        { name: 'rateProvider', type: 'address' },
        { name: 'paysYieldFees', type: 'bool' }
      ]},
      { name: 'balancesRaw', type: 'uint256[]' },
      { name: 'lastBalancesLiveScaled18', type: 'uint256[]' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getCurrentLiveBalances',
    inputs: [],
    outputs: [{ name: 'balancesLiveScaled18', type: 'uint256[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getStaticSwapFeePercentage',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getAggregateFeePercentages',
    inputs: [],
    outputs: [
      { name: 'aggregateSwapFeePercentage', type: 'uint256' },
      { name: 'aggregateYieldFeePercentage', type: 'uint256' }
    ],
    stateMutability: 'view'
  }
] as const

const IRateProviderABI = [
  {
    type: 'function',
    name: 'getRate',
    inputs: [],
    outputs: [{ name: 'rate', type: 'uint256' }],
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
  }
] as const

// Create the hooks
const useReadPoolInfo = createUseReadContract({
  abi: IPoolInfoABI,
})

const useReadUniswapV2Pair = createUseReadContract({
  abi: IUniswapV2PairABI,
})

const useReadERC20 = createUseReadContract({
  abi: IERC20ABI,
})

const useReadRateProvider = createUseReadContract({
  abi: IRateProviderABI,
})

interface PoolComparison {
  poolName: string
  poolAddress: string
  poolTokens: {
    address: string
    name: string
    symbol: string
    decimals: number
    tokenType: 'STANDARD' | 'WITH_RATE'
    rateProvider?: string
    paysYieldFees: boolean
    rate?: bigint
    balanceRaw: bigint
    balanceLiveScaled18: bigint
    adjustedBalance?: bigint
  }[]
  strategyVaults: {
    name: string
    address: string
    underlyingPool: string
    token0: string
    token1: string
    token0Name: string
    token1Name: string
    uniswapReserves: {
      reserve0: bigint
      reserve1: bigint
    }
    balancerPrice?: number
    uniswapPrice?: number
    priceDifference?: number
  }[]
  poolFees: {
    staticSwapFeePercentage: bigint
    aggregateSwapFeePercentage: bigint
    aggregateYieldFeePercentage: bigint
  }
}

export default function InsightsPage() {
  const { address, isConnected } = useAccount()
  const chainId = useChainId()
  const resolvedChainId = chainId || 11155111
  const [selectedPool, setSelectedPool] = useState<string>('')

  // Filter for Balancer pools that include vault share tokens ("vault-token pools")
  const strategyVaultPools = useMemo(() => {
    // Deployed pool names follow: "<Something> Vault + <Underlying> BalancerV3 Pool"
    const balancerPools = getBalancerPoolTokensForChain(resolvedChainId)
    return balancerPools
      .filter((p) => /Vault\s*\+/i.test(p.name) || /Vault\s*\+/i.test(p.symbol) || /StrategyVault/i.test(p.name) || /StrategyVault/i.test(p.symbol))
      .map(p => ({ name: p.name, address: p.address as `0x${string}` }))
  }, [resolvedChainId])

  // Read pool tokens
  const { data: poolTokens } = useReadPoolInfo({
    address: selectedPool as `0x${string}`,
    functionName: 'getTokens',
    query: {
      enabled: !!selectedPool
    }
  })

  // Read pool token info
  const { data: poolTokenInfo } = useReadPoolInfo({
    address: selectedPool as `0x${string}`,
    functionName: 'getTokenInfo',
    query: {
      enabled: !!selectedPool
    }
  })

  // Read current live balances
  const { data: poolBalances } = useReadPoolInfo({
    address: selectedPool as `0x${string}`,
    functionName: 'getCurrentLiveBalances',
    query: {
      enabled: !!selectedPool
    }
  })

  // Read pool fees
  const { data: staticSwapFeePercentage } = useReadPoolInfo({
    address: selectedPool as `0x${string}`,
    functionName: 'getStaticSwapFeePercentage',
    query: {
      enabled: !!selectedPool
    }
  })

  const { data: aggregateFees } = useReadPoolInfo({
    address: selectedPool as `0x${string}`,
    functionName: 'getAggregateFeePercentages',
    query: {
      enabled: !!selectedPool
    }
  })

  // Find strategy vaults in the selected pool
  const strategyVaultsInPool = useMemo(() => {
    const tokens: readonly `0x${string}`[] = Array.isArray(poolTokens)
      ? (poolTokens as readonly `0x${string}`[])
      : []

    if (tokens.length === 0) return []

    const vaultList = getStrategyVaultTokensForChain(resolvedChainId)
    return tokens
      .map(tokenAddress => {
        const v = vaultList.find(v => v.address.toLowerCase() === tokenAddress.toLowerCase())
        return v ? { name: v.name || v.symbol, address: v.address } : null
      })
      .filter(Boolean) as { name: string, address: string }[]
  }, [poolTokens, resolvedChainId])

  // Read underlying pool info for each strategy vault
  const { data: vault0Token0 } = useReadUniswapV2Pair({
    address: strategyVaultsInPool[0]?.address as `0x${string}`,
    functionName: 'token0',
    query: {
      enabled: !!strategyVaultsInPool[0]?.address
    }
  })

  const { data: vault0Token1 } = useReadUniswapV2Pair({
    address: strategyVaultsInPool[0]?.address as `0x${string}`,
    functionName: 'token1',
    query: {
      enabled: !!strategyVaultsInPool[0]?.address
    }
  })

  const { data: vault0Reserves } = useReadUniswapV2Pair({
    address: strategyVaultsInPool[0]?.address as `0x${string}`,
    functionName: 'getReserves',
    query: {
      enabled: !!strategyVaultsInPool[0]?.address
    }
  })

  const { data: vault1Token0 } = useReadUniswapV2Pair({
    address: strategyVaultsInPool[1]?.address as `0x${string}`,
    functionName: 'token0',
    query: {
      enabled: !!strategyVaultsInPool[1]?.address
    }
  })

  const { data: vault1Token1 } = useReadUniswapV2Pair({
    address: strategyVaultsInPool[1]?.address as `0x${string}`,
    functionName: 'token1',
    query: {
      enabled: !!strategyVaultsInPool[1]?.address
    }
  })

  const { data: vault1Reserves } = useReadUniswapV2Pair({
    address: strategyVaultsInPool[1]?.address as `0x${string}`,
    functionName: 'getReserves',
    query: {
      enabled: !!strategyVaultsInPool[1]?.address
    }
  })

  // Read token names
  const { data: vault0Token0Name } = useReadERC20({
    address: vault0Token0 as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!vault0Token0
    }
  })

  const { data: vault0Token1Name } = useReadERC20({
    address: vault0Token1 as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!vault0Token1
    }
  })

  const { data: vault1Token0Name } = useReadERC20({
    address: vault1Token0 as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!vault1Token0
    }
  })

  const { data: vault1Token1Name } = useReadERC20({
    address: vault1Token1 as `0x${string}`,
    functionName: 'name',
    query: {
      enabled: !!vault1Token1
    }
  })

  // Read token details for each pool token
  const poolTokenDetails = useMemo(() => {
    const tokens: readonly `0x${string}`[] = Array.isArray(poolTokens)
      ? (poolTokens as readonly `0x${string}`[])
      : []

    const tokenInfoRows: readonly any[] =
      Array.isArray(poolTokenInfo) && Array.isArray((poolTokenInfo as any)[1]) ? ((poolTokenInfo as any)[1] as any[]) : []
    const balancesRaw: readonly bigint[] =
      Array.isArray(poolTokenInfo) && Array.isArray((poolTokenInfo as any)[2]) ? ((poolTokenInfo as any)[2] as bigint[]) : []

    const liveBalances: readonly bigint[] = Array.isArray(poolBalances) ? (poolBalances as bigint[]) : []

    if (tokens.length === 0 || tokenInfoRows.length === 0) return []

    return tokens.map((tokenAddress, index) => {
      const tokenInfo = tokenInfoRows[index]
      const balanceRaw = balancesRaw[index]
      const balanceLiveScaled18 = liveBalances[index]

      return {
        address: tokenAddress,
        tokenType: tokenInfo?.tokenType === 0 ? 'STANDARD' : 'WITH_RATE',
        rateProvider:
          tokenInfo?.rateProvider && tokenInfo.rateProvider !== '0x0000000000000000000000000000000000000000'
            ? tokenInfo.rateProvider
            : undefined,
        paysYieldFees: Boolean(tokenInfo?.paysYieldFees),
        balanceRaw,
        balanceLiveScaled18,
      }
    })
  }, [poolTokens, poolTokenInfo, poolBalances])

  const poolTokensList = useMemo(() => {
    return Array.isArray(poolTokens) ? (poolTokens as readonly `0x${string}`[]) : ([] as const)
  }, [poolTokens])

  const poolBalancesList = useMemo(() => {
    return Array.isArray(poolBalances) ? (poolBalances as readonly bigint[]) : ([] as const)
  }, [poolBalances])

  const poolToken0 = useMemo(() => {
    if (!Array.isArray(poolTokens) || poolTokens.length === 0) return undefined
    return (poolTokens[0] ?? undefined) as `0x${string}` | undefined
  }, [poolTokens])

  // Read token names, symbols, and decimals for pool tokens
  const poolTokenNames = useReadERC20({
    address: poolToken0,
    functionName: 'name',
    query: {
      enabled: !!poolToken0
    }
  })

  const poolTokenSymbols = useReadERC20({
    address: poolToken0,
    functionName: 'symbol',
    query: {
      enabled: !!poolToken0
    }
  })

  const poolTokenDecimals = useReadERC20({
    address: poolToken0,
    functionName: 'decimals',
    query: {
      enabled: !!poolToken0
    }
  })

  // Read rate provider rates for tokens that have them
  const rateProviderRates = useMemo(() => {
    const rates: { [address: string]: bigint } = {}
    
    poolTokenDetails.forEach(token => {
      if (token.rateProvider) {
        // We'll read the rate for each rate provider
        // This would need to be done with individual useReadRateProvider calls
        // For now, we'll set a placeholder
        rates[token.address] = BigInt(0) // Placeholder
      }
    })
    
    return rates
  }, [poolTokenDetails])

  // Calculate prices and differences
  const poolComparison = useMemo((): PoolComparison | null => {
    if (!selectedPool || poolBalancesList.length === 0 || !strategyVaultsInPool.length) return null

    const comparison: PoolComparison = {
      poolName: strategyVaultPools.find(p => p.address === selectedPool)?.name || '',
      poolAddress: selectedPool,
      poolTokens: poolTokenDetails.map((token, index) => ({
        address: token.address,
        name: `Token ${index}`, // Placeholder - would need individual token name reads
        symbol: `T${index}`, // Placeholder
        decimals: 18, // Placeholder
        tokenType: token.tokenType as 'STANDARD' | 'WITH_RATE',
        rateProvider: token.rateProvider,
        paysYieldFees: token.paysYieldFees,
        rate: rateProviderRates[token.address],
        balanceRaw: token.balanceRaw,
        balanceLiveScaled18: token.balanceLiveScaled18,
        adjustedBalance: token.rateProvider ? 
          (token.balanceLiveScaled18 * (rateProviderRates[token.address] || BigInt(1e18)) / BigInt(1e18)) : 
          token.balanceLiveScaled18
      })),
      strategyVaults: [],
      poolFees: {
        staticSwapFeePercentage: typeof staticSwapFeePercentage === 'bigint' ? staticSwapFeePercentage : BigInt(0),
        aggregateSwapFeePercentage:
          Array.isArray(aggregateFees) && aggregateFees[0] !== undefined ? (aggregateFees[0] as bigint) : BigInt(0),
        aggregateYieldFeePercentage:
          Array.isArray(aggregateFees) && aggregateFees[1] !== undefined ? (aggregateFees[1] as bigint) : BigInt(0)
      }
    }

    // Process each strategy vault in the pool
    strategyVaultsInPool.forEach((vault, index) => {
      const token0 = index === 0 ? vault0Token0 : vault1Token0
      const token1 = index === 0 ? vault0Token1 : vault1Token1
      const token0Name = index === 0 ? vault0Token0Name : vault1Token0Name
      const token1Name = index === 0 ? vault0Token1Name : vault1Token1Name
      const reserves = index === 0 ? vault0Reserves : vault1Reserves

      if (typeof token0 === 'string' && typeof token1 === 'string' && Array.isArray(reserves) && reserves[0] !== undefined && reserves[1] !== undefined) {
        // Calculate Uniswap price (token1 per token0)
        const uniswapPrice = Number(reserves[1]) / Number(reserves[0])
        
        // Find corresponding Balancer balance for this vault
        const vaultIndex = poolTokensList.findIndex(addr => addr.toLowerCase() === vault.address.toLowerCase())
        const balancerBalance = vaultIndex !== -1 
          ? poolBalancesList[vaultIndex] 
          : undefined

        // Calculate Balancer price if we have the balance
        let balancerPrice: number | undefined
        if (balancerBalance && poolBalancesList.length > 1) {
          // Find the other token's balance to calculate price
          const otherTokenIndex = vaultIndex === 0 ? 1 : 0
          const otherTokenBalance = poolBalancesList[otherTokenIndex]
          balancerPrice = Number(otherTokenBalance) / Number(balancerBalance)
        }

        const priceDifference = balancerPrice && uniswapPrice 
          ? ((balancerPrice - uniswapPrice) / uniswapPrice) * 100 
          : undefined

        comparison.strategyVaults.push({
          name: vault.name,
          address: vault.address,
          underlyingPool: vault.address, // Same as vault address
          token0,
          token1,
          token0Name: typeof token0Name === 'string' ? token0Name : 'Loading...',
          token1Name: typeof token1Name === 'string' ? token1Name : 'Loading...',
          uniswapReserves: {
            reserve0: (reserves[0] ?? BigInt(0)) as bigint,
            reserve1: (reserves[1] ?? BigInt(0)) as bigint
          },
          balancerPrice,
          uniswapPrice,
          priceDifference
        })
      }
    })

    return comparison
  }, [
    selectedPool, 
    poolBalancesList,
    strategyVaultsInPool, 
    vault0Token0, 
    vault0Token1, 
    vault0Reserves,
    vault1Token0,
    vault1Token1, 
    vault1Reserves,
    vault0Token0Name,
    vault0Token1Name,
    vault1Token0Name,
    vault1Token1Name,
    poolTokensList,
    strategyVaultPools,
    poolTokenDetails,
    rateProviderRates,
    staticSwapFeePercentage,
    aggregateFees
  ])

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Pool Insights</h1>
          <p className="text-gray-300 mt-2">Connect your wallet to view pool information</p>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 max-w-7xl">
      <h1 className="text-3xl font-bold text-white text-center py-8">Pool Insights</h1>
      <p className="text-gray-300 text-center mb-8">
        Compare prices between Balancer pools and underlying Uniswap V2 pools
      </p>
      
      <div className="bg-gray-800 rounded-lg p-6 mb-6">
        <h2 className="text-xl font-semibold text-white mb-4">Select Balancer Pool</h2>
        <select
          value={selectedPool}
          onChange={(e) => setSelectedPool(e.target.value)}
          className="w-full p-3 bg-gray-700 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2 focus-visible:ring-offset-gray-800"
        >
          <option value="">Select a Balancer Pool with Vault Share Tokens</option>
          {strategyVaultPools.map((pool) => (
            <option key={pool.address} value={pool.address}>
              {pool.name} ({pool.address})
            </option>
          ))}
        </select>
      </div>

      {poolComparison && (
        <div className="space-y-6">
          {/* Pool Overview */}
          <div className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-white mb-4">Pool Overview</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Pool Name</label>
                <p className="text-white">{poolComparison.poolName}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Pool Address</label>
                <p className="text-white font-mono text-sm break-all">{poolComparison.poolAddress}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Total Tokens</label>
                <p className="text-white">{poolComparison.poolTokens.length}</p>
              </div>
            </div>
          </div>

          {/* Pool Tokens and Reserves */}
          <div className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-white mb-4">Pool Tokens & Reserves</h2>
            <div className="space-y-4">
              {poolComparison.poolTokens.map((token, index) => (
                <div key={token.address} className="bg-gray-700 rounded-lg p-4">
                  <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                    <div>
                      <h3 className="text-lg font-semibold text-white mb-2">Token {index + 1}</h3>
                      <div className="space-y-1">
                        <p className="text-white font-mono text-sm break-all">{token.address}</p>
                        <p className="text-gray-300 text-sm">{token.name} ({token.symbol})</p>
                        <p className="text-gray-300 text-sm">Decimals: {token.decimals}</p>
                        <p className="text-gray-300 text-sm">Type: {token.tokenType}</p>
                        {token.rateProvider && (
                          <p className="text-gray-300 text-sm">Rate Provider: {token.rateProvider}</p>
                        )}
                        <p className="text-gray-300 text-sm">Pays Yield Fees: {token.paysYieldFees ? 'Yes' : 'No'}</p>
                      </div>
                    </div>
                    <div>
                      <h4 className="text-md font-semibold text-white mb-2">Raw Balances</h4>
                      <div className="space-y-1">
                        <p className="text-white font-mono text-sm">
                          Raw: {token.balanceRaw.toString()}
                        </p>
                        <p className="text-white font-mono text-sm">
                          Live Scaled (18): {token.balanceLiveScaled18.toString()}
                        </p>
                      </div>
                    </div>
                    <div>
                      <h4 className="text-md font-semibold text-white mb-2">Rate Adjusted</h4>
                      <div className="space-y-1">
                        {token.rate && (
                          <p className="text-white font-mono text-sm">
                            Rate: {(Number(token.rate) / 1e18).toFixed(6)}
                          </p>
                        )}
                        {token.adjustedBalance && (
                          <p className="text-white font-mono text-sm">
                            Adjusted: {token.adjustedBalance.toString()}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Pool Fees */}
          <div className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-white mb-4">Pool Fees</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
               <div>
                 <label className="block text-sm font-medium text-gray-300 mb-1">Static Swap Fee</label>
                 <p className="text-white font-mono">
                   {(Number(poolComparison.poolFees.staticSwapFeePercentage) / 1e16).toFixed(4)}%
                 </p>
               </div>
               <div>
                 <label className="block text-sm font-medium text-gray-300 mb-1">Aggregate Swap Fee</label>
                 <p className="text-white font-mono">
                   {(Number(poolComparison.poolFees.aggregateSwapFeePercentage) / 1e16).toFixed(4)}%
                 </p>
               </div>
               <div>
                 <label className="block text-sm font-medium text-gray-300 mb-1">Aggregate Yield Fee</label>
                 <p className="text-white font-mono">
                   {(Number(poolComparison.poolFees.aggregateYieldFeePercentage) / 1e16).toFixed(4)}%
                 </p>
               </div>
            </div>
          </div>

          {/* Price Comparisons */}
          {poolComparison.strategyVaults.map((vault, index) => (
            <div key={vault.address} className="bg-gray-800 rounded-lg p-6">
              <h3 className="text-lg font-semibold text-white mb-4">
                Strategy Vault: {vault.name}
              </h3>
              
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Uniswap V2 Pool Info */}
                <div className="bg-gray-700 rounded-lg p-4">
                  <h4 className="text-md font-semibold text-white mb-3">Underlying Uniswap V2 Pool</h4>
                  <div className="space-y-2">
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Pool Address</label>
                      <p className="text-white font-mono text-sm break-all">{vault.underlyingPool}</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Token 0</label>
                      <p className="text-white">{vault.token0Name} ({vault.token0})</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Token 1</label>
                      <p className="text-white">{vault.token1Name} ({vault.token1})</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Reserves</label>
                      <p className="text-white font-mono text-sm">
                        {vault.token0Name}: {vault.uniswapReserves.reserve0.toString()}
                      </p>
                      <p className="text-white font-mono text-sm">
                        {vault.token1Name}: {vault.uniswapReserves.reserve1.toString()}
                      </p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Uniswap Price</label>
                      <p className="text-white font-mono">
                        {vault.uniswapPrice ? `${vault.uniswapPrice.toFixed(6)} ${vault.token1Name} per ${vault.token0Name}` : 'Calculating...'}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Balancer Pool Info */}
                <div className="bg-gray-700 rounded-lg p-4">
                  <h4 className="text-md font-semibold text-white mb-3">Balancer Pool</h4>
                  <div className="space-y-2">
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Balancer Price</label>
                      <p className="text-white font-mono">
                        {vault.balancerPrice ? `${vault.balancerPrice.toFixed(6)} ${vault.token1Name} per ${vault.token0Name}` : 'Calculating...'}
                      </p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Price Difference</label>
                      <p className={`font-mono ${
                        vault.priceDifference === undefined 
                          ? 'text-gray-400' 
                          : vault.priceDifference > 0 
                            ? 'text-green-400' 
                            : vault.priceDifference < 0 
                              ? 'text-red-400' 
                              : 'text-white'
                      }`}>
                        {vault.priceDifference !== undefined 
                          ? `${vault.priceDifference > 0 ? '+' : ''}${vault.priceDifference.toFixed(2)}%`
                          : 'Calculating...'
                        }
                      </p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-300">Arbitrage Opportunity</label>
                      <p className={`font-semibold ${
                        vault.priceDifference === undefined 
                          ? 'text-gray-400' 
                          : Math.abs(vault.priceDifference) > 1 
                            ? 'text-yellow-400' 
                            : 'text-gray-400'
                      }`}>
                        {vault.priceDifference !== undefined 
                          ? Math.abs(vault.priceDifference) > 1 
                            ? 'Significant arbitrage opportunity detected!'
                            : 'No significant arbitrage opportunity'
                          : 'Calculating...'
                        }
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}

        </div>
      )}
    </div>
  )
}
