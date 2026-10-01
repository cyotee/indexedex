# FullSpread execution status

## Family acceptance closure and writer return (2026-09-28)

The previously excluded 15 new acceptance/support files are now compiled and
executed against the optimized H/P sources. **270 tests passed, zero failed or
skipped, across 68 suites** (the gas worker's 239 plus 31 new cases). Both current
artifact identity/runtime checkers exited 0. H OutFacet remains 24,571 bytes; P
OutFacet remains 24,540 bytes. No production files were changed in this acceptance
pass, and no consumer root was selected.

Both strengthened stateful campaigns passed **128 fuzz inputs x 32 sequential
actions per family**, or 8,192 action steps total. They independently check
core-derived backing, observed swap/placement attribution, proportional issuance,
withdrawal entitlement, separate Pons fee/tax ledgers, custody conservation, share
ledgers, local booking and atomic rejection. This is bounded stateful fuzz
evidence, not an exhaustive invariant proof or security audit.

Final logs under `/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/`:
`fullspread-family-n76462kp/` (full gate and final identities), and
`fullspread-family-k8degvt0/` (strengthened 128-run campaigns). Each has collected
`output.log` and `result.json` with command exit codes. The final code manifests
are H `5253edf4d196b43358fd2c0292cd2652cb355ae948c8142e0562d2e5e41e5bd6`
and P `92710ced093ee772ce64126f5d0457b19c6ad4b40d809cd1c6689baf5f51b852`;
P includes the shared test references and validation scripts. See
[Pons execution status](UNISWAP_V4_FULLSPREAD_PONS_EXECUTION_STATUS.md) for exact
coverage, commands, historical-versus-current evidence and construction limits.

P's production-chain negative rejects the local hook/manager binding before the
later manager-address pin; a separate genuine-hook manager-mismatch negative
supplies combination evidence. It is not an isolated canonical-hook manager-pin
test. No fake SUT or live RPC prerequisite was introduced.

**The serialized artifact writer is returned to the parent. Consumer validation,
combined audit-submission readiness, the human removal checkpoint, and final
post-removal validation remain outstanding.** The older pending-new-case and gas
blocker statements below are chronological records, superseded only by the
bounded acceptance and gas gates recorded above and below.

## Holder-repair gas closure (2026-09-28)

**The bounded H/P performance task is complete for the frozen family suite and
the gas matrix below.** This supersedes the older gas-blocker statements in this
document, not the outstanding consumer/new-acceptance/readiness work.

The supplied Robinhood mainnet observation is chain 4663, block 74659884,
hash `0x6556dbd9a0ba35597d20a3be2a5764113076b03b5b4a018b26b1eb75a7ab8dd2`:
ArbGasInfo at `0x6c` returned 32,000,000 for both `getMaxTxGasLimit` and
`getMaxBlockGasLimit`. This task made no live transaction or new RPC attestation.

### Final measured gate

- **239 tests passed, 0 failed, 0 skipped, across 57 suites.** The original H95/P118
  suite files were retained, with new runtime/reference/gas cases added. The
  parent's 15 new unfinished acceptance/support files were deliberately not selected.
- Both `check-hookless-artifacts.py` and `check-pons-fullspread-artifacts.py` exited
  **0**: current source identities matched compiler metadata and all reported
  production runtimes fit 24,576 bytes.
- Gas regressions assert **less than 28,000,000 execution gas**. The stress matrix
  also forwards only 28,000,000 gas to the actual vault call, retaining 4M below
  the network cap. It requires a real nonzero holder swap, not disabled repair.
- Worst measured repair: **22,884,791 gas**, leaving **9,115,209** below the network
  cap. Worst automatic-maintenance operation: **21,681,900 gas**.
- Original heavy-repair fixture: H **54,617,528 -> 19,795,187**; P
  **54,466,716 -> 20,373,933**. These are individual operation measurements.

Maximum individual-operation gas in each matrix environment:

| Family / tick spacing / registered P fee | Public repair | Automatic maintenance |
|---|---:|---:|
| H / 60 | 21,797,092 | 21,128,768 |
| H / 1 | 21,828,740 | 21,147,970 |
| P / 60 / 100 + 100 bps | 22,149,359 | 21,681,655 |
| P / 1 / 100 + 100 bps | 22,190,741 | 21,681,900 |
| P / 60 / 100 + 1,900 bps | 22,859,208 | 19,786,041 |
| P / 1 / 100 + 1,900 bps | 22,884,791 | 19,789,596 |

Each environment exercises both token directions. Repair donations are 10, 1,000
and 1,000,000 whole tokens against the real fixture's vault/external LP. Automatic
maintenance covers direct exact-input swaps, share redemptions and dual joins
after a 10-token imbalance, with exact preview/result assertions and complete
booking checks. The two P fee terms retain separate floors. Suite-total gas,
reference-loop gas, deployment/setup and address mining are not transaction gas.
These are measured regressions, not a universal gas bound over every possible pool.

### Implementation and semantic preservation

Only four production files changed in this performance task: the two family
`TransitionPlanner` files and H `InventoryMath` / `ProtectionMath`.

- Moved the unchanged pure placement stencil into the approved shared inventory
  helper so temporary placement allocations do not accumulate across all trials.
- Cache exact baseline/best/candidate progress and retain the chosen placement's
  exact progress and sign instead of recomputing them. Sleeve comparison is lazy
  when composition already decides the lexicographic result.
- Preserve all candidate directions, both local and released-position funding
  domains, the existing refinement ceilings, endpoint evaluations, tie ordering,
  price/shortfall/alignment protections and the maximum one executed holder swap.
  No eight-probe substitution, gas-dependent candidate dropping or no-op shortcut
  was added. Section 6.3 required no algorithm or economic amendment.
- Eight-limb arithmetic remains exact: scalar multiplication skips only known
  zero high limbs and still rejects overflow; fixed-size comparison/subtraction
  use bounded memory-safe word access under pinned solc 0.8.35, preserving borrow
  checks. New full-width controls compare against independent lexicographic and
  base-256 subtraction references. Existing carry/overflow/rational tests pass.
- H/P fee/quote/execution implementations remain separate. P still imports only
  the three approved H pure helper/type files. No P fee-model, generic SY, consumer,
  shared-hook, legacy or candidate source was edited by this task.

Reference-plan tests retain the pre-optimization selection loop and compare the
entire selected plan, including work counters, in both directions and at realistic
and extreme amounts. They **share current financial/math primitives**, so they are
selection-equivalence evidence, not an independent financial oracle. Independent
arithmetic/core controls remain in the retained suites. The parent's bounded
Oracle static review reported no concrete semantic change in caching/aliasing/
selection; this is not a whole-protocol audit approval.

A separate family-local evaluator experiment increased gas and was removed. Only
its two task-created orphan `RepairEvaluator.json` artifacts were removed; no
`out/` or cache directory was cleared, and no legacy/source file was deleted.

### Reproducible commands and exact logs

The successful serialized job first refreshed the planner roots with `forge build`,
then ran the canonical artifact-first helper and both identity/size checkers:

```bash
H=contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless
P=contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook
T=test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread
forge build "$H/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol" \
  "$P/UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol"
args=()
for family in hookless ponsFamilyV2Hook; do
  for suite in AdmissionAndIdentity Adversarial AdversarialReentrancy \
    AttributionAndBooking BlockedFormulaReference ConsumingHook CoreSettlement \
    EquivalentInterfaces FormulaDomains MaintenanceProgress NativeSettlement \
    NestedAndConsumer OneBackedLeg PositionImport ProtectionAndInventoryMath \
    QuoteExecutionParity RuntimeAndWork ZapAndPlacement; do
    args+=(--test-root "$T/$family/$suite.t.sol")
  done
done
args+=(--test-root "$T/ponsFamilyV2Hook/PonsFeeSemantics.t.sol")
args+=(--test-root "$T/ponsFamilyV2Hook/RegisteredLaunch.t.sol")
python3 scripts/forge-artifacts.py test \
  "$H/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol" \
  "$H/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol" \
  "$P/UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol" "${args[@]}" -- -vv
python3 scripts/check-hookless-artifacts.py
python3 scripts/check-pons-fullspread-artifacts.py
```

Exact expanded command arrays, exit codes and full output are retained at:

`/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/fullspread-gas-e5fq7nwh/`

- `result.json`: all four commands exit 0; `success: true`.
- `output.log`: 239-test results, per-operation gas, runtime sizes and manifests.
- Job execution elapsed: 1,211.26 seconds; test execution: 53.22 seconds.

Final checker source-manifest digests:

- H: `5253edf4d196b43358fd2c0292cd2652cb355ae948c8142e0562d2e5e41e5bd6`
- P: `30ac364a7e2b2fc6d9c8d42563107ce0621b21b06a5262e8a0db4ca01342f4d2`

SHA-256 of this task's changed code files (H/P roots as defined above):

| File | SHA-256 |
|---|---|
| H `UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol` | `f38a3fc5833868a4a31cb9fc01b7665877f77daa0dda89d603fbf27502c7e182` |
| H `UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol` | `4e60b1eba506db6f3b2ec7a863ecd3dd3bd4eeb52383dfa2758506cf735e4a1b` |
| H `UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol` | `94412bcb1b153b4818ce209f5505108b13e0769835302fb7b274b4b024efd9d1` |
| P `UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol` | `ea8ba6aa93437d1ae2dc9bf802e63c5adb839d3a0fa449947791e028698b4869` |
| H suite `MaintenanceProgress.t.sol` | `18d4d20961448282de32794a4a4fe8d3bcbc8338b9c8b5f344cfa5656dc1eadf` |
| H suite `RuntimeAndWork.t.sol` | `1ed05d580838ed1c7b663d6cecaa929205b2d9679fd747671f9b681683a36265` |
| P suite `MaintenanceProgress.t.sol` | `8a45f86643a32e1f0309bf3a0232722cbf3833109f8cd98f7bdacff0a3f3b0f5` |
| P suite `RuntimeAndWork.t.sol` | `17e720b413ed31758acff26783ced0f349adb942f19ba71de7eff92b955bd69f` |

Changed-file LSP checks returned no errors. No compiler settings/profiles were
changed, no compiler was killed, and no commits/broadcasts/live actions occurred.

### Handoff and residual concerns

- The 15 new acceptance/support files and consumer changes remain parent-owned and
  unvalidated by this frozen gate. They must receive their own serialized validation.
- H OutFacet remains **24,571 bytes** (five bytes of headroom); P OutFacet remains
  **24,540 bytes** (36 bytes). The pure InventoryMath is 12,157 bytes; H/P planners
  are 14,858 / 14,856 bytes. Future changes must rerun the size/identity gates.
- The fixed-array assembly relies on the pinned compiler's documented memory
  layout; retain the independent full-width regressions for compiler upgrades.
- This closes the measured gas blocker for this matrix, not consumer readiness,
  the entire remaining acceptance program, audit completion or the human removal gate.
- The final runner exited. No further build/test process is scheduled by this
  worker; artifact-writer ownership is returned to the parent.

## Resumed execution checkpoint (2026-09-28)

The owner resumed implementation after the council-guard scoping fix. The records
below are retained chronologically; this checkpoint supersedes their stale H-only
validation and P-not-started descriptions, not their unresolved acceptance gaps.

- Combined family validation before the pause: H 95 and P 118 tests, **213 passed,
  zero failed or skipped**, across 53 suites. Both artifact identity/runtime
  checkers passed again during independent QA review.
- Mainnet chain 4663 at block 74659884 reported a 32,000,000 transaction execution
  gas limit through ArbGasInfo. Measured individual holder repairs were
  54,617,528 gas (H) and 54,466,716 gas (P). Both require optimization and executable
  gas regressions; passing under the hermetic test allowance is insufficient.
- Twelve backend consumer files were partially migrated. Remaining closure includes
  launch/discovery references, consuming hooks that assume the now-unsupported
  two-backed-leg exact-output redemption, and affected regression fixtures.
- The five read-only reviews did not approve whole-plan completion. The bounded
  custody/callback/admission review found no additional actionable vulnerability;
  goal, QA, quality, and consumer reviews retained the liveness/closure blockers.
- No legacy files have been retired. No commits, broadcasts, live registry changes,
  or migration of deployed instances have been performed by this execution.

Current work is to resolve those blockers, complete the remaining acceptance cases,
and record combined readiness before the plan's human removal checkpoint.

## Scope and readiness

Execution started 2026-09-27 for phases 1 and 2 of the approved implementation
and test plan. **H implementation is present; the current-tree acceptance gate
is not complete or audit-ready. The delegation is handed back to the parent.** No legacy
removal is authorized by this status. P-family implementation and consumer
migration are later phases of the overall implementation plan, outside this
Hookless delegation, not abandoned work. Deployment and live actions are not
authorized by this record.

The plan's R1-R11 matrix, F0-F6 domains, R8 vector exception and section 7 component
map govern implementation. The candidate is unadopted and remains untouched.
The six historical documents in the removal manifest are not replacement law.

## Starting evidence

- IndexedEx HEAD: `b019f232a1a109868da81be2d81f94d00a8a0be7`.
- Crane HEAD: `1c60b34ea5a0e55661f82ff09549dc6e9f8724f9`.
- The worktree was already dirty: `.cspell/custom-dictionary.txt`, the proportional
  zap-in PRD, two netnet documents and Crane; untracked candidate, candidate tests,
  approved plan/manifest and research records were present. These are user work.
- Crane had pre-existing edits to its dictionary and `ROBINHOOD_MAIN.sol`.
- Forge: `1.5.1-stable`, commit `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`.
- Configured compiler: Solidity 0.8.35, optimizer enabled, one run, no via-IR;
  default hermetic profile, `out/` and `cache_forge/`. Existing warm artifacts
  were present. No profile, compiler or cache-path changes were made.

SHA-256 of working files before implementation (not a claim that dirty files
match HEAD):

| Source | SHA-256 |
|---|---|
| Approved implementation plan | `d6dfa3a559394c7cff9674e5b564f6ec20106d493ec4dc9b714e4fb1afe0c810` |
| Proportional zap-in PRD | `43549bccaf20cd793c127c599f0e5108ee79958982ded696a27061672a0609be` |
| Removal manifest | `1b50fa28050f0639a0c443e691dc62c4c6fd85cc0ae611b45e70c5b3e77dac67` |
| `StandardExchangeConstantProduct.sol` | `ab471ddbf4c3f81fac2990d59913d9b940e76ca387b6f4c1d1509e4ab9f58de9` |
| Baseline FullSpread `Common.sol` | `82cead3623734229f49c74f9bb0dabe911091b8970003dd991b4ff3ca764c7af` |
| Baseline FullSpread `QuoteService.sol` | `6709bf5e55774ba6190d66729966d82d6b698d60c584a1c40aae023ce7428d89` |
| Crane `ROBINHOOD_MAIN.sol` | `74d3e4c20444b5ebc33d524c2778a5f03f151e5297f93c809836154a6a77fac5` |
| `foundry.toml` | `14536c5fabad6b40fea707ad11d8b80d48b6ada96c5995eaa25e2384908e8d38` |

Starting artifact JSON identities (historical cache observations, **not** refreshed
acceptance evidence):

| Baseline artifact | SHA-256 |
|---|---|
| `out/UniswapV4FullSpreadStandardExchangeVaultInFacet.sol/UniswapV4FullSpreadStandardExchangeVaultInFacet.json` | `77693e753738dcbdec77cf33d96ceb5df00570dc43aca647bd1087771b57c797` |
| `out/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol/UniswapV4FullSpreadStandardExchangeVaultDFPkg.json` | `63d810fbebc4d678fd91f47a9a14dff0848959da5377b794be193310a3b0ac9b` |

## Validation record and final delegation handoff

The H section-7 implementation, interfaces and requested decimal TestBases are
present. Production execution uses real registry proxies and separately compiled
H components. The permitted pure helpers are linked libraries where needed;
there is no H/P economic dispatcher. Generic NativeStandardYieldTarget is unchanged.

Executed milestones, in chronological order (each used `scripts/forge-artifacts.py
test` with edited production sources and the relevant exact H test roots):

- Initial independent arithmetic build: 11 tests passed.
- Arithmetic plus real PoolManager settlement and exhaustive blocked formula
  controls: 22 tests passed.
- Initial registry-proxy quote/execution and full-state transition checks:
  27 tests passed.
- Expanded nested/SY/adversarial/maintenance/selector gate: 48 passed, 3 failed.
  Failures were oversized runtimes, missing native-SY selector controls in the
  test, and a revert expectation set before a balance read. These were corrected;
  no assertion was deleted.
- Decimal/native/formula expansion: 77 passed, 1 failed (runtime size gate).
- Latest targeted runtime/import/proxy gate: 8 passed, 0 failed. All deployed H
  facets, delegates and package passed 24,576 bytes. Largest was OutFacet at
  24,571 bytes, only five bytes of headroom; the final artifact report must be rerun
  after any further production edit.

Two externally reviewed issues were corrected with passing real-core regressions:
positive trial swaps with no directional room no longer abort a valid zero-swap
candidate; shared lower/upper tick liquidityGross capacity is modeled in snapshots
and signed placement. Tests cover both price extremes, maximum endpoint headroom
versus one extra liquidity unit, and safe maintenance deferral at full endpoints.

Composition gas improved from approximately 80M/188M in the first implementation
to approximately 7.22M-7.59M per successful proxy operation in the latest measured
18/18 fixture. These are individual operation measurements, not suite-total gas.
The earlier holder-repair measurement was approximately 54M gas; it requires a
fresh post-convergence-optimization measurement and remains an explicit cost concern.
Hermetic success under the repository's large test gas limit is not production
gas feasibility or a live-chain attestation.

### Latest executed results

1. Full H gate: **92 tests passed, 0 failed, 0 skipped, 24 suites**. The subsequent
   artifact checker exited **0**, verifying present artifacts, current H source
   keccak identities in compiler metadata, and every reported runtime at or below
   24,576 bytes.
2. Additional real one-backed-leg acceptance: **2 tests passed**. Both blocked F2
   linear exact-output and idle linear exact-output with CC succeeded. The state
   was reached through actual swaps and maintenance, not storage modification.
   Its artifact checker also exited **0**.
3. Last consolidated H run: **94 tests passed, 0 failed, 0 skipped, 25 suites**;
   test command exited **0**. **The following artifact checker exited 1** because
   the final single-token-bootstrap classification changes were newer than its
   compiled artifacts. This run is **not** a current-tree green acceptance gate.

The late correction makes positive single-token activation reject as
`InvalidRoute` before a token pull, consistently across ordinary and transition
previews. It changes `InTarget.sol`, `InBase.sol`, and `InQueryTarget.sol`, and adds
`test_singleSidedActivationRejectedBeforeTokenPull` in `QuoteExecutionParity.t.sol`.
That regression is **not included in the 94-test passing total**. Refresh and rerun
the current tree; the expected test total is 95. No passing assertion was removed.

All file-level LSP calls made for the H sources, TestBases, suites and Python
helpers returned no errors before that late correction. The late correction still
needs its final compile/test/diagnostic confirmation. Directory-level Solidity
diagnostics were unsupported, so individual files were checked. `forge-lsp` also
queued background compiler passes; these were allowed to exit naturally. No
compiler was killed by this delegation.

### Commands and retained logs

The concrete artifact/test command used by the detached runner is equivalent to:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/*.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless \
  -- -vv
python3 scripts/check-hookless-artifacts.py
```

`python3 scripts/run-hookless-acceptance.py` detaches that same serialized workflow
from tool-wait cancellation, waits for existing compiler processes, and records
the actual command exit codes. It does not change compiler settings or profiles.

Local evidence directories under
`/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/`:

| Directory | Evidence |
|---|---|
| `hookless-acceptance-z0zt1fr8/` | 92-test full gate and successful artifact checker |
| `hookless-acceptance-1h88035e/` | Two one-backed-leg successes and successful artifact checker |
| `hookless-acceptance-opgiqrlr/` | Last 94-test run; stale-artifact failure after the late guard correction |

Each contains `output.log` and `result.json`. These are local execution records,
not committed build outputs. The checker prints an exact file manifest with
per-file SHA-256 hashes, per-runtime source/artifact hashes, runtime sizes and
stale/missing-artifact failures. The last report's source-manifest SHA-256 is
`2a6378fd544e5cb5b81ec714568656cdd3eab0e174cfbecaea7a56512e5090a7`;
this identifies its recorded sources, **not a successful current artifact match**.
The aggregate hashes the newline-joined sorted `path:sha256` rows printed in
`files`. Rerun the checker after the parent refreshes artifacts.

### Runtime and work evidence

Last successful deployed-runtime gate (bytes):

| H component suffix | Bytes |
|---|---:|
| InFacet | 23,923 |
| InQueryFacet | 18,987 |
| PositionImportFacet | 24,050 |
| OutFacet | 24,571 |
| OutQueryFacet | 22,358 |
| LiquidReserveFacet | 21,106 |
| InMultiFacet | 23,899 |
| InMultiQueryFacet | 18,639 |
| OutMultiFacet | 23,344 |
| OutMultiQueryFacet | 20,372 |
| InExecutionDelegate | 23,419 |
| OutExecutionDelegate | 19,399 |
| DFPkg | 14,008 |

OutFacet has **five bytes of headroom**. The last artifact report also checked
linked libraries and concrete targets; none exceeded the limit. The late guard
edits require refreshed sizes, particularly for InFacet and its dependents.

Latest measured individual operations:

- Composition planner: **6,666,055 / 6,589,112 gas**, two directions in the core fixture.
- Proxy composition: **7,216,828; 7,409,328; 7,592,285; 7,429,526 gas** over four
  successive 18/18 deposits.
- Holder repair: **54,617,528 gas** for the donation/repair fixture. This remains
  a material production-cost concern, not resolved by the green hermetic test.
- Real forward traversal has a passing multi-step fill below the 64-step ceiling;
  an unfinished 64-step trial is rejected as a completed fill.
- Composition refinements stop on a passing relative-protection candidate and
  still evaluate final endpoints; the ceiling remains 32. Repair retains at most
  32 refinements per direction across its funding domains and reports evaluated
  work. No timing or cumulative trading restriction was added.

Test totals that include setup, preview plus execution, repeated actions, exhaustive
reference enumeration or hook-address mining are **not single product-transaction
gas measurements**. No live-chain transaction-gas feasibility was established.

### Coverage established and remaining requirements

Established by the executed suites: independent carry/large-product and 1,472-bit
rational controls; F0 decimal/minimum controls; exhaustive small F1 minimal-inverse
checks; F2 radical counterexample and entitlement arithmetic; actual core fee and
signed-liquidity settlement; first-step exact-output boundaries; live protocol-fee
splitting; nonzero CC; R8 preservation when composition certification fails; repeated
composition and full-state transition parity; SE/SY equivalence; native/WETH booking;
all eight requested decimal combinations; prior fees, donations, pull/push and refund
attribution; real outer unlock and a real consuming-hook callback; token reentrancy;
unauthorized callbacks; disabled-inbound exit preservation; import/full-range
conversion; fixed diagnostics; occupied package-binding mismatch; 43 interface-derived
H/native-SY selectors installed on registry proxies; remaining query/reward-selector
smoke calls; runtime and work checks.

Parent-owned remaining work, **not silently passed**:

1. **Immediate H gate:** refresh the three late guard sources, execute the new
   bootstrap regression and the entire current H suite, rerun artifact identity/size
   checks, and record the resulting source manifest. Last full tests were 94/94,
   but current-tree artifact acceptance is stale as explained above.
2. **Production liveness:** evaluate the 54.62M holder-repair cost against the target
   chain's applicable transaction/block limits; optimize if required without changing
   the approved protections or exact-output domains. Test gas allowance is not evidence
   that this transaction fits production.
3. **Explicit coverage still not demonstrated here:** constructor-time and EIP-7702
   pretransfer-wallet cases; a dedicated production-chain constructor rejection case
   for a wrong manager; the full blocked-SY and native-NFT-import cross-product; and
   a long stateful cross-mode invariant campaign. Existing tests cover ordinary EOA
   rejection, code-bearing callers, occupied binding mismatch, idle native SY,
   ERC20 NFT import, blocked SE routes and targeted cross-mode cycles. Do not equate
   those with the missing scenarios.
4. P-family implementation/acceptance and consumer migration are the parent's next
   phases. Only H InventoryMath, ProtectionMath and RouteTypes are approved for P
   reuse; do not import H Common, QuoteService, TransitionPlanner, facets or delegates.
   Shared-helper changes require a fresh H gate, including the narrow size margin.
5. The later combined audit-submission/readiness record and human removal gate remain
   unmet. No legacy deletion, commits, broadcasts or live actions occurred.

No five-agent review-work pass or completed security audit is claimed. The two
reported Oracle arithmetic/certificate findings were fixed and regression-tested.

### Exact edit boundary

The checker's `files` array enumerates every authored Solidity/Python path and hash.
All H production/interface/TestBase/harness files are under
`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`, with
the section-7 full prefix `UniswapV4FullSpreadHooklessStandardExchangeVault` and the
corresponding `I`/`TestBase_` prefixes. Additional local test infrastructure is
`test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol`
and `test/harness/UniswapV4FullSpreadHooklessStandardExchangeVaultConsumingHook.sol`.

Acceptance files under the corresponding `test/foundry/spec/.../hookless/` root:
`AdmissionAndIdentity.t.sol`, `Adversarial.t.sol`, `AdversarialReentrancy.t.sol`,
`AttributionAndBooking.t.sol`, `BlockedFormulaReference.t.sol`, `ConsumingHook.t.sol`,
`CoreSettlement.t.sol`, `EquivalentInterfaces.t.sol`, `FormulaDomains.t.sol`,
`MaintenanceProgress.t.sol`, `NativeSettlement.t.sol`, `NestedAndConsumer.t.sol`,
`OneBackedLeg.t.sol`, `PositionImport.t.sol`, `ProtectionAndInventoryMath.t.sol`,
`QuoteExecutionParity.t.sol`, `RuntimeAndWork.t.sol`, `ZapAndPlacement.t.sol`.

Other authored files: this execution-status document,
`scripts/check-hookless-artifacts.py`, and `scripts/run-hookless-acceptance.py`.
Pre-existing dirty/untracked work, generic NativeStandardYieldTarget, both legacy
families and the unadopted candidate were preserved. The integration subagent
reported using system `patch` because its environment lacked `apply_patch`; parent
edits used `apply_patch`. That tool deviation is recorded rather than hidden.

**Artifact-writer handoff:** the H detached worker exited and released its lock.
At handoff only Pons `forge-lsp` compiler processes were observed; those were not
terminated. The parent may schedule the next serialized build after those exit.
