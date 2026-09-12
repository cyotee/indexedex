import { getAddress } from 'viem'
import { describe, expect, it } from 'vitest'

import { explorerAddressUrl, explorerOrigin, explorerTxUrl } from './explorer'

const ADDR = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117'
const CHECKSUM = getAddress(ADDR)

describe('explorerOrigin', () => {
  it('uses the official Robinhood mainnet Blockscout host', () => {
    expect(explorerOrigin(4663)).toBe('https://robinhoodchain.blockscout.com')
    expect(explorerOrigin(4663)).not.toContain('explorer.mainnet.chain.robinhood.com')
  })

  it('uses the Robinhood testnet explorer host', () => {
    expect(explorerOrigin(46630)).toBe('https://explorer.testnet.chain.robinhood.com')
  })

  it('uses Sepolia Etherscan', () => {
    expect(explorerOrigin(11155111)).toBe('https://sepolia.etherscan.io')
  })
})

describe('explorerAddressUrl', () => {
  it('checksums the address and uses /address/', () => {
    expect(explorerAddressUrl(46630, ADDR, false)).toBe(
      `https://explorer.testnet.chain.robinhood.com/address/${CHECKSUM}`,
    )
  })

  it('returns null on local Anvil even for Robinhood chain ids', () => {
    expect(explorerAddressUrl(4663, ADDR, true)).toBeNull()
    expect(explorerAddressUrl(46630, ADDR, true)).toBeNull()
    expect(explorerAddressUrl(31337, ADDR, false)).toBeNull()
  })

  it('returns null for an unknown chain', () => {
    expect(explorerAddressUrl(999999, ADDR, false)).toBeNull()
  })
})

describe('explorerTxUrl', () => {
  it('builds a tx URL on the matching explorer', () => {
    const hash = '0xabc'
    expect(explorerTxUrl(4663, hash, false)).toBe(
      'https://robinhoodchain.blockscout.com/tx/0xabc',
    )
  })
})
