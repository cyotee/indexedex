import type { TokenList, TokenInfo } from '@uniswap/token-lists/src/types'

export type Address = `0x${string}`
export type ChainId = number

export interface ManifestFragment {
  chainId: ChainId
  address: Address
  name: string
  symbol: string
  decimals: number
  tags?: string[]
  extensions?: Record<string, unknown>
  sourcePath?: string
  sourceTypeDir?: string
}

export interface ListBucketConfig {
  id: string
  name: string
  keywords: string[]
  includeTypeDirs: string[]
  defaultTags: string[]
  tagDefinitions: Record<string, { name: string; description: string }>
}

export interface ChainEntry {
  chainId: ChainId
  chainDir: string
}

export interface EnvironmentEntry {
  environment: string
  chains: ChainEntry[]
}

export interface AggregatorConfig {
  inputRoot: string
  outputRoot: string
  environments: EnvironmentEntry[]
  buckets: ListBucketConfig[]
}

export interface BumpResult {
  bump: 'major' | 'minor' | 'patch' | 'none'
  previous: { major: number; minor: number; patch: number } | null
  next: { major: number; minor: number; patch: number }
  changes: {
    added: Address[]
    removed: Address[]
    modified: Address[]
  }
}

export type { TokenList, TokenInfo }
