# Member response

## Identity

- Run ID: pairtoken-prd-sourcify-accuracy-20261027
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Is docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md, identity pairtoken-unified-prd-r1, an accurate definition of the PairToken-local behavior in the exact-match source at https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources?
- Required targets: that PRD, raw SHA-256 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2; the 28-file exact-match source identified by the brief and evidence/SOURCE.md.
- Optional context: not supplied. Earlier requirements, errata, fidelity reports, and member responses were not read.
- Admitted read scope: the PRD; this run's brief.md and evidence/SOURCE.md; the coordinator-supplied decode under docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/evidence/sources/; one refetch of the exact public Sourcify URL. No other repository path was read.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| PRD identity | docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md | source observation | Raw file SHA-256 computed as 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2. It matches the pinned identity. 641 newline-separated lines. Read completely. |
| Sourcify refetch | https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources | source observation | Refetched on this pass. HTTP 200. Raw response 147694 bytes. Raw response SHA-256 ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98. matchId 55980642. creationMatch exact_match. runtimeMatch exact_match. match exact_match. chainId 4663. address 0x56C8c249d4c021e93635b120aC68A9a36eb01753. verifiedAt 2026-10-12T10:33:37Z. 28 source files. No source excerpt was sent to any other search or fetch. |
| Local decode | evidence/SOURCE.md and the sources tree | coordinator-supplied, then source observation | SOURCE.md records the same response hash and identity. Byte comparison of every remote `sources[<path>].content` to the local file found zero differences after removing one trailing newline from each local file. Line numbers match. |
| PairToken | sources/src/pair/PairToken.sol | static analysis | Read completely, 694 lines. Public ABI, constants, events, errors, check order, and callback encoding compared with the PRD. |
| Used helpers | PriceMath.sol, LiquidityAmounts.sol, FullMath.sol, TickMath.sol (functions PairToken calls), SqrtPriceMath.sol amount deltas, StateLibrary.sol reads PairToken uses, Position.sol key, Currency.sol, BalanceDelta.sol, PoolKey.sol, PoolId.sol, SafeCast.sol, CustomRevert.sol, UnsafeMath.sol, FixedPoint96.sol, IExtsload.sol, IERC20Minimal.sol, IUnlockCallback.sol, IPoolManager.sol | static analysis | Formulas, selectors, packing, and call signatures compared with the PRD claims that depend on them. |
| Integer transcription | transcribed PriceMath.sqrt and TickMath.getSqrtPriceAtTick | static analysis | Not contract execution. Floor-sqrt transcription matched a reference floor sqrt on 220026 samples, including 0 through 200000, powers of two, nearby perfect squares, and values at the uint256 boundary. No mismatch in that set. Tick transcription of the PRD formula matched the source multiply-shift algorithm on 5789 ticks, including 0, plus and minus 1, plus and minus 887272, spacing-60 bounds, and a stride across the legal range. T(0) was 2^96. Endpoint results were 4295128739 and 1461446703485210103287273052203988822378723970342. |
| Error selectors | computed keccak256 of the named signatures | static analysis | InvalidPrice() is 0x00bfc921, matching the assembly selector in SqrtPriceMath.sol. transfer, transferFrom, and approve selectors match the low-level selectors in PairToken.sol. |

Public search was not used. The only network read was the exact Sourcify URL above.

## Assumptions

- Solidity 0.8.26 explicit same-width signed/unsigned casts wrap rather than revert. This is inferred from SafeCast.sol, which adds the negativity and range checks that the built-in casts do not perform. It was not confirmed by compilation. PairToken.sol uses the built-in casts on the removal return and the swap amount, and the PRD describes that wrap.
- No other assumption. The source tree and the PRD were both readable.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| PRD.md, identity pairtoken-unified-prd-r1 | required | examined | Full text read. Raw hash matched. |
| Sourcify exact-match identity | required | examined | Refetched. Identity fields and response hash recorded above. |
| src/pair/PairToken.sol | required | examined | Full file read and compared with every tagged external-behavior claim. |
| src/base/PriceMath.sol | required for genesis sqrt | examined | `sqrt` compared. `sqrtPriceFor` is not called by PairToken. |
| src/vendor/uniswap/LiquidityAmounts.sol | required | examined | Full file. Branching, ordering, and SafeCastOverflow match PT-MATH-03. |
| lib/v4-core/src/libraries/FullMath.sol | required | examined | Floor and ceiling full-precision division, including upward-rounding overflow, match PT-MATH-01. |
| lib/v4-core/src/libraries/TickMath.sol | required for T, bounds, and sqrt limits | partially examined | Constants, min/max usable tick, and getSqrtPriceAtTick read. getTickAtSqrtPrice is not called by PairToken and was not used for a claim. |
| lib/v4-core/src/libraries/SqrtPriceMath.sol | required for amount deltas | examined | getAmount0Delta and getAmount1Delta, including sort, InvalidPrice, and round-up composition, read. Next-price helpers are not called by PairToken. |
| lib/v4-core/src/libraries/StateLibrary.sol | required for manager reads | examined | getSlot0, getLiquidity, getPositionLiquidity, and the slot helpers read. Other getters are not called by PairToken. |
| lib/v4-core/src/libraries/Position.sol | required for the position key | examined | calculatePositionKey packing read. Position.update is not called by PairToken. |
| lib/v4-core/src/types/Currency.sol | required | examined | Idle read, native and ERC-20 payout, and isAddressZero read. |
| lib/v4-core/src/types/BalanceDelta.sol | required | examined | amount0 is the high 128 bits; amount1 is the low 128 bits. |
| lib/v4-core/src/types/PoolKey.sol and PoolId.sol | required | examined | Five-field key and 160-byte id hash match PT-INIT-02 and PT-API-BASE. |
| lib/v4-core/src/libraries/CustomRevert.sol | required for payout errors | examined | WrappedError bubble includes complete returndata and a four-byte details selector. |
| lib/v4-core/src/libraries/SafeCast.sol, UnsafeMath.sol, FixedPoint96.sol | required for cast and rounding claims | examined | Q96 is 2^96. divRoundingUp is ceil. SafeCast documents the checks the built-in casts omit. |
| lib/v4-core/src/interfaces/IExtsload.sol, external/IERC20Minimal.sol, callback/IUnlockCallback.sol, IPoolManager.sol | required for the calls PairToken makes | examined | Signatures used by PairToken match the PRD's integration contracts. |
| BitMath.sol, LiquidityMath.sol, BeforeSwapDelta.sol, IHooks.sol, IProtocolFees.sol, IERC6909Claims.sol, IExttload.sol | not used by a PairToken behavior the PRD states | not examined | PairToken does not call them. Hook, fee, and 6909 internals are outside the yes standard. |
| Old fidelity report, requirements copy, and peer responses | excluded | not examined | Not evidence for this pass. |

## Conclusions

Yes, with only non-material clarifications

The PRD, read alone, requires the PairToken-local external behavior in the exact-match source. I did not find a requirement that forces an observable result, failure, event, or order the source does not have. I did not find a PairToken-local behavior that changes an external result, failure, event field, or integration contract and is left out of both the normative text and an explicit dependency or absence. The formulas I checked do not diverge from the source integer results.

What the source shows, not what the PRD's provenance prose claims:

- Public surface matches. Seventeen functions plus `receive`, seventeen generated getters, five events with the stated indexing, and thirteen empty custom errors, including declared but unused `NotFactory`. Constants are 18, 10000, 1000, 10, 1000, and the dead address. PairToken.sol lines 49-66, 102-118, and 133-214.
- Check and call order matches the guarded entrypoints, quote-before-pull, gross minShares before the dead mint, nominal zap cap before the measured pull, pre-zap basket for issuance, retention before removal, skip-add on the exit swap, and separate unlock boundaries. PairToken.sol lines 256-293, 308-347, 351-409, and 416-444.
- Amount, liquidity, and tick formulas match the helper integer results, including unclamped basket endpoints, two-step amount0 rounding, amount1 remainder rounding, nested compound cap floors, and the tick coefficient table. SqrtPriceMath.sol getAmount0Delta and getAmount1Delta; LiquidityAmounts.sol getLiquidityForAmounts; TickMath.sol getSqrtPriceAtTick; PairToken.sol `_ratioSwap`.
- Manager reads match. Pool id is the 160-byte key hash. Position key is the 20/3/3/32 packed hash. Slot0, active liquidity, and position liquidity use the stated offsets and low-bit extractions. For the two-word preimages, abi.encode and abi.encodePacked are the same 64 bytes, which PT-VIEW-01 states. PoolId.sol lines 11-16; Position.sol calculatePositionKey; StateLibrary.sol `_getPoolStateSlot` and `_getPositionInfoSlot`.
- Payout and settlement match. Removal and collection return the unsigned reinterpretation of caller deltas, not their absolute values. Swap output clamps nonpositive deltas to zero. Native payout and ERC-20 payout use the wrapped error; the paired native refund uses `TransferFailed`. Currency.sol transfer; PairToken.sol lines 610-644 and 670-676.
- Recomputed scenarios PT-AC-02, PT-AC-12, PT-AC-18, PT-AC-23, and PT-AC-35 match the source integers. PT-AC-47 matches the built-in `uint128` reinterpretation of a negative caller delta, which SafeCast.sol does not use on that path.
- Absent selectors, no fallback, no armed callback, no local fee clamp, and no initialized gate on ERC-20 or the receiver match PT-ABSENT-01, PT-ABSENT-02, and PT-INIT-03.

Agreement with other members is not available. This pass did not read peers. This is not a claim of council consensus, runtime equivalence, or bytecode identity.

The three items below are clarifications. Each matching rule is already in the PRD. They do not by themselves make the definition inaccurate.

## Review findings

### No material defect

- Location: docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md, compared with sources/src/pair/PairToken.sol and the helpers named in Coverage
- Invariant or requirement: An implementer who has only this PRD must reproduce PairToken-local public ABI, constants, events, errors, integer results, stated casts, stated check and call order, and the source's dependency boundaries.
- Impact: No compared requirement forces a result, failure, event, or order the source lacks, and no compared source behavior that changes those observations is left unspecified.
- Fix direction: None. Do not change the source. Do not treat the low items below as permission to alter formulas, guards, or call order.
- Evidence class: static analysis

### Low: notification catch scope

- Location: sources/src/pair/PairToken.sol lines 451-463; PRD.md lines 315-319 and PT-AC-38
- Invariant or requirement: A failed `notify` is caught and reports zero. Factory getter failures, checked arithmetic, malformed approval data, and call-setup failures are not caught.
- Impact: The source uses a bare `catch`, so custom errors, Panic, and empty reverts from `notify` are caught. The PRD already says notification reverts are caught and lists the failures that are not. A reader who implements only `catch Error(string)` would let a custom-error fee manager abort the operation. That misreading is not required by the PRD.
- Fix direction: In PT-COMP-03, say both notify catches are catch-all external-call failures, including custom errors, Panic, and empty reverts, not only `Error(string)`. Do not apply that edit here.
- Evidence class: static analysis

### Low: native value-call gas

- Location: sources/lib/v4-core/src/types/Currency.sol line 47; sources/src/pair/PairToken.sol line 674; PRD.md lines 410 and 416
- Invariant or requirement: Native payout is an empty-calldata value call with `WrappedError` on failure. Paired refund is an empty-calldata value call with `TransferFailed` on a false result.
- Impact: Both source calls forward remaining gas. The PRD's "value call", together with those distinct failure modes, already excludes a 2300-gas `transfer` or `send`. It does not spell out remaining-gas forwarding. A stipend would change success for some recipients. A Solidity 0.8.26 `.call` does not have that stipend.
- Fix direction: State that both native payout and paired refund use CALL with remaining gas, not a fixed 2300-gas stipend. Do not apply that edit here.
- Evidence class: static analysis

### Low: static balance and extsload reads

- Location: sources/lib/v4-core/src/interfaces/IExtsload.sol line 9; sources/lib/v4-core/src/interfaces/external/IERC20Minimal.sol line 10; PRD.md line 608 and PT-BAL-01
- Invariant or requirement: Position, price, active liquidity, and ERC-20 idle reads use the consumed external ABI. Factory reads are already marked view at PT-DEPENDS-01.
- Impact: The source calls view `extsload(bytes32)` and view `balanceOf`, so those reads are static. PT-DEPENDS-03 names `extsload(bytes32)->bytes32` without repeating `view`. Against a view implementation the result is the same. A balance or slot read that writes, or reverts under a static call, would fail in the source and could differ under a non-static call. That is outside a compliant view ABI and is not a result the PRD currently requires the implementer to change.
- Fix direction: Mark the consumed single-slot `extsload` and token `balanceOf` reads as view static calls. Do not apply that edit here.
- Evidence class: static analysis

## Limits

- Runtime or extraction proof: none. No contract was executed. No project test, build, install, or deployment was run. Static reading is not runtime proof. The sqrt and tick checks are transcribed integer comparisons on the domains named above, not an exhaustive proof over every uint256 and not an on-chain result.
- Not examined: unused files listed in Coverage; getTickAtSqrtPrice; peer responses; the earlier fidelity report and its requirements copy; any path outside the admitted read scope.
- Selector and cast checks were local computations and source inference, not a compiler run.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
