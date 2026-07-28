# Product Marketing Context

**Document version:** v2  
**Last updated:** 2026-07-27  

> Shared context for global `product-marketing` / `copywriting` skills.  
> **Domain law:** always also load `indexedex-product-voice` and `docs/marketing/DETF_NARRATIVE_SPINE.md`.

## Product Overview

**One-liner:** IndexedEx is modular DeFi vault infrastructure whose **premier product is creating your own DETFs** (Decentralized ETFs) from many package types. **Protocol DETF** is how you earn a share of protocol fees — not the whole product story.

**What it does:** Deployable DETF packages create immutable share tokens over multi-asset Balancer V3 reserves, with bonding into protocol-owned depth and primary-market mint/burn (Policy or Open). Families cover single SE, multi-vault weighted, mixed-buffer stable, composed shapes, and more.

**Product category:** Onchain reserve-backed share / decentralized ETF **product pattern** (not a registered securities ETF).

**Product type:** DeFi protocol + web app (list-driven, multi-chain).

**Business model:** Protocol usage / seigniorage fees via fee oracle (amounts not guaranteed); infrastructure so others can deploy many DETF instances.

## Target Audience

**Primary:** Builders and operators who want to launch reserve-backed DETF shares; DeFi users who want basket-style exposure without discretionary rebalancers; holders who want a protocol fee-share path (Protocol DETF).

**Jobs to be done:**
- Deploy / compose a DETF from a family package (premier)
- Hold one share over a configured reserve
- Bond to establish protocol-owned depth and go live
- Mint/burn against vault shares under explicit Policy or Open rules
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
- Deploy-time **Policy** (price-gated mint/burn) or **Open** (no price restrictions)  
- Instances immutable / unowned after deploy  
- Protocol DETF = protocol fees path, not “the only DETF” or a “separate product”  

## Customer Language

**Words to use:** DETF (Decentralized ETF — D is decentralized), Protocol DETF (share of protocol fees), bond, mint, burn, reserve, live, Policy, Open, share token, strategy vaults, Earn, DETF types / families.

**Words to avoid:** Protocol DETF as “premier product” or “separate product”; Fee-accrual DETF (as brand); Single Vault DETF (as UI title); hero; workspace (as product name); seigniorage surface; streamline; unlock; seamless; fake APY; registered ETF; staking-style / staking analogue (internal only).

**Glossary:**

| Term | Meaning |
|------|---------|
| DETF | Decentralized ETF product pattern — the D is decentralized; any family instance you deploy or hold |
| Protocol DETF | Path to earn a share of protocol fees on `/staking` (same DETF design) |
| Policy | Mint/burn restricted by synthetic price deadband |
| Open | No price restrictions on primary mint/burn |
| rateAsset / pairToken | Role names (contracts); not for casual UI unless explaining roles |

## Brand Voice

**Tone:** Serious, specific, lab-honest — not agency hype.  
**Style:** Plain verbs; short sentences; disclaimers when needed.  
**Personality:** Precise, unowned-by-design, research-backed when claims are measured.

## Goals

**Conversion actions (priority order):**  
1. Understand / explore **DETF types** and how to compose one (`/research/detf`, Earn legs).  
2. Optionally open **Protocol DETF** for fee-share (`/staking?detf=…`).  

**Do not:** invent TVL/APY; re-list Protocol DETF in Earn grid; call Protocol DETF the premier product.

## Proof Points

- Hermetic research on SE rates / preview-execution (see `research/MARKETING_AND_PERFORMANCE_FINDINGS.md`) — **not** full DETF seigniorage performance until that campaign ships  
- Product law: `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md`  
- Families under `contracts/vaults/detf/**`  

## Changelog

- v2 (2026-07-27) — Premier product = create-your-own DETFs; Protocol DETF = fee-share staking analogue.  
- v1 (2026-07-27) — Initial context: Protocol DETF naming, Policy/Open truth, banned marketing chrome.
