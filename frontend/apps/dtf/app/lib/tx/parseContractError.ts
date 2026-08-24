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
function extractDataBlob(err: unknown): string {
  const parts: string[] = []
  let current: unknown = err
  for (let i = 0; i < 6 && current != null; i++) {
    if (typeof current === 'object') {
      const o = current as Record<string, unknown>
      if (typeof o.data === 'string') parts.push(o.data)
      current = o.cause
      continue
    }
    break
  }
  return parts.join(' ')
}

export function parseContractError(err: unknown): string {
  const code = extractCode(err)
  const raw = extractMessage(err)
  const blob = `${raw} ${extractDataBlob(err)}`
  const lower = blob.toLowerCase()

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

  // Revert data first. Wallets often label a hard revert as "not enough ETH for gas".
  if (/0x3dec0665|InsufficientTokenOut/i.test(blob)) {
    return 'Mint could not add that token to the reserve. Bond still works. The pair-side book cannot take more of this token right now.'
  }

  if (/0x7939f424|TransferFromFailed/i.test(blob)) {
    return 'Token transfer failed. Approve the token again, then retry.'
  }

  if (/0x000cd769|MintingNotAllowed/i.test(blob)) {
    return 'Mint is blocked by Policy. Synthetic price is below the mint line.'
  }

  if (/0x28ccf317|ReserveNotLive/i.test(blob)) {
    return 'This DETF is inert until the first bond.'
  }

  if (/insufficient funds|insufficient balance|exceeds balance/i.test(raw)) {
    return 'Insufficient balance for this transaction'
  }

  if (/network changed|chain mismatch|wrong network|chain id/i.test(lower)) {
    return 'Wrong network. Switch to the app network and try again.'
  }

  if (/already initialized|pool already exists|PoolAlreadyInitialized|0x7983c051/i.test(blob)) {
    return 'This pool already exists.'
  }

  if (/interaction failed|failed to simulate|internal json-rpc error/i.test(lower)) {
    return 'Wallet could not simulate this transaction.'
  }

  if (/allowance|transfer amount exceeds allowance/i.test(lower)) {
    return 'Token allowance too low. Approve again.'
  }

  if (/deadline|expired/i.test(lower) && /transaction|swap|permit/i.test(lower)) {
    return 'Transaction deadline expired. Try again.'
  }

  // Prefer shortMessage-like first line without huge stacks
  const firstLine = raw.split('\n')[0]?.trim() || ''
  if (firstLine.length > 0 && firstLine.length <= 400) {
    return firstLine.replace(/^Error:\s*/i, '')
  }

  return 'Transaction failed. Check the wallet and try again.'
}
