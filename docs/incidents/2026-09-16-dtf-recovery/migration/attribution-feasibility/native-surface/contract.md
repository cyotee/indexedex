# Finite ArbOS 61 native-surface capability contract

Date: 2026-11-11. Evidence only. **Result: unbound. Pinned-source result:
no-candidate. Named candidate: none. Full E2 acceptance: not established.**

## 1. Exact finding

The complete pinned registration/ABI/handler inventory contains **18 families,
191 ABI methods, 190 version-enabled methods at ArbOS 61, and 109 potentially
successful ordinary-callable methods**. Every method has an individual
address, canonical signature, selector, implementation range, version bounds,
access class, fields/return expressions and dataflow disposition in
`inventory.json`. The remaining enabled methods are 5 always-reverting ordinary
dispatches, 68 role-restricted methods, 7 debug-config-only methods and one
zero-caller-only export. One additional ABI method is inactive at 61.

**None of the 109 ordinary methods supplies an authenticated ordered
executing-prefix commitment at the caller's actual execution position.**
The negative result follows from their bodies and producer writes, not a
keyword search. The result includes methods with current values, mutations,
fees, variable-length outputs and conditional ticket access, not just `view`
functions. The rejected completed-parent/selected-observation construction is
not reopened, reprobed or proposed.

This is a complete **source-level** inventory at the exact pins below. It is
not whole-handler runtime attestation. Available actual deployment observations
bind selected ArbSys/history/opcode/helper behavior, not all native handlers,
generated ABI metadata and active configuration. Consequently this producer
does **not** claim `confirmed-no-native-prefix` for the entire deployment.
The exact deployment-level result is **unproven-binding**, rather than an
untested candidate. Section 7 identifies the finite missing binding.

No new cryptographic design, owner-policy decision, production API, build or
chain-native probe is proposed. The original E2 requirements remain unchanged.

## 2. Inputs, pins and inventory boundary

The native-surface brief, original phase06 E2 brief and complete prior
`../verification/report.md`, including sections 1.1 and 7.1, were read.
`../verification/native-surface-scope.json` is the starting registration scope.
Paths beginning `nitro/`, `go-ethereum/` or `nitro-precompile-interfaces/` below
refer to raw, unmodified files retained under `sources/` in this directory.
Their SHA-256, Git blob SHA-1 and exact retrieval URLs are in
`source-provenance.json`. All 79 archived files match their pinned Git blobs.

| Identity | Pin or observation |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2` |
| Branch/base | `work/dtf-migration-phase-06-e2` / `5021e8d4a62bcbddc555f580ef98f8666d993aab` |
| Nitro | `70fa99a6e711f09eedd96a907290c3df0f3bcf7d` |
| Nitro's Geth gitlink | `5eee8f546e7602b7deeef7909f291bbebc77e233` |
| Nitro's `contracts-local/src/precompiles` gitlink | `7e88c8cc53c2e96201a23c638f1536557b9cb68b`, repository `OffchainLabs/nitro-precompile-interfaces` |
| Historical P | Chain 4663, L2 108944663, `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Inherited additional C | L2 111330887, `0x309c2f18fbdfc1ae225dd123693dfc66157dbce50640cc0ed040198fcfe5af42` |
| Observed version | ABI result 116 at P/C; `55 + formatVersion` gives ArbOS 61 |

Branch/base were checked by reading the worktree's `.git` pointer, its HEAD
and referenced branch file, without a Git command. P and C are inherited
observations, not newly acquired pins or a funded Migration quote snapshot.

`nitro/solgen/gen.go` obtains `precompilesgen` from
`contracts-local/out/precompiles/*.sol/*.json`; registration consumes that
metadata. Its interfaces come from the **pinned interface gitlink**, not an
assumed `contracts/src` path or a current branch. No generated ABI/build
artifact was rebuilt or represented as runtime-attested.

The registration in `nitro/precompiles/precompile.go:515-701`, ABI-to-handler
checks at `:120-241`, version/call dispatcher at `:736-810`, and Geth address
constants in `go-ethereum/core/types/arbitrum_signer.go:9-30` define the finite
universe. Full method details are in `method-inventory.md` and `inventory.json`.
The latter's `body` is the actual complete handler body, not a paraphrase.
`fieldsRead` and `dataflowIds` connect each row to `dataflows.json`.

### All 18 families

Addresses below are short forms of zero-padded 20-byte addresses.
Ordinary means potentially successful without a chain/platform role; ordinary
ticket ownership, existence, expiry, value, gas and argument conditions still
apply. Enabled means **version-enabled at source**, before those conditions.

| Family | Address | ABI methods | Enabled at 61 | Ordinary potential success | Other disposition |
| --- | --- | ---: | ---: | ---: | --- |
| ArbInfo | `0x65` | 2 | 2 | 2 | Selected balance/code |
| ArbAddressTable | `0x66` | 7 | 7 | 7 | Supplied-address registry/codec |
| ArbBLS | `0x67` | 0 | 0 | 0 | Empty ABI and exported-handler set |
| ArbFunctionTable | `0x68` | 3 | 3 | 2 | `get` always reverts; others zero/no-op |
| ArbosTest | `0x69` | 1 | 1 | 1 | Caller-selected gas burn |
| ArbGasInfo | `0x6c` | 29 | 29 | 29 | Prices, fees, configuration, counters |
| ArbAggregator | `0x6d` | 8 | 8 | 6 | 2 role-restricted writes |
| ArbStatistics | `0x6f` | 1 | 1 | 1 | L2 number and five zeros |
| ArbOwnerPublic | `0x6b` | 18 | 18 | 18 | Configuration/membership, including repair |
| ArbWasm | `0x71` | 21 | 21 | 21 | Stylus configuration/program metadata |
| ArbWasmCache | `0x72` | 6 | 5 | 3 | 2 role-restricted; `cacheCodehash` inactive |
| ArbRetryableTx | `0x6e` | 8 | 8 | 7 | `submitRetryable` always reverts |
| ArbSys | `0x64` | 12 | 12 | 11 | 1 zero-caller-only export |
| ArbOwner | `0x70` | 60 | 60 | 0 | All 60 chain-owner restricted |
| ArbDebug | `0xff` | 7 | 7 | 0 | Debug configuration required |
| ArbosActs | `0xa4b05` | 3 | 3 | 0 | All 3 ordinary dispatches always revert |
| ArbNativeTokenManager | `0x73` | 2 | 2 | 0 | Native-token-owner role |
| ArbFilteredTransactionsManager | `0x74` | 3 | 3 | 1 | 2 transaction-filterer writes |
| Total | | 191 | 190 | 109 | 5 revert, 68 role, 7 debug, 1 zero-caller; 1 inactive |

The stale `Address` comment in ArbStatistics is not registration authority:
the actual Geth constants put RetryableTx at `0x6e` and Statistics
at `0x6f`. Every method selector is computed from its **Solidity ABI**, not Go
parameter spelling: for example, `setWasmMinInitGas(uint8,uint16)` and
`setChainConfig(string)` retain those signatures despite convertible Go handler
types. Nested resource constraints encode
`((uint8,uint64)[],uint32,uint64,uint64)[]`, including the enum's `uint8`.

## 3. Gates applied, rather than presumed capabilities

The dispatcher initializes method version bounds to zero, applies explicit
registration overrides and family-wide Stylus loops, and enforces min/max at
call time. `cacheCodehash(bytes32)` (`0x4ceac817`, `0x72`) has min=max=30,
so it is **not active at 61**; `cacheProgram(address)` starts at 31.
The `minInitGas` body additionally requires version >=32, satisfied at 61.
All version assignments and their exact raw-source lines are retained.
[Registration `:528-689`; `ArbWasm.go:145-153`.]

Nonpure methods require `actingAsAddress == precompile.address`; delegatecall
and callcode do not bypass that gate. Write/payable methods reject static
execution, and nonpayable methods reject nonzero callvalue. `makeContext`
requires an actual Nitro `TxProcessor`, opens state only for nonpure methods
and applies read-only metering. An ordinary Anvil EVM is not that native
runtime. [Dispatcher `:736-810`; `context.go:138-175`.]

Return encoding adds no hidden commitment source. Successful values are
ABI-packed from the handler outputs; custom errors pack only the arguments
supplied by the handler. At 61 other handler errors return no revert data.
Thus the inventory also covers reverting observations, not only successful
returns. [`precompile.go:447-495,810-865`.]

`ArbOwner`'s wrapper checks current ChainOwners membership even for getters.
Aggregator poster admission, fee-collector changes, cache writes, native
mint/burn and filter-list writes have their individual role gates. No such
role is assumed for Migration. Debug requires `ChainConfig.DebugMode()`;
the inherited advertised chain configuration says
`AllowDebugPrecompiles: false`, but is not an active-runtime attestation.
Even the inspected debug bodies return supplied data, selected old code,
errors or no data, not an executing-prefix root.
[`wrapper.go:34-51,84-140`; individual handler ranges in `inventory.json`.]

The misleading wrapper name `filtererOnly` does **not** make
`isTransactionFiltered(bytes32)` privileged. The wrapper forwards all calls;
the two write bodies enforce membership. The public getter is counted in the
109 ordinary methods. Likewise `rectifyChainOwner(address)` is counted:
it can repair an existing corrupt membership mapping, not admit an arbitrary
nonmember. [Wrapper `:151-208`; filtering handler `:26-61`;
`addressSet/addressSet.go:108-139`.]

ArbosActs' three handlers always return `CallerNotArbOS`. Actual internal
transactions are processed by `ApplyInternalTxUpdate`, not an ordinary call
with a forged sender argument. `submitRetryable` is similarly an
explorer-facing ABI that always returns `NotCallable` under ordinary dispatch.
[`ArbosActs.go:16-26`; `internal_tx.go:62-204`;
`ArbRetryableTx.go:263-270`.]

## 4. Return-data dependencies and update boundaries

The following are source observations; their exclusion as complete prefix
oracles is the bounded inference from the stated producer semantics.
`dataflows.json` supplies exact reader/writer references for every method row.

### Roots, hashes and apparently promising values

| Exact method | Selector | Producer/update point | Finite disposition |
| --- | --- | --- | --- |
| `0x64 arbBlockHash(uint256)` | `0x2b407a82` | `ArbSys.go:41-58` reads ancestor `BlockContext.GetHash`; `core/evm.go:104-138` walks completed headers | Requires `n-256 <= k < n`; executing block excluded |
| `0x64 sendMerkleTreeState()` | `0x7aeecd2a` | `ArbSys.go:223-235` exports accumulator size/root/partials | Caller must be zero; outbox sends only, not complete transaction history |
| `0x64 sendTxToL1(address,bytes)` | `0x928c169a` | `ArbSys.go:149-217` hashes caller/destination/numbers/time/value/supplied bytes, then `Append` | Returns new send index at 61, not a full-prefix root |
| `0x6e redeem(bytes32)` | `0xeda1122c` | `ArbRetryableTx.go:71-125`; `retryable.go:357-387` constructs scheduled retry transaction | Hash of that future ticket-derived transaction; not preceding execution |
| `0x74 isTransactionFiltered(bytes32)` | `0x85c733a4` | Filter state stores supplied hash => 1; authorized add/delete | Mutable filter membership, not execution/inclusion/order authentication |

Outbox `Append` increments size and folds send-leaf hashes into partials;
`Root` folds those partials. It is a real selective commitment, but an ordinary
legacy token transfer does not thereby become an outbox leaf. `withdrawEth`
uses the same send path with empty data. Nonzero value is rejected at >=41
when native-token owners exist. No voluntary instrumentation of unmodified
tokens is substituted for the missing history boundary.
[`ArbSys.go:112-240`; `merkleAccumulator.go:133-258`.]

The ordinary history-storage contract at
`0x0000F90827F1C53a10cb7A02335B175320002935` has **no four-byte selector**:
it accepts exactly one 32-byte L2 number. Its 393168-block ring also excludes
the executing block. StartBlock obtains `GetHash(n-1)` and calls
`ProcessParentBlockHash` before ordinary execution. The protocol write caller
is `0xfffffffffffffffffffffffffffffffffffffffe`, not an ordinary contract.
[`params/protocol_params.go:239-246`; `internal_tx.go:74-86`.]

The actual new block header initializes Root/TxHash/ReceiptHash to zero.
After execution, `FinalizeBlock` sets Root with `IntermediateRoot(true)`;
`NewBlock` derives transaction and receipt trie roots. These are real
completed-block commitments, not getters for the current caller's prefix.
[`block_processor.go:197-235,775-826`;
`go-ethereum/core/types/block.go:250-265`.]

### Counters, selected state, supplied inputs and configuration

All 29 ArbGasInfo methods are covered individually, including newer resource
constraints and multi-gas fees. L1 pricing fields are stored prices, parameters,
debt/payment aggregates or timestamps. Before EVM execution,
`GasChargingHook` adds compressed calldata units and computes the current
message's PosterFee; transaction end credits recognized fees. Internal batch
reports allocate units, pay debts/rewards and adjust price/surplus/time.
These are integer accounting updates, not hashes of ordered transfer effects.
[`ArbGasInfo.go:27-389`; `tx_processor.go:603-646,875-883`;
`l1pricing.go:144-515`; `internal_tx.go:115-200`.]

L2 resource backlogs grow from gas usage at transaction end, can shrink for
retryable gas donation, and decay by elapsed time at block start. Owner methods
set constraints, limits and parameters. The active model depends on configured
constraints, not just version. Current resource base fees rotate from next
fees before block execution; at 61 SingleDim uses the actual block base fee.
Weighted sums, saturation, subtraction and decay discard content/order. They
can distinguish some histories without being commitments to complete history.
[`l2pricing/model.go`; `multi_gas_constraint.go`; `multi_gas_fees.go`;
`tx_processor.go:834-920`; `block_processor.go:372-381`;
`ArbRetryableTx.go:130-158`.]

ArbInfo returns selected account balance/code. AddressTable contains supplied
address registrations; size counts those registrations, not transactions.
Compress only reads/encodes despite its nonpayable ABI. Decompress decodes
supplied bytes/index. FunctionTable is stubbed; Statistics has five zero
legacy fields. OwnerPublic/poster/cache-manager queries read configuration or
member sets, with 65536-member enumeration bounds, not a full state census.
[Individual bodies and the `account`, `addressTable`, `legacy`, `config` and
`posters` closures in `dataflows.json`.]

Stylus getters decode selected codehash activation records or packed metering
parameters. Activation records version, init cost, footprint, estimated asm
size, activation hour and cache flag for selected program code. Keepalive
updates its activation hour and byte-demand fee model; authorized cache writes
change the cache flag. A compiled module hash is code identity/event data,
not an executing-history producer. Ticket getters read the selected ticket's
beneficiary/timeout; Keepalive increments lifetime windows, Redeem increments
tries, and success/cancel/reaping can delete tickets. CurrentRedeemer reads the
current retry transaction's refund address. None authenticates the intervening
ordinary-token transfer sequence.
[`programs/programs.go:112-194,543-744`; `programs/params.go:45-258`;
`programs/data_pricer.go:63-89`; `retryables/retryable.go:73-272,315-387`;
`tx_processor.go:403-415,543-568,834-850`.]

## 5. Relevant EVM hooks and other native entrypoints

`opcode-hooks.json` enumerates these observations with producer references:

- NUMBER and BLOCKHASH invoke Nitro L1-number/hash hooks, not ArbSys's L2
  numbering. Start-block writes their backing blockhash state; skipped
  parent-number entries can be synthesized. A nonzero value does not alone
  establish an Ethereum L1 header. [Geth `instructions.go:416-469`;
  Nitro `tx_processor.go:960-992`; `blockhash.go:33-78`.]
- BALANCE/SELFBALANCE, EXTCODE operations and SLOAD/TLOAD return selected
  account/code/storage values, not a global or receipt root. GAS, GASPRICE and
  BASEFEE are frame/fee observations. Caller/origin/value/calldata/returndata
  do not add an implicit canonical history input. Block fields are established
  before ordinary execution. BLOBHASH reads message hashes; BLOBBASEFEE
  explicitly errors on Arbitrum. [Exact opcode bodies and context producers
  in `opcode-hooks.json`.]
- At source 61 the registration bridge selects the Elara/StartingFromArbOS60
  map and adds Osaka's 18 standard primitives: `0x01`-`0x11` and `0x100`.
  Their `Run(input []byte)` performs supplied-input cryptography/arithmetic/
  copying, not StateDB-prefix retrieval. They are listed separately, with no
  fictitious ABI selectors. In particular, standard BLS primitives are not
  omitted merely because the distinct ArbBLS family has an empty ABI.
  NewEVM derives Rules from the block-context ArbOS version; IsElara requires
  Arbitrum and version >=60, establishing the map choice rather than assuming it.
  [`gethhook/geth-hook.go:90-125`; Geth `contracts.go:48-55,151-173,215-226`,
  `core/vm/evm.go:145-160`, `params/config.go:1489-1495`.]
- NodeInterface `0xc8` and debug helper `0xc9` are top-level RPC interception,
  not registered ordinary native contracts. `InterceptRPCMessage` supplies
  backend/header objects outside ordinary nested EVM dispatch.
  [`node_interface.go:33-47`; `virtual_contracts.go:39-117`.]
- The expected beacon-root address has no code in the inherited P/C
  observations. It is not admitted as a missing onchain current-prefix input.
  [Inherited RPC R21/R25.]

This closes the requested registered-method/dataflow and relevant hook question.
It does not claim an exhaustive audit of arbitrary deployed application
contracts or a universal theorem about every combined observation vector.

## 6. Completeness and actual deployment observations

The inventory independently reconciles **all exported Go handler names**
against **all Solidity function declarations** for each of the 18 families,
including the empty family. It checks within-address selector uniqueness,
every explicit version-assignment name, final assignment precedence, family
gates/loops and the single maximum-version exclusion. Source-file Git blob
hashes match the pinned API trees; the original scope's three source SHA-256
values also match. The table total is not inferred from filenames.
`completeness.json` records the actual offline assertions.

There are no unclassified ABI methods and no missing ordinary-method
dispositions. The dispatcher rejects unknown selectors and inputs shorter
than four bytes; no unlisted fallback/receive capability is inferred.
ABI events and errors are not callable methods. Type widths, imported structs
and version aliases are resolved from the exact pinned sources.

Existing actual observations are retained in `deployment-observations.json`,
with original raw request/response records and IDs from `../anchors/rpc.json`:

| Evidence | What it binds | What it does not bind |
| --- | --- | --- |
| R6-R8, R11-R18 | Chain ID, L2 number, encoded version and ArbSys ancestor/current rejection | Every native family or all method branches |
| R19/R23 | `0xfe` ArbSys precompile marker | Native implementation bytecode |
| R20/R24 and R27-R38/R49-R51 | Identical 133-byte history runtime, range behavior, successful nested ordinary history call | Other native handlers or a mined Nitro mid-block prefix |
| R22/R26/R43-R45 | Parent-domain NUMBER/BLOCKHASH behavior | Current L2 prefix commitment |
| R46-R48 | NodeInterface direct helper result versus nested success with zero returndata | Ordinary contract access to RPC backend data |
| R56 versus R2 | Archive `v3.12.1+70fa99a` versus public `v3.12.4-rc.3+960ca0a` strings | Attested executable identity/equality |

The history bytecode was compared offline against the exact pinned
`HistoryStorageCodeArbitrum` constant at both observations; both match and have
Keccak-256
`0xceef1f6ad6c0cb7eb8fb15678abf11da3ce0d3a7c7106aa900c5930e556a43ff`.
This narrower binding does not attest native Go handlers. New public RPC calls,
transactions, forks and runtime probes in this lane: **zero**.

## 7. Exact unbound item and completion boundary

The missing binding is **the active native execution implementation, generated
ABI registration and configuration for chain 4663 at P/C to these source
trees**. An archive build string is not that proof. The public build's
`960ca0a` revision remains unresolved in the inherited evidence; this inventory
does not relabel archive or master source as that build.

The finite next binding check is to obtain independently authenticated
execution-revision/validation-machine provenance for those chain positions,
link it to the native handler/ABI/configuration source pins, and reconcile
any difference against the 18-family/191-method inventory. A reproducible
source-to-executable or chain-anchored execution-module linkage must include
generated ABIs and configuration, not merely repeat `web3_clientVersion`.
No such provenance is present in the admitted evidence and no build or new
environment was authorized here. Another collection of matching ordinary
queries would not by itself attest every handler.

There is **no exact candidate address/selector/update point** in the inspected
source, so no faithful native-prefix probe is admitted. If a reconciled
different implementation supplies one, it must first identify that exact
method and its commitment producer; only then would a faithful Nitro
execution through the relevant ordinary call position be a material probe.
Ordinary Anvil cannot establish these native mid-block semantics.

**DoneClaim:** finite source inventory and dispositions are complete;
source-native-prefix hypothesis has **no candidate** at these pins.
Deployment-wide closure remains **unbound / unproven-binding** for the precise
provenance item above. This is not full E2 acceptance, universal cryptographic
impossibility, or permission to change requirements. The prior failed parent
model remains rejected. Complete source transitions, caller-context handoff,
bounded continuation, long-offline recovery and atomic funded custody remain
the prior report's independent E2 obligations.

## 8. Artifacts, preservation and cleanup

Only this `native-surface/` directory is authored: this contract,
`inventory.json`, `method-inventory.md`, `dataflows.json`, `opcode-hooks.json`,
`source-provenance.json`, `deployment-observations.json`, `completeness.json`,
`commands.md`, `cleanup.json` and 79 raw source evidence files under `sources/`.
The archived `.go`/`.sol` files are evidence copies, not production/test edits.

`cleanup.json` records before/after raw-byte fingerprints of all 21 inherited
E2 evidence files. No existing evidence was overwritten. No owned fork,
listener, child, subprocess, temporary root or monitor was created; no cleanup
of another lane's processes was attempted. No Forge/Nitro build, test suite,
install, production/test/config edit, commit, delegation or public transaction
was performed. Validation is offline enumeration, hashing, JSON/ABI processing
and cross-reference checks; no unrun native-runtime or compiler check is
represented as passing.
