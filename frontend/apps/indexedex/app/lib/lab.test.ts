import { afterEach, describe, expect, it, vi } from 'vitest'

describe('lab flags', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('isEarnDetfEmbedEnabled defaults false', async () => {
    vi.stubEnv('NEXT_PUBLIC_EARN_DETF_EMBED', undefined)
    const { isEarnDetfEmbedEnabled } = await import('./lab')
    expect(isEarnDetfEmbedEnabled()).toBe(false)
  })

  it('isEarnDetfEmbedEnabled true only when set to "true"', async () => {
    vi.stubEnv('NEXT_PUBLIC_EARN_DETF_EMBED', 'true')
    const { isEarnDetfEmbedEnabled } = await import('./lab')
    expect(isEarnDetfEmbedEnabled()).toBe(true)
  })

  it('isEarnDetfEmbedEnabled rejects "1" / "yes"', async () => {
    vi.stubEnv('NEXT_PUBLIC_EARN_DETF_EMBED', '1')
    const { isEarnDetfEmbedEnabled } = await import('./lab')
    expect(isEarnDetfEmbedEnabled()).toBe(false)
  })
})
