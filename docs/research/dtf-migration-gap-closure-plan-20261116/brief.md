# Council implementation-plan authoring brief

## Authorized outcome

The user asks: "Have the council write a implementatio plan for closing these gaps."
Write one executable implementation and test plan for the accepted migration
review findings and the pricing-evidence qualification. This is planning only.
Do not implement code, execute project tests/builds, or transact.

Profile: research/plan authoring. Full council: Astra, Grok, MiniMax, Kimi.
Coordinator: invoking agent. Current implementation checkout:
`/Users/cyotee/Projects/indexedex`.

Run root: `docs/research/dtf-migration-gap-closure-plan-20261116/`.
Final plan: `IMPLEMENTATION_PLAN.md` in this run root.
The original migration plan and review report remain unchanged.

## Required inputs and precedence

Read the complete final review and its resolution:

- `docs/reviews/dtf-migration-implementation-council-20261116-0228/REMEDIATION_PRD.md`
  (SHA-256 `5df379c5865f3be2f74b70a834e1c48965b30c86697aeef41619b41dd36393ba`).
- `docs/reviews/dtf-migration-implementation-council-20261116-0228/coordinator/resolution.md`
  (SHA-256 `4c4cf99eff4899a69f94b245665c7717097b342f3b9bb96c7bc02ed4d70ffe49`).
- `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`
  (SHA-256 `affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949`).

The coordinator refreshed these inputs and the five principal affected source
files before this assignment; they match the earlier review's read bytes.
These hashes are supplied provenance; no member hash recomputation is required.
The working tree remains live, not an atomic snapshot.

The November 15 owner correction and sections 1.1-1.10 govern. Preserve native
Foundry scope; no custom CLI, preparation application, bundle/journal framework,
holder-transfer ancestry requirement, automatic price capture, or selected
live-production-composition prerequisite is to be restored.

The prior council's accepted findings are inputs to close, not an invitation
to repeat the whole audit or refile rejected claims. Its rejected adapter
dependency, absent-gas assertion, and mandatory NFT-wrapper interpretation
must not reappear as requirements.

## Five gaps to close

1. **F1, production funding:** a permitted partial bootstrap leaves legitimate
   `donationInventory` unable to reach reserve liquidity. Select one concrete
   minimal repair using the existing accounting and reserve route. Explain exact
   state transitions, placement, rounding/refunds, bounded work and pre/post
   activation availability. Preserve unsolicited assets, legacy recovery
   inventory, protected backing, and immutable activation. No arbitrary
   withdrawal/execution or new discretionary authority.
2. **F2, retained native QA:** `MigrationCoreLocalOwner` cannot make the genuine
   owner-first purchase required by activation. Specify the helper API, source of
   actual payment, transaction sequence, ordinary terms, expected NFT identities
   and necessary changes to hardcoded assertions/metadata calls. Execute the
   retained two-stage lifecycle in the future plan, not just compile it. The
   production prerequisite remains correct and unchanged.
3. **F3, metadata:** ordinary owner-first bonds display closed rewards as
   claimable. Separate parent activation-based reward availability from principal
   vesting style across numeric JSON and rendered output; preserve ordinary
   packages, reserved roles and migration cliffs.
4. **F4, documentation:** plan-named evidence must navigate to the current
   native implementation, real commands/results, source/compiler applicability,
   gas limits, and unresolved work. Preserve historical evidence. Make the
   runbook portable and its exact typed function coverage explicit, including
   operations not wrapped. Do not require adding the optional NFT wrapper.
5. **P1, pricing evidence qualification:** distinguish existing real-proxy
   V3/disabled-buffer comparisons from Raw/RawRate arithmetic vectors. Inspect
   current fixtures and determine the exact existing or missing observed-hook
   comparisons. Plan the minimal production-first differential coverage needed
   to establish Raw/RawRate parity, or cite already sufficient evidence. Treat
   this as an evidence obligation unless an actual arithmetic defect is found;
   do not presume pricing is wrong or invent a universal nested-vault model.

## Admitted code and evidence

Read current relevant code, tests and repository rules to settle design choices.
Primary roots:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `scripts/foundry/recovery/dtf-migration/`
- `docs/incidents/2026-09-16-dtf-recovery/migration/`
- Relevant shared DETF/bond/Weighted math, metadata, deployment and test fixtures.

Canonical repository router/law and testing skills apply. Source reads of Crane
and direct dependencies are allowed when needed. Read `.github/ASSISTANT_RULES.md`
and its coding/testing/deployment rules as needed to specify executable work;
this does not authorize implementation during planning.

Existing test evidence is in `.omo/verification/dtf-operator-removal-20261115/`
and `.omo/verification/artifact-mismatch-20261116/`. Some raw historical logs
reside in the original conformance worktree, as the final review records.
Use historical worktrees only as evidence, not as implementation targets.
The numeric gas record is
`migration/conformance-20261114/task-11/batch-limits.md`.
Do not repeat a broad archive census or hash an entire repository.

## Independent authoring contribution

Each member proposes one coherent recommended implementation plan covering all
five gaps. Alternatives may be dismissed briefly, but leave no unresolved menu
where current code and invariants can settle the choice.

Include:

- Identity, Question and targets, Evidence, Assumptions, Coverage, Proposed plan,
  Conclusions, and Limits. This is authoring: omit a new Review findings section.
- For each gap: exact files/symbols, chosen mechanism, invariants and explicit
  exclusions, failure/rollback behavior, production-first regressions with
  concrete names or existing test locators, and observable acceptance.
- A dependency-ordered task list with individually verifiable units and parallel
  boundaries only where edits do not collide. Shared edits and test fixtures
  need explicit ordering.
- Exact future verification commands and evidence destinations. Use Solar for
  every compiling Forge command. Refresh concrete runtime artifacts before tests;
  use current `scripts/forge-artifacts.py` workflows. Never retarget FOUNDRY_TEST,
  delete caches, weaken tests or use mocked SUTs. Distinguish hermetic tests,
  pinned legacy forks, native local-script execution and public broadcasts.
- A realistic native-QA procedure using existing repo local-node conventions.
  Do not invent a nonexistent launcher or silently require public funding.
  Any needed new local QA test/fixture must be explicitly in the plan.
- A final gate that proves every gap closed with source-bound passing evidence,
  ordinary-family regressions, actual residual progress and metadata output,
  no stale-artifact substitution, and a current completion record.
- Label facts read, design inferences, and unverified points. Ask no question
  answerable from source. If a real owner product decision cannot be settled,
  isolate it precisely; do not invent a new authority or behavior to avoid it.

The plan must not assume an already activated immutable deployment can be
upgraded. Source changes and fresh verification/deployment artifacts are in
scope for the future implementation; any live-deployment repair is a separate
explicit decision and authorization.

## Ownership and stop

Continue your original council session, but this is a new logical planning
assignment and a new artifact root. Prior review context is common background.
Do not read another member's new planning response before submitting your own.
Do not read prior peer-original files; the final review and resolution suffice.

Your sole writable path is
`docs/research/dtf-migration-gap-closure-plan-20261116/members/<member>/response.md`.
Use apply_patch. If unavailable, return the complete contribution inline and
do not use an alternate writer. The coordinator can archive inline output.

No subagents, shell/project commands, builds, tests, installs, Git, RPC/wallet/
transactions, code/config edits, or external messages. Bounded read-only
filesystem/eval, read/glob/grep and native read-only code navigation are allowed.
Only the coordinator writes the common brief, run record, synthesized draft,
resolution and final plan.

Stop after delivering your complete independent contribution. The coordinator
will synthesize one plan and request one advisory pass on an identified draft.
No contribution authorizes implementation or demands another review round.
