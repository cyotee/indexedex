import { Badge } from '../ui/Badge'
import { EARN_PRODUCT_TYPE_LABEL, type EarnProductType } from '@indexedex/protocol/earn/types'

export function ProductTypeBadge({ type }: { type: EarnProductType }) {
  const tone =
    type === 'strategy' ? 'accent' : type === 'protocol-detf' ? 'info' : type === 'detf' ? 'warning' : 'neutral'
  return <Badge tone={tone}>{EARN_PRODUCT_TYPE_LABEL[type]}</Badge>
}

export default ProductTypeBadge
