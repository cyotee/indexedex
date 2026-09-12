import { expect, type Page } from '@playwright/test'
import { DEFAULT_E2E_CHAIN_ID } from '../wallet/fixture'

export async function prepareLocalChain(page: Page, chainId: number = DEFAULT_E2E_CHAIN_ID) {
  await page.goto('/learn')
  await page.evaluate((id) => {
    localStorage.setItem('indexedex:selected-network', String(id))
    // Align with DTF RH default if present
    localStorage.setItem('indexedex:deployment-environment', 'anvil_robinhood_main')
    for (const k of Object.keys(localStorage)) {
      if (k.startsWith('dtf-rainbowkit') || k.startsWith('rk-') || k.includes('wagmi')) {
        localStorage.removeItem(k)
      }
    }
  }, chainId)
  await page.reload({ waitUntil: 'domcontentloaded' })
  const overlay = page.getByTestId('token-staking-overlay')
  if (await overlay.isVisible()) {
    await overlay.getByRole('button', { name: 'Close migration notice' }).click()
  }
  const selector = page.locator('#header-chain-selector')
  await expect(selector).toHaveValue(String(chainId))
}

export async function connectInjectedWallet(page: Page) {
  const account = page.getByTestId('wallet-account')
  if (await account.isVisible()) return
  await page.getByTestId('wallet-connect').click()
  await page.getByRole('button', { name: 'Test Wallet', exact: true }).click()
  await expect(account).toBeVisible({ timeout: 25_000 })
}

/** Select option by value (address) on a select element. Case-insensitive for hex. */
export async function selectByValue(page: Page, testId: string, value: string) {
  const select = page.getByTestId(testId)
  await select.waitFor({ state: 'visible', timeout: 20_000 })
  const matched = await select.locator('option').evaluateAll((opts, v) => {
    const lower = v.toLowerCase()
    const hit = opts.find((o) => (o as HTMLOptionElement).value.toLowerCase() === lower)
    return hit ? (hit as HTMLOptionElement).value : null
  }, value)
  if (!matched) {
    const labels = await select.locator('option').allTextContents()
    throw new Error(`No option value matching ${value} in [data-testid=${testId}]. Options: ${labels.join(' | ')}`)
  }
  await select.selectOption(matched)
}

export async function waitForOption(page: Page, testId: string, value: string, timeout = 30_000) {
  await page.getByTestId(testId).waitFor({ state: 'visible', timeout })
  await page.waitForFunction(
    ({ id, v }) => {
      const el = document.querySelector(`[data-testid="${id}"]`) as HTMLSelectElement | null
      if (!el) return false
      const lower = v.toLowerCase()
      return Array.from(el.options).some((o) => o.value.toLowerCase() === lower)
    },
    { id: testId, v: value },
    { timeout },
  )
}
