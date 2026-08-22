import type { ResearchArticle } from '../types'

/**
 * DETF types as basket shapes. Package names stay in sourceNote only.
 * Four live families: one vault, weighted multi-vault, layered like-kind,
 * one cash buffer plus vaults. Same DETF verbs on every type.
 */
export const detfTypesArticle: ResearchArticle = {
  slug: 'detf-types',
  title: 'DETF types: pick the basket shape',
  summary:
    'A DETF is one token for a basket. The type is the shape of that basket. Bond, mint, and burn stay the same. Pick the type that matches the vaults you want.',
  date: '2026-08-17',
  tags: ['detf', 'types', 'product'],
  status: 'published',
  claims: [
    'There are four DETF types. They change how the basket is laid out, not whether the product is a DETF.',
    'Every type is one DETF token over a managed reserve. That token is a claim on a share of the reserve and sits in market liquidity.',
    'Basket legs are vault shares from Earn. Those vaults wrap other protocols. The DETF does not hardcode a venue.',
    'One-vault type: the DETF token plus exactly one vault share.',
    'Fixed-weight type: the DETF token plus several vault shares, each with a set weight.',
    'Grouped type: several similar vaults sit in two grouped pools next to the DETF token, marked two ways.',
    'Cash-buffer type: the DETF token, one cash token, and vaults that all take and give that cash. Burn returns that cash.',
    'The first successful bond turns a new DETF on. Creating a DETF also issues an unredeemable creator bond.',
  ],
  notClaiming: [
    'No type is a registered securities ETF or fund share.',
    'Type choice does not guarantee a peg, yield, or market depth.',
    'What you can create on a given network depends on what is deployed. This note is the design map, not a live catalog.',
    'Deploy package names in code are not customer titles.',
    'The creator bond cannot be redeemed for principal. Accrued DETF amounts are not guaranteed.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'How DETFs work',
  sourceNote:
    'Four live families under contracts/vaults/detf/: standardExchange/single (SingleStandardExchangeDETF); composed/multi-vault-weighted (MultiVaultWeightedDetf); composed/stable/common (ComposedStableCommonDetf); composed/stable/mixedBuffer (MixedBufferMultiVaultStableDetf). Removed path composed/single is not a product type. Spine: docs/marketing/DETF_NARRATIVE_SPINE.md §2.',
  sections: [
    {
      heading: 'Start with the basket',
      paragraphs: [
        'IndexedEx is a strategy protocol. A DETF (Decentralized ETF) is how you deploy your own strategy as one token. The type is not a second product. It is the shape of the basket that token sits over.',
        'Start from what you want in the basket. Do not start from a package name.',
      ],
    },
    {
      heading: 'What stays the same',
      paragraphs: [
        'Every type is the same DETF pattern. The token is a claim on a share of the managed reserve. It also sits in market liquidity, which is how that reserve is managed.',
      ],
      bullets: [
        'Create the DETF, then bond to turn it on. Later you mint, hold, or burn.',
        'Policy can pause mint and burn near a target price. Open never does. Fees can still apply.',
        'Creating a DETF issues an unredeemable bond that collects a cut of DETF minted to bond holders, including Policy expansion.',
        'A bad setup means a new DETF. The design does not get rewritten after it goes live.',
      ],
    },
    {
      heading: 'What sits in the basket',
      paragraphs: [
        'Basket legs are usually vault shares. You deposit into a vault, receive a vault share, and redeem later. Those vaults wrap a market, a lending book, or another protocol. That is how a DETF reaches other venues.',
        'Earn vaults are building blocks. They are not the strategy product. Venue names you see in diagrams are examples, not a closed list. How vault shares are marked: /research/rate-providers.',
      ],
    },
    {
      heading: 'One vault',
      paragraphs: [
        'The reserve holds the DETF token and exactly one vault share. Use this when one working position in another protocol is the whole strategy.',
      ],
      bullets: [
        'Mint and burn move between that vault share and the DETF token.',
        'A common starting mix is more DETF than vault share. You can set the mix when you create it.',
        'The first successful bond turns it on.',
        'Skip this type if you need several vaults or one shared cash token.',
      ],
      diagram: 'single-standard-exchange',
    },
    {
      heading: 'Several vaults, fixed weights',
      paragraphs: [
        'The reserve holds the DETF token plus several vault shares. Each vault keeps its own weight and its own value. Use this when the vaults are different products and should stay separate legs.',
      ],
      bullets: [
        'You pick the weights at create time. They stay put.',
        'Mint and burn use the vault shares you configured. Deposit into a vault first if you hold the underlying.',
        'After the reserve is set up, the first bond turns it on.',
        'Skip this type if the vaults are alike and should share one cash token, or if they should be grouped rather than listed by weight.',
      ],
      diagram: 'multi-vault-weighted',
    },
    {
      heading: 'Several similar vaults, grouped',
      paragraphs: [
        'Several like-kind vaults sit in two grouped pools. One group marks each vault on its own. The other marks them against one shared target. Those two groups sit next to the DETF token. You still hold one DETF token.',
      ],
      bullets: [
        'Use this when similar vaults should compose as one structure, not as a flat weighted list.',
        'The DETF token lives only next to the two groups, not inside each vault group.',
        'How those marks work is the rate-provider choice: /research/rate-providers.',
        'This is not the one-cash-token design below.',
      ],
      diagram: 'multi-vault-stable',
    },
    {
      heading: 'One cash token plus vaults',
      paragraphs: [
        'The reserve holds the DETF token, exactly one cash token, and vaults that all take and give that cash. Use this when the strategy is a cash family: several vaults processing the same asset.',
      ],
      bullets: [
        'Mint with the cash token or with a vault share.',
        'Burn returns the cash token only.',
        'The first bond can turn it on. You put in cash or a vault share. Matching DETF is minted into the reserve.',
        'Skip this type if the vaults are different assets that need their own weights, or if you want the grouped design above.',
      ],
      diagram: 'mixed-buffer-multi-vault-stable',
    },
    {
      heading: 'How to choose',
      paragraphs: [],
      bullets: [
        'One working position in another protocol? One vault.',
        'Several different vaults that should keep their own weights? Several vaults, fixed weights.',
        'Several similar vaults that should compose as one structure? Several similar vaults, grouped.',
        'Several vaults on one cash token, and you want to burn back to that cash? One cash token plus vaults.',
        'Unsure how vault shares should be marked? Read /research/rate-providers after you pick the shape.',
        'Need the mint versus bond pick? That is the same on every type: /research/bond-vs-mint.',
      ],
    },
    {
      heading: 'FAQ',
      paragraphs: [],
      bullets: [
        '**Is a type a different product?** No. Every type is a DETF: one token over a basket. The type only changes the basket shape.',
        '**Do I pick a package name?** No. Pick the basket. Package names stay in engineer docs.',
        '**What is a vault share?** A claim on a vault that wraps another protocol. Deposit, receive a vault share, redeem later. Earn lists those vaults.',
        '**Does the type change mint or bond?** No. Those steps stay the same. Inputs can change with the basket.',
        '**Does the creator still get a bond?** Yes. Creating any DETF issues an unredeemable bond that collects a cut of minted DETF, including Policy expansion.',
        '**Is Protocol DETF a fifth type?** No. It uses the same design so you can take part in protocol fees. Home: /staking.',
        '**Where next?** How DETFs work: /research/detf. Mint or bond: /research/bond-vs-mint. Marking vault shares: /research/rate-providers. Create: /create.',
      ],
    },
  ],
}
