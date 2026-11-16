import type { AggregatorConfig } from './scripts/node/src/types.js'

// Map each deploy directory to the chain id its fragments target.
// Outputs go to frontend/app/addresses/chain/<chainId>/<bucket>.tokenlist.json.
// A given chain id can appear multiple times; later inputs override earlier ones
// (last-writer-wins per (chainId, bucket)).
export const config: AggregatorConfig = {
  inputRoot: 'deployments',
  outputRoot: 'frontend/app/addresses',
  inputs: [
    { inputDir: 'local_testing/anvil_single', chainId: 11155111 },
    { inputDir: 'supersim_sepolia/ethereum', chainId: 11155111 },
    { inputDir: 'supersim_sepolia/base', chainId: 84532 },
  ],
  buckets: [
    {
      id: 'base-tokens',
      name: 'Indexedex Base Tokens',
      keywords: ['indexedex', 'tokens'],
      includeTypeDirs: ['tokens'],
      defaultTags: [],
      tagDefinitions: {
        token: { name: 'Token', description: 'ERC20 token' },
        testToken: { name: 'Test Token', description: 'Test ERC20' },
        weth: { name: 'WETH', description: 'Wrapped Ether' },
        wrapUnwrap: { name: 'Wrap Unwrap', description: 'Pool select wrap unwrap entry' },
      },
    },
    {
      id: 'balancer-v3-pools',
      name: 'Indexedex Balancer V3 Pools',
      keywords: ['indexedex', 'balancer', 'pool'],
      includeTypeDirs: ['pools/balancerV3'],
      defaultTags: [],
      tagDefinitions: {
        pool: { name: 'Pool', description: 'AMM pool' },
        balancer: { name: 'Balancer', description: 'Balancer pool' },
        balV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
      },
    },
    {
      id: 'uni-v2-pools',
      name: 'Indexedex Uniswap V2 Pools',
      keywords: ['indexedex', 'uniswap', 'pool'],
      includeTypeDirs: ['pools/uniV2'],
      defaultTags: [],
      tagDefinitions: {
        pool: { name: 'Pool', description: 'AMM pool' },
        uniV2: { name: 'Uniswap V2', description: 'Uniswap V2 pool LP token' },
      },
    },
    {
      id: 'aerodrome-pools',
      name: 'Indexedex Aerodrome Pools',
      keywords: ['indexedex', 'aerodrome', 'pool'],
      includeTypeDirs: ['pools/aerodrome'],
      defaultTags: [],
      tagDefinitions: {
        pool: { name: 'Pool', description: 'AMM pool' },
        aero: { name: 'Aerodrome', description: 'Aerodrome pool' },
      },
    },
    {
      id: 'strategy-vaults',
      name: 'Indexedex Strategy Vaults',
      keywords: ['indexedex', 'vault'],
      includeTypeDirs: ['vaults/strategy'],
      defaultTags: [],
      tagDefinitions: {
        vault: { name: 'Vault', description: 'Vault share token' },
        strat: { name: 'Strategy Vault', description: 'Pachira strategy vault' },
      },
    },
    {
      id: 'erc4626-vaults',
      name: 'Indexedex ERC4626 Vaults',
      keywords: ['indexedex', 'vault', 'erc4626'],
      includeTypeDirs: ['vaults/erc4626'],
      defaultTags: [],
      tagDefinitions: {
        vault: { name: 'Vault', description: 'Vault share token' },
        erc4626: { name: 'ERC4626', description: 'ERC4626 compliant vault' },
      },
    },
    {
      id: 'protocol-detfs',
      name: 'Indexedex Protocol DETFs',
      keywords: ['indexedex', 'detf'],
      includeTypeDirs: ['vaults/protocolDetf'],
      defaultTags: [],
      tagDefinitions: {
        vault: { name: 'Vault', description: 'Vault share token' },
        detf: { name: 'Protocol DETF', description: 'Protocol decentralized ETF' },
      },
    },
  ],
}
