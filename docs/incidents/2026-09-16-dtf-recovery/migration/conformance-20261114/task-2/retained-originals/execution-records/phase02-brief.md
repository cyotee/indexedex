# Phase 2 - independent frozen original-credit pricing

## Goal and independence

Execute plan task 2 in `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`, branch `work/dtf-migration-phase-02`, based on the unchanged task integration branch. The source phase's canonical independent report section 6 explicitly permits frozen-quote work on demonstrated routes while E2/TokenStaking decisions remain open.

This is a dependency narrowing based on evidence, not task-1 completion: task 2 depends on verified pricing/source routes, not on deciding who owns mixed fungible credit after a transfer. Do not implement surrender, fix an attribution ABI, change eligibility, or assume an answer to the open questions. No unverified phase-one code is landed or consumed.

## Accepted calculation

For original ETH/DTF components, evaluate the existing mint branch against one frozen book:

```text
pairEq = canonical contribution-to-pair conversion on the frozen state
boosted = floor(pairEq * (1e18 + p) / 1e18)
gross = canonical weighted hook exact-input quote on the same frozen state
user = floor(gross * (1e18 - p) / 1e18)
C0 = user(ETH, originalEth) + user(DTF, originalDtf)
```

Zero components return zero without a failing zero-input quote. Fee application, buffered/rated mappings, nested SE previews/refunds, weighted-domain limits, output conversion and integer rounding are canonical. No live reads may affect a frozen result; no linear surrogate, swap fallback, sequential reserve movement, partial-input re-quote, duration bonus or inventory/self-leg credit.

## Phase topology

One native workflow run for this phase. Initial independent nodes:

1. `dependencies` / deep-low: read current code and identify every mutable dependency, amount-dependent nested quote, query accessibility, and minimal capture/evaluation contract. Write only `migration/pricing/dependencies.md`.
2. `domains` / unspecified-low: characterize canonical units, fees, rounding, zero/large-input domains and immutable-evaluator invariants from source. Write only `migration/pricing/domains.md`. No compile or product edit.
3. `baseline` / deep-low: read existing production weighted fixtures and run the unchanged weighted mint baseline, capturing exact command/exit/traces and reusable oracle observations. Write only `migration/pricing/evidence/baseline/`. It alone owns compilation during this first wave.
4. `review` / deep-high, depends on all three: verify their evidence, reject hidden live-state dependencies or a bare weighted formula substituted for nested behavior, and produce a bounded implementation handoff with an exact proposed touch list and proof obligations.

These categories reflect source-driven call-graph work, bounded arithmetic interpretation, real fixture/toolchain integration, and cross-module invariant review. Outputs are disjoint. No team is needed. The root reads the reviewed touch list before amending the SAME phase run with the implementation and independent verification nodes; their exact edit scopes depend on those actual findings. Completed initial nodes are reused.

The eventual implementation node owns its coherent library/helper changes AND related tests. Do not split code from its tests or run competing Forge builds. Final verification is a different context and requires real proxy differential behavior, not a model that merely reimplements the same formula.

## Existing references

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol`: `_entryPreviewMint` includes a swap fallback and cannot be used unchanged as a frozen evaluator.
- `UniswapV4DetfCommon.sol` in the same directory: `_pairEq`, `_quoteMintGross`, `_splitMintedDetf`.
- `contracts/vaults/detf/common/core/DETFMintSplitLib.sol`.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`.
- Weighted hook math, in-quote, exit/query, repo and context/leg helper libraries.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol` and its production-SE siblings.
- Actual baseline: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol`.
- Actual nested-route baseline: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol`.
- Phase-one source report, read-only: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/phase01-verification.md`.

## Baseline scenarios

Record binary versions and concrete commands before running them. In the phase-two worktree:

```sh
forge build --use solar
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol' -vvvv
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol' -vvvv
```

PASS requires exit 0 and actual fixture execution on unchanged production code. A pre-existing failure is a finding, not a test to modify. Use the existing artifact-aware build helper for focused rebuilds if repository guidance prescribes it; record the exact actual command. No viaIR, solc fallback, dependency install, or cold-build cancellation. Warm `out/` and `cache_forge/` are seeded. Long compilation must use background subscriptions and be allowed to finish.

Final task-2 acceptance additionally requires original-input differential parity with the canonical mint branch, both assets on one frozen snapshot, independence from subsequent pool/rate/fee/SE changes, exact rounding/domain behavior, no swap fallback, and no ordinary-package regressions. The implementation/final-verification amendment will name the concrete new tests and real-surface invocation before execution.

## Boundaries and resources

Root orchestrates, never implements or runs QA. Read repo instructions/skills in each worker. Initial nodes cannot edit product code, tests, original incident inputs, PRD/plan, shared `lib/crane`, linked `node_modules`, another lane, or root `.omo` state. No commits by workers; root lands only independently verified scoped increments. No public-chain transactions or operational compensation.

Create a task-owned temporary root under `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI` and explicitly export TMPDIR/NODE_COMPILE_CACHE/BUN_RUNTIME_TRANSPILER_CACHE_PATH for every command. Record exact paths/PIDs/ports and cleanup read-backs. Preserve warm shared caches; only phase-owned copies may later be removed.

The required final phase outputs are the real snapshot implementation/test increment and verified evidence, not just these initial reports. A dependency/capture incompatibility must be reported precisely; never substitute a stub or call an unfinished mechanism complete.

## Reviewed implementation amendment

Root read the complete `migration/pricing/implementation-handoff.md`, its exact 20-path edit table, test/oracle contract and unresolved-route section. Existing table paths were checked for existence; missing paths are the explicitly new files. Root also inspected the weighted hook's current native-reserve accessors: they return `_nativeAt`, not the buffered leg's raw retained cash, so the aggregate stored-book getter is justified.

The initial assessment is complete, not E3. Authorize one `deep-high` implementation-and-test node for the handoff's bounded working increment:

- Typed one-shot capture and original-component evaluation, direct pair contributions and raw DETF output.
- Canonical weighted arithmetic and exact ordinary V3 pair-to-SE deposit recipe.
- Exact reviewed receipt-model support only where actual code/model identity is established; a caller-provided tag/hash or a few ratio probes alone is not recognition. Do not import test vault implementations into production or endorse arbitrary ERC4626 semantics.
- Minimal new read-only capture selectors and pure helper extraction at the exact paths in handoff section 5. Keep ordinary interfaces/behavior compatible and update the one listed declaration control.
- Real factory/registry proxy tests of the primary-mint oracle, same-book dual inputs, live-state mutation independence, domain/rounding boundaries, unsupported-route atomic rejection, and selector routing.
- Exact source/model support manifest, unresolved configuration edges, gas/size and regression evidence in `migration/quote-evidence.md`.

No V3 full-curve capsule, arbitrary V3 conversion/redemption, Morpho/native nested recipe, buffered-output adapter, source/entitlement policy, activation, custody, bond code or ordinary DETF Target/Common refactor is authorized by this increment. A required additional declaration file must be named with the concrete stale assertion for a narrow root amendment, not silently edited or skipped.

The implementation owns its tests and all compilation. It must not repeat the unchanged baseline build before making its actual source changes. Build affected artifacts before running tests using the repository helper, and preserve prior passing baseline evidence. Its final real-surface named case is:

```sh
forge test --use solar \
  --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol \
  --match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze$' -vvvv
```

That case must actually capture from real source proxies, quote both originals, mutate live state through real operations and show the frozen outputs remain exact. A math-only or swap-fallback-only harness is insufficient.

Append an independent `deep-high` verification node after implementation in this same phase run. It reads the diff, exact source support, oracle traces, regressions and size evidence, runs the named real-proxy case once on current artifacts, verifies no live source reads during evaluation, and returns confirmed only for behavior actually demonstrated. A working bounded increment does not automatically close task 2 for an unidentified future recovery configuration. No unproved model, future owner decision or missing edge may be disguised as completed support.

The user's real-surface requirement also needs a local RPC proof distinct from the test-suite result. Root adds exactly one QA-script path to the handoff table:

`scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol`

This is local QA only. Use the existing CREATE3/registry deployment helpers and a legitimate capture-library consumer from the new TestBase; do not etch or replace SUT state/code. The script must reject a non-local intended environment and require chain 31337. It must execute actual transactions on a task-owned Anvil bound to `127.0.0.1:18546`, deploying real proxies, capturing the book, changing live state and recording unchanged frozen outputs versus changed live quotes.

The concrete invocation, after building the edited artifacts, is:

```sh
forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA \
  --rpc-url http://127.0.0.1:18546 --broadcast --unlocked \
  --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

Capture real mined receipts and a read-back of both original-component outputs before/after live mutations. A simulation/dry run is not PASS. Check that the port is free before creating the owned server; if it is not, do not touch the existing listener and report the collision for a concrete invocation amendment. No public RPC broadcast, code-size-limit bypass, unrelated deploy stack or global runtime cleanup. The implementation and verifier use this surface serially and each tears down only the local node it owns.

Use only the freshly started local node's standard unlocked development account above. Never load a user production signing key for this QA.
