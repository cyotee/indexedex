# Product Requirements Document (PRD)

## Title

**UniswapV4StandardExchangeCurveQuadStableDETF** — true DETF with Uniswap V4 **Standard Exchange Curve Quad Stable Buffer** reserve

## Status

**LOCKED v0.4** — co-design Q1–Q23 closed (2026-08-12). Product LOCK stamped 2026-08-12. Implementation plan authorized.

**How Qs closed:** Two AskQuestion rounds. Round 1 (Q1–Q17): per-route + all-legs-rich; prop-remove only; close = purchase token; exact-out iff closed-form; path `stable/quad/curve/`; like-kind only. Round 2 (Q18–Q23): first-bond close = pick one of three funded pairs; exact DETF-out mint + exact tokenOut burn; exact-out still prop-remove + redeposit; expansion uses **min S_spot_k**; like-kind is operator convention; claim redeem full matrix.

| Related | Role |
|---------|------|
| **This family impl plan** | [`UniswapV4StandardExchangeCurveQuadStableDETF_IMPLEMENTATION_AND_TEST_PLAN.md`](./UniswapV4StandardExchangeCurveQuadStableDETF_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Reserve hook (mandatory dependency)** | [`UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_PRD.md`](../../../../../../../../../../hooks/uniswap/v4/standardExchange/stable/quad/curve/UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_PRD.md) (**LOCKED v0.2**) |
| **Hook ABI (frozen surface)** | [`IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol`](../../../../../../../../../../hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol) |
| **Behavioral DETF peer (primary process)** | [`UniswapV4StandardExchangeOrbitalDETF_PRD.md`](../../../orbital/UniswapV4StandardExchangeOrbitalDETF_PRD.md) — multi-external seigniorage, first bond, bond/claim, mature-only sell, compound |
| **Behavioral DETF peer (n>2 host + hook surface)** | [`UniswapV4StandardExchangeWeightedDETF_PRD.md`](../../../weighted/UniswapV4StandardExchangeWeightedDETF_PRD.md) — per-route synthetic, all-legs-rich expansion, later-bond single-external, hook-SoT quotes |
| **Behavioral DETF peer (economics)** | [`UniswapV4SingleStandardExchangeDETF_PRD.md`](../../../constantProduct/single/UniswapV4SingleStandardExchangeDETF_PRD.md) — seigniorage split, epoch expansion, threshold Policy/Open |
| **Shared core** | `detf/common/core/*` (`DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFBondNFTMathLib`, expansion/compound helpers) |
| **Shared compound / expansion law** | `docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` (this family **in scope** once LOCKED; epoch form + debt-inclusive synthetic) |
| **Shared Uni V4 DETF packages** | `detf/protocols/dexes/uniswap/v4/common/` — bond NFT + rebasing (LP principal); **share with CP + Orbital + Weighted** |
| **AGENTS.md / agent law** | DETF families — common expectations; product docs co-located with code. Families table must gain this row at LOCK |
| **Skill** | `indexedex-uniswap-v4-hook-packages` (hook package deploy); `indexedex-testing` (DETF tests) |

**Short name:** UniV4 SE Curve Quad Stable DETF (quad StableSwap buffer reserve family).

**Package path (LOCKED Q16):**  
`contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/`

Matches the reserve hook tree (`hooks/…/stable/quad/curve/`). The hook is **exactly n=4**. This DETF family is the **n=4 StableSwap** consumer. Dual / triple StableSwap DETFs, if ever wanted, are **separate PRDs**.

**Do not conflate with:**

| Package | Role |
|---------|------|
| `UniswapV4SingleStandardExchangeDETF` | Same true-DETF spirit; **2-leg CP** reserve (DETF raw × one pair) |
| `UniswapV4StandardExchangeOrbitalDETF` | Same true-DETF spirit; **3-leg orbital sphere** (DETF + 2 pairs); hook has **zap-in, no zap-out** |
| `UniswapV4StandardExchangeWeightedDETF` | Same true-DETF spirit; **n∈[2,8] weighted** book (distinct valuations, per-route synthetic) |
| Raw `UniswapV4CurveQuadStableSwapHook` | No SE buffering — not a DETF reserve host for this family |
| `UniswapV4StandardExchangeCurveQuadStableBufferHook` | Reserve host only — not a DETF / seigniorage product |
| Balancer composed-stable / mixed-buffer | Multi-SE valuation on Balancer hosts — different reserve topology |

---

## 0. Intent

### 0.1 Why this family

The UniV4 Single SE CP DETF lists **DETF ↔ one pairToken** under a constant-product buffer hook. The Orbital DETF lists DETF against **exactly two** external underlyings on a **sphere**. The Weighted DETF lists DETF against **1–7** underlyings that must keep **distinct** valuations.

Product goal for **this** family:

1. **List DETF against three like-kind external underlyings** on Uniswap V4 under a **4-asset StableSwap** book (six doors, one room, amplification \(A\)).
2. **Optionally buffer each external leg** into a Standard Exchange (yield-aware claim / optional rate provider) — **1–3 SE vaults**; a leg may also be a **bare ERC-20**. **≥1 SE required** so this family is always a true *Standard Exchange* Curve Quad Stable DETF. All-external-bare is **out of scope** for v1.
3. Keep true-DETF law: diamond is the share ERC-20; seigniorage vs a reserve that includes a **DETF self-leg**; bond principal = **fungible hook LP**; rebasing claim on protocol-owned LP.
4. Start the reserve at **deploy-time multi-leg creation rates** (may seed rich / off peg) with a **deploy-time immutable** hook amplification \(A\).
5. Reuse CP / Orbital family **epoch expansion + debt-inclusive synthetic**, with the synthetic ruler **LOCKED** as Weighted-style **per-route** `syntheticVs(pair_k)` (mint/burn vs the path’s pair). Natural expansion accrues only when **all three** external pairs are mint-rich at epoch end (**Q5 / Q6**). **No** whole-DETF deploy-time `rateAsset` field.
6. Price and settle using the **StableSwap curve itself** via **hook source of truth** (rated mids, single-asset impact, proportional / unbalanced residual) rather than an off-book FX ledger or a DETF-side StableSwap reimplementation.

The reserve host is:

**`UniswapV4StandardExchangeCurveQuadStableBufferHook`**

- Pool currencies: **exactly four** ERC-20s in **strict address-ascending** binding order (hook D9)
- **DETF binding (LOCKED):**
  - Exactly **one** leg is the **DETF self-leg**: raw only (`standardExchange = 0`, no rate provider on that leg).
  - The other **three** legs are **external pair tokens** (`pairToken0`, `pairToken1`, `pairToken2` in product naming — not necessarily consecutive binding indices).
  - Each external leg: **optional** SE (`address(0)` ⇒ bare raw token inventory) + **optional** rate provider **only if** SE is set.
  - **At least one** of the three external legs **must** have a non-zero SE. All-external-bare **reverts** at deploy.
  - Non-zero SE addresses **pairwise distinct** (hook D5b).
  - **Free binding order:** DETF may occupy any of the four address-sorted indices as the unique raw self-leg.
- **StableSwap \(A\)** on **rated** balances for swaps / seigniorage quotes; **native inventory** for LP (hook dual-domain law).
- Fungible hook LP ≈ BPT.
- Proportional join/exit + **unbalanced join (shipped closed-form)** + **single-asset aliases** `depositSingle` / `withdrawSingle` (Balancer/Stable single-asset — **not** multi-leg force rebalance).
- All **six** \(\binom{4}{2}\) Uni V4 pair doors share one book.

**Primary product difference vs Orbital family:** reserve is a **4-asset StableSwap** (DETF + **three** like-kind pairs, amp \(A\), six doors), not a 3-asset sphere. The hook **has** `withdrawSingle` / `joinUnbalanced` (Orbital hook v1 has zap-in and **no** zap-out). First mint **requires all four legs**. Partial book is **not** a designed after-live state (hook full-book exit floors).

**Primary product difference vs Weighted family:** curve is **StableSwap \(A\)** for **like-kind** assets, not free weights. Synthetic / expansion **follow Weighted** (per-route FD + all-legs-rich). Burn does **not** use hook `withdrawSingle` even as an optimization (Q4).

**Primary product difference vs CP family:** four currencies, six doors, three externals, SE buffering via the quad stable hook.

### 0.2 Product one-liner

A **true DETF**: diamond **is** the DETF ERC-20; seigniorage mint/burn vs a **Uni V4 Curve Quad Stable SE Buffer reserve** with DETF self-leg + three like-kind external pair legs (bare and/or SE-buffered); bond principal = **hook LP**; rebasing claim = pro-rata claim on **protocol-owned hook LP**; Policy mint/burn gates use **per-route whole-reserve** FD synthetic in the path’s pair unit; **permissionless** first **bond** establishes **full-book** live at **deploy-time creation rates**; Policy natural expansion is **immutable epoch premium-closure** paid to bonders **only for epochs still all-legs mint-rich at end**.

### 0.3 Goals

1. Ship DETF package under  
   `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/`.
2. Wire **three** external pair tokens + **1–3** distinct backing SEs (≥1 required) + optional rate providers + **`baseAmp`** via **`PkgArgs` → hook package deploy** (create all six pair doors in hook postDeploy) + **one** Curve Quad Stable Buffer Hook with raw DETF self-leg.
3. Primary mint/burn + bond + **maturity** close and **post-maturity** sell→claim + direct claim paths (adapted to 4-leg StableSwap host).
4. Deploy-time **creation rates** (one per external pair) for empty-reserve first join; synthetic + Policy/Open thereafter.
5. Seigniorage inventory → bond reward ledger (**same split spirit as Balancer / CP / Orbital / Weighted UniV4 DETF**); protocol compound into reserve LP via single-sided DETF join (`depositSingle(DETF)`) when single-asset eligible.
6. **Natural expansion (Policy):** same epoch premium-closure form as CP / Orbital UniV4 DETF peers (§10); accrues only when **every** external pair is mint-rich under per-route synthetic (**all-legs rich**).
7. Production-first tests; no SUT mocks.

### 0.4 Non-goals (v1)

1. Implementing the reserve hook inside this package (hook is a dependency; already has its own PRD + plan).
2. Dual-OOR CL listing bonds / app-level listing oracle.
3. \(n \neq 4\) (dual / triple StableSwap DETFs would be separate PRDs).
4. Binding DETF as a buffered SE leg (self-leg is **raw** only).
5. Same SE address on two legs (forbidden by hook).
6. Balancer BPT reserve.
7. Native ETH as a pool currency (use WETH if needed).
8. Cross-chain.
9. Subclassing Balancer DETF contracts, CP / Orbital / Weighted UniV4 DETF contracts, or hook contracts. **Fresh codepath.** Behavioral reference only.
10. Guaranteeing peg, APY, or first-bond holder parity with later bonders.
11. Multi-leg internal rebalance “zap” (forbidden by hook — one-token paths are Stable single-asset only).
12. MEV protection / commit-reveal on permissionless first bond.
13. Treating V4 `sqrtPriceX96` as product mid after first bond.
14. Family-local bond NFT / rebasing packages when shared Uni V4 common packages suffice.
15. **All-external-bare** deploy (zero SEs) — use raw Quad StableSwap + a different product if needed; this family requires **≥1 SE**.
16. Fee-on-transfer / rebasing **pair** tokens as pool currencies (hook forbids; DETF restates).
17. Protocol “rebalance to restore full book” surface — not needed for the designed lifecycle: this family **first-bonds a full book**; hook law forbids zeroing a full-book leg via exit; StableSwap swaps do not fully drain a leg at finite size.
18. Binary-search solvers for non-closed-form routes — **`InvalidRoute`** only.
19. Amp ramping / post-deploy \(A\) mutation (hook D7).
20. Reimplementing StableSwap \(D\) / \(y\) / single-asset algebra **inside the DETF** for quotes (hook is source of truth).
21. Pair-token rate providers on **raw** legs (hook Q2 — SE RP only).
22. User-paid **DETF as bond capital** — bond payment is always external; protocol **mints** join DETF into the reserve with that payment.
23. Claim redeem **`tokenOut = DETF`** — **`InvalidRoute`**.
24. Treating this DETF as a substitute rename of Orbital or Weighted.
25. Using hook **`withdrawSingle`** on DETF burn / claim redeem — **forbidden** (Q4). Redeposit + residual only.
26. A whole-DETF deploy-time **`rateAsset`** field for mint/burn gates (per-route pair unit — Q5).
27. Mixed-vol / non-like-kind externals under this StableSwap \(A\) host (Q17) — **operator convention**, not an extra deploy revert (Q22).

---

## 1. Locked product decisions (summary)

> v0.4: all §20 Qs **closed by stakeholder answers**. Stance = **LOCKED** unless noted as hook law / agent law.

| Topic | Decision | Stance |
|-------|----------|--------|
| Family type name | **`UniswapV4StandardExchangeCurveQuadStableDETF`** | **LOCKED Q16** |
| Package path | `detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/` | **LOCKED Q16** (matches hook tree) |
| True DETF | **Yes** — diamond is share ERC-20; reserve includes DETF self-leg | Peer copy |
| Reserve host | **`UniswapV4StandardExchangeCurveQuadStableBufferHook` only** | LOCKED |
| Reserve size | **Exactly 4** pool tokens; **exactly 3** external pairs | Hook law |
| Binding order | Hook: **address-ascending** tokens. DETF is the unique **raw** self-leg at **its address index** | **LOCKED Q10** |
| External legs | **Three** like-kind pair tokens always; each may be **bare** or **SE-buffered** | **LOCKED Q17** |
| SE slots | **At least one** non-zero SE on an external leg; at most three; non-zero SEs **pairwise distinct**. All-external-bare **forbidden** | **LOCKED Q11** |
| Amplification | Deploy-time **`baseAmp`** passed through to hook; immutable; DETF does **not** store a second \(A\) or re-solve StableSwap | LOCKED |
| Rate providers | **Optional** per SE-buffered leg only; when set, **must rate SE shares → that leg’s pairToken**. Not on DETF or bare legs | **LOCKED Q9** |
| **Synthetic / FD ruler** | **Per-route, whole-reserve:** `syntheticVs(pair_k)` = FD extractable residual of the **entire reserve pool** consolidated **to pair_k** (incl. DETF self-leg) ÷ effective DETF supply, scaled by **creationPairPerDetfWad[k]**. Mint uses funded pair; burn uses `tokenOut` pair. **No whole-DETF `rateAsset` field** | **LOCKED Q5** |
| Primary mint quote | Capital always **rated into the funded pair-leg units**, then seigniorage quote against reserve for that leg via **hook source of truth**. **No** forced convert through another pair mid | **LOCKED Q12** |
| PkgArgs → hook | DETF DFPkg passes tokens / SEs / RPs / `baseAmp` / poolManager / feeOracle / mineNonce into hook `deployHookVault` + six-door init | LOCKED |
| Backing SEs | Settlement SEs for mint/bond capital are the **same** instances bound on the hook for that pair | Peer copy |
| Live | **Permissionless first successful bond** that joins reserve LP (synthetically ungated) | Peer copy |
| First bond capital | **Requires all three external pair legs** funded (pair tokens and/or SE-accepted capital that settles to each) | **LOCKED Q1** |
| First bond close asset | **`capitalToken` = a pair the user actually funded at open.** First bond: caller **must pass** one of the three funded pairs (**Q18**). Later bond: **forced** to the one funded pair (no choice). Close pays **only** that token | **LOCKED Q7 / Q18** |
| Creation rates | **Deploy-time `PkgArgs`** — three WAD rates, each **`> 0`**; size first-bond DETF + pairs so initial StableSwap mids ≈ creation | LOCKED |
| First-bond excess | Unused external capital after min-implied DETF sizing is **refunded** | **LOCKED Q13** |
| Seigniorage | Peer: boost on **funded pair-leg notional** → `quoteDetfAgainstReserve` (hook SoT) → usage fee → half-incentive inventory / user / feeTo | Peer copy |
| Primary mint (live) | **Any of the three external pairs** (or capital settled into that pair / its SE) via hook **`depositSingle` / `joinSingleAssetExactIn`**. Revert if not single-asset eligible | **LOCKED Q2** |
| Primary burn | **Burn only user-provided free DETF** when under peg on **`tokenOut` pair**. **Only path:** `exitProportional` + **redeposit** returned DETF + residual consolidate to `tokenOut`. **`withdrawSingle` forbidden** on DETF burn/redeem | **LOCKED Q4** |
| Bond (after live) | **No Policy/synthetic price gate**; **exactly one external pair** capital; protocol **mints join DETF** + **`joinUnbalanced`** (DETF + that pair; zeros on other legs); **does realize** expansion debt | **LOCKED Q3** |
| Bond principal | **Hook LP** on shared Uni V4 bond NFT package | **LOCKED Q8** |
| Bond `effectiveShares` | **DETF-valued principal at open** × lock bonus: funded external pair notional(s) converted to DETF at **open-time rated StableSwap mids** (hook preview). No `rateAsset` FX | Follows Q5 |
| **Sell bond → rebasing claim** | **Only after maturity** — pre-maturity sell **reverts**. DETF-wide standard. Enforced on DETF surface; shared package `requireMatureForSell = true` | Peer copy (Orbital first adopter) |
| **Pre-maturity principal exit** | **None** — only `claimRewards` while locked | Peer copy |
| **Maturity close settlement** | Pay **only the token used to buy the bond** (`capitalToken` recorded at open). Prop remove → redeposit DETF → consolidate other non-DETF legs → that token. **No** residual basket | **LOCKED Q7** |
| **Post-maturity hold** | Exit **optional forever** — no forced close | Peer copy |
| **Bond NFT transfer** | **Free ERC-721 transfer** anytime; buyer inherits lock + capital-token metadata | Peer copy |
| Claim redeem | Protocol-LP apportioning; **redeposit** DETF returned from remove; **`tokenOut = DETF` → InvalidRoute**; prefer **clean vaultShare path** when `tokenOut` is a share. **No** `withdrawSingle` | **LOCKED Q4** |
| Free DETF → claim | Hook **`depositSingle(DETF)`** when single-asset eligible; no seigniorage | Peer copy |
| Expansion realize paths | **Only** bond / `claimRewards` / `compoundProtocolRewards` (+ reward updates). **Not** primary mint/burn | Peer copy |
| Compound if not single-asset eligible | **Skip** (no revert) — leave pending | Orbital Q6 |
| Route errors | **`InvalidRoute`** plus family errors (not-live, not-mature, not-single-asset-eligible, first-bond-needs-all-externals, later-bond-single-only, protocol-LP-empty, lock-too-short, min-out) | LOCKED |
| Exact-out DETF routes | **Exact DETF-out mint** + **exact tokenOut burn**, ship iff closed-form + bit-exact preview. Execution still prop-remove + redeposit + residual — **never** hook `withdrawSingle` / `exitSingleAssetExactTokenOut`. Else **`InvalidRoute`**. **Never** binary-search | **LOCKED Q15 / Q19 / Q20** |
| Fixed-point | Scale to **1e18** internal; scale back for transfers | Peer copy |
| Instance governance | Immutable / unowned after deploy | Peer copy |
| DETF DFPkg path | IndexedEx manager vault registry. **Never** `new` facets/DFPkg; never bypass registry | Agent law |
| Hook / children deploy | Hook: registry `deployHookVault` + hook diamond factory; bond NFT + rebasing: pure Crane; owner = DETF diamond | Peer copy |
| Bond NFT / rebasing | **Share** `uniswap/v4/common/` packages; mature-only via DETF + shared flag | **LOCKED Q8** |
| Fee-recipient NFT | Wire like peer UniV4 DETFs; **same** mature-only principal rules | Peer copy |
| Compound | Protocol NFT only → `depositSingle(DETF)` when single-asset eligible | Peer copy |
| Natural expansion | Deploy-time epochs + premium-closure; unlimited whole-epoch catch-up (`maxCatchUpEpochs=0`); **not** fee oracle; Policy accrues only when **all three** external legs are mint-rich (`allLegsMintRich`) at epoch end. Formula uses **`min(S_spot_0, S_spot_1, S_spot_2)`** | **LOCKED Q6 / Q21** |
| Synthetic + epoch debt | Pending expansion in synthetic denominator | Peer copy |
| Peg narrative | Per external pair \(k\): abstract **1e18** = FD claim in pair \(k\) per DETF equals **creationPairPerDetfWad[k]**. No global external peg pair | **LOCKED Q5** |
| Buffered-leg mint capital | **Pair face allowed** (hook buffers last); also vaultShare / SE.tokens(); B6 flexible share flags allowed as **optimization** | **LOCKED Q14** |
| Asset story | **Three like-kind stables only** (operator convention — **no** extra deploy check beyond hook token rules). Mixed-vol → Weighted / Orbital | **LOCKED Q17 / Q22** |
| Test matrix | Gentle **and** launch-rich expansion; **1 SE + 2 bare**, **2 SE + 1 bare**, **3 SE**; reject all-bare; RP on/off; mixed decimals 6/18; DETF not at binding index 0; amp bounds inherited from hook | LOCKED |

---

## 2. Role vocabulary (LOCKED)

| Role | Name | Meaning |
|------|------|---------|
| DETF share / diamond | `detfToken` / `address(this)` | ERC-20; reserve **raw** self-leg at its binding index |
| Pair legs | `pairToken0` / `pairToken1` / `pairToken2` | The three external ERC-20s (product / PkgArgs order); map to hook binding indices at deploy |
| Bare pair leg | pair with `standardExchange_i == 0` | Hook holds **face ERC-20** as that leg’s book |
| Buffered pair leg | pair with non-zero SE | Hook holds **SE shares**; free pair is dust only |
| Backing SE \(i\) | `standardExchange[i]` | Optional SE for each pair; **must not** list DETF; **distinct** when non-zero |
| SE share \(i\) | `vaultShare[i]` | Present only when that SE is set |
| Rate provider \(i\) | `rateProvider[i]` | Optional; non-zero **only if** corresponding SE set; rates **SE shares → that leg’s pairToken** |
| Amplification | `baseAmp` | Deploy-time hook \(A\) (unscaled). Hook math uses \(A \cdot\) `AMP_PRECISION` (`100`). Bounds: hook D7 |
| Per-route synthetic | `syntheticVs(pair_k)` | Debt-inclusive FD richness of DETF vs external pair \(k\) (creation-scaled) (**LOCKED Q5**) |
| FD residual to pair | `previewWholeReserveToPair(pair_k)` | Prop-remove residual of the **entire reserve pool** consolidated **to pair_k** via StableSwap exact-in (incl. DETF → pair_k) |
| Reserve | `reserveHook` / `reservePool` | Curve Quad Stable Buffer Hook + its six V4 doors |
| Reserve principal | `reserveLp` / hook LP | Fungible LP from reserve hook (BPT analogue); hook prefix **`SEQS`** |
| Bond NFT | `bondNft` | Shared Uni V4 package; holds user `reserveLp` while open |
| Protocol principal | protocol-owned `reserveLp` | Held by **shared** rebasing package |
| Rebasing claim | `rebasingClaimToken` | ERC-20 claim on protocol `reserveLp` |
| Creation rates | `creationPair0PerDetfWad`, `creationPair1PerDetfWad`, `creationPair2PerDetfWad` | Deploy-time empty-book join rates (WAD) for each external pair vs DETF; **each must be > 0** |
| Native / rated reserves | hook `nativeReserve(i)` / `ratedBalance(i)` | LP uses native inventory; swaps / seigniorage quotes use rated (face / claim / shares×rate) |
| Single-asset eligible | hook `isFullBook()` + supply > `MINIMUM_LIQUIDITY` | Gate for `depositSingle` / single-asset join paths. Prefer this term over Orbital “zap-eligible” |
| Bond capital token | per-`tokenId` `capitalToken` | **The pair used to buy the bond** (first bond: one of the three funded; later: the one funded). Close pays **only** this token (**LOCKED Q7**) |
| Witness legs | the two non-trade tokens in a directed pair swap | Enter StableSwap invariant; solver **tolerates** zero-rated witnesses **defensively** (hook Q7) — not a DETF product state |

**Anti-patterns:** brand tickers; pair ∉ SE tokens when SE set; DETF listed in any SE; same SE on two legs; RP without SE; RP on bare/DETF legs; inventing hook APIs; treating V4 mid as product mid; burning DETF returned from proportional remove (must redeposit); FoT/rebasing pair tokens; all-external-bare deploy; multi-leg force-rebalance “zap” wording for one-token paths; reimplementing StableSwap inside the DETF; calling this family Orbital or Weighted; reintroducing a **whole-DETF `rateAsset`** field for mint/burn gates; using `withdrawSingle` on DETF burn/redeem.

**WETH rule:** use `weth` / `WETH` only in truly WETH-specific code. This family has **no** product role `rateAsset` as a whole-DETF numeraire. SE **rate providers** still rate **shares → pairToken** for buffered legs only.

**Not used in this family:** product role **`rateAsset`** as a **whole-DETF** synthetic numeraire. Mint/burn use the **route pair**. Peer CP / Orbital PRDs that name a single `rateAsset` gate are **not** copied here; **this family supersedes** that role for synthetic/gates (Weighted peer).

---

## 3. Topology (LOCKED)

```text
                    ┌──────────────────────────────────────────────┐
                    │ UniswapV4StandardExchangeCurveQuadStableDETF  │
                    │ diamond = detfToken ERC-20                    │
                    │ immutable / unowned after deploy              │
                    └───────────────────┬──────────────────────────┘
                                        │
     ┌──────────────────────────────────┼──────────────────────────────────┐
     │                                  │                                  │
     v                                  v                                  v
┌──────────────┐              ┌─────────────────────────┐        ┌─────────────────┐
│ SE ×1–3      │              │ Reserve Quad Stable Hook  │        │ Bond NFT pkg    │
│ (distinct)   │◄─buffer?─────│ 4 tokens: DETF raw +      │──LP───►│ (shared common) │
│ or bare legs │              │ pair0 + pair1 + pair2     │        │ user LP + rewards│
└──────────────┘              │ each pair: bare or SE+RP? │        └────────┬────────┘
                              │ StableSwap A on rated     │                 │ sell
                              │ native inventory LP       │                 │
                              │ fungible LP; 6 V4 doors   │                 v
                              └──────────┬────────────────┘        ┌─────────────────┐
                                         │ protocol LP             │ migrate LP →    │
                                         v                         │ protocol        │
                              ┌─────────────────────┐              │ (shared common) │
                              │ Rebasing claim pkg   │◄─────────────│                 │
                              │ holds protocol LP    │  deposit     └─────────────────┘
                              │ redeem matrix §9     │
                              └─────────────────────┘
```

**Public market (six doors, one room):**

```text
Pool DETF/pair0  ──┐
Pool DETF/pair1  ──┤
Pool DETF/pair2  ──┼──► same reserve hook
Pool pair0/pair1 ──┤    (shared native inventory + rated StableSwap book + A)
Pool pair0/pair2 ──┤
Pool pair1/pair2 ──┘
```

A swap on any door still uses the **other two tokens as witnesses** in the StableSwap solve. DETF product paths do **not** construct native-zero legs.

**Opacity:** DETF production talks to `IStandardExchange*`, reserve hook ABI (`IUniswapV4StandardExchangeCurveQuadStableBufferHook` + `IStandardExchangeMultiAssetLiquidity` + In/Out), bond NFT APIs, rebasing APIs, fee oracle, shared DETF libs. DFPkg wires hook package deploy from `PkgArgs`. Product mid is **never** V4 `sqrtPriceX96` after first bond.

**Same SE instances:** Settlement for mint/bond capital uses the SEs bound on the hook for the corresponding pair token (when set).

**Hook liquidity surface this DETF is allowed to call (do not invent others):**

| Hook selector | DETF use |
|---------------|----------|
| `joinProportional` / `joinProportionalFlexible` | First bond (all four legs) |
| `joinUnbalanced` | Later bonds (DETF + one pair; zeros on other legs) |
| `depositSingle` / `joinSingleAssetExactIn` (+ Flexible) | Live primary mint; protocol compound; free-DETF→claim |
| `exitProportional` / `exitProportionalFlexible` | Normative burn / claim redeem / maturity close |
| `withdrawSingle` / `exitSingleAssetExactBptIn` (+ Flexible) | **Not used** on DETF burn/redeem (Q4) |
| `withdrawSingleExactOut` / `exitSingleAssetExactTokenOut` | **Not used** on DETF (Q4 / Q20). Exact-out burn still sizes via invert then `exitProportional` |
| `previewSwapExactIn` / SE In/Out | Residual consolidate other pairs → `tokenOut` / `capitalToken` |
| `nativeReserve` / `ratedBalance` / `isFullBook` / `baseAmp` | Info + gates |

---

## 4. Liveness & first bond (LOCKED)

### 4.1 States

| State | Condition |
|-------|-----------|
| **Inert** | Deployed; reserve hook bound; six V4 doors may be initialized with plumbing; **no** successful bond yet; primary mint/burn blocked; non-first bonds blocked |
| **Live** | First **successful bond** completed that minted DETF for join and placed **reserve LP** on the bond NFT; `isReserveLive = true` |

### 4.2 First bond access

**Permissionless.** Any address may establish live with a successful first bond.  
No product min notional beyond hook **MINIMUM_LIQUIDITY** / first-mint constraints (all four native inventories \(> 0\) after buffer; inventory geo-mean > MINIMUM_LIQUIDITY).  
If first mint would fail hook geometric / MIN liquidity constraints, **revert** with a clear product error (cannot go live).  
No MEV protection in v1; operators should seed with a **small but viable** four-leg proportional first bond. **No holder-parity guarantee** between first and later bonders.

### 4.3 Creation rates (deploy-time)

| Field | Meaning |
|-------|---------|
| **`creationPair0PerDetfWad`** | After decimal normalize to 1e18, how much **pairToken0** (WAD) equals **1e18 DETF** at empty-book join |
| **`creationPair1PerDetfWad`** | Same for **pairToken1** |
| **`creationPair2PerDetfWad`** | Same for **pairToken2** |
| Storage | Resolved from `PkgArgs` at deploy; **immutable** on instance |
| **Validation** | All three rates **must be `> 0`**. Zero or missing ⇒ deploy/init **reverts**. No product max; operators choose seed richness. **No required invariant** between the three rates (cross-pair relative prices are free; a large \(A\) will keep like-kind pairs tight after seed). |

#### Decimal convention (peer CP / Orbital DETF)

1. Convert amounts to **internal WAD (1e18)** for all pricing, synthetic, creation-rate, and seigniorage math.
2. Creation rates stored and consumed **only in WAD space**.
3. Scale back to native decimals for ERC-20 transfers and hook calls.

**Example:** Want “1 DETF ≈ 1 USDC ≈ 1 USDT ≈ 1 DAI” at seed →  
`creationPair*PerDetfWad = 1e18` for each (after WAD normalize of 6-decimal stables).  
Want a **rich** seed vs USDC → `creationPairUsdcPerDetfWad = 2e18` (1 DETF sized as 2 USDC at join) while other rates stay `1e18` — operators own that choice.

**Peg narrative (LOCKED Q5):** for each external pair \(k\), abstract **1e18** on `syntheticVs(pair_k)` means FD claim of the whole reserve **in pair \(k\)** per DETF equals **creationPairPerDetfWad[k]**. There is **no** single global external peg pair — richness is always relative to a chosen pair leg. StableSwap \(A\) is what keeps like-kind pairs near each other.

### 4.4 First bond mechanics (LOCKED Q1)

First bond is **synthetically ungated** (Policy and Open).

**Requires all three external pair legs** with non-zero capital after settlement (pair tokens, vault shares, and/or SE-accepted tokens that resolve to **every** `pairToken[i]`). Missing any external → **reverts** (`FirstBondRequiresAllExternalPairs` or family equivalent).

This is **forced by hook first-mint law** (all four native inventories \(> 0\)). A two-pair first bond cannot create a valid hook book.

**Close asset (LOCKED Q7 / Q18):** caller **must** supply **`capitalToken`** — one of the three **funded** `pairTokens`. Stored on the NFT as the **sole** maturity-close settlement token. Orbital dual-residual close is **out**.

1. User supplies capital resolving to **all three** pair-notionals \(C_0, C_1, C_2 > 0\) in WAD, plus chosen **`capitalToken`**.
2. **Mint DETF for join** using **creation rates only** (not live StableSwap mid):

```text
// WAD space — join DETF sized so empty proportional ratio matches creation
detfFrom0 = pair0NotionalWad * 1e18 / creationPair0PerDetfWad
detfFrom1 = pair1NotionalWad * 1e18 / creationPair1PerDetfWad
detfFrom2 = pair2NotionalWad * 1e18 / creationPair2PerDetfWad
detfForJoinWad = min(detfFrom0, detfFrom1, detfFrom2)
require detfForJoinWad > 0
// Size each pair used at join = detfForJoinWad * creationPair_i / 1e18
// Excess external capital is REFUNDED
```

3. Apply **peer mint modifiers** on the join-sized gross (seigniorage split for free legs). Free `user` / `feeTo` / `inventory` DETF is **not** joined into the reserve; only **join-sized** DETF enters the proportional join.
4. Settle capital to **native pair tokens** (convert SE tokens/shares → pair when SE set; bare legs are already native). B6 flexible join may pass SE shares directly on buffered legs if that is preview-equal — impl plan freezes the default (**LOCKED Q14:** settle to pair face, let hook buffer-last; Flexible is optimization only).
5. Reserve hook **`joinProportional`** with join DETF on self-leg index + all three pairs on external indices (binding-order amount arrays). Hook first mint: inventory geo-mean − `MINIMUM_LIQUIDITY`; buffer-last; dead MIN to `address(0)`.
6. **Refund** any unused external capital (and unused SE-routed remainder) to the caller after join sizing / hook clamp.
7. **LP → bond NFT package** for `tokenId`; record **`capitalToken`** (single) and **effectiveShares**.
8. Set **`isReserveLive = true`**.
9. **Post-condition:** first bond establishes a **full book** (all four native inventories \(> 0\)). Incomplete seed **reverts**.

**Empty book / mids:** hook first mint sets inventory-domain \(V\); join DETF sized by creation rates so **rated** StableSwap mids ≈ creation rates at the proportional join (modulo SE buffer fees, dust, amp geometry, free seigniorage legs outside the pool). Free seigniorage legs **intentionally** sit outside the pool and do **not** re-size the join. **No holder-parity guarantee.** Full-book seed means primary mint **`depositSingle`** is available immediately after live.

### 4.5 After live

- **Primary mint/burn:** subject to Policy/Open **per-route whole-reserve** debt-inclusive synthetic gates (Open: ungated). Mint gate uses funded pair; burn gate uses `tokenOut` pair (**LOCKED Q5**).
- **Further bonds (after live):** **no synthetic / Policy mint gate.** User pays **exactly one** external pair (or SE capital settling to that pair) — **never** DETF. Protocol **mints join DETF** and calls hook **`joinUnbalanced`** with DETF + that pair (zeros on the other two externals). Multi-external later bonds **revert** (Q3).
- Bond paths **also** mint free DETF legs from the seigniorage split of the join quote.
- Bond / `claimRewards` / `compoundProtocolRewards` **realize** pending expansion debt (§10). Primary mint/burn **do not**.
- Reserve swap mids from **rated** StableSwap balances; LP ownership from **native** inventory (hook law).
- Creation rates remain first-bond seed **and** per-leg synthetic scale; **not** used to size later mint join amounts.
- **Full book stays the designed live state:** hook full-book exit floors + first bond required all externals + later unbalanced joins **add** inventory. Partial book is exceptional (mis-config / defect), not “later bonds emptied a leg.”
- **Live does not imply burnable depth:** first-bond LP sits on the NFT; protocol LP may be ~0 until primary mint, bond-sell, or compound. Primary burn **reverts** if protocol LP insufficient (intentional).

---

## 5. Pricing, synthetic, thresholds (LOCKED)

### 5.1 Marks

| Mark | When | Use |
|------|------|-----|
| **Creation rates** | First bond only (and inert info) | Size first-bond DETF for proportional join; seed mids |
| **Reserve mids** | Live | Rated StableSwap mids from hook; **seigniorage quotes** and open-time bond valuation |
| **FD backing / synthetic** | Live | Per external pair: fully diluted claim of the **whole reserve pool in that pair** ÷ **effective DETF supply** (includes **pending epoch expansion debt**), scaled by that pair’s creation rate — §5.5 |

### 5.2 Decimal scale

All internal pricing, synthetic, thresholds, creation rates, seigniorage boost, and expansion math run in **1e18-normalized** units. Scale to/from native decimals only at token boundary I/O.

### 5.3 Seigniorage quote shape after live

**Goal:** replicate Balancer / CP / Orbital / Weighted UniV4 DETF seigniorage economics on this host, with **per-leg rating**.

**Normative capital rating (Orbital Q15 spirit):**

1. Identify which **external pair leg** the `tokenIn` funds (`pairToken0`, `pairToken1`, or `pairToken2`).
2. Convert `tokenIn` amount → **pair-leg units** for that leg only:
   - **pairToken itself:** face amount (WAD).
   - **SE vault share:** always **rate** to pair units — if RP set: `shares × getRate() / 1e18` (then toWad); if no RP: fee-inclusive SE unwrap/claim preview to pair.
   - **Other token ∈ SE.tokens():** SE route → pair, then same as pair face.
3. **Do not** convert that pair notional through another pair mid for the mint quote.
4. Boost that **pair-leg notional** by seigniorage incentive; **`quoteDetfAgainstReserve(pairLeg, pairNotionalBoosted)`** via **hook source of truth**.
5. Peer `_splitMintedDetf` for free legs.

```text
pairNotionalWad = rateTokenInToPairLeg(tokenIn, amountIn)  // never skip rate on SE shares
pairBoosted     = pairNotionalWad * (1e18 + seigniorageIncentiveWad) / 1e18
grossDetf       = quoteDetfAgainstReserve(fundedPairLeg, pairBoosted)  // via hook previews
// Split peer:
feeToDetf / inventoryDetf / userDetf from gross
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| **Live primary mint** | Rate capital → pair units → hook **`depositSingle(pairToken_i)`**. **No** DETF self-leg join on this path. | Mint `user` / `feeTo` / `inventory` only |
| **Bond (live)** | Rate capital → **one** pair; **`joinUnbalanced`** DETF + that pair; LP → bond NFT; **record `capitalToken` = that pair** | **Also** mint free legs from split |
| **First bond** | Creation-rate sized join DETF + **all three** pairs via **`joinProportional`**; LP → bond NFT; **record user-chosen `capitalToken`** | Same free legs from split of gross |

**`quoteDetfAgainstReserve` (economic + implementation):**

| Layer | Rule |
|-------|------|
| **Economic identity** | Gross DETF is the seigniorage mint size such that the **pair-leg capital**, if joined single-sided via the same path as live primary mint (`depositSingle` impact on rated StableSwap), backs that DETF at the **post-impact** reserve mid for that leg. **Not** creation rate. **Not** forced convert through other pairs. **Not** tick-walk / binary search. |
| **Source of truth** | The **reserve hook** is the sole calculator for join impact / single-asset economics. DETF **must call hook view/preview** (e.g. invert `previewDepositSingle` / `previewJoinSingleAssetExactIn` / rated swap preview as the impl plan freezes). **Do not reimplement StableSwap \(D\)/\(y\) inside the DETF.** |
| **Preview == execution** | Assert on mint/bond closed-form routes (≤ few-wei only if SE multi-leg dust forces it; document). |

**Rate providers:** when set on a buffered leg, RP **must** express **SE shares → that leg’s pairToken**. Fail-closed on rated paths (hook O5).

### 5.4 Settlement `tokenIn` (primary mint & bond capital)

| `tokenIn` | Allowed | Notional resolution |
|-----------|---------|---------------------|
| `pairToken0` / `pairToken1` / `pairToken2` | Yes | amount → that pair WAD (face) |
| `vaultShare[i]` | Yes **if** corresponding SE set | **Always rate** share → pair units (RP or SE claim) |
| Other token ∈ SE_i `tokens()` | Yes **if** SE_i set | SE → pair, then face pair WAD |
| Else | **`InvalidRoute`** | — |

**Primary mint:** user may mint with **any** of the three external pairs (or capital that settles/rates to that pair). Hook path = **`depositSingle` / `joinSingleAssetExactIn` of the native pair token** after settle. **Buffered legs: bare pair face is allowed** — the hook buffers last. Vault shares / SE.tokens() remain allowed when SE set. B6 `depositSingleFlexible(..., amountIsSeShare=true)` is an allowed optimization when `tokenIn` is already the vault share.

**Later bond:** same capital table, but must resolve to **exactly one** external pair; multi-pair funding **reverts**. User **never** pays DETF to open a bond.

**Full book vs single-asset eligibility (designed lifecycle):**

| Fact | Product law |
|------|-------------|
| Curve swaps | StableSwap with finite \(A\) does not fully drain a trade leg at finite size; hook also requires post-swap trade-leg native + rated \(> 0\). |
| Hook full-book exits | While full book, removes **must leave all four native reserves \(> 0\)** (hook D48). Zeroing a leg via full-book exit **reverts**. |
| Partial book on hook | Not a designed product state. First mint requires all four; v1 operational paths do not intentionally create native-zero legs (hook Q6 / Q7). |
| This family first bond | **Requires all three externals** and **reverts if any external would remain zero** → goes live only on a **full book**. |
| After live | **Normal path:** full book remains; `depositSingle` for primary mint / compound is available. |
| `NotSingleAssetEligible` | **Exceptional** (mis-config, defect) — **not** a normal “later bonds emptied a leg” lifecycle. Later one-pair unbalanced joins **add** DETF + that pair; they do **not** zero siblings. |

### 5.5 Synthetic (gates + expansion) — **per-route pair unit + pending epoch debt** (LOCKED Q5)

**Why not one global numeraire:** the reserve is a **4-asset StableSwap**. The hook already prices DETF vs each pair (and pairs vs pairs) without an off-book USD ledger. Product law uses that: **richness is always relative to a specific external pair**. Like-kind \(A\) keeps pairs tight in the happy path; per-route gates still fire correctly if one SE/leg depegs.

**Route unit of account (LOCKED):**

| Operation | Pair unit \(k\) |
|-----------|----------------|
| Primary **mint** | External pair the `tokenIn` settles/rates into |
| Primary **burn** | User’s `tokenOut` pair (before optional SE unwrap) |
| Natural **expansion** (no tokenIn) | **All three** external pairs must be mint-rich (Q6) |
| Bonds after live | **No** synthetic gate |

**Peg narrative:** for pair \(k\), abstract **1e18** means FD claim of the whole reserve **in pair \(k\)** per DETF equals **creationPairPerDetfWad[k]**.

**Rule:** each `syntheticVs(pair_k)` uses **effective DETF supply** = on-chain `totalSupply` + **pending expansion DETF**.

**Whole-reserve FD (market richness, not holder slice):**

Synthetic measures how rich the **market reserve** is relative to DETF supply. Use the **entire reserve pool** (full hook book / full outstanding hook LP) — **not** “protocol LP only,” **not** “bond NFT LP only.” Who holds LP matters for **exit rights**; it does **not** redefine the synthetic ruler.

**`previewWholeReserveToPair(pair_k)` (LOCKED):**

```text
// Whole-reserve residual in pair_k:
// 1) Preview proportional remove of totalSupply hook LP
//    → (a_detf, a_pair0, a_pair1, a_pair2) in binding order
//    Prefer hook previewExitProportional (SoT).
// 2) FULL residual → pair_k:
//      pair_k face += a_pair_k
//      each other pair → StableSwap / SE In-Out exact-in sell into pair_k
//      DETF self       → StableSwap exact-in sell into pair_k
//    Prefer hook previewSwapExactIn / SE In-Out previews.
//    Fee-aware; order frozen in impl plan.
// 3) Redeposit-on-execution is SEPARATE from FD.

fdPair_k = previewWholeReserveToPair(pair_k)

S_spot_k = (fdPair_k * 1e18 / detfTotalSupply) * 1e18 / creationPairPerDetfWad[k]

pendingExpansionDetf = previewPendingExpansionMint()
effectiveSupply = detfTotalSupply + pendingExpansionDetf

syntheticVs(pair_k) = (fdPair_k * 1e18 / effectiveSupply) * 1e18 / creationPairPerDetfWad[k]
```

**Why include DETF→pair_k in FD:** excluding the self-leg systematically understates extractable backing on a 4-leg book. **Redeposit on burn/claim** remains mandatory for **protocol self-leg depth** — it does not redefine FD.

**Policy gates (when live):**

| Path | Gate |
|------|------|
| Primary mint → pair \(i\) | Allow iff `syntheticVs(pair_i) > mintThreshold` (default 1.05e18) |
| Primary burn → pair \(j\) | Allow iff `syntheticVs(pair_j) < burnThreshold` (default 0.95e18) |
| Equality on that route | **Deadband** for that route only |
| Open | Threshold gates **always pass**; pending expansion **0** |
| First bond | Synthetically **ungated** |
| Bonds after live | **No** synthetic mint gate |

**Implication:** the book may be mint-open for USDC and mint-closed for USDT at the same time (skew / a depeg). That is intentional.

**Natural expansion mint-rich predicate (LOCKED Q6):**

```text
allLegsMintRich =
  live && thresholdMode == Policy
  && for every external pair_k:
       syntheticVs(pair_k) > mintThreshold
```

Expansion **accrues** only while `allLegsMintRich` (Open: never). See §10. Pending debt still enters **every** `syntheticVs` denominator when computing gates.

**Gas:** \(m = 3\). One prop-remove residual + three StableSwap consolidations. Prefer hook previews; short-circuit on first non-rich leg when only a boolean is required.

**Source of truth:** `ThresholdMode` + thresholds from **`PkgArgs` → resolve → storage only**. Fee oracle does **not** set thresholds. Defaults via `DETFThresholdPolicy` (0 → 1.05e18 / 0.95e18). After resolve: `mintThreshold > burnThreshold`.

**Realize vs accrue:** realize only on bond / claimRewards / compound; **not** on primary mint/burn.

**Info surface:**

- `syntheticPrice(address pair)` / `syntheticVs(pair)` — debt-inclusive
- optional `syntheticPriceSpot(address pair)`
- `isMintingAllowed(address pair)` / `isBurningAllowed(address pair)`
- optional `isAllLegsMintRich()` for expansion UX
- `pendingExpansionDetf()`, creation rates, pairs, SEs, RPs, amp, binding indices, `isFullBook`
- **No** parameterless global `syntheticPrice()` as the sole gate oracle
- **No** `rateAsset()` getter

### 5.6 Primary burn of DETF (LOCKED Q4)

**When:** Policy burn gate on **`tokenOut` pair** (`syntheticVs(tokenOut) < burnThreshold`) or Open when live.  
**Settlement:** user chooses `tokenOut ∈ {pairToken0, pairToken1, pairToken2}` (and optionally SE unwrap of that pair — §9.4). **`tokenOut = DETF` → InvalidRoute**. Else **`InvalidRoute`**.

**LP basis (peer debt model):**

```text
protocolLp = reserveLp.balanceOf(protocolLpHolder)
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
lpOut = detfBurned * protocolLp / effectiveSupply
// if protocolLp == 0 or lpOut == 0 → revert
```

**Execution:**

1. Require live + **debt-inclusive** burn gate on **`tokenOut` pair** (Open: always when live).
2. Pull **user-provided free DETF** (`detfBurned`); compute `lpOut` with **effectiveSupply** (**do not** realize expansion).
3. **Burn only `detfBurned`**.
4. **Usage fee on burn: YES** — vault fee oracle burn usage fee (`DETFUsageFeeLib`). **No** mint-style inventory / seigniorage split on burn.
5. **Only path — proportional remove + redeposit (LOCKED Q4):**
   - Hook `exitProportional(lpOut, …)` → receive four-leg amounts including a DETF self-leg slice.
   - **Redeposit** all **DETF returned from remove** into protocol reserve LP (ladder §5.6.1).
   - **Consolidate residual non-`tokenOut` pair legs** into `tokenOut` via hook SE In/Out / `previewSwapExactIn` execution.
6. **`withdrawSingle` is forbidden** on this DETF for burn and claim redeem — do not call it even as an optimization.
7. Pay **`tokenOut` only**. **Dust policy:** dust of `tokenOut` after settle goes to the user; dust of other pairs that cannot be economically consolidated (below min swap / dust threshold frozen in plan) may remain on the DETF diamond and is **not** a user claim in v1. Tests assert no material free inventory of user capital on success paths.
8. Enforce `minOut`.

**Exact-out burn (LOCKED Q15 / Q19 / Q20):** user names **exact `tokenOut` amount**. If Phase 0 finds a **closed-form** invert to DETF in / `lpOut` with **bit-exact preview == execution**, expose it. **Execution is still** `exitProportional` + redeposit DETF + residual consolidate — **never** hook `withdrawSingle` / `exitSingleAssetExactTokenOut`. If no closed-form: selector **`InvalidRoute`** (exec + preview). **Never** binary-search.

#### 5.6.1 Redeposit ladder

1. **Prefer** hook **`depositSingle(DETF)`** when single-asset eligible.
2. **Else** `joinUnbalanced` with DETF amount and zeros on the three pairs **if the hook accepts** that shape on a live full book.
3. **Else** full tx **reverts** (atomicity: user must not lose burned free DETF without payout).
4. **Do not** burn returned DETF. **Do not** pay returned DETF to the burner.

**Do not** size burn from creation rate while live.  
**Do not** draw on bond-NFT LP for primary burn.  
**Do not** clear expansion debt on burn.  
**Do not** invent hook APIs.

This family **has** hook `withdrawSingle`. Stakeholder lock (**Q4**): DETF burn/redeem **must not** use it. Only proportional remove + redeposit + residual.

---

## 6. Fees (four layers — do not conflate)

| Kind | What | Source |
|------|------|--------|
| **A. Reserve StableSwap trading fee** | Live `dexSwapFeeOfVault(hook)` residual in book; same channel taxes single-asset join/exit taxable portion | Hook law (Q5 / Q9) |
| **B. Hook protocol growth** | Live `usageFeeOfVault(hook)` LP mint to feeTo on \(k\) growth | Hook law |
| **C. DETF protocol fees** | Usage fee, seigniorage incentive, mint split; **burn usage fee yes** | Vault Fee Oracle on DETF |
| **D. SE usage fees** | On buffer/mint routes inside each SE (when set) | SE + oracle |

**Bond lock terms:** fee oracle via `DETFBondNFTMathLib` — **revert if lock < min**; **clamp to max** if longer (bonus at max).

**Fee-recipient NFT:** wire as peer (claimable free DETF; **no** auto-compound in v1).

---

## 7. Primary mint after live (LOCKED Q2)

1. **Do not** realize expansion debt / advance `lastExpansionTimestamp`.
2. Resolve notional from `tokenIn` (WAD); settle to an **external pair leg**.
3. **Debt-inclusive** Policy mint gate: `syntheticVs(pair_i)` (§5.5). Open: ungated when live.
4. Quote gross DETF (boost → `quoteDetfAgainstReserve` hook-SoT → split).
5. **Deepen protocol LP:** hook **`depositSingle(pairLeg)`** / `joinSingleAssetExactIn`.
   - After a successful all-external first bond, the reserve is a **full book**; single-asset mint is the **normal** live path.
   - **If not single-asset eligible:** **revert** (`NotSingleAssetEligible`). Treat as exceptional (§5.4). No protocol multi-leg rebalance API in v1.
6. Mint free DETF: user / feeTo / inventory → bond vault (if inventory > 0).
7. **Do not** auto-call `compoundProtocolRewards` on this path if that entry always realizes expansion.

**Invariant:** live primary mint does **not** require four-leg proportional deposit; peer is single-sided external-leg join + free DETF mint.

**Exact-out mint (LOCKED Q15 / Q19):** user names **exact DETF amount out**. If Phase 0 finds a **closed-form** invert to pair capital in (seigniorage quote inverse + hook SoT) with **bit-exact preview == execution**, expose it. Else selector **`InvalidRoute`**. **Never** binary-search. Not “exact hook LP out.”

---

## 8. Bond lifecycle (LOCKED)

### 8.1 Open (after live; first bond §4)

| Item | Rule |
|------|------|
| Access | Permissionless |
| Capital | **First bond:** all three external pairs. **Later bonds:** **exactly one** external pair (and/or SE capital settling to it); `joinUnbalanced` DETF + that pair (**Q3**) |
| **Price / Policy gate** | **None after live.** Bonds deepen LP liquidity. |
| DETF economics | Join-sized DETF + free fee/inventory/user legs from seigniorage **split** |
| Join | First: `joinProportional`. Later: `joinUnbalanced`. **LP → bond NFT** |
| Expansion debt | **Realize** pending expansion on bond before/with reward update |
| **effectiveShares** | **DETF-valued principal at open × lock bonus.** Convert each funded **external** pair notional to DETF at **open-time rated StableSwap mids** (hook preview / closed-form exact-in). First bond: sum of three converted legs. Later bond: the one funded pair. DETF join leg is **not** bond capital and does **not** add to effectiveShares. **Do not** use creation rates for this FX after live. |
| **capitalToken (Q7)** | **The token used to buy the bond.** First bond: caller **must pass** one of the three funded pairs. Later bond: **forced** to the single funded pair — passing any other address **reverts**. |
| claimRewards | Free DETF anytime while open (**realizes** expansion debt) — **not** a principal exit |
| Partial close | **Forbidden** |
| **Pre-maturity principal exit** | **Forbidden** |
| **Sell → rebasing claim** | **Forbidden until maturity** (§8.3) |
| **NFT transfer** | **Allowed** anytime (ERC-721, incl. secondary markets); inherits unlock + `capitalToken` |
| **Capital token metadata** | On open, record the **single** `capitalToken` (first bond: user-chosen among the three funded pairs; later bond: the one funded pair) |

`acceptedBondTokens()`: at least all three pair tokens; vault shares for each set SE; tokens from each set SE; not DETF as bond capital (DETF is minted for join).

### 8.2 Maturity

A bond is **mature** when `block.timestamp >= unlockTime` (lock terms from fee oracle / bond open — peer clamp/revert law).

**Post-maturity hold:** the NFT may remain unexited **indefinitely**. Maturity only **unlocks** exit options.

At maturity the holder chooses **exactly one** full exit:

| Exit | Result |
|------|--------|
| **Maturity close** | Withdraw principal as the **single `capitalToken` recorded at open** |
| **Sell → rebasing claim** | Convert principal LP into rebasing claim — **only when mature** |

#### 8.2.1 Maturity close (full only)

1. Require **mature**.
2. Pay pending rewards.
3. Bond NFT withdraws **all** position LP.
4. Hook `exitProportional`.
5. **Redeposit** all returned DETF self-leg into protocol LP (same ladder as §5.6.1).
6. Consolidate the two non-`capitalToken` external residuals → `capitalToken` via hook SE In/Out / StableSwap exact-in.
7. Pay user **only** `capitalToken`. Holder takes mark-to-market vs open.
8. Retire NFT; stop accrual.

**Do not** default maturity close to an unfunded pair. Close pays **only the token used to buy the bond**.  
**Do not** pay a three-asset basket (**LOCKED Q7**).

### 8.3 Sell → rebasing claim (full only — **post-maturity only**)

**DETF-wide standard:** pre-maturity sell **reverts** (`BondNotMature`).

1. **Mandatory:** this DETF’s bonding surface **always** checks maturity.
2. Shared `uniswap/v4/common/` package **`requireMatureForSell = true`** (or equivalent).
3. DETF-level check remains even if the flag is missing.

Mechanics:

1. Require **mature**.
2. Pay pending rewards.
3. Transfer **hook LP** from bond NFT to **rebasing package**.
4. Mint rebasing claim from **Δ protocol LP contribution** (pro-rata of protocol LP). Redeem consolidates that LP slice to the chosen `tokenOut` pair.
5. Credit protocol NFT id 0 principal weight if peer ledger requires.
6. Retire user NFT.

**Fallback if LP transfer blocked:** `exitProportional` → redeposit DETF → rebasing deposit of residual / LP re-mint as plan freezes — still **only when mature**.

### 8.4 Protocol NFT id 0 & fee-recipient

- Protocol NFT id 0: reward ledger weight for inventory seigniorage / expansion; compound §10.
- **Fee-recipient NFT:** wire as peer. If the fee recipient holds a bond position, **same** mature-only principal exit rules apply.

---

## 9. Rebasing claim (LOCKED Q23)

### 9.1 Package

- **Share** Uni V4 DETF bond NFT + rebasing packages under  
  `detf/protocols/dexes/uniswap/v4/common/` with CP / Orbital / Weighted.
- Ownable/operable owner = DETF diamond for privileged absorb/donate.
- Pure Crane deploy (not vault registry).
- **Holds protocol LP.**

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
| Bond sell (**post-maturity only**) | No | Migrate LP → protocol; mint claim from contribution |
| New money (pair / SE token / share) | **No** | Settle to pair → hook `depositSingle(pair)` when single-asset eligible → LP to protocol → mint claim |
| Free DETF | **No** | `depositSingle(DETF)` → LP to protocol → mint claim (price impact is user’s) |

Claim shares: SE-style pro-rata of **protocol hook LP**. First depositor inflation guards as peers.

### 9.4 Redeem claim

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
// burn claim shares only (not DETF from remove)
// exitProportional(lpOut)
// REDEPOSIT all DETF returned from remove into protocol LP
// residual pairs → consolidate to tokenOut
```

**`tokenOut` options:**

| `tokenOut` | Execution |
|------------|-----------|
| Any `pairToken[i]` | Prop remove + **redeposit DETF** + residual consolidate → that pair |
| `vaultShare_i` | Only if SE_i set; **prefer clean share path** (B6 `receiveSeShare` / flexible exit when residual is already shares) |
| Token ∈ SE_i `tokens()` | Only if SE_i set; obtain pair then SE path |
| DETF | **`InvalidRoute`** |
| Else | **`InvalidRoute`** |

**Preview == execution** on every closed-form redeem route.  
**Never burn DETF withdrawn on claim redeem** — only burn claim shares; redeposit self-leg DETF.

**`withdrawSingle` is forbidden** on claim redeem (Q4) — same as primary burn.

---

## 10. Protocol compound & natural expansion (LOCKED)

### 10.1 Compound

| Item | Rule |
|------|------|
| Who | Protocol NFT id 0 pending free DETF only |
| Method | **Single-sided DETF into reserve**: hook `depositSingle(DETF)` when **single-asset eligible** → protocol LP ↑ |
| Claim | **0** new claim shares to protocol |
| Trigger | Lazy on reward-updating touches + public `compoundProtocolRewards()` |
| If not single-asset eligible | **Skip** compounding (do **not** revert). Leave pending DETF. Dual to Orbital Q6; rare after full-book first bond. |
| Failure (join reverts) | Best-effort on lazy paths; public compound may still surface join failure if eligible but join fails — plan freezes |
| User / fee-recipient pending | **Claimable free DETF** while locked — **do not** auto-compound them in v1 |

When rebasing claim is wired: protocol compound **must** increase detf-owned / protocol LP so claim redemption rate **can rise**.

### 10.2 Natural expansion — epoch form (LOCKED Q6)

Identical to CP / Orbital UniV4 DETF peer:

- Policy + live only; Open never expands.
- Deploy-time `expansionEpochLength`, `expansionClosureRatePerYearWad`, `expansionMaxCatchUpEpochs`.
- Resolve defaults: epoch `0` → **8 hours**; `R == 0` → **0.10e18**; `maxCatchUpEpochs == 0` → unlimited.
- Pending debt always in synthetic denominator.
- Realize **only** on bond / claimRewards / compound / bond reward updates.
- Premium-closure O(1) formula using **`S_spot = min(S_spot_0, S_spot_1, S_spot_2)`** then debt-inclusive synthetics for gates (**LOCKED Q21**).
- Accrues while **`allLegsMintRich`** (every external pair’s `syntheticVs(pair_k) > mintThreshold`) at epoch end (**LOCKED Q6**). Open never expands.

Reference tables for launch-rich `R` sizing: **copy CP UniV4 DETF §10.3–§10.4**. Per-leg creation rates are the peg references; the formula input is the **weakest** pair’s `S_spot_k`.

---

## 11. Deploy & PkgArgs (LOCKED)

### 11.1 Deploy sequence (postDeploy spirit)

1. Deploy DETF diamond via vault registry (inert) — **need the diamond address** before hook token sort.
2. From **`PkgArgs`**, sort `{detfToken, pair0, pair1, pair2}` **address-ascending**; align SE / RP slots to that binding order (DETF slot: SE=0, RP=0).
3. Deploy reserve Curve Quad Stable Buffer Hook via registry `deployHookVault`:
   - four tokens in binding order
   - SE slots (1–3 non-zero on external legs only)
   - optional rate providers (only with SE)
   - `baseAmp`
   - poolManager, feeOracle, mineNonce / salt fields
4. Hook **postDeploy** initializes **all six** V4 pair doors (`DYNAMIC_FEE_FLAG`, plumbing sqrtPrice). Permissionless `ensurePairPools` is repair-only.
5. Deploy **shared** bond NFT + rebasing packages (owner=DETF); rebasing is protocol LP holder; **`requireMatureForSell = true`**.
6. Store creation rates (all three), thresholds, mode, expansion params, binding index of DETF, `baseAmp` (view passthrough to hook is enough). **No** `rateAsset` field.
7. Validate: pairs distinct and ≠ DETF; DETF raw only; pair ∈ SE tokens when SE set; SEs distinct when set; RP only with SE; **≥1 SE set**; **all three creation rates `> 0`**; hook `baseAmp` in hook bounds; no FoT/rebasing pairs; decimals in hook [6, 18].

### 11.2 PkgArgs (normative fields)

| Field | Notes |
|-------|--------|
| `pairToken0` / `pairToken1` / `pairToken2` | Three external ERC-20s; pairwise distinct; ≠ DETF; **not** FoT/rebasing |
| `standardExchange0` / `1` / `2` | `address(0)` = bare leg; else SE for that pair; non-zero SEs distinct; **require ≥1 non-zero SE** |
| `rateProvider0` / `1` / `2` | Optional; non-zero only if corresponding SE set; **must** rate shares → that leg’s pairToken |
| `baseAmp` | Passed through to hook; immutable; hook D7 bounds (`0 < baseAmp < 1_000_000`; product guidance \(A \ge 10\)) |
| `poolManager` | Uni V4 PoolManager (or factory immutable — align with hook package) |
| `creationPair0PerDetfWad` / `1` / `2` | First-bond / peg reference (WAD); **all `> 0`** or deploy reverts |
| `thresholdMode`, mint/burn thresholds | Shared `DETFThresholdPolicy` resolve |
| `expansionEpochLength` | Seconds; `0` → 8 hours |
| `expansionClosureRatePerYearWad` | Premium closed per year; `0` → 10%/yr gentle |
| `expansionMaxCatchUpEpochs` | `0` = unlimited |
| Bond NFT / rebasing package refs | Shared common package wiring; **`requireMatureForSell = true`** |
| Hook salt / mineNonce / product binding | Passed through to hook package (`PRODUCT_ID` remains the **hook** type name on the hook salt) |
| Fee oracle | Manager / vault wiring |

**Not used:** listing TWAP seconds; CL width; weight vector (that is Weighted); Orbital sphere params; monomorph CREATE3 hook factory as primary path.

---

## 12. Public surface (normative groups)

| Group | Examples |
|-------|----------|
| **Info** | `isReserveLive`, `syntheticPrice(address pair)` / `syntheticVs(pair)` (**debt-inclusive**), optional `syntheticPriceSpot(pair)`, `pendingExpansionDetf`, thresholds, `isMintingAllowed(pair)` / `isBurningAllowed(pair)`, optional `isAllLegsMintRich()`, creation rates, pairs, SEs, RPs, `baseAmp`, DETF binding index, reserve hook, expansion getters, `isFullBook`. **No** `rateAsset()` |
| **Exchange in** | Mint DETF from any pair / share / SE token; burn free DETF → `tokenOut` ∈ pair legs (+ SE unwrap matrix). Exact-out mint/burn **iff** closed-form (Q15) |
| **Bond** | `bond`, maturity close, `sellPositionToDetfNft` (**mature only**), `claimRewards`, `acceptedBondTokens` |
| **Claim** | Direct deposit paths; redeem claim with `tokenOut` matrix §9.4 |
| **Compound / expansion** | `compoundProtocolRewards` (skip if not single-asset eligible); lazy update on touches |
| **Previews** | Every closed-form execution path exposes a view preview with **preview == execution** (≤ few-wei only if SE dust forces it; document): mint, burn, bond, claim deposit/redeem, maturity close, sell→claim contribution |
| **Errors (stable family)** | `InvalidRoute`; mint/burn not allowed; reserve not live; lock too short; **`BondNotMature`**; min out; **`FirstBondRequiresAllExternalPairs`**; **`LaterBondSinglePairOnly`**; **`NotSingleAssetEligible`**; **`ProtocolLpEmpty`** / insufficient protocol LP; redeposit failure = full revert |

Exact selector layout follows Crane facet split (Info / Exchange / Bonding / …) in the impl plan.

---

## 13. Package layout

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/
    stable/
      quad/
        curve/
          UniswapV4StandardExchangeCurveQuadStableDETF_PRD.md          # this file
          UniswapV4StandardExchangeCurveQuadStableDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # later
          interfaces/
            IUniswapV4StandardExchangeCurveQuadStableDETF.sol
          UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol
          UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol
          UniswapV4StandardExchangeCurveQuadStableDETFCommon.sol
          … Facets / Targets / FactoryService / TestBase
    orbital/                 # process peer — do not subclass
    weighted/                # n>2 / hook-surface peer — do not subclass
    constantProduct/single/  # economics peer — do not subclass
  common/
    nft/      # Uni V4 DETF bond NFT (LP principal) — SHARED
    rebasing/ # claim on protocol hook LP — SHARED
```

**Fresh codepath rule:** do not subclass CP / Orbital / Weighted UniV4 DETF or Balancer Single SE contracts; reuse `detf/common/core/*` libs and shared Uni V4 common packages.

**Suggested type names** (full words, match hook prefix):

| Kind | Name |
|------|------|
| Interface | `IUniswapV4StandardExchangeCurveQuadStableDETF` |
| Diamond package | `UniswapV4StandardExchangeCurveQuadStableDETDFPkg` |
| Facet / Target / Repo | `UniswapV4StandardExchangeCurveQuadStableDETF{Facet,Repo,…}` |
| TestBase | `TestBase_UniswapV4StandardExchangeCurveQuadStableDETF` |
| PRODUCT_ID (DETF pkg salt) | `"UniswapV4StandardExchangeCurveQuadStableDETF"` |

---

## 14. Canonical flows

1. **Deploy** — creation rates, Policy/Open, 1–3 SEs + optional RPs + `baseAmp` via PkgArgs → quad stable hook + six doors, shared bond + rebasing. **No** `rateAsset` arg.
2. **First bond (live)** — permissionless; **all three** pair legs required; mint DETF at creation rates; `joinProportional`; LP on NFT; live=true; excess refunded.
3. **Second+ bonds** — market quote; **no** synthetic mint gate; **single-pair + joinUnbalanced(DETF, pair)**; LP on NFT; realize expansion + rewards.
4. **Primary mint** — any pair → free DETF + protocol LP `depositSingle`; **revert if not single-asset eligible**; debt-inclusive Policy gate; does **not** realize expansion.
5. **Primary burn** — burn **user free DETF only** → `exitProportional` → **redeposit returned DETF** → residual consolidate → chosen pair; effectiveSupply basis. **No** `withdrawSingle`.
6. **Maturity close** — after unlock (optional forever): withdraw LP; redeposit DETF; pay recorded **`capitalToken`**.
7. **Sell bond → claim** — **only after maturity**: LP to protocol; mint claim. Pre-maturity sell **and** early close revert.
8. **Direct claim** — pair/SE or free DETF via `depositSingle`; no seigniorage.
9. **Redeem claim** — burn claim shares; prop remove; **redeposit DETF**; pay pair / share / SE token.
10. **Compound / expansion** — §10 (skip compound if not single-asset eligible).
11. **External swap** — public V4 doors via the quad stable hook (six pairs).

---

## 15. Testing expectations

Production-first (`indexedex-testing`). No mocks of SUT (DETF, hook, manager, registry, fee oracle, attached SEs). Gold TestBase: `CraneTest` → `IndexedexTest` → hook TestBase / family TestBase.

1. Deploy inert; primary mint reverts; non-first bond reverts.
2. Permissionless first bond at creation rates → live; **all three pairs required** (two-pair first bond reverts); mids ≈ creation; MINIMUM_LIQUIDITY edge; excess refund.
3. After first bond only: primary burn reverts (protocol LP empty) until mint/sell/compound.
4. Second bond allowed when live without synthetic gate; **single-pair `joinUnbalanced` succeeds**; multi-pair later bond reverts; primary mint Policy-gated; Open ungated for primary.
5. Synthetic FD via prop remove + **full residual → each pair including DETF self-leg**; per-route mint/burn gates; first bond ungated; all-legs-rich expansion rows.
6. Preview == execution mint/bond/burn/claim/maturity close/sell→claim contribution.
7. Seigniorage split matches peer ratios for same oracle fees; burn applies usage fee; mint quote uses **hook previews** (no DETF-side StableSwap fork).
8. Bond LP on NFT; claimRewards free DETF while locked; pre-maturity **any** principal exit reverts; NFT transferable mid-lock; post-maturity close pays `capitalToken` **or** sell→claim; mature hold indefinite.
9. Claim redeem: each pair, vaultShare (if SE; prefer clean share path), SE token; **returned DETF redeposited**; no `withdrawSingle`.
10. Primary burn: only user free DETF burned; returned DETF redeposited; invalid `tokenOut` → `InvalidRoute`.
11. Protocol compound increases protocol LP when single-asset eligible; **skips without revert** when not (force exceptional path if possible).
12. Natural expansion Policy only; Open never; dual expansion TestBase rows (gentle + launch-rich).
13. Decimal scaling: 6-decimal + 18-decimal pairs.
14. Real quad stable hook package + real SEs; hermetic + fork smoke (Ethereum + Base + 4663 when hook fork DoD applies); no SUT mocks.
15. Config matrix: **1 SE + 2 bare**, **2 SE + 1 bare**, **3 SE** (all required in DoD); **reject all-bare** at deploy; mixed bare+buffered; RP on/off for ≥1 buffered config; reject same SE twice; reject RP without SE; reject DETF in SE tokens; reject creation rate 0; reject `baseAmp` out of hook bounds.
16. Price movement under **default** thresholds via real reserve trades on the six doors + seigniorage dilution.
17. Nested reentrancy → `IsLocked`.
18. Residual free inventory zero on success paths where peers require it (dust policy documented).
19. Six V4 doors swap after live.
20. Primary mint via `depositSingle` each pair leg; mint reverts when not single-asset eligible.
21. Free binding order: at least one TestBase row with DETF **not** at binding index 0 (address sort).
22. `effectiveShares` multi-leg first bond uses open-time DETF valuation via StableSwap mids (not creation rates).
23. Per-route mint-open / burn-open skew rows; `allLegsMintRich` expansion rows.
24. Exact-out mint/burn: ship iff closed-form + preview==exec; else `InvalidRoute`.
25. Adversarial: donation of DETF / SE shares to hook (dilution accepted); protocol-LP-empty burn; redeposit-failure atomicity; early sell→claim; fee-stacking documented.

---

## 16. Differences vs peers

| | UniV4 CP SE DETF | UniV4 Orbital DETF | UniV4 Weighted DETF | **This family (v0.4)** |
|--|------------------|--------------------|---------------------|------------------------|
| Reserve | CP buffer hook (2 currencies) | Orbital SE buffer (3) | Weighted SE buffer (\(n\in[2,8]\)) | **Curve Quad Stable buffer (4)** |
| Curve | Constant product | Sphere \(L^2\) | Weighted math | **StableSwap \(A\)** |
| External legs | 1 pair | 2 pairs | \(m\in[1,7]\) | **3 pairs** |
| Self-leg | DETF raw | DETF raw (any of 3) | DETF raw (any of \(n\)) | **DETF raw (any of 4, address-sorted)** |
| Public doors | 1 | 3 | \(\binom{n}{2}\) | **6** |
| Hook one-token | zap-in; **no zap-out** | zap-in; **no zap-out** | single-asset in **and** out | **single-asset in and out** (+ unbalanced shipped) |
| First bond | pair + DETF | **both** pairs | **all** externals | **all three** pairs |
| Later bonds | family rules | single-leg OK (any subset) | **exactly one** external + minted DETF | **exactly one** (LOCKED Q3) |
| Live primary mint | pair zap-in | either pair zap-in | any pair `depositSingle` | **any of 3** `depositSingle` |
| Primary burn | hook zap-out | prop remove + residual (no hook zap-out) | prop remove; `withdrawSingle` opt. | **prop remove only** (no `withdrawSingle`) |
| Synthetic | FD LP zap-out / creation | FD LP→**one** `rateAsset` | **per-route** pair unit | **per-route** pair unit (LOCKED Q5) |
| Expansion gate | Policy mint-rich | Policy mint-rich | **all-legs-rich** | **all-legs-rich** (LOCKED Q6) |
| Maturity close | family | single **or dual residual** | **always one** `capitalToken` | **always one** (LOCKED Q7) |
| Sell→claim | transitional | **Mature only** (first adopter) | Mature only | **Mature only** |
| Amp / weights | n/a | n/a | weight vector | **`baseAmp`** |
| Quote SoT | family math | sphere math | **hook previews** | **hook previews** |

---

## 17. Dependencies & sequencing

| Order | Work |
|-------|------|
| 1 | Curve Quad Stable Buffer Hook PRD **LOCKED** + ABI frozen (done enough to draft this DETF) |
| 2 | **This DETF PRD** → **LOCKED v0.4** |
| 3 | DETF implementation plan (authorized) |
| 4 | Shared bond NFT + rebasing packages for **LP principal** (already shared with CP / Orbital / Weighted) |
| 5 | DETF DFPkg + tests |

**Hard gate:** DETF package coding **must not** invent hook APIs — only call surfaces from the hook PRD / frozen ABI. If a desired DETF path needs a missing hook selector, **revise the hook PRD** first.

Hook DoD does **not** include this DETF (hook D80). This family may ship after the hook’s hermetic matrix is green; do not block hook completion on DETF work.

---

## 18. Definition of Done (product — after LOCK)

- [ ] Inert deploy; live only via permissionless first bond with **all three** pairs
- [ ] Creation-rate first bond (all three rates `> 0`); mids ≈ creation at join; MINIMUM_LIQUIDITY handled; excess refunded
- [ ] Live mint (any of three pairs) / bond seigniorage split peer-compatible; preview == execution; quotes via **hook SoT**
- [ ] Primary mint reverts when not single-asset eligible; no protocol rebalance API
- [ ] Primary burn burns only user free DETF; usage fee applied; redeposits DETF from remove; pair settlement from protocol LP / effectiveSupply
- [ ] Claim redeem redeposits DETF from remove; tokenOut matrix; InvalidRoute elsewhere
- [ ] Sell→claim and maturity close **revert pre-maturity**; succeed post-maturity; single `capitalToken`; NFT transfer preserves metadata
- [ ] Later bonds single-pair `joinUnbalanced` OK; first bond three-pair required
- [ ] Compound skips when not single-asset eligible (no revert)
- [ ] Policy/Open **per-route** debt-inclusive synthetic with **FD full residual incl. DETF→pair_k**; all-legs-rich expansion; realize only bond/claim/compound
- [ ] PkgArgs deploys hook with **1–3** SEs + optional RPs + `baseAmp` + free DETF binding index; all-bare reverts; **no** `rateAsset` field
- [ ] Burn/redeem never call `withdrawSingle`
- [ ] Exact-out mint/burn shipped iff closed-form; else `InvalidRoute`
- [ ] Shared common bond/rebasing packages; mature-only DETF gate + shared flag true
- [ ] Production-first tests §15 green (hermetic + at least one fork profile)

---

## 19. Threat notes (product-level)

| Risk | Stance |
|------|--------|
| Permissionless first bond sniping / dust | No MEV protection v1; MINIMUM_LIQUIDITY revert; operators choose seed size |
| Donation of raw DETF or SE shares to hook | Synthetic/FD uses whole-reserve extractable value **per pair** (incl. self-leg); native-inventory donations **dilute** LPs (hook D21) |
| Primary burn insolvency | Protocol-LP-only; revert if empty |
| Residual settle impact on burn | User accepts StableSwap impact consolidating two other pairs → tokenOut; previews must include it |
| Redeposit path failure on burn/claim | Full tx reverts after redeposit ladder exhausted |
| Expansion catch-up cliff | Debt-inclusive synthetic; optional maxCatchUpEpochs; high \(R\) intentional for launch-rich |
| Reentrancy via ERC-20 / SE / hook | Family diamond `nonReentrant` / `IsLocked` peer patterns |
| Fee stacking | Documented four layers (curve residual + hook growth + DETF usage + SE); burn usage fee is intentional |
| Partial book | Designed **not** to happen after live; mint/compound revert if it does; **no** protocol rebalance in v1 |
| Distinct SE / bare-leg configs | Deploy validation + matrix coverage |
| Early sell→claim | **Forbidden**; DETF gate + shared flag |
| Like-kind assumption breaks | Per-route gates + all-legs-rich expansion **cover** a depeg (mint may stay open on the rich pair and closed on the cheap one; expansion stops). Mixed-vol still **out** (Q17) — use Weighted / Orbital |
| Amp too low / too high | Hook bounds only; operators own \(A\); DETF does not clamp beyond hook |
| Shared package early-sell drift | DETF-level maturity check is mandatory even if shared flag missing |
| Hook-SoT drift | Forbidding DETF-side StableSwap copies prevents quote/exec skew when hook math is patched |

---

## 20. Clarification lock table (resolved)

Stakeholder answers 2026-08-12. Flip any row in chat before stamping LOCK.

| ID | Topic | Locked value |
|----|--------|--------------|
| **Q1** | First bond capital | **All three** external pairs required (hook first mint requires all four native legs) |
| **Q2** | Live primary mint `tokenIn` | **Any** of the three pairs (or SE-settled capital into that pair) |
| **Q3** | Later bonds | **Exactly one** external pair + protocol-minted DETF via hook `joinUnbalanced` |
| **Q4** | Primary burn path | **Only** `exitProportional` + redeposit DETF + residual. **`withdrawSingle` forbidden** on DETF burn/redeem |
| **Q5** | Synthetic ruler | **Per-route** `syntheticVs(pair_k)` (whole-reserve FD incl. DETF self-leg). **No** whole-DETF `rateAsset` field |
| **Q6** | Expansion mint-rich gate | **All-legs-rich:** every external pair `syntheticVs(pair_k) > mintThreshold` at epoch end. Open never expands |
| **Q7** | Maturity close | **Only the token used to buy the bond.** See Q18 for first bond |
| **Q8** | Bond NFT + rebasing | **Share** `uniswap/v4/common/` with CP / Orbital / Weighted. `requireMatureForSell = true` |
| **Q9** | Rate providers | **Optional** per SE leg; when unset, rated = SE claim. DoD includes RP on/off rows |
| **Q10** | DETF binding index | **Free** among the four address-sorted slots. No fixed index |
| **Q11** | Minimum SEs | **≥1** on an external leg. All-bare deploy **reverts** |
| **Q12** | Quote / FD calculator | **Hook source of truth** (previews only). No DETF-side StableSwap copy |
| **Q13** | First-bond excess | **Refund** unused pair capital after min-implied DETF sizing |
| **Q14** | B6 flexible share flags | Allowed as **optimization** when `tokenIn` is already vaultShare. Default remains pair-face + hook buffer-last |
| **Q15** | Exact-out DETF routes | See Q19 / Q20 |
| **Q16** | Type name vs directory | Type **`UniswapV4StandardExchangeCurveQuadStableDETF`** at path **`…/standardExchange/stable/quad/curve/`** (matches hook) |
| **Q17** | Asset story | **Three like-kind stables only.** Mixed-vol belongs on Weighted or Orbital. Enforcement: Q22 |
| **Q18** | First-bond close token | Caller **picks one of the three funded pairs** as `capitalToken`. Not a three-asset residual basket. Not a PkgArgs default |
| **Q19** | Exact-out meaning | **Exact DETF-out mint** + **exact tokenOut burn**. Not “exact hook LP out.” Ship iff closed-form + preview==exec |
| **Q20** | Exact-out burn settle | **Still** `exitProportional` + redeposit + residual. **Never** hook `withdrawSingle` / `exitSingleAssetExactTokenOut` |
| **Q21** | Expansion formula input | **`S_spot = min(S_spot_0, S_spot_1, S_spot_2)`** once `allLegsMintRich` |
| **Q22** | Like-kind enforcement | **Operator convention only.** No extra deploy check beyond hook token rules (ERC-20, decimals 6–18, not FoT/rebasing) |
| **Q23** | Claim redeem `tokenOut` | **Full matrix** like burn: any of three pairs, vaultShare if SE set (prefer clean share path), or SE.tokens(). DETF face = `InvalidRoute`. Prop-remove + redeposit only |

**Plan-only remaining (not product forks):** frozen in the impl plan — facet cut; storage layout; atomic order of burn-then-remove-then-redeposit; which hook preview inverts for `quoteDetfAgainstReserve` and exact-out; residual sell order of the two non-out pairs; dust thresholds; exact shared-package flag name.

**LOCK-time plan-scope answers (2026-08-12, not Q-table flips):**

| Topic | Answer |
|-------|--------|
| Deposit / mint / bond capital units | **Whatever the reserve hook already accepts as a liquidity deposit.** Pair face always. Vault shares when the hook Flexible path accepts them. Do not invent extra DETF-only capital types. Do not refuse a unit the hook would take. Burn / claim redeem still **must not** call hook `withdrawSingle` (Q4). |
| Exact-out mint / burn | **Phase 0 invert spike** against hook previews. Ship selectors iff closed-form + bit-exact preview==exec. Else `InvalidRoute`. Never binary-search. Never hook `withdrawSingle`. |
| Agent-law / compound inventory | Add this family at LOCK (agent-law families table + shared compound/expansion inventory). |

---

## 21. Canonical user story (illustrative — not a required config)

```text
Binding after address sort (example):
  tokens  = [DAI, DETF, USDC, USDT]     // DETF happened to sort to index 1
  baseAmp = 200
  SE      = [SE_DAI, 0, SE_USDC, 0]     // ≥1 SE; DETF raw
  RP      = [RP_DAI, 0, 0, 0]           // RP only where SE set
  creation* = 1e18 each                 // 1 DETF ≈ 1 of each stable at seed
  // no rateAsset field — synthetic is per-route

Uniswap V4 doors (all 6), fee = DYNAMIC_FEE_FLAG, hooks = reserve hook:
  DAI/DETF, DAI/USDC, DAI/USDT, DETF/USDC, DETF/USDT, USDC/USDT

--- First bond ---
User bonds DAI + USDC + USDT (all > 0), capitalToken = USDC
  → mint join DETF at creation rates (min implied)
  → hook.joinProportional([DAI, DETF, USDC, USDT])
  → LP on bond NFT; live = true; excess refunded

--- Live mint ---
User depositSingle(USDC) on DETF
  → Policy: syntheticVs(USDC) > mintThreshold
  → hook.depositSingle(USDC) deepens protocol LP
  → free DETF to user / feeTo / inventory (no DETF joined)

--- Later bond ---
User bonds USDT only
  → no synthetic gate
  → mint join DETF + hook.joinUnbalanced([0, DETF, 0, USDT])
  → LP on NFT; capitalToken = USDT

--- Burn ---
User burns free DETF → tokenOut = USDC
  → Policy: syntheticVs(USDC) < burnThreshold
  → exitProportional(protocol LP slice) → redeposit DETF → sell DAI+USDT residual → USDC
  → no withdrawSingle
```

---

## 22. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-12 | First draft. Orbital DETF economics + Curve Quad Stable Buffer Hook reserve. Process borrowed from Weighted where the hook surface matches. OPEN Q1–Q17. |
| **v0.2** | 2026-08-12 | Interim: AskQuestion declined → recommended defaults applied (superseded by v0.3). |
| **v0.3** | 2026-08-12 | Round-1 answers applied (Q1–Q17). |
| **v0.4** | 2026-08-12 | Round-2 answers: Q18 first-bond close = pick one funded pair; Q19 exact DETF-out mint + exact tokenOut burn; Q20 exact-out still prop-remove; Q21 min `S_spot_k`; Q22 like-kind convention-only; Q23 claim redeem full matrix. Ready for product LOCK. |
| **LOCKED v0.4** | 2026-08-12 | Product LOCK. No Q1–Q23 flips. Plan-scope: hook-accepted deposit units; exact-out Phase 0 spike; agent-law + compound inventory rows. |

---

## 23. Approval

| Role | Sign-off |
|------|----------|
| Product | **LOCKED v0.4** — 2026-08-12. Q1–Q23 unchanged. |
| Protocol | Pending (implementation plan stamp) |

**Status LOCKED v0.4 — implementation plan authorized.**
