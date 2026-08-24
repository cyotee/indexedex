export const VAULT_TOKENS_ABI = [
  {
    type: 'function',
    name: 'vaultTokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: 'tokens_', type: 'address[]' }],
  },
] as const

export const ERC20_META_ABI = [
  { type: 'function', name: 'symbol', stateMutability: 'view', inputs: [], outputs: [{ type: 'string' }] },
  { type: 'function', name: 'name', stateMutability: 'view', inputs: [], outputs: [{ type: 'string' }] },
] as const

export const V3_FACTORY_ABI = [
  {
    type: 'function',
    name: 'getPool',
    stateMutability: 'view',
    inputs: [
      { name: 'tokenA', type: 'address' },
      { name: 'tokenB', type: 'address' },
      { name: 'fee', type: 'uint24' },
    ],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'createPool',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenA', type: 'address' },
      { name: 'tokenB', type: 'address' },
      { name: 'fee', type: 'uint24' },
    ],
    outputs: [{ name: 'pool', type: 'address' }],
  },
  {
    type: 'function',
    name: 'feeAmountTickSpacing',
    stateMutability: 'view',
    inputs: [{ name: 'fee', type: 'uint24' }],
    outputs: [{ type: 'int24' }],
  },
] as const

export const V3_POOL_ABI = [
  {
    type: 'function',
    name: 'slot0',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'sqrtPriceX96', type: 'uint160' },
      { name: 'tick', type: 'int24' },
      { name: 'observationIndex', type: 'uint16' },
      { name: 'observationCardinality', type: 'uint16' },
      { name: 'observationCardinalityNext', type: 'uint16' },
      { name: 'feeProtocol', type: 'uint8' },
      { name: 'unlocked', type: 'bool' },
    ],
  },
  {
    type: 'function',
    name: 'initialize',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'sqrtPriceX96', type: 'uint160' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'token0',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'token1',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const

export const V4_POOL_KEY_COMPONENTS = [
  { name: 'currency0', type: 'address' },
  { name: 'currency1', type: 'address' },
  { name: 'fee', type: 'uint24' },
  { name: 'tickSpacing', type: 'int24' },
  { name: 'hooks', type: 'address' },
] as const

export const V4_STATE_VIEW_ABI = [
  {
    type: 'function',
    name: 'getSlot0',
    stateMutability: 'view',
    inputs: [{ name: 'poolId', type: 'bytes32' }],
    outputs: [
      { name: 'sqrtPriceX96', type: 'uint160' },
      { name: 'tick', type: 'int24' },
      { name: 'protocolFee', type: 'uint24' },
      { name: 'lpFee', type: 'uint24' },
    ],
  },
] as const

export const V4_POOL_MANAGER_ABI = [
  {
    type: 'function',
    name: 'initialize',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'key', type: 'tuple', components: V4_POOL_KEY_COMPONENTS },
      { name: 'sqrtPriceX96', type: 'uint160' },
    ],
    outputs: [{ name: 'tick', type: 'int24' }],
  },
] as const

export const V4_SE_PKG_ABI = [
  {
    type: 'function',
    name: 'deployVault',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'poolKey', type: 'tuple', components: V4_POOL_KEY_COMPONENTS },
      { name: 'widthMultiplier', type: 'uint24' },
    ],
    outputs: [{ name: 'vault', type: 'address' }],
  },
] as const

export const MORPHO_MARKET_PARAMS_COMPONENTS = [
  { name: 'loanToken', type: 'address' },
  { name: 'collateralToken', type: 'address' },
  { name: 'oracle', type: 'address' },
  { name: 'irm', type: 'address' },
  { name: 'lltv', type: 'uint256' },
] as const

export const MORPHO_ABI = [
  {
    type: 'function',
    name: 'createMarket',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'marketParams', type: 'tuple', components: MORPHO_MARKET_PARAMS_COMPONENTS },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'market',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [
      { name: 'totalSupplyAssets', type: 'uint128' },
      { name: 'totalSupplyShares', type: 'uint128' },
      { name: 'totalBorrowAssets', type: 'uint128' },
      { name: 'totalBorrowShares', type: 'uint128' },
      { name: 'lastUpdate', type: 'uint128' },
      { name: 'fee', type: 'uint128' },
    ],
  },
  {
    type: 'function',
    name: 'isIrmEnabled',
    stateMutability: 'view',
    inputs: [{ name: 'irm', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    type: 'function',
    name: 'isLltvEnabled',
    stateMutability: 'view',
    inputs: [{ name: 'lltv', type: 'uint256' }],
    outputs: [{ type: 'bool' }],
  },
] as const

export const MORPHO_SE_PKG_ABI = [
  {
    type: 'function',
    name: 'deployVault',
    stateMutability: 'nonpayable',
    inputs: [
      {
        name: 'args',
        type: 'tuple',
        components: [
          { name: 'morpho', type: 'address' },
          { name: 'marketParams', type: 'tuple', components: MORPHO_MARKET_PARAMS_COMPONENTS },
        ],
      },
    ],
    outputs: [{ name: 'vault', type: 'address' }],
  },
] as const

export const MORPHO_SE_INFO_ABI = [
  {
    type: 'function',
    name: 'marketParams',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'loanToken', type: 'address' },
      { name: 'collateralToken', type: 'address' },
      { name: 'oracle', type: 'address' },
      { name: 'irm', type: 'address' },
      { name: 'lltv', type: 'uint256' },
    ],
  },
] as const

export const V3_SE_PKG_ABI = [
  {
    type: 'function',
    name: 'deployVault',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'pool', type: 'address' },
      { name: 'widthMultiplier', type: 'uint24' },
    ],
    outputs: [{ name: 'vault', type: 'address' }],
  },
] as const

export const NEW_VAULT_EVENT = {
  type: 'event',
  name: 'NewVault',
  inputs: [
    { name: 'vault', type: 'address', indexed: true },
    { name: 'package', type: 'address', indexed: true },
    { name: 'vaultFeeIds', type: 'bytes32', indexed: false },
    { name: 'contentsId', type: 'bytes32', indexed: true },
    { name: 'vaultTypes', type: 'bytes4[]', indexed: false },
    { name: 'tokens', type: 'address[]', indexed: false },
  ],
} as const

export const PACKAGE_NAME_ABI = [
  {
    type: 'function',
    name: 'packageName',
    stateMutability: 'view',
    inputs: [{ name: 'pkg', type: 'address' }],
    outputs: [{ type: 'string' }],
  },
] as const

/** Registry queries used to find an SE vault for a token pair. */
export const VAULT_REGISTRY_SE_ABI = [
  {
    type: 'function',
    name: 'vaultsOfPkgOfTokens',
    stateMutability: 'view',
    inputs: [
      { name: 'pkg', type: 'address' },
      { name: 'tokens_', type: 'address[]' },
    ],
    outputs: [{ name: 'vaults_', type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'vaultsOfTokens',
    stateMutability: 'view',
    inputs: [{ name: 'tokens_', type: 'address[]' }],
    outputs: [{ name: 'vaultsOfTokens_', type: 'address[]' }],
  },
] as const
