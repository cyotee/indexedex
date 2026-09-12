import { redirect } from 'next/navigation'

/** Archived Balancer batch swap. Trade is being rebuilt on Universal Router. */
export default function BatchSwapArchivedRedirectPage() {
  redirect('/swap')
}
