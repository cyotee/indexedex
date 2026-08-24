import { test, expect } from './wallet/fixture'

test.describe('Weighted strategy host buttons', () => {
  test('each strategy slot switches listed, Uniswap, and Morpho forms', async ({ walletPage }) => {
    await walletPage.goto('/create/weighted')
    const listed = walletPage.getByTestId('create-slot-0-listed-mode')
    const v3 = walletPage.getByTestId('create-slot-0-host-uniswap-v3')
    const v4 = walletPage.getByTestId('create-slot-0-host-uniswap-v4')
    const morpho = walletPage.getByTestId('create-slot-0-host-morpho')
    await expect(listed).toBeVisible()
    await expect(v3).toBeVisible()
    await expect(v4).toBeVisible()
    await expect(morpho).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-1-host-uniswap-v3')).toBeVisible()

    await v3.click()
    await expect(walletPage.getByTestId('create-slot-0-token-a')).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-version')).toHaveCount(0)

    await morpho.click()
    await expect(walletPage.getByTestId('create-slot-0-loan')).toBeVisible()
    await expect(walletPage.getByTestId('create-slot-0-collateral')).toBeVisible()

    await listed.click()
    await expect(walletPage.getByTestId('create-slot-0-listed')).toBeVisible()
  })

  test('basket weights include the DETF token and even-split DETF plus strategies', async ({
    walletPage,
  }) => {
    await walletPage.goto('/create/weighted')
    await expect(walletPage.getByTestId('create-detf-weight')).toBeVisible()
    await expect(walletPage.getByTestId('create-detf-weight')).toHaveValue('34')
    await expect(walletPage.getByTestId('create-weight-total')).toContainText(/Weights total 34%/)
    await expect(walletPage.getByTestId('create-weight-warning')).toBeVisible()
    await expect(walletPage.getByTestId('create-step-basket')).toContainText(/DETF token/)

    const listed0 = walletPage.getByTestId('create-slot-0-listed')
    const listed1 = walletPage.getByTestId('create-slot-1-listed')
    await expect(listed0).toBeVisible()
    const values = await listed0.locator('option').evaluateAll((opts) =>
      opts.map((o) => (o as HTMLOptionElement).value).filter(Boolean),
    )
    if (values.length < 2) return

    await listed0.selectOption(values[0]!)
    await listed1.selectOption(values[1]!)
    await expect(walletPage.getByTestId('create-detf-weight')).toHaveValue('34')
    await expect(walletPage.getByTestId('create-slot-0-weight')).toHaveValue('33')
    await expect(walletPage.getByTestId('create-slot-1-weight')).toHaveValue('33')
    await expect(walletPage.getByTestId('create-weight-total')).toContainText(/Weights total 100%/)
    await expect(walletPage.getByTestId('create-weight-warning')).toHaveCount(0)

    await walletPage.getByTestId('create-detf-weight').fill('20')
    await expect(walletPage.getByTestId('create-weight-warning')).toBeVisible()
    await expect(walletPage.getByTestId('create-weight-total')).toContainText(/Weights total 86%/)
    await walletPage.getByTestId('create-detf-weight').fill('34')

    const pair0 = walletPage.getByTestId('create-slot-0-pair')
    const pair1 = walletPage.getByTestId('create-slot-1-pair')
    await expect(pair0).toBeVisible({ timeout: 20_000 })
    await expect(pair1).toBeVisible({ timeout: 20_000 })
    const opts0 = await pair0.locator('option').evaluateAll((opts) =>
      opts.map((o) => (o as HTMLOptionElement).value).filter(Boolean),
    )
    const opts1 = await pair1.locator('option').evaluateAll((opts) =>
      opts.map((o) => (o as HTMLOptionElement).value).filter(Boolean),
    )
    if (opts0.length === 0 || opts1.length === 0) return
    const first = opts0[0]!
    const second = opts1.find((v) => v.toLowerCase() !== first.toLowerCase()) ?? opts1[0]!
    if (first.toLowerCase() === second.toLowerCase()) return
    await pair0.selectOption(first)
    await pair1.selectOption(second)

    await walletPage.getByTestId('create-next').click()
    await expect(walletPage.getByTestId('create-step-name')).toBeVisible()
    await expect(walletPage.getByText(/weights with the DETF token first/i)).toBeVisible()
    await expect(walletPage.getByTestId('create-name')).toHaveValue(/DETF/, { timeout: 20_000 })
    await expect(walletPage.getByTestId('create-symbol')).toHaveValue(/DETF/)

    await walletPage.getByTestId('create-next').click()
    await expect(walletPage.getByTestId('create-step-gates')).toBeVisible()
    await walletPage.getByTestId('create-next').click()
    await expect(walletPage.getByTestId('create-step-review')).toBeVisible()
    const deploy = walletPage.getByTestId('create-deploy-detf')
    await expect(deploy).toBeVisible()
    await expect(deploy).not.toHaveAttribute('data-gate', 'disabled')
  })
})
