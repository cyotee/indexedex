import { test, expect } from './wallet/fixture'

test.describe('One-strategy Morpho market form', () => {
  test('shows loan and collateral fields instead of a later stub', async ({ walletPage }) => {
    await walletPage.goto('/create/one-vault')
    await walletPage.getByTestId('create-host-morpho').click()
    await walletPage.getByTestId('create-next').click()
    await expect(walletPage.getByTestId('create-slot-0-loan')).toBeVisible()
    await expect(walletPage.getByRole('combobox', { name: 'Lending token' })).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-collateral')).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-lltv')).toBeVisible()
    await expect(walletPage.getByText(/not on this screen yet/i)).toHaveCount(0)
    await expect(walletPage.getByText(/does not create a second one/i)).toBeVisible()

    await walletPage.getByTestId('create-slot-0-loan').selectOption({ label: 'TTUSDE · Test Token USDE' })
    await walletPage.getByTestId('create-slot-0-collateral').selectOption({ label: 'TTWETH · Test Token WETH' })
    await expect(walletPage.getByTestId('create-slot-0-status')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByTestId('create-slot-0-status')).toHaveText(/Market: (found|not found)/i)
  })
})
