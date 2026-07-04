// Menu definitions for UI dropdowns. Each menu names a sequence of Token List
// inclusions; the consumer (tokenlists.ts) resolves those lists against the
// active chain id and renders one option per matching token.
//
// Adding a new menu = add an entry here.
// Adding a new source for an existing menu = add a row to fromLists.
//
// No platform-derived fallbacks. If an entry should appear in a menu, it must
// be present in one of the listed Token Lists.

/**
 * Discriminator carried on each rendered option. Used by downstream code to
 * route swap / batch / vault logic. Superset of PoolOption['type'] and
 * TokenOption['type'].
 */
export type OptionType = 'token' | 'lp' | 'vault' | 'balancer'

export interface MenuListInclude {
  /** Matches TokenListRef.id in tokenlistRegistry.ts. */
  listId: string
  /** Optional tag filter — only entries with at least one matching tag are included. */
  includeTags?: string[]
  /** Appended to the rendered label in parentheses (e.g. "Vault" -> "Foo (Vault)"). */
  labelSuffix?: string
  /** Routing discriminator. */
  type: OptionType
}

export interface MenuConfig {
  fromLists: MenuListInclude[]
}

export const MENU_CONFIG = {
  // The Select Pool dropdown on /swap and /batch-swap.
  // Spec: Balancer V3 pools, Standard Exchange (strategy) Vaults, plus the
  // WETH sentinel for wrap/unwrap. No ERC4626 vaults, no Protocol DETFs —
  // those are not valid swap routes through the Standard Exchange Router.
  'pool-select': {
    fromLists: [
      { listId: 'base-tokens', includeTags: ['wrapUnwrap'], labelSuffix: 'Wrap/Unwrap', type: 'balancer' },
      { listId: 'balancer-v3-pools', type: 'balancer' },
      { listId: 'strategy-vaults', labelSuffix: 'Vault', type: 'vault' },
    ],
  },
  // Token In / Token Out dropdowns on /swap, /batch-swap, /detf.
  // Spec: Tokens, ERC4626 Vaults, Standard Exchange Vaults, Protocol DETFs
  // (pool legs such as CHIR on Balancer V3 pools). ETH is a sentinel prepend
  // by the consumer. No LP tokens, no seigniorage DETFs in these menus.
  'token-select': {
    fromLists: [
      { listId: 'base-tokens', type: 'token' },
      { listId: 'erc4626-vaults', type: 'vault' },
      { listId: 'strategy-vaults', type: 'vault' },
      { listId: 'protocol-detfs', type: 'vault' },
    ],
  },
  // Vault selector on /vaults — only Pachira strategy vaults.
  'vaults-page': {
    fromLists: [
      { listId: 'strategy-vaults', type: 'vault' },
    ],
  },
  // Earn catalog sources (merged in loadEarnProducts; menus kept for list-driven access).
  'earn-strategy-vaults': {
    fromLists: [{ listId: 'strategy-vaults', type: 'vault' }],
  },
  'earn-protocol-detfs': {
    fromLists: [{ listId: 'protocol-detfs', type: 'vault' }],
  },
  'earn-seigniorage-detfs': {
    fromLists: [{ listId: 'seigniorage-detfs', type: 'vault' }],
  },
  // DETF picker on /detf — only seigniorage DETFs.
  'seigniorage-detfs-page': {
    fromLists: [
      { listId: 'seigniorage-detfs', type: 'vault' },
    ],
  },
  // /token-info — every chain-keyed token bucket merged into one balance grid.
  'token-info': {
    fromLists: [
      { listId: 'base-tokens', type: 'token' },
      { listId: 'erc4626-vaults', type: 'vault' },
      { listId: 'seigniorage-detfs', type: 'vault' },
      { listId: 'protocol-detfs', type: 'vault' },
      { listId: 'strategy-vaults', type: 'vault' },
      { listId: 'uni-v2-pools', type: 'lp' },
      { listId: 'aerodrome-pools', type: 'lp' },
      { listId: 'balancer-v3-pools', type: 'balancer' },
    ],
  },
} satisfies Record<string, MenuConfig>

export type MenuId = keyof typeof MENU_CONFIG
