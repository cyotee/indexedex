import type { ResearchArticle } from '../types'

/**
 * Bond vs mint — help a reader pick a path.
 * Code: capital bond mints matching DETF into the reserve and joins (maker LP);
 * mint/bond seigniorage inventory (`inventoryDetf`) accrues to bond holders in both modes;
 * natural expansion is Policy-only (DETFNaturalExpansionLib; Open never expands).
 * Olympus is a one-line aside, not a framing section.
 */
export const bondVsMintArticle: ResearchArticle = {
  slug: 'bond-vs-mint',
  title: 'Mint or bond: which position do you want?',
  summary:
    'Mint if you want DETF tokens you can move now. Bond if you want the efficient maker seat: matching DETF minted into the reserve for your deposit, plus a cut of DETF minted when others mint or bond. On a price-gated DETF, bonders also get a portion of regular supply expansion.',
  date: '2026-08-17',
  tags: ['detf', 'bond', 'mint', 'product'],
  status: 'published',
  claims: [
    'Mint puts DETF tokens in your wallet when the DETF is live. Fees may apply.',
    'Bond deposits one side and mints matching DETF into the reserve, so both sides of the liquidity are filled. That is the efficient way to take a maker position.',
    'Bond holders receive a portion of DETF minted when anyone mints or bonds with real capital. That split does not depend on price gating.',
    'When mint and burn are price-gated (Policy), bond holders also receive a portion of regular supply expansion. Open DETFs never expand that way.',
    'A new DETF starts off. The first successful bond turns it on.',
  ],
  notClaiming: [
    'Neither path is a promised return or a fixed APY.',
    'Matching DETF minted into the reserve is not the same as that full amount landing as spendable tokens in your wallet.',
    'A DETF is not OlympusDAO or the OHM token.',
    'Open only keeps mint and burn available at any price. It does not invent returns.',
    'Fees and lock terms come from onchain configuration. Amounts are not promises.',
  ],
  relatedProductHref: '/staking',
  relatedProductLabel: 'Open Protocol DETF',
  sourceNote:
    'Matching self-leg + join: SingleStandardExchangeDETFBondingTarget and peer families. Inventory split to bond vault on mint and bond: DETFMintSplit / _splitMintedDetf (mode-independent). Expansion: DETFNaturalExpansionLib (Policy only). Companions: /research/detf, /research/uniswap-v4-markets.',
  sections: [
    {
      heading: 'Start with what you want',
      paragraphs: [
        'A DETF (Decentralized ETF) is one token over a basket. That token is a claim on a share of the managed reserve. You can get exposure two ways: mint, or buy a bond. The better choice depends on whether you want tokens in your wallet now, or a maker seat in the reserve, and on whether this DETF pauses mint and burn when the price sits near a target.',
      ],
    },
    {
      heading: 'Why mint',
      paragraphs: [
        'Mint when you want DETF tokens you can hold, move, or sell. You put in vault shares (or the input that type accepts) and receive DETF tokens. You can burn later to go back toward those vault shares, when burn is allowed.',
      ],
      bullets: [
        'You walk away with DETF tokens in your wallet.',
        'Use this for simple exposure to the basket.',
        'The DETF must already be live. Fees may apply.',
      ],
    },
    {
      heading: 'Why bond',
      paragraphs: [
        'Bond when you want to take a maker position: you add liquidity the reserve can trade against. You deposit one side. The DETF mints a matching amount of DETF token into the reserve and pairs it with your deposit. You do not have to buy the DETF token first, and you do not offer only one side yourself. That is usually the cheaper way to put up two-sided liquidity.',
        'You receive a locked liquidity position, typically as a bond NFT. You also receive some DETF tokens at that step from the same mint split. The matching amount that fills the reserve stays in the pool.',
      ],
      bullets: [
        'Matching DETF is minted into the reserve for your deposit. Both sides of the book get filled.',
        'Cheaper than buying the DETF token and pairing it, or offering one-sided liquidity.',
        'The first successful bond also turns a new DETF on so others can mint.',
      ],
    },
    {
      heading: 'Bond holders share DETF that gets minted',
      paragraphs: [
        'Whenever someone mints or bonds with real capital, part of the minted DETF goes to the bond ledger. If you hold a bond, you receive a portion of that. This happens whether or not the DETF uses price-gated mint and burn.',
        'So a bond is not only a liquidity seat. It is also a seat on DETF that is minted as the product is used.',
      ],
    },
    {
      heading: 'When mint and burn are price-gated',
      paragraphs: [
        'Some DETFs use Policy: mint and burn can pause when the price sits near a target, and the supply can expand or contract with that price. On those DETFs, bond holders also receive a portion of regular supply expansion, as a further reason to lock liquidity. That extra expansion is the same kind of mechanic people know from Olympus. It is not OlympusDAO or OHM.',
        'Open DETFs do not pause mint or burn for price, and they do not run that regular expansion. Bonding is still the matching-liquidity path, and bond holders still share DETF minted from real deposits.',
      ],
      bullets: [
        '**Policy:** mint and burn can pause near the target. Bonders get the mint-split plus regular supply expansion when the unit is rich.',
        '**Open:** mint and burn stay available at any price. Bonders still get matching liquidity and a share of minted DETF. No regular expansion.',
      ],
    },
    {
      heading: 'How to choose',
      paragraphs: [],
      bullets: [
        'Want DETF tokens you can move now? Mint, if the DETF is live and mint is open.',
        'Want the efficient maker seat? Bond. Matching DETF is minted into the reserve for your deposit.',
        'Want a cut of DETF minted as others use the product? Bond. That split runs in both modes.',
        'Want expansion on top of that? Bond on a Policy DETF, when the price is rich.',
        'Mint paused near the target on Policy? Bond (or trade in the Uniswap V4 pools) can still be the path.',
        'On Open, mint is already open on price. Bond is a choice to make liquidity and lock it, not a workaround.',
      ],
    },
    {
      heading: 'FAQ',
      paragraphs: [],
      bullets: [
        '**Can I mint before the first bond?** No. A new DETF stays off until the first successful bond.',
        '**Do I get spendable DETF when I bond?** You get a locked liquidity position, plus some DETF from the mint split. The matching amount stays in the reserve.',
        '**Why is bonding the efficient maker path?** The DETF mints the DETF side for you. You do not buy that side first, and you do not add only one side.',
        '**Do bond holders share minted DETF if there is no price gate?** Yes. The cut of DETF minted from real deposits goes to bond holders in both modes.',
        '**When do bonders get regular supply expansion?** Only on Policy DETFs, when mint and burn are price-gated and the unit is rich. Open never expands that way.',
        '**Is this Olympus?** No. Policy expansion is a passing comparison: new supply can go to people who locked liquidity. A DETF is not OlympusDAO or OHM.',
        '**Where do I do this?** Create a DETF on /create. Protocol DETF is on /staking. Actions are Bond, Mint, Burn, and Claim.',
      ],
    },
  ],
}
