# Astra requirements advisory: weir-import-prd-r1

## Identity and reviewed draft

- Member: Astra, continued independent council author.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`; provider/model exposed earlier in this session were `chatgpt-subscription` / `gpt-6-astra`. The reasoning setting was not independently exposed.
- Session: `01a188d5-0ee8-70a7-967e-eee1bd8e7dbf`.
- Advisory: exactly one requirements advisory.
- Draft: `docs/research/weir-source-import-prd-20261029-01a18660/coordinator/draft.md`.
- Frozen revision: **weir-import-prd-r1**.
- Owned output: `docs/research/weir-source-import-prd-20261029-01a18660/members/astra/feedback.md`.

## Disposition

**SUPPORT WITH CORRECTIONS.**

The draft preserves the baseline rather than adopting the behavior-changing dependency upgrade or erroneous arithmetic/safety expectations present in some originals. Its source-import boundary, explicit free-struct adjustment, versioned V5 routing, first-caller-delta accounting, 10,000 fee denominator, cast semantics, residual-output handling, and real-manager characterization policy are suitable.

Three bounded corrections remain: account for allowed self-directed payments in the physical-inventory formula; scope rollback and manager-lock assertions to the correct call boundary; and make callback-test preconditions reflect the calls the source actually performs. The first two overbroad formulations and AC59's creation-stage wording were also present in my original contribution. Their inclusion in that original is not a reason to preserve them.

No change below requests a production behavior change or another advisory round.

## Reading and evidence

I read the complete frozen draft through its final council-status paragraph in bounded, contiguous chunks:

- Lines 1-220.
- Lines 221-370.
- Lines 371-470.
- Lines 471-555, through the end.

The supplied length is 77,121 characters. I did not recompute its length or a hash; the revision/path and supplied length identify the reviewed artifact, not an independent integrity attestation.

I also read all three peer originals completely, not their feedback:

| Original | Completed reading |
|---|---|
| `members/grok/response.md` | Lines 1-200, 201-380, 381-540, through the end |
| `members/minimax/response.md` | Lines 1-180, 181-400, 401-620, 621-820, 821-947, through the end |
| `members/kimi/response.md` | Lines 1-200, 201-400, 401-576, through the end |

Paths in this table are relative to the run root `docs/research/weir-source-import-prd-20261029-01a18660/`.

I read the complete admitted `coordinator/source-notes.md`. Its canonical V5 comparisons and related repository observations are supplied coordinator evidence, not a new dependency audit by this author. The configured Robinhood aliases are reported in the draft; I did not reopen configuration or exercise an endpoint.

The complete brief, frozen manifest, three domain sources, and previously examined dependency source remain existing session context. Narrow source rechecks for the material concerns were limited to:

- Frozen W, `src/WeirVaults.sol.txt:145-183`: creation and deposit call order.
- Frozen W:319-427: compound accounting, swaps, and setters.
- Frozen B, `src/base/WeirBase.sol.txt:56-88`: pay/take/settle/refund dispatch.

These paths are under the run's `source-snapshot/sources/`. No unrelated rules or fixtures were reopened. No new network research, shell/Git/build/test/install/deploy/wallet action, delegation, or external message was performed.

## Material corrections

### C1. Include self-directed treasury cuts and withdrawal proceeds in inventory reconciliation

**Affected text:** WI-22, WI-24, WI-33; the arithmetic section's compound-and-settlement ledger; AC32, AC34-35, AC63.

**Problem.** The arithmetic paragraph says that, for ordinary exact-transfer/non-adversarial-hook success, the physical Weir balance change for a compound phase equals `Nj`. That is false when the treasury is Weir itself, which is permitted by the baseline. The treasury cut is then another physical receipt by Weir, while the source still excludes it from recorded idle and reinvestment sizing.

Likewise, a withdrawal may validly designate Weir itself as its token recipient. Its returned proceeds then become physically held inventory without being credited back to idle or shares. An invariant whose unassigned-inventory ledger counts only direct donations would fail faithful ordinary operations.

**Source rationale.**

- W:408-412 rejects only zero treasury, not `address(this)`.
- W:327-330 takes the fee to the treasury read at each call site.
- W:332-359 excludes that cut from retained-fee net and idle.
- B:68-76 sends positive manager credits to the supplied recipient.
- W:193 rejects only zero withdrawal recipient; W:313-315 settles to that recipient and returns positive nets.

**Requested replacement for the compound inventory paragraph:**

> For an ordinary exact-transfer compound phase without additional callback-driven asset movements, let `Sj` be the portion of that currency's treasury cut actually delivered to the Weir address. The physical Weir balance change is `Nj + Sj`, while the recorded idle change remains the source result of `int256(Ij) + Nj`. When the treasury is external, `Sj = 0`; when that cut is sent to Weir, `Sj = Cj`. Self-directed cuts are unassigned physical inventory, not an additional idle credit. If callbacks independently move assets, record those movements separately rather than asserting this restricted phase formula.

**Requested WI-24/AC63 clarification:**

> Unassigned inventory includes every independently tracked physical receipt not booked to a vault ledger, including direct donations, treasury cuts sent to Weir, and withdrawal proceeds sent to Weir. A nonzero self-recipient or self-treasury remains valid; do not reject it, sweep it, or rebook it as an import-only repair.

**Exact acceptance extensions to existing rows:**

1. Extend AC32 with F1, but set treasury to the Weir address before compounding. Gross currency0 fees are 20, cut is 1, recorded idle0 is 19, added liquidity is zero, and physical currency0 held by Weir increases by **20**, not 19. Track the extra 1 as unassigned inventory. Total shares remain K and the event remains `Compounded(id,20,0,0)`. An immediately repeated no-fee compound does not absorb that unassigned unit into idle.
2. Extend AC34 with the F0 full assigned-share withdrawal to `recipient = address(Weir)`, without fees or zap. Returned outputs and physical Weir receipts are each **1,047,575**; recorded idle remains `(0,0)`; L and T remain 1,000; the holder's shares become zero. Those receipts do not mint shares or create a new idle claim.

These expectations are source-derived arithmetic proposals, not executed results.

### C2. Define rollback and lock assertions at the actual reverting/unlock boundary

**Affected text:** WI-11, WI-30, WI-33; the acceptance-matrix introduction; AC51, AC54, AC58, AC61, AC63-64.

**Problem.** WI-30's reference to rolling back "all transaction logs," combined with the blanket rule that every failure row includes complete rollback, can be read as requiring whole-transaction rollback even when an enclosing contract catches a failed Weir call or a peripheral catches a rejected reentrant call. AC54 correctly distinguishes catching from bubbling, but the global requirement needs the same condition.

WI-33's lock assertion also needs to distinguish an unlock-owning operation that has returned from an unguarded method called inside somebody else's still-active unlock. `createVault`, `transferShares`, and views do not acquire or close the manager lock.

**Source rationale.**

- W:175-177,199,209 call manager unlock; W:212-217 does not.
- W:145-156 performs a state read and local vault creation, not unlock.
- W:178-183 checks shares before credit/refund; W:199-203 checks output minima after callback settlement.
- The examined real manager's CPM:55-64 checks all deltas and relocks only when its own unlock completes successfully.
- W's guarded entry points can reject a nested call that a real token/hook/receiver catches; the source does not require that peripheral to propagate the failure.

**Requested replacement/qualification:**

> A failed Weir invocation reverts all effects and receipt logs in that reverting call subtree. If its revert propagates through the enclosing transaction, all transaction effects and receipt logs revert. If an enclosing router catches it, earlier or later successful outer effects remain. Similarly, a caught rejected reentrant call does not by itself revert a successful outer Weir operation. Rollback snapshots must identify the exact invocation whose failure is being asserted. Debug call traces or test-instrumented log captures are not proof that reverted receipt logs survived.
>
> After a successful deposit, withdrawal, or compound has completed its own manager unlock, the manager is relocked and all address/currency deltas required by that unlock are closed. Do not apply that assertion at callback checkpoints or immediately after an unguarded method returns inside an independently owned unlock. Apply transaction-level invariants only after the enclosing operation has closed.

**Concrete acceptance clarification:**

- In AC51, have the router sync the ERC20 and catch the failing native deposit. Snapshot immediately before the Weir call: the deposit subtree rolls back, but the earlier router sync persists for the rest of that enclosing transaction unless the router clears it. A second case that lets the error escape the whole transaction has whole-transaction rollback.
- In AC54, explicitly retain both outcomes: catching the rejected reentrant call permits the outer operation to finish if its remaining checks pass; bubbling it causes the outer failure and appropriate full subtree rollback.
- In AC58, distinguish the direct nested-call error from any hook/manager wrapping on its propagation path. An auxiliary unlock that catches `AlreadyUnlocked()` remains open until its owner completes it; the failed inner Weir call does not relock it.

This correction narrows test assertions to actual EVM call behavior. It does not weaken rollback for an uncaught failed deposit, withdrawal, or compound.

### C3. Make hook and receiver test stages executable without inventing callbacks

**Affected text:** WI-11, WI-21, WI-28-29; AC54, AC56-57, AC59.

**Problem.** AC59 asks a non-delta hook to record each "create/add/remove/swap stage's supplied hookData." Weir `createVault` does not call a pool hook and has no hookData parameter. Pool initialization is a separate manager operation; it is not a Weir creation callback. The same row's unqualified poke/reinvestment ordering should state the conditions under which those calls exist.

AC57's owner-treasury receiver must also actually receive control. An ordinary ERC20 transfer does not automatically call an arbitrary recipient contract's receive function. The intended treasury mutation is executable with a native currency0 cut or an explicitly callback-capable peripheral, not merely with an ERC20 treasury address.

**Source rationale.**

- W:145-156 derives the ID, reads slot0, records state, and emits `VaultCreated`; it does not invoke a hook.
- W:320-321 skips the poke for zero liquidity.
- W:346-354 performs reinvestment only when calculated liquidity is positive.
- W:329-330 can reach the first treasury receiver before the second treasury destination is read.
- B:68-76 delegates credit transfer to manager.take; the type of currency/peripheral determines whether its recipient gets control.
- W:212-215 uses actual `msg.sender` for share transfers, so a token-driven callback moves the token's own shares, not an unrelated holder's.

**Requested AC59 replacement:**

> In an existing nonzero-liquidity vault, use a valid non-delta hook to record applicable manager liquidity-poke, add, remove, and swap callbacks and their supplied hookData. Require a positive reinvestment amount in the fixture that asserts poke-before-reinvestment-before-user-action ordering; separately assert skipped poke at zero liquidity and skipped reinvestment at zero calculated liquidity. HookData must be unchanged at each actual manager call. For `createVault`, assert the slot0 read, local record/array change, and `VaultCreated`, and assert that it does not invoke a pool hook. Pool initialization is separate setup, not a Weir hookData stage.

**Requested AC57 precondition clarification:**

> Use a native/ERC20 pool with currency0 native and a strictly positive first treasury cut, with the initial treasury receiver also being the current owner. Its native callback changes treasury before the second cut. Alternatively, use an explicitly specified callback-capable peripheral and record the actual caller and authority. An ordinary ERC20 recipient is not presumed to receive a callback.

Apply the same actual-caller discipline in AC54/AC56: identify whether the reentrant caller is the token, hook, payer, treasury, or output recipient; provide that caller's required shares/owner status when success is expected. Preserve exact errors when its own authority or balance is insufficient.

## Required fidelity checks: disposition

| Requested focus | Advisory conclusion |
|---|---|
| Current versioned OZ V5 route | Support `@crane/contracts/external/openzeppelin-contracts-v5/` consistently. Coordinator notes supply the matching inherited-file and used SafeERC20-path comparisons. Preserve compiled-layout/ABI/token-return gates. Do not restore the mixed generic tree or the 5.6.1 namespaced-guard upgrade. |
| Free-struct adjustment | Support WI-04's explicit five constructions: four ModifyLiquidityParams constructions and one SwapParams construction. This resolves the former proposal ambiguity without allowing parameter, tuple, selector, or logic changes. |
| Explicit casts versus checked arithmetic | Support WI-30/31, AC39, AC46, and AC67. Explicit narrowing truncates; signed/unsigned conversion does not validate range. Surrounding arithmetic, negation, library checks and later settlement can fail separately. No automatic fail-closed assertion belongs here. |
| First caller-delta return | Support WI-15 and WI-21/22 and AC16/60. W binds the first return and ignores the second. `pendingFees` and harvested caller delta need not agree under hook effects. |
| Performance-fee denominator | Correct: 10,000. A cap of 1,000 is 10%, not 100%. F1/F2 and AC32 preserve exact rounding. C1 only corrects physical receipt attribution when the cut is self-directed. |
| Residual outputs and deposit leftovers | Correct: WI-15/19/20 and AC15/24/25 preserve actual signed deltas, payer refunds and possible two-currency withdrawal outputs. No strict zero-opposite-output or idle<=2 rule should return. |
| Native sync | Support WI-29 and AC51. Do not insert sync(native) as an import fix. C2 clarifies the scope of rollback when the router catches that characterized failure. |
| Configured Robinhood aliases | Accept the draft's supplied observation that `robinhood_mainnet`, `robinhood_mainnet_public`, and `robinhood_mainnet_alchemy` are configured. Alias presence does not prove RPC success, archive access, manager identity, or equivalent state. Do not revive the peer assertion that chain4663 parity must be moved to another chain. |
| Callback and rollback conditions | Broad structure is correct; apply C2 and C3. Do not require hook creation callbacks, automatic recipient callbacks for ordinary ERC20s, universal outer rollback after caught failures, or lock closure while an enclosing unlock remains active. |
| Stateful invariants | AC63/64 correctly separate supported-domain invariants from hostile characterization. Extend unassigned-inventory tracking per C1 and retain end-of-operation boundaries per C2. Include all share recipients, including Weir. |
| AC67 wrap characterization | Correctly conditional on a real reachable manager/hook state and independent backing. Failure to construct that state is a reachability gap, not permission to inject storage or declare cast safety. |
| Licensing and release evidence | Support separate frozen and actual resolved graphs, runtime helper versus test-only licenses, and explicit unresolved release gates. No legal clearance is established by this advisory. |

## Disposition of my original proposals

The draft retains the substance of all original WI groups. This table records their disposition without requiring a second full PRD.

| Original proposal | Disposition in r1 / this advisory |
|---|---|
| WI-01-03: destination, preservation, provenance | Adopted. Support the three-file destination, frozen research corpus, explicit diff allowlist, and separate original/adjusted hashes. |
| WI-04: dependency proof and free-struct issue | Adopted and improved: r1 explicitly permits the five type constructions and selects the versioned V5 route. My original left the OZ route unverified and type exception for coordinator adoption; that uncertainty is appropriately resolved by supplied source evidence, not a behavior-changing upgrade. |
| WI-05-07: license, compiler, excluded adaptation | Adopted. The expanded actual-graph license requirement and rejected 5.6.1 route are appropriate. No new profile, viaIR, wrapper or economic repair. |
| WI-08-11: identity, structs, ABI and callback | Adopted, with a useful canonical ABI appendix. Apply C2's unlock-boundary clarification, not a callback guard addition. |
| WI-12-20: entry, reserve shares, issuance, transfers, withdrawal and zaps | Adopted. Idle dilution and same-deposit swap-fee attribution remain explicit. Extend existing inventory acceptance for valid self-recipient withdrawals under C1. |
| WI-21-25: compound, inventory and views | Adopted. Correct my original overly narrow physical-balance formula through C1; retain first-return, signed-cast and limited-preview semantics. |
| WI-26-31: administration, ownership, guards, payments and failures | Adopted. Apply C2/C3 to my original global rollback and callback-stage wording. These are requirement corrections, not source changes. |
| WI-32-37: real-manager tests, exact expectations, campaigns and parity | Adopted. r1's explicit CraneTest choice and actual Robinhood alias note improve implementability. Retain all missing-runtime and unavailable-fork labels. |
| F0-F3 and AC01-66 | Substantially retained. Support the numeric ordinary fixtures and 66-row coverage; correct/extend the affected rows identified above. AC23 and AC33 remain subject to real reachability and their stated fee/state preconditions. |
| Full 39-file license inventory and preservation-risk register | Adopted; runtime hashing-helper license distinction is a useful addition. No blanket license conclusion. |
| New AC67-69 reconciliation rows | Support. They address cast safety, current V5 selection and resolved-license-graph evidence without prescribing remediation. |

No original proposal for economic repair was omitted: none was authorized or proposed as baseline work. The original contribution remains preserved; this advisory does not replace it.

## What was not adopted from peer originals, and why

These are dispositions of original proposals, not reviews of peer feedback.

### Grok

- Do not restore R-20/R-25/R-32/R-35 and related AC expectations that explicit uint128/uint64 or signed-to-unsigned casts themselves panic or make compound fail closed. W uses raw conversions. The draft correctly separates arithmetic errors from cast results and adds AC67.
- Do not restore AC-62's claim that fee=1,000 sends the entire harvest to treasury. W's denominator is 10,000.
- Do not restore AC-93's unconditional division-by-zero panic for the equal-bound liquidity path. Frozen FullMath uses an empty revert there; draft AC45 preserves that distinction.
- Do not turn AC-76's outer-rollback wording into a requirement when a peripheral catches the nested failure. C2 makes the required distinction explicit.
- Do not restore a blanket pending-fees-unchanged assertion for a price-moving swap. A fee-bearing swap can accrue new fees.
- Grok's generic-tree mismatch was useful evidence, but its conclusion that a compatible OZ route remained unresolved is superseded by the supplied versioned V5 comparison. No shared-tree upgrade is needed.
- Predicted selector literals, hand-derived layout tables, and inconsistent source-line/metadata entries in that original are not substitutes for the frozen manifest and actual compiler evidence. r1's artifact-derived ABI policy is preferable.

### MiniMax

- Reject D-11 through D-13's recommended 5.6.1 route and namespaced-guard storage shift. This import has an existing versioned V5 candidate that preserves the inherited layout and used semantics; recording a deviation does not authorize an unnecessary behavior change.
- Reject B-14/R-01's second-return fee premise. W:322-326 uses the first caller-delta return. Pool donations through the real manager are funded fee growth; they are not automatically an unbacked harvest.
- Reject idle<=2 and non-wrapped-idle safety invariants across unrestricted success paths. One-sided ordinary idle can exceed two, and raw signed conversion does not prove solvency.
- Reject AC-29/30's unconditional zero residual outputs, B-15/R-04's attribution of new deposit leftovers to idle, and R-05's claim that unconsumed input necessarily remains in the pool. Preserve exact net settlement/refund/output flows.
- Reject AC-45's inference that any non-first deposit liquidity <=1,000 mints zero shares. The actual later-issuance quotient controls; the genesis threshold does not apply again.
- Reject the claim that missing a numeric chain-ID alias proves chain4663 unreachable, moving parity to another chain, and skip-as-pass handling. r1 supplies named Robinhood aliases and correctly leaves live availability and equivalent state unproven.
- Do not adopt a bare Test-only exception, an ERC20-token text ban that would reject Weir's own IERC20/SafeERC20 plumbing, or source-hash equality after approved edits. The draft's CraneTest ladder and transformation-aware comparison are the usable requirements.

### Kimi

- Support its complete ABI, inherited-surface, guard, residual-output and preview-limitation coverage, which r1 incorporates.
- Do not promote its AC-WV-043 pending-fee/harvest reconciliation into unconditional equality merely because there is no intervening external transaction: hook-return deltas can change the first caller delta. r1's AC60 is the necessary qualification.
- Do not require AC-WV-051's complete outer rollback when a nested guard failure is caught. Apply C2.
- Do not require constructing a zero-liquidity tiny-share withdrawal by storage injection merely to satisfy AC-WV-032. r1 AC23 properly conditions unreachable branches.
- Its original import-path-only formulation did not resolve the canonical free-struct mismatch; r1's explicit type-resolution exception is justified and remains narrow.

## Minor editorial correction

WI-02 and several inherited locator ranges still use `B:1-89` and `L:1-69`, while the draft's own source table correctly gives 88 and 68 source lines. Normalize terminal-line ranges to `B:1-88` and `L:1-68` where they intend the complete source. This is not a behavior or scope change.

## Limits and closing

This is a static, single-round requirements advisory. It does not establish compiler success, emitted ABI/layout equality, runtime manager parity, fork accessibility, economic safety, deployment readiness, or legal clearance. Current canonical V5 and Robinhood configuration observations are accepted as attributed coordinator evidence, not independently re-audited here.

No peer feedback was read. No original, draft, code, configuration, or other PRD was edited. Only this assigned feedback file was written using apply_patch.

The coordinator can resolve C1-C3 and publish its own final revision without another advisory round. This advisory neither replaces my original contribution nor authorizes implementation.
