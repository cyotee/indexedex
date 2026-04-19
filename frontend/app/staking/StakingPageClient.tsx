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
  const chain = useChainResolution(CHAIN_ID_SEPOLIA)
  const publicClient = usePublicClient({ chainId: chain.dataChainId }) as PublicClient | undefined
  const { writeContractAsync, isPending: isWritePending } = useWriteContract()

  const artifacts = useMemo(() => getAddressArtifacts(chain.dataChainId, chain.environment), [chain.dataChainId, chain.environment])
  const platform = artifacts.platform as {
    protocolDetf?: string
    richToken?: string
    richirToken?: string
    weth?: string
    weth9?: string
    protocolNftVault?: string
    reservePool?: string
    balancerV3StandardExchangeRouter?: `0x${string}`
    permit2?: `0x${string}`
  }

  const detfs = useMemo(() => getProtocolDetfsForChain(chain.dataChainId, chain.environment), [chain.dataChainId, chain.environment])
  const detfOptions = useMemo(() => detfs.map((token) => ({ value: token.address, label: token.name || token.symbol })), [detfs])
  const [selectedDetf, setSelectedDetf] = useState<Address | ''>(() => detfs[0]?.address ?? '')
  const [status, setStatus] = useState('')

  useEffect(() => {
    setSelectedDetf(detfs[0]?.address ?? '')
    setStatus('')
  }, [chain.dataChainId, chain.environment, detfs])

  useEffect(() => {
    if (detfs.length === 0) {
      setSelectedDetf('')
      return
    }

    setSelectedDetf((current) => {
      if (current && detfs.some((detf) => detf.address.toLowerCase() === current.toLowerCase())) {
        return current
      }

      return detfs[0]?.address ?? ''
    })
  }, [detfs])

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

  const handleBondWithWeth = useCallback(async (amount: bigint, lockSeconds: bigint, wethAsEth: boolean) => {
    if (!detfAddress || !chain.address || !stakingReads.effectiveWethToken) return
    if (!chain.walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${chain.dataChainId} to bond.`)
      return
    }

    if (!wethAsEth) {
      await approveToken(stakingReads.effectiveWethToken, detfAddress, amount)
    }
    setStatus(wethAsEth ? 'Bonding with native ETH…' : 'Bonding with WETH…')
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
    const hash = await writeContractAsync({
      chain: chain.targetChain,
      account: chain.address,
      address: detfAddress,
      abi: protocolDetfAbi,
      functionName: 'bond',
      args: [stakingReads.effectiveWethToken, amount, lockSeconds, chain.address, wethAsEth, deadline],
      value: wethAsEth ? amount : undefined,
    })
    await waitForReceiptAndRefresh(hash as `0x${string}`, wethAsEth ? 'Bond ETH' : 'Bond WETH')
  }, [detfAddress, chain, stakingReads.effectiveWethToken, approveToken, writeContractAsync, waitForReceiptAndRefresh])

  const handleBondWithRich = useCallback(async (amount: bigint, lockSeconds: bigint) => {
    if (!detfAddress || !chain.address || !stakingReads.effectiveRichToken) return
    if (!chain.walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${chain.dataChainId} to bond.`)
      return
    }

    await approveToken(stakingReads.effectiveRichToken, detfAddress, amount)
    setStatus('Bonding with RICH…')
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
    const hash = await writeContractAsync({
      chain: chain.targetChain,
      account: chain.address,
      address: detfAddress,
      abi: protocolDetfAbi,
      functionName: 'bond',
      args: [stakingReads.effectiveRichToken, amount, lockSeconds, chain.address, false, deadline],
    })
    await waitForReceiptAndRefresh(hash as `0x${string}`, 'Bond RICH')
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
      <h1 className="text-2xl font-semibold">Staking</h1>
      <p className="mt-2 text-sm text-gray-300">
        Protocol DETF (CHIR): bond with WETH or RICH to mint NFT positions, mint CHIR through the Standard Exchange Router, or burn CHIR back through the same router path.
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
          <p className="text-sm text-gray-200">No Protocol DETF found for this chain. Run Stage 16 and then re-export tokenlists.</p>
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
                <div className="break-all text-sm text-gray-100">{stakingReads.richTokenAddress}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400">RICHIR</div>
                <div className="break-all text-sm text-gray-100">{stakingReads.richirTokenAddress}</div>
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
            richTokenAddress={stakingReads.richTokenAddress}
            richirTokenAddress={stakingReads.richirTokenAddress}
            reservePoolAddress={stakingReads.reservePoolAddress}
            nftVaultAddress={stakingReads.nftVaultAddress}
            status={status}
          />
        </div>
      )}
    </div>
  )
}