/**
 * Map wallet / contract errors to short user-facing strings.
 * Never surface raw selectors as the only feedback.
 */

function extractMessage(err: unknown): string {
  if (err == null) return ''
  if (typeof err === 'string') return err
  if (err instanceof Error) return err.message || String(err)
  if (typeof err === 'object') {
    const o = err as Record<string, unknown>
    if (typeof o.shortMessage === 'string' && o.shortMessage) return o.shortMessage
    if (typeof o.message === 'string' && o.message) return o.message
    if (o.cause != null) return extractMessage(o.cause)
  }
  return String(err)
}

function extractCode(err: unknown): number | string | undefined {
  if (err == null || typeof err !== 'object') return undefined
  const o = err as Record<string, unknown>
  if (typeof o.code === 'number' || typeof o.code === 'string') return o.code
  if (o.cause != null) return extractCode(o.cause)
  return undefined
}

/**
 * Parse a thrown wallet/contract error into a safe UI string.
 */
export function parseContractError(err: unknown): string {
  const code = extractCode(err)
  const raw = extractMessage(err)
  const lower = raw.toLowerCase()

  // EIP-1193 user rejection
  if (
    code === 4001 ||
    code === 'ACTION_REJECTED' ||
    /user rejected|user denied|rejected the request|denied transaction|request rejected/i.test(
      raw,
    )
  ) {
    return 'Transaction rejected in wallet'
  }

  if (/insufficient funds|insufficient balance|exceeds balance/i.test(raw)) {
    return 'Insufficient balance for this transaction'
  }

  if (/network changed|chain mismatch|wrong network|chain id/i.test(lower)) {
    return 'Wrong network — switch to the app network and try again'
  }

  if (/allowance|transfer amount exceeds allowance/i.test(lower)) {
    return 'Token allowance too low — approve again'
  }

  if (/deadline|expired/i.test(lower) && /transaction|swap|permit/i.test(lower)) {
    return 'Transaction deadline expired — try again'
  }

  // Prefer shortMessage-like first line without huge stacks
  const firstLine = raw.split('\n')[0]?.trim() || ''
  if (firstLine.length > 0 && firstLine.length <= 180) {
    // Strip leading "Error: " / viem wrappers when still readable
    return firstLine.replace(/^Error:\s*/i, '')
  }

  return 'Transaction failed — check wallet and try again'
}
