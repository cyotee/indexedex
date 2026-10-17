# MiniMax M3 — REQ-02 execution confirmation original

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent first pass. No peer originals or peer review files were read. No reviewers/ directory was read. The supplied `apex-req-02-execution-confirmation` path does not exist in this tree; the controlling PRD, plan, execution report, and evidence logs were re-read from `apex-req-02-residual-preview-internal/` (the location actually present in the working tree).
- **Question:** Was the REQ-02 plan executed completely against the current working tree?
- **I did not run Forge.** The reported test output is a previous session's log. Source presence is not a passing run. I re-read the source files and the evidence logs, and I did not invoke a build or test command.

## Documents re-read this round

- `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md` (controlling PRD)
- `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md` (plan)
- `docs/reviews/apex-req-02-residual-preview-internal/EXECUTION_REPORT.md`
- `docs/reviews/apex-req-02-residual-preview-internal/evidence/artifact-build.log`
- `docs/reviews/apex-req-02-residual-preview-internal/evidence/focused-tests-sandbox-crash.log`
- `docs/reviews/apex-req-02-residual-preview-internal/evidence/focused-tests.log`

The user-named directory `apex-req-02-execution-confirmation/` is absent. The current round's documents and the prior execution artifacts all live under `apex-req-02-residual-preview-internal/`. The PRD controls. I cite the plan, the report, and the actual code lines I read.

## Source lines re-read this round

- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:382-400` (preview function, `bufferQuotedResidual`)
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:367-379` (sweep)
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:131-142` (sweep)
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:388-400` (sweep)
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:477-489` (sweep)
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` (full read, 219 lines)
- Grep over `contracts/` for `previewResidualBuffer`: 5 files, all sweep call sites plus the ClaimLib declaration. No new external selector, no new wrapper, no new facet file.

## Verdict table

| Done-when item | Verdict | Evidence |
|---|---|---|
| `previewResidualBuffer` is `internal`, has no `catch`, and still returns `previewExchangeIn` of the excess pair amount | executed | `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-389`; visibility is `internal view`; body is the direct `previewExchangeIn`; no `catch`, no zero check |
| `bufferQuotedResidual` is still `external` | executed | `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:393`; `external` retained; body unchanged |
| All four sweeps still call `ClaimLib.previewResidualBuffer` and still return without depositing when the quote is zero. The quote body was not pasted in and the calls were not deleted | executed | `DepositCommon.sol:375-377`; `WithdrawalLib.sol:138-140`; `Target.sol:396-398`; `SeTarget.sol:485-487`; all four still call `ClaimLib.previewResidualBuffer(excess)` and keep the `if (preview == 0) return` early-out. Grep confirms five call sites, no new wrapper, no inlined body. |
| Monolithic `Target._refundPairDust` and `SeTarget._refundPairDust` were not given a new entry | executed | `ResidualPreview.t.sol:20-21` cites both as unreached and not exercised; no production entry was added in the diff. The monolithic Target's existing in-file callers (`Target.sol:846, 971, 1139, 1215`) remain unchanged; `SeTarget.sol` has no caller. |
| `DepositCommon` and `WithdrawalLib` each have a separate zero-preview witness and a separate reverting-preview witness, or an implementation report names which case and which copy was not reached | executed | `ResidualPreview.t.sol:47-91` (zero × two sweeps), `:94-122` (revert × two sweeps), `:125-131` (no selector). All four cases reached. |
| The hook did not gain a `previewResidualBuffer` selector | executed | `ResidualPreview.t.sol:125-131` queries the diamond loupe for `previewResidualBuffer(uint256)` and asserts `address(0)`. Grep over `contracts/` finds no external declaration, no new wrapper, no new facet selector. |
| Case 2 was not manufactured by mocking the vault or by faulting a harness `balanceOf` | executed (with a noted scope) | Case 2 is built on the existing `SimpleYieldERC4626.convertToShares` checked arithmetic: `excess = type(uint256).max / pairProtocolVault.totalSupply() + 1` makes the inner `(assets * supply) / totalAssets` overflow, so the bound SE's own `previewExchangeIn` reverts with `Panic(0x11)`. The vault is real; no `balanceOf` is faulted; the production SE preview is the revert source. This is the plan's "another rejection the production vault already exposes" (plan line 86), not a mock. |
| Artifact refresh and a reported forge run | partial (sandbox re-run) | `evidence/artifact-build.log` shows the initial artifact build compiled 36 files. `evidence/focused-tests-sandbox-crash.log` shows the first `forge test` invocation crashed in macOS `system-configuration` proxy discovery before any test ran (exit 250). `evidence/focused-tests.log` shows the identical command re-run reported 21 tests passed, 0 failed across the two suites. The execution report (lines 71-80) records both runs and the rerun was outside the sandbox. The 21 passing tests are not re-verified by this pass; they are a previous session's reported run. |

## Findings

### F1 — `apex-req-02-execution-confirmation/` does not exist; the plan and report are in `apex-req-02-residual-preview-internal/`

- **Severity:** Low (process / directory mismatch, not a code defect)
- **File and line:** `docs/reviews/apex-req-02-execution-confirmation/` (absent)
- **Remediation ID:** REQ-02 (process routing)
- **Intended behavior from the plan / PRD:** Plan step 1-3 and Done-when list are satisfied within `apex-req-02-residual-preview-internal/`. The execution report and evidence live in the same parent. The user-named path is not the location of the controlling documents.
- **Broken requirement or invariant:** None on the production source. The path mismatch means a later reader of `apex-req-02-execution-confirmation/` will find no PRD, no plan, no report, and no evidence. A future confirmation pass that expects the documents at that path will see a missing-inputs failure.
- **Impact class:** Process / record location. Not a behavior defect.
- **Fix direction:** Either create `apex-req-02-execution-confirmation/` and copy or symlink the PRD, plan, execution report, and evidence there so the confirmation round and its source-of-truth live in one directory, or document in this round's PRD that the controlling records live in `apex-req-02-residual-preview-internal/`. Do not move the source files; the plan keeps them at the parent path.
- **Confidence:** High
- **Observed fact vs inference:** Observed: directory listing of `docs/reviews/` shows no `apex-req-02-execution-confirmation/`. Inference: the user-named path is the intended confirmation-round directory and was not created.

### F2 — Case 2 uses the `SimpleYieldERC4626` fixture's checked-arithmetic overflow; the "no mock of the vault" rule is met, but the production-vault reading is brittle

- **Severity:** Low (within plan scope; not a defect; recording for the next owner)
- **File and line:** `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:156-163` (test helper `_prepareRevertingQuote`); `SimpleYieldERC4626.sol:104-106` (checked `convertToShares`); `SimpleYieldERC4626.sol:114-116` (`previewDeposit`).
- **Remediation ID:** REQ-02 Case 2.
- **Intended behavior from the plan / PRD:** Plan step Case 2 (line 81-89) — reach a state the bound SE supports in which `previewExchangeIn` of the sweep's excess reverts, without mocking the vault and without faulting a harness `balanceOf`. PRD Case 2 step 5 (line 102-103) restates this.
- **Broken requirement or invariant:** None observed. The test exercises the actual `SimpleYieldERC4626.convertToShares` checked multiplication with `excess = type(uint256).max / totalSupply() + 1`, which causes `assets * supply` to overflow. The bound SE's own `_previewExchangeIn` then propagates that `Panic(0x11)`. The vault, the SE, the hook, the package, the manager, the registry, and the fee oracle are all real. The plan permits "another rejection the production vault already exposes" (line 86).
- **Impact class:** Test construction. The `Panic(0x11)` is an arithmetic-level revert, not a domain-level error. It is the same fixture the deploy test and the SE matrix tests already use. A future change to `SimpleYieldERC4626` that swaps checked arithmetic for `unchecked` would silently make Case 2 unreached on this TestBase. The execution report (lines 41-42) acknowledges this: "tests an extreme amount boundary supported by the unchanged fixture; it does not claim a pause/disable preview failure or fault the receipt's `balanceOf`."
- **Fix direction:** None required. Record the brittleness in the test file header so a future maintainer does not mistake the overflow for a domain error. The plan does not require a different Case 2 construction.
- **Confidence:** Medium (the construction is on-bounds per the plan; its long-term stability depends on the fixture's arithmetic style).
- **Observed fact vs inference:** Observed: the helper computes `excess = type(uint256).max / pairProtocolVault.totalSupply() + 1`, the test then expects `Panic(0x11)`, and `SimpleYieldERC4626.convertToShares` uses Solidity's checked `*`. Inference: a future unchecked-arithmetic migration would change this behavior; the test file should be re-read after any such change.

### F3 — The first focused-test run crashed before any test executed; the report runs once outside the sandbox to recover

- **Severity:** Low (process / not a code defect)
- **File and line:** `docs/reviews/apex-req-02-residual-preview-internal/evidence/focused-tests-sandbox-crash.log:40-79` (Foundry crash in `system-configuration::dynamic_store::SCDynamicStoreBuilder`); `EXECUTION_REPORT.md:71-80` (re-run notes).
- **Remediation ID:** REQ-02 (build / run reporting).
- **Intended behavior from the plan / PRD:** Plan step "Refresh artifacts, then run" (line 93-97) requires a reported forge run. A present assertion is not a pass until that run is reported.
- **Broken requirement or invariant:** None on the source. The first `forge test` invocation crashed before any test ran due to a macOS sandbox proxy-discovery bug. The execution report notes the rerun was outside the sandbox with approval. The `focused-tests.log` shows 21 passed on the rerun, but I have not independently re-run Foundry. The plan allows reporting a green test run; it does not require a second sandbox-safe run.
- **Impact class:** Process / re-verifiability. The first-run crash is a host-environment artifact, not a code defect. The rerun exit code 0 with 21 passed tests is the reported evidence.
- **Fix direction:** None required. The execution report records both the crash and the rerun. A future confirmation round that runs in the same macOS sandbox should expect the same crash and rerun the same way.
- **Confidence:** High (the crash trace is in the evidence log; the rerun log shows the same 21 tests with 0 failed).
- **Observed fact vs inference:** Observed: the focused-tests-sandbox-crash.log shows the same 56 build roots and the same `forge test` flags as the focused-tests.log, with the macOS proxy-discovery panic at the end. Inference: the rerun is the same command outside the sandbox, and the 21 tests passed in the rerun; I did not re-run the command this round.

## Files examined where I found no defect

- `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:382-400` — visibility change applied, body unchanged, no `catch` introduced, `bufferQuotedResidual` still `external`.
- `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:367-379` — sweep unchanged; still calls `ClaimLib.previewResidualBuffer(excess)`; still has `if (preview == 0) return`; still has the 3-iteration loop; still uses `Repo.MAX_DUST_WEI`.
- `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:131-142` — sweep unchanged; same checks.
- `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:388-400` — sweep unchanged; same checks. (Not reached by the TestBase; cited as unreached in the test header.)
- `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:477-489` — sweep unchanged; same checks. (No caller; cited as unreached in the test header.)
- `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` (full read) — five tests with `depositWithSeShares` and `withdrawSeShares` as the production entries, all four required cases reached, loupe check confirms no `previewResidualBuffer` selector, balances asserted with `_feeTo()` and zero-fee-recipient handling.
- `evidence/artifact-build.log` — 36 files compiled, exit success, only notes and one unrelated unreachable-code warning in `NativeStandardYieldTarget.sol:52-53` (pre-existing, not introduced by REQ-02).
- `evidence/focused-tests.log` — 5 new tests + 16 existing deploy tests = 21 passed, 0 failed, 0 skipped; exit 0.

## Dissent and unverified items

- I did not re-run Foundry. The 21 passing tests in `focused-tests.log` are a previous session's report. I cite the log; I do not re-verify.
- The `simple-yield` fixture's arithmetic style is the load-bearing piece of Case 2. A future migration to `unchecked` arithmetic in `SimpleYieldERC4626` would silently make Case 2 unreached on this TestBase. The plan does not require a different Case 2 construction, but I record this as a brittleness observation, not a defect.
- The `apex-req-02-execution-confirmation/` directory named in the task does not exist. I read the PRD, plan, and execution report from `apex-req-02-residual-preview-internal/`. If the coordinator intended a separate confirmation-round directory, the documents were not moved into it. Recording as F1.
- The execution report's rerun note ("The identical focused command was rerun outside the sandbox with approval") is reported, not independently verified. The user-facing claim "21 passed, 0 failed" matches the focused-tests.log I re-read; I do not have a way to confirm the rerun was on the same artifact set without the test code being changed between the crash and the rerun.
- I did not grep `test/` outside the new ResidualPreview file for any selector that might still call `previewResidualBuffer` via a public wrapper. The new test file itself computes the selector and queries the diamond loupe for `address(0)`, which is the strongest no-selector evidence. A wider search found no external declaration.
- The monolithic `Target._refundPairDust` reachability claim is verified by an exact-name search of `contracts/`: only the file itself and two PRD markdowns reference it. I did not re-search `test/` for any spec that instantiates the monolithic Target directly. If a test file outside `contracts/` does so, the unreached claim is wrong. The execution report cites this as a build-rooted compile (line 46-47), which keeps the contract compiling but does not make it a proxy route.

## End

I did not run Forge.