# Issuance decoder repair

The owned issuance repair is complete. Focused state tests and manual proof
pass. Combined full-suite and strict-type gates are explicitly deferred to the
existing integration QA executor after the domain sibling finishes. No shared
suite or strict tsc command was started in this repair.

Only `scripts/recovery/dtf-migration/execution-state.ts` and its state test were
edited as product files. New evidence is confined to this issuance directory.
Prior reports and claims remain untouched. The setter case, producer source
binding, sibling-owned execution files, historical receipt, diagnostic, journal,
and signed intent remain unchanged.

## Diagnosis from actual evidence

The blocker names successful transaction
`0xa41931626451a9242220fcb3c253b9275e8d697beb1a7fd860afcc6fd2ebdc68`,
status `0x1`, at block hash
`0xcd7a32d10749d878890d870619fa139a79d8ab5f063b51e50eea40604c1e37a0`.

Its bond child `0xebb22b8619265b4a587a72eaa2b438b0f0c0bc50` emits:

- At log index `0xa`, ERC721 `Transfer`: four topics, indexed token ID 3,
  empty data, recipient `0x0e9971c0005d91336c1441b8f03c1c4fe5fb4584`.
- At log index `0xc`, `MigrationPositionCreated`: token ID 3, that same
  recipient, principal 736, start 1794111266, unlock 1801887266.

The real transaction also contains staking-token ERC20 transfers, `Staked`,
the bond child's `BondPurchased`, and the parent's allocation issuance event.
The generated child interface confirms the separate required event declaration:
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol:17-19`.

Before repair, the independent issuance branch filtered bond logs by emitter,
then attempted to parse every one with a funding Interface that included ERC20
`Transfer`. ERC20 and ERC721 Transfer have the same signature topic; the indexed
token ID does not supply the ERC20 decoder's expected data word. The actual
saved diagnostic and the new production regression both show:

```text
data out-of-bounds (buffer=0x, length=0, offset=32, code=BUFFER_OVERRUN, version=6.17.0)
```

## Narrow fix and same-cause audit

The existing funding Interface and ethers event machinery now select each
required event by both its exact child emitter and its event fragment topic
before decoding. The unused ERC20 Transfer fragment was removed. No replacement
Transfer decoder, broad catch, or malformed-event fallback was introduced.

The same broad-decoder pattern existed in the adjacent staking-child scan.
Both child scans now use the same local selector with their respective required
event: bond `MigrationPositionCreated` and staking `Staked`.

Decoded required events must re-encode to the exact original topics and data.
The ordered required-event arrays must match the signed requests in count,
position ID, recipient, principal, start/cliff, payer, funded amount and gons.
Staking must precede creation, and creation must precede the corresponding
parent issuance event. Unrelated ERC721, ERC20 and BondPurchased logs coexist
without being fed to a decoder for another proof.

All other `parseLog` sites in the owned source were inspected. The proxy event
loop is restricted to the proxy's bound interfaces, not bond-child logs; the
configuration census decoder receives its requested configuration event topics.
No other instance of this child-emitter/Transfer-decoder misuse was found.
The separately assigned empty-census defect remains with the domain owner.

## Runs and results

Every command ran once for its recorded inputs through a monitored asynchronous
run, with cwd:

```text
/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1
```

`evidence.json` records exact argv and shell command, timestamps, observed exits,
raw stdout/stderr paths and hashes, source hashes at each run, final source
fingerprints, new fixture source bindings, diagnostics, and preservation checks.

| Run | Result |
| --- | --- |
| `state-before` | Exit 1; new production issuance regression fails with the actual BUFFER_OVERRUN, existing 8 state tests pass. |
| `manual-before` | Exit 0; explicitly asserts and records the expected pre-fix production parser failure. This is not a successful issuance claim. |
| `state-after` | Exit 0; 10 state tests pass, including the new positive and corruption matrix. |
| `manual-after` | Exit 0; saved real facts authenticate; new synthetic production completion passes; 25 event corruptions reject. |
| `dirty-worktree` | Exit 0; raw status retained, 193 rows in the shared dirty tree. |
| `test-audit` | Exit 0; no junk-test findings in the owned state test. |

Focused argv:

```text
bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-state.test.ts
```

Manual argv:

```text
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/issuance/manual-issuance.ts --before
bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/issuance/manual-issuance.ts
```

No passing check was repeated without changed inputs. The user reassigned the
domain files during this task and directed state-only QA and deferred combined
gates; no domain/state combined suite was run after that correction.

## Manual proof boundary

The manual channel replays the original header, receipt, and ordered logs through
production `canonicalReceipt` with an evidence-only transport. It decodes the
actual ERC721 and migration events with the real generated bond ABI, confirms
their matching ID and recipient, and reproduces the ERC20 collision with the
generated ERC20 ABI. These are saved real local-chain facts, not a new transaction.

The saved canonical file and transaction trace do not provide the complete
post-issuance getter responses required by `captureCompletion`, including
`independentIssuance`, `ownerOf`, `positionOf`, and `isMigrationPosition`.
A complete historical completion was therefore not fabricated or claimed.

The production completion positive uses a new signed wire fixture built on
existing `executionFixture` infrastructure. It binds the actual generated child
artifacts in its new manifest, preserves ERC721 empty-data/indexed-ID shape and
the actual event sequence, and supplies explicitly synthetic addresses,
quantities, and getter responses. It calls production canonical receipt and
completion verification. It never rebinds the original signed domain.
The later real Anvil lifecycle remains the parent's acceptance gate.

## Sensitive probes

The 25 independently corrupted receipt copies cover missing/malformed/truncated,
duplicate, wrong-emitter, wrong-signature, wrong-ID, wrong-recipient,
wrong-principal, wrong-start, wrong-cliff, extra-topic, extra-data, and order
failures for the required bond event, plus corresponding staking proof failures
for payer, recipient, amount, gons, emitter, count and encoding.

The state test separately rejects altered canonical transaction identity.
Manual and state tests reject a status-0 transaction despite complete valid-looking
events, and reject a stale principal getter despite a valid event receipt.
Missing or malformed required events are never hidden by skipping a parse error.

The pre-fix production regression is the mutation witness for the actual decoder
defect: the owner code rejected a valid issuance shape and passes after the fix.
Existing tests had no bond-child ERC721 Transfer in their issuance receipt,
which is why the failure escaped them. No test-only production export was added.

The original receipt, diagnostic, journal domain, and intent have identical
before/after hashes in `evidence.json`. Receipt SHA-256:
`1e05a886203d090dfa235589da6a98c5c130b5e00afc7be5d9c636b80eabebd9`.
The dirty worktree was preserved; no unrelated edits were reverted.

Artifact mutation is inapplicable to the cause being changed: this repair adds
no artifact loader or authority rule, and all existing source binding validation
remains active. New fixture source descriptors and hashes are captured.
Stale receipt/state evidence is exercised directly through the principal and
canonical identity negatives rather than a source-text check.

UI/accessibility/responsive/browser probes are inapplicable because no rendered
surface changes. Public-network, wallet authorization, deployment, restart,
rollback and load tests are inapplicable to this offline decoder repair; no node
or transaction was started. Lifecycle concurrency and fresh-chain behavior belong
to the explicitly deferred combined integration/rehearsal gates.

## Review, diagnostics, and cleanup

The state file continues to own completion interpretation; the new local event
selector has two inputs and two callers. It reuses the existing ABI decoder.
Input receipts and fixture manifests pass through existing schemas, with Zod at
the saved-evidence boundary. No `any`, type assertion, suppression, defensive
fallback, retry, logging framework, new tagged variant, or production authority
was added. Fixture helpers are shared by tests and manual QA; assertions cover
observable acceptance/rejection rather than source wording. There is no
destructive post-write verification or unrelated refactor.

Measured nonblank/non-comment lines: state 428, state tests 322, evidence fixture
158, manual script 62. State and its test already exceeded the generic size limit;
the explicit two-file repair scope takes precedence over a broad split.

Native file diagnostics report no errors for the production state file and
manual script. Fresh diagnostics timed out for the state test and evidence
fixture; they are not claimed type-clean. JSON LSP support is unavailable because
Biome is not installed; no installation was attempted.

The full operator suite and BOTH exact strict tsc argv lists from integration
`02-operator-types` and `03-helper-types` are retained as deferred commands in
`evidence.json`. No shared gate validates the combined later domain/state tree
until the existing integration QA executor runs after both writers finish.

All monitors exited. Fixture servers and providers closed, temporary fixture
directories were removed, and raw evidence remains retained. No Anvil, public
RPC, transactions, Forge, installs, commits, delegation or parent readiness write
occurred. The new issuance claim is written after this report as the final file
write.
