import { test, expect } from '@playwright/test'
import { installInjectedWallet } from './wallet/injectWallet'
import { connectInjectedWallet, selectByValue, waitForOption } from './helpers/connect'
import { ETH_PAY } from '../app/lib/ethPay'
import { findBaseBySymbol } from './helpers/chainArtifacts'

// Explicit opt-in. This fixture only allows reads against mainnet; no Anvil,
// signatures, approvals, wrapping or purchases are sent by this suite.
test('mainnet bond limits are visible before any payment on both local apps', async ({ page }) => {
  test.skip(process.env.E2E_MAINNET_READONLY !== '1', 'Read-only mainnet verification is opt-in')
  test.setTimeout(180_000)
  await installInjectedWallet(page, {
    rpcUrl: 'https://rpc.mainnet.chain.robinhood.com', chainId: 4663,
    readOnlyAddress: '0xec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8',
  })
  await page.goto('/staking?tab=bond', { waitUntil: 'domcontentloaded' })
  await connectInjectedWallet(page)
  const weth = findBaseBySymbol('WETH')!
  const input = page.getByTestId('detf-bond-amount-input')
  await expect(input).toBeVisible()
  await waitForOption(page, 'detf-action-token', weth.address)
  await selectByValue(page, 'detf-action-token', weth.address)
  const lock = page.getByTestId('detf-bond-days')
  await lock.fill('')
  await expect(lock).toHaveValue('')
  await lock.pressSequentially('60', { delay: 150 })
  await expect(lock).toHaveValue('60')
  await lock.blur()
  await expect(lock).toHaveValue('60')
  await lock.fill('1')
  await lock.pressSequentially('80', { delay: 150 })
  await expect(lock).toHaveValue('180')
  await lock.fill('29')
  await lock.blur()
  await expect(lock).toHaveValue('29')
  await expect(page.getByTestId('detf-bond-lock-error')).toContainText('whole number of days')
  await expect(page.getByTestId('detf-approve').or(page.getByTestId('detf-bond'))).toBeDisabled()
  await lock.fill('30')
  await lock.blur()
  await expect(page.getByTestId('detf-bond-lock-error')).not.toBeVisible()
  await input.fill('1')
  await expect(page.getByTestId('detf-bond-quote-error')).toContainText('per-transaction liquidity limit')
  await expect(page.getByTestId('detf-approve').or(page.getByTestId('detf-bond'))).toBeDisabled()

  // Native payment must fail the same preflight, before wrapping anything.
  await selectByValue(page, 'detf-action-token', ETH_PAY)
  await expect(page.getByTestId('detf-bond-quote-error')).toContainText('per-transaction liquidity limit')
  await expect(page.getByTestId('detf-bond')).toBeDisabled()
  await expect(page.getByText('ETH payment requires wrapping', { exact: false })).toBeVisible()

  await selectByValue(page, 'detf-action-token', weth.address)
  await page.getByTestId('detf-bond-smaller').click()
  await expect(page.getByTestId('detf-bond-quote-error')).not.toBeVisible({ timeout: 60_000 })
  await expect(page.getByTestId('detf-bond-preview')).toContainText('Purchase preview')
  await expect(page.getByTestId('detf-action-status')).toContainText('no bond has been submitted')
  expect(Number(await input.inputValue())).toBeGreaterThan(0)
  expect(Number(await input.inputValue())).toBeLessThan(1)
  await expect(page.getByTestId('detf-approve').or(page.getByTestId('detf-bond'))).toBeEnabled()
})
