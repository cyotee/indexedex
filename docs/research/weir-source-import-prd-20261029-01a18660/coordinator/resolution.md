# Weir source-import PRD — resolution ledger

Draft: `coordinator/draft.md`, immutable revision `weir-import-prd-r1`, SHA-256 `633e430bd6b551c9cabc3147ad9d3275f07534ac50364b30503392f161829b51`.

The draft has 37 normative WI requirements and 69 distinct AC rows. All four originals are preserved. This ledger records coordinator decisions; pending advisories are not approvals.

## Original contribution dispositions

### Astra

- Adopt the source-grounded normative core, exact arithmetic, 66 AC scenarios, source locators, F0-F3 fixtures and complete 39-file license inventory.
- Explicitly adopt the narrow free-struct/import exception rather than leave its authority ambiguous.
- Add the actual compatible versioned OZ V5 route; do not leave a resolved choice open.
- Add the signed-idle wrap characterization and actual runtime/test import-graph licensing distinctions.
- Keep source/cast semantics distinct from checked arithmetic, fee timing, native sync assumptions, partial fills, callback visibility, conditional event emission and source-fidelity limits.

### Kimi

- Adopt full constructor/receive/function/inherited surface, per-pool ledger and balance ownership, exact rollback, bounded deterministic campaigns, fee/cushion/preview coverage and limitations.
- Retain source-specific preview semantics; no universal preview==withdraw, fixed-output or ERC20 compliance gate.
- Correct any interpretation that a caught reentrancy rejection necessarily reverts the outer call. Catching and propagation are separate cases.
- Do not adopt unverified command flags for invariant run/depth settings; current repository artifact commands are the documented gate.

### Grok

- Adopt generic OZ mismatch evidence, precise ordinary/nested guard distinction, real-manager deployment, concrete hook/callback/return-mode coverage and no silent v4-style error/layout substitution.
- Resolve the generic OZ concern using the existing `external/openzeppelin-contracts-v5/` family. The original did not establish that this route was absent; current compatible files and used SafeERC20 paths were subsequently compared by coordinator.
- Reject the original claim that direct narrowing/signedness casts perform range checks or inherently revert. Keep uint128/uint64 truncation and negative-to-uint256 wrapping distinct from checked arithmetic around them.
- Reject fail-closed compound-idle reasoning based on those raw casts. A funded extra debt may settle after idle wraps; characterize, do not patch.
- Correct AC62: 1,000bps is 10%, not all harvested fees. Correct zero-denominator errors at the actual FullMath/division expression.
- A fee-bearing price-moving swap may change pending fees; no assertion otherwise without isolating the fee condition.
- Do not copy hand-derived selectors, storage offsets, source line counts/locators or repeated hash tables as independent authority. Final values use actual metadata, frozen source and future compiler evidence.
- Full retained original retransmitted for delivery only, not revised; visible original prefix/suffix checked. No additional advisory round.

### MiniMax

- Adopt structural compile-gap evidence, actual graph licensing (AGPL hashing helper, GPL math and literal BSL/BUSL distinction), current artifact workflow and source/deployed-parity separation.
- Reject the unnecessary 5.6.1 OZ upgrade/storage shift. Existing canonical versioned V5 inherited files match the frozen files; no owner decision to change storage is needed.
- Reject bare forge-std/Test as a new implied exception to the selected ladder. Use dedicated TestBase_WeirVaults extending CraneTest, without making the SUT a proxy product.
- Reject “no configured chain4663 endpoint.” Root foundry.toml includes Robinhood mainnet aliases. Actual RPC/archive/reference-state availability is untested; keep parity on the reference chain and report missing evidence, not a green skip or substitute chain.
- Correct fee-base description: `_compound` reads the FIRST caller-delta return, not informational second `feesAccrued`. Pool donations can be real harvested value; they do not by themselves prove an unbacked-fee exploit.
- Reject required zero unwanted-token outputs, universal idle<=2, and constant-product swap expectations. Preserve actual concentrated-liquidity execution, partial fills, one-sided idle and exact refunds.
- Correct first issuance to L-1,000 and later issuance to the ratio; no universal later L<=1,000 rejection.
- Correct withdrawal validation order; use frozen source locators, not inconsistent line numbers in the original.
- Deposit leftovers are refunded, not automatically booked as idle. A failed initial deposit rolls back auto-creation.
- Reject ERC20-string grep bans: the source legitimately imports/uses ERC20 plumbing. Machine ABI/fidelity checks prevent added interfaces without pinning prose.
- No assumed arbitrary enum fall-through: ABI enum decoding constrains valid action values. No invented successful unknown-pool share transfer beyond zero/available balances.
- Array getters are indexed, not a whole-array iteration whose gas necessarily grows with count.
- No commit prerequisite, private dependency clone, shared-source rewrite, automatic license clearance or new runtime result.

## Process deviations and limits

- Astra saved its assigned original via apply_patch. Kimi/Grok complete inline deliveries were archived via coordinator apply_patch; Grok needed one delivery-format repair because substantive commentary was elided by Native output.
- MiniMax reported using harness write on its single assigned Markdown path despite the apply_patch-or-inline instruction. Preserve the delivered original and record the deviation; do not silently claim all member writes complied or repeat it. No other mutation was reported by that member; no independent filesystem-wide audit is claimed. The advisory explicitly repeats the boundary.
- All four exact model routes and process ancestry are recorded in RUN.md. Static analysis and integer derivation are not runtime tests, legal clearance or deployment approval.

## Kimi advisory — SUPPORT WITH CORRECTIONS

- C1 formula precision: **adopt as an explicit-stage clarification**, not evidence of a reachable fee truncation. Write `delta_j` as the signed int128 returned by BalanceDelta.amount0/amount1; `Fj=0` if nonpositive, else `uint256(uint128(delta_j))`. Coordinator read the frozen accessors: both return int128. Thus a positive component is at most 2^127-1 and fits uint128.
- C1 proposed hook case above 2^128-1: **reject as impossible under the actual return type**. No real BalanceDelta component can satisfy it; do not add a test that fabricates a wider delta or label an established type impossibility as an unexplained reachability gap. Keep the genuine uint128 preview/uint64 timestamp and negative-idle casts distinct.
- Editorial B/L terminal line locators: **adopt**, consistently use B:1-88 and L:1-68.
- AC59 hook stages: **adopt**, say zero-delta poke/add/remove/swap rather than create/add/remove/swap; createVault neither has hookData nor triggers a manager hook stage.
- Preserve the advisory's support for current V5 routing, five free-struct constructions, first-return fee accounting, fee denominator, residuals, configured aliases, exact callback/rollback semantics and bounded invariants.

## Grok advisory — SUPPORT WITH CORRECTIONS

- Complete advisory recovered intact from the tail of its Native transcript, excluding only transcript role/tool delimiters. No further delivery-repair turn or review round.
- C1: **principle already adopted; claimed locator is incorrect.** Actual AC66 is the release-evidence gate and contains no cast-revert claim. WI-22/WI-31 and AC67 already specify the negative-idle conversion and later settlement split correctly. Preserve that content rather than overwrite the unrelated release gate.
- C2: **adopt** broader AC51 characterization: a still-open non-native sync may originate before unlock or from a legitimate hook/token callback before native payment. Preserve the native-pay source and exact rollback, without adding sync(0).
- C3: **adopt explicit conditioning** in AC63: standard supported domain, after successful top-level transaction, outside callbacks, without hostile return-delta or other intentionally introduced invariant-breaking effects. AC64 remains a separate hostile characterization campaign.
- Many WI locators in the advisory do not match the frozen draft (e.g. WI-27 is ownership, not idle casting; WI-17 is withdrawal entry, not first-return accounting). Preserve the advisory verbatim but use actual draft/source identifiers in final edits. No invented “nine identical OZ files”: six selected inherited/interface files were byte-identical; used SafeERC20 paths were separately compared, not the whole library.
- Preserve the advisory's useful support for the selected V5 route, five type constructions, first-return deltas, 10,000 denominator, residual outputs and configured aliases. No original range-check/fee/idle overstatement is reinstated.

## Astra advisory — SUPPORT WITH CORRECTIONS

- C1: **adopt** self-directed inventory accounting. Compound physical change is N+S where S is the treasury cut actually delivered to Weir; idle follows N only. Track self-treasury cuts and self-recipient withdrawal proceeds as unassigned receipts alongside direct donations. Extend AC32/AC34 with the source-derived F1/F0 numbers; no new production restriction or rebooking.
- C2: **adopt** rollback at the actual failed call subtree. An uncaught transaction revert undoes the whole transaction; a caught Weir/reentry failure does not erase earlier/later outer successes. Debug log captures are not receipt persistence proof. Only Weir operations that complete their own unlock imply relock/global delta closure; unguarded calls inside another owner's unlock do not close it. Clarify WI-30/33 and AC51/54/58/63.
- C3: **adopt** actual callback preconditions. AC59 records real zero-delta-poke/add/remove/swap operations only when source performs them; no createVault hook stage or invented dedicated poke hook. AC57 uses native currency0 with a positive cut and an actual current-owner receiver, or a deliberately callback-capable peripheral. Ordinary ERC20 receipt is not a callback. AC54/56 identify the real caller, shares and roles.
- Adopt source-terminal locator normalization. Preserve all unchanged source-fidelity, V5 import, first-return accounting, residual-output, configured-alias and license limits.
- Final candidate revisions are coordinator changes to the 69-row draft, not a new member-approved draft; frozen r1 remains unchanged.

## MiniMax advisory — SUPPORT WITH CORRECTIONS

- C1: **adopt exact direct-import table** for all 22 statements and the additional free-type import. Correct its examples: FullMath/FixedPoint96/128 live in common Uniswap libraries, not v4/libraries; the selected types are free ModifyLiquidityParams/SwapParams, not a nonexistent PoolOperation library namespace. The frozen interface is not edited/copied; canonical interface selection is recorded. Canonical SafeERC20 is not modified to restore a frozen unused import.
- C2: **clarify the already correct distinction**: six selected inherited/interface files are byte-identical; SafeERC20 used paths are compared, not whole-file equality. Do not assert that its only whole-file differences were proved to be two lines.
- C3: **adopt general open-sync condition**, already aligned with Grok/Astra. Coordinator narrowly read CPM: sync is external with no onlyWhenUnlocked modifier; ERC20 settle resets the currency slot, native settle rejects a still-synced ERC20 with positive msg.value. These are same-transaction transient conditions, not proof of a persistent cross-transaction third-party DoS. No repair to native pay.
- C4: **partially adopt** explicit preview boundaries. With L=T=2^20, s=2^128+7 truncates to7, while s>=2^236 overflows the checked product (including equality). **Reject zero-supply division panic:** W returns (0,0) before dividing. Keep library Error("liquidity overflow") and actual division-by-zero expression tests separate. Existing AC39/44/45 cover them; no fabricated case.
- C5: **adopt concrete donation topology**. Coordinator read CPM donate: it exists and requires unlock. Auxiliary IUnlockCallback router calls donate and settles its own debt before its unlock closes; only then invoke Weir compound. A mere token transfer/settle is not pool fee-growth donation. Correct the advisory's mixed F1/F2 narrative: F1 leaves one-sided idle19 and adds zero liquidity; F2 starts from that state and adds17 with idle(2,2).
- C6: **partially adopt hard fork inputs under actual AC65/WI-37, not nonexistent AC70**. Pin chain/alias/block/hash/archive/reference code and manager getter/address, equivalent state and role mapping. Reference Weir address is already supplied. **Reject production owner private-key requirement:** local fork caller impersonation can exercise roles, and ordinary money actions are permissionless subject to holdings. No real-chain transaction. Add a concrete fresh-selected-pool/fork-snapshot comparison construction rather than compare unrelated live states.
- C7: **reject the mistaken same-pool interpretation**. AC35 means two distinct pools sharing one currency, e.g. (A,B) and (A,C), each with distinct sorted currencies. Explicitly define aggregate per-currency idle plus unassigned physical receipts across those pools. Do not remove that nonvacuous coverage.
- Remaining concerns are covered by first-return hook-sensitive accounting, separate supported/hostile campaigns, actual self-directed inventory accounting and conditional unrun wrap characterization. Do not repeat the advisory's statement that every full user exit necessarily leaves exactly1,000 liquidity; only total shares remain1,000 generally, while exact liquidity is proportional (F0 specifically leaves1,000).
- Advisory header misnames the frozen revision and references a nonexistent AC70; preserve it verbatim but final provenance uses the assigned actual `weir-import-prd-r1` path/hash and real identifiers. Its original recommendation was the 5.6.1 upgrade, not the final compatible V5 route it later described as adopted. No retrospective original edit or false unanimity.

## Advisory status and final disposition

All four same-task advisory turns settled and are preserved: SUPPORT WITH CORRECTIONS from each. All substantive concerns above are adopted, clarified, rejected with source/type rationale, or retained as explicit future implementation evidence gates. There is no missing member, second round, new model route, unapproved source edit, or implementation claim.

The final coordinator revision retains 37 WI requirements and 69 AC rows, adds exact import paths and precise fixture/precondition wording, and leaves the frozen draft/originals unchanged. The requested co-located PRD is the final deliverable; source copying and all execution remain a separate task. Compiler/runtime/fork/legal questions are future acceptance inputs, not unreported passes.
