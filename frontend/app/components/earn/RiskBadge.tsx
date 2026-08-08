import { Badge } from '../ui/Badge'
import {
  RISK_LEVEL_LABEL,
  type RiskLevel,
} from '@indexedex/protocol/earn/riskFromTags'

const TONE: Record<RiskLevel, 'accent' | 'info' | 'warning'> = {
  conservative: 'accent',
  balanced: 'info',
  experimental: 'warning',
}

const TITLE: Record<RiskLevel, string> = {
  conservative: 'Lower relative strategy complexity (list-tagged). Not a guarantee of safety.',
  balanced: 'Moderate relative risk (list-tagged). Read the Risks tab.',
  experimental: 'Higher smart-contract and strategy risk (list-tagged). Read Risks before depositing.',
}

/**
 * Risk chip from tokenlist tags only. Renders nothing when level is missing —
 * never defaults to Balanced / invents risk.
 */
export function RiskBadge({
  level,
  className = '',
}: {
  level?: RiskLevel | null
  className?: string
}) {
  if (!level) return null
  return (
    <span title={TITLE[level]} className={className ? `inline-flex ${className}` : 'inline-flex'}>
      <Badge tone={TONE[level]}>{RISK_LEVEL_LABEL[level]}</Badge>
    </span>
  )
}

export default RiskBadge
