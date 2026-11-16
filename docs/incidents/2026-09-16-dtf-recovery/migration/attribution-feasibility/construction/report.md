# E2 construction assessment

Date: 2026-11-11. **Disposition: unproven.**

## 1. Decision

No complete mechanism satisfying the unchanged E2 requirements is established
by the admitted capabilities. The decisive missing capability is **an
authenticated connection between a complete attribution proof's endpoint and
the actual pre-custody execution position**, including ordinary transfers
earlier in the same block and transaction. Neither a valid completed-block
receipt proof nor a valid execution proof under a caller-chosen prefix supplies
that connection.

This is a finite missing-capability result, not a request to choose a different
product and not a proof that every cryptographic construction is impossible.
The observed chain supplies useful canonical completed-L2-block anchors.
The complete recorded transfer histories can be distinguished and their
required credits computed. What remains unproved is how an immutable Migration
contract can authenticate **which complete history reaches its current call**
without a forbidden trusted updater, mandatory transfer wrapper, or earlier
irreversible custody transaction.

The strongest construction examined here is a permissionlessly advanced,
origin-aware history ledger, authenticated by native L2 header commitments,
followed by one atomic surrender. Sections 4-7 specify its producer inputs,
verifier obligations, continuation, and exact stopping point. It is not
presented as an installed verifier or production ABI. A proof-system name is
not substituted for any missing step.

There are additional unresolved requirements: source-complete representation
semantics, bounded executable continuation and historical-data recovery, and
the claimant-only TokenStaking atomic handoff. These are enumerated rather
than hidden behind the main freshness gap. **No owner policy decision is
justified by this unproven disposition.** In particular, no requirement is
selected for relaxation.

## 2. Authority, evidence and identity

The following were read completely:

- `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase06-e2-brief.md`.
- `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
  including MIG-P01-P15, E1-E5 and all acceptance rows.
- `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/attribution-spec.md`.
- That phase01 migration directory's `evidence/phase01-verification.md`.
- [Anchor contract](../anchors/contract.md) and
  [freshness contract](../freshness/contract.md), with their raw requests,
  results, source excerpts, calculations, witness and cleanup receipts.

For compact citations below:

- **P1** is the absolute phase01 migration directory above.
- **A** is [anchors/rpc.json](../anchors/rpc.json); R numbers are
  `requests[].request.id`, not array offsets.
- **AS** is [anchors/primary-sources.json](../anchors/primary-sources.json).
  Source line numbers refer to its original numbered excerpts.
- **F** is [freshness/runtime-evidence.json](../freshness/runtime-evidence.json).
  Record indexes are zero-based.
- **W** is [freshness/witness.mjs](../freshness/witness.mjs).
- **Audit** is [evidence.json](evidence.json), the construction lane's offline
  recomputation; [invocations.md](invocations.md) preserves its executable
  calculation and command outcomes.

| Identity | Value |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2` |
| Branch | `work/dtf-migration-phase-06-e2` |
| Verified HEAD | `5021e8d4a62bcbddc555f580ef98f8666d993aab` |
| Source chain | 4663 |
| Historical pin P | L2 108944663, `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Additional anchor-lane pin C | L2 111330887, `0x309c2f18fbdfc1ae225dd123693dfc66157dbce50640cc0ed040198fcfe5af42` |
| P's EVM NUMBER | 26367659; not its L2 number |
| Construction calculation runtime | Resident Bun 1.4.4 |

C is a separate observation, not a replacement for P. F's blocks 108944664
and 108944665 are counterfactual Anvil descendants of P, not public-chain
observations. No additional chain pin or local fork was acquired here.

HEAD and branch match. Ordinary Git status failed on the authorized
`lib/crane` symlink; `--ignore-submodules=all` succeeded and showed only the
existing untracked attribution-feasibility evidence. This lane did not begin
with an empty evidence directory and does not claim otherwise. `lib/crane`
and `node_modules` point to the main checkout; neither was modified.

Observation, source interpretation and inference are separated below.
Recorded RPC responses remain provider-dependent research evidence, not
onchain proofs. The independent phase01 report supersedes the older statement
that historical other-source custody was still unavailable: its metered
historical replay succeeded. Missing future Migration integration is not
retroactively treated as a failed source primitive.

## 3. Executable boundary evidence

### 3.1 What the chain actually authenticates

**Observed:** A R14-R18 establish ArbSys's preceding-256-L2-block window at P,
including rejection of P itself. R27-R38 establish the deployed history
contract's preceding-393168-L2-block window at P and C, again excluding the
executing block. R51's nested ordinary STATICCALL returns a real 32-byte parent
hash. R48's equivalent NodeInterface call returns zero bytes despite call
success; its RPC helper result is not a contract-callable anchor.

The history contract is `0x0000F90827F1C53a10cb7A02335B175320002935`.
Its query is exactly a 32-byte L2 number, without a selector. The same 133-byte
runtime at P/C hashes to
`0xceef1f6ad6c0cb7eb8fb15678abf11da3ce0d3a7c7106aa900c5930e556a43ff`.
This is the Arbitrum-specific implementation, not Ethereum's 8191-block
implementation. [A R20/R24/R27-R38/R51; AS
`go-ethereum/params/protocol_params.go:239-246`.]

**Source interpretation:** ArbSys rejects `requested >= current`.
The history system update writes the preceding block hash at start-block;
final transaction/receipt roots and end-state root are assembled after
execution. These surfaces do not expose the current ordered execution prefix.
The archive-reported Nitro source pin is
`70fa99a6e711f09eedd96a907290c3df0f3bcf7d`; its Geth submodule is
`5eee8f546e7602b7deeef7909f291bbebc77e233`. Version strings alone are not
runtime attestations. The exact history-code comparison and pinned interface
responses supply the narrower observed binding. [AS
`nitro/precompiles/ArbSys.go:35-69`,
`nitro/arbos/internal_tx.go:62-87`,
`nitro/arbos/block_processor.go:197-234,775-793,809-826`.]

**Independently recomputed:** the Audit reconstructs P, P-1 and C's header
hashes from raw fields, binds P-1 to R14, and reconstructs P's two-receipt root:

```text
0xed4030c56b19861b12d407133d34d67e86eb659431133713cbdc126ba9f35a17
```

The inputs include the actual internal receipt type `0x6a` and user receipt
type `0x02`. Trie keys are RLP transaction indexes, not transaction hashes.
Consensus receipt encoding does not independently authenticate RPC-added
`blockHash`, `transactionIndex` or `logIndex`. This two-leaf reconstruction is
not a general verifier. [A R3/R14/R42/R52/R54; AS
`go-ethereum/core/types/receipt.go:54-81,99-105,472-491`,
`go-ethereum/core/types/hashing.go:107-139`; Audit.]

### 3.2 Same-block boundary, using the existing real-source witness

F executes the unchanged weighted DETF
`0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7`, with transfer operations bound
to facet `0x1d17aca0e0717d90cea916372070a1be4652223f`, runtime hash
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
The source stores balances/allowances and emits transfers without updating a
Migration ledger. Its archived source match is `match`, not an invented
metadata-exact match. [F records 10-21; P1
`evidence/earlier-cp/probe-alchemy-retry.source.json`, that facet's
`ERC20Facet.sol:2470-2477,2683-2694,2722-2741`; F branch call traces.]

Assume a valid baseline: Alice and Bob each have 100 units carrying 1000 and
3000 prequoted credit. These are deliberately synthetic unequal credits, not
actual donor allocations. W's seed transfers and allowance establish the
actual source quantities. Each branch then mines three successful transactions
in one local block:

| Position | Control | Mixing |
| --- | --- | --- |
| 0 | Alice self-transfers 50 | Alice sends Bob 50, carrying 500 credit |
| 1 | Bob self-transfers 50 | Bob sends Alice 50, carrying `floor(3500*50/150)=1166` |
| Before custody | Alice has 100 units / 1000 credit | Alice has 100 units / 1666 credit |
| 2 | Approved pull of Alice's 50 units | Identical approved pull of Alice's 50 units |
| Required delivered credit | 500 | 833 |

**New offline cross-check, not another runtime probe:** the Audit reads raw
receipts F[62,64,63] and F[84,83,85], independently replays their actual
ordered `Transfer` contents and reconstructs both complete three-receipt tries.
It does not import W's arithmetic. The roots match the recorded blocks:

```text
control  0x9a8004d24a432c866ee94c38a5fc0e6e6303488e2e43bdb73f474d71982b3f77
mixing   0xffeba2de437b5e51d7e357b584fd669ca4bf0194e31df68d7493e3a7e996a3ae
```

Swapping the first two receipts fails each root comparison. Both replays
conserve 4000 credit. Their raw pre-custody source storage is equal. Their
custody event contents agree, but their **complete consensus custody receipts
do not**: cumulative gas is 125872 versus 141072. The full historical
commitments distinguish them. F's local fork headers contain zero state roots;
they are not evidence of globally equal real state or usable state proofs.
[F records 63/65/66/85/86/87; Audit.]

Thus this witness rules out **completed-parent attribution plus current
selected token observations** as a sufficient surrender condition. It does
not rule out a stronger authenticated history predicate. Nor does it establish
that identical whole receipts, global state, native gas balances or all
possible EVM observations require unequal credit.

No repeat fork was necessary: changing a donor, amount or port would not
answer the missing authentication question. Construction-owned port 18553
was not used. All 24 offline checks passed. They validate evidence and the
finite boundary, not E2 acceptance.

## 4. Candidate construction and its explicit proof contract

This section examines an immutable history machine, not a proposed public
API. The notation is internal mathematical notation only.

Let `D` bind chain 4663, Migration instance, snapshot identity, source kinds
and deployed selector/code semantics, original entitlement IDs and quote-unit
grouping. Let `L_b` be the Stage1 authenticated attribution state at boundary
`b`; let `e` identify an exact block hash, transaction position and
within-transaction transition position. Let `L_e` be the resulting state.

The machine would need to establish:

```text
CompleteCanonicalHistory(D, b, e, H)
L_e = ReplaySourceSemantics(D, L_b, H)
CurrentCustodyConnection(D, e, L_e, actual_call_position)
```

The third relation is the missing capability, not a function whose existence
this report assumes. The second is also not yet an implemented all-source
transition verifier. Only the small ordinary-transfer subset in section 3
has an executed replay here.

### 4.1 Actual inputs the producer would need

1. **Baseline material:** original native/source-normalized units, original
   ETH and DTF components, separately quoted C0, exact original entitlement
   identity, source/representation ownership, zero-credit and unknown units,
   wrapper backing relationships, and the disjoint independent-compensation
   set. The historical source pin is not the funded snapshot. Stage1
   configuration may authenticate these inputs; it cannot authenticate later
   transfers. Unknown ETH or ancestry cannot be replaced by zero.
2. **Canonical history material:** exact encoded L2 headers from an accessible
   native anchor back to the baseline; complete ordered transaction and receipt
   bytes, including system transactions and all source-relevant transitions;
   account/storage/code witnesses and execution inputs wherever events do not
   determine exact source-normalized changes.
3. **Attribution material:** every causally necessary incoming holding's prior
   mixture, all representation conversions, rewards/dust/index changes,
   prior Migration consumption and issuance, and Stage1 configuration
   revisions at their actual execution positions.
4. **Custody-boundary material:** a proof tied to a live, authenticated
   execution-prefix commitment or another demonstrated sufficient condition
   that closes the interval through the actual call. No such material is
   supplied by the observed interfaces.

Any party could assemble these inputs if available. Producer permissionlessness
does not make its input truthful. The verifier must reject a valid proof about
a different chain, instance, source, revision, snapshot or execution endpoint.

### 4.2 What the immutable verifier must check

**Baseline/domain:** freeze `D` and the accepted Stage1 baseline without erasing
execution state. Store/prove original quote-unit identities separately from
merged holdings: `C0 = U(ETH,E0) + U(DTF,D0)` is computed once; merging sums
credits, not original inputs for another nonlinear quote.

**Completeness/order:** authenticate every completed block's header to the
native anchor or a previously authenticated parent-link chain. For a full
receipt route, reconstruct the canonical trie over the complete indexed list;
a list with a deleted, inserted, reordered or duplicated receipt must not
match the root. A sparse route instead needs authenticated exclusion and
causal closure, not just inclusion for the surrendering address. Bob's earlier
incoming mixture may determine Alice's entitlement.

Receipt completeness alone is insufficient where exact effects require
internal shares, rates, dust or calls not fully represented in events.
An execution-proof route must authenticate the transactions and their order,
initial state/code, chain-version-specific execution, nested calls and source
semantics. An RPC trace is not authenticated by a receipts root. A circuit
proving merely that *some* supplied execution reaches selected balances is not
proof that the actual canonical prefix was that execution.

**Execution state and nonduplication:** maintain a shared economic-origin
partition, not just per-source nullifiers. Its state must include normalized
units, contribution components, already quoted credit and rounding residues;
consumed NFT identities; permanently consumed origin portions; independent
issuance; current representation and backing; and custody/bond delivery
records. Each accepted transition consumes its exact predecessor state once.
Concurrent submissions cannot both advance from the same spendable state.

The partial fungible rule remains:

```text
0 < q <= Q
award = C                 if q == Q
award = floor(C*q/Q)       otherwise
(Q,C) after = (Q-q,C-award)
```

Physical zero-credit units still affect mixing denominators; unknown units
are not known-zero units. Transfer of attributed components and credit,
merge, and whole-remainder dust must agree across every representation.
The complete partition/rounding implementation has not been supplied for all
sources; a Merkle root over an unspecified ledger would conceal that gap.

**Revision/consumption ordering:** a Stage1 replacement changes only the
allowed still-unconsumed partition. It cannot reset consumed units, transferred
portions, delivered bonds or earlier issuance. A checkpoint must bind the
configuration revision and execution state it extends. Once activated, there
is no trusted configuration/root/signature update. Proved permissionless
advancement is allowed, but only of states satisfying the immutable relation.

## 5. The exact point where the candidate cannot proceed

Suppose every obligation above has been implemented perfectly through block
`B-1`, and the owner has supplied a perfect baseline. Custody will execute in
transaction `j` of block `B`.

The verifier still needs relevant effects from transactions before `j` and
from earlier calls in `j`. The block number identifies neither that prefix
nor its end state. The tested anchors bind completed ancestors; they reject
`B`. Their old commitment plus the live token state is exactly the boundary
that section 3 defeats.

The candidate can therefore take none of these steps as a completed solution:

| Attempt | Exact failure |
| --- | --- |
| Use a proof ending at B-1 and compare balances | Both branches pass the selected-state comparison but need different awards. |
| Supply an execution proof for the purported current prefix | Proof soundness establishes the supplied computation; a separate authenticated binding to the actual prefix remains absent. |
| Submit the future completed B header/root during B | No observed interface authenticates it then; internal hash consistency is not canonical selection. |
| Advance the ledger in an earlier transaction | Ordinary transfers may follow that update, including in the same block; the same suffix obligation reappears. |
| Wait for B to complete before pulling custody | Custody then occurs later and needs a fresh connection to that later call. |
| Pull custody now and credit after B completes | Breaks MIG-P06's single-operation rollback and creates a two-transaction surrender. |
| Require an offchain bundle, fresh signature or sequencer promise | No demonstrated contract-enforced prefix binding; cannot add a trusted postactivation approver. |
| Reject every call that might have an unproved suffix | Avoids a wrong award but does not establish the required current-holder migration behavior. |

**Bounded contradiction:** under freshness model O, a deterministic adapter
receives the same baseline, unchanged internal consumption state, completed
parent history, selected live token observations and identical custody
request. It must decide the same award in both branches. MIG-P02/P15 and
plan section 5.4 require 500 versus 833. Accepting both cannot be correct.
Rejecting both does not establish general surrender support.

This contradiction uses O's restricted observation assumption; that assumption
is not itself a product requirement. It therefore does **not** establish an
inherent conflict among the unchanged requirements. Arbitrary global
observations, a proven stronger live-state/history predicate, or an additional
already deployed protocol capability are not exhausted by O. No minimum owner
policy change can honestly be inferred from this finite witness.

### 5.1 Atomic ordering if the missing connection were supplied

A successful final operation would have to:

1. Enter a shared reentrancy/transition guard; bind current owner, exact source,
   amount, minimum credit, snapshot/revision and current unconsumed state.
2. Authenticate complete attribution through the actual pre-custody position,
   including any source synchronization needed to determine the quantity.
   Synchronization cannot silently introduce an unproved transition.
3. Compute positive proportional credit and reserve/debit its origin partition
   before any callback can spend it again.
4. Perform the typed source custody/extinguishment call and measure exact
   source-normalized receipt, not merely an assumed native-unit amount.
5. Mint exactly delivered principal and create/fund a fresh bond for the
   surrendering owner; start that bond's own 90-day clock at creation.
   Settle prior participation as required by the existing funding contract.
6. Commit consumption, residuals, custody and bond identity together. Any
   failed pull, short receipt, wrong owner, zero award, callback, funding or
   bond creation must revert the whole operation.

No top-level transaction interleaves inside that operation, but callbacks and
source synchronization still require protection. Later history replay must
recognize this operation as consumption, not award its custody transfer again
to Migration or revive its credit during harvest. Partial surrender followed
by an ordinary transfer carries only the post-consumption residual.

These are the required ordering constraints, **not executed Migration
integration evidence**. Step 2 is currently unproved, and source-specific
step 4 is not generic for TokenStaking.

## 6. Source-specific transitions: all categories retained

The producer/verifier relation must cover every row below. The table does not
declare these adapters implemented. Native units, claims and backing cannot be
collapsed into a generic ERC-20 balance relation.

| Category and identity | Required source-specific proof/consumption semantics | Evidence and remaining limit |
| --- | --- | --- |
| Weighted liquid DETF `0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7` | Native 9-decimal transfers, mint/burn cause and recipient, mixed credit, partial custody and residuals | Actual facet/routing and same-block witness in section 3. Freshness unresolved. |
| Earlier liquid DETF `0xaf0e1967c8f755c747615c5427108bc549ca1122` | Separate 18-decimal ledger and original origins; do not mix units with weighted DETF | P1 earlier archive binds the generic ERC20 facet; custody is demonstrated in P1 verification. Complete ancestry/freshness unresolved. |
| Weighted NFT `0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e` | Current owner, original fixed principal, actual claimed principal; exclude rewards; award `floor(C0*remaining/original)`; consume whole collection/ID | P1 weighted deployed excerpts, `DETFFundedBondTarget.sol:127-140,163-200,210-242`. Claimed receipt descendants do not automatically receive the withheld credit. Approved operators can redirect legacy claims, so current owner/recipient binding is essential. |
| Earlier NFT `0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391` | Original LP accounting shares, current identity and sale/burn; no invented fixed-principal `claimedPrincipal` | Earlier deployed `DETFNFTVaultFacet.sol:16377-16404`, `UniswapV4SingleStandardExchangeDETFFacet.sol:25419-25447`. Reward weight is not original LP shares. Source-specific remaining-unit model required. |
| Weighted sDETF `0x4fa4974a8a09660258b8edd430b51c1620ebfe5c` | Replay gons and funded index at each transition; separate rewards, principal, stake/unstake and final fractional retirement | Weighted `StakedDETFTarget.sol:104-124,187-214`, `DETFFundedStakingRepo.sol:109-161`. Native Transfer logs alone do not supply every normalized effect. |
| Earlier receipt `0x4ac89ad061a531fa62ddceed53520c2750113b01` | Exact internal shares and contemporaneous redemption rate, not rounded external shares or displayed balance deltas | Earlier `RebasingClaimTokenFacet.sol:9859-9878,10125-10148`; archived source match is `match`. P1 verification records a native `10^18` transfer displaying `999999999999999999`. |
| Weighted SY `0xb55604cf4dcdabb362078e106d20f98512391edf` | Share burn/mint, backing gons, conversion dust, actual output and recipient; move one credit across representations | Weighted `DETFSYTarget.sol:94-134,225-253`. Wrapper and underlying reserve cannot both own the same credit. |
| TokenStaking `0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00` | DTF-denominated claim weight, reassignment, phase, weight-to-vault-share conversion, actual SY receipt, extinction and recipient | P1 `evidence/verification/tokenstaking-caller.json`: ordinary forwarding pull reverts `InsufficientStake(helper,q,0)`; direct holder reassignment makes no receiver callback. Tested permit/ERC20/multicall selectors are unbound. Atomic claimant-context execution remains unproved. |
| Claim-vault shares `0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0` | Distinct 19-decimal shares backed by 9-decimal SY; link weight consumption and share redemption without duplicate credit | P1 `evidence/verification/other-metered.json`, `sourceObservations` and named custody/harvest cases. Infrastructure holdings are not proof of an end user's command authority. |
| Earlier SE `0xb7d4bb379d361ad442cddee53ea71a33957826a7` | 18-decimal shares, original acquisition and conversion ancestry | Same historical raw evidence: custody/rollback demonstrated; tested exits disabled. Ancestry unresolved. |
| Weighted WETH-leg SE `0x999dae02d22e5fee1c4508430d5196d31d631009` | Separate 18-decimal shares and ancestry; do not count backing twice | Same historical evidence: custody/rollback demonstrated; tested exits disabled. |
| Weighted DTF custody SE `0x2e9c1f705ab967c5af59249203d7495bdabb223b` | 28-decimal shares, conversion into 18-decimal DTF, precise rounding and origin | Same historical evidence: custody/redemption demonstrated; user exposure/ancestry not thereby proved. |
| Earlier fungible LP `0x923877336b14662cfb5b3a60b14e7d716d54a888` | 18-decimal fungible LP, distinct from the NFT lock; joins/exits and backing-origin partition | Same historical custody evidence; P1 verification preserves `UnsupportedRoute`/`NotOwner` exit failures. |
| Weighted fungible LP `0x46e068c2393e189fbc86632f67210af253a42aa8` | Separate 18-decimal LP; source joins/exits and current holder ancestry | Historical custody demonstrated; tested new-custodian exits are owner-restricted. No source-owner impersonation is a user route. |

The weighted source excerpts are in P1
`evidence/weighted/deployed-source-extracts.json`; earlier flattened sources
are in `evidence/earlier-cp/probe-alchemy-retry.source.json`. These are
deployed archives, not substitute current repository implementations.
Some source archives remain missing; executed behavior does not fill in an
unread all-source transition program.

TokenStaking is a second concrete boundary, independent of receipt inclusion:
an ordinary Migration call cannot spend another claimant's weight merely
because it has a proof of that claimant's ownership. A holder-context atomic
execution route could matter, but no chain/wallet/runtime-compatible route
for all affected holders is established here. Account delegation, an arbitrary
multicall wrapper or a source change is not silently assumed. Direct
reassignment followed by later issuance is not MIG-P06 atomicity.

For nonduplication, a 1000-credit NFT with 60/100 remaining pays 600 and consumes
the whole NFT identity. The other 400 is not newly authorized credit for its
withdrawn descendant. A separately admitted fungible entitlement must prove
its disjoint original basis. Likewise a 901-credit wrapper and its backing are
one claim, not 1802. Independent compensation must be disjoint from held
exposure; reward-only units do not create original contribution credit.

Current disabled harvesting and owner-restricted LP exits remain source-route
findings, not evidence that immutable attribution is impossible. Staged
harvesting is permitted. No category is omitted because the historical ledger
has no standalone row; absence requires evidence.

## 7. Canonicality, finality, continuation and long-offline operation

### 7.1 Canonicality and reorg rule

A direct native history call authenticates a completed ancestor relative to
the chain executing that call. Permissionless callers may then supply
headers whose hashes match that ancestor. The normal reorg model discards
transactions/state after a common ancestor, including Migration checkpoints,
custody, consumption and funded bonds executed there. An offchain producer
must discard orphaned progress and resume from the last surviving onchain
checkpoint, not trust a cached height alone. [AS documentation entry
`finality-and-reorgs`, sections "The reorg model" and "Reorg detection patterns".]

This is not an externally irreversible finality certificate. A R9/R10 observe
different RPC safe/finalized heads; R57 authenticates the selected finalized
head's **hash**, not its finality status. Native history interfaces do not
return the parent finality proof. No fixed L2 block delay is substituted for
finality, and no generic Ethereum BLOCKHASH recipe is imported onto Orbit.
[A R9/R10/R22/R26/R43-R48/R57; AS
`go-ethereum/core/vm/instructions.go:416-449,462-469`.]

If the construction requires stronger parent-finality authentication than
same-chain reorg-atomic execution, it needs an actual authenticated parent
trust root, batch binding, version/governance model and verifier. None is
established here. Conversely, the plan does not explicitly require waiting
for Ethereum finality before the current same-chain custody transaction:
inventing that requirement and declaring it contradictory to atomicity would
be a false impossibility argument.

### 7.2 Concrete continuation relation, not a gas claim

There is a finite header-authentication procedure for an arbitrarily old
baseline **conditional on historical bytes remaining obtainable**:

1. During a call, authenticate a recent completed L2 hash using the actual
   history interface. Persist that hash and number; an old ring slot need not
   remain populated thereafter.
2. In each bounded call, accept a finite batch of supplied headers. Rehash
   each; require the expected hash and exact decreasing L2 number; carry its
   committed parent hash into the next cursor. Reject any discontinuity.
3. Reach the exact accepted baseline. In a separate forward ordered traversal,
   authenticate complete block contents and source transitions, extending an
   exact predecessor attribution-state commitment. Bind each continuation
   cursor to domain, baseline/revision, anchor and execution state.
4. Store progress without taking custody or minting. Do not expose an
   incomplete block/transition prefix as spendable final attribution. A later
   surrender must also validate the current consumption state and the missing
   current-custody connection.

The chain-link argument uses only already authenticated parent links;
it does not require an always-online keeper to refresh ring slots. A complete
receipt-trie stream could subdivide work within a large block rather than
requiring that whole block in one call. Actual bounds must cover header bytes,
receipt/transaction bytes, trie traversal, source execution, representation
state updates and proof verification. A cap that permanently rejects a valid
large block is truncation, not continuation.

This is a specified relation, not an executable gas-bounded system. No
continuation implementation, gas/byte/storage bound, large-history recovery
run or throughput guarantee is delivered by the small Audit. Persistent state
also needs protection against stale progress overwriting later consumption.
Whether history is materialized onchain or proven succinctly, it must close
the same source semantics and custody endpoint; compression cannot supply
a missing authentic endpoint.

### 7.3 Availability and eventual progress

Long-offline operation cannot assume that the holder or a keeper continually
checkpointed. The preceding procedure avoids that assumption for authentication,
but requires headers and historical receipt/execution witnesses. An archive
or retained chain data can be an untrusted provider of those bytes; it cannot
be an approver of their truth. There is no demonstrated permanent recovery
service or complete incident-data reconstruction procedure here.

A R53's historical `eth_getProof` fails with HTTP 503 / code -32001,
`Unable to complete request at this time.` This is one acquisition failure,
not proof that all state witnesses are unobtainable. Headers and receipts were
available. Nor does the 393168-block native window imply an expiry: parent
links can authenticate older material if available.

A finite historical gap has finite work but not a history-independent total
cost. Ongoing transfers can keep extending the required suffix while bounded
calls catch up. No tested liveness argument shows that this candidate reaches
the live custody boundary under the allowed activity. It may neither cut off
old holders nor assume a trusted party freezes their history.

## 8. All six obligations considered together

The numbered column preserves the actual numbering in attribution-spec
section 6. It also covers the brief's regrouping of baseline/domain, ordered
proof/nonduplication, finality, atomic freshness, boundedness and offline use.

| Section 6 item | Supported fact | Missing capability / disposition |
| --- | --- | --- |
| 1. Domain and immutable configuration | Exact source/chain pins and frozen-domain requirements are identified | No production verifier binds all sources, revisions, quote units and snapshot. Must not finalize affected ABI from this report. |
| 2. Authenticated baseline | Stage1 authentication is permitted; witness assumes a stronger, complete baseline | Actual incident unknowns and disjoint exposure must remain explicit. Operational funded C0/amount inputs are not the reason for the structural verdict. |
| 3. Execution state | Ordinary-transfer arithmetic is executable and conserves credit; source conversion/caller facts are pinned | Complete origin/representation partitions, residuals, replacements and onchain consumption integration remain unimplemented. TokenStaking needs an atomic claimant-context handoff. |
| 4. Complete ordered proof input | Actual complete small receipt roots reconstruct and distinguish histories; order tampering fails root comparison | No source-complete ordered execution/replay relation with omission and causal-dependency protection is implemented. Selected receipts are insufficient. |
| 5. Canonical anchor and freshness | Real completed-L2-block anchors exist, with exact windows and same-chain reorg interpretation | **Decisive gap:** no authenticated predicate ties proved attribution to actual pre-custody history, including same-block/transaction prefixes. Parent-finality verification, if required, is also not supplied. |
| 6. Bounded operation | Parent-linked old-header authentication does not inherently require continuously refreshed checkpoints | No executable bounded continuation plus data acquisition and eventual live-boundary procedure; no expiry or category truncation is authorized. |

All six must hold in the **same** successful mechanism. Passing the first
two, receipt inclusion, a current balance check, or the two-receipt codec does
not permit issuance while item 5 is absent.

## 9. Exact missing facts and decision boundary

The minimum technical evidence capable of changing the overall disposition is:

1. **Freshness:** an actual, contract-usable authenticated predicate on this
   chain that identifies the complete relevant prefix up to custody, or a
   proved equivalent condition. Its evidence must distinguish the two recorded
   prefixes at the call boundary and cover earlier calls in that transaction;
   selected source-state equality alone demonstrably fails.
2. **Complete state transition:** a concrete producer and verifier implementing
   the origin-aware relation in sections 4/6, including non-event semantics,
   source revisions, claim/wrapper descendants, residuals and prior consumption.
   A sound generic proof backend without that relation is insufficient.
3. **Atomic source handoff:** a permitted caller path for claimant-only rights
   that rolls back custody and consumption if new-bond funding fails. Ordinary
   forwarded reassignment and a recipient callback are concretely ruled out
   by pinned TokenStaking observations, not every possible account mechanism.
4. **Bounded no-expiry execution:** actual continuation, recovery inputs and
   measured per-call bounds, with a procedure for a long-offline holder and
   a justified final catch-up step. Any finality assumption must be bound to
   the actual chain rather than asserted by RPC.

These are engineering capabilities and evidence gaps, not newly invented
owner choices. Universal absence of item 1 has not been proved; therefore
**unproven**, not global **demonstrated-conflict**, is the justified disposition.
If a later investigation establishes that only a rule-changing workaround is
possible, it must name the exact incompatible requirements and request the
minimum change. This report does not preselect delayed issuance, escrow,
wrapping, payer-only credit, trusted updates, omission or expiry.

## 10. Execution, preservation and cleanup

Only this construction directory is written. All 12 inherited anchor/freshness
files were fingerprinted before writing; their preservation and final scoped
Git/resource checks are in [verification.json](verification.json).
The earlier evidence files are read-only and unchanged by this lane.

No Forge compilation, test-suite execution, production/test edit, contract
deployment, public transaction, dependency/configuration mutation, commit or
delegation occurred. No compilation is indispensable for this finite
missing-capability disposition. No local runtime, temporary root or listener
was created, so no runtime deletion was necessary. Port 18553 remained unused.

The initial shell syntax error and linked-submodule status error are retained
in invocations.md. A web-tool open of the pinned ArbSys source returned no
usable text; the existing exact source archive was read instead. A separate
read-only fetch returned the complete primary finality document. JSON LSP
diagnostics were unavailable because Biome is not installed; no installation
or clean LSP result is claimed.

The executable evidence is intentionally bounded: W's prior real-source
transactions, A's prior native-chain observations, and this lane's 24-check
offline reconstruction. It does not execute a Migration verifier, custody
plus credit plus funded bond, large-history continuation, or Nitro mid-block
consensus experiment. Those limits are part of the disposition, not deferred
success claims.

**DoneClaim:** the requested construction assessment is delivered with a
decisive **unproven** result and exact demonstrated boundaries. E2, affected
fungible ABI/storage readiness, all-category implementation and the original
plan remain open. All unchanged requirements remain binding.
