import { afterEach, describe, expect, it, vi } from 'vitest'

describe('lab flags', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('isEarnDetfEmbedEnabled defaults on unless explicitly "false"', async () => {
    vi.stubEnv('NEXT_PUBLIC_EARN_DETF_EMBED', undefined)
    const { isEarnDetfEmbedEnabled } = await import('./lab')
    expect(isEarnDetfEmbedEnabled()).toBe(true)
  })

  it('isEarnDetfEmbedEnabled true when set to "true"', async () => {
    vi.stubEnv('NEXT_PUBLIC_EARN_DETF_EMBED', 'true')
    const { isEarnDetfEmbedEnabled } = await import('./lab')
    expect(isEarnDetfEmbedEnabled()).toBe(true)
  })

  it('isEarnDetfEmbedEnabled false only when set to "false"', async () => {
    vi.stubEnv('NEXT_PUBLIC_EARN_DETF_EMBED', 'false')
    const { isEarnDetfEmbedEnabled } = await import('./lab')
    expect(isEarnDetfEmbedEnabled()).toBe(false)
  })
})
