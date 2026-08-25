/** Sentinel for “pay native ETH, wrap to WETH, then spend WETH”. */
export const ETH_PAY = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' as const

export const WETH9_DEPOSIT_ABI = [
  {
    type: 'function',
    name: 'deposit',
    stateMutability: 'payable',
    inputs: [],
    outputs: [],
  },
] as const

export function isEthPay(value: unknown): boolean {
  return typeof value === 'string' && value.toLowerCase() === ETH_PAY.toLowerCase()
}

export function sameHex(a: unknown, b: unknown): boolean {
  return typeof a === 'string' && typeof b === 'string' && a.toLowerCase() === b.toLowerCase()
}

/** If the list already accepts WETH, insert ETH immediately before it. */
export function withEthPayOption<T extends { address: string }>(
  tokens: readonly T[],
  weth: string | null | undefined,
  eth: T,
): T[] {
  if (!weth || !tokens.some((t) => sameHex(t.address, weth))) return [...tokens]
  if (tokens.some((t) => isEthPay(t.address))) return [...tokens]
  const out: T[] = []
  let inserted = false
  for (const t of tokens) {
    if (!inserted && sameHex(t.address, weth)) {
      out.push(eth)
      inserted = true
    }
    out.push(t)
  }
  if (!inserted) out.unshift(eth)
  return out
}

/** Address the contract should see: WETH when the user picked ETH. */
export function settlePayToken(
  selected: string,
  weth: string | null | undefined,
): `0x${string}` | null {
  if (isEthPay(selected)) {
    if (!weth || !/^0x[0-9a-fA-F]{40}$/i.test(weth) || /^0x0{40}$/i.test(weth)) return null
    return weth as `0x${string}`
  }
  if (!/^0x[0-9a-fA-F]{40}$/i.test(selected)) return null
  return selected as `0x${string}`
}
