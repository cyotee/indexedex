import EarnDetailClient from './EarnDetailClient'

export default async function EarnDetailPage({
  params,
}: {
  params: Promise<{ address: string }>
}) {
  const { address } = await params
  return <EarnDetailClient address={address} />
}
