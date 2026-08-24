/** Wallet RPC helpers for create-flow reads and writes. */

import { encodeFunctionData, type Abi, type Address, type PublicClient, type WalletClient } from 'viem'

export type RpcRequestProvider = {
  request: (args: { method: string; params?: unknown[] }) => Promise<unknown>
}

export type MinedReceipt = {
  hash: `0x${string}`
  status: 'success' | 'reverted' | 'unknown'
  logs: { data: `0x${string}`; topics: readonly `0x${string}`[] }[]
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms)
  })
}

function asHex(value: unknown): `0x${string}` | null {
  return typeof value === 'string' && value.startsWith('0x') ? (value as `0x${string}`) : null
}

/** Normalize a viem or JSON-RPC receipt. Null if not mined yet. */
export function receiptFromUnknown(hash: `0x${string}`, raw: unknown): MinedReceipt | null {
  if (raw == null || typeof raw !== 'object') return null
  const o = raw as Record<string, unknown>
  if (o.blockNumber == null || o.blockNumber === '0x0' || o.blockNumber === 0n) return null

  const statusRaw = o.status
  const reverted =
    statusRaw === 'reverted' || statusRaw === 0 || statusRaw === 0n || statusRaw === '0x0'
  const ok =
    statusRaw === 'success' ||
    statusRaw === 1 ||
    statusRaw === 1n ||
    statusRaw === '0x1' ||
    statusRaw == null

  const logs: MinedReceipt['logs'] = []
  if (Array.isArray(o.logs)) {
    for (const item of o.logs) {
      if (!item || typeof item !== 'object') continue
      const log = item as Record<string, unknown>
      const data = asHex(log.data)
      const topics = Array.isArray(log.topics)
        ? log.topics.map((t) => asHex(t)).filter((t): t is `0x${string}` => t != null)
        : []
      if (data) logs.push({ data, topics })
    }
  }

  return {
    hash,
    status: reverted ? 'reverted' : ok ? 'success' : 'unknown',
    logs,
  }
}

/** Resolve the injected wallet provider. */
export async function resolveWalletProvider(
  getProvider?: () => Promise<unknown>,
): Promise<RpcRequestProvider | null> {
  try {
    const provider = await getProvider?.()
    if (provider && typeof (provider as RpcRequestProvider).request === 'function') {
      return provider as RpcRequestProvider
    }
  } catch {
    /* fall through */
  }
  if (typeof window !== 'undefined') {
    const injected = (window as unknown as { ethereum?: RpcRequestProvider }).ethereum
    if (injected && typeof injected.request === 'function') return injected
  }
  return null
}

/** Wait for a receipt on the wallet's RPC. */
export async function waitForSubmittedReceipt(input: {
  hash: `0x${string}`
  walletProvider: RpcRequestProvider
  timeoutMs?: number
  pollMs?: number
}): Promise<MinedReceipt> {
  const timeoutMs = input.timeoutMs ?? 90_000
  const pollMs = input.pollMs ?? 800
  const deadline = Date.now() + timeoutMs

  while (Date.now() < deadline) {
    try {
      const raw = await input.walletProvider.request({
        method: 'eth_getTransactionReceipt',
        params: [input.hash],
      })
      const parsed = receiptFromUnknown(input.hash, raw)
      if (parsed) return parsed
    } catch {
      /* keep polling */
    }
    await sleep(pollMs)
  }

  throw new Error('Timed out waiting for the transaction receipt')
}

export function isZeroDataError(err: unknown): boolean {
  const text = err instanceof Error ? err.message : String(err ?? '')
  return /returned no data|ContractFunctionZeroDataError/i.test(text)
}

/** True when eth_getCode returned real bytecode, not an empty account. */
export function bytecodeLooksLikeContract(code: unknown): boolean {
  if (typeof code !== 'string') return false
  const hex = code.trim().toLowerCase()
  return hex.startsWith('0x') && hex.length > 4
}

/**
 * Ask the wallet's RPC if `address` has code. Empty accounts make MetaMask show
 * "Send ETH" for a 0-value call; do not submit those.
 */
export async function requireContractCode(input: {
  walletProvider: RpcRequestProvider
  address: Address
  label: string
}): Promise<void> {
  const code = await input.walletProvider.request({
    method: 'eth_getCode',
    params: [input.address, 'latest'],
  })
  if (!bytecodeLooksLikeContract(code)) {
    throw new Error(`${input.label} is not on the connected network.`)
  }
}

/**
 * Encode the call and submit it through the connected wallet.
 * No eth_getCode gate. The wallet's node is the RPC.
 */
export async function sendWalletWrite(input: {
  walletClient?: Pick<WalletClient, 'sendTransaction'> | null
  walletProvider?: RpcRequestProvider | null
  account: Address
  address: Address
  abi: Abi
  functionName: string
  args?: readonly unknown[]
}): Promise<`0x${string}`> {
  const data = encodeFunctionData({
    abi: input.abi,
    functionName: input.functionName,
    args: input.args as never,
  })
  if (input.walletProvider) {
    const hash = await input.walletProvider.request({
      method: 'eth_sendTransaction',
      params: [{ from: input.account, to: input.address, data }],
    })
    if (typeof hash === 'string' && hash.startsWith('0x') && hash.length === 66) {
      return hash as `0x${string}`
    }
  }
  if (input.walletClient) {
    return input.walletClient.sendTransaction({
      account: input.account,
      to: input.address,
      data,
    } as never)
  }
  throw new Error('Connect a wallet.')
}

/** Wait on the wallet-preferred client, then poll the injected provider if needed. */
export async function waitForCreateReceipt(input: {
  hash: `0x${string}`
  readClient?: Pick<PublicClient, 'waitForTransactionReceipt'> | null
  walletProvider?: RpcRequestProvider | null
  timeoutMs?: number
}): Promise<MinedReceipt> {
  const timeoutMs = input.timeoutMs ?? 90_000
  if (input.readClient) {
    try {
      const receipt = await input.readClient.waitForTransactionReceipt({
        hash: input.hash,
        timeout: timeoutMs,
      })
      const parsed = receiptFromUnknown(input.hash, receipt)
      if (parsed) {
        if (parsed.status === 'reverted') throw new Error('Transaction reverted')
        return parsed
      }
    } catch (err) {
      if (err instanceof Error && /reverted/i.test(err.message)) throw err
    }
  }
  if (input.walletProvider) {
    const parsed = await waitForSubmittedReceipt({
      hash: input.hash,
      walletProvider: input.walletProvider,
      timeoutMs,
    })
    if (parsed.status === 'reverted') throw new Error('Transaction reverted')
    return parsed
  }
  throw new Error('No wallet RPC to wait for the transaction.')
}
