# FullSpread Pons family execution status

## Final bounded family acceptance handoff (2026-09-28)

**Family acceptance is green for the recorded sources. The artifact writer is
returned to the parent for consumer validation. This is not audit readiness or
permission to remove legacy sources.** No consumer gate was run by this handoff.

Production P lives under
`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`
with the exact `UniswapV4FullSpreadPonsFamilyHook` prefix. It has its own package,
facets, targets, delegates, quote service, planner, callback and execution context.
Its only H economic-source imports are the three approved pure helpers/types.
The package fixes production manager/hook identities to `ROBINHOOD_MAIN`; P quotes
decode registered launch terms and preserve separate fee/tax floors, exact-input
output charging and exact-output input-debt charging. No runtime-codehash gate,
unknown-hook fallback or numerical exact-output inverse was introduced.

## Executed results

| Gate | Result |
|---|---|
| Historical combined family gate before optimization/new acceptance | H 95 + P 118 = 213 passing tests; historical only |
| Gas worker's optimized family gate before these new cases | 239 passing tests / 57 suites |
| Final refreshed complete family root, including new cases | **270 passed, 0 failed, 0 skipped / 68 suites** |
| Strengthened stateful campaigns | **128 fuzz inputs per family, 32 actions per input: 4,096 steps per family, 8,192 total; both passed** |
| H artifact identity/runtime checker | Exit 0, no failures |
| P artifact identity/runtime checker | Exit 0, no failures |
| New Solidity files and Python validation helpers, LSP error diagnostics | No errors reported |

The first 270-test run and initial 128-run campaign also passed. Read-only review
then identified opportunities to strengthen campaign references, so that helper
was updated and **both the 128-run campaign and full 270-test gate were rerun**.
The final results above include those changes, not just the earlier weaker checks.
There were no production-code changes in this acceptance-closure pass.

Solidity 0.8.35, optimizer runs 1, normal hermetic profile and no via-IR were
preserved. `--no-cache` forced fresh test compilation to avoid the previously
observed cached-library linking mismatch; no cache directory was cleared and no
compiler/profile/path setting was changed. Compiler warnings include future use
of `error` as an identifier and shadowed test locals; they did not prevent builds.

### Durable local logs

Base directory:
`/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/`

| Directory | Evidence |
|---|---|
| `fullspread-family-yso91cmd/` | First full 270-test gate and both artifact checks |
| `fullspread-family-y8b1k7tb/` | Initial 128-run campaigns, before reference strengthening |
| `fullspread-family-k8degvt0/` | Final strengthened 128-run campaigns and artifact checks; finished 2026-09-28T22:17:02Z |
| `fullspread-family-n76462kp/` | Final full 270-test gate and current artifact checks |

Each directory contains `output.log` and `result.json`, including exact invoked
commands, elapsed time and command exit codes. All workers exited and results
were collected. No running compile was killed.

## Coverage added in this pass

The 15 new Solidity files comprise three generic test-only reference bases,
three family-local fixture/probe files, and nine regression files. They add
**31 executable cases**, including inherited native variants, to the prior 239.

| Area | Evidence |
|---|---|
| H pretransfer caller lifecycle | Constructor-time guard rejection; real EIP-7702 delegation plus fresh-credit success and booked-inventory reuse rejection |
| Blocked SY, both families and native variants | Both input/output directions; deposit and external redemption agree with SE on restored state; internal redemption retains surplus self-shares; funded shortage reverts exactly and rolls back; later successful operation verifies usable state |
| Native NFT import, both families | Real PositionManager mint paid with ETH and Permit2 tokens; independent control withdrawal measures actual NFT funding; donated pre-existing WETH/token sleeve does not increase caller issuance; exact dead-sink shares; retained empty NFT custody; nonzero full-range position; booked balances and zero ETH remainder; late minimum-output rollback |
| Production constructor bindings | Fresh full-name probe identities execute unchanged production constructors through the registry path; failed construction does not register a package; hermetic positive control proves usable bytecode/components and unoccupied identity |
| Cross-mode stateful campaigns | 32 sequential actions with no state restoration between steps; exactly four visits to each of eight modes; randomized amounts/directions; real H proxy and genuine P launch/graduation proxy |

Campaign reference checks include core-derived slot0, full-range bounds, owned
liquidity and fee growth; independent F1 forward/minimal-inverse arithmetic;
post-swap proportional minting from observed core settlement, original-holder
backing and signed placement rounding; pro-rata withdrawal/conversion entitlement;
separate Pons fee and creator-tax ledgers computed from core Swap events; exact
token custody conservation; a passive incumbent's share ledger; supply/caller
mint-burn reconciliation; final reserve snapshots; and failure-state fingerprints.
Production previews are also checked, but are not the sole expected amounts for
those economic assertions. No production family planner/math helper supplies the
campaign's expected issuance or payout.

Modes 0-5 require positive execution. Mode 6 attempts scalar exact-output and
accepts only its defined `InvalidRoute` domain failure, with matching execution
failure and atomicity; dedicated FormulaDomains/CoreSettlement suites establish
nonzero exact-output successes. Mode 7 deliberately tests false pretransfer
rejection. Attempt counters are not mislabeled as successful executions.

### Explicit construction/coverage limits

- P's chain-4663 constructor test proves rejection of a local launch hook/manager
  binding. The canonical hook check occurs before the manager-address pin; it
  does **not** isolate that later branch. A separate genuine-hook/different-real-
  manager test covers manager mismatch. This combination evidence is accepted
  for this bounded handoff; no fake canonical hook, code injection or live RPC
  requirement was introduced.
- Blocked-SY failure tests bubble the failure through the whole outer unlock,
  verify atomic rollback before restoring snapshots, and then execute again.
  They do not claim catch-and-continue testing within one surviving unlock.
- The delegated-wallet case establishes code-bearing caller classification and
  real credit, not every wallet implementation's atomic funding workflow.
- Campaigns are 32-step stateful fuzz tests, not a proof over all possible pool
  states or an exhaustive handler invariant suite. Fixture arithmetic ranges are
  bounded; existing independent wide-arithmetic tests cover larger products.

## Runtime and gas

Every reported production runtime remains at or below 24,576 bytes. Tightest
facets remain H OutFacet **24,571** and P OutFacet **24,540** bytes. Future production
edits must retain the runtime gate.

The final full gate reproduced the optimized heavy repairs: H **19,795,187** and
P **20,373,933** execution gas. The retained gas-worker matrix enforces less than
28M and recorded worst repair **22,884,791**, worst automatic maintenance
**21,681,900**, against the supplied 32M mainnet transaction cap. See the combined
execution status for the matrix and RPC provenance. This supersedes this worker's
historical 54.47M P repair blocker; it is not a universal upper bound.

Campaign suite-total gas includes 32 operations plus independent references and
assertions. It is not a single production transaction gas measurement.

## Source identities and reproduction

The worktree's supplied baseline is
`b019f232a1a109868da81be2d81f94d00a8a0be7`; it is not the identity of uncommitted
implementation changes. The final artifact reports include per-file SHA-256
hashes and check current production-source keccak identities against compiler
metadata. Final source-manifest SHA-256 values:

- H: `5253edf4d196b43358fd2c0292cd2652cb355ae948c8142e0562d2e5e41e5bd6`
- P: `92710ced093ee772ce64126f5d0457b19c6ad4b40d809cd1c6689baf5f51b852`

P's final manifest additionally includes the three shared acceptance-reference
bases and validation scripts. Its value therefore differs from the earlier
campaign report's manifest without requiring a production-source change.
Markdown status records are outside these code manifests.

```bash
python3 scripts/run-fullspread-family-acceptance.py
# Wait for this worker's result.json and real process exit before the next writer.
python3 scripts/run-fullspread-family-acceptance.py --campaign
```

The runner serializes through the existing lock, waits for diagnostic compilers,
refreshes both families' artifacts with `scripts/forge-artifacts.py`, selects only
the full family test root, and checks H/P artifacts afterwards. Campaign mode uses
`--match-test testFuzz_crossModeStatefulCampaign --fuzz-runs 128`. Both modes use
`-vv --no-cache`. No consumer tests are selected.

## Remaining parent-owned gates

Consumer migration/build/regressions, combined readiness review, the human legacy
removal checkpoint, and final post-removal validation remain pending. Nothing in
this record authorizes legacy deletion, deployment, live registry changes,
commits, broadcasts, or a claim of completed security audit. Those gates must use
their own final source/artifact identities after further edits.
