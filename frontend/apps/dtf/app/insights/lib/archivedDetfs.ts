import { getAddress, isAddress } from 'viem'

import { CHAIN_ID_ROBINHOOD } from '@indexedex/protocol/addressArtifacts'

import type { InsightDetf } from './mergeInsightDetfs'

/** Robinhood DETFs that stay listed, with mint and bond off in the UI. */
export const ARCHIVED_DETF_ADDRESSES = [
  '0xaf0E1967c8F755c747615c5427108Bc549CA1122',
  '0x0f585337c8C7075886C575aFc14A11C8e44ba30E',
  '0x2094aA9A98d4255E61911D3Bb250e92d3d50d26B',
  '0xbebD0E65414437a8f91e13C47e399a906D7C2935',
  '0xd3B36C198C91fd0E02115782ACDC3d905AC6Bb76',
  '0x72EF4Be65e356E102bB31a97d2d7B309e8c97226',
] as const satisfies readonly `0x${string}`[]

const ARCHIVED_SET = new Set(ARCHIVED_DETF_ADDRESSES.map((address) => address.toLowerCase()))

export function isArchivedDetf(address?: string | null): boolean {
  if (!address || !isAddress(address)) return false
  return ARCHIVED_SET.has(address.toLowerCase())
}

function placeholder(chainId: number, address: `0x${string}`): InsightDetf {
  return {
    chainId,
    address: getAddress(address) as `0x${string}`,
    name: 'Archived DETF',
    symbol: 'DETF',
    decimals: 18,
    protocolFee: false,
  }
}

export function splitInsightDetfs(
  detfs: InsightDetf[],
  chainId: number,
): { live: InsightDetf[]; archived: InsightDetf[] } {
  const live = detfs.filter((d) => !isArchivedDetf(d.address))
  const byAddr = new Map(
    detfs.filter((d) => isArchivedDetf(d.address)).map((d) => [d.address.toLowerCase(), d]),
  )
  const archived: InsightDetf[] = []
  if (chainId === CHAIN_ID_ROBINHOOD) {
    for (const address of ARCHIVED_DETF_ADDRESSES) {
      archived.push(byAddr.get(address.toLowerCase()) ?? placeholder(chainId, address))
    }
  } else {
    for (const d of detfs) {
      if (isArchivedDetf(d.address)) archived.push(d)
    }
  }
  return { live, archived }
}
