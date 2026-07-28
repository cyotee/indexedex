import type { ResearchArticle } from '../types'

export const rateProvidersArticle: ResearchArticle = {
  slug: 'rate-providers',
  title: 'Rate providers keep nested markets honest',
  summary:
    'When Standard Exchange vault shares sit in nested Balancer legs, rate providers keep mids fair as underlying markets move. That is mark integrity — not free yield.',
  date: '2026-07-21',
  tags: ['rates', 'se', 'balancer', 'integrity'],
  status: 'published',
  claims: [
    'With rate providers on, residual mid lag under tested Uni-driven demand paths is effectively zero.',
    'With rate providers off, residual lag grows as volume scales.',
    'Residual lag is not a free arb until edge clears pool fees and path costs.',
    'Pool fee acts as an arb presentation threshold: below the stack, residuals can exist with zero fills.',
  ],
  notClaiming: [
    'Rate providers do not print yield or guarantee profit.',
    'Results are from hermetic/fork research scenarios — not a promise of live DETF portfolio performance.',
    'Fee ladders and fill behavior transfer carefully across pool fee settings; do not extrapolate one research fee to all production pools.',
    'This note does not claim DualLiquidity itself is an arb product.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'What is a DETF?',
  sourceNote:
    'research/MARKETING_AND_PERFORMANCE_FINDINGS.md §3.3 (rate provider comparative); scenarios under research/scenarios/uniswapV2Se/rateProviderCompare/.',
  sections: [
    {
      heading: 'The problem nested reserves create',
      paragraphs: [
        'Standard Exchange (SE) vault shares re-mark with their underlying venues. When those shares become legs in a Balancer pool, the nested mid only stays fair if the pool sees an accurate rate for the vault share.',
        'Without rate providers, the nested mid can lag while the underlying market moves. With rate providers, research runs show residual mid error collapsing under the same demand path.',
      ],
    },
    {
      heading: 'What the comparative runs showed',
      paragraphs: [
        'In pure separate worlds (rates on vs rates off) against Uni V2 SE demand:',
      ],
      bullets: [
        'Baseline and higher-volume Mode A paths: rates on → residual ≈ 0; rates off → residual scales with volume (from tens of bps into multi-percent under stress tiers).',
        'Modest Mode C arb probes: residuals below the research fee stack produced zero fills — lag without a free lunch.',
        'Extreme stress tiers: when residual cleared fees, fills appeared — confirming fee as a presentation threshold, not that “rates off is free money.”',
      ],
    },
    {
      heading: 'Why DETFs care',
      paragraphs: [
        'A DETF prices seigniorage from its reserve pool. If vault-share legs mis-mark, synthetic price and mint/burn gates inherit that error. Rate providers are a mark-integrity control for nested composition — the same class of honesty problem DETF reserves face when legs are SE shares.',
        'Product messaging should lead with integrity and re-mark behavior, not with residual-as-yield.',
      ],
    },
    {
      heading: 'How to read the graphs later',
      paragraphs: [
        'When figures ship on this site (R4), the primary compare panel is residual / fairness under matched demand with rates on vs off. Until then, the monorepo plot packs under research/out/uniswapV2Se/rateProviderCompare/ are the machine-readable evidence.',
      ],
    },
  ],
}
