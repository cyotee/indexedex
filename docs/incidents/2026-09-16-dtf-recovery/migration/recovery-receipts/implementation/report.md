# Phase30 stopped conversion and recovery receipt acquisition

Date: 2026-11-13.

**Producer deliverable complete:** explicit bounded selection, strict types,
meaningful tests, one actual complete 319-transaction acquisition and exact
all-row raw-response reconciliation. All 319 canonical associations pass.
All 250 conversion and 69 recovery outputs match exactly, with no missing,
ambiguous, shared-transaction or declared-block conflicts in this actual set.
Every record remains reviewed observations only and NON-ISSUABLE.

This is the producer handoff, not independent-verifier confirmation. The
producer owns implementation/ only, has not authored verification/, and has
launched no delegated task. The brief's separate verifier must inspect this
stopped source/evidence/seal, execute its own suite and complete319 collection,
and publish confirmed/needs-fix. The producer-side independent algorithm below
is additional evidence, not a substitute for that separate role.

## Source and authorization boundary

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts`

Branch: `work/dtf-migration-phase-30-recovery-receipts`.
Base and unchanged HEAD: `07d54b9a3d20d98aee24e75235bbf16b650a8028`.
No commit or staging occurred. `boundary.md` records the parent/source
boundaries before editing. The parent, originals, prior archives and candidates
were not edited.

Only these existing operator files changed:

- `receipt-input.ts`: explicit selection and typed original output references.
- `receipt-reconciliation.ts`: exact native output matching and qualifications.
- `receipt-evidence.ts`: selection plumbing and unavailable-record qualification.
- `cli.ts`: narrow collection-only option; existing execution paths reject it.
- `receipt.fixture.ts`, `receipt.test.ts`, `receipt-reconciliation.test.ts`:
  request selection, native schema, ambiguity and canonical-boundary regressions.
- `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`:
  operator invocation and interpretation.

Unqualified source paths above are under `scripts/recovery/dtf-migration/`.
`source.diff` preserves the complete tracked diff and final status, not an
excerpt. `source-manifest.json` binds all 69 operator TypeScript files, the
runbook, all three evidence scripts and gate source identities. Every operator
body matches the final strict check, passing suite, actual collection and oracle
command snapshots.

The complete brief, current plan r5 and PRD r22, router and assistant coding/
testing/deployment rules, accepted phase28 collector, fixtures, reconciliation,
producer report and independent verification report were read. The current
original-wallet, Stage2-only and owner-first-paid-bond rules govern. Historical
conversion/recovery labels are observations, not new compensation policy.
This acquisition is distinct from, and does not resume, phase29.

## Explicit finite selection and unchanged default

```sh
bun scripts/recovery/dtf-migration/cli.ts collect-receipts \
  --input /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery \
  --output "$FRESH_IMPLEMENTATION_OUTPUT" \
  --rpc-alias robinhood_mainnet_alchemy \
  --selection conversions-and-recoveries
```

Omitting selection preserves the previous purchases-and-claims path and output
shape. The new selection enumerates every original row in both complete bound
tables; no hash list or fixed319 oracle selects records. Request deduplication
shares transaction retrieval, not row identity or economic allocation.

The existing loader authenticates sources.json through manifest.json before
using its declarations, then authenticates every original binding before CSV
derivation or credential resolution. There are 36 declarations over 27 unique
declared paths and 28 bodies including the manifest. All authenticate, including
Markdown and pre-exploit sibling inputs. `actual/inputs.json` retains every
declaration and raw identity. These are recovered hash-authenticated historical
bodies, **not located original captures**. No raw historical hash was changed.

| Complete authenticated origin | Rows / distinct transactions |
| --- | ---: |
| bond_to_sdetf | 7 |
| legacy_weight_to_sy | 18 |
| detf_to_sdetf | 138 |
| sdetf_to_detf | 87 |
| All conversions | 250 |
| observed-recoveries | 69 |
| Union | 319 |

Independent comparison with the old77 archive derives 20 overlapping rows:
the 18 raw claims and two detf_to_sdetf conversions. The remaining299 were
outside that named archive. All20 overlap transactions were collected as part
of this new complete scope; the old77 collector was not separately replayed.

## Actual acquisition and safe raw identities

`collect.command.json` records the exact invocation, CWD, source identities,
start **2026-11-13T08:22:40.022Z**, stop **08:24:38.736Z**, exit **0** and
empty stderr. This was the sole actual producer collection, with no failed or
replacement live attempt. Exit0 means canonical acquisition, not approval.

The existing login-shell credential bootstrap supplies only the selected
`ALCHEMY_KEY`. The collector requires the exact existing
`robinhood_mainnet_alchemy` template in foundry.toml. No endpoint/private
credential appears in argv, report or request bodies. There is no URL option,
alternate provider, redirect, retry middleware, trace, range scan, signer,
wallet key or transaction submission.

Chain **4663** and canonical anchor **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
authenticated before named requests. Actual matched blocks span
**64397386 through 104818717**, all at/before anchor.

| Actual read method | Requests |
| --- | ---: |
| eth_chainId | 1 |
| eth_getTransactionByHash | 319 |
| eth_getTransactionReceipt | 319 |
| eth_getBlockByHash | 319 |
| eth_getBlockByNumber, including anchor | 320 |
| Total | 1278 |

All1,278 requests succeeded. There were no actual HTTP/RPC/transport errors,
null/missing results, response-ID/schema errors, unavailable transactions or
redacted responses. Complete request and safe raw response entity bytes remain
under `actual/http/`, bound by length and SHA-256 in `http-manifest.json`.
The HTTP manifest records IDs, methods, parameters, HTTP status, raw flag,
received length and outcomes. Captures are entities, not HTTP framing,
historical signed transactions, storage, traces or trustless proofs.

All319 transactions retain standalone result files, full normalized transaction/
receipt/block objects, raw request links and every one of **2,228 logs**.
Transaction/receipt hash, endpoints, block hash/number, transaction index,
unique exact block membership, canonical block-by-number agreement, successful
receipt status and every log's identity/index/order pass.

The existing transport remains unchanged. Credential-bearing wire responses
are sanitized, marked non-raw and rejected; transport errors retain sanitized
diagnostics. Wire tests exercise those failures. No actual response needed
redaction. `credential-scan.json` records the literal and URL-encoded selected
RPC credential absence scan without revealing it.

## Exact reconciliation and complete qualifications

`actual/references.json` preserves all319 original rows and logical locators.
`actual/reconciliation.json` preserves every original field, caller/callee/
value/calldata, selected saved Transfer locators, individually decoded candidate
outputs, exact matches, integer amount, token decimals and declared block.

Recovery matching requires exact transaction, log index, asset, recipient,
integer amount and block. Conversion matching requires exact asset, recipient,
amount and block. Zero/multiple matches are conflicts; shared transactions
remain unresolved rather than assigning a whole-transaction total to each row.
Blank output amounts remain null and cannot match a presumed zero.
Actual results: **319 unique exact matches, zero output or canonical conflicts**.
This is exact named-output coverage, not clean economic eligibility.

`independent-proof.json` includes **every qualification row**, original field,
independently matched output, native unit, transaction context, conflict list,
all raw capture identities, input declarations and overlap locators.
`reconcile.ts` uses its own CSV decoder and raw RPC schemas/canonical checks;
it imports no producer collector, association, CSV or reconciliation function.
It separately authenticates complete input declarations and captured input
identities, every raw request/response length/hash/envelope, every log, both
full canonical blocks, normalized archived observations, standalone transaction
files, request links, all319 original rows and exact outputs. It independently
reconstructs conflict lists and compares them to the producer reconciliation.
The complete actual archive is also rejected by unchanged preparation,
prepared-envelope and execution schemas.

All250 conversions retain `is_external_recovery=false`. All69 recoveries retain
`classification=detf_exchange_output`, native18 DTF, `deduct_from_R=false` and
blank `R_eth`. These are historical labels, not proof of zero prior delivery,
net contributions or approved deductions. Conversion output units remain
native9 sDETF, SY and DETF; recovery DTF stays native18. No cross-unit totals,
ETH translation, C0 or current valuation was produced.

Every row explicitly retains reviewed-observations-only status and unknown
prior compensation, deduction and current custody as null. Matching gross
transfers do not establish net original contribution, refunds, all prior claims,
zero compensation, current control, original eligibility, W0/Q0, source exposure
or entitlement transfer. Principal and rewards are not conflated or allocated
from transaction totals. The raw-claim rows in this selection are output
observations, not newly admitted direct-EOA or delegated sources. In particular,
matching the historical indirect raw-claim output does not decode its outer
calldata as withdrawClaim or remove the prior lane's admission qualification.

The archive retains version `dtf-finite-receipt-evidence-v1` and status
`NON-ISSUABLE-RECEIPT-OBSERVATIONS`. No configuration, pricing, eligibility,
execution/signing, lineage admission or financial approval changed.
No old1,240 candidate unknowns were automatically closed.

## Checks and retained failures

The final production source passed strict TypeScript using the existing
TypeScript installation with `strict`, `noUncheckedIndexedAccess`,
`exactOptionalPropertyTypes` and `verbatimModuleSyntax`. Final support scripts
also passed the same strict gate. All command receipts and streams remain.

The final successful complete operator suite exited **0**, **172 pass,
0 fail, 15 files**, Bun **1.4.2**. There are 13 new behavioral cases beyond
the prior159, covering explicit selection/default exclusion, anchor failure
accounting, CLI rejection, exact native schema, blank unknown amounts,
asset/recipient/amount/log-index/block matching, ambiguity, shared attribution
and canonical contradictions. Existing default and operational-intake tests
remain. Three deliberate negative mutation failures prove the amount/index
and ambiguity guards; they were restored before final gates and collection.

The first complete-suite attempt failed because a new worktree had no warm
Migration ABI under out/: **87 pass,85 fail**, exit1. This was a missing
pre-existing fixture dependency, not a production change failure. Full logs
remain in `operator-tests-final.*`. Reading the existing phase28 out/ through
a symlink fixed the environment; no artifact copy/build, cache seed, install,
configuration change, Forge, Solidity or full-rehearsal run occurred. The
unchanged suite then passed once as `operator-tests-complete.*`.

`attempts.md` records the initial fixture LSP type diagnostic and its typed
fix, unavailable fresh LSP diagnostics, all recorded passes, deliberate
failures, environmental failure and recovery. Real strict compiler results
pass; LSP timeouts are not called passing diagnostics.

Every touched source module is below200 nonblank/noncomment lines. The files
retain their existing responsibilities: selection, collection, reconciliation,
CLI dispatch and behavioral fixtures/tests. Untrusted quantities are parsed
at the boundary; new code has no any, type/non-null assertions or suppressions.
The optional fourth collector argument preserves its existing positional API
and default callers, rather than creating an unrelated options abstraction.
No single-use transport/helper layer or speculative retry was introduced.

## Stopped cleanup, identities and remaining work

All collection, strict checks, test servers, oracle and recorder children have
exited. `cleanup.json` records their stopped command receipts. The84 empty
fixture directories created before the failed artifact read were removed with
nonrecursive rmdir; every exact path and selection interval remains recorded.
Successful suites completed awaited cleanup. No signer, chain, Anvil, Forge,
delegated task, operational checkpoint or pending provider call remains.

Existing node_modules remains read-linked. The temporary warm out/ link was
unlinked after checks; no dependency or artifact was installed, copied, compiled
or modified. A verifier running the artifact-dependent suite must similarly
make the existing warm ABI readable without compiling or copying it.
All actual evidence and failed
attempts remain retained. Shared runtimes and old evidence were untouched.
Read-only Git whitespace check exits0, staged diff is empty, HEAD is unchanged,
and the only tracked edits are the eight files named above. `source.diff`
captures the full source patch before temporary-link cleanup; `final-boundary.md`
records the final status after unlink, with no untracked out link.

`manifest.json` binds every implementation artifact except itself and seal.
`seal.json` binds the complete manifest, this report, source manifest, cleanup,
actual archive/reconciliation/HTTP manifest and full independent proof with
exact byte lengths and SHA-256. The sealer checks existing credential absence
and publishes seal **last**; no producer file write follows it.

Separate independent verification remains the next external deliverable.
No confirmed verdict is invented here. Broader source/data/current-control,
gas/funding limits and P1 preservation remain separate; this work authorizes no
deployment, funding, stage activation, real allocation, held09/gas work,
fullTask9 or full-plan acceptance.
