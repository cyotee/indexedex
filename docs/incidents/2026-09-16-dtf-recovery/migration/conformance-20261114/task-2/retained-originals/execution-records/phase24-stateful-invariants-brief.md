# Migration stateful invariant gate

Implement the plan section8.2 stateful gate on cumulative audited15fd629375edeb361f6a39262795bdc66723ca3a. Worktree `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants`, branch work/dtf-migration-phase-24-stateful-invariants. Warm artifacts/cache are copied from stopped accepted phase23; dependency links are unchanged. This is a test-only unit, not the held phase09 deployment-gas lane, not operational allocation or deployment. No held09 inspection/import/replay, optimization or alternate-provider route is authorized.

Read current main implementation plan/PRD, root stateful-invariant-intake.md including actual fixture seams, canonical IndexedEx/Crane testing, programming/test-discipline rules and relevant test/deployment law. Read the complete actual phase23 implementation/r2/immutable reports, all declared source admission boundaries needed by chosen handlers and current production/TestBase code. The complete-original claimed-SY subset remains direct-EOA isolated-source-block only; ordinary-SY contract callback coverage must not be relabeled claimed-origin source evidence.

## Deliverable and owned paths

Deliver real stateful handlers, independent expected-state models, invariant tests and exact executed coverage for all twelve properties below. First confirm actual existing coverage: root bounded searches found no invariant_ target in52 Migration-named files and no Migration reference in85 invariant-named files; not a proof that differently named helpers do not exist. Reuse proper existing patterns rather than duplicating working coverage.

Allowed code edits are NEW test infrastructure under contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/ and NEW tests under test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/ and test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/. Keep few coherent names/files, no generic framework. Do not edit existing TestBase, tests, production, operator/runbook, configuration/dependencies or prior evidence. If a real SUT failure appears, retain its reproduction and report to root; do not weaken a test or silently patch production. Producer owns implementation/ evidence, independent verifier owns verification/. No commit/ref/index changes in these runtime lanes.

## Exact plan properties

### 8.2 Stateful invariants

- For unchanged configuration, remaining/delivered wallet-bound frozen credit conserves the configured eligible claim subject only to explicitly retained integer residue. Ordinary ownership transfers do not move that compensation record.
- No surrender succeeds without a matching configured entitlement and the recorded original wallet's actual eligible asset; rejected unconfigured/wrong-wallet calls leave custody, credit, supply and bonds unchanged.
- A configuration correction cannot modify any existing bond, consumption fact or custody event.
- No successful credit exists without matching irreversible custody or an authorized independent allocation.
- No custody debit or entitlement consumption survives failed issuance.
- `stakingValue(position) >= remainingPrincipal(position)` for every live funded bond.
- No migration principal leaves before its own `unlockTime`.
- No Stage 1 route pays new-instance rewards.
- No Stage 2 action restores or emulates configuration/independent-issuance authority.
- Pool trading, fee changes, provider-rate changes and later donations do not alter configured original credit.
- Total recovery balances reconcile by asset and stage; no recovered asset reaches an alternative beneficiary.
- Changing a current owner does not change pricing, registry ownership, an existing bond or consumed entitlement.

Adversarial coverage includes A0 donation-before-first-issuance, I1-I3 booked-inventory/pretransfer negatives wherever inherited, J1-J3 real proxy surface, K1 donation theft, E6 residual refund bounds where applicable, N1 callback mutation, fee/creator nondilution, source spoofing, wrapper double-credit, NFT claim/surrender races, activation reentrancy, and custody batch failure. State inapplicable catalog cases with a concrete reason; do not weaken a failing test to close the matrix.

## Real subjects and nonvacuous action models

Use the existing TestBase_UniswapV4DetfMigration registry/factory path and real parent/children/reserve/oracle. Existing _fundAndCapture, _configure, _issue and _buyOwnerFirstBond provide real native lifecycle/funded independent witnesses without pretending legacy custody occurred. _deployMigration supports distinct instances but changes the fixture reserveHook member: retain separate actual proxy/hook/child/snapshot identities. Existing hermetic mintable external currencies/native test funding remain non-SUT fixtures. Never subclass, etch, storage-inject or impersonate the SUT, or mock registry/facets/fee oracle/children.

Hermetic tests are primary for native lifecycle, loading/issuance/activation, actual paid deposits, funding/principal/rewards, owner changes, real pool/fee/rate/donation changes and multi-instance isolation. Real admitted legacy custody/recovery uses pinned fork fixtures in the fork home where fixed historical addresses prevent hermetic execution. Keep source units and provenance explicit; no fabricated legacy balance/code/role or unsupported E-S/raw pull/disabled conversion success. Read existing actual source fixtures before choosing acquisition. Source-donor simulation in Foundry is not a real signature or public consent.

Use Handler/TestBase structure and invariant_* discovery per canonical skills, with a bounded actor/action set and exact ghost ledgers. A meaningful successful action must reach the real SUT; no revert-only/no-op sequence may be reported as positive coverage. Include deterministic successful-action witnesses/preludes without requiring random luck to reach a selector. Report actual action/success/rejection counts and run/depth/seed. Time warp is for real cliff/time behavior, never a synchronization delay. Expected invalid actions must assert exact errors and unchanged economic state; do not swallow unexpected errors with broad catch or reduce counts/seeds to hide a counterexample.

Model quantities independently from the current SUT field being asserted. Keep original source units, original-wallet credit, current holdings, authorized independent credit, actual custody/recovery budgets and new escrow distinct. Configuration changes are constrained by lifecycle and prior delivery; unchanged-configuration conservation is not a ban on authorized preconsumption replacement. Original contribution pricing stays frozen through actual later trades/fee/rate/donation changes. Include actual failed-issuance state restoration, fresh cliff principal limits, Stage1 new-instance reward gating, permanent Stage2 selector removal, ownership and separate-instance invariance.

Coverage must name supported source/unit classes and actual exercised actions, not claim one scalar SY handler proves gon/internal-share/whole-NFT paths. Use current actual source admissions and tests to cover or explicitly identify any remaining unit-specific stateful gap. Unsupported source classes stay unsupported. Ordinary-SY receiver coverage remains ordinary-SY; no new claimed contract-wallet admission. Reference existing deterministic/adversarial tests honestly where they supplement but do not replace stateful assertions.

## Validation and immutable evidence

Artifact-first Solar with required real dynamic FactoryService artifacts, no viaIR/size override. Run the new complete invariant targets and relevant complete Migration specs/forks, plus focused existing ordinary-family regression coverage called for by these shared fixtures, once per final candidate. Use repository run/depth settings or justified bounded settings with actual recorded counts; do not declare a truncated/default no-action run full coverage. Ensure exact commands include new subdirectory targets. Run diagnostics on new Solidity files before builds. Any required failure is preserved and fixed only within allowed new tests when it is a harness defect; genuine SUT failures go to root. Do not edit green an old failing test.

No operator/CLI changes occur, so do not replay the previously green18573 cumulative CLI or its resumes as new coverage. No whole-repository hermetic success follows from this bounded gate; the eventual full repository run remains separate. Forks use existing approved login-shell alias at4663/block108944663/hash0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733. If a local node is genuinely necessary, own18574 and stop it; Foundry forks do not require inventing one. No provider changes, public actions, IPFS or installs.

Retain original source/authority hashes, exact candidate diff/manifest, compiler/source/artifact and actual deployment evidence, full raw logs and any counterexample/replay inputs. Produce a twelve-row property matrix with source locations, independent expected state, actual successful witnesses, random-sequence results and precise limits; catalog applicability separately. Mark unexecuted/inapplicable items accurately rather than treating a table as proof. Stop all source edits and owned processes, then seal implementation/report.md and evidence before independent handoff. Verifier reads actual stopped candidate and independently executes required bounded tests against the exact source, checks model independence/nonvacuity and original preservation, with no source fixes.

The overarching full integration/adversarial/fork task is not automatically done by a bounded increment. Historical originals, E-S, blocked conversions, raw/native/WETH/partial mapping, archive equivalence/portability, full-repo hermetic and target gas remain open. Actual latest registration45,116,678 exceeds32million; no gas solution or held-lane retry is part of these invariants. No dependency/worktree cleanup until safe landing. Separate commit and immutable audit follow actual confirmation.
