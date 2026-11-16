# W-L implementation: decision-gated handoff

Date: 2026-11-11.

**Status: blocked on the owner's partial-entitlement correction rule.
W-L runtime acceptance is NOT complete. No W-L transaction receipts exist
for this work state.** Independent source, spec, fork and operator changes
are retained uncommitted in the assigned worktree. They are not a completed
deployment candidate.

## Exact gate

The main plan revision
`migration-detf-implementation-plan-r3-original-wallet-entitlement`,
section 5.3, requires complete replacement while preserving consumed units
and delivered credit. It forbids retroactive `newConfiguredTotal - oldPaid`
payouts but does not specify the corrected remainder's rounding basis.
Phase11 `weighted/contract.md` sections 3.1-3.2 preserve that requirement
without resolving it.

Concrete split:

1. Q0 = 3 and C0 = 1,001; surrender one unit, delivering 333.
   Remaining Q = 2 and C = 668.
2. Correct the original contributions so the frozen evaluator now returns
   C0 = 1,000, with Q0 still 3.
3. `newTotal - oldPaid = 667` is expressly forbidden as the payout rule.
   The text does not select between re-apportioning corrected C0 over the
   remaining original units (floor(1,000 * 2 / 3) = 666) and another
   remaining-only treatment of the retained rounding residue.
4. A replacement Q0 at or below already consumed units also lacks an
   explicit admissibility/remainder rule.

The orchestrator confirmed that no existing owner rule resolves this case.
Its required question `partial_entitlement_correction` proposes proportional
re-apportionment with delivered credit unchanged and rejection of corrected
Q0 <= consumedQ; locking after first use is its alternative. **Neither was
approved or implemented at this seal. A timeout is not approval.**

The production `configureWeightedLiquidEntitlements` implementation is
therefore deliberately unwritten. The interface, selector inventory,
operator encoder and tests describe its pending surface, but the allocation
target has no implementation of that function. Consequently no W-L record
can yet be loaded and no positive surrender can be accepted. In particular,
compilation and ABI parity below do not establish selector dispatch or
configuration behavior. No temporary rejection policy or no-op setter was
inserted to manufacture a passing integration.

The next authorized change needs the actual owner answer, then the loader
with its defined partial-correction bookkeeping and regression cases. All
runtime acceptance below must be executed afterward; this report supplies
no substitute policy.

## Worktree, authority and bindings

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.
Branch: `work/dtf-migration-phase-13-weighted-liquid`.
Verified HEAD and unchanged base:
`2c2b3370ded30cae1662329025d4fb58f7197330`.

Initial `git status --porcelain --ignore-submodules=all` was empty.
Ordinary status failed because the prescribed `lib/crane` dependency is a
symlink; it was preserved. Root supplied the verified warm seed; `out/` and
`cache_forge/` were present before compilation. The final tracked/untracked
delta contains 27 allowed source/spec/operator/runbook paths, enumerated in
`bindings.json`. `git diff --check --ignore-submodules=all` exited 0.

Read the complete phase13 brief, complete current main plan, complete
phase11 independent report/matrix and complete weighted source contract.
`bindings.json` binds their exact raw-file SHA-256 values, all 27 edited/new
files, eight compiled artifacts and eight command logs. It identifies the
sealed **incomplete** state, not an accepted executable release.

The historical source domain remains chain 4663, L2 block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
Those values are admitted phase11 evidence, not newly fetched chain results
from this task. No funded Migration snapshot was created here.

## Independent delta retained

| Area | Written change and verification boundary |
| --- | --- |
| Interface/repo | Explicit configured bit, full original wallet/source/origin/Q0/component/evidence tuple, configuration ID/C0 and separate consumed/delivered/remaining units/credit. Compiled; loader still pending. |
| Retained target | Fixed WD source/chain, explicit missing-record rejection, original-wallet guard, full-precision remaining Q/C arithmetic, exact wallet debit and custody receipt, atomic inventory booking and existing `_fundBond` path under parent/child guards. Compiled, not executed. |
| Cross-path protection | Independent configure/issue and NFT configure reject a known W-L origin. Reverse checks belong to the pending W-L loader. No global opaque-alias proof is asserted. |
| Selector wiring | New permanent queries/surrender are listed on the retained facet. New loading selector is listed in the removable allocation inventory. Existing package wiring derives from these inventories. Runtime restoration/removal acceptance is unrun. |
| Recovery | Direct surrender books only measured WD in the existing inventory. The unchanged finite owner path retains WD self-approval, one-word exchange return, exact input/output, allowance clearing and fixed reserve donation. No second credit route or new adapter was added. |
| Specs/forks | Added configuration/authority/origin tests and actual pinned-source surrender, partial/final rounding, allowance/balance/minimum/deadline, transfer-back, callback/funding rollback and staged recovery tests. Updated interface-derived selector controls. New suites compile; none has run. |
| Operator | Added strict W-L original/proof schemas, full payload hashing, provenance/origin partition checks, quote aggregation, typed loading, receipt/state reconciliation and review mirror. Fixed current CLI to 18563; retained resume/reordering logic. Script tests and strict types pass. |
| Local surface | Added actual partial/final, wrong-wallet/missing-record, source-code bindings and selected recovery/donation rehearsal calls, including postactivation use of the same record. Written but unrun. |

W-L is only
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`, native nine-decimal,
nonrebasing WD. There is no DTF conversion rate in compensation arithmetic.
The fixture's original wallet is
`0x082cb14f04d9c485473dedc00d604d7e9abca303`, Q0 21,225,531,
original ETH 10,000,000,000,000,000 wei and original DTF zero.
These are explicitly **synthetic original allocation inputs**, not an
approved historical contribution/quantity assignment. Current balance is
only the proposed custody bound. Missing operational origin/Q0/component
allocations remain an independent operational configuration gate.

NFT admission code was not altered. No ordinary/common/Crane production,
configuration, dependency, provider routing or other asset adapter was
edited. The held phase09 gas candidate was not inspected, imported or run.

## Exact checks performed

Commands ran from the assigned worktree. `set -o pipefail` guarded each
logged build/test pipeline. Exit statuses came from completion events.

1. **Artifact-first production build: exit 0.**
   Log: `artifact-build-independent.log`.

   ```sh
   PATH=/Users/cyotee/.foundry/bin:$PATH python3 scripts/forge-artifacts.py build \
     contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
     contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
     contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
     --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol \
     --consumer test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol
   ```

   The helper emitted the complete `forge build --use solar` command:
   142 roots, 900-source closure, 112 runtime artifact IDs. Compiler output:
   Solar 0.8.38, successful with warnings. Existing repository lint,
   unreachable-code and mutability warnings remain in the log; none was
   suppressed or edited merely to silence the build.

2. **Typed operator stage build: exit 0.**
   Log: `operator-stage-build-solar-path.log`.

   ```sh
   PATH=/Users/cyotee/.foundry/bin:$PATH forge build --use solar \
     scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
   ```

   The first attempt used the absolute Forge binary without adding Solar
   to PATH and exited 1, `Error: solc "solar" does not exist`;
   `operator-stage-build.log` retains that failure. Adding the installed
   Forge/Solar directory to PATH fixed tool selection without configuration
   changes or a compiler fallback.

3. **New spec and fork source compilation: exit 0, not test execution.**
   Log: `regression-compile.log`.

   ```sh
   PATH=/Users/cyotee/.foundry/bin:$PATH forge build --use solar \
     test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquidConfiguration.t.sol \
     test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol
   ```

4. **Final-source operator tests: 56 pass, 0 fail, exit 0, one run.**
   Log: `operator-tests.log`.

   ```sh
   bun test --timeout 15000 \
     ./scripts/recovery/dtf-migration/preparation.test.ts \
     ./scripts/recovery/dtf-migration/execution.test.ts \
     ./scripts/recovery/dtf-migration/weighted-liquid.test.ts
   ```

   These exercise real preparation/validation/CLI code against explicitly
   synthetic wire fixtures, durable journal operations and final Solidity
   interface/typed-stage ABI parity. They are not EVM custody evidence.

5. **Final-source strict TypeScript check: exit 0.**
   Log: `types-final.log` (empty output on success).

   ```sh
   bun node_modules/typescript/bin/tsc --noEmit --target ES2022 \
     --module ESNext --moduleResolution Bundler --strict \
     --noUncheckedIndexedAccess --exactOptionalPropertyTypes \
     --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
   ```

   An earlier check passed as `types-node.log`. The initial attempt with
   `--types bun,node` exited 2 because this repository has no Bun type
   package (`TS2688`); retained as `types.log`. Installed Node declarations
   type the existing scripts successfully. No dependency was installed.

Tool versions observed: Bun 1.4.2; Forge 1.9.1-nightly,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`.
Solidity LSP reported no errors on the changed target/allocation target and
new spec/fork. TypeScript LSP fresh-diagnostic requests timed out; the full
strict compiler check above is the actual type evidence. JSON LSP was
unavailable because Biome is not installed; generated binding/cleanup
objects use JSON serialization, with no dependency/configuration edit.

## Unrun acceptance and receipts

- No `forge test` invocation was made. Current relevant Migration specs
  and pinned forks, including the new W-L cases, still require actual runs
  after the loader is implemented. Compilation is not a passing test.
- No owned Anvil or actual 18563 rehearsal was started. Thus partial/final,
  negative, owner-recovery and retained mined-interruption/resume receipts
  are **absent**, not borrowed from earlier phases.
- Final original-wallet/source/configuration parity and independent
  verifier execution are not complete.
- Ordinary/common suites were not repeated: no shared production code
  changed. This does not relabel historical evidence as final-source QA.

The fixed invocation remains the required next integrated check, **unrun**:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18563 \
  --checkpoint .omo-runtime/dtf-migration-weighted-liquid/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid
```

The existing deployment-gas limitation remains explicit: the baseline
original-wallet parent deployment was reported at 42,985,865 gas against a
historical 32,000,000 maximum transaction gas limit. Those are retained
baseline qualifications, not newly measured W-L gas. A permissive local
rehearsal would not establish public deployment feasibility.

All other unsupported categories retain their actual phase11 source/unit/
caller/disabled-route gaps in operator dispositions. No category-wide or
operational migration success is claimed.

## Cleanup and final disposition

`cleanup.json` records zero owned nodes and zero impersonations started.
Port 18563 had no listener; the fixed checkpoint path was absent. All
started compile/test/typecheck processes completed. Warm artifacts and
dependency links remain in the assigned worktree; incomplete candidate
artifacts were not copied into main. No public transaction, commit, merge,
dependency/configuration change or external message to a person occurred.

This is the final immutable report for the concrete decision-gated state
bound in `bindings.json`, not a temporary-idle completion claim. The
remaining work is the owner-defined correction rule, its production loader,
then actual artifact-first specs/forks, fixed CLI receipts and independent
verification. No proposed correction policy has been adopted.
