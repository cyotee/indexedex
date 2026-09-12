/** Minimal connector shape used by overlay / Header connect. */
export type Connectable = {
  id: string
  name?: string
}

function errorName(err: unknown): string {
  if (err && typeof err === 'object' && 'name' in err && typeof err.name === 'string') {
    return err.name
  }
  return ''
}

function errorMessage(err: unknown): string {
  if (err instanceof Error) return err.message
  if (err && typeof err === 'object' && 'shortMessage' in err && typeof err.shortMessage === 'string') {
    return err.shortMessage
  }
  if (err && typeof err === 'object' && 'message' in err && typeof err.message === 'string') {
    return err.message
  }
  return String(err ?? '')
}

export function isProviderNotFoundError(err: unknown): boolean {
  return (
    errorName(err) === 'ProviderNotFoundError' || /provider not found/i.test(errorMessage(err))
  )
}

export function isConnectUserRejected(err: unknown): boolean {
  const code =
    err && typeof err === 'object' && 'code' in err ? (err as { code?: unknown }).code : undefined
  if (code === 4001 || code === 'ACTION_REJECTED') return true
  return /user rejected|user denied|rejected the request/i.test(errorMessage(err))
}

/**
 * MetaMask-targeted `injected({ target: 'metaMask' })` throws ProviderNotFound
 * when window.ethereum is Coinbase, Brave, or an untagged injected wallet.
 * Try MetaMask first, then generic injected, then the rest.
 */
export function orderWalletConnectors<T extends Connectable>(connectors: readonly T[]): T[] {
  const rank = (c: T): number => {
    if (c.id === 'metaMask' || c.id === 'metaMaskSDK' || /metamask/i.test(c.name ?? '')) return 0
    if (c.id === 'injected') return 1
    if (c.id === 'coinbaseWallet') return 2
    return 3
  }
  const seen = new Set<string>()
  return [...connectors]
    .sort((a, b) => rank(a) - rank(b))
    .filter((c) => {
      if (seen.has(c.id)) return false
      seen.add(c.id)
      return true
    })
}

export async function connectInjectedWallet<T extends Connectable>(args: {
  connectAsync: (input: { connector: T }) => Promise<unknown>
  connectors: readonly T[]
}): Promise<void> {
  const ordered = orderWalletConnectors(args.connectors)
  if (ordered.length === 0) {
    throw new Error('No browser wallet found.')
  }
  let last: unknown
  for (const connector of ordered) {
    try {
      await args.connectAsync({ connector })
      return
    } catch (e) {
      last = e
      if (isConnectUserRejected(e)) throw e
      if (isProviderNotFoundError(e)) continue
      throw e
    }
  }
  throw last ?? new Error('No browser wallet found.')
}
