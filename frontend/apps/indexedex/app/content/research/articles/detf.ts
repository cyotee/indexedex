import type { ResearchArticle } from '../types'

/**
 * Flagship DETF product note — intent-first (spine §3 benefits, then how / modes / hierarchy).
 * Claims and mode language follow docs/marketing/DETF_NARRATIVE_SPINE.md and indexedex-product-voice
 * (Open = no price restrictions on mint/burn; premier = create your own DETFs).
 */
export const detfArticle: ResearchArticle = {
  slug: 'detf',
  title: 'DETFs: one token over a basket',
  summary:
    'A DETF (Decentralized ETF) is how you deploy a strategy: one token over a basket that manages assets in other protocols. That token is a claim on a share of the managed reserve. The token also sits in market liquidity so the reserve can be managed. Create it, bond to turn it on, then mint or burn. Or open Protocol DETF for protocol fees.',
  date: '2026-07-29',
  tags: ['detf', 'product'],
  status: 'published',
  claims: [
    'A DETF token is one token over a basket that manages assets in other protocols, not a static list or a private spreadsheet value.',
    'That token is a claim on a share of the managed reserve.',
    'The DETF token sits in market liquidity. That is how the reserve behind the token is managed.',
    'Mint, burn, and the displayed price read the reserve itself.',
    'A new DETF starts off. The first successful bond turns it on and adds shared reserve.',
    'Policy can pause mint and burn when the price sits near target. Open never does (fees may still apply).',
    'On Policy only, while live and synthetic is rich (above mint threshold), free DETF may accrue over time to bond holders — natural expansion. Open never expands this way.',
    'Protocol-owned bond rewards can compound into more protocol-owned reserve liquidity (BPT); users still claim free DETF on their own bonds.',
    'After deploy, true DETF instances are immutable and unowned for normal operation — flawed config means a new instance, not discretionary admin fixes.',
    'Create your own DETFs from several types. Protocol DETF uses the same design so you can earn a share of protocol fees (amounts not guaranteed).',
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
        'A DETF (Decentralized ETF) is how you deploy a strategy as one token. The basket is not a list of idle tokens. It manages assets that sit in other protocols. You hold that one token instead of running each position yourself.',
        'The token is a claim on a share of the managed reserve. It also lives in market liquidity, which is how that reserve is managed. Create your own DETF, or open Protocol DETF for a path into protocol fees.',
      ],
    },
    {
      heading: 'Why that matters',
      paragraphs: [
        'IndexedEx is a strategy protocol. A DETF is the product you deploy. You get ETF-shaped exposure without handing the book to a fund administrator.',
      ],
      bullets: [
        'The basket manages assets in other protocols, not a static token list.',
        'The DETF token sits in market liquidity so the reserve can be managed.',
        'One token over a basket you can inspect onchain. The token is a claim on a share of that reserve.',
        'Price comes from the reserve, so a dashboard cannot disagree with the pool.',
        'Bond is the first real deposit. It turns the DETF on and adds to the reserve.',
        'Policy can pause mint and burn near a target price. Open never does. Fees can still apply.',
        'Bond holders, not free unlocked balances, sit in the fee and expansion path.',
        'After it goes live, nobody quietly rewrites the design. A bad setup means a new DETF.',
      ],
    },
    {
      heading: 'How you use it',
      paragraphs: [
        'Typical path on a live DETF: deposit into a vault if you need vault shares, then mint DETF. Burn reverses that when the mode allows. You can hold or move the token.',
        'Bond when you want to turn a new DETF on, add to the reserve, and sit in the fee or claim path. Detail: /research/bond-vs-mint.',
      ],
      bullets: [
        'Mint: DETF in your wallet, when the DETF is live and the mode allows it.',
        'Burn: exit back toward the vault shares in the basket.',
        'Bond: first deposit that turns a new DETF on; later bonds add to the reserve.',
        'Value can come from the mix, from bonding, from fees when they apply, or from trading. This note does not promise APY.',
      ],
    },
    {
      heading: 'Policy vs Open',
      paragraphs: [
        'When you create a DETF you choose whether mint and burn care about price. The reserve still shows a price either way. Only Policy uses that price to pause mint or burn.',
      ],
      bullets: [
        'Policy (default): mint when the price is clearly above target; burn when it is clearly below. Near the target, mint and burn pause. You can still trade elsewhere.',
        'Open: mint and burn stay available at any price. Fees can still apply. You choose this mode at create time; a zero setting is not Open.',
        'Pick Policy if you want mint and burn to quiet down near target. Pick Open if you want those doors to stay open.',
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
        'The main offer is the platform: deploy your own strategy as a DETF. Types change what the basket holds in other protocols. Bond, mint, and burn stay the same steps. Type shapes: /research/detf-types.',
        'Protocol DETF uses the same design so you can take part in protocol fees (home: /staking). Fees may apply. Amounts are not guarantees.',
      ],
    },
    {
      heading: 'What the token is a claim on',
      paragraphs: [
        'The DETF token is a claim on a share of the managed reserve. The basket usually holds vault shares: deposit, receive a vault share, redeem later. Those vaults can wrap a market, a lending book, or another protocol. That is how a DETF strategy reaches other venues without baking those brands into the DETF itself.',
        'The DETF token also sits in the reserve market. That liquidity is how the backing is managed, not a separate listing product. How vault legs are marked: /research/rate-providers. Building-block vaults live under Earn.',
      ],
    },
    {
      heading: 'Short FAQ',
      paragraphs: [
        'Is a DETF a registered stock ETF? No. It is an onchain product pattern: one token that is a claim on a share of onchain reserve assets, not a securities fund and not legal ownership of offchain underlyings.',
        'Does Open mean free yield or no fees? No. Open only removes price restrictions on primary mint and burn. Fees and splits can still apply; nothing invents returns. Open also never runs natural expansion.',
        'Does natural expansion pay everyone who holds DETF? No. It accrues to bond positions when Policy + rich. Free unlocked balances alone do not get an expansion airdrop.',
        'Do I need to create a DETF to use one? No. Open Protocol DETF on /staking for the protocol fees path, or hold any live DETF instance that accepts mint, burn, or bond.',
        'Mint or bond? Mint for liquid DETF you can move and use elsewhere. Bond for protocol-owned depth, reward eligibility, and the claim / fee path. Detail: /research/bond-vs-mint.',
        'Where next? Types and reserve shapes: /research/detf-types. Mark accuracy vs reprice on vault legs: /research/rate-providers. Live product: Open Protocol DETF on /staking. Building-block vaults: /earn.',
      ],
    },
  ],
}
