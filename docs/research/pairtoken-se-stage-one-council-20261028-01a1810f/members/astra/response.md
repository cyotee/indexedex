# Identity

- Member: Astra, independent initial requirements-assessment pass.
- Assigned route: `chatgpt-subscription/gpt-6-astra:high`, as supplied by the assignment. This signature is not independent runtime attestation of the route.
- Run: `pairtoken-se-stage-one-council-20261028-01a1810f`.
- Date: 2026-10-28.
- This is an independent recommendation, not the coordinator's synthesis or an advisory review.

# Question and targets

**Question:** What material requirements need owner clarification, and what concrete improvements would make the stage-one PRD coherent, implementable, testable, and faithful to the confirmed owner choices?

**Conclusion:** The PRD is a useful scope and interface specification, but it is not yet a decision-complete implementation contract. The principal blockers are the explicitly unresolved zap-attribution economics, the compatibility of a bounded full-operation projector with exit availability, and a concrete mixed-decimal SY rate-unit mismatch. The read-guard wording also needs reconciliation with the required unchanged reusable facets. These can be addressed without reopening the settled decisions about one full-range position, native ETH, mandatory swap-based compounding, removal of dead shares/retention/protocol-fee routing, unsupported exact output, or canonical facet reuse.

Required target, read in full:

`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`

The examined version contains S1-ARCH-04/05 and all acceptance rows S1-A01 through S1-A57. Below, bare S1 identifiers refer to that file.

Required behavioral context, all read in full:

- `contracts/pairtoken-baseline/PairToken.sol`
- `contracts/pairtoken-baseline/PairTokenMath.sol`
- `contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol`

# Evidence and coverage

## Evidence classes and authority

The eight confirmed choices in the common brief are **supplied owner-decision evidence**. I have not independently reconstructed the owner's earlier conversation. The PRD's normative wording is **source observation**, not evidence that the owner approved every proposed detail. In particular, X08-X14, the 512-step proposal, the exact zap issuance policy, the spot SY valuation policy, the donation ledger, and configuration restrictions remain proposed requirements.

The analysis below uses **source observations** from the local files and explicitly identified **inferences** about their implications. It contains no runtime proof. No peer responses, earlier councils, private memory, external reconstructions, or implementation plans were consulted. No public queries were needed or issued.

## Additional admitted source context actually examined

Paths and symbols are source locators, not claims of an immutable repository snapshot.

| Context | Sources and examined locators |
| --- | --- |
| Repository and council rules | `CLAUDE.md`; relevant Crane instructions and canonical `crane-architecture` skill; `docs/agent/INDEXEDEX_AGENT_LAW.md` token-policy and native-SY sections; the common brief and Native council procedures. Broader agent-law and Crane documents were not exhaustively assessed as product evidence. |
| Canonical scalar and multi-asset interfaces | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and `IStandardExchangeOut.sol`; `contracts/interfaces/IStandardExchange.sol`, `IStandardExchangeInMulti.sol`, `IStandardExchangeOutMulti.sol`, and `IStandardExchangeMultiAssetLiquidity.sol`. |
| Basic and standard vault reuse | `contracts/vaults/basic/{IBasicVault,MultiAssetBasicVaultFacet,MultiAssetBasicVaultTarget,MultiAssetBasicVaultRepo}.sol`; the forwarding `contracts/interfaces/IBasicVault.sol`; `contracts/vaults/standard/{MultiAssetStandardVaultFacet,MultiAssetStandardVaultTarget,StandardVaultRepo}.sol`. |
| Share facets | `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol::facetInterfaces/facetFuncs`; `tokens/ERC2612/ERC2612Facet.sol::facetInterfaces/facetFuncs`; `utils/cryptography/ERC5267/ERC5267Facet.sol::facetInterfaces/facetFuncs`, under the same Crane contracts root. Underlying token/permit Repo internals were not independently audited. |
| SY execution, discovery, and units | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`, `NativeStandardYieldDiscoveryTarget.sol`, `NativeStandardYieldPreviewTarget.sol`, and `ConstantProductStandardYieldTarget.sol`; `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`; `lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol`. |
| Credit accounting | `contracts/utils/LocalCreditLib.sol::available/requirePretransferCaller`. |
| Deployment and native proxy context | `contracts/interfaces/IVaultRegistryDeployment.sol`; the complete current `UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol` at the PRD's section 2 path; `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` constructor/deploy/interface declarations; `lib/crane/contracts/proxies/{MinimalDiamondCallBackProxy,MinimalDiamondCallBackProxyResolution,Proxy}.sol`; canonical `IWETH.sol` alias. Registry implementation and wrapper implementation were not audited. |
| Actual V4 behavior | `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol::unlock/modifyLiquidity/swap/sync/take/settle/_settle`; `libraries/Pool.sol::modifyLiquidity/swap`; complete `libraries/Position.sol` and `libraries/StateLibrary.sol`. This was relevant-function examination, not a complete PoolManager audit. |
| Test feasibility | Complete `test/foundry/spec/pairtoken-baseline/harness/{PairTokenTestBase,ScriptedDependencies}.sol`; complete Wings TestBase at the PRD's section 2 path. These were read, not executed. |

An initial guessed location for `SYUtils.sol` was absent. A local search located the canonical file listed above, which was then read. There is no outstanding access gap for the required target or baseline sources.

## Whole-document coverage

| PRD area | Assessment |
| --- | --- |
| Sections 1-4; A01-A07, A47-A48, A56-A57 | Scope separation and five-facet composition are sound directions. Package/factory separation is materially better than treating the package cut as the whole diamond. Read-guard compatibility and final declaration controls need tightening. |
| Section 5; A08-A12, A16-A17, A20, A34-A38, A41 | Paired issuance and removal equations are substantially specified. Complete fee checkpoints, credit-ledger invariants, and zero-output/zero-supply behavior need additional precision. |
| Section 6; A13-A24, A49-A55 | Native face mapping is coherent; zap attribution remains expressly unresolved. Mandatory compounding makes paired exits conditional on maintenance success. Boundary math must cover compound sizing as well as `basket()`. |
| Section 7; A25-A26, A29-A31, A35-A37 | Narrow paired methods are justified by the existing multi-asset ABI semantics. Exact-output rejection, shared shares, empty rewards, and contract-only pretransfers are coherent. Final family ABI and caller-independent preview semantics need explicit controls. |
| Section 8; A27-A28, A32-A33 | Exact projection is a substantial new state-transition model, not a small baseline adaptation. The proposed SY rate formula conflicts with raw-unit conversion helpers when decimals differ. |
| Sections 9-11; A39-A48 and native rollback rows | Security and production-first intent are good. Several obligations need measurable outcomes rather than a future judgment of whether results are acceptable. |
| Section 12 | Later-stage wrappers, Wings economics, rate-provider deployment, and new oracle defenses should remain excluded. None is needed to make the recommendations below. |

# Recommendations

## R1. Correct SY rate units before approval

**Priority:** Implementation blocker.  
**PRD:** S1-QUOTE-02; S1-API-03; S1-A32/A33.  
**Evidence:** Source observation plus arithmetic inference; high confidence.

`IStandardizedYield.exchangeRate()` describes multiplying a share balance by the rate and dividing by `1e18` to obtain the asset balance. The actual `SYUtils.syToAsset` and `assetToSy` helpers perform that multiplication/division without reading decimals. The existing `ConstantProductStandardYieldDiscoveryTarget.exchangeRate()` returns `convertToAssets(1e18)`, in asset native units.

The PRD instead returns whole-asset/whole-share value normalized to WAD:

`Vraw * 1e36 / (S * 10^d)`.

For `S = 1e18`, `Vraw = 1e6`, and a six-decimal rate asset, this returns `1e18`. Passing one whole share to `SYUtils.syToAsset` then returns `1e18` raw asset units, rather than `1e6`: a factor of `1e12`.

**Proposed replacement:**

> With public supply measured in raw 18-decimal share units and accounting value measured in raw rate-asset units, `exchangeRate = floor(Vraw * 1e18 / S)`. `assetInfo.assetDecimals` describes the returned asset's units; callers must not apply a second normalization inside canonical SY conversion helpers. At zero supply return zero. A separately named human-normalized reporting value, if ever needed, is not `exchangeRate()`.

Retain the distinction between accounting value and an executable withdrawal-and-sale quote. Add independent vectors using canonical SY conversion helpers for 6-, 8-, and 18-decimal assets, not only a test reproducing the PRD formula.

**Disposition/trade-off:** Technical correction if canonical SY interoperability is intended. A deliberately different unit convention would require an explicit owner-approved incompatibility and adapter scope; I do not recommend it. Correcting units does not approve the draft spot-valuation policy itself.

## R2. Resolve zap attribution before coding, not after an undefined test verdict

**Priority:** Economic implementation blocker.  
**PRD:** S1-OP-02; S1-X08/X09; S1-A13/A15/A46; section 11(4).  
**Evidence:** Source observation and inference; high confidence in the unresolved requirement, not a claim of a demonstrated runtime loss.

`PairToken.zapDeposit` snapshots the old basket, calls `_requestDeploy`, and mints from `result.used0/used1`. `_deploy` sizes additions from all `_idle` balances; `_add` reports gross principal deployed, separating fee credits from net settlement. Neither result records which deposited units belonged to the entering caller. The PRD knowingly preserves that behavior while warning that incumbent idle inventory can enter the issuance numerator.

Mandatory pre-entry compounding reduces some idle balances; it does not itself prove that all residual inventory is gone. Partial swaps, integer rounding, and imbalanced inventory are expressly admitted by the PRD. A15's phrase "unacceptable transfer" has no definition or approved tolerance. It leaves an economic decision to the implementation team.

**Proposed requirement:**

> Before implementation approval, define an operation attribution ledger and exact issuance equation. Moving already-owned inventory from idle custody into the position must not, by itself, create entrant shares. Specify the ownership of input residuals, swap proceeds, fees earned by the existing position during the entry swap, and reinvested incumbent idle inventory. State the valuation/snapshot convention used to compare incumbent claims before and after entry, separately from execution price movement and pool fees.

My recommended direction is to separate caller-funded deployed amounts from incumbent reinvestment, rather than treating gross deployment as new contribution. This is a **candidate economic change**, not a claim that subtracting one balance from `used_i` solves every fee and price-movement case. If the owner chooses it, the PRD must contain the complete equation before implementation; it must not delegate that equation to code.

The alternative is explicit baseline characterization with acknowledged attribution limitations, but that cannot simultaneously satisfy section 11's no-unresolved-accounting gate as a deployable product.

**Disposition/trade-off:** Owner choice. Correcting attribution sacrifices exact baseline zap parity and requires new arithmetic controls; retaining it preserves historical behavior but leaves the principal product risk unresolved. Do not replace this issue with a TWAP/oracle discussion or re-ask whether mandatory compounding is wanted.

## R3. Specify the bounded projector and qualify the paired-exit availability claim

**Priority:** Implementation and liveness blocker.  
**PRD:** S1-QUOTE-01; S1-P01; S1-ACC-05; S1-OP-03/05; S1-A19/A21/A27/A28/A40/A42.  
**Evidence:** Source observation and inference; high confidence in the coupling, unverified worst-case gas feasibility.

The proposal is not merely to quote a swap. It must project collection, compounding, additions, entry/removal, and another swap against the resulting pool. `Pool.swap` traverses bitmap words, initialized ticks, liquidity changes, directional protocol fees, and fee growth. `Pool.modifyLiquidity` changes tick state and capacity. Later simulated swaps cannot simply reread untouched live state after a simulated addition/removal.

The 512-step proposal also affects paired redemption: mandatory pre-exit compound can swap even though the redemption itself does not. Therefore "paired exit remains the fallback" does not mean an always-available swap-free exit. Budget exhaustion or another compound failure can reject it. This is not proof of permanent lockup; a separate compound or changed pool state may help. Neither recovery is guaranteed by the current text.

**Proposed requirements:**

1. Define a projection step as one canonical swap-loop iteration, including uninitialized bitmap-word traversal. Count the aggregate across all swaps in the projected operation.
2. Specify projected changes to liquidity, initialized boundaries/bitmap, fee growth, position checkpoints, balances, and signed deltas. Include the live directional PoolManager protocol fee as well as the LP fee; removing the vault's fee routing does not remove pool-level fees.
3. State whether standalone `compound()` has the same budget, its own bound, or no projector restriction. An undocumented escape through standalone maintenance is not an exit guarantee.
4. Replace unconditional fallback language with: "Paired redemption avoids the post-removal sale, but remains subject to the mandatory compound's executable domain."
5. Treat 512 as provisional until a gas/work feasibility assessment supports a precisely named domain. Test exactly-at-budget and over-budget cases involving both swaps and empty bitmap words.

**Disposition/trade-off:** Owner approval is needed for the restricted execution/liveness domain; definitions and state-transition detail are technical corrections. I recommend retaining confirmed mandatory compounding, refusing an unsupported unconditional exit promise, and validating the budget before fixing its value. A larger cap broadens availability but increases execution cost; any stronger exit guarantee needs separately approved design work, not a silent compound bypass.

## R4. Reconcile fail-closed reads with mandatory unchanged facets

**Priority:** Architectural contradiction to resolve before implementation.  
**PRD:** S1-ARCH-04/05; S1-SEC-01; S1-A07/A39/A41/A56/A57.  
**Evidence:** Source observation and inference; high confidence.

`MultiAssetBasicVaultTarget.reserveOfToken/reserves` directly read the shared Repo and contain no family guard. Its metadata views and the canonical token facet remain callable independently of the family's operation engine. `Proxy.fallback` resolves and delegatecalls a facet; it does not apply a family-wide read guard.

Consequently, a requirement that every potentially inconsistent economic read must revert cannot be implemented merely by adding a guard to new family targets while retaining these facets unchanged. Changing or recutting them would violate a confirmed owner choice.

**Proposed wording:**

> Family basket, accounting-rate, position-dependent economic queries, and previews reject during an active family money operation. The unchanged basic-vault reserve selectors return the last committed booked-local snapshot and are not executable quotes. Publish both shared reserve values at the operation's final commit, after external payout/refund interactions. Canonical ERC-20 and metadata views retain their canonical behavior. No caller may infer a coherent in-flight whole-basket NAV by combining these unguarded views.

Add a selector-level read-policy table and callback observations that prove which views revert and which return committed values. Do not invent a proxy-wide guard or modify canonical facets to make a generic assertion pass.

**Disposition/trade-off:** Technical reconciliation that preserves the confirmed reuse requirement; the documented read-consistency contract should be accepted explicitly. Committed views are less strong than universal read rejection, but are achievable without unauthorized shared-facet changes.

## R5. Specify fee checkpoints and split principal from whole-position fee realization

**Priority:** Accounting requirement needed before implementation.  
**PRD:** S1-ACC-01/03; S1-OP-02/04/05; S1-SEC-01; S1-A12/A17/A22/A24/A41.  
**Evidence:** Source observation plus inference; high confidence.

`PoolManager.modifyLiquidity` returns `callerDelta = principalDelta + feesAccrued`. `Position.update` computes accrued fees using the position's old total liquidity, not just the liquidity being removed. A partial removal can therefore realize fees on the entire position.

The baseline collects before its ratio swap. `_deploy` realizes fees again through `_add` only if a positive addition occurs. A swap followed by no addition can leave newly earned fees uncollected. The PRD's command to include fees before the snapshot must cover that branch explicitly, rather than assuming one initial collection exhausted all fees generated during the operation.

**Proposed wording:**

> The pre-issuance/pre-redemption snapshot includes every fee earned through completion of the mandatory compound, exactly once. Where the final addition did not realize those fees, use a defined nonrecursive collection checkpoint for a nonempty position; do not repeat ratio swaps until no fees remain. On every modify result, separate principal from the fee component. Whole-position fee receipts are booked or allocated under their ownership checkpoint, not automatically granted in full to a partial withdrawing holder.

Specify explicitly that entry-swap fee attribution belongs to the R2 equation, while fees earned by the remaining position from the exit sale belong to remaining holders as S1-OP-04 already says.

**Disposition/trade-off:** Mostly technical completion of the stated accounting contract; entry fee economics require the R2 owner decision. A final collection checkpoint may add work and must be recorded as a deliberate baseline difference. This is preferable to a recursive compound requirement or an ambiguous "actual proceeds" allocation.

## R6. Name the native synchronization step instead of copying the baseline settlement branch

**Priority:** Required technical correction.  
**PRD:** S1-NATIVE-01; S1-SEC-01; S1-A51/A52.  
**Evidence:** Direct source observation; high confidence.

`PairToken._resolve` settles native debts with `settle{value: amount}()` directly. In the real `PoolManager`, `_settle` branches on `CurrencyReserves.getSyncedCurrency()`. `sync(address(0))` resets that currency, and the manager's own `_settle` comment tells native integrators to sync first. An already-synced ERC-20 currency with nonzero value causes `NonzeroNativeValue()`.

**Proposed wording:**

> Immediately before settling each native debt, call `PoolManager.sync(Currency.wrap(address(0)))`, then `settle{value: exactDebt}()`, and validate the reported paid amount and operation delta. The native branch must not depend on an earlier ERC-20/native synchronization state.

Add an acceptance subcase starting with a nonnative synced currency, without relying on a scripted manager that ignores that state.

The canonical proxy's `receive()` is empty and payable. Thus direct ETH receipt can succeed without a family receive selector and must remain unbooked unless the active engine attributes it. Do not promise receive-time sender rejection that this unchanged proxy cannot provide.

**Disposition/trade-off:** Technical settlement detail consistent with actual ETH support, not a new owner question. It adds a small explicit call and makes behavior independent of manager synchronization history.

## R7. Extend boundary arithmetic requirements to every liquidity-sizing use

**Priority:** Accounting and executable-domain completion.  
**PRD:** S1-X13; S1-ACC-01/02; S1-OP-02/05; S1-A11/A23/A45.  
**Evidence:** Source observation and inference; high confidence.

`PairTokenMath.Fit` branches at the range endpoints, but baseline `basket` and `_ratioSwap` use unclamped amount calculations with `price` directly. `_ratioSwap` computes both `need0` and `need1` even when `Fit` has selected a one-sided branch. Fixing only `basket()` leaves inconsistent compound leftovers and sizing at/outside the usable range.

The real `Pool.modifyLiquidity` also applies signed liquidity casts and per-tick gross-liquidity limits. A mathematically affordable addition is not automatically admissible to the manager, especially when other positions share the full-range boundaries.

**Proposed requirement:**

> Define one piecewise full-range principal/cost contract: below range only token0, inside range both currencies, above range only token1; use downward rounding for removable principal and upward rounding for required deposits. Apply it consistently to basket valuation, paired additions, compound leftover estimation, and projection. State separately how the baseline active-pool reserve estimate is extended at range boundaries. Validate manager signed-delta and per-tick capacity constraints in the projected execution domain.

Specify exact one-sided accepted-input amounts in S1-ACC-02: to preserve the baseline branch, consume the complete maximum of the supported leg and zero of the other, rather than silently substituting a new ceiling-trimmed rule.

**Disposition/trade-off:** Technical completion of X13 plus explicit documentation of any changed compound-cap boundary behavior. Do not silently clamp liquidity to manager capacity and retain the balance as idle: that would be a new liveness/economic deviation requiring approval. Rejecting an over-capacity addition preserves a narrower baseline domain.

## R8. Make the ownership ledger executable as invariants

**Priority:** Implementability improvement.  
**PRD:** S1-ACC-04/05; S1-NATIVE-01; S1-SEC-01; S1-A34-A38/A41/A49/A52/A54/A55.  
**Evidence:** Source observation and inference; high confidence.

The direction is correct: `LocalCreditLib.available` subtracts booked balances, and `requirePretransferCaller` proves only the presence of bytecode, not ownership or atomicity. The PRD correctly acknowledges this. However, the draft uses "booked balances," "operation reservations," "pending input," and "exit allocations" without a complete transition ledger.

**Proposed requirement:**

> At stable operation boundaries, raw pool-currency custody is at least booked local custody; the difference is unbooked credit. During an operation, each unit is assigned to exactly one of incumbent book, accepted input, exit allocation, refund, or unbooked excess. Manager deltas and temporary wrapper transformations update these categories explicitly. A credited native unwrap replaces, rather than adds to, its reserved wrapped input. A short custody balance is an accounting failure, not an invitation to consume another category.

Add a short transition table for pull, reserve, unwrap, manager debt/credit, book, payout, refund, and final commit. State whether exit allocations have been removed from `B_i` before calculating available credit; do not subtract them twice.

For shares held by the vault, say explicitly that ordinary ERC-20 transfers can create unowned staged share credit, subject to the same atomic-integration caveat. A contract-only check does not authenticate a particular transfer's owner.

**Disposition/trade-off:** Technical specification, not a request to add ownership attribution to the canonical pretransfer protocol. A small operation ledger is necessary; a generic credit subsystem or future reserve abstraction is not.

## R9. Define exactly what preview parity promises

**Priority:** Testability and API completion.  
**PRD:** S1-OP-01/03; S1-API-02/03; S1-QUOTE-01; S1-A27/A29/A30/A43.  
**Evidence:** Source observation and inference; high confidence.

Canonical `previewExchangeIn(tokenIn, amountIn, tokenOut)` has no recipient, deadline, allowance, or pretransfer flag. It cannot promise that a particular receiver accepts ETH, that a caller owns shares, or that token transfer callbacks will leave all external state unchanged. Native SY previews also do not receive `msg.value`.

**Proposed wording:**

> Preview parity covers economic outputs and economic-domain failures for a fixed pool/book/configuration state and valid funded operation parameters. Previews do not validate unavailable caller-specific authorization, allowance, pretransfer ownership, future deadlines, receiver acceptance, or attached value. Execution validates those conditions separately. Unsupported SY token previews return zero as specified; supported-token economic failures use the specified errors.

Require execution to use actual manager deltas and revalidate any preflight assumptions invalidated by external token/wrapper interactions. An unchanged-state parity statement is not permission to trust a stale preflight after such interactions.

Complete the family ABI with exact parameter/return types and mutability for paired previews, `depositPair`, `redeemPair`, queries, `donate`, and `compound`. Distinguish quote outputs from received inputs, gross deployment, and payouts in event fields. Define deadline equality and validation precedence only where the acceptance suite needs stable public errors.

**Disposition/trade-off:** Technical correction. This narrows an overbroad promise without weakening actual minimum-output checks. Do not require a view to simulate arbitrary recipient code or to depend on funded caller balances.

## R10. Specify zero-supply, zero-output, and arithmetic corner behavior

**Priority:** Material edge-case completion.  
**PRD:** S1-ACC-02/03/05; S1-OP-05; S1-SEC-02; S1-A08-A11/A16-A23/A33/A45/A54.  
**Evidence:** Source observation and inference; high confidence.

Removing dead shares creates reachable states absent from the baseline's intended lifecycle. The PRD handles terminal assets well, but should also state what `compound()` does on a clean empty instance. `Position.update` rejects zero-delta updates of an empty position, so blindly collecting at zero liquidity is invalid.

Positive input shares can also produce zero integer payouts on a sufficiently small partial withdrawal. "Reject zero amount" does not say whether it means zero input, zero output, or either. The shared SY redemption target only checks output against the supplied minimum, which can be zero.

**Proposed wording:**

> With `S = L = B0 = B1 = 0`, explicit compound is a successful no-op: do not poke an empty position or adopt unsolicited balances. Positive supply with no liquidity but positive booked inventory remains a distinct state; execute the defined compound/withdrawal logic rather than treating it as genesis. At terminal reset, no booked asset or unconsumed manager delta remains.

My recommendation is to reject a share-burning operation whose total actual payout is zero, even when user minima are zero; a one-sided positive paired payout remains valid. This is a proposed behavioral choice, not an existing confirmed requirement. The alternative is to allow explicit zero-minimum dust destruction and document it.

Retain checked genesis multiplication and its explicit rejection domain. Do not reintroduce a hidden minimum share sink, virtual shares, or arbitrary decimals allowlist to handle precision problems.

**Disposition/trade-off:** Empty-state behavior is technical completion. Zero-output burning is an owner choice: rejection avoids accidental destruction but can leave dust redeemable only when combined with more shares or at terminal exit.

## R11. Keep the SY valuation choice explicit and its arithmetic fully specified

**Priority:** Owner valuation approval plus technical completion.  
**PRD:** S1-QUOTE-02; S1-API-04; S1-A32/A33/A45.  
**Evidence:** Source observation and inference; high confidence.

The selected rate asset, spot-marked basket, zero rate before genesis, and exclusion of a Balancer adapter are coherent draft choices. They are not implied by the eight confirmed owner choices. Native ETH support also does not itself approve using wrapped-native metadata as the reporting asset.

**Proposed requirement, in addition to R1:**

> Define `A_i` explicitly as clamped removable principal plus booked local assets plus claimable position fees at the observation state, before any simulated compound. Compute position fees from current fee growth inside the range minus the stored checkpoint using the manager's modular subtraction and rounding rules. State exactly where conversion to the target currency is floored. The rate is an accounting observation, not a safe oracle or a guaranteed conversion.

`StateLibrary.getFeeGrowthInside/getPositionInfo` and `Position.update` supply concrete local references for accrued fees. No external price feed is required by this proposal.

Specify behavior when a representable output cannot be obtained: explicit arithmetic-domain failure, not wrapping or an invented capped value. Supporting arbitrary declared decimals without an allowlist is compatible with avoiding `10^d` entirely in the corrected raw-unit SY rate.

**Disposition/trade-off:** Ask the owner to approve spot accounting as a reporting policy, not as issuance authority. It is simple and faithful to available local state, but remains price-sensitive. Do not silently turn it into `getRate()` or an exit quote.

## R12. Preserve the confirmed package composition and make the final manifest authoritative

**Priority:** Technical completeness; not a reason to redesign the package.  
**PRD:** S1-ARCH-01-05; S1-API-01/04; S1-PKG-01; S1-A01-A07/A47/A56/A57.  
**Evidence:** Source observation; high confidence in declarations, unverified runtime behavior.

The five canonical facet declarations do total 20 selectors. The current factory installs its own introspection facets and temporary hook. The revised package/factory split is supported by source and should remain. The canonical multi-asset interfaces also support the rationale for using a narrow paired surface rather than mislabeling maxima-input deposits or proportional exits as exact-output operations.

**Proposed additions:**

- Publish one manifest mapping every installed package selector and interface declaration to its owning facet, shared Repo initialization, and acceptance evidence. Include the exact new family type declaration; a name alone is not an interface identity.
- Derive declared IDs from the canonical interfaces and verification workflow. Do not guess that an inheritance-only combined marker has the XOR of all inherited selectors.
- Require absence of `diamondCut`, operational ownership, rescue, ERC-4626, and unrequested quote/rate-provider selectors on the final product proxy, not merely absence from one family source file.
- Make deployment-identity tests cover package bindings as well as instance arguments. Separate factory initialization, package storage, and delegatecalled proxy storage. Native face order remains PoolKey order even if the wrapper address sorts differently.
- Keep the two exact-output selectors and their explicit unconditional unsupported behavior. This means the call does not pull/refund staged funds; it cannot promise that someone never transferred tokens to the address earlier.

**Disposition/trade-off:** Technical completion of settled architecture. No new factory facets, duplicate token selectors, Wings economic facets, or second token supply should be introduced.

## R13. Turn the acceptance matrix into outcome controls, not deferred product judgment

**Priority:** Approval and verification gate.  
**PRD:** S1-A01-A57; especially A15/A24/A27/A28/A32/A41/A46/A48; S1-TEST-01; section 11.  
**Evidence:** Source observation and inference; high confidence.

The baseline TestBase uses a real PairToken but scripted dependency results. Its scripted manager queues arbitrary swap/modify results and does not implement the real pool's tick traversal or settlement constraints. The Wings TestBase demonstrates registered package deployment with the real PoolManager. The PRD correctly separates these roles; maintain that distinction.

**Proposed acceptance improvements:**

1. Give A15 and A46 numerical acceptance rules after the R2 decision: attribution conservation, permitted fees/rounding, and the chosen before/after comparison basis. "Measure" and "report unacceptable" are evidence tasks, not pass criteria.
2. Use independent arithmetic controls and actual receipts. Preview and execution sharing a model does not independently prove that model's economics.
3. Add subcases for R1 raw-unit SY conversion, R5 compound-without-add fee checkpoints, R6 native sync history, R4 callback-time read policies, and R7 shared-boundary liquidity capacity.
4. Cover partial exit rounding as removal of `floor(L*s/S)` followed by manager principal rounding, not merely `floor(basket*s/S)`. These are not generally identical integer operations.
5. State which failures are economic-domain failures, caller/recipient failures, or expected unsupported operations. A26's intentional revert is successful selector coverage, not a missing route.
6. Preserve all 57 existing IDs. Add new IDs or explicit subcases with traceability rather than replacing rows with a generic invariant test.

**Disposition/trade-off:** Technical test-spec completion, dependent on the owner resolving economic choices. More precise controls reduce implementation discretion; they do not require running tests during this consultation.

# Owner clarification questions

These questions concern draft choices or newly exposed consequences. They do not reopen the eight settled choices.

1. **Should zap issuance be corrected to exclude incumbent inventory reinvestment, or remain baseline characterization?**  
   Alternatives: approve a complete caller-attribution formula before implementation, or preserve gross-deployed-amount issuance with explicitly limited readiness claims. **Recommendation:** approve the attribution correction direction, then require the full equation and fee/residual policy in the PRD before coding. Do not label the stage complete while A15's economic pass criterion is undefined. See R2/R5.

2. **Is conditional paired-exit availability acceptable when mandatory compounding exceeds the admitted quote/execution domain?**  
   Alternatives: accept a documented bounded domain and conditional maintenance-dependent exits; or require a broader liveness design and revise the proposed budget/domain before implementation. Both retain mandatory compounding unless a later, separate owner decision says otherwise. **Recommendation:** do not ratify 512 or promise unconditional fallback yet; establish the operational bound and explicitly approve the resulting liveness limitation. No guarantee of universal bounded-gas execution is established here. See R3.

3. **Do you approve spot-marked accounting value in the configured rate asset as the SY reporting policy?**  
   Alternatives: approve that policy, including zero before bootstrap and raw-unit canonical SY scaling; or keep valuation design unresolved and defer implementation readiness until a different concrete accounting policy is specified. **Recommendation:** approve it as an explicitly price-sensitive reporting value, never an issuance input, executable exit quote, or oracle guarantee. Correct the units regardless. See R1/R11.

4. **Should a positive-share redemption with zero actual payout reject even when all minima are zero?**  
   Alternatives: reject zero-total-payout burns; or allow deliberate dust destruction with zero minima. **Recommendation:** reject, while allowing paired exits with a positive payout in only one currency. This introduces no minimum-liquidity sink and does not change the last holder's ownership. See R10.

I would not ask again about full-range versus Wings, ETH versus wrapped-only support, exact-output support, keeping mandatory compounding, dead shares, retention, protocol-fee routing, or the five reusable facets. I also would not ask for universal zap parameter defaults: immutable per-instance values without silent defaults are already a workable draft configuration model.

# Assumptions and limits

- This is a local static requirements assessment, not an implementation audit, exploit reproduction, runtime correctness proof, or security certification.
- The required PRD and three baseline files were read completely. Optional surrounding sources were examined only to the extent identified above. The source tree was live; no atomic revision/hash snapshot is claimed.
- No implementation plan or audit report was supplied. No future stage-one implementation exists in the admitted target set to validate against these requirements.
- No tests, builds, Git commands, installs, deployments, wallet actions, or subagents were used. No exact selector IDs or gas bounds were computed or runtime-verified. The reused selector count is derived from the inspected declarations.
- No peers or earlier council outputs were read. Wings was used only for package/factory/test-deployment context, not as authority for ownership or economic formulas.
- The wrapper is assumed to be the configured canonical one-to-one native adapter. This pass read its canonical interface alias, not its concrete implementation; operational wrapper guarantees still require implementation evidence.
- Token callback interactions, worst-case projector work, maximum admissible manager state, and real mixed-decimal execution remain verification obligations, not proven results.
- Only the assigned `members/astra/response.md` artifact was written. The PRD, baseline, other code, configuration, and tests remain outside this assignment's edit scope.
- The next step is coordinator synthesis and owner resolution of the material choices, not implementation or an unsolicited advisory pass.
