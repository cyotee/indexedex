'use client'

import { useMemo } from 'react'
import { useAccount, useBalance, useReadContract, useReadContracts } from 'wagmi'
import { erc20Abi, formatUnits } from 'viem'
import { debugWarn } from '../lib/debug'
import { useDeploymentEnvironment } from '../lib/deploymentEnvironment'
import { useSelectedNetwork } from '../lib/networkSelection'

import {
  CHAIN_ID_SEPOLIA,
  getAddressArtifacts,
} from '../lib/addressArtifacts'
import { selectFromMenu } from '../lib/tokenlists'
import { resolveLabel } from '../lib/tokenlistCompose'
import type { TokenListEntry } from '../lib/tokenlists'

export default function TokenInfoPage() {
  const { address, isConnected } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const { selectedChainId } = useSelectedNetwork()
  const resolvedChainId = selectedChainId ?? CHAIN_ID_SEPOLIA

  const artifacts = useMemo(() => {
    return getAddressArtifacts(resolvedChainId, environment)
  }, [environment, resolvedChainId])
  const platform = artifacts?.platform
  const wethAddress =
    platform?.weth9 && platform.weth9 !== '0x0000000000000000000000000000000000000000'
      ? (platform.weth9 as `0x${string}`)
      : undefined

  // Fed by the 'token-info' menu — every chain-keyed Token List bucket merged
  // by address. The Token List supplies name/symbol/decimals, so the only
  // on-chain read we need per row is balanceOf.
  const allTokens = useMemo(() => {
    const merged = new Map<string, TokenListEntry>()
    for (const { token } of selectFromMenu('token-info', resolvedChainId)) {
      const entry: TokenListEntry = {
        chainId: token.chainId,
        address: token.address as `0x${string}`,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        display: resolveLabel(token),
      }
      merged.set(entry.address.toLowerCase(), entry)
    }
    return Array.from(merged.values())
  }, [resolvedChainId])

  const {
    data: ethBalanceData,
    refetch: refetchEth,
  } = useBalance({
    address,
    chainId: resolvedChainId,
    query: { enabled: !!address },
  })

  const {
    data: wethBalanceRaw,
    refetch: refetchWeth,
  } = useReadContract({
    address: wethAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: resolvedChainId,
    query: { enabled: !!address && !!wethAddress },
  })

  const {
    data: balanceResults,
    refetch: refetchAll,
  } = useReadContracts({
    contracts: allTokens.map((t) => ({
      address: t.address,
      abi: erc20Abi,
      functionName: 'balanceOf' as const,
      args: [address ?? '0x0000000000000000000000000000000000000000'] as const,
      chainId: resolvedChainId,
    })),
    query: { enabled: !!address && allTokens.length > 0 },
  })

  const ethBalance = ethBalanceData ? formatUnits(ethBalanceData.value, 18) : '0'
  const wethBalance =
    typeof wethBalanceRaw === 'bigint' ? formatUnits(wethBalanceRaw, 18) : '0'

  const rows = useMemo(() => {
    return allTokens.map((entry, idx) => {
      const result = balanceResults?.[idx]
      let balance: string
      if (!result) {
        balance = '—'
      } else if (result.status === 'failure') {
        debugWarn('[Token Info] balanceOf failed', {
          address: entry.address,
          error: (result as { error?: unknown }).error,
        })
        balance = 'Not deployed'
      } else {
        balance = formatUnits(result.result as bigint, entry.decimals)
      }
      return {
        address: entry.address,
        name: entry.name,
        symbol: entry.symbol,
        balance,
      }
    })
  }, [allTokens, balanceResults])

  const refreshAll = () => {
    refetchEth()
    refetchWeth()
    refetchAll()
  }

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

  return (
    <div className="container mx-auto px-4 max-w-6xl">
      <h1 className="text-3xl font-bold text-white text-center py-8">Token Information</h1>

      {/* ETH + WETH Balances */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <div className="p-4 bg-slate-700/50 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm text-blue-300 font-medium">ETH Balance</div>
              <div className="text-lg text-white">{ethBalance} ETH</div>
            </div>
            <button
              onClick={() => refetchEth()}
              className="px-3 py-1 bg-blue-600 text-white rounded-md text-sm hover:bg-blue-700"
            >
              Refresh ETH
            </button>
          </div>
        </div>

        <div className="p-4 bg-slate-700/50 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm text-emerald-300 font-medium">WETH Balance</div>
              <div className="text-lg text-white">{wethBalance} WETH</div>
              {wethAddress ? (
                <div className="text-xs text-gray-400 break-all">{wethAddress}</div>
              ) : null}
            </div>
            <div className="space-x-2">
              <button
                onClick={() => refetchWeth()}
                className="px-3 py-1 bg-emerald-600 text-white rounded-md text-sm hover:bg-emerald-700"
              >
                Refresh WETH
              </button>
              <button
                onClick={refreshAll}
                className="px-3 py-1 bg-green-600 text-white rounded-md text-sm hover:bg-green-700"
              >
                Refresh All
              </button>
            </div>
          </div>
        </div>
      </div>

      {rows.length > 0 && (
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
              {rows.map((token) => (
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
                      {token.balance === 'Not deployed' ? (
                        <span className="text-amber-300">Not deployed</span>
                      ) : token.balance === '—' ? (
                        <span className="text-gray-500">—</span>
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
