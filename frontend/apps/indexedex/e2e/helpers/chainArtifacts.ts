import fs from 'node:fs'
import path from 'node:path'

const CHAIN_DIR = path.join(process.cwd(), 'app/addresses/chain/11155111')

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

export function loadPlatform(): Record<string, string> {
  return JSON.parse(fs.readFileSync(path.join(CHAIN_DIR, 'platform.json'), 'utf8'))
}

export function strategyVaults() {
  return readList('strategy-vaults.tokenlist.json')
}

export function protocolDetfs() {
  return readList('protocol-detfs.tokenlist.json')
}

export function baseTokens() {
  return readList('base-tokens.tokenlist.json')
}

export function balancerPools() {
  return readList('balancer-v3-pools.tokenlist.json')
}

export function findBaseBySymbol(symbol: string) {
  const s = symbol.toLowerCase()
  return baseTokens().find((t) => t.symbol.toLowerCase() === s || t.symbol.toLowerCase().includes(s))
}
