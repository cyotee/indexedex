# E2 freshness and observation contract

Date: 2026-11-11. Evidence-only observation lane.

## 1. Finite conclusion

**Complete attribution through a completed block is not, by itself, fresh
attribution at a later custody operation.** The missing interval includes
earlier transactions in the custody block and earlier calls in the custody
transaction. Restoring the holder's token balance during that interval does
not restore its prequoted credit.

The new witness executes ordinary transfers and an approved `transferFrom`
against the actual pinned weighted DETF. Two same-block prefixes leave the
same source-token inputs for the same custody pull, but require respectively
**500 and 833** credit under the accepted proportional rule. It is a
source-primitive and observation-boundary witness, **not** an implemented
Migration surrender, proof verifier, funded bond, or Nitro consensus test.
Full histories distinguish the branches. Even the complete custody receipts
differ: only their custody-event contents, not their entire receipt encodings,
are identical.

Consequently, the mechanism restricted to the observation model in section 6
cannot correctly accept both histories. A verifier admitting additional
authenticated history is not disproved by that result. For such a verifier,
the precise remaining obligation is:

> Authenticate a complete, correctly ordered attribution transition sequence
> through the actual pre-custody execution position, or authenticate an
> equivalent sufficient condition connecting its proved endpoint to that
> position. Then consume that state, take custody and fund the fresh bond
> atomically.

The examined pinned ArbSys interface authenticates a prior L2 block hash but
rejects the current L2 block number as a hash query. It does not thereby
authenticate a current execution-prefix receipt/state commitment. This is
not an exhaustive proof that every possible protocol capability or
cryptographic construction lacks such a commitment. The anchor lane owns the
broader canonicality, finality, retention and recovery capability assessment.

**Disposition:** finite freshness gap demonstrated for the explicitly bounded
model; an unchanged-policy complete E2 construction remains unproven here.
No source category, current-owner entitlement, atomicity requirement or
postactivation trust restriction is relaxed.

## 2. Inputs, identity and evidence classification

The following were read completely:

* `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase06-e2-brief.md`.
* `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`
  (MIG-P01-P15, E1-E5, sections 5.3-5.5 and all remaining sections).
* `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/attribution-spec.md`.
* The same phase01 migration directory's
  `evidence/phase01-verification.md`, including its narrower E1 interpretation
  and its historical other-sources acquisition correction.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2`.
Branch: `work/dtf-migration-phase-06-e2`.
HEAD: `5021e8d4a62bcbddc555f580ef98f8666d993aab`.
Initial tracked/untracked Git status was clean with
`--ignore-submodules=all`. Ordinary status failed because `lib/crane` is the
root-authorized symlink, not a materialized submodule; no link was repaired or
replaced. `lib/crane` and `node_modules` resolve to the main checkout.

Historical public pin: chain **4663**, L2 block **108944663**
(`0x67e5d17`), hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
There was no fresh-block fallback. Local descendants 108944664 and 108944665
are counterfactual Anvil blocks, not additional public-chain pins.

Evidence files in this directory:

| File | Role |
| --- | --- |
| `witness.mjs` | Executable real-source transfer/custody witness; no compilation or file writes |
| `runtime-evidence.json` | 105 raw RPC request/response records, public pin, routing/code binding, local receipts/prestate/call traces, assertions and snapshot cleanup |
| `protocol-sources.json` | Primary-source URLs and fetched-text fingerprints, two supplemental public RPC records, and actual Multicall opcode bytes |
| `invocations.md` | Exact execution method, replay procedure, observables and failures |
| `verification.json` | Final file/provenance, tracked-diff, syntax and resource checks |

**Observation** below means a recorded RPC result or executed local operation.
**Source interpretation** means the explicitly identified deployed archive or
upstream protocol text. **Inference/contract obligation** is identified as such.
RPC observations are research evidence under provider trust; an offchain JSON
response is never presented as an onchain proof.

## 3. Actual source and chain observation surfaces

### 3.1 Ordinary token reads and writes

Weighted DETF: `0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7`.
At the historical pin, `transfer`, `transferFrom`, `approve` and `balanceOf`
route to `0x1d17aca0e0717d90cea916372070a1be4652223f`, whose runtime Keccak-256 is
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
Public calls and the local fork independently returned that binding/hash.

The admitted deployed archive is phase01
`migration/evidence/weighted/probe.sources.json`, that facet's flattened
`ERC20Facet.sol`. Its generic runtime match remains **match**, not an invented
metadata-exact recompilation:

* Lines 2455, 2470-2477, 2500-2502 define the namespaced storage, including
  supply, balances and allowances.
* Lines 2617-2623 and 2647-2657 add/subtract balances.
* Lines 2683-2694 and 2706-2708 implement ordinary transfer with a `Transfer`
  emission and no recipient or Migration callback.
* Lines 2722-2727 and 2739-2741 spend allowance and then transfer.
* Lines 3060-3077 expose the two transfer entrypoints.

These source observations are corroborated by six local branch call traces:
each proxy call delegates to the pinned facet, with no further call to a
recipient or attribution verifier. The custody call reads the same four
touched token storage words in both branches: selector routing, Alice's
100-unit balance, the zero custody balance and Alice's 50-unit allowance.
`prestateTracer` shows these words immediately before the third transaction.
This is not a dump of every account's state.

A contract can authenticate a live `balanceOf` result by calling the actual
source in its execution context, subject to correctly bound source semantics.
The result says how many native token units exist there now; it does not
say which mixed prequoted credit those units carry. `allowance` authorizes
movement, not historical contribution attribution.

### 3.2 Pinned native-chain calls

Public `eth_call` at the exact historical block, with nonzero caller
`0x000000000000000000000000000000000000e603`, returned:

| Interface | Actual result | What it does not establish |
| --- | --- | --- |
| ArbSys `0x64`, `arbBlockNumber()` | 108944663 | A transaction/log index or prefix commitment |
| ArbSys `arbChainID()` | 4663 | Attribution or finality |
| ArbSys `arbOSVersion()` | 116 | Exact node source-build identity; the documented offset implies ArbOS 61 |
| ArbSys `arbBlockHash(108944662)` | `0x22205b831726e31a4aeaa054c3a9e527198d25e3e5ad234ed0e3d363ec6cd03e` | History completeness, current-block prefix or finalized status |
| ArbSys `arbBlockHash(108944663)` | `InvalidBlockNumber(108944663,108944663)`, selector `0xd5dc642d` | No successful current-block anchor |
| ArbSys `getStorageGasAvailable()` | 0 | A storage-change counter |
| ArbSys `sendMerkleTreeState()` | Revert, empty error data | No usable root for an ordinary nonzero Migration caller in this probe |
| ArbStatistics `0x6f`, `getStats()` | `(108944663,0,0,0,0,0)` | No observed transaction-receipt counter/digest |
| Existing Multicall3 `0xca11bde05977b3631167028862be2a173976ca11`, `getBlockNumber()` | 26367659 (`0x19256ab`) | Not L2 block 108944663 |

The pinned header's `l1BlockNumber` is also `0x19256ab`. Multicall's deployed
selector `0x42cbb15c` dispatches to offset `0x1d9`; recorded opcode bytes include
`NUMBER` followed by its return path. This establishes the numeric distinction
without deploying a helper or manufacturing an opcode response. The attempted
public `debug_traceCall` was rejected by the provider's Free-tier policy
(HTTP 400); it is retained as a failed optional diagnostic, not successful
trace evidence.

Primary Offchain Labs `ArbSys.go`, functions `ArbBlockHash`,
`GetStorageGasAvailable` and `SendMerkleTreeState`, explains the observed
checks. The last method is an outbox accumulator export with a zero-caller
restriction in that source, not an ERC-20 transfer-history commitment.
The upstream interface inventory also exposes account balance/code and gas
pricing/statistics surfaces; it does not supply a prefix verifier merely by
naming those surfaces. Only the calls in the table are runtime claims.

The upstream docs are versioned-by-fetch references, not proof that the
historical chain ran byte-for-byte that upstream build. In particular,
ArbStatistics' deprecated interface prose is not substituted for its actual
returned tuple. Do not treat an Anvil fork's precompiles, `NUMBER` or
`BLOCKHASH` as Nitro behavior: all native-interface observations above were
made against the public pinned chain, not the local fork.

The ArbSys documented 256-block historical window is specific to that
interface. It is **not** asserted to be every available history-retention
window: current Arbitrum documentation also describes a modified EIP-2935
history contract. Its deployment, usable window, trust and long-offline
recovery are anchor-lane questions, not silently ruled out here.

## 4. Executed distinguishing witness

### 4.1 Setup and scope

The real historical EOA holder
`0x082cb14f04d9c485473dedc00d604d7e9abca303` sends 100 native units each to
Alice (`...e601`) and Bob (`...e602`). Alice approves spender `...e603` for
50. Custody is `...e604`. All five addresses had empty code; no infrastructure
contract or SUT was impersonated. The four sending EOAs were unlocked only
on the isolated fork and given native gas funds. Source code/storage/token
balances were never patched or minted.

Those three setup transactions succeed in local block 108944664, creating a
common parent with hash
`0x3264ed836bc8ab016903b89fbf7858031ef8055d60479407a14e9e90f08b11ba`.
Manual mining with FIFO ordering then places exactly three transactions in
each snapshot-isolated branch at local block 108944665. Receipts prove
transaction indexes 0, 1, 2 and a common block hash within each branch.

The attribution baseline is deliberately synthetic: Alice has 1000 credit
and Bob 3000, each on 100 units. These are admissible unequal prequoted credits
for an information witness, not actual allocations inferred for the donor.
Baseline completeness is assumed in order to isolate freshness.

| Position | Control branch | Mixing branch |
| --- | --- | --- |
| 0 | Alice transfers 50 to herself | Alice transfers 50 to Bob |
| 1 | Bob transfers 50 to himself | Bob transfers 50 to Alice |
| Immediately before position 2 | Alice 100 units / 1000 credit; Bob 100 / 3000 | Alice 100 units / 1666 credit; Bob 100 / 2334 |
| 2 | Spender pulls Alice's 50 into custody | Identical spender, source, calldata and amount |
| Required credit on that pull | `floor(1000*50/100) = 500` | `floor(1666*50/100) = 833` |
| Final token balances | Alice 50, Bob 100, custody 50 | Alice 50, Bob 100, custody 50 |

Self-transfers are identity transitions for ownership/credit: debiting and
crediting the same holder does not create a second holding. In the mixing
branch Alice first moves 500 credit, then receives
`floor(3500*50/150) = 1166`. Her remaining 1666 is divided into 833 custody
credit and 833 remainder. Bob retains 2334. Both branches conserve 4000.

The new fact beyond phase01 H1/H2 is **same-block balance restoration directly
before an identical approved custody pull**, with real prestate and call
traces at that pull. Phase01 H1/H2 remains evidence of its actual balance-only
conclusion and is not rerun or promoted into a cryptographic impossibility
proof.

### 4.2 What is equal and what is not

Both branches have the same setup parent, local height, chosen timestamp,
custody transaction hash
`0xae90991d183530b0aa29d41273eeaaa834145ef4bb8d80b9adc11062648aec75`,
custody-call gas used 60304, touched pre-custody token storage, final
donor/Alice/Bob/custody balances, supply and remaining allowance.
The custody `Transfer` event's address/topics/data agree.

The branches have **different** preceding transfer logs, transaction roots,
receipt roots, block hashes and native gas effects. The control block hash is
`0xf342a80036fee3573a31ee7bb2d31ed8545c8e7c0db6861049de5bbdd5450fb3`;
the mixing block hash is
`0x8a16c12b9b9dc84b01252bafc74815b9970af867a6d89b749239b2c7fb3ddafa`.
Custody receipt cumulative gas is **125872 versus 141072**.
Thus a complete authenticated custody receipt can distinguish this pair's
cumulative-gas field. No equality of whole receipts, native-account balances,
global state roots or block commitments is claimed.

All nine local transactions succeeded: three setup and six branch
transactions. The witness's assertions passed in the resident Bun 1.4.4
kernel. Both branch snapshots and the original source snapshot were reverted;
donor balance returned to 212255318 and the three recipient balances to zero.
No actual Migration credit was minted. No bond, atomic issuance rollback or
live Nitro sequencing policy was exercised.

## 5. The observation contract

Let `b` be the authenticated baseline, `p` the endpoint of a complete verified
attribution replay, and `c-` the instant immediately before custody consumes
the surrendered holding. An execution position identifies the chain, block,
transaction order, and relevant within-transaction transition order; block
height alone is insufficient.

Let `L(p)` include attributable native/source-normalized units, original
components, prequoted credit, residuals, representation/origin identities,
prior consumption and issuance. The required value is:

```text
L(c-) = Replay(L(b), complete relevant ordered transitions in (b, c-])
award = residual credit                           if q is the whole holding
award = floor(current credit * q / current units) otherwise
```

For the liquid-token witness, current units equal its native balance. For
other source types, their source-specific eligible/unknown/zero-credit unit
classification and normalization remain required. An unclassified unit is
not silently a zero-credit unit.

### 5.1 What each observation can establish

| Observation available to a proposed verifier | Finite conclusion | Still required |
| --- | --- | --- |
| Actual source call for balances, shares, gons, rate, allowance or owner | Current source quantity/authorization under the bound implementation | Contribution mixing, eligibility and residual credit |
| Stage1 authenticated ledger and unchanged verifier consumption state | Baseline ownership/credit and this verifier's recorded consumptions | Ordinary legacy transitions that never called it |
| Canonically authenticated historical state root plus account/storage proofs | Values at that state boundary | Correct ancestry and changes after it; token-state equality is not history equality |
| Canonically authenticated header/receipt root plus selected receipt inclusion | Those receipt bytes occur at their verified trie positions | Exhaustiveness of relevant transitions, ordering across the entire interval and causally necessary incoming provenance |
| Complete authenticated ordered receipts with adequate source semantics | All emitted transitions in the covered interval; this distinguishes the witness histories once covered | Semantics for transitions not fully described by logs; baseline, causal dependencies and freshness at custody |
| Sound complete execution proof anchored to canonical history | Whatever executed-state/history relation its circuit actually proves | Explicit domain, circuit completeness, endpoint binding, bounds and current-custody connection |
| Live source custody delta and successful pull | Actual token units moved in this operation | Correct historical credit on those units |
| Hypothetical chain-authenticated current prefix commitment | Could bind proof to the actual prefix, if its semantics and access permit | No such usable construction is established by this lane |

Receipts are not directly readable by a contract merely because they exist.
The Solidity primary documentation distinguishes emitted logs from externally
provided proofs. The go-ethereum receipt definition separates consensus
receipt contents from RPC-added inclusion fields. A verifier must authenticate
the root/header and the receipt's trie index, not trust RPC `blockHash`,
`transactionIndex` or a JSON `logIndex` field by itself. This report implements
neither a receipt encoder nor an onchain proof verifier; its Anvil roots are
recorded node outputs, not constructed Merkle proofs.

**Complete history is a semantic requirement, not necessarily a demand to
upload every unrelated transaction.** Full receipt-trie reconstruction,
complete execution verification, or authenticated exclusion of irrelevant
regions could meet it if correctly constructed. Selected inclusion alone
does not certify exclusion. For example, even all Alice-related transfers are
insufficient if Bob's omitted incoming mixture determines the credit he
subsequently sends Alice. A sparse/recursive scheme must close that causal
dependency, not merely match Alice's ending balance.

### 5.2 Freshness at custody

For `p < c-`, a proof of `L(p)` needs a verified bridge across `(p,c-]`.
The bridge must cover all credit-changing transfers, mints/burns, claims,
wrap/unwrap conversions, index/reward/dust effects and relevant source
implementation changes. A proof that current balances equal balances at `p`
is not that bridge; the witness makes the gap concrete.

The bridge may be a complete authenticated suffix proof or another proven
sufficient condition. A non-resettable transfer/version counter could help
detect a suffix, but no such counter is written by this pinned ordinary
transfer path. A counter alone would still not reconstruct its mixed credit.
An EOA nonce is not a token-transfer history: incoming transfers and nested
calls also matter. No new counter/hook is introduced here.

A timestamp, deadline, "latest" RPC tag, or recent historical block number
does not prove absence of intervening transitions. The current L2 block
number identifies a block, not its prefix. Permissionless advancement of the
verifier to yesterday's or the preceding block's state is legitimate in
principle, but does not exempt the remaining suffix from verification.

### 5.3 Same-block and same-transaction ordering

If custody runs in transaction `j` of block `B`, a proof ending at `B-1`
must cover relevant effects of transactions `0..j-1`. The witness demonstrates
that this requirement persists when their aggregate token-balance change is
zero. A completed header for `B` becomes useful to later execution, but the
examined `arbBlockHash` call cannot return `B` in execution context `B`.
An RPC-supplied prospective header or prefix is not made canonical merely by
checking its internal hashes or verifying execution under that supplied root.

Earlier calls within transaction `j` also count. A smart-account/batch caller
could transfer before entering Migration; a proof tied only to transaction
start would then need a verified suffix through those calls. That scenario
was not executed here and is a derived contract obligation, not another
claimed runtime witness.

After entry, other top-level transactions do not interleave with the running
operation, but source calls, callbacks and later bond-funding calls still
need an audited reentrancy/transition discipline. The witnessed ordinary
token path makes no recipient callback. That local fact is not generalized
to every legacy representation.

### 5.4 Atomicity, subsequent transfers and continuation

At the eventual implementation boundary, verified current attribution,
positive proportional credit, authorization, custody, permanent consumption
and exact fresh-bond funding must succeed or revert together. A balance read
can establish source availability at that instant, not the credit proof.
An approval can precede surrender because it moves no custody; it is not
an escrow workaround.

After successful surrender, later ordinary transfers of the holder's
remaining legacy units move only the **post-consumption residual** credit.
A replay must integrate Migration's consumption at its exact execution order.
It must not replay the custody `Transfer` as a fresh independent entitlement
of the custody address, resurrect an old proof, or pay again on later
harvest/representation changes. A subsequent holder may require a new suffix
proof. Partial surrender and a later transfer cannot reuse the original
unconsumed denominator/credit.

Bounded continuation can accumulate authenticated progress over a long
history without custody. Each progress step must bind the prior accepted
checkpoint, exact next interval, configuration revision and economic-origin
state. The last step still has to close freshness to `c-`. A user waiting
offline for years cannot be assumed to have continuously refreshed an
anchor, and continuously advancing history does not guarantee catch-up or
data availability. Retention, reorg handling, proof-generation availability
and a finite per-call verification/storage bound need a concrete construction;
none was benchmarked or discharged by this small witness.

## 6. Exact impossibility scope and excluded capabilities

Define model **O** as an adapter whose entitlement inputs are:

1. The same authenticated baseline and immutable source/snapshot configuration.
2. Its unchanged internal attribution/consumption state, plus authenticated
   history ending no later than the common setup parent.
3. The current source-token balances/supply/allowance, source identity, same
   surrender owner/quantity, same relevant block-height/time context, and
   custody success/delta.

Ordinary prefix transfers do not call or update that adapter. There is no
authenticated current-prefix/suffix proof among O's inputs.

**Inference from source and witness:** the two histories give identical O
inputs but unequal required awards. Any deterministic award decision using
only O must therefore be wrong for at least one branch if it accepts both.
Rejecting both avoids a false award but does not meet the required general
current-holder surrender behavior. This is the only impossibility claim made.
The custody fixture has an EOA spender; applying the inference to a Migration
contract uses the inspected source transferFrom semantics and does not claim
that this fixture implemented Migration.

The model explicitly excludes:

* Complete authenticated history covering these prefixes. It distinguishes
  them; it is not disproved.
* A sound proof tied to an accessible canonical current-prefix commitment,
  or another stronger live-state/history-binding primitive. Its availability
  and construction are not established or universally denied.
* Arbitrary global account-state observations, gas/fee side channels and all
  possible native interfaces. Native gas balances and cumulative gas already
  differ in this witness. No all-EVM-state indistinguishability claim is made.
* An exhaustive historical node-build/native-interface audit, proof-system
  security proof, finality/reorg implementation, receipt-trie reconstruction,
  sequencer ordering guarantee and large-history gas/prover benchmark.

Selected receipt inclusion warrants special care: the example proves that a
selected custody **event** and current token state do not recover the missing
mix. It does **not** prove two identical complete receipt proofs can require
different awards. Inclusion alone has a separate logical incompleteness
unless accompanied by an authenticated coverage/exclusion relation. A root
committing the entire block could support such a stronger relation; merely
naming a SNARK or submitting a selected branch does not implement it.

No two-step escrow, mandatory wrapper, trusted postactivation signer/root,
original-payer restriction, expiry or owner approval is adopted. No owner
decision is needed to state this finite boundary. If a downstream construction
requires such a change, it must name the exact requirement pair and return
that decision rather than treating this report as permission.

## 7. Six-obligation handoff

This is a contract for the construction lane, not E2 closure:

| Attribution-spec section 6 item | Observation-lane disposition |
| --- | --- |
| 1. Domain/configuration | Real source pin/routing demonstrated; full verifier domain binding not implemented |
| 2. Baseline | Assumed complete synthetic baseline for the witness; actual incident unknowns remain unknown |
| 3. Execution state | Source custody primitive observed; residual/consumption model specified, not deployed |
| 4. Complete ordered proof input | Histories distinguishable; no full onchain history proof implemented |
| 5. Canonical anchor and custody freshness | Specific prior/current ArbSys distinction observed; O's suffix gap demonstrated; stronger mechanism unproven |
| 6. Bounded operation and long offline periods | Finite witness only; no catch-up/retention/gas closure |

All categories remain binding: both liquid DETFs and NFT models, weighted
sDETF/earlier receipts, SY, TokenStaking and claim-vault rights, underlying
SE shares and fungible LPs. This witness uses only the weighted ordinary
liquid-token route. Phase01's actual gons/rounding, cross-representation,
TokenStaking caller and restricted-harvest findings remain intact.
The independent report's distinction between source prerequisites and future
Migration integration is preserved: missing future bond integration is not
retroactively labeled a failed task01 primitive.

## 8. Primary references, verification and cleanup

Primary source locators (fetched-text hashes are in `protocol-sources.json`):

* Offchain Labs `ArbSys.go`, `ArbBlockNumber`, `ArbBlockHash`,
  `GetStorageGasAvailable`, `SendMerkleTreeState`:
  `https://raw.githubusercontent.com/OffchainLabs/nitro/master/precompiles/ArbSys.go`.
* Offchain Labs native interfaces:
  `https://raw.githubusercontent.com/OffchainLabs/nitro-precompile-interfaces/main/ArbSys.sol`,
  and adjacent `ArbInfo.sol`, `ArbStatistics.sol`, `ArbGasInfo.sol`.
* Offchain Labs block-number/timing documentation:
  `https://docs.arbitrum.io/arbitrum-essentials/arbitrum-vs-ethereum/block-numbers-and-time`.
* Solidity's event-access/proof distinction:
  `https://raw.githubusercontent.com/ethereum/solidity/develop/docs/contracts/events.rst`.
* go-ethereum `Receipt`, `receiptRLP`, `DeriveFields`:
  `https://raw.githubusercontent.com/ethereum/go-ethereum/master/core/types/receipt.go`.
  This explains the general receipt distinction; no claim that this current
  Ethereum implementation is the pinned Nitro receipt codec is made.
* Multicall3 `getBlockNumber()`:
  `https://raw.githubusercontent.com/mds1/multicall3/main/src/Multicall3.sol`.
  Its relevant deployed opcode path is separately inspected above.
* Foundry manual mining and FIFO:
  `https://www.getfoundry.sh/anvil/mining`.

Runtime was owned port **18552** only. The monitored Anvil process was
terminated after restoring the original snapshot; its monitor reported exit
0, and a subsequent TCP connection returned `ECONNREFUSED`.
The owned `freshness/runtime/` directory was removed. No other node, port,
dependency tree or worktree was cleaned.

No Forge compilation, production/test edit, dependency/config change,
public transaction, commit or delegation occurred. The module contains no
SUT replacement or deployment. The missing Biome LSP was not installed;
no clean LSP diagnostic result is claimed. Raw failed optional trace and
Git-status diagnostics are retained rather than relabeled successful.

The finite stop condition is satisfied by this observation contract, the
executed distinguishing witness and its cleanup evidence. This does not close
E2, select a production API, authorize deployment, or prove that all
cryptographic constructions are impossible.
