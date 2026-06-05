import type { ListBucketConfig, ManifestFragment } from './types.js'

export function filterFragmentsForBucket(
  bucket: ListBucketConfig,
  fragments: ManifestFragment[]
): ManifestFragment[] {
  const allow = new Set(bucket.includeTypeDirs)
  return fragments.filter((f) => f.sourceTypeDir !== undefined && allow.has(f.sourceTypeDir))
}
