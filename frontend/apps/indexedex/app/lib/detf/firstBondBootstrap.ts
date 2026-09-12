import { toFunctionSelector, type Address, type PublicClient } from 'viem'
import { isNonZeroAddress } from '../../create/lib/bondTokens'

const purchased = [{ name: 'tokenId', type: 'uint256' }, { name: 'principal', type: 'uint256' }] as const
const liquidity = [{ name: 'tokenId', type: 'uint256' }, { name: 'protocolLpAdded', type: 'uint256' }] as const
const tail = [{ name: 'duration', type: 'uint256' }, { name: 'recipient', type: 'address' }, { name: 'deadline', type: 'uint256' }] as const

export const FUNDED_BOOTSTRAP_ABI = [
  { type: 'function', name: 'initializeReserve', stateMutability: 'nonpayable',
    inputs: [{ name: 'amounts', type: 'uint256[]' }, ...tail], outputs: liquidity },
  { type: 'function', name: 'bootstrapFirstBond', stateMutability: 'nonpayable',
    inputs: [{ name: 'buffer', type: 'uint256' }, { name: 'amounts', type: 'uint256[]' }, ...tail],
    outputs: [...liquidity, { name: 'principal', type: 'uint256' }] },
  { type: 'function', name: 'initializeReserve', stateMutability: 'nonpayable',
    inputs: [{ name: 'stableBpt', type: 'uint256' }, { name: 'commonBpt', type: 'uint256' }, ...tail], outputs: purchased },
  { type: 'function', name: 'vaultShares', stateMutability: 'view', inputs: [], outputs: [{ type: 'address[]' }] },
  { type: 'function', name: 'bufferToken', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'acceptedBondTokens', stateMutability: 'view', inputs: [], outputs: [{ type: 'address[]' }] },
] as const

export const FUNDED_BOOTSTRAP_SELECTORS = {
  multi: toFunctionSelector(FUNDED_BOOTSTRAP_ABI[0]),
  mixed: toFunctionSelector(FUNDED_BOOTSTRAP_ABI[1]),
  composed: toFunctionSelector(FUNDED_BOOTSTRAP_ABI[2]),
} as const
export type BootstrapKind = keyof typeof FUNDED_BOOTSTRAP_SELECTORS

export async function resolveBootstrapRoute(readFacet: (selector: `0x${string}`) => Promise<unknown>): Promise<BootstrapKind | null> {
  const kinds = Object.keys(FUNDED_BOOTSTRAP_SELECTORS) as BootstrapKind[]
  const facets = await Promise.all(kinds.map((kind) => readFacet(FUNDED_BOOTSTRAP_SELECTORS[kind])))
  const installed = kinds.filter((_, index) => isNonZeroAddress(facets[index]))
  if (installed.length > 1) throw new Error('The DETF exposes conflicting first-bond routes.')
  return installed[0] ?? null
}

/** Preserve the contract's argument order, independent of token address sorting or display labels. */
export async function readBootstrapTokens(client: Pick<PublicClient, 'readContract'>, address: Address, kind: BootstrapKind): Promise<Address[]> {
  let tokens: readonly Address[]
  if (kind === 'composed') {
    // Composed acceptedBondTokens starts with stable BPT, then common BPT, then routed payments.
    const accepted = await client.readContract({ address, abi: FUNDED_BOOTSTRAP_ABI, functionName: 'acceptedBondTokens' })
    tokens = accepted.slice(0, 2)
    if (tokens.length !== 2) throw new Error('The DETF did not return both first-bond pool tokens.')
  } else {
    const shares = await client.readContract({ address, abi: FUNDED_BOOTSTRAP_ABI, functionName: 'vaultShares' })
    if (shares.length < 1 || shares.length > 7) throw new Error('The DETF did not return its configured first-bond vault shares.')
    tokens = kind === 'mixed'
      ? [await client.readContract({ address, abi: FUNDED_BOOTSTRAP_ABI, functionName: 'bufferToken' }), ...shares]
      : shares
  }
  if (tokens.some((token) => !isNonZeroAddress(token)) || new Set(tokens.map((token) => token.toLowerCase())).size !== tokens.length) {
    throw new Error('The DETF returned invalid first-bond payment tokens.')
  }
  return [...tokens]
}

export function fundedBootstrapRequest(kind: BootstrapKind, amounts: readonly bigint[], duration: bigint, recipient: Address, deadline: bigint) {
  if (!amounts.length || amounts.some((amount) => amount <= 0n) || (kind === 'composed' && amounts.length !== 2) || (kind === 'mixed' && amounts.length < 2)) {
    throw new Error('Enter a positive amount for every first-bond payment.')
  }
  if (kind === 'multi') return { abi: FUNDED_BOOTSTRAP_ABI, functionName: 'initializeReserve', args: [amounts, duration, recipient, deadline] } as const
  if (kind === 'mixed') return { abi: FUNDED_BOOTSTRAP_ABI, functionName: 'bootstrapFirstBond', args: [amounts[0], amounts.slice(1), duration, recipient, deadline] } as const
  return { abi: FUNDED_BOOTSTRAP_ABI, functionName: 'initializeReserve', args: [amounts[0], amounts[1], duration, recipient, deadline] } as const
}


export const V4_FIRST_BOND_PAYMENTS_ABI = [{
  type: 'function', name: 'previewFirstBondPayments', stateMutability: 'view',
  inputs: [{ name: 'tokenIn', type: 'address' }, { name: 'amountIn', type: 'uint256' }],
  outputs: [{ name: 'tokens', type: 'address[]' }, { name: 'amounts', type: 'uint256[]' }],
}] as const
export const V4_FIRST_BOND_PAYMENTS_SELECTOR = toFunctionSelector(V4_FIRST_BOND_PAYMENTS_ABI[0])

export function asFirstBondPayments(raw: unknown, lead: Address, amount: bigint): { address: Address; amount: bigint }[] | null {
  if (!Array.isArray(raw) || raw.length !== 2 || !Array.isArray(raw[0]) || !Array.isArray(raw[1])) return null
  const [tokens, amounts] = raw
  if (!tokens.length || tokens.length !== amounts.length || tokens.some((token) => !isNonZeroAddress(token)) ||
      amounts.some((value) => typeof value !== 'bigint' || value <= 0n)) return null
  if (new Set(tokens.map((token: string) => token.toLowerCase())).size !== tokens.length) return null
  const index = tokens.findIndex((token: string) => token.toLowerCase() === lead.toLowerCase())
  if (index < 0 || amounts[index] !== amount) return null
  return tokens.map((address: Address, index: number) => ({ address, amount: amounts[index] as bigint }))
}

export async function readFirstBondPayments(client: Pick<PublicClient, 'readContract'>, address: Address, lead: Address, amount: bigint) {
  const raw = await client.readContract({ address, abi: V4_FIRST_BOND_PAYMENTS_ABI, functionName: 'previewFirstBondPayments', args: [lead, amount] })
  const payments = asFirstBondPayments(raw, lead, amount)
  if (!payments) throw new Error('The DETF did not return valid first-bond payment amounts.')
  return payments
}


export const COMPOSED_OPENING_ABI = [{
  type: 'function', name: 'openingConfiguration', stateMutability: 'view', inputs: [],
  outputs: [{ name: 'prices', type: 'uint256[2]' }, { name: 'seedAmounts', type: 'uint256[3]' }],
}] as const
export type ComposedOpening = { prices: readonly [bigint, bigint]; seedAmounts: readonly [bigint, bigint, bigint] }

export async function readComposedOpening(client: Pick<PublicClient, 'readContract'>, address: Address): Promise<ComposedOpening> {
  const [prices, seedAmounts] = await client.readContract({ address, abi: COMPOSED_OPENING_ABI, functionName: 'openingConfiguration' })
  if (prices.length !== 2 || seedAmounts.length !== 3 || [...prices, ...seedAmounts].some((value) => typeof value !== 'bigint' || value <= 0n)) {
    throw new Error('The DETF returned invalid opening prices or reserve proportions.')
  }
  return { prices, seedAmounts }
}

/** Match the contract's native-unit proportional seed calculation, including its floor. */
export function composedFirstBondAmounts(stableIn: bigint, opening: ComposedOpening): readonly [bigint, bigint] {
  if (stableIn <= 0n || opening.seedAmounts.some((value) => value <= 0n)) throw new Error('Enter a positive first-bond payment.')
  const commonIn = stableIn * opening.seedAmounts[2] / opening.seedAmounts[1]
  if (commonIn === 0n) throw new Error('The payment is too small to fund both reserve assets.')
  return [stableIn, commonIn]
}
