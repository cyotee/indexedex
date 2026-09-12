import { redirect } from 'next/navigation'

/** Legacy DETFs catalog → unified Earn. */
export default function DetfsRedirectPage() {
  redirect('/earn?type=detf')
}
