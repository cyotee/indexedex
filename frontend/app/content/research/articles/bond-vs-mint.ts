import type { ResearchArticle } from '../types'

/**
 * Bond vs mint — two ways to participate in a DETF.
 * Product law: docs/marketing/DETF_NARRATIVE_SPINE.md; bond/claim paths in AGENTS.md DETF section.
 * Avoid APY / guaranteed seigniorage language.
 */
export const bondVsMintArticle: ResearchArticle = {
  slug: 'bond-vs-mint',
  title: 'Bond vs mint: liquid share or seigniorage path',
  summary:
    'Mint for DETF tokens you can hold, transfer, and use elsewhere. Bond to deepen protocol-owned reserve and take a position that can claim into the seigniorage economy of that DETF — not free spendable supply at the same moment.',
  date: '2026-07-27',
  tags: ['detf', 'bond', 'mint', 'product'],
  status: 'published',
  claims: [
    'Minting against the primary market issues free DETF ERC-20 to the user (subject to Policy/Open, liveness, and fees).',
    'Bonding deposits into protocol-owned reserve depth under onchain bond terms and produces a bond position (typically an NFT), not the same free-transferable DETF stack as mint.',
    'Selling a bond position to the protocol (when wired) can mint rebasing claim on protocol-owned reserve — a path into fee / seigniorage participation for that DETF.',
    'First successful bond also takes an inert DETF live; mint of user DETF against vault shares stays blocked until live.',
  ],
  notClaiming: [
    'Bonding is not a guaranteed share of every future mint, fixed APY, or risk-free yield.',
    'Mint does not guarantee peg, secondary liquidity, or profitable use in other protocols.',
    'Claim redeem paths unwind toward configured rate assets after burning claim shares — not free BPT authority without that burn.',
    'Fees, lock terms, and splits come from onchain configuration (fee oracle where wired); amounts are not promises.',
    'This note is product mechanics education, not measured seigniorage performance.',
  ],
  relatedProductHref: '/staking',
  relatedProductLabel: 'Open Protocol DETF',
  sourceNote:
    'Bond / claim lifecycle: monorepo AGENTS.md DETF section; family PRDs under contracts/vaults/detf/**; spine §4 (lifecycle, routes). Narrative: docs/marketing/DETF_NARRATIVE_SPINE.md.',
  sections: [
    {
      heading: 'Two different outcomes',
      paragraphs: [
        'A DETF (Decentralized ETF) offers more than one way in. The useful split is not “better vs worse” — it is what you hold when the transaction settles.',
        'Mint is for liquid DETF: a share token you can transfer, trade when markets exist, and plug into other protocols that accept that ERC-20. Bond is for the seigniorage path: you help build protocol-owned reserve and take a position that can participate in how that DETF’s supply and fee economy work over time — usually with locks and claim mechanics, not instant free float.',
      ],
    },
    {
      heading: 'What mint gives you',
      paragraphs: [
        'On a live DETF, primary-market mint exchanges configured vault shares (or a family-defined input) for DETF. The diamond is the share ERC-20 — free DETF lands in your wallet after fees and mode rules apply.',
      ],
      bullets: [
        'Outcome — spendable / transferable DETF supply (subject to any venue that accepts it).',
        'Use cases — hold the basket share, sell later, or compose with other DeFi that takes the DETF token.',
        'Gates — instance must be live; Policy may block mint near peg; Open does not price-gate mint. Fees may still apply.',
        'Exit on the primary market — burn DETF back toward configured vault shares when mode and liveness allow.',
      ],
    },
    {
      heading: 'What bond gives you',
      paragraphs: [
        'Bonding is how the product deepens protocol-owned reserve and how many families wire long-horizon participation. You bond under oracle terms (lock floors and ceilings apply where configured). The typical v1 shape is a bond NFT that records principal — not an immediate free mint of the full DETF stack into your wallet for spend.',
        'When the package wires claim: sell the bond position to the protocol, move principal into protocol accounting, and mint rebasing claim on protocol-owned reserve BPT. That claim path is the seigniorage-style participation surface — a share of protocol-owned depth and fee mechanics for that DETF instance, not a promise of constant rebase yield.',
      ],
      bullets: [
        'Outcome — bond position (NFT) and, when sold to protocol, rebasing claim — not the same liquid DETF as mint at the same step.',
        'Use cases — go long the instance’s protocol-owned economy; first bond also takes an inert DETF live.',
        'Gates — lock terms from configuration; first bond often ungated by synthetic supply rules because there is no live product yet.',
        'Exit — hold to term, sell to protocol when ready, redeem claim by burning claim shares and unwinding toward configured rate asset(s).',
      ],
    },
    {
      heading: 'Merits side by side',
      paragraphs: ['Choose by the asset you want, not by marketing labels:'],
      bullets: [
        'Prefer mint when you want DETF you can move, spend, or integrate elsewhere now.',
        'Prefer bond when you want protocol-owned depth and a claim into that DETF’s seigniorage / fee path rather than free float.',
        'You can often use both over time: bond to help the product go live or deepen reserve; mint later when Policy or Open allows and you want liquid shares.',
        'Neither path invents yield. Value can come from reserve composition, fees when they apply, and secondary markets — never from a promised APY in this note.',
      ],
    },
    {
      heading: 'How this shows up in the app',
      paragraphs: [
        'Protocol DETF on /staking is the live product surface for mint, burn, bond, sell, and claim when configured. Research here explains the tradeoff; the product page names actions by verb (Bond, Mint, Burn, Claim).',
        'Companion notes: What is a DETF? (pattern and modes), DETF types (which reserve shape you stand up), and Rate providers (mark accuracy vs market reprice for nested vault-share legs).',
      ],
    },
  ],
}
