import type { ResearchArticle } from '../types'

/**
 * Flagship DETF note. IndexedEx is a strategy protocol; a DETF is one token over a
 * basket that manages assets in other protocols. Token (not share) is the default
 * name. Reserve liquidity is how the backing is managed. Earn vaults are legs.
 * Open = no price restrictions on mint/burn. Regular expansion is Policy-only.
 * Creators receive an unredeemable bond that collects a cut of DETF minted to
 * bond holders (mint/bond split + Policy expansion). Same pattern as the
 * protocol's feeTo bond. Do not say seigniorage in customer copy.
 */
export const detfArticle: ResearchArticle = {
  slug: 'detf',
  title: 'DETFs: one token over a basket',
  summary:
    'A DETF (Decentralized ETF) is one token for a basket you pick. That basket puts money to work in other apps. You own a piece of the assets behind the token. People can trade the token. Make it, bond to turn it on, then mint or burn.',
  date: '2026-08-17',
  tags: ['detf', 'product'],
  status: 'published',
  claims: [
    'A DETF token is one token over a basket that manages assets in other protocols, not a static list.',
    'That token is a claim on a share of the managed reserve.',
    'The DETF token sits in market liquidity. That is how the reserve behind the token is managed.',
    'Mint, burn, and the displayed price read the reserve itself.',
    'A new DETF starts off. The first successful bond turns it on and adds to the reserve.',
    'Policy can pause mint and burn when the price sits near target. Open never does. Fees may still apply.',
    'On Policy only, while live and the price is rich, extra DETF can accrue over time to bond holders. Open never expands that way.',
    'After deploy, DETF instances stay as configured. A flawed setup means a new instance, not a later rewrite.',
    'Create your own DETFs from several types. Protocol DETF uses the same design so you can earn a share of protocol fees (amounts not guaranteed).',
    'Creating a DETF issues an unredeemable bond to the creator. That bond collects a portion of DETF minted to bond holders, including Policy supply expansion.',
  ],
  notClaiming: [
    'A DETF is not a registered securities ETF or fund share, and holding it is not legal ownership of offchain stocks or underlyings.',
    'No promised APY, rebase return, or peg guarantee.',
    'Open removes price gates only. It does not erase fees, invent returns, or enable regular supply expansion.',
    'Regular supply expansion is not a yield product for unlocked DETF holders and is not available in Open mode.',
    'Policy thresholds are not a guarantee of peg stability or yield.',
    'Fee amounts, including Protocol DETF, are not guarantees.',
    'The creator bond cannot be redeemed for principal. Accrued DETF amounts are not guaranteed.',
  ],
  relatedProductHref: '/staking',
  relatedProductLabel: 'Open Protocol DETF',
  sourceNote:
    'Product rules: contracts/vaults/detf/** PRDs (Threshold Modes; Protocol Compound + Supply Expansion) and monorepo AGENTS.md DETF section. Handoff: DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md. Narrative spine: docs/marketing/DETF_NARRATIVE_SPINE.md. Companion notes: /research/detf-types, /research/bond-vs-mint, /research/rate-providers. Hermetic research: research/scenarios/detf/singleSe/FINDINGS.md.',
  sections: [
    {
      heading: 'What a DETF is',
      paragraphs: [
        'IndexedEx lets you run a money plan as one token. A DETF (Decentralized ETF) is that token. The D means decentralized. This is not a stock ETF.',
        'The basket puts money to work in other apps. You hold that one token instead of running each app yourself.',
      ],
    },
    {
      heading: 'Why that matters',
      paragraphs: [
        'You get ETF-shaped exposure without handing the book to a fund administrator. The token is a claim on a share of the managed reserve.',
      ],
      bullets: [
        '**A basket that works in other protocols:** The assets sit in other protocols as a working strategy, not a static token list.',
        '**One token over that basket:** Hold, move, or exit a single token instead of managing each protocol position yourself.',
        '**The token is in the market:** The DETF token lives in market liquidity. That is how the reserve is managed, not a side listing.',
        '**You pick the rules:** Policy can pause mint and burn near a target price. Open never does. Fees can still apply.',
        '**The design stays put:** After it goes live, nobody rewrites the rules. A bad setup means a new DETF.',
      ],
    },
    {
      heading: 'How you use it',
      paragraphs: [
        'Typical path: create the DETF, bond to turn it on, then mint, hold, or burn. Earn vaults are building blocks a DETF can put in its basket. They are not the strategy product.',
      ],
      bullets: [
        '**Create:** Deploy a DETF as your strategy. Pick the type and the mix. You receive an unredeemable bond that collects a cut of minted DETF. The DETF stays off until someone bonds.',
        '**Bond:** Bond is the first real deposit. It turns the strategy on and funds the reserve. Later bonds add more.',
        '**Use:** Hold the token, mint more, or burn to exit. The token stays in market liquidity so the reserve can be managed.',
      ],
    },
    {
      heading: 'What the token is a claim on',
      paragraphs: [
        'The DETF token is a claim on a share of the managed reserve. The basket usually holds vault shares: you deposit, receive a vault share, and redeem later. Those vaults can wrap a market, a lending book, or another protocol. That is how a DETF strategy reaches other venues.',
        'The DETF token also sits in the reserve market. That liquidity is how the backing is managed, not a separate listing. Building-block vaults live under Earn. How vault legs are marked: /research/rate-providers.',
      ],
    },
    {
      heading: 'You pick the rules',
      paragraphs: [
        'When you create a DETF you choose whether mint and burn care about price. The reserve still shows a price either way. Only Policy uses that price to pause mint or burn.',
      ],
      bullets: [
        '**Policy:** Mint when the price is clearly above target. Burn when it is clearly below. Near the target, mint and burn pause. You can still trade in the Uniswap V4 pools.',
        '**Open:** Mint and burn stay available at any price. Fees can still apply. You choose this mode at create time. A zero setting is not Open.',
      ],
    },
    {
      heading: 'Mint or bond',
      paragraphs: [
        'Mint if you want DETF tokens you can move now. Bond if you want the maker seat: you deposit one side, and matching DETF is minted into the reserve so both sides of the book get filled.',
        'Whenever someone mints or bonds with real capital, part of the minted DETF goes to bond holders. That split runs in both modes. The creator bond and the protocol bond sit in that same seat. On Policy only, those bonds also get a portion of regular supply expansion when the unit is rich. Open never expands that way.',
        'Full pick: /research/bond-vs-mint.',
      ],
    },
    {
      heading: 'Create your own or open Protocol DETF',
      paragraphs: [
        'Deploy your own strategy as a DETF. Types change what the basket holds in other protocols. Bond, mint, and burn stay the same steps. Type shapes: /research/detf-types.',
        'Protocol DETF uses the same design so you can take part in protocol fees. Home: /staking. Fees may apply. Amounts are not guarantees.',
      ],
    },
    {
      heading: 'If you create a DETF',
      paragraphs: [
        'Creating a DETF issues you an unredeemable bond. Same idea as the protocol bond: you cannot cash the bond out, but it collects a portion of the DETF minted to bond holders.',
        'That includes DETF minted when people mint or bond, and on Policy, a portion of regular supply expansion. You collect those DETF tokens. You do not redeem the bond itself. Amounts are not guaranteed.',
      ],
    },
    {
      heading: 'FAQ',
      paragraphs: [],
      bullets: [
        '**Is a DETF a registered stock ETF?** No. It is an onchain product: one token that is a claim on a share of onchain reserve assets, not a securities fund and not legal ownership of offchain underlyings.',
        '**What is the DETF token?** The token you hold. It is a claim on a share of the managed reserve. We say token, not share, unless we mean that claim, a share of protocol fees, or vault shares in the basket.',
        '**Does Open mean free yield or no fees?** No. Open only removes price restrictions on mint and burn. Fees can still apply. Open also never runs regular supply expansion.',
        '**Does expansion pay everyone who holds DETF?** No. Extra supply on Policy goes to bond positions when the unit is rich. Unlocked balances alone do not get an airdrop.',
        '**Do I need to create a DETF to use one?** No. Open Protocol DETF on /staking for the protocol fees path, or hold any live DETF that accepts mint, burn, or bond.',
        '**What does the creator get?** An unredeemable bond. It collects a cut of DETF minted to bond holders, including Policy expansion. You cannot redeem the bond itself.',
        '**Mint or bond?** Mint for DETF tokens you can move. Bond for the maker seat, matching liquidity, and a cut of minted DETF. Detail: /research/bond-vs-mint.',
        '**Where next?** Types: /research/detf-types. Uniswap V4 pools: /research/uniswap-v4-markets. Mark accuracy on vault legs: /research/rate-providers. Building-block vaults: /earn.',
      ],
    },
  ],
}
