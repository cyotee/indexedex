import { getAddress } from 'viem'

import { feeDetfAddress } from './helpers/chainArtifacts'
import { test, expect } from './wallet/fixture'

const SAMPLE_DETF = '0xd31fe4f8d93a373fb08ecf6a955095f8b3d27117'

test.describe('App routes & redirects (DTF)', () => {
  test('home, explore, create, you, learn, earn load', async ({ walletPage }) => {
    for (const path of ['/', '/explore', '/create', '/you', '/learn', '/earn', '/insights']) {
      const res = await walletPage.goto(path)
      expect(res?.ok() || res?.status() === 304).toBeTruthy()
      await expect(walletPage.locator('body')).not.toBeEmpty()
    }
  })

  test('landing names official $DTF fee token and address', async ({ walletPage }) => {
    await walletPage.goto('/')
    await expect(walletPage.getByTestId('official-dtf-token')).toHaveText(
      'The official fee-accruing token is $DTF at 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01.',
    )
  })

  test('/mint is gone', async ({ walletPage }) => {
    const res = await walletPage.goto('/mint')
    expect(res?.status()).toBe(404)
    await expect(walletPage.getByRole('heading', { name: 'Mint Test Tokens' })).toHaveCount(0)
    await walletPage.goto('/explore')
    await walletPage.getByRole('button', { name: 'More' }).click()
    await expect(walletPage.locator('a[href="/mint"]')).toHaveCount(0)
    await expect(walletPage.getByRole('link', { name: 'Mint Test Tokens' })).toHaveCount(0)
  })

  test('/vaults redirects toward earn', async ({ walletPage }) => {
    await walletPage.goto('/vaults')
    await walletPage.waitForURL(/earn/, { timeout: 15_000 })
    expect(walletPage.url()).toMatch(/earn/)
  })

  test('/detfs redirects toward earn', async ({ walletPage }) => {
    await walletPage.goto('/detfs')
    await walletPage.waitForURL(/earn/, { timeout: 15_000 })
    expect(walletPage.url()).toMatch(/earn/)
  })

  test('staking workspace loads', async ({ walletPage }) => {
    await walletPage.goto('/staking')
    const body = await walletPage.locator('body').innerText()
    expect(/DETF|Staking|workspace|DTF-DETF|mint|bond/i.test(body)).toBe(true)
  })

  test('insights catalog lists archived DETFs with mint and bond off', async ({ walletPage }) => {
    await walletPage.goto('/insights')
    await expect(walletPage.getByText('Archived DETFs').first()).toBeVisible({ timeout: 20_000 })
    const archived = walletPage.getByTestId('insights-archived-detf-list')
    await expect(archived).toBeVisible()
    await expect(archived.getByText('0xaf0E1967c8F755c747615c5427108Bc549CA1122')).toBeVisible()
    await expect(archived.getByText('0x72EF4Be65e356E102bB31a97d2d7B309e8c97226')).toBeVisible()
    await expect(walletPage.getByText('Mint and bond are off.')).toBeVisible()
  })

  test('archived DETF mint and bond controls stay disabled', async ({ walletPage }) => {
    const addr = '0xaf0E1967c8F755c747615c5427108Bc549CA1122'
    await walletPage.goto(`/insights/${addr}?tab=mint`)
    await expect(walletPage.getByTestId('detf-actions')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByTestId('detf-mint-archived')).toBeVisible()
    await expect(walletPage.getByTestId('detf-mint')).toBeDisabled()
    await walletPage.goto(`/insights/${addr}?tab=bond`)
    await expect(walletPage.getByTestId('detf-actions')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByTestId('detf-bond-archived')).toBeVisible()
    await expect(walletPage.getByTestId('detf-bond')).toBeDisabled()
  })

  test('insights ?detf= redirects to the token path', async ({ walletPage }) => {
    const checksum = getAddress(SAMPLE_DETF)
    await walletPage.goto(`/insights?detf=${SAMPLE_DETF}`)
    await walletPage.waitForURL(new RegExp(`/insights/${checksum}`, 'i'), { timeout: 15_000 })
  })

  test('insights burn tab is on the DETF actions panel', async ({ walletPage }) => {
    const addr = feeDetfAddress() ?? SAMPLE_DETF
    await walletPage.goto(`/insights/${addr}?tab=burn`)
    await expect(walletPage.getByTestId('detf-actions')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByTestId('detf-burn')).toBeVisible()
    await expect(walletPage.getByTestId('insights-contracts')).toBeVisible()
  })

  test('insights stake tab is on the DETF actions panel', async ({ walletPage }) => {
    const addr = feeDetfAddress() ?? SAMPLE_DETF
    await walletPage.goto(`/insights/${addr}?tab=stake`)
    await expect(walletPage.getByTestId('detf-actions')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByTestId('detf-staking')).toBeVisible()
    const body = await walletPage.locator('body').innerText()
    expect(/claim token|rebasing claim|Stake/i.test(body)).toBe(true)
  })

  test('insights claim tab shows bond owner and claim control', async ({ walletPage }) => {
    const addr = feeDetfAddress() ?? SAMPLE_DETF
    await walletPage.goto(`/insights/${addr}?tab=claim`)
    await expect(walletPage.getByTestId('detf-actions')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByTestId('detf-claim-id')).toBeVisible()
    await expect(walletPage.getByTestId('detf-claim-owner')).toBeVisible()
    await expect(walletPage.getByTestId('detf-claim-owner')).toContainText(/Owner/i)
    await expect(walletPage.getByTestId('detf-claim')).toBeVisible()
    await expect(walletPage.getByTestId('detf-claim')).toBeDisabled()
    await walletPage.getByTestId('detf-claim-id').fill('1')
    await expect(walletPage.getByTestId('detf-claim-owner')).toBeVisible()
  })
})
