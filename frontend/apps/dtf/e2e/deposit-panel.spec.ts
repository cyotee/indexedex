import { test, expect } from './wallet/fixture'
import { strategyVaults } from './helpers/chainArtifacts'
import { prepareLocalChain } from './helpers/connect'

test.describe('Deposit panel money path smoke (DTF)', () => {
  test('disconnected earn detail shows Connect wallet CTA when vault listed', async ({
    walletPage,
  }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults in tokenlist')

    await prepareLocalChain(walletPage)
    const v = vaults[0]!
    await walletPage.goto(`/earn/${v.address}`, { waitUntil: 'domcontentloaded' })
    await expect(walletPage.getByRole('navigation')).toBeVisible({ timeout: 20_000 })

    const connectCta = walletPage.getByTestId('earn-deposit-submit')
    await expect(connectCta).toBeVisible({ timeout: 15_000 })
    await expect(connectCta).toHaveAttribute('data-gate', 'disconnected')
    await expect(connectCta).toContainText(/connect/i)
  })

  test('deposit panel mode toggles render without crash', async ({ walletPage }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults')

    await prepareLocalChain(walletPage)
    await walletPage.goto(`/earn/${vaults[0]!.address}`, { waitUntil: 'domcontentloaded' })
    await expect(walletPage.getByTestId('earn-mode-deposit')).toBeVisible({ timeout: 15_000 })
    await walletPage.getByTestId('earn-mode-withdraw').click()
    await expect(walletPage.getByTestId('earn-deposit-submit')).toBeVisible()
  })
})
