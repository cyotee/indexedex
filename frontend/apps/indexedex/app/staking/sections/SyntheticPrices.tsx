'use client'

import { useQuery } from '@tanstack/react-query'
import { useAccount, usePublicClient } from 'wagmi'
import { erc20Abi, formatUnits, zeroAddress, type Address, type PublicClient } from 'viem'
import { detfReservePriceAbi, insightsViewAbi } from '../../insights/lib/insightsAbi'
import { displayTokenSymbol } from '../../lib/customerSymbols'
import { Button } from '../../components/ui/Button'

/** Match UniswapV4DetfCommon._quoteCtx(pair, false) and _protocolLp.
 * The creation array follows hook token order with the DETF self leg excluded.
 * Keep every input and quote at the same block and use integer arithmetic. */
export async function readSyntheticPrices(client: PublicClient, detf: Address) {
  const blockNumber = await client.getBlockNumber({ cacheTime: 0 })
  const [hook, creation, bondVault, supply, decimals, live] = await Promise.all([
    client.readContract({ address: detf, abi: detfReservePriceAbi, functionName: 'hook', blockNumber }),
    client.readContract({ address: detf, abi: detfReservePriceAbi, functionName: 'creationPairPerDetfWad', blockNumber }),
    client.readContract({ address: detf, abi: insightsViewAbi, functionName: 'bondNftVault', blockNumber }),
    client.readContract({ address: detf, abi: erc20Abi, functionName: 'totalSupply', blockNumber }),
    client.readContract({ address: detf, abi: erc20Abi, functionName: 'decimals', blockNumber }),
    client.readContract({ address: detf, abi: insightsViewAbi, functionName: 'isReserveLive', blockNumber }),
  ])
  if (decimals !== 9) throw new Error('Unsupported DETF precision.')
  const holder = bondVault === zeroAddress ? detf : bondVault
  const [tokens, held, bonded] = await Promise.all([
    client.readContract({ address: hook, abi: detfReservePriceAbi, functionName: 'tokens', blockNumber }),
    client.readContract({ address: hook, abi: erc20Abi, functionName: 'balanceOf', args: [detf], blockNumber }),
    holder.toLowerCase() === detf.toLowerCase() ? Promise.resolve(0n)
      : client.readContract({ address: hook, abi: erc20Abi, functionName: 'balanceOf', args: [holder], blockNumber }),
  ])
  const pairs = tokens.filter(token => token.toLowerCase() !== detf.toLowerCase())
  if (!pairs.length || pairs.length !== creation.length || creation.some(rate => rate === 0n)) {
    throw new Error('Reserve legs do not match the creation benchmarks.')
  }
  const prices = await Promise.all(pairs.map(async (pair, index) => {
    const [symbol, result] = await Promise.all([
      client.readContract({ address: pair, abi: erc20Abi, functionName: 'symbol', blockNumber })
        .catch(() => `${pair.slice(0, 6)}…${pair.slice(-4)}`),
      live ? client.readContract({ address: hook, abi: detfReservePriceAbi, functionName: 'previewSynthetic',
        args: [{ detfTotalSupply: supply * 1_000_000_000n, pendingExpansion: 0n,
          ownedLp: held + bonded, creationPairPerDetfWad: creation[index] }, pair], blockNumber })
        .then(value => ({ value })).catch(() => ({ value: undefined }))
        : Promise.resolve({ value: 0n }),
    ])
    return { pair, symbol: displayTokenSymbol(symbol), value: result.value }
  }))
  return { prices, blockNumber }
}

export default function SyntheticPrices({ detf, chainId }: { detf: Address; chainId: number }) {
  const client = usePublicClient({ chainId }) as PublicClient | undefined
  const wallet = useAccount()
  const wrongNetwork = wallet.isConnected && wallet.chainId !== chainId
  const query = useQuery({
    queryKey: ['detf-synthetic-prices', chainId, detf, wallet.address, wallet.connector?.uid, wallet.status, wallet.chainId],
    queryFn: () => readSyntheticPrices(client!, detf),
    enabled: !!client && !wrongNetwork, retry: false, staleTime: 0, refetchInterval: 15_000,
  })
  const unavailable = query.isError || query.data?.prices.some(price => price.value === undefined)
  return <section aria-label="Synthetic prices" data-testid="detf-synthetic-prices">
    {wrongNetwork ? <p role="status">Switch your wallet to the selected network to see both synthetic prices.</p> : <>
      {query.data ? <dl className="grid gap-3 sm:grid-cols-2">
        {query.data.prices.map(price => <div key={price.pair} className="min-w-0 rounded-lg bg-[var(--surface-2,#1c2030)] p-3" data-testid="detf-synthetic-price" data-pair={price.pair}>
          <dt className="text-sm text-[var(--text-muted,#9aa3b2)]">{price.symbol} synthetic price</dt>
          <dd className="mt-2 break-all font-mono text-base tabular-nums" data-testid="synthetic-price-value">
            {query.isError || price.value === undefined ? 'Unavailable' : formatUnits(price.value, 18)}
          </dd>
        </div>)}
      </dl> : !query.isError ? <p role="status">Loading synthetic prices…</p> : null}
      {unavailable ? <div role="alert" className="mt-2 text-sm">
        <p>Could not load all synthetic prices from the current RPC.</p>
        <Button variant="secondary" size="sm" className="mt-2" disabled={query.isFetching} onClick={() => void query.refetch()}>Retry prices</Button>
      </div> : null}
    </>}
    <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)]">Each price is relative to its leg’s creation price (1.0). Minting checks the input leg; burning checks the output leg. Transaction quotes include any pending rebase.</p>
  </section>
}
