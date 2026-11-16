# Canonical-history capability contract: chain 4663

Date: 2026-11-11 UTC. Lane: anchors. Evidence only; no Migration verifier is
implemented, deployed, selected or implied by this document.

## 1. Finite result

**Completed past L2 blocks have a directly callable canonical hash anchor.**
There are two distinct mechanisms: ArbSys retains 256 preceding L2 hashes;
the deployed Arbitrum-specific history contract retains **393,168** preceding
L2 hashes. The latter is not Ethereum's 8,191-block implementation.
Both exclude the executing L2 block. A correctly hashed supplied header
exposes its transaction, receipt and end-of-block state commitments.

**No authenticated executing-block transaction-prefix commitment is supplied
by these interfaces.** The current block's earlier transactions can already
have changed live contract state, but neither interface returns their receipt
root, ordered transaction list or intermediate state root. A completed-block
proof does not cover that prefix. RPC, NodeInterface, sequencer messages or
operator signatures cannot silently fill this boundary.

The retention window is not by itself an impossibility result for long-offline
users: recent authenticated headers link backward through `parentHash`.
Recovering old history still requires available historical headers and proof
data, bounded verified continuation and a separate freshness construction.
Those are not implemented here. This lane closes the anchor inventory, not E2.

## 2. Domain, pins and evidence identity

The complete root brief, original main-checkout implementation plan, phase01
`attribution-spec.md` and independent `evidence/phase01-verification.md` were
read. Their original files are unchanged. Their section 6 proof contract and
the plan's MIG-P01 through MIG-P15 remain binding, including current-owner
transfer-following eligibility, all categories, one atomic custody/credit/new
bond operation and no trusted postactivation updates.

| Identity | Observed value |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2` |
| Branch / HEAD | `work/dtf-migration-phase-06-e2` / `5021e8d4a62bcbddc555f580ef98f8666d993aab` |
| Chain | `4663` (`0x1237`), Robinhood Chain |
| Historical pin P | L2 `108944663`, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| P parent | `0x22205b831726e31a4aeaa054c3a9e527198d25e3e5ad234ed0e3d363ec6cd03e` |
| P EVM NUMBER | `26367659`, not `108944663` |
| Additional current pin C | L2 `111330887`, hash `0x309c2f18fbdfc1ae225dd123693dfc66157dbce50640cc0ed040198fcfe5af42` |
| C EVM NUMBER | `26388387` |
| ArbSys version at both pins | `116` (`0x74`); source defines this as `55 + ArbOSVersion`, hence format version `61` |

P is the historical source pin, not a funded quote snapshot. C is an explicitly
additional observation, not substituted historical evidence. RPC requests use
explicit block numbers except the one-time acquisition of C and finality tags.

Official Robinhood chain-info declares parent chain ID 1, non-Arbitrum parent,
ArbOS enabled, genesis block 0, initial ArbOS 51 and no data-availability
committee. It records Ethereum rollup
`0x23A19d23e89166adedbDcB432518AB01e4272D94`, bridge
`0xDf8755334ce7A73cCF6b581C02eA649AE3E864b3`, inbox
`0x1A07cc4BD17E0118BdB54D70990D2158AbAD7a2D` and sequencer inbox
`0xBd0D173EEb87D57A09521c24388a12789F33ba96`.
This downloaded configuration identifies the intended network; it is not an
L1 deployment/code audit or proof that these contracts are immutable.

Raw requests/results are in [rpc.json](rpc.json), abbreviated below as R1-R57.
There were 57 read-only RPC requests, including failed requests, not 57
successful checks. [calculations.json](calculations.json) records 11 passing
cross-checks and concrete header/receipt encodings.
[primary-sources.json](primary-sources.json) preserves source URLs, whole-file
SHA-256 values, exact numbered excerpts, official chain-info and discovery
failures. [commands.md](commands.md) records invocation and reconstruction.

The archive endpoint reports Nitro `v3.12.1+70fa99a`; its published source pin is
`70fa99a6e711f09eedd96a907290c3df0f3bcf7d`, with Geth submodule
`5eee8f546e7602b7deeef7909f291bbebc77e233`. References below use those
revisions, with their paths as keys in `primary-sources.json`. Public RPC
reports `v3.12.4-rc.3+960ca0a`; resolving that abbreviated commit returned HTTP
422. Exploratory master sources are not relabeled its exact implementation.
Version strings are RPC assertions; independently matching deployed history
bytecode and observed behavior supply the narrower runtime cross-check.

## 3. Callable interfaces and exact limits

Let `n = ArbSys(0x64).arbBlockNumber()` during a call, and `m = block.number`.
All numbers below are integers, not timestamps.

### A. ArbSys, address `0x0000000000000000000000000000000000000064`

| Call | Selector | Capability |
| --- | --- | --- |
| `arbBlockNumber() returns (uint256)` | `0xa3b1b31d` | Current L2 number n |
| `arbChainID() returns (uint256)` | `0xd127f54a` | Chain ID, observed 4663 |
| `arbOSVersion() returns (uint256)` | `0x051038f2` | Version encoding described above |
| `arbBlockHash(uint256 k) returns (bytes32)` | `0x2b407a82` | L2 hash for `n-256 <= k < n`, at these non-genesis pins |

Invalid numbers, including current/future/too old, revert here with
`InvalidBlockNumber(uint256,uint256)`, selector `0xd5dc642d`; they do not
successfully return zero. Source:
`nitro/precompiles/ArbSys.go:35-69`. R11-R18 observe the historical boundary:
P-1 and P-256 succeed; P-257, P and P+1 revert. P-1 agrees with the header's
parent hash. R6-R8 and R11-R13 establish numbering/domain/version.
`eth_getCode(0x64)` returns `0xfe`, a precompile marker, not a Solidity verifier
implementation (R19/R23).

### B. History contract, address `0x0000F90827F1C53a10cb7A02335B175320002935`

This is ordinary deployed protocol code, callable by a contract using
`STATICCALL`. Its read interface is **exactly 32 calldata bytes**, the big-endian
L2 block number, with **no four-byte function selector**. Successful output is
exactly one 32-byte hash. For an ordinary caller it requires:

```text
calldatasize == 32
n - 393168 <= k <= n - 1
return storage[k % 393168]
```

Malformed/current/future/out-of-window requests revert with empty revert data
in the observed calls. A successful zero word must not be promoted to proof
of a historical hash: range checks do not independently establish that a slot
was populated since activation. The tested slots are populated and agree with
the requested headers. Code deployment/support is established here only for
P and C, not every earlier chain upgrade boundary.

Its privileged write branch accepts only protocol system caller
`0xfffffffffffffffffffffffffffffffffffffffe`; it stores the supplied parent hash
at `(n-1) % 393168`. A user cannot call that branch by supplying a claimed
caller address. Nitro's start-block internal transaction invokes the update
before user execution. Source:
`go-ethereum/params/protocol_params.go:239-246`,
`nitro/arbos/internal_tx.go:62-87`, and
`nitro/arbos/arbosState/arbosstate.go:487-490`.

The 133-byte runtime at P and C is identical to the pinned primary-source
`HistoryStorageCodeArbitrum` constant; Keccak-256:
`0xceef1f6ad6c0cb7eb8fb15678abf11da3ce0d3a7c7106aa900c5930e556a43ff`.
R20/R24 retain the complete bytes. R51 exercises a nested ordinary
`STATICCALL` and returns success=1, returndata size=32 and P's parent hash:
this is not merely an RPC-intercepted helper.

| Executing context | Earliest allowed L2 block | Observed boundary |
| --- | ---: | --- |
| P = 108944663 | 108551495 | P-393168 succeeds; P-393169 reverts |
| C = 111330887 | 110937719 | C-393168 succeeds; C-393169 reverts |

R27-R38 and R49-R51 establish these limits and invalid inputs. At P,
P-257 and P-8192 also succeed; R39-R41 independently retrieve the corresponding
headers and match the returned hashes. The window is in **L2 blocks**.
No fixed wall-clock availability or guaranteed checkpoint interval follows
from it.

### C. EVM NUMBER and BLOCKHASH are a different domain

R22/R26 execute `0x4360005260206000f3` as read-only creation-call code and
observe the two parent-context NUMBER values in section 2. R43-R45 show:
`BLOCKHASH(26367658)` is nonzero at P, but `BLOCKHASH(P-1)` and
`BLOCKHASH(26367659)` are zero.

Source `go-ethereum/core/vm/instructions.go:416-449,462-469` routes these
opcodes through `L1BlockNumber`/`L1BlockHash`;
`nitro/arbos/tx_processor.go:960-993` reads ArbOS's parent-context storage.
`nitro/arbos/blockhash/blockhash.go:33-78` keeps a 256-parent-number ring and
fills skipped numbers with derived hashes. Consequently a nonzero BLOCKHASH
is not a general authenticated Ethereum-header oracle, and it is not an L2
receipt/state anchor. Ethereum-mainnet BLOCKHASH assumptions are inadmissible.

### D. RPC-only or absent alternatives

NodeInterface address `0x00000000000000000000000000000000000000c8` has no code
(R46). Direct RPC `blockL1Num(uint64)` returns P's parent-context number (R47),
but the same nested ordinary `STATICCALL` returns success=1 with **zero bytes**
(R48). Empty-account call success is not an ABI result. Primary source:
`nitro/execution/nodeinterface/node_interface.go:33-38,84-102`.
Its batch/confirmation/proof services are node helpers, not callable verifier
trust roots.

The Ethereum EIP-4788 beacon-root address
`0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` has no code at either pin
(R21/R25). An Ethereum beacon-root/history-proof recipe cannot be assumed
available on this child chain. ArbSys's outgoing-message accumulator is a
different commitment, not all transactions/receipts/state; its
`sendMerkleTreeState` also restricts the caller to address zero
(`nitro/precompiles/ArbSys.go`, preserved excerpt). No chain-4663 deployed
finality/light-client verifier or application history registry was authenticated
by this lane. This is not an exhaustive census of arbitrary deployed contracts.

## 4. What an authenticated completed header commits

At P the observed commitments are:

```text
stateRoot        b1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071
transactionsRoot 33c7e74b2b83169ffe7ccc0d196e7389b7edcf9da4b2aec25c442f450a5db7ab
receiptsRoot     ed4030c56b19861b12d407133d34d67e86eb659431133713cbdc126ba9f35a17
```

For both observed pins, Keccak-256 of the 16-field RLP header exactly reproduces
the reported block hash. The fields, in order, are parentHash, sha3Uncles,
miner, stateRoot, transactionsRoot, receiptsRoot, logsBloom, difficulty, number,
gasLimit, gasUsed, timestamp, extraData, mixHash, nonce and baseFeePerGas.
Integer RLP is minimal; zero is the empty byte string. This encoding is
observed for these headers, not a promise that future forks add no fields.
At P, P itself is not obtainable from the history interface until a later
block; P-1 already is. Its supplied header was hashed against the P-1
precompile response. Header hashing alone against an RPC-provided hash is not
onchain authentication.

Source `go-ethereum/core/types/block.go:68-108,125-129,249-265` defines the
header hash and transaction/receipt tries.
`nitro/arbos/block_processor.go:775-793,809-826` finalizes the block and its
end-state root. Receipt trie keys are RLP transaction indexes, **not transaction
hashes** (`go-ethereum/core/types/hashing.go:107-139`). Consensus receipt values
contain status/poststate, cumulative gas, bloom and logs; type prefixes include
Arbitrum-specific types (`go-ethereum/core/types/receipt.go:54-81,99-105,472-491`).
RPC fields such as `transactionHash`, `blockNumber`, `logIndex`, `removed` and
`gasUsedForL1` are not thereby independent consensus receipt fields.

R52/R54 provide P's two receipts, types `0x02` and internal `0x6a`. An
independent two-leaf reconstruction using keys `RLP(0)=0x80` and `RLP(1)=0x01`
exactly reproduces P's receiptsRoot. This is a concrete encoding check, not a
general receipt-proof verifier or complete attribution replay.

A future verifier could consume an authenticated header plus correctly
verified receipt/transaction/account/storage proofs. Inclusion authenticates
only what the proof covers. Complete ancestry additionally needs all relevant
ordered transitions and omission protection across every representation.
End-state storage does not encode the ordering of balance-restoring transfers.
No precompile here automatically verifies an application proof or enumerates
all relevant events.

R53's one historical `eth_getProof` request failed with code -32001,
`Unable to complete request at this time.` This records a proof-acquisition
gap, not proof that state commitments or every proof-generation route are
unavailable. Historical headers and receipts were available from the archive.
Public RPC could retrieve P's header but lacked P's historical state (R4);
the configured archive handled the historical execution calls. Availability
is separate from authentication.

## 5. Executing-block preceding history: exact boundary

**Observable:** live source calls can read state resulting from preceding
successful transactions and earlier calls in the same transaction, subject to
the source ABI. This is ordinary execution-state visibility, not access to
those transactions' complete history.

**Not exposed by the authenticated anchor surfaces above:** the executing
block's full hash, transaction/receipt prefix root, arbitrary earlier receipts,
current transaction index, or intermediate global state root. ArbSys rejects
`k=n`; the history contract rejects it too and its system update writes only
`n-1`. Final header roots are produced when block execution completes. Thus
these mechanisms cannot authenticate a caller-supplied list of preceding
same-block transfers as the actual complete prefix.

The endpoint calls were performed at completed block state. They are not
misrepresented as mined mid-block experiments. The executing-prefix conclusion
combines their observed rejection boundaries with exact source write/finalize
ordering. No owned fork was needed, and an Anvil fork's Ethereum execution
would not independently establish native Nitro block-building semantics.

An old canonical proof plus equality of selected current balances is still
insufficient for the already-demonstrated balance-restoring histories.
Authenticating block n-1 does not authenticate transfers earlier in n.
Requiring delayed custody, a pretransfer, transfer wrapping, original-payer
eligibility or a trusted fresh signature is not adopted. Nor does this finite
interface result prove all possible cryptographic constructions impossible.
Construction must supply an admissible independently established freshness
mechanism or report that exact missing capability.

## 6. Finality, reorgs and trust

The official chain configuration identifies Ethereum as parent. Arbitrum's
primary finality documentation distinguishes sequencer `latest`, parent-batch
`safe`, and parent-batch `finalized`; RPC finalization follows the parent
batch-posting block, not merely an operator signature and not the completion
of an optimistic withdrawal challenge.

R9/R10 observe distinct safe/finalized heads `111322906` / `111319239`.
R57 retrieves the latter's hash from the history contract at C, 11,648 L2
blocks later, and matches it. This authenticates the **hash**, not the
offchain claim that it is finalized. Neither consumed anchor interface returns
a finality certificate or finalized-head number. No exact delay, challenge
period or native onchain finality test for this deployment was measured, and
no Arbitrum One default is imposed on it.

A contract's direct history read is authenticated relative to the chain
execution containing that call. Normal reorgs also revert/reexecute verifier
transactions on the discarded branch; an offchain journal must follow the new
canonical branch rather than reuse orphaned checkpoints. Neither anchor
guarantees external irreversible finality for a recent sequencer block.
If a construction requires parent-finality verification, its proof and
authenticated parent trust root remain additional work, not a call to
`eth_getBlockByNumber("finalized")`.

Trust assumptions are the actual chain's consensus/execution, protocol-system
updates and governance, and cryptographic hash/proof soundness. Robinhood's
primary governance/full-node documentation describes governance and permissioned
BoLD validation; an immutable application does not remove protocol governance.
This report did not audit L1 governance or settlement contracts.
Our offchain observations additionally trust honest endpoint responses:
two providers agreeing on P and exact source/runtime checks strengthen evidence
but are not a deployed light client. A future contract reading these interfaces
directly need not trust its relayer's submitted hash. Conversely, a header,
signature or JSON supplied without that direct/proved binding remains an
assertion.

## 7. Long-offline recovery and bounded continuation

Native direct lookup expires after 256 or 393,168 L2 blocks, respectively.
Those are lookup limits, not a chain-history truncation rule. Conditional on
obtaining historical headers, a fresh anchor can authenticate older ancestry:

1. Read a recent hash from a real callable anchor and bind its L2 number.
2. For each supplied header, recompute its canonical hash, require equality
   to the expected hash and expected number, then take its committed
   `parentHash` as the next expected hash and decrement the number.
3. Persist the verified cursor between bounded batches. Stop at the exact
   Stage1 baseline and reject mismatches; a provider cannot choose a different
   ancestor without defeating the hash binding.

This is the header-link authentication argument, **not an implemented candidate
Migration verifier**. A fixed old cursor does not require continually refreshing
all historic native ring slots. Omitted headers cannot be skipped merely
because the ring moved. Authentication requires no trusted postactivation
signer or always-online checkpoint keeper. However, headers, receipts, trie
witnesses and any execution data must actually be obtainable. Commitments do
not themselves store all that data forever; this lane promises no perpetual
RPC/archive service or recovery from universally lost history.

Each finite gap has a finite number of header links, but there is no
history-independent bound on total recovery work. Concrete gas/byte/storage
limits, a forward complete replay or sound succinct proof, concurrency/reorg
handling and progress toward a moving live custody boundary are not provided
by this argument. Bounded continuation cannot silently omit transfers or impose
an expiry. Native lookup to an old checkpoint is therefore not the only
possible route, but neither an ancestor walk nor a zk/light-client name closes
the attribution-spec's six requirements.

## 8. Consumption contract for downstream work

| May rely on | Must not infer |
| --- | --- |
| Actual 4663 L2 numbering via ArbSys | Solidity NUMBER is an L2 index |
| Direct 256 / 393168 L2 hash windows, tested at P/C | Ethereum's 8191 window or permanent direct lookup |
| Header hash binding to completed transaction/receipt/end-state roots | Selected inclusion proves complete ancestry |
| Ordinary nested history STATICCALL works | NodeInterface is an onchain helper |
| Conditional parent-linked recovery of older headers | Archive availability, fixed total recovery gas, or an implemented continuation system |
| RPC tags exist and a selected tagged hash can be anchored | An onchain finality certificate or audited settlement configuration |
| Live ABI state reflects earlier execution | A complete authenticated executing-block prefix |

Missing construction capabilities are complete cross-representation transition
verification, current-prefix/custody freshness, executable bounded continuation
and its data-availability procedure, plus any stronger finality mechanism a
construction requires. This lane neither invents those capabilities nor changes
the current-owner, atomicity, category or activation constraints.

## DoneClaim

The exact anchor capability contract and bounded evidence are delivered here.
Eleven recorded cross-checks pass; expected reverts, public archive-state
failure, state-proof acquisition failure and source-resolution failures remain
preserved. No Forge compilation, test/production edit, dependency/config change,
commit, delegation, public transaction or owned local node was performed.
Only `anchors/` was written. No temporary root or port was allocated.
Final scope and cleanup observations are recorded in [verification.json](verification.json).
The JSON language server was unavailable (`biome` not installed); no clean LSP
result or installation is claimed.
