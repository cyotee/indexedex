# Implementation plan: APEX 2026-09-17 council remediation

**Status:** READY FOR HUMAN REVIEW — implementation not started or authorized by this document.  
**Prepared:** 2026-09-26.  
**Owner:** Astra moderator, following four independent first passes and four same-session cross-reviews.  
**Governing input:** [REMEDIATION_PRD.md](../../reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md), 2026-09-25 final clarity pass.  
**Release unit:** fresh deployments of corrected source; not upgrades to already-deployed instances.

The requested adjacent location is under `docs/reviews/`, outside the council's permitted document roots. This plan is therefore saved under `docs/plans/`, with the source PRD linked above. The source PRD is unchanged.

## 1. Outcome, authority, and boundaries

Implement and produce auditor-readable evidence for RC-01 through RC-08, without relying on earlier completion statements. Money/control regressions use the same assertion against the pre-fix source and corrected source. Use only the PRD's explicit comment, source-absence, removed-return, and documented focused-helper evidence exceptions. A compilation success, arbitrary revert, or passing return value alone is not closure.

Authority order for this work:

1. Current `CLAUDE.md`, current remediation PRD, and its owner follow-up/clarity pass.
2. Applicable current APEX decisions and family product law, insofar as not superseded by the current remediation PRD.
3. Canonical Crane and IndexedEx deployment/testing skills.
4. Source observations, older plans, and council findings as evidence, not permission or proof.

Important reconciliations:

- Current PRD lines 55–67 and 218 supersede older live-instance inventory, migration, and historical fork-replay work. None is required here.
- Current RC-07 supersedes the older BasicVault deficit-panic rule **on D16 paths**, while expressly preserving outside-D16 consumers. Merely enumerating historical consumers does not authorize changing their behavior.
- `CLAUDE.md:47–61` supersedes stale package-profile examples: use default hermetic tests, no `via_ir`, stable source/test/cache paths, and refreshed runtime artifacts before tests.
- Current router/agent law excludes functional Slipstream revival and Balancer-hosted DETF refactoring. These RC items do not authorize either.
- The current PRD expressly permits a thin RC-05 entry delegating to the installed guarded helper. Deletion is selected below for simplicity; it is not the only permissible reading of the requirement.

### 1.1 Invariants that must survive

| Rule | Required preservation |
| --- | --- |
| D12/D28 | A contract caller may consume declared resting unbooked credit. No donor attribution, exclusive claim, or mandatory atomicity is added. |
| D44 | Contract wallets and EIP-7702 delegated accounts pass the bytecode check; code-less and constructor-time callers do not. |
| D32 | Aave Cross-Version Loop and `BalancerV3PoolStandardExchangeTarget` retain hard public-pretransfer rejection. |
| D6 | Protocol residual is retained as book; only explicit fees go to `feeTo`. Stata liquidity-mining reward forwarding is unchanged. |
| D15 | Exact-in push credits exactly the requested input when available credit is sufficient; no exact-in refund. Pull delta must equal requested input. True-flag exact-out refunds only authorized `credit - used`; false-flag exact-out pulls quoted used and refunds nothing. |
| Historical source | Do not edit preserved `contracts/protocols/dexes/uniswap/{v3,v4}/` or select its bytecode for fresh replacement deployments. FullSpread remains the replacement, not an excluded tree. |
| Deployment | Real facets through CREATE3/FactoryService; registered vault DFPkgs through manager/registry. Hooks through the registered hook factory, mined flags, staged initialization, and finalization. |
| Test integrity | No SUT mocks, fabricated SUT storage, spoofed protocol authority, live RPC, or forks. Callback tokens and non-unit ERC-4626 dependencies are permitted fixtures; the adapter/SE/hook/manager/router under test stays real. |

No product-law question blocks this plan. Unknown callback/deficit reachability and fixture construction are engineering evidence tasks, not reasons to reopen settled economic decisions.

## 2. Selected implementation decisions

| RC | Selected approach | Acceptance form |
| --- | --- | --- |
| 01 | Crane operation-wide lock on both standalone Balancer money entries; finite route-budget approvals on all three authorization surfaces; retain success cleanup and revert propagation. | Production adapter callback regressions, in-flight allowance assertions, funded controls, state rollback. |
| 02 | Exact-asset `withdraw` for the protocol-vault shortfall in local-first payout. | Non-unit-rate exact-in/out recipient deltas, receipt charge, reserves, real orbital composition. |
| 03 | One inlined backing calculation in existing accounting library, consumed by adapter, generic SE, Stata SE, and Stata SY; preserve quote-state simulation. | Funded booked-aToken parity across IERC4626/SE/SY/transition surfaces and later deposit pricing. |
| 04 | Correct the specified comments and FullSpread README without economics changes. | Text/body inspection and existing money regressions. |
| 05 | Delete the complete unused HookTarget `exchangeOut` function, not the file or installed SeTarget entry. | Source absence, consumer closure, unchanged installed selector mapping and funded route. |
| 06 | Remove the unused internal share-count return. | Source inspection, compilation of all callers, real unwrap output/allowance/rollback assertions. |
| 07 | Preserve base bodies; make surplus helper virtual and add active-family forwarding overrides using `LocalCreditLib.available`. Protect Camelot payout against deficit-to-success regression. | Active D16 credit/refund tests, historical preservation, entrypoint guard matrix, permitted focused helper check if necessary. |
| 08 | Named LP-backing error carrying held and required amounts; unchanged comparison/order. | Reachable production failure, or documented focused check of the actual production comparison, plus funded success. |

These are plan-level engineering selections. Allowed alternatives are recorded below, but an implementer must not mix incompatible halves of different approaches.

## 3. Work breakdown and dependency graph

All work packages are **NOT STARTED**. Estimates are deliberately omitted: compile times and fixture reachability have not been measured for these edits.

| Work package | Scope | Dependencies / handoff |
| --- | --- | --- |
| WP-00 | Freeze baseline, map actual consumers, record runtime/deployment provenance, add red assertions. | Required before production edits; complete RC-07 census before its base declaration change. |
| WP-01 | RC-01 and its RC-04 Balancer comment. | Independent after WP-00. |
| WP-02 | RC-02 and ERC4626 portions of RC-04. | Establish rounding red before fixing the dependency; coordinate with WP-03 on ERC Common. |
| WP-03 | RC-03 canonical backing and SY coverage. | Shared accounting library first; serialize ERC Common and Stata Common edits. |
| WP-04 | RC-05 source removal and single-CP surface preservation. | Independent after consumer closure. |
| WP-05 | RC-06 void return and orbital integration. | Can edit independently; composed green depends on WP-02. |
| WP-06 | RC-07 scoped saturation, payout guard, historical protection. | Complete census; serialize Stata Common with WP-03 and Uni V2 files with WP-07. |
| WP-07 | RC-08 named check and evidence fallback if needed. | Independent of economics changes; shares Uni V2 regression suite with WP-06. |
| WP-08 | Remaining RC-04 README, integrated regression/campaign gates, reviewer closeout. | All earlier work complete; no concurrent writers to `out/` or `cache_forge/`. |

Suggested serial integration order: WP-00 → WP-01 → WP-02 → WP-03 → WP-04 → WP-05 → WP-06 → WP-07 → WP-08. Independent source work may be parallelized only in a separately authorized implementation task with disjoint ownership; shared-file and artifact writes remain serialized.

### 3.1 WP-00: baseline and evidence setup

1. Re-read current PRD, router, implementation rules, and relevant canonical skills at execution time. Protect unrelated working-tree changes; do not reset or silently replace them.
2. Record source revision/dirty-file identities, Crane dependency revision, selected compiler, installed Forge version, effective non-secret build settings, and artifact IDs. Do not copy environment dumps or credentials into evidence.
3. Record selector → facet → package-cut mappings for affected products, including finalized hooks. Record the actual source-qualified artifact loaded for each fresh test deployment.
4. Inventory base-helper consumers and all seven RC-06 callers. Expand searches to imports, indirect inheritance, tests, scripts, and deployment helpers; a single textual `is BaseName` search is not complete closure.
5. Create the regression cases below. Refresh pre-fix artifacts before recording red. Record the actual failing assertion and why it identifies the defect; do not call an unrelated setup failure a red proof.
6. Use a Markdown execution ledger under this plan directory, proposed `IMPLEMENTATION_EVIDENCE.md`, with one row per acceptance case. It is a future implementation deliverable, not a report of tests already run.

## 4. WP-01 / RC-01: standalone Balancer lock and bounded approvals

### 4.1 Observed source and touch set

Production file: `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol`.

- Declaration at line 22 inherits only `IStandardExchange`.
- `exchangeIn` at 69–107 and `exchangeOut` at 131–196 move tokens, approve, invoke routers, refund/pay, then synchronize reserves without an adapter lock.
- `_approvePermit2ToRouter` at 262–276 ignores the nonzero approval amount and grants maxima. It already clears three authorization amounts on successful paths.
- `_unbookedSurplus` at 218–222 already saturates on deficit. Do not describe this copy as an underflow bug.

Tests: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`; reuse its actual pool/adapter deployment patterns. Add a callback ERC20 fixture under the established test-fixture location only if no suitable fixture exists.

### 4.2 Implementation steps

1. Inherit `ReentrancyLockModifiers` from `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol`. Put `nonReentrant` on both external money entries, before their bodies. Keep the lock through approval reset, refund, payout, and reserve synchronization, including all early returns.
2. Preserve route validation, quote functions, native BPT issuance, deadlines, recipient resolution, funding, and refund formulas.
3. Set nonzero approvals to the existing route budget:
   - exact-in join: `actualAmountIn`;
   - exact-in exit: `actualBptIn`;
   - true-flag exact-out: `spendable = credit`;
   - false-flag exact-out: `spendable = quotedUsed`.
4. Bound/check the uint160 conversion before Permit2 approval; overflow must not truncate or fall back to unlimited approval. Reuse a suitable existing checked conversion/error, or define a descriptive local error and test its arguments.
5. Apply the finite amount to ERC20 allowance to the router, ERC20 allowance to Permit2, and Permit2 token/router allowance. Preserve the existing expiration convention unless implementation evidence requires otherwise; do not add an arbitrary deadline buffer.
6. Keep all three zero-reset calls on success before refund/payout. Failures propagate normally and roll back approvals and token movements. No catch-based cleanup.
7. Rewrite the stale M3 infinite-approval comment. Optionally replace the already-equivalent local saturation expression with `LocalCreditLib.available`; this is canonicalization only, not a new money behavior.

### 4.3 Regression matrix

Cover join and exit, exact-in and exact-out, supported funding flags, and same-entry/cross-entry nested attempts. Configure the callback token as a real pool token. If the existing gold pool cannot use it, deploy a parallel production pool through the same production path rather than mocking the router or adapter.

| Case | Required assertion |
| --- | --- |
| Funding, nonzero approval, router transfer, zero reset, refund, payout callbacks | At each reachable callback stage, a funded valid nested money entry encounters the adapter's exact `IReentrancyLock.IsLocked` error. Record actual attempt count. Document non-callable stages rather than claim executed coverage. |
| Swallowed nested failure | Fixture records the rejection and completes the outer token action; outer operation succeeds with correct deltas. |
| Propagated failure | Outer transaction reverts with intended error; caller/recipient balances, books, supply where relevant, and approvals equal their opening values. Probe storage also rolls back, so do not rely on a persisted counter from the reverted transaction. |
| In-flight approval | Observe finite allowance before consumption; equals route budget, not global maxima. |
| Successful ordinary-token control | Quoted funding/output, authorized exact-out refund, no exact-in or false-flag refund, all three allowances zero, affected reserves equal post-settlement balances. |
| Prior booked inventory | Seed book through a completed ordinary route; nested attempts cannot treat it as new credit. |
| Permit2 narrowing boundary | Supported bounded amount succeeds; overflow rejects without partial state/approval change. |

Existing allowance helper assertions at test lines 103–118 already check zero amounts after return. They are controls, not proof of in-flight bounds or reentrancy rejection. No demonstrated extraction or successful nested swap is required before the guard fix; a baseline nested call may fail elsewhere. The red oracle is the missing adapter-lock behavior on a reached valid attempt.

## 5. WP-02 / RC-02: exact local-first ERC-4626 payout

### 5.1 Observed source and touch set

`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80–92` redeems `previewWithdraw(shortfall)` shares directly to the recipient and accepts overdelivery. The exact-in caller at `ERC4626StandardExchangeInTarget.sol:144–151` returns the computed amount; the exact-out caller at `ERC4626StandardExchangeOutTarget.sol:108–115` owes the specified amount. Neither makes a rounded-share redemption exact in assets.

Modify Common; caller code changes should be unnecessary unless the compiler/source trace shows otherwise. Extend:

- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol`.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` or the corresponding `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_ERC4626StandardExchange.t.sol`, using the real capped-unwrap route.

### 5.2 Implementation steps

1. Keep `local = min(booked underlying, held underlying)`, `fromLocal = min(due, local)`, and `shortfall = due - fromLocal`.
2. For nonzero shortfall, call `vault.withdraw(shortfall, recipient, address(this))` instead of redeeming rounded shares directly to the recipient.
3. Pay exactly `fromLocal` from authorized booked cash. Do not consume resting unbooked credit.
4. Retain existing end-of-route synchronization, caller share accounting, fees, and protocol failure propagation. Do not add deposit retries, refunds, fee-recipient dust payments, or catch logic.

**Permitted but unselected alternative:** redeem the rounded shares to the SE, verify sufficient proceeds, forward exactly the shortfall, and retain/book the remainder at existing end-sync. It is a valid PRD alternative, not restricted to non-compliant vaults. Never redeem to the recipient and then attempt to recover the excess by depositing SE-owned cash; that does not recover what was overpaid. Re-depositing the remainder is unnecessary and adds capacity/rounding interactions.

### 5.3 Test preparation and assertions

1. Use existing `CappedPausableERC4626` / `SimpleYieldERC4626` dependency fixtures and real registry-deployed SE.
2. Fund receipt supply, create a non-unit exchange rate through the supported yield fixture, and use capacity controls to retain nonzero booked local cash.
3. Choose a due amount requiring both local cash and receipt withdrawal. Assert the precondition that redeeming `previewWithdraw(shortfall)` would deliver **more** than the shortfall; a non-unit rate alone is insufficient.
4. From equivalent prepared states test exact-in and exact-out exits, plus local-only and receipt-only controls.
5. Assert recipient underlying delta equals accounted due exactly; exact-in returned output equals this delta; SE-share burn and protocol-receipt charge are correct; ending reserves equal settled balances; no unauthorized refund or feeTo residual exists.
6. For the deterministic fixture, assert withdrawal receipt charge matches its preview, as required by the selected PRD acceptance route. General ERC-4626 guarantees only that the charge is no greater than the same-transaction preview; do not call equality a universal standard guarantee or remove the fixture-specific acceptance assertion.
7. Preserve maximum-withdraw/pause/short-delivery failure controls appropriate to the selected withdrawal path, with full rollback. A prior redeem-only hostile fixture is not automatically a withdrawal-failure test; configure the dependency behavior actually used.

### 5.4 Orbital integration

Use a finalized production hook, real PoolManager/router, required rate provider, and this real SE on a **non-identity buffered output leg**. Prove the call reaches `_unwrapExactTokenOut`, not a raw-leg or exact-in unwrap shortcut.

Assert exact user output and exact SE-to-hook delivery. With no outside transfers, the operation creates no face balance on that buffered leg. With pre-existing D12 resting face, track the opening amount separately and prove the unrelated pull-funded operation neither pays it out nor adds new face. Assert real share-balance delta, cap compliance, cleared SE allowance, and preserved short-output rollback. Do not add a hook-side book or raw transfer to PoolManager to hide a surplus.

## 6. WP-03 / RC-03: canonical Stata backing across all surfaces

### 6.1 Required production touch set

| Source | Observed reason / intended edit |
| --- | --- |
| `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:6–20` | Existing inlined receipt-plus-local calculation. Extend it with a shared storage-reading backing/expected-hold helper, not a linked deployment. |
| `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:173–198` | Preserve exclusive family dispatch and move canonical hold-set calculation into shared helper. |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:63–69` | Route generic backing through the shared calculation with generic mode, no aToken term. |
| `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:52–58` | Replace smaller Stata-only/local-underlying basis with the shared Stata backing calculation. |
| `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardYieldTarget.sol:26–34` | **Mandatory additional consumer:** independent `exchangeRate()` formula omits aToken and does not inherit Stata Common. Route it through the same backing calculation. |

Inspect, but edit only if required: Stata InTarget/OutTarget, generic SY, transition quote consumers, marker registration, and expected-hold initialization. `AaveV3StataStandardExchangeDFPkg.sol:245–258` already registers aToken when present; `BasicVaultCommon.sol:43–50` already syncs the full set. Do not add a second slot, a second ledger, or a direct unbooked-aToken term.

### 6.2 Calculation and integration rules

The existing shared adapter's semantics define the canonical basis:

```text
heldReceipts = receipt.balanceOf(proxy)
bookedCash = reserveOfToken(underlying)
bookedExtra = sum of booked expected-hold tokens excluding receipt and underlying,
              only for Stata family mode
backingReceiptUnits = heldReceipts + receipt.convertToShares(bookedCash + bookedExtra)
```

Keep combined conversion before rounding. Separately converting cash and aToken equivalents may lose different fractional amounts and reintroduce surface divergence. Generic mode contributes zero extra even if its receipt happens to be a Stata token. Absent aToken hold-set membership contributes zero; do not infer an extra term from an unsolicited live balance.

Preserve `UnsupportedAccountingFamily()` for both/neither marker cases on the shared adapter. No external self-call to another fee-bearing surface; no external Target inheritance merely to reuse internal logic. Keep the helper internal/inlined under D45.

`AaveV3StataStandardExchangeInTarget.sol:149–157` seeds quote state from `_stataBacking`; its transition math evolves that state. Fix the seed, but do not replace simulated transition-state calculations with fresh live-state reads at each step. Stata SY `exchangeRate()` needs its own call-site change. Preserve zero-supply behavior, native units, fee differences, receipt payout limits, and rewards forwarding at Stata Common 182–198.

### 6.3 Regression cases

Extend:

- `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`.
- `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol`.

Acquire aToken using the hermetic Aave setup; transfer it to the real Stata proxy and complete an ordinary funded operation that performs full-set sync. Assert nonzero **booked** aToken before comparing entitlements. Donation is test funding, not depositor attribution.

For one matched state, record and compare:

1. IERC4626 total assets, conversions, and previews in receipt units.
2. SE issuance/redemption previews and actual exchange deltas, including later depositor shares.
3. SY `exchangeRate`, plus deposit/redeem paths routed through the existing exchange.
4. `quoteState` and at least one subsequent `quoteTransition`, in the same native units and with explicit fee adjustments.
5. Ending books, supply, receipt inventory, and unchanged fee/reward destinations.

Use a fractional receipt rate to distinguish combined from separately rounded conversions. Test zero booked aToken, absent expected-hold extra, generic-over-Stata receipt mode, and mutually exclusive marker controls. Receipt/underlying/aToken-funded later deposits must not receive shares on a smaller denominator or double-count their own in-flight input.

The source inconsistency is confirmed; no actual funded-aToken execution was performed in this planning round. Do not seek deployed-instance evidence as a prerequisite.

## 7. WP-08 / RC-04: security-critical documentation corrections

Edit only the cited text, coordinated with the production changes sharing those files:

| File / baseline lines | Required correction |
| --- | --- |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17–20` | Residual stays booked, not sent to `feeTo`. |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:201–211` | Pull delta equals requested amount; no immediate overshoot refund. Push sufficiency is not equality of the entire surplus. |
| Same Common:277–281 | Burn precisely operation shares; no leftover self-share sweep/refund to owner. |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:126` | Remove obsolete overshoot-refund statement. |
| `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32–38` | Exact-in excess push does not revert merely for being excess; no exact-in refund; false-flag exact-out/dual exits pull quoted used, not max or a quote buffer. True-flag exact-out refund is bounded by credit minus used. |
| Balancer standalone adapter:262 | Finite operation approval and success reset, delivered with RC-01. |

Keep the D12 integration warning. Do not modify executable behavior to match old prose or edit historical Uniswap trees. Closure: reviewer line/body comparison, ERC4626 R14 suite, and a **current FullSpread exact-out** suite (not a Balancer test or legacy Uni V2 test). Discover the exact maintained FullSpread test path during WP-00 and record it in the ledger.

## 8. WP-04 / RC-05: remove unused single-CP money implementation

File: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736–768`.

1. Confirm import/inheritance/call closure across production, tests, and scripts. Existing research found no inheritor, but scoped search is not an eternal guarantee.
2. Delete the complete unused `exchangeOut` function, including its unsafe `maxAmountIn - amountIn` refund. Keep unrelated preview functions and the file itself.
3. Do not alter the installed `...HookSeTarget.exchangeOut`, its SeFacet selectors, or package cuts.
4. Compile affected sources and run `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol`.
5. Compare Target/interface → facet selectors → finalized cut → proxy callable surface before/after. Run funded installed exact-out and caller-credit controls; verify no second unguarded public exact-out remains in this family source.

If consumer closure invalidates the unused premise, use the PRD-permitted thin delegation to the **installed single-CP guarded helper**, preserving its caller/credit/refund checks. Do not substitute ERC4626 helpers from another family. Record the reason for that permitted implementation variation; it does not require a new economic decision.

Grok additionally noted the unused HookTarget `exchangeIn` as an adjacent concern. This is not opened as a ninth requirement by this plan. Do not expand the deletion or change installed exact-in behavior without separate scope review.

## 9. WP-05 / RC-06: remove unused orbital share-count return

File: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550–565`.

1. Make `_unwrapExactTokenOut(address,uint256)` return nothing.
2. Convert zero-amount and identity early returns to bare returns.
3. Replace the named-return temporary with a local variable for the inverted quote used to compute `maxIn`.
4. Delete `seIn = maxIn`. Preserve the capped exact-output SE call, approve-to-cap/reset sequence, and `InsufficientTokenOut` short-delivery check.
5. Verify all seven current statement callers: Common 586/604/1899, `...HookSeTarget.sol` 125/185/250, and `...HookWithdrawTarget.sol` 177. Compile their concrete facet consumers; statement callers may require no textual edits.
6. Run the real orbital unwrap tests from WP-02, plus zero/identity/insufficient-cap and short-delivery controls. Assert quoted token output, actual share delta bounded by cap, zero ending allowance, and full rollback on failure.

Do not change weighted or quad hooks' different-signature helpers. Do not add a public selector just to observe a dead internal return. The allowed truthful-return alternative remains available if a genuine production-compatible observation path exists; merely checking an external SE return cannot detect the old internal cap assignment. Removing the return closes the honesty requirement with source inspection and unchanged production behavior tests; no claim of an existing user-visible loss is made.

## 10. WP-06 / RC-07: scoped deficit handling and historical preservation

### 10.1 Baseline census

`contracts/vaults/basic/BasicVaultCommon.sol:33–36` and its base pretransfer branch at 77–103 use checked subtraction. `_refundExcess` at 120–135 calls the surplus helper. The active families already override secure transfer with caller checks and saturating availability.

| Consumer | Baseline locations | Plan treatment |
| --- | --- | --- |
| Uni V2 Common | Secure pull 420–447; refund 476 | D16 saturation override; retain guarded pull. |
| Camelot V2 Common / OutTarget | Secure pull 158–185; refund 214; direct payout OutTarget 430 | D16 saturation override plus deficit payout rejection. |
| Aerodrome V1 Common / OutExecuteTarget | Secure pull 946–973; refund 1002; OutExecute refund calls 168/267/335/371/473/497/552 | D16 saturation override; verify every inherited refund dispatch. |
| Stata Common | Secure pull 200–227 | D16 saturation override for shared-helper reachability; retain caller behavior. |
| BasicVault hermetic tests | `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol`, `BasicVaultCommon_TrustFlags.t.sol`, `BasicVaultCommon_Permit2.t.sol` | Historical base behavior preserved; do not rewrite expectations to legitimize global semantic changes. |
| BasicVault fork harnesses | `test/foundry/fork/base_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_BaseFork.t.sol`; corresponding `eth_main/.../BasicVaultCommon_TokenTransfer_Permit2_EthFork.t.sol` | Preserve source/semantics; do not execute forks. |
| Same-name unrelated helpers | Standalone Balancer, ERC4626 Common, FullSpread V4, preserved Uni V4 | Not consumers of this base helper; no mechanical replacement. |

This is a starting census, not a claim that every D16 public entry has been body-audited. WP-00 must finish indirect inheritance/import closure and map each public entry to guarded/rejected/not-reaching-base behavior.

### 10.2 Selected change

1. Make base `_unbookedSurplus` virtual; leave its checked-subtraction body and base `_secureTokenTransfer` body unchanged. Explain the legacy/default versus active override distinction in local NatSpec.
2. Add thin `_unbookedSurplus` overrides in the active Common classes. Each forwards `balanceOf(this)` and the existing booked reserve to `LocalCreditLib.available`. Do not duplicate the arithmetic formula.
3. Verify inherited `_refundExcess` resolves to the active override on actual concrete deployments. Rebuild every affected concrete artifact; changing an abstract/common base alone is insufficient evidence.
4. Keep all active guarded pull overrides and named insufficient-credit errors. No new bytecode check on the historical base branch is required if the public-entry matrix proves D16 cannot reach it unguarded.
5. Preserve end-sync ordering and refund credit limits. Saturation never authorizes spending the whole held balance.

**Camelot payout companion:** `CamelotV2StandardExchangeOutTarget.sol:411–437` uses `_unbookedSurplus(tokenOut)` as a payout amount, not merely an optional refund. A deficit must not become a successful zero payout. At this boundary, reject `balance < booked` when a positive output is requested using the existing family error, proposed `AmountOutNotMet(amountOut, 0)`. Keep the existing non-deficit measured-surplus payout sizing and operation rollback. Do not broaden this remediation into changing all positive-but-short payout behavior or whole-surplus economics.

For a refund with an already-established positive liability, trace the family's existing requirement that full authorized refund remains available (APEX D35). A deficit authorizes zero credit, never a write-off of a mandatory liability. Retain/add the active caller's existing insufficient-credit rejection where needed, with used/credit/liability quantities correctly identified. This does not change the historical base refund or invent a deficit recovery mechanism.

### 10.3 Tests and closure

Extend existing Uni V2/Camelot security-remediation and Aerodrome secure-pull/E6 suites; retain Stata guarded-entry controls where it reaches the base family. Record exact files and test names during WP-00 rather than silently omitting a family.

- Below/equal/above-book controls; deficit availability is zero on active paths.
- Positive credit request with zero availability rejects the family's exact insufficient-credit error, never arithmetic panic.
- No booked token payout, no attacker share gain, no successful Camelot zero-output swap on deficit, and atomic rollback of input/swap effects.
- EOA true-flag rejection for **each named public D16 entry** in the reachability matrix; funded contract/pull controls beside negatives. Preserve constructor, wallet/delegation, and D32 semantics.
- True-flag exact-out bounded refunds, false-flag quoted-used/no-refund controls, exact-in sufficient-surplus/no-refund controls.
- Historical hermetic base tests retain their original expectations. Fork consumers remain read-only preservation entries, not execution gates.

First attempt a supported production route to create deficit without rebasing/FoT support, SUT mocks, arbitrary burns of production balances, or storage writes. If unavailable, document attempted states and use the PRD-authorized direct test of the **actual active production helper**. A narrow production calculation extraction/thin test exposure may be used; do not copy the arithmetic into a fake vault and call it production evidence. Keep real public-entry guard/refund controls alongside the focused check. Do not manufacture a state to claim an end-to-end exploit.

### 10.4 Why not a global base edit?

MiniMax and Kimi prefer global saturation and updating historical harness expectations. Astra and Grok's cross-reviews favor isolation. The moderator selects isolation because current PRD line 168 requires historical semantics not to change outside D16, and the historical BasicVault PRD line 47 explicitly specified checked subtraction. Five distinct historical test consumers were directly located. Thin overrides reuse one arithmetic implementation; they do not create competing backing formulas.

This is unresolved engineering dissent recorded transparently, not an unresolved owner requirement. A future broader base migration would need separate scope/authority, not just a new passing expectation.

## 11. WP-07 / RC-08: named LP-backing error

File: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:575–581`.

1. Define a descriptive family error, proposed `InsufficientLPBacking(uint256 held, uint256 required)`, at the appropriate existing error surface or target.
2. Measure held pool tokens once and preserve the exact `held < vaultLpReserve` comparison. On failure, report both values in that order.
3. Keep refund ordering, reserve sync, and successful-route behavior. Do not touch the other empty reverts elsewhere in this file.
4. Use the repository's established NatSpec signature/selector verification process; do not invent hex selectors.

Extend `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol`.

**Preferred evidence:** a supported production zap-out reaches the check, baseline fails the named-error assertion, corrected source returns the expected selector/values; transaction state is unchanged and a funded positive twin still completes.

**Authorized fallback:** if supported routes cannot reach the deficit without forbidden setup, record the attempted preconditions. Extract the identical comparison into a small internal pure production check called from the original site. A thin test exposure calls that real check with held below/equal/above required. Assert exact error arguments and boundary success, while the real zap-out success control proves continued routing. Preserve a baseline source/error characterization and do not pretend the focused test demonstrates a reachable exploit. This closes the PRD evidence requirement without waiting for a later owner authorization or end-to-end trigger.

## 12. Build, test, and release evidence workflow

### 12.1 Observed configuration versus unknown runtime

Directly read `foundry.toml:7–45`: solc `0.8.35`, optimizer enabled/runs `1`, `via_ir=false`, default `test/foundry/spec`, `out/`, `cache_forge/`, default fuzz runs `16`, invariant runs `16`, depth `8`. Installed Forge/solc binaries, effective EVM target, environment overrides, git/submodule identities, and artifact freshness were **not executed/observed**. Older Forge 1.5.1/Prague statements are contextual claims, not current-runtime attestations.

Before the future first compile in a new/empty worktree, seed both configured artifact/cache directories from a warm checkout under current router rules. Keep paths/configuration stable. Do not delete artifacts or introduce a package-specific profile. Cold compilation may take 20–40+ minutes; use the router's hours-scale timeout and wait for process exit rather than killing it for silence.

### 12.2 Artifact-safe execution template — NOT RUN

Repository workflow source: `docs/testing/ARTIFACT_BUILDS.md:3–24,41–55`; `CLAUDE.md:59–61`.

```bash
# Future authorized implementation only; example RC-02 run.
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol
```

Supply **every** edited production source and repeat `--test-root` for the selected affected suites. The helper refreshes concrete/runtime artifacts with a build before running tests. Inspect selected roots when shared libraries/common bases change. If an artifact identifier is dynamic or a source is removed, explicitly supply affected concrete consumers; do not assume the graph discovers missing references. RC-05 source absence does not excuse compiling its remaining file/consumers.

Run targeted regressions first, then complete affected hermetic family/surface suites, then integrated controls. Avoid broad catalog-prefix matchers that accidentally select unrelated tests. Serialize build/test jobs sharing artifact directories.

The upstream APEX D4/D24 release campaign remains applicable where not superseded: 10,000 fuzz cases per targeted property and 256 stateful runs at depth 64, with recorded success/branch counters. Apply approved per-run overrides (`FOUNDRY_FUZZ_RUNS`, `FOUNDRY_INVARIANT_RUNS`, `FOUNDRY_INVARIANT_DEPTH`), not config edits; verify effective counts and test-local overrides at execution time. Default 16-run settings are not those campaign results.

Target properties: credit never includes booked balance; refund never exceeds authorized unused credit; callback attempts cannot complete a nested money operation; successful payout equals accounted assets; all Stata surfaces share one backing denominator; success clears allowances; reverting operations preserve opening state. A handler that only reverts is not invariant evidence—record successful join/exit/issue/redeem counts and reached branches.

### 12.3 Final integrated gates

1. Exact same regression assertions red then green, or individually documented PRD evidence exception.
2. Real deployment/source artifact identities recorded; no stale `out/` deployment, missing bytecode, or unresolved linking.
3. Changed concrete facets/delegates/packages within the 24,576-byte runtime limit. If exceeded, follow APEX D19's minimal Ext split with explicit new surface evidence; do not enable IR, change compiler knobs, drop behavior, or silently enlarge scope.
4. Target/API → declaration → package cut → finalized production proxy surface verified. RC-05 and RC-06 require no new public selectors.
5. Relevant cross-interface accounting, fee, pretransfer, wallet, supply, reserve, and allowance controls remain green.
6. FullSpread replacement selection and preserved historical source verified. Fresh source does not upgrade occupied CREATE3 identities or immutable live instances; no operational deployment is authorized here.
7. No forbidden economics changes, catch cleanup, SUT mocks, storage fabrication, or loosened amount tolerances.
8. Reviewer signs each RC acceptance row and the evidence limits; unrelated baseline failures are recorded, not hidden or automatically assigned to this remediation.

### 12.4 Required execution ledger fields

| Field | Contents |
| --- | --- |
| Requirement/case | RC ID, exact PRD clause, named test or permitted source/focused-check exception. |
| Source identity | Pre/post revision or dirty-file identities, dependency revision, source-qualified runtime artifact. |
| Configuration | Actual tool versions, effective compiler/EVM/optimizer/profile/campaign settings; no secrets. |
| Red | Actual failing assertion/error and reached branch, or reason the permitted exception applies. |
| Green | Same assertion, exact output/error arguments, complete command/exit status, test and campaign counts. |
| Accounting | Before/after balances, book, supply/share burns, fees, allowances, positive twin. |
| Coverage limits | Callback stages not executable, attempted deficit setup, helper-versus-route distinction. |
| Review | Touch-set/surface preservation, reviewer, remaining limitations, acceptance state. |

## 13. Council record, corrections, and dissent

Eight task calls completed this round: four independent first passes followed by one combined original-only cross-review per original session. No earlier cross-review was supplied to another researcher. Task metadata reports the configured models; it is not provider-truth verification.

| Researcher | Reported model | Current session | Original / cross-review |
| --- | --- | --- | --- |
| Astra | `openai/gpt-6-astra` | `ses_f21987c0dffeYha4SnFyReKXN7` | [Original](astra-original.md) / [Cross](round-2026-09-26-astra-cross.md) |
| Grok | `xai/grok-4.7` | `ses_f2191dfbaffe9UAWC70B78YHIo` | [Preserved current original](round-2026-09-26-grok-original.md) / [Cross](round-2026-09-26-grok-cross.md) |
| MiniMax M3 | `minimax/MiniMax-M3` | `ses_f21876c95ffewRUeqEI4w575Oy` | [Original](round-2026-09-26-minimax-original.md) / [Cross](round-2026-09-26-minimax-cross.md) |
| Kimi K3 | `kimi-code-plan-global/k3` | `ses_f2184971cffei3K6PnEmguqEl3` | [Original](round-2026-09-26-kimi-original.md) / [Cross](round-2026-09-26-kimi-cross.md) |

Provenance caveats: the directory also contains an older `COUNCIL_STATUS.md` and an older `grok-original.md`; they are not this round's findings. Grok reported encountering only the older original's header while avoiding an overwrite; its current substantive answer was separately preserved verbatim by the moderator. MiniMax copied a historical PRD session ID into its original; the table above uses live returned metadata, and its cross-review records the correction without rewriting the original. These are attribution/independence limitations, not grounds to silently merge old and new sessions or claim pristine artifact isolation.

### 13.1 Initial positions and cross-review movement

| Topic | Initial positions | Cross-review / moderator disposition |
| --- | --- | --- |
| RC-01 | All preferred Crane lock and bounded approvals; MiniMax also offered lock-only. | Lock-only rejected as contrary to PRD. No extraction prerequisite. Existing tests already assert zero allowance after return. |
| RC-02 | All preferred exact-asset withdrawal. Some overstated preview equality or suggested redepositing recipient overpayment. | Exact asset payout selected. Preview upper-bound clarified; deterministic fixture equality retained. Safe alternative receives redemption into SE, not recipient. |
| RC-03 | All preferred shared backing; initial focus was adapter/Common. | Astra/Grok cross-review identified independent Stata SY omission. Moderator directly confirmed `AaveV3StataStandardYieldTarget.sol:26–34`; SY is mandatory, not a later optional grep gate. |
| RC-05 | All preferred deleting unused exact-out. | Complete function removal selected. MiniMax's deletion-only interpretation rejected: the PRD still allows guarded delegation. |
| RC-06 | Astra preferred removal; other originals preferred truthful return. | All four cross-reviews recommend removal by default, principally because seven callers ignore an internal return. Original functional-impact dissent remains recorded. |
| RC-07 | Astra preferred active-family isolation; others preferred broader base edits. | Grok moved to isolation. MiniMax/Kimi retain global-edit preference. Moderator chooses preservation-conforming isolation and narrow Camelot deficit guard. |
| RC-08 | All agreed on named error and authorized fallback. | Actual production comparison exposure selected if supported route is unreachable; no string-error substitute or new owner gate. |

MiniMax's cross-review still contains proposals not adopted here: redefining allowed RC-02 alternatives, removing fixture preview matching, global base edits, and narrowing RC-05 to deletion only. Kimi's search for `_stataBacking` did not find SY's independent formula; direct reading overrides that negative search inference. No majority vote can waive a PRD requirement.

### 13.2 Residual dissent and confidence

- **RC-07 engineering dissent:** global helper edit versus scoped overrides remains. The latter is selected, with the historical-preservation rationale above.
- **Severity/impact history:** PRD uses Medium for RC-01 and Low for RC-07/RC-06. Historical Astra High on potential RC-01 impact, Kimi Medium on RC-07 specification nonconformance, and MiniMax's RC-06 functional-impact objection do not alter required scope.
- **High confidence:** current PRD requirements; directly inspected lock/approval gap, ERC4626 payout mechanism, Stata SY omission, BasicVault subtraction, Camelot payout call, and orbital unused return.
- **Medium confidence:** final consumer closure and fixture construction; requires implementation-time verification.
- **Unverified:** red/green results, lasting extraction, callback-stage execution, naturally reachable deficit routes, nonzero aToken funded setup, runtime sizes, installed executable versions, effective EVM target, artifact provenance, and earlier claimed test totals.

No council member executed Foundry for this round. Consensus and future passing tests alone are not proof of security or economic soundness.

## 14. Evidence sources and access notes

All source reads and external accesses cited here are dated **2026-09-26**. Baseline line numbers may drift after implementation; update the execution ledger with final anchors.

- Current remediation PRD: RC-01–08 at 71–186; owner scope at 55–67; suite/acceptance matrix at 224–244; closed clarifications at 246–254.
- `CLAUDE.md:26–61,93–97`: deployment, profile, compilation, cache, and artifact rules.
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:294–302,323–364`: constraints, D4/D24 campaigns, D15/D35 refunds, D19 sizes, D25 orbital exact output, D45 shared accounting. Older live-instance/fork requirements are superseded here.
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:29–47`: historical helper semantics; superseded only for active D16 paths by current RC-07.
- Orbital and single-CP family PRDs under their production package directories, particularly orbital 7/100 and single-CP 90 for current staged deployment. Older optional-rate-provider and monomorph examples are not authority to bypass current initialization law.
- `docs/agent/INDEXEDEX_AGENT_LAW.md:89–105`: token policy and excluded/deprecated families.
- Canonical `lib/crane/.claude/skills/{crane-deployment,crane-architecture,crane-testing,crane-adversarial-testing}/SKILL.md`; local `.claude/skills/{indexedex-testing,indexedex-adversarial-testing,indexedex-uniswap-v4-hook-packages}/SKILL.md`. Current router overrides stale skill profile examples.
- Context7 selected `/websites/openzeppelin_contracts_5_x` for exact assets versus shares: [OpenZeppelin Contracts 5.x ERC20 API](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20), [interfaces](https://docs.openzeppelin.com/contracts/5.x/api/interfaces). Documentation version is not an installed dependency claim.
- Primary standard directly fetched: [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626), `previewWithdraw`, `withdraw`, `redeem`. This confirms preview upper bound and exact assets versus exact shares, not safety of arbitrary interface-conforming vault code.
- Context7 `/foundry-rs/book`: [invariant testing](https://github.com/foundry-rs/book/blob/master/src/pages/guides/invariant-testing.mdx), [inline test configuration](https://github.com/foundry-rs/book/blob/master/src/pages/config/reference/inline-test-config.mdx). Exact local build commands and campaign overrides are grounded in current repo workflow/APEX D24, not assumed runtime support.
- `docs/testing/ARTIFACT_BUILDS.md:3–55,68`: artifact refresh, concrete consumers, stable paths, and occupied CREATE3 identity caveat. Its historical measurement/test totals are not fresh validation of this plan.

Read/search limitations: Astra recorded a missing `lib/crane/contracts/access/reentrancy/ReentrancyLock.sol`; the actual `ReentrancyLockModifiers.sol` was located separately. A moderator repository-wide glob encountered broken Crane mirror/vendor paths; scoped direct reads and targeted searches were used instead. No inaccessible secret was searched by another mechanism. Long D16 inventory rows are truncated by the read tool; this plan does not claim exhaustive D16 body review from that row. Audit PDF claims were not independently re-audited by the moderator.

## 15. Human checkpoint and separate implementation handoff

**Decision checkpoint:** review this selected plan, particularly RC-07 isolation and RC-06 return removal. No new economic ruling is requested. Writing this plan does not authorize code changes or tests.

A later explicit implementation request should name this plan and the current source PRD, authorize the code/test work separately, and require:

1. WP-00 baseline/provenance and complete consumer mapping.
2. RC-01–08 touch sets and selected approaches, with documented PRD-permitted variations only.
3. Same-assertion red/green evidence or the named exception, positive controls, refreshed concrete artifacts, and relevant campaign/surface/size gates.
4. A completed auditor-facing `IMPLEMENTATION_EVIDENCE.md` and per-RC acceptance review.
5. No deployments, migrations, chain inventory, commits, resets, config changes, or unrelated remediation inferred from this plan.

**Stop here.** No production code, tests, deployment configuration, or instructions were changed by the moderator; no shell, tests, chain actions, or deployments were executed.
