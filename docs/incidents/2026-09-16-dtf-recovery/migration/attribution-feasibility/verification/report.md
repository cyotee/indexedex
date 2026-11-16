# Independent E2 feasibility verification

Date: 2026-11-11. **Disposition: unproven.**

## 1. Decisive disposition

The construction report's **unproven** disposition is supported. The admitted
evidence establishes neither a complete compliant construction nor a conflict
inherent in the unchanged Migration requirements.

The decisive gap is an **authenticated connection from complete attribution
history to the actual pre-custody execution position**. The demonstrated native
anchors authenticate completed L2 blocks. They do not authenticate the
executing block's ordered prefix. Ordinary legacy transfers in that interval
can restore selected token observations while changing the required credit.
Correct proof verification about a supplied history does not establish that
the supplied history is the actual complete prefix.

The finite conflict is narrower: an adapter limited to freshness model O
(completed-parent history, unchanged internal execution state, selected live
token observations and the custody request) cannot correctly accept both
recorded branches. They require **500 versus 833** credit. That observation
restriction is not itself a product requirement. The branches differ in full
receipts, native-account effects and complete history commitments. Therefore
this result cannot be promoted to universal cryptographic impossibility.
[F records 60-90; W; C sections 3-5; audit.json.]

No source-complete origin/representation transition verifier, executable
bounded continuation, long-offline recovery procedure or claimant-only atomic
handoff is established either. These are specific gaps, not evidence that such
mechanisms can never exist. The construction's predicates and ordering are
proof obligations, not implemented proof functions.

**Minimum owner decision required now: none.** No pair of binding product
requirements has been proved incompatible. The evidence does not justify
asking the owner to waive current-holder eligibility, atomicity, categories,
no expiry or no trusted postactivation updates. E2 and affected fungible
ABI/storage readiness remain open; this report completes only the independent
feasibility verification.

### 1.1 The deployed capability model, not hypothetical proof systems

The disposition has two different, explicitly bounded subjects:

| Subject | Decision |
| --- | --- |
| C's concrete admitted construction using the demonstrated completed-block anchors plus the live source observations in model O | **demonstrated-conflict at its freshness boundary**. It cannot correctly accept both recorded histories. No additional unchanged balance, receipt or anchor probe is needed to settle that model. |
| A complete E2 mechanism on the actual unmodified chain/source deployment | **unproven**. The evidence has not established a compliant endpoint predicate, and it has not closed the actual callable native surface strongly enough to extend model O's contradiction to every available native observation. This is a bounded source/runtime coverage limit, not an appeal to arbitrary future cryptographic systems. |

In particular, **no specific untested RPC query is identified that would make
C's construction work**. Calling the decisive gap "unproven" must not make the
failed completed-parent construction look as though it merely awaits one
successful repeat probe. C's `CurrentCustodyConnection` is the missing
operation, not an implemented operation with an uncertain test result.
Changing proof backends cannot add an authenticated input absent from that
construction.

Section 7.1 identifies the finite native-surface check relevant to a stronger
deployment-wide negative claim, including its exact pass/fail meaning.
Unspecified global-state observations are not admitted capabilities or rescue
arguments. The current evidence already permits root to reject C as a passing
E2 construction; no further generic investigation is a prerequisite to that
decision.

## 2. Authority, identity and evidence locators

The complete brief, original main-checkout plan, phase01 attribution
specification and independent report, and all three upstream E2 reports were
read. The plan's MIG-P01-P15, including its precedence over older principal
rules, remains unchanged.

| Locator | Exact artifact |
| --- | --- |
| Brief | `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase06-e2-brief.md` |
| Plan | `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` |
| P1 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/` |
| Phase01 requirements | P1 `attribution-spec.md`, especially section 6 |
| Phase01 verification | P1 `evidence/phase01-verification.md` |
| A | `../anchors/rpc.json`, indexed by `requests[].request.id` (R1-R57) |
| AS | `../anchors/primary-sources.json`, exact path and original numbered excerpts |
| F | `../freshness/runtime-evidence.json`, zero-based `records[]` |
| W | `../freshness/witness.mjs` |
| C | `../construction/report.md` |
| Anchor/freshness reports | `../anchors/contract.md`, `../freshness/contract.md` |
| Independent calculations | `audit.json`; exact reproduction and invocation outcomes in `invocations.md` |
| Native-surface scope clarification | `native-surface-scope.json`, finite registration/source inventory following root's scope question |
| Preservation/cleanup | `cleanup.json` |

Additional actual supporting inputs read were P1
`evidence/weighted/deployed-source-extracts.json`,
`evidence/earlier-cp/probe-alchemy-retry.source.json`,
`evidence/verification/tokenstaking-caller.json` and
`evidence/verification/other-metered.json`. Deployed source excerpts and actual
request/receipt/trace fields, not just producer PASS labels, support the
findings below.

| Identity | Value |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2` |
| Branch | `work/dtf-migration-phase-06-e2` |
| HEAD | `5021e8d4a62bcbddc555f580ef98f8666d993aab` |
| Historical P | Chain 4663, L2 108944663 |
| P hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| P state root | `0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071` |
| Additional inherited C pin | L2 111330887, `0x309c2f18fbdfc1ae225dd123693dfc66157dbce50640cc0ed040198fcfe5af42` |
| Local witness blocks | Counterfactual Anvil descendants 108944664-108944665 of P |
| Independent calculation runtime | Resident Bun 1.4.4, darwin arm64 |

C is not substituted historical evidence. Neither P nor C is the funded
Migration quote snapshot. No new chain pin was acquired by this verifier.
The approved dependency links point to the main checkout. Tracked/staged
diffs are empty; upstream untracked evidence already existed at verifier entry.
The ordinary Git status failure caused by the linked submodule was corrected
using read-only `--ignore-submodules=all`, not a dependency change.

## 3. Independent adversarial calculation

The audit used an independently written recursive receipt-trie encoder and
integer transfer replay. It imported no producer functions. **33 assertions
passed in one execution.** For each local three-receipt block, it enumerated
every list of length 0 through 4 over receipt indexes 0, 1 and 2:
`1 + 3 + 9 + 27 + 81 = 121`. Only `[0,1,2]` reproduced that block's root.
Across both branches, **240 mutated lists failed root equality and two
unchanged controls matched**. These cover omissions, all three-item
permutations, duplicates and additional repeated receipts. Each sequence and
calculated root is retained in `audit.json`.

| Attempt or control | Actual result | Limit |
| --- | --- | --- |
| Rehash P, P-1 and C headers | All reported hashes reproduced; P-1 matches native anchor R14/R27 | RPC evidence is not itself an onchain verifier |
| Reconstruct P receipt trie | Root `0xed4030c56b19861b12d407133d34d67e86eb659431133713cbdc126ba9f35a17` reproduced, including internal type `0x6a` and user type `0x02` | Tiny fixture, not all Nitro types/eras |
| Reconstruct control/mixing complete tries | Both recorded roots reproduced from raw receipts | Local execution, not Nitro consensus |
| Omit/reorder/repeat complete receipt-list entries | 240/240 altered lists mismatch their fixed recorded roots | Does not prove a deployed verifier rejects them |
| Alter RPC `transactionIndex`, `blockHash`, `logIndex` only | Consensus roots unchanged | Those metadata fields need authenticated context, not blind parsing |
| Omit the mixing prefix from attribution replay | Custody credit becomes 500 instead of 833 | A supplied-log attack, not authenticated history |
| Apply the mixing prefix twice before custody | Custody credit becomes 944 instead of 833 | Repeated receipt bytes are not valid signed transaction replay |
| Compare custody token prestate/request | Same selected storage and exact submitted custody request | Not all globally readable observations |
| Compare full custody receipts/prestates | Different consensus receipts and different whole traced prestates | Defeats an overbroad indistinguishability claim |
| Check claimant forwarding evidence | Actual reverted receipt; error names the forwarding contract | Does not exclude all account-level mechanisms |

Raw branch receipts are F[62,64,63] and F[84,83,85], in execution order.
F[65]/F[86] are their block records; F[66]/F[87] are custody prestates.
The recomputed local roots are:

```text
control  0x9a8004d24a432c866ee94c38a5fc0e6e6303488e2e43bdb73f474d71982b3f77
mixing   0xffeba2de437b5e51d7e357b584fd669ca4bf0194e31df68d7493e3a7e996a3ae
```

Replay starts from the explicitly synthetic valid baseline: Alice and Bob
each have 100 native units with credits 1000 and 3000. It reads actual Transfer
contents rather than importing W's arithmetic. The control self-transfers
preserve Alice's 1000. The mixing prefix transfers 500 credit to Bob and
`floor(3500*50/150)=1166` back, leaving Alice 1666. The identical 50-unit pull
therefore carries 500 or 833. Repeating that mix yields 1888 before custody
and 944 on the pull. All four replay variants conserve 4000 total credit and
end with physical units Alice/Bob/custody = 50/100/50.

These new offline omission/replay checks address missing adversarial coverage
without repeating a valid fork probe. Port 18554 was not used.

## 4. Chain capabilities and authentication assumptions

### 4.1 Observed anchor capabilities

At P, ArbSys `arbBlockNumber()` returns 108944663, whereas EVM NUMBER returns
26367659. ArbSys's `arbBlockHash` accepts P-1 and P-256 and rejects P-257,
P and P+1 with `InvalidBlockNumber`. The deployed history contract
`0x0000F90827F1C53a10cb7A02335B175320002935` accepts a selector-free, exactly
32-byte L2 number and exposes preceding hashes for a 393168-L2-block window.
Boundary and current-block rejection were observed at P and C. Its 133-byte
runtime matches AS's Arbitrum-specific constant and is identical at both pins.
[A R11-R38/R49-R51; AS `nitro/precompiles/ArbSys.go:35-69`,
`go-ethereum/params/protocol_params.go:239-246`; independent audit.]

The ordinary nested history STATICCALL returns success, 32 bytes and the real
parent hash. In contrast the nested call to NodeInterface at `0xc8` returns
success with zero bytes. Its direct RPC helper response is not a
contract-callable trust root. EIP-4788's expected beacon-root address has no
code at either pin. These observations do not exhaust arbitrary deployed
contracts. [A R21/R25/R46-R51; AS
`nitro/execution/nodeinterface/node_interface.go:33-38`.]

EVM BLOCKHASH is not an L2-history substitute: at P, querying P-1 returns
zero while a parent-number query returns nonzero. The pinned Geth opcode
implementation invokes L1-number/hash hooks; Nitro's skipped-parent-number
logic may synthesize values. A nonzero result alone is not proof of an
Ethereum header. [A R43-R45; AS
`go-ethereum/core/vm/instructions.go:416-449,462-469`,
`nitro/arbos/tx_processor.go:960-993`,
`nitro/arbos/blockhash/blockhash.go:33-78`.]

### 4.2 Last-block is not same-block freshness

Source interpretation corroborates the runtime boundaries: the start-block
internal transaction writes the preceding hash, while current transaction,
receipt and final state commitments are assembled after execution. The
inspected anchor surfaces therefore do not expose the current complete
prefix. Completed-block `eth_call` observations were not a mined Nitro
mid-block experiment. [AS `nitro/arbos/internal_tx.go:62-87`,
`nitro/arbos/block_processor.go:197-234,775-793,809-826`.]

The actual liquid-token transfer path modifies balances/allowances and emits
Transfer without calling Migration or maintaining an attribution counter.
The deployed generic facet has a source-service `match`, not an asserted
metadata-exact match; its runtime hash is
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
The six recorded branch call traces stop at that delegatecalled facet.
[P1 earlier source archive, facet
`0x1d17aca0e0717d90cea916372070a1be4652223f`,
`ERC20Facet.sol:2470-2477,2683-2694,2722-2741,3060-3077`;
F[67-69,88-90].]

A proof ending at B-1 does not cover transactions preceding custody in B.
Advancing in an earlier transaction still leaves a suffix. Waiting to pull
until the proved block is complete moves custody to another block and
recreates the problem. Supplying a prospective B header or proving execution
of caller-chosen inputs supplies no canonical selection rule.

Earlier calls within the custody transaction also require coverage. The
fixture tests earlier transactions in one block, not that within-transaction
case. A contract/batch caller can create an additional suffix before entry;
a transaction-start predicate alone would need to account for it. This is a
derived verification obligation, not another executed witness.

The reported same-observation contradiction is sound only under model O:
full custody cumulative gas is 125872 versus 141072, the native balance of
the traced zero address differs, and full block/receipt commitments differ.
The local state roots are zero, not evidence of equal authenticated global
state. Neither this report nor C proves all possible EVM observation models
indistinguishable. Gas/nonce differences distinguish this pair but do not
themselves implement complete attribution for arbitrary histories.

### 4.3 Reorgs, finality and cryptography

A native history read authenticates an ancestor relative to the chain
executing the call. In the same-chain reorg model, discarded Migration
checkpoints, custody, consumption and bond issuance roll back with the rest
of that branch. Offchain continuation must resume from surviving onchain
state and bind hashes, not only heights. Importing an orphaned checkpoint
from an RPC journal would violate that relation. No reorg experiment was
performed here. [AS documentation entry `finality-and-reorgs`, official
sections "The reorg model" and "Reorg detection patterns"; C section 7.1.]

R9/R10's safe/finalized tags are RPC assertions. R57 authenticates the tagged
block's hash, not its finalized status. The examined surfaces return no
parent-finality certificate. Stronger finality would need an authenticated
parent trust root, settlement/batch binding and actual verifier. The plan
does not require independently irreversible Ethereum finality before every
same-chain custody call; inventing that demand would manufacture a conflict.
The official chain-info in AS identifies parent chain 1 and no DAC but is
not an L1 governance/deployment audit.

The supported authentication arguments assume:

- Keccak collision/second-preimage resistance and unambiguous canonical
  header/receipt/trie encoding, including typed receipts and correct trie keys.
- Correct execution and protocol-system history writes on the chosen chain.
  Application immutability does not eliminate chain governance or upgrades.
- Stage1's admitted baseline is correctly bound to domain, original quote
  units, source semantics and disjoint exposure.
- Historical bytes needed for recovery are obtainable. An untrusted supplier
  can supply them without approving their truth.

The archive-reported Nitro revision
`70fa99a6e711f09eedd96a907290c3df0f3bcf7d` and Geth submodule
`5eee8f546e7602b7deeef7909f291bbebc77e233` identify inspected source.
An RPC version string is not attestation of every historical native behavior.
Exact history runtime matching and observed calls provide narrower binding.
Our research observations still rely on provider honesty; hashing recorded
JSON does not deploy an onchain light client.

No concrete SNARK/STARK/recursive proof backend, circuit, verification key,
trusted setup or measured verifier has been supplied. Accordingly no
cryptographic soundness, completeness, setup independence or prover
availability claim for such a backend is established. A sound backend would
still need to prove the actual all-source relation and bind its endpoint.
The audit's receipt roots prove neither fact.

## 5. Transition, continuation and atomicity attacks

### 5.1 Omission, ordering and replay

The mutation experiment demonstrates why a **fixed authenticated full root**
can reject tampered complete lists. It does not make selected inclusion
complete. All Alice-related receipts can still omit Bob's earlier incoming
mixture; causal incoming provenance and representation transitions must be
closed. Where exact effects are not determined by emitted data, verified
execution or sufficient authenticated state witnesses remain necessary.
[P1 attribution-spec section 6; F report section 5; deployed sources below.]

Whole-batch replay is distinct from duplicated receipt entries. The same
genuine old proof retains a valid root when submitted again. A real verifier
must consume an exact predecessor state/version once, domain-bind chain,
proxy, snapshot, source and original identity, and refuse stale progress
overwriting subsequent surrender. No actual replay-protected state machine
was executed. C section 4 states these obligations; treating their names as
implemented checks would be a proof-shaped placeholder.

Migration consumption must appear in the replay at its actual position:
after partial surrender, only the remaining units and credit travel onward.
The custody transfer cannot create a new Migration-held award, and later
harvest cannot revive consumed origins. Stage1 replacement must not erase
transferred/consumed partitions or recompute a retroactive top-up. After
activation no trusted revision/root/signature may repair an omitted suffix.
[Plan MIG-P02/P10/P11/P15, sections 5.3-5.4.]

### 5.2 Long-offline recovery and bounded work

The 393168-block lookup window does **not** imply a migration expiry. From a
recent native hash, a supplied header's committed parent hash can authenticate
the next older header. Persisting the expected hash/number cursor allows
bounded batches without an always-online holder or keeper. Skipping a link,
substituting a different branch, or resuming with a stale revision must fail
that relation. This is a hash-link argument, not executed continuation code.
[A R27-R41; AS `go-ethereum/core/types/block.go:68-86,125-129`;
C section 7.2.]

For a finite gap, such traversal has finite but history-dependent total work.
No implemented per-call gas/bytes/storage bound, intra-large-block
continuation, historical witness recovery or eventual live catch-up is
demonstrated. A cap that permanently excludes a valid large history would
violate no expiry; batching only headers would not bound an arbitrarily large
receipt/execution work item. New transitions while catch-up proceeds must
not overwrite consumption or leave the final suffix assumed away.

This does not assert impossibility under endless adversarial activity or
demand a history-independent total cost. Liveness needs a concrete procedure
and explicit ordinary chain inclusion/data-availability assumptions, not a
guarantee against every permanently censored or data-destroyed environment.
The missing procedure remains unproven even for the finite-history recovery
case. R53's one failed historical `eth_getProof` is an acquisition failure,
not proof all witnesses are unobtainable; headers and receipts were obtained.

### 5.3 Custody and issuance

An approved ERC-20 pull is a usable source primitive. Missing future funded
bond integration does not invalidate that primitive. However, feasibility of
the complete operation requires a protected order:

1. Bind current owner, source, amount, domain/revision and latest consumption;
   authenticate attribution through actual pre-custody execution, including
   any source synchronization.
2. Compute positive proportional credit, reserve its origin partition, and
   perform typed custody with exact source-normalized receipt checks.
3. Mint only delivered principal and fund a fresh bond to that surrendering
   owner, settling prior participation as required.
4. Commit custody, consumption, residuals and bond together; every failure
   reverts all of them. Each bond starts its own 90-day clock.

The ordering is a requirement, not a new API or executed integration. Guards
must cover callbacks as well as top-level entry. Ordinary top-level
transactions do not interleave during a transaction, but that does not solve
the unproved history before entry or callback/source-synchronization changes.
[Plan MIG-P06-P08, sections 5.4-5.5; C section 5.1.]

TokenStaking adds a concrete independent handoff limitation. The actual
pinned forwarding attempt fails with `InsufficientStake(helper,q,0)`; its
error encodes helper `0x1a0511e3d0657f00eb5d2695478f9ee1d1debce4`, not the
holder. A direct reassignment to an always-reverting receiver succeeds with
no recipient call and transfers weight `64890781291192882058375`. The inspected
facet hash is
`0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742`.
[P1 `evidence/verification/tokenstaking-caller.json`, checks 0/1,
RPC indexes 2-11,25-28,36-45; independently checked in audit.json.]

Thus a generic forwarding pull or receiver callback is not a solution.
The recorded successful inner-claim/outer-revert case in `other-metered.json`
starts **after** a separate custody reassignment: it proves rollback of that
inner claim, not rollback of the earlier transfer. It cannot certify one-step
original-holder custody plus fresh funded bond. This distinction is preserved
even though that artifact names another case "staking atomic source-right
surrender". Holder-context/account-level alternatives remain unproved, not
universally impossible. A receipt codec's support for a transaction type is
not evidence that a compatible account path exists for every affected holder.
No account delegation or two-transaction escrow is silently adopted.

## 6. Cross-source descendants and retained coverage

All categories remain required. The ordinary weighted-token witness does not
stand in for the following transition programs:

| Required category | Binding semantics and remaining proof |
| --- | --- |
| Weighted liquid DETF | 9-decimal native transfer mixing; exact source runtime and same-block boundary demonstrated, complete fresh attribution unproven |
| Earlier liquid DETF | Separate 18-decimal units and original origins; generic transfer source does not supply ancestry |
| Weighted fixed-principal NFT | Actual owner, original/claimed principal and whole collection/ID consumption; reward gons do not add principal |
| Earlier LP-lock NFT | Original LP accounting shares, lock/sale/burn; do not invent weighted-model `claimedPrincipal` |
| Weighted sDETF | Current-index gons, synchronization, stake/unstake, full-account fractional retirement and reward separation |
| Earlier rebasing receipt | Internal shares and contemporaneous redemption rate; emitted native amount is not exact normalized ownership movement |
| Weighted SY | Share burn/mint, backing gons, conversion dust and actual recipient/output; one economic claim with its backing |
| TokenStaking rights | Claim weight, reassignment, claim extinction and source caller context; complete atomic handoff unproven |
| Claim-vault shares | Distinct shares backed by SY, linked to claim-weight consumption; infrastructure custody is not user authority |
| Earlier underlying SE shares | Independent source identity/units/acquisition ancestry; tested disabled harvesting is separate from E2 |
| Weighted WETH-leg SE shares | Independent source identity/units/acquisition ancestry; tested disabled harvesting is separate from E2 |
| Weighted DTF custody SE shares | Distinct conversion units, original origin and rounding; successful redemption does not prove eligible user ancestry |
| Earlier fungible LP | Distinct from NFT lock; original acquisition and join/exit ancestry, with tested harvest restrictions retained |
| Weighted fungible LP | Distinct source and owner-restricted tested exits; no source-owner impersonation as an end-user route |

Source observations supporting these distinctions:

- P1 weighted deployed extracts, `DETFFundedBondTarget.sol:127-140,163-200`:
  principal claims debit the position and can retire/burn it; operator
  authorization and recipient selection require explicit current-owner
  protection in Migration.
- The same archive, `StakedDETFTarget.sol:104-124,187-214` and
  `DETFFundedStakingRepo.sol:109-161`: synchronization, gons transfers and
  full-account debit differ from a raw native-token event ledger.
- The same archive, `DETFSYTarget.sol:94-134,225-253`: shares are burned,
  backing gons/dust adjusted and actual receipt/underlying outputs routed.
- P1 earlier deployed archive,
  `RebasingClaimTokenFacet.sol:9859-9878,10125-10148`: native transfers convert
  to internal shares at the current rate. Rounded external shares are not
  the exact replay unit.
- That archive, `DETFNFTVaultFacet.sol:16377-16404` and
  `UniswapV4SingleStandardExchangeDETFFacet.sol:25419-25447`: the earlier
  position is an LP-share model with sale into a receipt representation.
- P1 `other-metered.json` contains historical claim extinction to 117153341
  SY, claim-vault redemption, source custody and rollback receipts. Its
  successful historical replay supersedes the older attribution-spec's
  unresolved historical acquisition statement. It does not complete ancestry.

For a 1000-credit fixed-principal NFT with 60/100 remaining, the award is 600
and the whole NFT identity is consumed. The other 400 is not an automatically
authorized descendant credit. Separately admitted fungible original
entitlements need disjoint provenance; categories cannot simply be excluded.
A wrapper and its 901-credit backing are one claim, not 1802. Independent
compensation must not overlap held exposure. Reward-only units create no
original-contribution credit; known-zero units still matter to physical mixing
denominators, and unknown ancestry is not known-zero ancestry.
[Plan MIG-P03-P05/P09/P15; P1 attribution-spec section 4.]

A per-source nullifier can stop the same source identity being spent twice
while still paying correlated representations twice. The required shared
origin partition and its source-specific rounding have not been implemented
or proved. The simple examples diagnose that obligation; they do not certify
a deployed duplicate-rejection mechanism. The complete all-source contract in
C section 6 is therefore a specification of missing work, not a coverage PASS.

## 7. All six requirements and exact decision boundary

| Attribution-spec section 6 | Independent disposition |
| --- | --- |
| 1. Domain and immutable configuration | Exact historical identities are available; no complete verifier binds chain/proxy/source/code/snapshot/original quote units and revisions |
| 2. Authenticated baseline | Permitted Stage1 input; synthetic complete baseline isolates the structural gap. Unknown incident data remain unknown. Future funding/C0 is not used as a circular blocker |
| 3. Execution state | Finite liquid-transfer arithmetic checked; complete origin partitions, all representations, consumption/replacement and bond records unproven |
| 4. Complete ordered proof input | Fixed complete small receipt roots reject mutation; omission/exclusion, causal closure and non-event execution semantics across all sources remain unproven |
| 5. Canonical anchor and freshness | Completed-L2 anchors demonstrated; no authenticated current-prefix connection. Model O conflict demonstrated, universal conflict not demonstrated |
| 6. Bounded operation | Conditional old-header authentication is sound under stated hash/data assumptions; executable continuation, recovery and final live-boundary procedure unproven |

Evidence sufficient to change **unproven** to **feasible** must jointly
establish: an actual chain-usable current-custody predicate; a complete
origin-aware producer/verifier relation for every category; permitted atomic
source handoffs; and executable bounded, no-expiry recovery and consumption.
If a succinct proof is used, its exact public inputs, circuit semantics,
soundness/setup assumptions and verification bounds must be explicit. Naming
a light client, receipt proof, execution proof or a truth-returning predicate
does not discharge these requirements.

Evidence sufficient to change **unproven** to **demonstrated-conflict** would
instead need a contradiction under assumptions actually required by the
product, not model O's additional observation restriction or the absence of
implementation. The current witness cannot supply that stronger conclusion.

Conditional workaround conflicts are already clear but are not owner choices
this report selects: trusted future attestations conflict with MIG-P11/E2;
payer-only eligibility or mandatory wrapping conflicts with MIG-P15/E2;
custody now and credit later conflicts with MIG-P06; dropping sources conflicts
with MIG-P15; expiry conflicts with MIG-P07. None is proved necessary.
**There is no justified minimum requirement relaxation to request now.**
The exact missing technical fact is the authenticated pre-custody connection,
with the additional construction gaps listed above.

### 7.1 Exact finite checks and what each would settle

**Already settled, no further check needed:** in C's admitted model, the only
authenticated historical inputs stop before the executing block, and its
selected source-state suffix check has the executed counterexample. This is
a demonstrated conflict between that implementation model and MIG-P02/P15's
award rule with MIG-P06's same-operation custody. It is not a contradiction
among those owner requirements without the model restriction.

**Finite remaining surface check for a broader native-anchor claim:** at the
reported Nitro revision, `precompiles/precompile.go:515-701` registers exactly
18 named ArbOS families; `:120-241` binds their metadata ABIs to handlers and
`:736-766` applies version/selector/context gates. The exact missing artifact
is a table of **each callable method at the observed ArbOS 61**, with its
address/selector, caller restriction, fields read, and whether its result
authenticates an ordered transaction/receipt prefix or current state
commitment at the caller's actual execution position. Trace only those
data dependencies, including the EVM opcode hooks already identified in AS.
Apply the configured debug/owner restrictions rather than counting RPC-only,
inactive or privileged methods as ordinary Migration capabilities.

The inspected registration names and source hashes are in
`native-surface-scope.json`. `ArbInfo.go:18-36` supplies balance/code, not a
history root; `ArbStatistics.go:17-25` supplies the block number and five zero
legacy statistics. Their source bodies do not fill the missing predicate.
The remaining registered handlers/ABI metadata have not all been inspected,
and the archive's build string is not a full runtime attestation.

The finite check's outcomes are precise:

- If an eligible method actually reads such a prefix commitment, identify
  **that address, selector and producer update point**, then use a nonzero
  ordinary contract call in a chain-native execution containing two preceding
  balance-restoring transfers. Check that its returned commitment binds the
  ordered prefix through that call and is not an RPC-intercepted, completed
  parent or caller-supplied value. Only that named missing-capability probe
  could justify another local runtime; repeat balance probes cannot.
- If the version-gated, deployment-bound method/dataflow inventory has no
  such method, the claim "this deployment has a native executing-prefix
  commitment oracle" is false within that inventory. That closes that
  finite protocol question. It does not turn a gas/fee counter into an
  attribution oracle or make absent implementation a universal theorem.

This is a finite source-to-runtime closure check, not a request to search for
new cryptographic architectures. No speculative method is assumed to exist.
A chain-native replay would require a faithful Nitro execution environment;
ordinary Anvil cannot settle native mid-block semantics. No such environment
or indispensable compilation was requested or started in this evidence-only
lane.

**Stronger global-state equality is not required to reject C.** If instead a
new claim explicitly relies on other live observations, it must first name
their finite call/opcode set and a deterministic award/prefix predicate. The
exact countercheck is then to evaluate that declared predicate on both
histories with the complete declared observation vector, including native
fee/counter effects and within-transaction context. Equal vectors with unequal
required awards refute that predicate; different vectors refute only the
indistinguishability assertion and do not prove general attribution. The
present pair already has different native balances, so it is not a valid
global-state counterexample. No all-address state census or unspecified
stronger-observation search is made a completion prerequisite here.

Thus the residual **unproven** is not a claim that an omitted known runtime
observation will succeed. It records the exact boundary between the rejected
concrete construction and an unestablished deployment-wide closure proof.
The other source-transition, claimant-handoff and bounded-recovery gaps are
construction/evidence obligations, not missing magic RPC responses.

## 8. Preservation, cleanup and completion limits

Only `verification/report.md`, `verification/audit.json`,
`verification/invocations.md`, `verification/native-surface-scope.json` and
`verification/cleanup.json` are authored.
The 16 inherited E2 artifacts and eight admitted brief/plan/phase01 inputs
have preservation fingerprints; final results are in `cleanup.json`.
Producer artifacts, requirements and production remain unchanged. The check
does not claim a recursive hash audit of the linked dependency trees.

No owned fork, listener, temporary root or long-running process was created;
assigned port 18554 was unused. No Forge compilation was indispensable or
attempted. No test-suite execution, production/test edit, public transaction,
dependency/config change, commit or delegation occurred. JSON parsing and
actual offline calculations provide validation. Biome is not installed, so
automatic JSON LSP diagnostics were unavailable; no installation or clean
LSP result is claimed.

The evidence does not execute a Migration verifier, complete cross-source
replay, same-transaction-prefix witness, reorg recovery, long-offline catch-up,
gas-bounded continuation, claimant account alternative or custody plus
consumption plus funded new bond. These limits are explicit reasons not to
claim **feasible**, not inferred universal impossibility.

**DoneClaim:** independent E2 feasibility verification is complete with
**unproven** and no presently justified owner-policy decision. The finite
completed-parent/selected-observation conflict and concrete claimant-forwarding
limitation are supported. E2, affected fungible implementation readiness,
all-category delivery and the full Migration plan are **not complete**.
All unchanged requirements remain binding.
