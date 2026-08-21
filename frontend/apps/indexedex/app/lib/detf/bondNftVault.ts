import { zeroAddress, type Address, type PublicClient } from 'viem'

export const BOND_NFT_VAULT_GETTER_ABI = [
  { type: 'function', name: 'bondNftVault', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'protocolNFTVault', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
] as const

export const BOND_NFT_POSITION_ABI = [
  {
    type: 'function',
    name: 'getPosition',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      {
        name: 'position',
        type: 'tuple',
        components: [
          { name: 'originalShares', type: 'uint256' },
          { name: 'effectiveShares', type: 'uint256' },
          { name: 'bonusMultiplier', type: 'uint256' },
          { name: 'unlockTime', type: 'uint256' },
          { name: 'rewardDebt', type: 'uint256' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'positionOf',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      {
        name: 'position',
        type: 'tuple',
        components: [
          { name: 'originalShares', type: 'uint256' },
          { name: 'effectiveShares', type: 'uint256' },
          { name: 'bonusMultiplier', type: 'uint256' },
          { name: 'unlockTime', type: 'uint256' },
          { name: 'rewardDebt', type: 'uint256' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'detfNFTId',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'protocolNFTId',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const

export type BondNftPosition = {
  originalShares: bigint
  effectiveShares: bigint
  bonusMultiplier: bigint
  unlockTime: bigint
  rewardDebt: bigint
}

type ReadClient = Pick<PublicClient, 'readContract'>

function asText(value: unknown): string {
  if (typeof value === 'string') return value
  if (value == null) return ''
  try {
    return String(value)
  } catch {
    return ''
  }
}

/** Diamond FunctionNotFound / missing selector (`0x23dbef4b`). */
export function isFunctionNotFound(error: unknown): boolean {
  const cause = error && typeof error === 'object' ? (error as { cause?: unknown }).cause : undefined
  const parts = [
    asText((error as { message?: unknown })?.message),
    asText((error as { shortMessage?: unknown })?.shortMessage),
    asText((error as { data?: unknown })?.data),
    asText((cause as { data?: unknown })?.data),
    asText(error),
  ]
  return parts.some(
    (part) =>
      part.includes('0x23dbef4b') || /FunctionNotFound/i.test(part) || /NoTargetFor\(bytes4\)/.test(part),
  )
}

async function readFirstAddress(
  client: ReadClient,
  address: Address,
  names: ReadonlyArray<'bondNftVault' | 'protocolNFTVault'>,
): Promise<Address | null> {
  for (const functionName of names) {
    try {
      const value = (await client.readContract({
        address,
        abi: BOND_NFT_VAULT_GETTER_ABI,
        functionName,
        args: [],
      })) as Address
      if (value && value !== zeroAddress) return value
    } catch (error) {
      if (isFunctionNotFound(error)) continue
      throw error
    }
  }
  return null
}

/** Uni V4 DETFs expose `bondNftVault()`. Protocol DETFs expose `protocolNFTVault()`. */
export async function readBondNftVault(client: ReadClient, detf: Address): Promise<Address | null> {
  return readFirstAddress(client, detf, ['bondNftVault', 'protocolNFTVault'])
}

async function readFirstUint(
  client: ReadClient,
  address: Address,
  names: ReadonlyArray<'detfNFTId' | 'protocolNFTId'>,
): Promise<bigint | null> {
  for (const functionName of names) {
    try {
      return (await client.readContract({
        address,
        abi: BOND_NFT_POSITION_ABI,
        functionName,
        args: [],
      })) as bigint
    } catch (error) {
      if (isFunctionNotFound(error)) continue
      throw error
    }
  }
  return null
}

export async function readDetfNftId(client: ReadClient, nftVault: Address): Promise<bigint | null> {
  try {
    return await readFirstUint(client, nftVault, ['detfNFTId', 'protocolNFTId'])
  } catch {
    return null
  }
}

function asPosition(raw: unknown): BondNftPosition | null {
  if (!raw || typeof raw !== 'object') return null
  const row = raw as Partial<BondNftPosition>
  if (typeof row.originalShares !== 'bigint') return null
  return {
    originalShares: row.originalShares,
    effectiveShares: typeof row.effectiveShares === 'bigint' ? row.effectiveShares : 0n,
    bonusMultiplier: typeof row.bonusMultiplier === 'bigint' ? row.bonusMultiplier : 0n,
    unlockTime: typeof row.unlockTime === 'bigint' ? row.unlockTime : 0n,
    rewardDebt: typeof row.rewardDebt === 'bigint' ? row.rewardDebt : 0n,
  }
}

/** Reserved ids: 0 protocol, 1 feeTo, 2 creator. User bonds start at 3. */
export const DETF_PROTOCOL_BOND_NFT_ID = 0n
export const DETF_FEE_TO_BOND_NFT_ID = 1n
export const DETF_CREATOR_BOND_NFT_ID = 2n

export async function readBondPosition(
  client: ReadClient,
  nftVault: Address,
  tokenId: bigint,
): Promise<BondNftPosition | null> {
  for (const functionName of ['getPosition', 'positionOf'] as const) {
    try {
      const raw = await client.readContract({
        address: nftVault,
        abi: BOND_NFT_POSITION_ABI,
        functionName,
        args: [tokenId],
      })
      const position = asPosition(raw)
      if (position) return position
    } catch (error) {
      if (isFunctionNotFound(error)) continue
      throw error
    }
  }
  return null
}
