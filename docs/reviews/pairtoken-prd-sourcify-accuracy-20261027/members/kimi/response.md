# Identity

- Reviewer: Kimi, council-member, initial independent response.
- Run ID: `pairtoken-prd-sourcify-accuracy-20261027`.
- PRD identity: `pairtoken-unified-prd-r1`.
- PRD raw SHA-256 computed from the supplied file: `1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2`.
- Source identity reported by the admitted `evidence/SOURCE.md`: matchId `55980642`, chain `4663`, address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, with `match`, `creationMatch`, and `runtimeMatch` all `exact_match`.

# Question and targets

Does `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md` accurately define the PairToken-local external behavior of the exact-match source at the supplied Sourcify URL, under the review's materiality standard?

The targets were the complete standalone PRD and the coordinator-supplied decode of the 28-file source bundle. Bytecode identity, private storage layout, helper decomposition, runtime proof, legal clearance, and unsupplied external-contract internals were not treated as requirements for approval.

# Evidence

- Read all 641 lines of the PRD, including the complete text of its long lines, and computed its raw SHA-256 locally. The computed hash matches the assigned identity.
- Read `docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/evidence/SOURCE.md` and `docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/brief.md` completely.
- Read `src/pair/PairToken.sol` completely, including its public surface, internal route logic, callback operations, settlement, and token helpers.
- Read every admitted dependency source completely: `src/base/PriceMath.sol`; `src/vendor/uniswap/LiquidityAmounts.sol`; the 12 supplied v4-core libraries (`BitMath`, `CustomRevert`, `FixedPoint128`, `FixedPoint96`, `FullMath`, `LiquidityMath`, `Position`, `SafeCast`, `SqrtPriceMath`, `StateLibrary`, `TickMath`, and `UnsafeMath`); the five supplied types (`BalanceDelta`, `BeforeSwapDelta`, `Currency`, `PoolId`, and `PoolKey`); and the eight supplied interfaces (`IExtsload`, `IExttload`, `IHooks`, `IUnlockCallback`, `IPoolManager`, `IProtocolFees`, `IERC20Minimal`, and `IERC6909Claims`).
- The comparison used the source text and dependency semantics directly, not the PRD's provenance claim or any earlier review verdict. No peer response, old report, requirements copy, or old member response was read.
- I did not refetch Sourcify. The source identity fields above are attributed to `SOURCE.md`, not represented as live observations by this member.

# Assumptions

- Per `SOURCE.md`, each local source file equals the corresponding Sourcify `sources[path].content` except for one extra local trailing newline; line numbers therefore match. This is the admitted source decode for this review.
- Solidity 0.8.26 arithmetic, ABI decoding, dispatch, and revert behavior supply the language semantics where the PRD expressly relies on them.
- Manager, factory, fee-manager, hook, token, and recipient internals remain external dependencies. Only PairToken's calls to them, consumption of their results, and local failure handling are assessed here.

# Coverage

- **ABI and state:** Checked all 17 named functions plus the receiver, all 17 generated getters, constants, pool-key and pool-ID encoding, initialization rules, reentrancy scope, custom errors, and the absence of additional entrypoints against `PairToken.sol:45-253` and `PairToken.sol:550-555`.
- **Exact arithmetic:** Checked full-precision multiplication/division and rounding-up failure behavior, amount-delta formulas, amounts-to-liquidity branching and casts, tick coefficients and intermediate floors, floor square root, signed/unsigned casts, redemption narrowing, and swap-amount sign conversion against the PRD's PT-MATH requirements and the supplied math libraries.
- **Reads and quotations:** Checked position-key and manager storage-read derivations, slot bit extraction, basket endpoint ordering and lack of clamping, idle-balance inclusion, paired quote branches, genesis guard, and redemption preview short-circuit against `PairToken.sol:201-252`, `StateLibrary.sol`, and `Position.sol`.
- **Money routes:** Checked admission and guard precedence, native reservation, automatic-compound checkpoints, pull and add ordering, genesis minting, zap cap and tick guard, redemption burn/retention/removal order, chosen-leg swap, output minima, zero-transfer behavior, refunds, and event values against `PairToken.sol:256-408`.
- **Compounding:** Checked collection deltas, runtime factory reads, uncapped protocol calculation, native and ERC-20 notification failure boundaries, idle trigger, ratio calculation, active-pool cap, separate Deploy unlock, conditional event, and public return values against `PairToken.sol:412-497`.
- **Callbacks and settlement:** Checked manager-only authorization before decoding, all five operation discriminators, payload/return schemas, Deploy price checkpoints, skip-add behavior, fee-minus-caller used amounts, delta resolution order, and separate unlock boundaries against `PairToken.sol:533-643` and the supplied manager interfaces.
- **Currency and errors:** Checked low-level transfer and approval return-data handling, native refund differences, wrapped payout errors and their fields, checked/modular arithmetic distinctions, event schemas/order, and rollback requirements against `PairToken.sol:646-692`, `Currency.sol`, and `CustomRevert.sol`.
- **Acceptance scenarios and dependencies:** Checked PT-AC-01 through PT-AC-68, including their numerical examples and edge-case precedence, against the same source behavior. Checked Part III's factory, fee-manager, manager, hook, currency, and live-state boundaries against the interfaces actually used by PairToken.

# Conclusions

Yes, with only non-material clarifications

No material defect. The PRD requires the source's PairToken-local public ABI, constants, events, errors, integer results and casts, observable check/call order, and dependency boundaries. I found no stated formula or acceptance result that diverges from the source, no extra observable guard or failure, and no omitted PairToken-local behavior that changes an external result, failure, event field, or integration contract. The single wording issue below does not change the required behavior because the same row expressly permits zero and the callback requirements otherwise state the matching rule.

# Review findings

No material defect.

## KIMI-LOW-01 — low: Add callback wording says “positive” while expressly including zero

- **Location:** `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md:364`; compared with `docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/evidence/sources/src/pair/PairToken.sol:552-555`.
- **Invariant or requirement:** An Add callback decodes a `uint128` and forwards its nonnegative signed value to the liquidity-modification path; an explicitly supplied zero remains a zero-liquidity modification.
- **Impact:** “Positive liquidity modification … including zero” is terminologically inconsistent. The explicit zero clause and the rest of PT-CB-02 preserve the source behavior, so this is only an editorial ambiguity and has no material behavioral effect.
- **Fix direction:** In the PRD only, replace “Positive liquidity modification” with “Nonnegative liquidity modification,” retaining the express zero permission.
- **Evidence class:** Low clarification, static source comparison.

# Limits

This is a static source-to-requirements comparison, not runtime proof. I ran no tests, builds, deployments, or live chain calls, and I did not independently refetch or hash the Sourcify response. Whole-system equivalence remains dependent on compatible external manager, factory, fee-manager, hook, token, and live-state behavior. This response does not authorize implementation or any edit to the PRD or source.
