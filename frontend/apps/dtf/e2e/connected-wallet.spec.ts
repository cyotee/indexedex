import { test, expect, ANVIL_ACCOUNT_0, DEFAULT_E2E_CHAIN_ID } from './wallet/fixture'
import { prepareLocalChain, connectInjectedWallet } from './helpers/connect'

/**
 * UI + connected wallet smoke (injected EIP-1193, not MetaMask).
 * Defaults to Robinhood chain 4663.
 */
test.describe('Connected wallet UI (DTF)', () => {
  test('injects wallet provider before load', async ({ walletPage }) => {
    await walletPage.goto('/')
    const hasProvider = await walletPage.evaluate(() => {
      const eth = (window as any).ethereum
      return Boolean(eth?.isMetaMask && typeof eth.request === 'function')
    })
    expect(hasProvider).toBe(true)

    const accounts = await walletPage.evaluate(async () => {
      return (window as any).ethereum.request({ method: 'eth_requestAccounts' })
    })
    expect(accounts[0]?.toLowerCase()).toBe(ANVIL_ACCOUNT_0.address.toLowerCase())

    const chainIdHex = await walletPage.evaluate(async () => {
      return (window as any).ethereum.request({ method: 'eth_chainId' })
    })
    expect(Number.parseInt(chainIdHex, 16)).toBe(DEFAULT_E2E_CHAIN_ID)
  })

  test('Connect Wallet uses injected provider and shows truncated address', async ({
    walletPage,
    walletAddress,
  }) => {
    await prepareLocalChain(walletPage)
    const short = walletAddress.slice(0, 6)

    if (await walletPage.getByText(new RegExp(short, 'i')).first().isVisible().catch(() => false)) {
      return
    }

    await connectInjectedWallet(walletPage)
    await expect(walletPage.getByText(new RegExp(short, 'i')).first()).toBeVisible({
      timeout: 25_000,
    })
  })

  test('Earn is reachable with wallet provider present', async ({ walletPage }) => {
    await prepareLocalChain(walletPage)
    await walletPage.goto('/earn')
    await expect(walletPage.getByRole('heading', { name: /Earn/i })).toBeVisible()
    const body = await walletPage.locator('body').innerText()
    expect(body.toLowerCase()).toMatch(/earn|preferred|registry|strateg|product/)
  })
})

test.describe('Shell without requiring chain', () => {
  test('primary nav exposes Earn Swap Portfolio Token', async ({ walletPage }) => {
    await walletPage.goto('/')
    const nav = walletPage.getByRole('navigation')
    await expect(nav.getByRole('link', { name: 'Earn', exact: true })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Swap', exact: true })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Portfolio', exact: true })).toBeVisible()
    await expect(nav.getByRole('link', { name: 'Token', exact: true })).toBeVisible()
  })
})
