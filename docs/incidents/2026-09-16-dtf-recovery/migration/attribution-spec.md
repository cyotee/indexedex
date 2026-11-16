# E2 transfer-following attribution: exact interface blocker

Date: 2026-11-10. Scope: implementation-plan task 1, attribution only.

## 1. Verdict and boundary

**E2: FAIL under the current authenticated legacy interfaces and approved
Migration surfaces.** Ordinary fungible transfers do not maintain contribution
ancestry or prequoted Migration credit. Current ownership and remaining units
can be demonstrated for particular sources; that does not determine the credit
carried by mixed fungible holdings. A frozen address ledger cannot distinguish
the two histories in section 3. No working, authenticated, complete-history
proof construction has been established for postactivation transfers.

This is an interface-limited impossibility result, **not** a claim that
cryptographic history verification is universally impossible. Full canonical
history distinguishes the histories. A separate verifier could potentially
expose that information, but its construction, chain anchoring, completeness,
operational bounds and atomic freshness have not been supplied or implemented.
Inventing such a subsystem is outside this unit's authorization. Neither a
generic proof-shaped ABI field nor an offchain RPC journal closes E2.

Keep the affected fungible attribution ABI/storage and implementation blocked.
Do not drop any required source category or replace its entitlement with
payer-only eligibility, a static wallet allowance, a trusted fresh signature,
a mutable root, or mandatory transfer wrapping. This report changes no product
decision. The completed failure witness is an acceptable task-1 deliverable;
it is not implementation readiness.

The minimal mismatch is an information boundary: ordinary source operations
change balances, shares or claim rights without updating an authenticated
Migration attribution state; the demonstrated same-balance histories require
different awards. E1 has a separate unproved boundary: source custody alone
does not demonstrate one atomic operation that binds the current owner,
consumes the correct entitlement, takes custody and funds the new bond, with
complete rollback on failure. Neither boundary is established by a successful
standalone legacy transfer or staged recovery transaction.

## 2. Evidence and deployed interfaces

All four mandatory reports were present and read. Their original files remain
unchanged. Paths in this document are relative to
`docs/incidents/2026-09-16-dtf-recovery/migration/`; the evidence manifests contain
absolute paths and SHA-256 fingerprints.

| Producer | Concrete result | Preserved limitation |
| --- | --- | --- |
| `evidence/weighted/report.md` | 34 PASS, 1 FAIL, 2 UNPROVEN; authenticated historical code, purchases, claims, actual custody and staged conversions | Approved operator can redirect legacy bond payouts; complete fungible attribution and integrated Migration safeguards unproved |
| `evidence/earlier-cp/report.md` | Pinned Alchemy replay: 18 PASS, 2 FAIL, 4 UNPROVEN | `VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)` blocks mature close and receipt redemption; one facet source unavailable; mature-close authorization masked |
| `evidence/other-sources/report.md` | Fresh public replay: 21 PASS, 4 FAIL, 3 UNPROVEN; two additional native LP exit failures | Earlier/weighted WETH SE disabled; earlier LP exact-in `UnsupportedRoute()` and native exit `NotOwner`; weighted LP exits `NotOwner`; historical Alchemy acquisition HTTP 429 |
| `evidence/provenance/report.md` | Deterministic reconciliation, all 15 declared source files readable; frozen CSV/JSON unchanged | Manifest drift confined to two later-amended Markdown reports; incomplete ancestry remains an evidence limitation, while funded C0 and final approved amounts are operational inputs |

Weighted `WEIGHTED_PROBE_PASS` and exit 0 certify the enumerated source
capabilities only: its FAIL and UNPROVEN rows remain in force. Earlier-CP
pinned custody succeeded even though current harvest exits revert
`VaultDisabled`. Other-sources has fresh custody evidence; its pinned acquisition
HTTP 429 is a harness gap, not proof that the source mechanism is incompatible.

The other-sources historical credential problem was resolved by its login-shell
retry; remaining throttling is an environmental gap, not missing credentials.
Its historical custody is still UNPROVEN. Its fresh-block custody evidence is
not silently relabeled historical. Earlier-CP's later historical retry did
succeed in executing the suite; prior provider failures remain preserved.

### Source anchors

These anchors refer to **deployed source text inside the producer archives**,
not merely similar current repository contracts:

* Weighted `probe.sources.json`, facet
  `0x1d17aca0e0717d90cea916372070a1be4652223f`,
  flattened `ERC20Facet.sol:2470-2477,2617-2623,2647-2657,2683-2694,3060-3077`:
  storage has balances and allowances; `transfer` reaches `_transfer`, which
  changes the two balances and emits `Transfer`. Its leaf balance operations
  have no external Migration callback. `transferFrom` also spends allowance.
* Weighted `deployed-source-extracts.json`, deployed
  `DETFFundedBondTarget.sol:127-140,163-200,210-242`: current NFT identity and
  position are readable; claims update principal/gons and pay receipts;
  retirement deletes the position and burns. Authorization includes approved
  operators and recipient redirection, so approval alone is not beneficiary
  authentication.
* The same archive, `StakedDETFTarget.sol:104-124,187-214` and
  `DETFFundedStakingRepo.sol:109-161`: transfers use current-index gons;
  stake/unstake change representation, and full-account unstake retires final
  fractional gons. These are not ETH/DTF contribution or C0 ledgers.
* The same archive, `DETFSYTarget.sol:94-134,225-253`: redemption burns shares,
  debits backing gons, accounts for conversion dust and pays/unstakes receipts.
  Wrapper shares and backing cannot both earn an award.
* Earlier `probe-alchemy-retry.source.json`,
  `RebasingClaimTokenFacet.sol:9859-9878,10125-10148`: external shares lose
  internal precision; a transfer converts native amount to internal shares
  at the current redemption rate. Its emitted native amount does not directly
  equal an exact displayed-balance delta.
* That earlier archive,
  `UniswapV4SingleStandardExchangeDETFFacet.sol:25419-25447` and
  `DETFNFTVaultFacet.sol:16377-16404`: mature sale creates a receipt descendant;
  retirement reads original LP shares, removes the position and burns.

Weighted proxy bytecode alone is insufficient: diamonds share it. The witness
checks chain 4663, block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
both DETF `transfer(address,uint256)` bindings, and the bound facet bytes against
the archived deployed bytes. The producer labels this generic facet `match`,
not `exact_match`; metadata equality is not invented. Source-service
recompilation and provider canonical-chain reporting remain evidence trust
assumptions, not a deployed onchain light client.

For other sources, source-equivalent implementation is not independently
verified by its producer. Its mined operation receipts support the stated
mechanical behavior. Current `TokenStakingTarget.sol:184-209,289-306` and
`RebasingAwareERC4626Target.sol:97-110` explain reassignment, weight consumption
and redemption but are not promoted to authenticated legacy code.

## 3. Minimal distinguishability witness

Assume one authenticated initial attribution checkpoint, already stronger than
the incomplete incident inputs. Alice and Bob each hold 100 native units of the
same ordinary legacy token. Their already quoted credits are 1000 and 3000.
These are synthetic valid unequal-credit inputs, not computed user allocations
or an assertion that the fork donor purchased at those prices. The approved
nonlinear original-contribution quote imposes no uniform-credit-per-token rule.

Apply plan section 5.4: a partial transfer moves
`floor(senderCredit * amount / senderUnits)`; its remainder stays with sender.
Receiver adds already quoted credit without requoting.

| History | Ordinary transfers after the checkpoint | Final balances | Required credits |
| --- | --- | --- | --- |
| H1 | Alice sends Bob 50; Bob sends Alice 50 | Alice 100, Bob 100 | Alice 1666, Bob 2334 |
| H2 | Bob sends Alice 25; Alice sends Bob 25 | Alice 100, Bob 100 | Alice 1400, Bob 2600 |

H1: first credit transfer is 500; second is
`floor(3500 * 50 / 150) = 1166`. H2: first is 750; second is
`floor(1750 * 25 / 125) = 350`. Each preserves total credit 4000.
Even exact rational arithmetic distinguishes these histories; this is not
merely a one-unit rounding trick.

The fork witness obtains the two 100-unit holdings by actual transfers from a
real source holder. It never edits source token storage/code or mints fake
tokens. Snapshot-isolated histories execute against the unchanged deployed
weighted DETF. It compares donor/Alice/Bob balances, total supply and reciprocal
allowances, and archives every mined receipt. The histories have different
logs, as expected. It does **not** assert identical block hashes, receipt roots,
gas balances, or whole-chain states. The equality is exactly the queried
token-state information available to a balance-based attribution adapter.

Let an adapter use a frozen initial attribution table, its own unchanged
consumption state, and those current token observations. Neither history calls
the adapter. The adapter therefore has identical entitlement inputs for H1 and
H2 and must return the same answer for an identical surrender request. The
required answers differ. Thus at least one answer is wrong. A global credit
ceiling or address nullifier cannot restore the missing information.

The stronger positive/zero-credit mixture is also modeled: initial credits
1000/0 produce Alice 666 in H1 and 800 in H2. A zero-credit lot still contributes
physical units to the mixing denominator; ignoring it attributes too much
credit to a partial transfer. An actual baseline must authenticate which units
are eligible, ineligible or unknown. Unknown ancestry is not zero.

The mathematical probe exhausts three-piece partitions with total units 1-12
and credit 0-12, asserting conservation and full-remainder closure. The explicit
7-unit/10-credit partial-consumption vector pays 1, 1, then 8. This tests the
arithmetic requirement, not an implemented Migration contract.

## 4. Required categories and cross-path consumption

| Required category | What can be read or moved | E2 status |
| --- | --- | --- |
| Weighted liquid DETF, 9 decimals | Native balances; actual ordinary transfers | FAIL for balance-only attribution: section 3 |
| Earlier liquid DETF, 18 decimals | Same generic transfer facet observed; producer custody PASS | Same interface blocker; acquisition history also incomplete |
| Weighted fixed-principal NFT | Current owner, original/claimed principal, gons; transfer/claim/burn demonstrated | Identity-local attribution feasible; integrated surrender/credit/bond still UNPROVEN |
| Earlier LP-lock NFT | Current owner, original LP accounting shares, lock, reward weight | Distinct model, no fabricated `claimedPrincipal`; producer custody succeeds, withdrawal blocked |
| Weighted sDETF | Native balances plus gons and funded index | Complete mixed contribution/credit ancestry UNPROVEN |
| Earlier receipt | Internal shares/rate conversion; rounded external shares | Complete ancestry UNPROVEN; holder/supply gap unresolved |
| SY | Static shares backed by receipt gons | One economic claim; full wrapper ancestry UNPROVEN |
| TokenStaking rights | Holder-only reassignment; staged weight consumption into SY | No operator pull/callback; integrated atomic issuance and attribution UNPROVEN |
| Claim-vault shares | 19-decimal shares redeem to SY | Mechanical custody/redemption PASS; allocation ancestry UNPROVEN |
| Underlying SE shares | Earlier 18-decimal, weighted WETH 18-decimal, weighted DTF custody 28-decimal | Do not omit; mixed ancestry UNPROVEN; first two exits fail, DTF custody redemption succeeds |
| Fungible LP tokens | Earlier and weighted 18-decimal shares, distinct from NFT locks | Do not omit; current-custodian exits fail; user ancestry UNPROVEN |

Infrastructure-holder impersonation in other-sources demonstrates token
mechanics, not that users can command those contracts to surrender backing.
Zero standalone-holder rows in the historical ledger do not prove absence.

For a fixed-principal NFT, retain the approved formula:
`C0 = U(ETH,E0) + U(DTF,D0)` on one frozen funded snapshot;
`award = floor(C0 * remainingPrincipal / originalPrincipal)`.
Original principal zero, nonexistent/burned NFT, or remaining principal zero
is ineligible. Still-locked principal is remaining principal. Reward gons
must not enlarge it. No configuration premint occurs.

Whole-NFT surrender consumes the whole collection/token identity. With
`P0=100`, withdrawn principal 40, remaining 60 and `C0=1000`, its award is 600.
The unused 400 is **not automatically a descendant entitlement**. Paying 600
for the NFT, 400 newly inferred from a claimed receipt, and 1000 as an
independent payer allocation double pays the origin (2000 total). The witness
records this rejected accounting. It does not authorize the 400.

Conversely, supported fungible categories cannot be discarded wholesale:
separately admitted original entitlements require their own disjoint provenance.
The ledger must distinguish that case from an NFT's already withdrawn principal
or reward-only descendant. Source-specific nullifiers without shared economic
origin identities do not prove disjointness.

For wrapping, consuming an attributed representation and issuing another must
move one credit, not create one. Crediting both a 901-credit wrapper position
and its 901-credit underlying reserve yields a false 1802. Claims, unstaking,
wrapper redemption, and staged harvest are transition edges, not new purchases.
A source balance cannot identify these edges by itself.

Partial surrender must atomically debit the attributable units and credit,
take custody, and create a **fresh 90-day cliff bond**. Zero-credit surrender
reverts before custody; full-remainder surrender receives the entire residual
credit. A failed source pull or bond creation reverts all effects. Pre-activation
corrections preserve already consumed/transferred units and delivered bonds;
they cannot recompute a retroactive `newTotal - paid` top-up. These requirements
remain binding but are not implemented by this evidence program.

## 5. Candidate mechanisms: exact rejection conditions

| Candidate | Producer/witness check | Verdict |
| --- | --- | --- |
| Frozen per-wallet credit plus current balance | Real transfer histories H1/H2 and generic transfer source | FAIL: identical inputs require unequal outputs |
| Original payer signs or remains beneficiary | NFT 26 transferred ownership; reassignment and ordinary transfers demonstrated | FAIL: violates current-owner rule; signature does not prove complete ancestry |
| Current gons, shares, or exchange rate | Weighted gons/SY and earlier rounded receipt conversions | FAIL as sufficient proof: fixes units, not mixed original credit |
| Frozen Merkle root with user-supplied later logs | Same source emits distinct histories but no Migration callback | FAIL without authenticated complete replay; root authenticates only its committed boundary |
| Selected canonical receipt inclusion proofs | Omitted incoming/outgoing transfer can change mixture while restoring balances | FAIL as sufficient proof: inclusion alone does not prove no omitted transitions |
| RPC balances/storage proofs or archived JSON | Producer RPC observations and section 3 | FAIL as an onchain ancestry mechanism; endpoint assertions are not verifier state |
| Per-source consumption/nullifier map | NFT claim, wrapper, TokenStaking conversion probes | FAIL alone: stops exact replay, not correlated cross-path double credit |
| Mutable owner root/fresh trusted signature | Activation freezes configuration and removes authority | FAIL by approved constraint |
| New mandatory transfer wrapper/hook | Unmodified legacy transfer has no such callback | FAIL by approved constraint |
| Immutable permissionless history verifier | No authenticated implemented construction supplied; scoped source search found no receipt/history verifier in Migration task code or product contracts | UNPROVEN, not a speculative PASS; separate scope/owner decision required |

An immutable verifier whose state advances permissionlessly is not equivalent
to a mutable **trusted** owner root, and is not rejected merely for advancing
state. It fails this acceptance gate because no concrete admissible verifier,
proof producer and bounded canonical-chain procedure has been established.
The local source search is supporting evidence, not a universal absence proof.

## 6. Data/proof contract that remains unsatisfied

No executable fungible surrender ABI is finalized here. The plan's conceptual
`required verified provenance data` argument has no demonstrated verifier.
Returning true from a placeholder would change the trust model.

A passing construction would have to bind all of the following together:

1. **Domain and immutable configuration:** chain ID, Migration proxy, source
   identity/kind, verified implementation/selector semantics, funded snapshot
   identity, original entitlement identity and ETH/DTF quote-unit grouping.
2. **Authenticated baseline:** original native units, both contribution
   components and C0 per original entitlement; exact wrapper/receipt unit basis;
   excluded/unknown units; disjoint independent compensation set. Stage 1 owner
   configuration is permitted, but is not evidence of subsequent transfers.
3. **Execution state:** current normalized attributable units/components/credit,
   residuals, consumed NFT identities, consumed origin fractions, independent
   issuance, representation transitions and custody/bond records. Configuration
   replacement must not erase any execution record.
4. **Proof input:** authenticated complete ordered changes from that baseline
   through the relevant transfer/claim/wrap boundary, including merges, mints,
   burns, index changes, rewards, routing recipients and source-specific dust.
   Transaction and log indexes must prevent reordering/replay. Proving only
   selected events or a final balance is insufficient.
5. **Canonical anchor and freshness:** a concrete chain-authenticated commitment
   to the relevant block/receipt/state history, reorg/finality handling, and
   protection against further transfers between the proved endpoint and custody.
   A block hash in an offchain JSON file or operator-supplied header does not
   supply that onchain trust root. Same-block preceding transfers also matter.
6. **Bounded operation:** finite per-call verification and storage work with
   deterministic continuation if needed, without truncating history or imposing
   an unapproved migration expiry. No required third party may approve future
   users. Long offline periods and growing transfer histories need an actual
   supported procedure, not an assumption that someone continuously checkpoints.

Neither receipt-inclusion proofs alone nor a new light-client name satisfies
items 4-6. No approved implementation, gas bound, deployed anchor or operational
availability argument was demonstrated. Filling this gap is a concrete separate
construction decision; this unit does not select a trust relaxation.

## 7. Mechanism blockers, evidence gaps and operational inputs

The structural blocker persists even assuming perfect source availability,
complete initial contribution records and a valid funded quote. Removing HTTP
429 or repairing a source archive does not make current balances encode history.

Evidence limitations are separately retained: other-sources historical RPC
throttling; the earlier missing verified facet; unknown native ETH; incomplete
holder/acquisition census; and the earlier receipt discrepancy. The manifest
drift is confined to later-amended `CUSTODY_AND_HARVEST.md` and
`LOSS_AND_RECOVERY_LEDGER.md`; frozen CSV/JSON evidence remains unchanged.
These findings do not each create a new owner-policy question.

A funded C0 snapshot is expected only after funding. Final approved allocation
amounts are also operational inputs. Their absence at this phase is not, by
itself, a new product blocker and is not the basis for the E2 verdict. The
eventual records must still satisfy the existing disjointness and provenance
requirements; this report neither approves amounts nor invents a new approval
policy.

Disabled vaults and owner-only LP exits remain concrete failures of the tested
harvest routes, not RPC errors or proofs of E2 impossibility. The plan permits
staged harvesting, so an unavailable present harvest is not automatically an
impossible atomic surrender or a demand for a new owner decision. Conversely,
successful source custody does not close E1's atomic source-to-Migration
handoff: the producer fixtures did not execute integrated entitlement
consumption and fresh funded bond creation. That integration remains UNPROVEN,
not proven impossible by these probes.

All accepted categories remain required. Their unsupported rows are FAIL or
UNPROVEN, never supported merely because an address or selector exists.

## 8. Reproduction and evidence contract

`evidence/attribution/invocations.md` records literal commands and binary PASS
observables before execution. `witness.mjs` is the owned evidence-only runner.
Its results retain raw RPC responses, source identity, transaction receipts,
arithmetic vectors, producer checks, source excerpts and input fingerprints.
The original harness arithmetic failure is preserved separately rather than
rewritten as successful evidence. Execution and cleanup receipts accompany this
specification; they distinguish counterexample success from E2 failure.

No product contract, PRD, plan, other lane, original incident input, linked
library, dependency, or root orchestration state is edited. No Forge compile
is needed for ordinary transfers on existing deployed bytecode. No public
transaction, asset transfer, deployment, commit, push or delegation is performed.

## 9. Executed result

Final P1 invocation from `invocations.md`, with `WITNESS_RUN=witness-r3`, exited
**0** and printed **`ATTRIBUTION_COUNTEREXAMPLE_PASS`**. Runtime was Bun 1.4.2
at `/opt/homebrew/Cellar/bun/1.4.2/bin/bun`; executed script SHA-256 was
`6b2d4ffcb16f28a586124e9664226224fc7d8b87575a8f813584086a3a857ff7`.
No fresh-block fallback occurred. The pin's state root was
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.

Six local transactions succeeded: two seed transfers and four history
transfers. H1 transaction hashes begin `0x3056dd50` and `0x1a0c0084`; H2 hashes
begin `0x5fad593c` and `0x4055a901`. Full hashes, raw receipts and block identities
are in `witness-r3.results.json`. Both histories ended at donor balance
212255118, Alice 100, Bob 100, total supply 16868128524740 and reciprocal
allowances zero. Required credits differed as section 3 predicts. All **5902**
bounded arithmetic partitions conserved credit.

The base snapshot restored donor 212255318, Alice/Bob zero and unchanged
supply/allowances. Owned Anvil PID **68218** exited **0**; endpoint
`127.0.0.1:58263` then returned TCP `ECONNREFUSED`. All three cache environment
paths were recorded under the owned `attribution.cIEIBO` root.

The initial arithmetic-expectation failure and second-run fetch-error
classification failure remain in `witness.*` and `witness-r2.*`; the latter
already executed the counterexample successfully but exited 2 at cleanup
classification. Neither failure is hidden or treated as product evidence.
The first run's producer archive is `producer-audit.json`; later runs use
`witness-r2.producer-audit.json` and `witness-r3.producer-audit.json`.

`verify-cleanup.mjs` independently checks final source fingerprint, receipts,
producer verdict counts, all input fingerprints, both recorded node PIDs/ports,
and owned-root deletion; its durable receipt is `cleanup.json` with raw stdout
in `cleanup.stdout.log`. It makes no public RPC call. Fresh LSP diagnostics
timed out after 3000 ms; they are not claimed clean. Successful executable
runs provide syntax/runtime validation, not a static typecheck or a Migration
integration test.

**Decision:** retain the exact E2 blocker rather than substitute a trust model.
Current-interface impossibility is demonstrated; authenticated-history
construction and E1 atomic source-to-Migration handoff remain unproved.
Producer failures and environmental gaps remain preserved, without promoting
expected funding/allocation inputs or current harvest failures into automatic
new owner-policy questions.
