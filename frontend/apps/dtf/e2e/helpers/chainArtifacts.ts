import fs from 'node:fs'
import path from 'node:path'

/**
 * Load committed protocol address artifacts for the e2e chain.
 * Default chain: 4663 (Robinhood / Anvil RH fork).
 * Path: packages/protocol (shared) — not app-local addresses.
 */
export const E2E_CHAIN_ID = Number(process.env.E2E_CHAIN_ID ?? 4663)

function resolveChainDir(chainId: number): string {
  // apps/dtf cwd → monorepo frontend/packages/protocol/...
  const fromProtocol = path.join(
    process.cwd(),
    '../../packages/protocol/src/addresses/chain',
    String(chainId),
  )
  if (fs.existsSync(fromProtocol)) return fromProtocol
  // fallback: app-local (legacy)
  const local = path.join(process.cwd(), 'app/addresses/chain', String(chainId))
  return local
}

const CHAIN_DIR = resolveChainDir(E2E_CHAIN_ID)

export type TokenListToken = {
  chainId: number
  address: `0x${string}`
  name: string
  symbol: string
  decimals: number
  tags?: string[]
}

function readList(file: string): TokenListToken[] {
  const p = path.join(CHAIN_DIR, file)
  if (!fs.existsSync(p)) return []
  const j = JSON.parse(fs.readFileSync(p, 'utf8')) as { tokens?: TokenListToken[] }
  return j.tokens ?? []
}

export function loadPlatform(): Record<string, string | number> {
  const p = path.join(CHAIN_DIR, 'platform.json')
  if (!fs.existsSync(p)) return {}
  return JSON.parse(fs.readFileSync(p, 'utf8'))
}

export function strategyVaults() {
  return readList('strategy-vaults.tokenlist.json')
}

export function protocolDetfs() {
  return readList('protocol-detfs.tokenlist.json')
}

export function featuredFeeDetfs() {
  return readList('featured-fee-detfs.tokenlist.json')
}

export function baseTokens() {
  return readList('base-tokens.tokenlist.json')
}

export function balancerPools() {
  return readList('balancer-v3-pools.tokenlist.json')
}

export function findBaseBySymbol(symbol: string) {
  const s = symbol.toLowerCase()
  return baseTokens().find(
    (t) => t.symbol.toLowerCase() === s || t.symbol.toLowerCase().includes(s),
  )
}

export function feeDetfAddress(): `0x${string}` | undefined {
  const fromList = featuredFeeDetfs()[0]?.address ?? protocolDetfs()[0]?.address
  if (fromList) return fromList
  const platform = loadPlatform()
  const chir = platform.chir ?? platform.feeDetf
  if (typeof chir === 'string' && /^0x[0-9a-fA-F]{40}$/.test(chir)) {
    return chir as `0x${string}`
  }
  return undefined
}

export function chainDir(): string {
  return CHAIN_DIR
}
