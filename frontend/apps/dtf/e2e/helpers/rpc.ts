import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
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
