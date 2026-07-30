import type { ResearchArticle } from '../types'

/**
 * Bond vs mint — liquid share vs protocol depth / claim.
 * Product law: docs/marketing/DETF_NARRATIVE_SPINE.md; AGENTS.md DETF section;
 * Open = no price restrictions on mint/burn (indexedex-product-voice).
 * Avoid APY / guaranteed seigniorage language.
 */
export const bondVsMintArticle: ResearchArticle = {
  slug: 'bond-vs-mint',
  title: 'Bond vs mint: liquid share or protocol depth',
  summary:
    'Mint gives you DETF in your wallet—the basket share you can move and use. Bond deepens protocol-owned reserve and can lead to a claim path into that instance’s fee economy—not free spendable DETF at the same step. Whether mint is open when you’re live depends on the instance: Policy may block mint/burn on synthetic price; Open never price-gates mint or burn.',
  date: '2026-07-29',
  tags: ['detf', 'bond', 'mint', 'product'],
  status: 'published',
  claims: [
    'Mint issues free DETF ERC-20 when the instance is live (fees may apply). Policy may block mint or burn on synthetic price; Open has no price restrictions on primary mint or burn.',
    'Bonding deepens protocol-owned reserve under onchain bond terms and produces a bond position (typically an NFT)—not the same free-transferable DETF stack as mint.',
    'First successful bond takes an inert DETF live; user mint against vault shares stays blocked until live. First bond is not synthetic-gated the way live Policy mint is.',
    'Bond positions can earn free DETF rewards from capital seigniorage and, on Policy when synthetic is rich, natural expansion. Free unlocked DETF with no bond does not receive expansion.',
    'Users claim free DETF on their bonds while locked. Protocol-owned bond rewards compound into more protocol-owned reserve BPT; user bonds do not auto-compound into the pool in v1.',
    'Selling a bond position to the protocol (when wired) can mint claim on protocol-owned reserve—a fee / depth participation path, not guaranteed yield.',
    'Deploy-time mode does not redefine bond: Open and Policy change when primary mint/burn are open on price, not what a bond position is. Open never runs natural expansion.',
  ],
  notClaiming: [
    'Bonding is not a guaranteed share of every future mint, fixed APY, or risk-free yield.',
    'Mint does not guarantee peg, secondary liquidity, or profitable use in other protocols.',
    'Open removes price gates only — it does not erase fees, invent returns, or enable natural expansion.',
    'Natural expansion is not an airdrop to all DETF holders and is not available in Open mode.',
    'Protocol compound does not guarantee claim redemption growth or a fixed coupon.',
    'Policy thresholds are not a guarantee of peg stability or yield.',
    'Claim redeem paths unwind toward configured rate assets after burning claim shares — not free reserve BPT authority without that burn.',
    'Fees, lock terms, and splits come from onchain configuration (fee oracle where wired); amounts are not promises.',
    'This note is product education, not measured seigniorage or fee performance.',
  ],
  relatedProductHref: '/staking',
  relatedProductLabel: 'Open Protocol DETF',
  sourceNote:
    'Bond / claim lifecycle: monorepo AGENTS.md DETF section; family PRDs under contracts/vaults/detf/**; Protocol Compound + Supply Expansion PRD + HANDOFF_FOR_DOCS_AND_UI; spine §4–§5. Narrative: docs/marketing/DETF_NARRATIVE_SPINE.md. Companions: /research/detf, /research/detf-types, /research/rate-providers.',
  sections: [
    {
      heading: 'Two different outcomes',
      paragraphs: [
        'A DETF (Decentralized ETF) offers more than one way in. The useful split is not “better vs worse” — it is what you hold when the transaction settles.',
        'Mint is for liquid DETF: a share token you can transfer, trade when markets exist, and plug into other protocols that accept that ERC-20. Bond is for protocol-owned depth: you help build shared reserve and take a position that can participate in that instance’s fee economy over time — usually with locks and, when wired, claim mechanics, not instant free float.',
      ],
    },
    {
      heading: 'What mint gives you',
      paragraphs: [
        'On a live DETF, primary-market mint exchanges configured vault shares (or a family-defined input) for DETF. The DETF token is the share — free DETF lands in your wallet after fees, when mint is allowed.',
      ],
      bullets: [
        'Outcome — spendable / transferable DETF (the basket share), subject to any venue that accepts it.',
        'Use cases — hold the reserve composition in one token, sell later, or compose with other DeFi that takes the DETF.',
        'Exit on the primary market — burn DETF back toward configured vault shares when burn is allowed.',
        'When mint is open — instance must be live. Whether synthetic price also blocks mint depends on Policy vs Open (next section). Fees may still apply either way.',
      ],
    },
    {
      heading: 'What bond gives you',
      paragraphs: [
        'Bonding deepens protocol-owned reserve under onchain terms (lock floors and ceilings apply where configured). The typical v1 shape is a bond NFT that records principal — not an immediate free mint of spendable DETF into your wallet.',
        'While locked, bond effective shares can earn free DETF rewards: capital seigniorage when others mint or bond with capital, and — on Policy instances when synthetic is rich — natural expansion over time. You claim that free DETF; it is not forced into the pool for users. Protocol-owned bonds auto-compound their rewards into more reserve BPT instead.',
        'When the package wires claim: sell the bond position to the protocol, move principal into protocol accounting, and mint claim on protocol-owned reserve. That claim path is fee / depth participation for that instance — not a promise of constant rebase yield. Redeem burns claim shares and unwinds toward configured rate asset(s). Protocol compound that raises protocol BPT can improve claim backing — it does not guarantee a coupon.',
      ],
      bullets: [
        'Outcome — bond position (NFT) and, when sold to protocol, claim — not the same liquid DETF as mint at the same step.',
        'Rewards — claim free DETF while locked (seigniorage + Policy expansion when rich). Free unlocked DETF alone gets no expansion airdrop.',
        'Use cases — go long the instance’s protocol-owned economy; first successful bond also takes an inert DETF live so others can mint later.',
        'Gates — lock terms from configuration. First bond is not synthetic-gated the way live Policy mint is (both Policy and Open).',
        'Exit — hold to term, sell to protocol when ready, redeem claim by burning claim shares — never free reserve BPT authority without that burn.',
      ],
    },
    {
      heading: 'How Policy vs Open changes mint',
      paragraphs: [
        'Every DETF picks a deploy-time mode for primary mint and burn. Mode does not redefine bond: locks, NFT shape, and claim wiring stay the depth path. Mode only answers whether synthetic price can block mint or burn when the instance is live.',
      ],
      bullets: [
        'Policy (default) — mint only when synthetic price is strictly above the mint threshold; burn only when strictly below the burn threshold. Near peg (inside the band), primary mint and burn stay quiet; the reserve AMM and other routes remain available. Bond still works under bond terms.',
        'Open — no price restrictions on primary mint or burn. When live, users can mint and burn regardless of synthetic price. Fees and fee splits may still apply. Open does not turn bond into mint and never runs natural expansion.',
        'First bond / go-live — still required before user mint. First bond remains synthetically ungated in both modes; Open does not skip inert → live.',
        'Full mode copy — /research/detf (Policy vs Open). This note only covers how mode affects the mint vs bond choice.',
      ],
    },
    {
      heading: 'Rewards: who gets free DETF',
      paragraphs: [
        'Mint lands free DETF in your wallet. Bond can land free DETF in your bond reward balance over time. Those are different books.',
      ],
      bullets: [
        'Capital seigniorage — real capital mints/bonds can pay free DETF into the bond reward ledger (fee and inventory splits as configured).',
        'Natural expansion — Policy + live + synthetic above mint threshold may mint free DETF over time into that same ledger. Open never expands. No new external capital on that path.',
        'Claim while locked — users take free DETF out of pending rewards; they are not auto-compounded into the reserve in v1.',
        'Protocol compound — only the protocol’s bond position auto-sinks rewards into more protocol-owned BPT (single-sided DETF join). That can help claim holders; it is not a promised yield rate.',
        'Free holders without a bond — no expansion airdrop. If you only hold free DETF, you are not on the expansion distribution path.',
      ],
    },
    {
      heading: 'Side by side',
      paragraphs: [
        'Toy path: the DETF is live, you hold configured vault shares, and you want exposure. Synthetic price sits near the abstract peg unless noted.',
      ],
      bullets: [
        'Policy, synthetic in the deadband — primary mint and burn blocked on price. You can still bond under bond terms (depth / position), or use reserve and secondary routes. Mint waits until synthetic is rich enough.',
        'Policy, synthetic rich (above mint threshold) — mint open for liquid DETF. Bond remains optional if you want depth and claim rather than free float.',
        'Open, any synthetic — mint open on price when live. Choosing bond vs mint is almost pure intent: wallet DETF now vs protocol depth / claim — not “wait for a price gate.”',
        'Still inert (either mode) — user mint blocked. First bond is how the product goes live and seeds protocol-owned reserve.',
      ],
    },
    {
      heading: 'How to choose',
      paragraphs: ['Choose by the asset you want and by the instance’s mode — not by marketing labels:'],
      bullets: [
        'Prefer mint when you want DETF you can move, spend, or integrate elsewhere now — and mint is open (live + Open, or live + Policy with synthetic rich enough).',
        'Prefer bond when you want protocol-owned depth, reward eligibility (seigniorage / Policy expansion), help take an instance live, or a claim into that DETF’s fee path rather than free float.',
        'On Policy near peg — bond (or the reserve AMM) may be your path while primary mint/burn stay quiet. Expansion also stays off when synthetic is not mint-rich. Bond is not only a “yield” story.',
        'On Open — do not treat bond as a mint workaround. When live, mint is open on price; bond is intentional depth and claim. Open never expands.',
        'You can use both over time: bond to go live or deepen reserve; mint later when you want liquid shares and rules allow.',
        'Neither path invents yield. Value can come from reserve composition, bonding into shared depth, fees when they apply, and secondary markets — never from a promised APY in this note.',
      ],
    },
    {
      heading: 'Short FAQ',
      paragraphs: [
        'Can I mint before the first bond? No. Instances deploy inert; user mint stays blocked until live. First bond is how many families go live.',
        'Does Open remove fees or invent returns? No. Open only removes price restrictions on primary mint and burn. Open also never runs natural expansion.',
        'Does Open change what bond is? No. Same depth / lock / claim shape. Mode does not redefine bond.',
        'Policy near peg — can I still bond? Yes, subject to bond terms and package wiring. Mint and burn may be closed on synthetic; bond is a different path.',
        'Do free DETF holders get natural expansion? No. Expansion accrues to bond effective shares when Policy + rich. Claim free DETF while locked if you hold a bond.',
        'Is claim free yield? No. Claim is participation after selling a bond to the protocol when wired — amounts and timing are not guarantees.',
        'Where do I act in the app? Create DETF (/create) to deploy your own. Open Protocol DETF (/staking) for the featured fee path. Product pages name actions by verb: Bond, Mint, Burn, Claim.',
        'Where next? DETF overview and modes: /research/detf. Reserve shapes: /research/detf-types. Mark accuracy vs reprice on SE legs: /research/rate-providers.',
      ],
    },
  ],
}
