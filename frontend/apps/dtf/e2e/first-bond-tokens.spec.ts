import { protocolDetfs } from './helpers/chainArtifacts'
import { test, expect } from './wallet/fixture'

test.describe('First bond token picker', () => {
  test('offers the vault token and every SE vaultTokens() entry', async ({ walletPage }) => {
    const detf = protocolDetfs().find((t) => t.symbol === 'DTF-DETF') ?? protocolDetfs()[0]
    test.skip(!detf, 'No protocol DETF in the chain tokenlist')

    await walletPage.goto(`/create/bond?detf=${detf!.address}`)
    const select = walletPage.getByTestId('first-bond-token')
    await expect(select).toBeVisible()
    await expect
      .poll(async () => select.locator('option').count(), { timeout: 20_000 })
      .toBeGreaterThanOrEqual(2)

    const labels = (await select.locator('option').allTextContents()).map((s) => s.trim())
    expect(labels.some((l) => /vault token/i.test(l))).toBe(true)
    expect(labels.some((l) => /TTWETH/i.test(l))).toBe(true)
    expect(labels.some((l) => /^DTF$/.test(l) || l === 'DTF')).toBe(true)

    const pair = '0x23DA2E4264019f2BDeF4bCe0E5866E8f8d8b7172'
    await expect
      .poll(async () => (await select.inputValue()).toLowerCase(), { timeout: 10_000 })
      .toBe(pair.toLowerCase())

    const vaultOption = labels.find((l) => /vault token/i.test(l))
    expect(vaultOption).toBeTruthy()
    await select.selectOption({ label: vaultOption! })
    const vaultSymbol = vaultOption!.replace(/\s*\(vault token\)\s*$/i, '').trim()
    await expect(walletPage.getByTestId('first-bond-amount')).toBeVisible()
    await expect(walletPage.getByText(`${vaultSymbol} amount`)).toBeVisible()
  })
})
