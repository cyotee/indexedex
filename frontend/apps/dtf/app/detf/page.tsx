import { redirect } from 'next/navigation'

/** Legacy dual-token DETF route → Earn (product removed). */
export default function DetfRedirectPage() {
  redirect('/earn')
}
