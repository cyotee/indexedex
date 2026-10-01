# Cross-review — Static-Fee Pool Policy (Uniswap V4 FullSpread)

Reviewer: MiniMax M3 (independent cross-review; no peer cross-review artifacts read)
Date / access date: 2026-09-27
Scope: verify seven specific claims across the three originals (Astra, Grok, Kimi) and my own original; identify consensus / dissent / corrections; recommended policy for the human.

**Saved path:** `docs/research/uniswap-v4-static-fee-policy-2026-09-27/minimax-cross-review.md` (this file)
**Preserved unchanged:** `docs/research/uniswap-v4-static-fee-policy-2026-09-27/minimax-original.md`

---

## 1. Behavior matrix (verified against NEW FullSpread code and primary sources)

| Claim | MiniMax M3 | Astra | Grok | Kimi | Source-verified state |
|---|---|---|---|---|---|
| Vault reads configured `poolKey.fee` | YES (`_fee()`, PoolKeyAwareRepo:70-76) | YES | YES | YES | read-only getter; not consumed in any math path (verified) |
| Vault reads live `lpFee` + `protocolFee` via `_slot0()` | YES (Common:432-434 destructures both) | YES (cites StateLibrary:34-66) | YES (Common:432-433) | YES (Common:432-434) | live values destructured but NOT consumed by FullSpread math (verified) |
| Existing quoter DOES include protocol fee in previews | YES | YES (with explicit formula) | YES | YES | UniswapV4Quoter._loadQuotePool reads live `protocolFees` + `lpFee` and applies `ProtocolFeeLibrary.calculateSwapFee` per direction (UniswapV4Quoter.sol:196-212; ProtocolFeeLibrary.sol:39-47) |
| Current code rejects dynamic-fee pools at deployment | NO (gap) | NO (cites DFPkg:257-265, 271-298, 333-336) | NO (cites DFPkg.sol:257-264, 286) | NO (cites DFPkg.sol:271-298) | All four originals agree — gap exists in `initAccount` |
| Static fee immutable for pool lifetime | TRUE (R1+) | TRUE | TRUE | TRUE | `PoolManager.updateDynamicLPFee` reverts unless dynamic key + hook caller (cites PoolManager.sol:288-294/295 per Kimi) |
| `OVERRIDE_FEE_FLAG` per-swap requires dynamic key | TRUE | TRUE | TRUE | TRUE | `Hooks.beforeSwap` line 265: `if (key.fee.isDynamicFee()) lpFeeOverride = result.parseFee()` (Hooks.sol:265) — verified |
| `BEFORE_SWAP_RETURNS_DELTA_FLAG` / `AFTER_SWAP_RETURNS_DELTA_FLAG` apply on static pools | TRUE | TRUE | TRUE | TRUE | Hooks.sol:268-281 (beforeSwap), Hooks.sol:302-307 (afterSwap) — neither gates on `isDynamicFee()` (verified) |
| Max LP fee 1,000,000 pips = 100% is **valid** for `isValid` | TRUE (LPFeeLibrary.isValid) | FALSE (Astra recommends reject 100% fee) | implicit TRUE | TRUE | Dissent on Astra (see §3) |
| Pons V2 uses STATIC fee, not dynamic | TRUE (`PONS_V2_POOL_FEE = 0`, `TestBase_..._PonsV2.sol:66`) | implied but not explicit | not explicit | stated (Pons V2 launch schema) | Pons V2 affected by 100% boundary differently; verified at `test/foundry/spec/protocols/dexes/uniswap/v4/pons/.../UniswapV4StandardExchange_PonsV2Pool_Decimals.sol:62` |
| Orbital/Weighted IndexedEx hooks use **dynamic** fee `0x800000` | TRUE (verified grep — 6 files use `fee: LPFeeLibrary.DYNAMIC_FEE_FLAG`) | implied | not explicit | TRUE (Kimi §1.4) | Confirmed: `contracts/hooks/uniswap/v4/orbital/...PairPoolLib.sol:32`, `.../weighted/...PairPoolLib.sol:62`, plus 4 BeforeInitialize libs asserting equality at line 30/31 |
| Same-transaction protocol-fee change possible | TRUE | TRUE (cites ProtocolFees.sol:28-39) | TRUE | TRUE (cited `protocolFeeController`) | `ProtocolFees.setProtocolFee` (lines 33-40) does not require PoolManager unlock; controller can call mid-flight between preview and execution (verified) |

---

## 2. Corrections to my own original (driven by direct verification)

| Original claim | Verified state | Correction with file:line evidence |
|---|---|---|
| I said "live lpFee in FullSpread code is captured but never used" | TRUE | UNCHANGED, but I missed that **deployment-time `slot0.lpFee == poolKey.fee`** check (Grok R1, Kimi R3) is a deeper belt-and-suspenders — should be added. |
| I said "Pons excluded under R1" | **FALSE (Pons INCLUDED)** | Pons V2 fixtures set `PONS_V2_POOL_FEE = 0` (`TestBase_..._PonsV2.sol:66`); Pons pools are **static**, not dynamic. Kimi §1.4 lists only Orbital/Weighted as excluded; same. My old reading was wrong. |
| I said "MAX_LP_FEE is `1_000_000`" but treated it as acceptable without comment | TRUE | UNCHANGED, but should explicitly reject per Astra (see §3.1) and note this does not exclude Pons V2 (fee = 0 is well below MAX_LP_FEE). |
| I did NOT call out deploy-time protocol-fee check impossibility | implicit | **ADD:** protocol fee is set on PoolManager (owned), not PoolKey; deploy-time validator has no reference. Must enforce at quote/execution path, not at init. |
| I said "Orbital/Weighted are dynamic" | TRUE | UNCHANGED — verified by grep: 6 files under `contracts/hooks/uniswap/v4/{orbital,weighted}/` use `fee: LPFeeLibrary.DYNAMIC_FEE_FLAG`. R1 excludes them; product-visible consequence. |
| I did NOT call out `Hooks.beforeSwap` requiring a 96-byte result for AFTER_SWAP_FEE_PATH | TRUE | Verified `result.length != 96` at Hooks.sol:261 — calls returning wrong length revert `InvalidHookResponse`. A non-Pons hook returning a different length silently fails before the vault can detect it; the v4SF QuoteService only checks flag bits, not return shape. Plan should explicitly enumerate required return shapes (96 bytes) for any bespoke hook compatibility. |

### Cross-references to peer claims I verified as correct
- All three originals agree `PoolKey.fee` reading is unimplementable to "use as static fee in calculations" without the live `getSlot0` composition — verified at UniswapV4Quoter.sol:196-212.
- All three correctly note `OVERRIDE_FEE_FLAG` is gated on dynamic (Hooks.sol:265).
- All three correctly note the protocol fee is controller-mutable per-direction (ProtocolFees.sol:33-40).
- All three correctly note `UniswapV4Utils.sol:17` comment disagrees with `ProtocolFeeLibrary.calculateSwapFee` (Grok is explicit); verified by reading ProtocolFeeLibrary.sol:39-47.

---

## 3. Genuine product-level disagreements

### 3.1 MAX_LP_FEE = 1_000_000 (100% fee) — Astra vs. the rest

**Astra** explicitly recommends a separate determinist reject at full LP fee (cites `Pool.sol:315-320` "consumes entire vanilla exact-input amount as fees, exact-out reverts"). My original, Grok, and Kimi accept `MAX_LP_FEE` as the upper bound without comment.

**Verdict (verified by LPFeeLibrary.sol:38-39 and Pool.sol context):** `1_000_000` pips is the canonical V4 maximum. Closed-form exact-out would `InvalidFeeForExactOut`; exact-input would degenerate in the limit. Product-visible consequence depends on whether the FullSpread vault must support any pool with fee = 100%. For Pons V2 fixtures, fee = 0 is used. Recommend **accept MAX_LP_FEE** as the upper bound for static compatibility; document that exact-out for fee=1_000_000 is not supported as a runtime consequence (per PRD §13/§6.4-style closed-form-only support).

### 3.2 Deploy-time `slot0.lpFee == poolKey.fee` check — Grok/Kimi vs. my original + Astra

**Grok (R1)** and **Kimi (R3)** recommend reading `getSlot0(poolId)` at deployment and asserting equality. **Astra** and my original do not include this.

**Verdict:** PoolManager.initialize writes `lpFee = key.fee.getInitialLPFee()` for static pools (Kimi's research). For a static pool at deploy time the equality will hold. For an **uninitialized** pool, `getSlot0` returns zero, the equality check fails; the vault-deploy check would then require the pool to be initialized at vault deploy. This is a real product decision: does the vault deploy require the pool to already exist on PoolManager? Kimi allows `initAccount` to deploy before pool initialization **and** recommends `slot0.lpFee == poolKey.fee` check which would force-vault-deploy-after-init. These two are not perfectly compatible. Recommend: structural-only check by default (gate = `!isDynamicFee && isValid && non-Pons hook optional`); add optional `slot0.lpFee == poolKey.fee` as a strict-mode override (controlled by an immutable boolean at construction or a vault-deck flag, NOT a mutable registry flag).

### 3.3 Pons V2 vs. dynamic-fee hook compatibility — Kimi's framing

**Kimi §1.4** says "IndexedEx Orbital/Weighted hook pools are dynamic-fee; FullSpread vaults could therefore never bind those." This is correct (verified by 6 file matches in grep). However, **Pons V2 uses static fee = 0** (PonsV2 Pool Decimals test base line 62; `PONS_V2_POOL_FEE = 0`), which means Pons pools WOULD pass R1. The product description should say: "Dynamic-IndexedEx-hook pools (Orbital, Weighted, Curve Quad balancer-analog) are out; Pons V2 (static fee, model-able) is in."

---

## 4. Seven targeted claims (as requested)

| Claim | Verified state | Evidence |
|---|---|---|
| 1. Existing quoter includes protocol fee | **YES** (live per-direction) | UniswapV4Quoter.sol:196-212; ProtocolFeeLibrary.sol:39-47; called by FullSpread `_quoteSwapIn`/`_quoteSwapOut` |
| 2. Static hooks' extra deltas | **YES** (before/after-swap return-delta flags apply independent of fee mode) | Hooks.sol:268-281 (beforeSwap), Hooks.sol:302-307 (afterSwap) — only `lpFeeOverride = result.parseFee()` (line 265) is dynamic-gated; `hookReturn` (line 269), `hookDelta` (line 311) apply always |
| 3. Same-tx protocol fee changes | **POSSIBLE** (no PoolManager-lock gating in ProtocolFees.sol) | ProtocolFees.sol:34-40 `setProtocolFee` callable any time by `protocolFeeController`; no `unlock` requirement. Preview snapshot diverges from execute when controller edits between blocks; covered by min-out/max-in already in PRD §3 |
| 4. Compatibility vs. quote-model gates | **Two distinct gates.** R1 (static-only admission) is structural at deploy; `_supportsProjectedHook` + `_ponsHookFees` is runtime quote-capability. Both are deterministic on inputs; together they define supported domain | Common:104 (`_supportsInventoryQuote`); QuoteService:21-58 (_ponsHookFees); DFPkg:271-298 (initAccount) |
| 5. Init-time pool existence | **NOT REQUIRED** today. Pool may not exist at vault-deploy. Adding a `slot0.lpFee == poolKey.fee` check would force it | Common:432-434 destructures live `lpFee`; if pool uninitialized, `slot0.lpFee == 0`. Compare to `key.fee != 0` ⇒ auto-revert unless key.fee==0 |
| 6. 100% static fee (MAX_LP_FEE) | **ACCEPTED by UniswapV4 LPFeeLibrary**; structurally valid. Closed-form exact-out for fee=1_000_000 is infeasible (input consumed as fee entirely). Recommend accept but document runtime infeasibility | LPFeeLibrary.sol:26; Pool.sol context for exact-out-with-fee=1_000_000 (Astra cites Pool.sol:315-320 — verifié) |
| 7. Pons exclusion impact | **Pons INCLUDED, NOT excluded.** Pons V2 uses static fee = 0 (`PONS_V2_POOL_FEE = 0`); R1 admits Pons. Existing IndexedEx Orbital/Weighted curves are EXCLUDED because they use DYNAMIC_FEE_FLAG | TestBase_UniswapV4StandardExchange_PonsV2.sol:66; contracts/hooks/uniswap/v4/orbital/...PairPoolLib.sol:32; contracts/hooks/uniswap/v4/weighted/...PairPoolLib.sol:62 |

---

## 5. Recommended final policy for the human (minimum safe answer)

> **Static-only deployment is proposed (not yet an approved PRD change). Implement R1 + R2 + R3 + R5 as policy candidates; defer R4 unless an R1-compliant pool evidence matrix contradicts.**

| # | Requirement | Status | Reason |
|---|---|---|---|
| **R1** | Reject dynamic at deploy. In `UniswapV4FullSpreadStandardExchangeVaultDFPkg.initAccount`, revert `DynamicFeePoolUnsupported(uint24)` if `LPFeeLibrary.isDynamicFee(poolKey.fee)` | **proposed for adoption** | Deterministic; preserves D14/§10; required for static-only quote math |
| **R2** | Accept fee ≤ `MAX_LP_FEE` (1,000,000 pips) inclusive. Do NOT add a product-level 100% reject; rely on runtime closed-form infeasibility for exact-out, document | **proposed for adoption (lax over strict)** | Pons V2 fixture uses 0% which is well below; MAX_LP_FEE matches V4 canonical contract; tight bound has no clear product benefit |
| **R3** | At deploy, read `StateLibrary.getSlot0(poolManager, poolId)`; require `slot0.lpFee == poolKey.fee` (strongly recommended for *production-path* instances only; allow post-activation deployment for stress/buffer integrations) | **proposed as a flag-gated strict mode**, not a universal gate | Conflicts with allow-pre-init; do not force-order |
| **R4** | At every quote/execution, read live `slot0.protocolFee` per direction; compose `calculateSwapFee(directionProtocolFee, poolKey.fee)`. Never cache protocolFee | **proposed for adoption** | ProtocolFees is controller-mutable; same-tx drift risk; existing UniswapV4Quoter already does this |
| **R5** | Reject `BEFORE_SWAP_RETURNS_DELTA_FLAG` and `AFTER_SWAP_RETURNS_DELTA_FLAG` and `AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG` and `AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG` on hooks for **fee-exact-quote** paths (closed-form); keep them allowed for measured-actual execution paths | **proposed for adoption (scope-limited)** | Static ≠ static; closes "static fee ≠ static total cost" gap for quote-exact routes |
| **R6** | Document IndexedEx Orbital/Weighted/Quad Balancer-analog dynamic-fee hook-pool EXCLUSION in the package README compatibility notes (Kimi's §1.4 evidence). Document Pons V2 (static fee = 0, model-able) as INCLUDED | **proposed for adoption** | Preserves deployer responsibility transparency |
| **R7** | Live observation of `AFTER_SWAP_RETURNS_DELTA_FLAG` Pons hook delta via `BalanceDelta` after `manager.swap` is the backstop; do not model it in preview | **already in code; no change** | See Common:973-989 + QuoteService:50-58 |

**Compatibility matrix under R1 + R2 + R3-strict + R4 + R5:**

| Pool type | Fee | Hook flag set | Status |
|---|---|---|---|
| Vanilla (no hook) | static ≤ MAX | (none) | ✅ supported (R4 only) |
| Pons V2 | static 0 | BEFORE_INIT/AFTER_SWAP/AFTER_SWAP_RETURNS_DELTA | ✅ supported (R4 + R5 requires quote-exact path to ignore Pons delta) |
| Orbital / Weighted DETF | dynamic | address-set | ❌ R1 reject |
| Other static + return-delta | static ≤ MAX | +X_RETURNS_DELTA | quote-exact ≠ R5; measured-actual execution OK |
| Static ≤ MAX + no return-delta | static ≤ MAX | (other flags) | ✅ R1+R2+R3+R4 |

---

## 6. Consensus vs. dissent summary

**Consensus (4/4):** vault can read poolKey.fee, can read live lpFee/protocolFee, dynamic-fee reject is deterministic, no current rejection, protocol fee is controller-mutable, OVERRIDE_FEE_FLAG is dynamic-only, BEFORE_SWAP/AFTER_SWAP return-delta flags apply on static pools, Pons V2 uses static fee (not dynamic — verified by code).

**Dissent (3 viewpoints):**

| Issue | Astra | Grok | Kimi | MiniMax M3 |
|---|---|---|---|---|
| 100% fee accept/reject | reject | implicit accept | accept | accept (this round) |
| Deploy-time `slot0.lpFee == poolKey.fee` | not included | R1 (included) | R3 (recommended) | recommend flag-gated strict mode |
| Pons V2 specifically named | "Pons-style" generic | "Pons handling separate constant-bps model" | "Pons V2 uses static fee 0" | agreed with Kimi (this round) |

---

## 7. Confidence and open items

**High confidence:** the seven targeted claims in §4 are verified. R1 is safe and deterministic. Pons V2 implication in §3.3 is verified by code.

**Medium confidence:** R3 strict-mode optionality depends on whether the deployment flow requires the pool to already exist; PRD is silent.

**Low confidence / open:** timing of `beforeSwap`/`afterSwap` deltas observed inside `unlockCallback` versus preview — the preview is necessarily an underestimate. PRD D22 acceptance of measured-actual fills covers this.

**Caveats noted:** PRD §15 self-discloses upstream `main` not deployed-pinned. `HookNotStaticallyDecodeable` and `DynamicFeePoolUnsupported` are new error-name proposals; either may reuse existing LPFeeLibrary error.

**No file edits performed** in this research pass. Original preserved at `docs/research/uniswap-v4-static-fee-policy-2026-09-27/minimax-original.md`. No peer cross-review artifacts read.
