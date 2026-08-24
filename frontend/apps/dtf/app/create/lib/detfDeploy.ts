import { encodeAbiParameters, type Address, type Hex, type PublicClient, zeroAddress } from 'viem'

import {
  burnPriceFromBand,
  humanToWad,
  mintPriceFromBand,
  percentToWad,
  type CreatePlan,
  withPriceLegs,
} from './createPlan'
import {
  CP_DETF_PKG_ABI,
  CP_HOOK_ARGS_COMPONENTS,
  CP_HOOK_PKG_ABI,
  DETF_PKG_ARGS_COMPONENTS,
  DIAMOND_FACTORY_ABI,
  HOOK_FACTORY_ABI,
  WEIGHTED_DETF_PKG_ABI,
  WEIGHTED_DETF_PKG_ARGS_COMPONENTS,
  WEIGHTED_HOOK_ARGS_COMPONENTS,
} from './detfAbi'
import { CP_HOOK_REQUIRED_FLAGS, WEIGHTED_HOOK_REQUIRED_FLAGS, findMineNonce } from './hookMine'
import type { SePlatform } from './sePlatform'

export type CpDetfPkgArgs = {
  name: string
  symbol: string
  standardExchangeVault: Address
  standardExchangeVaultShare: Address
  pairToken: Address
  creationPairPerDetfWad: bigint
  openingPairPerDetfWad: bigint
  mintThreshold: bigint
  burnThreshold: bigint
  thresholdMode: number
  expansionEpochLength: bigint
  expansionClosureRatePerYearWad: bigint
  expansionMaxCatchUpEpochs: bigint
  creator: Address
  claimName: string
  claimSymbol: string
  bondName: string
  bondSymbol: string
}

export function buildCpDetfArgs(plan: CreatePlan, creator: Address): CpDetfPkgArgs {
  const priced = withPriceLegs(plan)
  const creation = BigInt(humanToWad(priced.creationPairPerDetf[0] ?? '1') ?? '0')
  const openingRaw = (priced.openingPairPerDetf[0] ?? '').trim()
  const opening = openingRaw ? BigInt(humanToWad(openingRaw) ?? '0') : 0n
  const mint = plan.mode === 'policy' ? BigInt(humanToWad(mintPriceFromBand(plan.mintBandPct)) ?? '0') : 0n
  const burn = plan.mode === 'policy' ? BigInt(humanToWad(burnPriceFromBand(plan.burnBandPct)) ?? '0') : 0n
  return {
    name: plan.name.trim(),
    symbol: plan.symbol.trim(),
    standardExchangeVault: plan.vaults[0]!,
    standardExchangeVaultShare: zeroAddress,
    pairToken: plan.pairToken as Address,
    creationPairPerDetfWad: creation,
    openingPairPerDetfWad: opening,
    mintThreshold: mint,
    burnThreshold: burn,
    thresholdMode: plan.mode === 'open' ? 1 : 0,
    expansionEpochLength: 0n,
    expansionClosureRatePerYearWad: 0n,
    expansionMaxCatchUpEpochs: 0n,
    creator,
    claimName: plan.claimName.trim(),
    claimSymbol: plan.claimSymbol.trim(),
    bondName: plan.bondName.trim(),
    bondSymbol: plan.bondSymbol.trim(),
  }
}

export function encodeDetfPkgArgs(args: CpDetfPkgArgs, mineNonce: bigint): Hex {
  return encodeAbiParameters(
    [
      { type: 'tuple', components: DETF_PKG_ARGS_COMPONENTS },
      { type: 'uint256' },
    ],
    [args, mineNonce],
  )
}

export function encodeCpHookArgs(args: {
  poolManager: Address
  feeOracle: Address
  standardExchange: Address
  pairToken: Address
  rawToken: Address
  ownerOnlyLiquidity: boolean
  owner: Address
}): Hex {
  return encodeAbiParameters([{ type: 'tuple', components: CP_HOOK_ARGS_COMPONENTS }], [args])
}

export async function premineCpDetf(
  client: Pick<PublicClient, 'readContract'>,
  platform: SePlatform,
  detfArgs: CpDetfPkgArgs,
): Promise<{ predictedDetf: Address; mineNonce: bigint }> {
  if (!platform.cpDetfPkg || !platform.cpHookPkg || !platform.hookFactory || !platform.diamondPackageFactory) {
    throw new Error('This network has no one-strategy DETF create path.')
  }
  if (!platform.poolManager || !platform.feeOracle) {
    throw new Error('Missing pool manager or fee oracle.')
  }
  const predictedDetf = (await client.readContract({
    address: platform.diamondPackageFactory,
    abi: DIAMOND_FACTORY_ABI,
    functionName: 'calcAddress',
    args: [platform.cpDetfPkg, encodeDetfPkgArgs(detfArgs, 0n)],
  })) as Address

  const hookArgs = encodeCpHookArgs({
    poolManager: platform.poolManager,
    feeOracle: platform.feeOracle,
    standardExchange: detfArgs.standardExchangeVault,
    pairToken: detfArgs.pairToken,
    rawToken: predictedDetf,
    ownerOnlyLiquidity: true,
    owner: predictedDetf,
  })
  const [packageSalt, flags, initHash] = await Promise.all([
    client.readContract({
      address: platform.cpHookPkg,
      abi: CP_HOOK_PKG_ABI,
      functionName: 'calcSalt',
      args: [hookArgs],
    }),
    client.readContract({
      address: platform.cpHookPkg,
      abi: CP_HOOK_PKG_ABI,
      functionName: 'requiredHookFlags',
    }),
    client.readContract({
      address: platform.hookFactory,
      abi: HOOK_FACTORY_ABI,
      functionName: 'PROXY_INIT_HASH',
    }),
  ])
  const mineNonce = findMineNonce(
    platform.hookFactory,
    initHash as Hex,
    packageSalt as Hex,
    BigInt(flags as bigint) || CP_HOOK_REQUIRED_FLAGS,
  )
  return { predictedDetf, mineNonce }
}

export type WeightedDetfPkgArgs = {
  name: string
  symbol: string
  pairTokens: Address[]
  standardExchanges: Address[]
  vaultShares: Address[]
  rateProviders: Address[]
  detfWeight: bigint
  pairWeights: bigint[]
  creationPairPerDetfWad: bigint[]
  openingPairPerDetfWad: bigint[]
  mintThreshold: bigint
  burnThreshold: bigint
  thresholdMode: number
  expansionEpochLength: bigint
  expansionClosureRatePerYearWad: bigint
  expansionMaxCatchUpEpochs: bigint
  creator: Address
  claimName: string
  claimSymbol: string
  bondName: string
  bondSymbol: string
}

export type WeightedHookPkgArgs = {
  poolManager: Address
  feeOracle: Address
  n: number
  tokens: Address[]
  weights: bigint[]
  standardExchanges: Address[]
  rateProviders: Address[]
  ownerOnlyLiquidity: boolean
  owner: Address
}

export function sortAddresses(addrs: Address[]): Address[] {
  return [...addrs].sort((a, b) => {
    const av = BigInt(a)
    const bv = BigInt(b)
    if (av < bv) return -1
    if (av > bv) return 1
    return 0
  })
}

export function unorderedPairs(tokens: Address[]): [Address, Address][] {
  const out: [Address, Address][] = []
  for (let i = 0; i < tokens.length; i++) {
    for (let j = i + 1; j < tokens.length; j++) {
      out.push([tokens[i]!, tokens[j]!])
    }
  }
  return out
}

export function productTokensWeighted(detf: Address, pairTokens: Address[]): Address[] {
  return sortAddresses([detf, ...pairTokens])
}

function requireAddr(raw: string, label: string): Address {
  if (!/^0x[0-9a-fA-F]{40}$/.test(raw) || raw.toLowerCase() === zeroAddress) {
    throw new Error(`${label} is missing.`)
  }
  return raw as Address
}

export function buildWeightedDetfArgs(plan: CreatePlan, creator: Address): WeightedDetfPkgArgs {
  const priced = withPriceLegs(plan)
  const m = plan.vaults.length
  if (m < 1) throw new Error('Pick at least one strategy vault.')
  const pairTokens = plan.pairTokens.slice(0, m).map((a, i) => requireAddr(a, `Pair token ${i + 1}`))
  const standardExchanges = plan.vaults.map((a, i) => requireAddr(a, `Strategy vault ${i + 1}`))
  const detfWeight = BigInt(percentToWad(plan.detfWeight) ?? '0')
  const pairWeights = plan.weights.slice(0, m).map((w, i) => {
    const wad = BigInt(percentToWad(w) ?? '0')
    if (wad < 10n ** 16n) throw new Error(`Strategy ${i + 1} weight must be at least 1%.`)
    return wad
  })
  if (detfWeight < 10n ** 16n) throw new Error('DETF token weight must be at least 1%.')
  let wSum = detfWeight
  for (const w of pairWeights) wSum += w
  if (wSum !== 10n ** 18n) throw new Error('Weights must add to 100%.')
  const creation = priced.creationPairPerDetf.slice(0, m).map((v) => BigInt(humanToWad(v) ?? '0'))
  if (creation.some((v) => v === 0n)) throw new Error('Peg must be greater than 0.')
  const opening = priced.openingPairPerDetf.slice(0, m).map((v) => {
    const t = v.trim()
    if (!t) return 0n
    return BigInt(humanToWad(t) ?? '0')
  })
  const mint = plan.mode === 'policy' ? BigInt(humanToWad(mintPriceFromBand(plan.mintBandPct)) ?? '0') : 0n
  const burn = plan.mode === 'policy' ? BigInt(humanToWad(burnPriceFromBand(plan.burnBandPct)) ?? '0') : 0n
  const zeros = Array.from({ length: m }, () => zeroAddress)
  return {
    name: plan.name.trim(),
    symbol: plan.symbol.trim(),
    pairTokens,
    standardExchanges,
    vaultShares: zeros,
    rateProviders: zeros,
    detfWeight,
    pairWeights,
    creationPairPerDetfWad: creation,
    openingPairPerDetfWad: opening,
    mintThreshold: mint,
    burnThreshold: burn,
    thresholdMode: plan.mode === 'open' ? 1 : 0,
    expansionEpochLength: 0n,
    expansionClosureRatePerYearWad: 0n,
    expansionMaxCatchUpEpochs: 0n,
    creator,
    claimName: plan.claimName.trim(),
    claimSymbol: plan.claimSymbol.trim(),
    bondName: plan.bondName.trim(),
    bondSymbol: plan.bondSymbol.trim(),
  }
}

export function encodeWeightedDetfPkgArgs(args: WeightedDetfPkgArgs, mineNonce: bigint): Hex {
  return encodeAbiParameters(
    [
      { type: 'tuple', components: WEIGHTED_DETF_PKG_ARGS_COMPONENTS },
      { type: 'uint256' },
    ],
    [args, mineNonce],
  )
}

export function buildWeightedHookArgs(input: {
  detfArgs: WeightedDetfPkgArgs
  predictedDetf: Address
  poolManager: Address
  feeOracle: Address
}): WeightedHookPkgArgs {
  const m = input.detfArgs.pairTokens.length
  const n = m + 1
  const sorted = sortAddresses([input.predictedDetf, ...input.detfArgs.pairTokens])
  const tokens: Address[] = Array.from({ length: n }, () => zeroAddress)
  const ses: Address[] = Array.from({ length: n }, () => zeroAddress)
  const rps: Address[] = Array.from({ length: n }, () => zeroAddress)
  const weights: bigint[] = Array.from({ length: n }, () => 0n)
  const detfIdx = sorted.findIndex((a) => a.toLowerCase() === input.predictedDetf.toLowerCase())
  tokens[detfIdx] = input.predictedDetf
  weights[detfIdx] = input.detfArgs.detfWeight
  for (let i = 0; i < m; i++) {
    const p = input.detfArgs.pairTokens[i]!
    const b = sorted.findIndex((a) => a.toLowerCase() === p.toLowerCase())
    tokens[b] = p
    ses[b] = input.detfArgs.standardExchanges[i]!
    rps[b] = input.detfArgs.rateProviders[i]!
    weights[b] = input.detfArgs.pairWeights[i]!
  }
  return {
    poolManager: input.poolManager,
    feeOracle: input.feeOracle,
    n,
    tokens,
    weights,
    standardExchanges: ses,
    rateProviders: rps,
    ownerOnlyLiquidity: true,
    owner: input.predictedDetf,
  }
}

export function encodeWeightedHookArgs(args: WeightedHookPkgArgs): Hex {
  return encodeAbiParameters([{ type: 'tuple', components: WEIGHTED_HOOK_ARGS_COMPONENTS }], [args])
}

export async function premineWeightedDetf(
  client: Pick<PublicClient, 'readContract'>,
  platform: SePlatform,
  detfArgs: WeightedDetfPkgArgs,
): Promise<{ predictedDetf: Address; mineNonce: bigint }> {
  if (
    !platform.weightedDetfPkg ||
    !platform.weightedHookPkg ||
    !platform.hookFactory ||
    !platform.diamondPackageFactory
  ) {
    throw new Error('This network has no weighted DETF create path.')
  }
  if (!platform.poolManager || !platform.feeOracle) {
    throw new Error('Missing pool manager or fee oracle.')
  }
  const predictedDetf = (await client.readContract({
    address: platform.diamondPackageFactory,
    abi: DIAMOND_FACTORY_ABI,
    functionName: 'calcAddress',
    args: [platform.weightedDetfPkg, encodeWeightedDetfPkgArgs(detfArgs, 0n)],
  })) as Address
  const hookArgs = encodeWeightedHookArgs(
    buildWeightedHookArgs({
      detfArgs,
      predictedDetf,
      poolManager: platform.poolManager,
      feeOracle: platform.feeOracle,
    }),
  )
  const [packageSalt, flags, initHash] = await Promise.all([
    client.readContract({
      address: platform.weightedHookPkg,
      abi: CP_HOOK_PKG_ABI,
      functionName: 'calcSalt',
      args: [hookArgs],
    }),
    client.readContract({
      address: platform.weightedHookPkg,
      abi: CP_HOOK_PKG_ABI,
      functionName: 'requiredHookFlags',
    }),
    client.readContract({
      address: platform.hookFactory,
      abi: HOOK_FACTORY_ABI,
      functionName: 'PROXY_INIT_HASH',
    }),
  ])
  const mineNonce = findMineNonce(
    platform.hookFactory,
    initHash as Hex,
    packageSalt as Hex,
    BigInt(flags as bigint) || WEIGHTED_HOOK_REQUIRED_FLAGS,
  )
  return { predictedDetf, mineNonce }
}

export { CP_DETF_PKG_ABI, WEIGHTED_DETF_PKG_ABI }
