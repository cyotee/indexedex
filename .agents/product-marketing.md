# Product Marketing Context

**Document version:** v4  
**Last updated:** 2026-09-07  

> Shared context for global `product-marketing` / `copywriting` skills.  
> **Domain law:** always also load `indexedex-product-voice` and `docs/marketing/DETF_NARRATIVE_SPINE.md`.

## Product Overview

**One-liner:** IndexedEx is modular DeFi vault infrastructure whose **premier product is creating your own DETFs** (Decentralized ETFs) from many package types. **Protocol DETF** is how you earn a share of protocol fees — not the whole product story.

**What it does:** The approved refactor creates immutable nine-decimal DETF tokens over Balancer or Uniswap V4 reserves. Mandatory price gates choose primary issuance/redemption or a reserve swap. Bonds buy discounted DETF that is funded and staked while vesting linearly; claimable principal and rewards pay sDETF. Each sDETF unstakes for one held DETF. This describes the target design, not an automatic change to existing deployments. Families cover single SE, multi-vault weighted, mixed-buffer stable, composed shapes, and more.

**Product category:** Onchain reserve-backed share / decentralized ETF **product pattern** (not a registered securities ETF).

**Product type:** DeFi protocol + web app (list-driven, multi-chain).

**Business model:** Protocol usage / seigniorage fees via fee oracle (amounts not guaranteed); infrastructure so others can deploy many DETF instances.

## Target Audience

**Primary:** Builders and operators who want to launch reserve-backed DETF shares; DeFi users who want basket-style exposure without discretionary rebalancers; holders who want a protocol fee-share path (Protocol DETF).

**Jobs to be done:**
- Deploy / compose a DETF from a family package (premier)
- Hold one share over a configured reserve
- Bond to establish protocol-owned depth and go live
- Use supported purchase/redemption routes with primary issuance or a reserve swap
- Stake DETF one-for-one and claim funded bond principal/rewards as sDETF
- Use **Protocol DETF** to earn a share of protocol fees
- Use strategy vaults on Earn for composed liquidity (legs under DETFs)

## Problems & Pain Points

- Black-box “manager rebalance” stories without pool-priced rules  
- Spreadsheet indices with no onchain reserve  
- One-size “staking token” when the real product is custom DETF design  
- Product UIs that use deploy package names and marketing jargon  
- Fake APY / peg promises  

## Differentiation

- **Many DETF types**, one platform (not a single branded fund)  
- Diamond **is** the share ERC-20  
- Pricing engine = reserve pool (not off-pool ledger)  
- Mandatory primary price gates with reserve-swap fallback
- Funded DETF staking and continuously vesting bond principal  
- Instances immutable / unowned after deploy  
- Protocol DETF = protocol fees path, not “the only DETF” or a “separate product”  

## Customer Language

**Words to use:** DETF (Decentralized ETF — D is decentralized), Protocol DETF (share of protocol fees), bond, mint, burn, reserve, live, stake, unstake, sDETF, share token, strategy vaults, Earn, DETF types / families.

**Words to avoid:** Protocol DETF as “premier product” or “separate product”; Fee-accrual DETF (as brand); Single Vault DETF (as UI title); hero; workspace (as product name); seigniorage surface; streamline; unlock; seamless; fake APY; registered ETF; staking-style / staking analogue (internal only).

**Glossary:**

| Term | Meaning |
|------|---------|
| DETF | Decentralized ETF product pattern — the D is decentralized; any family instance you deploy or hold |
| Protocol DETF | Path to earn a share of protocol fees on `/staking` (same DETF design) |
| Price gates | Choose primary issuance/redemption or a reserve swap for supported routes |
| sDETF | A funded staking receipt, unstakable for one held DETF per token |
| Bond | Discounted DETF purchase, funded and staked immediately, with linearly vesting principal and separately claimable staking rewards |
| rateAsset / pairToken | Role names (contracts); not for casual UI unless explaining roles |

## Brand Voice

**Tone:** Serious, specific, lab-honest — not agency hype.  
**Style:** Plain verbs; short sentences; disclaimers when needed.  
**Personality:** Precise, unowned-by-design, research-backed when claims are measured.

## Goals

**Conversion actions (priority order):**  
1. **Create** a DETF (`/create`) or **use a live DETF** (`/explore`).  
2. **Learn** how DETFs work (`/learn`).  
3. Optionally **buy $RICH** / open **Protocol DETF** for the fee path (`/staking?detf=…`).  

**Do not:** invent TVL/APY; re-list Protocol DETF in Earn grid; call Protocol DETF the premier product.

## Proof Points

- Hermetic research on SE rates / preview-execution (see `research/MARKETING_AND_PERFORMANCE_FINDINGS.md`) — **not** full DETF seigniorage performance until that campaign ships  
- Product law: `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D32–D55 / §24  
- Families under `contracts/vaults/detf/**`  

## Changelog

- v4 (2026-09-07) — Approved funded staking target; mandatory gate-to-swap routes, linear bonds and one-for-one sDETF. Earlier entries describe superseded product versions.

- v3 (2026-08-21) — Landing conversion: Create / Explore / Learn first; $RICH and Protocol DETF are the fees path, not the first-screen CTA.  
- v2 (2026-07-27) — Premier product = create-your-own DETFs; Protocol DETF = fee-share staking analogue.  
- v1 (2026-07-27) — Initial context: Protocol DETF naming, Policy/Open truth, banned marketing chrome.
