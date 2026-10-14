# Astra — round 2 single cross-review

2026-10-12. Read Grok, MiniMax M3 and Kimi K3 round-2 originals completely and together, treating them as evidence only. No earlier/new cross-review files read. Retained-session context is historical, not fresh independence. Originals preserved. No delegation, shell, execution, tests, source/config edits or deployments occurred. Only this report was written.

## Verdict: no outstanding owner requirement; command corrections are blockers to plan execution

Astra retains its original readiness verdict and agrees with Grok: the approved filename-only decision and current PRD provide sufficient scope. MiniMax's proposed owner questions and Kimi's root/dialect questions do not warrant another approval cycle:

- **BC root is documented:** `lib/crane/docs/deployment/BC_AAVE_V4_DEPLOY_STEPS.md:139–150` specifies Crane paths, flags the upstream emitter mismatch, and explicitly changes working directory to `lib/crane`. Re-read directly this review. IndexedEx tests use IndexedEx root and its JSON-link-reference loader. Record these roots explicitly in the plan; do not invent portability for Crane operational helpers.
- **Emitter correction is already required:** PRD `75–76,95,106` covers correcting maintained operational output to its supported root. It is not a new feature needing owner confirmation.
- **Conditional overload removal is already specified:** PRD `108` mandates caller verification, removal when no required caller remains, and scope review only if another caller actually exists. MiniMax Q3 asks to reapprove that existing requirement.
- Other basename collisions and Echidna changes are excluded. Deployment occupancy is evidence gathering for the identity table, not a naming blocker; unknown live state must be reported without inventing a migration or authorizing transactions.

The PRD's approval-status wording and cold-preparation/warm-seeding clarification remain administrative updates from Astra's original. None authorizes executing this plan.

## 1. Corrections to peer plans

### Grok

**Warm bootstrap command is wrong despite correct prose.** Lines 63–69 use `python3 scripts/forge-artifacts.py build`. The current entrypoint calls `graph.plan` at `scripts/forge-artifacts.py:417` before `execute_plan` at `427–428`. Thus `build` can fail on stale removed-source link IDs just like `plan`. Passing the seed does not bypass planning or its helper classification. Use **direct `forge build`** with renamed sources and concrete dependents first.

**Fixture is not a runnable test root.** Line 84 selects `SeMatrix_AaveLoopFixture.sol`; the helper documents `--test-root` as an exact `.t.sol` or directory (`394`). Select actual consumers listed below.

**Loader negatives need separate preparation.** Lines 79–85 mix `ArtifactCreationCode.t.sol` into automatic literal discovery. Its intentionally nonexistent/wrong-source artifact IDs can make preparation fail. Use explicit real fixture/source preparation with `--no-consumer-artifacts`, or refresh runtime artifacts then run this loader suite directly, as Astra proposed.

**“Compile-only” script command executes.** Line 90 proposes `forge script ... --sig "run()"`. Removing broadcast does not prevent local script execution and its cheatcode side effects. Replace with `forge build scripts/foundry/bc/<script>.s.sol` from Crane root. Test emitted strings in hermetic helper tests with synthetic inputs, not by invoking deployment `run()`.

### Kimi K3

**Owner-root gap is overstated:** line 13 itself cites the documented Crane working directory, contradicting line 9's claim that the supporting document does not exist. Resolve Q1 from that documentation; resolve Q2 from the PRD's existing emitter requirement.

**Bootstrap also starts with the planner:** lines 53–56 use `forge-artifacts.py build`. Make direct Forge dependent refresh the first step, not a fallback after an avoidable stale-ID failure. Include concrete Pool instances, not just an abstract/base implementation.

**Baseline and placeholder commands need stronger evidence:** use `methodIdentifiers`, not unverified `methods`; artifact line count (`29`) identifies neither source nor version. Match a placeholder to its source-qualified `linkReferences` entry and byte offsets rather than assume a whole-artifact regex yields exactly one distinct token (`65`). Prelinked artifacts can contain no token; treat that as a diagnosed preparation state, not a license to change compiler configuration.

Kimi's zero-caller regex plus manual review is at most discovery assistance: nested/multiline calls defeat line-based argument counting. Inventory actual callsites, verify arity semantically, and compile all affected consumers after removal.

### MiniMax M3

**Do not adopt the proposed commands without repair.** Material issues:

- `forge-artifacts.py resolve` (`42`) does not exist: supported actions are `audit`, `plan`, `build`, `test` (`389`). Bare `plan` (`146`) supplies no changed sources/consumers/all-artifacts selection and is not a meaningful acceptance command.
- `forge inspect ... methods` and `StorageLayout` should use documented `methodIdentifiers` and `storageLayout`. Record the compiler actually used by Forge; a PATH `solc --version` alone may describe another binary.
- Lines 101 and 157 reauthorize `--force`, contradicting the PRD and their own preservation claims. No exception for placeholder derivation or reseeding: `--force` clears artifacts/cache.
- After returning to IndexedEx root, lines 149–150 filter Crane tests under `lib/crane/test`. A filter is not a change to the configured test root and cannot establish those suites were discovered. Run Crane suites from Crane root and verify test counts.
- `getLibraryString` is on `SpokeDeployUtils`, not `SpokeBytecodeLinker` (`92`). Filename-only leaves the symbol `LiquidationLogic`, not `LiquidationLogicAaveV4` (`93`). Tighten parser selection to the correct source-qualified V4 identity as already required.
- Runtime code hash must **not** equal initcode hash (`163`). Library runtime also includes its deployment-address patch. Compare like-for-like artifacts/code with known link/address substitutions, and independently assert expected deployment addresses.
- The first 64 hex characters need not change when metadata changes near the end (`178`). Capture complete bytecode hashes and source targets, not bytecode heads. Do not require no old link reference in *any* retained artifact (`177`): old outputs may remain; current refreshed consumers must not select them.
- Do not print unrestricted `forge config` output as evidence. Record only reviewed, nonsecret compiler/path settings; RPC/environment values are outside this research's evidence needs.
- Overload tests must be rerun **after** removing plumbing, not merely before (`83–84`). Unexpected additional import sites are inventory updates, not automatic scope blockers; unexpected required override callers are the explicit stop condition.

MiniMax's broad direct Forge builds do avoid the planner-bootstrap trap, but redundant build steps and the later test-root errors still need correction.

## 2. Astra correction: expand the concrete matrix inventory

My round-2 original named single/dual and weighted examples, with a requirement to discover all consumers. That example list was incomplete. This review's unrestricted `.t.sol` search within `test/foundry/spec/hooks` found **21 direct consumers**, not merely the earlier subset. This is current source-search evidence, not a claim that tests ran or that transitive closure is complete.

All paths below are relative to `test/foundry/spec/hooks/uniswap/v4/standardExchange/`. For each row, select `<dir>/<stem>.t.sol` and `<dir>/decimals/<stem>_F6.t.sol`, `<dir>/decimals/<stem>_F9.t.sol`:

| Directory | Exact stem |
|---|---|
| `single` | `UniswapV4SingleSEBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `dual` | `UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop` |
| `weighted` | `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `orbital` | `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `constantProduct/single` | `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_AaveCrossVersionLoop` |
| `stable/quad/balancer` | `UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop` |
| `stable/quad/curve` | `UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop` |

Use repeated exact `--test-root` arguments, or explicitly approved containing suite directories. Recheck imports immediately before implementation and include indirect consumers. A fixture `--consumer` can help build dependencies; it does not replace selecting runnable tests.

## 3. Recommended corrected sequence — PROPOSED, NOT RUN

1. Record approved naming and the two documented roots. Capture safe baseline settings, revisions, source/artifact identities, ABI/method identifiers/layouts. Preserve and seed each root's own warm output/cache; serialize writers.
2. Rename both sources; update 11 imports and remove the twelfth TestBase import. Preserve declarations and all economic bodies. Correct artifact IDs/emitter/parser paths; retain seed and genuine onchain creation-code deployments. Remove override overload/plumbing after complete caller review, retaining all generic loader safeguards.
3. **Direct bootstrap from IndexedEx root:**

```bash
forge build \
  lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/LiquidationLogicAaveV3.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v3.6/instances/L2PoolInstance.sol \
  lib/crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol \
  contracts/utils/foundry/CraneFactoryArtifactSeed.sol
```

Refresh additional stale concrete artifacts identified by their old links. Repeat equivalent root-relative preparation in Crane. Only then invoke `forge-artifacts.py plan/build/test` with explicit renamed sources and actual consumers. Persistent failure triggers narrow review, never global unresolved-library suppression or cache clearing.

4. Derive/validate the Crane placeholder against freshly compiled source-qualified link references, update the constant and rebuild its consumers. Compile scripts without execution, from Crane root:

```bash
forge build scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol \
  scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol
```

5. Run separately authorized hermetic helper tests for configuration output/parser behavior. Run Crane liquidation/deficit/getter suites from Crane root; IndexedEx full cross-version family including actual invariant execution, loader negative/memory/nested-link/occupied-identity suite, planner tests, and the 21 matrix consumers above. Handle negative artifact literals separately. Verify nonzero selected counts, not just successful command exit.
6. Verify warm pre-rename migration and both build orders in each root. Distinguish cache-hit observations from actual recompilation evidence. My original suggested optional disposable comment probes; these require separate explicit authorization and must not be silently expanded into core-library edits. No unseeded full build or `--force` needed.
7. Close gates: exact version-bound distinct library addresses; real liquidation/deficit behavior; correct targets/new links; unchanged consumer ABI/storage and library selectors; old/new ID/salt/full-initcode-hash/address table; runtime sizes; docs/provenance. Retain historical artifacts and report skipped/failed validation honestly.

## Sources and remaining uncertainty

Additional direct source reads: `BC_AAVE_V4_DEPLOY_STEPS.md:126–168`, `scripts/forge-artifacts.py:387–428`; direct consumer search restricted to Solidity test sources, not council outputs. PRD scope and earlier original source evidence remain controlling.

Context7 resolve/query used before the new script-CLI claim, accessed 2026-10-12: https://github.com/foundry-rs/book/blob/master/src/pages/forge/scripting.mdx and https://github.com/foundry-rs/book/blob/master/src/pages/forge/scripting-internals.mdx establish that `forge script` executes locally without broadcast. Previously checked build/inspect references remain applicable; current documentation does not verify the installed executable version.

High confidence: no further owner requirement is needed, helper `build` still plans, documented BC root, and identified command/fixture defects. Unverified: actual compiler/test outcomes, exact hashes/placeholders/addresses, complete transitive suite closure and deployment occupancy. No consensus or passing test claim substitutes for those checks.

Returned once to moderator. Originals preserved; this plan does not authorize execution.
