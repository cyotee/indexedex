import { encodeAbiParameters, type Address, type Hex, type PublicClient, zeroAddress } from 'viem'

import {
  burnPriceFromBand,
  humanToWad,
  mintPriceFromBand,
  percentToWad,
  planPairTokens,
  resolvedBondName,
  resolvedBondSymbol,
  resolvedClaimName,
  resolvedClaimSymbol,
  type CreatePlan,
  withPriceLegs,
} from './createPlan'
import {
  CP_HOOK_ARGS_COMPONENTS,
  CP_HOOK_DEPLOY_ABI,
  DIAMOND_FACTORY_ABI,
  HOOK_FACTORY_ABI,
  HOOK_PKG_VIEW_ABI,
  QUAD_HOOK_ARGS_COMPONENTS,
  QUAD_HOOK_DEPLOY_ABI,
  UNI_V4_DETF_PKG_ARGS_COMPONENTS,
  WEIGHTED_HOOK_ARGS_COMPONENTS,
  WEIGHTED_HOOK_DEPLOY_ABI,
} from './detfAbi'
import {
  CP_HOOK_REQUIRED_FLAGS,
  QUAD_HOOK_REQUIRED_FLAGS,
  WEIGHTED_HOOK_REQUIRED_FLAGS,
  findMineNonce,
  predictHookAddress,
} from './hookMine'
import type { SePlatform } from './sePlatform'

export const QUAD_BASE_AMP = 100n
export const ROUTE_TABLE_DEFAULT = 0

export type UniV4DetfPkgArgs = {
  name: string
  symbol: string
  hook: Address
  ownerOnlyLiquidity: boolean
  creationPairPerDetfWad: bigint[]
  openingPairPerDetfWad: bigint[]
  mintThreshold: bigint
  burnThreshold: bigint
  expansionClosureRatePerYearWad: bigint
  creator: Address
  claimName: string
  claimSymbol: string
  bondName: string
  bondSymbol: string
  mintRouteMode: number
  mintRoutes: { token: Address; vault: Address }[]
  burnRouteMode: number
  burnRoutes: { token: Address; vault: Address }[]
  bondRouteMode: number
  bondRoutes: { token: Address; vault: Address }[]
  donateRouteMode: number
  donateRoutes: { token: Address; vault: Address }[]
}

export type CpHookPkgArgs = {
  poolManager: Address
  feeOracle: Address
  standardExchange: Address
  pairToken: Address
  rawToken: Address
  pairTokenDecimals: number
  rawTokenDecimals: number
  ownerOnlyLiquidity: boolean
  owner: Address
}

export type WeightedHookPkgArgs = {
  poolManager: Address
  feeOracle: Address
  n: number
  tokens: Address[]
  weights: bigint[]
  standardExchanges: Address[]
  rateProviders: Address[]
  tokenDecimals: number[]
  seDecimals: number[]
  ownerOnlyLiquidity: boolean
  owner: Address
}

export type QuadHookPkgArgs = {
  poolManager: Address
  feeOracle: Address
  tokens: [Address, Address, Address, Address]
  standardExchanges: [Address, Address, Address, Address]
  rateProviders: [Address, Address, Address, Address]
  tokenDecimals: [number, number, number, number]
  seDecimals: [number, number, number, number]
  baseAmp: bigint
  ownerOnlyLiquidity: boolean
  owner: Address
}

const ERC20_DECIMALS_ABI = [
  {
    type: 'function',
    name: 'decimals',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
] as const

export async function readLiveDecimals(
  client: Pick<PublicClient, 'readContract'>,
  token: Address,
): Promise<number> {
  return Number(
    await client.readContract({
      address: token,
      abi: ERC20_DECIMALS_ABI,
      functionName: 'decimals',
    }),
  )
}

function emptyRoutes(): { token: Address; vault: Address }[] {
  return []
}

function requireAddr(raw: string, label: string): Address {
  if (!/^0x[0-9a-fA-F]{40}$/.test(raw) || raw.toLowerCase() === zeroAddress) {
    throw new Error(`${label} is missing.`)
  }
  return raw as Address
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

function ratesInHookPairOrder(
  pairTokens: Address[],
  values: string[],
  fallback: string,
): bigint[] {
  const byPair = new Map<string, string>()
  for (let i = 0; i < pairTokens.length; i++) {
    byPair.set(pairTokens[i]!.toLowerCase(), values[i] ?? fallback)
  }
  return sortAddresses(pairTokens).map((pair) => {
    const raw = byPair.get(pair.toLowerCase()) ?? fallback
    const t = raw.trim()
    if (!t) return 0n
    return BigInt(humanToWad(t) ?? '0')
  })
}

export function buildUniV4DetfArgs(plan: CreatePlan, creator: Address): UniV4DetfPkgArgs {
  const priced = withPriceLegs(plan)
  const pairs = planPairTokens(plan)
  if (pairs.length === 0) throw new Error('Pick a pair token for each strategy.')
  const creation = ratesInHookPairOrder(pairs, priced.creationPairPerDetf, '1')
  if (creation.some((v) => v === 0n)) throw new Error('Peg must be greater than 0.')
  const opening = ratesInHookPairOrder(pairs, priced.openingPairPerDetf, '')
  const mint = BigInt(humanToWad(mintPriceFromBand(plan.mintBandPct)) ?? '0')
  const burn = BigInt(humanToWad(burnPriceFromBand(plan.burnBandPct)) ?? '0')
  const none = emptyRoutes()
  return {
    name: plan.name.trim(),
    symbol: plan.symbol.trim(),
    hook: zeroAddress,
    ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
    creationPairPerDetfWad: creation,
    openingPairPerDetfWad: opening.every((v) => v === 0n) ? [] : opening,
    mintThreshold: mint,
    burnThreshold: burn,
    expansionClosureRatePerYearWad: 0n,
    creator,
    claimName: resolvedClaimName(plan),
    claimSymbol: resolvedClaimSymbol(plan),
    bondName: resolvedBondName(plan),
    bondSymbol: resolvedBondSymbol(plan),
    mintRouteMode: ROUTE_TABLE_DEFAULT,
    mintRoutes: none,
    burnRouteMode: ROUTE_TABLE_DEFAULT,
    burnRoutes: none,
    bondRouteMode: ROUTE_TABLE_DEFAULT,
    bondRoutes: none,
    donateRouteMode: ROUTE_TABLE_DEFAULT,
    donateRoutes: none,
  }
}

export function encodeUniV4DetfPkgArgs(args: UniV4DetfPkgArgs): Hex {
  return encodeAbiParameters(
    [{ type: 'tuple', components: UNI_V4_DETF_PKG_ARGS_COMPONENTS }],
    [args],
  )
}

export function encodeCpHookArgs(args: CpHookPkgArgs): Hex {
  return encodeAbiParameters([{ type: 'tuple', components: CP_HOOK_ARGS_COMPONENTS }], [args])
}

export function encodeWeightedHookArgs(args: WeightedHookPkgArgs): Hex {
  return encodeAbiParameters([{ type: 'tuple', components: WEIGHTED_HOOK_ARGS_COMPONENTS }], [args])
}

export function encodeQuadHookArgs(args: QuadHookPkgArgs): Hex {
  return encodeAbiParameters([{ type: 'tuple', components: QUAD_HOOK_ARGS_COMPONENTS }], [args])
}

export function buildCpHookArgs(input: {
  ownerOnlyLiquidity: boolean
  predictedDetf: Address
  pairToken: Address
  standardExchange: Address
  poolManager: Address
  feeOracle: Address
  pairTokenDecimals: number
}): CpHookPkgArgs {
  return {
    poolManager: input.poolManager,
    feeOracle: input.feeOracle,
    standardExchange: input.standardExchange,
    pairToken: input.pairToken,
    rawToken: input.predictedDetf,
    pairTokenDecimals: input.pairTokenDecimals,
    rawTokenDecimals: 9,
    ownerOnlyLiquidity: input.ownerOnlyLiquidity,
    owner: input.predictedDetf,
  }
}

export function buildWeightedHookArgs(input: {
  ownerOnlyLiquidity: boolean
  predictedDetf: Address
  pairTokens: Address[]
  standardExchanges: Address[]
  detfWeight: bigint
  pairWeights: bigint[]
  poolManager: Address
  feeOracle: Address
  pairTokenDecimals: number[]
  seShareDecimals: number[]
}): WeightedHookPkgArgs {
  const m = input.pairTokens.length
  const n = m + 1
  const sorted = sortAddresses([input.predictedDetf, ...input.pairTokens])
  const tokens: Address[] = Array.from({ length: n }, () => zeroAddress)
  const ses: Address[] = Array.from({ length: n }, () => zeroAddress)
  const rps: Address[] = Array.from({ length: n }, () => zeroAddress)
  const weights: bigint[] = Array.from({ length: n }, () => 0n)
  const tokenDecimals: number[] = Array.from({ length: n }, () => 18)
  const seDecimals: number[] = Array.from({ length: n }, () => 0)
  const detfIdx = sorted.findIndex((a) => a.toLowerCase() === input.predictedDetf.toLowerCase())
  tokens[detfIdx] = input.predictedDetf
  weights[detfIdx] = input.detfWeight
  tokenDecimals[detfIdx] = 9
  seDecimals[detfIdx] = 0
  for (let i = 0; i < m; i++) {
    const p = input.pairTokens[i]!
    const b = sorted.findIndex((a) => a.toLowerCase() === p.toLowerCase())
    tokens[b] = p
    ses[b] = input.standardExchanges[i]!
    weights[b] = input.pairWeights[i]!
    tokenDecimals[b] = input.pairTokenDecimals[i] ?? 18
    seDecimals[b] = input.seShareDecimals[i] ?? 0
  }
  return {
    poolManager: input.poolManager,
    feeOracle: input.feeOracle,
    n,
    tokens,
    weights,
    standardExchanges: ses,
    rateProviders: rps,
    tokenDecimals,
    seDecimals,
    ownerOnlyLiquidity: input.ownerOnlyLiquidity,
    owner: input.predictedDetf,
  }
}

export function buildQuadHookArgs(input: {
  ownerOnlyLiquidity: boolean
  predictedDetf: Address
  pairTokens: Address[]
  standardExchanges: Address[]
  poolManager: Address
  feeOracle: Address
  pairTokenDecimals: number[]
  seShareDecimals: number[]
}): QuadHookPkgArgs {
  if (input.pairTokens.length !== 3 || input.standardExchanges.length !== 3) {
    throw new Error('Three dollar vaults, each with a pair token.')
  }
  const toks = sortAddresses([input.predictedDetf, ...input.pairTokens]) as [
    Address,
    Address,
    Address,
    Address,
  ]
  const ses: [Address, Address, Address, Address] = [zeroAddress, zeroAddress, zeroAddress, zeroAddress]
  const rps: [Address, Address, Address, Address] = [zeroAddress, zeroAddress, zeroAddress, zeroAddress]
  const tokenDecimals: [number, number, number, number] = [18, 18, 18, 18]
  const seDecimals: [number, number, number, number] = [0, 0, 0, 0]
  for (let i = 0; i < 4; i++) {
    const t = toks[i]!
    if (t.toLowerCase() === input.predictedDetf.toLowerCase()) {
      ses[i] = zeroAddress
      tokenDecimals[i] = 9
      seDecimals[i] = 0
      continue
    }
    const idx = input.pairTokens.findIndex((p) => p.toLowerCase() === t.toLowerCase())
    ses[i] = input.standardExchanges[idx]!
    tokenDecimals[i] = input.pairTokenDecimals[idx] ?? 18
    seDecimals[i] = input.seShareDecimals[idx] ?? 0
  }
  return {
    poolManager: input.poolManager,
    feeOracle: input.feeOracle,
    tokens: toks,
    standardExchanges: ses,
    rateProviders: rps,
    tokenDecimals,
    seDecimals,
    baseAmp: QUAD_BASE_AMP,
    ownerOnlyLiquidity: input.ownerOnlyLiquidity,
    owner: input.predictedDetf,
  }
}

export function weightedLegsFromPlan(plan: CreatePlan): {
  pairTokens: Address[]
  standardExchanges: Address[]
  detfWeight: bigint
  pairWeights: bigint[]
} {
  const m = plan.vaults.length
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
  return { pairTokens, standardExchanges, detfWeight, pairWeights }
}

export function hookPkgForPlan(plan: CreatePlan, platform: SePlatform): Address | null {
  if (plan.typeId === 'one-vault') return platform.cpHookPkg
  if (plan.typeId === 'weighted') return platform.weightedHookPkg
  if (plan.typeId === 'stables') return platform.curveQuadHookPkg
  return null
}

export function hookFlagsForPlan(plan: CreatePlan): bigint {
  if (plan.typeId === 'weighted') return WEIGHTED_HOOK_REQUIRED_FLAGS
  if (plan.typeId === 'stables') return QUAD_HOOK_REQUIRED_FLAGS
  return CP_HOOK_REQUIRED_FLAGS
}

export type HookDecimalScales = {
  pairTokenDecimals: number[]
  seShareDecimals: number[]
}

export async function readHookDecimalScales(
  client: Pick<PublicClient, 'readContract'>,
  plan: CreatePlan,
): Promise<HookDecimalScales> {
  if (plan.typeId === 'one-vault') {
    const pair = requireAddr(plan.pairToken, 'Pair token')
    const se = requireAddr(plan.vaults[0] ?? '', 'Strategy vault')
    const [pairTokenDecimals, seShareDecimals] = await Promise.all([
      readLiveDecimals(client, pair),
      readLiveDecimals(client, se),
    ])
    return { pairTokenDecimals: [pairTokenDecimals], seShareDecimals: [seShareDecimals] }
  }
  if (plan.typeId === 'weighted') {
    const legs = weightedLegsFromPlan(plan)
    const pairTokenDecimals = await Promise.all(legs.pairTokens.map((a) => readLiveDecimals(client, a)))
    const seShareDecimals = await Promise.all(
      legs.standardExchanges.map((a) => readLiveDecimals(client, a)),
    )
    return { pairTokenDecimals, seShareDecimals }
  }
  if (plan.typeId === 'stables') {
    const m = plan.vaults.length
    const pairTokens = plan.pairTokens.slice(0, m).map((a, i) => requireAddr(a, `Pair token ${i + 1}`))
    const ses = plan.vaults.map((a, i) => requireAddr(a, `Dollar vault ${i + 1}`))
    const pairTokenDecimals = await Promise.all(pairTokens.map((a) => readLiveDecimals(client, a)))
    const seShareDecimals = await Promise.all(ses.map((a) => readLiveDecimals(client, a)))
    return { pairTokenDecimals, seShareDecimals }
  }
  throw new Error('Pick how many strategies to include.')
}

export function encodeHookArgsForPlan(input: {
  plan: CreatePlan
  predictedDetf: Address
  poolManager: Address
  feeOracle: Address
  scales: HookDecimalScales
}): Hex {
  const { plan, predictedDetf, poolManager, feeOracle, scales } = input
  if (plan.typeId === 'one-vault') {
    return encodeCpHookArgs(
      buildCpHookArgs({
        predictedDetf,
        ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
        pairToken: requireAddr(plan.pairToken, 'Pair token'),
        standardExchange: requireAddr(plan.vaults[0] ?? '', 'Strategy vault'),
        poolManager,
        feeOracle,
        pairTokenDecimals: scales.pairTokenDecimals[0] ?? 18,
      }),
    )
  }
  if (plan.typeId === 'weighted') {
    const legs = weightedLegsFromPlan(plan)
    return encodeWeightedHookArgs(
      buildWeightedHookArgs({
        predictedDetf,
        ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
        pairTokens: legs.pairTokens,
        standardExchanges: legs.standardExchanges,
        detfWeight: legs.detfWeight,
        pairWeights: legs.pairWeights,
        poolManager,
        feeOracle,
        pairTokenDecimals: scales.pairTokenDecimals,
        seShareDecimals: scales.seShareDecimals,
      }),
    )
  }
  if (plan.typeId === 'stables') {
    const m = plan.vaults.length
    return encodeQuadHookArgs(
      buildQuadHookArgs({
        predictedDetf,
        ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
        pairTokens: plan.pairTokens.slice(0, m).map((a, i) => requireAddr(a, `Pair token ${i + 1}`)),
        standardExchanges: plan.vaults.map((a, i) => requireAddr(a, `Dollar vault ${i + 1}`)),
        poolManager,
        feeOracle,
        pairTokenDecimals: scales.pairTokenDecimals,
        seShareDecimals: scales.seShareDecimals,
      }),
    )
  }
  throw new Error('Pick how many strategies to include.')
}

export function hookProductTokens(plan: CreatePlan, predictedDetf: Address): Address[] {
  return productTokensWeighted(predictedDetf, planPairTokens(plan))
}

export async function predictUniV4Detf(
  client: Pick<PublicClient, 'readContract'>,
  platform: SePlatform,
  detfArgs: UniV4DetfPkgArgs,
): Promise<Address> {
  if (!platform.uniV4DetfPkg || !platform.diamondPackageFactory) {
    throw new Error('This network has no DETF create path.')
  }
  const saltArgs = { ...detfArgs, hook: zeroAddress }
  return (await client.readContract({
    address: platform.diamondPackageFactory,
    abi: DIAMOND_FACTORY_ABI,
    functionName: 'calcAddress',
    args: [platform.uniV4DetfPkg, encodeUniV4DetfPkgArgs(saltArgs)],
  })) as Address
}

export async function premineHook(
  client: Pick<PublicClient, 'readContract'>,
  platform: SePlatform,
  plan: CreatePlan,
  predictedDetf: Address,
): Promise<{
  hookPkg: Address
  mineNonce: bigint
  hookArgs: Hex
  predictedHook: Address
  scales: HookDecimalScales
}> {
  const hookPkg = hookPkgForPlan(plan, platform)
  if (!hookPkg || !platform.hookFactory || !platform.poolManager || !platform.feeOracle) {
    throw new Error('This network has no reserve hook create path for this basket.')
  }
  const scales = await readHookDecimalScales(client, plan)
  const hookArgs = encodeHookArgsForPlan({
    plan,
    predictedDetf,
    poolManager: platform.poolManager,
    feeOracle: platform.feeOracle,
    scales,
  })
  const [packageSalt, flags, initHash] = await Promise.all([
    client.readContract({
      address: hookPkg,
      abi: HOOK_PKG_VIEW_ABI,
      functionName: 'calcSalt',
      args: [hookArgs],
    }),
    client.readContract({
      address: hookPkg,
      abi: HOOK_PKG_VIEW_ABI,
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
    BigInt(flags as bigint) || hookFlagsForPlan(plan),
  )
  const predictedHook = predictHookAddress(
    platform.hookFactory,
    initHash as Hex,
    packageSalt as Hex,
    mineNonce,
  )
  return { hookPkg, mineNonce, hookArgs, predictedHook, scales }
}

export function buildHookDeployArgs(
  plan: CreatePlan,
  predictedDetf: Address,
  platform: SePlatform,
  mineNonce: bigint,
  scales: HookDecimalScales,
): { abi: readonly unknown[]; args: readonly unknown[] } {
  if (!platform.poolManager || !platform.feeOracle) {
    throw new Error('Missing pool manager or fee oracle.')
  }
  if (plan.typeId === 'one-vault') {
    return {
      abi: CP_HOOK_DEPLOY_ABI,
      args: [
        buildCpHookArgs({
          predictedDetf,
        ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
          pairToken: requireAddr(plan.pairToken, 'Pair token'),
          standardExchange: requireAddr(plan.vaults[0] ?? '', 'Strategy vault'),
          poolManager: platform.poolManager,
          feeOracle: platform.feeOracle,
          pairTokenDecimals: scales.pairTokenDecimals[0] ?? 18,
        }),
        mineNonce,
      ],
    }
  }
  if (plan.typeId === 'weighted') {
    const legs = weightedLegsFromPlan(plan)
    return {
      abi: WEIGHTED_HOOK_DEPLOY_ABI,
      args: [
        buildWeightedHookArgs({
          predictedDetf,
        ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
          pairTokens: legs.pairTokens,
          standardExchanges: legs.standardExchanges,
          detfWeight: legs.detfWeight,
          pairWeights: legs.pairWeights,
          poolManager: platform.poolManager,
          feeOracle: platform.feeOracle,
          pairTokenDecimals: scales.pairTokenDecimals,
          seShareDecimals: scales.seShareDecimals,
        }),
        mineNonce,
      ],
    }
  }
  if (plan.typeId === 'stables') {
    const m = plan.vaults.length
    return {
      abi: QUAD_HOOK_DEPLOY_ABI,
      args: [
        buildQuadHookArgs({
          predictedDetf,
        ownerOnlyLiquidity: plan.ownerOnlyLiquidity,
          pairTokens: plan.pairTokens.slice(0, m).map((a, i) => requireAddr(a, `Pair token ${i + 1}`)),
          standardExchanges: plan.vaults.map((a, i) => requireAddr(a, `Dollar vault ${i + 1}`)),
          poolManager: platform.poolManager,
          feeOracle: platform.feeOracle,
          pairTokenDecimals: scales.pairTokenDecimals,
          seShareDecimals: scales.seShareDecimals,
        }),
        mineNonce,
      ],
    }
  }
  throw new Error('Pick how many strategies to include.')
}
