import type { ListBucketConfig, ManifestFragment, TokenList, TokenInfo } from './types.js'
import { deriveTagsFromTypeDir } from './deriveTags.js'
import { filterFragmentsForBucket } from './groupByList.js'
import { computeBump, type PreviousList } from './bumpVersion.js'
import { validateTokenList, type ValidationResult } from './schema.js'
import { normalizeFragmentToToken } from './normalize.js'

export interface BuildListInput {
  bucket: ListBucketConfig
  fragments: ManifestFragment[]
  previousList: PreviousList | null
  timestamp: string
}

export interface BuildListResult {
  list: TokenList
  validation: ValidationResult
  bump: ReturnType<typeof computeBump>
}

export function buildList({
  bucket,
  fragments,
  previousList,
  timestamp,
}: BuildListInput): BuildListResult {
  const scoped = filterFragmentsForBucket(bucket, fragments)

  const tokens: TokenInfo[] = scoped.map((f) => {
    const derivedTags = deriveTagsFromTypeDir(f.sourceTypeDir ?? '')
    const explicitTags = f.tags ?? []
    const tags = unionPreservingOrder(derivedTags, explicitTags)
    return normalizeFragmentToToken(f, tags).token
  })

  const bump = computeBump(previousList, tokens)

  const list: TokenList = {
    name: bucket.name,
    timestamp,
    version: bump.next,
    keywords: bucket.keywords,
    tags: bucket.tagDefinitions,
    tokens,
  }

  return { list, validation: validateTokenList(list), bump }
}

function unionPreservingOrder<T>(a: T[], b: T[]): T[] {
  const seen = new Set<T>()
  const out: T[] = []
  for (const x of [...a, ...b]) {
    if (!seen.has(x)) {
      seen.add(x)
      out.push(x)
    }
  }
  return out
}
