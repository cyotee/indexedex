import type { Page } from '@playwright/test'
import { ANVIL_ACCOUNT_0 } from '../wallet/fixture'

export async function prepareLocalChain(page: Page) {
  await page.goto('/')
  await page.evaluate(() => {
    localStorage.setItem('indexedex:selected-network', '11155111')
    for (const k of Object.keys(localStorage)) {
      if (k.startsWith('indexedex-wagmi') || k.includes('wagmi')) localStorage.removeItem(k)
    }
  })
  await page.reload({ waitUntil: 'domcontentloaded' })
}

export async function connectInjectedWallet(page: Page) {
  const short = ANVIL_ACCOUNT_0.address.slice(0, 6)
  // Already connected (header shows truncated address)
  if (await page.getByText(new RegExp(short, 'i')).first().isVisible().catch(() => false)) {
    return
  }

  // Ensure shell is loaded; after failed tests page can be mid-navigation
  if (!(await page.getByRole('button', { name: /Connect Wallet/i }).first().isVisible().catch(() => false))) {
    await page.goto('/', { waitUntil: 'domcontentloaded' })
  }

  await page.waitForFunction(
    () =>
      Array.from(document.querySelectorAll('button')).some((b) =>
        /^Connect Wallet$/i.test((b.textContent || '').trim()),
      ) ||
      Array.from(document.querySelectorAll('button')).some((b) =>
        /0x[a-fA-F0-9]{4}/.test((b.textContent || '').trim()),
      ),
    { timeout: 20_000 },
  )

  if (await page.getByText(new RegExp(short, 'i')).first().isVisible().catch(() => false)) {
    return
  }

  await page.evaluate(() => {
    const btn = Array.from(document.querySelectorAll('button')).find((b) =>
      /^Connect Wallet$/i.test((b.textContent || '').trim()),
    ) as HTMLButtonElement | undefined
    btn?.click()
  })
  await page.getByText(new RegExp(short, 'i')).first().waitFor({ state: 'visible', timeout: 25_000 })
}

/** Select option by value (address) on a select element. Case-insensitive for hex addresses. */
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

/** Wait until a select has an option whose value matches address (case-insensitive). */
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
