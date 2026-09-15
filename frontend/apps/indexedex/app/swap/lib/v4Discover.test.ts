import { expect, it } from 'vitest'
import { toHex, type Address, type Hex } from 'viem'
import { readSePoolKey } from './v4Discover'

it('reads Solidity PoolKey packing: fee and tick share currency1 slot, hooks use next slot', async () => {
  const token: Address = '0x0000000000000000000000000000000000000020'
  const hook: Address = '0x0000000000000000000000000000000000000030'
  const words: Hex[] = [toHex(0n, { size: 32 }), toHex(BigInt(token) | (3000n << 160n) | (60n << 184n), { size: 32 }), toHex(BigInt(hook), { size: 32 })]
  let index = 0
  const reader = { getStorageAt: async () => words[index++] }
  expect(await readSePoolKey(reader, token)).toEqual({ currency0: '0x0000000000000000000000000000000000000000', currency1: token, fee: 3000, tickSpacing: 60, hooks: hook })
})
