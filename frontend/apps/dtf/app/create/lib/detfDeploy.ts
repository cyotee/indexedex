import { encodeAbiParameters, type Address, type Hex, type PublicClient, zeroAddress } from 'viem'

import { burnPriceFromBand, humanToWad, mintPriceFromBand, type CreatePlan, withPriceLegs } from './createPlan'
import {
  CP_DETF_PKG_ABI,
  CP_HOOK_ARGS_COMPONENTS,
  CP_HOOK_PKG_ABI,
  DETF_PKG_ARGS_COMPONENTS,
  DIAMOND_FACTORY_ABI,
  HOOK_FACTORY_ABI,
} from './detfAbi'
import { CP_HOOK_REQUIRED_FLAGS, findMineNonce } from './hookMine'
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
    throw new Error('This network has no Single Pool DETF package.')
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

export { CP_DETF_PKG_ABI }
