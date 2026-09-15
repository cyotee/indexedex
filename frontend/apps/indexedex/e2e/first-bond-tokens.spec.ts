import { getAddress, parseAbi, zeroAddress } from 'viem'
import { test, expect } from './wallet/fixture'
import { loadPlatform } from './helpers/chainArtifacts'
import { publicClient } from './helpers/rpc'
import { selectByValue, waitForOption } from './helpers/connect'
import { readProtocolDetf } from '../app/lib/tokenStaking/migration'

test.describe('First bond token picker', () => {
  test('offers every accepted payment token for the active protocol DETF', async ({ walletPage }) => {
    const client = publicClient()
    const detf = await readProtocolDetf(client, getAddress(String(loadPlatform().tokenStaking)))
    if (!detf) throw new Error('The fork must contain the migrated protocol DETF')
    const accepted = await client.readContract({
      address: detf,
      abi: parseAbi(['function acceptedBondTokens() view returns (address[])']),
      functionName: 'acceptedBondTokens',
    })
    const payments = accepted.filter(token => token !== zeroAddress && token.toLowerCase() !== detf.toLowerCase())
    expect(payments.length).toBeGreaterThan(0)

    await walletPage.goto(`/create/bond?detf=${detf}`, { waitUntil: 'domcontentloaded' })
    const select = walletPage.getByTestId('first-bond-token')
    for (const token of payments) {
      await waitForOption(walletPage, 'first-bond-token', token)
      await selectByValue(walletPage, 'first-bond-token', token)
      expect((await select.inputValue()).toLowerCase()).toBe(token.toLowerCase())
      const label = await select.locator('option:checked').innerText()
      await expect(walletPage.getByTestId('first-bond-amount')).toBeVisible()
      await expect(walletPage.getByText(`${label.trim()} amount`, { exact: true })).toBeVisible()
    }
  })
})
