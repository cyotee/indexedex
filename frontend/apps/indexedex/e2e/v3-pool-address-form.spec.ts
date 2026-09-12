import { test, expect } from './wallet/fixture'

const EMPTY_CODE = '0x1111111111111111111111111111111111111111'

test.describe('One-strategy Uniswap V3 pool address', () => {
  test('lets the user apply a V3 pool address onto the SE vault form', async ({ walletPage }) => {
    await walletPage.goto('/create/one-vault')
    await walletPage.getByTestId('create-host-uniswap-v3').click()
    await walletPage.getByTestId('create-next').click()

    const poolToggle = walletPage.getByTestId('create-slot-0-v3-entry-pool')
    if (!(await poolToggle.isVisible())) {
      await walletPage.getByTestId('create-slot-0-build').click()
    }
    await expect(poolToggle).toBeVisible()
    await poolToggle.click()

    await walletPage.getByTestId('create-slot-0-apply-v3-pool').click()
    await expect(walletPage.getByTestId('create-slot-0-v3-pool-error')).toHaveText(
      'Paste a pool address first.',
    )

    await walletPage.getByTestId('create-slot-0-v3-pool').fill(EMPTY_CODE)
    await walletPage.getByTestId('create-slot-0-apply-v3-pool').click()
    await expect(walletPage.getByTestId('create-slot-0-v3-pool-error')).toHaveText(
      /No contract at that address|That contract is not a Uniswap V3 pool|No RPC client/,
    )
  })
})
