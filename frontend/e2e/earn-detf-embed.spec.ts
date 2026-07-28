import { test, expect } from './wallet/fixture'
import { protocolDetfs, strategyVaults } from './helpers/chainArtifacts'

/**
 * Wave 1.5 Slice D — Earn DETF embed flag gate.
 *
 * Flag is compile-time (NEXT_PUBLIC_*). Default build keeps embed off.
 * Lab enable is proven by a separate process env when E2E_EARN_DETF_EMBED=true.
 */

test.describe('Earn DETF embed (flag default off)', () => {
  test('DETF detail has deep-link workspace, no embed mount when flag off', async ({
    walletPage,
  }) => {
    const detfs = protocolDetfs()
    test.skip(detfs.length === 0, 'No protocol DETFs in chain/11155111 tokenlist')

    const d = detfs[0]!
    await walletPage.goto(`/earn/${d.address}`, { waitUntil: 'domcontentloaded' })
    await expect(walletPage.getByRole('navigation')).toBeVisible({ timeout: 20_000 })

    // Production default: deep-link only (no data-testid embed root)
    await expect(walletPage.getByTestId('detf-workspace-embed')).toHaveCount(0)

    // Overview always offers full workspace deep link
    const workspaceLink = walletPage.getByRole('link', {
      name: /open mint \/ bond \/ sell workspace/i,
    })
    await expect(workspaceLink).toBeVisible({ timeout: 15_000 })
    await expect(workspaceLink).toHaveAttribute('href', new RegExp(`/staking\\?detf=${d.address}`, 'i'))

    // No Mint/bond/sell tab when flag off
    await expect(walletPage.getByRole('tab', { name: /mint\s*\/\s*bond/i })).toHaveCount(0)
  })

  test('strategy product still shows deposit panel (money path surface)', async ({
    walletPage,
  }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults')

    await walletPage.goto(`/earn/${vaults[0]!.address}`, { waitUntil: 'domcontentloaded' })
    await expect(walletPage.getByTestId('earn-deposit-submit')).toBeVisible({ timeout: 15_000 })
    await expect(walletPage.getByTestId('detf-workspace-embed')).toHaveCount(0)
  })
})

test.describe('Earn DETF embed (lab flag on)', () => {
  test('mounts embed when NEXT_PUBLIC_EARN_DETF_EMBED=true was baked into the server', async ({
    walletPage,
  }) => {
    // Only meaningful when the webServer / next process was started with the flag.
    // CI and default local `npm run start` keep flag false — skip then.
    test.skip(
      process.env.E2E_EARN_DETF_EMBED !== 'true' &&
        process.env.NEXT_PUBLIC_EARN_DETF_EMBED !== 'true',
      'Lab flag not enabled for this e2e process (set E2E_EARN_DETF_EMBED=true + rebuild with NEXT_PUBLIC_EARN_DETF_EMBED=true)',
    )

    const detfs = protocolDetfs()
    test.skip(detfs.length === 0, 'No protocol DETFs')

    const d = detfs[0]!
    await walletPage.goto(`/earn/${d.address}`, { waitUntil: 'networkidle' })
    await expect(walletPage.getByRole('navigation')).toBeVisible({ timeout: 20_000 })
    // Flag-on surface: actions tab appears only when isEarnDetfEmbedEnabled()
    await expect(walletPage.getByRole('button', { name: 'Mint / bond / sell', exact: true })).toBeVisible({
      timeout: 20_000,
    })

    // Tabs component uses buttons (not ARIA tabs) — open Mint / bond / sell panel
    // Exact label avoids matching "Open mint / bond / sell workspace" CTA
    await walletPage.getByRole('button', { name: 'Mint / bond / sell', exact: true }).click()

    await expect(walletPage.getByTestId('detf-workspace-embed')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByText(/Mint, bond, and sell/i)).toBeVisible()
    // No debug panel on embed surface
    await expect(walletPage.getByText(/staking debug/i)).toHaveCount(0)

    const fullWorkspace = walletPage.getByRole('link', { name: /open full workspace/i })
    await expect(fullWorkspace).toBeVisible()
    await expect(fullWorkspace).toHaveAttribute(
      'href',
      new RegExp(`/staking\\?detf=${d.address}`, 'i'),
    )
  })
})
