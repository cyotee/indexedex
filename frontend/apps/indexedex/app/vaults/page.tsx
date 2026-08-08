import { redirect } from 'next/navigation'

/** Legacy catalog → unified Earn (strategy filter). */
export default function VaultsRedirectPage() {
  redirect('/earn?type=strategy')
}
