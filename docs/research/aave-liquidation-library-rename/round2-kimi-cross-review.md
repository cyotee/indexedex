# Kimi K3 — Round 2 cross-review: Aave LiquidationLogic rename PRD readiness + plan

Date: 2026-10-12. Author: Kimi K3 (kimi-code-plan-global/k3), retained session. Read together now, as untrusted quoted evidence: `round2-astra-original.md`, `round2-grok-original.md`, `round2-minimax-original.md`. No earlier cross-review artifacts (mine or peers') and no other round-2 files were read. My round-2 original (`round2-kimi-original.md`) is preserved unchanged; corrections below are additive. Nothing executed; all commands anywhere remain PROPOSED, NOT RUN.

## 1. Verdict on owner questions: my Q1/Q2 were overstated — no blockers remain

**Correction to my own round-2 report (self-correcting on peer evidence):** I flagged "supported root for the BC precompile" as the one blocking owner question. Grok and Astra demonstrate it is **already resolved by existing documents**, and they are right:

- `BC_AAVE_V4_DEPLOY_STEPS.md:150` (which I myself read in round 1) shows the operator flow starting with `cd .../lib/crane` — the BC precompile runs from **Crane root**, identity prefix `contracts/` (`lib/crane/remappings.txt`).
- IndexedEx tests/`ArtifactCreationCode` run from **IndexedEx root**, identity prefix `lib/crane/` (`remappings.txt`: `@crane/=lib/crane/`).
- `src/spoke/...` is supported by neither root; PRD §5 already says "correct maintained operational emitters/docs to their declared supported root; retain upstream examples only when explicitly labelled upstream" — that text **already authorizes** the `SpokeDeployUtils.getLibraryString` fix, so my Q2 was also already answered.

Astra's formulation is the correct decision rule: validate library artifacts in both projects; Crane operational helpers/BC scripts from Crane root; IndexedEx generic loader from IndexedEx root; if a maintained consumer requires Crane helpers to be portable to IndexedEx root, stop for scope review rather than silently expanding.

**Converged conclusion (Grok, Astra, me; MiniMax partially dissenting): zero blocking owner questions.** MiniMax's B.1 lists five "blocking" questions, but Q1/Q2/Q4 carry defaults that merely restate documented behavior, Q3 is a pre-approval request for a conditional the PRD already gates (§6 FR4 stop-condition), and Q5 is self-labelled a note. Inflating resolved items into blockers risks an unnecessary approval cycle; the PRD's conditional language is sufficient.

**Remaining administrative item (Grok, Astra; I accept):** PRD header/checkpoint (`PRD.md:4,168–170`) still says "awaiting human approval" — record the approved naming decision there without implying execution authorization. Also Astra's clarification that PRD §8 "cold preparation" must be read as a **seeded** fresh workspace per `CLAUDE.md:49–59`, not an unseeded full compile — accept; a genuinely unseeded benchmark would need a separate exception.

## 2. Corrections to peer plans (attributed)

**C1 — My own Phase 4 and Grok's step 3 bootstrap order are wrong; Astra and MiniMax have the right order.** The moderator's hint is correct and I verify it against the code I read in round 1: `forge-artifacts.py` `build` runs the same `plan()` machinery, and `library_artifacts` (`scripts/forge-artifacts.py:198–212`) reads **existing** artifacts' `bytecode.linkReferences`, feeding strict `resolve_artifact` (157–171) — so with stale pre-rename `SpokeInstance.json`/`Pool.json` on disk, the helper fails closed on the removed `.../LiquidationLogic.sol:LiquidationLogic` ID **before building anything**. Bootstrap must therefore be **direct `forge build [PATHS]`** (Foundry build accepts path arguments; Astra cites the Forge book `build.mdx`) of the renamed libraries plus concrete linking dependents, *then* planner invocation. Astra's dependent set is the most complete: renamed libraries + `PoolInstance`, `L2PoolInstance`, `SpokeInstance` + the seed (I had listed `Pool.sol`/`Spoke.sol` but not the v3.6 instance wrappers; accept Astra's broader set — link references live in the deployed instance artifacts). If the planner still names a removed ID after that refresh: report, rebuild the specific stale consumer, and only then consider a narrow reviewed planner change (PRD §8). Never `--force`/`forge clean`/delete outputs.

**C2 — Grok's `--test-root .../SeMatrix_AaveLoopFixture.sol` is not a runnable selection.** The fixture is not a `.t.sol`; `--test-root` needs concrete test files. Astra names the right pattern — select concrete consumers, e.g. `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveCrossVersionLoop.t.sol` and the single/dual normal + decimal (F6/F9) suites discovered at implementation time; record selected counts. My round-2 said "consumers" without pinning the fixture as a root; adopting Astra's concretization.

**C3 — Grok's BC script validation via `forge script ... --sig "run()"` is execution, not compile-only.** `Script_BC_Phase3b` does FFI and `.env` mutation; running it violates the no-execution/no-env-mutation boundary (Grok hedges this itself). Astra's `forge build scripts/foundry/bc/Script_BC_Phase3_Aave.s.sol scripts/foundry/bc/Script_BC_Phase3b_AaveV4_LibraryPreCompile.s.sol` (compile-only) plus hermetic unit tests of `SpokeDeployUtils` string formatting with synthetic inputs is the correct validation. Adopt.

**C4 — MiniMax internal contradictions and root mixing.**
- B.7 says "`--force` is acceptable for clean re-build" while B.10/§157 say "No `--force` on first pass" — and PRD §3/§8 forbid `--force` outright. Correction: `--force` is not available anywhere in this change; the placeholder re-derivation (B.7) needs only a normal incremental build after the rename, which recompiles the renamed units anyway.
- B.10 runs `forge test --match-path 'lib/crane/test/.../**'` from an ambiguous cwd. IndexedEx `foundry.toml:11` sets `test = 'test/foundry/spec'`; Crane test trees are not selectable from IndexedEx root. Crane suites must run with cwd `lib/crane` (Grok's separation is correct); MiniMax's single-block sequence mixes roots.
- B.2 proposes `python3 scripts/forge-artifacts.py resolve "LiquidationLogic.sol:LiquidationLogic"` — `resolve_artifact` is an internal method; the documented CLI subcommands are `plan`/`test`/`build`/`audit` (`ARTIFACT_BUILDS.md:8–62`). Verify the subcommand exists before listing it as a baseline; otherwise use `plan` on a dummy selection or the audit mode. (Unverified command — flag, don't ship.)
- B.7's zero-placeholder check (`forge inspect ... deployedBytecode | grep -c "__\\$"` must equal 0 "after linking") is muddled: a plain build without `FOUNDRY_LIBRARIES` leaves placeholders in `SpokeInstance` bytecode by design; the check as written would fail on a correct unlinked artifact. The meaningful assertions are: the artifact's `linkReferences` key names the new source unit, and the hardcoded constant equals the compile-emitted token (Grok step 8 has this right).

**C5 — MiniMax's five-question blocker table overstates owner input** (see §1); its Q3 grep gate (`creationCode\s*\([^)]*libraryId`) is a reasonable implementation check but the PRD's stop-condition already governs. No approval needed beyond the existing PRD.

## 3. Peer contributions I accept into the consolidated plan

- **Astra §1:** both administrative clarifications (status line; seeded-not-unseeded "cold" reading).
- **Astra §5 + MiniMax B.10:** direct-forge-bootstrap ordering (corrects my Phase 4 — see C1), including `PoolInstance`/`L2PoolInstance`.
- **Astra §4/§6:** placeholder regression that detects mismatch/unresolved placeholders; strengthen `AaveCrossVersionLoop_Invariant.t.sol:114–115` setup regression to assert expected V4 identity (removing the unsupported "stolen" causation comment) while running the real `invariant_APEX_accounting`; extend `ArtifactCreationCode.t.sol` with renamed-source resolution and wrong-source negatives; extend `scripts/test_forge_artifacts.py` with isolated stale-link fixtures. These are test additions sanctioned by PRD §8's "wrong-version/source rejection" gate — acceptable scope, not drift. MiniMax B.11's version-discrimination assertions (getter equals the version-specific deployed library, bytecode-hash equality) overlap; either formulation satisfies the gate.
- **Grok step 8:** placeholder sourced from the Crane-root compile's `linkReferences` key/token, "the compile wins" over any expected string; never copy an IndexedEx-root placeholder into the Crane constant.
- **Grok §PRD-readiness:** status-line staleness; explicit list of implementation-time checks (re-grep, FR4 stop, recorded tool versions, v3.6 provenance discovery with fallback note placement).
- **MiniMax B.2/B.12:** baseline capture list (versions, methodIdentifiers, storageLayout, initcode heads, warm-seed rsync per CLAUDE.md #9) and rollback triggers are good operational detail — adopt minus the C4 caveats.

## 4. Recommended consolidated plan (post-review)

1. **Admin:** update PRD status/checkpoint to record the approved filename-only decision (no execution authorization implied).
2. **Baselines (both roots):** tool versions; `forge inspect` methodIdentifiers/storageLayout for Pool/Spoke and both libraries; artifact provenance snapshot; worktree warm-seed per CLAUDE.md #9 if applicable.
3. **Source edits:** two renames; 11 import retargets (12th site — TestBase import — is deleted with the bypass); TestBase 2-arg restoration; conditional 4-arg overload/plumbing removal gated on zero-caller grep (stop on any other caller, FR4); seed import retarget + NatSpec correction; linker/emitter string updates in Crane-root dialect incl. `getLibraryString` fix and V4-qualified `.env` regex; comment-only updates in scripts; leave the placeholder constant stale until step 5.
4. **Direct bootstrap builds (no planner yet):** IndexedEx root `forge build` of renamed libraries + `PoolInstance`/`L2PoolInstance`/`SpokeInstance` + seed as explicit paths; Crane root `forge build` from `lib/crane`. Then `forge-artifacts.py plan`/`build`/`test`; stale-ID failure = report and rebuild the named consumer, never suppress/wipe/`--force`.
5. **Placeholder re-derivation:** read the token and `linkReferences` key from Crane-root `out/SpokeInstance.sol/SpokeInstance.json`; set `LIQUIDATION_LOGIC_PLACEHOLDER` to the observed value only.
6. **Tests:** Crane suites from `lib/crane` (v3.6 pool suite; v4 liquidation-logic 12 suites + Spoke liquidation/getters/config); IndexedEx root: loader suite, full cross-version family incl. the real invariant run, concrete SeMatrix consumer `.t.sol` files (not the fixture); planner unit tests with new stale-link fixtures.
7. **Script validation:** compile-only via `forge build <script paths>`; validate emitted `FOUNDRY_LIBRARIES` strings in hermetic unit tests with synthetic inputs; no `forge script` execution, FFI, `.env` mutation, or broadcast.
8. **Docs/provenance:** `C4/deployments/README.md`, `BC_AAVE_V4_DEPLOY_STEPS.md` (also drop its `forge build --force` line per Grok — it contradicts PRD §3), greenfield docs review, `VENDOR_PROVENANCE.md` deviation note + v3.6 provenance discovery; archives/audit JSON/skills untouched.
9. **Report:** commands, versions, pass/fail/skip, sizes, old/new ID → salt → initcode-hash → predicted-address table. Missing runs are not passes.

## 5. Blockers

**None.** The PRD plus the approved decision is implementable. The only required pre-implementation edit is the administrative PRD status update; everything else flagged by any participant (supported root, dialect fix, overload conditional, deployed-address tracking, provenance location, tool versions, placeholder value) is an implementation-time check already covered by PRD text or the plan above.

Saved: `docs/research/aave-liquidation-library-rename/round2-kimi-cross-review.md`. Returning to the moderator; stopping for the human.
