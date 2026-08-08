/**
 * Parse Swap launch query defaults from URL search params.
 * Used by Token → Swap handoff (?launch=1&tokenOut=0x…).
 */
export type LaunchQueryInput = {
  launch?: string | null
  tokenOut?: string | null
  tokenIn?: string | null
}

export type LaunchQueryResult = {
  isLaunchMode: boolean
  tokenOut: `0x${string}` | null
  tokenIn: `0x${string}` | null
}

function parseAddress(raw: string | null | undefined): `0x${string}` | null {
  if (!raw) return null
  const v = raw.trim()
  if (!/^0x[0-9a-fA-F]{40}$/.test(v)) return null
  if (v.toLowerCase() === '0x0000000000000000000000000000000000000000') return null
  return v as `0x${string}`
}

export function parseLaunchQuery(input: LaunchQueryInput): LaunchQueryResult {
  const isLaunchMode =
    input.launch === '1' ||
    input.launch === 'true' ||
    Boolean(input.tokenOut && parseAddress(input.tokenOut))

  return {
    isLaunchMode,
    tokenOut: parseAddress(input.tokenOut ?? null),
    tokenIn: parseAddress(input.tokenIn ?? null),
  }
}
