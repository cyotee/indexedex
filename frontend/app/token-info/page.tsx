'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { useAccount, useConnection, useConnectorClient, usePublicClient, useWalletClient } from 'wagmi'
import { erc20Abi, formatUnits } from 'viem'
import { debugError, debugLog, debugWarn } from '../lib/debug'
import { useBrowserChainId, useConnectedWalletChainId } from '../lib/browserChain'
import { useDeploymentEnvironment } from '../lib/deploymentEnvironment'
import { useSelectedNetwork } from '../lib/networkSelection'

import {
  CHAIN_ID_SEPOLIA,
  getAddressArtifacts,
  isSupportedChainId,
  resolveArtifactsChainId,
} from '../lib/addressArtifacts'
import {
  getBaseTokensForChain,
  getErc4626TokensForChain,
  getProtocolDetfTokensForChain,
  getSeigniorageDetfsForChain,
  getStrategyVaultTokensForChain,
  getUniV2PoolTokensForChain,
  getAerodromePoolTokensForChain,
  getBalancerPoolTokensForChain,
} from '../lib/tokenlists'
import type { TokenListEntry } from '../lib/tokenlists'

interface TokenInfo {
  address: string
  name: string
  symbol: string
  decimals: number
  balance: string
}

export default function TokenInfoPage() {
  const { address, chainId: accountChainId, isConnected } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const { selectedChainId } = useSelectedNetwork()
  const connection = useConnection()
  const connectedWalletChainId = useConnectedWalletChainId(isConnected, connection.connector)
  const browserChainId = useBrowserChainId(isConnected)
  const { data: connectorClient } = useConnectorClient()
  const { data: walletClient } = useWalletClient()
  const attachedWalletChainId = isConnected
    ? (accountChainId ?? connection.chainId ?? walletClient?.chain?.id ?? connectorClient?.chain?.id ?? connectedWalletChainId ?? browserChainId)
    : undefined
  const resolvedWalletChainId = attachedWalletChainId !== undefined
    ? resolveArtifactsChainId(attachedWalletChainId, environment, selectedChainId)
    : null
  const resolvedChainId = selectedChainId ?? CHAIN_ID_SEPOLIA
  const wagmiPublicClient = usePublicClient({ chainId: resolvedChainId })
  const isUnsupportedChain = isConnected && attachedWalletChainId !== undefined && !isSupportedChainId(attachedWalletChainId, environment)
  const artifacts = useMemo(() => {
    return getAddressArtifacts(resolvedChainId, environment)
  }, [environment, resolvedChainId])
  const platform = artifacts?.platform
  const [ethBalance, setEthBalance] = useState<string>('0')
  const [wethBalance, setWethBalance] = useState<string>('0')
  const [tokenInfos, setTokenInfos] = useState<TokenInfo[]>([])
  const [isLoading, setIsLoading] = useState(false)

  const publicClient = useMemo(() => {
    return wagmiPublicClient ?? null
  }, [wagmiPublicClient])

  const allTokens = useMemo(() => {
    const merged = new Map<string, TokenListEntry>()

    const baseTokens = getBaseTokensForChain(resolvedChainId, environment)
    const erc4626Tokens = getErc4626TokensForChain(resolvedChainId, environment)
    const seigniorageDetfs = getSeigniorageDetfsForChain(resolvedChainId, environment)
    const protocolTokens = getProtocolDetfTokensForChain(resolvedChainId, environment)
    const strategyVaultTokens = getStrategyVaultTokensForChain(resolvedChainId, environment)
    const uniV2PoolTokens = getUniV2PoolTokensForChain(resolvedChainId, environment)
    const aerodromePoolTokens = getAerodromePoolTokensForChain(resolvedChainId, environment)
    const balancerPoolTokens = getBalancerPoolTokensForChain(resolvedChainId, environment)

    for (const t of [
      ...baseTokens,
      ...erc4626Tokens,
      ...seigniorageDetfs,
      ...protocolTokens,
      ...strategyVaultTokens,
      ...uniV2PoolTokens,
      ...aerodromePoolTokens,
      ...balancerPoolTokens,
    ]) {
      merged.set(t.address.toLowerCase(), t)
    }

    return Array.from(merged.values())
  }, [environment, resolvedChainId])

  // Fetch all token information using generic hooks
  const fetchAllTokenInfo = useCallback(async () => {
    if (!publicClient) return

    debugLog('[Token Info] Refresh All button clicked!')
    debugLog('[Token Info] Current state:', {
      address,
      publicClient: !!publicClient,
      allTokens: allTokens.length
    })
    
    if (!address) {
      debugLog('[Token Info] Missing required values - address:', !!address, 'publicClient:', !!publicClient)
      return
    }
    
    setIsLoading(true)
    const infos: TokenInfo[] = []
    
    try {
      debugLog('[Token Info] Fetching ETH balance for address:', address)
      // Fetch ETH balance
      const ethBalance = await publicClient.getBalance({ address: address as `0x${string}` })
      debugLog('[Token Info] ETH balance result:', ethBalance.toString())
      setEthBalance(formatUnits(ethBalance, 18))

      // Fetch WETH balance (useful to distinguish "received WETH" vs "received ETH")
      if (platform?.weth9 && platform.weth9 !== '0x0000000000000000000000000000000000000000') {
        try {
          const rawWethBal = await publicClient.readContract({
            address: platform.weth9 as `0x${string}`,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [address as `0x${string}`]
          })
          setWethBalance(formatUnits(rawWethBal, 18))
        } catch (error) {
          debugWarn('[Token Info] Failed to fetch WETH balance:', error)
        }
      }
      
      // Fetch token information for each address
      debugLog('[Token Info] Starting to fetch info for', allTokens.length, 'tokens')
      for (const tokenEntry of allTokens) {
        const tokenAddress = tokenEntry.address
        try {
          debugLog('[Token Info] Fetching info for token:', tokenAddress)
          const bytecode = await publicClient.getBytecode({ address: tokenAddress as `0x${string}` })
          if (!bytecode || bytecode === '0x') {
            infos.push({
              address: tokenAddress,
              name: tokenEntry.name,
              symbol: tokenEntry.symbol,
              decimals: tokenEntry.decimals,
              balance: 'Not deployed',
            })
            continue
          }

          const [nameRes, symbolRes, decimalsRes, balanceRes] = await Promise.allSettled([
            publicClient.readContract({
              address: tokenAddress as `0x${string}`,
              abi: erc20Abi,
              functionName: 'name',
            }),
            publicClient.readContract({
              address: tokenAddress as `0x${string}`,
              abi: erc20Abi,
              functionName: 'symbol',
            }),
            publicClient.readContract({
              address: tokenAddress as `0x${string}`,
              abi: erc20Abi,
              functionName: 'decimals',
            }),
            publicClient.readContract({
              address: tokenAddress as `0x${string}`,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [address as `0x${string}`],
            }),
          ])

          const name = nameRes.status === 'fulfilled' ? String(nameRes.value) : tokenEntry.name
          const symbol = symbolRes.status === 'fulfilled' ? String(symbolRes.value) : tokenEntry.symbol
          const decimals =
            decimalsRes.status === 'fulfilled' && typeof decimalsRes.value === 'number'
              ? decimalsRes.value
              : tokenEntry.decimals

          const rawBalance = balanceRes.status === 'fulfilled' ? balanceRes.value : BigInt(0)
          
          const tokenInfo = {
            address: tokenAddress,
            name,
            symbol,
            decimals,
            balance: formatUnits(rawBalance, decimals)
          }
          
          debugLog('[Token Info] Token fetch result:', {
            address: tokenAddress,
            name: tokenInfo.name,
            symbol: tokenInfo.symbol,
            balance: tokenInfo.balance
          })
          
          infos.push(tokenInfo)
          
        } catch (error) {
          debugWarn(`Failed to fetch token info for ${tokenAddress}:`, error)
          // Add error entry
          infos.push({
            address: tokenAddress,
            name: 'Error',
            symbol: 'Error',
            decimals: 18,
            balance: 'Error'
          })
        }
      }
      
      debugLog('[Token Info] All tokens fetched successfully. Total tokens:', infos.length)
      setTokenInfos(infos)
      
    } catch (error) {
      debugError('[Token Info] Failed to fetch token information:', error)
    } finally {
      setIsLoading(false)
    }
  }, [address, publicClient, allTokens, platform?.weth9])

  // Refresh ETH balance only
  const refreshEthBalance = useCallback(async () => {
    if (!publicClient) return

    debugLog('[Token Info] Refresh ETH button clicked!')
    debugLog('[Token Info] ETH refresh state:', {
      address,
      publicClient: !!publicClient
    })
    
    if (!address) {
      debugLog('[Token Info] ETH refresh - missing required values')
      return
    }
    
    try {
      debugLog('[Token Info] Fetching ETH balance for address:', address)
      const ethBalance = await publicClient.getBalance({ address: address as `0x${string}` })
      debugLog('[Token Info] ETH balance result:', ethBalance.toString())
      setEthBalance(formatUnits(ethBalance, 18))
    } catch (error) {
      debugError('[Token Info] Failed to refresh ETH balance:', error)
    }
  }, [address, publicClient])

  // Refresh WETH balance only
  const refreshWethBalance = useCallback(async () => {
    if (!publicClient) return

    if (!address) return
    if (!platform?.weth9 || platform.weth9 === '0x0000000000000000000000000000000000000000') return

    try {
      const rawWethBal = await publicClient.readContract({
        address: platform.weth9 as `0x${string}`,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [address as `0x${string}`]
      })
      setWethBalance(formatUnits(rawWethBal, 18))
    } catch (error) {
      debugError('[Token Info] Failed to refresh WETH balance:', error)
    }
  }, [address, publicClient, platform?.weth9])

  // Initial fetch
  useEffect(() => {
    fetchAllTokenInfo()
  }, [fetchAllTokenInfo])

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Token Information</h1>
          <p className="text-gray-300 mt-2">Connect your wallet to view token information</p>
        </div>
      </div>
    )
  }

  if (!address) {
    return (
      <div className="container mx-auto px-4 max-w-3xl">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Token Information</h1>
          <p className="text-gray-300 mt-2">Waiting for wallet…</p>
        </div>
      </div>
    )
  }

  if (isUnsupportedChain) {
    debugWarn('[Token Info] Unsupported wallet chain; falling back to environment chain', {
      walletChainId: attachedWalletChainId,
      resolvedChainId,
      environment,
    })
  }

  return (
    <div className="container mx-auto px-4 max-w-6xl">
      <h1 className="text-3xl font-bold text-white text-center py-8">Token Information</h1>
      {isUnsupportedChain && (
        <div className="mb-4 rounded-lg border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
          Wallet chainId {String(attachedWalletChainId ?? '(unknown)')} is not mapped for {environment}. Showing addresses from chain {resolvedChainId} instead.
        </div>
      )}
      
      {/* ETH + WETH Balances */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <div className="p-4 bg-slate-700/50 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm text-blue-300 font-medium">ETH Balance</div>
              <div className="text-lg text-white">{ethBalance} ETH</div>
            </div>
            <div>
              <button
                onClick={refreshEthBalance}
                className="px-3 py-1 bg-blue-600 text-white rounded-md text-sm hover:bg-blue-700"
              >
                Refresh ETH
              </button>
            </div>
          </div>
        </div>

        <div className="p-4 bg-slate-700/50 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm text-emerald-300 font-medium">WETH Balance</div>
              <div className="text-lg text-white">{wethBalance} WETH</div>
              {platform?.weth9 ? <div className="text-xs text-gray-400 break-all">{platform.weth9}</div> : null}
            </div>
            <div className="space-x-2">
              <button
                onClick={refreshWethBalance}
                className="px-3 py-1 bg-emerald-600 text-white rounded-md text-sm hover:bg-emerald-700"
              >
                Refresh WETH
              </button>
              <button
                onClick={fetchAllTokenInfo}
                className="px-3 py-1 bg-green-600 text-white rounded-md text-sm hover:bg-green-700"
              >
                Refresh All
              </button>
            </div>
          </div>
        </div>
      </div>
      
      {/* Loading State */}
      {isLoading && (
        <div className="text-center py-8">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-400 mx-auto mb-4"></div>
          <p className="text-gray-300">Loading token information...</p>
        </div>
      )}
      
      {/* Token Table */}
      {!isLoading && tokenInfos.length > 0 && (
        <div className="overflow-x-auto">
          <table className="w-full bg-slate-700/50 rounded-lg">
            <thead>
              <tr className="border-b border-slate-600">
                <th className="text-left p-4 text-gray-300">Token</th>
                <th className="text-left p-4 text-gray-300">Address</th>
                <th className="text-left p-4 text-gray-300">Balance</th>
              </tr>
            </thead>
            <tbody>
              {tokenInfos.map((token, index) => (
                <tr key={token.address} className="border-b border-slate-600/50">
                  <td className="p-4">
                    <div>
                      <div className="font-medium text-white">{token.name}</div>
                      <div className="text-sm text-gray-400">{token.symbol}</div>
                    </div>
                  </td>
                  <td className="p-4">
                    <div className="text-xs text-gray-400 font-mono break-all">
                      {token.address}
                    </div>
                  </td>
                  <td className="p-4">
                    <div className="text-white">
                      {token.balance === 'Error' ? (
                        <span className="text-red-400">Error</span>
                      ) : token.balance === 'Not deployed' ? (
                        <span className="text-amber-300">Not deployed</span>
                      ) : (
                        `${token.balance} ${token.symbol}`
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      
    </div>
  )
}
