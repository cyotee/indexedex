import { redirect } from 'next/navigation'

export default function YouPage({ searchParams }: { searchParams: Record<string, string | string[] | undefined> }) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(searchParams)) {
    for (const item of Array.isArray(value) ? value : value == null ? [] : [value]) query.append(key, item)
  }
  redirect(`/portfolio${query.size ? `?${query}` : ''}`)
}
