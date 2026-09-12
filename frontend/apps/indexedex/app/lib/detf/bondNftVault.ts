import { zeroAddress, type Address, type PublicClient } from 'viem'

export const BOND_NFT_VAULT_GETTER_ABI = [
  { type: 'function', name: 'bondNftVault', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'protocolNFTVault', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
] as const

/** Funded bonds have fixed nine-decimal principal and pay principal/rewards in sDETF. */
export const BOND_NFT_POSITION_ABI = [
  { type: 'function', name: 'positionOf', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'tuple', components: [
      { name: 'principal', type: 'uint256' },
      { name: 'claimedPrincipal', type: 'uint256' },
      { name: 'stakingGons', type: 'uint256' },
      { name: 'startTimestamp', type: 'uint256' },
      { name: 'vestingDuration', type: 'uint256' },
    ] }],
  },
  { type: 'function', name: 'previewClaim', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'tuple', components: [
      { name: 'vestedPrincipal', type: 'uint256' },
      { name: 'principalRemaining', type: 'uint256' },
      { name: 'principalDue', type: 'uint256' },
      { name: 'rewardsDue', type: 'uint256' },
    ] }],
  },
  { type: 'function', name: 'claimPrincipal', stateMutability: 'nonpayable', inputs: [{ name: 'tokenId', type: 'uint256' }, { name: 'recipient', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'claimRewards', stateMutability: 'nonpayable', inputs: [{ name: 'tokenId', type: 'uint256' }, { name: 'recipient', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'claimBond', stateMutability: 'nonpayable', inputs: [{ name: 'tokenId', type: 'uint256' }, { name: 'recipient', type: 'address' }], outputs: [{ name: 'principal', type: 'uint256' }, { name: 'rewards', type: 'uint256' }] },
  { type: 'function', name: 'ownerOf', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'getApproved', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'isApprovedForAll', stateMutability: 'view', inputs: [{ name: 'owner', type: 'address' }, { name: 'operator', type: 'address' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'tokenURI', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ type: 'string' }] },
] as const

export type BondNftPosition = {
  principal: bigint
  claimedPrincipal: bigint
  stakingGons: bigint
  startTimestamp: bigint
  vestingDuration: bigint
}

export type BondNftClaim = {
  vestedPrincipal: bigint
  principalRemaining: bigint
  principalDue: bigint
  rewardsDue: bigint
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

/** Reserved ids: 0 protocol, 1 feeTo, 2 creator. Purchased bonds start at 3. */
export const DETF_PROTOCOL_BOND_NFT_ID = 0n
export const DETF_FEE_TO_BOND_NFT_ID = 1n
export const DETF_CREATOR_BOND_NFT_ID = 2n

export function asBondPosition(raw: unknown): BondNftPosition | null {
  if (!raw || typeof raw !== 'object') return null
  const value = raw as BondNftPosition
  if (![value.principal, value.claimedPrincipal, value.stakingGons, value.startTimestamp, value.vestingDuration]
    .every((field) => typeof field === 'bigint' && field >= 0n)) return null
  if (value.claimedPrincipal > value.principal) return null
  return value
}

export function asBondClaim(raw: unknown): BondNftClaim | null {
  if (!raw || typeof raw !== 'object') return null
  const value = raw as BondNftClaim
  if (![value.vestedPrincipal, value.principalRemaining, value.principalDue, value.rewardsDue]
    .every((field) => typeof field === 'bigint' && field >= 0n)) return null
  if (value.principalDue > value.principalRemaining) return null
  return value
}

/** Uses the funded position ABI only. A legacy LP position is never relabeled as funded principal. */
export async function readBondPosition(client: ReadClient, nftVault: Address, tokenId: bigint): Promise<BondNftPosition | null> {
  try {
    return asBondPosition(await client.readContract({ address: nftVault, abi: BOND_NFT_POSITION_ABI, functionName: 'positionOf', args: [tokenId] }))
  } catch (error) {
    if (isFunctionNotFound(error)) return null
    throw error
  }
}

/** A successful previewClaim identifies funded-bond support independently of the old positionOf selector. */
export async function readBondClaim(client: ReadClient, nftVault: Address, tokenId: bigint): Promise<BondNftClaim | null> {
  try {
    return asBondClaim(await client.readContract({ address: nftVault, abi: BOND_NFT_POSITION_ABI, functionName: 'previewClaim', args: [tokenId] }))
  } catch (error) {
    if (isFunctionNotFound(error)) return null
    throw error
  }
}

/** The old bond purchase selector is reused; verify funded semantics before allowing a payment. */
export async function requireFundedBondSupport(client: ReadClient, detf: Address): Promise<Address> {
  const vault = await readBondNftVault(client, detf)
  if (!vault || !await readBondClaim(client, vault, DETF_PROTOCOL_BOND_NFT_ID)) {
    throw new Error('This DETF does not expose funded staking bonds.')
  }
  return vault
}
