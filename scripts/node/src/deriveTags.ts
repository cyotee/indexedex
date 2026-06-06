const TAXONOMY: Record<string, string[]> = {
  'tokens': ['token'],
  'pools/balancerV3': ['pool', 'balancer', 'balV3'],
  'pools/uniV2': ['pool', 'uniV2'],
  'pools/aerodrome': ['pool', 'aero'],
  'vaults/erc4626': ['vault', 'erc4626'],
  'vaults/strategy': ['vault', 'strat'],
  'vaults/protocolDetf': ['vault', 'detf'],
  'vaults/seigniorageDetf': ['vault', 'sdetf'],
}

function normalize(typeDir: string): string {
  return typeDir.replace(/^\/+|\/+$/g, '')
}

export function deriveTagsFromTypeDir(typeDir: string): string[] {
  const tags = TAXONOMY[normalize(typeDir)]
  return tags ? [...tags] : []
}

export function isKnownTypeDir(typeDir: string): boolean {
  return normalize(typeDir) in TAXONOMY
}

export function knownTypeDirs(): string[] {
  return Object.keys(TAXONOMY)
}
