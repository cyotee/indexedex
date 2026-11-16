import { describe, it, expect } from 'vitest'
import { buildList } from '../src/buildList.js'
import type { ManifestFragment, ListBucketConfig } from '../src/types.js'

const POOLS_BUCKET: ListBucketConfig = {
  id: 'balancer-v3-pools',
  name: 'Indexedex Balancer V3 Pools',
  keywords: ['indexedex', 'balancer'],
  includeTypeDirs: ['pools/balancerV3'],
  defaultTags: [],
  tagDefinitions: {
    pool: { name: 'Pool', description: 'AMM pool' },
    balancer: { name: 'Balancer', description: 'Balancer pool' },
    balV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
  },
}

const fragment: ManifestFragment = {
  chainId: 11155111,
  address: '0x2222222222222222222222222222222222222222',
  name: 'AB Pool',
  symbol: 'abPool',
  decimals: 18,
  sourceTypeDir: 'pools/balancerV3',
}

describe('buildList', () => {
  it('produces a schema-valid list with derived tags and stamped metadata', () => {
    const result = buildList({
      bucket: POOLS_BUCKET,
      fragments: [fragment],
      previousList: null,
      timestamp: '2026-06-05T00:00:00.000Z',
    })

    expect(result.list.name).toBe('Indexedex Balancer V3 Pools')
    expect(result.list.timestamp).toBe('2026-06-05T00:00:00.000Z')
    expect(result.list.version).toEqual({ major: 1, minor: 0, patch: 0 })
    expect(result.list.tokens).toHaveLength(1)
    expect(result.list.tokens[0]?.tags).toEqual(['pool', 'balancer', 'balV3'])
    expect(result.list.tags).toEqual(POOLS_BUCKET.tagDefinitions)
    expect(result.validation.valid).toBe(true)
  })

  it('drops fragments whose sourceTypeDir is outside includeTypeDirs', () => {
    const other: ManifestFragment = {
      ...fragment,
      sourceTypeDir: 'tokens',
      address: '0x3333333333333333333333333333333333333333',
    }
    const result = buildList({
      bucket: POOLS_BUCKET,
      fragments: [fragment, other],
      previousList: null,
      timestamp: '2026-06-05T00:00:00.000Z',
    })
    expect(result.list.tokens).toHaveLength(1)
    expect(result.list.tokens[0]?.address.toLowerCase()).toBe(fragment.address.toLowerCase())
  })

  it('preserves explicit fragment tags as a union with directory-derived tags', () => {
    const tagged = { ...fragment, tags: ['custom', 'pool'] }
    const result = buildList({
      bucket: POOLS_BUCKET,
      fragments: [tagged],
      previousList: null,
      timestamp: '2026-06-05T00:00:00.000Z',
    })
    expect(result.list.tokens[0]?.tags).toEqual(['pool', 'balancer', 'balV3', 'custom'])
  })
})
