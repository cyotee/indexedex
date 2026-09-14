import { encodeAbiParameters, encodeEventTopics, erc20Abi, getAddress, type TransactionReceipt } from 'viem'
import { describe, expect, it } from 'vitest'
import { collectStakeTokenAddresses, formatTokenAmount, receivedDetfAmount, insightsStakingHref, stakingExchangeRoute } from './claimMint'

const DETF = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117' as const
const PAIR = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206' as const
const STAKING = '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099' as const
const ZERO = '0x0000000000000000000000000000000000000000' as const

describe('funded staking routes', () => {
  it('stakes raw DETF through the staking token with its actual allowance spender', () => {
    expect(stakingExchangeRoute({ detf: DETF, stakingToken: STAKING, tokenIn: DETF, unstake: false })).toEqual({
      target: STAKING, tokenIn: DETF, tokenOut: STAKING, needsAllowance: true, requiresLiveReserve: false,
    })
  })
  it('acquires wallet-held DETF for payment tokens before a separate direct stake', () => {
    expect(stakingExchangeRoute({ detf: DETF, stakingToken: STAKING, tokenIn: PAIR, unstake: false })).toEqual({
      target: DETF, tokenIn: PAIR, tokenOut: DETF, needsAllowance: true, requiresLiveReserve: true,
    })
  })
  it('unstakes directly without reserve gating or approval of the DETF', () => {
    expect(stakingExchangeRoute({ detf: DETF, stakingToken: STAKING, unstake: true })).toEqual({
      target: STAKING, tokenIn: STAKING, tokenOut: DETF, needsAllowance: false, requiresLiveReserve: false,
    })
  })
  it('waits for required addresses', () => {
    expect(stakingExchangeRoute({ detf: DETF, unstake: true })).toBeUndefined()
    expect(stakingExchangeRoute({ detf: DETF, stakingToken: STAKING, unstake: false })).toBeUndefined()
  })
})

describe('directional staking token discovery', () => {
  it('offers raw DETF directly while SY discovery is pending', () => {
    expect(collectStakeTokenAddresses({ detf: DETF, stakingToken: STAKING })).toEqual([DETF])
  })
  it('deduplicates accepted inputs and excludes staking receipts and invalid tokens', () => {
    expect(collectStakeTokenAddresses({ detf: DETF, stakingToken: STAKING, acceptedInputs: [PAIR, DETF, STAKING, ZERO, 'invalid', PAIR] })).toEqual([DETF, PAIR])
  })
})

describe('formatTokenAmount', () => {
  it('formats nine-decimal DETF and preserves explicitly supplied payment precision', () => {
    expect(formatTokenAmount(1_500_000_000n)).toBe('1.5')
    expect(formatTokenAmount(1n, 9, 9)).toBe('0.000000001')
    expect(formatTokenAmount(1_500_000_000_000_000_000n, 18)).toBe('1.5')
  })
  it('dashes missing values', () => expect(formatTokenAmount(undefined)).toBe('—'))
})

describe('insightsStakingHref', () => {
  it('keeps Protocol DETF navigation separate', () => {
    expect(insightsStakingHref(DETF)).toBe(`/insights/${getAddress(DETF)}?tab=stake`)
    expect(insightsStakingHref(DETF)).not.toMatch(/^\/staking(\?|$)/)
    expect(insightsStakingHref(DETF)).not.toMatch(/[?&]detf=/)
  })
})


describe('received DETF for the second staking step', () => {
  const wallet = '0x1111111111111111111111111111111111111111' as const
  function transfer(token: typeof DETF | typeof PAIR, from: `0x${string}`, to: `0x${string}`, value: bigint): TransactionReceipt['logs'][number] {
    return {
      address: token, data: encodeAbiParameters([{ type: 'uint256' }], [value]),
      topics: encodeEventTopics({ abi: erc20Abi, eventName: 'Transfer', args: { from, to } }) as [`0x${string}`, ...`0x${string}`[]],
      blockHash: `0x${'00'.repeat(32)}`, blockNumber: 1n, transactionHash: `0x${'11'.repeat(32)}`, transactionIndex: 0, logIndex: 0, removed: false,
    }
  }
  it('uses only net DETF delivered to this wallet in this receipt', () => {
    expect(receivedDetfAmount([
      transfer(DETF, ZERO, wallet, 12_377n), transfer(DETF, wallet, STAKING, 2n),
      transfer(PAIR, ZERO, wallet, 10n ** 18n), transfer(DETF, ZERO, STAKING, 9_000n),
      transfer(DETF, wallet, wallet, 500n),
    ], DETF, wallet)).toBe(12_375n)
  })
  it('does not substitute the quote or an existing balance for a missing delivery', () => {
    expect(() => receivedDetfAmount([], DETF, wallet)).toThrow('Check your wallet balance')
    expect(() => receivedDetfAmount([transfer(DETF, wallet, STAKING, 1n)], DETF, wallet)).toThrow()
  })
})
