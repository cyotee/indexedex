# Phase 30 independent stopped verification

Date: November 13, 2026.

**Verdict: confirmed for the bounded phase 30 source/data increment.**
No needs-fix source or actual-data defect was established. Independent strict
TypeScript passes, the complete operator suite passes with 172 tests, and the
sole independent actual collector has exited successfully. Independent raw
reconciliation verifies all 319 canonical associations and exact outputs in
both producer and verifier archives. All owned execution and cleanup have stopped.

This confirms named receipt observations, not compensation, source admission,
current control, operational readiness, full Task 9 or full-plan acceptance.

## Subject and stopped handoff

Subject:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts`.
Branch: `work/dtf-migration-phase-30-recovery-receipts`.
Unchanged HEAD/base: `07d54b9a3d20d98aee24e75235bbf16b650a8028`.
Only this `verification/` directory and its removed temporary runtime were owned.
No source fix, staging or commit occurred.

The entire phase 30 brief, current plan r5 and PRD r22 were read, along with
the router/assistant rules, complete tracked increment, collector dependencies,
behavior tests and accepted phase 28 report/seal/cleanup. Current original-wallet,
Stage 2-only and owner-first-paid-bond requirements govern historical policy.
Phase 29 was not resumed.

The producer's complete report, source manifest, evidence manifest, cleanup
and final seal were required before execution. All 2,922 manifest entries,
seven direct seal bindings and the manifest binding authenticate. All 70
operator/runbook source bindings match. All 276 source snapshots across the
four passing producer gates and all 552 snapshots across eight verifier
commands match the unchanged operator bodies. No producer artifact or bound
original changed during verification. `intake-and-preservation.json` retains
every expected/actual check; `source-manifest.json` binds sources and commands.

`final-boundary.stdout` retains the complete actual source diff, branch/HEAD
and status, not an excerpt. It equals the sealed producer diff. The staged
diff is empty and read-only Git whitespace validation exited 0. Exactly the
same eight tracked paths remain modified; untracked evidence is separate.

## Independent acquisition and input population

Input root:
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`.

The existing loader and an independent manifest/hash implementation both
authenticate all 36 declarations over 27 paths, plus the manifest body:
28 bodies total. `sources.json` authenticates before its declarations are used.
These are recovered hash-authenticated historical bodies, not located original
captures. No historical hash or CSV was rewritten.

The oracle independently parses complete originals using its own CSV tokenizer,
not producer parsing/reconciliation. Derived populations:

| Original table/kind | Rows |
| --- | ---: |
| bond_to_sdetf | 7 |
| legacy_weight_to_sy | 18 |
| detf_to_sdetf | 138 |
| sdetf_to_detf | 87 |
| All conversions | 250 |
| observed-recoveries | 69 |
| Union, also distinct transaction count | 319 |

The maximum declared block is 104818717. Original purchase/claim tables derive
the prior 77 hashes independently and agree with the accepted old archive.
Their overlap with this selection is 20: 18 raw claims and two detf_to_sdetf
conversions. Thus 299 hashes were missing from that prior named archive.
The old 77 collector was not replayed.

The sole verifier live command ran from **08:34:34.649Z to 08:36:32.574Z**,
November 13, 2026, and exited **0** with empty stderr:

```sh
bun scripts/recovery/dtf-migration/cli.ts collect-receipts \
  --input "$COMPLETE_RECOVERED_TREE" --output "$VERIFICATION/actual" \
  --rpc-alias robinhood_mainnet_alchemy \
  --selection conversions-and-recoveries
```

`collect.command.json` retains exact argv/CWD, actual start/stop/exit, source
identities and stream identities. The existing login-shell bootstrap provided
the selected `ALCHEMY_KEY`; no private endpoint/key entered argv or evidence.
The collector accepts only the existing exact alias template in foundry.toml.
No alternate provider/method, trace, range scan, retry bypass, delegation,
wallet credential, operational signature or transaction submission occurred.

Chain 4663 and anchor 108944663 / hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
authenticate before named requests. Actual named blocks span 64397386 through
104818717, all at or before anchor.

| Actual method | Requests per archive |
| --- | ---: |
| eth_chainId | 1 |
| eth_getTransactionByHash | 319 |
| eth_getTransactionReceipt | 319 |
| eth_getBlockByHash | 319 |
| eth_getBlockByNumber, including anchor | 320 |
| Total | 1278 |

Both actual archives contain zero HTTP/RPC/transport errors, null/missing
results, unavailable records or redacted responses. Empty failure lists are
explicit in `proof.json`. Every raw entity/request is retained with length,
SHA-256, method/params, response ID, HTTP status and raw qualification.
`credential-scan.json` records zero literal/encoded selected-key matches across
5,804 then-present producer/verifier files and clear command streams. Later
proof/report records derive from those checked bodies and public source data.

## Independent all-row proof

`raw.ts` independently authenticates every captured entity and envelope,
rejects duplicate or orphan method/parameter requests/files, and validates
every transaction/receipt/block/log association. It verifies exact block
membership/index, sender/callee, block number/hash, successful status, all
2,228 logs per archive, unique ordered log indices and complete canonical
block-by-hash versus block-by-number equality. All normalized archived
observations and standalone transaction files match their raw results.

`oracle.ts` independently derives each row's candidates, exact matches,
expected saved transfers, transaction context and unresolved conditions.
Neither file imports producer transport, association, CSV or reconciliation
algorithms. Imports of the existing input loader and three intake schemas
provide additional boundary checks, not the raw oracle.

All 319 original fields/locators, exact native output amounts/assets/recipients,
declared blocks, and all 319 selected saved Transfer locators match. Recovery
matches additionally require the exact log index. Zero/multiple matches,
unknown amounts and shared-transaction attribution are reconstructed rather
than replaced by totals. In this actual population there are 319 unique exact
matches and zero output/canonical/saved-transfer conflicts in each archive.
Every complete actual archive is rejected by preparation, prepared-envelope
and execution schemas.

`proof.json` retains every qualification row in both lanes, full original
fields, individual output/candidate locators, caller/callee/value/calldata,
units, input identities, raw capture identities, overlap locators and conflict
lists. `output-identities.json` binds main verifier outputs. Proof identity:
4,434,725 bytes, SHA-256
`a49921f03a27653a651d97fedbe6deac16683b98458d58ea700feceb03024032`.

Both runs have identical complete normalized results and byte-identical
reconciliation. Of 1,278 corresponding raw responses, 1,277 are byte-identical.
Response 482, eth_getBlockByNumber for 0x3da6876, differs only in JSON-RPC
object property order: producer places id after result, verifier before it.
Parsed envelopes are deeply equal. Both raw entities and their different
hashes remain; this changes the HTTP-manifest hash and consequently the
archive's HTTP binding, not observed chain facts. `cross-checks.json` records
the exact difference.

## Preserved flags, units and economic limits

All 250 conversion rows retain `is_external_recovery=false`. All 69 recovery
rows retain `classification=detf_exchange_output`, native18 DTF,
`deduct_from_R=false` and blank `R_eth`. Conversions retain native9 sDETF,
SY and DETF as distinct assets. No cross-unit total, ETH/C0/current-value
translation or compensation deduction was created.

Every row retains reviewed-observations-only status and null priorCompensation,
compensationDeduction and currentCustody. Blank principal/reward/historical
fields remain blank. Matching gross transfers are not net original
contributions, all prior claims/refunds, zero prior compensation, current
holdings/control, eligible original exposure, W0/Q0 or entitlement transfer.
No transaction total is allocated to multiple rows or conflated with principal
and rewards.

The existing input loader projects `sources.json` onto its parsed schema and
does not copy its historical `policyRevision` key into parsed archive metadata.
The first strict raw-versus-parsed oracle comparison exposed that existing
projection. The original body remains hash-bound; the final proof explicitly
preserves its full document and value
`held-assets-no-upfront-credit-20261108`, records the projection and rejects
that stale field as current policy authority. No CSV flag or unknown was lost.

Matching legacy conversion outputs does not admit direct or delegated claims.
In particular, the phase 28 indirect claim qualification for
`conversions.csv#row=21` remains in that immutable archive. The new lane retains
the complete outer call and raw logs without decoding arbitrary calldata as
withdrawClaim or promoting a matched output into source approval.
All new archives remain NON-ISSUABLE. Old 1,240 candidate unknowns are not
automatically closed.

## Code/default/operational audit and actual checks

The complete increment is confined to the existing receipt-input,
receipt-evidence, receipt-reconciliation, CLI, their three fixture/test files
and operator runbook. Selection is explicit; omission keeps purchases-and-claims
and its old archive shape. Requests deduplicate transaction retrieval only,
not row identity. Existing ReceiptRpc and canonical checks are reused.

CLI selection is rejected on every non-collection command; collection rejects
execution flags, URL overrides, duplicate arguments and unknown selections.
Input authentication precedes credential resolution. Output publication is
fresh/exclusive. Pricing, lineage admission, execution, signer and operational
schemas are unchanged. No evidence archive becomes an executable dataset.

Independent strict TypeScript over all 69 operator bodies and recorder exited 0
with strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes and
verbatimModuleSyntax. Final support types including both oracle modules also
exited 0. Final complete suite: **172 pass, 0 fail, 15 files**, Bun 1.4.2.
The full two-archive oracle exited 0. Command files retain exact flags/streams.

Behavior tests cover selection/default exclusion, all-row unavailable accounting,
native schema/unknown amounts, exact asset/recipient/amount/log-index/block,
ambiguity/shared attribution, canonical contradictions and operational rejection,
alongside existing transport/redaction/canonical tests. No tests were changed
or weakened by this verifier, and no sleeps or timing retries were introduced.

Retained verifier failures:

- Initial owned-runtime suite: 171 pass, one failure because the existing CLI
  subprocess uses relative scripts/recovery/dtf-migration/cli.ts. Adding only
  an owned read-link to the subject scripts fixed the runtime; the final entire
  suite passed. The ABI was read through an owned link to existing phase 28 out.
- Initial support types: TS2345 in the verifier's flatMap inference. An explicit
  Transfer generic fixed verifier code; the final strict check passed.
- Initial oracle: original policyRevision versus existing parsed projection,
  resolved explicitly as described above, with the failed receipt retained.
- A tool-rendered large manifest read was truncated; full raw reads then
  authenticated all bindings. No evidence was edited to make it parse.

Fresh LSP diagnostics timed out; Biome is not installed. Neither is called a
passing check. No installation/configuration workaround was attempted. Required
real compiler and behavior checks passed. Producer failures/diagnostics remain
unchanged and bound. No Forge or unchanged full rehearsal was run.

Verifier support responsibilities are command capture, raw authentication and
row reconciliation; each is below 200 nonblank/noncomment lines. No suppressions,
type assertions or source fixes were introduced.

## Stopped cleanup and seal

All eight recorded commands and their children have actual stopped exits.
The live collector and all oracle/test operations finished before this report.
The two owned runtime links and empty tmp/runtime directories were removed;
no shared target was modified or removed. Post-cleanup process inspection
exited 0 and showed only the harness-managed TypeScript language server,
not an owned collector/test/oracle. Shared services were left untouched.

`cleanup.json` records actual stops, runtime removal and retained failures.
`manifest.json` binds all verifier artifacts except itself and seal. The final
`seal.json` is published last, after owned operations stop, binding report,
proof, cleanup, source/evidence manifests and actual output identities.

No deployment, funding, activation, real allocation, held09/gas work,
full Task 9/full-plan approval or P1 reconstruction follows this result.
Broader source/exposure, prior-compensation, current-control and gas/funding
limits remain separate. **Confirmed and stopped for this bounded increment.**
