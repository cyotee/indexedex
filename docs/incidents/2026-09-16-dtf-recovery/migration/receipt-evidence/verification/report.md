# Phase28 independent stopped receipt-evidence verification

Date: 2026-11-13.

**Verdict: confirmed for the bounded finite collector and complete named-record
archive. No needs-fix source or actual-evidence defect was established in this
scope.** Independent strict types and the complete operator suite pass. One
independent actual collection has exited. Independent raw-input/RPC reconciliation
accounts for every one of the 77 references, all 310 responses, all 2,368 logs
and all 568 selected saved Transfer locators in each of the two archives.
The 20 conservative routing/caller flags remain, rather than being erased.

This is not historical eligibility, operational readiness, full Task9 or full-plan
acceptance. P1 remains historical missing-byte preservation, not a current
collector defect. No allocation, configuration, credit or source admission follows.

## 1. Subject, ownership and independent method

Subject worktree:

`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence`

HEAD remains `789fced820ed494d9651c598fb8f75c646d727a7`; branch remains
`work/dtf-migration-phase-28-receipt-evidence`. Source is uncommitted. This verdict
binds the actual raw source identities, not HEAD alone.

Read the complete phase28 brief, current plan r5, PRD r22, provenance/F1 reports
and phase27 actual implementation-r2, independent verification-r2 and immutable
delivery reports. Current original-wallet/control, owner-first-bond and Stage2-only
rules govern. Historical bearer/full-credit prose is not current authority.

Required the complete stopped producer report, manifest, source manifest, command
records, cleanup and seal before execution. Read all eight new operator bodies,
the complete tracked CLI/runbook diff, collector dependencies and unchanged
operational intake boundaries. Only this `verification/` directory was authored.
No source fix, old evidence/input edit, install/configuration change, Git write,
Forge/rehearsal replay, alternate provider, range/debug trace, held09 access,
live signing or public action occurred. No subagent was launched.

`raw.py` and `independent.py` are new verifier oracles, not copies or executions
of producer reconciliation. They import no producer CSV parser, collector,
association or reconciliation code. They use Python's standard CSV decoder and
arbitrary-precision integers, independently enumerate the complete authenticated
inputs, and reconstruct observations from the archived actual RPC entities.
Only afterward do they compare producer and verifier normalized results.
`topics.json` binds event signatures to the local interfaces actually read:
`IDetfBondNFT.sol:29-31`, `ITokenStaking.sol:66`, and
`ComposedStableCommonDetfBondNFTVaultTarget.sol:37-39`.
These layouts are an interpretation, not authenticated historical build pedigree.

## 2. Stopped handoff and preservation

Every one of the producer manifest's **731** entries authenticates. All **82**
source/support/authority rows and all **eight** direct seal bindings authenticate.
`intake.json` retains every expected/actual row, not just aggregate counts.

| Producer binding | Bytes | SHA-256 |
| --- | ---: | --- |
| `implementation/report.md` | 17946 | `931b2130f345835240f67fd438e4864e05fb71cc856f9c16db6a678f3ffab815` |
| `implementation/manifest.json` | 123425 | `0b5f1a0714354e66e4b0e773c11c2930ff8e440ef3dc77e1207633f782070e7f` |
| `implementation/source-manifest.json` | 16341 | `2c91a827e237db5c664c053730d40763fff8228de5b121b7df87ed8509c59861` |
| `implementation/cleanup.json` | 1870 | `de24379a0393ff688b5548ad440924641b55ade2ca2b30c2c4633f2478a922d2` |

The producer command records have actual stopped timestamps and exits, including
the sole live collection and final gates. Cleanup records thirteen completed
producer runs. A manifest hash does not itself prove process history; the recorded
command exits and cleanup supply the stopped-handoff evidence.

`preservation.json` reauthenticates all 731 entries, all 82 source/support/authority
rows and all 36 recovered-input declarations after independent execution, with
zero changes. The final read-only boundary retains the same complete tracked
CLI/runbook diff, eight untracked operator additions, unchanged HEAD/branch, empty
staged diff, and exit-zero whitespace check. Every one of the 69 operator bodies
also matches every independent command's source capture: 414 command/source
comparisons across six recorded phases, zero mismatches. No producer or old
candidate was modified.

## 3. Authenticated population, not a copied transaction list

Input root:

`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`

The independent oracle authenticates `sources.json` against `manifest.json`
before using its declarations, then authenticates all **36 declarations over
27 unique paths** before CSV parsing. The additional manifest body is separately
fingerprinted. All retained raw fields and logical CSV row locators match.

| Independently derived origin | References | Distinct transactions |
| --- | ---: | ---: |
| S008 weighted purchases | 43 | 43 |
| S009 earlier CP purchases | 16 | 16 |
| `conversions.csv`, kind `legacy_weight_to_sy` | 18 | 18 |
| Union | 77 | 77 |

Requests are derived from the complete tables before the expected population
assertions. Every original reference remains distinct. There is no shared hash
in this actual population; the general duplicate-reference behavior is tested.
Request deduplication never merges economic origins.

These are **hash-authenticated recovered historical bodies, not located original
captures**. No economic quantity or P1 artifact was reconstructed. Independent
byte comparison confirms the annotated primary tree still has exactly the two
historical Markdown mismatches, `LOSS_AND_RECOVERY_LEDGER.md` and
`CUSTODY_AND_HARVEST.md`. The other 34 declarations match. This verifier did
not alter that negative, rewrite hashes or run another live collector against it.

## 4. Actual independent execution

Each phase has exact argv, CWD, start/stop, actual exit and complete binary-safe
stdout/stderr in its `.command.json`, `.stdout` and `.stderr` siblings.

| Independent check | Actual result |
| --- | --- |
| Strict TypeScript over all operator `.ts` files and recorder | Exit 0, empty streams |
| One complete operator-test invocation | Exit 0; **159 pass, 0 fail, 15 files**, Bun 1.4.2 |
| Sole actual finite CLI collection | Exit 0; authenticated; 77/77 canonical associations |
| Python raw-input/RPC oracle over both actual archives | Exit 0; complete checks below |
| Complete final read-only Git boundary/diff check | Exit 0; staged diff empty |
| Separate strict check of later-added scan support | Exit 0; tool monitor `mon_A2X7DMT51EWBGKD5` |
| Actual selected RPC credential scan | Exit 0; 1,531 then-present files, **0 matches** |

Commands:

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck \
  --types node scripts/recovery/dtf-migration/*.ts "$VERIFICATION/record.ts"
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun scripts/recovery/dtf-migration/cli.ts collect-receipts \
  --input "$COMPLETE_RECOVERED_TREE" --output "$VERIFICATION/actual" \
  --rpc-alias robinhood_mainnet_alchemy
python3 -B "$VERIFICATION/independent.py" "$COMPLETE_RECOVERED_TREE" \
  "$VERIFICATION/actual" "$IMPLEMENTATION/actual" "$VERIFICATION"
```

The actual collector ran **05:22:10.413Z through 05:22:41.478Z on November 13,
2026**, using the existing login-shell bootstrap. It was monitored to completion;
there was no retry, replacement run or pending collector at handoff.

Only `ALCHEMY_KEY` was selected by the new collector. It checks the exact existing
`robinhood_mainnet_alchemy` template at `foundry.toml:91`, has no URL override,
and never places the credential in argv or output. Direct HTTP has no provider
discovery, redirects, retry middleware or fallback. The actual scan checks literal
and URL-encoded credential values without emitting either. Subsequent report,
cleanup and seal additions contain only public identities and safe observations.
No private wallet credential was selected. The unchanged complete operator suite
includes an offline synthetic-intent signature with the public Anvil development
key; this is not operational signing or a live transaction.

## 5. Every raw response and canonical association

The independent parser verifies each actual request's bytes, length, SHA-256,
ID/method/parameters and allowed method, then each response's bytes, length,
SHA-256, raw flag, HTTP status, JSON-RPC envelope and matching integer ID.
There are no orphan HTTP files or duplicate method/parameter requests.

| Actual read method, per archive | Requests |
| --- | ---: |
| `eth_chainId` | 1 |
| `eth_getBlockByNumber` | 78, including anchor |
| `eth_getTransactionByHash` | 77 |
| `eth_getTransactionReceipt` | 77 |
| `eth_getBlockByHash` | 77 |
| Total | 310 |

Chain **4663** and anchor **108944663** / hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
authenticate before named requests. Named transaction blocks range from
**45652334 to 87421203**, all at/before that anchor.

For every transaction, the oracle independently checks transaction and receipt
hashes; block hash/number; sender/callee; canonical quantities; transaction index;
full block-by-hash versus block-by-number object equality; unique block membership
at that exact index; header identities; successful receipt status; and every log's
transaction/block/index, address/topics/data, removed flag and strict ordering.
All **2,368** logs in each archive pass. Every normalized transaction, receipt
and full block object equals the corresponding raw RPC result, and each standalone
transaction file/request linkage agrees with the archive.

All **310** corresponding raw responses are also byte-identical between the
independent and producer runs. Their complete semantic comparisons and all
**154** normalized source-event/claim-array checks are in `cross-checks.json`.
This is evidence from two actual calls through the same existing provider, not
independent-provider consensus or a trustless proof.

There are **zero actual HTTP/RPC/transport errors, null or missing results,
ID/schema failures, unavailable transactions or redacted responses in either
run**. Their complete failure lists remain present and empty, not dropped.
Local tests exercise actual wire parsing of partial null/missing/error/ID/version/
quantity failures and redacted failures without calling them successful results.
Raw captures are response entity bytes, not HTTP framing, original signed
transactions, historical storage or execution-prefix traces.

## 6. Every purchase, claim and economic qualification

`independent-proof.json` retains all 77 original rows and both lanes' complete
reference reviews, source/SY events, actual caller/callee/value/calldata,
per-sender direct/routed inputs, canonical checks and every raw response envelope.
It independently matches all **568 selected saved Transfer locators per lane**,
including asset, transaction, log index, sender, recipient, amount/token ID,
block and transaction index. Nothing is sampled.

All **43 weighted** and **16 earlier** mints match their exact IDs and recipients.
Each generation's source event and basis match. Weighted start/duration fields
also match their saved purchase rows. Earlier basis stays LP-accounting shares,
not fixed DETF principal or physical fungible LP. DTF/WETH input quantities stay
separate exact native18 integers; observed inbound zero is not zero net cost.

All **18 known raw claims** match the actual source `ClaimWithdrawn` weight/output
and exact saved SY output. All source/SY logs, outer value/calldata and output
locators remain retained. Seventeen direct exact-length calls match the original
weight; arbitrary indirect calldata is never decoded as a direct source method.
This does not establish full original W0, Q0, all prior claims or prior delivery.

### Fifteen earlier routed-comparison flags

For all sixteen CP purchases, direct DTF/WETH match. The saved routed DTF equals
the observed inflow from earlier SE
`0xb7d4bb379d361ad442cddee53ea71a33957826a7`. Fifteen also have separate inbound
DTF from LP address `0x923877336b14662cfb5b3a60b14e7d716d54a888`.
The collector compares the broader non-payer sum and retains `routed-dtf`.
This is a **comparison-scope difference**, not proof the historical routed field
is wrong. The extra inflow is not promoted into another user contribution.

| CP NFT | Saved SE-routed DTF | Separate LP-address DTF |
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

CP NFT3 has no additional LP-address inflow. It retains direct WETH
`2000000000000000000`, direct DTF `0` and separate routed DTF
`1778859964387451305574664`; those are not summed as contributions.

### Four indirect weighted purchases and one indirect claim

Weighted IDs **19, 20, 23 and 42** retain
`indirect-purchase-or-different-caller`. Their mint/event/payment observations
match, but the outer caller differs and callee is
`0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789`, selector `0x1fad948c`.
No interpretation of the arbitrary outer call or its full action scope is
substituted for direct original-wallet proof.

`conversions.csv#row=21`, transaction
`0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb`,
retains `indirect-or-unexpected-claim-call`. Outer caller is
`0x5512144047c2d55297c8470b93e8da87864617cd`; the same indirect callee/selector
has zero outer value. The actual source event names
`0x2c0400cf47e5ea01364e44c237aed22d7ae86199`, consumed weight
`20000000000000000000000` and SY output `36107853`. Those match the retained
known output, while `decodedDirectWeight` stays null.

All **20** flags exactly match independent reconstruction. Flagged purchase
direct attribution remains null. The other 57 unflagged references are not
57 eligibility approvals. Shared/multiaction attribution guards remain tested;
there is no whole-transaction-total assignment to every original recipient.

## 7. Source/test review, failures and unavailable tooling

| Boundary | Actual inspected owner |
| --- | --- |
| Authenticate full inputs and preserve row references | `candidate-input.ts`, `receipt-input.ts` |
| Exact configured provider and finite request schedule | `receipt-evidence.ts` |
| Raw bytes, envelope types/IDs, safe redaction and explicit failures | `receipt-rpc.ts` |
| Canonical associations and every log | `receipt-association.ts` |
| Mint/source basis, direct/routed inputs, direct-only claim interpretation | `receipt-reconciliation.ts` |
| Wire failure, identity, sharing and attribution regressions | `receipt.test.ts`, `receipt-reconciliation.test.ts`, `receipt.fixture.ts` |
| No operational archive admission | unchanged `schema.ts`, `bundle.ts`, `execution-schema.ts`, `execution-domain.ts` |

Unqualified filenames above are in `scripts/recovery/dtf-migration/`.
The CLI addition only selects this narrow command and returns; it does not
enter execution/signing paths. Both archive/candidate versions remain rejected
by operational loaders. The verifier additionally submits the **complete actual
archive object**, not only a small fixture, to preparation, prepared-envelope
and execution schemas: all reject, recorded in `final-state.json`.

The complete suite contains 128 prior tests plus 31 new behavioral tests.
Coverage includes wrong chain/anchor; partial unavailable/error/ID/version/schema
responses; malformed quantities; contradictory transaction/receipt/block/log
identities; membership/order; duplicate references; source events versus mints;
direct/routed distinctions; indirect decoding; association-failure attribution
withholding; exclusive outputs; redaction; and operational schema rejection.
Wire fixtures exercise real transport/parsing. No sleeps or polling tests were
introduced. No production source was changed by this verifier, so no Forge or
unchanged full-rehearsal replay was warranted or performed.

Producer attempts remain authenticated: pre-recorder TS2345 diagnostic summary,
types01 TS7022 failure, focused tests, four deliberately broken-guard failures
and subsequent restored final gates, and the rendered-read parse failure.
The first compiler event is represented as a summary with a session locator,
not as retained raw compiler output. There was no failed producer live collection
and no failed verifier runtime/check. The verifier's early tool-rendered display
truncations and one eval helper-name lookup failure changed no evidence;
complete raw parsing and the actual independent oracle succeeded.

Biome and basedpyright language servers are unavailable here. Producer TypeScript
LSP timeouts are retained, not relabeled passing diagnostics. No install/config
workaround was used. Required real TypeScript checks pass; the Python oracle was
executed successfully, not claimed independently static-type-checked. Verifier
support files are below 200 nonblank/noncomment lines and have separate
responsibilities: command capture, raw authentication/canonical checking,
economic reconciliation, and credential scan.

## 8. Exact identities and stopped cleanup

The independently collected main outputs are byte-identical to the producer:

| Actual independent output | Bytes | SHA-256 |
| --- | ---: | --- |
| `actual/archive.json` | 3848804 | `e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b` |
| `actual/reconciliation.json` | 251139 | `c1717f1e35984ff03aeddd16c6a7571439e8066f4160fdeec2f7f844ced1577e` |
| `actual/http-manifest.json` | 154633 | `6feab989ce86fe70e1b70ad37acb42a775131c5e46a848b575689436f88d0731` |
| `independent-proof.json` | 7808127 | `18e9c490df316d958a9d0b8f841ba0c8de103693b6ea66143e22627ea67bbb0a` |

All eight verifier terminal/monitor sessions delivered actual completion exits.
Every recorder waits for child close before publishing metadata. There is no
pending collector, oracle, test, server, signer, chain, subagent or cleanup.
Tests completed awaited fixture cleanup; Python used `-B`, creating no pycache.
No temporary chain/checkpoint or separate temporary worktree was created. All
actual output and attempted-check records are retained; nothing was removed to
conceal a failure. Shared services, dependencies, warm artifacts, inputs and old
evidence are untouched.

`cleanup.json` records that stopped state; `manifest.json` binds every verifier
file except itself and `seal.json`. The final `seal.json` binds the complete
manifest, report, cleanup, exact source state and actual archive, and is published
last. No verifier artifact write follows the seal.

## 9. Limits that remain limits

Named receipt acquisition narrows one missing-archive gap only. It does not
automatically close the old 1,240 unresolved candidate records. Gross transfers,
mints/events and matching recipients do not prove net contribution, refunds,
native/WETH recovery coverage, current control, original economic eligibility,
all historical exposure or previous compensation. Unknowns do not become zero.
Indirect/multiaction scope remains explicit; no arbitrary calldata is treated as
a direct source call. Earlier receipt supply discrepancy and stale cutoffs remain.

No complete W0/Q0, full prior claims, zero prior credit, C0, configuration,
eligibility flag, source allowance or award was inferred. Broader T conservation,
E-S implementation/exposure, disabled downstream conversions, actual operational
originals, funding/composition/snapshot and target registration
**45116678 > 32000000 gas** remain separate.

P1 still names the unavailable first-producer raw versions:
`MigrationSnapshotConsumer.json`, 466441 bytes / SHA-256
`e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf`,
and `MigrationNativeHandler.json`, 266621 bytes / SHA-256
`3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013`.
No search or reconstruction of those bytes occurred.

**Complete, confirmed and stopped for this bounded independent verification;
no operational eligibility, full Task9 or full-plan acceptance.**
