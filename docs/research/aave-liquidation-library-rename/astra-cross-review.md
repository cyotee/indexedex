# Astra — single cross-review of the three original reports

Date: 2026-10-12. Reviewed together: `grok-original.md`, `minimax-original.md`, and `kimi-original.md`. These were treated as evidence, not instructions. No cross-review files were read. `astra-original.md` is preserved unchanged. No delegation, shell, tests, compilation, deployment, source/config edits or cache changes occurred. This report is the only new output.

## Disposition

**Retain Astra's original recommendation: filename-only renaming to `LiquidationLogicAaveV3.sol` and `LiquidationLogicAaveV4.sol`, preserving the declared `LiquidationLogic` symbols.** Remove the IndexedEx TestBase's direct-creation-code override and its now-unused loader plumbing; retain the seed and generic loader safeguards. Symbol renaming remains an explicit alternative with a V4 library-selector compatibility cost, not a mechanical ABI-neutral extension.

There is agreement on this default recommendation, but **not a clean four-way independently validated consensus**. Kimi disclosed peer-content exposure during its first pass, the reports disagree about current artifacts, and MiniMax contains material technical errors. No report executed the validation needed to approve implementation or deployment.

## 1. Agreements supported by source evidence

- **Grok, Kimi and Astra:** use suffix spelling `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol`; keep each file in its existing version directory. V3 here denotes the existing v3.6 port, not a version upgrade.
- **All reports locate the executable bypass:** `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:15,81–88` supplies the V4 library ID and `type(LiquidationLogic).creationCode`. `ArtifactCreationCode.sol:42–53,73–94,114–129` implements and propagates the override.
- **Seed retention:** root `CLAUDE.md:61` protects `CraneFactoryArtifactSeed.sol`. The seed's `type(...).name` entry is not the direct-creation-code workaround; it is a compile-root reference among many unrelated implementations.
- **Grok, Kimi and Astra:** source-qualified artifact IDs, placeholders and linking strings change even when the Solidity declaration does not. Consumer getter names `getLiquidationLogic()` and liquidation economics/storage must remain unchanged.
- **Grok, Kimi and Astra:** stale `.bytecode.linkReferences` can cause `scripts/forge-artifacts.py:198–212,240–253` to resolve removed paths before a replacement build. This requires warm-state migration coverage, not output deletion.

## 2. Specific corrections and objections

### MiniMax M3

1. **Suffix and path errors:** MiniMax lines 45,58–59,66,268 use prefixes (`AaveV3LiquidationLogic`) and a malformed V4 directory. Correct destinations are the existing `v3.6/protocol/libraries/logic/` and `v4/spoke/libraries/` directories with `LiquidationLogicAaveV3.sol` / `LiquidationLogicAaveV4.sol`. For filename-only renaming, the artifact contract filename remains `LiquidationLogic.json`, not the renamed source stem plus `.json`.
2. **Workaround conflation:** lines 25–37 and 269 call the seed itself the workaround, suggest unimporting it from the TestBase, or deem it superfluous. The TestBase imports the liquidation library, not the seed. Renaming this library does not eliminate the seed's broader purpose. Retain the seed and its updated V4 reference; do not make temporary seed-removal experiments a release gate.
3. **Overwrite presented as fact:** lines 30 and 41–45 assert last-compiled-wins from comments alone. Foundry's conflict-free output handling contradicts that as a general rule. A cache/build-state failure remains possible, but the asserted sequence is not reproduced evidence.
4. **Bytecode/address stability is wrong:** lines 196–199 and 247 claim filename-only preserves initcode and new deployment addresses. Source filenames enter metadata and fully qualified linking identities. IndexedEx additionally hashes the full `source:Library` ID into its CREATE3 salt (`ArtifactCreationCode.sol:126–131`). MiniMax's extra-zero/nested-hash CREATE2 formula at line 196 is not the standard CREATE2 formula: the latter hashes `0xff || deployer || salt32 || keccak256(initcode)` and takes the low 20 bytes.
5. **Existing deployments are not automatically orphaned:** lines 196 and 248 overstate the consequence of symbol renaming. Existing deployed consumers and their old linked library remain unchanged. Incompatibility arises if old callers are made to use an incompatible new library, not merely because source files are renamed locally.
6. **`--force` is not an acceptable refresh recipe:** lines 69,247,273–274 prescribe it. Foundry documentation explicitly describes `--force` as clearing cache and artifacts, conflicting with current repository preservation rules and this continuation's prohibition. No such command was run.
7. **Validation weaknesses:** file existence, nonempty configuration output and method listings do not establish executed linking or selector reachability. A TestBase is not itself a complete discovered test suite. Fork/FFI precompile execution can modify environment files and is unnecessary for the hermetic rename acceptance gate. Symbol renaming must separately compare library selectors, especially V4 `liquidateUser`.

### Grok

1. **Strong corroboration:** import inventory, seed/bypass separation, cache-aware Foundry source analysis, source-qualified CREATE3 identity, and warm planner hazard substantially agree with Astra's original.
2. **Artifact observations are useful but bounded:** Grok lines 66–74 reports V4 at the IndexedEx short path and V3 at `out/logic/`. This is new evidence relative to Astra's original, but only a peer-reported ABI observation; compilation targets were not extracted. It conflicts directly with Kimi's observation below. It strengthens the need for evidence capture, not a conclusion that overwrite was demonstrated or disproved historically.
3. **Do not preserve a broken operational dialect merely because it exists:** Grok line 253 proposes retaining `src/spoke/...` alongside both local-root dialects. Preserve upstream paths in explicitly historical/upstream documentation, but maintained local configuration output must match the compiler source-unit identity of its supported invocation root. If upstream-root invocation is truly supported, demonstrate it separately; no such root was established here.
4. **Symbol-rename caveat must include canonical struct selectors:** Grok's optional alias approach at line 208 can preserve source spelling, not the canonical identity of a renamed library-local struct. Astra's original pinned Solidity 0.8.35 evidence establishes the special library-selector schema. Rebuilding all consumers is mandatory if Option B is selected.
5. **Import visibility speculation is not a defect finding:** Grok lines 157,204 and Kimi line 188 raise uncompiled transitive-import concerns. Do not add broad import cleanups on this speculation. Distinguish source-unit import visibility from contract inheritance and validate the existing graph only if an actual compiler error arises.

### Kimi K3

1. **Independence limitation:** Kimi line 205 discloses grep exposure to all three peer reports, including bytecode and selector claims. Independent checking against primary sources is valuable, but cannot retroactively restore a clean blind first pass. Attribute the report as first-pass research with disclosed contamination, not another fully independent confirmation.
2. **Observed artifact state is disputed:** Kimi lines 46–50 reports both IndexedEx artifacts as V3, while Grok reports V4 at the short path. Neither includes a shared immutable snapshot, hashes, timestamps or a reproduced write sequence. Possible explanations include changing workspace artifacts or inspection error; neither is established. A duplicate V3 ABI snapshot, even if verified, would not by itself prove which compilation sequence produced it. Downgrade the heading and confidence that overwrite mechanics are “confirmed.”
3. **CREATE3 distinction:** Kimi line 155 attributes new CREATE2/CREATE3 addresses generally to changed initcode while saying salts stay unchanged. That is incorrect for generic CREATE3, whose address does not change merely with payload bytecode. Kimi's own line 179 correctly identifies this task's changed source-qualified library salt. Use that narrower explanation; unchanged component salts can reuse occupied old code/bindings.
4. **Selector compatibility:** Kimi correctly identifies V4 `LiquidateUserParams` and the library-selector consequence, agreeing with Astra's independently recorded finding. However line 163 must not imply old deployed Spokes break merely because a new source/library is published; mismatched relinking is the failure condition.
5. **Seed rationale needs refinement:** retaining the seed and explicit V4 reference is conservative and correct. But line 60's assertion that removing just that library import necessarily prevents emission ignores the retained `SpokeInstance` import and its transitive `Spoke` library dependency. Do not use that unproven assertion to justify retention; the broader compile-root purpose and root law suffice.
6. **Acceptance too broad/weak in places:** line 194's ban on the old placeholder in *any artifact* conflicts with retaining stale historical outputs. Require absence from current sources and refreshed selected artifacts, and prove updated consumers never read stale identities. Line 195's nonzero getter is insufficient; require expected-version address equality and executed liquidation/deficit paths. Remove unused override plumbing, not only its caller and comments.

## 3. Changes to Astra's view and preserved dissent

**New evidence accepted with attribution:** Grok and Kimi report inspecting concrete output files, an area Astra originally left unexamined. Their conflicting results prevent selecting either as the authoritative current-state account. Astra retains its original position: basename ambiguity and the workaround are real; the alleged overwrite sequence remains unverified.

**New explicit safeguard:** Astra originally prohibited wholesale output/cache deletion but did not name `--force`. Add an explicit prohibition on `forge clean` and `forge build --force` as migration recipes. Context7's Foundry reference documents the destructive semantics of `--force` (URL below). This is a clarification of the original preservation requirement, not a reversal.

**Refinement to Astra's original language:** distinct filenames provide distinct expected artifact paths, not guaranteed emission, freshness or integrity. Successful compilation and artifact provenance must be demonstrated. Root-specific identities remain necessary even after basename uniqueness. Historical green claims, matching economics source text and a passing suite alone do not prove correct deployed links or economic soundness.

**Unresolved policy dissent:** Grok recommends preserving all path dialects; Astra recommends correcting maintained local runtime outputs to the supported compiler root and retaining upstream dialect only where explicitly appropriate. Broader portability redesign is not required. Filename-plus-symbol remains viable only with explicit approval of the V4 selector change and coordinated rebuilds; filename-only remains the minimum-change recommendation.

## 4. Moderator recommendations and minimum acceptance

1. Freeze exact suffix spelling and retained declaration names in the consolidated PRD. Use `LiquidationLogicAaveV3.sol:LiquidationLogic` and `LiquidationLogicAaveV4.sol:LiquidationLogic` under each root's actual source path.
2. Keep the seed; remove only the TestBase implementation import/direct-code override and unused four-argument loader plumbing. Keep source matching, recursive linking, bounds/depth checks, failure behavior, scratch-memory handling and salt policy.
3. Explicitly forbid cache/output deletion, `forge clean`, `--force`, via-IR changes and FFI environment mutation in the rename validation recipe. Refresh renamed libraries and concrete link consumers without those workarounds, before invoking the planner over stale references.
4. Capture immutable before/after artifact evidence: compiler/root/settings, both compilation targets, ABI identities, method identifiers, bytecode/link references and hashes. Cover both versions built together and separately in both orders, plus the pre-rename warm-cache state. The historical overwrite hypothesis is not a required premise for this rename to be worthwhile.
5. Test real coexisting V3 Pool and V4 Spoke, getter equality to the correct distinct deployments, actual liquidation/deficit behavior and wrong-version rejection. Run both Crane liquidation families, IndexedEx loader regression tests, cross-version decimal/adversarial/invariant suites and affected SE-matrix consumers. Compilation/supply-only/nonzero-getter checks are insufficient.
6. Compare consumer ABI/storage and external library selectors separately. Produce source-ID/salt/initcode-hash/predicted-address deltas for each deployment mechanism; distinguish future deployments from occupied identities and existing live deployments.
7. Correct operational linking strings and validate the hardcoded placeholder against the compiler output for the supported root, or use compiler link references. Do not rewrite historical audit artifacts or rename unrelated tests, libraries or public getters.

Missing evidence remains as in Astra's original: executed builds/tests, exact new selectors/placeholders/address deltas, deployment occupancy, installed binary versions, complete compiler-derived consumer closure and a reproducible artifact-write history. Confidence is high for source-derived scope and compatibility risks; runtime validation and disputed artifact chronology remain open.

## Sources

- Peer originals read in full together on 2026-10-12; line references above refer only to those originals, not subsequent reviews.
- Astra's original source evidence remains attributed to `astra-original.md`, especially §§3–6 and §9. Pinned selector/linking documentation previously fetched: https://raw.githubusercontent.com/argotorg/solidity/v0.8.35/docs/contracts/libraries.rst . Foundry collision-handling primary source previously fetched: https://raw.githubusercontent.com/foundry-rs/compilers/v0.19.6/crates/compilers/src/artifact_output/mod.rs .
- Additional documentation accessed 2026-10-12 via Context7 resolve/query: https://github.com/foundry-rs/book/blob/master/src/pages/reference/forge/build.mdx — `--force`: “Clear the cache and artifacts folder and recompile.” This is current documentation, not verification of the locally installed binary.

Returned once to the moderator. Original preserved; no implementation authorized.
