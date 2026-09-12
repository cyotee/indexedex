import type { ResearchArticle } from '../types'

/**
 * Rate providers: how a DETF reserve marks vault-share legs.
 * Customer choice: keep the mark current (rates on) or leave raw counts so the
 * market can catch up (rates off). Neither is yield. Voice: destacked, token
 * not share, Earn vaults are building blocks, no seigniorage / package titles.
 */
export const rateProvidersArticle: ResearchArticle = {
  slug: 'rate-providers',
  title: 'Rate providers: keep the price honest, or let traders catch up',
  summary:
    'A DETF is one token for a basket. The basket often holds vault shares. A rate provider tells the DETF what one vault share is worth right now. Turn rates on to keep mint, burn, and the shown price current. Leave them off if you want traders to fix a stale price. Neither setting is yield.',
  date: '2026-09-07',
  tags: ['rates', 'detf', 'product'],
  status: 'published',
  claims: [
    'When a DETF basket holds vault shares, you can deploy those legs with rate providers on or off.',
    'Rates on keep the reserve mark current as vault-share value moves. Mint, burn, deposits, and the displayed price read that mark.',
    'Rates off leave raw vault-share counts. If the underlying moves and nobody trades the reserve, the displayed price can lag.',
    'That lag can invite traders to reprice the reserve when the gap is large enough to cover fees and path costs. Volume is not promised.',
    'Rate providers re-mark vault shares. They do not move capital from one vault to another.',
    'Every new DETF uses the reserve mark to choose primary issuance/redemption or a reserve swap.',
  ],
  notClaiming: [
    'Neither setting prints yield, guarantees profit, or promises live reprice volume.',
    'Research numbers come from hermetic and fork scenarios, not a live DETF performance promise.',
    'Fee levels and fill behavior change with pool settings. Do not treat one research fee as a production rule.',
    'Rates on do not replace mint, burn, bond, or deposit when you want to move inventory.',
    'Rates off do not guarantee trades. A small gap can sit with no fills.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'How DETFs work',
  sourceNote:
    'research/MARKETING_AND_PERFORMANCE_FINDINGS.md §3.3; research/scenarios/uniswapV2Se/rateProviderCompare/. Product spine: docs/marketing/DETF_NARRATIVE_SPINE.md (price comes from the reserve). Companions: /research/detf, /research/detf-types, /research/bond-vs-mint.',
  sections: [
    {
      heading: 'Start with the question',
      paragraphs: [
        'IndexedEx is a strategy protocol. A DETF (Decentralized ETF) is one token over a basket that manages assets in other protocols. That token is a claim on a share of the managed reserve. The price you see comes from that reserve.',
        'Many basket legs are vault shares from Earn. Those vault shares change in value as the other protocol moves. When you create the DETF, you choose whether the reserve should keep asking what one vault share is worth right now.',
      ],
    },
    {
      heading: 'Why the mark matters',
      paragraphs: [
        'Quotes read the reserve. Price gates use its backing measure to choose primary issuance/redemption or a reserve swap. A stale mark can affect both the price and the selected route.',
      ],
      bullets: [
        '**The DETF token sits in the reserve.** Liquidity is how the backing is managed, not a side listing.',
        '**Vault shares are the working legs.** Earn vaults are building blocks. They are not the strategy product.',
        '**A rate provider answers one question.** How much is one vault share worth right now.',
        '**You pick this at create time.** Families that expose the flag let you turn it on or off per vault-share leg.',
      ],
    },
    {
      heading: 'Keep the mark current',
      paragraphs: [
        'Turn rate providers on when you want mint, burn, deposits, and the displayed price to stay aligned with what a vault share would redeem for as the other protocol moves.',
      ],
      bullets: [
        'The reserve re-marks vault shares as their claim value changes, even before anyone trades the DETF.',
        'Quotes stay closer to redeem value. You do not need a trader to update the mid.',
        'Primary price gates read the current book.',
        'When a primary price condition is not met, the supported route swaps through the reserve.',
      ],
    },
    {
      heading: 'Let the market catch up',
      paragraphs: [
        'Leave rate providers off when you want raw vault-share counts in the reserve. If the other protocol moves and the reserve is quiet, the displayed price can lag. That gap can pull in traders to reprice the book.',
      ],
      bullets: [
        'The reserve sees vault-share amounts, not live redeem value, until someone trades.',
        'A large enough gap can invite reprice volume. Fees and path costs still have to be covered.',
        'Until that trade happens, mint, burn, and the displayed price can sit away from live redeem value.',
        'A small gap can sit with no fills. This is not a yield product.',
      ],
    },
    {
      heading: 'A simple example',
      paragraphs: [
        'The reserve holds a fixed amount of vault shares. The other protocol moves so one vault share is worth 5% more. Nobody has traded the DETF yet.',
      ],
      bullets: [
        '**Rates on:** the reserve re-marks those shares. Mint, burn, and the displayed price move with the 5%.',
        '**Rates off:** the raw count is unchanged. Redeem value moved about 5%. The displayed price can lag until someone trades the reserve.',
      ],
    },
    {
      heading: 'How to choose',
      paragraphs: [],
      bullets: [
        'Want fair mint, burn, and deposits as vault-share value moves? Turn rates on.',
        'Want the displayed price to stay current without waiting for a trade? Turn rates on.',
        'Want lag that can invite traders to reprice the reserve? Leave rates off, and accept stale quotes until that trade happens.',
        'Primary issuance and redemption conditions read the same reserve mark.',
        'A failed price condition selects a reserve swap; liquidity and your minimum output still matter.',
        'This flag does not pick mint versus bond. That choice is /research/bond-vs-mint.',
      ],
    },
    {
      heading: 'What this does not do',
      paragraphs: [
        'Rate providers re-mark vault shares. They do not move capital from one vault to another, and they do not replace mint, burn, bond, or deposit.',
      ],
    },
    {
      heading: 'What we measured',
      paragraphs: [
        'Lab runs compared rates on and rates off under the same demand path. Those runs used a research fee, not a production fee. Treat them as a picture of the two intents, not a forecast.',
      ],
      bullets: [
        'With rates on, the mark stayed current as the underlying moved.',
        'With rates off, the gap grew as the underlying moved and the reserve sat quiet.',
        'Trades only showed up when the gap cleared fees and path costs. Modest lag often meant no fills.',
      ],
    },
    {
      heading: 'FAQ',
      paragraphs: [],
      bullets: [
        '**What is a rate provider?** A feed that tells the reserve what one vault share is worth right now.',
        '**Can I deploy either way?** Yes, when that DETF type exposes the flag. Both settings are intentional.',
        '**Which is better for a fair primary market?** Rates on. Mint, burn, and deposits stay closer to redeem value.',
        '**Which invites traders to reprice the reserve?** Rates off, when the gap clears costs. Volume is not promised.',
        '**Do rate providers rebalance the basket for me?** No. They re-mark vault shares. You still mint, burn, bond, or deposit to change exposure.',
        '**Does a price gate block my route?** A failed primary condition selects a reserve swap on supported routes. Quote quality still depends on the reserve mark.',
        '**Where next?** How DETFs work: /research/detf. Types: /research/detf-types. Mint or bond: /research/bond-vs-mint. Building-block vaults: /earn.',
      ],
    },
  ],
}
