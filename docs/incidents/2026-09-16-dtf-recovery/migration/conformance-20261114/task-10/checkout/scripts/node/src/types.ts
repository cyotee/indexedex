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

export interface InputEntry {
  /** Path under inputRoot containing a `fragments/` subdir. */
  inputDir: string
  /** Chain id that this input's fragments target. Output goes to chain/<chainId>/. */
  chainId: ChainId
}

export interface AggregatorConfig {
  /** Root for fragment inputs. Typically "deployments". */
  inputRoot: string
  /** Root for Token List outputs. Typically "frontend/packages/protocol/src/addresses". */
  outputRoot: string
  /** Each input is a deploy directory mapped to a chain id. */
  inputs: InputEntry[]
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
