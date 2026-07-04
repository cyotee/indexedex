import { redirect } from 'next/navigation'

/** Legacy DETF route → unified Earn. */
export default function DetfRedirectPage() {
  redirect('/earn?type=detf')
}
