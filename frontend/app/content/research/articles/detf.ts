import type { ResearchArticle } from '../types'

/**
 * Flagship DETF product note.
 * Claims and mode language follow docs/marketing/DETF_NARRATIVE_SPINE.md §5 / §7
 * and indexedex-product-voice (Open = no price restrictions on mint/burn).
 */
export const detfArticle: ResearchArticle = {
  slug: 'detf',
  title: 'What is a DETF?',
  summary:
    'DETF means Decentralized ETF — the D is decentralized. One onchain share over a real multi-asset reserve, often built from Standard Exchange vault shares (IndexedEx’s standard for integrating external protocols). Premier offer: create DETFs from many types. Protocol DETF: share of protocol fees. Policy price-gates mint/burn; Open never does.',
  date: '2026-07-27',
  tags: ['detf', 'product'],
  status: 'published',
  claims: [
    'The DETF diamond is the share ERC-20 — one token surface for the product.',
    'Standard Exchange (SE) is IndexedEx’s vault standard: one interface that wraps external protocols so DETFs and Earn can integrate them the same way.',
    'Example backends: Uniswap V4 as a DEX integration; Euler as a lending integration — both appear as SE vault shares to the rest of the stack.',
    'Reserve pricing lives in a Balancer V3 pool, not an off-pool dashboard ledger.',
    'Instances deploy inert; the first successful bond takes them live and deepens protocol-owned reserve.',
    'Policy mode restricts primary mint/burn by synthetic price thresholds; Open mode has no price restrictions on mint or burn.',
    'After deploy, instances are immutable and unowned for normal operation.',
  ],
  notClaiming: [
    'A DETF is not a registered securities ETF or fund share.',
    'Holding DETF or reserve assets is not legal ownership of offchain stocks or underlyings.',
    'SE vaults are not DETF types; they are the standard adapter under strategy vaults and DETF reserve legs.',
    'Naming Uniswap V4 or Euler is illustrative — not an exclusive or guaranteed live catalog on every network.',
    'Policy thresholds (or choosing Open) are not a guarantee of peg stability or yield.',
    'There is no promised APY, rebase return, or “(3,3)” performance.',
    'Open removes price gates only — it does not erase fees or invent returns.',
  ],
  relatedProductHref: '/staking',
  relatedProductLabel: 'Open Protocol DETF',
  sourceNote:
    'Product rules: contracts/vaults/detf/** PRDs (incl. DETF_Threshold_Modes_PRD.md) and monorepo AGENTS.md DETF section. Narrative spine: docs/marketing/DETF_NARRATIVE_SPINE.md. Research roll-up: research/MARKETING_AND_PERFORMANCE_FINDINGS.md.',
  sections: [
    {
      heading: 'What DETF means',
      paragraphs: [
        'DETF expands to Decentralized ETF. The D is decentralized: this is an onchain product pattern, not a registered securities ETF. User intent stays simple — one share over a basket of legs — without a fund administrator or a discretionary rebalancer.',
        'IndexedEx’s premier product is the platform: deployable packages so you can stand up your own reserve-backed DETFs across several types (single Standard Exchange, multi-vault weighted, multi-vault stable, mixed-buffer stable) — with explicit bond, mint, and burn rules. Not a spreadsheet index, and not a single branded black-box fund.',
        'Protocol DETF is how you earn a share of protocol fees using that same DETF design (home: /staking). Fees may apply; amounts are not guarantees. Same bond / mint / burn pattern as any DETF — one you can open today for protocol fee participation.',
      ],
    },
    {
      heading: 'What is a Standard Exchange vault?',
      paragraphs: [
        'A Standard Exchange (SE) vault is IndexedEx’s vault standard for integrating an external protocol under one interface. You deposit into the vault, receive an ERC-20 vault share, and redeem that share later — deposit / share / redeem is the same shape no matter which protocol sits underneath.',
        'Example: a Uniswap V4 SE vault wraps V4 liquidity exposure as that share. Example: an Euler SE vault wraps lending-market exposure the same way. The vault, not the DETF, talks to Uni or Euler; other products only need the SE share surface.',
        'SE vaults are not DETF types. They are adapters you can use on Earn, in routers, or as reserve legs when a DETF is composed. Naming Uniswap V4 or Euler is illustrative — not an exclusive live catalog on every network.',
      ],
    },
    {
      heading: 'Core shape',
      paragraphs: ['A true DETF combines these design choices:'],
      bullets: [
        'Share token — the diamond proxy is the ERC-20 users hold.',
        'Reserve — a Balancer V3 pool that includes the DETF self-leg and external legs (often SE vault shares).',
        'Bonding — first bond establishes liveness and protocol-owned reserve depth; bond terms come from onchain configuration.',
        'Primary market — preferred routes are configured vault shares against DETF (exact-in, closed-form where supported).',
        'Threshold mode — deploy-time Policy (price-gated mint/burn) or Open (no price restrictions on mint/burn). Zero thresholds never mean Open.',
        'Immutability — no instance owner, no diamondCut, no admin pause surface for normal operation after deploy. Flawed config means a new package, not discretionary fixes on a live instance.',
      ],
    },
    {
      heading: 'Policy vs Open',
      paragraphs: [
        'Deploy-time mode chooses whether primary mint and burn care about synthetic price. Synthetic valuation still comes from the reserve pool for transparency (and for Policy gates). Open does not use synthetic price to block mint or burn.',
      ],
      bullets: [
        'Policy (default) — mint only when synthetic price is strictly above the mint threshold; burn only when strictly below the burn threshold. Defaults commonly resolve to 1.05e18 / 0.95e18 (±5% around an abstract 1e18 peg). Inside the band, primary mint/burn stay quiet; the reserve AMM and other routes remain available.',
        'Open — no price restrictions on primary mint or burn. Users can mint and burn regardless of synthetic price. Fees and protocol fee splits still apply. Mode is explicit at deploy; zero threshold args never imply Open.',
        'When thresholds are stored, both modes still require mint threshold greater than burn threshold after zeros resolve to defaults (config validity — not an Open price gate).',
      ],
    },
    {
      heading: 'How users typically interact',
      paragraphs: [
        'Preferred live routes are configured vault shares against DETF on the product surface (exact-in, closed-form where supported). Users often deposit into a Standard Exchange vault first, then use shares — rate-asset zaps are family-specific and not assumed universal.',
        'Bond and claim paths (where wired) move principal into protocol accounting and can mint rebasing claim on protocol-owned reserve BPT. Redeem paths burn claim and unwind toward configured rate assets — never free BPT authority without burning claim shares.',
      ],
    },
    {
      heading: 'Why research matters',
      paragraphs: [
        'Nested reserve legs follow a deploy-time rate policy — mark accuracy or market reprice. Companion notes cover DETF types (which reserve shape to stand up), bond vs mint (liquid share vs seigniorage path), and rate providers (that choice for SE-share legs). Measured fee-share (Protocol DETF) performance campaigns are product-ops work beyond this mechanics note.',
      ],
    },
  ],
}
