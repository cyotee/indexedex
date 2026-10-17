> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Legacy V4 architecture redesign — execution report

Status: **stopped at the required runtime-size gate; not release-ready**.
Date: 2026-10-15.

The production build succeeded. The IN facet is **28,818 bytes** (4,242 over the hard limit), and the OUT facet is **30,033 bytes** (5,457 over). [Step 7 of the plan](REDESIGN_PRD.plan.md) requires stopping when any family facet exceeds 24,576 bytes. No replacement delegate, self-call, selector split, optimizer change, or `via_ir` workaround was introduced. Tests were not run after this measurement.

## Implemented source changes

- Created the six internal libraries: Config, Accounting, Custody, PoolOps, Reserve, and Import. Existing repos and stored-reserve pretransfer credit are preserved; no storage slot was added.
- Added the single callback target/facet. Package cuts and facet addresses contain the specified sixteen entries in order. Other selector owners remain the same in the declarations.
- Removed both execution delegates, their constructor arguments and deployments, the SY import shim, Common/InBase/OutBase, and the unused OutTarget combiner. Removed imported-position growth helpers while retaining intake decrease/collect.
- Replaced preview self-calls with internal accounting calls. Share supply reads use ERC20Repo. Single-token exits share the same free-path settlement calculation, and burns use an explicit holder through Custody.
- Added disable checks at the legacy V4 SY deposit and redeem overrides. Existing guard call sites remain. The shared SY entrypoints became public/virtual to allow these internal overrides; their validation and execution bodies are otherwise unchanged apart from error namespace references.
- Extracted the five SY errors with unchanged signatures. V3, hookless, Pons, and other shim consumers have import changes only. Two test consumers use the new error namespace through an import alias.
- Updated TestBase deployment wiring. With the owner's explicit follow-up authorization, changed the IN declaration expectation and removed obsolete delegate-size assertions. Added the callback declaration suite and production-proxy architecture, disabled-SY, callback-caller, and no-self-call regressions. These tests are **not yet compiled or executed** by this run; the artifact build compiles production roots and discovers runtime dependencies from test consumers.

## Build and measurement

Forge **1.5.1-stable**, commit `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`; solc **0.8.35**. Default Foundry profile; optimizer enabled, **1 run**, `via_ir = false`, EVM `prague`. Configured paths remain `contracts`, `test/foundry/spec`, `out`, and `cache_forge`. No artifact/cache deletion or profile change.

The helper selected 129 production build roots, a 788-source import closure, and 58 runtime artifact IDs. Forge compiled 98 changed files; solc finished in **165.18 seconds**, with compiler success and warnings. The earlier compilation errors involving removed constructor references, explicit SY override bases, and extracted error namespaces were corrected before this successful run.

Executed wrappers:

```sh
python3 .scratch/legacy-v4-redesign/run.py plan
python3 .scratch/legacy-v4-redesign/run.py build
python3 .scratch/legacy-v4-redesign/sizes.py
```

The expanded helper arguments are preserved in [commands.sh](execution/commands.sh), [command-build.json](execution/command-build.json), and [sources.json](execution/sources.json). The build used `--consumer 'test/foundry/spec/protocol/dexes/uniswap/v4/**/*.t.sol'` to refresh test deployment dependencies before measurement. [Build log](execution/build.log), [compiler settings](execution/compiler-config.json), and [toolchain](execution/toolchain.txt) contain the evidence.

Runtime sizes below come from the fresh artifacts' `deployedBytecode.object` lengths, including metadata. They are artifact runtime measurements, not successful onchain deployments. Immutables/link substitutions retain byte length. The package has not been deployed by this run. [Machine-readable sizes](execution/sizes.json) and the [measurement script](execution/measure-sizes.py) are included.

| Cut | Facet | Runtime bytes | Result |
|---|---|---:|---|
| 1 | `ERC20Facet` | 3,164 | Below 23,000 advisory |
| 2 | `ERC5267Facet` | 1,447 | Below 23,000 advisory |
| 3 | `ERC2612Facet` | 2,173 | Below 23,000 advisory |
| 4 | `MultiAssetBasicVaultFacet` | 1,720 | Below 23,000 advisory |
| 5 | `MultiAssetStandardVaultFacet` | 1,747 | Below 23,000 advisory |
| 6 | `UniswapV4StandardExchangeCallbackFacet` | 4,441 | Below 23,000 advisory |
| 7 | `UniswapV4StandardExchangeInFacet` | 28,818 | STOP: exceeds 24,576 |
| 8 | `UniswapV4StandardExchangeInQueryFacet` | 19,673 | Below 23,000 advisory |
| 9 | `UniswapV4StandardExchangePositionImportFacet` | 15,293 | Below 23,000 advisory |
| 10 | `UniswapV4StandardExchangeOutFacet` | 30,033 | STOP: exceeds 24,576 |
| 11 | `UniswapV4StandardExchangeOutQueryFacet` | 18,541 | Below 23,000 advisory |
| 12 | `UniswapV4StandardExchangeLiquidReserveFacet` | 13,119 | Below 23,000 advisory |
| 13 | `UniswapV4StandardExchangeInMultiFacet` | 15,454 | Below 23,000 advisory |
| 14 | `UniswapV4StandardExchangeInMultiQueryFacet` | 16,003 | Below 23,000 advisory |
| 15 | `UniswapV4StandardExchangeOutMultiFacet` | 15,733 | Below 23,000 advisory |
| 16 | `UniswapV4StandardExchangeOutMultiQueryFacet` | 17,912 | Below 23,000 advisory |

## Searches and preserved semantics

[Search commands and results](execution/searches.txt) record the final state:

- No deleted legacy types, delegate artifact IDs, or shim imports remain in maintained `contracts/`, `test/`, or `scripts/` Solidity sources. The earlier [deletion search](execution/deletion-search.txt) records references within the set of bases being removed.
- A wider repository Solidity search still finds **two historical imports** in `implementation-artifacts/detf-funded-staking/hermetic-followups-before-validation-remediation/contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol`, at lines 905 and 911. This saved implementation snapshot is outside configured source/test roots and was left intact. Historical Markdown mentions also remain; they are not live compilation dependencies.
- No `delegatecall`, `functionDelegateCall`, `this.` call, or `address(this)` interface-call candidate remains in the legacy family targets and six libraries. The PoolManager unlock/callback boundary remains.
- Exactly one internal `_quoteZapOutAmount`, `_executeZapInDeposit`, and `_executeZapOutWithdrawal` implementation remains. Quote helpers were retained rather than deleted while callers exist. `_quoteZapOutAmount` serves both exact-in and exact-output quotes; `_quotedWithdrawalShares` and `_withdrawalAssets` serve PoolOps withdrawal execution. The existing unused quote wrappers were moved intact.
- Eight disable-check call sites remain: the six existing money/rebalance entrypoints and the two new SY overrides. No view guard was added.
- Normalized comparison against the pre-refactor working-tree snapshot found changes to moved helper bodies only for removing imported growth, replacing the two self-preview helpers, and sharing equivalent withdrawal settlement. Namespace qualification, visibility changes, and direct ERC20Repo supply/burn access were normalized for that comparison. This review is not a substitute for runtime tests.

A final [`git diff --check`](execution/diff-check.txt) also reports trailing blank lines at EOF in nine rewritten targets. They were left unchanged after the hard-size stop; they do not affect the measured runtime length.

## Required follow-up

The hard-size stop must be resolved under an explicit owner-approved continuation before further implementation or validation. The full named V4 suite, including vault-held redemption, full-range book, local liquid buffer, adversarial, and decimals tests, remains unrun. No passing test claim or deployment claim is made. Existing unrelated worktree edits were preserved; no commit, push, or deployment was performed.
