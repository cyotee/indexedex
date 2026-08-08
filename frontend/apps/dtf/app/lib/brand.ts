export type BrandId = 'dtf'
export type BrandDefinition = {
  id: BrandId; name: string; title: string; description: string; tagline: string; manifestoLabel: string; logoSrc: string; logoAlt: string
}
import { SITE, applySiteToDocument } from './site'
export function normalizeBrandId(_raw?: string | null): BrandId { return 'dtf' }
export function getDefaultBrandId(): BrandId { return 'dtf' }
export function getBrand(_id?: BrandId): BrandDefinition { return SITE as BrandDefinition }
export function applyBrandToDocument(_id?: BrandId) { applySiteToDocument() }
export const BRANDS: Record<BrandId, BrandDefinition> = { dtf: SITE as BrandDefinition }
