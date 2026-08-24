import { fallback, http, type Transport } from 'viem'
import { unstable_connector } from 'wagmi'
import { injected } from 'wagmi/connectors'

/**
 * Contract reverts are answers, not RPC failures. If the injected wallet says
 * initialize reverted, do not fall through to HTTP (that node can disagree).
 * Disconnect / timeout still fall through so SSR and disconnected pages work.
 */
export function shouldThrowWalletFirst(error: Error): boolean {
  const text = error.message ?? ''
  if (/user rejected|rejected the request/i.test(text)) return true
  if (
    /execution reverted|insufficient gas|intrinsic gas|gas too low|out of gas|0x7983c051|PoolAlreadyInitialized|Internal JSON-RPC/i.test(
      text,
    ) &&
    !/insufficient funds/i.test(text)
  ) {
    return true
  }
  if ('code' in error && typeof (error as { code: unknown }).code === 'number') {
    const code = (error as { code: number }).code
    if (code === 3 || code === 4001 || code === 5000) return true
  }
  return false
}

/** Prefer the connected wallet's RPC. HTTP is SSR / disconnected fallback only. */
export function walletFirstTransport(fallbackUrl: string): Transport {
  return fallback([unstable_connector(injected, { retryCount: 0 }), http(fallbackUrl)], {
    rank: false,
    shouldThrow: shouldThrowWalletFirst,
  })
}
