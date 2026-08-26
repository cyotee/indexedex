import { isZero } from './tokenLabels'

/** Parse the Bond token ID field. Empty or non-integer values are ignored. */
export function parseBondTokenId(raw: string): bigint | undefined {
  const trimmed = raw.trim()
  if (!trimmed) return undefined
  try {
    const id = BigInt(trimmed)
    if (id < 0n) return undefined
    return id
  } catch {
    return undefined
  }
}

export function addressesMatch(a?: string | null, b?: string | null): boolean {
  if (!a || !b) return false
  return a.toLowerCase() === b.toLowerCase()
}

/** Uni V4 unused ids return the zero address instead of reverting. */
export function bondOwnerAddress(owner?: string | null): `0x${string}` | undefined {
  if (!owner || isZero(owner)) return undefined
  return owner as `0x${string}`
}

/**
 * Same chain gate as mint / bond / burn on this panel.
 * Anvil / localhost wallets may stay on 31337 / 1337 while the app is on the lab chain.
 */
export function walletCanSignOnChain(input: {
  isConnected: boolean
  walletChainId?: number
  appChainId: number
  localWallet: boolean
}): boolean {
  if (!input.isConnected) return false
  if (input.localWallet) return true
  return input.walletChainId === input.appChainId
}

/**
 * Claim rewards is allowed while the bond is still locked.
 * Maturity only gates sell / redeem. Pending = 0 still lets the owner claim (returns 0).
 * Known non-owners stay enabled so a bad ownerOf read cannot hide the button; the contract reverts.
 */
export function claimRewardsButtonEnabled(input: {
  canSign: boolean
  tokenId?: bigint
  matured?: boolean
  pendingRewards?: bigint
  owner?: string | null
  wallet?: string | null
}): boolean {
  void input.matured
  void input.pendingRewards
  void input.owner
  void input.wallet
  return input.canSign && input.tokenId !== undefined
}

export function claimRewardsBlockedReason(input: {
  isConnected: boolean
  walletMatches: boolean
  appChainId: number
  tokenId?: bigint
}): string | null {
  if (!input.isConnected) return 'Connect a wallet to sign.'
  if (!input.walletMatches) return `Switch the wallet to chain ${input.appChainId}.`
  if (input.tokenId === undefined) return 'Enter a bond token ID.'
  return null
}

export function bondUnlockState(
  unlockTime: bigint | undefined,
  nowSec: number,
): { locked: boolean | null } {
  if (unlockTime == null || unlockTime === 0n) return { locked: null }
  const sec = Number(unlockTime)
  if (!Number.isFinite(sec)) return { locked: null }
  return { locked: nowSec < sec }
}

const DEFAULT_BOND_ID_SCAN = 32

/** How many consecutive token IDs to probe with ownerOf, starting at 1. */
export function bondIdScanCount(nextTokenId?: bigint): number {
  if (nextTokenId == null || nextTokenId <= 1n) return DEFAULT_BOND_ID_SCAN
  const minted = Number(nextTokenId - 1n)
  if (!Number.isFinite(minted) || minted <= 0) return DEFAULT_BOND_ID_SCAN
  return Math.min(Math.max(minted, 1), 64)
}

/** Map ownerOf multicall rows (id 1 at index 0) to IDs owned by `wallet`. */
export function ownedBondIdsFromOwnerReads(
  reads: unknown,
  wallet?: string | null,
  firstId = 1n,
): bigint[] {
  if (!Array.isArray(reads) || !wallet) return []
  const out: bigint[] = []
  for (let i = 0; i < reads.length; i++) {
    const row = reads[i] as { result?: unknown } | undefined
    const owner = typeof row?.result === 'string' ? row.result : undefined
    if (!bondOwnerAddress(owner)) continue
    if (!addressesMatch(owner, wallet)) continue
    out.push(firstId + BigInt(i))
  }
  return out
}
