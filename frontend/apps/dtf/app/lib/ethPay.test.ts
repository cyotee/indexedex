import { describe, expect, it } from 'vitest'

import { ETH_PAY, isEthPay, settlePayToken, withEthPayOption } from './ethPay'

const WETH = '0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73' as const
const DTF = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01' as const
const SE = '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099' as const

describe('ethPay', () => {
  it('inserts ETH before WETH when WETH is accepted', () => {
    const got = withEthPayOption(
      [
        { address: DTF, symbol: 'DTF' },
        { address: WETH, symbol: 'WETH' },
        { address: SE, symbol: 'SE' },
      ],
      WETH,
      { address: ETH_PAY, symbol: 'ETH' },
    )
    expect(got.map((t) => t.symbol)).toEqual(['DTF', 'ETH', 'WETH', 'SE'])
  })

  it('does not insert ETH when WETH is not in the list', () => {
    const tokens = [{ address: DTF, symbol: 'DTF' }]
    expect(withEthPayOption(tokens, WETH, { address: ETH_PAY, symbol: 'ETH' })).toEqual(tokens)
  })

  it('does not insert ETH twice', () => {
    const once = withEthPayOption([{ address: WETH, symbol: 'WETH' }], WETH, {
      address: ETH_PAY,
      symbol: 'ETH',
    })
    expect(withEthPayOption(once, WETH, { address: ETH_PAY, symbol: 'ETH' })).toEqual(once)
  })

  it('settles ETH to WETH and leaves other tokens alone', () => {
    expect(settlePayToken(ETH_PAY, WETH)).toBe(WETH)
    expect(settlePayToken(DTF, WETH)).toBe(DTF)
    expect(settlePayToken(ETH_PAY, null)).toBeNull()
    expect(isEthPay(ETH_PAY)).toBe(true)
    expect(isEthPay(WETH)).toBe(false)
  })
})
