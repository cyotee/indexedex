Ask: Complete the only advisory pass for `pairtoken-requirements-draft-r1` - wanted: full source-controlled feedback and an explicit position. For you: **SUPPORT**, with no requested corrections. `apply_patch` is unavailable, so the complete feedback follows for coordinator archival; no artifacts were modified. Now: no task remains. Next: no task remains.

# Kimi Advisory Feedback — PairToken Requirements Draft R1

## Draft identity

- Draft: `pairtoken-requirements-draft-r1`
- Reviewed SHA-256: `763dd6ad786ac84e61f968af77a627a2c0103a6fc6c67c8152127115083f229b`
- Hash verification: matched the supplied immutable draft exactly.
- Review inputs: the complete draft, analyst traceability, and targeted frozen-source passages where width and external-transfer semantics required confirmation.
- Peer originals and peer feedback were not read.

## Position

**SUPPORT.**

I have no substantive corrections to request. The draft is complete and accurate enough for a different agent to write an implementation plan without reading the raw PairToken source.

It preserves the source’s actual external behavior rather than repairing its quirks or substituting a preferable vault design. It also corrects overstatements present in candidate originals, including broad checked-cast assumptions, overly strong protocol-routing safety language, and uniform error tagging for malformed token returns.

## Concerns and required corrections

**None.**

I found no material public-surface omission, branch error, checkpoint reversal, rounding error, unsupported dependency assumption, event/error mismatch, or provenance overstatement that should block coordinator finalization.

## Verification summary

### 1. Complete public interface and permissions

PT-API-01 through PT-API-18 and PT-GET-01 through PT-GET-17 cover all 17 declared named functions, the payable receiver, and all 17 generated getters. Visibility, mutability, return tuples, caller/recipient rules, nonpayable behavior, and non-reentrancy scope are consistent with PairToken lines 47-74 and 133-574.

The draft correctly states that:

- the first successful initializer becomes `factory`;
- no active `NotFactory` guard exists;
- only deposit, zap deposit, both redemptions, and compound carry the entered guard;
- callback admission is manager equality without an armed flag;
- ERC-20 methods and native receipt do not acquire an initialization or operation lock; and
- unknown selectors have no fallback or invented administrative API.

### 2. Exact arithmetic and width behavior

PT-MATH-01 through PT-MATH-05 provide the required full-precision and checked-arithmetic distinctions, all reserve branches, amount/liquidity rounding, integer tick function, and signed-width behavior.

The following source-sensitive corrections are especially important:

- **Redemption liquidity narrowing:** PT-MATH-05 and PT-EXIT-02 correctly specify low-128-bit retention rather than an added checked-positive or checked-narrowing guard. Source anchor: `PairToken._redeemToSelf`, original line 399.
- **Removal and collection deltas:** `U128` correctly models same-width signed-to-unsigned reinterpretation before widening. Source anchors: `unlockCallback`, lines 554-564.
- **Swap amount encoding:** the `2^255` failure and above-boundary sign reinterpretation are correctly distinguished from a safe-cast requirement. Source anchor: `_deployInLock`, line 590.
- **Swap output:** nonpositive opposite-currency delta becomes zero rather than causing a new output guard. Source anchors: lines 590-591.
- **Checked products:** genesis, retention, protocol-fee, and both cap products retain their ordinary overflow behavior instead of being silently rewritten into full-precision operations.
- **Tick math:** the integer coefficients, intermediate floors, inversion, and final ceiling are sufficient to reproduce exact tick-price results without floating-point substitution.

These clauses supersede my earlier prose where it implied broader checked narrowing than the source provides.

### 3. Deposits, genesis, and zap behavior

PT-QUOTE-01 and PT-DEP-01 through PT-DEP-05 cover every quote branch and the required ordering:

1. recipient/native admission;
2. native reservation;
3. automatic compounding;
4. basket/supply checkpoint;
5. gross quote and `minShares`;
6. measured pulls without paired-share recomputation;
7. deployment of all supportable idle balances;
8. genesis dead mint and net recipient mint; and
9. native refund followed by `Deposit`.

The draft correctly preserves:

- gross `minShares` before genesis dead-share deduction;
- `BadGenesis` for a zero-supply geometric quote at most 1,000;
- the separate zero-supply positive-computed-addition requirement;
- no new dead mint when supply is positive but both reserves are zero;
- gross deposit previews versus net genesis execution;
- measured ERC-20 receipt without share requotation;
- non-universal ERC-20 refunds; and
- native refunds to the caller rather than the share recipient.

PT-ZAP-01 through PT-ZAP-04 correctly distinguish the user-zap vault-basket cap from compounding’s active-pool cap. They also preserve half of measured receipt, post-deployment tick-limit checking, pre-zap basket issuance, deployment-returned used amounts, and the absence of a zap-specific native/leftover refund.

### 4. Redemption, zero payouts, and partial fills

PT-EXIT-01 through PT-EXIT-05 accurately specify:

- post-compound supply and idle checkpoints;
- caller-only burn without allowance delegation;
- `floor(s*9990/10000)`;
- separate liquidity and idle rounding;
- actual removal caller-delta inclusion;
- independent paired minima;
- chosen-leg output selection and pre-swap event amounts;
- skip-add suppression of all addition during the redemption-only swap;
- the selected-currency transfer even when final output is zero; and
- no last-holder or dead-share sweep.

The draft expressly preserves zero-payout burns and does not add complete-input-consumption or positive-output requirements. PT-AC-27 properly makes partial-fill success conditional on actual settlement, aggregate `minOut`, and payout success rather than claiming every partial fill succeeds.

### 5. Collection, protocol routing, and compounding

PT-COMP-01 through PT-COMP-06 correctly describe collective caller-delta collection, runtime factory reads, gross fee returns, protocol carve calculations, strict dust thresholds, ratio selection, active-pool quarter caps, zero-swap deployment attempts, and conditional `Compounded` emission.

The external-failure qualifications are appropriately narrow:

- caught native notify reverts report zero;
- false/failing ERC-20 approval skips notify;
- caught ERC-20 notify reverts attempt approval clearing;
- successful notify does not prove an ERC-20 pull or allowance consumption;
- there is no unconditional success-path allowance reset; and
- malformed approval data, cleanup decoding failures, factory failures, and call-setup failures can still abort.

Source anchors are `PairToken._carve` at lines 447-463 and `_tryApprove` at lines 688-690. These requirements correctly avoid my earlier broader implication that fee-manager failure is uniformly non-blocking.

The compounding cap and tick behavior are also correct: active pool liquidity, not the vault basket, controls the compound cap, and the user-zap tick guard is not imported into compounding.

### 6. Callback, settlement, native, and token behavior

PT-CB-01 through PT-CB-07 cover every callback operation, payload and return schema, zero-salt modification, empty hook data, used-amount calculation, Deploy price checkpoints, skip-add behavior, and per-currency settlement order.

PT-BAL-01 through PT-BAL-07 correctly distinguish:

- idle native balance minus reservation from ERC-20 `balanceOf`;
- balance-measured incoming pulls;
- low-level pull/manager-payment helpers that reject with PairToken `TransferFailed` on call failure or decoded false;
- malformed nonempty return data that can instead fail ABI decoding;
- native refund failure using `TransferFailed`; and
- outgoing `Currency.transfer` payouts using their distinct wrapped-error behavior.

The outgoing ERC-20 payout rule—empty return data or at least 32 bytes whose first word is exactly one, with extra bytes permitted—matches `Currency.sol:40-95`. The draft does not mislabel every malformed payout or pull as `TransferFailed`.

### 7. Events, errors, and acceptance coverage

All five events have the correct field order and indexing. The draft retains:

- genesis dead mint before recipient mint;
- paired native refund before `Deposit`;
- net genesis `Deposit.shares`;
- measured paired-deposit amounts versus zap add-used amounts;
- burn `Transfer` before redemption payout;
- pre-swap pair amounts in zap `Redeem`; and
- conditional `Compounded` after collection/routing/deployment.

All 13 declared local errors, including unused `NotFactory`, are covered with meaningful precedence and dependency-failure qualifications.

The 58 acceptance scenarios are observable criteria rather than an implementation plan. Their arithmetic examples are consistent with the requirement formulas, including the paired quote `(333;100,234)`, gross/net genesis example, retained redemption example, zero-burn case, protocol carve example, and signed-width boundaries.

## Disposition of Kimi’s original material topics

| Original topic | Draft disposition |
|---|---|
| System property, one position, collective fees, no personal escrow | Resolved by PT-SCOPE-01 through PT-SCOPE-04 and PT-ABSENT-01/02. |
| Complete named functions, receiver, generated getters | Resolved by PT-API-01 through PT-API-18 and PT-GET-01 through PT-GET-17. |
| Initialization, full-range identity, zero salt, first-caller factory | Resolved by PT-INIT-01 through PT-INIT-03 and PT-VIEW-01. |
| Exact math, all reserve branches, rounding, and genesis | Resolved by PT-MATH-01 through PT-MATH-05, PT-QUOTE-01, and PT-DEP-02/04. Width wording is corrected where my original was too broad. |
| Paired deposits, native reservation/refund, measured ERC-20 receipt | Resolved by PT-DEP-01 through PT-DEP-05 and PT-BAL-01/02/06. |
| Single-leg zap and distinct zap/compound caps | Resolved by PT-ZAP-01 through PT-ZAP-04 and PT-COMP-05. |
| Redemption, retention, dead shares, zero payout, and partial fill | Resolved by PT-EXIT-01 through PT-EXIT-05 with exact low-width and output rules. |
| Collective collection, protocol routing, and ratio compounding | Resolved by PT-COMP-01 through PT-COMP-06, including external-failure qualifications. |
| Callback operations, delta conversion, settlement, and hooks | Resolved by PT-CB-01 through PT-CB-07 and PT-DEPENDS-03/04. |
| Plain ERC-20 allowances and transfers | Resolved by PT-ERC20-01 through PT-ERC20-04. |
| Views, previews, donations, and absent `getRate` | Resolved by PT-VIEW-02 through PT-VIEW-05, PT-BAL-01, and PT-ABSENT-01. |
| Events, errors, native/token failure surface | Resolved by PT-EVENT-01 through PT-EVENT-03, PT-ERROR-01 through PT-ERROR-04, and PT-BAL-03 through PT-BAL-06. |
| Acceptance scenarios and dependency/provenance boundaries | Resolved by PT-AC-01 through PT-AC-58 and Part III. |

## Handoff and provenance assessment

The planner-facing draft is original prose, interface/data tables, and mathematical definitions. It does not contain target source listings or require the planner to consult raw code. The tick coefficients, storage-read conventions, and ABI schemas are necessary behavioral contracts, not copied implementation listings.

Part III properly separates settled local behavior from unknown factory, fee-manager, manager-engine, hook, token, deployment, and live-state behavior. Those unknown concrete dependencies are not treated as missing PairToken requirements, and the draft does not invent their values or guarantees.

The provenance language is factual and bounded: the document is source-informed, a different planner alone does not prove source nonexposure, and no legal or license conclusion is made. No new product behavior is introduced.

**Final advisory disposition: SUPPORT. No changes requested.**
