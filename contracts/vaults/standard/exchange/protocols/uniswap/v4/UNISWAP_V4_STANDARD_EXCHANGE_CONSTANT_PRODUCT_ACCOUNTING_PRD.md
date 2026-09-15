# Uniswap V4 Standard Exchange — Constant-Product Accounting

**Implementation:** See [new-version code and integration notes](../README.md) and the linked validation record. This PRD retains the broader release matrix.

**Status:** New implementation and focused regression suite complete; broader release requirements retained
**Date:** 2026-09-15
**New implementation:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/`
**Preserved implementation:** `contracts/protocols/dexes/uniswap/v4/`

> **Scope update — V3/V4 and pretransfer security:** the owner now requires two new vault versions with the same liquidity economics, plus correction of the stale-reserve pretransfer vulnerability in both. The [shared remediation PRD][shared-remediation] governs this expanded scope and its P0 tests. This file remains the common economic reference at its original path; the [V3 companion PRD][v3-companion] defines protocol-specific adaptation. Neither old source tree may be changed.

## 1. Purpose

Deliver a separately identifiable V4 Standard Exchange implementation whose deposits, share ownership, withdrawals, and quotes consistently implement the owner's intended **Uniswap V2-style constant-product liquidity model**, while supporting a local liquidity sleeve and a full-range V4 position.

The work follows an unexpectedly large WETH withdrawal from a DTF/ETH vault. The observed transactions must be reproduced and explained against the intended model before changing formulas. A profitable trade against a mispriced constant-product inventory is not, by itself, an accounting defect.

The deployed implementation must remain in its original location as an unchanged reference. This PRD does not authorize changing the deployed vault, moving funds, changing live settings, or migrating existing DETFs.

## 2. Authority and interpretation

### 2.1 Owner requirements

| ID | Requirement |
|---|---|
| D1 | Preserve the existing implementation in place for reference and analysis. Implement the corrected version in the new directory above. |
| D2 | Treat liquidity and share ownership using constant-product / proportional-liquidity economics, as in Uniswap V2. Do not silently substitute an oracle-valued, single-numeraire portfolio. |
| D3 | Define a fair deposit process and verify that every supported exit accounts for the resulting ownership consistently. |
| D4 | Preserve the investigation, including the correction to the initial diagnosis. Do not encode an unproven interpretation as a regression expectation. |
| D5 | Apply the same liquidity-management economics to new V3 and V4 versions, using their distinct protocol execution adapters. |
| D6 | Fix the reported stale-reserve pretransfer bug in both new versions. No position repricing may substitute for an actual input delivery. This requirement is independent of the economic interpretation in §2.2. |

The existing [DETF alignment PRD, D57–D59 and §24.7.1][alignment] requires full-range positions, complete-book accounting, two-token activation, subsequent single-token deposits, and funded sleeve operations while the underlying pool cannot be modified. These remain requirements for this work.

The old [liquid-buffer PRD][buffer-prd] and [full-range PRD][range-prd] remain historical references. Their obsolete sections do not override the alignment PRD or the owner's requirements above. Do not edit them to make the old implementation appear to satisfy the new design.

This document specifies the target behavior and the evidence required to implement it. Choices explicitly listed in §10 remain unresolved; they must receive a concrete specification and reference tests before dependent production implementation. Draft proposals must not be reported as owner-approved decisions.

### 2.2 Correction to the initial investigation

Earlier analysis compared share redemption with market-valued contributions and described the square-root mint formula as necessarily defective. That conclusion was too strong for the intended product:

- A reserve ratio is a price in a constant-product pool. A WETH-rich, DTF-scarce pool prices DTF highly, regardless of another market's price.
- Ignoring fees and rounding, the current square-root growth expression can represent a single-token constant-product swap followed by a proportional liquidity addition.
- A large payout, a large share fraction, or a better return than a direct swap at another venue does not alone demonstrate an implementation error.
- Equal-value funding reduced the observed difference in simulations. That demonstrates sensitivity to inventory ratios, not that equal market value must be enforced by this product.

The engineering task is to identify discrepancies between actual behavior and the specified constant-product reference process, including reserve definitions, fee treatment, position accounting, and execution during pool operations. Correct those discrepancies; retain mathematically valid behavior even when it exposes ordinary AMM arbitrage.

### 2.3 Separate confirmed source-level funding flaw

The auditor's supplied account identifies a different issue: `_secureTokenTransfer` subtracts a **current** deployed token quantity from a **previously stored** total to infer booked local custody. An external pool trade can make this infer positive input credit with no token delivery. Equivalent executable helper logic is present in both preserved V3 and V4 sources.

This is not ordinary constant-product arbitrage. The [shared remediation PRD][shared-remediation] specifies the mechanism, evidence limitations, required separate delivery accounting and PT-01 through PT-11 regression tests. A zero-delivery caller receiving deposit-funded shares or outputs must not be excused by §2.2 or the economic decisions still open in §10.

## 3. Historical evidence and preservation

### 3.1 Observed mainnet activity

These are historical findings from the preceding read-only investigation, not new live-state claims.

| Item | Evidence |
|---|---|
| Network | Robinhood mainnet, chain ID `4663` |
| SE vault | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| Deposit | [Transaction `0x73cb89…31aaa9`][deposit-tx], block `63,428,570`: `3,821,584.602086025844922413` DTF deposited; `8,016.015264635240674926` SE shares minted. |
| Ownership after deposit | Approximately `99.9986002292%`, reconstructed from share mint/burn events and a later supply snapshot. |
| Pool funding during deposit | Receipt showed `4.026868923220639354` WETH unwrapped and `3,057,267.681668820675937688` DTF transferred to the PoolManager. |
| Withdrawal | [Transaction `0x305e48…ff9f7`][withdraw-tx], block `63,448,485`: the same shares burned; `94.048048190442332206` WETH paid. |
| Ownership before withdrawal | Approximately `91.5106878717%`, after intervening activity. |

The vault is **V4**, notwithstanding earlier references to V3 in the discussion.

Historical state calls at the transaction blocks failed with the RPC's `metadata is not found` error. Receipts and event logs remained available. The approximate pre-deposit DTF total inferred from mint mathematics is an inference, not an archival balance observation. Tests must distinguish exact historical replay from a reconstructed scenario.

### 3.2 Code provenance

The investigation matched these live components to local build artifacts:

| Component | Address | Comparison |
|---|---|---|
| In facet | `0x4D9976E8Fd5C6f698DF0303C6056efAff47e6f48` | Runtime matched after resolving constructor immutable delegate addresses. |
| In execution delegate | `0x1396ab43c85bbf201322b18f5840f32b609851f3` | Exact runtime match; code hash `0x636ce285e0692f5258b686d0669ab8524b83182ad10df076b509a6d82de2aece`. |
| In multi-query facet | `0xB69eCB09a9DEa163260d1f973B3a338996D46026` | Exact runtime match to `UniswapV4StandardExchangeInMultiQueryFacet`, which exposes the three-argument preview. |

The source hashes recorded in matching artifact metadata were:

| File under the preserved directory | Keccak-256 |
|---|---|
| `UniswapV4StandardExchangeCommon.sol` | `0x08da97caaa7cdfc244ee40076b1158c68d5d6c4ecf070fdde0b375116b0da4f2` |
| `UniswapV4StandardExchangeInBase.sol` | `0x6b84625921209b7fb148588f55526da2c3cfc0a03cfec17664d703901de4e0e6` |
| `UniswapV4StandardExchangeInTarget.sol` | `0x64512443172fc7b635f5ae1893aa536585353fbbbd5514ff061890ccf279bda7` |

### 3.3 Preservation requirements

Before implementation, capture a durable baseline manifest containing source hashes, relevant transitive dependency revisions, compiler settings, artifact identifiers, constructor inputs, facet cuts, and deployment provenance. Preserve the original evidence alongside the corrected interpretation in §2.2.

The original investigation files were saved locally under `/tmp/indexedex-se-investigation/`, including `REPORT.md`, `transactions.json`, `verification.json`, `extra.json`, `simulations.json`, and `reverse-simulations.json`. That location is temporary and its report predates the constant-product clarification. Archive relevant files durably as implementation evidence; do not rely on `/tmp` as the sole reference or silently rewrite the original conclusions.

Do not move, rename, reformat, replace with forwarding imports, or repair files in the preserved implementation tree. New tests may exercise those files unchanged. Changes to shared dependencies must not silently alter the old comparison implementation; pin or isolate its dependency/artifact context when necessary.

## 4. Scope

### In scope

- A reference economic model and comparative diagnosis of old versus intended behavior.
- Corrected V4 SE accounting and execution under the new directory.
- Equivalent new V3 liquidity accounting and secure delivery under the shared remediation PRD, with V3-specific pool/callback behavior.
- P0 stale-reserve pretransfer reproduction and correction across both new families and all affected token-input/refund routes.
- Initial activation, ordinary and imported full-range positions, single- and two-token entry/exit routes.
- Exact-input, exact-output, previews, transition quotes, share conversions, and associated SY integration surfaces.
- Free assets, deployed assets, earned fees, donations, rounding, and native ETH/WETH representation.
- Idle and in-session PoolManager behavior, including funded sleeve operations used by existing hook integrations.
- Separately identifiable facets, execution delegates, package/factory wiring, and production-path tests for the new version.
- Compatibility and migration notes describing what new instances can support.

### Out of scope

- Changing the old contracts, deployed instances, deployment manifests, or currently running tool UI.
- Mainnet deployment, vault replacement, transferring balances, disabling the live vault, or changing live fee/sleeve settings.
- Retrofitting immutable DETFs to accept a replacement vault without a separately established mechanism.
- Oracle-NAV issuance, guaranteed execution at an external market price, or a promise that LPs cannot lose value through arbitrage.
- Automatic trading by `rebalanceLiquidReserve()` as a presumed fix, or a DTF refill bot as a correctness requirement.
- Functional changes to SE families other than the newly required V3/V4 versions, reserve-hook liquidity permissions, or DETF bond economics.

## 5. Economic specification

### 5.1 Definitions and accounting boundary

Let `X` and `Y` be the complete backing quantities of the two configured assets before the user operation, and `S` the outstanding SE share supply. Quantities are expressed in each token's native units at transfer boundaries.

For each token, the complete book includes:

1. Spendable local inventory attributable to the vault.
2. Exact token amounts represented by the vault's V4 position, calculated at the actual position bounds and pool state.
3. Earned fees attributable to shareholders and not already counted in either balance above.

Explicitly account for protocol fee liabilities and assets owed to the current caller. A transfer or fee collection cannot count the same asset twice. A position's liquidity scalar is not a substitute for the complete book.

Maintain the distinction between:

- **Accounting reserves:** the assets backing all shares.
- **Executable reserves:** the inventory actually available for a particular swap or payout, in the current PoolManager state.
- **External pool state:** the V4 price, liquidity, fee schedule, and hook behavior governing a swap performed there.

These quantities cannot be substituted for one another implicitly. A full-range V4 position with finite tick bounds is not an exact V2 pair: derive position amounts with concentrated-liquidity mathematics.

### 5.2 Activation and proportional deposits

Activation requires actual funding in both tokens, including imported-position activation. Apply the existing minimum/dead-share and empty-supply residual policy explicitly; prior donations must not be captured for free by a first depositor.

For an already activated book, a proportional contribution `(dx, dy)` uses the V2 ownership reference:

```text
shares = min(dx * S / X, dy * S / Y)
```

Evaluate this against reserves immediately before the liquidity addition, after any swap or fee settlement belonging to that route. Round share issuance down. Attribute only actual user-delivered assets to that user's contribution.

A two-token input with surplus must have an explicit policy: return unused input, treat identified excess as a donation, or convert it through the specified zap. §10 requires selection and quote coverage; no silent surplus confiscation or refund from prior shareholders' assets.

### 5.3 Single-token deposits

A single-token deposit must be economically equivalent to:

1. Swapping the required portion of the input under the specified constant-product swap process.
2. Accounting for swap fees, price impact, and the resulting reserve transition.
3. Adding the remaining input and swap proceeds proportionally against the post-swap reserves.
4. Minting the corresponding SE shares and settling every asset movement or internal claim once.

V2's pair does not itself provide a single-token LP mint. Its swap and proportional mint compose into this reference process. An algebraic or internally settled implementation is allowed only if it is proven equivalent, including the resulting reserves and existing holders' claims; matching the number of minted shares alone is insufficient.

For a **zero-fee, same-book** reference with positive `X`, `Y`, `S` and a `Y`-only input `d`:

```text
swapInputY = sqrt(Y * (Y + d)) - Y
swapOutputX = X * swapInputY / (Y + swapInputY)
newShares = S * (sqrt(1 + d / Y) - 1)
```

These real-number formulas establish a reference case. They are not a prescription to reuse the last expression when fees, a different swap venue, rounding, or execution constraints change the economics. Uniswap V2's fee-adjusted swap invariant supplies the fee-bearing reference; do not invent a new fee or hardcode V2's fee into the V4 product without specifying the fee policy.

**Worked example, excluding fees and integer rounding:** with `100 X`, `10,000 Y`, and `100 S`, deposit `2,100 Y`. Swap `1,000 Y` for approximately `9.090909 X`. The post-swap pool has approximately `90.909091 X` and `11,000 Y`. Contribute the `9.090909 X` and remaining `1,100 Y`, minting `10 S`. The depositor owns `10/110`, or approximately `9.090909%`, of the final book. This example must agree with an independently executed reference.

### 5.4 Withdrawals

Burning `b` shares establishes a proportional entitlement to both backing assets:

```text
entitlementX = X * b / S
entitlementY = Y * b / S
```

Actual token settlement must reconcile position-removal rounding and fees. A request for only one token additionally requires conversion of the other entitlement using the declared swap/settlement process. Account for the post-removal pool state, available liquidity, execution fees, partial fills, price limits, and residual assets.

Do not silently discard the entitlement to the other token because the PoolManager is busy. Do not pay an invented conversion amount from existing holders' assets. Internal settlement requires a specified, funded reserve transition equivalent to the reference operation. Exact-output exits round required input shares up and enforce the caller's maximum; impossible output must revert rather than succeed with a supply clamp or short payment.

Entry and exit need not use the same external venue, but any difference must be explicit and simulated with that venue's actual state. An arbitrage opportunity between declared venues is distinct from creating an unbacked claim.

### 5.5 Fairness and economic risk

Fairness means receiving the claims and paying the costs specified by the constant-product process, with no undocumented transfer of claims between users.

It does **not** mean:

- A token always has the price observed in another market.
- A deposit must redeem for its externally marked value.
- WETH and DTF must remain equal in external market value.
- Every profitable deposit/redemption sequence is forbidden.

For a closed reference cycle with unchanged external conditions and no third-party deposits, donations, or fee income, unexplained gains beyond the independently modeled trades, fees, and rounding are a defect. For cycles involving different prices or venues, attribute gains to the actual trades before classifying them. Tests must not hide an error behind a broad “arbitrage allowed” exemption.

## 6. Execution, sleeves, and integration requirements

| ID | Requirement |
|---|---|
| R1 | Use one documented accounting model across In/Out, multi-token routes, previews, transition quotes, and SY conversions. Different routes may have different execution costs, but cannot silently assign incompatible claims to the same shares. |
| R2 | Preserve subsequent single-token deposits during an outer V4 operation. Never open a nested PoolManager unlock. Define internal sleeve settlement explicitly; assuming an external swap always remains possible is insufficient. |
| R3 | When interaction is blocked, serve a requested output only when the local inventory can fund the specified settlement in full. Otherwise revert atomically. Cover alone does not justify incorrect entitlement pricing. |
| R4 | Quotes use the same route, fee policy, reserve transitions, and rounding as execution. At identical state, quantify and test any unavoidable quote tolerance. A view must not imply that an unavailable route is executable. |
| R5 | Snapshot and validate accounting around external calls. Reentrancy, hook callbacks, and in-session pool state must not allow a second credit or a valuation change to manufacture shares. |
| R6 | Keep the live fee-oracle sleeve percentage and its inheritance/zero-as-unset semantics. A sleeve target is a placement preference, not a share-pricing rule or hard withdrawal cap. |
| R7 | Retain permissionless add/remove-only `rebalanceLiquidReserve()` and its PoolManager gate. Placement alone must not change total claims; explain rounding or earned fees separately. Do not add swaps to this function through this PRD. |
| R8 | Handle ETH/WETH as representations of one pool currency without double counting; wrap/unwrap only as required for actual settlement. Preserve PoolKey token ordering for native-currency pairs. |
| R9 | Support allowed mixed decimals, small inputs, large products, and near-empty reserves. Reject unsupported token behavior under existing project law; do not add a token allowlist or claim fee-on-transfer/rebasing-underlying support. |
| R10 | Pretransferred, approval, and permit routes prove actual delivery and cannot reuse a previous transfer or donation. Refunds are capped to this caller's unused input. |
| R11 | Preserve full-range position requirements, including imported-position activation and accounting. Test collection, deployment, removal, and price movement as distinct transitions. |
| R12 | Inventory every exposed selector and integration before changing accounting. Shared generic interfaces remain usable; any unavoidable incompatibility needs explicit migration notes and tests. |
| R13 | Separate operation input credit from complete-book valuation in both versions. Implement and test the secure-delivery requirements of the shared remediation PRD; a stale stored total minus a live deployed amount is never evidence of receipt. |

PoolManager terminology: **idle** means its lock is closed and this vault can open its own unlock session. **In-session / interaction-blocked** means another session is already open and the vault must not attempt nested unlock. These are execution conditions, not alternative share-ownership policies.

## 7. Version separation and deployment architecture

Use Crane Facet/Target/Repo and CREATE3/FactoryService patterns. Define package argument structures on interfaces. Deploy test vault packages through the IndexedEx manager vault registry.

The new implementation must have an unambiguous identity across fully qualified artifact paths, facet/package metadata, constructor delegate addresses, factory methods, deterministic salts, and registry discovery. Identical short Solidity names in different directories must not cause the build or factory to select the preserved artifact accidentally. The implementation plan must enumerate the actual old/new mapping before deployment wiring changes.

Reuse stable interfaces and protocol libraries where appropriate. Do not solve preservation by inheriting old implementations and changing their behavior through edited shared bases. Conversely, avoid copying unrelated protocol infrastructure just to change the accounting path.

Do not repoint current deployments or consumers to the new package as part of implementation. Produce compatibility notes covering SE selectors, hook use during pool operations, quote adapters, SY, and new DETF compositions. Existing immutable instances remain separate; no in-place upgrade or automatic migration is assumed.

## 8. Acceptance criteria

The old implementation, corrected implementation, and independent reference must be distinguishable in test output. A reference must not call the same production mint/withdraw helper whose correctness it claims to establish.

| Test ID | Required evidence |
|---|---|
| CP-01 | Preserved source-tree hashes remain unchanged; required old artifacts/provenance are captured. Old and new package/facet/delegate identities cannot collide or be confused. |
| CP-02 | Two-token activation, minimum/dead shares, residual inventory at empty supply, and first-mint donation cases reconcile ownership without free capture. |
| CP-03 | Proportional joins match V2 mint mechanics; imbalanced two-token inputs follow the explicit surplus policy. |
| CP-04 | Single-token joins in both directions match independently executed swap-then-mint transitions, including the §5.3 zero-fee example and fee-bearing cases. |
| CP-05 | Proportional exits and single-token exits match burn-then-convert reference transitions. Exact-output routes return the full requested output within the caller's maximum or revert atomically. |
| CP-06 | WETH-rich/DTF-scarce and reverse cases include near-zero reserves and very large deposits. Classify gains as reference-consistent arbitrage or an identified discrepancy; do not require an arbitrary market-value payout cap. |
| CP-07 | Reproduce the historical deposit/share/withdrawal observations to the extent supported by evidence. Label reconstructed state and isolate intervening deposits, swaps, and fee income from the user's round trip. |
| CP-08 | Same-token and opposite-token cycles, repeated operations, split deposits, and alternating users produce no unexplained gain relative to the full reference sequence. Include real external price movements and their costs. |
| CP-09 | Generic outer-unlock harness and at least one real consuming hook demonstrate funded single-token entry and output while in-session, with no nested unlock, forfeited entitlement, or free claim. Insufficient local output reverts cleanly. |
| CP-10 | Local/deployed splits, 2% and inherited 20% targets, fee collection, rebalance, and donations reconcile complete reserves. Placement alone cannot create share value. |
| CP-11 | Preview, execute, exact-output inverses, transition quotes, and SY conversions agree under the specified execution conditions. Cover partial fills, reserve exhaustion, stale state, and unsupported routes. |
| CP-12 | Mixed decimals, native ETH/WETH mapping, extreme ticks, full-range/imported positions, rounding, multiplication overflow, and final-share exits satisfy explicit error bounds. |
| CP-13 | False/short/reused pretransfers, prior donations, overpayment refunds, malicious callbacks, and signature misuse cannot create an unfunded claim or transfer another user's assets. |
| CP-14 | Target/interface selectors, facet declarations, package cuts, and deployed-proxy calls agree. Test each route on the actual registry-deployed proxy. |
| CP-15 | Document live disable-control behavior separately from desired new-version behavior and applicable withdrawal-preservation rules. No live control is activated, and no additional freeze or bypass is introduced silently. |
| CP-16 | Pass shared PT-01 through PT-11 on both new families, including an external price-moving trade between reserve synchronization and a false pretransfer. Existing false-pretransfer tests at a freshly synchronized state are insufficient. |
| CP-17 | Exercise paired V3/V4 economic scenarios and document only real protocol differences. Passing one family's suite cannot satisfy the other family's release gate. |

### Test methodology

- Use existing Crane/IndexedEx TestBases and real protocol components. No mocks of the vault, manager, fee oracle, registry, package, or underlying PoolManager under test.
- Use deterministic hermetic tests for the accounting reference and regressions, with targeted fuzz/invariant tests over ratios, inputs, fees, and operation sequences.
- Historical RPC evidence supplements the hermetic tests; missing archival state is not permission to manufacture an exact replay claim.
- Follow the repository's artifact build-before-test workflow so comparisons cannot accidentally deploy stale or incorrectly resolved bytecode. Use default hermetic and standard fork profiles; no package-specific profile or `via_ir` workaround.
- Record commands, relevant revisions, fixture provenance, test results, and specific remaining limitations in the eventual implementation/test plan. This documentation-only PRD does not claim those tests have run.
- Retain the user's mainnet-wallet tool configuration. Do not start or connect that UI to Anvil for this work.

## 9. Work sequence and completion criteria

1. **Preserve and diagnose:** capture the baseline, archive evidence with the corrected interpretation, inventory routes/dependencies, and compare existing behavior with an independent constant-product model.
   Preserve both source trees and reproduce the stale-reserve pretransfer defect on real old-version deployments before claiming the input-validation problem fixed. This P0 work does not depend on selecting new economic formulas.
2. **Specify the unresolved mechanics:** produce the reserve/venue/fee/settlement decision table in §10, complete reference transitions, and an implementation/test plan under this new directory. Record which behavior is correct, which is inconsistent, and why.
3. **Implement separately:** create only the required corrected accounting components and distinct package wiring; keep the preserved implementation reproducible and unchanged.
4. **Verify:** pass the acceptance matrix on production deployment paths, including nested integration and all affected quote/conversion surfaces.
5. **Prepare migration documentation:** explain new-instance adoption, compatibility limits, and what would require a separate deployment/migration operation. Do not execute it.

Completion requires evidence of identified discrepancies being corrected, not merely different outputs or a copied implementation in a new path. If the original suspicious outcome matches the approved constant-product reference, retain it as an explained economic case and do not claim it was a fixed exploit. Any remaining implementation change must have its own demonstrated requirement or discrepancy.

The zero-delivery pretransfer flaw is independently required to be fixed in both new versions; that requirement cannot be dismissed by reclassifying the earlier funded DTF deposit as constant-product arbitrage.

## 10. Decisions to resolve before dependent implementation

The constant-product product model and source preservation are settled. The following execution details are not settled by saying “like V2”:

| ID | Required decision/artifact | Constraint |
|---|---|---|
| Q1 | Define the swap reserves and venue for every single-token entry/exit and direct swap: complete vault book, local book, or actual underlying V4 execution. Provide before/after asset and share transitions. | Complete backing remains accounted for; an external venue's price must not be silently substituted for the vault book's ratio. Any intended arbitrage between them must be described. |
| Q2 | Define how an internally settled zap works during an outer PoolManager session, and which inventory funds each transition. | Preserve funded single-token sleeve functionality without nested unlock, fictitious swap proceeds, or discarding the other-token claim. If the requirements cannot coexist under a proposed mechanism, surface the conflict rather than silently reject the required route. |
| Q3 | Map LP, protocol, hook, and any existing SE fees to explicit legs of the reference process, including fee ownership and rounding. | No double fee, omitted fee, or new fee knob introduced without an explicit product decision. Zero-fee square-root equivalence alone is insufficient. |
| Q4 | Select surplus handling for two-token inputs and partial swap fills, and define zero-reserve/final-exit behavior. | Only this caller's unused input can be refunded; prior inventory and fees remain attributed correctly. |
| Q5 | Produce the old/new artifact, storage, factory, package, and selector map. | Preserve old code and deterministic deployment identity; no accidental reuse of an old delegate or ambiguous artifact lookup. |

## References

- [Uniswap V2 pair source][v2-pair]: initial/proportional minting, proportional burning, fee-adjusted swap invariant. Pin the exact upstream revision used by the executable reference in the implementation plan.
- [Uniswap V2 pools][v2-pools]: reserve-ratio pricing and arbitrage when pool and market prices differ.
- [Preserved V4 implementation][baseline], especially `UniswapV4StandardExchangeCommon.sol`, `UniswapV4StandardExchangeInBase.sol`, `UniswapV4StandardExchangeOutBase.sol`, execution delegates, and multi-query targets.
- [DETF alignment PRD][alignment], D57–D59 / §24.7.1.
- [Historical local-buffer PRD][buffer-prd] and [historical full-range PRD][range-prd].
- [Repository agent router][router], [artifact build workflow][artifact-builds], and [IndexedEx testing guidance][testing].

[baseline]: ../../../../../../protocols/dexes/uniswap/v4/
[alignment]: ../../../../../detf/DETF_ALIGNMENT_PRD.md
[buffer-prd]: ../../../../../../protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md
[range-prd]: ../../../../../../protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md
[router]: ../../../../../../../CLAUDE.md
[artifact-builds]: ../../../../../../../docs/testing/ARTIFACT_BUILDS.md
[testing]: ../../../../../../../.agents/skills/indexedex-testing/SKILL.md
[v2-pair]: https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
[v2-pools]: https://developers.uniswap.org/docs/protocols/v2/concepts/pools
[deposit-tx]: https://robinhoodchain.blockscout.com/tx/0x73cb89b7148a5416c34edc6882f03a2ac277c2a925bb4a9322fbf00e6331aaa9
[withdraw-tx]: https://robinhoodchain.blockscout.com/tx/0x305e480fae272826c0c362a982ffcd0fda121828b0f879ca27a92f2f636ff9f7
[shared-remediation]: ../UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md
[v3-companion]: ../v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md
