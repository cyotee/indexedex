'use client'

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'

import {
  applyBrandToDocument,
  BRANDS,
  getBrand,
  getDefaultBrandId,
  isBrandLocked,
  otherBrand,
  readStoredBrandId,
  writeStoredBrandId,
  type BrandDefinition,
  type BrandId,
} from './brand'

type BrandContextValue = {
  brandId: BrandId
  brand: BrandDefinition
  locked: boolean
  setBrandId: (id: BrandId) => void
  toggleBrand: () => void
}

const BrandContext = createContext<BrandContextValue>({
  brandId: 'pachira',
  brand: BRANDS.pachira,
  locked: false,
  setBrandId: () => {},
  toggleBrand: () => {},
})

export function BrandProvider({ children }: { children: ReactNode }) {
  const locked = isBrandLocked()
  const [brandId, setBrandIdState] = useState<BrandId>(() =>
    locked ? getDefaultBrandId() : getDefaultBrandId(),
  )

  useEffect(() => {
    const id = locked ? getDefaultBrandId() : readStoredBrandId()
    setBrandIdState(id)
    applyBrandToDocument(id)
  }, [locked])

  const setBrandId = useCallback(
    (id: BrandId) => {
      if (locked) return
      setBrandIdState(id)
      writeStoredBrandId(id)
      applyBrandToDocument(id)
    },
    [locked],
  )

  const toggleBrand = useCallback(() => {
    setBrandId(otherBrand(brandId))
  }, [brandId, setBrandId])

  const value = useMemo(
    () => ({
      brandId,
      brand: getBrand(brandId),
      locked,
      setBrandId,
      toggleBrand,
    }),
    [brandId, locked, setBrandId, toggleBrand],
  )

  return <BrandContext.Provider value={value}>{children}</BrandContext.Provider>
}

export function useBrand(): BrandContextValue {
  return useContext(BrandContext)
}
