import { readFile, writeFile, mkdir, readdir, stat } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import type { TokenList, TokenInfo } from './types.js'
import { normalizeFragmentToToken } from './normalize.js'
import { validateTokenList } from './schema.js'

// Mapping from legacy filename suffix to (bucketId, default tag set for entries).
const SUFFIX_BUCKETS: Array<{
  suffix: string
  bucketId: string
  bucketName: string
  keywords: string[]
  tagDefinitions: Record<string, { name: string; description: string }>
  entryTags: string[]
}> = [
  {
    suffix: 'tokens',
    bucketId: 'base-tokens',
    bucketName: 'Indexedex Base Tokens',
    keywords: ['indexedex', 'tokens'],
    tagDefinitions: {
      token: { name: 'Token', description: 'ERC20 token' },
      testToken: { name: 'Test Token', description: 'Test ERC20' },
      weth: { name: 'WETH', description: 'Wrapped Ether' },
    },
    entryTags: ['token'],
  },
  {
    suffix: 'balancerv3-pools',
    bucketId: 'balancer-v3-pools',
    bucketName: 'Indexedex Balancer V3 Pools',
    keywords: ['indexedex', 'balancer', 'pool'],
    tagDefinitions: {
      pool: { name: 'Pool', description: 'AMM pool' },
      balancer: { name: 'Balancer', description: 'Balancer pool' },
      balV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
    },
    entryTags: ['pool', 'balancer', 'balV3'],
  },
  {
    suffix: 'balancerv3-constprod-pools',
    bucketId: 'balancer-v3-pools',
    bucketName: 'Indexedex Balancer V3 Pools',
    keywords: ['indexedex', 'balancer', 'pool'],
    tagDefinitions: {
      pool: { name: 'Pool', description: 'AMM pool' },
      balancer: { name: 'Balancer', description: 'Balancer pool' },
      balV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
    },
    entryTags: ['pool', 'balancer', 'balV3'],
  },
  {
    suffix: 'balancerv3-vault-token-pools',
    bucketId: 'balancer-v3-pools',
    bucketName: 'Indexedex Balancer V3 Pools',
    keywords: ['indexedex', 'balancer', 'pool'],
    tagDefinitions: {
      pool: { name: 'Pool', description: 'AMM pool' },
      balancer: { name: 'Balancer', description: 'Balancer pool' },
      balV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
    },
    entryTags: ['pool', 'balancer', 'balV3'],
  },
  {
    suffix: 'erc4626',
    bucketId: 'erc4626-vaults',
    bucketName: 'Indexedex ERC4626 Vaults',
    keywords: ['indexedex', 'vault', 'erc4626'],
    tagDefinitions: {
      vault: { name: 'Vault', description: 'Vault share token' },
      erc4626: { name: 'ERC4626', description: 'ERC4626 compliant vault' },
    },
    entryTags: ['vault', 'erc4626'],
  },
  {
    suffix: 'strategy-vaults',
    bucketId: 'strategy-vaults',
    bucketName: 'Indexedex Strategy Vaults',
    keywords: ['indexedex', 'vault'],
    tagDefinitions: {
      vault: { name: 'Vault', description: 'Vault share token' },
      strat: { name: 'Strategy Vault', description: 'Pachira strategy vault' },
    },
    entryTags: ['vault', 'strat'],
  },
  {
    suffix: 'aerodrome-strategy-vaults',
    bucketId: 'strategy-vaults',
    bucketName: 'Indexedex Strategy Vaults',
    keywords: ['indexedex', 'vault'],
    tagDefinitions: {
      vault: { name: 'Vault', description: 'Vault share token' },
      strat: { name: 'Strategy Vault', description: 'Pachira strategy vault' },
    },
    entryTags: ['vault', 'strat'],
  },
  {
    suffix: 'uniV2pool',
    bucketId: 'uni-v2-pools',
    bucketName: 'Indexedex Uniswap V2 Pools',
    keywords: ['indexedex', 'uniswap', 'pool'],
    tagDefinitions: {
      pool: { name: 'Pool', description: 'AMM pool' },
      uniV2: { name: 'Uniswap V2', description: 'Uniswap V2 pool LP token' },
    },
    entryTags: ['pool', 'uniV2'],
  },
  {
    suffix: 'aerodrome-pools',
    bucketId: 'aerodrome-pools',
    bucketName: 'Indexedex Aerodrome Pools',
    keywords: ['indexedex', 'aerodrome', 'pool'],
    tagDefinitions: {
      pool: { name: 'Pool', description: 'AMM pool' },
      aero: { name: 'Aerodrome', description: 'Aerodrome pool' },
    },
    entryTags: ['pool', 'aero'],
  },
  {
    suffix: 'protocol-detf',
    bucketId: 'protocol-detfs',
    bucketName: 'Indexedex Protocol DETFs',
    keywords: ['indexedex', 'detf'],
    tagDefinitions: {
      vault: { name: 'Vault', description: 'Vault share token' },
      detf: { name: 'Protocol DETF', description: 'Protocol decentralized ETF' },
    },
    entryTags: ['vault', 'detf'],
  },
]

interface LegacyEntry {
  chainId: number
  address: string
  name: string
  symbol: string
  decimals: number
}

interface BucketBuilder {
  bucketId: string
  bucketName: string
  keywords: string[]
  tagDefinitions: Record<string, { name: string; description: string }>
  tokens: Map<string, TokenInfo>
}

async function walk(dir: string): Promise<string[]> {
  const out: string[] = []
  let entries: string[] = []
  try {
    entries = await readdir(dir)
  } catch {
    return out
  }
  for (const entry of entries) {
    // Skip backup directories like `supersim_sepolia.pre_minimal_backup_*`.
    if (entry.includes('.pre_minimal_backup')) continue
    const full = join(dir, entry)
    const s = await stat(full)
    if (s.isDirectory()) {
      out.push(...(await walk(full)))
    } else if (entry.endsWith('.tokenlist.json')) {
      out.push(full)
    }
  }
  return out
}

function matchSuffix(filename: string): (typeof SUFFIX_BUCKETS)[number] | undefined {
  const stem = filename.replace(/\.tokenlist\.json$/, '')
  // Filenames look like `<env>-<suffix>` (e.g. `sepolia-balancerv3-pools`).
  // Drop the leading env token by taking everything after the first dash.
  const dashIdx = stem.indexOf('-')
  if (dashIdx < 0) return undefined
  const candidate = stem.slice(dashIdx + 1)
  // Match longest suffix first to avoid `tokens` shadowing in `aerodrome-tokens`.
  const sorted = [...SUFFIX_BUCKETS].sort((a, b) => b.suffix.length - a.suffix.length)
  return sorted.find((b) => candidate === b.suffix)
}

async function migrate(addressesRoot: string, timestamp: string): Promise<void> {
  const files = await walk(addressesRoot)
  const byDirAndBucket = new Map<string, BucketBuilder>()

  for (const file of files) {
    const base = file.split('/').pop()!
    const m = matchSuffix(base)
    if (!m) continue

    let raw: string
    try {
      raw = await readFile(file, 'utf8')
    } catch {
      continue
    }
    let parsed: unknown
    try {
      parsed = JSON.parse(raw)
    } catch {
      continue
    }
    if (!Array.isArray(parsed)) continue

    const dir = dirname(file)
    const key = `${dir}::${m.bucketId}`
    let bucket = byDirAndBucket.get(key)
    if (!bucket) {
      bucket = {
        bucketId: m.bucketId,
        bucketName: m.bucketName,
        keywords: m.keywords,
        tagDefinitions: m.tagDefinitions,
        tokens: new Map(),
      }
      byDirAndBucket.set(key, bucket)
    }

    for (const entry of parsed as LegacyEntry[]) {
      if (!entry || typeof entry.address !== 'string') continue
      const normalized = normalizeFragmentToToken(
        {
          chainId: entry.chainId,
          address: entry.address as `0x${string}`,
          name: entry.name ?? '',
          symbol: entry.symbol ?? '',
          decimals: entry.decimals ?? 18,
          tags: m.entryTags,
        },
        m.entryTags
      )
      const k = `${normalized.token.chainId}-${normalized.token.address.toLowerCase()}`
      bucket.tokens.set(k, normalized.token)
    }
  }

  let wrote = 0
  let failed = 0

  for (const [key, bucket] of byDirAndBucket) {
    if (bucket.tokens.size === 0) continue
    const dir = key.split('::')[0]!
    const outPath = join(dir, `${bucket.bucketId}.tokenlist.json`)

    const list: TokenList = {
      name: bucket.bucketName,
      timestamp,
      version: { major: 1, minor: 0, patch: 0 },
      keywords: bucket.keywords,
      tags: bucket.tagDefinitions,
      tokens: [...bucket.tokens.values()],
    }

    const validation = validateTokenList(list)
    if (!validation.valid) {
      failed++
      console.error(`[FAIL] ${outPath}`)
      for (const e of validation.errors) console.error(`  - ${e}`)
      continue
    }

    await mkdir(dirname(outPath), { recursive: true })
    await writeFile(outPath, JSON.stringify(list, null, 2) + '\n', 'utf8')
    console.log(`[OK]   ${outPath} (${list.tokens.length} tokens)`)
    wrote++
  }

  console.log(`\nWrote ${wrote} list(s), ${failed} failure(s).`)
  if (failed > 0) process.exit(1)
}

async function main() {
  const repoRoot = process.env.INDEXEDEX_REPO_ROOT ?? process.cwd()
  const addressesRoot = join(repoRoot, 'frontend/packages/protocol/src/addresses')
  const timestamp = new Date().toISOString()
  console.log(`Migrating legacy tokenlists under ${addressesRoot}`)
  await migrate(addressesRoot, timestamp)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
