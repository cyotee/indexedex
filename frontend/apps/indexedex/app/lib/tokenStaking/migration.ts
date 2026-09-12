import { erc20Abi, parseAbi, zeroAddress, type Address, type PublicClient } from 'viem'
import { tokenStakingAbi, TOKEN_STAKING_PHASE } from './abi'

export const migrationRouteAbi = parseAbi([
  'function detfToken() view returns (address)',
  'function stakingSY() view returns (address)',
  'function rebasingClaimToken() view returns (address)',
  'function yieldToken() view returns (address)',
  'function asset() view returns (address)',
  'function previewRedeem(address tokenOut, uint256 shares) view returns (uint256)',
  'function redeem(address receiver, uint256 shares, address tokenOut, uint256 minimum, bool internalBalance) returns (uint256)',
])
const same = (a: Address, b: Address) => a.toLowerCase() === b.toLowerCase() && a !== zeroAddress

/** Discover bindings on the selected provider, never treat the adapter as a DETF.
 * Read a consistent block; a missing/incompatible deployment is an error, not a zero balance. */
export async function readMigrationPosition(client: PublicClient, staking: Address, detf: Address, account: Address, minimumBlock = 0n) {
  const latest = await client.getBlockNumber({ cacheTime: 0 })
  const blockNumber = latest < minimumBlock ? minimumBlock : latest
  const legacy = { address: staking, abi: tokenStakingAbi, blockNumber } as const
  const phase = await client.readContract({ ...legacy, functionName: 'phase' })
  if (phase !== TOKEN_STAKING_PHASE.Wrapped) return { ready: false, phase } as const
  const [claimVault, target, dtf, sy, sdetf] = await Promise.all([
    client.readContract({ ...legacy, functionName: 'claimVault' }),
    client.readContract({ ...legacy, functionName: 'targetDetf' }),
    client.readContract({ ...legacy, functionName: 'stakingToken' }),
    client.readContract({ address: detf, abi: migrationRouteAbi, functionName: 'stakingSY', blockNumber }),
    client.readContract({ address: detf, abi: migrationRouteAbi, functionName: 'rebasingClaimToken', blockNumber }),
  ])
  const [asset, yieldToken, actualDetf] = await Promise.all([
    client.readContract({ address: claimVault, abi: migrationRouteAbi, functionName: 'asset', blockNumber }),
    client.readContract({ address: sy, abi: migrationRouteAbi, functionName: 'yieldToken', blockNumber }),
    client.readContract({ address: target, abi: migrationRouteAbi, functionName: 'detfToken', blockNumber }),
  ])
  if (!same(asset, sy) || !same(yieldToken, sdetf) || !same(actualDetf, detf)) {
    throw new Error('The migration contracts do not match this DTF-DETF. Claims are unavailable on this network.')
  }
  const [stake, syBalance, sdetfBalance, dtfDecimals, syDecimals, sdetfDecimals] = await Promise.all([
    client.readContract({ ...legacy, functionName: 'balanceOf', args: [account] }),
    client.readContract({ address: sy, abi: erc20Abi, functionName: 'balanceOf', args: [account], blockNumber }),
    client.readContract({ address: sdetf, abi: erc20Abi, functionName: 'balanceOf', args: [account], blockNumber }),
    client.readContract({ address: dtf, abi: erc20Abi, functionName: 'decimals', blockNumber }),
    client.readContract({ address: sy, abi: erc20Abi, functionName: 'decimals', blockNumber }),
    client.readContract({ address: sdetf, abi: erc20Abi, functionName: 'decimals', blockNumber }),
  ])
  const claimableSY = stake > 0n
    ? await client.readContract({ ...legacy, functionName: 'previewClaim', args: [account, stake] }) : 0n
  const totalSY = claimableSY + syBalance
  const sdetfValue = totalSY > 0n
    ? await client.readContract({ address: sy, abi: migrationRouteAbi, functionName: 'previewRedeem', args: [sdetf, totalSY], blockNumber }) : 0n
  return { ready: true, phase, claimVault, target, dtf, sy, sdetf, stake, syBalance, sdetfBalance,
    dtfDecimals, syDecimals, sdetfDecimals, claimableSY, sdetfValue, blockNumber } as const
}
