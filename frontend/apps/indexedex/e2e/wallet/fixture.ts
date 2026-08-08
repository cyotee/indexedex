import { test as base, expect } from '@playwright/test'
import {
  ANVIL_ACCOUNT_0,
  installInjectedWallet,
  DEFAULT_E2E_CHAIN_ID,
  DEFAULT_E2E_RPC,
} from './injectWallet'

type WalletFixture = {
  /** Page with window.ethereum already injected (Anvil account #0). */
  walletPage: import('@playwright/test').Page
  walletAddress: `0x${string}`
}

/**
 * Prefer this fixture for any test that needs a connected (or connectable) wallet.
 * Does not automate MetaMask — injects EIP-1193 so wagmi's injected connector works.
 */
export const test = base.extend<WalletFixture>({
  walletPage: async ({ page }, use) => {
    await installInjectedWallet(page, {
      rpcUrl: DEFAULT_E2E_RPC,
      chainId: DEFAULT_E2E_CHAIN_ID,
      privateKey: ANVIL_ACCOUNT_0.privateKey,
    })
    await use(page)
  },
  walletAddress: async ({}, use) => {
    await use(ANVIL_ACCOUNT_0.address)
  },
})

export { expect, ANVIL_ACCOUNT_0, DEFAULT_E2E_CHAIN_ID, DEFAULT_E2E_RPC }
