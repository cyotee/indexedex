import { encodeAbiParameters, keccak256, parseAbiParameters, type Address } from 'viem'

import { errorText } from './sePool'

/** Rehearsal Morpho enables this LLTV (80%). */
export const MORPHO_LLTV_80 = 800000000000000000n

export const MORPHO_LLTV_OPTIONS: readonly { label: string; wad: bigint }[] = [
  { label: '80%', wad: MORPHO_LLTV_80 },
]

export type MorphoMarketParams = {
  loanToken: Address
  collateralToken: Address
  oracle: Address
  irm: Address
  lltv: bigint
}

export function morphoMarketId(params: MorphoMarketParams): `0x${string}` {
  return keccak256(
    encodeAbiParameters(parseAbiParameters('address, address, address, address, uint256'), [
      params.loanToken,
      params.collateralToken,
      params.oracle,
      params.irm,
      params.lltv,
    ]),
  )
}

export function morphoMarketExists(lastUpdate: bigint | undefined | null): boolean {
  return typeof lastUpdate === 'bigint' && lastUpdate > 0n
}

export function marketStatusCopy(exists: boolean): string {
  return exists ? 'found' : 'not found'
}

export function isMorphoMarketAlreadyCreatedError(err: unknown): boolean {
  let current: unknown = err
  for (let i = 0; i < 8 && current != null; i++) {
    const text = errorText(current)
    if (/market already created/i.test(text)) return true
    if (typeof current === 'object') {
      current = (current as Record<string, unknown>).cause
      continue
    }
    break
  }
  return false
}

/** Wallet often reports a low-level createMarket revert as insufficient gas. */
export function isMorphoCreateWalletRevert(err: unknown): boolean {
  if (isMorphoMarketAlreadyCreatedError(err)) return true
  const text = errorText(err)
  return (
    /insufficient gas|intrinsic gas|gas too low|out of gas|execution reverted|returned no data|Internal JSON-RPC/i.test(
      text,
    ) && !/insufficient funds/i.test(text)
  )
}

export function lastUpdateFromMarket(raw: unknown): bigint | null {
  if (raw == null) return null
  if (typeof raw === 'bigint') return raw
  if (Array.isArray(raw) && raw.length >= 5) {
    try {
      return BigInt(raw[4] as bigint)
    } catch {
      return null
    }
  }
  if (typeof raw === 'object' && 'lastUpdate' in (raw as object)) {
    try {
      return BigInt((raw as { lastUpdate: bigint }).lastUpdate)
    } catch {
      return null
    }
  }
  return null
}

