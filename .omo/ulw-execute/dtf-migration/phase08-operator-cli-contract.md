# Operator CLI contract fixed before script implementation

This fixes the application CLI and rehearsal before dispatching the script
lane. It does not launch that lane or authorize a public operation. Its
worktree/base must be the independently verified recovery commit, once one
exists. R1 runtime verification is accepted; the scoped source commit still
requires independent provenance verification before it becomes this baseline.

Read original plan task9, MIG-P03/P07/P11/P13/P14, preparation provenance
recipe and the repository script-orchestration rules. Tooling belongs under
`scripts/recovery/dtf-migration/`; Solidity transaction stages under
`scripts/foundry/recovery/dtf-migration/`. Reuse installed Bun/Foundry tooling.
No new dependency, compiler or RPC configuration is selected here.

## Exact application entrypoint and commands

Entrypoint: `bun scripts/recovery/dtf-migration/cli.ts`.

Distinct commands:
`prepare`, `validate`, `deploy`, `fund`, `capture`, `configure`,
`independent-issue`, `verify`, `activate`, `harvest`, `resume`, `rehearse`.

The invocation contract is:

```text
bun scripts/recovery/dtf-migration/cli.ts prepare --input <file> --output <directory>
bun scripts/recovery/dtf-migration/cli.ts validate --manifest <file>
bun scripts/recovery/dtf-migration/cli.ts <stage> --manifest <file> --checkpoint <directory>
bun scripts/recovery/dtf-migration/cli.ts resume --manifest <file> --checkpoint <directory>
```

`<stage>` is one of the eight distinct onchain stage names above, never
arbitrary target/calldata. File arguments are real caller-supplied paths.
Every onchain stage and resume defaults to read-only validation/simulation.
No resume silently inherits an old broadcast mode.

Explicit execution modes are separate: `--execute-local` requires a loopback
RPC plus the exact observed Anvil instance ID and matching manifest chain;
`--broadcast` requires fresh explicit chain/proxy/snapshot confirmations and
must never be executed in this agent task. Do not load unrelated signer keys
or print resolved private RPC endpoints. A simulation result is not a receipt.

## Deterministic preparation and proof domains

Acquire/use explicitly pinned evidence, normalize all native integers as
decimal strings, fingerprint raw sources and normalized records, reconcile
origins/descendants/recoveries, and produce distinct independent and NFT
migration configuration payloads. Quote ETH and original DTF independently
against the immutable actual snapshot; never upload an arbitrary C0 credit.
Missing/unknown original inputs are errors, not zero. Replacement records
carry complete replacement values, never script-generated deltas.

Retain every required category in validation/disposition reports. Current
unsupported fungible/history/TokenStaking routes must fail with their actual
unclosed evidence gate; do not emit a forged actionable config or a no-op
success. A bounded operator implementation may serve verified independent,
NFT and admitted recovery paths while original all-category task9 remains open.
Synthetic rehearsal data must be explicitly identified and barred from
nonlocal broadcast. Operational evidence is not an owner-approved allocation.

## Durable execution/resume

Checkpoints bind chain, node/fork identity for local runs, actual proxy,
registry/package/facet identities, snapshot, source/evidence fingerprints,
complete payload hashes, signer/nonce/transaction intent, canonical receipts,
actual emitted bond IDs and consumption/configuration state.

Persist transaction intent before sending. Capture enough identity to
reconcile a mined transaction even if the process dies before writing its
completion checkpoint or receiving the send response. Reconcile actual
canonical receipts plus exact onchain state before any resend; ambiguity
fails closed. A changed manifest/domain is not an instruction to reuse an
old checkpoint. Rebatch/reorder only unsettled work without replaying
donations, consumed identities or issuance. No blanket retry on revert.

Weighted recovery selection must not equate a stored native inventory of zero
with no redeemable recovery value. The R1 correction reconciles tracked gons
at the source operation's synchronized divisor; the stored query is not a
live preview. Use the verified typed gon/index information and bounded
simulation to select a conversion, then record actual output/revaluation
events separately from NFT claims. Never expand a budget from the proxy's
total balance or spend unrelated gons. The rehearsal must include accrued
recovery value after the original claim quantity was already converted.

## Exact local rehearsal CLI

From the task-owned operator worktree, run:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18560 \
  --checkpoint .omo-runtime/dtf-migration-operator/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/operator
```

This command owns a loopback Anvil fork, chain4663, and resolves the existing
archive alias internally without exposing its key. Verify historical block
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
and distinguish L2 numbering from EVM BLOCKNUMBER. Record exact spawned
Anvil and Solar stage commands in the evidence. Use known local-only Anvil
accounts/unlocked transactions; never use a production signer.

The rehearsal must execute the actual CLI stages against a genuine
manager-registry Migration deployment. Include local funding/genesis,
capture, full configuration replacement, selected independent issuance,
actual NFT surrender through its real caller path, verification, activation
and all admitted recovery stages. Leave a configured entitlement unclaimed
and prove no supply/bond was created for it.

Fault-inject process interruption after an actual receipt is mined and before
the completion checkpoint is written, then invoke actual resume in a fresh
process. Prove the same transaction/nonce/bond and funding totals are recovered
without a second donation/issuance. Repeat for a donation and issuance.
Test wrong chain/proxy/package/snapshot/payload and reordered remaining batches.

The fault mechanism must be local-rehearsal-only and preserve real RPC,
transaction execution, filesystem journal and resume logic. Never mock the
very receipt/state reconciliation being tested. Subscribe to precise
node-ready/receipt/event/process signals with bounded timeouts before acting;
no sleeps, timed polling or timing-luck tests.

Write command help, schemas, deterministic fixture outputs, commands/receipts
and all limits to `migration/operator-runbook.md` with supporting operator/
evidence. Stop owned processes/listeners and clean temporary runtime roots;
retain useful evidence and warm caches. Independent verification must execute
the interruption/resume scenario itself. No original operator/full-release
acceptance is implied while required unsupported categories remain.
