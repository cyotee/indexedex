import { test, expect } from './wallet/fixture'

const POOL_ID = '0x1975619ad4179048b8574d0679588c8eb132637a45fc0062c840b2640b7adcbc'

test.describe('One-strategy Uniswap V4 pool key', () => {
  test('accepts a 32-byte pool ID in a single field', async ({ walletPage }) => {
    await walletPage.goto('/create/one-vault')
    await walletPage.getByTestId('create-host-uniswap-v4').click()
    await walletPage.getByTestId('create-next').click()

    const poolKeyToggle = walletPage.getByTestId('create-slot-0-v4-entry-poolkey')
    if (!(await poolKeyToggle.isVisible())) {
      await walletPage.getByTestId('create-slot-0-build').click()
    }
    await expect(poolKeyToggle).toBeVisible()
    await poolKeyToggle.click()

    const field = walletPage.getByTestId('create-slot-0-pool-key')
    await expect(field).toBeVisible()
    await expect(field).toHaveJSProperty('tagName', 'INPUT')

    await walletPage.getByTestId('create-slot-0-apply-pool-key').click()
    await expect(walletPage.getByTestId('create-slot-0-pool-key-error')).toHaveText(
      'Paste a pool ID first.',
    )

    await field.fill('0x1975')
    await walletPage.getByTestId('create-slot-0-apply-pool-key').click()
    await expect(walletPage.getByTestId('create-slot-0-pool-key-error')).toHaveText(
      'Need a 32-byte pool ID (0x plus 64 hex characters).',
    )

    await field.fill(POOL_ID)
    await walletPage.getByTestId('create-slot-0-apply-pool-key').click()
    await expect(walletPage.getByTestId('create-slot-0-apply-pool-key')).toHaveText(/Apply pool key/, {
      timeout: 60_000,
    })
    const err = walletPage.getByTestId('create-slot-0-pool-key-error')
    if (await err.isVisible()) {
      await expect(err).toHaveText(
        /No Uniswap V4 pool with that ID|Could not look up|No RPC|pool manager/,
      )
    } else {
      await expect(walletPage.getByTestId('create-slot-0-token-a')).not.toHaveValue('')
      await expect(walletPage.getByTestId('create-slot-0-token-b')).not.toHaveValue('')
    }
  })
})

