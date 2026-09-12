import { test, expect } from './wallet/fixture'

const ETH = '0x0000000000000000000000000000000000000000'
const DTF = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01'
const HOOKS = '0xe5E702641EA86f4ae6cC3cdaED2B886F976Be044'

test.describe('One-strategy Uniswap V4 pool key', () => {
  test('takes the five PoolKey fields used in SE PkgArgs', async ({ walletPage }) => {
    await walletPage.goto('/create/one-vault')
    await walletPage.getByTestId('create-host-uniswap-v4').click()
    await walletPage.getByTestId('create-next').click()

    const poolKeyToggle = walletPage.getByTestId('create-slot-0-v4-entry-poolkey')
    if (!(await poolKeyToggle.isVisible())) {
      await walletPage.getByTestId('create-slot-0-build').click()
    }
    await expect(poolKeyToggle).toBeVisible()
    await poolKeyToggle.click()

    await expect(walletPage.getByTestId('create-slot-0-currency0')).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-currency1')).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-apply-pool-key')).toHaveCount(0)

    await walletPage.getByTestId('create-slot-0-currency0').fill(ETH)
    await walletPage.getByTestId('create-slot-0-currency1').fill(ETH)
    await expect(walletPage.getByTestId('create-slot-0-pool-key-error')).toHaveText(
      'The two pool tokens must be different.',
    )

    await walletPage.getByTestId('create-slot-0-currency1').fill(DTF)
    await walletPage.getByTestId('create-slot-0-fee').selectOption('custom')
    await walletPage.getByTestId('create-slot-0-fee-custom').fill('0')
    await walletPage.getByTestId('create-slot-0-tick-spacing').fill('200')
    await walletPage.getByTestId('create-slot-0-hooks').fill(HOOKS)

    await expect(walletPage.getByTestId('create-slot-0-currency0')).toHaveValue(ETH)
    await expect(walletPage.getByTestId('create-slot-0-currency1')).toHaveValue(DTF)
    await expect(walletPage.getByTestId('create-slot-0-fee-custom')).toHaveValue('0')
    await expect(walletPage.getByTestId('create-slot-0-tick-spacing')).toHaveValue('200')
    await expect(walletPage.getByTestId('create-slot-0-hooks')).toHaveValue(HOOKS)
  })
})


