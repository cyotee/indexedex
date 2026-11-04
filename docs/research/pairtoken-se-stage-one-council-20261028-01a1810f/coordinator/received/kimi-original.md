# Kimi original: coordinator archival receipt

Source: complete final inline response from Native task `st_01a183c4`. The member used the authorized inline fallback because apply_patch was unavailable. The body below is preserved verbatim, not a coordinator revision.

---

Ask: Independent Kimi initial-pass council assessment - wanted: a comprehensive, source-located PRD assessment in the assigned response file. For you: `apply_patch` is not exposed in this session, and tool discovery found no such capability. Per the brief, no alternate write mechanism was attempted and no file was created. The complete independent response follows inline.

## Identity

Independent Kimi council member, initial pass. Exact selected route supplied for this assignment: `kimi-coding/k3.1-pro:high`, global route.

This is a defensive product-requirements assessment, not an implementation audit, runtime correctness proof, or security certification.

## Question and targets

Assessed question: what material requirements need owner clarification, and what concrete improvements would make the stage-one PRD coherent, implementable, testable, and faithful to the confirmed owner choices?

Target reviewed in full:

- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`
- Revision containing S1-ARCH-04/05 and acceptance S1-A01 through S1-A57.

**Overall disposition: not yet ready for implementation.** The package/facet composition, native/wrapped interface mapping, terminal paired exit, deviation register, and standard-route structure are substantially coherent. However:

1. S1-OP-02 deliberately leaves the single-token issuance attribution question unresolved.
2. S1-A15 and S1-A46 do not define objective economic pass/fail criteria.
3. S1-QUOTE-01 implies a substantial pure-state V4 simulation engine whose required state transitions and work unit are not specified.
4. Mandatory-compound failure semantics can determine whether otherwise valid exits remain live.

These are requirements decisions, not details that should be discovered during coding.

I treated the eight choices in the brief as settled: staged simple SE; one full-range position; ownership logic only without dead shares, retention, or protocol-fee routing; baseline mandatory compounding; actual native ETH; installed-but-reverting exact output; the five reused facets with factory facets excluded from package cuts; and no stage-one shares-of-shares model. The recommendations below do not ask to reopen those choices. Detailed formulas, quote policy, donation rules, failure handling, and other normative wording remain author-proposed unless separately confirmed.

## Evidence and coverage

Read completely:

- The target PRD.
- `PairToken.sol`, especially `deposit`, `zapDeposit`, `_quote`, `_deploy`, `_redeem`, `_compound`, `_ratioSwap`, `_resolve`, and `_add`.
- `PairTokenMath.sol`, especially `MD`, `MU`, `Fit`, `A0down`, `A1down`, and `T`.
- `interfaces/IPairTokenDependencies.sol`.

Directly relevant admitted context checked:

- Standard SE In/Out/errors, multi-asset liquidity interfaces, native SY execution/discovery/preview targets, `IStandardizedYield`, and `LocalCreditLib`.
- The five reusable facets and their associated ERC-20, ERC-2612, ERC-5267/EIP-712, basic-vault, and standard-vault Targets/Repos.
- Current Wings package and production-first TestBase as packaging context only.
- Baseline PairToken TestBase and scripted harness for comparison feasibility; none were executed.
- Canonical `TickMath`, `SqrtPriceMath`, `LiquidityAmounts`, `SwapMath`, `StateLibrary`, `Pool.swap`, `PoolManager.unlock`, `modifyLiquidity`, `swap`, `sync`, `settle`, and `take`.
- Registry disable behavior and current Wings usage.
- Repository instructions cited by the PRD.

Useful confirmed coherence:

- S1-ARCH-04’s 9 + 3 + 1 + 3 + 4 selector count matches the five canonical facets’ actual `facetFuncs()`.
- The ERC-20, ERC-2612, and ERC-5267 split is consistent with the current Wings TestBase.
- S1-ARCH-05 correctly requires proxy-context `ERC20Repo` and `EIP712Repo` initialization; `EIP712Repo` caches `address(this)` and chain ID and rebuilds when either changes.
- The 16 named SY methods match the canonical native SY surface. Keeping token selectors on the shared token facets is consistent with SY inheriting metadata interfaces.
- The PRD properly distinguishes local booked reserves from deployed position ownership and SY spot accounting value from executable redemption quotes.
- Native and wrapped faces retain PoolKey order, and exact-output rejection is explicit rather than silently unsupported.

No peer responses, earlier council material, external research, builds, tests, Git operations, or deployment activity were used.

## Recommendations

### R1 — Resolve single-token issuance attribution before implementation

**Priority: blocking owner/economic decision.**

- **Locator and evidence:** S1-OP-02 steps 6–9 and its “Inherited limitation”; S1-A15 and S1-A46. `PairToken.sol::zapDeposit` computes shares from `result.used0/used1`; `_deploy` calculates those amounts from all idle balances after the swap. **Source observation plus inference.**
- **Gap and consequence:** Gross deployed amounts can include incumbent booked idle inventory, not only the entrant’s new contribution. The PRD acknowledges this but postpones the decision until comparative tests. An implementation can therefore faithfully follow the PRD while transferring ownership attributable to existing holders to a new entrant. “Unacceptable value transfer” is not a test oracle, and the current completion criteria still leave the economic algorithm to be selected later.
- **Proposed requirement:** Replace the inherited-limitation paragraph with a chosen normative rule before implementation. If incremental attribution is selected, use wording such as:  
  “Booked inventory and owned liquidity present immediately after the mandatory pre-entry compound shall contribute zero to the entrant’s share issuance. Gross deployed amounts shall not be used as the issuance contribution when they contain incumbent inventory. The PRD shall define the entrant’s net contribution, valuation price, swap-fee treatment, unmatched-input treatment, and integer rounding before implementation.”  
  If legacy attribution is intentionally retained, state instead that incumbent-to-entrant transfer is accepted behavior and define its permitted quantitative bound. In either case, make S1-A15 a deterministic balance/NAV assertion rather than a report-only observation.
- **Disposition:** Owner choice between explicit legacy behavior and a new incremental formula; technical correction to the acceptance row afterward.
- **Trade-offs and confidence:** Legacy behavior maximizes baseline fidelity but weakens proportional-ownership claims. Incremental attribution better matches the product goal but requires a new formula and comparative rounding vectors. **High confidence** that the current text is not implementation-complete; no claim is made about exploit magnitude without runtime tests.

### R2 — Make genesis, donation, and economic-abuse acceptance criteria objective

**Priority: blocking owner risk decision and testability correction.**

- **Locator and evidence:** S1-ACC-02 genesis requirements; S1-ACC-04 permissionless `donate`; S1-A08, S1-A38, and S1-A46. `PairToken.sol::_quote` contains the geometric-mean branch, while `DEAD_SHARES` currently supplies a permanent sink that stage one intentionally removes. **Source observation; risk magnitude is inference/unverified.**
- **Gap and consequence:** Removing dead shares is confirmed, but the proposed replacement requires only `q > 0` and positive fundable liquidity. Permissionless donations can change reserves per existing share and interact with issuance rounding. S1-A46 merely requires measuring gains/losses, so an implementation can pass while demonstrating an economically unacceptable first-depositor or donation sequence.
- **Proposed requirement:** Keep the confirmed absence of dead/virtual shares, but add an explicit owner-selected risk policy. Options should be stated as either:
  1. accept and prominently document the residual genesis/donation rounding risk; or
  2. require immutable minimum genesis share/liquidity thresholds plus defined incumbent-value and entrant-rounding bounds.  
  Rewrite S1-A46 with concrete oracles: exact supply/share conservation, no unbooked balance adoption, enumerated incumbent NAV before/after each sequence, maximum permitted entrant rounding loss, and a defined pass/fail rule for attacker net gain. Do not use “measure” or “unacceptable” as the final assertion.
- **Disposition:** Owner chooses the risk tolerance and any minimum parameters; editorial/technical work converts that choice into acceptance assertions.
- **Trade-offs and confidence:** A minimum genesis size raises the cost of adverse sequences but does not prove their impossibility. A strict no-value-transfer requirement may necessitate a different economic design rather than another test. **High confidence** that the present acceptance rows are non-deterministic; **medium confidence** about the severity of particular sequences absent execution.

### R3 — Specify the exact V4 preview state machine and work unit

**Priority: blocking scope decision; substantial technical correction if retained.**

- **Locator and evidence:** S1-X08, S1-QUOTE-01, S1-A27, and S1-A28. Canonical `Pool.swap` updates slot0, active liquidity, global fee growth, initialized-tick transitions, and tick fee-growth-outside. `PoolManager._swap` additionally accounts for protocol fees. `StateLibrary.getPositionInfo` exposes each position’s cached fee-growth-inside-last values. **Source observation plus inference.**
- **Gap and consequence:** Calling `SwapMath.computeSwapStep` alone cannot provide execution-equivalent multi-swap previews. Mandatory collect → ratio swap → reinvest → entry/exit sequencing also requires updating the simulated position’s fee-growth checkpoints so later collections are neither omitted nor duplicated. A pure `view` implementation cannot simply invoke the state-changing manager or reuse `Pool.swap` on in-memory state. The PRD therefore implies a custom manager-state simulator but does not identify its full state or complexity. “512 traversal steps” is also undefined.
- **Proposed requirement:** If full parity is retained, specify:
  - the simulated slot0, active liquidity, LP/protocol fee, global fee growth, tick bitmap/tick info, owned-position liquidity, and position fee-growth-checkpoint transitions;
  - one work step as **one iteration of canonical `Pool.swap`’s loop**, including zero-liquidity and uninitialized-next-tick iterations;
  - one shared 512-step total across compound and subsequent entry/exit swaps, with step 512 accepted and the next required step reverting `QuoteWorkExceeded`;
  - preflight after pending-input isolation and before any compound, pull, swap, or liquidity deployment;
  - identical preflight behavior for native and ERC-20 faces.  
  Add acceptance vectors with nonzero PoolManager protocol fee, tick-crossing fee-growth updates, zero-active-liquidity steps, fees generated between collection and reinvestment, and exact 512/513-step boundaries.
- **Disposition:** Owner decides whether exact pure-view parity and its liveness cap are required product scope. The state-machine definition is a technical correction if retained.
- **Trade-offs and confidence:** Full parity improves integrator safety but adds a large, gas-intensive component and can reject otherwise executable operations beyond the cap. Relaxing parity would simplify stage one but requires changing S1-X08 and consumer expectations explicitly. **High confidence** in the hidden complexity; implementation effort was not prototyped.

### R4 — Define mandatory-compound failure semantics for withdrawal liveness

**Priority: blocking owner liveness decision.**

- **Locator and evidence:** Confirmed S1-P01; S1-OP-05; S1-ACC-05; S1-QUOTE-01; S1-A19–A21 and S1-A42. `PairToken.sol::_compound` proceeds from collection into `_requestDeploy` when eligible leftovers exist; `_ratioSwap` determines the amount and cap. **Source observation plus inference.**
- **Gap and consequence:** The PRD does not say whether an exit must revert when fee collection and proportional removal would succeed but the discretionary ratio swap or reinvestment cannot execute. Strict atomic inheritance can make paired redemption unavailable, weakening the stated terminal-exit fallback. Catching arbitrary manager failures would instead risk hiding settlement/accounting defects.
- **Proposed requirement:** Add an explicit owner-selected policy:
  - **Strict baseline:** every compound failure reverts the triggering operation, and documentation/acceptance acknowledge that paired exits can be blocked; or
  - **Narrow exit-liveness fallback:** when preflight determines that the optional ratio-swap plan is not executable, an exit still performs mandatory fee collection, books the collected assets, skips only that ratio swap/reinvestment, and proceeds. Actual unexpected manager, settlement, or accounting failures still revert.  
  I recommend the narrow fallback for paired exits if compatible with the owner’s compounding intent. Preview and execution must use the same branch, with an acceptance case proving paired exit under the specified compound-swap failure.
- **Disposition:** Owner choice about detailed failure behavior; this does not request removal of mandatory pre-operation compounding.
- **Trade-offs and confidence:** Strict behavior is closest to the baseline; the fallback improves holder liveness but is a deliberate compounding deviation requiring comparison-ledger coverage. **Medium-high confidence** in the requirements gap; exact failure frequency is unverified.

### R5 — Require explicit native `sync` before native settlement

**Priority: high technical correction.**

- **Locator and evidence:** S1-NATIVE-01 settlement bullets and S1-A51. `PoolManager.sync` resets the synced currency for native currency; `_settle` uses the currently synced currency and rejects nonzero `msg.value` if an ERC-20 remains synced. The source explicitly warns integrators to call `sync` before native settlement to avoid denial-of-service vectors. **Source observation.**
- **Gap and consequence:** “Canonical native `settle{value: amount}()` sequence” is not sufficient when an earlier operation in the same unlock synced an ERC-20. Mixed-delta sequencing can otherwise revert even though both debts are funded.
- **Proposed requirement:** Add:  
  “Immediately before every native `settle{value: amount}()`, call canonical `sync` for the native currency to clear any prior synced ERC-20. ERC-20 debt uses `sync(currency) → transfer → settle`; a later native debt repeats the native reset before value settlement.”  
  Extend S1-A51 with mixed native/ERC-20 debts, native settlement following ERC-20 settlement, repeated operations in one unlock, and verification of final zero deltas.
- **Disposition:** Editorial/technical correction; no owner economic choice.
- **Trade-offs and confidence:** A small additional call and stricter sequencing requirement versus avoiding order-dependent settlement failure. **High confidence.**

### R6 — Define one reservation invariant and place preflight explicitly in every operation order

**Priority: high technical/requirements correction.**

- **Locator and evidence:** S1-ACC-04, S1-OP-01/02/04, S1-NATIVE-01, S1-QUOTE-01, S1-SEC-01, S1-A41, and S1-A52. `LocalCreditLib.available` defines unbooked credit as raw balance minus booked balance but does not itself attribute ownership. **Source observation plus inference.**
- **Gap and consequence:** The PRD requires booked balances and operation reservations but never states their common conservation invariant. The paired and zap operation orders also omit the later-introduced preflight step, leaving its position relative to mandatory compounding open. Native wrapping adds temporary representations that can easily be miscounted without a single ledger rule.
- **Proposed requirement:** Add a common invariant for each actual pool currency:  
  `raw balance = booked shareholder inventory + pending caller input + reserved refund/exit allocations + unbooked balance`, with temporary wrapped/native representations mapped to the same underlying reserve exactly once. At every successful external return, pending and reserved amounts are zero and actual custody covers booked inventory. Payouts and refunds spend only their reservations; compound and liquidity addition spend only booked inventory plus explicitly reserved operation input.  
  Amend each operation sequence to: `validate → guard → isolate/reserve input → preflight complete plan → compound → execute → settle reservations → synchronize Repo reserves → unlock`.
- **Disposition:** Technical clarification consistent with existing intent.
- **Trade-offs and confidence:** More explicit bookkeeping and test assertions versus much less room for double-counting and accidental use of another operation’s assets. **High confidence.**

### R7 — Fully define SY accounting inputs, metadata, and rounding

**Priority: medium technical correction.**

- **Locator and evidence:** S1-QUOTE-02 and S1-A32/A33. `StateLibrary.getFeeGrowthInside` and `getPositionInfo` provide the canonical pending-fee inputs; canonical `IStandardizedYield.exchangeRate` defines a WAD asset-per-SY relationship. **Source observation.**
- **Gap and consequence:** `A0` and `A1` appear without a precise definition. The method for including accrued LP fees “once” and for obtaining `rateAsset` decimals is unspecified. Extreme prices and mixed decimals make an informal sequence of divisions capable of producing different rates through premature truncation.
- **Proposed requirement:** Define `A0/A1` as removable full-range principal at the current clamped price plus booked local balances and currently accrued LP fees, excluding unbooked funds, pending caller input, and reserved payouts/refunds. Compute pending fees from canonical global/tick/position fee-growth values without simulating a whole-book sale. Validate and cache the rate asset’s exact `decimals()` result during initialization; native legs use the bound wrapper’s 18 decimals. Specify full-precision intermediate arithmetic and every intentional floor, including the final WAD normalization. Add vectors with accrued fees, extreme prices, zero supply, and 6/8/18-decimal rate assets.
- **Disposition:** Editorial/technical correction; the proposed spot-rate policy itself remains author-proposed but is internally reasonable.
- **Trade-offs and confidence:** Slightly more initialization and arithmetic specification versus deterministic consumer behavior. **High confidence.** The existing warning that this spot rate is not an execution quote or manipulation-resistant oracle should remain.

### R8 — Enumerate fail-closed reads without conflicting with unchanged ERC-20 facets

**Priority: medium technical correction.**

- **Locator and evidence:** S1-SEC-01’s read-method guard, S1-ARCH-04’s unchanged-facet requirement, and S1-API-01. Canonical `ERC20Target` exposes unguarded `totalSupply`, `balanceOf`, `allowance`, and metadata methods. **Source observation.**
- **Gap and consequence:** If “read methods that could expose a half-settled economic book” includes share supply or balances, the requirement conflicts with reusing the ERC-20 facet unchanged. If it applies only to family economic queries, the protected set is currently unstated.
- **Proposed requirement:** Enumerate the guarded family reads: basic reserves, raw basket/position queries, paired/SE/SY previews, and `exchangeRate`. Explicitly state whether canonical ERC-20 supply/balance/metadata/allowance reads remain callable during mutation; the recommended reading is to permit them while forbidding them from creating or consuming reserve credit, because the confirmed reuse decision precludes adding a family guard to those methods. Add static reentrancy tests for each listed family read and for callback-originated cross-facet calls.
- **Disposition:** Technical/editorial resolution consistent with the settled facet-reuse choice.
- **Trade-offs and confidence:** Permitting canonical token reads preserves reuse and normal token composability but allows observers to see transient token state during a guarded callback. Guarding them would require a different facet composition. **High confidence** in the textual conflict; the desired external-observer policy is currently ambiguous.

### R9 — Make full-range boundary arithmetic canonical and exact

**Priority: medium technical correction.**

- **Locator and evidence:** S1-ARCH-02, S1-X13, S1-ACC-01, and S1-A45. Baseline `basket()` directly calls `PairTokenMath.A0down/A1down` with live price, while `Fit` has explicit below/above-range branches. Canonical `TickMath.minUsableTick/maxUsableTick`, `SqrtPriceMath.getAmount0Delta/getAmount1Delta`, and `LiquidityAmounts` define the boundary behavior. **Source observation.**
- **Gap and consequence:** “Use canonical clamped V4 amount math” states the direction but not the exact clamp, equality, or rounding rules. Boundary equality is especially important because a full-range position changes from two-sided to one-sided inventory there.
- **Proposed requirement:** Set `tickLower = TickMath.minUsableTick(tickSpacing)` and `tickUpper = TickMath.maxUsableTick(tickSpacing)`. For removable principal, clamp live price to the corresponding lower/upper sqrt-price boundary and use canonical amount deltas rounded against the vault; for required contributions use the opposing ceiling rule. Preserve the specified baseline interior `MD/MU` behavior only where it is proven identical to canonical math. Add explicit vectors below, equal to, inside, equal to, and above both boundaries, comparing quote results with actual manager removal receipts.
- **Disposition:** Editorial/technical correction.
- **Trade-offs and confidence:** No material product trade-off; it makes an existing deviation implementable and testable. **High confidence.**

## Owner clarification questions

1. **What ownership rule should single-token entry use?**  
   Alternatives: retain baseline gross-deployed issuance with an explicit accepted incumbent-to-entrant transfer bound, or require incremental entrant-only attribution.  
   **Recommendation:** choose incremental attribution and put its exact integer formula in the PRD before implementation; otherwise explicitly accept and bound the legacy transfer rather than deferring the decision to tests.

2. **What residual genesis/donation risk is acceptable after removing dead shares?**  
   Alternatives: document acceptance of the unmitigated rounding risk, or add owner-selected minimum genesis thresholds and objective economic bounds.  
   **Recommendation:** require meaningful immutable genesis minima and deterministic incumbent/entrant value assertions, while acknowledging that minima alone are not a complete manipulation defense. Do not restore dead shares.

3. **Is exact pure-view execution parity, including a 512-step execution liveness cap, a firm stage-one requirement?**  
   Alternatives: fund the complete V4 state simulator described in R3, or relax S1-X08/S1-QUOTE-01 and explicitly define weaker quote semantics.  
   **Recommendation:** retain exact parity if standard consumers will depend on these previews; otherwise relax it now rather than allowing a superficial spot quote to be represented as equivalent.

4. **Should an otherwise valid paired exit be blocked by failure of the optional compound ratio swap?**  
   Alternatives: strict baseline atomic compounding, or a narrowly defined collect-and-skip-ratio-swap exit fallback with all unexpected failures still reverting.  
   **Recommendation:** prefer the narrow exit-liveness fallback if it is compatible with the confirmed compounding intent, and specify it identically for previews and execution.

## Assumptions and limits

- No runtime tests or prototype simulator were used; economic magnitudes and implementation effort are qualitative.
- No implementation plan or audit report was supplied or assumed.
- No external research was necessary, and no external citations are claimed.
- Recommendations identify requirements decisions and corrections; they do not authorize implementation or PRD edits.
- The eight confirmed owner choices are treated as settled. In particular, recommendations about genesis risk do not propose restoring dead shares, and exact-output operations remain rejected.
- `apply_patch` was unavailable in this session. The assigned file was not written, no alternate write mechanism was attempted, and this inline response is the complete fallback required by the brief.

Now: no task remains.
Next: no task remains.
