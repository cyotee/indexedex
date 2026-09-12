import { test, expect } from '@playwright/test'
import { installInjectedWallet, ANVIL_ACCOUNT_0, ANVIL_ACCOUNT_1 } from './wallet/injectWallet'
import { connectInjectedWallet } from './helpers/connect'

async function openApp(page: import('@playwright/test').Page) {
  await page.goto('/learn')
  await expect(page.getByTestId('wallet-connect')).toBeVisible()
}

test('normal browser has no injected test wallet and opens a dismissible picker', async ({ page }) => {
  await openApp(page)
  expect(await page.evaluate(() => Boolean((window as any).ethereum))).toBe(false)
  await page.getByTestId('wallet-connect').click()
  await expect(page.getByRole('dialog')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Test Wallet', exact: true })).toHaveCount(0)
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.getByTestId('wallet-connect')).toBeVisible()
})

test('explicit selection connects, reconnects after reload, and opens account controls', async ({ page }) => {
  await installInjectedWallet(page)
  await openApp(page)
  const popups: unknown[] = []
  page.on('popup', (popup) => popups.push(popup))
  await page.getByTestId('wallet-connect').click()
  await expect(page.getByRole('button', { name: 'Test Wallet', exact: true })).toBeVisible()
  await expect(page.getByTestId('wallet-account')).toHaveCount(0)
  await page.getByRole('button', { name: 'Test Wallet', exact: true }).click()
  await expect(page.getByTestId('wallet-account')).toHaveAttribute('title', ANVIL_ACCOUNT_0.address)
  expect(popups).toHaveLength(0)
  await page.reload()
  await expect(page.getByTestId('wallet-account')).toBeVisible()
  await page.getByTestId('wallet-account').click()
  await expect(page.getByRole('button', { name: /copy address/i })).toBeVisible()
  await page.getByRole('button', { name: /disconnect/i }).click()
  await expect(page.getByTestId('wallet-connect')).toBeVisible()
  await page.reload()
  await expect(page.getByTestId('wallet-connect')).toBeVisible()
})

test('rejecting a connection does not try another provider or request a signature', async ({ page }) => {
  await installInjectedWallet(page)
  await openApp(page)
  await page.evaluate(() => {
    const eth = (window as any).ethereum
    const request = eth.request
    ;(window as any).__walletMethods = []
    eth.request = async (args: { method: string }) => {
      ;(window as any).__walletMethods.push(args.method)
      if (args.method === 'eth_requestAccounts') {
        return new Promise((_resolve, reject) => {
          ;(window as any).__rejectConnection = () => reject(Object.assign(new Error('User rejected the request.'), { code: 4001 }))
        })
      }
      return request(args)
    }
  })
  await page.getByTestId('wallet-connect').click()
  await page.getByRole('button', { name: 'Test Wallet', exact: true }).click()
  await expect.poll(() => page.evaluate(() => (window as any).__walletMethods.filter((method: string) => method === 'eth_requestAccounts').length)).toBe(1)
  await expect(page.getByText('Opening Test Wallet...')).toBeVisible()
  await page.evaluate(() => (window as any).__rejectConnection())
  await expect(page.getByRole('button', { name: /retry/i })).toBeVisible()
  const methods: string[] = await page.evaluate(() => (window as any).__walletMethods)
  expect(methods.filter((method) => method === 'eth_requestAccounts')).toHaveLength(1)
  expect(methods.filter((method) => /sign|sendTransaction|sendCalls/i.test(method))).toEqual([])
  await expect(page.getByTestId('wallet-account')).toHaveCount(0)
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.getByTestId('wallet-connect')).toBeVisible()
})

test('account and chain changes follow the selected EIP-6963 provider', async ({ page }) => {
  await installInjectedWallet(page)
  await openApp(page)
  await connectInjectedWallet(page)
  await page.evaluate((address) => {
    const eth = (window as any).ethereum
    const request = eth.request
    eth.request = (args: { method: string }) => args.method === 'eth_accounts' ? Promise.resolve([address]) : request(args)
    eth.emit('accountsChanged', [address])
  }, ANVIL_ACCOUNT_1.address)
  await expect(page.getByTestId('wallet-account')).toHaveAttribute('title', ANVIL_ACCOUNT_1.address)
  await page.evaluate(() => {
    const eth = (window as any).ethereum
    const request = eth.request
    eth.request = (args: { method: string }) => args.method === 'eth_chainId' ? Promise.resolve('0x1') : request(args)
    eth.emit('chainChanged', '0x1')
  })
  await expect(page.getByRole('button', { name: 'Switch network', exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Switch network', exact: true }).click()
  await expect(page.getByRole('dialog')).toContainText('Robinhood Local Anvil')
  await expect(page.getByRole('dialog')).not.toContainText('Robinhood Testnet')
})

test('account access is requested before querying the wallet network', async ({ page }) => {
  await installInjectedWallet(page)
  await openApp(page)
  await page.evaluate(() => {
    const eth = (window as any).ethereum
    const request = eth.request
    let requestedAccess = false
    ;(window as any).__connectionMethods = []
    eth.request = (args: { method: string }) => {
      ;(window as any).__connectionMethods.push(args.method)
      if (args.method === 'wallet_requestPermissions' || args.method === 'eth_requestAccounts') requestedAccess = true
      // Model an extension whose network is unavailable before account access.
      if (args.method === 'eth_chainId' && !requestedAccess) return new Promise(() => {})
      return request(args)
    }
  })
  await page.getByTestId('wallet-connect').click()
  await page.getByRole('button', { name: 'Test Wallet', exact: true }).click()
  await expect(page.getByTestId('wallet-account')).toHaveAttribute('title', ANVIL_ACCOUNT_0.address)
  const methods: string[] = await page.evaluate(() => (window as any).__connectionMethods)
  expect(methods.indexOf('wallet_requestPermissions')).toBeLessThan(methods.indexOf('eth_chainId'))
})

for (const code of [4001, -32002]) {
  test(`immediate wallet error ${code} shows retry instead of an endless opening message`, async ({ page }) => {
    await installInjectedWallet(page)
    await openApp(page)
    await page.evaluate((errorCode) => {
      const eth = (window as any).ethereum
      const request = eth.request
      eth.request = (args: { method: string }) => {
        if (args.method === 'wallet_requestPermissions' || args.method === 'eth_requestAccounts') {
          return Promise.reject(Object.assign(new Error('Connection unavailable'), { code: errorCode }))
        }
        return request(args)
      }
    }, code)
    await page.getByTestId('wallet-connect').click()
    await page.getByRole('button', { name: 'Test Wallet', exact: true }).click()
    await expect(page.getByRole('button', { name: /retry/i })).toBeVisible()
    await expect(page.getByTestId('wallet-account')).toHaveCount(0)
    await page.keyboard.press('Escape')
    await expect(page.getByRole('dialog')).toHaveCount(0)
  })
}

test('local network metadata is explicit and stale network selection cannot expose public mainnet', async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('indexedex:selected-network', '46630'))
  await openApp(page)
  const network = page.locator('#header-chain-selector')
  await expect(network).toHaveValue('4663')
  await expect(network.locator('option')).toHaveCount(1)
  await expect(network.locator('option')).toHaveText('Robinhood Local Anvil')
  await expect(page.getByText('Browsing RPC: http://127.0.0.1:8545')).toBeVisible()
})

test('mobile wallet picker fits the viewport and can be dismissed', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await installInjectedWallet(page)
  await openApp(page)
  await page.getByTestId('wallet-connect').click()
  const dialog = page.getByRole('dialog')
  await expect(dialog).toBeVisible()
  const box = await dialog.getByRole('document').boundingBox()
  expect(box).not.toBeNull()
  expect(box!.x).toBeGreaterThanOrEqual(0)
  expect(box!.x + box!.width).toBeLessThanOrEqual(390)
  await page.screenshot({ path: '/tmp/dtf-rainbowkit-mobile.png' })
  await dialog.getByRole('button', { name: /close/i }).click()
  await expect(dialog).toHaveCount(0)
})

test('multiple installed wallets stay distinct and only the selected wallet receives the request', async ({ page }) => {
  await installInjectedWallet(page)
  await openApp(page)
  await page.evaluate((address) => {
    const first = (window as any).ethereum
    const requests: string[] = []
    const originalRequest = first.request
    first.request = (args: { method: string }) => {
      requests.push(`first:${args.method}`)
      return originalRequest(args)
    }
    let authorized = false
    const second = {
      ...first,
      request: (args: { method: string }) => {
        requests.push(`second:${args.method}`)
        if (args.method === 'eth_requestAccounts') { authorized = true; return Promise.resolve([address]) }
        if (args.method === 'eth_accounts') return Promise.resolve(authorized ? [address] : [])
        return originalRequest(args)
      },
    }
    ;(window as any).__discoveryRequests = requests
    const announce = () => window.dispatchEvent(new CustomEvent('eip6963:announceProvider', {
      detail: {
        info: {
          uuid: 'b5edd15a-291c-4c04-a9fd-893c524667ef',
          name: 'Second Wallet',
          icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="blue"/></svg>',
          rdns: 'test.indexedex.second',
        },
        provider: second,
      },
    }))
    window.addEventListener('eip6963:requestProvider', announce)
    announce()
  }, ANVIL_ACCOUNT_1.address)
  await page.getByTestId('wallet-connect').click()
  await expect(page.getByRole('button', { name: 'Test Wallet', exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Second Wallet', exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Second Wallet', exact: true }).click()
  await expect(page.getByTestId('wallet-account')).toHaveAttribute('title', ANVIL_ACCOUNT_1.address)
  const requests: string[] = await page.evaluate(() => (window as any).__discoveryRequests)
  expect(requests).toContain('second:eth_requestAccounts')
  expect(requests).not.toContain('first:eth_requestAccounts')
})
