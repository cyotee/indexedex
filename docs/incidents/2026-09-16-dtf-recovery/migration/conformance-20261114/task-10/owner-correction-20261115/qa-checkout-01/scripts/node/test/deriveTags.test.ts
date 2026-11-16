import { describe, it, expect } from 'vitest'
import { deriveTagsFromTypeDir } from '../src/deriveTags.js'

describe('deriveTagsFromTypeDir', () => {
  it('derives pool + balancer tags for pools/balancerV3', () => {
    expect(deriveTagsFromTypeDir('pools/balancerV3')).toEqual(['pool', 'balancer', 'balV3'])
  })

  it('derives pool + uniV2 for pools/uniV2', () => {
    expect(deriveTagsFromTypeDir('pools/uniV2')).toEqual(['pool', 'uniV2'])
  })

  it('derives vault + erc4626 for vaults/erc4626', () => {
    expect(deriveTagsFromTypeDir('vaults/erc4626')).toEqual(['vault', 'erc4626'])
  })

  it('derives token tag for tokens/', () => {
    expect(deriveTagsFromTypeDir('tokens')).toEqual(['token'])
  })

  it('returns empty for unknown directory', () => {
    expect(deriveTagsFromTypeDir('mystery')).toEqual([])
  })

  it('normalizes leading slash and trailing slash', () => {
    expect(deriveTagsFromTypeDir('/pools/balancerV3/')).toEqual(['pool', 'balancer', 'balV3'])
  })
})
