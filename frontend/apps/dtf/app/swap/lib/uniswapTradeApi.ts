import { CHAIN_ID_ROBINHOOD } from '@indexedex/protocol/addressArtifacts'

import type { Address } from './v4Types'
import { ZERO_ADDRESS } from './v4Types'

const TRADE_API = 'https://trade-api.gateway.uniswap.org/v1'

export type UniswapApiQuote = {
  amountOut: bigint
  to: Address
  data: `0x${string}`
  value: bigint
  source: 'uniswap-api'
}

function apiKey(): string | null {
  const k = process.env.NEXT_PUBLIC_UNISWAP_API_KEY
  if (!k || !k.trim()) return null
  return k.trim()
}

/** Trading API covers Robinhood mainnet (4663), not 46630 / Anvil. */
export function uniswapApiEnabled(chainId: number): boolean {
  return chainId === CHAIN_ID_ROBINHOOD && apiKey() != null
}

function readAmount(value: unknown): bigint | null {
  if (typeof value === 'string' && /^\d+$/.test(value)) return BigInt(value)
  if (typeof value === 'number' && Number.isFinite(value)) return BigInt(Math.trunc(value))
  return null
}

function digAmountOut(body: unknown): bigint | null {
  if (!body || typeof body !== 'object') return null
  const o = body as Record<string, unknown>
  const quote = o.quote && typeof o.quote === 'object' ? (o.quote as Record<string, unknown>) : o
  const output = quote.output && typeof quote.output === 'object' ? (quote.output as Record<string, unknown>) : null
  return (
    readAmount(quote.amountOut) ??
    readAmount(output?.amount) ??
    readAmount(quote.quote) ??
    readAmount(o.amountOut)
  )
}

function digTx(body: unknown): { to: Address; data: `0x${string}`; value: bigint } | null {
  if (!body || typeof body !== 'object') return null
  const o = body as Record<string, unknown>
  const swap = (o.swap ?? o.methodParameters ?? o.tx ?? o) as Record<string, unknown>
  const to = typeof swap.to === 'string' ? (swap.to as Address) : null
  const data = typeof swap.data === 'string' ? (swap.data as `0x${string}`) : typeof swap.calldata === 'string' ? (swap.calldata as `0x${string}`) : null
  if (!to || !data || !data.startsWith('0x')) return null
  const value = readAmount(swap.value) ?? BigInt(0)
  return { to, data, value }
}

/**
 * Uniswap Labs Trading API (classic AMM quote + Universal Router calldata).
 * Used on 4663 so vanilla search matches app.uniswap.org. Hooked IndexedEx
 * pools are still quoted locally and preferred when they win.
 */
export async function quoteAndSwapUniswapApi(args: {
  chainId: number
  tokenIn: Address
  tokenOut: Address
  amountIn: bigint
  swapper: Address
  slippageBps: number
}): Promise<UniswapApiQuote | null> {
  if (!uniswapApiEnabled(args.chainId)) return null
  const key = apiKey()
  if (!key) return null

  const tokenIn = args.tokenIn.toLowerCase() === ZERO_ADDRESS ? ZERO_ADDRESS : args.tokenIn
  const tokenOut = args.tokenOut.toLowerCase() === ZERO_ADDRESS ? ZERO_ADDRESS : args.tokenOut
  const body = {
    type: 'EXACT_INPUT',
    amount: args.amountIn.toString(),
    tokenInChainId: args.chainId,
    tokenOutChainId: args.chainId,
    tokenIn,
    tokenOut,
    swapper: args.swapper,
    slippageTolerance: args.slippageBps,
    hooksOptions: 'V4_HOOKS_INCLUSIVE',
    routingPreference: 'BEST_PRICE',
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    'x-api-key': key,
    'x-universal-router-version': '2.1.1',
  }

  try {
    const quoteRes = await fetch(`${TRADE_API}/quote`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    })
    if (!quoteRes.ok) return null
    const quoteJson: unknown = await quoteRes.json()
    const amountOut = digAmountOut(quoteJson)
    if (amountOut == null || amountOut <= BigInt(0)) return null

    const swapRes = await fetch(`${TRADE_API}/swap`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ ...body, quote: quoteJson }),
    })
    if (!swapRes.ok) return null
    const swapJson: unknown = await swapRes.json()
    const tx = digTx(swapJson) ?? digTx(quoteJson)
    if (!tx) return null
    return { amountOut, to: tx.to, data: tx.data, value: tx.value, source: 'uniswap-api' }
  } catch {
    return null
  }
}
