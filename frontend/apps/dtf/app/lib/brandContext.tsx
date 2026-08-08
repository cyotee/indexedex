'use client'
import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react'
import { applySiteToDocument, getSite, type SiteDefinition } from './site'
type BrandContextValue = { brandId: 'dtf'; brand: SiteDefinition }
const site = getSite()
const BrandContext = createContext<BrandContextValue>({ brandId: 'dtf', brand: site })
export function BrandProvider({ children }: { children: ReactNode }) {
  useEffect(() => { applySiteToDocument() }, [])
  const value = useMemo(() => ({ brandId: 'dtf' as const, brand: site }), [])
  return <BrandContext.Provider value={value}>{children}</BrandContext.Provider>
}
export function useBrand(): BrandContextValue { return useContext(BrandContext) }
