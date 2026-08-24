import { describe, expect, it } from 'vitest'
import { encodeAbiParameters, keccak256, parseAbiParameters } from 'viem'

import {
  isMorphoCreateWalletRevert,
  isMorphoMarketAlreadyCreatedError,
  lastUpdateFromMarket,
  marketStatusCopy,
  morphoMarketExists,
  morphoMarketId,
  MORPHO_LLTV_80,
} from './seMorpho'

const LOAN = '0x1111111111111111111111111111111111111111' as const
const COLL = '0x2222222222222222222222222222222222222222' as const
const ORACLE = '0x3333333333333333333333333333333333333333' as const
const IRM = '0x4444444444444444444444444444444444444444' as const

describe('morphoMarketId', () => {
  it('is keccak256 of abi.encode of the five MarketParams words', () => {
    const params = {
      loanToken: LOAN,
      collateralToken: COLL,
      oracle: ORACLE,
      irm: IRM,
      lltv: MORPHO_LLTV_80,
    }
    const expected = keccak256(
      encodeAbiParameters(parseAbiParameters('address, address, address, address, uint256'), [
        LOAN,
        COLL,
        ORACLE,
        IRM,
        MORPHO_LLTV_80,
      ]),
    )
    expect(morphoMarketId(params)).toBe(expected)
    expect(morphoMarketId(params)).toMatch(/^0x[0-9a-f]{64}$/)
  })
})

describe('morphoMarketExists', () => {
  it('is true only when lastUpdate is a positive timestamp', () => {
    expect(morphoMarketExists(0n)).toBe(false)
    expect(morphoMarketExists(undefined)).toBe(false)
    expect(morphoMarketExists(1n)).toBe(true)
    expect(morphoMarketExists(1_700_000_000n)).toBe(true)
  })
})

describe('lastUpdateFromMarket', () => {
  it('reads a tuple or a struct', () => {
    expect(lastUpdateFromMarket([0n, 0n, 0n, 0n, 42n, 0n])).toBe(42n)
    expect(lastUpdateFromMarket({ lastUpdate: 9n })).toBe(9n)
    expect(lastUpdateFromMarket(null)).toBeNull()
  })
})

describe('market status copy', () => {
  it('says found or not found', () => {
    expect(marketStatusCopy(true)).toBe('found')
    expect(marketStatusCopy(false)).toBe('not found')
  })
})

describe('already-created errors', () => {
  it('detects the Morpho string revert', () => {
    expect(isMorphoMarketAlreadyCreatedError(new Error('market already created'))).toBe(true)
    expect(isMorphoCreateWalletRevert(new Error('execution reverted'))).toBe(true)
    expect(isMorphoCreateWalletRevert(new Error('insufficient funds'))).toBe(false)
  })
})
