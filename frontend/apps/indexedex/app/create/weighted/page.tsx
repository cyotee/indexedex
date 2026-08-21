import { CreatePageFrame } from '../CreatePageFrame'

export const metadata = {
  title: 'Create: several vaults, fixed weights — IndexedEx',
}

export default function CreateWeightedPage() {
  return <CreatePageFrame initialTypeId="weighted" />
}
