# Identity

- Member: Astra, acting only as the assigned independent council member.
- Run: `pairtoken-prd-sourcify-accuracy-20261027`.
- Profile and phase: review; initial independent response only.
- Requested role: `council-member`.
- Requested and exposed actual route: `chatgpt-subscription/gpt-6-astra`, reasoning `high`. The session environment exposed these as `PI_PROVIDER`, `PI_MODEL`, and `PI_REASONING_LEVEL`; no substitution was made.
- Exposed session ID: `01a17e7a-70bc-78fc-842a-9d14253e4444`.
- Review date: October 27, 2026.
- Peer responses read before submission: none. No prior fidelity verdict, requirements copy, member response, or other file in the PRD's research directory was used.

# Question and targets

Does `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md`, identity `pairtoken-unified-prd-r1`, accurately require the PairToken-local external behavior of the specified exact-match Sourcify source?

I applied the supplied implementer-facing standard: the complete PRD must preserve local ABI, integer outcomes, casts, errors, events, observable check and interaction order, and actual dependency boundaries. I did not require bytecode identity, private storage layout, original helper decomposition, or reconstruction of absent external implementations.

The source evidence root is:

`docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/evidence/sources/`

In this response, source locators beginning `src/` or `lib/v4-core/` are relative to that root. PRD locators identify the single pinned file above.

# Evidence

## Identity and retrieval

I computed the pinned PRD's SHA-256 from its raw file bytes:

- Bytes: `95049`.
- SHA-256: `1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2`.
- Result: matches the assignment.

I completely read the pinned PRD, this run's `evidence/SOURCE.md`, and this run's `brief.md`. I also read all 28 files in the admitted source bundle, including the complete `src/pair/PairToken.sol`.

I refetched the exact public URL supplied in the assignment:

`https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources`

The direct response observed during this review had:

| Field | Observed value |
| --- | --- |
| HTTP status | `200` |
| Raw response bytes | `147694` |
| Raw response SHA-256, independently computed | `ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98` |
| `matchId` | `55980642` |
| `chainId` | `4663` |
| `address` | `0x56C8c249d4c021e93635b120aC68A9a36eb01753` |
| `creationMatch` | `exact_match` |
| `runtimeMatch` | `exact_match` |
| `match` | `exact_match` |
| `verifiedAt` | `2026-10-12T10:33:37Z` |
| Source files | `28` |

For each of the 28 entries, I compared the local raw bytes against its decoded live `content` string plus one trailing newline. Every comparison matched. Thus the local source line references below identify the retrieved content without a substantive local-source discrepancy. Retrieval metadata is provenance evidence, not proof of the PRD's behavioral correctness.

## Source reading coverage

The complete source reading included:

- `src/pair/PairToken.sol`.
- `src/base/PriceMath.sol` and `src/vendor/uniswap/LiquidityAmounts.sol`.
- Libraries: `TickMath.sol`, `SqrtPriceMath.sol`, `FullMath.sol`, `StateLibrary.sol`, `Position.sol`, `CustomRevert.sol`, `UnsafeMath.sol`, `FixedPoint96.sol`, `FixedPoint128.sol`, `SafeCast.sol`, `LiquidityMath.sol`, and `BitMath.sol`.
- Types: `Currency.sol`, `BalanceDelta.sol`, `PoolKey.sol`, `PoolId.sol`, and `BeforeSwapDelta.sol`.
- Interfaces: `IPoolManager.sol`, `IHooks.sol`, `IExtsload.sol`, `IExttload.sol`, `IProtocolFees.sol`, `callback/IUnlockCallback.sol`, `external/IERC20Minimal.sol`, and `external/IERC6909Claims.sol`.

Imported files and interface comments were not treated as evidence that PairToken executes every function in those files. In particular, PairToken's use of the position-key helper does not establish execution of the supplied position-update implementation by the absent manager.

# Assumptions

1. The object under review is the complete pinned PRD, not an isolated paragraph or the earlier requirements. Its tagged requirements and subordinate text control under PT-CONFORM-03.
2. Ordinary Solidity 0.8.26 ABI, checked-arithmetic, conversion, and transaction-revert semantics apply. Source-preserving edge behavior is not replaced with a safer cast, clamp, callback guard, or token restriction.
3. External-call scenarios remain conditional on the stated manager, token, hook, factory, and fee-manager responses. An arbitrary manager response is not asserted to be reachable through an ordinary deployed pool.
4. Concrete manager, factory, fee-manager, hook, token, and chain-state internals are outside the supplied implementation evidence. Their absence is already explicit in PT-DEPENDS-01 through PT-DEPENDS-05; it is not a reason by itself to reject a PairToken-local definition.

# Coverage

The following summarizes the substantive comparison, rather than claiming that a provenance statement or an acceptance table proves itself.

| Area | PRD coverage examined | Source evidence and assessment |
| --- | --- | --- |
| Public surface and initialization | PT-API, PT-GET, PT-CONST, PT-INIT, PT-PERM | `src/pair/PairToken.sol:47-152`, `:156-250`, `:256-414`, `:550-571`. The 17 named functions, receiver, 17 getters, constants, five guarded entrypoints, first-caller initialization, unused `NotFactory`, and absence of an added readiness gate match. |
| Pool and position identity | PT-INIT-02, PT-VIEW-01 | `lib/v4-core/src/types/PoolKey.sol:11-21`, `PoolId.sol:10-15`, `lib/v4-core/src/libraries/Position.sol:48-66`, `StateLibrary.sol:40-62`, `:183-190`, `:279-285`, `:324-347`. The five-word pool hash, 58-byte position-key preimage, zero salt, storage offsets, and extracted widths match. |
| Integer mathematics | PT-MATH-01 through PT-MATH-05 | `src/base/PriceMath.sol:29-63`, `src/vendor/uniswap/LiquidityAmounts.sol:13-54`, `lib/v4-core/src/libraries/FullMath.sol:14-115`, `SqrtPriceMath.sol:188-253`, `TickMath.sol:20-113`. The formulas preserve staged floors and ceilings, independently checked liquidity candidates, endpoint sorting, tick coefficients, zero-price rejection, and specified cast distinctions. |
| Basket and quotations | PT-VIEW, PT-QUOTE | `src/pair/PairToken.sol:214-250`, `:500-528`. The live price is not clamped in basket; pending fees are not separately added; quote branch precedence, gross genesis preview, upward selected-amount rounding, and preview/execution differences match. |
| Paired entry | PT-DEP-01 through PT-DEP-05 | `src/pair/PairToken.sol:261-302`, `:661-675`. Native reservation precedes compounding; quote/minimum precede pulls; measured receipts do not reprice shares; all eligible idle funds the addition; genesis needs computed positive addition; dead shares are actual mints; native refund goes to the caller before `Deposit`. |
| Zap entry | PT-ZAP-01 through PT-ZAP-04 | `src/pair/PairToken.sol:314-345`, `:533-535`, `:576-607`. The cap uses the pre-zap vault basket and nominal input; the swap uses half the pull return; issuance uses add-used amounts and pre-zap snapshots; the signed tick check occurs after Deploy and before issuance. |
| Redemption | PT-EXIT-01 through PT-EXIT-05, PT-ERROR-02 | `src/pair/PairToken.sol:356-405`, `:538-543`. Caller-only burn, payout haircut, separate liquidity/idle rounding, retained low-128-bit cast, removal caller deltas, pair minima, swap-only exit, selected zero payout, and pre-swap event fields match. The low finding below concerns paragraph-local clarity, not a missing rule in the complete PRD. |
| Collection and protocol routing | PT-COMP-01 through PT-COMP-03 | `src/pair/PairToken.sol:416-463`. Collection uses caller deltas; the factory getter order, unclamped checked fee product, notification catches, approval cleanup, and lack of proof that an ERC-20 notification pulled funds match. The conditional reservation-underflow example follows the actual subsequent idle subtraction. |
| Ratio deployment and event predicate | PT-COMP-04 through PT-COMP-06 | `src/pair/PairToken.sol:434-442`, `:469-495`. Dust comparisons, sequential token0-value floors, tie direction, half-leftover proposal, active-pool reserve cap divided by four, absence of a compound tick guard, and omission of a swap-only `Compounded` event match. |
| Callback and settlement | PT-CB-01 through PT-CB-07 | `src/pair/PairToken.sol:546-641`; `lib/v4-core/src/interfaces/IPoolManager.sol:108-165`, `:183-201`; `lib/v4-core/src/types/BalanceDelta.sol:61-70`. Sender check before decoding, enum/payload schemas, no armed-request condition, signed amount encoding, price checkpoints, fee-minus-caller used amounts, and currency0-before-currency1 settlement match. Separate unlock boundaries are retained. |
| Token and native helpers | PT-BAL-01 through PT-BAL-07 | `src/pair/PairToken.sol:646-690`; `lib/v4-core/src/types/Currency.sol:40-107`; `lib/v4-core/src/libraries/CustomRevert.sol:83-117`. Measured incoming receipts, zero-pull skips, helper Boolean handling, raw-word payout acceptance, full wrapped reason/context, refund error distinction, and absence of an imported token ban match. |
| Shares, events, failures, and absences | PT-ERC20, PT-EVENT, PT-ERROR, PT-ABSENT | `src/pair/PairToken.sol:54-118`, `:156-197`, and the operation bodies above. Finite allowance precedence, no owner bypass, no allowance-consumption `Approval`, checked versus modular updates, event indexing/fields/order, and declared versus active errors are preserved. |

I also read PT-AC-01 through PT-AC-68 against their governing requirements and the corresponding source paths. I found no acceptance scenario that independently mandates a different result once its premises and PT-AC-BASE failure precedence are applied. For example, the paired quote `(333,100,234)`, the redemption payout `999` with requested liquidity `4995` and idle components `(10,9)`, and the native reservation-underflow example agree with the stated integer operations. These are static arithmetic observations, not executed test results.

# Conclusions

Yes, with only non-material clarifications

No material defect.

The complete PRD accurately defines the reviewed PairToken-local behavior under the supplied standard. It preserves several behaviors that a higher-level vault description could easily misstate: paired shares are not recomputed from received ERC-20 amounts; genesis checks gross shares before deducting the dead mint; basket valuation does not clamp the live price; protocol reporting does not prove token movement; collection/removal casts do not reject every negative delta; zero chosen-leg payouts still call the transfer helper; and redemption events retain pre-swap pair amounts.

The explicit external dependency boundaries are appropriate. They do not excuse a demonstrated local mismatch, but I found none that requires changing the verdict. One local wording clarification is recorded below because the complete PRD already supplies the correct ordering rule.

# Review findings

## ASTRA-L1 - low: Repeat the retention-before-position-read order in the shared exit paragraph

**Location:** `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md:277-285` (PT-EXIT-01/02), read together with `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md:473` (PT-ERROR-02). Source: `docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/evidence/sources/src/pair/PairToken.sol:391-405`.

**Invariant or requirement:** After the idle reads and caller burn, the checked retention multiplication and division occur before the position-liquidity read. Source lines 396-399 put the burn, payout calculation, position read, and removal-liquidity calculation in that order.

**Impact:** The sentence at PRD line 277 says to read position liquidity after the burn without mentioning the intervening payout calculation. A reader implementing from this paragraph alone could place that external read before retention arithmetic, changing which failure occurs first when both can fail. This is non-material in the complete PRD: line 473 already orders retention arithmetic before the liquidity read, and PT-CONFORM-01 requires the requirements to be read together. The PRD does not actually permit the reordered implementation when read as a whole.

**Fix direction:** Clarify PT-EXIT-01 locally as: burn the caller's shares, calculate the checked payout, then read position liquidity and calculate the removal amount. Keep the existing formulas and PT-ERROR-02 precedence; no new guard or behavior change is needed. Do not modify the source.

**Evidence class:** Direct static source-to-PRD comparison; paragraph-local clarity issue resolved by an existing normative rule elsewhere in the same PRD. Not a runtime observation.

# Limits

- This is an independent initial response, not the coordinator's synthesis or another member's vote. No advisory pass was started.
- Static reading is not runtime proof. I ran no contract tests, builds, installations, deployments, or live-chain calls.
- The raw-byte hashes and source-content comparisons establish which documents were reviewed; they do not establish executable equivalence.
- No whole-system guarantee is made about absent manager, factory, fee-manager, hook, token, or deployed-state behavior. I did not infer those implementations from interfaces or comments.
- This is not a bytecode-equivalence, storage-layout, legal-clearance, source-nonexposure, or economic-safety opinion.
- The finding proposes only a PRD clarification. It was not applied to the PRD or source, and this response does not authorize implementation.
