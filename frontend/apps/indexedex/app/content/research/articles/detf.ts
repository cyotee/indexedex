import type { ResearchArticle } from '../types'

export const detfArticle: ResearchArticle = {
  "slug": "detf",
  "title": "DETFs: one token over a basket",
  "summary": "A DETF (Decentralized ETF) is one token for a basket you pick. Buy liquid DETF, stake it for sDETF, or buy a discounted bond that stays staked while its principal vests.",
  "date": "2026-09-07",
  "tags": [
    "detf",
    "product"
  ],
  "status": "published",
  "claims": [
    "The DETF token represents exposure to its configured onchain reserve, including vault positions in other protocols.",
    "The first successful bond establishes the reserve and starts the fixed eight-hour expansion clock.",
    "Every new DETF uses price gates that choose primary issuance/redemption or a reserve swap on supported routes.",
    "DETF and sDETF use nine decimals. One sDETF unstakes for one DETF held in the staking reserve.",
    "Bonds fund and stake purchased DETF immediately. Principal vests linearly and staking rewards can be claimed while vesting; both pay sDETF.",
    "Issuance rewards are funded immediately. Only automatic expansion uses epochs; completed idle periods settle together.",
    "Creator and fee rights continue receiving funded sDETF after earlier receipts are fully unstaked.",
    "The approved design uses separate static SY wrappers for raw and staked DETF; wrapping raw DETF does not stake it."
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
      "heading": "What a DETF is",
      "paragraphs": [
        "IndexedEx lets you run a strategy as one token. A DETF (Decentralized ETF) holds exposure to a basket of onchain assets. The D means decentralized.",
        "The basket can use vaults in other apps. You hold one token instead of managing each position yourself. This note explains the approved funded design; listed deployments may use an earlier version."
      ]
    },
    {
      "heading": "How you use it",
      "paragraphs": [],
      "bullets": [
        "**Create:** Pick a basket and its fixed rules. The DETF stays inactive until its first bond.",
        "**Buy:** Use a supported payment to receive liquid DETF. The quote selects primary issuance or a reserve swap.",
        "**Stake:** Deposit DETF and receive the same number of sDETF. Keep it staked for funded rewards or unstake for equal DETF units.",
        "**Bond:** Buy discounted DETF that is funded and staked immediately. Claim principal as it vests and staking rewards as they become available.",
        "**Exit:** Unstake sDETF to DETF, then use a supported DETF exchange route if you want a reserve asset."
      ]
    },
    {
      "heading": "What backs each token",
      "paragraphs": [
        "Raw DETF is priced against its reserve pool, which includes DETF and the configured external assets. LP acquired by DETF operations belongs to the DETF as a whole.",
        "sDETF has a separate backing reserve holding actual DETF. Each displayed sDETF unit can be unstaked for one held DETF unit. Pool-price movements do not reduce those staking units; they can still change the market value of DETF.",
        "Bond owners hold a right to funded, vesting staked DETF. They do not own an earmarked slice of reserve LP."
      ]
    },
    {
      "heading": "Price gates choose the route",
      "paragraphs": [
        "Every new DETF has a mint threshold and a burn threshold. Above the mint threshold, a supported purchase can issue new DETF. Below the burn threshold, a supported redemption can burn DETF against the reserve.",
        "When the relevant condition is not met, including equality, the same supported route swaps through the pool. A price gate alone does not block the route. Liquidity, fees and your minimum output still apply.",
        "The first bond, direct staking and unstaking, and claims from a bond do not require those price conditions. There is no Open deployment option."
      ]
    },
    {
      "heading": "Bond principal and staking rewards",
      "paragraphs": [
        "A bond purchase does two things: your actual payment and a separate matching DETF amount add liquidity, while the DETF you purchased is additionally minted and staked for your position.",
        "Purchased principal becomes claimable steadily over the selected period. Staking rewards can be claimed during vesting. Both arrive as sDETF, which you may keep staked or unstake. See /research/bond-vs-mint."
      ]
    },
    {
      "heading": "When rewards arrive",
      "paragraphs": [
        "Rewards from DETF issuance are funded immediately. Automatic expansion follows eight-hour boundaries starting with the first bond. After an idle period, the next interaction settles all completed periods in one update when expansion is eligible.",
        "Only actual minted and funded DETF contributes to staking rewards. A balance can stay flat when there are no funded rewards. Holding liquid DETF alone does not receive staking rewards."
      ]
    },
    {
      "heading": "Creator rights and Protocol DETF",
      "paragraphs": [
        "Creating a DETF assigns a standing creator right. The right itself has no redeemable principal. It receives new sDETF from reward allocations, and those receipts can be transferred or unstaked for DETF.",
        "Redeeming every receipt does not cancel the standing right to later rewards. The fee recipient follows the same pattern.",
        "Creating your own DETF is the main product. Protocol DETF uses the same design for participation in protocol fees. Open it on /staking; explore other live DETFs on /explore."
      ]
    },
    {
      "heading": "Using a yield wrapper",
      "paragraphs": [
        "The raw DETF wrapper holds DETF without staking it. The staking wrapper holds sDETF while its own token balance stays fixed as funded staking rewards change its redemption value.",
        "These separate wrappers target the Pendle Standardized Yield interface. A compatible interface does not by itself mean a Pendle market has been launched."
      ]
    }
  ]
}
