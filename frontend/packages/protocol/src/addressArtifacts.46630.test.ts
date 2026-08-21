import { describe, expect, it } from 'vitest'
import {
  CHAIN_ID_ROBINHOOD,
  CHAIN_ID_ROBINHOOD_TESTNET,
  getAddressArtifacts,
  resolveArtifactsChainId,
} from './addressArtifacts'
import { getMintableTestTokensForChain } from './tokenlists'

describe('46630 first-class protocol resolve', () => {
  it('resolveArtifactsChainId(46630) stays 46630 and never remaps to 4663 or Sepolia', () => {
    expect(resolveArtifactsChainId(CHAIN_ID_ROBINHOOD_TESTNET, 'anvil_robinhood_testnet')).toBe(46630)
    expect(resolveArtifactsChainId(CHAIN_ID_ROBINHOOD_TESTNET, 'anvil_robinhood_testnet')).not.toBe(
      CHAIN_ID_ROBINHOOD
    )
    expect(resolveArtifactsChainId(CHAIN_ID_ROBINHOOD_TESTNET, 'anvil_robinhood_testnet')).not.toBe(11155111)
  })

  it('getAddressArtifacts(46630) resolves the anvil_robinhood_testnet bundle', () => {
    const artifacts = getAddressArtifacts(46630, 'anvil_robinhood_testnet')
    expect(artifacts.chainId).toBe(46630)
    expect(artifacts.environment).toBe('anvil_robinhood_testnet')
    expect(artifacts.platform.chainId).toBe(46630)
    expect(artifacts.tokenlists.protocolDetf).toHaveLength(10)
    expect(artifacts.tokenlists.protocolDetf.some((t) => t.tags?.includes('fee-detf'))).toBe(false)
    const testTokens = artifacts.tokenlists.tokens.filter(
      (t) => t.tags?.includes('testToken')
    )
    expect(testTokens).toHaveLength(11)
    const weth = artifacts.tokenlists.tokens.find((t) => t.symbol === 'WETH')
    expect(weth?.tags).toEqual(['weth'])
    const faucet = artifacts.tokenlists.tokens.filter((t) => t.tags?.includes('rh-faucet'))
    expect(faucet).toHaveLength(5)
    faucet.forEach((t) => expect(t.tags).toEqual(['rh-faucet']))
  })

  it('mint list is the 11 stand-ins and excludes WETH and faucet stocks', () => {
    const mintable = getMintableTestTokensForChain(46630, 'anvil_robinhood_testnet')
    expect(mintable).toHaveLength(11)
    expect(mintable.every((t) => t.symbol.startsWith('TT'))).toBe(true)
    expect(mintable.some((t) => t.symbol === 'WETH')).toBe(false)
    expect(mintable.some((t) => t.tags?.includes('rh-faucet'))).toBe(false)
  })
})
