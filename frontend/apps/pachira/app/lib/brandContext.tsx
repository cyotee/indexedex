'use client'

import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react'

import { applySiteToDocument, getSite, type SiteDefinition } from './site'

type BrandContextValue = {
  brandId: 'pachira'
  brand: SiteDefinition
}

const site = getSite()

const BrandContext = createContext<BrandContextValue>({
  brandId: 'pachira',
  brand: site,
})

/** Site is fixed for this app. No runtime toggle / localStorage. */
export function BrandProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    applySiteToDocument()
  }, [])

  const value = useMemo(
    () => ({
      brandId: 'pachira' as const,
      brand: site,
    }),
    [],
  )

  return <BrandContext.Provider value={value}>{children}</BrandContext.Provider>
}

export function useBrand(): BrandContextValue {
  return useContext(BrandContext)
}
