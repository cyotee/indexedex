import { afterEach, describe, expect, it } from 'vitest'

import {
  APP_HOST,
  appPath,
  isAppHost,
  isMarketingHost,
  resolveHostNavigation,
} from './siteOrigins'

describe('siteOrigins', () => {
  const prev = process.env.NEXT_PUBLIC_APP_ORIGIN
  afterEach(() => {
    if (prev === undefined) delete process.env.NEXT_PUBLIC_APP_ORIGIN
    else process.env.NEXT_PUBLIC_APP_ORIGIN = prev
  })

  it('detects marketing and app hosts', () => {
    expect(isMarketingHost('downto.finance')).toBe(true)
    expect(isMarketingHost('www.downto.finance')).toBe(true)
    expect(isMarketingHost('downto.finance:443')).toBe(true)
    expect(isAppHost(APP_HOST)).toBe(true)
    expect(isAppHost('localhost')).toBe(false)
    expect(isMarketingHost('dtfinance.vercel.app')).toBe(false)
  })

  it('keeps relative app paths when origin env is unset', () => {
    delete process.env.NEXT_PUBLIC_APP_ORIGIN
    expect(appPath('/explore')).toBe('/explore')
    expect(appPath('create')).toBe('/create')
  })

  it('prefixes app paths when origin env is set', () => {
    process.env.NEXT_PUBLIC_APP_ORIGIN = 'https://app.downto.finance/'
    expect(appPath('/explore')).toBe('https://app.downto.finance/explore')
    expect(appPath('/swap?launch=1')).toBe('https://app.downto.finance/swap?launch=1')
  })

  it('sends app host / to /explore', () => {
    expect(resolveHostNavigation(APP_HOST, '/')).toEqual({
      type: 'redirect',
      location: '/explore',
    })
    expect(resolveHostNavigation(APP_HOST, '/', '?tab=x')).toEqual({
      type: 'redirect',
      location: '/explore?tab=x',
    })
    expect(resolveHostNavigation(APP_HOST, '/explore')).toEqual({ type: 'next' })
  })

  it('sends marketing host app paths to the app origin', () => {
    expect(resolveHostNavigation('downto.finance', '/')).toEqual({ type: 'next' })
    expect(resolveHostNavigation('downto.finance', '/explore')).toEqual({
      type: 'redirect',
      location: 'https://app.downto.finance/explore',
    })
    expect(resolveHostNavigation('www.downto.finance', '/create', '?x=1')).toEqual({
      type: 'redirect',
      location: 'https://app.downto.finance/create?x=1',
    })
  })

  it('leaves localhost and vercel.app hosts alone', () => {
    expect(resolveHostNavigation('localhost', '/explore')).toEqual({ type: 'next' })
    expect(resolveHostNavigation('dtfinance.vercel.app', '/')).toEqual({ type: 'next' })
    expect(resolveHostNavigation('dtfinance-git-main.vercel.app', '/explore')).toEqual({
      type: 'next',
    })
  })
})
