# Original-wallet admission for existing NFT surrender

## Authorized new behavior and separation

Implement the owner's later requirements in current main plan
`MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision
`migration-detf-implementation-plan-r3-original-wallet-entitlement`,
section 1.3: the recorded original acquiring wallet must have a matching
configured entitlement and actually control/surrender the asset.
Missing configuration or the wrong wallet must revert before custody,
consumption, minting or bond funding.

This is a distinct new NFT/configuration requirement, not a retry, rephrasing
or completion of the refused phase09 deployment-gas assignment. Do not
inspect, import, modify, test or verify that held candidate. Do not change
model routing or treat this phase as provider-access restoration.

The source-only phase11 independent report confirms the finite H1/H2/H7
handoff: missing NFT configuration already rejects, but both shipped NFT
configurations lack an original-wallet field and surrender currently checks
only current ownership. Implement that precise gap, not a transfer-history
system or general fungible surrender in this increment.

## Worktree and exact inputs

Work only in:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-12-wallet-admission`
on `work/dtf-migration-phase-12-wallet-admission`, base
`3f577eeca049c1bd70a812d130941c8a38dd4781`.
Root must verify warm seed and exact clean branch/HEAD before dispatch.

Read the complete independent handoff and matrix in:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources/docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources/verification/`.
Use its H1/H2/H7 locators and the actual baseline code. Historical phase05,
phase07 and phase08 accepted source/runtime reports remain read-only inputs.
Current r3 overrides their former current-holder eligibility assumptions;
their source ABI, custody, units, recovery and funding evidence remains useful.
Read repository router/rules and applicable canonical/programming/Bun skills.

## Smallest coherent implementation

1. Add a nonzero recorded `originalWallet` to complete NFT configuration input,
   storage, query and configuration identity/event data where appropriate.
   Follow current interface-owned schemas. Do not infer/default it from the
   current owner or accept it as an unconfigured surrender argument.
2. Keep the collection/token/source canonical economic-origin collision key
   wallet-independent. Configuration replacement, including wallet correction,
   must never reopen a consumed NFT, reset delivered facts, create another
   quote for the same origin or bypass independent-compensation overlap.
3. Require matching configuration, caller equal to recorded original wallet,
   and actual live NFT ownership before the existing safe pull. Keep the
   expected receiver/post-custody and source-position checks intact.
4. Preserve weighted remaining-principal arithmetic and earlier original-share
   arithmetic, whole-identity consumption, exact funded fresh 90-day bonds,
   reward gates, activation/removal and owner-only recovery.
5. Carry the required field through operator schemas, provenance joins,
   canonical payload/hash, typed Foundry configuration and rehearsal inputs.
   Missing original-wallet data rejects preparation rather than using live
   owner as a substitute. Independent allocations and capital donation are
   separate and unchanged.
6. Replace only stale ancestry-only blocked-reason wording with the actual
   phase11 row-specific implementation/unit/caller/disabled-route gap.
   Do not unblock an unimplemented category or claim a disabled exit works.

Allowed production paths are the current Migration interface, repo,
allocation Target, surrender Target and legacy NFT helper under
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`, plus only
necessary neighboring Migration fixture/spec/fork adaptations.
Allowed operator paths are `scripts/recovery/dtf-migration/`,
`scripts/foundry/recovery/dtf-migration/` and the operator runbook.
No package redesign, ordinary/common/Crane production, configuration,
dependency or held phase09 code changes. If a broader change is necessary,
report its exact dependency before editing outside scope.

Evidence belongs only under this worktree's incident
`migration/wallet-admission/implementation/` or `verification/` according
to the node. Prior reports, logs and original inputs stay immutable.

## Observable acceptance and checks

Cover both real NFT generations before and after activation:

- Absent matching configuration rejects with no balances/custody/consumption/
  supply/bond change, even if the caller owns and approves the NFT.
- Zero original wallet rejects during configuration.
- Another current holder or approved operator cannot use the original
  wallet's entitlement. The configured wallet without current ownership
  rejects too.
- Returning the NFT to its configured original wallet permits surrender
  without intermediate-transfer proof; prior consumption is never reset.
- Positive surrender keeps exact credit/funding/fresh clock and both source
  position layouts. Failed callbacks or funding roll back the whole operation.
- Full configuration replacement and wallet correction preserve consumed
  canonical origins and existing independent-origin collision protection.
- Unconfigured users may still make permissionless capital donations without
  receiving personal credit; this is not a surrender fallback.
- Operator serialized values, final ABI and configuration hashes agree;
  missing/wrong original-wallet records reject with the intended error.

Use production-first TestBases and actual pinned legacy NFTs. Update only
tests made stale by this owner-directed eligibility change; keep unrelated
failures visible. Add focused regressions in the existing test locations,
including a genuine fail-before wrong-current-holder case. No source-grep,
prose-pinning, fake subject, storage injection or timing-luck tests.

Run artifact-first Solar for affected current Migration specs/forks and
final-source script tests/typechecks. Preserve source/artifact bindings;
reuse unchanged ordinary/common evidence unless dependency impact requires
a fresh run. No cache deletion, viaIR or changed test/profile roots.

## Fixed real local CLI rehearsal

From this phase worktree:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18562 \
  --checkpoint .omo-runtime/dtf-migration-wallet-admission/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission
```

This fixes the invocation before operator edits. Retain the application
entrypoint/command names and durable journal; extend its real assertions
for the new wallet field/guard while preserving both mined-before-checkpoint
donation/issuance resumes, meaningful remaining-row ordering and unclaimed
zero issuance. Synthetic originals stay labeled and barred from public use.
Use original wallet values from the fixture's explicit records, not a new
live-owner fallback in preparation or production.

The verified baseline has the known 42,985,843-gas parent-deployment issue.
This local rehearsal proves the new admission behavior, not target-gas
feasibility. Do not borrow a phase09 candidate, relax/remove a check, or claim
that the old permissive local deployment resolves that separate held issue.

Independent verification must execute original-wallet and missing-config
rejections and successful surrender itself, inspect source/operator parity,
and report exact retained limitations. No tests or transactions on public
networks, production signers, source commit, push or merge in these nodes.
Stop owned local nodes/listeners/impersonations and retain cleanup receipts.
