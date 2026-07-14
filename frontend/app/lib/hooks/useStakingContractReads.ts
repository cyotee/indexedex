'use client'

import { useCallback, useMemo } from 'react'
import { erc20Abi, formatUnits, zeroAddress } from 'viem'
import { useReadContract } from 'wagmi'

import { protocolDetfAbi } from '../protocolDetfAbi'

type PlatformAddresses = {
  protocolDetf?: string
  /** @deprecated prefer pairToken */
  richToken?: string
  pairToken?: string
  /** @deprecated prefer rebasingClaimToken */
  richirToken?: string
  rebasingClaimToken?: string
  weth?: string
  weth9?: string
  rateAsset?: string
  protocolNftVault?: string
  reservePool?: string
}

type UseStakingContractReadsParams = {
  detfAddress: `0x${string}` | undefined
  dataChainId: number
  platform: PlatformAddresses
  address: `0x${string}` | undefined
}

export function useStakingContractReads({ detfAddress, dataChainId, platform, address }: UseStakingContractReadsParams) {
  const hasDetfAddress = !!detfAddress

  const { data: pairToken } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'pairToken', args: [], query: { enabled: hasDetfAddress } })
  const { data: rebasingClaimToken } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'rebasingClaimToken', args: [], query: { enabled: hasDetfAddress } })
  const { data: rateAsset } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'rateAsset', args: [], query: { enabled: hasDetfAddress } })
  const { data: nftVault } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'protocolNFTVault', args: [], query: { enabled: hasDetfAddress } })
  const { data: reservePool } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'reservePool', args: [], query: { enabled: hasDetfAddress } })
  const { data: syntheticPrice, error: syntheticPriceError, refetch: refetchSyntheticPrice } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'syntheticPrice', args: [], query: { enabled: hasDetfAddress } })
  const { data: mintThreshold, error: mintThresholdError, refetch: refetchMintThreshold } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'mintThreshold', args: [], query: { enabled: hasDetfAddress } })
  const { data: burnThreshold, error: burnThresholdError, refetch: refetchBurnThreshold } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'burnThreshold', args: [], query: { enabled: hasDetfAddress } })
  const { data: isMintingAllowed, refetch: refetchIsMintingAllowed } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'isMintingAllowed', args: [], query: { enabled: hasDetfAddress } })
  const { data: isBurningAllowed, refetch: refetchIsBurningAllowed } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'isBurningAllowed', args: [], query: { enabled: hasDetfAddress } })

  const platformPairToken = platform.pairToken ?? platform.richToken
  const platformClaimToken = platform.rebasingClaimToken ?? platform.richirToken
  const platformRateAsset = platform.rateAsset ?? platform.weth9 ?? platform.weth

  const effectivePairToken = (pairToken && pairToken !== zeroAddress ? pairToken : platformPairToken) as `0x${string}` | undefined
  const effectiveRebasingClaimToken = (rebasingClaimToken && rebasingClaimToken !== zeroAddress ? rebasingClaimToken : platformClaimToken) as `0x${string}` | undefined
  const effectiveRateAsset = (rateAsset && rateAsset !== zeroAddress ? rateAsset : platformRateAsset) as `0x${string}` | undefined

  // Legacy aliases for existing UI bindings
  const effectiveRichToken = effectivePairToken
  const effectiveRichirToken = effectiveRebasingClaimToken
  const effectiveWethToken = effectiveRateAsset

  const { data: pairDecimals } = useReadContract({ chainId: dataChainId, address: effectivePairToken, abi: erc20Abi, functionName: 'decimals', args: [], query: { enabled: !!effectivePairToken && effectivePairToken !== zeroAddress } })
  const { data: rateAssetDecimals } = useReadContract({ chainId: dataChainId, address: effectiveRateAsset, abi: erc20Abi, functionName: 'decimals', args: [], query: { enabled: !!effectiveRateAsset && effectiveRateAsset !== zeroAddress } })
  const { data: pairBalance, refetch: refetchPairBalance } = useReadContract({
    chainId: dataChainId,
    address: effectivePairToken,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!effectivePairToken && !!address,
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
    },
  })
  const { data: rateAssetBalance, refetch: refetchRateAssetBalance } = useReadContract({
    chainId: dataChainId,
    address: effectiveRateAsset,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!effectiveRateAsset && !!address,
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
    },
  })
  const { data: chirBalance, refetch: refetchChirBalance } = useReadContract({
    chainId: dataChainId,
    address: detfAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!detfAddress && !!address,
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
    },
  })

  const pairDec = Number(pairDecimals ?? 18)
  const rateAssetDec = Number(rateAssetDecimals ?? 18)
  const richDec = pairDec
  const wethDec = rateAssetDec
  const syntheticPriceDisplay = syntheticPrice !== undefined ? formatUnits(syntheticPrice, 18) : null
  const mintThresholdDisplay = mintThreshold !== undefined ? formatUnits(mintThreshold, 18) : null
  const burnThresholdDisplay = burnThreshold !== undefined ? formatUnits(burnThreshold, 18) : null
  const derivedMintingAllowed = syntheticPrice !== undefined && mintThreshold !== undefined ? syntheticPrice > mintThreshold : undefined
  const derivedBurningAllowed = syntheticPrice !== undefined && burnThreshold !== undefined ? syntheticPrice < burnThreshold : undefined
  const mintingAllowedNow = derivedMintingAllowed ?? (isMintingAllowed === true)
  const burningAllowedNow = derivedBurningAllowed ?? (isBurningAllowed === true)
  const availabilityMismatch =
    (derivedMintingAllowed !== undefined && isMintingAllowed !== undefined && derivedMintingAllowed !== isMintingAllowed) ||
    (derivedBurningAllowed !== undefined && isBurningAllowed !== undefined && derivedBurningAllowed !== isBurningAllowed)

  const syntheticPriceStatus = !hasDetfAddress ? '—' : syntheticPriceError ? 'Unavailable: read reverted on current pool state.' : syntheticPriceDisplay ?? '—'
  const mintThresholdStatus = !hasDetfAddress ? '—' : mintThresholdError ? 'Unavailable' : mintThresholdDisplay ?? '—'
  const burnThresholdStatus = !hasDetfAddress ? '—' : burnThresholdError ? 'Unavailable' : burnThresholdDisplay ?? '—'
  const pairTokenAddress = hasDetfAddress ? (effectivePairToken ?? '—') : (platformPairToken ?? '—')
  const rebasingClaimTokenAddress = hasDetfAddress ? (effectiveRebasingClaimToken ?? '—') : (platformClaimToken ?? '—')
  const richTokenAddress = pairTokenAddress
  const richirTokenAddress = rebasingClaimTokenAddress
  const nftVaultAddress = hasDetfAddress ? (nftVault ?? platform.protocolNftVault ?? '—') : (platform.protocolNftVault ?? '—')
  const reservePoolAddress = hasDetfAddress ? (reservePool ?? platform.reservePool ?? '—') : (platform.reservePool ?? '—')

  const refreshDetfState = useCallback(async () => {
    await Promise.all([
      refetchSyntheticPrice(),
      refetchMintThreshold(),
      refetchBurnThreshold(),
      refetchIsMintingAllowed(),
      refetchIsBurningAllowed(),
      refetchPairBalance(),
      refetchRateAssetBalance(),
      refetchChirBalance(),
    ])
  }, [refetchSyntheticPrice, refetchMintThreshold, refetchBurnThreshold, refetchIsMintingAllowed, refetchIsBurningAllowed, refetchPairBalance, refetchRateAssetBalance, refetchChirBalance])

  const stakingState = useMemo(() => ({
    pairToken,
    rebasingClaimToken,
    rateAsset,
    // legacy aliases
    richToken: pairToken,
    richirToken: rebasingClaimToken,
    wethToken: rateAsset,
    nftVault,
    reservePool,
    syntheticPrice,
    syntheticPriceError,
    mintThreshold,
    mintThresholdError,
    burnThreshold,
    burnThresholdError,
    isMintingAllowed,
    isBurningAllowed,
    pairDecimals,
    rateAssetDecimals,
    richDecimals: pairDecimals,
    wethDecimals: rateAssetDecimals,
    pairBalance,
    rateAssetBalance,
    richBalance: pairBalance,
    wethBalance: rateAssetBalance,
    chirBalance,
    pairDec,
    rateAssetDec,
    richDec,
    wethDec,
    effectivePairToken,
    effectiveRebasingClaimToken,
    effectiveRateAsset,
    effectiveRichToken,
    effectiveRichirToken,
    effectiveWethToken,
    syntheticPriceDisplay,
    mintThresholdDisplay,
    burnThresholdDisplay,
    syntheticPriceStatus,
    mintThresholdStatus,
    burnThresholdStatus,
    mintingAllowedNow,
    burningAllowedNow,
    availabilityMismatch,
    pairTokenAddress,
    rebasingClaimTokenAddress,
    richTokenAddress,
    richirTokenAddress,
    nftVaultAddress,
    reservePoolAddress,
    refreshDetfState,
  }), [
    pairToken,
    rebasingClaimToken,
    rateAsset,
    nftVault,
    reservePool,
    syntheticPrice,
    syntheticPriceError,
    mintThreshold,
    mintThresholdError,
    burnThreshold,
    burnThresholdError,
    isMintingAllowed,
    isBurningAllowed,
    pairDecimals,
    rateAssetDecimals,
    pairBalance,
    rateAssetBalance,
    chirBalance,
    pairDec,
    rateAssetDec,
    effectivePairToken,
    effectiveRebasingClaimToken,
    effectiveRateAsset,
    effectiveRichToken,
    effectiveRichirToken,
    effectiveWethToken,
    syntheticPriceDisplay,
    mintThresholdDisplay,
    burnThresholdDisplay,
    syntheticPriceStatus,
    mintThresholdStatus,
    burnThresholdStatus,
    mintingAllowedNow,
    burningAllowedNow,
    availabilityMismatch,
    pairTokenAddress,
    rebasingClaimTokenAddress,
    richTokenAddress,
    richirTokenAddress,
    nftVaultAddress,
    reservePoolAddress,
    refreshDetfState,
  ])

  return stakingState
}
