# Coordinator-preserved original

Grok returned the following initial response inline because project-scoped apply_patch was unavailable. Preserved verbatim from the completed Native task final_response; no member artifact write is claimed.

---

Ask: Independent Grok fidelity review of the published PairToken requirements — wanted: a member response at the assigned path. For you: No file was written. `apply_patch` is registered but inactive, and write/edit were not used. Verdict: Yes with corrections. The full response follows.

# Member response

## Identity

- Run ID: pairtoken-requirements-fidelity-20261027-01a17e03
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: /Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/members/grok/response.md
- Requested role: Grok member of the full council named in the brief
- Requested model and reasoning: not stated in the brief
- Actual role, model, reasoning, task ID, and session ID: harness-exposed xai/grok-4.7, reasoning xhigh; session 01a17e09-13ec-799a-8acb-a21cf7ed3770; session path contains st_01a17e0a. This self-description is not proof of the runtime model.
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does pairtoken-requirements-final-r2 accurately and sufficiently describe PairToken so a separate team can plan and implement behavioral equivalence without consulting the target code? Assess fidelity and standalone completeness. Distinguish technical readiness, source-exposure/process segregation, and legal clearance. Do not certify legal clean-room status.
- Required targets: the published requirements at docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/handoff/REQUIREMENTS.md, and the coordinator-supplied decoded source under this run's evidence/sources, especially src/pair/PairToken.sol.
- Optional context: PRD, implementation plan, and audit were not supplied. Not invented.
- Admitted read scope: the brief, SOURCE.md, the requirements, PairToken.sol, and included dependency sources needed to check the specified formulas, ABI, storage-read convention, and transfer helpers. No peer originals, earlier council artifacts, tests, builds, Git, installs, or network re-fetch.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Document identity | REQUIREMENTS.md lines 1-4; evidence/SOURCE.md | coordinator-supplied | Identity pairtoken-requirements-final-r2. SOURCE.md records Sourcify match 55980642, exact creation and runtime match, chain 4663, address 0x56C8c249d4c021e93635b120aC68A9a36eb01753, retrieved 2026-10-27. Not re-fetched by this member. |
| PairToken surface | evidence/sources/src/pair/PairToken.sol, 694 lines, read in full | coordinator-supplied | SPDX BUSL-1.1, pragma 0.8.26. Public surface, guards, quote, deposit, zap, redeem, compound, callback, and helpers match the sections cited below unless a finding says otherwise. |
| Amount math | SqrtPriceMath.sol getAmount0Delta/getAmount1Delta; LiquidityAmounts.sol; FullMath.sol; UnsafeMath.sol; FixedPoint96.sol | coordinator-supplied | Sorted amount0, absolute amount1, round-up remainder rule, Fit branches, and MD/MU failure modes match PT-MATH-01 through PT-MATH-03. |
| Tick function | TickMath.sol getSqrtPriceAtTick, minUsableTick, maxUsableTick | static analysis | All 20 requirement coefficients match the non-comment source constants. Recomputed T(0)=2^96, T(-887272)=4295128739, T(887272)=1461446703485210103287273052203988822378723970342. |
| Floor sqrt | PriceMath.sqrt | static analysis | Algorithm compared with integer floor sqrt on 110 inputs, including 0, 1, 2^128, and 2^256-1, plus 100 deterministic 256-bit samples. No mismatch. Not an exhaustive proof. |
| Manager reads | StateLibrary.sol; Position.calculatePositionKey; PoolId.toId; PoolKey.sol | static analysis | Slot 6, liquidity at +3, position at +6, low-160 price, next signed 24-bit tick, and low-128 liquidity match PT-VIEW-01. abi.encode and abi.encodePacked of two bytes32 values are the same 64-byte preimage. Position-key bytes for a negative lower tick match packed 20/3/3/32 encoding. |
| Payout wrapper | Currency.sol transfer; CustomRevert.bubbleUpAndRevertWith | source observation | Zero-value calls still occur. ERC-20 success is empty returndata or a first word equal to 1 with at least 32 bytes. Failures wrap the complete returndata in WrappedError with a 4-byte details selector. |
| Manager interface | IPoolManager.sol, IExtsload.sol, IUnlockCallback.sol, IERC20Minimal.sol, BalanceDelta.sol | source observation | Call shapes, caller-then-fee return order, and high-half amount0 / low-half amount1 packing match PT-DEPENDS-03. No PoolManager implementation is in the bundle. |
| Public query | not used | unverified | No network retrieval. Match identity is coordinator-supplied. |

## Assumptions

- Solidity 0.8.26 explicit uint256-to-int256 conversion reinterprets bits and does not revert; checked negation then matches PT-MATH-05. This is a language-contract inference from the source expression `-int256(d.swapAmount)`, not a compiler run.
- `require` without a reason string is an empty revert. That is the reading used for "unadorned revert" in FullMath.
- Two static bytes32 arguments have identical `abi.encode` and `abi.encodePacked` preimages. The slot formula in PT-VIEW-01 is therefore equivalent to StateLibrary's encodePacked calls. Not executed in Solidity.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| REQUIREMENTS.md, all 596 lines | required | examined | Read in full and checked against PairToken and the included helpers. |
| PairToken.sol | required | examined | Read in full. |
| Public ABI, 17 getters, events, errors | required | examined | Signatures, visibility, mutability, indexing, and empty custom errors match. NotFactory is declared and unused. No fallback. |
| Initialization and ERC-20 edges | required | examined | Check order, infinite allowance, modular recipient add, and modular burn supply match. |
| Integer arithmetic, rounding, casts | required | examined | Formulas match. Tick extrema recomputed. Sqrt floor checked on a sample only. |
| Basket and previews | required | examined | Unclamped basket and preview/execution split match. |
| Genesis, dead shares, minShares | required | examined | Dead shares are minted, not burned. Gross minShares check precedes the deduction. |
| Paired and zap deposits | required | examined | Reservation, cap, half-receipt swap, pre-zap pricing, and no zap refund match. |
| Redemption, retention, single output | required | examined | Separate floors, skip-add, and unconditional zap payout match. |
| Compound, protocol fee, notify failures | required | examined | Catch boundaries match. The source comment that a fee-manager failure never blocks users is correctly rejected by the requirements. |
| Native reservation, refunds, transfers | required | examined | Currency.transfer and PairToken helpers were both read. |
| Donation and dust | required | examined | Strict dust trigger and no donation exclusion match. |
| Callback ABI, deltas, dependency reads | required | examined | Encoding, U128 quirk, settlement order, and empty hook data match. PairToken bytecode was not disassembled. |
| Caps and tick checks | required | examined | User-zap basket cap and compound active-liquidity quarter cap are distinct and match. |
| Examples and acceptance vectors | required | examined | Numerical vectors AC-02, AC-08, AC-12, AC-18, AC-19, AC-23, and AC-35 were recomputed. None were executed. |
| Optional PRD, plan, audit | optional | absent | Not supplied. |
| PoolManager, factory, fee-manager, hook, and token implementations | required limit | not examined | Absent from the bundle. Requirements correctly refuse to invent them. |
| IHooks, IProtocolFees, IERC6909Claims, IExttload, BeforeSwapDelta, BitMath, SafeCast, LiquidityMath, getTickAtSqrtPrice | optional context | not examined | Not on the PairToken call path used by the requirements. |
| Earlier council artifacts and peer responses | forbidden | not examined | Not read. |

## Conclusions

- Verdict: Yes with corrections.
- Technical behavioral readiness: the published requirements are a faithful standalone description of this PairToken. A separate team can plan source-equivalent behavior from them after the two low corrections below. Those corrections do not reopen the quote, retention, callback, or dependency baseline.
- What the source shows, and the requirements already preserve: dead shares are minted to `0x...dEaD`; basket does not clamp price into range; removal and collection return `U128` of caller deltas, so a settled delta of -1 is reported as `2^128-1`; paired shares are not recomputed after a short ERC-20 receipt; zap has no leftover refund; redeemZap transfers even a zero output; compound has no tick guard; protocol bps are not clamped to 10000; skip-add suppresses every addition, including dust; `NotFactory` has no predicate; `Op.None` reverts `NotPoolManager`; fee-manager failure can still abort on getter, arithmetic, or approval-decode failure.
- Source exposure: the document says it is source-informed and does not certify an unexposed workflow. This pass cannot certify that a later planner was unexposed.
- Legal clearance: not certified. The examined source file is marked SPDX BUSL-1.1. No license research was done. A prose specification is not legal clearance.
- Agreement is not available. Peers were not read. This is not a council consensus.

## Review findings

### F1 - "Measured" mislabels a native pull return

- Severity: Low
- Location: REQUIREMENTS.md PT-DEP-05 line 236 and PT-EVENT-02 line 405; source `PairToken._pull` line 663
- Invariant or requirement: PT-DEP-05 says emit `Deposit` with "measured amounts `v0,v1`". PT-EVENT-02 says paired `Deposit` amounts "are measured pulls". PT-BAL-02 line 375 correctly says a native pull returns the nominal amount and does not measure a balance change.
- Impact: `_pull` returns `amount` for native currency and does not transfer. A balance delta around that pull is zero because `msg.value` arrived earlier. An implementer who treats both event legs as measured receipts would record native `amount0` as 0, keep `msg.value - 0` reserved, and refund the principal instead of deploying it. ERC-20 measurement in the same sections is correct.
- Fix direction: Call `v0,v1` pull-returned amounts. State that a native return is nominal and an ERC-20 return is the checked balance difference. Do not change PT-BAL-02.
- Evidence class: source observation

### F2 - Idle-pair read order is pinned only for paired entry

- Severity: Low
- Location: REQUIREMENTS.md PT-DEP-03 line 226, PT-VIEW-02 line 192, PT-COMP-04 line 301, and PT-CB-05 line 358; source `basket` lines 228-229, `_redeemToSelf` lines 394-395, `_compound` lines 435-436, and `_deployInLock` lines 599-600
- Invariant or requirement: PT-DEP-03 requires currency0 idle, then currency1 idle, then price, and says that order is specific to paired entry. The other three sections do not pin which idle balance is read first. The source reads currency0 then currency1 on all four paths. `_addAll` lines 296-298 are the paired-entry order and are already specified.
- Impact: If `balanceOf` reenters and changes the other currency before the second read, reversing the pair changes basket, the redemption idle fraction, the compound ratio, or Deploy liquidity. Non-callback tokens are unaffected. PT-BAL-07 already allows nonstandard tokens to change outcomes; it does not authorize a different read order.
- Fix direction: State that every idle pair is read currency0 then currency1. Keep the paired-entry distinction that price is read after those idles, while Deploy uses the price it already holds.
- Evidence class: source observation

No other incorrect statement was found on the examined surface. Missing numerical acceptance cases are listed under Limits and are not treated as false specification.

## Limits

- Runtime or extraction proof: none. No tests, builds, broadcasts, or Sourcify re-fetch. Static reading is not runtime proof. Acceptance numbers were recomputed, not executed.
- Sqrt floor: 110 compared inputs, zero mismatches, not a proof over all uint256 values.
- Not examined: PoolManager, factory, fee-manager, hook, and token implementations; optional PRD, plan, and audit; peer and earlier-council artifacts; PairToken bytecode.
- Missing numerical vectors, not false rules: out-of-range basket (PT-AC-33), int128-minimum settlement (PT-AC-47), and swap amount `2^255` (PT-AC-56) are specified qualitatively.
- Legal and process: no clean-room certification and no license opinion.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
- Publication: no file was written. `apply_patch` is registered but inactive in this session, including through the eval tool wrapper. write and edit were not used.

Now: none. Next: none.

