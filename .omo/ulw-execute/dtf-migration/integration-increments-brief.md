# Integration of independently verified increments

This phase combines already verified work only. It does not implement a new
Migration feature, adopt an accounting proposal, or close original task 10.

Task-owned worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration`
Task-owned branch: `work/dtf-migration`.
Expected initial HEAD: `90ff0307a7a8e084aa073e02eff125e9c7973933`.
Main checkout and main branch are not edit/integration targets.

## Admitted increments

1. Pricing: `215c2bba6aa75e3e79bf68b7980b730927a85817`.
   Independent evidence is in the phase-02 worktree under the incident
   `migration/pricing/evidence/{verification,correction-verification,commit}/`.
   Exactly 19 committed files; full actual-recovery E3 remains open.
2. Preparation: `6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd`.
   Independent evidence is in phase-03 under
   `migration/package/evidence/preparation-verification/`, with root commit
   receipt in `preparation/commit-receipt.md`.
   Exactly five committed files; default-preserving only.

Both commits have the initial base as parent. Their source edit sets are
disjoint. Verify that fact from the actual commits; do not infer it merely
from this brief.

## Ordered operations

1. Check branch/HEAD and empty index/tracked tree. Preserve any untracked files.
   Advance this owned integration branch to the pricing commit using
   `git cherry-pick --ff <pricing>`, so no source content is rewritten.
   Verify exact commit identity and unchanged tracked tree.
2. Apply preparation with `git cherry-pick --no-commit <preparation>`.
   Require exactly its five paths staged and byte-identical to that commit.
   Do not commit yet. If a conflict or unrelated staged change exists, stop
   with evidence; do not resolve by discarding work or destructive Git.
3. Independently bind the combined files to both accepted manifests, seed warm
   Foundry artifacts before compiling, and execute the combined relevant
   regression scope through the artifact-aware Solar helper.
4. Only after the independent combined verdict is confirmed, commit precisely
   the staged preparation paths in the existing imperative message convention,
   with the required coauthor trailer. Preserve pricing as the parent.
   Verify the resulting parent/tree, exact five paths and clean tracked state.

No push, PR, main merge, rebase, amend, reset, user-file restoration, broad
staging, package install or public-chain action. Every Git invocation uses
`GIT_MASTER=1`; shared Crane link status is excluded intentionally with
`--ignore-submodules=all`, not silently changed.

## Source and test contracts

Read both source manifests and independent reports from their task worktrees.
Pricing source manifest is
`docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/implementation/source-manifest.json`;
the corrected QA script and guard use correction-verification bindings.
Preparation manifest is its `migration/package/evidence/preparation/source-manifest.json`.

The build source list is the union of manifest Solidity paths under
`contracts/`, not test/script roots. Required test roots:

- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf`
- `test/foundry/spec/vaults/detf/common`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration`
- The pricing increment's verified weighted-hook, receipt TransitionQuote,
  V3 FullRangeBook/Previews and V3 InQuery declaration roots, taken exactly
  from its recorded final command (inspect, do not execute an unparsed file).

Use one artifact-first `python3 scripts/forge-artifacts.py test` invocation
with those sources and deduplicated test roots, `-- -vv`, from the integration
worktree. Select `/Users/cyotee/.foundry/bin`, and all expanded compiling Forge
commands must use `--use solar`. The combined source tree is a new input, so
this is a justified integration check, not a repeat of unchanged prior runs.
No local RPC scenario rerun is requested; the script/guard bytes are unchanged.

Preserve the staging boundary while running checks. No source/test changes in
the verification node; report any new failing integration with its exact
signature for root to address. Existing failures must be independently
demonstrated, never edited green. Require real executed counts, exit 0,
current artifacts, and no suppressed diagnostics/warnings.

## Evidence and resources

Author only new evidence under this integration worktree:
`docs/incidents/2026-09-16-dtf-recovery/migration/integration-increments/`.

- `pricing-land.md`
- `preparation-apply.md`
- `verification/report.md` plus captured commands/raw logs/manifests
- `commit-receipt.md`

No prior phase evidence is moved, overwritten or deleted. Before first Forge
compile, seed integration-owned `out/` and `cache_forge/` from green phase-03
outputs. Source worktree has no active Forge writer. Use read-only-use links
to main `lib/crane` and `node_modules` only where these integration-owned paths
are absent/empty; do not replace populated user directories.

Keep explicit task-owned TMPDIR and runtime-cache variables, monitor finite
build/test completion without short kill deadlines, and clean only created
temporary resources. Retain worktree artifact caches for later implementation;
their final cleanup remains separately tracked.

This phase ends at a verified combined local commit. The R3 accounting design
and owner/source questions are independent. No original-plan completion or
release readiness follows from this integration checkpoint.
