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
    kicker: 'One pool',
    title: 'Single Pool',
    blurb: 'The DETF token plus one pool. One working position in another app.',
    href: '/create/one-vault',
  },
]

export function isOfferedCreateType(id: string): id is CreateDetfTypeId {
  return CREATE_DETF_TYPES.some((t) => t.id === id)
}
