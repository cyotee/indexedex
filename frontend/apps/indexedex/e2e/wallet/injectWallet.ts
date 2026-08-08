/**
 * Injected EIP-1193 provider for Playwright.
 *
 * Tests our UI against a "connected wallet" without MetaMask extension.
 * Signs with Anvil account #0 and talks JSON-RPC to local Anvil (or configured RPC).
 */
import type { Page } from '@playwright/test'
import {
  createPublicClient,
  createWalletClient,
  http,
  type Hex,
  type TransactionRequest,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'

/** Anvil / Foundry default account #0 */
export const ANVIL_ACCOUNT_0 = {
  address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as const,
  privateKey:
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as Hex,
}

export const DEFAULT_E2E_CHAIN_ID = 11155111 // Sepolia id used by local_testing Anvil
export const DEFAULT_E2E_RPC =
  process.env.E2E_RPC_URL ?? process.env.NEXT_PUBLIC_LOCAL_RPC_URL ?? 'http://127.0.0.1:8545'

type RpcRequest = { method: string; params?: unknown[] }

/**
 * Install window.ethereum before any app script runs, bridged to Node via
 * page.exposeFunction so we can sign with viem + Anvil private key.
 */
export async function installInjectedWallet(
  page: Page,
  options?: {
    rpcUrl?: string
    chainId?: number
    privateKey?: Hex
  },
) {
  const rpcUrl = options?.rpcUrl ?? DEFAULT_E2E_RPC
  const chainId = options?.chainId ?? DEFAULT_E2E_CHAIN_ID
  const privateKey = options?.privateKey ?? ANVIL_ACCOUNT_0.privateKey
  const account = privateKeyToAccount(privateKey)

  const chain = {
    ...sepolia,
    id: chainId,
    rpcUrls: { default: { http: [rpcUrl] }, public: { http: [rpcUrl] } },
  }

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  })

  // Unique name per page to avoid collisions across tests
  const bridgeName = `__e2eWalletRequest`

  await page.exposeFunction(bridgeName, async (payload: RpcRequest) => {
    const { method, params = [] } = payload

    switch (method) {
      case 'eth_requestAccounts':
      case 'eth_accounts':
        return [account.address]
      case 'eth_chainId':
        return `0x${chainId.toString(16)}`
      case 'net_version':
        return String(chainId)
      case 'eth_blockNumber':
        return publicClient.getBlockNumber().then((n) => `0x${n.toString(16)}`)
      case 'eth_getBalance': {
        const [addr, blockTag] = params as [string, string?]
        const bal = await publicClient.getBalance({
          address: addr as `0x${string}`,
          blockTag: (blockTag as any) ?? 'latest',
        })
        return `0x${bal.toString(16)}`
      }
      case 'eth_call': {
        const [tx, blockTag] = params as [TransactionRequest, string?]
        const data = await publicClient.call({
          ...tx,
          blockTag: (blockTag as any) ?? 'latest',
        } as any)
        return data.data ?? '0x'
      }
      case 'eth_estimateGas': {
        const [tx] = params as [TransactionRequest]
        const gas = await publicClient.estimateGas(tx as any)
        return `0x${gas.toString(16)}`
      }
      case 'eth_gasPrice': {
        const gp = await publicClient.getGasPrice()
        return `0x${gp.toString(16)}`
      }
      case 'eth_getTransactionCount': {
        const [addr, blockTag] = params as [string, string?]
        const n = await publicClient.getTransactionCount({
          address: addr as `0x${string}`,
          blockTag: (blockTag as any) ?? 'latest',
        })
        return `0x${n.toString(16)}`
      }
      case 'eth_sendTransaction': {
        const [tx] = params as [
          {
            from?: string
            to?: string
            data?: Hex
            value?: string
            gas?: string
            gasPrice?: string
            maxFeePerGas?: string
            maxPriorityFeePerGas?: string
          },
        ]
        const hash = await walletClient.sendTransaction({
          to: tx.to as `0x${string}` | undefined,
          data: tx.data,
          value: tx.value ? BigInt(tx.value) : undefined,
          gas: tx.gas ? BigInt(tx.gas) : undefined,
          account,
          chain,
        } as any)
        return hash
      }
      case 'eth_sendRawTransaction': {
        const [raw] = params as [Hex]
        return publicClient.sendRawTransaction({ serializedTransaction: raw })
      }
      case 'personal_sign': {
        const [message, from] = params as [string, string]
        void from
        // message may be hex-encoded
        const msg =
          message.startsWith('0x')
            ? ({ raw: message as Hex } as const)
            : message
        return walletClient.signMessage({ message: msg as any, account })
      }
      case 'eth_signTypedData_v4': {
        const [, typedDataJson] = params as [string, string]
        const typed = typeof typedDataJson === 'string' ? JSON.parse(typedDataJson) : typedDataJson
        const { domain, types, primaryType, message } = typed
        const { EIP712Domain: _drop, ...rest } = types
        return walletClient.signTypedData({
          account,
          domain,
          types: rest,
          primaryType,
          message,
        })
      }
      case 'wallet_switchEthereumChain': {
        const [arg] = params as [{ chainId: string }]
        const requested = Number.parseInt(arg.chainId, 16)
        if (requested !== chainId) {
          // Mirror MetaMask rejection when chain is not the test chain
          const err = new Error(`Unrecognized chain ID ${arg.chainId}`) as Error & {
            code?: number
          }
          err.code = 4902
          throw err
        }
        return null
      }
      case 'wallet_addEthereumChain':
        return null
      case 'wallet_requestPermissions':
        return [{ parentCapability: 'eth_accounts' }]
      case 'wallet_getPermissions':
        return [{ parentCapability: 'eth_accounts' }]
      default: {
        // Forward unknown methods to the node
        const res = await fetch(rpcUrl, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
        })
        const json = (await res.json()) as { result?: unknown; error?: { message: string } }
        if (json.error) throw new Error(json.error.message)
        return json.result
      }
    }
  })

  await page.addInitScript(
    ({ bridge, address, chainIdHex }: { bridge: string; address: string; chainIdHex: string }) => {
      type Listener = (...args: unknown[]) => void
      const listeners = new Map<string, Set<Listener>>()

      const ethereum = {
        isMetaMask: true,
        isCoinbaseWallet: false,
        chainId: chainIdHex,
        networkVersion: String(Number.parseInt(chainIdHex, 16)),
        selectedAddress: address,
        request: async (args: { method: string; params?: unknown[] }) => {
          return (window as any)[bridge]({ method: args.method, params: args.params ?? [] })
        },
        on(event: string, handler: Listener) {
          if (!listeners.has(event)) listeners.set(event, new Set())
          listeners.get(event)!.add(handler)
        },
        removeListener(event: string, handler: Listener) {
          listeners.get(event)?.delete(handler)
        },
        removeAllListeners(event?: string) {
          if (event) listeners.delete(event)
          else listeners.clear()
        },
        emit(event: string, ...args: unknown[]) {
          listeners.get(event)?.forEach((h) => h(...args))
        },
        enable: async () => {
          return (window as any)[bridge]({ method: 'eth_requestAccounts', params: [] })
        },
        sendAsync: (payload: any, cb: (err: Error | null, res?: any) => void) => {
          ;(window as any)
            [bridge]({ method: payload.method, params: payload.params ?? [] })
            .then((result: unknown) => cb(null, { id: payload.id, jsonrpc: '2.0', result }))
            .catch((err: Error) => cb(err))
        },
        send: (methodOrPayload: any, paramsOrCb?: any) => {
          if (typeof methodOrPayload === 'string') {
            return (window as any)[bridge]({
              method: methodOrPayload,
              params: paramsOrCb ?? [],
            })
          }
          return ethereum.request(methodOrPayload)
        },
      }

      Object.defineProperty(window, 'ethereum', {
        value: ethereum,
        writable: true,
        configurable: true,
      })
      // Some connectors probe providers array
      ;(window as any).ethereum.providers = [ethereum]
    },
    {
      bridge: bridgeName,
      address: account.address,
      chainIdHex: `0x${chainId.toString(16)}`,
    },
  )

  return {
    address: account.address,
    chainId,
    rpcUrl,
  }
}
