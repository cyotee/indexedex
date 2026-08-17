import type { ResearchArticle } from '../types'

/**
 * Flagship DETF product note — intent-first (spine §3 benefits, then how / modes / hierarchy).
 * Claims and mode language follow docs/marketing/DETF_NARRATIVE_SPINE.md and indexedex-product-voice
 * (Open = no price restrictions on mint/burn; premier = create your own DETFs).
 */
export const detfArticle: ResearchArticle = {
  slug: 'detf',
  title: 'DETFs: one share over a real onchain reserve',
  summary:
    'A DETF (Decentralized ETF) is one onchain share over a multi-asset reserve — bond, mint, and burn priced from that pool, not from an admin spreadsheet. Create your own DETFs across several reserve shapes, or open Protocol DETF to participate in protocol fees. Same pattern either way: explicit rules, no discretionary rebalancer.',
  date: '2026-07-29',
  tags: ['detf', 'product'],
  status: 'published',
  claims: [
    'One DETF share is an ERC-20 over a real multi-asset reserve (typically Balancer V3), not a dashboard NAV.',
    'Mint, burn, and synthetic valuation read the reserve pool — balances, weights, fees, and rate providers when wired.',
    'Instances deploy inert; the first successful bond takes them live and deepens protocol-owned reserve.',
    'Policy mode price-gates primary mint and burn from synthetic price; Open mode has no price restrictions on mint or burn (fees may still apply).',
    'On Policy only, while live and synthetic is rich (above mint threshold), free DETF may accrue over time to bond holders — natural expansion. Open never expands this way.',
    'Protocol-owned bond rewards can compound into more protocol-owned reserve liquidity (BPT); users still claim free DETF on their own bonds.',
    'After deploy, true DETF instances are immutable and unowned for normal operation — flawed config means a new instance, not discretionary admin fixes.',
    'Premier offer: stand up your own DETFs from several types. Protocol DETF uses the same design so you can earn a share of protocol fees (amounts not guaranteed).',
  ],
  notClaiming: [
    'A DETF is not a registered securities ETF or fund share, and holding it is not legal ownership of offchain stocks or underlyings.',
    'No promised APY, rebase return, or peg guarantee.',
    'Open removes price gates only — it does not erase fees, invent returns, or enable natural expansion.',
    'Natural expansion is not a yield product for free unlocked DETF holders and is not available in Open mode.',
    'Protocol compound does not guarantee claim redemption growth or a fixed coupon.',
    'Policy thresholds are not a guarantee of peg stability or yield.',
    'Fee and seigniorage amounts (including Protocol DETF) are not guarantees.',
  ],
  relatedProductHref: '/staking',
  relatedProductLabel: 'Open Protocol DETF',
  sourceNote:
    'Product rules: contracts/vaults/detf/** PRDs (Threshold Modes; Protocol Compound + Supply Expansion) and monorepo AGENTS.md DETF section. Handoff: DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md. Narrative spine: docs/marketing/DETF_NARRATIVE_SPINE.md. Companion notes: /research/detf-types, /research/bond-vs-mint, /research/rate-providers. Hermetic research: research/scenarios/detf/singleSe/FINDINGS.md.',
  sections: [
    {
      heading: 'What you get',
      paragraphs: [
        'A DETF (Decentralized ETF) is an onchain share over a real multi-asset reserve. You hold one token surface over configured legs — often Standard Exchange vault shares and related onchain assets — with bond, mint, and burn rules that come from the pool, not from a discretionary manager or a separate spreadsheet ledger.',
        'You can create your own DETFs from IndexedEx’s family of reserve shapes, or open Protocol DETF when you want a path into protocol fees. Same product pattern either way: one share, explicit rules, no human rebalancer rewriting the book.',
      ],
    },
    {
      heading: 'Why that matters',
      paragraphs: [
        'ETF-shaped intent without a fund administrator: one transferable share over a basket of legs you can inspect onchain.',
      ],
      bullets: [
        'One share over a basket — exposure to the reserve’s composition (legs, weights, rates) in a single ERC-20, without a discretionary portfolio manager.',
        'Pricing from the reserve — mint, burn, and synthetic price read the Balancer V3 book. There is no off-pool “dashboard NAV” that can disagree with the pool.',
        'Bonding builds depth — instances start inert. The first successful bond takes them live and deepens protocol-owned reserve under onchain terms, not a market-maker promise.',
        'Explicit mint/burn policy — deploy-time Policy (price-gated seigniorage around synthetic) or Open (no price restrictions on primary mint and burn). Fees and fee splits can still apply in either mode.',
        'Bond rewards, not free-only airdrops — capital seigniorage inventory and (on Policy when synthetic is rich) natural expansion accrue to bond positions. Free unlocked DETF alone does not receive expansion.',
        'Protocol compound — the protocol’s bond rewards can sink into more protocol-owned reserve BPT without a keeper. That can strengthen claim backing when claim is wired; it is not a coupon.',
        'Immutable after deploy — no instance owner, no discretionary diamondCut, no admin pause surface as the product model. Flawed config means abandon and redeploy, not silent rewrites of a live instance.',
        'Honest primary routes — preferred vault-share ↔ DETF paths aim for preview that matches execution where the math is closed-form. That is a trust bar, not a yield claim.',
      ],
    },
    {
      heading: 'How you use it',
      paragraphs: [
        'Typical path on a live DETF: deposit into a strategy vault if you need vault shares, then mint DETF against those shares. Burn reverses that when mode and liveness allow. You hold, transfer, or use the DETF share where secondary markets and integrators accept it.',
        'Bond when you want to deepen protocol-owned reserve and take a position into that instance’s fee / claim path (often an NFT and, when wired, claim) rather than free liquid supply at the same step. Full tradeoff: /research/bond-vs-mint.',
      ],
      bullets: [
        'Mint — liquid DETF in your wallet (subject to live status, Policy/Open, and fees).',
        'Burn — exit primary market toward configured vault shares when allowed.',
        'Bond / claim — protocol-owned depth and long-horizon participation; first bond also takes an inert DETF live.',
        'Where value can come from — reserve composition, bonding into shared depth, fees when the family applies them, secondary trading when markets exist. Never a promised APY in this note.',
      ],
    },
    {
      heading: 'Policy vs Open',
      paragraphs: [
        'At deploy, every DETF chooses whether primary mint and burn care about synthetic price. Synthetic valuation still comes from the reserve for transparency; only Policy uses it to block mint or burn.',
      ],
      bullets: [
        'Policy (default) — mint only when synthetic is strictly rich (above the mint threshold); burn only when strictly cheap (below the burn threshold). Defaults commonly resolve to about ±5% around an abstract peg. Inside the band, primary mint/burn stay quiet; the reserve AMM and other routes remain available.',
        'Open — no price restrictions on primary mint or burn. Users can mint and burn regardless of synthetic price. Fees and protocol fee splits still apply. Mode is explicit at deploy; zero threshold args never imply Open.',
        'Choose by intent — Policy when you want seigniorage that expands and contracts with synthetic (and optional natural expansion when rich); Open when you want an always-open primary market and accept no natural expansion and no price gates.',
      ],
    },
    {
      heading: 'Capital seigniorage vs natural expansion',
      paragraphs: [
        'Two different ways free DETF can enter the bond reward system — keep them separate.',
      ],
      bullets: [
        'Capital seigniorage — someone mints or bonds with real vault shares (or family-defined capital). Fees and inventory splits can pay free DETF into the bond reward ledger.',
        'Natural expansion — only on Policy units that are live and synthetically rich (above the mint threshold). Over time, free DETF can mint without new external capital into that same bond reward ledger. Open never does this.',
        'Who gets it — bond holders (effective shares while locked). Holding free DETF with no bond does not earn expansion.',
        'Users claim free DETF on their bonds while locked. Protocol-owned bond rewards compound into more reserve BPT instead of sitting as free DETF forever.',
      ],
    },
    {
      heading: 'Create your own or open Protocol DETF',
      paragraphs: [
        'IndexedEx’s premier offer is the platform: deployable packages so you can stand up reserve-backed DETFs across several types — single Standard Exchange leg, multi-vault weighted, multi-vault stable, mixed-buffer stable, and more. Each type changes how the reserve is composed; bond, mint, and burn remain the same verbs. Type shapes: /research/detf-types.',
        'Protocol DETF is the same design class used as a path to earn a share of protocol fees (home: /staking). Fees may apply; amounts are not guarantees. It is not a separate product category — it is how you participate in protocol fee accrual with DETF mechanics you already understand.',
      ],
    },
    {
      heading: 'What sits under the share',
      paragraphs: [
        'Reserve legs are often Standard Exchange (SE) vault shares: deposit, receive an ERC-20 share, redeem later — the same shape whether the vault wraps a DEX book, lending market, or other protocol. The DETF talks to SE and Balancer; it does not need to bake venue brands into the product definition.',
        'How those share legs are marked (rate providers on for live claim accuracy, or off for market-driven reprice) is a separate deploy-time intent. That choice: /research/rate-providers. Strategy vaults live under Earn.',
      ],
    },
    {
      heading: 'Short FAQ',
      paragraphs: [
        'Is a DETF a registered stock ETF? No. It is an onchain product pattern — one share over onchain reserve assets, not a securities fund and not legal ownership of offchain underlyings.',
        'Does Open mean free yield or no fees? No. Open only removes price restrictions on primary mint and burn. Fees and splits can still apply; nothing invents returns. Open also never runs natural expansion.',
        'Does natural expansion pay everyone who holds DETF? No. It accrues to bond positions when Policy + rich. Free unlocked balances alone do not get an expansion airdrop.',
        'Do I need to create a DETF to use one? No. Open Protocol DETF on /staking for the protocol fees path, or hold any live DETF instance that accepts mint, burn, or bond.',
        'Mint or bond? Mint for liquid DETF you can move and use elsewhere. Bond for protocol-owned depth, reward eligibility, and the claim / fee path. Detail: /research/bond-vs-mint.',
        'Where next? Types and reserve shapes: /research/detf-types. Mark accuracy vs reprice on SE legs: /research/rate-providers. Live product: Open Protocol DETF on /staking. Strategy legs: /earn.',
      ],
    },
  ],
}
