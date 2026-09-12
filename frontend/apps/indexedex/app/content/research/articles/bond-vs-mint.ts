import type { ResearchArticle } from '../types'

export const bondVsMintArticle: ResearchArticle = {
  "slug": "bond-vs-mint",
  "title": "Mint or bond: which position do you want?",
  "summary": "Buy liquid DETF if you want tokens you can move now. Bond for a discounted DETF purchase that is funded and staked immediately, with principal becoming claimable steadily over your chosen period.",
  "date": "2026-09-07",
  "tags": [
    "detf",
    "product"
  ],
  "status": "published",
  "claims": [
    "A supported purchase receives liquid DETF through primary issuance or a reserve swap once the reserve is live.",
    "Bond payment adds liquidity together with a separately minted proportional DETF amount. Purchased principal is additionally minted and staked.",
    "The duration bonus increases the purchased quote, not the actual payment sent to the reserve.",
    "Bond principal vests linearly. Principal and rewards pay sDETF, and rewards can be claimed during vesting.",
    "One sDETF can be unstaked for one DETF. Bond holders have no separate LP entitlement or bond-only reward ledger.",
    "The first successful bond takes the DETF live."
  ],
  "notClaiming": [
    "A DETF is an onchain product pattern, not a registered securities ETF or legal ownership of offchain stocks.",
    "Funded growth in sDETF token units does not guarantee a higher market value, fixed APY or peg.",
    "Reward amounts depend on actual funding. The creator role has no redeemable principal; its received sDETF can be unstaked.",
    "This note describes the approved funded design, not an automatic upgrade of existing deployments or a live Pendle market."
  ],
  "relatedProductHref": "/staking",
  "relatedProductLabel": "Open Protocol DETF",
  "sourceNote": "Approved design: contracts/vaults/detf/DETF_ALIGNMENT_PRD.md D32–D55 / §24 and DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md. Narrative: docs/marketing/DETF_NARRATIVE_SPINE.md. These describe the funded refactor; verify the selected deployment before assuming these routes are live.",
  "sections": [
    {
      "heading": "Start with what you want",
      "paragraphs": [
        "A DETF (Decentralized ETF) is one token over a basket. The approved funded design offers liquid DETF, direct staking and discounted bonds. Choose based on when you need your principal available."
      ]
    },
    {
      "heading": "Buy liquid DETF",
      "paragraphs": [
        "Use a payment accepted by the DETF to receive tokens you can hold, transfer or stake immediately. The reserve must already be live.",
        "The quote uses primary issuance when its price condition is met and a reserve swap otherwise. The reverse route similarly chooses primary redemption or a swap. Both remain subject to available liquidity, fees and your minimum output."
      ]
    },
    {
      "heading": "Stake DETF directly",
      "paragraphs": [
        "Deposit DETF to receive an equal number of sDETF units. The staking reserve holds the DETF used to honor unstaking. You can unstake each displayed sDETF for one DETF.",
        "Funded rewards may increase your sDETF balance. Direct staking does not impose a bond vesting period."
      ]
    },
    {
      "heading": "Buy a discounted bond",
      "paragraphs": [
        "Choose a supported payment and vesting period. The existing duration formula gives a bonus to the amount used to quote your DETF purchase. Your actual payment does not increase.",
        "Your payment and a separately minted proportional DETF amount add liquidity. In addition, the DETF principal you purchased is minted and staked for the bond NFT. All reserve LP acquired this way belongs to the DETF.",
        "The first successful bond also starts the reserve. Later purchases use the live reserve curve. Check the quote and duration before paying."
      ]
    },
    {
      "heading": "Claim principal and rewards",
      "paragraphs": [
        "Purchased principal vests linearly. At halfway through the selected period, half the original principal has vested, less any principal already claimed.",
        "Staking rewards can be claimed while principal remains unvested. Principal-only, reward-only and combined claims all pay sDETF. You may keep those receipts staked or unstake them for equal DETF units.",
        "For example, a bond with 100 DETF principal and 10 funded staking rewards at halfway can pay 50 sDETF of vested principal and 10 sDETF of rewards. The remaining 50 principal continues vesting.",
        "After all principal and whole-unit rewards are paid, the final claim retires the bond NFT. There is no separate mature LP sale."
      ]
    },
    {
      "heading": "Where staking rewards come from",
      "paragraphs": [
        "DETF issuance funds its reward allocation immediately. Eligible automatic expansion uses fixed eight-hour periods from the first bond. Completed idle periods settle together, without hypothetical historical compounding.",
        "A bond benefits from having its purchased DETF staked while vesting. It does not receive a second distribution based on reserve LP or old bonus shares."
      ]
    },
    {
      "heading": "What the creator receives",
      "paragraphs": [
        "The creator and fee recipient have standing distribution rights. These role NFTs have no principal to cash out. Their reward receipts are ordinary funded sDETF that can be transferred or unstaked.",
        "Even after a recipient unstakes all earlier receipts, the standing right can receive more sDETF from later allocations."
      ]
    },
    {
      "heading": "Choose a route",
      "paragraphs": [],
      "bullets": [
        "Need all your DETF available now? Buy liquid DETF through the standard exchange.",
        "Want funded staking without a bond period? Stake DETF directly.",
        "Want the duration-based purchase bonus and staking while principal vests? Buy a bond.",
        "Need a bond reward before maturity? Claim rewards as sDETF and unstake if you want DETF.",
        "Create on /create, explore live instances on /explore, and open Protocol DETF on /staking."
      ]
    }
  ]
}
