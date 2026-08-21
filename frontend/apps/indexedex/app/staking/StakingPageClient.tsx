'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import type { PublicClient } from 'viem'
import { usePublicClient, useWriteContract } from 'wagmi'
import { useSearchParams } from 'next/navigation'

import WalletStatusBanner from '../components/WalletStatusBanner'
import { AddressLink } from '../components/ui/AddressLink'
import { PageHeader } from '../components/ui/PageHeader'
import { CHAIN_ID_SEPOLIA, getAddressArtifacts } from '@indexedex/protocol/addressArtifacts'
import { isDebugLabEnabled } from '../lib/lab'
import useChainResolution from '../lib/hooks/useChainResolution'
import useRouterBytecode from '../lib/hooks/useRouterBytecode'
import { useStakingContractReads } from '../lib/hooks/useStakingContractReads'
import { protocolDetfAbi } from '@indexedex/protocol/protocolDetfAbi'
import {
  getFeaturedFeeDetfsForChain,
  getProtocolDetfsForChain,
  type Address,
  type TokenListEntry,
} from '@indexedex/protocol/tokenlists'
import BondSection from './sections/BondSection'
import BurnChirSection from './sections/BurnChirSection'
import DetfSelectorSection from './sections/DetfSelectorSection'
import MintChirSection from './sections/MintChirSection'
import PriceInfoSection from './sections/PriceInfoSection'
import SellNftSection from './sections/SellNftSection'
import StakingDebugPanel from './sections/StakingDebugPanel'

export type StakingPageClientProps = {
  /** When true: compact chrome, no StakingDebugPanel (Earn embed). */
  embedMode?: boolean
  /** Pin DETF address (Earn embed / deep link). */
  fixedDetf?: `0x${string}`
}

const erc20ApproveAbi = [
  {
    type: 'function',
    name: 'approve',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const

export default function StakingPageClient({
  embedMode = false,
  fixedDetf,
}: StakingPageClientProps = {}) {
  // DETF workspace (mint / bond / sell). Primary discovery is /earn; this page remains for full flows.
  const chain = useChainResolution(CHAIN_ID_SEPOLIA)
  const publicClient = usePublicClient({ chainId: chain.dataChainId }) as PublicClient | undefined
  const { writeContractAsync, isPending: isWritePending } = useWriteContract()
  const searchParams = useSearchParams()
  const queryDetf = searchParams?.get('detf') ?? null

  const artifacts = useMemo(() => getAddressArtifacts(chain.dataChainId, chain.environment), [chain.dataChainId, chain.environment])
  const platform = artifacts.platform as {
    protocolDetf?: string
    pairToken?: string
    rebasingClaimToken?: string
    weth?: string
    weth9?: string
    protocolNftVault?: string
    reservePool?: string
    balancerV3StandardExchangeRouter?: `0x${string}`
    permit2?: `0x${string}`
  }

  // Wave 2: prefer featured-fee-detfs list; merge protocol DETFs for lab discovery.
  const detfs = useMemo((): TokenListEntry[] => {
    const fee = getFeaturedFeeDetfsForChain(chain.dataChainId, chain.environment)
    const protocol = getProtocolDetfsForChain(chain.dataChainId, chain.environment)
    if (fee.length === 0) return protocol
    const seen = new Set(fee.map((t) => t.address.toLowerCase()))
    const rest = protocol.filter((t) => !seen.has(t.address.toLowerCase()))
    return [...fee, ...rest]
  }, [chain.dataChainId, chain.environment])
  const feeDetfs = useMemo(
    () => getFeaturedFeeDetfsForChain(chain.dataChainId, chain.environment),
    [chain.dataChainId, chain.environment],
  )
  const detfOptions = useMemo(
    () =>
      detfs.map((token) => ({
        value: token.address,
        label: token.display || token.name || token.symbol,
      })),
    [detfs],
  )
  const preferredDetf = useMemo((): Address | '' => {
    const pinned =
      fixedDetf ||
      (queryDetf && /^0x[0-9a-fA-F]{40}$/.test(queryDetf) ? (queryDetf as Address) : '')
    if (pinned && detfs.some((d) => d.address.toLowerCase() === pinned.toLowerCase())) {
      return pinned as Address
    }
    if (pinned) return pinned as Address
    // Prefer first featured fee-detf when list is non-empty.
    if (feeDetfs[0]?.address) return feeDetfs[0].address as Address
    const platformDetf = platform.protocolDetf
    if (platformDetf && detfs.some((d) => d.address.toLowerCase() === platformDetf.toLowerCase())) {
      return platformDetf as Address
    }
    return detfs[0]?.address ?? ''
  }, [detfs, feeDetfs, platform.protocolDetf, fixedDetf, queryDetf])
  const [selectedDetf, setSelectedDetf] = useState<Address | ''>(() => preferredDetf)
  const [status, setStatus] = useState('')

  useEffect(() => {
    setSelectedDetf(preferredDetf)
    setStatus('')
  }, [chain.dataChainId, chain.environment, preferredDetf])

  useEffect(() => {
    if (detfs.length === 0) {
      setSelectedDetf('')
      return
    }

    setSelectedDetf((current) => {
      if (current && detfs.some((detf) => detf.address.toLowerCase() === current.toLowerCase())) {
        return current
      }

      return preferredDetf
    })
  }, [detfs, preferredDetf])

  const detfAddress = selectedDetf ? (selectedDetf as `0x${string}`) : undefined
  const stakingReads = useStakingContractReads({
    detfAddress,
    dataChainId: chain.dataChainId,
    platform,
    address: chain.address,
  })

  const routerCandidate = useMemo(() => platform.balancerV3StandardExchangeRouter, [platform.balancerV3StandardExchangeRouter])
  const { routerAddress, routerHasBytecode, routerBytecodeError } = useRouterBytecode({ publicClient, routerCandidate })
  const permit2Address = platform.permit2

  const waitForReceiptAndRefresh = useCallback(async (hash: `0x${string}`, label: string) => {
    if (!publicClient) {
      setStatus(`${label} submitted: ${hash}`)
      return
    }

    setStatus(`${label} submitted: ${hash}. Waiting for confirmation…`)
    await publicClient.waitForTransactionReceipt({ hash })
    await stakingReads.refreshDetfState()
    setStatus(`${label} confirmed: ${hash}`)
  }, [publicClient, stakingReads])

  const approveToken = useCallback(async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
    setStatus('Submitting approval…')
    const hash = await writeContractAsync({
      chain: chain.targetChain,
      account: chain.address,
      address: token,
      abi: erc20ApproveAbi,
      functionName: 'approve',
      args: [spender, amount],
    })
    await waitForReceiptAndRefresh(hash as `0x${string}`, 'Approval')
  }, [writeContractAsync, chain.targetChain, chain.address, waitForReceiptAndRefresh])

  const handleBondWithWeth = useCallback(async (amount: bigint, lockSeconds: bigint, _wethAsEth?: boolean) => {
    // DETF bond surface is ERC20-only (rateAsset); ignore native ETH flag.
    if (!detfAddress || !chain.address || !stakingReads.effectiveWethToken) return
    if (!chain.walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${chain.dataChainId} to bond.`)
      return
    }

    await approveToken(stakingReads.effectiveWethToken, detfAddress, amount)
    setStatus('Bonding with rate asset…')
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
    const hash = await writeContractAsync({
      chain: chain.targetChain,
      account: chain.address,
      address: detfAddress,
      abi: protocolDetfAbi,
      functionName: 'bond',
      // pretransferred=false: DETF pulls via transferFrom after ERC-20 approve
      args: [stakingReads.effectiveWethToken, amount, lockSeconds, chain.address, false, deadline],
    })
    await waitForReceiptAndRefresh(hash as `0x${string}`, 'Bond rate asset')
  }, [detfAddress, chain, stakingReads.effectiveWethToken, approveToken, writeContractAsync, waitForReceiptAndRefresh])

  const handleBondWithRich = useCallback(async (amount: bigint, lockSeconds: bigint) => {
    if (!detfAddress || !chain.address || !stakingReads.effectiveRichToken) return
    if (!chain.walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${chain.dataChainId} to bond.`)
      return
    }

    await approveToken(stakingReads.effectiveRichToken, detfAddress, amount)
    setStatus('Bonding with pair token…')
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
    const hash = await writeContractAsync({
      chain: chain.targetChain,
      account: chain.address,
      address: detfAddress,
      abi: protocolDetfAbi,
      functionName: 'bond',
      args: [stakingReads.effectiveRichToken, amount, lockSeconds, chain.address, false, deadline],
    })
    await waitForReceiptAndRefresh(hash as `0x${string}`, 'Bond pair token')
  }, [detfAddress, chain, stakingReads.effectiveRichToken, approveToken, writeContractAsync, waitForReceiptAndRefresh])

  const handleSellNft = useCallback(async (tokenId: bigint) => {
    if (!detfAddress || !chain.address) return
    if (!chain.walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${chain.dataChainId} to sell.`)
      return
    }

    setStatus('Selling NFT…')
    const hash = await writeContractAsync({
      chain: chain.targetChain,
      account: chain.address,
      address: detfAddress,
      abi: protocolDetfAbi,
      functionName: 'sellNFT',
      args: [tokenId, chain.address],
    })
    await waitForReceiptAndRefresh(hash as `0x${string}`, 'Sell NFT')
  }, [detfAddress, chain, writeContractAsync, waitForReceiptAndRefresh])

  const shellClass = embedMode
    ? 'text-[var(--text-primary,#EDEDED)]'
    : 'mx-auto max-w-5xl px-4 text-[var(--text-primary,#EDEDED)] sm:px-6 lg:px-8'

  const detfSymbol = useMemo(() => {
    const match = detfs.find(
      (d) => detfAddress && d.address.toLowerCase() === detfAddress.toLowerCase(),
    )
    return match?.symbol || match?.display || match?.name || 'DETF'
  }, [detfs, detfAddress])

  const addrOrDash = (value: string | undefined) =>
    value && /^0x[0-9a-fA-F]{40}$/.test(value) ? (value as `0x${string}`) : null

  return (
    <div className={shellClass} data-testid={embedMode ? 'detf-workspace-embed-body' : 'detf-workspace-full'}>
      {!embedMode ? (
        <>
          <div className="mb-4 rounded-lg border border-[var(--border-accent,rgba(79,212,75,0.35))] bg-[var(--accent-muted,#1A3721)] px-3 py-2 text-sm">
            Looking for vaults?{' '}
            <a href="/earn" className="text-[var(--accent,#4FD44B)] hover:underline">
              Browse Earn
            </a>
            . This page is Protocol DETF: mint, bond, and sell.
          </div>
          <PageHeader
            title="Protocol DETF"
            subtitle="Use Protocol DETF to take a cut of app fees. Mint, bond, or leave when you are ready. Fees may apply. Amounts are not promises."
          />
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            Usual path: mint, bond, sell, then claim. Pick a DETF below if more than one is listed.
          </p>
        </>
      ) : null}

      <WalletStatusBanner
        className={embedMode ? 'mt-0' : 'mt-4'}
        isConnected={chain.isConnected}
        isUnsupportedChain={chain.isUnsupportedChain}
        walletMatchesDataChain={chain.walletMatchesDataChain}
        attachedWalletChainId={chain.attachedWalletChainId}
        dataChainId={chain.dataChainId}
        environment={chain.environment}
      />

      {detfOptions.length === 0 && !fixedDetf ? (
        <div className="mt-6 rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
          <p className="text-sm text-[var(--text-primary,#EDEDED)]">
            No Protocol DETF configured on this network.
          </p>
          <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)]">
            Check that <code className="text-[var(--text-primary,#EDEDED)]">featured-fee-detfs</code> or{' '}
            <code className="text-[var(--text-primary,#EDEDED)]">protocol-detfs</code> (or platform{' '}
            <code className="text-[var(--text-primary,#EDEDED)]">protocolDetf</code>) is present under{' '}
            <code className="text-[var(--text-primary,#EDEDED)]">app/addresses/</code> for the active chain, and
            that the app network / deployment environment matches those artifacts. If lists are empty, use
            committed fixtures or an operator-provided stack — do not deploy from this UI.
          </p>
        </div>
      ) : (
        <div className={embedMode ? 'mt-3 space-y-4' : 'mt-6 space-y-4'}>
          {!embedMode && !fixedDetf ? (
            <DetfSelectorSection
              detfOptions={detfOptions}
              selectedDetf={selectedDetf}
              onSelect={(value) => setSelectedDetf(value as Address)}
              isConnected={chain.isConnected}
              address={chain.address}
              attachedWalletChainId={chain.attachedWalletChainId}
              dataChainId={chain.dataChainId}
            />
          ) : null}

          <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <div className="text-xs text-[var(--text-muted,#9aa3b2)]">DETF token</div>
                <div className="break-all text-sm text-[var(--text-primary,#EDEDED)]">
                  {addrOrDash(detfAddress) ? (
                    <AddressLink chainId={chain.dataChainId} address={detfAddress!} />
                  ) : (
                    '—'
                  )}
                </div>
              </div>
              <div>
                <div className="text-xs text-[var(--text-muted,#9aa3b2)]">Pair token</div>
                <div className="break-all text-sm text-[var(--text-primary,#EDEDED)]">
                  {addrOrDash(stakingReads.pairTokenAddress) ? (
                    <AddressLink
                      chainId={chain.dataChainId}
                      address={stakingReads.pairTokenAddress}
                    />
                  ) : (
                    stakingReads.pairTokenAddress || '—'
                  )}
                </div>
              </div>
              <div>
                <div className="text-xs text-[var(--text-muted,#9aa3b2)]">Claim token</div>
                <div className="break-all text-sm text-[var(--text-primary,#EDEDED)]">
                  {addrOrDash(stakingReads.rebasingClaimTokenAddress) ? (
                    <AddressLink
                      chainId={chain.dataChainId}
                      address={stakingReads.rebasingClaimTokenAddress}
                    />
                  ) : (
                    stakingReads.rebasingClaimTokenAddress || '—'
                  )}
                </div>
              </div>
              <div>
                <div className="text-xs text-[var(--text-muted,#9aa3b2)]">Bond NFT vault</div>
                <div className="break-all text-sm text-[var(--text-primary,#EDEDED)]">
                  {addrOrDash(stakingReads.nftVaultAddress) ? (
                    <AddressLink
                      chainId={chain.dataChainId}
                      address={stakingReads.nftVaultAddress}
                    />
                  ) : (
                    stakingReads.nftVaultAddress || '—'
                  )}
                </div>
              </div>
              <div>
                <div className="text-xs text-[var(--text-muted,#9aa3b2)]">Reserve pool</div>
                <div className="break-all text-sm text-[var(--text-primary,#EDEDED)]">
                  {addrOrDash(stakingReads.reservePoolAddress) ? (
                    <AddressLink
                      chainId={chain.dataChainId}
                      address={stakingReads.reservePoolAddress}
                    />
                  ) : (
                    stakingReads.reservePoolAddress || '—'
                  )}
                </div>
              </div>
            </div>
          </div>

          <PriceInfoSection
            syntheticPriceStatus={stakingReads.syntheticPriceStatus}
            mintThresholdStatus={stakingReads.mintThresholdStatus}
            burnThresholdStatus={stakingReads.burnThresholdStatus}
            syntheticPriceError={stakingReads.syntheticPriceError as Error | undefined}
            mintingAllowedNow={stakingReads.mintingAllowedNow}
            burningAllowedNow={stakingReads.burningAllowedNow}
            availabilityMismatch={stakingReads.availabilityMismatch}
          />

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <MintChirSection
              detfAddress={detfAddress}
              detfSymbol={detfSymbol}
              rateAssetSymbol="WETH"
              effectiveWethToken={stakingReads.effectiveWethToken}
              dataChainId={chain.dataChainId}
              isConnected={chain.isConnected}
              walletMatchesDataChain={chain.walletMatchesDataChain}
              mintingAllowedNow={stakingReads.mintingAllowedNow}
              routerAddress={routerAddress}
              routerHasBytecode={routerHasBytecode}
              permit2Address={permit2Address}
              address={chain.address}
              publicClient={publicClient}
              targetChain={chain.targetChain}
              writeContractAsync={writeContractAsync}
              setStatus={setStatus}
              waitForReceiptAndRefresh={waitForReceiptAndRefresh}
              wethDecimals={stakingReads.wethDec}
            />

            <BurnChirSection
              detfAddress={detfAddress}
              detfSymbol={detfSymbol}
              rateAssetSymbol="WETH"
              effectiveWethToken={stakingReads.effectiveWethToken}
              dataChainId={chain.dataChainId}
              isConnected={chain.isConnected}
              walletMatchesDataChain={chain.walletMatchesDataChain}
              burningAllowedNow={stakingReads.burningAllowedNow}
              routerAddress={routerAddress}
              routerHasBytecode={routerHasBytecode}
              permit2Address={permit2Address}
              address={chain.address}
              publicClient={publicClient}
              targetChain={chain.targetChain}
              writeContractAsync={writeContractAsync}
              setStatus={setStatus}
              waitForReceiptAndRefresh={waitForReceiptAndRefresh}
              chirBalance={stakingReads.chirBalance as bigint | undefined}
              wethDecimals={stakingReads.wethDec}
            />
          </div>

          <BondSection
            isConnected={chain.isConnected}
            walletMatchesDataChain={chain.walletMatchesDataChain}
            isWritePending={isWritePending}
            wethDecimals={stakingReads.wethDec}
            richDecimals={stakingReads.richDec}
            wethBalance={stakingReads.wethBalance as bigint | undefined}
            richBalance={stakingReads.richBalance as bigint | undefined}
            rateAssetSymbol="WETH"
            pairTokenSymbol="pair token"
            onBondWithWeth={handleBondWithWeth}
            onBondWithRich={handleBondWithRich}
          />

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <SellNftSection
              isConnected={chain.isConnected}
              walletMatchesDataChain={chain.walletMatchesDataChain}
              isWritePending={isWritePending}
              onSell={handleSellNft}
            />
            <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
              <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Status</div>
              <div className="mt-2 break-all text-sm text-[var(--text-muted,#9aa3b2)]">
                {status || '—'}
              </div>
            </div>
          </div>

          {/* Never mount debug on Earn embed; full page only when lab debug enabled */}
          {!embedMode && isDebugLabEnabled() ? (
            <StakingDebugPanel
              chainSources={chain.chainSources}
              attachedWalletChainId={chain.attachedWalletChainId}
              resolvedWalletChainId={chain.resolvedWalletChainId}
              dataChainId={chain.dataChainId}
              routerAddress={routerAddress}
              routerHasBytecode={routerHasBytecode}
              routerBytecodeError={routerBytecodeError}
              detfAddress={detfAddress}
              pairTokenAddress={stakingReads.pairTokenAddress}
              rebasingClaimTokenAddress={stakingReads.rebasingClaimTokenAddress}
              reservePoolAddress={stakingReads.reservePoolAddress}
              nftVaultAddress={stakingReads.nftVaultAddress}
              status={status}
            />
          ) : null}
        </div>
      )}
    </div>
  )
}