export type CreateDetfTypeId = 'one-vault' | 'weighted' | 'stables' | 'grouped' | 'cash-buffer'

export type CreateDetfType = {
  id: CreateDetfTypeId
  kicker: string
  title: string
  blurb: string
  href: `/create/${CreateDetfTypeId}`
  /** When true, the picker greys the card and cannot be selected. Wizard routes stay. */
  comingSoon?: boolean
  /** Overlay on a coming-soon card. Defaults to Coming Soon. */
  comingSoonLabel?: string
}

/**
 * Customer include-choices. Titles and blurbs must stay about what goes in the
 * basket. Never put DFPkg or family names (Single Vault, Weighted Pool, Curve Quad)
 * in UI copy.
 */
export const CREATE_DETF_TYPES: readonly CreateDetfType[] = [
  {
    id: 'one-vault',
    kicker: 'One',
    title: 'One strategy',
    blurb: 'One vault. Mint and burn against one pair token from that vault.',
    href: '/create/one-vault',
    comingSoon: true,
    comingSoonLabel: 'Update Coming Soon',
  },
  {
    id: 'weighted',
    kicker: 'Several',
    title: 'Up to 7 strategies',
    blurb: 'Several vaults in one basket. You set how much each one gets. The mix stays put.',
    href: '/create/weighted',
    comingSoon: true,
  },
  {
    id: 'stables',
    kicker: 'Stablecoins',
    title: 'Up to 4 stablecoins',
    blurb: 'A small set of dollar tokens. Use this when the basket is stables, not mixed assets.',
    href: '/create/stables',
    comingSoon: true,
  },
]

export function isOfferedCreateType(id: string): id is CreateDetfTypeId {
  return CREATE_DETF_TYPES.some((t) => t.id === id)
}

export function isComingSoonCreateType(id: string): boolean {
  return CREATE_DETF_TYPES.some((t) => t.id === id && t.comingSoon)
}

/** Platform DFPkg key. Do not render this string. */
export type CreateDetfPkgKey = 'cpDetfPkg' | 'weightedDetfPkg' | 'curveQuadDetfPkg'

export function platformDetfPkgKey(id: CreateDetfTypeId | ''): CreateDetfPkgKey | null {
  if (id === 'one-vault') return 'cpDetfPkg'
  if (id === 'weighted') return 'weightedDetfPkg'
  if (id === 'stables') return 'curveQuadDetfPkg'
  return null
}

/** Where the one-strategy vault sits. Never put DFPkg names in UI copy. */
export type CreateSeHostId = 'uniswap-v3' | 'uniswap-v4' | 'morpho'

export type CreateSeHost = {
  id: CreateSeHostId
  kicker: string
  title: string
  blurb: string
}

export const CREATE_SE_HOSTS: readonly CreateSeHost[] = [
  {
    id: 'uniswap-v3',
    kicker: 'Uniswap V3',
    title: 'Uniswap V3 pool',
    blurb: 'The strategy vault sits on a Uniswap V3 pool.',
  },
  {
    id: 'uniswap-v4',
    kicker: 'Uniswap V4',
    title: 'Uniswap V4 pool',
    blurb: 'The strategy vault sits on a Uniswap V4 pool.',
  },
  {
    id: 'morpho',
    kicker: 'Morpho',
    title: 'Morpho market',
    blurb: 'The strategy vault sits on a Morpho lending market.',
  },
]

export function isCreateSeHostId(id: string): id is CreateSeHostId {
  return CREATE_SE_HOSTS.some((h) => h.id === id)
}

export function seHostMeta(id: CreateSeHostId | ''): CreateSeHost | undefined {
  return CREATE_SE_HOSTS.find((h) => h.id === id)
}

/** Customer name fragment for DETF defaults. Not a package name. */
export function seHostNameTag(id: CreateSeHostId | ''): string {
  if (id === 'uniswap-v3') return 'Uniswap V3'
  if (id === 'uniswap-v4') return 'Uniswap V4'
  if (id === 'morpho') return 'Morpho Blue'
  return ''
}

/** Short ticker fragment for DETF symbol defaults. */
export function seHostSymbolTag(id: CreateSeHostId | ''): string {
  if (id === 'uniswap-v3') return 'V3'
  if (id === 'uniswap-v4') return 'V4'
  if (id === 'morpho') return 'MB'
  return ''
}

/** Platform SE DFPkg key. Do not render this string. */
export type CreateSePkgKey = 'uniV3SePkg' | 'uniV4SePkg' | 'morphoBlueSePkg'

export function platformSePkgKey(id: CreateSeHostId | ''): CreateSePkgKey | null {
  if (id === 'uniswap-v3') return 'uniV3SePkg'
  if (id === 'uniswap-v4') return 'uniV4SePkg'
  if (id === 'morpho') return 'morphoBlueSePkg'
  return null
}
