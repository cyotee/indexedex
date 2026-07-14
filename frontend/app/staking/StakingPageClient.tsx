'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import type { PublicClient } from 'viem'
import { usePublicClient, useWriteContract } from 'wagmi'

import WalletStatusBanner from '../components/WalletStatusBanner'
import { CHAIN_ID_SEPOLIA, getAddressArtifacts } from '../lib/addressArtifacts'
import useChainResolution from '../lib/hooks/useChainResolution'
import useRouterBytecode from '../lib/hooks/useRouterBytecode'
import useStakingContractReads from '../lib/hooks/useStakingContractReads'
import { protocolDetfAbi } from '../lib/protocolDetfAbi'
import { getProtocolDetfsForChain, type Address } from '../lib/tokenlists'
import BondSection from './sections/BondSection'
import BurnChirSection from './sections/BurnChirSection'
import DetfSelectorSection from './sections/DetfSelectorSection'
import MintChirSection from './sections/MintChirSection'
import PriceInfoSection from './sections/PriceInfoSection'
import SellNftSection from './sections/SellNftSection'
import StakingDebugPanel from './sections/StakingDebugPanel'

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

export default function StakingPageClient() {
  // DETF workspace (mint / bond / sell). Primary discovery is /earn; this page remains for full flows.
  const chain = useChainResolution(CHAIN_ID_SEPOLIA)
  const publicClient = usePublicClient({ chainId: chain.dataChainId }) as PublicClient | undefined
  const { writeContractAsync, isPending: isWritePending } = useWriteContract()

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

  // Single Vault DETF (composed/single CHIR) from tokenlists + platform.protocolDetf
  // written by local_testing Scenario 3 (Script_12).
  const detfs = useMemo(() => getProtocolDetfsForChain(chain.dataChainId, chain.environment), [chain.dataChainId, chain.environment])
  const detfOptions = useMemo(
    () =>
      detfs.map((token) => ({
        value: token.address,
        label: token.display || token.name || token.symbol,
      })),
    [detfs],
  )
  const preferredDetf = useMemo((): Address | '' => {
    const platformDetf = platform.protocolDetf
    if (platformDetf && detfs.some((d) => d.address.toLowerCase() === platformDetf.toLowerCase())) {
      return platformDetf as Address
    }
    return detfs[0]?.address ?? ''
  }, [detfs, platform.protocolDetf])
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
      args: [stakingReads.effectiveWethToken, amount, lockSeconds, chain.address, deadline],
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
      args: [stakingReads.effectiveRichToken, amount, lockSeconds, chain.address, deadline],
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

  return (
    <div className="mx-auto max-w-5xl px-4 text-gray-100 sm:px-6 lg:px-8">
      <div className="mb-4 rounded-lg border border-[var(--border-accent,rgba(79,212,75,0.35))] bg-[var(--accent-muted,#1A3721)] px-3 py-2 text-sm">
        Looking for the product catalog?{' '}
        <a href="/earn?type=detf" className="text-[var(--accent,#4FD44B)] hover:underline">
          Browse Earn
        </a>
        . This page is the full DETF mint / bond / sell workspace.
      </div>
      <h1 className="text-2xl font-semibold">DETF workspace</h1>
      <p className="mt-2 text-sm text-gray-300">
        Single Vault DETF (CHIR): bond with WETH or RICH to mint NFT positions, mint CHIR through the Standard Exchange
        Router, or burn CHIR back through the same router path. Local deploys use{' '}
        <code className="text-gray-100">local_testing.sh scenario3</code> (Script_12) and feed this page via the
        protocol-detfs token list and chain platform.json.
      </p>

      <WalletStatusBanner
        className="mt-4"
        isConnected={chain.isConnected}
        isUnsupportedChain={chain.isUnsupportedChain}
        walletMatchesDataChain={chain.walletMatchesDataChain}
        attachedWalletChainId={chain.attachedWalletChainId}
        dataChainId={chain.dataChainId}
        environment={chain.environment}
      />

      {detfOptions.length === 0 ? (
        <div className="mt-6 rounded-lg border border-gray-700 bg-gray-800 p-4">
          <p className="text-sm text-gray-200">
            No Single Vault DETF (CHIR) found for this chain. Deploy local Scenario 3, then rebuild token lists:
          </p>
          <pre className="mt-3 overflow-x-auto rounded bg-gray-900 p-3 text-xs text-gray-300">
{`DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh foundation
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh scenario3`}
          </pre>
          <p className="mt-3 text-xs text-gray-400">
            Scenario 3 writes <code className="text-gray-300">protocolDetf</code> into{' '}
            <code className="text-gray-300">12_scenario_3.json</code> and a{' '}
            <code className="text-gray-300">vaults/protocolDetf</code> fragment. The shell wrapper synthesizes
            chain platform.json and runs the tokenlist aggregator so Staking can discover CHIR.
          </p>
        </div>
      ) : (
        <div className="mt-6 space-y-4">
          <DetfSelectorSection
            detfOptions={detfOptions}
            selectedDetf={selectedDetf}
            onSelect={(value) => setSelectedDetf(value as Address)}
            isConnected={chain.isConnected}
            address={chain.address}
            attachedWalletChainId={chain.attachedWalletChainId}
            dataChainId={chain.dataChainId}
          />

          <div className="rounded-lg border border-gray-700 bg-gray-800 p-4">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <div className="text-xs text-gray-400">CHIR (Proxy)</div>
                <div className="break-all text-sm text-gray-100">{detfAddress ?? '—'}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400">RICH</div>
                <div className="break-all text-sm text-gray-100">{stakingReads.pairTokenAddress}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400">RICHIR</div>
                <div className="break-all text-sm text-gray-100">{stakingReads.rebasingClaimTokenAddress}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400">NFT Vault</div>
                <div className="break-all text-sm text-gray-100">{stakingReads.nftVaultAddress}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400">Reserve Pool</div>
                <div className="break-all text-sm text-gray-100">{stakingReads.reservePoolAddress}</div>
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
            <div className="rounded-md border border-gray-700 bg-gray-900 p-3">
              <div className="text-sm font-medium text-gray-100">Status</div>
              <div className="mt-2 break-all text-sm text-gray-200">{status || '—'}</div>
            </div>
          </div>

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
        </div>
      )}
    </div>
  )
}