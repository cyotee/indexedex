# Bounded operator execution delivery

Date: 2026-11-11.

**DoneClaim: all admitted CLI stages and durable transaction recovery are
implemented and exercised on the owned historical Anvil fork.** The final
exact `rehearse` command exited 0. This is not independent acceptance,
all-category task 9 completion, approved allocations, or public execution
authority.

## Accepted base and scope

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator`.
Branch: `work/dtf-migration-phase-08-operator`.
HEAD remains `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.

Read both complete phase08 contracts, original plan task 9 and its applicable
MIG-P requirements, the preparation report/interface, original provenance
recipe, repository rules and applicable skills. The root notepad's completed
worktree/seed gate and the complete independent phase07 commit-verification
report establish the admitted base. Direct branch, HEAD, artifact/dependency
inspection and the initial 41 passing preparation tests independently checked
the execution prerequisite.

Changes are confined to the brief-owned script, runbook and operator evidence
paths. Production contracts, TestBases, dependencies and configuration were
not edited. No source commit, public broadcast, push or merge occurred.
The only modification to a previously tracked file is changing
`MigrationCoreLocalQA._localInfrastructure` from private to internal so the
new local environment script can reuse the existing deployment implementation.

## Delivered implementation

The actual entrypoint remains `bun scripts/recovery/dtf-migration/cli.ts`.
It implements `prepare`, `validate`, `deploy`, `fund`, `capture`, `configure`,
`independent-issue`, `verify`, `activate`, `harvest`, `resume`, and `rehearse`.
The runbook contains commands and schema/operation contracts.

Under `scripts/recovery/dtf-migration/`:

| Files | Responsibility |
| --- | --- |
| `execution-schema.ts`, `execution-domain.ts` | Strict typed pre/post-capture manifests, full package/funding arguments, raw source/ABI bindings, actual registry/package/facet relationships and selector checks |
| `execution-plan.ts` | Finite ABI calls only; complete independent/NFT replacements, explicit issuance selection, bounded recovery tuples and separately identified donations |
| `execution-rpc.ts` | Fresh execution authority, exact Anvil instance/fork guards, canonical receipt reads and acknowledged bounded WebSocket subscriptions |
| `journal.ts`, `execution.ts` | Exclusive writer, durable signed intent before send, canonical transaction/receipt/state reconciliation, exact nonce/hash recovery and reordered unsettled rows |
| `execution-state.ts` | Actual emitted events, receipt-block configurations, consumption/recovery state, bond identity/principal/recipient/fresh cliff, and activation selector removal |
| `rehearse.ts`, `rehearsal-{process,chain,data,recovery}.ts` | Real process/CLI orchestration, deterministic synthetic inputs, genuine legacy-holder actions, recovery witnesses and cleanup |
| `execution.test.ts` | Neighboring filesystem/journal, schema and CLI authority tests |
| `cli.ts` | Integrated application dispatcher and help; preparation still uses its existing executable interface |

Under `scripts/foundry/recovery/dtf-migration/`:

- `Phase_08_Stage_00_OperatorEnvironment.s.sol` prepares real factories,
  manager registry, production packages, external liquidity and the
  owner-bound hook. It simulates the parent only to derive its identity;
  the separate `deploy` CLI mines the real registered parent deployment.
- `Phase_08_Stage_01_MigrationExecution.s.sol` exposes genuine typed
  deployment, funding/bootstrap, capture, configuration, issuance, activation
  and recovery simulations. There is no arbitrary target/calldata executor.

Defaults are read-only validation, explicitly labelled as such, not fabricated
receipts or a claim of stateful batch simulation. Resume never inherits an
execution mode. Local execution requires loopback, the explicit observed
instance ID, chain and historical fork identity. Public execution requires
fresh explicit confirmations and a specifically named signer environment
variable; it was not exercised. Pre-capture manifests use null snapshot
identity and the public confirmation literal `uncaptured`, never a fabricated
snapshot or caller-supplied price.

The journal persists the complete signed transaction, its deterministic hash,
nonce, starting block, full operation and domain before submission. Publishing
an intent/receipt uses exclusive creation, file sync and directory sync.
Resume checks actual canonical receipt and transaction fields and exact
receipt-block state before considering the same signed bytes for resend.
Unknown nonce movement, pending transactions, reverts, missing previously
completed receipts and changed domains fail closed. Completed work is not
replayed when singleton configuration/issuance rows are reordered.

The mechanism chosen is persisted signed bytes, rather than a nonce-only
record or a generic executor. It retains transaction identity even when a send
response is lost. Configuration, issuance and recovery are separate records;
revaluation events are not counted as NFT claims or additional compensation.

## Real local proof

Final evidence directory: `rehearsal-1794374935675/`.
Monitor `mon_DPGHTCN7ZYNMS7FV`, session `bash_21`: **exit 0**.

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18560 \
  --checkpoint .omo-runtime/dtf-migration-operator/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/operator
```

The existing archive credential is available through the user's interactive
Zsh login environment; the evidence run used `/bin/zsh -lic` around that exact
command. No credential or resolved private endpoint is retained. Anvil and
Solar commands, argv, exits and logs are recorded in the evidence directory.
Chain 4663 retains EIP-170 enforcement; no code-size or simulation bypass was
used. Explicit legacy fees are a local rehearsal setting, not a live gas quote.

Historical RPC/L2 block `108944663` has hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The captured snapshot is a later, actually funded book:
`0x6de828545af1081b985c33e99d7d8676bf563a3e9de52e9bf4fa954c0dea60e5`.
Its receipt is at RPC block `108944894`; the emitted EVM block number is
`26367890`. These number spaces are not conflated.

| Identity | Actual address |
| --- | --- |
| Migration proxy | `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0` |
| Manager registry | `0xaa66038ae217b246f5bf7537104342672e56fed8` |
| Migration package | `0x642fa76f2f7a6b97ec0822d67a785379a92df347` |

The exact node instance is
`0x67fdd8908873222d63616abae2bfd84fa34be5c608c5bfe71c01247d0f6bee7a`.
Twenty proxy/registry/package/facet runtime bindings are retained.

There are **220 successful infrastructure receipts, 30 successful unique
operator-journal receipts, and 11 successful legacy funding/surrender fixture
receipts**. The 41 recorded subprocess commands comprise 34 exits of 0,
five intentional domain-rejection exits of 1, and two intentional SIGKILL
interruptions. `transactions.json` indexes the exact commands, hashes, nonces,
blocks and actual emitted events; original complete receipts remain alongside
their journal intents.

## Interruptions, replacements and issuance

| Operation | Actual hash / nonce | Observed result |
| --- | --- | --- |
| Registry parent deploy | `0xbc2ffc265391562244269342481d3d072e17e8fcec09e9f8d4938f69b10ee5ed` | Genuine registered parent |
| Interrupted donation | `0xa3d23d9646f0f34cc434c2f918af554dc1c505a6121bdcb011e67f45a0eed788`, nonce `2118` | Same mined transaction recovered; no second donation |
| Interrupted issuance | `0xe578da06bdf67bc9ab34f236ae9292f1befe74f1ca64024b0e899d0a44378a6b`, nonce `2127` | Same transaction and bond `3`, principal `461`, recovered |
| Remaining issuance | `0xf08523af3db5c1314e553c626a9e2a2e97c3305a791916bcdabad7be2163046a`, nonce `2128` | Bond `4`, principal `461` |
| Activation | `0x191097fca3ffdc2914c57e34d1a8e567dbe95ab65b19e75bb47769fa801c1c21`, nonce `2144` | Activated; all six allocation selectors removed |

Both fault processes die only after an actual canonical receipt is observed
and before the completion checkpoint. Actual fresh CLI processes first resume
without execution flags: signer nonces remain unchanged. Explicit local resume
then reconciles the same transaction/state. Issuance resumes with reversed
remaining order. These are real RPC, filesystem and process interruptions,
not mocked receipt/state tests.

Capital events prove exactly `1000000000000000000000` native units each of
WETH and original DTF. WETH combines an explicit 900-token transfer with a
100-native-ETH wrap; three actual received-capital events reconcile correctly.
Genesis supply is `1000000000000` native DETF. Configuration leaves it unchanged.
The two selected independent issuances raise it to `1000000000922`.
The third configured recipient remains unissued with bond ID 0.

A later full replacement doubles one original ETH input while preserving the
already issued record, bond 3 principal 461 and total supply exactly. No delta,
retroactive top-up or resized bond is generated. Wrong chain, proxy, package,
snapshot and prepared payload are rejected by actual resume commands.

Real holders approve and surrender weighted NFTs 4 and 26 and earlier NFT 3
through their actual caller paths. The actual resulting bonds are 5, 6 and 7,
with delivered native credits `13872781`, `22233172691` and `923391925`.
Complete hashes, ownership, source-specific remaining units and events are
retained in `fixture-receipts.json`.

## Admitted recovery evidence

Nine actual `harvest` transactions exercise all eight enum stages, including
two separate weighted unstakes. The selected legacy NFTs enter real Migration
custody first. Earlier claim and mature sale retain their real earlier-model
units; neither is represented as a successful liquidation.

- Original measured weighted claim inventory: `103956810` native units.
- After an actual eight-hour advance and conversion of that original amount,
  attributed gons remain
  `10409755823309028855319786677940495830840`.
- The source-synchronized divisor is
  `875381719530275893679866214021516565`.
- A separate subsequent operation converts **11891 accrued whole units**,
  yielding total actual weighted DETF output `103968701`.
- Genuine weighted conversion returns
  `557312616037878874629` native original DTF.
- Exactly `1000000000000000000` native DTF is donated to the fixed new reserve.

Selection uses attributed gons and typed source index data, followed by bounded
simulation of the genuine operation. It never authorizes spending the proxy's
whole balance or treats a stale stored native zero as no value. Actual
conversion/revaluation events and NFT recovery records are retained separately.

## Checks, failures preserved and bindings

The neighboring Bun suite passed **50 tests, zero failures**: the original
41 preparation cases and nine added execution cases. The last combined suite
and strict TypeScript gate was `mon_809SMFPNVFMESMG2`, `bash_15`, exit 0.
After subsequent reconciliation/rehearsal corrections, the final strict
TypeScript gate `mon_FBA3RX23C3CMNPCY`, `bash_20`, also exited 0; the real final
rehearsal exercises those corrections. No duplicate unchanged suite was run
merely to accept its result.

```sh
bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts

./node_modules/.bin/tsc --noEmit --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax \
  --module NodeNext --moduleResolution NodeNext --target ES2022 --types node \
  scripts/recovery/dtf-migration/*.ts
```

Both new Foundry scripts compile successfully with the installed
`/Users/cyotee/.foundry/bin/forge build --use solar`; monitor
`mon_1PM5MEVG2F6CCRNF`, `bash_5`, exit 0. The initial PATH Forge rejected Solar;
no compiler fallback or installation was used. The installed compatible Forge
and Anvil report `1.9.1-nightly`. The test-junk audit reports no findings,
exit 0 (`mon_7T99N3C114R632ZQ`). Final Git whitespace/scope/base inspection
exited 0 (`mon_AFF8BA04QNPGDV3W`).

Retained failed runs document:

1. An unconfigured Bash archive environment; the existing interactive Zsh
   environment resolved it without obtaining or exposing a new credential.
2. Anvil's default fee selection rejecting a fixture transaction; explicit
   local legacy fees corrected it.
3. Typed package decoding incorrectly treating empty ABI arrays as objects and
   rejecting valid default metadata/zero creator; the decoder now follows the
   actual ABI components and accepted package contract.
4. A mistaken Foundry receipt filename; the actual
   `prepareEnvironment-latest.json` is now retained.
5. An actual frozen-quote `E3` rejection of the undersized synthetic reserve.
   Only synthetic funding was increased; the actual evaluator was not changed.
6. Configuration's mined transaction followed by a JavaScript serialization
   failure: decoded NFT IDs were bigints in the state-query key. Decimal-string
   serialization fixed this script defect; actual reconciliation was retained.
7. Issuance to standard dev accounts 0-2 reverting in `onERC721Received`.
   Read-only code probes and the retained call trace establish historical
   EIP-7702 delegation and the receiver's attempted transfer callback. The
   rehearsal now uses verified code-empty accounts at public Anvil mnemonic
   indices 100-102. No account code was erased and no production guard changed.

`source-evidence-bindings.json` binds 25 source/runbook inputs, four artifact
envelopes, 20 actual runtime identities and all 250 final rehearsal evidence
files. All **226 compiler/source comparisons** match: 108 package inputs and
118 recovery-facet inputs. Artifact runtime objects are distinguished from
immutable-populated deployed runtime identities. Prior preparation reports
remain historical; they were not rewritten to claim their original CLI hash
is the final execution CLI hash.

New modules remain below 250 nonblank/noncomment lines. Boundaries own schemas,
planning, transport, journaling, state reconciliation or rehearsal orchestration
separately. No new dependency, untyped cast, type-error suppression, pricing
fallback or receipt/state mock was introduced. Native LSP requests repeatedly
timed out and sometimes returned stale diagnostics; no clean final LSP claim is
made. JSON LSP requires missing Biome. Strict compiler checks and JSON
serialization are used without changing prohibited dependencies/configuration.

## Cleanup, assumptions and remaining gates

The final node PID 62696 exited; its close signal was awaited. All temporary
checkpoint files were copied byte-for-byte into evidence before the owned
checkpoint root was removed. `cleanup.json` records this receipt. All
impersonated legacy holders were stopped in awaited `finally` blocks.
The now-empty task-created `.omo-runtime/dtf-migration-operator` parent was
then removed with `rmdir`; monitor `mon_RFGYBF4SSR54V88W`, `bash_23`, emitted
`OWNED_RUNTIME_PARENT_REMOVED` and exited 0. The shared `.omo-runtime` parent
was not removed.
Subprocesses, WebSocket subscriptions and providers are closed. No owned
background operation remains. Warm `out/` and `cache_forge/`, dependency links,
historical evidence and unrelated files remain intact.

The synthetic reserve deliberately uses local external liquidity and WETH,
real historical DTF and genuine production manager/package/proxy code.
Its independent originals are labelled synthetic. They are not approved
beneficiaries, public deployment parameters or evidence that all historical
exposure has been reconstructed.

No production defect requiring an out-of-scope edit was established.
Historical receiver delegation is an observed fixture constraint, not
authorization to change token-receiver or reentrancy behavior. Existing source
limits remain explicit: weighted/earlier liquid positions and receipts,
weighted SY, TokenStaking, claim-vault rights, underlying SE shares and
fungible LP retain E1/E2 gates; earlier liquidation retains SB-E1/E2/E3/E4.
No unsupported category receives executable credit or no-op success.

Independent verification must still execute the interruption/resume scenarios
itself. Full task 9, approved operational inputs, all-category migration and
release remain open. This bounded delivery authorizes none of them.
