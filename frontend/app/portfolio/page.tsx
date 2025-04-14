 'use client'

import Image from 'next/image'

import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  useAccount,
  useChainId,
  useConnection,
  useConnectorClient,
  usePublicClient,
  useWalletClient,
  useWriteContract,
} from 'wagmi'
import { erc20Abi, formatUnits, zeroAddress, parseAbiItem } from 'viem'

import DebugPanel from '../components/DebugPanel'
import { useBrowserChainId, useConnectedWalletChainId } from '../lib/browserChain'
import { useDeploymentEnvironment } from '../lib/deploymentEnvironment'

import {
  CHAIN_ID_SEPOLIA,
  isSupportedChainId,
  resolveArtifactsChainId,
} from '../lib/addressArtifacts'
import {
  getProtocolDetfsForChain,
  getProtocolDetfTokensForChain,
  getSeigniorageDetfsForChain,
  getStrategyVaultTokensForChain,
  type TokenListEntry,
} from '../lib/tokenlists'
import { resolveAppChain } from '../lib/runtimeChains'

type TokenBalance = {
  token: TokenListEntry
  balance: bigint
}

const ZERO = BigInt(0)

type BondNftMetadata = {
  name?: string
  description?: string
  image?: string
  rawTokenUri?: string
}

type BondPosition = {
  kind: 'seigniorage' | 'protocol'
  detf: TokenListEntry
  nftVault: `0x${string}`
  protocolNftId?: bigint
  claimToken?: `0x${string}`
  rewardToken?: `0x${string}`
  tokenId: bigint
  lockInfo?: {
    sharesAwarded: bigint
    rewardPerShare: bigint
    bonusPercentage: bigint
    unlockTime: bigint
  }
  pendingRewards?: bigint
  metadata?: BondNftMetadata
}

const seigniorageDetfAbi = [
  {
    type: 'function',
    name: 'seigniorageNFTVault',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

const protocolDetfAbi = [
  {
    type: 'function',
    name: 'protocolNFTVault',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

const seigniorageNftVaultAbi = [
  {
    type: 'function',
    name: 'withdrawRewards',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'rewards', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'unlock',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'lpAmount', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'claimToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
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
    name: 'lockInfoOf',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      {
        name: 'info',
        type: 'tuple',
        components: [
          { name: 'sharesAwarded', type: 'uint256' },
          { name: 'rewardPerShare', type: 'uint256' },
          { name: 'bonusPercentage', type: 'uint256' },
          { name: 'unlockTime', type: 'uint256' },
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

const protocolNftVaultAbi = [
  {
    type: 'function',
    name: 'protocolNFTId',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
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

  const shares = pos.lockInfo?.sharesAwarded?.toString() ?? '0'
  const rewards = pos.pendingRewards?.toString() ?? '0'
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

export default function PortfolioPage() {
  const { address, chainId: accountChainId, isConnected } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const configChainId = useChainId()
  const connection = useConnection()
  const connectedWalletChainId = useConnectedWalletChainId(isConnected, connection.connector)
  const browserChainId = useBrowserChainId(isConnected)
  const { data: connectorClient } = useConnectorClient()
  const { data: walletClient } = useWalletClient()
  const { writeContractAsync, isPending: isWritePending } = useWriteContract()
  const attachedWalletChainId = isConnected
    ? (accountChainId ?? connection.chainId ?? walletClient?.chain?.id ?? connectorClient?.chain?.id ?? connectedWalletChainId ?? browserChainId)
    : undefined
  const resolvedConfigChainId = configChainId !== undefined ? resolveArtifactsChainId(configChainId, environment) : null
  const resolvedWalletChainId = attachedWalletChainId !== undefined
    ? resolveArtifactsChainId(attachedWalletChainId, environment)
    : null
  const resolvedChainId = resolvedWalletChainId ?? resolvedConfigChainId ?? CHAIN_ID_SEPOLIA
  const wagmiPublicClient = usePublicClient({ chainId: resolvedChainId })
  const publicClient = useMemo(() => wagmiPublicClient ?? null, [wagmiPublicClient])
  const isUnsupportedChain = isConnected && attachedWalletChainId !== undefined && !isSupportedChainId(attachedWalletChainId, environment)

  const targetChain = useMemo(() => resolveAppChain(resolvedChainId), [resolvedChainId])

  const [isLoading, setIsLoading] = useState(false)
  const [strategyVaultBalances, setStrategyVaultBalances] = useState<TokenBalance[]>([])
  const [detfBalances, setDetfBalances] = useState<TokenBalance[]>([])
  const [bondPositions, setBondPositions] = useState<BondPosition[]>([])
  const [errors, setErrors] = useState<string[]>([])
  const [actionKeyPending, setActionKeyPending] = useState<string | null>(null)

  const strategyVaultTokens = useMemo(
    () => getStrategyVaultTokensForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )
  const seigniorageDetfs = useMemo(
    () => getSeigniorageDetfsForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )
  const protocolDetfTokens = useMemo(
    () => getProtocolDetfTokensForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )
  const protocolDetfs = useMemo(
    () => getProtocolDetfsForChain(resolvedChainId, environment),
    [environment, resolvedChainId]
  )

  const refresh = useCallback(async () => {
    if (!address || !publicClient) return

    setIsLoading(true)
    setErrors([])

    try {
      const appendError = (message: string) => {
        setErrors((prev) => (prev.includes(message) ? prev : [...prev, message]))
      }

      const defaultLookback = Number(process.env.NEXT_PUBLIC_PORTFOLIO_LOG_SCAN_BLOCKS ?? '2048')
      const lookbackBlocks = BigInt(Number.isFinite(defaultLookback) && defaultLookback > 0 ? defaultLookback : 2048)
      const latestBlock = await publicClient.getBlockNumber()
      const scanFromBlock = clampBlockFromLatest(latestBlock, lookbackBlocks)
      const bytecodeCache = new Map<string, Promise<boolean>>()

      const isContractDeployed = async (candidate: `0x${string}`): Promise<boolean> => {
        const key = candidate.toLowerCase()
        const cached = bytecodeCache.get(key)
        if (cached) return cached

        const pending = publicClient
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
            const chunk = await publicClient.getLogs({
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
            return await publicClient.getLogs({
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
              const bal = await publicClient.readContract({
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

      const [vaultBals, detfBals] = await Promise.all([
        fetchBalances(strategyVaultTokens),
        fetchBalances([...seigniorageDetfs, ...protocolDetfTokens]),
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
        getVaultAddress,
      }: {
        detfs: TokenListEntry[]
        kind: 'seigniorage' | 'protocol'
        getVaultAddress: (detfAddress: `0x${string}`) => Promise<`0x${string}`>
      }) => {
        for (const detf of detfs) {
          const detfAddress = detf.address as `0x${string}`
          if (!(await isContractDeployed(detfAddress))) continue

          let nftVault = zeroAddress as `0x${string}`
          try {
            nftVault = await getVaultAddress(detfAddress)
          } catch (e: any) {
            appendError(`Failed ${kind === 'protocol' ? 'protocolNFTVault' : 'seigniorageNFTVault'}() for ${detf.symbol}: ${String(e?.message ?? e)}`)
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

          if (candidateIdList.length === 0) continue

          let protocolNftId: bigint | null = null
          if (kind === 'protocol') {
            try {
              protocolNftId = (await publicClient.readContract({
                address: nftVault,
                abi: protocolNftVaultAbi,
                functionName: 'protocolNFTId',
              })) as bigint
            } catch {
              protocolNftId = null
            }
          }

          const ownedIds: bigint[] = []
          await Promise.all(
            candidateIdList.map(async (tokenId) => {
              if (protocolNftId !== null && tokenId === protocolNftId) return

              try {
                const owner = (await publicClient.readContract({
                  address: nftVault,
                  abi: kind === 'protocol' ? protocolNftVaultAbi : seigniorageNftVaultAbi,
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
            if (kind === 'seigniorage') {
              const [c, r] = await Promise.all([
                publicClient.readContract({ address: nftVault, abi: seigniorageNftVaultAbi, functionName: 'claimToken' }),
                publicClient.readContract({ address: nftVault, abi: seigniorageNftVaultAbi, functionName: 'rewardToken' }),
              ])
              claimToken = c as `0x${string}`
              rewardToken = r as `0x${string}`
            } else {
              rewardToken = (await publicClient.readContract({
                address: nftVault,
                abi: protocolNftVaultAbi,
                functionName: 'rewardToken',
              })) as `0x${string}`
            }
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
                if (kind === 'seigniorage') {
                  const [lockInfo, pending] = await Promise.all([
                    publicClient.readContract({
                      address: nftVault,
                      abi: seigniorageNftVaultAbi,
                      functionName: 'lockInfoOf',
                      args: [tokenId],
                    }),
                    publicClient.readContract({
                      address: nftVault,
                      abi: seigniorageNftVaultAbi,
                      functionName: 'pendingRewards',
                      args: [tokenId],
                    }),
                  ])

                  out.lockInfo = {
                    sharesAwarded: (lockInfo as any).sharesAwarded,
                    rewardPerShare: (lockInfo as any).rewardPerShare,
                    bonusPercentage: (lockInfo as any).bonusPercentage,
                    unlockTime: (lockInfo as any).unlockTime,
                  }
                  out.pendingRewards = pending as bigint
                } else {
                  const [position, pending] = await Promise.all([
                    publicClient.readContract({
                      address: nftVault,
                      abi: protocolNftVaultAbi,
                      functionName: 'getPosition',
                      args: [tokenId],
                    }),
                    publicClient.readContract({
                      address: nftVault,
                      abi: protocolNftVaultAbi,
                      functionName: 'pendingRewards',
                      args: [tokenId],
                    }),
                  ])

                  const originalShares = (position as any).originalShares as bigint
                  if (originalShares === ZERO) {
                    return null
                  }

                  out.lockInfo = {
                    sharesAwarded: (position as any).effectiveShares,
                    rewardPerShare: (position as any).rewardDebt,
                    bonusPercentage: (position as any).bonusMultiplier,
                    unlockTime: (position as any).unlockTime,
                  }
                  out.pendingRewards = pending as bigint
                }
              } catch (e: any) {
                appendError(`Failed position details for ${detf.symbol} #${tokenId}: ${String(e?.message ?? e)}`)
              }
              return out
            })
          )

          allBondPositions.push(...perId.filter((position): position is BondPosition => position !== null))
        }
      }

      await discoverBondPositions({
        detfs: seigniorageDetfs,
        kind: 'seigniorage',
        getVaultAddress: async (detfAddress) =>
          (await publicClient.readContract({
            address: detfAddress,
            abi: seigniorageDetfAbi,
            functionName: 'seigniorageNFTVault',
            args: [],
          })) as `0x${string}`,
      })

      await discoverBondPositions({
        detfs: protocolDetfs,
        kind: 'protocol',
        getVaultAddress: async (detfAddress) =>
          (await publicClient.readContract({
            address: detfAddress,
            abi: protocolDetfAbi,
            functionName: 'protocolNFTVault',
            args: [],
          })) as `0x${string}`,
      })

      setBondPositions(allBondPositions)
    } finally {
      setIsLoading(false)
    }
  }, [address, publicClient, strategyVaultTokens, seigniorageDetfs, protocolDetfTokens, protocolDetfs])

  const loadMetadata = useCallback(
    async (pos: BondPosition) => {
      if (!publicClient) return
      try {
        const tokenUri = await publicClient.readContract({
          address: pos.nftVault,
          abi: pos.kind === 'protocol' ? protocolNftVaultAbi : seigniorageNftVaultAbi,
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
    [publicClient]
  )

  const withdrawRewards = useCallback(
    async (pos: BondPosition) => {
      if (!address) return
      if (pos.kind !== 'seigniorage') return
      const key = `${pos.nftVault}:${pos.tokenId.toString()}:withdraw`
      setActionKeyPending(key)
      try {
        await writeContractAsync({
          chain: targetChain,
          account: address,
          address: pos.nftVault,
          abi: seigniorageNftVaultAbi,
          functionName: 'withdrawRewards',
          args: [pos.tokenId, address as `0x${string}`],
        })
        await refresh()
      } catch (e: any) {
        setErrors((prev) => [...prev, `Withdraw rewards failed for ${pos.detf.symbol} #${pos.tokenId}: ${String(e?.message ?? e)}`])
      } finally {
        setActionKeyPending(null)
      }
    },
    [address, targetChain, writeContractAsync, refresh]
  )

  const unlockBond = useCallback(
    async (pos: BondPosition) => {
      if (!address) return
      if (pos.kind !== 'seigniorage') return
      const key = `${pos.nftVault}:${pos.tokenId.toString()}:unlock`
      setActionKeyPending(key)
      try {
        await writeContractAsync({
          chain: targetChain,
          account: address,
          address: pos.nftVault,
          abi: seigniorageNftVaultAbi,
          functionName: 'unlock',
          args: [pos.tokenId, address as `0x${string}`],
        })
        await refresh()
      } catch (e: any) {
        setErrors((prev) => [...prev, `Unlock failed for ${pos.detf.symbol} #${pos.tokenId}: ${String(e?.message ?? e)}`])
      } finally {
        setActionKeyPending(null)
      }
    },
    [address, targetChain, writeContractAsync, refresh]
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
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Portfolio</h1>
          <p className="text-gray-300 mt-2">Connect your wallet to view your vault tokens and bond NFTs.</p>
        </div>
      </div>
    )
  }

  if (isUnsupportedChain) {
    return (
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Portfolio</h1>
          <p className="text-red-300 mt-2">This wallet is connected to an unsupported chain for the selected deployment environment.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 max-w-6xl">
      <div className="flex items-center justify-between py-8">
        <div>
          <h1 className="text-3xl font-bold text-white">Portfolio</h1>
          <p className="text-gray-300 mt-2">Vault share tokens + Seigniorage and Protocol DETF bond NFTs.</p>
        </div>
        <button
          onClick={refresh}
          disabled={!address || !publicClient || isLoading}
          className="px-4 py-2 rounded-md bg-green-600 hover:bg-green-700 text-white disabled:opacity-50"
        >
          {isLoading ? 'Refreshing…' : 'Refresh'}
        </button>
      </div>

      {/* Vault share tokens */}
      <div className="mb-8 p-4 bg-slate-800/50 rounded-lg border border-slate-700">
        <h2 className="text-xl font-semibold text-white">Strategy Vault Shares</h2>
        <p className="text-sm text-gray-300 mt-1">Non-zero balances from the chain tokenlist.</p>

        {strategyVaultBalances.length === 0 ? (
          <div className="text-gray-400 mt-4 text-sm">No strategy vault share balances found.</div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-gray-300 border-b border-slate-700">
                  <th className="py-2">Token</th>
                  <th className="py-2">Address</th>
                  <th className="py-2">Balance</th>
                </tr>
              </thead>
              <tbody>
                {strategyVaultBalances.map((row) => (
                  <tr key={row.token.address} className="border-b border-slate-800">
                    <td className="py-2 text-white">{row.token.name || row.token.symbol}</td>
                    <td className="py-2 text-gray-400 font-mono">
                      {row.token.address.slice(0, 6)}…{row.token.address.slice(-4)}
                    </td>
                    <td className="py-2 text-green-300">
                      {formatUnits(row.balance, row.token.decimals)} {row.token.symbol}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* DETFs */}
      <div className="mb-8 p-4 bg-slate-800/50 rounded-lg border border-slate-700">
        <h2 className="text-xl font-semibold text-white">DETF Tokens</h2>
        <p className="text-sm text-gray-300 mt-1">Non-zero balances of seigniorage + protocol DETFs.</p>

        {detfBalances.length === 0 ? (
          <div className="text-gray-400 mt-4 text-sm">No DETF token balances found.</div>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-gray-300 border-b border-slate-700">
                  <th className="py-2">Token</th>
                  <th className="py-2">Address</th>
                  <th className="py-2">Balance</th>
                </tr>
              </thead>
              <tbody>
                {detfBalances.map((row) => (
                  <tr key={row.token.address} className="border-b border-slate-800">
                    <td className="py-2 text-white">{row.token.name || row.token.symbol}</td>
                    <td className="py-2 text-gray-400 font-mono">
                      {row.token.address.slice(0, 6)}…{row.token.address.slice(-4)}
                    </td>
                    <td className="py-2 text-green-300">
                      {formatUnits(row.balance, row.token.decimals)} {row.token.symbol}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Bond NFTs */}
      <div className="mb-8 p-4 bg-slate-800/50 rounded-lg border border-slate-700">
        <h2 className="text-xl font-semibold text-white">Bond NFTs</h2>
        <p className="text-sm text-gray-300 mt-1">
          For each bond vault, discover owned tokenIds via ERC721 <span className="font-mono">Transfer</span> logs and
          confirm ownership with <span className="font-mono">ownerOf</span>.
        </p>

        {bondPositions.length === 0 ? (
          <div className="text-gray-400 mt-4 text-sm">No bond NFTs found for this wallet.</div>
        ) : (
          <div className="mt-4 space-y-4">
            {bondPositions.map((pos) => (
              <div key={`${pos.nftVault}:${pos.tokenId.toString()}`} className="rounded border border-slate-700 bg-slate-900 p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-white font-semibold">
                      {pos.detf.symbol} {pos.kind === 'protocol' ? 'Protocol Bond' : 'Bond'} #{pos.tokenId.toString()}
                    </div>
                    <div className="text-xs text-gray-400 mt-1 font-mono">
                      NFT Vault: {pos.nftVault.slice(0, 6)}…{pos.nftVault.slice(-4)}
                    </div>
                    {pos.claimToken && (
                      <div className="text-xs text-gray-400 mt-1 font-mono">
                        Claim token: {pos.claimToken.slice(0, 6)}…{pos.claimToken.slice(-4)}
                      </div>
                    )}
                    {pos.rewardToken && (
                      <div className="text-xs text-gray-400 mt-1 font-mono">
                        Reward token: {pos.rewardToken.slice(0, 6)}…{pos.rewardToken.slice(-4)}
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => loadMetadata(pos)}
                      className="px-3 py-1 rounded bg-gray-700 text-gray-100 hover:bg-gray-600 text-xs"
                    >
                      Load certificate
                    </button>
                  </div>
                </div>

                <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
                  <div className="text-gray-300">
                    <span className="text-gray-500">Unlock time:</span> {formatUnixSeconds(pos.lockInfo?.unlockTime)}
                  </div>
                  <div className="text-gray-300">
                    <span className="text-gray-500">Bonus:</span> {formatPercentWad(pos.lockInfo?.bonusPercentage)}
                  </div>
                  <div className="text-gray-300">
                    <span className="text-gray-500">Shares awarded:</span> {pos.lockInfo?.sharesAwarded?.toString?.() ?? '?'}
                  </div>
                  <div className="text-gray-300">
                    <span className="text-gray-500">Pending rewards:</span> {pos.pendingRewards?.toString?.() ?? '?'}
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  {(() => {
                    const nowSec = BigInt(Math.floor(Date.now() / 1000))
                    const unlockTime = pos.lockInfo?.unlockTime
                    const matured = unlockTime !== undefined ? nowSec >= unlockTime : false
                    const pending = pos.pendingRewards ?? ZERO
                    const withdrawKey = `${pos.nftVault}:${pos.tokenId.toString()}:withdraw`
                    const unlockKey = `${pos.nftVault}:${pos.tokenId.toString()}:unlock`
                    const claimKey = `${pos.nftVault}:${pos.tokenId.toString()}:claim`
                    const redeemKey = `${pos.nftVault}:${pos.tokenId.toString()}:redeem`
                    const withdrawDisabled = !pending || pending === ZERO || isWritePending || actionKeyPending === withdrawKey
                    const unlockDisabled = !matured || isWritePending || actionKeyPending === unlockKey
                    const claimDisabled = !pending || pending === ZERO || isWritePending || actionKeyPending === claimKey
                    const redeemDisabled = !matured || isWritePending || actionKeyPending === redeemKey

                    return (
                      <>
                        {pos.kind === 'seigniorage' ? (
                          <>
                            <button
                              onClick={() => withdrawRewards(pos)}
                              disabled={withdrawDisabled}
                              className="px-3 py-1 rounded bg-blue-700 text-white hover:bg-blue-600 disabled:opacity-50 text-xs"
                            >
                              {actionKeyPending === withdrawKey ? 'Withdrawing…' : 'Withdraw rewards'}
                            </button>
                            <button
                              onClick={() => unlockBond(pos)}
                              disabled={unlockDisabled}
                              className="px-3 py-1 rounded bg-purple-700 text-white hover:bg-purple-600 disabled:opacity-50 text-xs"
                              title={matured ? 'Unlock bond' : 'Bond not matured yet'}
                            >
                              {actionKeyPending === unlockKey ? 'Unlocking…' : matured ? 'Unlock' : 'Unlock (locked)'}
                            </button>
                          </>
                        ) : (
                          <>
                            <button
                              onClick={() => claimProtocolRewards(pos)}
                              disabled={claimDisabled}
                              className="px-3 py-1 rounded bg-blue-700 text-white hover:bg-blue-600 disabled:opacity-50 text-xs"
                            >
                              {actionKeyPending === claimKey ? 'Claiming…' : 'Claim rewards'}
                            </button>
                            <button
                              onClick={() => redeemProtocolBond(pos)}
                              disabled={redeemDisabled}
                              className="px-3 py-1 rounded bg-purple-700 text-white hover:bg-purple-600 disabled:opacity-50 text-xs"
                              title={matured ? 'Redeem bond' : 'Bond not matured yet'}
                            >
                              {actionKeyPending === redeemKey ? 'Redeeming…' : matured ? 'Redeem' : 'Redeem (locked)'}
                            </button>
                          </>
                        )}
                      </>
                    )
                  })()}
                </div>

                {pos.metadata?.image && (
                  <div className="mt-4">
                    <div className="text-xs text-gray-400 mb-2">On-chain SVG</div>
                    {/* image is typically a data:image/svg+xml;base64,... */}
                    <div className="max-w-full rounded border border-slate-700 bg-white overflow-hidden">
                      <Image
                        src={pos.metadata.image}
                        alt={pos.metadata.name || `Bond #${pos.tokenId.toString()}`}
                        width={800}
                        height={800}
                        unoptimized
                        className="w-full h-auto"
                      />
                    </div>
                  </div>
                )}

                {pos.metadata?.name && (
                  <div className="mt-3 text-sm text-gray-200">
                    <div className="font-semibold">{pos.metadata.name}</div>
                    {pos.metadata.description && <div className="text-gray-400 mt-1">{pos.metadata.description}</div>}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {errors.length > 0 && (
        <div className="mb-8 p-4 bg-red-900/20 rounded-lg border border-red-800">
          <div className="text-red-200 font-semibold">Errors</div>
          <ul className="mt-2 text-sm text-red-200 list-disc pl-5 space-y-1">
            {errors.slice(0, 10).map((e, idx) => (
              <li key={idx}>{e}</li>
            ))}
          </ul>
          {errors.length > 10 && <div className="mt-2 text-xs text-red-200">(showing first 10)</div>}
        </div>
      )}

      <DebugPanel title="Portfolio Debug">
        <div className="text-xs text-gray-400">
          <div>Environment: {environment}</div>
          <div>ChainId: {resolvedChainId}</div>
          <div>Wallet: {address}</div>
          <div>Strategy vault tokens in list: {strategyVaultTokens.length}</div>
          <div>Seigniorage DETFs in list: {seigniorageDetfs.length}</div>
          <div>Protocol DETFs in list: {protocolDetfs.length}</div>
          <div>Bond positions: {bondPositions.length}</div>
        </div>
      </DebugPanel>
    </div>
  )
}
