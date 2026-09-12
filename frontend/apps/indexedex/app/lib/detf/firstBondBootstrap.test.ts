import { describe, expect, it, vi } from 'vitest'
import { decodeFunctionData, encodeFunctionData, zeroAddress, type Address } from 'viem'
import { composedFirstBondAmounts, readComposedOpening, asFirstBondPayments, V4_FIRST_BOND_PAYMENTS_ABI, V4_FIRST_BOND_PAYMENTS_SELECTOR, FUNDED_BOOTSTRAP_ABI, FUNDED_BOOTSTRAP_SELECTORS, fundedBootstrapRequest, readBootstrapTokens, resolveBootstrapRoute, type BootstrapKind } from './firstBondBootstrap'

const detf = '0x9999999999999999999999999999999999999999' as const
const stable = '0x3333333333333333333333333333333333333333' as const
const common = '0x1111111111111111111111111111111111111111' as const
const buffer = '0x5555555555555555555555555555555555555555' as const
const payment = [1_000_001n, 2_000_000_000_000_000_003n, 4_000_000_005n] as const
const duration = 86400n
const deadline = 172800n

describe('first-bond payment routes', () => {
  it.each(['multi', 'mixed', 'composed'] as BootstrapKind[])('discovers %s without using a token count as the family identifier', async (kind) => {
    expect(await resolveBootstrapRoute(async (selector) => selector === FUNDED_BOOTSTRAP_SELECTORS[kind] ? detf : zeroAddress)).toBe(kind)
  })

  it('allows a single-payment family, rejects conflicting selectors, and propagates RPC errors', async () => {
    expect(await resolveBootstrapRoute(async () => zeroAddress)).toBeNull()
    await expect(resolveBootstrapRoute(async () => detf)).rejects.toThrow('conflicting')
    await expect(resolveBootstrapRoute(async () => { throw new Error('RPC unavailable') })).rejects.toThrow('RPC unavailable')
  })

  it.each(['multi', 'mixed', 'composed'] as BootstrapKind[])('uses %s payment order and native units in the actual calldata', async (kind) => {
    const readContract = vi.fn(async ({ functionName }: { functionName: string }) => {
      if (functionName === 'vaultShares') return kind === 'multi' ? [stable, common, buffer] : [stable, common]
      if (functionName === 'bufferToken') return buffer
      return [stable, common, buffer]
    })
    const tokens = await readBootstrapTokens({ readContract } as never, detf, kind)
    expect(tokens).toEqual(kind === 'mixed' ? [buffer, stable, common] : kind === 'multi' ? [stable, common, buffer] : [stable, common])
    const amounts = payment.slice(0, tokens.length)
    const request = fundedBootstrapRequest(kind, amounts, duration, detf, deadline)
    const data = encodeFunctionData(request)
    expect(data.slice(0, 10)).toBe(FUNDED_BOOTSTRAP_SELECTORS[kind])
    const decoded = decodeFunctionData({ abi: FUNDED_BOOTSTRAP_ABI, data })
    expect(decoded.args).toEqual(kind === 'multi'
      ? [amounts, duration, detf, deadline]
      : kind === 'mixed'
        ? [amounts[0], amounts.slice(1), duration, detf, deadline]
        : [amounts[0], amounts[1], duration, detf, deadline])
  })

  it.each([[], [stable, zeroAddress], [stable, stable]] as Address[][])('refuses incomplete or invalid discovered tokens %s', async (tokens) => {
    const readContract = vi.fn(async () => tokens)
    await expect(readBootstrapTokens({ readContract } as never, detf, 'composed')).rejects.toThrow()
  })

  it('refuses missing, zero and negative payments before assembling a transaction', () => {
    for (const amounts of [[], [1n], [1n, 0n], [1n, -1n]]) {
      expect(() => fundedBootstrapRequest('composed', amounts, duration, detf, deadline)).toThrow('positive amount')
    }
  })
})


describe('V4 first-bond payment quotes', () => {
  it('retains every quoted native payment in hook order without sorting around the selected lead', () => {
    expect(asFirstBondPayments([[common, stable, buffer], payment], stable, payment[1]))
      .toEqual([{ address: common, amount: payment[0] }, { address: stable, amount: payment[1] }, { address: buffer, amount: payment[2] }])
  })

  it('refuses an old quote after the selected lead or amount changes', () => {
    expect(asFirstBondPayments([[stable, common], [1n, 2n]], stable, 3n)).toBeNull()
    expect(asFirstBondPayments([[stable, common], [1n, 2n]], buffer, 1n)).toBeNull()
  })

  it('refuses missing amounts, duplicate tokens, nonpositive payments and invalid addresses', () => {
    for (const raw of [null, [[], []], [[stable], []], [[stable, stable], [1n, 1n]], [[stable, common], [1n, 0n]], [[stable, zeroAddress], [1n, 2n]]]) {
      expect(asFirstBondPayments(raw, stable, 1n)).toBeNull()
    }
  })

  it('encodes a payment quote independently of the bond vesting bonus', () => {
    const data = encodeFunctionData({ abi: V4_FIRST_BOND_PAYMENTS_ABI, functionName: 'previewFirstBondPayments', args: [stable, payment[0]] })
    expect(data.slice(0, 10)).toBe(V4_FIRST_BOND_PAYMENTS_SELECTOR)
    expect(decodeFunctionData({ abi: V4_FIRST_BOND_PAYMENTS_ABI, data }).args).toEqual([stable, payment[0]])
  })
})


describe('Composed configured opening', () => {
  const opening = { prices: [20n * 10n ** 18n, 40n * 10n ** 18n], seedAmounts: [100n * 10n ** 9n, 3n * 10n ** 18n, 7n * 10n ** 18n] } as const
  it('reads explicit rich prices and unequal seed proportions from the deployed DETF', async () => {
    const readContract = vi.fn(async () => [opening.prices, opening.seedAmounts])
    expect(await readComposedOpening({ readContract } as never, detf)).toEqual(opening)
    expect(readContract).toHaveBeenCalledWith(expect.objectContaining({ address: detf, functionName: 'openingConfiguration' }))
  })
  it('uses exact native payment ratios, independent of DETF decimals and the vesting bonus', () => {
    const [stableIn, commonIn] = composedFirstBondAmounts(1_000_000_000_000_000_001n, opening)
    expect(stableIn).toBe(1_000_000_000_000_000_001n)
    expect(commonIn).toBe(2_333_333_333_333_333_335n)
    const encoded = encodeFunctionData(fundedBootstrapRequest('composed', [stableIn, commonIn], duration, detf, deadline))
    expect(decodeFunctionData({ abi: FUNDED_BOOTSTRAP_ABI, data: encoded }).args).toEqual([stableIn, commonIn, duration, detf, deadline])
  })
  it('rejects missing or zero launch configuration instead of assuming a 1:1 price', async () => {
    const readContract = vi.fn(async () => [[0n, opening.prices[1]], opening.seedAmounts])
    await expect(readComposedOpening({ readContract } as never, detf)).rejects.toThrow('invalid opening')
    expect(() => composedFirstBondAmounts(0n, opening)).toThrow('positive')
    expect(() => composedFirstBondAmounts(1n, { ...opening, seedAmounts: [1n, 100n, 1n] })).toThrow('too small')
  })
})
