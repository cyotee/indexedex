# Independent observed-recipient flow worksheet verification

Date: November 13, 2026.

**Verdict: confirmed for the complete bounded offline receipt join and
observed-recipient Transfer-event derivation. No needs-fix worksheet derivation
defect was found.** The final independent program exited 0 with empty stderr:
17,922 checks pass, with no failures. This is not source admission, a financial
allocation, operational readiness, or full migration-plan acceptance.

## Subject and authenticated inputs

Subject:
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/observed-recipient-flow-review-20261113.json`.

Its actual identity is **902,872 bytes**, SHA-256
`ed8474ac3454453697308ce82adffebb8bbfe9d346050973e0753a46cf6af39e`,
matching the requested identity.

The four source bodies authenticate against the worksheet's exact declarations:

| Input | Bytes | SHA-256 |
| --- | ---: | --- |
| phase28 archive | 3848804 | `e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b` |
| phase28 reconciliation | 251139 | `c1717f1e35984ff03aeddd16c6a7571439e8066f4160fdeec2f7f844ced1577e` |
| phase30 archive | 5917231 | `67a8cd97a26d0bfe4fc118469db605a9b0424e7b40c17fb977f6bd6990dfefc0` |
| phase30 reconciliation | 841408 | `7b900c143f64446301f8385f81eaa0daaada81a06d4dd0468de4b38dcd5d90d2` |

`inputs.json` records absolute paths, byte lengths and SHA-256 for all eight
inputs: the subject, four source bodies, both accepted verification reports,
and the current plan. Both archives also bind the supplied reconciliation
body's exact length and hash. The plan identity is
`60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`;
only sections 2.1 and 5 are interpreted here.

Accepted reports:

- Phase28 `receipt-evidence/verification/report.md`, 20,647 bytes,
  SHA-256 `77bb12de3b210f0091d4f7409fdb52eff81b1fec5d8cc11dce0db38897bfa5aa`.
- Phase30 `recovery-receipts/verification/report.md`, 13,625 bytes,
  SHA-256 `b6fd48a199b7a577eaa4007741264d99e7b21d700a147e979c6e3f47b6077b50`.

Their recorded successful canonical/chain validation is reused as accepted
evidence, not rerun. They record chain 4663, anchor 108944663 and hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
This review authenticates those report bodies; it does not independently
reacquire their historical chain facts or replay their old proof programs.

## Independent method and coverage

`prove.py` is new, Python-standard-library-only, and imports no collector,
producer reconciliation, old oracle, operator loader or worksheet generator.
It authenticates every input before JSON interpretation. The expected joins,
recipient population, events and sums are built from the source bodies before
comparison with worksheet rows; worksheet totals are not their oracle.

The derivation uses historical purchase recipients/owners and conversion or
recovery recipients, cross-checked against the recorded mint/claim/expected
recipient fields. It does not use current owners or outer callers as a
substitute. Every archive result's reference membership is compared with its
lane's complete reconciliation. Every source-array index, original locator,
transaction and recipient is retained in `proof.json/sourceRows`.

| Independently reconstructed population | Result |
| --- | ---: |
| phase28 source-array rows / transactions | 77 / 77 |
| phase30 source-array rows / transactions | 319 / 319 |
| Source-array occurrences before joining | 396 |
| Overlapping transactions | 20 |
| Distinct union transactions | 376 |
| Repeated original locators across lanes | 18 |
| Unique original-row references | 378 |
| Recipient/transaction rows | 378 |
| Distinct recorded recipient addresses | 150 |
| Flagged original-row references | 20 |

The phase28 rows comprise 43 weighted purchases, 16 earlier CP purchases and
18 claims. Phase30 supplies 250 conversions and 69 observed recoveries.
The 18 claims share their original locators across lanes; the other two shared
transactions link different NFT and conversion locators.

All 20 overlaps have deeply equal complete `observed`,
`receiptObservation`, and `transactionObservation` objects, ignoring only JSON
object-property order. Lane-specific request IDs and reference membership are
not confused with chain semantics. All 376 transactions enter the union once.

Every joined reference matches its exact source indices and unioned flags and
qualifications. No extra/missing locator or recipient/transaction key exists.
Every flow row matches its exact recipient references, full transaction-reference
membership, outer sender/callee/value, both asset identities/units, exact event
list, incoming/outgoing sums, signed difference and unknown financial fields.
`allTransactionReferences` is compared as a membership list, retaining duplicate
detection; its phase encounter order is not an economic or locator contract.
Source-array indices themselves are compared exactly.

## Asset identities and exhaustive event reconstruction

Plan section 2.1 fixes these two distinct historical input assets:

| Label | Address | Units |
| --- | --- | --- |
| DTF | `0xee5576fa1bcaa380e591d01245f406f3f384eb01` | native18 |
| WETH | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` | native18 |

These are not the weighted native9 DETF, sDETF or SY assets. Section 5 requires
integer native units and forbids counting routed intermediates as another
contribution. The proof uses arbitrary-precision integers, never floating point.
There is no cross-asset sum or ETH/C0/current-value conversion.

All **4,372 receipt logs** in the 376-transaction union are traversed. Exactly
465 logs have a fixed asset address and the Transfer topic: 404 DTF and 61 WETH.
The other 3,907 logs are outside this two-asset Transfer scope. Of the 465,
129 touch a recorded recipient in that same transaction; 336 touch only other
endpoints and are excluded from recipient flows.

`proof.json/eventCensus` retains each fixed-asset Transfer, including excluded
ones, its affected-recipient set, transaction, originating archive/result
indices, receipt-array offset and decimal log index. These resolve to exact
hash-bound raw log locators such as
`archive28.results[i].receiptObservation.logs[j]`. `recipientFlows` retains
each included log's exact sender, recipient, amount and log index.

Incoming and outgoing are accumulated with separate endpoint predicates, so a
self-transfer would enter each sum once and cancel in the signed difference,
while appearing only once in the matching event list. There are **zero actual
self-transfers** among all 465 fixed-asset Transfer events; none was dropped
because its net would cancel.

| Metric, across all 378 recipient rows | DTF18 | WETH18 |
| --- | ---: | ---: |
| Matching event appearances / unique relevant events | 112 / 112 | 17 / 17 |
| Positive signed-net rows | 69 | 0 |
| Negative signed-net rows | 43 | 17 |
| Zero-event rows | 266 | 361 |
| Zero-net rows | 266 | 361 |

There are 250 recipient rows with no event for either fixed asset. The complete
per-row exact integer sums, including every negative sign, match. Equality of
the independently reconstructed full event lists and row populations proves
that every relevant event/recipient is represented and no unrelated recipient
or event is included. Other transaction participants are not automatically
new worksheet recipients.

## All older flags remain

All 20 phase28 flags survive unchanged in the joined references:

- Fifteen `routed-dtf` flags: `evidence/earlier-cp-bonds.csv#row=3` through
  `#row=17`, inclusive.
- Four `indirect-purchase-or-different-caller` flags:
  `evidence/weighted-bonds.csv#row=18`, `#row=19`, `#row=22`, `#row=41`.
- One `indirect-or-unexpected-claim-call` flag:
  `conversions.csv#row=21`.

The claim is worksheet `references[11]`, joined from `recon28[11]` and
`recon30[122]`, transaction
`0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb`,
recorded recipient `0x2c0400cf47e5ea01364e44c237aed22d7ae86199`.
The phase30 generic output match does not erase the older indirect-call flag.
All source qualifications are unioned as well; matching an output is not
original-wallet authority or eligibility approval.

## Two shared transactions: distinct contexts, no double attribution

The two pairs retain the acquiring-wallet context and the weighted-NFT
protocol recipient `0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e`
as separate rows. The wallet in both pairs is
`0xd221eea1c0ca823f57a96fdfe1d392a367384fdd`.

| Transaction | Original contexts | Worksheet flow indices | Wallet DTF18 signed net / log |
| --- | --- | --- | --- |
| `0x8175991424ff423b7e184076fbba7e2a3c6172c7b39d7993492b6d64edbaa7bd` | weighted NFT row43; conversion row94 | 176, 177 | `-1000000000000000000000`, log `0` |
| `0xd70fc904c7b3c6889eb2d3caad6417965674f4b2250a8d20a6649be3cae2e731` | weighted NFT row44; conversion row100 | 320, 321 | `-100000000000000000000000`, log `23` |

In each case the wallet's DTF transfer goes to weighted DETF
`0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7`, not the weighted NFT recipient.
The NFT protocol recipient has no matching DTF/WETH event and retains zero
event sums, rather than receiving the wallet's whole-transaction input.
Each row keeps both transaction references as context but only its own original
reference in its recipient-specific list. All indices above are zero-based.

Outer sender, callee and value are transaction context repeated explicitly,
not allocated inputs. All 376 recorded outer values are zero; this does not
establish zero economic contribution. Neither pair's input or value is
assigned as an original contribution to both contexts.

## Interpretation and unresolved financial facts

The worksheet's seven meaning statements preserve the required boundaries.
Recorded recipients may be protocol addresses; they are not automatically
original contributing wallets or people. A zero matched-event count or zero
emitted net flow does not establish zero economic contribution. Transaction
value alone does not resolve internal refunds, wrapping/unwrapping, fees,
other assets or multi-action attribution.

Current custody, complete original E0/D0, compensation deduction/C0,
eligibility, original-wallet authority, all prior claims and prior compensation
remain unestablished. All 378 rows retain unknown original contribution and
compensation deduction. These observed sums are not balances, approved payment
inputs, migration credit, source allowance or an executable allocation.
No partial phase29 evidence is an input.

## Reproduction, diagnostics and retained verifier correction

Run from any working directory with Python's standard library:

```sh
python3 -B /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/recipient-flow-review-verification/prove.py
```

The program reads `inputs.json` beside itself, requires all eight exact raw
identities and emits deterministic JSON to stdout. It writes no files.
Expected exit: **0**. Expected stdout is exactly `proof.json`:
3,313,903 bytes, SHA-256
`6840c3dd337213e5fb7569728cdd1304df178bc5a5a5f3e1a1cbdb2d0794548b`.

The actual final invocation ran **09:37:14.458Z to 09:37:14.561Z** on
November 13, 2026. `command.json` records exact executable/argv, CWD, runtime,
start/stop, exit, stdout/stderr and proof-source identities. Python was
3.15.2; the capture runtime was Bun 1.4.4. The published proof is byte-identical
to captured stdout.

The initial verifier exited 1 solely because it incorrectly required sorted
`allTransactionReferences` order at flow indices 176, 177, 320 and 321.
The worksheet instead retains phase28-before-phase30 encounter order.
`attempts.json` retains all four exact actual/expected lists, times, exit and
stdout identity. The verifier was corrected to compare membership without
losing duplicate detection. This is not a worksheet defect, and no worksheet
or source body was edited. The complete corrected run passed.

Biome and basedpyright language servers were unavailable; no static
diagnostic pass is claimed and no installation was attempted. The new proof
program actually executed successfully. Old tests, collector/oracle programs,
builds, source-admission gates and live chain validation were not replayed.

## Stopped cleanup, preservation and seal

Only new files in this `recipient-flow-review-verification/` directory were
authored. No source, worksheet, accepted evidence or plan edit occurred.
No Git operation, network/RPC call, provider retry, phase29/delegation/signing
work, deployment, financial approval or historical acquisition occurred.

Both proof invocations completed and their exit codes were observed. The
program spawns no process and starts no server, monitor or background task.
No temporary runtime, worktree, dependency or chain was created, and no cleanup
deletion is needed. There is no pending owned process.

`cleanup.json` records the stopped state and reauthenticates all eight inputs
after the review. `manifest.json` binds every new review artifact except itself
and the seal. `seal.json`, published last, binds the manifest, report, proof,
command, input identities and cleanup. No review-artifact write follows the
seal.

**Complete, confirmed and stopped for this bounded derivation review only.**
