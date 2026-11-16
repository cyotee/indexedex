# Stateful invariant gate intake

2026-11-12; read-only assessment of immutable cumulative4eaa7dec in the phase21 worktree. The current source/intake implementation continues separately. This does not claim invariant coverage or authorize work on the held deployment-gas lane.

## Evidence gap

Literal search across52 Migration-named Foundry files found no invariant_, handler-contract, targetContract or targetSelector declaration. A second search across85 invariant-named Foundry files found no Migration reference. These are bounded filename searches, not proof that no differently named helper exists. The accepted phase21 report establishes167 specifications and139 fork tests, but does not establish the section8.2 stateful gate. Before adding tests, inspect actual TestBase/invariant patterns and confirm which required properties already have stateful coverage. Do not relabel deterministic scenarios or pure fuzz arithmetic as stateful action sequences.

The pending parent task remains Complete integration invariant adversarial and fork validation. It is not closed by repeated green source-specific suites.

## Required property inventory

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

## Implementation boundary for the next stable cumulative base

Use production registry/factory deployment and the existing TestBase_UniswapV4DetfMigration chain. Follow canonical IndexedEx/Crane testing rules. Prefer hermetic coverage for native Migration lifecycle and accounting; only actual pinned legacy sources may supply legacy custody/recovery witnesses where canonical source addresses make hermetic execution unavailable. No counterfeit source identities, SUT mocks, storage/code injection, ordinary/common/Crane production edits, configuration changes or held09 access. Source unit classes and unsupported categories must remain explicit.

Handlers must maintain independent expected quantities and exact failure-state snapshots, with bounded valid actions and exact expected reverts rather than broad catches. Require real successful-action witnesses so no-op/revert-only action streams cannot appear as coverage. Make these witnesses deterministic rather than requiring a lucky random selector sequence. Time advancement is appropriate only for the actual cliff/time behavior. Model wallet-bound credit, actual source custody, authorized independent issuance and backing separately; do not derive the expected result solely from the SUT value being asserted.

Map all12 stateful properties and applicable adversarial catalog items to actual test/handler assertions and successful action evidence, or an explicit remaining gap. Preserve ordinary-family regression obligations and the separate eventual full-hermetic run. Test-only changes should be added to the next accepted cumulative base, not concurrently spliced into the presently active claimed-SY candidate or treated as an already verified merge. Scoped build/test commands and replay seeds must be recorded; no unchanged full-suite rerun for documentation alone.

No test, build, RPC, source/ref/index edit or held-lane execution occurred in this assessment. The active phase23 corrected implementation/verification subscription remains the next prerequisite for that cumulative handoff.


## Confirmed existing fixture seams

Read the complete immutable phase21 TestBase_UniswapV4DetfMigration.sol. Native Solidity document-symbol lookup timed out; direct source inspection supplied this assessment, not a clean LSP result. The fixture already builds actual WETH, real V3 pools/SE packages, the weighted hook and registry-deployed Migration plus actual bond/receipt/SY children. Its mintable contribution/rate currencies and external liquidity seeder are explicitly non-SUT fixtures. No new mock or alternate deployment path is needed for native lifecycle invariants.

- `TestBase_UniswapV4DetfMigration.sol:79`: `function setUp() public virtual override {`
- `TestBase_UniswapV4DetfMigration.sol:92`: `function _migrationEnvironment() internal {`
- `TestBase_UniswapV4DetfMigration.sol:281`: `function _deployMigration(MigrationPackage.PkgArgs memory args_) internal returns (address parent_) {`
- `TestBase_UniswapV4DetfMigration.sol:312`: `function _fundAndCapture() internal {`
- `TestBase_UniswapV4DetfMigration.sol:327`: `function _configure(address recipient_, uint256 original_, bytes32 id_) internal returns (uint256 credit_) {`
- `TestBase_UniswapV4DetfMigration.sol:340`: `function _buyOwnerFirstBond() internal returns (uint256 id_) {`
- `TestBase_UniswapV4DetfMigration.sol:344`: `function _buyOwnerFirstBond(uint256 amount_) internal returns (uint256 id_) {`
- `TestBase_UniswapV4DetfMigration.sol:353`: `function _issue(address recipient_) internal returns (uint256) {`

Use _fundAndCapture for a genuine donated/bootstrap reserve and frozen snapshot, _configure/_issue for authorized independent allocation state, and _buyOwnerFirstBond for actual paid capital rather than a synthetic reward seed. Independent issuance can provide nonvacuous hermetic funded-bond witnesses without pretending that legacy assets were surrendered. Actual source custody/recovery still needs appropriate admitted fork fixtures.

_deployMigration can create a distinct owner-aware proxy for isolation properties, but it also assigns the fixture reserveHook member; a second-instance test must retain each actual proxy/hook/children/snapshot identity instead of accidentally checking one fixture variable twice. Funding, configurations, issuance, ownership and real cliff state must be kept per instance. Existing helpers return actual credits/IDs; ghost conservation must track observed initial configuration versus subsequent independent action effects, not simply echo current SUT values.

No source, runtime or acceptance status changed. This narrows the next test implementation to existing real fixture seams after the currently running immutable-delivery gate supplies the next accepted base.
