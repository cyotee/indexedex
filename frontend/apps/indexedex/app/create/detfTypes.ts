export type CreateDetfTypeId = 'one-vault' | 'weighted' | 'grouped' | 'cash-buffer'

export type CreateDetfType = {
  id: CreateDetfTypeId
  kicker: string
  title: string
  blurb: string
  href: `/create/${CreateDetfTypeId}`
}

export const CREATE_DETF_TYPES: readonly CreateDetfType[] = [
  {
    id: 'one-vault',
    kicker: 'Simplest',
    title: 'One vault',
    blurb: 'The DETF token plus one vault share. One working position in another app.',
    href: '/create/one-vault',
  },
  {
    id: 'weighted',
    kicker: 'Fixed mix',
    title: 'Several vaults, fixed weights',
    blurb: 'Several different vaults. Each keeps its own weight. You set the mix when you create it.',
    href: '/create/weighted',
  },
  {
    id: 'grouped',
    kicker: 'Like-kind',
    title: 'Several similar vaults, grouped',
    blurb: 'Similar vaults sit in two grouped pools next to the DETF token. Marked two ways.',
    href: '/create/grouped',
  },
  {
    id: 'cash-buffer',
    kicker: 'Cash family',
    title: 'One cash token plus vaults',
    blurb: 'One cash token. Vaults that all take and give that cash. Burn returns the cash.',
    href: '/create/cash-buffer',
  },
]
