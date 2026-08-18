import { redirect } from 'next/navigation'

/** Research index is now the Learn walk. Slug notes stay at /research/[slug]. */
export default function ResearchIndexRedirect() {
  redirect('/learn')
}
