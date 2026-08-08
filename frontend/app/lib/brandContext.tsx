'use client'

import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react'

import {
  applyBrandToDocument,
  getBrand,
  getDefaultBrandId,
  type BrandDefinition,
  type BrandId,
} from './brand'

type BrandContextValue = {
  brandId: BrandId
  brand: BrandDefinition
}

const defaultId = getDefaultBrandId()

const BrandContext = createContext<BrandContextValue>({
  brandId: defaultId,
  brand: getBrand(defaultId),
})

/**
 * Brand is deploy-time only (NEXT_PUBLIC_DEFAULT_BRAND). No runtime toggle / localStorage.
 */
export function BrandProvider({ children }: { children: ReactNode }) {
  const brandId = getDefaultBrandId()

  useEffect(() => {
    applyBrandToDocument(brandId)
  }, [brandId])

  const value = useMemo(
    () => ({
      brandId,
      brand: getBrand(brandId),
    }),
    [brandId],
  )

  return <BrandContext.Provider value={value}>{children}</BrandContext.Provider>
}

export function useBrand(): BrandContextValue {
  return useContext(BrandContext)
}
