export const WEIGHTED_DETF_PKG_ARGS_COMPONENTS = [
  { name: 'name', type: 'string' },
  { name: 'symbol', type: 'string' },
  { name: 'pairTokens', type: 'address[]' },
  { name: 'standardExchanges', type: 'address[]' },
  { name: 'vaultShares', type: 'address[]' },
  { name: 'rateProviders', type: 'address[]' },
  { name: 'detfWeight', type: 'uint256' },
  { name: 'pairWeights', type: 'uint256[]' },
  { name: 'creationPairPerDetfWad', type: 'uint256[]' },
  { name: 'openingPairPerDetfWad', type: 'uint256[]' },
  { name: 'mintThreshold', type: 'uint256' },
  { name: 'burnThreshold', type: 'uint256' },
  { name: 'thresholdMode', type: 'uint8' },
  { name: 'expansionEpochLength', type: 'uint256' },
  { name: 'expansionClosureRatePerYearWad', type: 'uint256' },
  { name: 'expansionMaxCatchUpEpochs', type: 'uint256' },
  { name: 'creator', type: 'address' },
  { name: 'claimName', type: 'string' },
  { name: 'claimSymbol', type: 'string' },
  { name: 'bondName', type: 'string' },
  { name: 'bondSymbol', type: 'string' },
] as const

export const WEIGHTED_HOOK_ARGS_COMPONENTS = [
  { name: 'poolManager', type: 'address' },
  { name: 'feeOracle', type: 'address' },
  { name: 'n', type: 'uint8' },
  { name: 'tokens', type: 'address[]' },
  { name: 'weights', type: 'uint256[]' },
  { name: 'standardExchanges', type: 'address[]' },
  { name: 'rateProviders', type: 'address[]' },
  { name: 'ownerOnlyLiquidity', type: 'bool' },
  { name: 'owner', type: 'address' },
] as const

export const WEIGHTED_DETF_PKG_ABI = [
  {
    type: 'function',
    name: 'deployVault',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'args', type: 'tuple', components: WEIGHTED_DETF_PKG_ARGS_COMPONENTS },
      { name: 'mineNonce', type: 'uint256' },
    ],
    outputs: [{ name: 'vault', type: 'address' }],
  },
] as const

export const WEIGHTED_DETF_INFO_ABI = [
  {
    type: 'function',
    name: 'm',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'pairTokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'pairToken',
    stateMutability: 'view',
    inputs: [{ name: 'productIndex', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'standardExchanges',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'vaultShares',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'acceptedBondTokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address[]' }],
  },
] as const

export const WEIGHTED_BOND_ABI = [
  {
    type: 'function',
    name: 'bond',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIns', type: 'address[]' },
      { name: 'amountsIn', type: 'uint256[]' },
      { name: 'capitalToken', type: 'address' },
      { name: 'lockDuration', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'shares', type: 'uint256' },
    ],
  },
] as const

export const DETF_PKG_ARGS_COMPONENTS = [
  { name: 'name', type: 'string' },
  { name: 'symbol', type: 'string' },
  { name: 'standardExchangeVault', type: 'address' },
  { name: 'standardExchangeVaultShare', type: 'address' },
  { name: 'pairToken', type: 'address' },
  { name: 'creationPairPerDetfWad', type: 'uint256' },
  { name: 'openingPairPerDetfWad', type: 'uint256' },
  { name: 'mintThreshold', type: 'uint256' },
  { name: 'burnThreshold', type: 'uint256' },
  { name: 'thresholdMode', type: 'uint8' },
  { name: 'expansionEpochLength', type: 'uint256' },
  { name: 'expansionClosureRatePerYearWad', type: 'uint256' },
  { name: 'expansionMaxCatchUpEpochs', type: 'uint256' },
  { name: 'creator', type: 'address' },
  { name: 'claimName', type: 'string' },
  { name: 'claimSymbol', type: 'string' },
  { name: 'bondName', type: 'string' },
  { name: 'bondSymbol', type: 'string' },
] as const

export const CP_HOOK_ARGS_COMPONENTS = [
  { name: 'poolManager', type: 'address' },
  { name: 'feeOracle', type: 'address' },
  { name: 'standardExchange', type: 'address' },
  { name: 'pairToken', type: 'address' },
  { name: 'rawToken', type: 'address' },
  { name: 'ownerOnlyLiquidity', type: 'bool' },
  { name: 'owner', type: 'address' },
] as const

export const CP_DETF_PKG_ABI = [
  {
    type: 'function',
    name: 'deployVault',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'args', type: 'tuple', components: DETF_PKG_ARGS_COMPONENTS },
      { name: 'mineNonce', type: 'uint256' },
    ],
    outputs: [{ name: 'vault', type: 'address' }],
  },
  {
    type: 'function',
    name: 'calcSalt',
    stateMutability: 'pure',
    inputs: [{ name: 'pkgArgs', type: 'bytes' }],
    outputs: [{ type: 'bytes32' }],
  },
] as const

export const CP_HOOK_PKG_ABI = [
  {
    type: 'function',
    name: 'calcSalt',
    stateMutability: 'pure',
    inputs: [{ name: 'pkgArgs', type: 'bytes' }],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'requiredHookFlags',
    stateMutability: 'pure',
    inputs: [],
    outputs: [{ type: 'uint160' }],
  },
] as const

export const DIAMOND_FACTORY_ABI = [
  {
    type: 'function',
    name: 'calcAddress',
    stateMutability: 'view',
    inputs: [
      { name: 'pkg', type: 'address' },
      { name: 'pkgArgs', type: 'bytes' },
    ],
    outputs: [{ type: 'address' }],
  },
] as const

export const HOOK_FACTORY_ABI = [
  {
    type: 'function',
    name: 'PROXY_INIT_HASH',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
] as const

export const DETF_WIRE_ABI = [
  {
    type: 'function',
    name: 'reserveHook',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'pairToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'completeReserveBondNft',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'completeReserveClaim',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const

export const HOOK_STAGED_INIT_ABI = [
  {
    type: 'function',
    name: 'deployPair',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenA', type: 'address' },
      { name: 'tokenB', type: 'address' },
    ],
    outputs: [
      {
        name: 'key',
        type: 'tuple',
        components: [
          { name: 'currency0', type: 'address' },
          { name: 'currency1', type: 'address' },
          { name: 'fee', type: 'uint24' },
          { name: 'tickSpacing', type: 'int24' },
          { name: 'hooks', type: 'address' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'finalizeInitialization',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
] as const

export const DETF_BOND_ABI = [
  {
    type: 'function',
    name: 'bond',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'lockDuration', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'shares', type: 'uint256' },
    ],
  },
  {
    type: 'function',
    name: 'pairToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'standardExchangeVault',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'standardExchangeVaultShare',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'isReserveLive',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
] as const

export const FEE_ORACLE_BOND_ABI = [
  {
    type: 'function',
    name: 'bondTermsOfVault',
    stateMutability: 'view',
    inputs: [{ name: 'vault', type: 'address' }],
    outputs: [
      {
        name: 'bondTerms_',
        type: 'tuple',
        components: [
          { name: 'minLockDuration', type: 'uint256' },
          { name: 'maxLockDuration', type: 'uint256' },
          { name: 'minBonusPercentage', type: 'uint256' },
          { name: 'maxBonusPercentage', type: 'uint256' },
        ],
      },
    ],
  },
] as const
