const ZERO = '0x0000000000000000000000000000000000000000'

/** Live $DTF on Robinhood 4663. Pin only. */
export const DTF_TOKEN = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01' as const

function isAddress(value: unknown): value is `0x${string}` {
  if (typeof value !== 'string') return false
  return /^0x[0-9a-fA-F]{40}$/.test(value) && value.toLowerCase() !== ZERO
}

/**
 * Env `NEXT_PUBLIC_TOKEN_STAKING` wins, then `platform.tokenStaking`.
 * Empty / zero addresses are treated as not deployed yet.
 */
export function resolveTokenStakingAddress(
  platform?: Record<string, unknown> | null,
  envValue?: string | null,
): `0x${string}` | undefined {
  if (isAddress(envValue?.trim())) return envValue.trim() as `0x${string}`
  const fromPlatform = platform?.tokenStaking
  if (isAddress(fromPlatform)) return fromPlatform
  return undefined
}
