# Coordinator-preserved drafting contribution

Kimi returned this original contribution inline for the unified PRD authoring task. Preserved verbatim from Native final_response. It is not an advisory disposition or a replacement for the previous fidelity-review original.

---

## Recommended disposition

Integrate the following prose and acceptance rows directly into one complete standalone `pairtoken-unified-prd-r1`. Preserve the existing requirement IDs and all 58 original scenarios unchanged; do not publish the unified PRD as a summary or as r2 plus an errata companion.

## Exact prose to integrate

### Product purpose and operations

> **Product purpose.** Pair Token exposes a freely transferable ERC-20 share backed collectively by one directly held, full-range PoolManager position and the instance's idle pool-currency balances. It provides paired and single-currency entry, paired and chosen-currency exit, permissionless compounding, and ordinary share approvals and transfers. Issuance and redemption use the exact basket, retention, rounding, and checkpoint rules below rather than an oracle, target-token liquidation rate, or per-holder fee ledger.
>
> This PRD is the complete planner-facing source-equivalence baseline. It supersedes `pairtoken-requirements-final-r2` and its proposed errata as the working document; the original artifacts remain unchanged archives. It authorizes documentation consolidation only, not implementation, deployment, economic redesign, or an IndexedEx-specific architecture adaptation.

### C1 — PT-DEP-05 final sentence

> Emit `Deposit` after the refund with pull-returned amounts `v0,v1` and net recipient shares. A native pull returns its selected nominal amount; an ERC-20 pull returns its checked post-call balance minus pre-call balance difference, including zero. A negative difference fails checked subtraction.

### C1 — PT-EVENT-02 paired/zap amount sentence

> Paired `Deposit` amounts are pull-returned amounts: nominal selected native amounts or measured ERC-20 receipts as defined by PT-BAL-02; zap `Deposit` amounts are reported add-used amounts.

### C2 — General rule under PT-BAL-01

> Whenever both configured idle balances are sampled as a pair, evaluate currency0 idle before currency1 idle. Preserve each route's stated price, burn, settlement, and reservation checkpoints. Paired-entry addition reads fresh price after its two idle reads; Deploy uses its already-held initial or post-swap price. This is an evaluation-order requirement, not a snapshot, reentrancy, or balance-stability guarantee.

Cross-reference this rule from PT-VIEW-02, PT-EXIT-01, PT-COMP-04, and PT-CB-05 without replacing their route-specific checkpoints.

### Uncapped protocol-fee consequence under PT-COMP-02/03

> The `uint16` protocol fee rate may exceed 10000. The attempted payment is not capped by the reported collection or by an independently segregated principal budget. It can therefore use other instance balance when the fee manager and currency permit the payment. Native reservation is an idle-accounting exclusion, not a spend-limited escrow. If a successful native payment reduces the actual native balance below the current reservation, the subsequent checked idle calculation can underflow; that uncaught failure reverts the whole transaction, including the payment. This conditional rollback is not evidence of a successful permanent principal drain. No fee-rate or payment clamp is added.

### Conformance and release evidence

> A source-equivalent implementation plan shall map every normative requirement ID to planned work and observable acceptance evidence, including every original and added acceptance scenario. It shall identify the concrete manager, factory, fee-manager, hook, and token assumptions without inventing their missing internals or live settings. Any intentional departure shall name the superseded requirement, identify the changed external behavior, and be presented as a product adaptation rather than source equivalence.
>
> Release evidence shall demonstrate the specified external calls and their order where observable, exact integer results and failures, event values and ordering, rollback behavior, and the applicable dependency-conditioned scenarios. These acceptance scenarios are requirements for later verification, not evidence that this PRD itself executed tests or proved runtime equivalence.

## Proposed acceptance rows

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-59 | Native paired entry sends exactly requested `amount0`, but the accepted quote selects `u0 < amount0`; sender and recipient differ | The native pull returns selected nominal `u0`, not `msg.value` or a balance delta. The reservation becomes `amount0-u0`; after minting, that amount is refunded to the sender. A successful `Deposit.amount0` reports `u0`. | PT-DEP-01/03/05, PT-BAL-02/06, PT-EVENT-02 |
| PT-AC-60 | An accepted ERC-20 pull returns successfully but leaves the instance balance unchanged; separately, the post-call balance is lower than the pre-call balance | In the first case the pull returns zero, with no positive-receipt guard or share recomputation; if the operation otherwise succeeds, the corresponding `Deposit` amount is zero. In the second case checked subtraction fails and the operation rolls back. | PT-DEP-02/05, PT-BAL-02, PT-EVENT-02, PT-ERROR-04 |
| PT-AC-61 | Call traces observe paired addition, basket, shared redemption, compound ratio calculation, and Deploy addition | Every idle pair is evaluated currency0 then currency1. Paired addition evaluates both idles before its fresh price read. Deploy instead uses its already-held initial/post-swap price. Redemption preserves idle reads before burn and position-liquidity read after burn. | PT-VIEW-02, PT-DEP-03, PT-EXIT-01, PT-COMP-04, PT-CB-05, PT-BAL-01 |
| PT-AC-62 | An established zap passes admission, cap, and tick checks, but Deploy reports `used0=used1=0` and no liquidity addition | The pre-zap basket fractions produce `g=0`; the zap rejects with `MinShares`. No dead-share mint or separate no-add guard is introduced, and the pull/swap effects roll back. | PT-ZAP-03/04, PT-CB-05, PT-ERROR-04 |
| PT-AC-63 | `compound()` runs with zero position liquidity and idle balances that trigger a successful Deploy addition | No Collect unlock or collection-routing factory reads occur. The public return remains `(0,0)` even when reported addition is positive; `Compounded` has zero fee fields and the requested successful `liquidityAdded`. | PT-COMP-01/02/06 |
| PT-AC-64 | A chosen-native redemption has final output zero and `minOut=0`; separately, the recipient rejects the zero-value native call | On success, the route still makes the empty-calldata zero-value call, returns zero, and emits the pre-swap pair amounts. On rejection, it fails with `WrappedError` targeting the recipient, selector `bytes4(0)`, `NativeTransferFailed()` details, and the raw revert reason; the transaction rolls back. | PT-EXIT-04/05, PT-BAL-05, PT-EVENT-02, PT-ERROR-04 |
| PT-AC-65 | During native-funded entry, collection is 100 native, the runtime fee rate is 20000, no other free native balance exists, and reserved incoming native is `R >= 100`; notification succeeds | Collection supplies 100 and the attempted protocol payment is 200, leaving actual native `R-100`. The next idle calculation subtracts reservation `R`, underflows, and reverts the entire transaction, including collection and payment. No clamp or permanent successful principal loss is asserted. | PT-COMP-02/03, PT-BAL-01, PT-ERROR-04 |

## Preservation and standalone risks

- **Completeness:** Retain the full ABI, constants, formulas, casts, operation schemas, errors, events, dependency limits, absent-behavior list, and all original scenarios. A cross-reference to r2 or the fidelity report would not satisfy the standalone contract.
- **C1 terminology:** Do not describe native event amounts as measured balance increases, and do not accidentally impose a strictly positive ERC-20 receipt requirement. Zero is valid; only a negative post-minus-pre difference fails checked subtraction.
- **C2 ordering:** Do not flatten all routes into one generic price/idle sequence. Paired addition uses idle0, idle1, then fresh price; Deploy uses its held price before idle0 and idle1. Reservation, burn, settlement, and after-tick checkpoints remain distinct.
- **Fee explanation:** Do not add a 10000 clamp, collected-fee budget, principal escrow, or claim that a permanent principal drain succeeds. The specified example ends in checked-underflow rollback.
- **Source quirks:** Preserve gross genesis `minShares` versus net recipient shares, actual dead-share minting, unclamped basket prices, separate redemption floors, low-128 and `U128` conversions, signed swap-width behavior, modular balance/supply operations, and route-specific zero-transfer behavior.
- **Scope:** Do not introduce `getRate`, `IRateProvider`, Crane/registry deployment, target normalization, an armed callback, token restrictions, or other IndexedEx adaptations as inherited behavior.
- **Dependency boundaries:** Keep all factory, fee-manager, manager, hook, token, and live-setting unknowns inside the PRD. No companion report should be necessary to understand them.
- **Provenance:** State that the unified PRD is a new identity superseding the old working baseline, not a modification of archived r2. Carry the static-evidence, source-exposure, no-runtime-proof, and no-legal-clearance limitations without turning them into product behavior.
- **Acceptance evidence:** Keep added scenarios conditional on their stated dependencies. They clarify already-specified outcomes and are not claims of executed tests or newly introduced guards.

