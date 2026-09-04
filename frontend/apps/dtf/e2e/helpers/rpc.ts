import {
  createPublicClient,
  createWalletClient,
  encodeAbiParameters,
  http,
  keccak256,
  padHex,
  parseEther,
  toHex,
  type Address,
  type Hex,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'wagmi/chains'
import {
  ANVIL_ACCOUNT_0,
  DEFAULT_E2E_CHAIN_ID,
  DEFAULT_E2E_RPC,
} from '../wallet/injectWallet'

const chain = {
  ...sepolia,
  id: DEFAULT_E2E_CHAIN_ID,
  name: DEFAULT_E2E_CHAIN_ID === 4663 ? 'Robinhood (Anvil)' : sepolia.name,
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

export async function rpcAlive(): Promise<boolean> {
  try {
    await publicClient().getBlockNumber()
    return true
  } catch {
    return false
  }
}

export async function chainIdMatches(): Promise<boolean> {
  try {
    const id = await publicClient().getChainId()
    return id === DEFAULT_E2E_CHAIN_ID
  } catch {
    return false
  }
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
  const { findBaseBySymbol } = await import('./chainArtifacts')
  const weth = findBaseBySymbol('WETH9') ?? findBaseBySymbol('WETH')
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
  return publicClient().waitForTransactionReceipt({ hash, timeout: 90_000 })
}

/** DETF isReserveLive() when present. */
export async function isDetfReserveLive(detf: Address): Promise<boolean | null> {
  try {
    return await publicClient().readContract({
      address: detf,
      abi: [
        {
          type: 'function',
          name: 'isReserveLive',
          stateMutability: 'view',
          inputs: [],
          outputs: [{ type: 'bool' }],
        },
      ],
      functionName: 'isReserveLive',
    })
  } catch {
    return null
  }
}

export async function nftBalance(nft: Address, owner: Address): Promise<bigint> {
  try {
    return await publicClient().readContract({
      address: nft,
      abi: [
        {
          type: 'function',
          name: 'balanceOf',
          stateMutability: 'view',
          inputs: [{ name: 'owner', type: 'address' }],
          outputs: [{ type: 'uint256' }],
        },
      ],
      functionName: 'balanceOf',
      args: [owner],
    })
  } catch {
    return 0n
  }
}

export async function hasCode(address: Address): Promise<boolean> {
  try {
    const code = await publicClient().getCode({ address })
    return !!code && code !== '0x'
  } catch {
    return false
  }
}

/** ERC-20 `balanceOf` mapping is slot 0 on $DTF (Pons ERC20). */
export function erc20BalanceSlot(owner: Address, mappingSlot = 0n): Hex {
  return keccak256(
    encodeAbiParameters(
      [{ type: 'address' }, { type: 'uint256' }],
      [owner, mappingSlot],
    ),
  )
}

/**
 * Anvil `deal` for an ERC-20: set the balance mapping slot.
 * Used when the injected wallet needs tokens the fork did not already grant.
 */
export async function dealErc20(
  token: Address,
  owner: Address,
  amount: bigint,
  mappingSlot = 0n,
): Promise<bigint> {
  const slot = erc20BalanceSlot(owner, mappingSlot)
  const value = padHex(toHex(amount), { size: 32 })
  await publicClient().request({
    method: 'anvil_setStorageAt',
    params: [token, slot, value],
  })
  return erc20Balance(token, owner)
}

export async function ensureErc20(
  token: Address,
  owner: Address,
  minWei: bigint,
  mappingSlot = 0n,
): Promise<bigint> {
  const current = await erc20Balance(token, owner)
  if (current >= minWei) return current
  return dealErc20(token, owner, minWei, mappingSlot)
}

/** Nested `allowance[owner][spender]` slot. Default mapping slot 1 (after `balanceOf`). */
export function erc20AllowanceSlot(owner: Address, spender: Address, mappingSlot = 1n): Hex {
  const inner = keccak256(
    encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [owner, mappingSlot]),
  )
  return keccak256(
    encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [spender, BigInt(inner)]),
  )
}

/**
 * RH Anvil forks of 4663 omit untouched ERC-20 mapping slots (`metadata is not found`).
 * Writing 0 materializes the slot so `allowance` / `approve` / `transferFrom` can run.
 */
export async function warmErc20Allowance(
  token: Address,
  owner: Address,
  spender: Address,
  value = 0n,
  mappingSlot = 1n,
): Promise<void> {
  const slot = erc20AllowanceSlot(owner, spender, mappingSlot)
  await publicClient().request({
    method: 'anvil_setStorageAt',
    params: [token, slot, padHex(toHex(value), { size: 32 })],
  })
}
