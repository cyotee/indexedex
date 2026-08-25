import { test, expect } from './wallet/fixture'

const ETH = '0x0000000000000000000000000000000000000000'
const DTF = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01'
const HOOKS = '0xe5E702641EA86f4ae6cC3cdaED2B886F976Be044'

test.describe('One-strategy Uniswap V4 pool key', () => {
  test('applies a pasted pool key onto the SE vault form', async ({ walletPage }) => {
    await walletPage.goto('/create/one-vault')
    await walletPage.getByTestId('create-host-uniswap-v4').click()
    await walletPage.getByTestId('create-next').click()

    const poolKeyToggle = walletPage.getByTestId('create-slot-0-v4-entry-poolkey')
    if (!(await poolKeyToggle.isVisible())) {
      await walletPage.getByTestId('create-slot-0-build').click()
    }
    await expect(poolKeyToggle).toBeVisible()
    await poolKeyToggle.click()

    await walletPage.getByTestId('create-slot-0-apply-pool-key').click()
    await expect(walletPage.getByTestId('create-slot-0-pool-key-error')).toHaveText(
      'Paste a pool key first.',
    )

    await walletPage.getByTestId('create-slot-0-pool-key').fill(
      JSON.stringify({
        currency0: DTF,
        currency1: ETH,
        fee: 0,
        tickSpacing: 200,
        hooks: HOOKS,
      }),
    )
    await walletPage.getByTestId('create-slot-0-apply-pool-key').click()
    await expect(walletPage.getByTestId('create-slot-0-pool-key-error')).toHaveCount(0)

    await expect(walletPage.getByTestId('create-slot-0-token-a')).toHaveValue(ETH)
    await expect(walletPage.getByTestId('create-slot-0-token-b')).toHaveValue(
      new RegExp(`^${DTF}$`, 'i'),
    )
    await expect(walletPage.getByTestId('create-slot-0-fee-custom')).toHaveValue('0')
    await expect(walletPage.getByTestId('create-slot-0-tick-spacing')).toHaveValue('200')
    await expect(walletPage.getByTestId('create-slot-0-hooks')).toHaveValue(new RegExp(`^${HOOKS}$`, 'i'))
  })
})
