import type { TokenList, TokenListRef } from './tokenlistCompose'
import type { DeploymentEnvironment } from './addressArtifacts'
import { CHAIN_ID_BASE_SEPOLIA, CHAIN_ID_SEPOLIA } from './addressArtifacts'

// sepolia (live)
import sepoliaBaseTokens from '../addresses/sepolia/base-tokens.tokenlist.json'
import sepoliaBalancerV3Pools from '../addresses/sepolia/balancer-v3-pools.tokenlist.json'
import sepoliaUniV2Pools from '../addresses/sepolia/uni-v2-pools.tokenlist.json'
import sepoliaAerodromePools from '../addresses/sepolia/aerodrome-pools.tokenlist.json'
import sepoliaStrategyVaults from '../addresses/sepolia/strategy-vaults.tokenlist.json'
import sepoliaErc4626Vaults from '../addresses/sepolia/erc4626-vaults.tokenlist.json'

// supersim_sepolia / ethereum
import supersimEthBaseTokens from '../addresses/supersim_sepolia/ethereum/base-tokens.tokenlist.json'
import supersimEthBalancerV3Pools from '../addresses/supersim_sepolia/ethereum/balancer-v3-pools.tokenlist.json'
import supersimEthUniV2Pools from '../addresses/supersim_sepolia/ethereum/uni-v2-pools.tokenlist.json'
import supersimEthStrategyVaults from '../addresses/supersim_sepolia/ethereum/strategy-vaults.tokenlist.json'
import supersimEthErc4626Vaults from '../addresses/supersim_sepolia/ethereum/erc4626-vaults.tokenlist.json'
import supersimEthProtocolDetfs from '../addresses/supersim_sepolia/ethereum/protocol-detfs.tokenlist.json'

// supersim_sepolia / base
import supersimBaseBaseTokens from '../addresses/supersim_sepolia/base/base-tokens.tokenlist.json'
import supersimBaseBalancerV3Pools from '../addresses/supersim_sepolia/base/balancer-v3-pools.tokenlist.json'
import supersimBaseUniV2Pools from '../addresses/supersim_sepolia/base/uni-v2-pools.tokenlist.json'
import supersimBaseAerodromePools from '../addresses/supersim_sepolia/base/aerodrome-pools.tokenlist.json'
import supersimBaseStrategyVaults from '../addresses/supersim_sepolia/base/strategy-vaults.tokenlist.json'
import supersimBaseErc4626Vaults from '../addresses/supersim_sepolia/base/erc4626-vaults.tokenlist.json'
import supersimBaseProtocolDetfs from '../addresses/supersim_sepolia/base/protocol-detfs.tokenlist.json'

// public_sepolia / ethereum
import publicEthBaseTokens from '../addresses/public_sepolia/ethereum/base-tokens.tokenlist.json'
import publicEthBalancerV3Pools from '../addresses/public_sepolia/ethereum/balancer-v3-pools.tokenlist.json'
import publicEthUniV2Pools from '../addresses/public_sepolia/ethereum/uni-v2-pools.tokenlist.json'
import publicEthStrategyVaults from '../addresses/public_sepolia/ethereum/strategy-vaults.tokenlist.json'
import publicEthErc4626Vaults from '../addresses/public_sepolia/ethereum/erc4626-vaults.tokenlist.json'
import publicEthProtocolDetfs from '../addresses/public_sepolia/ethereum/protocol-detfs.tokenlist.json'

// local_testing / anvil_single
// Only buckets that the staged Solidity scripts currently emit fragments for are
// imported. Add more imports here when migrating additional scripts.
import localTestingBaseTokens from '../addresses/local_testing/anvil_single/base-tokens.tokenlist.json'
import localTestingUniV2Pools from '../addresses/local_testing/anvil_single/uni-v2-pools.tokenlist.json'
import localTestingStrategyVaults from '../addresses/local_testing/anvil_single/strategy-vaults.tokenlist.json'

// public_sepolia / base
import publicBaseBaseTokens from '../addresses/public_sepolia/base/base-tokens.tokenlist.json'
import publicBaseBalancerV3Pools from '../addresses/public_sepolia/base/balancer-v3-pools.tokenlist.json'
import publicBaseUniV2Pools from '../addresses/public_sepolia/base/uni-v2-pools.tokenlist.json'
import publicBaseAerodromePools from '../addresses/public_sepolia/base/aerodrome-pools.tokenlist.json'
import publicBaseStrategyVaults from '../addresses/public_sepolia/base/strategy-vaults.tokenlist.json'
import publicBaseErc4626Vaults from '../addresses/public_sepolia/base/erc4626-vaults.tokenlist.json'

type ChainRegistry = Partial<Record<11155111 | 84532, TokenListRef[]>>

// Priorities: lower wins on tie since `composeLists` sorts ascending then overwrites.
// Using priority 50 for everything means later registrations overwrite earlier ones.
const ref = (id: string, list: unknown, priority = 50): TokenListRef => ({
  id,
  priority,
  list: list as TokenList,
})

export const LIST_REGISTRY: Partial<Record<DeploymentEnvironment, ChainRegistry>> = {
  sepolia: {
    [CHAIN_ID_SEPOLIA]: [
      ref('base-tokens', sepoliaBaseTokens),
      ref('balancer-v3-pools', sepoliaBalancerV3Pools),
      ref('uni-v2-pools', sepoliaUniV2Pools),
      ref('aerodrome-pools', sepoliaAerodromePools),
      ref('strategy-vaults', sepoliaStrategyVaults),
      ref('erc4626-vaults', sepoliaErc4626Vaults),
    ],
  },
  supersim_sepolia: {
    [CHAIN_ID_SEPOLIA]: [
      ref('base-tokens', supersimEthBaseTokens),
      ref('balancer-v3-pools', supersimEthBalancerV3Pools),
      ref('uni-v2-pools', supersimEthUniV2Pools),
      ref('strategy-vaults', supersimEthStrategyVaults),
      ref('erc4626-vaults', supersimEthErc4626Vaults),
      ref('protocol-detfs', supersimEthProtocolDetfs),
    ],
    [CHAIN_ID_BASE_SEPOLIA]: [
      ref('base-tokens', supersimBaseBaseTokens),
      ref('balancer-v3-pools', supersimBaseBalancerV3Pools),
      ref('uni-v2-pools', supersimBaseUniV2Pools),
      ref('aerodrome-pools', supersimBaseAerodromePools),
      ref('strategy-vaults', supersimBaseStrategyVaults),
      ref('erc4626-vaults', supersimBaseErc4626Vaults),
      ref('protocol-detfs', supersimBaseProtocolDetfs),
    ],
  },
  local_testing: {
    [CHAIN_ID_SEPOLIA]: [
      ref('base-tokens', localTestingBaseTokens),
      ref('uni-v2-pools', localTestingUniV2Pools),
      ref('strategy-vaults', localTestingStrategyVaults),
    ],
  },
  public_sepolia: {
    [CHAIN_ID_SEPOLIA]: [
      ref('base-tokens', publicEthBaseTokens),
      ref('balancer-v3-pools', publicEthBalancerV3Pools),
      ref('uni-v2-pools', publicEthUniV2Pools),
      ref('strategy-vaults', publicEthStrategyVaults),
      ref('erc4626-vaults', publicEthErc4626Vaults),
      ref('protocol-detfs', publicEthProtocolDetfs),
    ],
    [CHAIN_ID_BASE_SEPOLIA]: [
      ref('base-tokens', publicBaseBaseTokens),
      ref('balancer-v3-pools', publicBaseBalancerV3Pools),
      ref('uni-v2-pools', publicBaseUniV2Pools),
      ref('aerodrome-pools', publicBaseAerodromePools),
      ref('strategy-vaults', publicBaseStrategyVaults),
      ref('erc4626-vaults', publicBaseErc4626Vaults),
    ],
  },
}

export function getListRefs(
  environment: DeploymentEnvironment,
  chainId: number
): TokenListRef[] {
  const env = LIST_REGISTRY[environment]
  if (!env) return []
  return (env as Record<number, TokenListRef[]>)[chainId] ?? []
}
