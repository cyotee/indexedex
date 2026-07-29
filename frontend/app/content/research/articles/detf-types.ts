import type { ResearchArticle } from '../types'

/**
 * DETF types (families) in plain customer language.
 * Four composition packages under contracts/vaults/detf/ (Single SE + multi-vault families).
 * Package names stay out of titles — engineer paths only in sourceNote.
 * SingleVaultDetf (composed/single) is deprecated / out of product map — hardcoded SE path.
 */
export const detfTypesArticle: ResearchArticle = {
  slug: 'detf-types',
  title: 'DETF types: which design for which basket',
  summary:
    'IndexedEx’s premier product is four DETF designs — not one black-box fund. They share the same DETF pattern (one share over a real reserve, bond / mint / burn) with different reserve layouts: single Standard Exchange, multi-vault weighted, multi-vault stable (layered composition), and mixed-buffer stable (one buffer + vaults).',
  date: '2026-07-27',
  tags: ['detf', 'types', 'platform', 'product'],
  status: 'published',
  claims: [
    'There are four DETF composition types under the product map — types differ in reserve layout and inputs, not in inventing a second product category.',
    'Single Standard Exchange DETFs pair the DETF share with exactly one SE vault share in a weighted reserve. Any Standard Exchange vault may be the external leg (no hardcoded venue).',
    'Multi-vault weighted DETFs put several SE vault shares next to DETF in one weighted reserve with custom weights and independent valuations.',
    'Multi-vault stable (composed) DETFs layer two intermediate Balancer stable pools of the same SE vault shares under different rate views, then put DETF plus those two pool BPTs in a weighted top reserve — so the vault set is composed into one structure.',
    'Mixed-buffer multi-vault stable DETFs use one MixedBuffer stable pool: DETF, exactly one buffer token, and vault shares that process that buffer; mint buffer or vault share → DETF; burn DETF → buffer only.',
  ],
  notClaiming: [
    'No type is a registered securities ETF or fund share.',
    'Type choice does not guarantee peg, yield, or secondary market depth.',
    'Family availability depends on what is deployed on a given network — this note is the design map, not a live catalog guarantee.',
    'Deploy package names in code are not customer product titles.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'What is a DETF?',
  sourceNote:
    'Four families under contracts/vaults/detf/: standardExchange/single (SingleStandardExchangeDETF); composed/multi-vault-weighted (MultiVaultWeightedDetf); composed/stable/common (ComposedStableCommonDetf); composed/stable/mixedBuffer (MixedBufferMultiVaultStableDetf). composed/single (SingleVaultDetf) is deprecated — not a product type. Spine: docs/marketing/DETF_NARRATIVE_SPINE.md §2.',
  sections: [
    {
      heading: 'One pattern, four compositions',
      paragraphs: [
        'DETF means Decentralized ETF: one onchain share over a real multi-asset reserve. IndexedEx’s premier product is standing up that pattern from more than one package type — so a one-vault basket is not forced into the same reserve layout as a multi-leg weighted or stable design.',
        'Every true DETF still: is the ERC-20, prices from its reserve, deploys inert until first bond (or family bootstrap), and offers Policy or Open mint/burn rules. Types change how legs are composed and which inputs mint or burn accept — not whether the product is “really a DETF.”',
        'A design rule across all types: reserve vault legs are Standard Exchange vaults injected at deploy — the DETF does not hardcode a single protocol backend.',
      ],
    },
    {
      heading: 'What is a Standard Exchange vault?',
      paragraphs: [
        'Before the four DETF layouts: a Standard Exchange (SE) vault is IndexedEx’s vault standard for integrating an external protocol. Each SE vault uses the same deposit / share / redeem surface. You deposit underlyings, hold an ERC-20 vault share, and redeem later — without learning a different API per venue.',
        'Example: a Uniswap V4 SE vault wraps V4 liquidity exposure as that share. Example: an Euler SE vault wraps lending-market exposure the same way. The vault is the adapter to Uni or Euler; products above it only see the SE share.',
        'SE vaults are not DETF types and not another composition family. They are building blocks on Earn, in routers, and as optional reserve legs. The types below describe how those shares sit in a DETF reserve — not how Uniswap or Euler themselves work. Venue names are illustrative, not an exclusive live list.',
      ],
    },
    {
      heading: '1. Single Standard Exchange DETF',
      paragraphs: [
        'Weighted reserve with two legs: the DETF share and exactly one Standard Exchange vault share (default weights often 80% DETF / 20% vault share, overridable at deploy). Classic mental model: one vault-share surface against DETF mint and burn, with bond into protocol-owned depth. First live path is first bond with vault shares. The diagram below shows the composition; Uniswap V4 and Euler under the SE vault are example backends, not a fixed venue list.',
      ],
      bullets: [
        'Best when — one external vault leg is enough for the basket.',
        'Primary market — vault shares ↔ DETF (exact-in closed form preferred).',
        'Avoid for — several vault legs, fixed multi-leg weights, or a shared cash buffer fan-out.',
      ],
      diagram: 'single-standard-exchange',
    },
    {
      heading: '2. Multi-Vault Weighted DETF',
      paragraphs: [
        'Weighted reserve: DETF plus one to seven Standard Exchange vault shares, each with a custom immutable weight. Use when a stable pool is the wrong abstraction — unrated shares, disparate rate targets (different assets), or same nominal asset but distinct market identity that must stay separate legs.',
      ],
      bullets: [
        'Best when — you need fixed basket weights and independent valuations across vault products.',
        'Primary market — configured vault shares ↔ DETF only (deposit into the SE vault first if you hold underlyings).',
        'First live path — initialize the reserve, then bond reserve BPT (family-specific).',
        'Claim redeem (when wired) — toward any configured rate asset of a rated leg.',
        'Avoid for — like-kind multi-vault cash baskets better served by multi-vault stable or mixed-buffer.',
      ],
      diagram: 'multi-vault-weighted',
    },
    {
      heading: '3. Multi-Vault Stable (Composed)',
      paragraphs: [
        'For several like-kind Standard Exchange vaults that should end up in one composed DETF structure — not as a flat weighted list of raw vault shares next to DETF, and not as Mixed-buffer’s single buffer pool.',
        'Composition is layered so every contained vault share is still bound into the same product. Deployer configures two rate groupings over the same vault set: a stable grouping (each vault gets its own rate target — unique per vault) and a common grouping (every vault shares one common rate target). The package builds two intermediate Balancer V3 Stable Pools that both hold those SE vault shares (only the rate markings differ). Joining vault shares into either pool mints that pool’s BPT.',
        'The true DETF reserve is a Weighted Pool of three legs: DETF (self), Stable Pool BPT, and Common Pool BPT. DETF lives only on that top pool; the intermediate stables do not hold DETF. Economically, the layers exist so many vault exposures compose as if they were paired together under one share — two multi-vault composition receipts plus DETF, instead of pairing two lone coins.',
      ],
      bullets: [
        'Best when — multi-vault like-kind composition under dual rate views (per-vault stable targets + one shared common target).',
        'Intermediate pools — both are Stable Pools; both hold the same SE vault shares; rates differ by grouping.',
        'Top reserve — weighted: DETF + Stable BPT + Common BPT; DETF inventory is that weighted pool’s BPT.',
        'Routing — deposits can route into vaults and intermediate pools by lowest rated liquidity (family rules).',
        'Not Mixed-buffer — no single buffer token as the primary cash leg of one mixed stable reserve.',
      ],
      diagram: 'multi-vault-stable',
    },
    {
      heading: '4. Mixed-Buffer Multi-Vault Stable',
      paragraphs: [
        'For one shared cash asset and one to three Standard Exchange vaults that all accept and produce that asset. The reserve is a single MixedBuffer stable pool — not a weighted multi-risk basket, and not the dual intermediate-BPT graph above.',
        'Reserve legs: unpaired DETF self-leg, exactly one buffer token, and the vault share legs. That single buffer is the point: vaults fan in and out of the same cash unit. Live mint accepts buffer or any configured vault share; burn of DETF settles to buffer only. Liveness uses a permissionless first-bond bootstrap (user supplies non-DETF legs; DETF seeds its self-leg into the reserve; bond NFT principal on the bootstrap position).',
      ],
      bullets: [
        'Best when — staking or lending “cash families” where many vaults process one buffer asset.',
        'Exactly one buffer — not several buffer tokens; rate asset for this family equals that buffer.',
        'Mint — buffer or vault share → DETF; burn — DETF → buffer only.',
        'Bond inputs after live — buffer or vault shares; claim redeem to buffer when wired.',
        'Avoid for — disparate asset weights (use multi-vault weighted) or dual intermediate stable+common composition (use multi-vault stable composed).',
      ],
      diagram: 'mixed-buffer-multi-vault-stable',
    },
    {
      heading: 'How to choose',
      paragraphs: ['Start from the basket, not from package names:'],
      bullets: [
        'One SE vault leg → Single Standard Exchange.',
        'Several vaults, different valuations / fixed weights → multi-vault weighted.',
        'Several like-kind vaults composed into one structure via dual rate views + weighted top → multi-vault stable (composed).',
        'Several vaults on one cash buffer, mint buffer or shares, burn to that buffer → mixed-buffer multi-vault stable.',
      ],
    },
  ],
}
