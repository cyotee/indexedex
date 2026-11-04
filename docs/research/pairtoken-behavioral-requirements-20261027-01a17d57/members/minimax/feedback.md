**Tool-gap report:** `apply_patch` is not available in this session — it is absent from my active tool set, and a catalog search for it returns no matching tool. Per the brief I did not attempt to activate it further and did not use a `write`/`edit` workaround. The full advisory feedback is delivered below for the coordinator to archive at `docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/members/minimax/feedback.md`. The draft, the four originals and all earlier artifacts are untouched; no code, config, test, build, install, deploy, wallet, Git or external-message action was taken, and no peer original or feedback file was read.

---

# MiniMax — advisory feedback on draft `pairtoken-requirements-draft-r1`

**Draft reviewed:** `coordinator/draft.md`, identity `pairtoken-requirements-draft-r1`, SHA-256 `763dd6ad786ac84e61f968af77a627a2c0103a6fc6c67c8152127115083f229b`.
**Basis:** the draft, `analyst/traceability.md`, and the admitted frozen source only, for locator verification. Current-run peers were not read.

## 0. Position

**SUPPORT WITH CORRECTIONS.** The draft is an accurate and unusually complete behavioral baseline. I found **no factual error** in its behavioral content, and no missing public surface. It is, in my judgment, sufficient for a different agent to write an implementation plan without opening raw target code, **subject to the four corrections below** (one substantive omission of an observable consequence, three precision items) and one optional wording refinement in the provenance paragraph. Nothing I raise proposes new product behavior, and nothing treats an unsupplied dependency as a missing local requirement.

## 1. What I verified, and how

I re-derived each area against the archived source rather than accepting the draft's restatement.

| Area checked | Method | Result |
|---|---|---|
| 17 named functions + receiver, 17 getters, 5 events, 13 errors | Cross-listed against the draft's §2.1/§2.2/§12/§13 tables | Complete; no member omitted, none invented; all signatures, visibilities, returns and mutabilities match |
| Quote branch table and rounding | Re-derived `_quoteShares` branch precedence, floor/ceiling selection and the `min` clamps | Matches PT-QUOTE-01 exactly, including the geometric branch reachable at positive supply |
| Acceptance-scenario arithmetic | Recomputed PT-AC-08, PT-AC-12, PT-AC-19, PT-AC-23 by hand from the stated formulas | All four match the draft's stated numbers |
| Tick-price constants and function | Compared all 20 coefficient rows in PT-MATH-04 against the dependency source, bit by bit | **20/20 exact match**; the `Rj = floor(R(j-1)·C[bj]/2^128)` recurrence, the `floor((2^256-1)/Rk)` inversion and the `ceil(R/2^32)` output match the source's shift/divide sequence |
| Amount-delta and liquidity formulas | Checked `A0down/A0up/A1down/A1up`, the `L0/L1` conversions, the `Fit` price branching and the per-candidate `uint128` cast | Matches PT-MATH-02/03, including that an overflowing candidate is not excused by a smaller sibling |
| Manager storage-read convention | Recomputed pool-state slot, `+3` liquidity offset, positions-mapping offset and the position-key packing | PT-VIEW-01 is correct (`StateLibrary` L324, L339, L183, L279) |
| Callback protocol | Re-read the operation enum, dispatch, add/remove/collect/deploy payloads, delta settlement order and hook-data emptiness | Matches PT-CB-01…07, including the five enum values and the `None` path reaching `NotPoolManager` |
| Error predicates and precedence | Re-walked every guard site in deposit/zap/redeem/redeemZap/transferFrom/callback | PT-ERROR-01/02 ordering matches, including `AlreadyInitialized` before the zero-manager check and the allowance subtraction before destination validation |
| Native and token helper behavior | Re-read the native-value rules, reservation lifecycle, refund recipient and all three low-level token helpers | Matches PT-DEP-01/03/05, PT-BAL-01…07 |
| Outgoing payout failure path | Re-read the v4-core currency transfer helper and the wrapped-error encoder | PT-BAL-05 is correct — see MINI-02 for the one place I want it more explicit |
| Helper failure identities | Checked how the helpers actually emit `InvalidPrice()` and `InvalidTick(int24)` | Correct as drafted (see §4) |
| Delta width conversions | Re-checked the `int128`→`uint128` reinterpretation, the `uint256`→`uint128` truncation and the `uint256`→`int256` negation | Matches PT-MATH-05 exactly, including `x = 2^255` failing the negation and `x > 2^255` producing `2^256 - x` |
| Handoff hygiene | Scanned the draft for source paths, line references, code fences, Solidity, member names and source URLs | **Zero** hits in every category: no `.sol` paths, no line numbers, no fenced code, no member names, no source URL. The baseline is planner-facing prose, tables and mathematics |
| Provenance wording | Read the scope and handoff paragraphs | No legal conclusion, no clearance claim, no unexposed-workflow claim; one attribution refinement in MINI-05 |

## 2. Corrections

### MINI-01 — [Substantive omission] A plain paired deposit can move the pool price, and no tick guard applies to it

- **Requirement IDs:** PT-DEP-01, PT-DEP-02 (and, for symmetry, PT-COMP-01/PT-COMP-04/PT-COMP-05).
- **What the draft says today:** PT-DEP-01/02 describe the deposit's automatic compounding only as a *quote checkpoint* ("Reserve that value from idle accounting before automatic compounding", "sampled after automatic compounding and before either ERC-20 pull"). PT-EXIT-03 states the redemption counterpart explicitly ("This path performs no post-removal sale, though its initial compound may have swapped"). PT-COMP-04/05 establish that the compound performs a Deploy that may swap, with no compound tick-movement check.
- **Observed behavior:** `deposit` calls the compound sequence at its head, and the compound sequence requests a Deploy whenever either idle balance exceeds the dust threshold; that Deploy performs a ratio swap that moves the pool price. The only tick-movement guard in the contract belongs to the user zap route. So an ordinary paired deposit — with no zap and no user swap — can execute a price-moving swap, and that swap is not bounded by `maxZapTickMove`.
- **Anchor:** `src/pair/PairToken.sol` L265 (compound call inside `deposit`; the same call also appears at L325, L357, L376, L413), L437 (dust trigger), L438 (`_ratioSwap`), L439 (Deploy request), L469-496 (ratio sizing and the active-pool clip at L494-495); contrast the guard that exists only at L339.
- **Consequence of the omission:** a planner reading only PT-DEP could reasonably implement or assume a deposit that never swaps, which is neither required nor excluded by the draft as written, and would change the price at which the deposit's own liquidity is added.
- **Smallest correction:** add one sentence to PT-DEP-02 (or PT-DEP-03), in the same register as PT-EXIT-03's parenthetical: *"The automatic compound at this checkpoint may execute a pool-moving balancing swap when idle balances exceed the dust threshold; no tick-movement guard applies to it, and the only such guard in the contract belongs to the user zap route."* No other requirement changes.

### MINI-02 — [Precision] Make the outgoing-payout failure contract fully explicit

- **Requirement ID:** PT-BAL-05 (and PT-AC-52, PT-ERROR-01's `TransferFailed` row).
- **What the draft says today:** it correctly separates payouts from the local pull/manager-payment helper, and correctly states the ERC-20 acceptance rule ("at least 32 bytes whose first word is exactly one… nonempty shorter data or another first word fails") and the wrapped-error shape. Two details are still implicit.
- **Observed behavior:** the wrapped error's `target` field is **the payout recipient** for a native payout and **the token address** for an ERC-20 payout — not a currency address in both cases. And the ERC-20 acceptance test does **not** ABI-decode the return data: it reads the raw first 32-byte word of the call's return buffer. Success therefore requires an empty return buffer, or a return buffer longer than 31 bytes whose first word equals exactly 1. A 32-byte word of `0`, and any nonempty return shorter than 32 bytes, are **payout failures reported through the wrapped error**, not decoder reverts — which is the distinction PT-AC-52 draws between the payout path and the pulling path.
- **Anchor:** `lib/v4-core/src/types/Currency.sol` L40-88 — L48 (native raw call), L52 (native wrap with target `to` and selector `bytes4(0)`), L64-74 (the raw-word acceptance test), L82-86 (ERC-20 wrap with target = token address and selector = `transfer`); `lib/v4-core/src/libraries/CustomRevert.sol` L11 (`WrappedError(address,bytes4,bytes,bytes)`) and L83-120 (`bubbleUpAndRevertWith`, which lays out target / selector / reason / details in that order).
- **Smallest correction:** in PT-BAL-05, replace "containing the failed target" with "containing the failed target — the payout recipient for a native payout, the token address for an ERC-20 payout —", and add that the ERC-20 acceptance test reads the raw first return word rather than decoding it. In PT-ERROR-01, the `TransferFailed` row stays as drafted: the wrapped payout error is not a PairToken `TransferFailed`.

### MINI-03 — [Precision] Disambiguate the two liquidity reads in PT-VIEW-01

- **Requirement ID:** PT-VIEW-01.
- **What the draft says today:** "Slot0 is read at `B`, active liquidity at `B+3`, and the position entry at `keccak256(abi.encode(positionKey, bytes32(uint256(B)+6)))`. Price is the low 160 bits of slot0, tick is the next 24 bits interpreted as signed; liquidity reads retain the low 128 bits."
- **Observed behavior:** the pool's active liquidity is read from slot `B+3`; the **position's own** liquidity is read from a different slot — the position entry — and takes the low 128 bits of **that entry's first word**. As drafted, the "low 128 bits" clause attaches only to the pool read, and `positionLiquidity()` is left without a stated read convention.
- **Anchor:** `lib/v4-core/src/libraries/StateLibrary.sol` L183-191 (pool liquidity at `B+3`, low 128 bits of that word) and L279-286 (position liquidity at the position entry, low 128 bits of that word).
- **Smallest correction:** in PT-VIEW-01, split the clause into "pool active liquidity is read at `B+3`; the position's own liquidity is read from the first word of the position entry; both retain the low 128 bits of the word they read".

### MINI-04 — [Precision] State the observable consequence of the zap cap's reference quantity

- **Requirement ID:** PT-ZAP-02.
- **What the draft says today:** "Choose `rIn` from the input side of this **vault basket**." The cap is correctly identified as basket-based rather than pool-based (which is the substantive point, and the draft is right about it).
- **Observed behavior:** the basket reserve of the input side includes the vault's idle balance, and idle balances include unsolicited transfers. The maximum permitted zap size is therefore a function of the vault's own property, and a donation to the input currency raises it (bounded only by the runtime `maxZapBps`). This is a direct consequence of the cap's reference quantity and is worth stating so a planner does not read the cap as a fixed, pool-derived limit.
- **Anchor:** `src/pair/PairToken.sol` L330-332 (cap computed from the pre-zap basket), L221-230 (`basket` adds idle), L646-649 (idle is the actual balance).
- **Smallest correction:** extend PT-ZAP-02's `rIn` sentence with: *"Because the reference is the vault's own basket, unsolicited balances of the input currency raise the permitted maximum zap size."* No behavior changes.

### MINI-05 — [Optional wording] Attribute the source-identity reconfirmation

- **Requirement ID:** Scope and origin, first paragraph.
- **What the draft says today:** "Source identity was reconfirmed on October 27, 2026; source analysts examined the code."
- **Point:** the reconfirmation was performed by the council's evidence retrieval and recorded in the analyst evidence manifest; the baseline should not read as if the document itself performed a verification. This is a provenance-attribution refinement only, and no legal or clearance conclusion attaches to it either way.
- **Smallest correction:** "Source identity was reconfirmed by the council's evidence retrieval on October 27, 2026; source analysts examined the code." Nothing else in the paragraph changes.

## 3. Expressly preserved quirks — confirmed present and correctly framed

| Preserved behavior | Where the draft holds it | Verification |
|---|---|---|
| Partial fill permitted; no complete-fill or positive-output assertion | PT-EXIT-05, PT-CB-04, PT-AC-27, PT-AC-48 | Correct; the swap output is clamped to zero rather than rejected, and only caller minima apply |
| Zero payouts that still burn | PT-EXIT-02, PT-EXIT-05, PT-AC-24 | Correct; a floored-zero liquidity slice is not rejected, and the burn is not rolled back |
| Unsigned / sign-width conversions | PT-MATH-05, PT-CB-03, PT-AC-47, PT-AC-56 | Correct; the `int128`→`uint128` conversion is bit-preserving, the redemption slice is a low-128-bit truncation, and the swap amount's signed encoding is width-dependent |
| Gross `minShares` before the genesis dead deduction | PT-DEP-02, PT-DEP-04, PT-AC-08 | Correct; the check is on the gross quote, so the recipient can receive fewer shares than requested |
| Malformed return data handled distinctly on the two token paths | PT-BAL-03, PT-BAL-05, PT-AC-52 | Correct; see MINI-02 for the one detail worth making explicit |
| No `getRate` | PT-VIEW-05, PT-ABSENT-01, PT-AC-58 | Correct; explicitly absent, with no substitute invented |

All six are preserved as-is, none is repaired, and none is contradicted elsewhere in the draft. The draft also preserves, correctly: the two different swap caps, the geometric quote branch reachable at positive supply, the first-initializer-as-factory, the sender-directed refund, the notification-success-is-not-proof qualification, the absent armed flag, and the absence of any last-redeemer sweep.

## 4. Checks that looked like errors and were not

Recording these so the coordinator knows they were examined and cleared rather than overlooked.

- **`InvalidPrice()` / `InvalidTick(int24)` naming (PT-MATH-02, PT-MATH-04, PT-ERROR-03).** Both helpers emit these through a raw `revert` idiom with the four-byte selector pre-stored in scratch memory, so the observable revert data is exactly the custom-error selector. The draft's naming is correct. Anchor: `SqrtPriceMath` L196-201 (the `InvalidPrice()` selector, L199) and `TickMath` L70 (`InvalidTick.selector.revertWith(tick)`).
- **Pool and position slot formulas (PT-VIEW-01).** The dependency uses packed encoding for two `bytes32` operands, which is byte-identical to the draft's stated encoding for these operand types. Correct as drafted.
- **`PT-MATH-05`'s "not a checked positivity conversion".** Correct, and materially better than a magnitude reading: the conversion preserves the low 128 bits.
- **`PT-MATH-01`'s distinction between full-precision multiply-divide and a checked product followed by division.** Correct and important; the draft then names exactly which products stay checked (genesis, retention, fee basis points, both cap basis points).

## 5. Dispositions of my material original topics

| My original topic (previous run) | Draft disposition | Note |
|---|---|---|
| System, property and scope | PT-SCOPE-01…04 | Carried; the draft states the position-vs-supply distinction and the absence of a liquidity-unit ledger more crisply than my prose |
| Domain concepts, units, constants | PT-SCOPE-04, PT-STATE-01/02, PT-CONST-01/02 | Carried; the draft's raw-unit discipline and the mathematical-constant list are additions beyond my original |
| Initialization and position identity | PT-INIT-01…03 | Carried; the draft adds the no-local-validation clause (spacing positivity, currency ordering, code existence, pool readiness, hook policy) that my original left unstated |
| 17 functions + receiver + 17 getters | PT-API-01…18, PT-GET-01…17 | Carried; the draft's per-row caller/recipient rules are complete |
| Pricing mathematics | PT-MATH-01…05, PT-QUOTE-01 | Carried and materially strengthened: exact amount-delta and liquidity formulas, the fixed integer tick function with coefficients, and the width-conversion rules go beyond my original |
| Paired deposit | PT-DEP-01…05 | Carried; the draft adds the checkpoint ordering and the "no invented `uReceived` test" instruction, which corrects my framing |
| Zap deposit | PT-ZAP-01…04 | Carried; the draft adds the cap-getter short-circuit and the negative-limit tick behavior |
| Redemption and retention | PT-EXIT-01…05 | Carried; the draft states the sender-only burn, the separate floors and the zero-payout survival explicitly |
| Collective fees, protocol routing, compounding | PT-COMP-01…06 | Carried; the draft's separation of collection caller deltas from reported fee deltas is the same correction I asked for in the earlier audit |
| Manager callback protocol | PT-CB-01…07 | Carried and extended; the draft enumerates five operation values and their inner schemas |
| Helper semantics, units, rounding | PT-MATH-02…04 | Carried with substantial additions |
| Views and preview/execution divergence | PT-VIEW-01…05 | Carried; the draft separates "current-state quotation" from "promise of execution" more explicitly |
| ERC-20 surface | PT-ERC20-01…04 | Carried; the draft adds the self-transfer and zero-`from` cases and the modular-vs-checked mutation split |
| Balances, donations, native, token helpers | PT-BAL-01…07 | Carried; corrected by MINI-02 below |
| Events | PT-EVENT-01…03 | Carried; the partial-order contract and the gross/net and pre-swap payload distinctions are the draft's addition |
| Errors, precedence, propagation | PT-ERROR-01…04 | Carried and extended; the check-ordering list and the non-custom-failure inventory exceed my original |
| Absent functions | PT-ABSENT-01/02 | Carried; the draft's absent-behavior list is broader than mine and correctly excludes product-rate and deployment adaptations from the baseline |
| Quirks (16 in my original) | Distributed across PT-DEP/PT-ZAP/PT-EXIT/PT-COMP/PT-CB/PT-MATH-05 and PT-AC-01…58 | **All 16 carried.** Fifteen are stated explicitly; the sixteenth — that an ordinary deposit may swap through compounding — is the one my MINI-01 asks to be stated on the deposit route as well as the redemption route |
| Dependency limits and unknowns | Part III, PT-DEPENDS-01…05, §16 table | Carried and expanded; the settled-versus-blocking table is the draft's addition and reads as an accurate division |

## 6. Self-corrections I offer against my own earlier prose

My previous-run requirements response was the weakest of the four originals on three points. The draft already corrects all three; I record them so they cannot re-enter the baseline from my side.

- **Outgoing payout failure (my FR-RDM-07 said a failed leg payout reverts with `TransferFailed`).** That is wrong for the redemption payout path. Redemption payouts use the dependency's currency transfer helper, which reports failure as a wrapped error carrying the target, the outbound selector, the raw revert data and a native/ERC-20 context selector; `TransferFailed` belongs to the local helper used for ERC-20 pulls, for ERC-20 payments into the manager, and for the native refund. The draft's PT-BAL-05/PT-BAL-06 are correct and control; my wording does not.
- **Routing safety (my FR-FEE-05 said a failing fee manager "leaves the slice idle for the holders and never blocks a user action").** Too strong: only the notification revert is caught. The approval helper's decode failure and the factory getter failures can abort the operation. The draft's PT-COMP-03 is correct — "Do not specify 'fee-manager failure can never block users.'" — and controls.
- **Signed-width conversions (my FR-QRK-07 described the removal amounts as "narrowed through `uint128`" without stating that the conversion is a bit-preserving reinterpretation rather than a magnitude).** The draft's PT-MATH-05 states the exact rule. Mine is superseded.

Also superseded by the draft: my genesis-quote wording omitted the floor, and my callback description did not enumerate the five operation values or the `None` path's `NotPoolManager` outcome.

## 7. Handoff and provenance boundaries

- **Math-only / original prose:** confirmed. The draft contains no source listing, no fenced code, no Solidity, no source path, no line reference, no member name and no source URL. The tick coefficients and helper formulas are numerical behavior, which the brief expressly permits. The behavioral text is original prose, not copied comments.
- **Provenance:** the baseline is self-describing as source-informed; the scope and handoff paragraphs state that raw source, member responses, analyst traceability and council deliberations are maintained separately and are not prerequisites; PT-CONFORM-02 forbids the planner from filling requirement gaps by consulting target implementation source; PT-HANDOFF-01/02 keep the adaptation question separate from source equivalence and require any deliberate quirk change to be labeled as a superseding requirement.
- **Legal conclusions:** none are offered anywhere in the draft, and none should be added. The draft's statements that exact-match metadata, SPDX markers and a different implementing agent do not themselves establish clearance or an unexposed workflow are the right boundary; they are provenance statements, not legal conclusions, and I support them unchanged. MINI-05 is the only provenance edit I propose.
- **Unsatisfied dependencies:** the draft treats the concrete factory, fee manager, manager/pool engine, hooks and token implementations as external and bounded, and §16 separates what is settled from what blocks a narrower plan. Nothing in my corrections asks for those values, and nothing treats their absence as a gap in the local requirement set.

## 8. Requested edits, consolidated

| ID | Type | Requirement | Action |
|---|---|---|---|
| MINI-01 | Substantive omission | PT-DEP-02 | Add one sentence: the deposit's automatic compound may execute a pool-moving balancing swap with no tick-movement guard |
| MINI-02 | Precision | PT-BAL-05 | Name the wrapped-error target per currency path; state that ERC-20 payout acceptance reads the raw first return word rather than decoding it |
| MINI-03 | Precision | PT-VIEW-01 | Split the "low 128 bits" clause between the pool-liquidity read and the position-entry read |
| MINI-04 | Precision | PT-ZAP-02 | Note that the basket-based cap makes the permitted zap size a function of the vault's own idle balances |
| MINI-05 | Optional wording | Scope paragraph | Attribute the reconfirmation to the council's evidence retrieval |

## 9. Position statement

I **support** draft `pairtoken-requirements-draft-r1` and recommend it be finalized with MINI-01 through MINI-04 applied (MINI-05 optional). The draft's behavioral content is accurate against the verified source on every area I re-derived — interface, branch precedence, rounding, checkpoints, error predicates and precedence, event payloads, native and token-helper behavior, callback protocol and dependency boundaries — and its expressly preserved quirks are all present and correctly framed. My original's material topics are carried, and the draft improves on my original in the tick-price function, the helper failure identities, the check-ordering inventory and the preview/execution distinction. I request the five edits above, none of which changes the baseline's semantics or introduces product behavior.

This is the single advisory round on this draft. It is not implementation authorization, does not modify the draft, and creates no approved clean-room process.

*Prepared by MiniMax (council member) for the advisory pass on `pairtoken-requirements-draft-r1`. Source locators above are original `src/pair/PairToken.sol` lines and dependency file paths, for analyst use; they are not proposed handoff content. No file was written or modified in this turn.*
