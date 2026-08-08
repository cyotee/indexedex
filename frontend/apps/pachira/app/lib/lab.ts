/**
 * Lab/debug UI is off by default. Enable with NEXT_PUBLIC_SHOW_DEBUG=true.
 */
export function isDebugLabEnabled(): boolean {
  return process.env.NEXT_PUBLIC_SHOW_DEBUG === 'true'
}

/**
 * Earn-detail DETF mint/bond/sell embed.
 * Default **false** until mint/bond e2e smoke passes (Wave 1 PR7).
 * Enable with NEXT_PUBLIC_EARN_DETF_EMBED=true for lab only.
 */
export function isEarnDetfEmbedEnabled(): boolean {
  return process.env.NEXT_PUBLIC_EARN_DETF_EMBED === 'true'
}

export function isLaunchBannerEnabled(): boolean {
  return process.env.NEXT_PUBLIC_SHOW_LAUNCH_BANNER === 'true'
}

export function getLaunchTokenAddress(): `0x${string}` | null {
  const raw = process.env.NEXT_PUBLIC_LAUNCH_TOKEN_ADDRESS?.trim()
  if (!raw || !/^0x[0-9a-fA-F]{40}$/.test(raw)) return null
  return raw as `0x${string}`
}

export function getDocsUrl(): string {
  return process.env.NEXT_PUBLIC_DOCS_URL?.trim() || 'https://github.com'
}

export function getAuditUrl(): string | null {
  const raw = process.env.NEXT_PUBLIC_AUDIT_URL?.trim()
  return raw || null
}
