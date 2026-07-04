import { Badge } from '../ui/Badge'
import { EARN_PRODUCT_TYPE_LABEL, type EarnProductType } from '../../lib/earn/types'

export function ProductTypeBadge({ type }: { type: EarnProductType }) {
  const tone =
    type === 'strategy' ? 'accent' : type === 'protocol-detf' ? 'info' : 'warning'
  return <Badge tone={tone}>{EARN_PRODUCT_TYPE_LABEL[type]}</Badge>
}

export default ProductTypeBadge
