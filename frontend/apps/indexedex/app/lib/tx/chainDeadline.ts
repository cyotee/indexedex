import type { PublicClient } from 'viem'

/** Use the selected chain's clock, including when a rehearsal advances time. */
export async function chainDeadline(client: PublicClient): Promise<bigint> {
  const block = await client.getBlock({ blockTag: 'latest' })
  return block.timestamp + 20n * 60n
}
