# Product Requirements Document (PRD)

## Title

**UniswapV4StandardExchangeWeightedDETF** — true DETF with Uniswap V4 **Standard Exchange Weighted Buffer** reserve

## Status

**SUPERSEDED for mint/bond/burn/claim/close process** — use [`DETF_ALIGNMENT_PRD.md`](../../../../../DETF_ALIGNMENT_PRD.md) D1–D28. This file remains for family curve/token-set notes.

**DRAFT v0.4** — Co-design Q1–Q10 + review locks (2026-08-05). Mirrors Orbital DETF economics on the **Weighted SE Buffer Hook** reserve host, with family deltas: **per-route synthetic** (tokenIn/tokenOut pair as unit; **whole-reserve** FD), **all-legs-rich** natural expansion (**epoch-end** gate), **single-asset later bonds**, always-explicit `capitalToken`, **hook-SoT** mint quotes, first-bond **excess capital refund**. Partial book is **not** a normal after-live state for this family (full first bond + hook full-book floors). Product may **LOCK independently** of hook coding; implementors still hard-gate on frozen hook ABI (§17).

| Related | Role |
|---------|------|
| **This family impl plan** | [`UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md`](./UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md) (**v1.0** — implementor SoT once stamped) |
| **Reserve hook (mandatory dependency)** | [`UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md`](../../../../../../../../../hooks/uniswap/v4/standardExchange/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md) |
| **Behavioral DETF peer (primary process)** | [`UniswapV4StandardExchangeOrbitalDETF_PRD.md`](../orbital/UniswapV4StandardExchangeOrbitalDETF_PRD.md) — multi-external seigniorage, first bond, bond/claim, compound |
| **Behavioral DETF peer (economics)** | [`UniswapV4SingleStandardExchangeDETF_PRD.md`](../constantProduct/single/UniswapV4SingleStandardExchangeDETF_PRD.md) — seigniorage split, epoch expansion, threshold Policy/Open |
| **Behavioral DETF peer (code)** | Balancer `SingleStandardExchangeDETF` under `detf/…/balancer/v3/standardExchange/single/` |
| **Hook topology / process peer** | Weighted SE Buffer: n-leg weighted book, all \(\binom{n}{2}\) doors, buffer-last, Balancer single-asset aliases; hook allows partial seed for other products — **this DETF first-bonds full book only** |
| **Shared core** | `detf/common/core/*` (`DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFBondNFTMathLib`, expansion/compound helpers) |
| **Shared compound / expansion law** | `docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` (this family **in scope**; epoch form + debt-inclusive synthetic; **per-route FD** + **all-legs-rich** expansion gate — §5.5 / §10) |
| **Shared Uni V4 DETF packages** | `detf/protocols/dexes/uniswap/v4/common/` — bond NFT + rebasing (LP principal); **share with CP + Orbital families** |
| **AGENTS.md** | DETF families — common expectations; product docs co-located with code |
| **Skill** | `indexedex-uniswap-v4-hook-packages` (hook package deploy); `indexedex-testing` (DETF tests) |

**Short name:** UniV4 SE Weighted DETF (weighted buffer reserve family).

**Do not conflate with:**

| Package | Role |
|---------|------|
| `UniswapV4SingleStandardExchangeDETF` | Same true-DETF spirit; **2-leg CP** reserve (DETF raw × one pair). This family at \(n=2\) is still **weighted host** (weight vector + single-asset join/exit aliases + SE buffer hook) — first-class, not a substitute rename of CP |
| `UniswapV4StandardExchangeOrbitalDETF` | Same true-DETF spirit; **3-leg orbital sphere** reserve (DETF + 2 pairs) |
| Raw `UniswapV4WeightedSwapHook` | No SE buffering — not a DETF reserve host for this family |
| Balancer multi-vault weighted / mixed-buffer | Multi-SE valuation on Balancer hosts — different reserve topology |
| Weighted SE Buffer Hook alone | Reserve host only — not a DETF / seigniorage product |

---

## 0. Intent

### 0.1 Why this family

The UniV4 Single SE CP DETF lists **DETF ↔ one pairToken** under a constant-product buffer hook. The Orbital DETF lists DETF against **exactly two** external underlyings on a sphere AMM. Product goal for **this** family:

1. **List DETF against \(m \in [1, 7]\) external underlyings** on Uniswap V4 under a **weighted multi-door book** (reserve \(n = m + 1 \in [2, 8]\) currencies including the DETF self-leg).  
2. **Optionally buffer each external leg** into a Standard Exchange (yield-aware claim / optional rate provider) under the hood — **0…m SE vaults** with **≥1 SE required** on some external leg. A leg may also be a **bare ERC-20** (raw inventory on the hook). Pure all-bare external is **out of scope** for v1.  
3. Keep true-DETF law: diamond is the share ERC-20; seigniorage vs a reserve that includes a **DETF self-leg**; bond principal = **fungible hook LP**; rebasing claim on protocol-owned LP.  
4. Start the reserve at **deploy-time multi-leg creation rates** (may seed rich / off peg) with a **deploy-time immutable weight vector**.  
5. Reuse CP / Orbital family **epoch expansion + debt-inclusive synthetic**, with **per-route richness** on the **whole reserve market**: mint/burn synthetic uses the path’s external pair as unit of account; expansion accrues for an epoch only when **all** external legs are mint-rich **at epoch end** (§5.5 / §10). **No** whole-DETF deploy-time `rateAsset` field (per-leg SE rate providers only).  
6. Price and settle using the **weighted curve itself** via **hook source of truth** (spot mids, single-asset impact, multipath residual) rather than an off-book multi-asset FX ledger or a DETF-side curve reimplementation.

The reserve host is:

**`UniswapV4StandardExchangeWeightedBufferHook`**

- Pool currencies: **\(n \in [2, 8]\)** ERC-20s in **strict address-ascending binding order** (hook law)  
- **DETF binding (LOCKED):**
  - Exactly **one** leg is the **DETF self-leg**: raw only (`standardExchange = 0`, no rate provider on that leg).  
  - The other **\(m = n - 1 \in [1, 7]\)** legs are **external pair tokens** (`pairToken[0..m-1]` in product naming — not necessarily consecutive binding indices).  
  - Each external leg: **optional** SE (`address(0)` ⇒ bare raw token inventory) + **optional** rate provider **only if** SE is set.  
  - **At least one** external leg **must** have a non-zero SE (Q5). All-external-bare **reverts** at deploy.  
  - Non-zero SE addresses **pairwise distinct** (hook law).  
  - **Free binding order:** DETF may occupy **any** of the \(n\) binding indices as the unique raw self-leg (Q5), subject to hook **address-ascending token order** (tokens array sorted by address; DETF is one of those addresses once the diamond exists).  
- **Balancer Weighted Pool math** on appropriate domains (rated for swaps; native inventory for LP — hook §4.3).  
- Fungible hook LP ≈ BPT.  
- Full weighted join/exit surface + **`depositSingle` / `withdrawSingle`** aliases (Balancer single-asset — **not** multi-leg force rebalance).  
- All \(\binom{n}{2}\) Uni V4 pair doors share one book.  

**Primary product difference vs Orbital family:** reserve is an **n-asset weighted book** (\(n \in [2,8]\)) with **\(m = n-1\) external legs**, not a fixed-3 sphere; synthetic is **per-route** (pair of the mint/burn path), not a single deploy-time numeraire.  
**Primary product difference vs CP family:** weighted multi-leg join surface + multi-door topology even at \(n=2\); SE buffering via Weighted SE Buffer Hook (not Single SE CP hook).

### 0.2 Product one-liner

A **true DETF**: diamond **is** the DETF ERC-20; seigniorage mint/burn vs a **Uni V4 Weighted SE Buffer reserve** with DETF self-leg + \(m \in [1,7]\) external pair legs (bare and/or SE-buffered); bond principal = **hook LP**; rebasing claim = pro-rata claim on **protocol-owned hook LP**; Policy mint/burn gates use **per-route whole-reserve** FD synthetic in the path’s pair unit; **permissionless** first **bond** establishes **full-book** live at **deploy-time creation rates** (excess capital **refunded**) with deploy-time **weights**; later bonds are **single-external** (add liquidity only); Policy natural expansion is **immutable epoch premium-closure** paid to bonders **only for epochs still all-legs mint-rich at end**.

### 0.3 Goals

1. Ship DETF package under  
   `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/`.  
2. Wire **\(m \in [1,7]\)** external pair tokens + **≥1** distinct backing SE(s) + optional rate providers + **weight vector** via **`PkgArgs` → hook package deploy** (bootstrap hook only; doors via `productTokensWeighted` + one TX per pair) + **one** Weighted SE Buffer Hook with raw DETF self-leg.  
3. Primary mint/burn + bond + **maturity** close and **post-maturity** sell→claim + direct claim paths (adapted to n-leg host).  
4. Deploy-time **per-external creation rates** for empty-reserve first join; synthetic + Policy/Open thereafter.  
5. Seigniorage inventory → bond reward ledger (**same split spirit as Balancer / CP / Orbital UniV4 DETF**); protocol compound into reserve LP via single-sided DETF join (`depositSingle(DETF)`) when **single-asset eligible**.  
6. **Natural expansion (Policy):** same epoch premium-closure form as CP / Orbital UniV4 DETF peers (§10); accrues only when **every** external pair is mint-rich under per-route synthetic (**all-legs rich**).  
7. Production-first tests; no SUT mocks.

### 0.4 Non-goals (v1)

1. Implementing the reserve hook inside this package (hook is a dependency).  
2. Dual-OOR CL listing bonds / app-level listing oracle.  
3. \(n > 8\) or \(n < 2\) (hook hard range).  
4. Binding DETF as a buffered SE leg (self-leg is **raw** only).  
5. Same SE address on two legs (forbidden by hook).  
6. Balancer BPT reserve.  
7. Native ETH as a pool currency (use WETH if needed).  
8. Cross-chain.  
9. Subclassing Balancer DETF contracts, CP / Orbital UniV4 DETF contracts, or hook contracts.  
10. Guaranteeing peg, APY, or first-bond holder parity with later bonders.  
11. Multi-leg internal rebalance “zap” (forbidden by hook — one-token paths are Balancer single-asset only).  
12. MEV protection / commit-reveal on permissionless first bond.  
13. Treating V4 `sqrtPriceX96` as product mid after first bond.  
14. Family-local bond NFT / rebasing packages when shared Uni V4 common packages suffice.  
15. **All-external-bare** deploy (zero SEs) — use a different product if needed; this family requires **≥1 SE**.  
16. Fee-on-transfer / rebasing **pair** tokens as pool currencies (hook forbids; DETF restates).  
17. Protocol “rebalance” / multi-leg force-restore surface — not needed for normal lifecycle: this family **first-bonds a full book**; hook law forbids zeroing a full-book leg via exit; curve swaps do not fully drain a leg.  
18. Binary-search solvers for non-closed-form routes — **`InvalidRoute`** only.  
19. A separate deploy-time **`rateAsset` / whole-DETF multi-asset numeraire** field for mint/burn gates (use **per-route** pair unit instead — §5.5). Per-leg SE **rate providers** remain (shares → that leg’s pairToken only).  
20. **Multi-leg later bonds** (post-live bonds fund **exactly one** external pair — §8.1).  
21. Multi-token maturity close baskets — **every** bond records a **single** `capitalToken` chosen at open (§8.2).  
22. User-paid **DETF as bond capital** — bond payment is always external; protocol **mints** join DETF into the reserve with that payment.  
23. Claim redeem **`tokenOut = DETF`** — **`InvalidRoute`** (external / share / SE token only).  
24. Treating synthetic as “protocol LP only” or “bond NFT LP only” — synthetic is **market / whole-reserve** richness (§5.5).

---

## 1. Locked product decisions (summary)

| Topic | Decision |
|-------|----------|
| Family type name | **`UniswapV4StandardExchangeWeightedDETF`** |
| Package path | `detf/protocols/dexes/uniswap/v4/standardExchange/weighted/` (PRD co-located) |
| True DETF | **Yes** — diamond is share ERC-20; reserve includes DETF self-leg |
| Reserve host | **`UniswapV4StandardExchangeWeightedBufferHook` only** |
| Reserve size | **\(n \in [2, 8]\)** pool tokens; **\(m = n-1 \in [1, 7]\)** external pairs (**Q1**). **\(n=2\) is first-class** (not CP) |
| Binding order | Hook: **address-ascending** tokens. DETF is the unique **raw** self-leg at **its address index**; free which token is DETF among the sorted set (**Q5**) |
| External legs | **\(m\)** pair tokens always for a given instance; each may be **bare** (SE=0) or **SE-buffered** (**Q5**) |
| SE slots | **At least one** non-zero SE on an external leg; at most \(m\); non-zero SEs **pairwise distinct**. **All-external-bare forbidden** (**Q5**) |
| Weights | **Deploy-time immutable** weight vector \(w[0..n-1]\) with \(\sum w_i = 1\mathrm{e}18\), \(w_i \ge 1\%\) (hook Option A); includes DETF self-leg weight (**Q6**) |
| Rate providers | **Optional** per SE-buffered leg only; when set, **must rate SE shares → that leg’s pairToken** (1e18 pair per share peer). **Not** a synthetic numeraire. Not on DETF or bare legs |
| **Synthetic / FD ruler** | **Per-route, whole-reserve:** `syntheticVs(pair_k)` = FD extractable residual of the **entire reserve pool** consolidated **to pair_k** ÷ effective DETF supply, scaled by **creationPairPerDetfWad[k]**. Measures **market** richness, not a particular LP holder. Mint uses funded pair; burn uses `tokenOut` pair. **No whole-DETF `rateAsset` field** (**Q7**) |
| Primary mint quote | Capital always **rated into the funded pair-leg units** (pair face, or SE share→pair via claim/RP), then seigniorage quote against reserve for that leg via **hook source of truth** (no DETF-side curve reimplementation). **No** forced convert through another pair mid |
| PkgArgs → hook | DETF DFPkg passes tokens / weights / SEs / RPs / poolManager / feeOracle / mineNonce into hook package `deployHookVault` + pool init |
| Backing SEs | Settlement SEs for mint/bond capital are the **same** instances bound on the hook for that pair |
| Live | **Permissionless first successful bond** that joins reserve LP (synthetically ungated) |
| First bond capital | **Requires all external pair legs** funded (pair tokens and/or SE-accepted capital that settles to each external) (**Q2**) |
| First bond close asset | Caller **always passes** `capitalToken ∈ pairTokens` (even if \(m=1\)). Maturity close pays **only** that token |
| Creation rates | **Deploy-time `PkgArgs`** — one WAD rate **per external pair**, each **`> 0`**; size first-bond DETF + external legs so initial weighted mids ≈ creation (**Q6**). Operators own amount ratios under unequal weights (no exact mid guarantee) |
| Seigniorage | Peer Single SE / CP / Orbital DETF: boost on **funded pair-leg notional** → `quoteDetfAgainstReserve` → usage fee → half-incentive inventory / user / feeTo |
| Primary mint (live) | **Any external pair** (or capital settled into that pair / its SE) via hook **`depositSingle` / `joinSingleAssetExactIn`** when single-asset eligible (**Q3**). After a successful all-external first bond, the reserve is a **full book**; partial-book single-asset blocks are **not** a normal lifecycle path for this family (see §5.4 / §7) |
| Primary burn | **Burn only user-provided free DETF** when under peg (Policy). **Normative:** multipath / proportional remove of protocol LP + residual pair settle; **redeposit** DETF returned from remove. **`withdrawSingle` = pure optimization** when preview-equal and depth invariants hold — **never** required for DoD (**Q4**) |
| Bond (after live) | **No Policy/synthetic price gate**; **exactly one external pair** capital (user never pays DETF); protocol **mints join DETF** + multipath with that pair; free seigniorage legs from split; **does realize** expansion debt |
| Bond principal | **Hook LP** on shared Uni V4 bond NFT package |
| Bond `effectiveShares` | **DETF-valued principal at open** × lock bonus: each funded external pair notional converted to DETF at **open-time weighted mids** (closed-form), then summed (reward-weight unit only — not Policy synthetic) |
| **Sell bond → rebasing claim** | **Only after maturity** — pre-maturity sell **reverts**. **DETF-wide standard**. Enforced on DETF surface always; shared common package **may** take optional `requireMature` flag |
| **Pre-maturity principal exit** | **None** — only `claimRewards` while locked |
| **Maturity close settlement** | Always pay the **single `capitalToken` recorded at open**. Prop remove → redeposit DETF → consolidate all other non-DETF legs → `capitalToken` |
| **Post-maturity hold** | Exit **optional forever** — no forced close |
| **Bond NFT transfer** | **Free ERC-721 transfer** anytime (incl. marketplaces); buyer inherits lock + capital-token metadata. No soulbound-while-locked |
| Claim redeem | Protocol-LP apportioning; settle matrix §9; **redeposit** DETF returned from remove; **`tokenOut = DETF` → InvalidRoute**; prefer **clean vaultShare path** when `tokenOut` is a share. May use `withdrawSingle` only as optimization |
| Free DETF → claim | Hook **`depositSingle(DETF)`** when single-asset eligible; no seigniorage (deposit path only — not redeem out) |
| Expansion realize paths | **Only** bond / `claimRewards` / `compoundProtocolRewards` (+ reward updates). **Not** primary mint/burn |
| Compound if not single-asset eligible | **Skip** (no revert) — leave pending |
| Route errors | **`InvalidRoute`** for bad routes; plus stable family errors for not-live, not-mature, not-single-asset-eligible, first-bond-needs-all-externals, later-bond-single-only, protocol-LP-empty, lock-too-short, min-out (see §12) |
| Fixed-point | Scale to **1e18** internal; scale back for transfers |
| Instance governance | Immutable / unowned after deploy |
| DETF DFPkg path | IndexedEx manager vault registry |
| Hook / children deploy | Hook: registry `deployHookVault` + hook diamond factory; bond NFT + rebasing: pure Crane; owner = DETF diamond |
| Bond NFT / rebasing | **Share** `uniswap/v4/common/` packages with CP + Orbital; mature-only via DETF + optional shared flag |
| Fee-recipient NFT | Wire like Balancer Single SE / peer UniV4 DETFs; **same** mature-only principal rules if they hold a bond |
| Compound | Protocol NFT only → single-sided DETF join (`depositSingle(DETF)`) when single-asset eligible |
| Natural expansion | Deploy-time epochs + premium-closure; unlimited whole-epoch catch-up (`maxCatchUpEpochs=0`); **not** fee oracle; Policy accrues only when **all** external legs mint-rich (**Q10**); **whole epoch only if still all-legs mint-rich at epoch end** |
| Synthetic + epoch debt | Pending expansion in **each** per-route synthetic denominator (§5.5); FD uses **whole reserve pool** |
| Peg narrative | Per external pair \(k\): abstract **1e18** = FD claim in pair \(k\) per DETF equals **creationPairPerDetfWad[k]**. No global external peg pair |
| Buffered-leg mint capital | **Pair face allowed** (pool/hook buffers); also vaultShare / SE.tokens() when SE set |
| Test matrix | Gentle **and** launch-rich expansion equal priority; configs for \(n \in \{2,3,4,8\}\) priority rows; **1 SE + bare rest** and **all-external-SE** configs; **no** all-bare production path; **RP on/off** optional rows; bare + buffered mix when \(m \ge 2\); first-bond **explicit capitalToken** + **excess refund** + **full book**; later bond **single-asset only** (adds only); **epoch-end all-legs-rich** expansion rows; per-route mint open / burn open skew rows; **hook-SoT** mint preview == execution |

---

## 2. Role vocabulary (LOCKED)

| Role | Name | Meaning |
|------|------|---------|
| DETF share / diamond | `detfToken` / `address(this)` | ERC-20; reserve **raw** self-leg at its binding index |
| External pairs | `pairToken[i]` / `pairTokens` | The \(m = n-1\) external ERC-20s (product / PkgArgs order); map to hook binding indices at deploy |
| Bare pair leg | pair with `standardExchange_i == 0` | Hook holds **face ERC-20** as that leg’s book |
| Buffered pair leg | pair with non-zero SE | Hook holds **SE shares**; free pair is dust only |
| Backing SE \(i\) | `standardExchange[i]` | Optional SE for each pair; **must not** list DETF; **distinct** when non-zero |
| SE share \(i\) | `vaultShare[i]` | Present only when that SE is set |
| Rate provider \(i\) | `rateProvider[i]` | Optional; non-zero **only if** corresponding SE set; rates **SE shares → that leg’s pairToken** |
| Weights | `weights` / \(w_i\) | Deploy-time immutable; index-aligned with **hook binding order**; sum \(1\mathrm{e}18\); each \(\ge 1\%\) |
| Reserve | `reserveHook` / `reservePool` | Weighted SE Buffer Hook + its \(\binom{n}{2}\) V4 doors |
| Reserve principal | `reserveLp` / hook LP | Fungible LP from reserve hook (BPT analogue) |
| Bond NFT | `bondNft` | Shared Uni V4 package; holds user `reserveLp` while open |
| Protocol principal | protocol-owned `reserveLp` | Held by **shared** rebasing package |
| Rebasing claim | `rebasingClaimToken` | ERC-20 claim on protocol `reserveLp` |
| Creation rates | `creationPairPerDetfWad[i]` | Deploy-time empty-book join rates (WAD) for each external pair vs DETF; **each must be > 0** |
| Native / rated reserves | hook inventory vs rated swap balances | LP uses native; swaps/seigniorage quotes use rated where RP/claim applies (hook law) |
| Single-asset eligible | hook full book + supply > MIN | Gate for `depositSingle` / single-asset join paths (prefer this term over “zap-eligible”) |
| Bond capital token | per-`tokenId` `capitalToken` | **Single** external pair address chosen at open; maturity close pays **only** this token |
| Per-route synthetic | `syntheticVs(pair_k)` | Debt-inclusive FD richness of DETF vs external pair \(k\) (creation-scaled) |
| FD residual to pair | `previewWholeReserveToPair(pair_k)` | Prop/multipath remove residual of the **entire reserve pool** consolidated **to pair_k** via weighted exact-in (incl. DETF → pair_k). Market-level, not holder-sliced |
| Whole reserve | reserve hook book + full LP supply | Synthetic marks the **market** (all pool inventory / outstanding hook LP), not “protocol’s share” or “bonders’ share” alone |

**Anti-patterns:** brand tickers; pair ∉ SE tokens when SE set; DETF listed in any SE; same SE on two legs; RP without SE; RP on bare/DETF legs; inventing hook APIs; treating V4 mid as product mid; burning DETF returned from multipath remove (must redeposit); FoT/rebasing pair tokens; all-external-bare deploy; multi-leg force-rebalance “zap” wording for one-token paths; reintroducing a **whole-DETF `rateAsset`** field for mint/burn gates; multi-leg later bonds; multi-token maturity baskets; user-paid DETF as bond capital; claim redeem to DETF face; computing synthetic from a **subset** of LP holders only.

**Not used in this family:** product role **`rateAsset`** as a **whole-DETF** synthetic numeraire / deploy-time “peg pair.” Mint/burn use the **route pair** as unit. SE **rate providers** still rate **shares → pairToken** for buffered legs only (hook / SE law) — that is **not** a DETF-wide rateAsset. Peer CP / Orbital PRDs and the generic AGENTS.md role table that name a single `rateAsset` gate are **not** copied here; **this family supersedes** that role for synthetic/gates.

---

## 3. Topology (LOCKED)

```text
                    ┌──────────────────────────────────────────────┐
                    │ UniswapV4StandardExchangeWeightedDETF         │
                    │ diamond = detfToken ERC-20                    │
                    │ immutable / unowned after deploy              │
                    └───────────────────┬──────────────────────────┘
                                        │
     ┌──────────────────────────────────┼──────────────────────────────────┐
     │                                  │                                  │
     v                                  v                                  v
┌──────────────┐              ┌─────────────────────────┐        ┌─────────────────┐
│ SE ×1…m      │              │ Reserve Weighted Hook     │        │ Bond NFT pkg    │
│ (distinct)   │◄─buffer?─────│ n∈[2,8] tokens: DETF raw  │──LP───►│ (shared common) │
│ or bare legs │              │ + pair[0..m-1]            │        │ user LP + rewards│
└──────────────┘              │ each pair: bare or SE+RP? │        └────────┬────────┘
                              │ weights; weighted math    │                 │ sell
                              │ fungible LP; C(n,2) doors │                 │
                              └──────────┬────────────────┘                 v
                                         │ protocol LP             ┌─────────────────┐
                                         v                         │ migrate LP →    │
                              ┌─────────────────────┐              │ protocol        │
                              │ Rebasing claim pkg   │◄─────────────│ (shared common) │
                              │ holds protocol LP    │  deposit     └─────────────────┘
                              │ redeem matrix §9     │
                              └─────────────────────┘
```

**Public market (many doors, one room):**

```text
All pairs among {DETF, pair[0], …, pair[m-1]}
  ──► same reserve hook (shared weighted book + LP)
```

Examples:

| \(n\) | Currencies | Doors \(\binom{n}{2}\) | External legs |
|------|------------|------------------------|---------------|
| 2 | DETF + A | 1 | 1 |
| 3 | DETF + A + B | 3 | 2 |
| 4 | DETF + A + B + C | 6 | 3 |
| 8 | DETF + 7 pairs | 28 | 7 |

**Opacity:** DETF production talks to `IStandardExchange*`, reserve hook ABI (`IStandardExchangeMultiAssetLiquidity` + join/exit aliases), bond NFT APIs, rebasing APIs, fee oracle, shared DETF libs. DFPkg wires hook package deploy from `PkgArgs`. Product mid is **never** V4 `sqrtPriceX96` after first bond.

**Same SE instances:** Settlement for mint/bond capital uses the SEs bound on the hook for the corresponding pair token (when set).

---

## 4. Liveness & first bond (LOCKED)

### 4.1 States

| State | Condition |
|-------|-----------|
| **Inert** | Deployed; reserve hook bound; all V4 doors may be initialized with plumbing; **no** successful bond yet; primary mint/burn blocked; non-first bonds blocked |
| **Live** | First **successful bond** completed that minted DETF for join and placed **reserve LP** on the bond NFT; `isReserveLive = true` |

### 4.2 First bond access (LOCKED)

**Permissionless.** Any address may establish live with a successful first bond.  
No product min notional beyond hook **MINIMUM_LIQUIDITY** / first-mint constraints (preferred all \(n > 0\) inventory legs; \(V_{\mathrm{inv}} >\) MINIMUM_LIQUIDITY).  
If first mint would fail hook geometric / MIN liquidity constraints, **revert** with a clear product error (cannot go live).  
No MEV protection in v1; operators should seed with a **small but viable** multipath / proportional first bond. **No holder-parity guarantee** between first and later bonders.

### 4.3 Creation rates (deploy-time)

| Field | Meaning |
|-------|---------|
| **`creationPairPerDetfWad[i]`** | After decimal normalize to 1e18, how much **pairToken[i]** (WAD) equals **1e18 DETF** at empty-book join |
| Storage | Resolved from `PkgArgs` at deploy; **immutable** on instance |
| Count | Exactly **\(m\)** rates — one per external pair (PkgArgs order aligned with `pairTokens[]`) |
| **Validation (LOCKED)** | Every rate **must be `> 0`**. Zero or missing ⇒ deploy/init **reverts**. No product max; operators choose seed richness. **No required invariant** between rates (cross-pair relative prices free). |

#### Decimal convention (LOCKED — peer CP / Orbital DETF)

1. Convert amounts to **internal WAD (1e18)** for all pricing, synthetic, creation-rate, and seigniorage math.  
2. Creation rates stored and consumed **only in WAD space**.  
3. Scale back to native decimals for ERC-20 transfers and hook calls.

**Example (\(m=2\)):** Want “1 DETF = 2 USDC and 1 DETF = 0.001 WETH” at seed →  
`creationPairPerDetfWad[USDC] = 2e18`, `creationPairPerDetfWad[WETH] = 0.001e18` after WAD normalize.

**Peg narrative (LOCKED):** for each external pair \(k\), abstract **1e18** on `syntheticVs(pair_k)` means FD claim of counted reserve LP **in pair \(k\)** per DETF equals **creationPairPerDetfWad[k]**. Creation rates also size the first multipath join and seed initial mids. There is **no** single global external peg pair — richness is always relative to a chosen pair leg.

### 4.4 First bond mechanics (LOCKED — Q2)

First bond is **synthetically ungated** (Policy and Open).

**Requires all external pair legs** with non-zero capital after settlement (pair tokens, vault shares, and/or SE-accepted tokens that resolve to **every** `pairToken[i]`). Missing any external → **reverts** (`FirstBondRequiresAllExternalPairs` or family equivalent).

**Close asset (LOCKED):** caller **must** supply **`capitalToken`** — required even when \(m=1\); must be one of `pairTokens` (all funded on first bond). Stored on the NFT as the **sole** maturity-close settlement token.

1. User supplies capital resolving to **all** external pair-notionals \(C_i > 0\) in WAD, plus chosen **`capitalToken`**.  
2. **Mint DETF for join** using **creation rates only** (not live weighted mid):

```text
// WAD space — join DETF sized so empty multipath / proportional ratio matches creation
for each external i:
  detfFrom[i] = pairNotionalWad[i] * 1e18 / creationPairPerDetfWad[i]
// Common join size: min of implied DETF amounts
detfForJoinWad = min_i(detfFrom[i])
require detfForJoinWad > 0
// Excess external capital beyond the amounts needed for that join (creation-price match
// under deploy weights) is REFUNDED to the bonder — user keeps surplus; do not seize it.
```

3. Apply **peer mint modifiers** on the join-sized gross (seigniorage split for free legs — same as CP / Orbital DETF spirit). Free `user` / `feeTo` / `inventory` DETF is **not** joined into the reserve; only **join-sized** DETF enters the multipath / proportional join.  
4. Settle capital to **native pair tokens** (convert SE tokens/shares → pair when SE set; bare legs are already native).  
5. Reserve hook **`joinProportional` / multipath unbalanced join with all maxes** (required product intent: all \(n\) legs > 0) with join DETF on self-leg index + all pairs on external indices (binding-order amount arrays). Buffer SE legs last (hook law).  
6. **Refund** any unused external capital (and unused SE-routed remainder) to the caller after join sizing / hook clamp.  
7. **LP → bond NFT package** for `tokenId`; record **`capitalToken`** (single) and **effectiveShares**.  
8. Set **`isReserveLive = true`**.  
9. **Post-condition (LOCKED):** first bond establishes a **full book** (all native inventory legs \(> 0\)). Incomplete seed is **out** for this family — if the join would leave any external leg at zero, **revert** (cannot go live partial).

#### Unequal weights (LOCKED product stance)

Empty-book weighted mids depend on **weights and amount ratios**. Product law:

- Sizing algorithm remains **min-implied DETF + multipath / proportional join** as above, with **refund of excess** external capital.  
- Operators **must** supply external amount ratios that, given deploy weights, approximate the desired creation mids (surplus is refunded, not forced into a skewed join beyond the min-implied size).  
- Product guarantees only: rates `> 0`, full external funding, viable MIN liquidity, **full book** post-join, and mids **≈** creation (modulo SE buffer fees, dust, weight geometry, free seigniorage legs outside the pool).  
- **No** on-chain solver that re-derives exact Balancer empty-join ratios in v1.  
- Tests cover equal and unequal weight rows; unequal weight does **not** require exact mid equality; refund paths covered.

**Empty book / mids (LOCKED):** hook first mint sets inventory-domain \(V\); join DETF sized by creation rates so **book** weighted mids ≈ creation rates at the multipath join (with the caveats above). Free seigniorage legs **intentionally** sit outside the pool and do **not** re-size the join; any later free-float or inventory mint into claim/compound can move mids — **no holder-parity guarantee**. All-external first bond **does** establish a **full book**, so primary mint **`depositSingle`** is available immediately after live under hook full-book rules.

**\(n=2\) special case:** only one external pair; “all external legs” = that single pair; `capitalToken` is that pair. First bond is still multipath DETF+pair (not one-token-only first mint — hook first mint is not via `depositSingle`).

### 4.5 After live

- **Primary mint/burn:** subject to Policy/Open **per-route whole-reserve** debt-inclusive synthetic gates (Open: ungated). Mint gate uses funded pair; burn gate uses `tokenOut` pair.  
- **Further bonds (after live):** **no synthetic / Policy mint gate.** User pays **exactly one** external pair (or SE capital settling to that pair) — **never** DETF. Protocol **mints join DETF** into multipath with that capital (**adds** DETF + that pair; does **not** remove other legs). Multi-external later bonds **revert**.  
- Bond paths **also** mint free DETF legs from the seigniorage split of the join quote (user/feeTo/inventory); quote via **hook SoT**.  
- Bond / `claimRewards` / `compoundProtocolRewards` **realize** pending expansion debt (§10). Primary mint/burn **do not**.  
- Reserve mids from weighted **rated** (swaps) / inventory (LP) domains per hook.  
- Creation rates remain first-bond seed **and** per-leg synthetic scale; **not** used to size later mint join amounts.  
- **Full book stays the designed live state** (§5.4): curve + hook full-book exit floors; first bond required all externals.  
- **Live does not imply burnable depth:** first-bond LP sits on the NFT; protocol LP may be ~0 until primary mint, bond-sell, or compound. Primary burn **reverts** if protocol LP insufficient (intentional) — this is about **who holds LP for redeem**, not about a pair leg being empty.

---

## 5. Pricing, synthetic, thresholds (LOCKED)

### 5.1 Marks

| Mark | When | Use |
|------|------|-----|
| **Creation rates** | First bond only (and inert info) | Size first-bond DETF for multipath join; seed mids |
| **Reserve mids** | Live | Weighted mids from live book; **seigniorage quotes** and open-time bond valuation |
| **FD backing / synthetic** | Live | Per external pair: fully diluted claim of the **whole reserve pool in that pair** ÷ **effective DETF supply** (includes **pending epoch expansion debt**), scaled by that pair’s creation rate — §5.5 |

### 5.2 Decimal scale (LOCKED)

All internal pricing, synthetic, thresholds, creation rates, seigniorage boost, weights (already WAD), and expansion math run in **1e18-normalized** units. Scale to/from native decimals only at token boundary I/O.

### 5.3 Seigniorage quote shape after live (LOCKED — peer spirit)

**Goal:** replicate Balancer / CP / Orbital UniV4 DETF seigniorage economics on this host, with **per-leg rating**.

**Normative capital rating:**

1. Identify which **external pair leg** the `tokenIn` funds.  
2. Convert `tokenIn` amount → **pair-leg units** for that leg only:  
   - **pairToken itself:** face amount (WAD).  
   - **SE vault share:** always **rate** to pair units — if RP set: `shares × getRate() / 1e18` (then toWad); if no RP: fee-inclusive SE unwrap/claim preview to pair.  
   - **Other token ∈ SE.tokens():** SE route → pair, then same as pair face.  
3. **Do not** convert that pair notional through another pair mid for the mint quote.  
4. Boost that **pair-leg notional** by seigniorage incentive; **`quoteDetfAgainstReserve(pairLeg, pairNotionalBoosted)`** — **hook is source of truth** for join impact / economic inverse (see below).  
5. Peer `_splitMintedDetf` for free legs.

```text
// LOCKED — per funded pair leg
pairNotionalWad = rateTokenInToPairLeg(tokenIn, amountIn)  // never skip rate on SE shares
pairBoosted     = pairNotionalWad * (1e18 + seigniorageIncentiveWad) / 1e18
grossDetf       = quoteDetfAgainstReserve(fundedPairLeg, pairBoosted)  // via hook previews
// Split peer:
feeToDetf / inventoryDetf / userDetf from gross
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| **Live primary mint** | Rate capital → pair units → hook **`depositSingle(pairToken_i)`** (single-asset join). **No** DETF self-leg join on this path. | Mint `user` / `feeTo` / `inventory` only |
| **Bond (live)** | Rate capital → **one** pair; multipath join DETF + that pair max; LP → bond NFT; **record `capitalToken` = that pair** | **Also** mint free legs from split |
| **First bond** | Creation-rate sized join DETF + **all** external pairs; LP → bond NFT; **record user-chosen `capitalToken`** | Same free legs from split of gross |

**`quoteDetfAgainstReserve` (economic + implementation LOCK):**

| Layer | Rule |
|-------|------|
| **Economic identity** | Gross DETF is the seigniorage mint size such that the **pair-leg capital**, if joined single-sided via the same path as live primary mint (`depositSingle` / single-asset join impact), backs that DETF at the **post-impact** reserve mid for that leg — i.e. the inverse of “how much DETF the reserve prices for this pair in under current book.” **Not** creation rate. **Not** forced convert through other pairs. **Not** tick-walk / binary search. |
| **Source of truth (LOCKED)** | The **reserve hook** is the sole calculator for join impact / single-asset economics. DETF **must call hook view/preview (and/or the same join path the hook will execute)** — **do not reimplement WeightedMath / curve algebra inside the DETF** for this quote. That keeps mint sizing **always consistent** with what the hook will do. |
| **Preview == execution** | Assert on mint/bond closed-form routes (≤ few-wei only if SE multi-leg dust forces it; document). |

Impl plan freezes which hook selectors/previews are used; product law forbids a divergent DETF-side formula.

**Rate providers (LOCKED + hook law):** when set on a buffered leg, RP **must** express **SE shares → that leg’s pairToken**. Product purpose: Uniswap V4 exposes **pair tokens** as pool currencies; SE inventory is rated **as** that pair for swap-side book and mint/bond capital. RPs configure share→pair rating only; **route pair** is the synthetic unit for that path.

**Preview == execution** on closed-form routes (≤ few-wei only if SE multi-leg dust forces it; document).

### 5.4 Settlement `tokenIn` (primary mint & bond capital) — LOCKED Q3

| `tokenIn` | Allowed | Notional resolution |
|-----------|---------|---------------------|
| Any `pairToken[i]` | Yes | amount → pair_i WAD (face) |
| `vaultShare[i]` | Yes **if** corresponding SE set | **Always rate** share → pair units (RP or SE claim) |
| Other token ∈ SE_i `tokens()` | Yes **if** SE_i set | SE → pair, then face pair WAD |
| Else | **`InvalidRoute`** | — |

**Primary mint:** user may mint with **any** external pair (or capital that settles/rates to that pair). Hook path = **`depositSingle` / `joinSingleAssetExactIn` of the native pair token** after settle. **Buffered legs: bare pair face is allowed** — the weighted SE buffer host abstracts buffering (buffer-last). Vault shares / SE.tokens() remain allowed when SE set.

**Later bond:** same capital table, but must resolve to **exactly one** external pair; multi-pair funding **reverts**. User **never** pays DETF to open a bond. Later bonds **add** DETF (protocol-minted) + that one external into the book — they **do not remove** other legs.

**Full book vs single-asset eligibility (LOCKED — v0.4 correction):**

| Fact | Product law |
|------|-------------|
| Curve swaps | Weighted pricing makes fully draining a leg with finite swap capital **not** a realistic path; price asymptotes. |
| Hook full-book exits | While full book, removes **must leave all \(n\) native reserves \(> 0\)** (hook D48 / weighted peer D67). Zeroing a leg via full-book exit **reverts**. |
| Partial book on hook | Entered only via **partial first mint / incomplete seed** on the hook — **not** by draining a full book with swaps or exits. |
| This family first bond | **Requires all external legs** and **reverts if any external would remain zero** → goes live only on a **full book**. |
| After live | **Normal path:** full book remains; `depositSingle` for primary mint / compound is available under hook full-book rules. |
| `NotSingleAssetEligible` | **Exceptional** (mis-config, defect, or non-family incomplete-seed paths) — **not** a normal “later bonds or trading emptied a leg” lifecycle. Do **not** document later one-pair bonds as causing zero legs. |
| Adding liquidity | One-pair bonds and primary mints **add** inventory; they do **not** reduce sibling legs. |

**v1:** settle/buffer to the **native pair token** before hook deposit. Bare legs: no SE hop. Buffered legs: pair face buffers via host; shares rate then buffer per hook.

### 5.5 Synthetic (gates + expansion) — **per-route pair unit + pending epoch debt** (LOCKED)

**Why not one global numeraire:** the reserve is a **weighted multi-asset book**. Balancer already prices DETF vs each pair (and pairs vs pairs) without an off-book USD ledger. Product law uses that: **richness is always relative to a specific external pair**.

**Route unit of account (LOCKED):**

| Operation | Pair unit \(k\) |
|-----------|----------------|
| Primary **mint** | External pair the `tokenIn` settles/rates into |
| Primary **burn** | User’s `tokenOut` pair (before optional SE unwrap) |
| Natural **expansion** (no tokenIn) | **All** external pairs must be mint-rich (see below) |
| Bonds after live | **No** synthetic gate |

**Peg narrative:** for pair \(k\), abstract **1e18** means FD claim of counted reserve LP **in pair \(k\)** per DETF equals **creationPairPerDetfWad[k]**.

**Rule (LOCKED):** each `syntheticVs(pair_k)` uses **effective DETF supply** = on-chain `totalSupply` + **pending expansion DETF**.

**Whole-reserve FD (LOCKED — market richness, not holder slice):**

Synthetic measures how rich the **market reserve** is relative to DETF supply. Use the **entire reserve pool** (full hook book / full outstanding hook LP supply and its extractable residual composition) — **not** “protocol LP only,” **not** “bond NFT LP only,” **not** any other holder subset. Who holds LP (bond NFT vs rebasing package vs elsewhere) matters for **exit rights and claim accounting**; it does **not** redefine the synthetic ruler.

**`previewWholeReserveToPair(pair_k)` (LOCKED — full extractable residual in pair \(k\)):**

```text
// Whole-reserve residual in pair_k (LOCKED):
// 1) Take the full reserve pool inventory / full LP supply as the FD basis
//    (equivalent: proportional remove of totalSupply hook LP, or inventory residual
//     that represents the entire book — impl freezes bit-exact vs hook)
// 2) Residual legs in binding order → (a_detf, a_pair[0], …, a_pair[m-1])
// 3) FULL residual → pair_k (LOCKED):
//      pair_k face += a_pair_k
//      each other pair → weighted exact-in sell into pair_k
//      DETF self       → weighted exact-in sell into pair_k
//    Prefer hook previews for residual/swap legs where available (same SoT spirit as §5.3).
//    Fee-aware closed forms; order frozen in impl plan when pure math is required.
// 4) Redeposit-on-execution is SEPARATE from FD (execution depth policy only).

fdPair_k = previewWholeReserveToPair(pair_k)

S_spot_k = (fdPair_k * 1e18 / detfTotalSupply) * 1e18 / creationPairPerDetfWad[k]

pendingExpansionDetf = previewPendingExpansionMint()
effectiveSupply = detfTotalSupply + pendingExpansionDetf

syntheticVs(pair_k) = (fdPair_k * 1e18 / effectiveSupply) * 1e18 / creationPairPerDetfWad[k]
```

**Policy gates (when live):**

| Path | Gate |
|------|------|
| Primary mint → pair \(i\) | Allow iff `syntheticVs(pair_i) > mintThreshold` (default 1.05e18) |
| Primary burn → pair \(j\) | Allow iff `syntheticVs(pair_j) < burnThreshold` (default 0.95e18) |
| Equality on that route | **Deadband** for that route only |
| Open | Threshold gates **always pass**; pending expansion **0** |
| First bond | Synthetically **ungated** |
| Bonds after live | **No** synthetic mint gate |

**Implication:** the book may be mint-open for USDC and mint-closed for WETH at the same time (skew / trades). That is intentional.

**Natural expansion mint-rich predicate (LOCKED — Q10):**

```text
allLegsMintRich =
  live && thresholdMode == Policy
  && for every external pair_k:
       syntheticVs(pair_k) > mintThreshold
```

Expansion **accrues** only while `allLegsMintRich` (Open: never). See §10. Pending debt still enters **every** `syntheticVs` denominator when computing gates.

**Gas feasibility (LOCKED product stance):** \(n \le 8\), \(m \le 7\). All-legs check is feasible on-chain:

1. **Read once** — load hook balances / weights / supply / counted LP (and rate providers if rated domain requires).  
2. **One** proportional-remove residual preview for counted LP (share across legs).  
3. **Loop** \(k = 0..m-1\): pure weighted exact-in math to consolidate residual → pair \(k\); compare to threshold.  
4. Math is cheap vs storage; short-circuit on first non-rich leg when only a boolean is required for expansion.

Real gas risk is **external RP/SE calls** if every rate read is hot — freeze rated vs inventory domain with hook law; do not invent per-leg solvers. Impl plan may cache residual and fail-fast.

**Source of truth:** `ThresholdMode` + thresholds from **`PkgArgs` → resolve → storage only**. Fee oracle does **not** set thresholds.

**Realize vs accrue:** expansion realize only on bond / claimRewards / compound; **not** on primary mint/burn.

**Info surface:**

- `syntheticPrice(address pair)` / `syntheticVs(pair)` — debt-inclusive  
- optional `syntheticPriceSpot(address pair)`  
- `isMintingAllowed(address pair)` / `isBurningAllowed(address pair)`  
- optional `isAllLegsMintRich()` for expansion UX  
- `pendingExpansionDetf()`, creation rates, pairs, SEs, RPs, weights, binding indices, \(n\), \(m\)  
- **No** parameterless global `syntheticPrice()` as the sole gate oracle (if exposed, document as deprecated alias or require pair)  
- **No** `rateAsset()` getter

### 5.6 Primary burn of DETF (LOCKED — Q4)

**When:** Policy burn gate on **`tokenOut` pair** (`syntheticVs(tokenOut) < burnThreshold`) or Open when live.  
**Settlement:** user chooses `tokenOut ∈ pairTokens` (and optionally SE unwrap of that pair — §9.4). **`tokenOut = DETF` → InvalidRoute**. Else **`InvalidRoute`**.

**LP basis (peer debt model):**

```text
protocolLp = reserveLp.balanceOf(protocolLpHolder)
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
lpOut = detfBurned * protocolLp / effectiveSupply
// if protocolLp == 0 or lpOut == 0 → revert
```

**Execution (LOCKED + burn fee/dust/redeposit):**

1. Require live + **debt-inclusive** burn gate on **`tokenOut` pair** (Open: always when live).  
2. Pull **user-provided free DETF** (`detfBurned`); compute `lpOut` with **effectiveSupply** (**do not** realize expansion).  
3. **Burn only `detfBurned`** (the free DETF the user is redeeming).  
4. **Usage fee on burn: YES** — apply vault fee oracle burn usage fee as peer DETFs (`DETFUsageFeeLib` path). **No** mint-style inventory / seigniorage split on burn.  
5. **Normative path — multipath / proportional remove:**  
   - `exitProportional` / multipath `removeLiquidity(lpOut, …)` on reserve hook → receive amounts including a DETF self-leg slice and residual external legs.  
   - **Redeposit** all **DETF returned from remove** into protocol reserve LP (ladder §5.6.1).  
   - **Consolidate residual non-`tokenOut` external legs** into `tokenOut` via hook SE In/Out / weighted exact-in.  
6. **Optional optimization — `withdrawSingle` / single-asset exit:**  
   - Implementors **may** use hook `withdrawSingle(lpOut, tokenOut)` **only if** it is **preview-equal** to the normative path and preserves protocol self-leg depth (redeposit ladder still applies if any DETF residual appears).  
   - **Never** required for DoD. Tests may cover the helper when used; multipath is the conformance path.  
   - **Do not** pay DETF face to the burner via single-asset exit of the DETF leg as primary burn settlement.  
7. Pay **`tokenOut` only**. **Dust policy (LOCKED):** dust of `tokenOut` after settle goes to the user; dust of other pairs that cannot be economically consolidated (below min swap / dust threshold frozen in plan) may remain on the DETF diamond and is **not** a user claim in v1 — document in NatSpec; tests assert no material free inventory of user capital on success paths.  
8. Enforce `minOut`.

#### 5.6.1 Redeposit ladder (LOCKED)

1. **Prefer** hook **`depositSingle(DETF)`** when single-asset eligible.  
2. **Else** multipath / unbalanced join with DETF max and zero other maxes **if the hook accepts** that shape on a live book.  
3. **Else** full tx **reverts** (atomicity: user must not lose burned free DETF without payout).  
4. **Do not** burn returned DETF. **Do not** pay returned DETF to the burner.

**Do not** size burn from creation rate while live.  
**Do not** draw on bond-NFT LP for primary burn.  
**Do not** clear expansion debt on burn.

---

## 6. Fees (two layers — do not conflate)

| Kind | What | Source |
|------|------|--------|
| **A. Reserve weighted trading fee** | Live `dexSwapFeeOfVault(hook)` residual in book | Hook law (dual-channel) |
| **B. Hook protocol growth** | Live `usageFeeOfVault(hook)` LP mint to feeTo on \(k\) growth | Hook law |
| **C. DETF protocol fees** | Usage fee, seigniorage incentive, mint split | Vault Fee Oracle on DETF |
| **D. SE usage fees** | On buffer/mint routes inside each SE (when set) | SE + oracle |

**Bond lock terms (LOCKED, peer):** fee oracle via `DETFBondNFTMathLib` — **revert if lock < min**; **clamp to max** if longer (bonus at max).

**Fee-recipient NFT (LOCKED):** wire fee-recipient bond NFT as peer (claimable free DETF; **no** auto-compound in v1).

---

## 7. Primary mint after live (LOCKED — Q3)

1. **Do not** realize expansion debt / advance `lastExpansionTimestamp`.  
2. Resolve notional from `tokenIn` (WAD); settle to an **external pair leg** \(i\).  
3. **Debt-inclusive** Policy mint gate: `syntheticVs(pair_i)` (§5.5). Open: ungated when live.  
4. Quote gross DETF (boost → `quoteDetfAgainstReserve` → split).  
5. **Deepen protocol LP:** hook **`depositSingle(pairLeg)`** / `joinSingleAssetExactIn`.  
   - After a successful all-external first bond, the reserve is a **full book**; single-asset mint is the **normal** live path (§5.4).  
   - **If not single-asset eligible:** **revert** (`NotSingleAssetEligible` / family equivalent). Treat as exceptional (see §5.4 full-book table) — **not** as “later bonds emptied a leg.” No protocol multi-leg rebalance API in v1 (unnecessary for the designed lifecycle).  
6. Mint free DETF: user / feeTo / inventory → bond vault (if inventory > 0).  
7. **Do not** auto-call `compoundProtocolRewards` on this path if that entry always realizes expansion (v1 peer: keep expansion realize off primary mint).

**Invariant:** live primary mint does **not** require multipath multi-pair deposit; peer is single-sided external-leg join + free DETF mint. Mint quote sizing uses **hook SoT** (§5.3).

---

## 8. Bond lifecycle (LOCKED)

### 8.1 Open (after live; first bond §4)

| Item | Rule |
|------|------|
| Access | Permissionless |
| Capital | **First bond:** **all** external pairs + **explicit** **`capitalToken ∈ pairTokens`** (required even if \(m=1\)). **Later bonds:** **exactly one** external pair (or SE capital settling to that pair). User **never** pays DETF. Multi-external later bonds **revert** (`LaterBondSingleExternalOnly` or family equivalent) |
| **Price / Policy gate** | **None after live.** Bonds deepen LP liquidity. |
| DETF economics | Protocol **mints join-sized DETF** and deposits it with external payment (primary bond benefit) + free fee/inventory/user legs from seigniorage **split** |
| Join | Hook multipath / proportional / unbalanced join (join DETF + funded external maxes); **LP → bond NFT** |
| Expansion debt | **Realize** pending expansion on bond before/with reward update |
| **effectiveShares (LOCKED)** | **DETF-valued principal at open × lock bonus only.** Convert each funded **external** pair notional (after SE settle, WAD) to DETF at **open-time weighted mids** (closed-form exact-in / mid as plan freezes — same fee-aware family as residual settle). Sum converted legs = DETF principal. **Do not** use creation rates for this FX after live. DETF join leg is **not** bond capital and does **not** add to effectiveShares. First bond sums all \(m\) funded externals; later bond has one funded external. |
| claimRewards | Free DETF anytime while open (**realizes** expansion debt) — **not** a principal exit |
| Partial close | **Forbidden** |
| **Pre-maturity principal exit** | **Forbidden** — no early close, no early sell→claim |
| **Sell → rebasing claim** | **Forbidden until maturity** (§8.3) |
| **NFT transfer** | **Allowed** anytime (ERC-721, incl. secondary markets); inherits unlock + **`capitalToken`**. **No** soulbound-while-locked |
| **Capital token metadata (LOCKED)** | On open, record the **single** external pair address used as maturity settlement: first bond = **required** caller `capitalToken` arg; later bond = the sole funded pair (still store explicitly). Notionals optional for analytics. Storage layout is plan-only |

`acceptedBondTokens()`: at least all pair tokens; vault shares for each set SE; tokens from each set SE; not DETF as bond capital (DETF is minted for join).

### 8.2 Maturity (LOCKED)

A bond is **mature** when `block.timestamp >= unlockTime` (lock terms from fee oracle / bond open — peer clamp/revert law unchanged).

**Post-maturity hold:** the NFT may remain unexited **indefinitely**. Maturity only **unlocks** exit options; nothing auto-closes or force-exits.

At maturity the holder chooses **exactly one** full exit (partial still forbidden):

| Exit | API spirit | Result |
|------|------------|--------|
| **Maturity close** | Withdraw principal as the **recorded `capitalToken` only** | §8.2.1 |
| **Sell → rebasing claim** | Convert principal LP into rebasing claim | §8.3 — **only when mature** |

Pre-maturity: **only** `claimRewards` (and remaining lock / free NFT transfer). **No** principal exit of any kind.

#### 8.2.1 Maturity close (full only — single capital token out) — LOCKED

**Bond capital token map (normative):**  
On bond open, store per `tokenId` the **single** external pair address the position will settle into at close. Not DETF. Not hook LP. Not a multi-token basket.

| Open path | Stored `capitalToken` | Maturity close payout |
|-----------|----------------------|------------------------|
| **First bond** (all externals funded) | Caller-chosen pair among `pairTokens` | Prop remove → **redeposit DETF** into protocol LP → **sell all other non-DETF pair legs** into `capitalToken` → pay user **only** `capitalToken` (user accepts impact) |
| **Later bond** (single external) | The sole funded pair | Same structure (often little/no cross-pair consolidate if residual is already mostly that pair) |

1. Require **mature**.  
2. Pay pending rewards.  
3. Bond NFT withdraws **all** position LP.  
4. Proportional / multipath `removeLiquidity` / `exitProportional`.  
5. **Redeposit** all returned DETF self-leg into protocol LP (same redeposit ladder as burn §5.6.1).  
6. Consolidate all non-DETF residual into **`capitalToken`**.  
7. Retire NFT; stop accrual.

**Do not** pay a multi-token residual basket.  
**Do not** default close to an implicit global numeraire — only the recorded `capitalToken`.

### 8.3 Sell → rebasing claim (full only — **post-maturity only**)

**DETF-wide standard (LOCKED):**  
Bond holders **must not** sell their bond for rebasing claim tokens **until the bond has matured**. Pre-maturity `sellPositionToDetfNft` / peer sell path **reverts** (e.g. `BondNotMature` / family equivalent).

**Enforcement vs shared packages (LOCKED):**

1. **Mandatory:** this DETF’s bonding surface **always** checks maturity before any sell→claim or principal migration.  
2. **Shared** `uniswap/v4/common/` bond NFT package **should** accept an optional deploy-time / init **`requireMatureForSell`** (or equivalent).  
3. **CP family** may keep early-sell until its migration PR; shared package must not **force** mature-only on CP until CP opts in.  
4. This family sets the flag **true** (or equivalent) when wiring the shared package. DETF-level check remains even if the flag is missing (defense in depth).

1. Require **mature** (same unlock predicate as §8.2).  
2. Pay pending rewards.  
3. Transfer **hook LP** from bond NFT to **rebasing package** (prefer ERC-20 LP transfer).  
4. Mint rebasing claim from **Δ protocol LP contribution** on a **pro-rata LP basis** (claim shares track protocol LP units — no global numeraire required).  
5. Credit protocol NFT id 0 principal weight if peer ledger requires.  
6. Retire user NFT.

**Fallback if LP transfer blocked:** removeLiquidity → redeposit DETF self-leg → rebasing deposit paths for residual pairs / LP re-mint as plan freezes — still **only when mature**.

### 8.4 Protocol NFT id 0 & fee-recipient

- Protocol NFT id 0: reward ledger weight for inventory seigniorage / expansion; compound §10; no required multi position.  
- **Fee-recipient NFT (LOCKED):** wire as peer (claimable free DETF; no auto-compound v1). If the fee recipient holds a bond position, **same** mature-only principal exit rules apply — no special early-exit privilege.

---

## 9. Rebasing claim (LOCKED)

### 9.1 Package

- **Share** Uni V4 DETF bond NFT + rebasing packages under  
  `detf/protocols/dexes/uniswap/v4/common/` with the CP and Orbital families.  
- Ownable/operable owner = DETF diamond for privileged absorb/donate.  
- Pure Crane deploy (not vault registry).  
- **Holds protocol LP** (LOCK).

### 9.2 Who holds LP

| Holder | LP |
|--------|-----|
| User bond (open) | Bond NFT package |
| Protocol / claim reserve | **Rebasing package** |
| Primary mint joins | Protocol (rebasing) |
| Compound | Protocol (rebasing) |

### 9.3 Mint claim

| Path | Seigniorage DETF mint? | Mechanics |
|------|------------------------|-----------|
| Bond sell (**post-maturity only**) | No | Migrate LP → protocol; mint claim from contribution. Pre-maturity sell **reverts** (§8.3) |
| New money (pair / SE token / share) | **No** | Settle to pair → hook `depositSingle(pair)` when single-asset eligible → LP to protocol → mint claim. **If not single-asset eligible: revert** (user path — not compound skip) |
| Free DETF | **No** | `depositSingle(DETF)` → LP to protocol → mint claim (price impact is user’s; preview includes impact). **If not single-asset eligible: revert** |

Claim shares: SE-style pro-rata of **protocol LP units** contributed (Δ LP vs protocol LP total supply of claim). First depositor inflation guards as peers. Valuation for UX may preview whole-reserve residual in a pair, but mint math is LP-pro-rata.

### 9.4 Redeem claim (LOCKED)

**Apportioning:**

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
// burn claim shares only (not DETF from remove)
// removeLiquidity / exitProportional(lpOut)  [or withdrawSingle helper when cleaner]
// REDEPOSIT all DETF returned from remove into protocol LP (keep self-leg depth)
// residual pairs → consolidate to tokenOut
```

**`tokenOut` options (user chooses unwrap depth):**

| `tokenOut` | Execution |
|------------|-----------|
| Any external pair leg | Multipath remove + **redeposit DETF** + residual consolidate → pay that pair |
| `vaultShare_i` | Only if SE_i set; **prefer clean share path** (leave as SE shares without unwrap→rebuffer round-trip) when residual is already buffered shares or can be obtained without destructive unwrap; unwrap only when needed for the chosen out — **same `lpOut`** |
| Token ∈ SE_i `tokens()` | Only if SE_i set; obtain pair then SE path |
| DETF (`address(this)`) | **`InvalidRoute`** — redeem out is external-only; free DETF is a **deposit into** claim path only |
| Else | **`InvalidRoute`** |

**Optional `withdrawSingle`:** pure optimization — same rules as burn §5.6 step 6.

**Preview == execution** on every closed-form redeem route (incl. maturity close previews when exposed).  
**Never burn DETF withdrawn on claim redeem** — only burn claim shares; redeposit self-leg DETF (same redeposit ladder as §5.6.1).

---

## 10. Protocol compound & natural expansion (LOCKED)

**Same product structure as CP / Orbital UniV4 DETF §10** for epoch expansion form, with **per-route synthetic** and **all-legs-rich** accrual gate (§5.5). Compound rules:

### 10.1 Compound (LOCKED)

| Item | Rule |
|------|------|
| Who | Protocol NFT id 0 pending free DETF only |
| Method | **Single-sided DETF into reserve**: hook `depositSingle(DETF)` when **single-asset eligible** → protocol LP ↑ |
| Claim | **0** new claim shares to protocol |
| Trigger | Lazy on reward-updating touches + public `compoundProtocolRewards()` |
| If not single-asset eligible | **Skip** compounding (do **not** revert). Leave pending DETF for later. Expected to be rare after full first bond (§5.4). |
| Failure (join reverts) | Best-effort on lazy paths; public compound may still surface join failure if eligible but join fails — plan freezes |

**User claim deposit (contrast):** user-initiated claim deposit paths that need `depositSingle` **revert** if not single-asset eligible (hard fail). Do **not** copy compound’s silent skip onto user claim deposit.

### 10.2 Natural expansion — epoch form

Structure matches CP UniV4 DETF peer, with family gate:

- Policy + live only; Open never expands.  
- **Accrue only when `allLegsMintRich`** (§5.5): every external pair has `syntheticVs(pair_k) > mintThreshold`.  
- **Mid-epoch richness flip (LOCKED — v0.4):** credit expansion for an epoch **only if the book is still all-legs mint-rich at epoch end**. If richness fails at the end of the epoch, **that whole epoch accrues 0** expansion (no pro-rate of the hours it was rich; no “snapshot only at realize” shortcut that ignores epoch-end). Catch-up of prior whole epochs still respects `expansionMaxCatchUpEpochs` and each such epoch’s end-of-epoch all-rich check.  
- Deploy-time `expansionEpochLength`, `expansionClosureRatePerYearWad`, `expansionMaxCatchUpEpochs`.  
- Resolve defaults: epoch `0` → **8 hours**; `R == 0` → **0.10e18**; `maxCatchUpEpochs == 0` → unlimited.  
- Pending debt always in **each** per-route synthetic denominator.  
- Realize **only** on bond / claimRewards / compound / bond reward updates.  
- Premium-closure O(1) formula: for expansion **size**, use a frozen scalar from the book — **LOCKED default:** min over \(k\) of `S_spot_k` (most conservative leg) so expansion does not outrun the thinnest mint-rich leg; alternative max/avg is **out** for v1. Gates still require all legs mint-rich (epoch-end rule above) before any accrual for that epoch.

**Gas:** all-legs check is O(\(m\)) pure math after one whole-reserve residual preview — acceptable for \(m \le 7\) on bond/claim/compound paths (§5.5). Prefer hook reads/previews where available.

Reference tables for launch-rich `R` sizing: **copy CP UniV4 DETF §10.3–§10.4** (do not re-derive ad hoc), interpreting richness via per-route whole-reserve synthetics + all-legs + epoch-end gate.

---

## 11. Deploy & PkgArgs (LOCKED)

Typed surface: `IUniswapV4StandardExchangeWeightedDETDFPkg.deployVault(PkgArgs args, uint256 mineNonce)`. The nonce is **not** a PkgArgs field. Caller premines via `UniswapV4DetfHookPremineLib`. Deploy arity SoT: [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](../UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md).

### 11.1 Deploy sequence (postDeploy spirit)

1. Deploy DETF diamond via vault registry (inert).  
2. From **`PkgArgs`**, deploy reserve Weighted SE Buffer Hook via registry `deployHookVault`:  
   - \(n\) tokens (DETF + \(m\) pairs in **address-ascending** binding order)  
   - weight vector (sum \(1\mathrm{e}18\), each \(\ge 1\%\))  
   - SE slots (≥1 non-zero on external legs only; DETF SE must be 0)  
   - optional rate providers (only with SE; shares → that leg’s pairToken)  
   - poolManager, feeOracle, mineNonce / salt fields  
3. Hook **postDeploy** does **not** init doors. Callers open all \(\binom{n}{2}\) product pairs on `IUniswapV4HookStagedPairInit` (`productTokensWeighted`, one TX each), then finalize. Then `completeReserveBondNft` + `completeReserveClaim` on this `I*DETF`. TestBase `setUp` may use `ensureReserveReadyWeighted`. SoT: staged-init PRD.  
4. Deploy **shared** bond NFT + rebasing packages (owner=DETF); rebasing is protocol LP holder.  
5. Store creation rates (length \(m\)), weights (or re-read from hook), thresholds, mode, expansion params, DETF binding index.  
6. Validate: pairs distinct; DETF raw only; pair ∈ SE tokens when SE set; SEs distinct when multiple; RP only with SE; **≥1 SE set** (reject all-external-bare); **all creation rates `> 0`**; weights valid; no FoT/rebasing pairs; \(n \in [2,8]\).  
7. **No** `rateAsset` field to validate.

### 11.2 PkgArgs (normative)

| Field | Notes |
|-------|--------|
| `pairTokens[]` | \(m \in [1,7]\) external ERC-20s; pairwise distinct; ≠ DETF; **not** FoT/rebasing; with DETF form address-sorted \(n\)-token binding |
| `weights[]` | Length \(n = m+1\); **hook binding-order** aligned; \(\sum = 1\mathrm{e}18\); each \(\ge 0.01\mathrm{e}18\) (**Q6**) |
| `standardExchanges[]` | Length \(n\); DETF index **must be** `address(0)`; external slots `address(0)` = bare; non-zero SEs distinct; **require ≥1 non-zero on an external index** (**Q5**) |
| `rateProviders[]` | Length \(n\); optional; non-zero only if corresponding SE set; **must** rate shares → that leg’s pairToken |
| `detfBindingIndex` or equivalent | Which hook index is DETF raw self-leg — determined by DETF address once known; free among \(n\) indices subject to sort (**Q5**) |
| `poolManager` | Uni V4 PoolManager |
| `creationPairPerDetfWad[]` | Length \(m\); first-bond seed rates (WAD); **each `> 0`** or deploy reverts (**Q6**) |
| `thresholdMode`, mint/burn thresholds | Shared policy resolve |
| `expansionEpochLength` | Seconds; `0` → 8 hours |
| `expansionClosureRatePerYearWad` | Premium closed per year; `0` → 10%/yr gentle |
| `expansionMaxCatchUpEpochs` | `0` = unlimited |
| Bond NFT / rebasing package refs | Shared common package wiring; **`requireMatureForSell = true`** (or equivalent) for this family |
| Hook salt / mineNonce / product binding | Passed through to hook package |
| Fee oracle | Manager / vault wiring |

**Not used:** listing TWAP seconds; CL width; monomorph CREATE3 hook factory as primary path; sphere-specific params; **`rateAsset` / external synthetic numeraire**.

---

## 12. Public surface (normative groups)

| Group | Examples |
|-------|----------|
| **Info** | `isReserveLive`, `syntheticPrice(pair)` / `syntheticVs(pair)` (**debt-inclusive per-route whole-reserve FD**), optional spot variant, `isMintingAllowed(pair)` / `isBurningAllowed(pair)`, optional `isAllLegsMintRich()`, `pendingExpansionDetf`, thresholds, creation rates, pairs, SEs, RPs, weights, \(n\)/\(m\), DETF binding index, reserve hook, expansion getters (**no** whole-DETF `rateAsset()`) |
| **Exchange in** | Mint DETF from any pair / share / SE token (pair face OK on buffered legs); burn free DETF→`tokenOut` ∈ pair legs (+ SE unwrap); **not** to DETF |
| **Bond** | `bond` (first: all externals + **required** `capitalToken`; later: single external, no DETF payment); maturity close; `sellPositionToDetfNft` (**mature only**); `claimRewards`; `acceptedBondTokens` |
| **Claim** | Direct deposit paths; redeem claim with `tokenOut` matrix §9.4 (**DETF out InvalidRoute**) |
| **Compound / expansion** | `compoundProtocolRewards` (skip if not single-asset eligible); lazy update on touches; expansion accrual only if all-legs mint-rich |
| **Previews (LOCKED)** | Every closed-form execution path exposes a view preview with **preview == execution** (≤ few-wei only if SE multi-leg dust forces it; document): mint, burn, bond, claim deposit/redeem, maturity close, sell→claim contribution |
| **Errors (stable family)** | `InvalidRoute`; mint/burn not allowed (per-route); reserve not live; lock too short; **`BondNotMature`** (sell/close); min out; **`FirstBondRequiresAllExternalPairs`**; **`LaterBondSingleExternalOnly`**; **`NotSingleAssetEligible`** (primary mint); **`ProtocolLpEmpty`** / insufficient protocol LP (burn); invalid `capitalToken`; redeposit failure surfaces as full revert (no partial success) |

Exact selector layout follows Crane facet split (Info / In / Out / Bonding / …) in impl plan.

---

## 13. Package layout

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/
    weighted/
      UniswapV4StandardExchangeWeightedDETF_PRD.md          # this file (internal law)
      UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # implementor SoT (v1.0)
      UniswapV4StandardExchangeWeightedDETFDFPkg.sol
      UniswapV4StandardExchangeWeightedDETFRepo.sol
      UniswapV4StandardExchangeWeightedDETFCommon.sol
      … Facets / Targets / FactoryService / TestBase
    orbital/                  # peer multi-leg UniV4 DETF — do not subclass
    constantProduct/single/   # peer CP DETF family — do not subclass
  common/
    nft/      # Uni V4 DETF bond NFT (LP principal) — SHARED
    rebasing/ # claim on protocol hook LP — SHARED
```

**Fresh codepath rule:** do not subclass CP / Orbital UniV4 DETF or Balancer Single SE contracts; reuse `detf/common/core/*` libs and shared Uni V4 common packages.

---

## 14. Canonical flows

1. **Deploy** — weights, creation rates, Policy/Open, ≥1 SE + optional RPs via PkgArgs → weighted SE buffer hook + all doors, shared bond + rebasing. **No whole-DETF rateAsset field** (per-leg RPs only).  
2. **First bond (live)** — permissionless; **all external pairs required**; **required** `capitalToken`; mint join DETF at creation rates; multipath/proportional join; **refund excess** external capital; **full book** post-condition; LP on NFT; live=true.  
3. **Second+ bonds** — market quote (hook SoT); **no** synthetic mint gate; **single external payment only** (never user DETF); protocol mints join DETF; **adds** liquidity (does not remove other legs); `capitalToken` = that pair; LP on NFT; realize expansion + rewards.  
4. **Primary mint** — any pair (face OK if buffered) → free DETF + protocol LP single-asset join (normal after full first bond); **per-route** Policy gate `syntheticVs(pair_i)` on **whole-reserve** FD; does **not** realize expansion.  
5. **Primary burn** — burn **user free DETF only** when `syntheticVs(tokenOut)` under peg → multipath remove (normative) → **redeposit returned DETF** → residual consolidate → chosen pair.  
6. **Maturity close** — after unlock (optional forever): withdraw LP; redeposit DETF; pay recorded **single `capitalToken`**.  
7. **Sell bond → claim** — **only after maturity**: LP to protocol; mint claim LP-pro-rata. Pre-maturity sell **and** early close revert.  
8. **Direct claim** — pair/SE or free DETF via depositSingle; no seigniorage; **revert** if not single-asset eligible.  
9. **Redeem claim** — burn claim shares; remove LP; **redeposit DETF**; pay pair / share / SE token (**not DETF**).  
10. **Compound / expansion** — §10; expansion accrues for an epoch only if **all legs mint-rich at epoch end**; skip compound if not single-asset eligible (user claim deposit reverts).  
11. **External swap** — public V4 doors via weighted SE buffer hook (does not zero full-book legs under hook law / curve asymptotics).

---

## 15. Testing expectations

1. Deploy inert; primary mint reverts; non-first bond reverts.  
2. Permissionless first bond at creation rates → live; **all external pairs required** (missing any external reverts); caller must pass valid `capitalToken`; mids ≈ creation; MINIMUM_LIQUIDITY edge; **excess capital refunded**; post-join **full book** (all legs \(> 0\)).  
3. After first bond only: primary burn reverts (protocol LP empty) until mint/sell/compound — **not** because a pair leg was zeroed.  
4. Second bond allowed when live without synthetic gate; **single-pair bond succeeds** and **increases** that leg (+ DETF join); multi-pair later bond reverts; user DETF as bond capital reverts; primary mint **per-route** Policy-gated; Open ungated for primary.  
5. Per-route synthetic: **whole-reserve** FD residual → **pair_k** + creation scale; mint open for pair A while closed for pair B (skew row via trades/seigniorage, not “empty leg”); burn gate on tokenOut; first bond ungated; **no** whole-DETF rateAsset field.  
6. Preview == execution mint/bond/burn/claim/maturity close/sell→claim contribution; mint/bond quotes **match hook** previews (hook SoT).  
7. Seigniorage split matches peer ratios for same oracle fees; burn applies usage fee.  
8. Bond LP on NFT; claimRewards free DETF while locked; pre-maturity **any** principal exit reverts; NFT transferable mid-lock; post-maturity close pays **only `capitalToken`** **or** sell→claim; mature hold indefinite; first-bond **required** capitalToken even when \(m=1\).  
9. Claim redeem: any pair, vaultShare (if SE; prefer clean share path), SE token; **DETF out reverts**; **returned DETF redeposited**. Claim **deposit** reverts if not single-asset eligible (unlike compound skip).  
10. Primary burn: only user free DETF burned; returned DETF redeposited (ladder); invalid `tokenOut` → `InvalidRoute`; multipath is conformance path.  
11. Protocol compound increases protocol LP when single-asset eligible; **skips without revert** when not.  
12. Natural expansion Policy: accrues for a completed epoch **only if allLegsMintRich at epoch end**; Open never; dual expansion TestBase rows; gas-bounded \(n=8\) all-legs check on realize path; mid-epoch “was rich then not” → **0 for that epoch**.  
13. Decimal scaling: 6-decimal + 18-decimal pairs.  
14. Real weighted SE buffer hook package + real SEs; hermetic + fork smoke; no SUT mocks.  
15. Config matrix: **\(n \in \{2,3,4,8\}\)** priority (**n=2 first-class**); **1 SE + bare rest**, **all external SE** (both required in DoD for at least one \(n \ge 3\)); **reject all-external-bare** at deploy; RP on/off for ≥1 buffered config; reject same SE twice; reject RP without SE; reject DETF in SE tokens; reject any creation rate 0; reject invalid weights.  
16. Price movement under **default** thresholds via real reserve trades + seigniorage dilution (skew gates without requiring zero inventory).  
17. Nested reentrancy → `IsLocked`.  
18. Residual free inventory zero on success paths where peers require it (dust policy documented).  
19. All V4 doors swap after live (at least one row for each priority \(n\); n=8 smoke acceptable if gas-heavy); swaps leave full-book floors intact (hook).  
20. Primary mint via `depositSingle` each external pair leg after full first bond; **no** DoD row that requires “later bond zeros a leg.”  
21. Free DETF binding order: at least one TestBase row with DETF not at binding index 0.  
22. `effectiveShares`: first bond multi-leg DETF valuation at open-time mids; later bond single-leg DETF valuation (not creation rates).  
23. Weight sensitivity: unequal weights (e.g. DETF 40%, rest split) covered; equal weights optional row; unequal does not require exact creation mid equality; first-bond refund under unequal weights.  
24. First-bond `capitalToken` invalid (not a pairToken) reverts; capitalToken always required; maturity close always single token.  
25. Pair-face mint on buffered leg succeeds (host buffers).  
26. Expansion: epoch accrues only if still all-legs mint-rich **at epoch end**; fails if any leg not mint-rich at end.

---

## 16. Differences vs peers

| | UniV4 CP SE DETF | UniV4 Orbital SE DETF | **This family** |
|--|------------------|------------------------|-----------------|
| Reserve | **CP buffer hook + LP** (2 currencies) | **Orbital SE buffer hook + LP** (3 currencies) | **Weighted SE buffer hook + LP** (\(n \in [2,8]\)) |
| External legs | **One** pairToken | **Two** pairs; **1–2 SEs** (≥1 required) | **\(m \in [1,7]\)** pairs; **1…m SEs** (≥1 required; bare OK) |
| Curve | Constant product | Sphere (orbital) | **Balancer weighted** |
| Self-leg | DETF raw leg | DETF raw leg (any of 3) | **DETF raw leg** (any of \(n\)) |
| Weights | Implicit 50/50 CP | Sphere (no weight vector) | **Deploy-time weight vector** |
| Synthetic ruler | FD LP → pair / creation | FD LP → **rateAsset** (remove + residual incl. DETF) | **Per-route whole-reserve FD → pair_k / creation_k**; mint/burn use path pair; **no whole-DETF rateAsset field** |
| Principal | Hook LP | Hook LP (shared packages) | **Hook LP** (shared packages) |
| Live | Permissionless first bond | Permissionless first bond (**both** pairs) | **Permissionless first bond (all externals) + required capitalToken** |
| Later bonds | No synthetic gate | No synthetic gate; single-leg OK | **No synthetic gate; single external payment; protocol mints join DETF** |
| Expansion realize | Bond / claim / compound only | Same | **Same** |
| Expansion accrue gate | Policy + mint-allowed synthetic | Same | **Policy + all external legs mint-rich at epoch end** |
| Init price | `creationPairPerDetfWad` | `creationPair0/1PerDetfWad` | **`creationPairPerDetfWad[i]`** (length \(m\)) |
| Live primary mint | Pair zap-in | Either pair **depositSingle**; revert if not zap-eligible | **Any pair depositSingle**; **revert if not single-asset eligible** |
| Primary burn out | pairToken via hook zap-out | Multipath remove + residual; redeposit DETF | **Multipath normative + residual; redeposit DETF; withdrawSingle optimization only** |
| One-token LP model | CP-style zap | Orbital multi-leg zap-in; **no** hook zap-out v1 | **Balancer single-asset aliases** (hook has both entry and exit) |
| Public market | Uni V4 + CP hook (1 pool) | Uni V4 + orbital (3 doors) | **Uni V4 + weighted ( \(\binom{n}{2}\) doors )** |
| Sell→claim gate | Peer may allow early sell (transitional) | **Mature only** (first adopter) | **Mature only** (same DETF-wide standard) |
| Maturity close | Capital / pair | Capital token(s); dual = residual basket | **Always single `capitalToken` recorded at open** |

---

## 17. Dependencies & sequencing

| Order | Work |
|-------|------|
| 1 | Weighted SE Buffer Hook PRD + implementation plan + **frozen ABI** (or DoD green) — **hard coding gate** |
| 2 | This DETF PRD → **product LOCK** after sign-off (**independent** of hook LOCK; coding still waits on step 1) |
| 3 | DETF implementation plan ([`…_IMPLEMENTATION_AND_TEST_PLAN.md`](./UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md) **v1.0**) |
| 4 | Shared bond NFT + rebasing packages for **LP principal** (CP / Orbital co-ownership) |
| 5 | DETF DFPkg + tests |

**Hard gate:** DETF package coding **must not** invent hook APIs — only call surfaces from the Weighted SE Buffer Hook PRD / frozen ABI.

**LOCK independence:** product may stamp this PRD **LOCKED** once product/protocol sign-off. That does **not** authorize coding before the hook ABI is frozen.

---

## 18. Definition of Done (product)

- [ ] Inert deploy; live only via permissionless first bond with **all** external pairs + chosen `capitalToken`  
- [ ] Creation-rate first bond (all rates `> 0`); mids ≈ creation at join; MINIMUM_LIQUIDITY handled; weights enforced; unequal weights covered without exact mid equality; **excess capital refunded**; **full book** after first bond  
- [ ] Live mint (any external pair) / bond seigniorage split peer-compatible; preview == execution; **hook SoT** for mint/bond quotes  
- [ ] Primary mint normal after full first bond; `NotSingleAssetEligible` is exceptional; later one-pair bonds **add** liquidity only  
- [ ] Primary burn burns only user free DETF; usage fee applied; redeposits DETF from remove (ladder); multipath is conformance path  
- [ ] Claim redeem redeposits DETF from remove; tokenOut matrix; InvalidRoute elsewhere; claim **deposit** reverts if not single-asset eligible  
- [ ] Sell→claim and maturity close **revert pre-maturity**; succeed post-maturity; close pays **single capitalToken** only; NFT transfer preserves metadata  
- [ ] Later bonds **single external only**; first bond all-external required; multi-leg later bond reverts; `effectiveShares` via open-time DETF valuation  
- [ ] Compound skips when not single-asset eligible (no revert); user claim deposit does **not** skip  
- [ ] Policy/Open **per-route** debt-inclusive synthetic (**whole-reserve** FD residual → route pair / creation); mint/burn gates route-coupled; expansion accrues for an epoch only if **all legs mint-rich at epoch end**; realize only bond/claim/compound; **no whole-DETF rateAsset field**  
- [ ] Claim redeem rejects `tokenOut = DETF`; capitalToken always required on first bond; pair-face mint on buffered legs  
- [ ] PkgArgs deploys hook with \(n \in [2,8]\), weights, ≥1 SE + optional RPs + free DETF binding; all-external-bare reverts  
- [ ] Shared common bond/rebasing packages; mature-only DETF gate + shared flag true for this family  
- [ ] Production-first tests §15 green (hermetic + at least one fork profile)  

---

## 19. Threat notes (product-level)

| Risk | Stance |
|------|--------|
| Permissionless first bond sniping / dust | No MEV protection v1; MINIMUM_LIQUIDITY revert; operators choose seed size |
| Donation of raw DETF or SE shares to hook | Whole-reserve FD uses full extractable residual in the route pair; native LP domain ignores claim/RP drift for ownership (hook law) — donations dilute LPs / market residual; document dilution |
| Primary burn insolvency | Protocol-LP-only for burn LP basis; revert if empty (first-bond LP may sit on NFT — intentional) |
| Residual settle impact on burn / close | User accepts weighted impact consolidating other pairs → `tokenOut` / `capitalToken`; previews must include it |
| Redeposit path failure on burn/claim | Full tx reverts after redeposit ladder exhausted |
| Expansion catch-up cliff | Debt-inclusive synthetic; optional maxCatchUpEpochs; high R intentional for launch-rich; **epoch-end all-rich** only |
| Reentrancy via ERC-20 / SE / hook | Family diamond `nonReentrant` / `IsLocked` peer patterns |
| Fee stacking | Documented multi-layer fees (weighted swap + hook growth + DETF usage + SE); burn usage fee intentional |
| “Partial book after later bonds / swaps” | **Rejected product myth.** Curve swaps do not fully drain legs; hook full-book exits cannot zero a leg; later bonds **add** liquidity; first bond forces full book. Do not design operator runbooks around routine zero-leg mint blocks. |
| High door count (\(n=8\) → 28 pools) | Gas / test cost accepted; DoD requires n=8 hermetic row (smoke OK if heavy) |
| Unequal weight + creation-rate seed | Operators choose amount ratios; surplus refunded; no exact mid guarantee; tests cover unequal weights + refund |
| Early sell→claim (pre-maturity) | **Forbidden**; DETF gate + optional shared flag |
| First-bond multi-fund, single close | Holder chose `capitalToken` at open; takes consolidate impact of other pairs at close |
| Shared package early-sell drift | DETF-level maturity check is mandatory even if shared flag missing or CP still early-sell |
| Confusing “zap” vocabulary | Prefer **single-asset eligible** / `depositSingle` / `withdrawSingle` per hook; multi-leg force-rebalance **out** |
| Confusing peer / AGENTS `rateAsset` | This family has **no whole-DETF rateAsset field**; mint/burn use **route pair** unit; per-leg RP is shares→pair only — do not copy single-numeraire gates from CP/Orbital or generic AGENTS table |
| Divergent mint math | **Forbidden** — DETF must use **hook SoT** for seigniorage/join impact quotes |
| All-legs expansion gas | \(m\le7\); one whole-reserve residual preview + pure math loop; fail-fast; RP external calls are the real cost — freeze domain with hook |
| Per-route skew | Intentional that one pair can be mint-open and another mint-closed (book shape / trades — not empty inventory) |

---

## 20. Clarification lock table (resolved)

| ID | Topic | Locked value |
|----|--------|--------------|
| **Q1** | Reserve size | **Full \(n \in [2,8]\)** (DETF + \(m \in [1,7]\) external pairs). Includes \(n=2\) as **first-class** product (weighted host ≠ CP) |
| **Q2** | First bond capital | **All external pair legs required** + caller-chosen **single `capitalToken`** |
| **Q3** | Primary mint routes | **Any single external pair** via `depositSingle` / `joinSingleAssetExactIn` when **single-asset eligible**; revert if not. SE share / SE-token capital rates into that pair |
| **Q4** | Primary burn | **Multipath/proportional remove is normative** + redeposit DETF + residual consolidate; **`withdrawSingle` pure optimization** when preview-equal / depth OK — not required for DoD |
| **Q5** | DETF + SE shape | **DETF raw only**; each external optional bare or SE-buffered; **≥1 SE** on some external; free DETF binding among \(n\); non-zero SEs distinct; all-external-bare reverts |
| **Q6** | Creation rates / weights | **Per-external creation rate** each `> 0`; **deploy-time weight vector** including DETF, sum \(1\mathrm{e}18\), each \(\ge 1\%\). Operators own first-bond amount ratios under unequal weights |
| **Q7** | Synthetic / FD ruler | **Per-route `syntheticVs(pair_k)`** on **whole-reserve** FD residual consolidated to pair \(k\), scaled by creation \(k\). Market richness (not holder-sliced). Mint uses funded pair; burn uses `tokenOut`. **No whole-DETF `rateAsset` field** |
| **Q8** | Later bonds | **Exactly one external pair payment**; user never pays DETF; protocol mints join DETF. Multi-leg later bonds revert. Bonds **add** liquidity only |
| **Q9** | Maturity close | **Always single `capitalToken`** recorded at open (first bond: **required** arg even if \(m=1\); later: funded pair). No residual multi-token basket |
| **Q10** | Expansion richness | Accrue only when **all** external legs are mint-rich; **whole epoch only if still all-rich at epoch end**. Gas-OK at \(n\le8\). Expansion size scalar: **min** of `S_spot_k` |
| **Q11** | First-bond excess capital | **Refund** surplus external capital beyond creation-price join sizing |
| **Q12** | Mint quote SoT | **Hook is source of truth** — no DETF-side WeightedMath reimplementation for seigniorage/join impact |
| **Q13** | Full book lifecycle | First bond → full book; curve + hook floors prevent normal zero-leg drain; later bonds do not zero sibling legs |
| **Q14** | Claim deposit vs compound | User claim deposit **reverts** if not single-asset eligible; compound **skips** |

### 20.1 Inherited locks (from Orbital / CP UniV4 DETF peers — restated; family deltas noted)

| ID | Topic | Locked value |
|----|--------|--------------|
| **H1** | Returned DETF from remove | **Never burn.** Redeposit for protocol self-leg depth on burn and claim redeem |
| **H2** | Later bonds | **Allowed** without synthetic mint gate; **this family: single external only** (stricter than Orbital “any subset”); **adds** LP only |
| **H3** | Compound when not eligible | **Skip; do not revert** |
| **H4** | Rate providers | Optional when SE set; DoD includes RP on/off rows; RP = shares → **pairToken** only (not whole-DETF rateAsset) |
| **H5** | Bond NFT + rebasing | **Share** Uni V4 `common/` packages with CP + Orbital |
| **H6** | LP valuation for FD | **Whole-reserve** residual + **full residual → route pair_k** for `syntheticVs` / mint-burn gates (market, not holder subset) |
| **H7** | Sell bond → rebasing claim | **Only after maturity.** Pre-maturity sell reverts |
| **H8** | Maturity close tokenOut | **Single `capitalToken` recorded per NFT at open** |
| **H9** | Pre-maturity principal exit | **None** — only `claimRewards` |
| **H10** | Mint / bond capital rating | Capital **always rated into the funded pair-leg units**. SE vault shares **always** rate→pair (RP or claim). **No** forced convert via another pair mid |
| **H11** | Post-maturity hold | **Indefinite** — exit optional forever |
| **H12** | Bond NFT transfer | **Free ERC-721** anytime; inherits lock + capital metadata |
| **H13** | Bond `effectiveShares` | Sum of funded external pair notionals **converted to DETF at open-time weighted mids** × lock bonus. DETF join leg excluded. (Reward weight only — not Policy synthetic unit.) |
| **H14** | Mature-only vs shared packages | **DETF surface always gates.** Shared package optional `requireMatureForSell` (this family sets true) |
| **H15** | Multi-capital residual basket close | **Out for this family.** Close is always single `capitalToken` |
| **H16** | FD self-leg / residual | **Include DETF self-leg and all other pairs** when consolidating whole-reserve residual → route pair_k. Redeposit is execution depth only |
| **H17** | `quoteDetfAgainstReserve` | Economic identity: fee-aware inverse of single-sided pair capital vs live book; **implementation: hook SoT only** — no DETF curve reimplementation |
| **H18** | Burn usage fee | **Yes** — oracle peer path; no mint-style inventory split on burn |
| **H19** | Redeposit ladder | Prefer `depositSingle(DETF)`; else multipath DETF-only max if hook accepts; else full revert |
| **H20** | Full book / single-asset | First bond establishes full book; normal mint/compound assume full book; zero-leg partial book is **not** a designed after-live state for this family; no protocol rebalance API needed for that myth |
| **H21** | Expansion epoch boundary | **Whole epoch accrues only if all-legs mint-rich at epoch end** (no mid-epoch pro-rate) |
| **H22** | First-bond refund | Excess external capital beyond creation-price join sizing **refunded** to bonder |
| **H23** | User claim deposit eligibility | **Revert** if not single-asset eligible (contrast H3 compound skip) |

**Plan-only remaining (not product forks):** bond NFT storage layout/slots for `capitalToken`; atomic order of burn-then-remove-then-redeposit; which **hook selectors/previews** implement `quoteDetfAgainstReserve` and whole-reserve residual; residual weighted-sell path order when pure math is required; multipath amount array order for free DETF index; dust thresholds; exact shared-package flag name/ABI; whether implementor ships `withdrawSingle` optimization; catch-up loop details under H21 (must still honor epoch-end all-rich per epoch).

---

## 21. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-05 | First draft: Orbital / CP UniV4 DETF economics + Weighted SE Buffer Hook reserve. Locked Q1–Q6: full \(n\in[2,8]\); first bond all externals; single-asset primary mint; multipath burn + optional withdrawSingle helper; DETF raw + ≥1 SE + free binding; per-external creation rates + rateAsset default + deploy-time weights |
| **v0.2** | 2026-08-05 | Quality / co-design review: remove global rateAsset; later bonds single-external; first bond capitalToken; multipath burn normative; \(n=2\) first-class |
| **v0.3** | 2026-08-05 | **Per-route synthetic** (`syntheticVs(pair)` via FD residual → pair / creation); mint/burn gates use tokenIn/tokenOut pair; **all-legs-rich** expansion (min \(S_{spot}\)); gas stance for \(m\le7\); claim redeem DETF InvalidRoute; capitalToken always required; bond payment never DETF; pair-face mint on buffered legs; claim mint LP-pro-rata |
| **v0.4** | 2026-08-05 | Review locks: **whole-reserve** FD (market richness); first-bond **excess refund** + full-book post-condition; **hook SoT** mint quotes; expansion **epoch-end** all-rich only; claim deposit **reverts** if not eligible vs compound skip; **correct partial-book myth** (swaps/later bonds do not zero full-book legs under curve + hook floors); AGENTS whole-DETF rateAsset override restated; Q11–Q14 / H20–H23 |

---

## 22. Approval

| Role | Sign-off |
|------|----------|
| Product | Pending — v0.4 review locks closed; ready for LOCK pass |
| Protocol | Pending |

**Status DRAFT v0.4 — co-design Q1–Q14 + H1–H23 locked; ready for product LOCK after sign-off; coding still gated on Weighted SE Buffer Hook frozen ABI; then implementation plan.**
