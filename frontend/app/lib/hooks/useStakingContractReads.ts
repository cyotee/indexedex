'use client'

import { useCallback, useMemo } from 'react'
import { erc20Abi, formatUnits, zeroAddress } from 'viem'
import { useReadContract } from 'wagmi'

import { protocolDetfAbi } from '../protocolDetfAbi'

type PlatformAddresses = {
  protocolDetf?: string
  richToken?: string
  richirToken?: string
  weth?: string
  weth9?: string
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

  const { data: richToken } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'richToken', args: [], query: { enabled: hasDetfAddress } })
  const { data: richirToken } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'richirToken', args: [], query: { enabled: hasDetfAddress } })
  const { data: wethToken } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'wethToken', args: [], query: { enabled: hasDetfAddress } })
  const { data: nftVault } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'protocolNFTVault', args: [], query: { enabled: hasDetfAddress } })
  const { data: reservePool } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'reservePool', args: [], query: { enabled: hasDetfAddress } })
  const { data: syntheticPrice, error: syntheticPriceError, refetch: refetchSyntheticPrice } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'syntheticPrice', args: [], query: { enabled: hasDetfAddress } })
  const { data: mintThreshold, error: mintThresholdError, refetch: refetchMintThreshold } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'mintThreshold', args: [], query: { enabled: hasDetfAddress } })
  const { data: burnThreshold, error: burnThresholdError, refetch: refetchBurnThreshold } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'burnThreshold', args: [], query: { enabled: hasDetfAddress } })
  const { data: isMintingAllowed, refetch: refetchIsMintingAllowed } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'isMintingAllowed', args: [], query: { enabled: hasDetfAddress } })
  const { data: isBurningAllowed, refetch: refetchIsBurningAllowed } = useReadContract({ chainId: dataChainId, address: detfAddress, abi: protocolDetfAbi, functionName: 'isBurningAllowed', args: [], query: { enabled: hasDetfAddress } })

  const effectiveRichToken = (richToken && richToken !== zeroAddress ? richToken : platform.richToken) as `0x${string}` | undefined
  const effectiveRichirToken = (richirToken && richirToken !== zeroAddress ? richirToken : platform.richirToken) as `0x${string}` | undefined
  const platformWethToken = platform.weth9 ?? platform.weth
  const effectiveWethToken = (wethToken && wethToken !== zeroAddress ? wethToken : platformWethToken) as `0x${string}` | undefined

  const { data: richDecimals } = useReadContract({ chainId: dataChainId, address: effectiveRichToken, abi: erc20Abi, functionName: 'decimals', args: [], query: { enabled: !!effectiveRichToken && effectiveRichToken !== zeroAddress } })
  const { data: wethDecimals } = useReadContract({ chainId: dataChainId, address: effectiveWethToken, abi: erc20Abi, functionName: 'decimals', args: [], query: { enabled: !!effectiveWethToken && effectiveWethToken !== zeroAddress } })
  const { data: richBalance, refetch: refetchRichBalance } = useReadContract({
    chainId: dataChainId,
    address: effectiveRichToken,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!effectiveRichToken && !!address,
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
    },
  })
  const { data: wethBalance, refetch: refetchWethBalance } = useReadContract({
    chainId: dataChainId,
    address: effectiveWethToken,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!effectiveWethToken && !!address,
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

  const richDec = Number(richDecimals ?? 18)
  const wethDec = Number(wethDecimals ?? 18)
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
  const richTokenAddress = hasDetfAddress ? (effectiveRichToken ?? '—') : (platform.richToken ?? '—')
  const richirTokenAddress = hasDetfAddress ? (effectiveRichirToken ?? '—') : (platform.richirToken ?? '—')
  const nftVaultAddress = hasDetfAddress ? (nftVault ?? platform.protocolNftVault ?? '—') : (platform.protocolNftVault ?? '—')
  const reservePoolAddress = hasDetfAddress ? (reservePool ?? platform.reservePool ?? '—') : (platform.reservePool ?? '—')

  const refreshDetfState = useCallback(async () => {
    await Promise.all([
      refetchSyntheticPrice(),
      refetchMintThreshold(),
      refetchBurnThreshold(),
      refetchIsMintingAllowed(),
      refetchIsBurningAllowed(),
      refetchRichBalance(),
      refetchWethBalance(),
      refetchChirBalance(),
    ])
  }, [refetchSyntheticPrice, refetchMintThreshold, refetchBurnThreshold, refetchIsMintingAllowed, refetchIsBurningAllowed, refetchRichBalance, refetchWethBalance, refetchChirBalance])

  const stakingState = useMemo(() => ({
    richToken,
    richirToken,
    wethToken,
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
    richDecimals,
    wethDecimals,
    richBalance,
    wethBalance,
    chirBalance,
    richDec,
    wethDec,
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
    richTokenAddress,
    richirTokenAddress,
    nftVaultAddress,
    reservePoolAddress,
    refreshDetfState,
  }), [
    richToken,
    richirToken,
    wethToken,
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
    richDecimals,
    wethDecimals,
    richBalance,
    wethBalance,
    chirBalance,
    richDec,
    wethDec,
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
    richTokenAddress,
    richirTokenAddress,
    nftVaultAddress,
    reservePoolAddress,
    refreshDetfState,
  ])

  return stakingState
}

export default useStakingContractReads