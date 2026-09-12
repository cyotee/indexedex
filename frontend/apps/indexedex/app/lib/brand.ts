export type BrandId = 'indexedex'
export type BrandDefinition = {
  id: BrandId; name: string; title: string; description: string; tagline: string; manifestoLabel: string; logoSrc: string; logoAlt: string
}
import { SITE, applySiteToDocument } from './site'
export function normalizeBrandId(_raw?: string | null): BrandId { return 'indexedex' }
export function getDefaultBrandId(): BrandId { return 'indexedex' }
export function getBrand(_id?: BrandId): BrandDefinition { return SITE as BrandDefinition }
export function applyBrandToDocument(_id?: BrandId) { applySiteToDocument() }
export const BRANDS: Record<BrandId, BrandDefinition> = { indexedex: SITE as BrandDefinition }
