# Phase28 stopped finite receipt-evidence implementation

Date: 2026-11-13. **Complete for the bounded collector and actual named-record archive.**
All 77 named references were collected and independently reconciled against
their raw rows and actual RPC responses. All 77 canonical associations pass.
Twenty conservative economic-routing/caller flags remain explicit; none was
removed to manufacture a clean allocation dataset.

This is producer evidence acquisition for plan Task1/Task9, not operational
approval, whole Task9, whole Migration completion, eligibility or source
admission. A separate verifier must start from this stopped handoff and owns
`verification/`; this producer has neither written there nor claimed that
separate verification has happened.

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence`.
Branch: `work/dtf-migration-phase-28-receipt-evidence`.
HEAD remains `789fced820ed494d9651c598fb8f75c646d727a7`. No commit was created.

## Delivered source and boundaries

The existing operator now accepts:

```sh
bun scripts/recovery/dtf-migration/cli.ts collect-receipts \
  --input "$COMPLETE_HISTORICAL_TREE" --output "$FRESH_OUTPUT_DIRECTORY" \
  --rpc-alias robinhood_mainnet_alchemy
```

Eight new operator files separate raw-input references, RPC entity capture,
association parsing, economic observation reconciliation, collection,
wire fixtures and two behavioral test modules. The existing CLI has only an
import, help line and narrow command case added. The existing runbook has an
additive receipt-evidence section. No existing financial, quote, hash, journal,
prepare, execution or candidate implementation changed. There are no Solidity,
dependency, configuration, installation, source-governance or old-data edits.

The CLI authenticates every historical raw binding before resolving the existing
alias and its one `ALCHEMY_KEY` variable. It accepts no URL, endpoint override,
signer or execution flags. The actual command used the already established
login-shell credential bootstrap. No wallet keys or environment dump were read
by the collector. The actual credential was never in argv or output.

Direct HTTP transport has no provider discovery/middleware, redirect following,
automatic retries or alternative provider. Requests are sequential and finite.
Each named transaction/receipt is requested once; exact block requests are
deduplicated by hash and number. Failed requests remain explicit while unaffected
named requests continue. Wrong chain/anchor prevents all named requests and
accounts for the complete reference set as unavailable.

The only methods are `eth_chainId`, `eth_getTransactionByHash`,
`eth_getTransactionReceipt`, `eth_getBlockByHash`, and `eth_getBlockByNumber`.
The actual collector performed no range queries, getLogs, debug traces, eth_call,
signing, sends or nonce changes. No held09 access, chain service, local fork or
full-rehearsal replay occurred. The required existing operator suite includes
its unchanged offline journal test signing a synthetic intent with the public
Anvil development key; that is not a live signer or a chain transaction.

## Authorities, full input binding and exact population

The complete phase28 brief, current main plan r5 and PRD r22, provenance/F1
reports, actual phase27 implementation-r2, independent verification-r2 and
immutable delivery reports were read. Actual operator RPC, CLI, candidate
input and reconciliation boundaries and relevant source event interfaces were
inspected before implementation. Current original-wallet and Stage2-only rules
govern; historical bearer/policy prose is not authority.

Actual input:

```text
/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery
```

All **36 declarations across 27 unique declared paths** authenticate. The
additional manifest body is also fingerprinted: 28 physical input bodies.
`sources.json` is authenticated through the manifest before its declarations
are used, and every declared body, including Markdown and the pre-exploit
sibling paths, authenticates before CSV derivation.

These are hash-authenticated recovered historical bodies, **not located
original captures**. No binding was edited or excluded. The annotated primary
tree remains a valid negative, and no economic quantity or P1 artifact was
reconstructed. The independent raw-row oracle reauthenticated all declarations
after collection.

The complete raw inputs, not a copied request list or hardcoded count oracle,
derive:

| Origin | References | Distinct transactions |
| --- | ---: | ---: |
| S008 weighted purchases | 43 | 43 |
| S009 earlier CP purchases | 16 | 16 |
| `conversions.csv`, `legacy_weight_to_sy` | 18 | 18 |
| Union | 77 | 77 |

Every original row and exact locator is retained in `actual/references.json`.
The collector's general duplicate handling shares requests while retaining
distinct original references; the actual set has no shared hash.

## Actual one-shot acquisition

`collect.command.json` records the exact executable/argv/CWD, start/stop,
source identities, stdout/stderr and actual exit **0**. This was the sole actual
complete collection. No failed live collection, retry or replacement run exists.
Exit 0 means completed canonical collection, not economic approval.

Chain **4663** and canonical anchor **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
were authenticated before named requests.

| Actual method | Requests |
| --- | ---: |
| `eth_chainId` | 1 |
| `eth_getBlockByNumber` | 78, including anchor |
| `eth_getTransactionByHash` | 77 |
| `eth_getTransactionReceipt` | 77 |
| `eth_getBlockByHash` | 77 |
| Total | 310 |

All **310** responses succeeded and have complete safe raw entity-byte captures,
lengths and SHA-256. No actual RPC, HTTP, transport, null, missing-result,
response-ID or parse failure occurred. No actual response required redaction.
Credential-bearing failures are exercised by the local wire tests: sanitized
bytes are explicitly non-raw and cannot become successful observations.

The 77 named transactions span blocks **45652334 through 87421203**, all at or
before the anchor. All **2368 receipt logs** are retained and checked.
Transaction/receipt hashes, endpoint addresses, block numbers/hashes,
transactionIndex, exact block membership, block-by-number canonical agreement,
receipt status and every log's transaction/block/index/order association pass.
The independent oracle separately checks raw responses rather than accepting
the producer's association result.

`actual/http-manifest.json` binds every request's method/parameters/ID and exact
request entity, each response entity and its raw/non-raw status, HTTP status and
selected safe headers. `actual/archive.json` retains full normalized observations,
partial-failure fields, request links and all per-transaction results. HTTP
framing is not claimed; neither is raw signed-transaction capture.

## Complete record reconciliation and all twenty flags

`independent.ts` imports no producer collector, CSV decoder, association or
reconciliation code. It uses an independent complete-token CSV decoder, raw
response parsing, exact integers and event/transfer comparisons. Its command
exited **0** after independently accounting for all 77 references, 36 declarations
and 310 HTTP captures. It found no unavailable transaction, association mismatch
or saved Transfer mismatch. This is a separate producer-side oracle, not a
substitute for the later verifier role.

All **43 weighted** and **16 earlier** mint IDs/recipients and generation-specific
purchase event/basis observations match. LP-accounting shares are never renamed
fixed principal or physical LP. All saved selected transfer locators, amounts,
recipients, blocks and indices match actual receipts. All **18** known raw-claim
source events and exact SY outputs match their saved observations. Full caller,
callee, value and calldata and actual source/SY logs remain archived.

### Fifteen earlier comparison-scope differences

The collector's `observedRouted` is deliberately a conservative **non-payer
inbound sum**, with every individual sender/log retained. It is not an assertion
that all such inflows are an original purchase conversion.

For all 16 CP records, saved direct DTF/WETH match actual direct transfers.
For all 16, the saved routed DTF amount equals the actual inbound from earlier
SE `0xb7d4bb379d361ad442cddee53ea71a33957826a7` alone. Fifteen transactions also
contain separate inbound transfers from LP address
`0x923877336b14662cfb5b3a60b14e7d716d54a888`. They make the broader non-payer
sum differ, producing retained `routed-dtf` flags. This establishes a comparison
scope difference, **not a demonstrated error in the saved routed field**.
No additional inflow is promoted into a user contribution.

| CP NFT | Saved SE-routed DTF | Additional observed LP-address DTF |
| --- | ---: | ---: |
| 4 | 0 | 3703818 |
| 5 | 0 | 5679593238886465 |
| 6 | 0 | 62816193844203301 |
| 7 | 0 | 327306939002799687 |
| 8 | 0 | 10210351169511441 |
| 9 | 41454674363068691516 | 41220182501921 |
| 10 | 0 | 2848 |
| 11 | 0 | 3 |
| 12 | 0 | 2 |
| 13 | 0 | 5212466 |
| 14 | 0 | 1390591 |
| 15 | 0 | 1444477 |
| 16 | 0 | 1 |
| 17 | 0 | 1 |
| 18 | 0 | 16837633828346 |

CP NFT3 has no such difference. Its direct WETH remains
`2000000000000000000`, direct DTF `0`, and separate SE-routed DTF
`1778859964387451305574664`. Routed DTF is not added to the contribution.
For all fifteen flagged records the collector withholds direct attribution,
while preserving the observed direct values and full comparison for review.

### Four indirect weighted purchases and one indirect raw claim

Weighted NFT IDs **19, 20, 23 and 42** have matching mint, purchase-event and
payment observations but different outer transaction callers and callee
`0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789`, selector `0x1fad948c`,
1348 calldata bytes and zero outer value. They retain
`indirect-purchase-or-different-caller`; matching payment/recipient does not
silently certify the outer sender or original economic eligibility.

Raw claim **`conversions.csv#row=21`**, transaction
`0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb`,
has outer caller `0x5512144047c2d55297c8470b93e8da87864617cd`, the same
callee/selector, 1188 calldata bytes and zero outer value. Its actual source
event records user `0x2c0400cf47e5ea01364e44c237aed22d7ae86199`, consumed weight
`20000000000000000000000` and SY output `36107853`, matching the known record
and exact output Transfer. It retains `indirect-or-unexpected-claim-call`;
`decodedDirectWeight` is null. The arbitrary outer calldata is not decoded as
a direct `withdrawClaim`. The other seventeen known claims have direct exact
call/event/output correspondence.

`actual/reconciliation.json` preserves all **20** flags unchanged.
`reference-review.json` contains **every one of the 77 records**, all actual
caller/value/calldata observations, saved fields, per-sender routing decomposition,
exact source/SY observations and each disposition. No source CSV or old candidate
was changed. Fifty-seven references have no conservative flag; that is not
fifty-seven eligibility approvals.

## Checks, failures and unchanged behavior

After the final operator source freeze:

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck \
  --types node scripts/recovery/dtf-migration/*.ts \
  "$EVIDENCE/record.ts" "$EVIDENCE/independent.ts"
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
```

Strict types exited **0**. The **one final complete operator invocation** exited
**0**, with **159 pass, 0 fail, 15 files**, Bun **1.4.2**. This includes the
previous 128 tests and **31 new behavioral tests**. The final suite's exact
operator source identities match the actual collection's source identities
and current raw files; `source-manifest.json` binds all 69 operator TypeScript
bodies, the runbook, both strict-checked evidence scripts and read authorities.

New tests cover wrong chain/anchor, null/missing/error/ID/version/schema failures,
malformed quantities, preserved unaffected success, transaction/receipt/block/log
contradictions, canonical membership, ordering, sharing, source purchase event
versus mint, payer/routed distinction, indirect claim decoding, attribution
withholding on association failure, exclusive outputs, redaction and operational
schema rejection. The archive version/status is rejected by unchanged prepare,
prepared-envelope validation and execution schemas. No financial/hash/journal
semantics were changed.

Preserved attempts, in order:

1. An initial tool-monitored strict check exited 2 on TS2345, flatMap's differing
   ERC20/ERC721 inferred branches. An explicit `Transfer` result type fixed it.
   The original tool event remains in the session; `attempts.json` labels its
   retained diagnostic summary as a summary, not original compiler bytes.
2. `focused01` passed 30 tests. `types01` exited 2 on TS7022 in a test fixture's
   inferred spread; the explicit existing `Associated` type fixed it.
3. `mutation01` deliberately disabled response-ID equality, receipt block-hash
   equality, source-purchase-event checking and shared-reference protection.
   Exactly the corresponding four tests failed (26 pass/4 fail). All guards
   were restored before final gates and collection.
4. Source review added a regression requiring association failure to withhold
   otherwise matching direct attribution. This explains the final 31 new tests.
5. `types-final`, `operator-tests-final`, `collect` and `independent` all exited 0.
   Their command metadata and complete stdout/stderr remain separate and intact.
6. A tool-rendered one-line reconciliation exceeded the read renderer's display
   limit and could not be JSON-parsed. No evidence was changed; subsequent
   complete raw-byte parsing and the independent oracle succeeded. The failed
   display parse is not called an RPC failure or a raw-data defect.

Native TypeScript LSP diagnostics repeatedly timed out. JSON Biome diagnostics
were unavailable because Biome is not installed. These are not clean LSP
results, and no installation/configuration workaround was attempted. The real
strict compiler and final tests pass. Read-only `git diff --check` exits 0,
the staged diff is empty, and the tracked diff is only the additive CLI/runbook
change; the eight new modules remain uncommitted.

Every new module owns one named responsibility and is below 200 nonblank,
noncomment lines. Typed parsed boundaries use no `any`, type assertions,
non-null assertions, suppressions or test-only production switch. All local wire
servers and test temporary trees close in awaited cleanup; there are no sleeps
or polling tests. No Forge, Solidity, paid workflow or full-rehearsal test was
run because this increment changes none of those surfaces.

## Identities, cleanup and stopped seal

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `actual/archive.json` | 3848804 | `e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b` |
| `actual/reconciliation.json` | 251139 | `c1717f1e35984ff03aeddd16c6a7571439e8066f4160fdeec2f7f844ced1577e` |
| `actual/http-manifest.json` | 154633 | `6feab989ce86fe70e1b70ad37acb42a775131c5e46a848b575689436f88d0731` |
| `independent-proof.json` | 143499 | `c1fd3a0195f4fcd6781245e1c9b78721efe953519657b1a9f8f7f8cc10ca024f` |
| `reference-review.json` | 225230 | `b82a2a0d5cd44addfc14baee05d19d5dd4386841d4e41d6b6117c07bcf2fce51` |
| `source-manifest.json` | 16341 | `2c91a827e237db5c664c053730d40763fff8228de5b121b7df87ed8509c59861` |

A credential scan using only the existing RPC key checked the then-present
727 evidence files and found **0 matches**. It emitted only file/match counts,
never the credential. Later report/manifest/seal additions contain only public
identities, scope descriptions and already-safe observations.

All thirteen owned terminal/monitor runs have delivered their actual completion
events. All recorder children exited before their command metadata was written.
There is no pending collector, oracle, test, server, signer, Anvil, Forge,
subagent or cleanup operation. Test temporary directories were removed by their
awaited finally blocks. No operational checkpoint or temporary chain was created.
All actual outputs, failed commands and deliberate negative evidence are retained.
Shared services, dependencies, warm artifacts, original inputs and old evidence
are untouched.

`cleanup.json` records that stopped state. `manifest.json` binds every retained
evidence file except itself and `seal.json`. The final `seal.json` binds this
report, source manifest and complete evidence manifest and is published **last**.
No producer write follows that seal.

The remaining qualifications are real: gross observed transfers/mints/events
do not prove net contributions, native refunds, eligibility or current control;
these named receipts do not establish full W0/Q0, all prior claims, zero previous
compensation, exhaustive recovery/holder/source coverage, historical storage,
execution-prefix traces, raw signed transactions, trustless proof or authenticated
build pedigree. No C0, credit, configuration or source allowance was generated.
The old 1240 unresolved candidate records were not automatically closed.

E-S, broader T mechanisms/current-control, disabled external conversions,
approved operational originals, actual funding/composition, target deployment
**45116678 > 32000000 gas**, and P1 historical preservation remain separate.
No permission to resolve them or perform operational actions follows from this
archive. The bounded producer deliverable is stopped and complete.
