# Product Requirements Document (PRD)

## Title
Protocol DETF Rename Plan: Protocol DETF -> DualSelfCommonDETF

## Purpose
Define a safe, staged refactor plan for renaming the current Protocol DETF codebase to its new product identity without breaking behavior, package wiring, test coverage, CREATE3 deployment expectations, or external integrations.

This document is intentionally a rename-execution plan rather than a feature PRD. The goal is to make the naming change systematic, auditable, and behavior-preserving.

## Naming Decision Locked
- The canonical target family name is `DualSelfCommonDETF`.
- `DualDelfCommonDETF` is treated as a rejected typo and should not appear in code, docs, tests, or deployment metadata.
- Before implementation starts, the team still needs to lock all of the following around the canonical name:
  - canonical contract/class/file prefix
  - canonical interface prefix
  - canonical package/factory-service prefix
  - canonical test folder and test-contract prefix
  - whether any user-facing token names or symbols change

## Rename Objective
- Replace the legacy `ProtocolDETF` naming family with the canonical `DualSelfCommonDETF` naming family.
- Preserve runtime behavior, storage layout, function selectors, and protocol semantics unless an explicit compatibility-breaking decision is approved.
- Separate pure code-symbol renaming from any public API renaming that would change external integrations.

## Scope
- Contracts in `contracts/vaults/protocol/`
- Interfaces in `contracts/interfaces/`
- Proxy interfaces in `contracts/interfaces/proxies/`
- Factory services, packages, repos, common helpers, and preview helpers
- Protocol NFT vault references that currently point to `ProtocolDETF`
- Rebasing token references that currently expose `protocolDETF` semantics
- Foundry tests under `test/foundry/spec/vaults/protocol/`
- Deploy and package wiring that uses class names, type names, salts, or labels derived from `ProtocolDETF`
- PRD and inline documentation referring to the old family name

## Out of Scope
- No behavioral redesign of the vault family
- No route-logic changes
- No threshold-policy changes
- No pool-composition changes
- No tokenomics changes unless separately approved
- No cross-family consolidation work beyond what is required to complete the rename safely

## Current Rename Surface

### Primary contract family
- `BaseDualSelfCommonDETF*`
- `EthereumDualSelfCommonDETF*`
- `DualSelfCommonDETFSuperchainBridgeRepo`
- `ProtocolNFTVault*`
- `RICHIR*` members and helpers that reference `protocolDETF`

### Primary interface family
- `IProtocolDETF`
- `IProtocolDETFErrors`
- `IProtocolDETFProxy`
- `IProtocolNFTVault` methods and parameter names that expose `protocolDETF`

### Primary test surface
- Foundry spec files under `test/foundry/spec/vaults/protocol/`
- test bases and helper fixtures using `ProtocolDETF` names
- Ethereum/Base variants with duplicated rename requirements

### Hidden rename traps
- CREATE3 salts derived from `type(X).name`
- `vm.label(...)` debugging names
- package metadata via `packageName()` and `vaultDeclaration()`
- facet metadata via `facetName()`
- interface docs and NatSpec titles
- filenames and folder names imported directly by remapped paths
- external function names like `protocolDETF()` that may be part of integration contracts

## Product Constraints
- The rename should preserve the current behavior of Base and Ethereum variants.
- The rename should be executed in narrow, reversible slices.
- Focused tests must stay green after each slice.
- Broad validation must run after the migration reaches a coherent checkpoint.
- The migration must not accidentally change storage slots, storage structs, or selector sets unless a specific compatibility break is approved.

## Key Compatibility Decision

### Decision A: Internal rename only vs public API rename
The highest-risk question is whether the rename changes only internal symbols or also changes public interface names and method names.

#### Option 1: Internal rename only
- Rename files, contracts, libraries, packages, tests, docs, and internal symbols.
- Keep public interfaces and method names such as `IProtocolDETF`, `protocolDETF()`, and related selectors stable.
- Lowest integration risk.
- Produces mixed vocabulary in some public APIs.

#### Option 2: Full public rename
- Rename public interfaces and externally visible methods to the new family name.
- Requires compatibility analysis for:
  - proxies
  - token contracts
  - NFT vault contracts
  - deployment scripts
  - any off-chain integrations
- Higher clarity, higher migration cost, higher break risk.

### Recommended default
- Start with Option 1 unless the team explicitly wants a breaking rename.
- If Option 2 is chosen, it should be implemented after a full internal rename lands and the codebase is stable.

## Execution Strategy
- Treat the rename as a migration program with explicit phases.
- First isolate spelling and compatibility decisions.
- Then rename lowest-risk internal artifacts.
- Then rename the contract family.
- Then decide whether to rename public interfaces/selectors.
- Validate after every phase with the narrowest relevant tests.

## Implementation Phases

### Phase 0: Naming lock and compatibility contract
- Use `DualSelfCommonDETF` as the canonical target name everywhere new naming is introduced.
- Approve whether the rename is:
  - internal-only
  - or full public API rename
- Approve whether the folder `contracts/vaults/protocol/` remains the same or is renamed later.
- Approve whether test folder names remain `protocol/` for continuity or move to a new family folder.

Acceptance criteria:
- The canonical spelling is documented and used consistently in the rename ledger.
- The compatibility level is explicitly decided.
- The team agrees on whether to preserve existing external selectors.

### Phase 1: Inventory and mapping table
- Build a concrete rename ledger before code edits begin.
- Record each old symbol/file and its intended new symbol/file.
- Include:
  - files
  - contracts
  - interfaces
  - libraries
  - package types
  - factory-service functions
  - test contracts
  - test filenames
  - string metadata from `type(X).name`

Deliverable:
- A checked mapping table committed alongside the implementation branch or tracked in the task notes.

Acceptance criteria:
- No rename is performed without an entry in the mapping table.

### Phase 2: Documentation and product-language rename
- Update PRDs, comments, NatSpec titles, and product references first.
- Keep behavior unchanged.
- Rename explanatory text before renaming code to reduce ambiguity during code review.

Targets:
- protocol family docs
- comments in interfaces and top-level contracts
- deploy/readme references where they describe the product family

Acceptance criteria:
- Documentation consistently uses the locked canonical product name.
- No code behavior changes are introduced in this phase.

### Phase 3: Internal helper/library/repo rename
- Rename the lowest-risk internal artifacts first.
- Recommended first candidates:
  - common helpers
  - preview helpers
  - repo libraries
  - factory-service libraries
  - package interfaces/types that are not yet public integration boundaries

Goals:
- Reduce the blast radius before touching user-facing interfaces.
- Keep imports coherent.
- Keep the folder-local architecture easy to follow.

Acceptance criteria:
- Internal artifacts compile.
- Base and Ethereum focused tests still pass.

### Phase 4: Contract family rename
- Rename the main contract/type family in `contracts/vaults/protocol/`.
- This includes:
  - `BaseDualSelfCommonDETF*`
  - `EthereumDualSelfCommonDETF*`
  - package contracts
  - facet contracts
  - target contracts
  - common helpers
  - factory services

Requirements:
- Keep inheritance trees intact.
- Update imports in narrow batches.
- Preserve storage libraries and storage-slot constants unless a separate migration explicitly approves a slot rename.

Acceptance criteria:
- Contracts compile after each batch.
- No accidental storage-slot or selector drift is introduced.

### Phase 5: Interface and proxy rename decision point
- If the project chose internal-only rename, stop short of public selector changes.
- If the project chose full public rename, rename:
  - `IProtocolDETF`
  - `IProtocolDETFErrors`
  - `IProtocolDETFProxy`
  - method names such as `protocolDETF()` if approved

Requirements for full public rename:
- compare old vs new selector sets
- decide whether shims or compatibility wrappers are needed
- decide whether token and NFT vault contracts expose both old and new names during transition

Acceptance criteria:
- Public rename does not proceed without an explicit compatibility sign-off.

### Phase 6: Deployment/package metadata alignment
- Update any logic that depends on `type(X).name` or package/facet names.
- Review:
  - CREATE3 salt derivation
  - package metadata
  - `facetName()`
  - `packageName()`
  - labels and deployment assertions

Risk:
- Renaming a type changes `type(X).name`, which can change deterministic salts and addresses when those names are hashed.

Required decision:
- either preserve old salts intentionally
- or accept new deterministic addresses as part of the rename

Recommended default:
- preserve existing salts where stable addresses matter
- do not let naming cleanup silently change deployment identity

Acceptance criteria:
- Salt/address policy is documented before these renames land.

### Phase 7: Test surface rename
- Rename test contracts and filenames after the production code is stable.
- Update test helper names, fixtures, and harness docs.
- Keep test coverage grouped by behavior, not by rename batch.

Acceptance criteria:
- Focused Protocol/Base/Ethereum tests are still easy to discover and run.
- Test names reflect the new canonical family name.

### Phase 8: Cleanup and deprecation pass
- Remove stale comments, aliases, and dead compatibility glue that are no longer needed.
- Keep only the minimum compatibility shims approved by the team.
- Ensure repo search for `ProtocolDETF` shows only intentional legacy references.

Acceptance criteria:
- Remaining `ProtocolDETF` references are documented and intentional.

## Validation Plan

### Validation principle
- After each substantive rename slice, run the narrowest behavior-scoped tests that prove the renamed surface still works.
- Use broad validation only after a coherent migration checkpoint.

### Focused validation anchors
- Base route previews and execution:
  - `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
- Ethereum route previews and execution:
  - `test/foundry/spec/vaults/protocol/EthereumDualSelfCommonDETF_Routes.t.sol`
- NFT vault behavior:
  - `test/foundry/spec/vaults/protocol/ProtocolNFTVault.t.sol`
  - `test/foundry/spec/vaults/protocol/ProtocolNFTVaultPermissions_Negative.t.sol`
- Bonding/sell flows:
  - `test/foundry/spec/vaults/protocol/ProtocolDETFBonding.t.sol`
  - `test/foundry/spec/vaults/protocol/ProtocolDETFSellNFT.t.sol`
  - Ethereum variants where applicable
- Minting/synthetic threshold behavior:
  - `test/foundry/spec/vaults/protocol/ProtocolDETFMinting.t.sol`
  - `test/foundry/spec/vaults/protocol/ProtocolDETFSyntheticThresholds.t.sol`

### Broad validation checkpoint
- Run `yarn test` after the production-code rename reaches a stable checkpoint.
- If full public API renaming is chosen, run `yarn test` again after interface/proxy changes settle.

## Risks and Controls

### Risk 1: Name-only rename changes deterministic deployment addresses
Control:
- Audit every `type(X).name` and hashed-name salt before renaming package/facet types.

### Risk 2: Public selector drift breaks integrations
Control:
- Keep public API stable by default.
- Only rename external method names with explicit sign-off.

### Risk 3: Storage/layout drift during repo/library rename
Control:
- Do not rename storage-slot constants as part of the rename unless separately approved.
- Treat storage slot names as compatibility artifacts, not branding artifacts.

### Risk 4: Large-batch import churn causes avoidable compile noise
Control:
- Rename in narrow slices.
- Validate between slices.
- Avoid repo-wide bulk text replacement without per-slice review.

### Risk 5: Mixed vocabulary leaves the codebase harder to understand
Control:
- Keep a mapping ledger.
- Finish documentation and cleanup phases.
- If public API names remain legacy, document them as intentional compatibility vocabulary.

## Recommended Slice Order
1. Lock canonical spelling and compatibility rules.
2. Produce rename ledger.
3. Update docs/comments only.
4. Rename internal helpers/repos/factory services.
5. Rename core contract family.
6. Decide on and handle package/type-name salt policy.
7. Rename tests and fixtures.
8. Optionally rename public interfaces/selectors in a separate follow-up migration.
9. Run full `yarn test` at the stable checkpoint.

## Acceptance Criteria
- The canonical new family name is `DualSelfCommonDETF`.
- The codebase has a documented mapping from old names to new names.
- Internal rename slices preserve behavior and compile cleanly.
- Deterministic deployment policy for renamed types is explicitly handled.
- Public API rename is either:
  - intentionally deferred and documented, or
  - intentionally executed with compatibility analysis and validation.
- Focused Protocol/Base/Ethereum tests remain green during the migration.
- A broad `yarn test` pass is green at the checkpointed end of the migration.

## Deliverable From This PRD
- A staged implementation plan for a safe Protocol DETF rename.
- A gating decision on whether the rename is internal-only or public-facing.

## Recommended Next Step
- Before any code rename, choose whether external API names stay legacy-compatible.
- With the canonical name now locked, the first implementation slice should be the rename ledger plus doc/comment updates, not production contract rewrites.