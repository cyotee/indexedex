import { getAddress, isAddress } from 'viem'

export const INSIGHTS_ACTION_TABS = ['mint', 'burn', 'bond', 'stake', 'claim'] as const
export type InsightsActionTab = (typeof INSIGHTS_ACTION_TABS)[number]

export function isInsightsActionTab(value: string | null | undefined): value is InsightsActionTab {
  return !!value && (INSIGHTS_ACTION_TABS as readonly string[]).includes(value)
}

/** EIP-55 checksum, or null if not an address. */
export function checksumDetfAddress(value: string | null | undefined): `0x${string}` | null {
  if (!value || !isAddress(value)) return null
  try {
    return getAddress(value) as `0x${string}`
  } catch {
    return null
  }
}

export function insightsTabQuery(tab?: string | null): string {
  if (!isInsightsActionTab(tab)) return ''
  return `?tab=${encodeURIComponent(tab)}`
}

/** Canonical DETF page: `/insights/0xChecksum` plus optional action tab. */
export function insightsDetfHref(detf: string, tab?: string | null): string {
  const addr = checksumDetfAddress(detf)
  if (!addr) return '/insights'
  return `/insights/${addr}${insightsTabQuery(tab)}`
}

export function parseInsightsDetfQuery(value: string | null | undefined): `0x${string}` | null {
  return checksumDetfAddress(value ?? null)
}
