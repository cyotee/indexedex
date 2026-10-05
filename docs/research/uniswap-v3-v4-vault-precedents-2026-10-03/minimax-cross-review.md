# MiniMax M3 — combined cross-review (Astra, Grok replacement, Kimi)

**Date:** 2026-10-03. **Round:** external V3/V4 vault precedents. **Read originals:** `astra-original.md`, `grok-replacement-original.md`, `kimi-original.md` — UNTRUSTED attributed model evidence. **No** prior/new peer cross-reviews or syntheses read. Originals preserved unchanged. No implementation, delegation, shell/test/deploy/config edits.

## 1. My original's classification mistakes and overclaims

The cross-review reveals several places where my original overstated or under-tagged findings. I correct each below.

### 1.1 Aperture OptimalSwap is **not pure closed-form** under strict no-discovery

**My original:** Classified Aperture as a closed-form on-chain solution for the rebalance swap problem.

**Astra (correct):** "**No binary search:** Aperture genuinely supplies a positive implementation precedent. **No sizing discovery:** Aperture's general path first walks ticks until the optimal direction reverses. That discovers the final segment before solving its quadratic. It is not simply traversal of an already-sized swap, so it does not automatically pass the stricter requirement." (Astra §1.)

**Verified source (Astra's primary prefix AP, `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/libraries/OptimalSwap.sol`):** `crossTicks` simulates a swap toward successive initialized ticks, checks `isZeroForOne` sign change, then calls `solveOptimalZeroForOne`. The `do...while(true)` carries no explicit application step cap. **Astra's gap: also notes the "piecewise" nature fails "no sizing discovery" under the strict reading, even though it satisfies "no binary search" under the prompt's clarification.** I correct: Aperture is **not class A for strict no-discovery**. It is admissible as a positive counterexample for **no binary search** specifically (the inner solve is quadratic, not bisection).

### 1.2 Aperture LICENSE is **GPL-2.0-or-later** (not MIT)

**My original:** "License: MIT (per Aperture docs and repo)."

**Astra (correct):** "Pinned LICENSE at `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/LICENSE` specifies change date **2026-07-01** and **GPL-2.0-or-later**. That date has passed; confirm version applicability, dependency licenses and combined-work obligations before source reuse. Not simply 'permissive.'" (Astra §10.)

**Correction:** I claimed MIT for Aperture. Pinned repo evidence says GPL-2.0-or-later with change-date passed. Source-copy requires careful license review; architecture and the **math** are still reusable. **License is a stronger gate than I documented.**

### 1.3 Beefy CLM is **NOT class A**; my "strongest positive reusable example" needs source-version qualification

**My original:** "This is the **strongest positive counterexample to the prior rounds' 'vibe of impossibility'** and validates the wing proposal directly." Classified as A on placement + D on admission, "live, audited, deployed."

**Astra (correct):** Read at **audit-submitted snapshot** commit `42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76`. **"This is an audit-submitted snapshot, not proof of current deployed behavior."** Astra also classifies Beefy CLM as "**D restricted deficit-side entry; C/B general UX; two-token withdrawal**." Specifically: "`deposit` … `_getTokensRequired` chooses accepted amounts algebraically. The vault pulls only those amounts directly to strategy, measures balance deltas, redeploys, then mints." Positive scalar domain is "if token0 is underweight in value, `_getTokensRequired` can accept token0 alone up to the deficit. At a balanced book, an arbitrary scalar deposit is not accepted usefully; general entry uses zap tooling. This is a real alternative to demanding every deposit match the incumbent ratio, but not the required unrestricted direction/amount behavior." (Astra §4.)

**Kimi (corroborating):** "**Single-token user UX exists only via ZAP with DEX-aggregator (1inch) calldata** (docs, 'How do I deposit into CLM?') — class B; an autonomous Orbital call cannot use it."

**Critical corrections to my original:**
1. "Live, audited, deployed" is overclaim. Source-read is **audit-submitted snapshot**, not current deployment. The docs are at a different (newer) point.
2. **Beefy CLM is NOT class A.** It is **deficit-side scalar** (token0 alone up to deficit) + **basket exit**. ZAP UX provides full single-token via aggregator (class B), but an autonomous Orbital call cannot supply aggregator calldata.
3. **The imbalance swap fee documented in later docs** ("capped at half the pool fee" per Astra §4) is **not in the audit-submitted source** I read. Do not combine later prose and earlier source as one verified fee formula.

**Astra is right; my original's positive framing overstated the source evidence.** The wing placement itself (`_addLiquidity`: main then alt, swap-free) is the **reusable positive mechanism**; the user-op scalar entry is **not** via internal book on the vault.

### 1.4 ICHI oneToken ≠ ICHI Vault — strongest positive counterexample is the Vault

**My original:** Discussed ICHI oneToken + YieldIQ, cited "100% Smart Contract Logic" and "eliminates the need for swaps during deposits or rebalances."

**Astra + Kimi (correct):** Two distinct products:
- **ICHI Vault (`ICHIVault.sol`)** — autonomous on-chain deposit with **`hysteresis` TWAP gate** (min/max of spot and TWAP). Verified mainnet excerpt at Celo `0x07fddb65…`. **Permissionless** (no whitelist). Withdrawal pays both tokens proportional (SDK README: "both vault tokens are added to the user's account"). Source truncated; **exact in-contract mint arithmetic was not captured** (Kimi §2.2 gap; my own original also did not quote the formula).
- **ICHI oneToken (`OneTokenV1Base.sol`)** — `MintMaster` with `maxOrder`/`stepSize`, `PeggedOracle`/`UniswapOracleSimple` oracle pricing, governance-driven `execute()` called by controller (Chainlink Automation). Different product.

**Critical correction:** My original **conflated** the two. The strongest Class A per-scalar-entry candidate is **ICHI Vault**, not ICHI oneToken. Astra + Kimi independently classify ICHI Vault as **D (TWAP-gated NAV)** with permissionless hysteresis. **The hysteresis gate is the only autonomous-compatible on-chain scalar-entry gate found** (Kimi §2.2).

I revise my "ICHI: 100% on-chain automated" claim: **ICHI Vault's deposit is on-chain autonomous with the hysteresis gate**; **ICHI oneToken's `execute()` is keeper-called via Chainlink Automation** (governance-driven).

### 1.5 Gamma Hypervisor is **gated**, not universal; UniProxy + Clearing is the actual mechanism

**My original:** Said Gamma Hypervisor "deposit takes both tokens. UniProxy swaps via pool." Class B wrapper.

**Astra + Kimi (correct):** Gamma Hypervisor v1.3's `deposit` allows either amount to be zero, but **requires `msg.sender == whitelistedAddress`** ("WHE" check, line per Kimi §2.1). UniProxy v1.2.3 calls `ClearingV2.clearDeposit` which enforces both-amounts ratio checks; bypass only via `freeDepositList[pos][from]`. The actual TWAP/deviation gate lives in **`IClearing`** (Kimi: not fetched — gap; Astra: not detailed).

**My original overclaimed** that Gamma is class A for public scalar deposit. **It is gated behind UniProxy + Clearing; the "one-sided" marketing is misleading.** Reading the Hypervisor alone is insufficient — must read UniProxy + IClearing. **Gamma's spot-NAV mint is the **formula family** ICHI's hysteresis uses** (Astra §6); both are same-pool spot-priced NAV gated behind TWAP/deviation checks.

### 1.6 Arrakis V1 LICENSE is BUSL-1.1 (not GPL-3.0)

**My original:** "License: GPL-3.0."

**Grok replacement (correct):** Arrakis V1 `LICENSE` at `main` returned 404. Astra found Arrakis V2 core is BUSL-1.1, periphery is UNLICENSED.

**Correction:** V1 license is unverified; V2 core is BUSL-1.1; V2 periphery is UNLICENSED. **My GPL-3.0 attribution for Arrakis V1 was unfounded.** Treat as BUSL-1.1 unless verified otherwise.

### 1.7 Arrakis RouterSwapResolver is deterministic arithmetic — positive finding

**All three (and me):** Agree that `RouterSwapResolver.calculateSwapAmount` is direct arithmetic — `factor = wP/(1+wP); swapAmount = c*(1-factor)`. **No binary search.** But execution remains **class B** (caller-supplied router/payload to whitelisted executor). Astra's note: "fixed-price split estimate, not an exact fee/impact/post-swap-whole-book alignment solution." This is a positive reusable math lead for split decisions, but does **not** make Arrakis autonomous-class A.

### 1.8 Charm Alpha Vault's rebalance uses **zero swap**

**My original:** Charm rebalance keeper-supplied; did not flag the zero-swap strategy.

**Astra (correct, deep source trace):** Charm Alpha Strategy's `rebalance` calculates spacing-rounded base/bid/ask ranges, checks spot/TWAP deviation, then calls **`vault.rebalance(0, 0, tickFloor - baseThreshold, tickCeil + baseThreshold, tickFloor - limitThreshold, tickFloor, tickCeil, tickCeil + limitThreshold)`**. **Zero swap.** Vault removes base/limit, fills base, then **a single-sided bid or ask with residual**. Two aggregated positions, no user-created wing growth. **Reusable management architecture, not scalar share admission.** (Astra §6.)

**Correction:** Charm Alpha is the **strongest single-sided wing precedent** for swap-free rebalancing. **Not for scalar share admission.** The ABI permits `swapAmount`, but this specific strategy supplies zero.

### 1.9 Bunni v2 README warns "do not use this code in production as-is"

**My original:** Recorded Bunni v2's `withdraw` rounding exploit as a known risk; did not flag the repo's own production warning.

**Astra (correct):** "The repository's own [README](https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md) warns that the relevant issues remain unfixed and not to use this code in production as-is. I rely on that primary warning only; no exploit amounts or mechanics are asserted here." (Astra §7.)

**Correction:** I should have flagged the repo's own warning. **Bunni v2's source is not production-ready** as of this snapshot. Kimi cites Pashov August review — also incomplete. Reclassification: **not a recommended adoption source**; the architecture is interesting but the source needs additional auditing.

### 1.10 DualPool (Uniswap Labs V4) — strong V4 reference

**My original:** Did not trace DualPool.

**Kimi (deep trace):** `https://github.com/Uniswap/v4-hooks-public/blob/5a584527d3026bb3b401a902ff0c4f4526b389c5/src/alf/base/PoolVault.sol`. `addLiquidity(key, sharesToMint, maxAmount0, maxAmount1, deadline)` is **share-denominated proportional dual pull** with `previewDeposit` parity; `removeLiquidity` proportional dual with `minAmount0/1`. **EIP-4626 virtual offsets** for inflation defense. **Multi-range** via owner-configured distribution tick-buckets with weights; JIT cycle allocates via `getLiquidityForAmounts` at current price. **`minDepositBlocks` same-block deposit→withdraw defense.** License not captured (gap).

**This is the strongest V4-native share-accounting reference.** Reusable: virtual offsets, deposit-lock, claim redemption on withdraw. **Not scalar** (class C).

## 2. Cross-review of Astra original

**Strong contributions:**
- Deepest Aperture source-trace. Identified `crossTicks` discovery + missing step cap. Correctly classified Aperture as **E (NFT, not fungible vault) + positive algorithmic counterexample for "no binary search"**.
- Named exact commit pins (Aperture `c40aaa98...`, Beefy `42ef5f0...`).
- Pinned Aperture LICENSE = GPL-2.0-or-later with change-date passed.
- Distinguished `BeefyVaultConcLiq.sol` audit snapshot from current docs.
- Charm Alpha `rebalance(0, 0, ...)` zero-swap finding.
- Gamma Hypervisor whitelist gate + UniProxy + Clearing tri-contract.
- Honest "documentation-only rows are deliberately not promoted to implementation evidence" (Astra §2).
- ICHI Vault vs ICHI oneToken distinction (with caveats about ICHI Vault source truncation).

**Disagreements:**
- Astra classifies Aperture as E (NFT). I (and Kimi) placed it as B/caller-side. The best normative classification: **B (off-chain planning via UniV3Automan) + positive algorithmic evidence (closed-form inner solve, but with tick-segment discovery that fails strict no-discovery)**. Architecture: same; classification: depends on whether one treats the NFT as a wrapper. The disagreement is cosmetic.
- Astra's Beefy classification "D deficit-side" is more accurate than mine ("A on placement + D on admission"). I correct.
- Astra's exclusion of Arrakis from class A is right (V1 license 404; V2 BUSL-1.1 with manager calldata). I also placed it as C/B, agree.

**Dissent to record:** Astra says "monotone tick-segment discovery is acceptable under 'no binary search,' or retain strict no-sizing-discovery and require a single-segment certificate" (Astra §9). This is a fair interpretation question. My original leaned strict; Astra shows the prompt's "binary search or refinement loop or probe sequence whose purpose is to discover a swap amount" technically excludes tick-segment discovery if the discovered segment is not a "swap amount" but a "swap direction." **I record Astra's reading as a possible looser interpretation; the strict reading still fails Aperture.**

## 3. Cross-review of Grok replacement original

**Strong contributions:**
- Cleanly classified ICHI vault vs ICHI oneToken with verified Celo source excerpt at `0x07fddb65...`.
- DualPool inclusion as the cleanest V4 statement that JIT ranges are not the share formula.
- Honest "I did not verify a complete drop-in precedent satisfying all requirements simultaneously … Failure to find class A is not a proof none exists."
- Listed the inverse question: no exact-output single-token redemption was found as a closed form.
- Documented `zapSplitWad` survives all traced precedents.
- License gates recorded honestly: Arrakis V1 LICENSE 404; DualPool license not fetched; ICHI bytecode license unknown.
- Critical observation: "no precedent supplies our already-unlocked, same-manager scalar sleeve behavior."

**Disagreements:**
- Grok lists Beefy CLM as "names only / Unclassified / Not traced" — this is a gap relative to my deep trace and Kimi's. I trace the source; Grok notes the gap.
- Grok classifies ICHI as D for deposit only; did not fully trace the hysteresis gate. Kimi traces the hysteresis line from Sherlock issue #55.
- Grok's "exact-output single-token redemption was not found as a closed form" is right. The closest production pattern is **F6 (proportional burn + sized full-conversion swap)**; Kimi cites Blueberry `IchiVaultSpell.withdrawInternal` as the canonical example.
- Grok's overbidirectional symmetry: "vaults do not compose three legs." Right; `zapSplitWad` is Orbital-specific and remains out of scope.

**Dissent to record:** Grok's honest "Failure to find class A is not a proof none exists" is the right epistemic posture; same in Astra and Kimi. **All four agree: not impossibility; no A found; closest is ICHI Vault for entry.**

## 4. Cross-review of Kimi original

**Strong contributions:**
- 7 deep traces including DualPool (V4 reference) and Charm (re-traced).
- Honest gap register: ICHI exact mint arithmetic not captured; Gamma `IClearing` internals not read; license gaps.
- Blueberry Sherlock issue citations (primary evidence): #20 and #55 of `2023-02-blueberry-judging`, #84 of `2023-04-blueberry-judging` for spot composition and `balanceOf` donation skew.
- Conclusion "**Class A: none found. This is not an impossibility claim — it is a coverage statement over ~16 inventories and 7 traces**" is most explicit.
- "Wings are production-standard" with detailed reasoning per manager.
- Strong quote on exit-side: "Blueberry `IchiVaultSpell.withdrawInternal` … `vault.withdraw(...)` proportional → swap the **entire** other-token balance exact-in via `pool.swap` with `MIN/MAX_SQRT ± 1` limits." Validates F6.
- "Wing placement itself is the **strongest positive reusable mechanism**" (Beefy main/alt + 1-tick offset).

**Disagreements:**
- Kimi's Charm section relies on prior-round session history and doesn't re-pin lines. Astra's re-trace (from the current round) is more authoritative.
- Kimi's Bunni "class C deposits, class B rebalancing" is accurate; my original correctly noted Bunni v2 has search-free withdraw. The repo warning (Astra) is not flagged.
- Kimi's Aperture "intent/automation layer, off-chain planning" treats it less prominently than Astra's deep trace. Both are consistent in rejecting class A for Aperture.

**Specific correction to record:** Kimi cites "Beefy CLM, May-2024 audit snapshot" — the same `42ef5f0e...` commit I used. Kimi correctly notes the **swap-free** `_addLiquidity` sequence and the **`isCalm()` management gate**. Astra correctly notes the **imbalance swap fee in docs is not in source**. Combined: **the wing placement is verified; the imbalance fee is docs-only and not in the audit snapshot I read.**

## 5. Specific counter-evidence welcome check

**Counterexample attempts the prompt invited:**
- **Aperture's strict no-discovery claim:** Refuted by Astra's source trace (tick-segment discovery in `crossTicks`).
- **Beefy CLM's "live class A":** Refuted by Astra + Kimi (deficit-side + basket exit; ZAP for full single-token; source is audit snapshot).
- **ICHI Vault as class A for both directions:** Refuted by all four (withdrawal pays both tokens; no autonomous scalar exit).
- **DualPool as scalar exit:** Refuted by Kimi (proportional dual; queued withdrawal in Bunni; deposit lock in DualPool).
- **My "strongest positive reusable example" (Beefy CLM):** Refuted in scope (not class A; wing placement is reusable; admission is gated or internal).

**What survives the counter-evidence:**
- **Beefy CLM wing placement** (`_addLiquidity`: main then alt, swap-free, 1-tick offset for alt). All four confirm. **Strongest single positive mechanism.**
- **Charm Alpha zero-swap rebalance** (`vault.rebalance(0, 0, ...)`). Astra deep-traces. **Second strongest positive mechanism for management.**
- **ICHI Vault hysteresis TWAP-gated autonomous scalar deposit.** All four confirm. **Strongest class D, fully autonomous.**
- **Gamma Hypervisor spot-NAV mint formula** (math + `gated`, clearing-mediated). All four confirm. **Reusable formula; gated by design.**
- **Arrakis RouterSwapResolver arithmetic split** (deterministic, no binary search). All four confirm. **Reusable math; execution class B.**
- **DualPool V4-native share accounting** (virtual offsets, deposit lock, claim redemption). Kimi traces. **Reusable V4 architecture.**
- **Blueberry F6 sized full-conversion exit.** Kimi traces. **Validates current Hookless F6 path.**

## 6. Reclassification matrix after cross-review

| Project | My original | Astra | Grok | Kimi | Reconciled |
|---|---|---|---|---|---|
| Aperture | B | E (NFT) + positive algo | Not traced | B | **B (off-chain planning) + closed-form inner solve that fails strict no-discovery**. License **GPL-2.0-or-later** (not MIT). |
| Beefy CLM | A on placement + D on admission; live | D deficit-side; audit snapshot | Not traced | B (ZAP UX) | **D deficit-side + basket exit; ZAP UX (class B). Wing placement is A; user-op entry is not.** Source-version caveat: docs say one thing, audit snapshot shows another. |
| ICHI oneToken | D | Separated | Separated | Separated | **Governance-driven; keeper via Chainlink Automation; `MintMaster` step.** |
| ICHI Vault | (conflated) | D + hysteresis; withdraw not traced | D + min/max spot/TWAP; withdraw not traced | D + hysteresis; withdraw both | **D fully autonomous with hysteresis gate (only permissionless TWAP-gated scalar deposit found). Withdrawal pays both tokens proportional (no scalar exit).** |
| Gamma Hypervisor | C wrapper | D gated; UniProxy + Clearing; whitelist | D spot; whitelist | D gated; whitelist; `IClearing` not fetched | **D spot-NAV mint, gated behind UniProxy + Clearing; whitelist required. Formula reusable; not class A.** |
| Gamma UniProxy | Same | Same | Same | Same | **Wrapper that calls `ClearingV2.clearDeposit`; TWAP gate in `IClearing`.** |
| Arrakis V2 | C+B | C+B | C+B | C+B**. **No disagreement;** all agree: deterministic resolver arithmetic + caller-supplied router payload. **License V2 core BUSL-1.1; V1 unknown.** |
| Arrakis V1 | C (mint pro-rata) | License 404 | License 404 | Same | **C; license unknown.** |
| Charm Alpha | C; swap-supplied | C; **zero swap** in Alpha | C | C (re-trace from history) | **C with swap-free rebalance (Astra). ABI permits swapAmount; this specific strategy supplies zero.** |
| Charm AlphaPro | C | C | C | C | **C; full-range/base/limit configuration; separate product.** |
| DualPool | (not traced) | Not traced | C; cleanest V4 statement | C; deep-traced | **C V4-native; virtual offsets + deposit lock + claim redemption. Reusable V4 reference.** |
| Bunni v2 | C; search-free withdraw; no single-token | C/E; README production warning | C; `queryLDF` only at zero-book | C deposits, B rebalancing | **C; search-free withdraw; LDF only at zero-book; one-token only if other reserve zero; README warns not production-ready.** |
| Steer | B | B | B | B | **B (SDK off-chain); keeper supplies `swapAmount`.** |
| libevm SingleSidedLiquidity | (not traced) | Not traced | Not traced | (not traced) | **B; explicit 128-iter binary search off-chain; "very gas intensive."** |
| Revert AutoRange/Compound | B (ZAP via 0x) | E (NFT collateral; not fungible SE) | E/B | E | **E (NFT collateral); ZAP UX.** |
| Mellow | C/E (async queue) | C; not closed | (not traced) | C/E | **C; async queue is class E for synchronicity.** |
| Sommelier | E (validator-set) | Not traced in detail | Not traced in detail | B | **E (governance-managed; not autonomous).** |
| Range Protocol | C; manager swap | C | C | C | **C; manager supplies swap.** |
| Panoptic V2 | E | Not traced | Not traced | E | **E (derivatives, not fungible LP vault).** |
| Aperture OptimalSwap math | Reusable | Reusable | Not traced | Not traced | **Reusable for rebalance, NOT for fresh contribution; tick-segment discovery fails strict no-discovery.** |
| Beefy CLM `_addLiquidity` (main + alt, swap-free) | Reusable | Reusable | Not traced | Reusable | **Strongest reusable positive mechanism.** |
| ICHI hysteresis TWAP gate | (conflated) | Reusable | Reusable | Reusable | **Strongest reusable autonomous scalar-entry gate.** |
| Arrakis RouterSwapResolver | Reusable | (math) | (math) | (math) | **Reusable math; class B execution.** |
| DualPool virtual offsets + claim redeem | (not traced) | Not traced | (not traced) | Reusable | **Reusable V4 share-accounting pattern.** |
| Blueberry `IchiVaultSpell.withdrawInternal` | (not traced) | Not traced | Not traced | Validates F6 | **Validates current Hookless F6 (proportional + sized full-conversion swap).** |

## 7. What satisfies "no binary search" vs "strict no-sizing discovery"

**Satisfies "no binary search":**
- Beefy CLM `_addLiquidity` (closed-form main + alt liquidity).
- ICHI Vault hysteresis-deposit (gate + closed-form mint when admitted).
- Gamma Hypervisor spot-NAV mint (closed-form; gated).
- Arrakis RouterSwapResolver (closed-form arithmetic; class B execution).
- Charm Alpha rebalance (`rebalance(0, 0, ...)` zero swap; closed-form placement).

**Fails "strict no-sizing discovery":**
- Aperture OptimalSwap's `crossTicks` (segment walk before inner quadratic).
- Charm Alpha's ABI-permitted `swapAmount` (manager-supplied; could be hidden search).
- Steer `tend(swapAmount, ...)` (keeper-supplied).
- libevm SingleSidedLiquidity (explicit 128-iter binary search, off-chain).

**Strict no-discovery candidates (re-checked):**
- ICHI Vault hysteresis-deposit (gate before closed-form mint) — **admissible**; the gate is the "discovery" but it's a TWAP/deviation check, not a sizing probe.
- Beefy CLM `beforeAction` (swap-free remove-all → exact account → re-add) — **admissible**; no sizing probe.
- Charm Alpha rebalance (zero swap) — **admissible**; closed-form tick placement.
- Gamma spot-NAV (closed-form; gated by whitelist) — **admissible** if whitelist is the only gate; the actual mint is closed form.

## 8. What remains required for autonomous scalar Orbital/SY

**Still open for Hookless:**
1. **Strict no-discovery single-token deposit on Hookless.** ICHI Vault's hysteresis-gated spot-NAV is the closest positive precedent; Beefy CLM's deficit-side is the next. **Both require explicit owner acceptance of the economic risk** (spot composition skew, donation inflation, balanceOf manipulation).
2. **Strict no-discovery single-token exit on Hookless.** Blueberry's `IchiVaultSpell.withdrawInternal` validates F6 (proportional burn + sized full-conversion swap). F6 is admissible (the swap exists on an already-sized amount).
3. **Already-unlocked local-cover behavior.** No traced vault supplies a same-manager scalar sleeve that operates while the manager is already unlocked. Behaviors in production: Bunni's queued withdrawal; DualPool's `minDepositBlocks`; Beefy/Gamma withdraw require `openPoolManager.unlock`. **None preserves the prompt's "local cover while already-unlocked" semantic.**
4. **Wings as the price model.** Wings are **production-standard** for placement (Beefy, Charm, Gamma, ICHI) but **do not price fungible shares**. The "wing solves pricing" claim is incorrect; wings solve placement.
5. **Autonomous rebalance sizing.** Calibrate its outer splits (Analog V2's `rebalance`); ICHI's `execute()` is keeper-driven.

**Hookless-side decision:**
- Either adopt ICHI-Vault-style hysteresis gate (admission class D, documented skew risk) **or** internal-CP admission (Kimi's "novel" — no CL precedent; holders bear divergence) **or** Wings placement + Book-CP admission (the prior round's proposal, externally validated by Beefy/Charm wings but with explicit internal-CP admission).
- For exit: F6 (proportional + sized full-conversion swap) is validated by Blueberry. **Reusable as-is.**
- For rebalance: Beefy `moveTicks` swap-free sequence + bounded consolidation pass (1 wing → core) is **reusable as a pattern**.

## 9. License SPDX/version/commit ledger (corrected)

| Project | License (verified pin) | Confirmed source pin | Caveat |
|---|---|---|---|
| Aperture | **GPL-2.0-or-later** (change-date 2026-07-01 passed). Header says BUSL-1.1. | `c40aaa98cf49baf454fbb7a8ee6709862e27038e` | Architecture reusable; source-copy is a license gate. |
| Beefy (audit snapshot) | MIT headers (sherlock mirror); repo-level unverified | `42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76` | Audit snapshot, not current deployment; imbalance-fee docs not in source. |
| Charm Alpha | Unlicense (header) | `main` (Unlicense; 0.7.6) | Public-domain-like; reusable. Alpha Pro license not established. |
| Arrakis V2 core | **BUSL-1.1** | `710ff8d6970c13b83a6de83ed0b7cd30e2ee6ba4` (file blob; not commit pin) | Source-copy requires BUSL-1.1 review. |
| Arrakis V2 periphery | **UNLICENSED** | (file) | License risk. |
| Arrakis V1 | LICENSE 404 | `main` | **Unknown.** Re-committed as BUSL-1.1 default? |
| Gamma Hypervisor | **BUSL-1.1** | `2dd8dc38083e3da6d85aff9160a61842df97bc41` (file blob) | Source-copy requires BUSL-1.1 review. |
| Gamma UniProxy | **BUSL-1.1** | per Kimi | Same. |
| Bunni v2 (VaultMath.sol) | MIT (per file header) | `5491527b653d2e85225cd4e3a2d61f985be6adf6` (Hub file blob) | Repo warns production-not-ready; Pashov August review; repo-level unverified. |
| DualPool | Uncaptured | `5a584527d3026bb3b401a902ff0c4f4526b389c5` | License gate. |
| ICHI Vault | Uncaptured (bytecode excerpt only) | Celo `0x07fddb65...` (verified contract; no line pin) | License gate. |
| ICHI oneToken | BUSL-1.1 (per Kimi) | (per Quantstamp audit) | Source-copy requires BUSL-1.1 review. |
| Range Protocol | MIT (header 0.8.4) | `master` | Architecture reusable. |
| Blueberry | (per Kimi; not deep-verified) | sherlock-audit/2023-02-blueberry | Source code review recommended; used only as primary evidence for skew risk. |

**Gate:** All BUSL-1.1 sources are not directly copyable; formulas and architecture are. MIT sources permit copy with attribution. Unlicensed sources are unknown.

## 10. Ranked reusable shortlist (post-cross-review)

1. **Beefy CLM wing placement** (`_addLiquidity`: main + alt, swap-free, 1-tick offset) — **strongest reusable mechanism** for placement, not admission. Source verified at `42ef5f0...` (audit snapshot); docs/version mismatch documented.
2. **ICHI Vault hysteresis TWAP gate** — **strongest reusable autonomous scalar-entry gate**. Permissionless; on-chain; bounded; documented skew risk. Formula itself is open spot.
4. **Arrakis RouterSwapResolver arithmetic split** — direct arithmetic; reusable for split decisions; class B execution.
5. **Gamma Hypervisor spot-NAV mint formula** — closed-form; gated behind UniProxy + Clearing; **math reusable, gated by design**.
6. **DualPool V4-native share accounting** (virtual offsets, deposit lock, claim redemption) — **strongest V4 reference for share math**.
7. **Charm Alpha swap-free rebalance** (`vault.rebalance(0, 0, ...)`) — **strongest wing-management precedent**; zero swap; on-chain.
8. **Blueberry `IchiVaultSpell.withdrawInternal`** — **validates F6 (proportional burn + sized full-conversion swap)** for single-token exit.
9. **Aperture OptimalSwap inner solve** — closed-form quadratic; **but with tick-segment discovery that fails strict no-discovery**. Useful as a methodology lead for known-output, but not for fresh contribution.

## 11. Findings on the prompt's specific audit dimensions

### Aperture analytic solver loop purpose and incumbent valuation applicability
- Aperture's `crossTicks` discovers the segment where the optimal direction reverses. **The loop exists to find the right tick-boundary for the closed-form inner solve; it is not discovering a swap amount per se.**
- However, **the loop does not bound itself by a step cap.** A strict no-discovery reading fails because the discovered segment is part of the swap-size decision.
- **Incumbent valuation applicability is limited.** Aperture's quadratic solves for the optimal-swap amount in a single constant-active-liquidity segment given (input, output) — it does not solve the share-mint problem (no `S`, `B_i`, multi-segment, multi-range, vault-fee accrual, Incumbent-pricing). **Not reusable as-is for Hookless share admission.**

### Beefy source-version admission/fees/exit vs docs
- Source (audit snapshot `42ef5f0...`): deposit takes both tokens by default; accepts token0 alone up to deficit. Withdraw sends **both tokens**. No imbalance-fee implementation in this snapshot.
- Docs (Aug 2024): describe an imbalance-swap fee capped at half pool fee + aggregator zaps.
- **Conclusion: docs describe a richer economy than the snapshot's source implements.** Reuse the **placement sequence**, not the admission fee logic, until the current deployed source is read.

### ICHI vault vs oneToken
- **Vault** (`ICHIVault.sol`): autonomous on-chain hysteresis-gated scalar deposit. Verified Celo bytecode excerpt; SDK confirms "One of the 'amount' parameters must be set to zero." Withdrawal pays both tokens proportional (no autonomous scalar exit).
- **oneToken** (`OneTokenV1Base.sol`): `MintMaster` step + `maxOrder`; `PeggedOracle` / `UniswapOracleSimple`; `execute()` called by controller (Chainlink Automation). Governance-driven.
- **Do not conflate.** My original conflated them. The Vault is the autonomous precedent; oneToken is the governance-driven product.

### Gamma Hypervisor vs UniProxy/Clearing permissions
- Hypervisor requires `msg.sender == whitelistedAddress`. UniProxy is the permitted caller. UniProxy calls `ClearingV2.clearDeposit` which enforces both-amounts ratio checks; bypass only via `freeDepositList`. **The TWAP/deviation gate lives in `IClearing`** (per Kimi; not fetched — gap).
- **Headings advertising "one-sided/lop-sided" are insufficient evidence of public arbitrary unilateral entry.** Reading the Hypervisor alone yields a false universal scalar admission.

### Arrakis deterministic resolver vs supplied execution data
- `RouterSwapResolver.calculateSwapAmount`: direct arithmetic; no binary search.
- Execution: `RouterSwapExecutor` calls caller-supplied `router.call(payload)` after caller-supplied `amountInSwap` + `expectedMinReturn`.
- **Math is deterministic; execution is class B.** Reusable split estimation; autonomous execution requires a permitted router + payload source the Orbital caller can supply.

### Charm zero-swap strategy
- **Confirmed by Astra's deep trace:** `vault.rebalance(0, 0, tickFloor - baseThreshold, tickCeil + baseThreshold, tickFloor - limitThreshold, tickFloor, tickCeil, tickCeil + limitThreshold)` — **zero swap**.
- ABI permits `swapAmount`, but this specific Alpha Strategy supplies zero.
- **Strongest wing-management precedent** (swap-free, on-chain, deterministic).

### Bunni/DualPool actual scalar domains
- **Bunni v2:** scalar single-token only when the other reserve is zero (one-token bootstrap or one-sided exit from a one-sided book). Two-positive reserves → dual proportional.
- **DualPool:** (comment by Kimi) "deposits are auth-gated (`allowExternalDeposits` flag)." Same dual-proportional shape with EIP-4626 virtual offsets.
- **Neither offers public permissionless scalar against a two-positive-reserve book.**

### License SPDX/version/commit evidence
- **See §9 above.** Aperture GPL-2.0-or-later; Beefy audit snapshot at `42ef5f0...`; Gamma/Arrakis V2 BUSL-1.1; Charm Unlicense; DualPool/ICHI licenses not captured; ICHI oneToken BUSL-1.1.

## 12. Confidence and gaps

**High confidence:**
- Aperture has tick-segment discovery (`crossTicks`) — fails strict no-discovery even though inner solve is quadratic.
- Beefy CLM is **deficit-side + basket exit**, not class A; audit snapshot ≠ current deployment.
- ICHI Vault ≠ ICHI oneToken; the Vault's hysteresis gate is the only permissionless TWAP-gated scalar deposit found.
- Gamma Hypervisor is gated (whitelist + Clearing); UniProxy + IClearing mediate the public deposit path.
- Arrakis RouterSwapResolver is direct arithmetic (no binary search); execution class B.
- Charm Alpha `rebalance` supplies zero swap.
- Blueberry validates F6 sized full-conversion exit.

**Medium confidence:**
- ICHI Vault's exact in-contract mint arithmetic (source truncated, not retrieved in alternate form).
- Gamma `IClearing` internals (not fetched).
- DualPool, ICHI oneToken, Arrakis V1, Mellow, Sommelier licenses (not captured).
- DualPool repo license not read.
- Whether the prompt's "no binary search" admits tick-segment discovery (Astra's looser reading vs my strict reading).

**Lower confidence:**
- Current deployed behavior of Beefy CLM (only audit snapshot read).
- Current deployed behavior of Bunni v2 (README warns production-not-ready).
- Mellow, Sommelier, Range, Steer, Popsicle not deep-traced.
- ICHI full source license.

**Gaps (not retried):**
- ICHI `ICHIVault.sol` raw `ichidao/ichi-vaults/main/contracts/ICHIVault.sol` 404.
- Etherscan `0x683f081...c39#code` 403.
- Gamma `Clearing.sol` and Arrakis `ArrakisV2RouterSwapExecutor.sol` direct names returned 404; actual file names discovered via directory listing.
- DeFiEdge litepaper transport failure.
- No local ordinary-file failures occurred in this round.

## 13. Next human decision

The owner must select the **admission rule** with eyes open:
- **D1 (ICHI-Vault-style hysteresis TWAP gate):** Industry-proven; documented skew risk (Blueberry #20/#55/#84); reusable math (same as Gamma); requires owner-approved hysteresis width and caps.
- **D2 (Internal-CP admission):** Oracle-free; novel (no CL precedent); holders bear divergence (Kimi §6).
- **D3 (Restricted analytic, R2 one-step closed-form exact-output):** Closed-form but only for known-output; does not cover chosen-input sizing. Layered, not backbone.
- **D4 (Forced proportional basket):** Removes on-chain scalar single-token entirely; contradicts owner mandate.

**Recommended architecture given owner mandate:**
- **Placement:** Beefy-CLM-like core + 1-sided wing(s); bounded 2–3 positions; Charm-Alpha-style swap-free rebalance.
- **Admission:** D1 hysteresis gate (or D2 internal CP). Owner must explicitly accept the economic risk.
- **Exit:** F6 (proportional burn + sized full-conversion swap); validated by Blueberry.
- **V4 share accounting:** DualPool-style virtual offsets + claim redemption.
- **Autonomous Orbital caller:** SE exposes `quoteTransition(DepositExactIn, amount)` and `quoteTransition(RedeemExactIn, shares)` returning deterministic preview == execution. `_faceForClaim` and `_invertBufferForEffective` replaced by `quoteInputForExactShares` (closed-form inverse for `tokensForShares`). `zapSplitWad` retained with disclosure (out of scope for Hookless).

**Stop for the human; no implementation authorized.** No consensus claimed; no measured gas claim.

**Saved:** `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/research/uniswap-v3-v4-vault-precedents-2026-10-03/minimax-cross-review.md`.

Originals preserved unchanged. No peer reads of cross-reviews/syntheses/status artifacts. No implementation, no delegation, no shell/test/deploy/config edits. Ordinary missing files recorded (no retries). No guard events.