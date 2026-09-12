import { toFunctionSelector } from 'viem'

/** Both live bond entrypoints retain their family's payment and bootstrap semantics. */
export const FUNDED_BOND_ABI = [
  {
    type: 'function', name: 'bond', stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' }, { name: 'amountIn', type: 'uint256' },
      { name: 'duration', type: 'uint256' }, { name: 'recipient', type: 'address' },
      { name: 'prepaid', type: 'bool' }, { name: 'deadline', type: 'uint256' },
    ],
    outputs: [{ name: 'tokenId', type: 'uint256' }, { name: 'protocolLpAdded', type: 'uint256' }],
  },
  {
    type: 'function', name: 'bond', stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' }, { name: 'amountIn', type: 'uint256' },
      { name: 'duration', type: 'uint256' }, { name: 'recipient', type: 'address' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [{ name: 'tokenId', type: 'uint256' }, { name: 'principal', type: 'uint256' }],
  },
] as const

export const FUNDED_BOND_SELECTORS = FUNDED_BOND_ABI.map((item) => toFunctionSelector(item))

/** Read the installed selectors before approvals or wrapping; never retry a failed purchase on another route. */
export async function resolveBondRoute(readFacet: (selector: `0x${string}`) => Promise<unknown>) {
  const facets = await Promise.all(FUNDED_BOND_SELECTORS.map(readFacet))
  const installed = facets.map((facet) => typeof facet === 'string' && /^0x[0-9a-fA-F]{40}$/.test(facet) && !/^0x0{40}$/.test(facet))
  if (installed[0]) return 'withPrepaid' as const
  if (installed[1]) return 'composed' as const
  throw new Error('This DETF does not expose a supported bond purchase route.')
}

export function fundedBondArgs(route: Awaited<ReturnType<typeof resolveBondRoute>>, input: {
  token: `0x${string}`; amount: bigint; duration: bigint; recipient: `0x${string}`; deadline: bigint
}) {
  const prefix = [input.token, input.amount, input.duration, input.recipient] as const
  return route === 'withPrepaid' ? [...prefix, false, input.deadline] as const : [...prefix, input.deadline] as const
}


/** Funded V4 purchase quote; LP payments exclude the reserve's direct DETF inventory. */
export const V4_BOND_PREVIEW_ABI = [{
  type: 'function', name: 'previewBond', stateMutability: 'view',
  inputs: [
    { name: 'tokenIn', type: 'address' }, { name: 'amountIn', type: 'uint256' },
    { name: 'lockDuration', type: 'uint256' },
  ],
  outputs: [
    { name: 'purchasedDetf', type: 'uint256' }, { name: 'principalDetf', type: 'uint256' },
    { name: 'rewardsDetf', type: 'uint256' }, { name: 'liquidityDetf', type: 'uint256' },
  ],
}] as const
