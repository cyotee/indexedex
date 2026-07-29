import { redirect } from 'next/navigation'

/**
 * Single-hop redirect to Earn type filter for seigniorage DETFs.
 * Do not chain through /detfs.
 */
export default function SeigniorageRedirectPage() {
  redirect('/earn?type=seigniorage-detf')
}
