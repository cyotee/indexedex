'use client'

import Link from 'next/link'
import { useSearchParams } from 'next/navigation'
import { Suspense, useCallback, useEffect, useMemo, useState } from 'react'
import {
  useAccount,
  useConnection,
  useConnectorClient,
  useWalletClient,
  useWriteContract,
} from 'wagmi'
import { erc20Abi, formatUnits, zeroAddress, parseAbiItem } from 'viem'

import DebugPanel from '../components/DebugPanel'
import { BondNftCard } from '../components/earn/BondNftCard'
import { SharePositionCard } from '../components/earn/SharePositionCard'
import { AddressLink } from '../components/ui/AddressLink'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { EmptyState } from '../components/ui/EmptyState'
import { PageHeader } from '../components/ui/PageHeader'
import { Stat } from '../components/ui/Stat'
import { useBrowserChainId, useConnectedWalletChainId } from '@indexedex/protocol/browserChain'
import { useBrand } from '../lib/brandContext'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { createAppReadClient } from '../create/lib/sePoolRead'
import { resolveSePlatform } from '../create/lib/sePlatform'
import {
  DETF_CREATOR_BOND_NFT_ID,
  DETF_FEE_TO_BOND_NFT_ID,
  isFunctionNotFound,
  readBondNftVault,
  readBondPosition,
  readDetfNftId,
} from '../lib/detf/bondNftVault'
import {
  entryFromAddress,
  loadCreatedDetfs,
  mergeDetfEntries,
  parseDetfQueryAddress,
} from '../lib/detf/createdDetfs'
import { entriesFromAddresses, loadRegisteredVaults, selectDetfsFromVaults } from '../lib/detf/discoverDetfs'
import { formatBondAmount } from '../lib/portfolio/formatBondAmount'
import type { SharePositionInput } from '../lib/portfolio/sanitizeShareFields'
import type { BondNftMetadata, BondPosition, TokenBalance } from '../lib/portfolio/types'

import {
  CHAIN_ID_ROBINHOOD,
  isSupportedChainId,
  resolveArtifactsChainId,
} from '@indexedex/protocol/addressArtifacts'
import { loadFeaturedFeeDetfs } from '../lib/earn/loadEarnProducts'
import {
  feeDetfStakingHref,
  getProtocolDetfsForChain,
  getProtocolDetfTokensForChain,
  getStrategyVaultTokensForChain,
  isFeaturedFeeDetfAddress,
  type TokenListEntry,
} from '@indexedex/protocol/tokenlists'
import { resolveAppChain } from '@indexedex/protocol/runtimeChains'

const ZERO = BigInt(0)

const protocolNftVaultAbi = [
  {
    type: 'function',
    name: 'claimRewards',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'rewards', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'redeemPosition',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [{ name: 'wethOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'rewardToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'getPosition',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      {
        name: 'position',
        type: 'tuple',
        components: [
          { name: 'originalShares', type: 'uint256' },
          { name: 'effectiveShares', type: 'uint256' },
          { name: 'bonusMultiplier', type: 'uint256' },
          { name: 'unlockTime', type: 'uint256' },
          { name: 'rewardDebt', type: 'uint256' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'pendingRewards',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'tokenURI',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ name: '', type: 'string' }],
  },
  {
    type: 'function',
    name: 'ownerOf',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

const transferEvent = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)')

function parseRpcGetLogsMaxRange(message: string): bigint | null {
  // Examples we’ve seen:
  // - “Under the Free tier plan, you can make eth_getLogs requests with up to a 10 block range.”
  // - “this block range should work: [0x0, 0x9]”
  const upToMatch = message.match(/up to a\s+(\d+)\s+block range/i)
  if (upToMatch?.[1]) {
    const n = Number(upToMatch[1])
    if (Number.isFinite(n) && n > 0) return BigInt(n)
  }

  const bracketMatch = message.match(/\[(0x[0-9a-fA-F]+),\s*(0x[0-9a-fA-F]+)\]/)
  if (bracketMatch?.[1] && bracketMatch?.[2]) {
    try {
      const lo = BigInt(bracketMatch[1])
      const hi = BigInt(bracketMatch[2])
      if (hi >= lo) return hi - lo + BigInt(1)
    } catch {
      // ignore
    }
  }

  return null
}

function clampBlockFromLatest(latest: bigint, lookbackBlocks: bigint): bigint {
  if (lookbackBlocks <= ZERO) return ZERO
  if (latest <= lookbackBlocks) return ZERO
  return latest - lookbackBlocks
}

function formatPercentWad(wad: bigint | undefined): string {
  if (wad === undefined) return '?'
  // bonusPercentage is WAD, where 1e18 == 100%
  const scaled = Number(wad) / 1e16 // convert 1e18 -> percent with 2 decimals
  if (!Number.isFinite(scaled)) return wad.toString()
  return `${(scaled / 100).toFixed(4)}x`
}

function formatUnixSeconds(unlockTime: bigint | undefined): string {
  if (unlockTime === undefined) return ''
  const ms = Number(unlockTime) * 1000
  if (!Number.isFinite(ms)) return unlockTime.toString()
  return new Date(ms).toLocaleString()
}

function decodeDataUriBase64(dataUri: string): { mime?: string; data: string } | null {
  // e.g. data:application/json;base64,AAAA
  const prefix = 'data:'
  if (!dataUri.startsWith(prefix)) return null
  const commaIdx = dataUri.indexOf(',')
  if (commaIdx === -1) return null
  const meta = dataUri.slice(prefix.length, commaIdx)
  const data = dataUri.slice(commaIdx + 1)
  return { mime: meta, data }
}

function parseBondMetadataFromTokenUri(tokenUri: string): BondNftMetadata {
  const parsed = decodeDataUriBase64(tokenUri)
  if (!parsed) return { rawTokenUri: tokenUri }

  // The vault uses base64 JSON
  try {
    const jsonText = atob(parsed.data)
    const obj = JSON.parse(jsonText) as any
    return {
      name: typeof obj?.name === 'string' ? obj.name : undefined,
      description: typeof obj?.description === 'string' ? obj.description : undefined,
      image: typeof obj?.image === 'string' ? obj.image : undefined,
      rawTokenUri: tokenUri,
    }
  } catch {
    return { rawTokenUri: tokenUri }
  }
}

function encodeDataUriBase64(value: string, mime: string): string {
  return `data:${mime};base64,${btoa(unescape(encodeURIComponent(value)))}`
}

function formatProtocolUnlockLabel(unlockTime: bigint | undefined): string {
  if (unlockTime === undefined) return 'Unknown'
  const now = Math.floor(Date.now() / 1000)
  const unlock = Number(unlockTime)
  if (!Number.isFinite(unlock)) return unlockTime.toString()
  if (unlock <= now) return 'Unlocked'

  const secs = unlock - now
  const d = Math.floor(secs / 86400)
  const h = Math.floor((secs % 86400) / 3600)
  const m = Math.floor((secs % 3600) / 60)

  if (d > 0) return `${d}d ${h}h`
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

function buildProtocolBondMetadata(pos: BondPosition): BondNftMetadata {
  const unlockLabel =
    pos.protocolNftId !== undefined && pos.tokenId === pos.protocolNftId
      ? 'Protocol (No Lock)'
      : formatProtocolUnlockLabel(pos.lockInfo?.unlockTime)

  // Human decimals for certificate — never raw wei .toString()
  const shares = formatBondAmount(pos.lockInfo?.sharesAwarded, 18)
  const rewards = formatBondAmount(pos.pendingRewards, 18)
  const tokenId = pos.tokenId.toString()

  const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0f172a"/>
      <stop offset="100%" stop-color="#1d4ed8"/>
    </linearGradient>
  </defs>
  <rect width="800" height="800" fill="url(#bg)" rx="32"/>
  <rect x="32" y="32" width="736" height="736" rx="24" fill="rgba(15,23,42,0.58)" stroke="rgba(255,255,255,0.16)"/>
  <text x="72" y="118" fill="#93c5fd" font-size="26" font-family="Georgia, serif">Protocol Bond Certificate</text>
  <text x="72" y="180" fill="#ffffff" font-size="54" font-weight="700" font-family="Georgia, serif">${pos.detf.symbol} #${tokenId}</text>
  <text x="72" y="268" fill="#cbd5e1" font-size="28" font-family="ui-monospace, SFMono-Regular, monospace">Unlock: ${unlockLabel}</text>
  <text x="72" y="328" fill="#cbd5e1" font-size="28" font-family="ui-monospace, SFMono-Regular, monospace">Shares: ${shares}</text>
  <text x="72" y="388" fill="#cbd5e1" font-size="28" font-family="ui-monospace, SFMono-Regular, monospace">Pending rewards: ${rewards}</text>
  <text x="72" y="720" fill="#93c5fd" font-size="22" font-family="ui-monospace, SFMono-Regular, monospace">client-generated fallback metadata</text>
</svg>`.trim()

  const image = encodeDataUriBase64(svg, 'image/svg+xml')
  const json = JSON.stringify({
    name: `${pos.detf.symbol} #${tokenId}`,
    description: 'Protocol bond certificate rendered client-side because tokenURI() is not exposed by the deployed NFT vault proxy.',
    image,
  })

  return {
    name: `${pos.detf.symbol} #${tokenId}`,
    description: 'Protocol bond certificate rendered client-side because tokenURI() is not exposed by the deployed NFT vault proxy.',
    image,
    rawTokenUri: encodeDataUriBase64(json, 'application/json'),
  }
}

function messageIncludesNoTargetForTokenUri(error: unknown): boolean {
  const message = String((error as any)?.message ?? error ?? '')
  return message.includes('0x23dbef4b') || message.includes('NoTargetFor(bytes4)')
}

function isProtocolMetadataUnavailableError(error: unknown): boolean {
  const message = String((error as any)?.message ?? error ?? '')
  return message.includes('0x23dbef4b') || message.includes('NoTargetFor(bytes4)') || message.includes('PositionNotFound')
}

function PortfolioPage() {
  const searchParams = useSearchParams()
  const queryDetf = parseDetfQueryAddress(searchParams.get('detf'))
  const { address, chainId: accountChainId, isConnected } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const { selectedChainId } = useSelectedNetwork()
  const connection = useConnection()
  const connectedWalletChainId = useConnectedWalletChainId(isConnected, connection.connector)
  const browserChainId = useBrowserChainId(isConnected)
  const { data: connectorClient } = useConnectorClient()
  const { data: walletClient } = useWalletClient()
  const { writeContractAsync, isPending: isWritePending } = useWriteContract()
  const attachedWalletChainId = isConnected
    ? (accountChainId ?? connection.chainId ?? walletClient?.chain?.id ?? connectorClient?.chain?.id ?? connectedWalletChainId ?? browserChainId)
    : undefined
  const resolvedWalletChainId = attachedWalletChainId !== undefined
    ? resolveArtifactsChainId(attachedWalletChainId, environment, selectedChainId)
    : null
  const resolvedChainId = selectedChainId ?? CHAIN_ID_ROBINHOOD
  const isUnsupportedChain = isConnected && attachedWalletChainId !== undefined && !isSupportedChainId(attachedWalletChainId, environment)

  const targetChain = useMemo(() => resolveAppChain(resolvedChainId), [resolvedChainId])

  const [isLoading, setIsLoading] = useState(false)
  const [strategyVaultBalances, setStrategyVaultBalances] = useState<TokenBalance[]>([])
  const [detfBalances, setDetfBalances] = useState<TokenBalance[]>([])
  const [bondPositions, setBondPositions] = useState<BondPosition[]>([])
  const [errors, setErrors] = useState<string[]>([])
  const [actionKeyPending, setActionKeyPending] = useState<string | null>(null)
  /** Active share panel — sanitized fields only (PR8). */
  const [shareTarget, setShareTarget] = useState<(SharePositionInput & { id: string }) | null>(null)
  const { brand } = useBrand()

  const strategyVaultTokens = useMemo(
    () => getStrategyVaultTokensForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )
  const protocolDetfTokens = useMemo(
    () => getProtocolDetfTokensForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )
  const listedProtocolDetfs = useMemo(
    () => getProtocolDetfsForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )
  const createdProtocolDetfs = useMemo(
    () => loadCreatedDetfs(resolvedChainId),
    [resolvedChainId]
  )
  const queryProtocolDetfs = useMemo(
    () => (queryDetf ? [entryFromAddress(resolvedChainId, queryDetf)] : []),
    [queryDetf, resolvedChainId]
  )
  const protocolDetfs = useMemo(
    () => mergeDetfEntries(listedProtocolDetfs, createdProtocolDetfs, queryProtocolDetfs),
    [createdProtocolDetfs, listedProtocolDetfs, queryProtocolDetfs]
  )
  const feeDetfExploreHref = useMemo(() => {
    const fee = loadFeaturedFeeDetfs(resolvedChainId, environment, 1)[0]
    return fee ? feeDetfStakingHref(fee.address) : '/staking'
  }, [environment, resolvedChainId])

  const refresh = useCallback(async () => {
    if (!address) return

    setIsLoading(true)
    setErrors([])

    try {
      const appendError = (message: string) => {
        setErrors((prev) => (prev.includes(message) ? prev : [...prev, message]))
      }

      const readClient = createAppReadClient(resolvedChainId)
      const defaultLookback = Number(process.env.NEXT_PUBLIC_PORTFOLIO_LOG_SCAN_BLOCKS ?? '2048')
      const lookbackBlocks = BigInt(Number.isFinite(defaultLookback) && defaultLookback > 0 ? defaultLookback : 2048)
      const latestBlock = await readClient.getBlockNumber()
      const scanFromBlock = clampBlockFromLatest(latestBlock, lookbackBlocks)
      const bytecodeCache = new Map<string, Promise<boolean>>()

      const isContractDeployed = async (candidate: `0x${string}`): Promise<boolean> => {
        const key = candidate.toLowerCase()
        const cached = bytecodeCache.get(key)
        if (cached) return cached

        const pending = readClient
          .getBytecode({ address: candidate })
          .then((code) => Boolean(code && code !== '0x'))
          .catch(() => false)
        bytecodeCache.set(key, pending)
        return pending
      }

      let providerMaxGetLogsRange: bigint | null = null
      const getLogsAutoPaged = async (params: {
        address: `0x${string}`
        args: { to: `0x${string}` } | { from: `0x${string}` }
      }) => {
        const baseReq = {
          address: params.address,
          event: transferEvent,
          args: params.args as any,
        }

        const page = async (maxRange: bigint) => {
          const out: any[] = []
          if (maxRange <= ZERO) return out
          for (let start = scanFromBlock; start <= latestBlock; start += maxRange) {
            const end = start + maxRange - BigInt(1)
            const toBlock = end > latestBlock ? latestBlock : end
            const chunk = await readClient.getLogs({
              ...(baseReq as any),
              fromBlock: start,
              toBlock,
            })
            out.push(...chunk)
          }
          return out
        }

        // First try in a single request for performance.
        if (providerMaxGetLogsRange === null) {
          try {
            return await readClient.getLogs({
              ...(baseReq as any),
              fromBlock: scanFromBlock,
              toBlock: latestBlock,
            })
          } catch (e: any) {
            const msg = String(e?.message ?? e)
            const maxRange = parseRpcGetLogsMaxRange(msg)
            if (!maxRange) throw e
            providerMaxGetLogsRange = maxRange
            return await page(maxRange)
          }
        }

        // Already learned the provider’s range limitation.
        return await page(providerMaxGetLogsRange)
      }

      // -------------------------------------------------------------------
      // 1) ERC20 balances (vault share tokens + DETFs)
      // -------------------------------------------------------------------
      const fetchBalances = async (tokens: TokenListEntry[]): Promise<TokenBalance[]> => {
        const results = await Promise.all(
          tokens.map(async (token) => {
            const tokenAddress = token.address as `0x${string}`
            if (!(await isContractDeployed(tokenAddress))) {
              return { token, balance: ZERO }
            }

            try {
              const bal = await readClient.readContract({
                address: tokenAddress,
                abi: erc20Abi,
                functionName: 'balanceOf',
                args: [address as `0x${string}`],
              })
              return { token, balance: bal }
            } catch (e: any) {
              appendError(`Failed balanceOf(${token.symbol}) ${token.address}: ${String(e?.message ?? e)}`)
              return { token, balance: ZERO }
            }
          })
        )

        // Only show non-zero by default (keeps the page readable)
        return results.filter((r) => r.balance !== ZERO)
      }

      const platform = resolveSePlatform(resolvedChainId, environment)
      let registryDetfs: TokenListEntry[] = []
      if (platform.registry) {
        try {
          const vaults = await loadRegisteredVaults(readClient, platform.registry)
          const detfAddresses = await selectDetfsFromVaults(readClient, vaults)
          registryDetfs = await entriesFromAddresses(readClient, resolvedChainId, detfAddresses)
        } catch (e: any) {
          appendError(`Failed vault registry DETF scan: ${String(e?.message ?? e)}`)
        }
      }

      const scanDetfs = mergeDetfEntries(protocolDetfs, registryDetfs, loadCreatedDetfs(resolvedChainId), queryProtocolDetfs)

      const [vaultBals, detfBals] = await Promise.all([
        fetchBalances(strategyVaultTokens),
        fetchBalances(mergeDetfEntries([...protocolDetfTokens], scanDetfs)),
      ])

      setStrategyVaultBalances(vaultBals)
      setDetfBalances(detfBals)

      // -------------------------------------------------------------------
      // 2) Bond NFTs (log-discovered tokenIds per NFT vault)
      // -------------------------------------------------------------------
      const allBondPositions: BondPosition[] = []

      const discoverBondPositions = async ({
        detfs,
        kind,
      }: {
        detfs: TokenListEntry[]
        kind: 'protocol'
      }) => {
        for (const detf of detfs) {
          const detfAddress = detf.address as `0x${string}`
          if (!(await isContractDeployed(detfAddress))) continue

          let nftVault = zeroAddress as `0x${string}`
          try {
            const vault = await readBondNftVault(readClient, detfAddress)
            if (!vault) continue
            nftVault = vault
          } catch (e: any) {
            if (isFunctionNotFound(e)) continue
            appendError(`Failed to read bond NFT vault for ${detf.symbol}: ${String(e?.message ?? e)}`)
            continue
          }

          if (!nftVault || nftVault === zeroAddress) continue
          if (!(await isContractDeployed(nftVault))) continue

          let logsTo: any[] = []
          let logsFrom: any[] = []

          try {
            logsTo = await getLogsAutoPaged({ address: nftVault, args: { to: address as `0x${string}` } })
            logsFrom = await getLogsAutoPaged({ address: nftVault, args: { from: address as `0x${string}` } })
          } catch (e: any) {
            const msg = String(e?.message ?? e)
            appendError(
              `Failed getLogs(Transfer) for ${detf.symbol} (scanning last ${lookbackBlocks.toString()} blocks starting at ${scanFromBlock.toString()}): ${msg}`
            )
            continue
          }

          const candidateIdSeen: Record<string, true> = {}
          const candidateIdList: bigint[] = []
          for (const l of [...logsTo, ...logsFrom]) {
            const tokenId = l?.args?.tokenId
            if (typeof tokenId !== 'bigint') continue
            const key = tokenId.toString()
            if (candidateIdSeen[key]) continue
            candidateIdSeen[key] = true
            candidateIdList.push(tokenId)
          }

          for (const reservedId of [DETF_FEE_TO_BOND_NFT_ID, DETF_CREATOR_BOND_NFT_ID]) {
            const key = reservedId.toString()
            if (!candidateIdSeen[key]) {
              candidateIdSeen[key] = true
              candidateIdList.push(reservedId)
            }
          }

          if (candidateIdList.length === 0) continue

          let protocolNftId: bigint | null = null
          if (kind === 'protocol') {
            protocolNftId = await readDetfNftId(readClient, nftVault)
          }

          const ownedIds: bigint[] = []
          await Promise.all(
            candidateIdList.map(async (tokenId) => {
              if (protocolNftId !== null && tokenId === protocolNftId) return

              try {
                const owner = (await readClient.readContract({
                  address: nftVault,
                  abi: protocolNftVaultAbi,
                  functionName: 'ownerOf',
                  args: [tokenId],
                })) as `0x${string}`

                if (owner?.toLowerCase() === address.toLowerCase()) ownedIds.push(tokenId)
              } catch {
                // burned or invalid => ignore
              }
            })
          )

          if (ownedIds.length === 0) continue

          let claimToken: `0x${string}` | undefined
          let rewardToken: `0x${string}` | undefined
          try {
            rewardToken = (await readClient.readContract({
              address: nftVault,
              abi: protocolNftVaultAbi,
              functionName: 'rewardToken',
            })) as `0x${string}`
          } catch {
            // non-fatal
          }

          const perId = await Promise.all(
            ownedIds.map(async (tokenId) => {
              const out: BondPosition = {
                kind,
                detf,
                nftVault,
                protocolNftId: protocolNftId ?? undefined,
                claimToken,
                rewardToken,
                tokenId,
              }
              try {
                const [position, pending] = await Promise.all([
                  readBondPosition(readClient, nftVault, tokenId),
                  readClient.readContract({
                    address: nftVault,
                    abi: protocolNftVaultAbi,
                    functionName: 'pendingRewards',
                    args: [tokenId],
                  }),
                ])

                if (!position || (position.originalShares === ZERO && position.effectiveShares === ZERO)) {
                  return null
                }

                out.lockInfo = {
                  sharesAwarded: position.effectiveShares,
                  rewardPerShare: position.rewardDebt,
                  bonusPercentage: position.bonusMultiplier,
                  unlockTime: position.unlockTime,
                }
                out.pendingRewards = pending as bigint
              } catch (e: any) {
                if (!isFunctionNotFound(e)) {
                  appendError(`Failed position details for ${detf.symbol} #${tokenId}: ${String(e?.message ?? e)}`)
                }
              }
              return out
            })
          )

          allBondPositions.push(...perId.filter((position): position is BondPosition => position !== null))
        }
      }

      await discoverBondPositions({
        detfs: scanDetfs,
        kind: 'protocol',
      })

      setBondPositions(allBondPositions)
    } finally {
      setIsLoading(false)
    }
  }, [address, environment, protocolDetfTokens, protocolDetfs, queryProtocolDetfs, resolvedChainId, strategyVaultTokens])

  const loadMetadata = useCallback(
    async (pos: BondPosition) => {
      try {
        const tokenUri = await createAppReadClient(resolvedChainId).readContract({
          address: pos.nftVault,
          abi: protocolNftVaultAbi,
          functionName: 'tokenURI',
          args: [pos.tokenId],
        })

        const parsed = parseBondMetadataFromTokenUri(tokenUri as string)

        setBondPositions((prev) =>
          prev.map((p) =>
            p.nftVault === pos.nftVault && p.tokenId === pos.tokenId
              ? {
                  ...p,
                  metadata: parsed,
                }
              : p
          )
        )
      } catch (e: any) {
        if (pos.kind === 'protocol' && isProtocolMetadataUnavailableError(e)) {
          const fallback = buildProtocolBondMetadata(pos)
          setBondPositions((prev) =>
            prev.map((p) =>
              p.nftVault === pos.nftVault && p.tokenId === pos.tokenId
                ? {
                    ...p,
                    metadata: fallback,
                  }
                : p
            )
          )

          const detail = messageIncludesNoTargetForTokenUri(e)
            ? 'tokenURI() is not exposed by the deployed protocol NFT vault proxy, so the certificate was generated client-side.'
            : 'tokenURI() metadata was unavailable from the vault, so the certificate was generated client-side.'
          setErrors((prev) => [
            ...prev,
            `Protocol bond metadata fallback for ${pos.detf.symbol} #${pos.tokenId}: ${detail}`,
          ])
          return
        }

        setErrors((prev) => [...prev, `Failed tokenURI for ${pos.detf.symbol} #${pos.tokenId}: ${String(e?.message ?? e)}`])
      }
    },
    [resolvedChainId]
  )

  const claimProtocolRewards = useCallback(
    async (pos: BondPosition) => {
      if (!address) return
      if (pos.kind !== 'protocol') return
      const key = `${pos.nftVault}:${pos.tokenId.toString()}:claim`
      setActionKeyPending(key)
      try {
        await writeContractAsync({
          chain: targetChain,
          account: address,
          address: pos.nftVault,
          abi: protocolNftVaultAbi,
          functionName: 'claimRewards',
          args: [pos.tokenId, address as `0x${string}`],
        })
        await refresh()
      } catch (e: any) {
        setErrors((prev) => [...prev, `Claim rewards failed for ${pos.detf.symbol} #${pos.tokenId}: ${String(e?.message ?? e)}`])
      } finally {
        setActionKeyPending(null)
      }
    },
    [address, targetChain, writeContractAsync, refresh]
  )

  const redeemProtocolBond = useCallback(
    async (pos: BondPosition) => {
      if (!address) return
      if (pos.kind !== 'protocol') return
      const key = `${pos.nftVault}:${pos.tokenId.toString()}:redeem`
      setActionKeyPending(key)
      try {
        await writeContractAsync({
          chain: targetChain,
          account: address,
          address: pos.nftVault,
          abi: protocolNftVaultAbi,
          functionName: 'redeemPosition',
          args: [pos.tokenId, address as `0x${string}`, BigInt(Math.floor(Date.now() / 1000) + 1800)],
        })
        await refresh()
      } catch (e: any) {
        setErrors((prev) => [...prev, `Redeem failed for ${pos.detf.symbol} #${pos.tokenId}: ${String(e?.message ?? e)}`])
      } finally {
        setActionKeyPending(null)
      }
    },
    [address, targetChain, writeContractAsync, refresh]
  )

  useEffect(() => {
    if (isConnected) refresh()
  }, [isConnected, refresh])

  if (!isConnected) {
    return (
      <div className="max-w-3xl mx-auto pt-6">
        <EmptyState
          title="Connect to see positions"
          body="Connect your wallet to view vault shares and DETF bond NFTs."
          action={
            <Link href="/earn">
              <Button variant="secondary" size="sm">
                Browse Earn
              </Button>
            </Link>
          }
        />
      </div>
    )
  }

  if (isUnsupportedChain) {
    return (
      <div className="max-w-3xl mx-auto pt-6">
        <EmptyState
          title="Unsupported network"
          body="This wallet is connected to an unsupported chain for the selected deployment environment."
        />
      </div>
    )
  }

  const tableHeadClass =
    'text-left text-[var(--text-muted,#9aa3b2)] border-b border-[var(--border-subtle,rgba(255,255,255,0.08))]'
  const tableRowClass = 'border-b border-[var(--border-subtle,rgba(255,255,255,0.08))]'

  return (
    <div className="max-w-6xl">
      <PageHeader
        title="You"
        subtitle="Your vault receipts, DETF tokens, and bond NFTs."
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href="/earn"
              className="text-sm text-[var(--accent,#4FD44B)] hover:underline"
            >
              Browse Earn
            </Link>
            <Button
              type="button"
              variant="primary"
              size="sm"
              onClick={refresh}
              disabled={!address}
              loading={isLoading}
            >
              {isLoading ? 'Refreshing…' : 'Refresh'}
            </Button>
          </div>
        }
      />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card padding="sm">
          <Stat label="Vault positions" value={String(strategyVaultBalances.length)} />
        </Card>
        <Card padding="sm">
          <Stat label="DETF balances" value={String(detfBalances.length)} />
        </Card>
        <Card padding="sm">
          <Stat label="Bond NFTs" value={String(bondPositions.length)} />
        </Card>
      </div>

      {strategyVaultBalances.length === 0 &&
      detfBalances.length === 0 &&
      bondPositions.length === 0 &&
      !isLoading ? (
        <div className="mb-8">
          <EmptyState
            title="No positions yet"
            body="Nothing here yet. Open Protocol DETF to mint, bond, and sell. Or browse Earn vaults."
            action={
              <div className="flex flex-wrap gap-2">
                <Link href={feeDetfExploreHref}>
                  <Button variant="primary" size="sm">
                    Explore Protocol DETF
                  </Button>
                </Link>
                <Link href="/earn">
                  <Button variant="secondary" size="sm">
                    Browse Earn
                  </Button>
                </Link>
              </div>
            }
          />
        </div>
      ) : null}

      {shareTarget ? (
        <Card className="mb-6" accent>
          <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
            <div>
              <p className="text-xs uppercase tracking-wide text-[var(--accent,#4FD44B)]">Share position</p>
              <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
                Symbol, amount, and address only. No extra markup.
              </p>
            </div>
            <Button type="button" variant="ghost" size="sm" onClick={() => setShareTarget(null)}>
              Close
            </Button>
          </div>
          <SharePositionCard
            kind={shareTarget.kind}
            symbol={shareTarget.symbol}
            amountLabel={shareTarget.amountLabel}
            address={shareTarget.address}
            detailLabel={shareTarget.detailLabel}
            brandName={shareTarget.brandName}
            showCulture={false}
          />
        </Card>
      ) : null}

      {/* Strategy vault shares */}
      <Card className="mb-6">
        <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Vault shares</h2>
        <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
          Non-zero balances from the chain tokenlist. Manage via Earn detail.
        </p>

        {strategyVaultBalances.length === 0 ? (
          <div className="mt-4 text-sm text-[var(--text-muted,#9aa3b2)]">
            No strategy vault share balances found.{' '}
            <Link href="/earn" className="text-[var(--accent,#4FD44B)] hover:underline">
              Browse Earn
            </Link>{' '}
            to deposit.
          </div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className={tableHeadClass}>
                  <th className="py-2">Token</th>
                  <th className="py-2">Address</th>
                  <th className="py-2">Balance</th>
                  <th className="py-2">Action</th>
                </tr>
              </thead>
              <tbody>
                {strategyVaultBalances.map((row) => {
                  const amountLabel = formatUnits(row.balance, row.token.decimals)
                  const shareId = `vault:${row.token.address.toLowerCase()}`
                  return (
                    <tr key={row.token.address} className={tableRowClass}>
                      <td className="py-2 text-[var(--text-primary,#EDEDED)]">
                        {row.token.name || row.token.symbol}
                      </td>
                      <td className="py-2">
                        <AddressLink chainId={resolvedChainId} address={row.token.address} />
                      </td>
                      <td className="py-2 font-mono tabular-nums text-[var(--text-primary,#EDEDED)]">
                        {amountLabel} {row.token.symbol}
                      </td>
                      <td className="py-2">
                        <div className="flex flex-wrap items-center gap-3">
                          <Link
                            href={`/earn/${row.token.address}`}
                            className="text-sm text-[var(--accent,#4FD44B)] hover:underline"
                          >
                            Manage
                          </Link>
                          <button
                            type="button"
                            className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
                            onClick={() =>
                              setShareTarget({
                                id: shareId,
                                kind: 'vault-share',
                                symbol: row.token.symbol,
                                amountLabel,
                                address: row.token.address,
                                detailLabel: row.token.name || undefined,
                                brandName: brand.name,
                                showCulture: false,
                              })
                            }
                          >
                            Share
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {/* DETFs */}
      <Card className="mb-6">
        <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">DETF Tokens</h2>
        <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
          Non-zero balances of protocol DETFs.
        </p>

        {detfBalances.length === 0 ? (
          <div className="mt-4 text-sm text-[var(--text-muted,#9aa3b2)]">No DETF token balances found.</div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className={tableHeadClass}>
                  <th className="py-2">Token</th>
                  <th className="py-2">Address</th>
                  <th className="py-2">Balance</th>
                  <th className="py-2">Action</th>
                </tr>
              </thead>
              <tbody>
                {detfBalances.map((row) => {
                  const amountLabel = formatUnits(row.balance, row.token.decimals)
                  const shareId = `detf:${row.token.address.toLowerCase()}`
                  const isFee = isFeaturedFeeDetfAddress(
                    resolvedChainId,
                    environment,
                    row.token.address,
                  )
                  const manageHref = isFee
                    ? feeDetfStakingHref(row.token.address)
                    : `/earn/${row.token.address}`
                  return (
                    <tr key={row.token.address} className={tableRowClass}>
                      <td className="py-2 text-[var(--text-primary,#EDEDED)]">
                        {row.token.name || row.token.symbol}
                      </td>
                      <td className="py-2">
                        <AddressLink chainId={resolvedChainId} address={row.token.address} />
                      </td>
                      <td className="py-2 font-mono tabular-nums text-[var(--text-primary,#EDEDED)]">
                        {amountLabel} {row.token.symbol}
                      </td>
                      <td className="py-2">
                        <div className="flex flex-wrap items-center gap-3">
                          <Link
                            href={manageHref}
                            className="text-sm text-[var(--accent,#4FD44B)] hover:underline"
                          >
                            Manage
                          </Link>
                          <button
                            type="button"
                            className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
                            onClick={() =>
                              setShareTarget({
                                id: shareId,
                                kind: 'detf-share',
                                symbol: row.token.symbol,
                                amountLabel,
                                address: row.token.address,
                                detailLabel: row.token.name || undefined,
                                brandName: brand.name,
                                showCulture: false,
                              })
                            }
                          >
                            Share
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {/* Bond NFTs */}
      <Card className="mb-6">
        <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Bond NFTs</h2>
        <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
          Owned bond positions discovered from NFT vault transfer logs.
        </p>

        {bondPositions.length === 0 ? (
          <div className="mt-4 text-sm text-[var(--text-muted,#9aa3b2)]">
            No bond NFTs found for this wallet.{' '}
            <Link
              href="/earn?type=protocol-detf"
              className="text-[var(--accent,#4FD44B)] hover:underline"
            >
              Browse DETFs on Earn
            </Link>
          </div>
        ) : (
          <div className="mt-4 space-y-4">
            {bondPositions.map((pos) => {
              const nowSec = BigInt(Math.floor(Date.now() / 1000))
              const unlockTime = pos.lockInfo?.unlockTime
              const matured = unlockTime !== undefined ? nowSec >= unlockTime : false
              const claimKey = `${pos.nftVault}:${pos.tokenId.toString()}:claim`
              const redeemKey = `${pos.nftVault}:${pos.tokenId.toString()}:redeem`
              const bondKey = `${pos.nftVault}:${pos.tokenId.toString()}`
              const sharesLabel = formatBondAmount(pos.lockInfo?.sharesAwarded, 18)

              return (
                <div key={bondKey} className="space-y-2">
                  <BondNftCard
                    kind={pos.kind}
                    symbol={pos.detf.symbol}
                    tokenId={pos.tokenId}
                    chainId={resolvedChainId}
                    nftVault={pos.nftVault}
                    claimToken={pos.claimToken}
                    rewardToken={pos.rewardToken}
                    unlockTimeLabel={formatUnixSeconds(pos.lockInfo?.unlockTime) || '—'}
                    bonusLabel={formatPercentWad(pos.lockInfo?.bonusPercentage)}
                    sharesAwarded={pos.lockInfo?.sharesAwarded}
                    pendingRewards={pos.pendingRewards}
                    matured={matured}
                    actionKeyPending={actionKeyPending}
                    claimKey={claimKey}
                    redeemKey={redeemKey}
                    isWritePending={isWritePending}
                    metadata={pos.metadata}
                    onLoadCertificate={() => loadMetadata(pos)}
                    onClaim={() => claimProtocolRewards(pos)}
                    onRedeem={() => redeemProtocolBond(pos)}
                  />
                  <div className="flex justify-end px-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        setShareTarget({
                          id: `bond:${bondKey}`,
                          kind: 'bond-nft',
                          symbol: pos.detf.symbol,
                          amountLabel: sharesLabel === '—' ? '0' : sharesLabel,
                          address: pos.nftVault,
                          detailLabel: `Bond #${pos.tokenId.toString()}`,
                          brandName: brand.name,
                          showCulture: false,
                        })
                      }
                    >
                      Share position
                    </Button>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </Card>

      {errors.length > 0 && (
        <Card className="mb-6 border-[var(--danger,#E6386A)]/40">
          <div className="font-semibold text-[var(--danger,#E6386A)]">Errors</div>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-[var(--text-primary,#EDEDED)]">
            {errors.slice(0, 10).map((e, idx) => (
              <li key={idx}>{e}</li>
            ))}
          </ul>
          {errors.length > 10 && (
            <div className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">(showing first 10)</div>
          )}
        </Card>
      )}

      <DebugPanel title="Portfolio Debug">
        <div className="text-xs text-[var(--text-muted,#9aa3b2)]">
          <div>Environment: {environment}</div>
          <div>ChainId: {resolvedChainId}</div>
          <div>Wallet: {address}</div>
          <div>Strategy vault tokens in list: {strategyVaultTokens.length}</div>
          <div>Protocol DETFs in list: {protocolDetfs.length}</div>
          <div>Bond positions: {bondPositions.length}</div>
        </div>
      </DebugPanel>
    </div>
  )
}

export default function PortfolioPageWithSearch() {
  return (
    <Suspense fallback={<p className="text-sm text-[var(--text-muted,#9aa3b2)]">Loading positions…</p>}>
      <PortfolioPage />
    </Suspense>
  )
}
