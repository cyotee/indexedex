import EarnDetailClient from './EarnDetailClient'

export default function EarnDetailPage({
  params,
}: {
  params: { address: string }
}) {
  return <EarnDetailClient address={params.address} />
}
