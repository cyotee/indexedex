# Rebasing-aware ERC4626 production review

Date: 2026-09-13. Release: `indexedex.rebasing-aware-erc4626.sy-se.v1`.

Status: wrapper release campaigns and the full hermetic repository gate passed.
No known unresolved defect remains from this review. The 20 broader DETF failures
were fixed in the [subsequent remediation](../../../vaults/detf/protocols/dexes/uniswap/v4/detf/UNISWAP_V4_DETF_RELEASE_GATE_REMEDIATION.md): **31,534 tests passed,
zero failures or skips**, plus three release fuzz/invariant campaigns.
This is not an unconditional public-deployment sign-off.
This review does not authorize or perform a public deployment or staking migration.

## Scope

Reviewed the production registry-deployed ERC4626/SY/SE diamond, shared accounting,
settlement and reentrancy boundaries, public static-share withdrawal prepayments,
fee exemption, quote projections, package declarations, and the approved static
wrapper-share buffer integration. The custody-wrapper and staking-migration design
remain unchanged. Other agents' artifact-loading changes remain in the workspace.

The approved behavior is retained: asset-input SE prepayments always revert;
share-input SE withdrawals burn the required amount and refund excess snapshotted
shares to the caller; SY internal redemption leaves excess shares in the vault.
There are no wrapper fees or reward tokens. Execution rejects zero input/output;
zero-amount previews return zero. Outstanding shares prevent new deposits at zero
backing until backing is restored externally. Share decimals retain the minimum
+10 offset. Transfer-triggered rebases fail closed; settled rebases are supported.

## Defects fixed

| Finding | Resolution and regression evidence |
|---|---|
| Share-issuing routes could mint to the zero address after taking payment | Validate the receiver in the shared deposit/mint paths; all five entry routes reject it without changing economic state. The vault itself remains a valid share receiver. |
| SE receiver validation occurred after deadline/prepayment checks | Validate the receiver at the specified point before those checks, including rejection of the vault itself as an asset-output receiver. |
| `totalAssets`, `reserves`, and `reserveOfToken` exposed unsettled backing during token callbacks | Apply the same read lock as conversion/rate views. Callback probes require the exact `IsLocked()` error. |
| Projected asset additions and share receipts could panic on arithmetic overflow | Check remaining capacity by subtraction; return `NumericDomainExceeded()` or `InvalidQuoteState()` as appropriate. |
| The rate-quote facet was installed without advertising its interface on the proxy | Include `IStandardExchangeRateQuote` in package ERC165 declarations. |
| Direct registry deployment could bypass the helper's contract-code check for the asset | Validate asset code in package `processArgs`, preserving the existing zero-asset error. |
| Active weighted, Curve, and Balancer stable buffer facets exceeded the EIP-170 runtime limit | Move the existing rated-inventory calculation into each family's existing linked claim library. Preserve math, rate-provider validation, storage context, and public selectors. |
| Stage 06-10 treated six live saved addresses as proof of the current release | Verify current creation-code-derived CREATE3 addresses, constructor dependencies, release ID, fingerprints, and registry membership before skipping. Wrong live facets/packages and stale fingerprints fail freshness checks; rerunning restores the current deployment record and reuses its package. |

The pre-fix regression run and post-fix run are preserved under
`.scratch/rebasing-production-review-20260913/`. The initial focused suite passed
140 tests despite the newly reproduced defects; that initial pass alone was not
sufficient release evidence.

## Test corrections and additions

- Replace the weak standalone invariant with two real registry-deployed vaults,
  four holders including an attacker, a separate receiver, independent asset/share
  ledgers, all ten money routes, both public-share withdrawal modes, approvals,
  paid donations, positive/negative rebases, complete loss/recovery, registry
  controls, and nonzero manager fee settings. Require successful route coverage.
- Remove broad exception swallowing from the composed buffer invariant. Track
  attempts, successful operations, and skipped inputs; unexpected errors fail.
- Add a real DETF composition invariant using a rich 100× opening and 10% annual
  closure. Exercise wrapper deposits, DETF mint/redeem cycles, donations, loss,
  time advance, actual funded expansion, and reward settlement. Reconcile wrapper
  backing and custody; check fixed staking ownership and backing of sDETF claims.
- Add fuzz properties for every money route at changed backing, decimal/rate
  quantization, exact limit failures and rollback, multi-holder loss/recovery,
  exact-output public prepayment refunds, all zero-value routes, and inflation
  attempts that debit the attacker's own donation budget.
- Check all Python arbitrary-precision vectors against production quote facets,
  including vectors with 512-bit intermediate products. Retain zero-output quote
  semantics separately from execution's zero-output rejection.
- Correct the purported outbound transfer-tax test: fund with tax disabled, then
  enable tax and reject all five withdrawal routes, checking burn/refund rollback.
- Verify exact canonical ERC4626 Deposit/Withdraw events on all ten routes, plus
  the additional SY Deposit/Redeem events only on SY routes.
- Probe all ten nested money routes from both inbound and outbound callbacks
  through every outer money route, requiring the exact shared-lock error.
- Compare all six facets' function declarations against compiler ABI signatures,
  validate `Behavior_IFacet` metadata, check every loupe destination and advertised
  interface, and reject unknown selector/interface discovery.
- Preserve minimized seed-1 regressions for a 5,803-unit buffer share join and a
  `1e20` wrapper-share DETF mint below their outer protocol's issuance precision.
  Require their exact rejection errors and economic rollback. Successful composed
  route generators use amounts above those outer precision floors.

The installed `forge fmt` also removed braces from compact multi-statement `if`
blocks and changed their control flow. A minimal reproduction is saved as
`.scratch/rebasing-production-review-20260913/FormatRegression.sol`. The affected
new test blocks were restored as explicit multiline blocks; runs with that
formatter damage are failures, not release evidence. Successful-coverage checks
detected the otherwise silent skipped operations.

## Validation evidence

Compiler: Solidity 0.8.35, optimizer enabled with one run, `via_ir=false`.
The default profile, source paths, artifact directory, and cache were retained.
Runtime artifacts were refreshed through `scripts/forge-artifacts.py`; no SUT
vaults, facets, registry, manager, buffers, or DETFs were mocked.

Release configuration: 10,000 fuzz runs per property; 1,000 invariant runs at depth
100 with `fail_on_revert=true`. Recorded seeds are 1, 17, and 257, represented as
32-byte hex values ending `01`, `11`, and `0101`. Commands, resolved configuration,
stdout, and process results are under `.scratch/rebasing-production-review-20260913/`.

### Completed gates

| Gate | Result | Evidence under `.scratch/rebasing-production-review-20260913/` |
|---|---|---|
| Full default build | Passed | `full-build.log` |
| All runtime deployment artifacts | Passed | `all-runtime-artifacts.log` |
| Stage 06-10 package and Stage 07-02 custody scripts compile | Passed | `launch-script-build.log` |
| Wrapper focused suite before final event addition | 158 passed, 0 failed | `final-focused.log` |
| Release seed 1 | 27 passed, 0 failed | `release-1.log` |
| Release seed 17 | 27 passed, 0 failed | `release-17.log` |
| Release seed 257 | 27 passed, 0 failed | `release-257.log` |
| Full hermetic repository run | 31,503 passed, 22 failed, 0 skipped; 2,722 suites | `full-hermetic.log` |

Each release campaign contains 19 fuzz properties at 10,000 runs (570,000 total
cases across the three seeds), six invariants at 1,000 runs and depth 100, and two
deterministic outer-precision regressions. Each invariant reports 100,000 calls
and zero unexpected reverts per seed. These are successful final runs after the
handler corrections, not the archived failed attempts. `release-config-*.json`
records the exact command and resolved configuration; `release-results.json`
records process exit status and timing.

The first broad invocation stopped before testing because setting
`FOUNDRY_ETH_RPC_URL` to an empty string caused this Forge version to request a
filesystem fork. Unsetting RPC environment variables resolved that runner error;
the completed hermetic result above is the rerun. No RPC credentials were printed.

### Initial broad-gate findings outside the wrapper (resolved)

The full run found two additional issues fixed in this review: the Balancer
stable buffer liquidity facet measured 24,801 bytes, and the Quad D15 unstaking
fixture required only a price above 1.0 while its actual mint threshold was 1.05.
The buffer uses the same calculation-to-existing-library extraction as the other
families. Its component FactoryService now passes the CREATE3 factory to the
artifact loader so the new library references are deterministically deployed and
linked; a first follow-up correctly failed closed until that wiring was added. The shared D15 fixture now requires price above `mintThreshold()` before
asserting expansion is due. The final follow-up passed both regressions, with all 550 selected tests green.

Twenty other failures were initially outstanding outside the rebasing-wrapper
implementation. All are now resolved; see the [remediation report](../../../vaults/detf/protocols/dexes/uniswap/v4/detf/UNISWAP_V4_DETF_RELEASE_GATE_REMEDIATION.md).
The initial findings were:

- Sixteen in `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol`:
  `test_boundaryStakeParticipationAndLateEntryOrdering` and
  `test_standardFallbackSettlesFundedCatchupBeforeBothDirections`, across CP,
  weighted, orbital, and Curve quad public/restricted fixtures. These configure
  a `100e18` mint threshold and expect funded expansion after a reserve-yield
  injection. The assertions receive zero pending expansion. Their setup and
  expectations were reconciled with threshold-gated automatic expansion.
- Four in the Orbital/Univ3 SE decimal compositions: lifecycle `test_H_OR_GV3_close`
  and product-law `test_postMaturity_claimPaysFundedStaking`, each for `B_ALL9` and
  `B_P9_R6`, reverted. The follow-up traced gas exhaustion to repeated reserve
  valuation after expansion epochs had already been consumed.

The initial failures remain recorded as failures, not waived or relabeled as
pre-existing. The follow-up fixed the epoch-valuation defect and the fixture
prerequisites, added direct-claim gas regressions, and reran the full repository
gate successfully. Its evidence supersedes the initial blocked readiness result.

### Runtime size measurements

All listed deployed components are below the EIP-170 limit of 24,576 bytes using
the recorded compiler settings. These measurements cover active components, not
obsolete combined facet artifacts left in the warm artifact directory.

| Component | Runtime bytes |
|---|---:|
| Rebasing ERC4626 facet | 10,552 |
| Rebasing SE facet | 9,961 |
| Rebasing SY facet | 10,318 |
| Rebasing metadata facet | 3,117 |
| Rebasing quote facet | 7,555 |
| Rebasing package | 8,615 |
| Weighted JoinFlexible facet | 24,171 |
| Weighted Join facet | 24,262 |
| Weighted Hooks facet | 24,037 |
| Curve JoinQuery facet | 24,058 |
| Curve Hooks facet | 24,411 |
| Balancer stable Liquidity facet | 24,131 |
| Weighted / Curve / Balancer claim libraries | 5,446 / 5,923 / 5,808 |

Raw measurements are in `component-sizes.json`. Recompiling with different settings
or adding code requires checking sizes again, especially the Curve Hooks facet.

### Final follow-up and readiness boundary

The final artifact-aware rebuild and regression run passed **550 tests, zero
failures, zero skips, across 59 suites**, including all **159 wrapper tests in
23 suites**, the full Balancer stable buffer family and its native SY surface,
and all selected D15 unstaking suites. `final-followup-command.json` records the
exact command, `final-followup.log` contains results, and
`final-followup-result.json` records exit code 0. This verifies both late fixes
from the full hermetic run; its original 22 failures are therefore reduced to the
20 initially outstanding broader failures listed above. The separately authorized
remediation then resolved all 20 and reran the entire broad suite successfully.

The final follow-up also exercised the wrapper with `fail_on_revert=true`.
The three high-volume release campaigns preceded only the additional event test,
Balancer buffer library extraction/linking, and D15 test-fixture correction;
those late changes do not change the wrapper, CP buffer, weighted buffer, or
DETF production implementations used by the release campaigns. The later DETF
epoch-valuation fix has its own three-seed release campaigns and full-gate evidence
in the remediation report.

No public transactions, Anvil restart, staking migration, or fresh-chain launch
rehearsal occurred during this review. The reviewed wrapper is ready to proceed
to the planned local deployment rehearsal. Public deployment still requires
validating the actual deployment configuration, existing factory authorization,
and migration on the fresh fork.
The user's explicit agreement to public deployment remains required.


## Follow-up: local migration rehearsal completed 2026-09-13

The reviewed wrapper was deployed through the existing core on a fresh Robinhood
fork and used as the 28-decimal DTF custody leg. All five deployed facet runtimes
matched the reviewed build. Native staking migration completed in 59 transactions,
converting deposits and rewards together and leaving zero DTF in Wrapped staking.
User claims and delayed SY redemption passed on a disposable fork. A separate
deployment-gas issue was fixed in the shared launch stage by predeploying the
deterministic bond NFT child; the DETF and wrapper bytecode were unchanged.
See [the completed rehearsal report](../../../../docs/FEE_ACCRUAL_DETF_REHEARSAL_2026_09_13.md).
