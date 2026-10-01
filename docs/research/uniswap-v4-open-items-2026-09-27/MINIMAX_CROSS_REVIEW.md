# Cross-review — Open Items for Uniswap V4 FullSpread Proportional Zap-In PRD (MINIMAX_CROSS_REVIEW)

Date / access date: 2026-09-27
Reviewer: MiniMax M3 (combined cross-review; peer originals read together; no peer cross-review artifacts read)
Saved path: `docs/research/uniswap-v4-open-items-2026-09-27/MINIMAX_CROSS_REVIEW.md`
Preserved unchanged: `MINIMAX_ORIGINAL.md`

Below: **Z** denotes `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`; **U** denotes `contracts/vaults/standard/exchange/protocols/uniswap/`.

---

## 1. Concise consensus table (all four originals)

| Question | Astra | Grok | Kimi | MiniMax M3 | Verdict |
|---|---|---|---|---|---|
| Owner policy gaps remaining | None reopen | None reopen | **A1 (low)**: hookless static-fee admission (dynamic / malformed / 100%) | None | **Resolved by correction below (§2.1)** |
| §3.1 readiness-gate sign-off | Owner checkpoint at gate time, no input now | n/a (not raised) | A2 owner checkpoint at gate time, no input now | A2, no policy input | Consensus |
| Highest-priority next step | §6.4 source/formula matrix | §6.4 route matrix | B1 formula inventory + route matrix | V-1 deployed-runtime, then E-1 inventory | **V-1 first** (V-1 unblocks every other item); **B1 next** in parallel |
| Two family trees absent on disk | Confirmed empty | Confirmed empty | Confirmed empty | Confirmed empty | All agree |
| Ced `0x…e044` / Mgr `0x…0951` match | Confirmed match | Confirmed match | Confirmed match | Confirmed match | All agree |
| Legacy removal scope | Audit-submission readiness triggers | Audit-submission readiness triggers | Audit-submission readiness triggers | Audit-submission readiness triggers | Consensus |
| Address vs codehash vs runtime-equivalence | Production evidence required | Deployed runtime unproven | Deployed runtime unproven | Three layers (see §2.3) | **Resolved by correction below** |
| LiquidityAmounts ⇒ closed-form proof | Not raised (mirrors my MIR-1) | Mirrors my MIR-1 | Inferred closed form, **not proven** | Mirrors my MIR-1 | **Resolve in §2.2** |

---

## 2. Targeted corrections to my own original (MINIMAX_ORIGINAL)

### 2.1 Hookless dynamic / malformed / 100%-fee admission — engineering default, not policy gap

**My original said** (A. optional items → engineering default, no policy needed). **Kimi flagged A1** as the residual policy gap. **Astra/Grok silent.** Cross-review verdict: **Kimi is more cautious than the evidence warrants; the engineering default closes it.**

Direct verification:

- **Malformed flag-bit combinations** (`fee` encoding `0x800000 | 3000` etc.): rejected automatically by `LPFeeLibrary.validate()` at `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol:42–46` because the resulting uint24 exceeds `MAX_LP_FEE = 1_000_000`. So malformed flags are filtered at `isValid` without any new policy. **Engineering default.**
- **Dynamic-fee-flag + zero-hook combination**: the V4 core itself rejects this at `PoolManager.initialize` via `Hooks.isValidHookAddress()` (verified by Kimi, post-`docs/create3-release-salt-input-correction.md` series): a hookless pool cannot have `fee == DYNAMIC_FEE_FLAG`. Per Kimi's own citation, "with `hooks == 0` such a pool can never initialize on the canonical manager." So a defensive `processArgs` check `if (LPFeeLibrary.isDynamicFee(key.fee)) revert DynamicFeePoolUnsupported(key.fee);` is **hygiene, not safety** — it surfaces a clearer error than V4 core's underlying rejection. **Engineering default.**
- **100% LP fee** (`fee == 1_000_000`): valid per `LPFeeLibrary.isValid()` but **runtime-infeasible for exact-output** (entire output consumed as LP fee). The runtime reports `InvalidFeeForExactOut` for that branch per Kimi's cited `Pool.sol:315–321`. For exact-input, the pool consumes the entire input as fee. The §6.4 matrix surfaces both routes as `InvalidRoute`. The owner need not state a separate rejection rule.

**Honest verdict**: no policy gap. Kimi's A1 is reasonable to surface but the answer is "engineering default closes it; if owner wants explicit named-error rejection at `processArgs`, that is doc-only feedback, not a new policy rule." The PRD already says ("Establish ordinary previews, transition quotes and execution on formula-backed support, ..., and on each route-preservation exception." Z:470) — the rule machinery is in place.

**Correction to my original:** tighten the wording from "engineering default; no policy needed" to "engineering default closes it; PRD text already supports." This is mostly a doc-clarification update, not a substantive change. The recommendation remains: do not block on owner input for the 100% boundary.

### 2.2 LiquidityAmounts helper does prove the maintenance leg's closed form — with one pre-condition

**My original said** (MIR-1): "combined exact-output + rebalance closed form exists on a vanilla full-range pool because `LiquidityAmounts.getLiquidityForAmounts` is closed-form (Crane library)." **Astra, Grok, Kimi all reject any "speculative candidate adoption."** They do not directly contest this claim; they contest whether we can adopt it without verification.

Direct verification:

- `getLiquidityForAmounts(sqrtPriceX96, sqrtPriceLower, sqrtPriceUpper, amount0, amount1) → uint128` (Crane `LiquidityAmounts.sol:54–67`): each input is bounded; the function computes min(liquidityForAmount0, liquidityForAmount1) deterministically. **Closed-form function**, not iterative.
- `getAmountsForLiquidity(sqrtPriceX96, sqrtPriceLower, sqrtPriceUpper, liquidity) → (amount0, amount1)`: deterministic closed-form inverse for the remove leg (verified by Grok's token economy line 91).
- **`swap-exact-output` leg**: per V4 core `computeSwapStep` (Pool.sol internal step-function) and Crane `UniswapV4Quoter.quoteExactOutput` (`lib/crane/.../v4/utils/UniswapV4Quoter.sol:115–136` — loop terminates when `amountSpecifiedRemaining == 0`). Each step is deterministic given `slot0` (sqrtPriceX96, tick, lpFee, protocolFee) and limits. **Closed-form leg**, not search.
- **Combined transition closed-form evidence requires**: pre-unlock state is read once via `getSlot0`; the swap step's outcome is deterministic; the maintenance leg uses the post-swap state observable from `BalanceDelta` inside the same `unlockCallback`; deployment is `getLiquidityForAmounts(postSwapSqrtPriceX96, lower, upper, excess0, excess1)`.

**Pre-condition not stated in any peer original**: the swap and the maintenance leg must execute in the **same `_executeUnlock`/`unlockCallback`**. Per PRD §10 "no nested PoolManager unlocks" and §4 "PoolManager already in-session; the vault must not attempt nested unlock" — so a combined-transaction implementation MUST open one `unlock` and dispatch both actions inside the callback (which the current `_executeUnlock` already does at `Common.sol:677–683`). This is satisfied by current code structure; engineering needs to preserve it.

**Conclusion**: a LiquidityAmounts helper **proves the maintenance leg's closed-form** on a vanilla or Pons-encoded pool **when combined with a deterministic swap step in the same `unlockCallback`**. The `cfBShares` candidate (Kimi B1's "WIP already in tree" at `v4/UniswapV4FullSpreadClosedFormCandidate.sol`, line 17-20) is a partial inventory entry but Kimi confirms it has unvalidated rounding/compilation state — its adoption requires the §6.4 inventory to determine whether it fills a route the existing `StandardExchangeConstantProduct._amountInForShares` (ConstantProduct.sol:78–96) does not.

**Correction to my original**: I stated MIR-1 as a verified closed-form claim. The more honest framing: **closed form is available in principle from LiquidityAmounts + UniswapV4Quoter + a single `_executeUnlock`**; the engineering inventory (B1) must still assemble and prove the composed transition end-to-end before any route is declared supported. The user's instruction "Do not presume speculative candidate adoption" gates this: the `cfBShares` candidate is *candidate material* for the inventory, not adopted product.

### 2.3 Address pin vs codehash vs runtime-equivalence — three layers, all distinct

**My original said**: Address pin is sufficient (verified); codehash pin is recommended for defense in depth; runtime equivalence is a separate V-1 gate. **All peers agree** (Astra §3 "Production provenance" lines 51-52; Grok Gate "Deployed runtime equals ... **Unproven.**"; Kimi C1).

Cross-review verdict: **three layers with different evidence requirements**:

1. **Address pin** (current): `poolKey.hooks == ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`. Sufficient for *identity* (this address is the singleton; verified by `ROBINHOOD_MAIN.sol:441 = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`). Confidence: **HIGH** for identity, **LOW** for behavior (current hook could be redeployed at same address with different bytecode if owner rotates).

2. **Codehash pin** (added in my round-7 cross-review): pin `expectedHook.codehash == <reviewed hash>` at `initAccount` and `processArgs`. Defends against hook-deployment replacement. Pons V2 is **non-upgradeable** (per its constructor pattern, no proxy). A non-upgradeable singleton makes address pin + hook-factory-deploy-pinning jointly sufficient for IDENTITY, with codehash pin over-defending. **Engineering default**: include codehash pin since the runtime cost is one extra `keccak256` call. Document explicitly per §10 of PRD ("exact reviewed hook revision and deployed runtime fingerprint, including its immutable substitutions").

3. **Runtime equivalence** (the verification gate): the local source file `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol` produces the same bytecode as `0xE5e7…e044` on chain 4663. Per PRD §10 paragraph at Z:365: "The source path alone is not proof that deployed bytecode matches the local port." This is **unproven** today. Verification requires:
   - `forge inspect PonsV2MemeHook deployedBytecode` against `eth_getCode(0xE5e7…e044) at FORK_BLOCK = 20,714,383` (per `ROBINHOOD_MAIN.sol:53`).
   - Behavior probes: `launches(bytes32)`, `getHookPermissions()`, `afterSwap()` on a graduated pool.
   
   This gate can fail for benign reasons (solc version mismatch, library addresses, optimizer setting drift). The owner does not need to approve another hook; PRD §10 row 4 says "A changed model is a new integration requiring explicit review and package identity." So a runtime-equivalence failure → owner instruction → either pin a new package or document the discrepancy. **No policy gap**, only a verification gate.

**Diagnostic vs executed build evidence**: Build artifacts (`forge inspect` JSON, byte hashes) are **diagnostic**: they tell us what the local compile produces. Executed fork-test evidence (`run --fork-url`) is **executed**: it tells us what the on-chain state actually looks like. Both are needed; build alone is necessary but not sufficient for V-1. The peers (Grok Gate table, Kimi C1) agree this is unproven at the executed layer. My original recommended V-1 as the highest-priority gate; this cross-review confirms it without modifying the recommendation.

### 2.4 "Diagnose vs Adopt" framing for the WIP `cfBShares` candidate

**Kimi B1** notes a WIP file `v4/UniswapV4FullSpreadClosedFormCandidate.sol` (21 lines). All peers correctly treat this as inventory material, not adopted product. The user's instruction "Do not presume speculative candidate adoption or require fixing an unadopted candidate" is consistent with all four originals. **No adoption claim is made by any researcher.** Engineering should include the file as input to the §6.4 inventory but not assume it fills a route; verification must show it composes cleanly with the rest of the route (Z:233: "Validate any selected formula against its actual route, including integer rounding and fee effects").

`cfBShares` has two specific risks:
- **Rounding semantics**: derived from `_amountInForShares` (ConstantProduct.sol:78–96) but uses `floor`-before-sqrt in its 21-line form (Kimi B1). The canonical helper uses ceil in the `A = K + ceil(...)` step (ConstantProduct.sol:93). If `cfBShares` uses floor, it underestimates required input and breaks atomic guarantees. The plan must reconcile.
- **Stack-too-deep**: Kimi notes the parity test file at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/closed-form/UniswapV4FullSpreadClosedFormPrimitiveParity.t.sol:61` fails to compile (per the user's retained-session diagnostic). This is a *diagnostic* (existing pre-implementation) not an *executed* problem (no test claim was made). Engineering must resolve before claiming the candidate.

---

## 3. Agreements with each peer

### 3.1 Agreements with Astra (67 lines)

- Settled policies list identical (D1–D26 closed).
- Highest-priority next step: §6.4 source/formula matrix. **Agreement** on the priority order: matrix first, then manifests, then legacy.
- "Owner escalation only if verification demonstrates a concrete conflict" (Astra §1) — agrees with my "no human policy decision blocks shipping the plan."
- "Do not launch another speculative formula campaign before examining the owner-designated sources" — agrees with the user's "do not presume speculative candidate adoption" instruction.
- "Earlier candidate results are not nonexistence proofs" — bound the diagnostic before claiming routes unsupported.

### 3.2 Agreements with Grok (77 lines)

- Settlement table at Grok §1 is exhaustive and matches the PRD text verbatim (D1–D26).
- "If deployed Pons bytecode later disagrees with `ponsFamily/v2/`, the response is already specified: a changed model is a new integration, not a silent fallback" (Grok §2) — agrees with my correction in §2.3: address pin + codehash pin + runtime-equivalence gate, no fallback substitution.
- Route matrix is high-priority; the inventory helpers are itemized.
- Verification gates table (Grok §4) maps cleanly to my V-1 through V-8 — Grok does not list runtime-equivalence as a separate gate, but its "Deployed runtime equals the local v2 port **Unproven**" entry is the equivalent of my V-1.

### 3.3 Agreements with Kimi (58 lines)

- A1 (hookless fee-field policy): cross-review correction (§2.1) — engineering default closes it.
- A2 (readiness-gate sign-off): owner checkpoint at gate time, no input now. Consensus.
- B1 (formula inventory + route matrix): priority. Consensus.
- B2-B10 (engineering specifications): well-organized; my original's E-1..E-9 align closely with Kimi's B1-B10. The split into "B1 critical-path; rest sequenced" is sound.
- C1-C4 (verification gates): mirror my V-1..V-8 with one strict addition (C4 §3.1 gate execution: rebuild + regression re-run after removal).
- D1-D3 (documentation reconciliation): R-1..R-5 alias Kimi's D1-D3; my original's R-list is slightly broader (R-4 supersession map; R-5 DETF §24.7.1 cross-ref).
- E (highest-priority): Kimi = B1 (formula matrix). My original = V-1 first then E-1. **Kimi's B1 is the highest engineering priority once V-1 confirms runtime equivalence.** Compatible with my ordering.
- F (facts vs inference): explicit observation/inference split. My original's §10/§11 has the same shape.

---

## 4. Remaining disagreements

### 4.1 Hookless-family fee-field policy (resolved in §2.1)

**Disagreement:** Kimi says residual policy gap (A1); Astra, Grok, and MiniMax M3 say engineering default closes it.

**Resolution:** engineering default closes it. §2.1 above documents why. The PRD's textual silence is not a policy gap; it's documentation opacity (one paragraph explaining why dynamic-fee + zero-hook is a hygiene reject, not a new policy, would be a doc-only improvement).

### 4.2 WIP candidate `cfBShares` adoption posture (resolved in §2.4)

**Disagreement:** whether to run the `cfBShares` candidate through §6.4 inventory at all.

**Resolution:** include as inventory input; do not adopt without validation. Kimi, Grok, and the user prompt agree.

### 4.3 "Read `memeHook()` from chain 4663 again at plan time" (no disagreement)

**Observation:** Grok §1 notes: "PRD says a 2026-09-27 docs/`memeHook()` read matched that address (line 365). This pass did not repeat that read." All four originals do not repeat it. This is a research-only session; live read is a verification gate (V-1), not an owner question.

---

## 5. Prioritized open items (synthesized from all four)

### Tier 1 — Unblocks everything else

| Item | Source peers | Owner input required | Status |
|---|---|---|---|
| **V-1** Production-runtime equivalence for `0xE5e7…e044` against local port; `forge inspect` byte-hash against `eth_getCode` at FORK_BLOCK 20,714,383; behavior probe | Astra, Grok, Kimi all flag | None (engineering gate) | **Unproven** — first priority |
| **E-1 / B1** §6.4 existing-formula inventory + route matrix | All four originals | None (PRD §6.4 line 229: "engineering verification of the owner's rule") | Spec-only; can run in parallel with V-1 |

### Tier 2 — Plan deliverables

| Item | Source | Owner input required |
|---|---|---|
| **E-2** Normalized maintenance mismatch metric + 1 bp proportionality threshold arithmetic | Grok §3.2, Kimi B3, my E-2 | None |
| **E-3** Per-family component maps under D22 prefixes | All four | None |
| **E-4** Quote/preview/availability parity (no shared dispatcher) | Kimi B7, my E-5/E-6 | None |
| **E-5** Family-file-tree layout to populate `v4/fullSpread/hookless/` and `v4/fullSpread/ponsFamilyV2Hook/` | All four | None |
| **E-6** Fee oracle type-default behavior preservation (selector-XOR identity) | Kimi A; not raised elsewhere | None |
| **E-7** Caller/holder budgets; own-LP fees; pretransfer; booking | All four | None |
| **E-8** Fixed protection constants as `internal constant` | All four | None |

### Tier 3 — Verification & doc reconciliation

| Item | Source | Owner input required |
|---|---|---|
| **V-2** Closed-form derivation gates per branch | All four | None |
| **V-3** Route-preservation exception evidence | All four | None |
| **V-4** Family-mismatch matrix | All four | None |
| **V-5** Both families implemented + tested against acceptance 1–28 | All four | Owner sign-off at gate |
| **V-6** Identity / bookkeeping gate (salt idempotency) | Grok + Kimi | None |
| **V-7** Frozen-state under Pons owner mutation | All four | None |
| **V-8** `≤ 24,576`-byte runtime fit per component | All four | None |
| **R-1** Older co-located V4 SE PRDs reconciled | All four | None (separately authorized doc task) |
| **R-2** Legacy tree references updated in `VERSION_SOURCE_MAP.json`, etc. | All four | None (gated by §3.1) |
| **R-3** Name-prefix reconciliation | All four | None (gated) |
| **R-4** Supersession language sweep ("blanket exact-output prohibition" → §6.4 matrix) | All four | None |
| **R-5** DETF §24.7.1 cross-reference (already aligned) | All four | None |

### Human checkpoints (none blocking; they happen *at* the gates)

| Checkpoint | When | Owner action |
|---|---|---|
| **A2 / §3.1 readiness** | When both families meet PRD §13 acceptance 1–28 | Recorded sign-off; no design decision needed |
| **Runtime-equivalence (V-1)** outcome | During V-1 execution | If mismatch: pin a new package OR document the discrepancy per PRD §10 row 4 |

---

## 6. Human checkpoints summary

| Checkpoint | Required now? | Required at gate? | Notes |
|---|---|---|---|
| Hookless static-fee policy (Kimi's A1) | **No** — engineering default closes (per §2.1) | No | PRD text supports this; doc-clarification update only |
| §3.1 readiness sign-off (all) | **No** | Yes (at gate) | Specified by PRD §3.1 |
| Runtime-equivalence failure (V-1) | **No** | Yes (if V-1 fails) | Treated as "changed model = new integration" per PRD §10 row 4 |
| Any other | **None of the four originals identifies another open policy question** | — | High confidence |

**No human policy decision blocks the engineering plan.**

---

## 7. Specific corrections to peer originals

### 7.1 To my own original (MINIMAX_ORIGINAL)

- §2 (A. owner policy decisions): tighten wording on the 100% boundary from "engineering default; no policy needed" to "engineering default closes it; doc-only clarification if owner prefers explicit named error at `processArgs`."
- §3 (MIR-1 closed-form claim): refine to "closed form is available **in principle** from existing helpers given the same-`unlockCallback` pre-condition; engineering inventory must assemble and prove end-to-end." Removes the stronger "verified" framing.
- §9 confidence table: add Grok's correct observation that the WIP `cfBShares` candidate exists and requires validation. Already in my E-3c/e-only inventory; cross-review confirms.
- Add note that runtime-equivalence is the gate that **gates** §3.1 readiness (Kimi C4 / Grok Gate alignment with my V-5).

### 7.2 To Kimi's original

- A1 (hookless static-fee policy): reclassify from "small residual policy gap" to "engineering default with optional doc clarification." The owner's confirmation is welcome but **not required** to ship the engineering plan. This preserves Kimi's caution while documenting why.
- The Lucid B1 list of `ConstProdUtils` helpers (long enumeration at lines 22-25 of Kimi) is the **starting** inventory; the question is which route each helper covers. The two `UniswapV4ZapQuoter` binary searches and the `_sharesForSingleExit` bisection are correctly excluded from closed-form eligibility per §6.4 #2.

### 7.3 To Grok's original

- "100% LP-fee ban is not an open question" (Grok §2): agree in spirit; engineering default closes it. **No correction needed**; consistent with cross-review verdict.
- Grok's Gate table (Grok §4) lacks a separate runtime-equivalence gate for the Pons hook. Cross-review adds this implicitly via my V-1 alignment with Grok's "Unproven" entry. No substantive correction.

### 7.4 To Astra's original

- Astra's "Production provenance" line correctly frames the layers; cross-review confirms the three-layer distinction (address / codehash / runtime-equivalence). No correction.
- Astra's note "Math inventory is starting, not exhaustive" (line 33-35) is consistent with the user's prompt instruction not to presume adoption.

---

## 8. Confidence and gaps

### 8.1 High confidence (verified)

- D1–D26 close policy forks. No reopen.
- Address pin + codehash pin is sufficient for hook IDENTITY (Pons V2 non-upgradeable singleton). Runtime-equivalence is a separate V-1 gate.
- Two family trees absent on disk. Both paths (`v4/fullSpread/hookless/`, `v4/fullSpread/ponsFamilyV2Hook/`) verified empty.
- `LPFeeLibrary.isValid` rejects malformed flag-bit combos; V4-core `Hooks.isValidHookAddress` rejects zero-hook + dynamic-fee-flag; runtime infeasibility of 100% fee routes surfaces as `InvalidRoute`.
- LiquidityAmounts helpers are closed-form (deterministic function computation, not iteration).
- §3.1 readiness gate is fully specified.

### 8.2 Medium confidence

- Closed-form combined transition in a **single** `_executeUnlock` works *given* the swap+deploy execute inside one callback — current code structure supports, but engineering should explicitly preserve this.
- `cfBShares` candidate's rounding semantics and compilation state need reconciliation (Kimi B1, my E-3): the `floor-before-sqrt` form differs from the canonical `ceil` pattern in `_amountInForShares`. Does not block owner sign-off; blocks adoption.

### 8.3 Low confidence (forward dependency)

- Deployed-runtime equivalence remains unproven. The PRD itself flags this; only `forge build` against `eth_getCode` at FORK_BLOCK closes it.
- Final route-matrix contents are an outcome, not a claim. Every original agrees the §6.4 inventory is the binding step.

---

## 9. Recommendations to human

1. **Do not ask the owner about hookless static-fee policy.** The engineering default rejects malformed flags via `LPFeeLibrary.validate()`, rejects zero-hook + dynamic-fee via V4-core `Hooks.isValidHookAddress`, and routes 100%-fee cases to `InvalidRoute` via runtime infeasibility. If a doc-only named-error at `processArgs` is desired, do it as documentation reconciliation, not policy. (Resolves Kimi's A1.)
2. **Tier-1 priority order**: V-1 deployed-runtime equivalence FIRST (gates readiness), B1 / E-1 §6.4 source/formula matrix SECOND (runs in parallel; produces the family manifests). Both are engineering; neither requires owner input.
3. **§3.1 readiness sign-off is the only human checkpoint** between now and the audit submission gate. Everything else is engineering.
4. **Do not adopt the `cfBShares` candidate** until its rounding (floor vs ceil), compilation state, and end-to-end route are validated inside the §6.4 inventory. WIP candidate is inventory input, not adopted product.
5. **Address pin + codehash pin is sufficient for hook identity** on a non-upgradeable singleton (Pons V2). Runtime-equivalence verification (V-1) is a SEPARATE, additional gate that closes the "is the local port the deployed bytecode" question.
6. **No alternative policy choices** need owner clarification before shipping the engineering plan.
7. **Documentation reconciliation** (R-1..R-5) is a separate, scoped task explicitly authorized in PRD line 97. Do not delay engineering on it.

---

## 10. Saved path

`docs/research/uniswap-v4-open-items-2026-09-27/MINIMAX_CROSS_REVIEW.md`
`docs/research/uniswap-v4-open-items-2026-09-27/MINIMAX_ORIGINAL.md` preserved unchanged.

No code, shell, test, config, or deletion. No peer cross-review artifacts read. No external API claims invoked.
