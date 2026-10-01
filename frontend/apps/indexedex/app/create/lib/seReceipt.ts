import { decodeEventLog, type Address, type Hex } from 'viem'

import { NEW_VAULT_EVENT } from './seAbi'

/** Return the first matching vault. An omitted package explicitly allows any package. */
export function vaultFromReceipt(
  logs: readonly { data: Hex; topics: readonly Hex[] }[] | undefined,
  pkg?: Address,
): Address | undefined {
  if (!logs) return undefined
  for (const log of logs) {
    try {
      const { args } = decodeEventLog({
        abi: [NEW_VAULT_EVENT],
        data: log.data,
        topics: log.topics as [Hex, ...Hex[]],
      })
      if (pkg !== undefined && args.package.toLowerCase() !== pkg.toLowerCase()) continue
      return args.vault
    } catch {
      // Malformed or unrelated logs do not prevent a later matching event.
    }
  }
  return undefined
}
