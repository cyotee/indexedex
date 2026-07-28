import { test, expect } from './wallet/fixture'
import { strategyVaults } from './helpers/chainArtifacts'

/**
 * Wave 1 PR2/PR10 — disconnected deposit panel shows Connect CTA (four-state).
 */
test.describe('Deposit panel money path smoke', () => {
  test('disconnected earn detail shows Connect wallet CTA', async ({ walletPage }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults in tokenlist')

    const v = vaults[0]!
    await walletPage.goto(`/earn/${v.address}`, { waitUntil: 'domcontentloaded' })
    await expect(walletPage.getByRole('navigation')).toBeVisible({ timeout: 20_000 })

    // ActionCta disconnected gate
    const connectCta = walletPage.getByTestId('earn-deposit-submit')
    await expect(connectCta).toBeVisible({ timeout: 15_000 })
    await expect(connectCta).toHaveAttribute('data-gate', 'disconnected')
    await expect(connectCta).toContainText(/connect/i)

    // Swap fallback always present
    await expect(walletPage.getByTestId('earn-deposit-swap-fallback')).toBeVisible()
  })

  test('deposit panel mode toggles render without crash', async ({ walletPage }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults')

    await walletPage.goto(`/earn/${vaults[0]!.address}`, { waitUntil: 'domcontentloaded' })
    await expect(walletPage.getByTestId('earn-mode-deposit')).toBeVisible({ timeout: 15_000 })
    await walletPage.getByTestId('earn-mode-withdraw').click()
    await expect(walletPage.getByTestId('earn-deposit-submit')).toBeVisible()
  })
})
