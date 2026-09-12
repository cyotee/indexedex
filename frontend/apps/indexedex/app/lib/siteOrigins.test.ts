import { describe, expect, it } from 'vitest'
import { appPath } from './siteOrigins'

describe('IndexedEx application navigation', () => {
  it('keeps landing links on the current host and preserves the query', () => {
    expect(appPath('/explore')).toBe('/explore')
    expect(appPath('create')).toBe('/create')
    expect(appPath('/staking?detf=0x123')).toBe('/staking?detf=0x123')
  })
})
