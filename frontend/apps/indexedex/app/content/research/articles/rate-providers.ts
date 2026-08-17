import type { ResearchArticle } from '../types'

/**
 * Rate providers — deploy-time mark policy for SE-share legs in nested / DETF reserves.
 * Public framing: accuracy-first (rates on) vs reprice-volume (rates off).
 * Evidence: research/MARKETING_AND_PERFORMANCE_FINDINGS.md §3.3;
 * research/scenarios/uniswapV2Se/rateProviderCompare/.
 * Voice: indexedex-product-voice.
 */
export const rateProvidersArticle: ResearchArticle = {
  slug: 'rate-providers',
  title: 'Rate providers: mark accuracy or market reprice',
  summary:
    'DETF reserves that hold Standard Exchange vault shares can deploy with rate providers on or off. On prioritizes accurate live marks so deposits and synthetic price track claim value. Off leaves raw-share mids that can lag — inviting reprice volume when that gap is large enough to trade. Two product intents. Neither is free yield.',
  date: '2026-07-28',
  tags: ['rates', 'se', 'balancer', 'detf', 'integrity'],
  status: 'published',
  claims: [
    'DETF and nested SE-share reserves can deploy with rate providers on or off — two intentional mark policies.',
    'Rates on prioritize mark accuracy: live claim accounting so deposit and synthetic quotes track redeem-fair value as underlyings move.',
    'Rates off prioritize market reprice: raw-share mids can lag claim value, which can invite closer volume when residual clears fees and path costs.',
    'With rate providers on under tested Uni-driven demand paths, residual mid lag is effectively zero.',
    'With rate providers off, residual lag grows as underlying volume scales; fills appear only when edge clears the fee stack.',
    'Rate providers re-mark live claim units; they do not auto-rebalance weights or allocate capital across vaults.',
  ],
  notClaiming: [
    'Neither policy prints yield, guarantees profit, or promises mainnet reprice volume.',
    'Results are from hermetic/fork research scenarios — not a promise of live DETF portfolio performance.',
    'Fee ladders and fill behavior transfer carefully across pool fee settings; do not extrapolate one research fee to all production pools.',
    'Rates on do not replace user mint, burn, bond, or deposit flow for moving inventory.',
    'Rates off do not guarantee aggressive rebalancing — residual can exist below fees with no fills.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'DETFs: one token over a basket',
  sourceNote:
    'research/MARKETING_AND_PERFORMANCE_FINDINGS.md §3.3 (rate provider comparative); research/scenarios/uniswapV2Se/rateProviderCompare/ (AGENT_RESEARCH_REPORT.md, FINDINGS.md). Product spine: docs/marketing/DETF_NARRATIVE_SPINE.md (pricing engine = reserve pool). DualLiquidity optional rates appear only as composition context — not the hero product.',
  sections: [
    {
      heading: 'Two ways to mark SE-share legs',
      paragraphs: [
        'A DETF (Decentralized ETF) prices itself from a real multi-asset reserve — often Balancer V3 legs that hold Standard Exchange (SE) vault shares. Those shares track claim value on underlying venues (for example a Uniswap book wrapped as an SE vault).',
        'When you stand up a reserve, you can wire those share legs with rate providers on, or leave them as raw ERC-20 legs with rate providers off. That is a product intent choice: mark accuracy first, or market-driven reprice first.',
        'Both designs are intentional. Pick the one that matches how you want the reserve to behave when underlyings move.',
      ],
    },
    {
      heading: 'What the switch changes',
      paragraphs: [
        'SE vault shares are raw token balances. A rate provider answers how much claim one share is worth right now against the vault’s rate target. Balancer can use that answer so pool math works in live claim units.',
      ],
      bullets: [
        'Mark accuracy (rates on) — live balance of a share leg scales with the SE rate. Nested mids re-mark as underlyings move, even before anyone trades the reserve.',
        'Market reprice (rates off) — the pool sees raw share amounts. If underlyings move and reserve inventory is quiet, the nested mid can hold while redeem claim value moves.',
        'Same raw inventory, two intents — continuous live marks versus raw-share mids that markets can reprice when the gap is worth trading.',
      ],
    },
    {
      heading: 'Mark accuracy (rates on)',
      paragraphs: [
        'Choose rate providers when accurate reserve pricing matters most: fair deposits, fair vault-share ↔ DETF quotes, and a synthetic price that tracks live claim as underlyings move.',
        'With rates on, the composed pool acts as a live ledger for the DETF reserve. Heterogeneous vault shares become comparable claim units in one Balancer book. Primary mint, burn, and deposit sizing can read that same book — not a separate admin NAV.',
      ],
      bullets: [
        'Live path — SE shares (raw) → rate providers (claim per share) → live reserve balances → synthetic price and deposit quotes.',
        'Fair deposits — joins and primary routes use rate-aware math so quotes stay aligned with claim value.',
        'Honest synthetic — Policy mode gates mint and burn from reserve-derived synthetic price. A current book keeps those gates and quotes tied to redeem-fair marks. Open mode still benefits: quotes stay current even though Open does not price-gate mint or burn.',
        'Who moves inventory — users rebalance exposure through deposit, mint, burn, and bond. Rates re-mark the book; they do not auto-shift weight from vault A to vault B. You do not need lag-driven arb to keep the mid honest.',
      ],
    },
    {
      heading: 'Market reprice (rates off)',
      paragraphs: [
        'Choose rates off when you want raw-share mids and stronger incentive for markets to trade the reserve when claim value and the nested mid diverge.',
        'As underlying venues move, SE rates update and residual mid lag can grow while raw inventory is quiet. That gap can invite closers to trade nested paths — more active reprice flow on the reserve when the edge clears fees, impact, and path costs.',
      ],
      bullets: [
        'Product upside — lag creates a signal for reprice volume that can push reserve inventory more actively than a continuously fair mid alone.',
        'Clear tradeoff — mids may not track claim value continuously until that flow happens. Deposit and synthetic quotes can inherit the lag in the meantime.',
        'Fee-aware — residual is not free yield. Research closers only filled when residual cleared the fee stack; modest lag can sit with no fills.',
        'Best fit — compositions that want market-driven reprice on nested SE-share legs and accept less continuous mark accuracy.',
      ],
    },
    {
      heading: 'Side-by-side: same underlying move',
      paragraphs: [
        'Toy path: the reserve holds a fixed raw amount of SE shares. The underlying market moves so the SE rate goes from 1.00 to 1.05. No one has traded the reserve yet.',
      ],
      bullets: [
        'Rates on — live share balance scales up; the pool’s quote per raw share re-marks with claim value. Residual mid×rate stays near zero. A deposit or mint against that leg tracks live claim more closely.',
        'Rates off — raw mid holds; redeem claim moved about five percent. Residual grows. That gap can later invite reprice trades if it clears costs; until then, quotes can sit away from live claim.',
        'Why scaling under rates on is not free arb — the scale is re-pricing live claim units so the book stays fair. Reprice incentive shows up when the mid is left raw (rates off) and residual is large enough to trade.',
      ],
    },
    {
      heading: 'How to choose',
      paragraphs: [
        'Match the flag to product goals. Families may expose this as a deploy-time option on SE-share reserve legs. Defaults can differ by package — read instance args for the DETF or vault you care about.',
      ],
      bullets: [
        'Choose mark accuracy (rates on) when fair primary deposits, live multi-leg accounting, and redeem-aligned synthetic matter most — with users moving inventory through product routes.',
        'Choose market reprice (rates off) when you want lag to invite closer volume across the reserve and accept that mids may trail claim until that volume trades.',
        'Weighted, stable, or multi-token design changes impact and path shape — not the core choice between continuous re-mark and raw-share reprice. More legs make a clear mark policy more important, because more raw counts can look similar when their claims are not.',
      ],
    },
    {
      heading: 'What research measured',
      paragraphs: [
        'Hermetic Uni V2 SE runs compared pure rates-on and rates-off worlds under the same demand path. Those matrices used a research Balancer const-prod fee of 5% — treat fee thresholds as scenario-specific, not a universal production rule.',
      ],
      bullets: [
        'Underlying demand only: rates on → residual ≈ 0 across volume tiers tested; rates off → residual scales with volume (tens of bps at modest stress into multi-percent and higher under extreme tiers).',
        'Modest closer probes: residual below the research fee stack → no fills — lag without a free lunch.',
        'Extreme stress: when residual cleared fees, fills appeared — reprice volume becomes real once edge clears costs. Multi-path stress can still produce some fills with rates on; residual series still separates continuous re-mark (on) from raw mid lag (off).',
        'Figures on this site (when R4 ships): residual and fairness compares under matched demand. Until then: monorepo research/out/uniswapV2Se/rateProviderCompare/ and research/scenarios/uniswapV2Se/rateProviderCompare/.',
      ],
    },
    {
      heading: 'Short FAQ',
      paragraphs: [
        'Can I deploy either way? Yes — when the package allows the flag. Both are intentional mark policies.',
        'Which is better for a fair primary market? Mark accuracy (rates on).',
        'Which invites reprice volume on nested legs? Market reprice (rates off), when residual clears costs — not guaranteed every path.',
        'Do rate providers rebalance weights for me? No. Rates on re-mark live claim. Rates off leave raw mids for markets to reprice. Users still deposit, mint, burn, and bond to change exposure.',
        'Does Open mode make rates irrelevant? No. Open removes price restrictions on primary mint and burn; quote quality still follows how the reserve marks SE legs.',
        'Where does this sit in the stack? SE vaults under Earn and many DETF reserve legs. Basket shape: /research/detf-types. Liquid share vs bond path: /research/bond-vs-mint. DETF overview: /research/detf.',
      ],
    },
  ],
}
