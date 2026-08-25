import { test, expect } from './wallet/fixture'

const SHORT_HEX = '0x1975'
const UNKNOWN_POOL_ID = `0x${'11'.repeat(32)}`

test.describe('One-strategy Uniswap V4 pool ID', () => {
  test('lets the user paste a 32-byte pool ID on the basket step', async ({ walletPage }) => {
    await walletPage.goto('/create/one-vault')
    await walletPage.getByTestId('create-host-uniswap-v4').click()
    await walletPage.getByTestId('create-next').click()

    const poolIdToggle = walletPage.getByTestId('create-slot-0-v4-entry-poolid')
    if (!(await poolIdToggle.isVisible())) {
      await walletPage.getByTestId('create-slot-0-build').click()
    }
    await expect(poolIdToggle).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-pool-id')).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-token-a')).toHaveCount(0)
    await expect(walletPage.getByTestId('create-slot-0-currency0')).toHaveCount(0)

    await walletPage.getByTestId('create-slot-0-apply-pool-id').click()
    await expect(walletPage.getByTestId('create-slot-0-pool-id-error')).toHaveText(
      'Paste a pool ID first.',
    )

    await walletPage.getByTestId('create-slot-0-pool-id').fill(SHORT_HEX)
    await walletPage.getByTestId('create-slot-0-apply-pool-id').click()
    await expect(walletPage.getByTestId('create-slot-0-pool-id-error')).toHaveText(
      'Need a 32-byte pool ID (0x plus 64 hex characters).',
    )

    await walletPage.getByTestId('create-slot-0-pool-id').fill(UNKNOWN_POOL_ID)
    await expect(walletPage.getByTestId('create-slot-0-pool-id-error')).toHaveText(
      /No Uniswap V4 pool with that ID|No RPC client|Could not look up that pool ID/,
      { timeout: 30_000 },
    )
  })
})
