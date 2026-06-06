// Menu definitions for UI dropdowns. Each menu names a sequence of Token List
// inclusions; the consumer (tokenlists.ts) resolves those lists against the
// active (env, chain) registry and renders one option per matching token.
//
// Adding a new menu = add an entry here.
// Adding a new source for an existing menu = add a row to fromLists.
//
// No platform-derived fallbacks. If an entry should appear in a menu, it must
// be present in one of the listed Token Lists.

import type { PoolOption } from './tokenlists'

export interface MenuListInclude {
  /** Matches TokenListRef.id in tokenlistRegistry.ts. */
  listId: string
  /** Optional tag filter — only entries with at least one matching tag are included. */
  includeTags?: string[]
  /** Appended to the rendered label in parentheses (e.g. "Vault" -> "Foo (Vault)"). */
  labelSuffix?: string
  /** PoolOption discriminator. Routes to swap/batch logic downstream. */
  type: NonNullable<PoolOption['type']>
}

export interface MenuConfig {
  fromLists: MenuListInclude[]
}

export const MENU_CONFIG = {
  'pool-select': {
    fromLists: [
      { listId: 'base-tokens', includeTags: ['wrapUnwrap'], labelSuffix: 'Wrap/Unwrap', type: 'balancer' },
      { listId: 'balancer-v3-pools', type: 'balancer' },
      { listId: 'strategy-vaults', labelSuffix: 'Vault', type: 'vault' },
      { listId: 'erc4626-vaults', labelSuffix: 'ERC4626', type: 'vault' },
      { listId: 'protocol-detfs', labelSuffix: 'Protocol DETF', type: 'vault' },
    ],
  },
} satisfies Record<string, MenuConfig>

export type MenuId = keyof typeof MENU_CONFIG
