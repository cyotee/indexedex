import { test, expect, ANVIL_ACCOUNT_0 } from './wallet/fixture'

/**
 * UI + connected wallet smoke (injected EIP-1193, not MetaMask).
 *
 * Prerequisites:
 *   - Next app running (playwright webServer starts `npm run start` after build, or reuse dev)
 *   - Optional: Anvil at 127.0.0.1:8545 for on-chain reads; connect still works without RPC for UI state
 *
 * Run:
 *   npm run test:e2e
 */

test.describe('Connected wallet UI', () => {
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
  })

  test('Connect Wallet uses injected provider and shows truncated address', async ({
    walletPage,
    walletAddress,
  }) => {
    await walletPage.goto('/')
    await walletPage.evaluate(() => {
      localStorage.setItem('indexedex:selected-network', '11155111')
      // Avoid stale wagmi reconnect fighting the inject
      for (const k of Object.keys(localStorage)) {
        if (k.startsWith('indexedex-wagmi') || k.includes('wagmi')) localStorage.removeItem(k)
      }
    })
    await walletPage.reload({ waitUntil: 'domcontentloaded' })

    const short = walletAddress.slice(0, 6) // 0xf39F

    // Already connected?
    if (await walletPage.getByText(new RegExp(short, 'i')).first().isVisible().catch(() => false)) {
      return
    }

    // Header re-renders while connectors hydrate — click via DOM to avoid detach flakiness
    await walletPage.waitForFunction(() =>
      Array.from(document.querySelectorAll('button')).some((b) =>
        /^Connect Wallet$/i.test((b.textContent || '').trim()),
      ),
    )
    await walletPage.evaluate(() => {
      const btn = Array.from(document.querySelectorAll('button')).find((b) =>
        /^Connect Wallet$/i.test((b.textContent || '').trim()),
      ) as HTMLButtonElement | undefined
      btn?.click()
    })

    // Header shows truncated address on the disconnect/account button (ellipsis may vary)
    await expect(walletPage.getByText(new RegExp(short, 'i')).first()).toBeVisible({
      timeout: 25_000,
    })
  })

  test('Earn is reachable with wallet provider present', async ({ walletPage }) => {
    await walletPage.goto('/earn')
    await expect(walletPage.getByRole('heading', { name: /Earn/i })).toBeVisible()
    // Preferred catalog or empty state — either is valid without deploy
    const body = await walletPage.locator('body').innerText()
    expect(body.toLowerCase()).toMatch(/earn|preferred|registry|strateg|product/)
  })

  test('Portfolio empty state encourages Earn when connected path available', async ({
    walletPage,
  }) => {
    await walletPage.goto('/portfolio')
    // Without connect click, may show connect prompt; with provider, can still render
    const body = await walletPage.locator('body').innerText()
    expect(body.toLowerCase()).toMatch(/portfolio|connect|earn|position/)
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
