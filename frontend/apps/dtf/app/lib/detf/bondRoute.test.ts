import { describe, expect, it, vi } from 'vitest'
import { decodeFunctionData, encodeFunctionData, zeroAddress } from 'viem'
import { FUNDED_BOND_ABI, FUNDED_BOND_SELECTORS, fundedBondArgs, resolveBondRoute } from './bondRoute'

const token = '0x1111111111111111111111111111111111111111' as const
const recipient = '0x2222222222222222222222222222222222222222' as const
const input = { token, recipient, amount: 12_345_678n, duration: 86400n, deadline: 172800n }

describe('funded bond route discovery', () => {
  it.each(['withPrepaid', 'composed'] as const)('encodes %s from its installed selector, preserving units and disabling prepaid credit', async (route) => {
    const selector = FUNDED_BOND_SELECTORS[route === 'withPrepaid' ? 0 : 1]
    const read = vi.fn(async (value: `0x${string}`) => value === selector ? token : zeroAddress)
    expect(await resolveBondRoute(read)).toBe(route)
    const args = fundedBondArgs(route, input)
    const data = encodeFunctionData({ abi: FUNDED_BOND_ABI, functionName: 'bond', args })
    expect(data.slice(0, 10)).toBe(selector)
    const decoded = decodeFunctionData({ abi: FUNDED_BOND_ABI, data })
    expect(decoded.args).toEqual(route === 'withPrepaid'
      ? [token, input.amount, input.duration, recipient, false, input.deadline]
      : [token, input.amount, input.duration, recipient, input.deadline])
    expect(read).toHaveBeenCalledTimes(2)
  })

  it('rejects missing selectors instead of guessing a purchase signature', async () => {
    await expect(resolveBondRoute(async () => zeroAddress)).rejects.toThrow('supported bond purchase route')
  })

  it('propagates read failures before a purchase can be assembled', async () => {
    await expect(resolveBondRoute(async () => { throw new Error('RPC unavailable') })).rejects.toThrow('RPC unavailable')
  })
})
