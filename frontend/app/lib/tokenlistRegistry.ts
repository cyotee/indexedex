import type { TokenList, TokenListRef } from './tokenlistCompose'

// Chain 11155111 — Ethereum Sepolia (also matches local Anvil forks of Sepolia).
import ethBaseTokens from '../addresses/chain/11155111/base-tokens.tokenlist.json'
import ethBalancerV3Pools from '../addresses/chain/11155111/balancer-v3-pools.tokenlist.json'
import ethUniV2Pools from '../addresses/chain/11155111/uni-v2-pools.tokenlist.json'
import ethStrategyVaults from '../addresses/chain/11155111/strategy-vaults.tokenlist.json'
import ethProtocolDetfs from '../addresses/chain/11155111/protocol-detfs.tokenlist.json'

// Chain 84532 — Base Sepolia.
import baseBaseTokens from '../addresses/chain/84532/base-tokens.tokenlist.json'
import baseBalancerV3Pools from '../addresses/chain/84532/balancer-v3-pools.tokenlist.json'
import baseUniV2Pools from '../addresses/chain/84532/uni-v2-pools.tokenlist.json'
import baseAerodromePools from '../addresses/chain/84532/aerodrome-pools.tokenlist.json'
import baseStrategyVaults from '../addresses/chain/84532/strategy-vaults.tokenlist.json'
import baseErc4626Vaults from '../addresses/chain/84532/erc4626-vaults.tokenlist.json'
import baseProtocolDetfs from '../addresses/chain/84532/protocol-detfs.tokenlist.json'

const ref = (id: string, list: unknown, priority = 50): TokenListRef => ({
  id,
  priority,
  list: list as TokenList,
})

/**
 * Token Lists indexed by chain id. The active chain id from the wallet (or the
 * nav-bar chain selector) drives which entries appear in the dropdowns. There is
 * no "environment" layer — local Anvil forks of Sepolia and live Sepolia both
 * write to chain/11155111/ and the latest deploy wins.
 */
export const LIST_REGISTRY: Record<number, TokenListRef[]> = {
  11155111: [
    ref('base-tokens', ethBaseTokens),
    ref('balancer-v3-pools', ethBalancerV3Pools),
    ref('uni-v2-pools', ethUniV2Pools),
    ref('strategy-vaults', ethStrategyVaults),
    ref('protocol-detfs', ethProtocolDetfs),
  ],
  84532: [
    ref('base-tokens', baseBaseTokens),
    ref('balancer-v3-pools', baseBalancerV3Pools),
    ref('uni-v2-pools', baseUniV2Pools),
    ref('aerodrome-pools', baseAerodromePools),
    ref('strategy-vaults', baseStrategyVaults),
    ref('erc4626-vaults', baseErc4626Vaults),
    ref('protocol-detfs', baseProtocolDetfs),
  ],
}

export function getListRefs(chainId: number): TokenListRef[] {
  return LIST_REGISTRY[chainId] ?? []
}
