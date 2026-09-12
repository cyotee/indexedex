export type DetfFamily = 'one-vault' | 'quad'

export type DetfLeg = {
  role: string
  symbol: string
  name: string
  address: `0x${string}`
}

export type DetfProfile = {
  symbols: string[]
  addresses: `0x${string}`[]
  family: DetfFamily
  kicker: string
  blurb: string
  shape: string
  /** Scripted first bond already ran on this listed instance. */
  firstBonded: boolean
  openedHow: string
  legs: DetfLeg[]
}

const PROTOCOL_DTF_DETF: DetfProfile = {
  symbols: ['DTF-DETF', 'UP', 'TTUP', 'TTCHIR'],
  addresses: ['0xb5F0543DD9D758F8DD577856A5Df848674af335d'],
  family: 'one-vault',
  kicker: 'Protocol DETF',
  shape: 'One vault',
  firstBonded: true,
  openedHow: 'Opened by the first bond: 10 TTWETH, 1 day lock. Later bonds still work.',
  blurb:
    'One token over one vault: DTF paired with TTWETH. Protocol fees can accrue here. That is not a promised yield. The first bond already opened it. Primary issuance and redemption follow the on-chain price thresholds. Exchanges use the reserve pool outside those thresholds. Stake funded DETF for sDETF and unstake it 1:1.',
  legs: [
    {
      role: 'Pair token',
      symbol: 'TTWETH',
      name: 'Test Token WETH',
      address: '0xd97e3BCF599A5dbc893387680868d4Ad76E81206',
    },
    {
      role: 'Underlying vault',
      symbol: 'SE-DTF-TTWETH',
      name: 'Test SE DTF/TTWETH',
      address: '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
    },
    {
      role: 'Claim token',
      symbol: 'DTF-CLAIM',
      name: 'Test Claim DTF-CLAIM',
      address: '0xdD2E0A3D11E55d10D3440AFa3fcF102992977E7e',
    },
  ],
}

const DOUBLE_DOLLAR: DetfProfile = {
  symbols: ['$$DETF', 'TTDOL-Q'],
  addresses: ['0x7497BB4cCd882f2EEA2843bb3573B1FfE2dDc0E5'],
  family: 'quad',
  kicker: 'Double Dollar',
  shape: 'Three similar vaults, grouped',
  firstBonded: true,
  openedHow:
    'Opened by the first bond: 10 TTUSDE, 10 TTUSDG, and 10 TTWETH. Capital token TTUSDG. Later bonds still work.',
  blurb:
    'One token over three vaults. Each vault holds a pair of test tokens: TTUSDE/TTWETH, TTUSDG/TTWETH, and TTUSDG/TTUSDE. Those are not official dollars. The first bond already opened it. Primary mint and burn thresholds apply versus each pair, with reserve swaps outside those thresholds. Supported redemption tokens appear in the route selector.',
  legs: [
    {
      role: 'Pair token',
      symbol: 'TTUSDE',
      name: 'Test Token USDE',
      address: '0x00a7413b2d28BAfe10d9182299Ad6d58F90E2665',
    },
    {
      role: 'Pair token',
      symbol: 'TTUSDG',
      name: 'Test Token USDG',
      address: '0x2f1E7e0B6dd21f0f3E3E4218a94918d8DF9e3769',
    },
    {
      role: 'Pair token',
      symbol: 'TTWETH',
      name: 'Test Token WETH',
      address: '0xd97e3BCF599A5dbc893387680868d4Ad76E81206',
    },
    {
      role: 'Vault',
      symbol: 'SE-TTUSDE-TTWETH',
      name: 'Test SE TTUSDE/TTWETH',
      address: '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    },
    {
      role: 'Vault',
      symbol: 'SE-TTUSDG-TTWETH',
      name: 'Test SE TTUSDG/TTWETH',
      address: '0x54094E08f1eb96C74c9A80A3f2cf6fFaF6720DcC',
    },
    {
      role: 'Vault',
      symbol: 'SE-TTUSDG-TTUSDE',
      name: 'Test SE TTUSDG/TTUSDE',
      address: '0x5c07271240B4ddaE69eBCE90c2CD0774a42B781b',
    },
    {
      role: 'Claim token',
      symbol: 'I$$DETF',
      name: 'Infinite Double Dollar',
      address: '0x3f26691aFE755964cDfe1481109c10bd9c43Ab08',
    },
  ],
}

export const DETF_PROFILES: readonly DetfProfile[] = [PROTOCOL_DTF_DETF, DOUBLE_DOLLAR]

export function profileFor(address: string, symbol?: string): DetfProfile | undefined {
  const key = address.trim().toLowerCase()
  if (key) {
    const byAddr = DETF_PROFILES.find((p) => p.addresses.some((a) => a.toLowerCase() === key))
    if (byAddr) return byAddr
  }
  const sym = (symbol ?? '').trim()
  if (!sym) return undefined
  return DETF_PROFILES.find((p) => p.symbols.some((s) => s.toLowerCase() === sym.toLowerCase()))
}

export function pairAddresses(profile: DetfProfile): `0x${string}`[] {
  return profile.legs.filter((l) => l.role === 'Pair token').map((l) => l.address)
}
