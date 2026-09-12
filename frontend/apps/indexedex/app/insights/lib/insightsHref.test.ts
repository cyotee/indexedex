import { getAddress } from 'viem'
import { describe, expect, it } from 'vitest'

import {
  checksumDetfAddress,
  insightsDetfHref,
  insightsTabQuery,
  isInsightsActionTab,
  parseInsightsDetfQuery,
} from './insightsHref'

const RAW = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117'
const CHECKSUM = getAddress(RAW)

describe('insightsDetfHref', () => {
  it('puts a checksummed DETF token in the path', () => {
    expect(insightsDetfHref(RAW)).toBe(`/insights/${CHECKSUM}`)
    expect(insightsDetfHref(CHECKSUM, 'stake')).toBe(`/insights/${CHECKSUM}?tab=stake`)
  })

  it('keeps burn as a tab query on the path', () => {
    expect(insightsDetfHref(RAW, 'burn')).toBe(`/insights/${CHECKSUM}?tab=burn`)
  })

  it('drops unknown tabs and bad addresses', () => {
    expect(insightsDetfHref(RAW, 'nope')).toBe(`/insights/${CHECKSUM}`)
    expect(insightsDetfHref('not-an-address')).toBe('/insights')
  })
})

describe('parseInsightsDetfQuery', () => {
  it('checksums a legacy ?detf= value', () => {
    expect(parseInsightsDetfQuery(RAW)).toBe(CHECKSUM)
    expect(parseInsightsDetfQuery(null)).toBeNull()
  })
})

describe('tab helpers', () => {
  it('accepts the action tabs only', () => {
    expect(isInsightsActionTab('burn')).toBe(true)
    expect(isInsightsActionTab('swap')).toBe(false)
    expect(insightsTabQuery('mint')).toBe('?tab=mint')
    expect(insightsTabQuery('x')).toBe('')
  })
})

describe('checksumDetfAddress', () => {
  it('rejects zero-length junk', () => {
    expect(checksumDetfAddress('')).toBeNull()
    expect(checksumDetfAddress('0x123')).toBeNull()
  })
})
