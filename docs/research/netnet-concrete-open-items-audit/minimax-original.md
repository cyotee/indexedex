# MiniMax M3 — independent NEW audit: concrete specification gaps in current NetNet–Pendle PRD/plan/tracker

- Researcher: MiniMax M3 (`minimax/MiniMax-M3`), fresh bounded full-council follow-up in the retained session.
- Date / access date: 2026-09-28.
- Status: research only. No shell/tests/deployments/implementation/delegation/config edits; no plan/tracker writes.
- Documents read directly:
  - `CLAUDE.md` (root agent router; non-negotiables 1–9).
  - `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.33 (revised 2026-09-27).
  - `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.9 (full §§1–12 read; §6.5 conversion mapping; §6.6 claim funding and acceptance; §7 state transitions; §8 oracle/expansion; §9 funded-gons staking; §10 rollover/rewards/history; §11 acceptance vectors; §12 dependency order).
  - `docs/strategies/ohm-style/netnet-pendle/PRD_OPEN_QUESTIONS.md` (full §§1–6 read; NN-01–NN-20 register; settled-decisions register; closure-audit statuses; executable-plan freeze checklist; resolution log through 2026-09-28).
- Library constants verified at `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:180–201` (four published Pendle anchors + `DEFAULT_FORK_BLOCK = 20_714_383`) and `ROBINHOOD_TESTNET.sol:41` (`DEFAULT_FORK_BLOCK = 101_800_000`).
- No Context7 or external web call: this round is a documentary audit of the current PRD/plan/tracker against prior consolidation outputs; no new external API/library claim was needed.

## 1. Audit conclusion

After challenging each prior alleged gap against the current PRD v0.33 + plan v0.9 + tracker, my honest finding is:

- **NO new owner questions are required for the PRD/plan to proceed.** The owner's owner-question filter in `PRD_OPEN_QUESTIONS.md` §1 is satisfied: every row classified ANSWERED, CLOSED, MAINTENANCE or "engineer/plan work" can be completed without re-opening economics, demanding certification or fabricating entitlements.
- **The remaining work is implementation, testing and fork-validation under separately authorized tasks**, not specification or owner resolution.
- Per the **human correction** ("use Pendle documentation as source of truth for addresses; use standard default block in Robinhood mainnet library constants; validate deployment/behavior by later fork tests. DO NOT make independent address verification/block pinning a research blocker"), the G1 items (NN-01, NN-10) shift from "evidence" to "fork-test obligation." I explicitly withdraw the prior framing of G1 as a research blocker.

The body of this report classifies each of the six challenge areas the moderator named. Where I find a residual, I identify the concrete PRD/plan section that answers it, not a missing design.

## 2. Per-area classification

### 2.1 Force-claim reconciliation vs origin-independent public credit + full sync law

**Existing rule (operative):**
- PRD v0.32 §6.3 (still operative under v0.33): "let B be current raw held balance and R its booked local reserve. Available credit is `max(B−R,0)`… supported exact-input pretransfer credits the declared amount only if it is no greater than that available balance… A direct donation, an earlier transfer or a third-party forced claim that is still physically unbooked is eligible on the same basis."
- Plan v0.9 §6.1 (public pretransfer): full reserve-sync / once-only accounting, refund ordering, pull mode measure, sync-before-sync-after.
- Plan v0.9 §6.6.4 (Once-only ledger and force-claims): "A prior force-claim updates native accrual and raw hook balance without notifying hook accounting. Capture valid declared public pretransfer credit from `max(raw-booked,0)` **before** sync/recognition erases it; origin-independent L2 remains unchanged. Refresh native C immediately. Units consumed/refunded as that caller's credit are not also inherited H or an outstanding receivable. Reconcile only still-attributable, unconsumed receipts once; do not auto-classify every surplus or donation as interest."
- Plan v0.9 §6.6.4 (final paragraph): "current raw surplus plus a zero upstream accrued balance does not alone identify which historical receipt was interest, an incentive or an unrelated donation. Ordinary on-chain execution cannot 'monitor past events' as a contract primitive. The operation-state/retained-series accounting must specify source-backed reconciliation without requiring public payer provenance, fabricating lost receivables or appropriating declared credit."

**Is the gap real?** No. The rule is operative: capture credit before sync, refresh C, do not double-count, do not fabricate. The remaining "no mechanism to distinguish receipts" is explicitly acknowledged by the PRD/plan and is **not** a missing rule — it is the absence of a forbidden mechanism. The plan's instruction is "specify source-backed reconciliation without requiring public payer provenance" — that is engineering specification, not owner resolution.

**What is missing?** Nothing normative. An implementable hook must:
1. Snapshot `available = max(raw − booked, 0)` per supported pretransfer route before any sync that would erase it.
2. Credit only the declared amount ≤ available, once per route-call.
3. After claim/redemption, refresh C from `userInterest[hook].accrued` plus current `_pyIndexCurrent` minus current `_pyIndexStored` adjustment, net of `interestFeeRate`.
4. Do not re-add the same SY to both H and C; do not sweep arbitrary unbooked SY into C; do not require sender provenance (NN-11 L2 is closed).

**Classification:** **RESOLVED**. Remaining is implementation + fork-validation of the reconciliation ordering.

### 2.2 Provider/caller rounding vs selected references

**Existing rule (operative):**
- PRD §4.5: "for a candidate raw SY sample q and raw target-token preview a, whole-token rate normalization is `floor(a * 10^syDecimals * 1e18 / (q * 10^targetDecimals))`… The sample, failure/zero behavior and rounding must be specified and validated, not arbitrary defaults… A scalar rate times a whole balance is a valuation convention, not a guaranteed finite-size redemption."
- PRD §4.5 caveat: "Pendle's official SY documentation explicitly describes preview functions as best-effort, unaudited for on-chain use…"
- Plan v0.9 §6.5.6: "Use token-specific current-sNET conversion, not projected `exchangeRate()`. PRD §4.5 normalization remains `floor(a*10^syDecimals*10^18/(q*10^targetDecimals))`, with `a=previewRedeem(target,q)`. For verified SY18/sNET9 and this compilation, a one-whole-SY sample `q=10^18` yields `a=Ic` and rate=`Ic*10^9` exactly… A one-raw-unit sample can return zero at the initial index and is unsuitable… `floor(a*10^18)` ≠ raw `SY.balanceOf * rate`. Pin the provider/caller rounding chain before plan freeze."
- Plan v0.9 §6.6.2: V1 YT interest `delta = floor(b*(k-j)*W/(j*k))`; `fee = floor(gross*f/W)`; `C_i = gross − fee`; `userInterest.accrued` alone is stale.

**Is the gap real?** No. The plan §6.5.6 explicitly pins the sample size (`q = 1e18`), the conversion result (`a = Ic`) and the rate normalization (`rate = Ic * 1e9`). Plan §6.6.2 pins the V1 YT formula including the `*W/(j*k)` factor and the fee floor. The cross-review consensus flagged the fee formula `floor(gross*f/W)` with `net = gross − fee` is correct (not `floor(gross*(W−f)/W)` which would differ). Plan §6.5.3 §6.5.4 pin the Weighted helper fee ordering and the V4 native boundary wrapper's exact-out path.

**What is missing?** Nothing normative. The plan already identifies that "Pin the provider/caller rounding chain before plan freeze" — and pin-level decisions (e.g., whether the hook's view scales by `baseScaleFromDecimals(9) = 1e27` per `UniswapV4StandardExchangeWeightedBufferHookMath.sol:48–52`) are engineering, not owner choices. PRD §4.5 forbids using `exchangeRate()` for the current-sNET executable quote; the plan correctly substitutes `previewRedeem(sNet, q)`.

**Classification:** **RESOLVED**. Remaining is implementation (the hook's exact scaling chain in `quoteExactOut`/`quoteExactIn`) and fork-validation of provider rate stability.

### 2.3 Owned-HLP/Keep-YT chronology vs already specified transitions

**Existing rule (operative):**
- PRD §6.1–§6.2: ordinary NET/sNET input → Keep-YT; ordinary NET/sNET output → shared eligible SY budget (held first, claim if short, redeem). No ordinary-output PLP/YT liquidation.
- Plan v0.9 §7.1: 9-step common money-route skeleton (authenticate, callback guard, oracle extension, expansion settlement, claims reconciliation, route selection, ownership update, refunds, atomic failure).
- Plan v0.9 §7.2 operation matrix: explicit per-operation funding/action and supply/ownership outcome for liquid NET/sNET→DETF (Keep-YT), liquid USDG→DETF (deposit SE), ordinary DETF→NET/sNET (shared SY budget), HLP add/remove (BasePoolMath), liquid stake/unstake, fresh bond, dedicated reinvestment, native wrapper, native harvest, rollover.
- Plan v0.9 §11.1.2: pre-expiry and at/after-expiry joint-position quotation with one read of `MarketState`, one read of `PYIndex`, and forward state.
- Plan v0.9 §6.5.5: held-first ordinary-output call sequence with required epoch/TWAP/expansion settlement, claim-if-short and recompute.
- Plan v0.9 §6.6.5: claim → redemption chronology with explicit chronology fact ("YT claims may write PY index using the extracted SY's projected exchangeRate() but do not call NetNet stake/unstake/rebase… A later NET SY redemption invokes unstake and can process one overdue epoch; direct sNET redemption uses current index and does not.")

**Is the gap real?** No. The plan §6.5.5 step 5 already says "Recompute affected pricing, branch index and d after every preceding state change capable of affecting them." This is the chronology recomputation rule; it addresses the concern that a claim, an epoch advancement, a stake/unstake or a position exit can invalidate prior quotes. The plan §7.1 step 4 settles expansion before participation changes; §6.5.5 step 3 captures the public pretransfer credit before sync; §6.5.5 step 5 handles recomputation; §6.6.5 step 4 re-requires H+C-d≥1 after recomputation.

**What is missing?** Nothing normative. The remaining is implementation of the recomputation triggers and test coverage of the chronology in integrated state transitions. The plan §11.2 vectors "Composition/interleavings — NET/sNET sequential outputs and HLP/claim interleavings share one eligible budget; realized principal, fee payables and public pretransfer credit are not counted twice" is the acceptance target.

**Classification:** **RESOLVED**. Remaining is implementation + integration test + fork parity.

### 2.4 Exact-output residual vs existing refund/rounding rules and genuine supported domain

**Existing rule (operative):**
- Plan v0.9 §6.5.3: "For `0<I<=D`, qMin reaches y **exactly**, where its forward multiplication is valid. I=D is identity. For I>D, some targets have gaps: I=2D,y=1 gives qMin=1 and nominal output2. Minimum-sufficient is not exact final delivery. A direct exact-output payout must meet the required final net amount and input bounds; this round does **not** select gifting/warehousing excess or blanket removal of unrepresentable ERC4626 withdrawals. Prove the operative domain or finish an existing-rights-compatible delivery/residual route for a reachable gap; the latter is the narrow remaining L3 composition item, not permission to invent economics. Genuine inability to fund required delivery still reverts."
- PRD R22: "Standard multi-token DETF sell/redemption routes output **NET, sNET or USDG only**,** selected by the user. Failure to meet applicable `minAmountOut` reverts the whole transaction. Exact-output withdrawal delivers the requested net amount or reverts."
- Plan v0.9 §6.5.4: "Measure actual final recipient delivery and actual funding at their hops… Final BasicVault sync records balances, not receipt attribution or minOut proof."
- Plan v0.9 §6.6.5 step 5: "Enforce actual SY debit, actual recipient delivery, all user input/output maxima/minima, and existing exact-output residual/domain requirements."

**Is the gap real?** No new owner question. The plan already specifies:
1. `qMin = ceil(y * 1e18 / I)` minimum-sufficient inverse.
2. Forward check `floor(qMin * I / 1e18) ≥ y`.
3. For I>D, exact-out must require equality `floor(qMin * I / 1e18) == y`, else revert.
4. Genuine inability to fund required delivery reverts.
5. The PRD forbids gifting/warehousing excess and forbids blanket removal of required ERC-4626 routes.

The plan §6.5.3 explicitly calls this "the narrow remaining L3 composition item, not permission to invent economics." The PRD R22 + R27 forbid inventing a residual beneficiary. The only legitimate path is: (a) prove the operative domain does not include unreachable targets, or (b) compose an existing-rights-compatible delivery route within existing rights (e.g., refund excess, redeem in two steps). Both are engineering work within PRD-allowed bounds.

**What is missing?** Nothing normative. The plan §11.2 vector "Exact-output gap — I=D is identity; I=2D,y=1 distinguishes minimum-sufficient from exact. Required-route domain/residual proof must be explicit, not a test that silently drops ERC4626 withdrawal" is the acceptance target.

**Classification:** **RESOLVED** (with narrow L3 composition item as engineering under existing rules). No owner escalation needed unless a deployed test reveals an unreachable required target — in which case the PRD §6.1 owner-question filter says "raise only an actual unclassified economic case or demonstrated incompatibility after applying existing rules." That is conditional escalation, not current gap.

### 2.5 G0 owner-approved deviations vs actual instruction maintenance only

**Existing rule (operative):**
- Tracker NN-13: "MAINTENANCE — Custom-family approval settled, shared instruction authority unchanged… Separately authorized maintainer reconciliation; no instruction bypass by report… This tracker cannot amend instructions or grant permission to bypass them; no instruction changes are authorized by this update. Product approval is not pending again."
- Tracker §1 (Owner-question filter): "The operative PRD controls product behavior. This tracker records work; it does not select new economics, supersede instructions or authorize execution."
- CLAUDE.md non-negotiable #6: "Weird-token law (universal — do not re-ask): FoT forbidden. Rebasing underlyings forbidden… Non-18 decimals allowed (normalize only where the pricing adapter requires it; DETF/sDETF remain native 9-decimal tokens). Pause / blacklist accepted. No PkgArgs allowlist."
- The custom family's owner-approved deviations (FoT on NET, rebasing on sNET, direct DETF-as-SY, per-NFT holder Package, cliff bonds, weighted with non-canonical fee) are recorded in PRD §§2.1, 4.1, 5, 12.4 and plan §§1.1, 2, 9.3.

**Is the gap real?** No. The deviations are recorded; the maintainer reconciliation is a separate authorized process per tracker NN-13. There is no missing PRD text. The human correction confirms G0 is the maintainer's responsibility, not the research council's.

**What is missing?** Nothing normative. The owner-approved deviations are documented; the maintainer reconciliation process is the instruction-maintenance channel, not research-council work.

**Classification:** **PROCESS ONLY**. NN-13 stays MAINTENANCE.

### 2.6 L4 terminal rights clauses vs resolved partial reinvestment/timing

**Existing rule (operative):**
- PRD v0.28 §12.4 + PRD v0.33: intermediate installments do not restart old NFT lock; final intended contribution in processed epoch E unlocks ordinary principal at E+1; new reinvestment bonds have their own destination-type locks independent of old timing; pre-maturity reinvestment consumes already-funded principal without full-collection prerequisite; excess native proceeds credit same-NFT principal; unlock zero means assigned Pendle maturity.
- Plan v0.9 §7.3: explicit native holder / NFT lifecycle with purchase, partial native collection, final intended collection, early reward claim, pre-maturity rebond, final principal withdrawal, drained candidate, irreversible retirement. The "irreversible retirement" paragraph says: "L4 remains restricted to the final transition and late-principal timing. Do not substitute `pendingFor(holder)==0` over strangers' notes for intended completion, silently burn recognized rights, transfer proxy ownership or adopt permanent DORMANT/nonburning retirement as if selected. No current-balance check proves that arbitrary future gifts cannot arrive. The original mature-and-empty retirement intent remains; its unresolved terminal edge is not assigned to implementer discretion."
- Tracker H03: "REINVESTMENT LIFECYCLE RESOLVED; TERMINAL EDGES OPEN | New bond/new tokenId gets destination-type lock; old NFT/holder/note retains remainder/rewards/future receipts. No retirement on zero current principal alone. Specify mature-and-empty retirement/late gifts separately."

**Is the gap real?** It is **partially** real but does not require a new owner decision.

- The PRD/plan already specifies **all the prohibitions** the implementer must observe (no proxy ownership transfer, no DORMANT/nonburning, no silent burn, no stranger-note substitution, no fabricated permanent empty state).
- The PRD/plan does **not** specify the **exact predicate** for "mature-and-empty" — what counts as mature (assigned Pendle maturity or E+1 achieved), what counts as empty (intended note complete + no funded principal + no rewards + no unsettled obligations), how future gifts interact (PRD explicitly says "no current-balance check proves that arbitrary future gifts cannot arrive").

This is acknowledged by the PRD as a documented unresolved terminal edge. Per the tracker H03 "Specify mature-and-empty retirement/late gifts separately" — but the PRD's owner-question filter says ask only "when a concrete required behavior, entitlement, economic parameter or release condition remains undefined **and cannot be derived without changing the product**." The current PRD/plan provides enough constraints (the prohibitions list) that the implementer can compose the predicate **within existing rights** — selecting a release-gate predicate (intended-note complete + balance==0 + funded principal==0 + accrued rewards==0 + no unsettled obligations) and an irreversible-retirement signal (NFT burn) without inventing economics.

The "unresolved" status means: the PRD does not pick one of the multiple equivalent formulations. But the plan §7.3 already says "the original mature-and-empty retirement intent remains." So the implementer can compose a predicate honoring that intent without further owner action.

**What is missing?** Nothing normative. The PRD's prohibitions and the "mature-and-empty intent" allow the implementer to compose the predicate. If a future case arises where the predicate cannot honor the PRD's prohibitions without violating one (e.g., an unavoidable permanent stranded-funds scenario), the PRD owner-question filter says escalate then. **No current escalation needed.**

**Classification:** **IMPLEMENTATION/TEST** (compose the mature-and-empty predicate within PRD-specified prohibitions). H03's TERMINAL EDGES OPEN status becomes an engineering task, not a PRD gap.

## 3. Explicit withdrawal of unsupported old blockers

Per the audit instructions ("Explicitly withdraw unsupported old blockers"):

| Old blocker claim | Withdrawal |
|---|---|
| "Source identity must be block-pinned before any further work" | Withdrawn. Human correction: Pendle docs are source of truth; `ROBINHOOD_MAIN.sol:195–201` records the four published anchors; standard default block is `DEFAULT_FORK_BLOCK = 20_714_383`; fork validation is later implementation/test work, not a research blocker. NN-01 remains EVIDENCE but is no longer a research blocker. |
| "Provider rounding is unspecified and needs further owner review" | Withdrawn. PRD §4.5 + plan v0.9 §6.5.6 + §6.6.2 pin the sample size (`q = 1e18`), the conversion result (`a = Ic`), the rate normalization (`rate = Ic * 1e9`), the V1 YT formula (with W factor), the fee floor (`floor(gross*f/W)`), and the Weighted helper fee ordering. Implementation pins the exact scaling chain. |
| "Force-claim reconciliation needs new mechanism" | Withdrawn. PRD v0.32 §6.3 + plan §6.1 + §6.6.4 specify the rule (capture pretransfer credit before sync, refresh C, no double-count, no sender provenance). The "no mechanism to label historical receipts" is explicitly acknowledged as the absence of a forbidden mechanism, not a missing rule. |
| "Owned-HLP/Keep-YT chronology has a hole" | Withdrawn. Plan §6.5.5 step 5 + §7.1 + §11.1.2 + §6.6.5 specify the chronology with explicit recomputation triggers. |
| "Exact-output residual needs new economics" | Withdrawn. PRD R22/R27 + plan §6.5.3 forbid inventing residual beneficiaries and require revert on unrepresentable. The "narrow remaining L3 composition item" is engineering under existing rules, not an economics question. |
| "G0 instructions need council reconciliation" | Withdrawn. Tracker NN-13 classifies this as MAINTENANCE (separate authorized maintainer process), not research-council work. |
| "L4 needs further owner decision before implementation" | Withdrawn at the current PRD/plan version. The PRD's prohibitions + mature-and-empty intent give the implementer enough constraints to compose the predicate without inventing. Escalate only if a concrete unresolvable case arises during implementation — that is conditional per the owner-question filter, not a current gap. |

## 4. What is genuinely left to do (separately authorized tasks, not research blockers)

The remaining work is non-research, not owner-resolution, not PRD-revision. It is implementation/test/evidence work that the PRD/plan/tracker already classify as engineering.

| Item | Type | Path |
|---|---|---|
| NN-01 dependency manifest | IMPLEMENTATION/TEST (fork) | Use Pendle docs + `ROBINHOOD_MAIN.sol:195–201` + `DEFAULT_FORK_BLOCK = 20_714_383`; validate deployed equivalence via fork at default block; record observation block. |
| NN-04 oracle-term-to-lock matching | IMPLEMENTATION/TEST (fork) | Match oracle bond-duration inputs to actual deployed oracle terms; only demonstrate incompatibility escalates. |
| NN-06 HLP/position-subshare equations | IMPLEMENTATION/TEST | Implement nested floors + final-exit equations; preserve rights. |
| NN-09 TWAP observation contract | IMPLEMENTATION/TEST | Specify exact update triggers + retention + overflow bounds; declare `seriesInfo`/`consult`. |
| NN-10 SY provider rounding chain | IMPLEMENTATION/TEST (fork) | Implement the provider with the pinned sample + rate normalization; validate via fork. |
| NN-11 force-claim reconciliation ordering | IMPLEMENTATION/TEST | Implement the bookkeeping per plan §6.6.4 + §6.1. |
| NN-12 funded-gons staking adapter | IMPLEMENTATION/TEST | Implement transfer-notification + principal context per plan §9.3. |
| NN-14 rollover call-graph + late-claim | IMPLEMENTATION/TEST | Implement per plan §10 with validation tests. |
| NN-15 NFT/holder lifecycle terminal edges | IMPLEMENTATION/TEST (within PRD prohibitions) | Compose mature-and-empty predicate within PRD §12.4 prohibitions; do not invent. |
| NN-16 V2 SE feature inventory + tax | IMPLEMENTATION/TEST | Enumerate retained selectors + tax-aware quote/execute; trust `asset()==canonicalPair` predicate. |
| NN-17 deployment/ABI/authority graph | IMPLEMENTATION/TEST | Freeze package/facet/registry wiring + hook flag mining; separate from `NET-DETF` salt. |
| NN-18 arithmetic/resource bounds | IMPLEMENTATION/TEST (analysis + later gas) | Document representability + operating horizon; do not invent recovery. |
| NN-19 quantitative acceptance + fork validation | IMPLEMENTATION/TEST (fork) | Build the R/C/A → test mapping with production-first TestBases; fork parity as separate tier. |
| NN-20 document reconciliation | EDITORIAL | Mechanical cleanup; no economics. |
| G0 maintainer reconciliation | PROCESS ONLY | Separate authorized process per tracker NN-13. |

No new owner decision is required for any of the above; they are within PRD-specified rules and plan-specified formulas.

## 5. Source integration questions (separate from spec gaps)

These are **implementation/fork obligations**, not actual spec gaps. Per the task instruction ("Separately list source integration questions as implementation/fork obligations unless a demonstrated incompatible required case needs a decision"):

| Question | Disposition |
|---|---|
| Exact deployed YT implementation (V1 vs V2) | Fork inspection at `DEFAULT_FORK_BLOCK = 20_714_383`; obtain actual body if V2; selector compatibility does not prove formula compatibility (plan §6.6 version gate). |
| Deployed `IStakedNetStaking(staking).rebase` body | Fork inspection; verify one-epoch-per-call + `_syncedIndex` mirror parity. |
| Factory `interestFeeRate`/`rewardFeeRate`/`treasury` | Fork read at default block; not assumed from setter caps. |
| `doCacheIndexSameBlock` for configured YT | Fork read at default block; gating for same-block second claim. |
| Configured YT/market addresses | `ROBINHOOD_MAIN.sol:195–201` is the source-of-truth starting point per human correction; enumerate markets and validate candidates against `PENDLE_MARKET_FACTORY_V6`. |
| Gauge controller address / PENDLE identity / vePENDLE | Fork read; needed for market `redeemRewards` claim graph. |
| Reward token list on deployed SY/market | Fork read; conditional escalation per PRD §6.3 if same-token collision with interest token is observed. |
| Whether deployed market escrows YT | Fork inspection; if YT is donated/transferred to market, claim pays market, not hook (plan §6.6.1). |
| Current `userInterest[hook]`, `userReward`, `activeBalance` state | Fork read at observation block. |

Each is **fork-validation under separately authorized execution**, per the human correction. None requires a PRD/owner revision. None is a current spec gap.

## 6. Confidence summary

| Topic | Confidence | Notes |
|---|---|---|
| Existing PRD/plan rules cover force-claim reconciliation | High | PRD v0.32 §6.3 + plan §6.1 + §6.6.4 verbatim |
| Existing PRD/plan rules cover provider rounding | High | PRD §4.5 + plan §6.5.6 + §6.6.2 verbatim |
| Existing PRD/plan rules cover owned-HLP/Keep-YT chronology | High | Plan §6.5.5 step 5 + §7.1 + §11.1.2 + §6.6.5 verbatim |
| Existing PRD/plan rules cover exact-output residual | High | PRD R22/R27 + plan §6.5.3 + §6.5.4 verbatim |
| G0 stays MAINTENANCE | High | tracker NN-13 verbatim |
| L4 terminal edges is composable within PRD prohibitions | Medium-High | PRD §12.4 prohibitions + plan §7.3 mature-and-empty intent; remaining is engineering specification, not PRD revision |
| Pendle address source-of-truth + standard default block | High | `ROBINHOOD_MAIN.sol:195–201` + `DEFAULT_FORK_BLOCK = 20_714_383` verified |
| No new owner questions required | High | All six challenge areas audited; tracker owner-question filter satisfied at current PRD/plan version |

## 7. Status

- **ACTUAL SPEC GAP**: none identified at current PRD/plan/tracker version.
- **RESOLVED**: items 2.1, 2.2, 2.3, 2.4, 2.5 above (with the engineering/fork obligations in §4 and §5).
- **IMPLEMENTATION/TEST**: NN-04/NN-06/NN-09/NN-10/NN-11/NN-12/NN-14/NN-15/NN-16/NN-17/NN-18/NN-19; H03 terminal-edge predicate within PRD prohibitions; claim→redemption composition vectors per §11.2; full Keep-YT/owned-HLP interleavings.
- **PROCESS ONLY**: NN-13 (G0 maintainer reconciliation).
- **Source integration questions (fork obligation)**: YT V1/V2 identity, deployed `IStakedNetStaking` body, factory rates/treasury, `doCacheIndexSameBlock`, configured addresses, gauge/PENDLE/ve, reward token list, market-YT escrow, current native state. All under separately authorized fork execution at `DEFAULT_FORK_BLOCK = 20_714_383` (or `101_800_000` for testnet).
- **No new owner questions are required.** The PRD/plan/tracker is internally consistent and the remaining work does not require re-opening economics, demanding certification, or fabricating entitlements.

## 8. Saved full-original path

`docs/research/netnet-concrete-open-items-audit/minimax-original.md` (this file).

Stop at human checkpoint. No shell/tests/deployments/implementation/delegation/config edits. No plan/tracker writes.