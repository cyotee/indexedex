import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  type Address,
  type Hex,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'
import { ANVIL_ACCOUNT_0, DEFAULT_E2E_CHAIN_ID, DEFAULT_E2E_RPC } from '../wallet/injectWallet'

const chain = {
  ...sepolia,
  id: DEFAULT_E2E_CHAIN_ID,
  rpcUrls: {
    default: { http: [DEFAULT_E2E_RPC] },
    public: { http: [DEFAULT_E2E_RPC] },
  },
}

export function publicClient() {
  return createPublicClient({ chain, transport: http(DEFAULT_E2E_RPC) })
}

export function walletClient() {
  const account = privateKeyToAccount(ANVIL_ACCOUNT_0.privateKey)
  return createWalletClient({ account, chain, transport: http(DEFAULT_E2E_RPC) })
}

export async function erc20Balance(token: Address, owner: Address): Promise<bigint> {
  return publicClient().readContract({
    address: token,
    abi: [
      {
        type: 'function',
        name: 'balanceOf',
        stateMutability: 'view',
        inputs: [{ name: 'account', type: 'address' }],
        outputs: [{ type: 'uint256' }],
      },
    ],
    functionName: 'balanceOf',
    args: [owner],
  })
}

export async function ensureWeth(minWei: bigint = parseEther('1')) {
  const weth = (await import('./chainArtifacts')).findBaseBySymbol('WETH9')
    ?? (await import('./chainArtifacts')).findBaseBySymbol('WETH')
  if (!weth) throw new Error('WETH not in tokenlist')
  const bal = await erc20Balance(weth.address as Address, ANVIL_ACCOUNT_0.address)
  if (bal >= minWei) return weth.address as Address
  const account = privateKeyToAccount(ANVIL_ACCOUNT_0.privateKey)
  const wc = createWalletClient({ account, chain, transport: http(DEFAULT_E2E_RPC) })
  const hash = await wc.writeContract({
    address: weth.address as Address,
    abi: [{ type: 'function', name: 'deposit', stateMutability: 'payable', inputs: [], outputs: [] }],
    functionName: 'deposit',
    value: minWei,
    chain,
    account,
  })
  await publicClient().waitForTransactionReceipt({ hash })
  return weth.address as Address
}

export async function waitForReceipt(hash: Hex) {
  return publicClient().waitForTransactionReceipt({ hash, timeout: 60_000 })
}

/** Balancer V3 Vault.isPoolInitialized(pool) — false means S-BAL quote will revert PoolNotInitialized. */
export async function isBalancerPoolInitialized(pool: Address): Promise<boolean> {
  const platform = (await import('./chainArtifacts')).loadPlatform()
  const vault = platform.balancerV3Vault as Address | undefined
  if (!vault) return false
  try {
    return await publicClient().readContract({
      address: vault,
      abi: [
        {
          type: 'function',
          name: 'isPoolInitialized',
          stateMutability: 'view',
          inputs: [{ name: 'pool', type: 'address' }],
          outputs: [{ type: 'bool' }],
        },
      ],
      functionName: 'isPoolInitialized',
      args: [pool],
    })
  } catch {
    return false
  }
}

/**
 * Initialize a registered but empty Balancer V3 pool with exact amounts of two tokens.
 * Requires the Anvil account to hold both tokens and have approved the Permit2/router path.
 * Returns true if pool is initialized after the call.
 */
export async function seedBalancerPoolInitialize(params: {
  pool: Address
  tokenA: Address
  amountA: bigint
  tokenB: Address
  amountB: bigint
}): Promise<boolean> {
  const platform = (await import('./chainArtifacts')).loadPlatform()
  const router = platform.balancerV3Router as Address | undefined
  if (!router) throw new Error('balancerV3Router missing from platform.json')
  if (await isBalancerPoolInitialized(params.pool)) return true

  // Sort tokens (Balancer InputHelpers.sortTokens = ascending address)
  const tokens =
    params.tokenA.toLowerCase() < params.tokenB.toLowerCase()
      ? [params.tokenA, params.tokenB]
      : [params.tokenB, params.tokenA]
  const amounts =
    params.tokenA.toLowerCase() < params.tokenB.toLowerCase()
      ? [params.amountA, params.amountB]
      : [params.amountB, params.amountA]

  const account = privateKeyToAccount(ANVIL_ACCOUNT_0.privateKey)
  const wc = createWalletClient({ account, chain, transport: http(DEFAULT_E2E_RPC) })
  const pc = publicClient()

  // Approve router to pull tokens (many local routers use Permit2; try direct ERC20 approve first)
  for (let i = 0; i < 2; i++) {
    const token = tokens[i]!
    const amount = amounts[i]!
    const allowance = await pc.readContract({
      address: token,
      abi: [
        {
          type: 'function',
          name: 'allowance',
          stateMutability: 'view',
          inputs: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
          ],
          outputs: [{ type: 'uint256' }],
        },
      ],
      functionName: 'allowance',
      args: [account.address, router],
    })
    if (allowance < amount) {
      const hash = await wc.writeContract({
        address: token,
        abi: [
          {
            type: 'function',
            name: 'approve',
            stateMutability: 'nonpayable',
            inputs: [
              { name: 'spender', type: 'address' },
              { name: 'amount', type: 'uint256' },
            ],
            outputs: [{ type: 'bool' }],
          },
        ],
        functionName: 'approve',
        args: [router, amount * 2n],
        chain,
        account,
      })
      await pc.waitForTransactionReceipt({ hash })
    }
  }

  const hash = await wc.writeContract({
    address: router,
    abi: [
      {
        type: 'function',
        name: 'initialize',
        stateMutability: 'payable',
        inputs: [
          { name: 'pool', type: 'address' },
          { name: 'tokens', type: 'address[]' },
          { name: 'exactAmountsIn', type: 'uint256[]' },
          { name: 'minBptAmountOut', type: 'uint256' },
          { name: 'wethIsEth', type: 'bool' },
          { name: 'userData', type: 'bytes' },
        ],
        outputs: [{ type: 'uint256' }],
      },
    ],
    functionName: 'initialize',
    args: [params.pool, tokens, amounts, 0n, false, '0x'],
    chain,
    account,
  })
  await pc.waitForTransactionReceipt({ hash })
  return isBalancerPoolInitialized(params.pool)
}
