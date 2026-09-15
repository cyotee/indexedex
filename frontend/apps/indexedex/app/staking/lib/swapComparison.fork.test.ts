import { describe, expect, it } from 'vitest'
import { createPublicClient, encodeFunctionData, http, parseUnits, type Address } from 'viem'
import { loadSwapComparison, quoteComparisonPool, swapDeadline } from './swapComparison'
import { readProtocolDetf } from '../../lib/tokenStaking/migration'
import { encodeUniversalSwap, UNIVERSAL_ROUTER_EXECUTE_ABI } from '../../swap/lib/v4Encode'
import platform from '../../../../../packages/protocol/src/addresses/chain/4663/platform.json'

describe.skipIf(!process.env.E2E_SWAP_RPC)('actual mainnet fork swap comparison', () => {
  it('discovers distinct pools, quotes both directions and simulates complete native buys', async () => {
    const url = new URL(process.env.E2E_SWAP_RPC!)
    expect(['127.0.0.1', 'localhost']).toContain(url.hostname)
    const client = createPublicClient({ transport: http(url.href) })
    expect(await client.getChainId()).toBe(4663)
    const staking = platform.tokenStaking as Address
    const detf = await readProtocolDetf(client, staking)
    if (!detf) throw new Error('Missing deployed DETF')
    const pools = await loadSwapComparison(client, staking, detf, platform)
    expect(pools.base.hooks.toLowerCase()).not.toBe(pools.reserve.hooks.toLowerCase())
    for (const pool of ['base', 'reserve'] as const) {
      for (const direction of ['buy', 'sell'] as const) {
        const amount = direction === 'buy' ? parseUnits('0.000001', 18) : parseUnits('1', pools.decimals)
        const quote = await quoteComparisonPool(client, pools, pool, direction, amount)
        expect(quote.hops).toHaveLength(1)
        expect(quote.amountOut).toBeGreaterThan(0n)
        if (direction === 'buy') {
          const block = await client.getBlock()
          const encoded = encodeUniversalSwap({ route: quote, amountOutMinimum: quote.amountOut * 9950n / 10000n, nativeIn: true, wrappedNative: pools.weth })
          await client.call({ account: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', to: pools.router, value: encoded.value,
            data: encodeFunctionData({ abi: UNIVERSAL_ROUTER_EXECUTE_ABI, functionName: 'execute', args: [encoded.commands, encoded.inputs, swapDeadline(block.timestamp)] }),
          })
        }
      }
    }
    expect(pools.detfDecimals).toBe(9)
    for (const settlement of ['eth', 'dtf'] as const) {
      for (const direction of ['buy', 'sell'] as const) {
        const amount = direction === 'sell' ? parseUnits('0.000001', pools.detfDecimals)
          : settlement === 'eth' ? parseUnits('0.000001', 18) : parseUnits('1', pools.decimals)
        const quote = await quoteComparisonPool(client, pools, 'detf', direction, amount, undefined, settlement)
        expect(quote.hops).toHaveLength(1)
        expect(quote.hops[0].pool.hooks.toLowerCase()).toBe(pools.reserve.hooks.toLowerCase())
        expect(quote.amountOut).toBeGreaterThan(0n)
      }
    }
  }, 120_000)
})
