# DETF Litepaper: Reserve-Backed Onchain Shares, Nested Mark Integrity, and Bond-Ledger Rewards

| Field | Value |
|-------|--------|
| **Status** | Phase 4 draft (2026-07-30) |
| **Genre** | Design + mechanism paper with measured appendix — **not** mainnet APY marketing |
| **Gold empirics** | Single Standard Exchange DETF + Uni V2 SE (hermetic) |
| **Definitions** | [`FORMAL_DEFINITIONS.md`](./FORMAL_DEFINITIONS.md) |
| **Figures** | [`FIGURE_MANIFEST.md`](./FIGURE_MANIFEST.md) |
| **DETF findings** | [`../../scenarios/detf/singleSe/FINDINGS.md`](../../scenarios/detf/singleSe/FINDINGS.md) |
| **SE findings** | [`../../scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../../scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md) |
| **Product narrative** | [`../../../docs/marketing/DETF_NARRATIVE_SPINE.md`](../../../docs/marketing/DETF_NARRATIVE_SPINE.md) |

**Evidence tags used below:** `[design]` · `[code]` · `[measured-DETF]` · `[measured-SE]` · `[product-law]`

---

## 0. Abstract

A **DETF (Decentralized ETF)** is an onchain product pattern: one ERC-20 share over a real multi-asset reserve, with mint, burn, and synthetic valuation derived from that same reserve—not from an admin spreadsheet. Instances deploy **inert**, go **live** on first successful bond, and choose deploy-time **Policy** (synthetic price-gates primary mint/burn) or **Open** (no price gates when live). Nested Standard Exchange legs can keep marks fair under underlying demand when rate providers are on; residual lag under rates-off is real but not free arb once fees bind.

We formalize synthetic price, Policy/Open gates, **natural supply expansion** (Policy + mint-rich only, bond ledger only), and **protocol compound** (protocol bond rewards → protocol-owned reserve BPT). Hermetic Single SE DETF scenarios (D0–D9) and prior Uni V2 SE rate-provider matrices supply measured support. We do **not** claim mainnet APY, peg guarantees, registered-fund status, or expansion yields for free unlocked holders.

---

## 1. Introduction

ETF-shaped demand wants one transferable share over a basket. Onchain attempts often fail in predictable ways: discretionary managers, off-pool “NAV” that disagrees with the market, opaque rebalancers, or nested vault legs that freeze mids while underlyings move.

A DETF answers with **reserve-pool pricing** as the single engine for primary mint/burn and synthetic valuation, **immutable unowned instances** after deploy, and an explicit **inert → live** lifecycle. Nested SE vaults plus Balancer rate providers address mark integrity on vault-share legs. Bonding builds protocol-owned depth; capital seigniorage and (on Policy units) natural expansion share a bond reward ledger; protocol compound sinks protocol rewards into reserve BPT.

This litepaper defines the pattern, states merits as **properties**, and reports what hermetic research has measured. It is not a prospectus and not a yield forecast.

---

## 2. Background: nested Standard Exchange and rate providers

Standard Exchange (SE) vaults wrap protocol liquidity (e.g. Uni V2 LP) behind deposit/redeem share interfaces. When a Balancer pool holds SE shares as legs, two deploy intents matter:

| Intent | Effect under Uni demand |
|--------|-------------------------|
| **Rates on (R+)** | Pool mids re-mark with SE redeem rates → residual ≈ 0 |
| **Rates off (R−)** | Mids can freeze while rates track Uni → residual grows |

**Residual** (research metric):

```text
residual ≈ mid_index × rate_index − 1
```

Residual measures mark lag; it is **not** profit. A closer must clear Balancer swap fee + SE usage fee + impact + dust. In the SE research package, Balancer const-prod fee is **5%**—a hard economic filter.

**[measured-SE]** Under baseline Uni-only demand, R+ residual ≈ 0 and R− residual ~±0.24%; at extreme volume (mul=25, 48 steps) R− residual ~10–12% and Mode C fills appear once residual exceeds fee scale. See F5–F6 and rateProviderCompare agent report.

We cite industry LVR / adverse-selection literature for *why* fees and inventory matter; we do not re-derive LVR theory here.

---

## 3. DETF model

### 3.1 Roles and reserve

The DETF diamond **is** the share ERC-20 (`detfToken`). A typical Single SE composition:

- One **SE vault** and its **vaultShare**
- A Balancer V3 **weighted reserve** including the DETF self-leg and external legs
- **Bond NFT vault** for locked principal and reward accounting
- Optional **rebasing claim** on protocol-owned reserve BPT

**[design][product-law]** Production DETF code talks to `IStandardExchange*`, share ERC-20s, and Balancer—not venue brands baked into the product definition.

### 3.2 Synthetic price

```text
p_syn = (rate-scaled claim of owned reserve BPT on pool balances)
        / (DETF totalSupply)
```

(with bond-vault BPT included when peer families do). Abstract Policy peg narrative: **1e18**. **All mint/burn threshold gates use synthetic**, never spot alone. Full definition: [`FORMAL_DEFINITIONS.md`](./FORMAL_DEFINITIONS.md) §3.

### 3.3 Lifecycle: inert → live

| State | User primary mint | Protocol depth |
|-------|-------------------|----------------|
| **Inert** | Blocked | None / not live |
| **Live** (after first successful bond) | Subject to Policy/Open | Bond principal in protocol accounting |

First bond is **synthetically ungated**. **[measured-DETF]** D0: inert, mint reverts, warp does not enable mint. D1: first bond → live, residual free SE shares on diamond 0 (RQ1–RQ2, F1).

### 3.4 Policy vs Open

| | Policy (default) | Open |
|--|------------------|------|
| Mint when live | `p_syn > mintThreshold` | Always (route rules still apply) |
| Burn when live | `p_syn < burnThreshold` | Always |
| Defaults | mint 1.05e18 / burn 0.95e18 if args zero | Same stored defaults; gates ignore |
| Natural expansion | When mint-rich + time | **Never** |
| Zero args imply Open? | **No** | Mode must be explicit |

**[measured-DETF]** D2–D5: post-bond hermetic synth often burn-side; Policy mint blocked until rich path; Open mint/burn when live without synth gates (RQ3–RQ4, RQ7).

### 3.5 Immutability

**[product-law]** True DETF instances are **immutable and unowned** after deploy for normal operation: no instance owner, no diamondCut, no admin pause as product model. Flawed config → abandon and redeploy.

### 3.6 Routes and preview honesty

Preferred routes: configured **vault shares ↔ DETF** (closed form). RateAsset-as-mint-input is family-scoped only. `vaultShare_i` ↔ `vaultShare_j` on the DETF is out of scope (use Balancer / SE router on the reserve).

**[measured-DETF]** D3 capital mint: preview == execution **exact** (RQ6, F4).

---

## 3b. Rewards: capital seigniorage, natural expansion, protocol compound

These three paths must stay labeled separately.

### Capital seigniorage

External capital (SE shares) → mint DETF when gates allow → usage fee + inventory split to the **bond reward ledger** as family defines. This is **not** expansion.

### Natural supply expansion

**[product-law][code]** When **Policy ∧ live ∧ `p_syn > mintThreshold`**, free DETF may mint over time into the bond reward vault (premium-closure formula; deploy-time rate/caps). Distributed by **bond effective shares**. Free unlocked DETF holders get **none**. **Open never expands.** Inert / non-rich: no expansion.

**[measured-DETF]** D5: Open supply/pending unchanged over long warp. D8: Policy supply rises after rich + 12h warp + touch; Open twin does not (RQ8–RQ9, F8). D7: bob free DETF unchanged across warp while alice has bond reward path (F7).

### Protocol compound

**[product-law]** Protocol-owned NFT free DETF rewards **auto-sink** into more **protocol-owned reserve BPT** via single-sided DETF join (best-effort; public `compoundProtocolRewards`). Users still **claim free DETF** on their bonds. Claim redemption **can** improve when protocol BPT rises—not a coupon.

**[measured-DETF]** D9: protocol BPT principal 192.27e18 → 217.82e18 after compound (RQ10, F9).

---

## 4. Merits (properties, not performance promises)

| Property | Evidence |
|----------|----------|
| ETF-shaped basket exposure without a discretionary PM | [design] C1, C10 |
| Mint, burn, synthetic share one pricing engine | [design][measured-DETF] C2, C4 · F2–F3 |
| Clear inert/live; bonding builds protocol-owned depth | [measured-DETF] C3 · F1 |
| Explicit monetary policy (Policy vs Open) at deploy | [product-law][measured-DETF] C4 · F2, F8 |
| No admin rewrite of a live instance as product model | [product-law] C5 |
| Nested SE legs with rates on keep residual ≈ 0 under Uni demand | [measured-SE] C7 · F5 |
| Lag can invite reprice only after fee stack clears | [measured-SE] C8 · F6 |
| Liquid mint vs seigniorage/bond books | [measured-DETF] C9 · F7 |
| Natural expansion when rich (Policy only); capital seigniorage labeled separate | [measured-DETF] C12 · F8 |
| Protocol compound deepens protocol BPT (claim backing *can* improve) | [measured-DETF] C13 · F9 |
| Keeper-free accrual / compound | [product-law][code] |
| Composable package types for different baskets | [design] C10 |
| Platform: many DETFs; optional protocol fee path | [design] C11 |

---

## 5. Nested mark integrity (measured SE)

**Headline.** With rate providers on, Uni demand re-marks Balancer mids so mid×rate residual ≈ 0. With rates off, residual scales with Uni stress. Residual is not free arb: under a 5% research pool fee, modest residual never filled; extreme residual did.

| Tier | R+ residual | R− residual | Mode C R− fills |
|------|-------------|-------------|-----------------|
| Baseline | ≈ 0 | ~±0.24% | 0 |
| mul10 | ≈ 0 | ~±2.4% | 0 (fee-drowned) |
| mul25 × 48 steps | ≈ 0 | ~±10–12% | Fills from ~step 22 |

Figures **F5–F6** ([FIGURE_MANIFEST](./FIGURE_MANIFEST.md)). Transferability: hermetic only; research fee ≠ all production fees.

---

## 6. DETF scenarios (measured Single SE + Uni V2)

**Harness:** production-first CREATE3 + registry DFPkg; Uni V2 WETH/USDC SE; `FOUNDRY_PROFILE=default`. Runner: `./research/run_detf_single_se.sh`. Details: Phase 3 FINDINGS.

| ID | Result | One-line |
|----|--------|----------|
| D0 | PASS | Inert Policy; defaults 1.05/0.95; mint blocked; warp inert |
| D1 | PASS | First bond → live |
| D2 | PASS | Post-bond burn-side synth; mint reverts; no expansion on warp |
| D3 | PASS | Mint-allowed after prod inventory path + Uni trades; preview==exec exact |
| D4 | PASS | Burn-allowed; burn executes |
| D5 | PASS | Open mint/burn live; no natural expansion over warp |
| D6 | PASS | Serial capital mints increase supply (not expansion) |
| D7 | PASS | Bonder reward path ≠ free-holder airdrop |
| D8 | PASS | Policy expansion when rich; Open twin none |
| D9 | PASS | Protocol compound raises protocol NFT BPT principal |

**Important limitation (RQ5).** After first bond, hermetic synthetic often sits ~0.625 (far below mintThreshold). **Uni trades alone** did not clear mintThreshold in this fixture; D3 uses **production** free-DETF primary burns + Uni trades + external share joins (no Open mode, no deal-seed). Document as research limitation of the post-bond book, not a product bug and not a license to storage-hack synthetic.

Figures **F1–F4, F7–F9**.

---

## 7. Composition types (short)

Four **live** families share the DETF pattern; only the reserve shape changes:

| Type | Choose when |
|------|-------------|
| Single SE | One SE vault + DETF weighted reserve |
| Multi-vault weighted | Multiple SE legs that must keep distinct valuations |
| Multi-vault stable | Like-kind rate targets |
| Mixed-buffer multi-vault stable | Shared buffer rateAsset; burn buffer only |

Removed `composed/single` / SingleVaultDetf is **out of universe**. v1 empirics cover Single SE only; other families are taxonomy + product law.

---

## 8. Product hierarchy

| Offer | Meaning |
|-------|---------|
| **Premier** | Create / deploy **your own DETFs** across package families |
| **Protocol DETF** | Same design class as a path to **share protocol fees** (amounts not guaranteed) |

Neither is a registered fund. Fee sizes are not promises.

---

## 9. Limitations and risks

1. **Hermetic only** — not mainnet TVL, APY, or reprice volume guarantees.  
2. **Not a registered securities ETF** — no legal ownership of offchain underlyings.  
3. **No peg / expansion APY / claim coupon** — Policy bands and expansion are mechanisms, not guarantees.  
4. **Open** removes price gates only — not fees, not returns, not expansion.  
5. **IL / LVR** on underlying legs remains; DETF does not “resolve” IL by slogan.  
6. **Fee transferability** — SE research 5% fee is not every production pool.  
7. **Post-bond synthetic** in hermetic Single SE may require inventory paths (not Uni alone) to re-enter mint-allowed (RQ5).  
8. **Protocol compound** single-sided join accepts self-leg weight skew in v1.  
9. **Immutable instances** imply abandonment risk if misconfigured—not silent admin rescue.

---

## 10. Future work

- Multi-family hermetic scenarios (weighted / mixed-buffer)  
- Fork validation of Single SE paths  
- Whitepaper threat model depth (malicious legs, residual-as-MEV, expansion dilution)  
- Optional F10 composition stacks under capital mints  
- Frontend R4 figure embeds under `/research` (claim-safe captions only)

---

## 11. Conclusion

A DETF is a reproducible onchain share over a real reserve, with one pricing engine, explicit Policy or Open rules, bonding into protocol-owned depth, bond-ledger rewards, Policy-only natural expansion when rich, and keeper-free protocol compounding into reserve BPT. Nested SE rate providers keep marks honest under demand when wired on. Hermetic research supports the lifecycle, gates, preview honesty, expansion negatives on Open, and protocol BPT growth on compound—without inventing yield.

---

## Appendix A. Methodology

| Item | Value |
|------|--------|
| Profile | `FOUNDRY_PROFILE=default` |
| DETF runner | `./research/run_detf_single_se.sh` |
| DETF out | `research/out/detf/singleSe/D{0..9}_*/` + `figures/` |
| SE compare | `./research/run_rate_provider_compare.sh` (+ high-vol flags only if regenerating) |
| SE out | `research/out/uniswapV2Se/rateProviderCompare/` |
| Telemetry | `series.jsonl` + stamped `meta.json` + `NOTES.md` per run |
| Production-first | CREATE3 facets; vault/DETF DFPkg via manager registry; **no mock SUT** |
| Synthetic drive (DETF D3/D4/D8) | Real Uni V2 trades (+ production inventory paths as documented); no primary storage hacks |

Agent handoffs: [`../../scenarios/detf/singleSe/AGENT_RESEARCH_REPORT.md`](../../scenarios/detf/singleSe/AGENT_RESEARCH_REPORT.md), SE agent report as above.

---

## Appendix B. Claims checklist (C1–C13)

| ID | Status in this draft |
|----|----------------------|
| C1 one share over reserve | §3 design |
| C2 pricing engine | §3.2 + F2–F3 measured |
| C3 inert → live | §3.3 + D0–D1 |
| C4 Policy/Open | §3.4 + D2–D5 |
| C5 immutability | §3.5 design |
| C6 preview honesty | §3.6 + D3 |
| C7 R+ residual | §5 + F5 |
| C8 fee threshold | §5 + F6 |
| C9 bond vs mint | §3b + D7 |
| C10 four live types | §7 taxonomy |
| C11 product hierarchy | §8 |
| C12 natural expansion | §3b + D5/D8 |
| C13 protocol compound | §3b + D9 |

---

*End of draft. Abstract and §1–2 refined last after figure polish in Phase 5.*
