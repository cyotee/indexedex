# PairToken SE stage-one implementation/testing plan council

## Run and authorization

- Run ID: `pairtoken-se-stage-one-plan-20261028-01a1810f`.
- Profile: research/document authoring; full four-member Native council.
- Owner request: "Thank you. Now please have the council write the implementation and testing plan file. Plase it next to the PRD file."
- Coordinator mode: invoking agent, not an additional independent vote.
- Required deliverable: a decision-complete, dependency-ordered implementation
  and testing plan for the current revised PRD, published beside that PRD.
- Authorized final path:
  `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_IMPLEMENTATION_AND_TEST_PLAN.md`.
- No contract implementation, PRD edits, tests/builds, installs, deployment,
  wallets, Git commands, configuration changes, or unrelated files.
- The owner explicitly authorizes this co-located Markdown plan. Historical
  OpenCode-only publication restrictions do not change this Native assignment.

## Authoritative inputs

Read the complete immutable snapshot `inputs/PRD.md` under this run root.
It is byte-identical to the source PRD at admission:

`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`

SHA-256: `574ce6c03c0bc62f79a816e5a7775c831cb932082e0dd4bfe414fc1945ed7a7f`

The coordinator computed this from the raw source text. Members need not run a
hash command; a repeated supplied hash is not independent verification.
Read in bounded chunks until complete; a tool truncation notice is not EOF.

This is the **revised** PRD with 70 acceptance rows, not the earlier 57-row
assessment target. Its specified equations and owner decisions govern the plan:

- One full-range V4 position and one public 18-decimal share supply.
- No dead shares, redemption retention, or baseline protocol-fee routing.
- Correct caller/holder reserve and fee attribution under S1-ACC-06/07:
  caller-only additions, post-entry-swap incumbent snapshot, actual removable
  principal growth, paired residual credit and zap uncredited residual policy.
- Full baseline compounding plus defined fee checkpoints.
- Withdrawal-only, preflight-selected **conditional** collection-only fallback
  under S1-EXIT-01; never blanket exception catching.
- Native ETH plus wrapped ERC-20 faces, exact-output explicitly unsupported.
- Spot-accounting SY rate with canonical raw-unit scaling.
- Five specified reusable facets; no factory-provided facets in package cuts.
- Exact projection with per-candidate work bound and two-candidate withdrawal
  planning, source-defined failure domain, and deployment gas/code-size gates.
- All S1-A01 through S1-A70 and the specific family ABI are in scope.

Do not reopen settled choices or substitute a different issuance equation,
fallback, fee policy, share supply, oracle, route set, or genesis sink. If a
genuine contradiction or infeasibility remains, identify it explicitly as a
planning blocker with a precise requirement reference and proposed resolution;
do not silently rewrite the PRD.

## Admitted context

Read repository instructions and directly relevant local sources needed to
make concrete planning decisions:

- `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding/deployment/testing
  documents; relevant portions of `docs/agent/INDEXEDEX_AGENT_LAW.md`.
- Canonical Crane architecture/deployment/testing guidance and
  `.claude/skills/indexedex-testing/SKILL.md`.
- `contracts/pairtoken-baseline/PairToken.sol`, `PairTokenMath.sol`,
  `interfaces/IPairTokenDependencies.sol` as behavioral comparison context.
- The five canonical facets and their Repos; V4 manager/math/state/settlement
  interfaces; shared SE/SY, registry, artifact-loading, and LocalCreditLib code.
- Existing current-family package/FactoryService/TestBase/test examples when
  directly relevant. Wings is packaging/test context, not an economic template.
- Read `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol`
  and `ScriptedDependencies.sol` before recommending baseline comparisons.
  Keep that fixture stable, use fresh real SUT instances, never subclass,
  inject storage into, or etch the SUT. No test execution during this council.

No peer contributions, previous council reports, private memory, external
baseline reconstructions, or unrelated product redesigns are initial-pass
evidence. No implementation exists for this new family; proposed file paths
must be labeled proposed rather than claimed as already present.

External research is not required. If a public primary source is necessary,
use generalized public identifiers only and record the exact query/citation.
Never send private source to public search.

## Shared authoring question

Produce an independent implementation and testing contribution that an engineer
can execute from the revised PRD without making new product choices. Include:

1. Concrete production file/component map, canonical reuse paths, proposed new
   family Targets/Facets/Repos/libraries/interfaces, and initialization ownership.
2. Dependency-ordered work packages, minimal coherent increments, prerequisites,
   implementation actions, and observable exit evidence for each.
3. Exact implementation approach for the operation ledger, fee checkpoints,
   caller-attributed issuance, proportional exits, and fallback classification.
4. Exact-view projector architecture: copied state/overlays, fee/tick/position
   transitions, native/wrapped input isolation, budgets, and invalidation.
5. A viable arithmetic approach for S1-QUOTE-02's single-floor rational price
   conversion without unsafe intermediate overflow; do not substitute two
   sequential floors as if equivalent.
6. Full typed ABI/selector ownership, shared facet preservation, registry
   sorted contents identity, proxy read policy, and runtime code-size strategy.
7. Production-first real-manager fixtures, declaration Behaviors, independent
   math controls, fuzz/invariant handlers, and regression placement. Scripted
   baseline fixtures are characterization only, not new-family acceptance.
8. A coverage mapping for **every** S1-A01 through S1-A70 to a proposed test
   suite/case and assertion. Group cases when justified but omit none.
9. Artifact-first build/test commands using the current repo workflow, cache
   and compiler constraints, release gates, evidence and handoff format.
10. Concrete blockers/assumptions with source locators. Keep unmeasured gas,
    unrun tests, and unproved economics labeled.

Do not write a replacement PRD, partial implementation, pseudocode that hides
an unresolved economic decision, or instructions to perform unapproved Git/
deployment actions. Do not demand a new council or implement the plan.

## Roster and independence

| Member | Role | Exact requested model |
| --- | --- | --- |
| Astra | council-member | chatgpt-subscription/gpt-6-astra:high |
| Grok | council-member | xai/grok-4.7:xhigh |
| MiniMax | council-member | minimax/MiniMax-M3, existing adaptive setting |
| Kimi | council-member | kimi-coding/k3.1-pro:high, global route |

Fresh independent planning tasks, not continuations of the earlier PRD
assessment. No provider/model/account fallback and no subagent delegation.
The loaded ordinary role permits direct-child depth; existing MiniMax
forceAdaptiveThinking is configured. Record actual identity only from Native.

## Delivery and owned artifacts

All initial members deliver their **complete contribution inline in one final
response**. This is intentional: some exact-route members do not expose
apply_patch. Do not write any file, search for alternative writers, or return
only a path/summary. Do not emit a second final summary after the complete body.
The coordinator archives each exact response under
`coordinator/received/<member>-original.md`.

Use headings: Identity; Inputs and coverage; File/component map; Implementation
stages; Testing plan and A01-A70 matrix; Validation/release gates; Blockers and
limits. Be concrete rather than repeating the full PRD or copying source.

Coordinator owns the unique run's snapshot, brief, RUN, received-text archives,
one frozen draft, resolution, and report; it alone publishes the authorized
co-located implementation/testing plan. The original PRD is read-only.

After all initial tasks settle, the coordinator synthesizes one identified
draft. Members then get one separate draft-only advisory assignment, inline
feedback only. No peer-original reading before submission; no advisory pass
until specifically assigned. Same inherited permissions do not enlarge scope.

## Settlement and limits

Wait for every requested initial/advisory task to settle. Quiet work stays
pending. Three substantive originals after all four settle may support a
labeled partial council; fewer than three blocks full synthesis. No unilateral
roster substitution.

At most three council-issued attempts per logical member assignment and two
per synthesis, including initial attempts. Delivery-only recovery is recorded.
No retry for disagreement, low confidence, or auth/policy failure; no imposed
silence deadline or consumption budget. A plan and advisory support do not
authorize implementation.
