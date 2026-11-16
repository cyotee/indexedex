# Independent native-prefix surface verification

Date: 2026-11-11. **Verdict: unproven-binding.**

## 1. Decisive result and exact scope

The producer's scoped conclusion is supported. Independent enumeration and
handler inspection found **no ordinary-contract-callable native method that
authenticates an ordered executing prefix at the caller's actual execution
position in the inspected source**. This covers all 18 registered ArbOS
families, 191 interface-declared methods, their version gates at ArbOS 61,
the 18 additional standard primitives, and the relevant native/EVM hooks.
There is no candidate address, selector and prefix-producing update point
that warrants a new execution probe.

The deployment-level answer remains **unproven-binding**, not a deployment-wide
negative. The admitted evidence does not authenticate the active chain 4663
execution implementation, generated ABI registration and configuration at
P/C to the inspected source trees. The archive and public services advertise
different client revisions. Matching selected calls and history-contract
bytecode does not attest every native Go handler. This is the precise
remaining limitation, not a reason to repeat the rejected parent model.
[Audit: `bindingChecks`, `sourceHashes`, `methodReview`; sections 2-6 below.]

No source-inventory omission or contrary eligible commitment was found.
The producer's 109 ordinary / 5 always-reverting / 68 role-restricted /
7 debug-config / 1 zero-caller enabled-method partition is independently
reproduced; one further method is inactive at version 61. "Ordinary" means
potential success without a platform role, not success for every argument,
ticket, program, gas budget, value or static-call context.

This result rejects an alleged native prefix oracle **in this finite pinned
source surface**. It neither proves arbitrary E2 mechanisms impossible nor
selects a policy relaxation. It is not an audit of arbitrary application
contracts, every possible combined observation vector, or all Stylus host
internals. No owned runtime was started or remains pending.

## 2. Inputs, provenance and independent checks

All paths below are relative to the phase06 evidence prefix
`docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility/`
inside `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2`.
The task's base is `5021e8d4a62bcbddc555f580ef98f8666d993aab`; this verifier
performed no Git operation or independent HEAD attestation.

Read the complete native-surface brief and original phase06 brief, complete
`verification/report.md` including sections 1.1 and 7.1,
`verification/native-surface-scope.json`, producer `native-surface/contract.md`,
the complete machine-readable method inventory, dataflow and opcode records,
and the actual pinned interfaces, registration, handlers and relevant
producers. Runtime interpretation uses actual inherited
`anchors/rpc.json` requests/responses, not just producer summary labels.
No settled balance witness was executed again.

Source notation:

- `N:` means `native-surface/sources/nitro/`.
- `G:` means `native-surface/sources/go-ethereum/`.
- `I:` means `native-surface/sources/nitro-precompile-interfaces/`.
- `V:` means this `native-surface-verification/` directory.
- `R<n>` means request ID `<n>` in `anchors/rpc.json`, not an array offset.

| Item | Exact pin |
| --- | --- |
| Nitro | `70fa99a6e711f09eedd96a907290c3df0f3bcf7d` |
| Geth gitlink | `5eee8f546e7602b7deeef7909f291bbebc77e233` |
| Precompile-interface gitlink | `7e88c8cc53c2e96201a23c638f1536557b9cb68b` |
| Historical P | Chain 4663, L2 108944663, `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Inherited additional C | L2 111330887, `0x309c2f18fbdfc1ae225dd123693dfc66157dbce50640cc0ed040198fcfe5af42` |
| ArbOS observation | R12 at P and R8 at C return 116; `ArbOSVersion()` adds 55, hence source version 61 |

I independently fetched all three exact pinned Git trees. Their responses
were HTTP 200 and nontruncated. All **79** producer source copies match both
their recorded SHA-256 and independently fetched pinned Git blob identities.
The Nitro tree independently supplies both gitlinks. The three original
scope-file SHA-256 values also match. One additional pinned file,
`G:core/state_processor.go`, was fetched, blob-checked and archived only at
`V:sources/go-ethereum/core/state_processor.go` to close the history
system-writer edge. These checks establish source provenance, not execution
attestation. Relevant raw tree entries, response digests and exact retrieval
URLs are in `audit.json`; the full existing source copies remain untouched.

Independent structural checks, all with no mismatch:

| Check | Result |
| --- | --- |
| Actual metadata registration names versus family inventory | 18/18, including empty ArbBLS |
| Solidity function declarations versus exported Go receivers | 191/191; no missing or extra handler |
| Canonical signatures, selectors, input/output type shapes, mutability and addresses | 191/191 match |
| Inventory handler bodies versus complete referenced source ranges | 191/191 match |
| Selector uniqueness within each address | All 18 families pass |
| Explicit version assignments, aliases, family gates, loops and final precedence | 65 assignments reconciled; 190 enabled |
| Independently classified access/disposition versus producer rows | 191/191 agree |
| Osaka primitive map and actual `Run` bodies | 18/18 covered |
| History runtime versus pinned Arbitrum constant | Both P/C match, 133 bytes |

Selectors were recomputed from independently extracted Solidity declarations
using the existing linked ABI utility, not copied from the producer.
Nested resource types resolve to
`((uint8,uint64)[],uint32,uint64,uint64)[]`; the enum is `uint8`.
ABI widths and strings were preserved rather than inferred from convertible
Go types. For example, `setWasmMinInitGas(uint8,uint16)` and
`setChainConfig(string)` are the ABI signatures.
[I:ArbMultiGasConstraintsTypes.sol:14-44;
N:precompiles/ArbOwner.go:440-447,520-565.]

**Generated-ABI limit:** the 191 count is a complete interface-source/handler
reconciliation, not direct inspection of a deployed generated metadata blob.
The Nitro tree contains no `solgen/go/precompilesgen` entries.
`N:solgen/gen.go:225-250` reads compiled
`contracts-local/out/precompiles/*.sol/*.json` artifacts, while
`N:precompiles/precompile.go:120-241` consumes and checks generated metadata.
No such build was run here. The expected source ABI is well specified; the
actual executable registration remains part of the binding gap.

## 3. Complete family accounting and exclusion challenges

Short addresses below are zero-padded to 20 bytes in `audit.json`.
Its `methodReview` contains every individual signature, selector, address,
version, ABI/handler locator, access decision, return expressions and semantic
closure group. Each group points to inspected primary writer/dataflow ranges;
classification is source reasoning, not a semantic proof from counting rows.

| Family | Address | Methods | Enabled | Ordinary | Remaining methods |
| --- | --- | ---: | ---: | ---: | --- |
| ArbInfo | `0x65` | 2 | 2 | 2 | None |
| ArbAddressTable | `0x66` | 7 | 7 | 7 | None |
| ArbBLS | `0x67` | 0 | 0 | 0 | Empty interface and handler set |
| ArbFunctionTable | `0x68` | 3 | 3 | 2 | 1 always reverts |
| ArbosTest | `0x69` | 1 | 1 | 1 | None |
| ArbGasInfo | `0x6c` | 29 | 29 | 29 | None |
| ArbAggregator | `0x6d` | 8 | 8 | 6 | 2 role-restricted |
| ArbStatistics | `0x6f` | 1 | 1 | 1 | None |
| ArbOwnerPublic | `0x6b` | 18 | 18 | 18 | None |
| ArbWasm | `0x71` | 21 | 21 | 21 | None |
| ArbWasmCache | `0x72` | 6 | 5 | 3 | 2 role-restricted; 1 inactive |
| ArbRetryableTx | `0x6e` | 8 | 8 | 7 | 1 always reverts |
| ArbSys | `0x64` | 12 | 12 | 11 | 1 zero-caller |
| ArbOwner | `0x70` | 60 | 60 | 0 | 60 role-restricted |
| ArbDebug | `0xff` | 7 | 7 | 0 | 7 debug-config |
| ArbosActs | `0xa4b05` | 3 | 3 | 0 | 3 always revert |
| ArbNativeTokenManager | `0x73` | 2 | 2 | 0 | 2 role-restricted |
| ArbFilteredTransactionsManager | `0x74` | 3 | 3 | 1 | 2 role-restricted |
| Total | | 191 | 190 | 109 | 81 enabled exclusions; 1 inactive |

Primary enumeration authority is `N:precompiles/precompile.go:515-701` and
`G:core/types/arbitrum_signer.go:9-30`. Comments are not address or behavior
authority: Statistics' stale Go address comment differs from registration;
FunctionTable interface comments misdescribe upload/get, while actual bodies
make upload a no-op and get an error. The producer correctly follows bodies.
[N:precompiles/ArbStatistics.go:14-25;
I:ArbFunctionTable.sol; N:precompiles/ArbFunctionTable.go:18-31.]

The following challenges cover every exclusion class and the easily
misclassified public methods:

| Challenge | Primary result |
| --- | --- |
| Can a delegatecall/callcode obtain native privileges or a hidden fallback? | Nonpure methods require the actual precompile execution address. Unknown/short selectors revert; write methods reject static execution and nonpayable methods reject value. `makeContext` requires Nitro's TxProcessor. N:precompiles/precompile.go:736-810; context.go:138-175. |
| Is `cacheCodehash` merely deprecated but still usable at 61? | No: minimum and maximum are 30. `cacheProgram` begins at 31. Both family minima are 30. The body-level `minInitGas` threshold is 32 and satisfied at 61. N:precompiles/precompile.go:566-587; ArbWasm.go:145-153. |
| Can ordinary callers use owner getters? | The wrapper checks ChainOwners before every method, including views. All 60 are excluded from ordinary Migration authority. N:precompiles/wrapper.go:84-133. |
| Are the other eight role exclusions real rather than names? | Aggregator add requires owner and fee-collector change requires poster/collector/owner; cache writes require cache manager/owner; mint/burn require NativeTokenOwners; filter writes require TransactionFilterers. N:precompiles/ArbAggregator.go:42-92; ArbWasmCache.go:50-78; ArbNativeTokenManager.go:29-62; ArbFilteredTransactionsManager.go:26-61. |
| Does `filtererOnly` exclude the getter? | No. The wrapper forwards calls and adjusts gas charging. `isTransactionFiltered` is public and counted. It reads a supplied-hash membership bit, not an execution proof. N:precompiles/wrapper.go:151-199; ArbFilteredTransactionsManager.go:54-61; arbos/filteredTransactions/state.go:26-65. |
| Does public owner repair grant arbitrary owner access? | No. `RectifyMapping` first requires existing membership, then repairs the mapping. The public method is still counted among the 109, without assuming it succeeds on an already-correct mapping. N:precompiles/ArbOwnerPublic.go:26-31; arbos/addressSet/addressSet.go:108-139. |
| Could debug export an otherwise hidden root? | Wrapper requires DebugMode; advertised chain configuration says false, but is not active-runtime attestation. Even inspected debug bodies expose supplied values, selected old code, errors or mutations, not a prefix root. N:precompiles/wrapper.go:34-51; ArbDebug.go:28-76. |
| Can a forged ArbOS caller activate internal methods? | All three ordinary ArbosActs handlers unconditionally return CallerNotArbOS. Internal processing is a separate protocol path. N:precompiles/ArbosActs.go:16-26; arbos/internal_tx.go:62-204. |
| Is retryable submission an ordinary native transaction factory? | Its explorer-facing method unconditionally returns NotCallable. Cancel's beneficiary restriction is a ticket condition, not a platform role; cancel stays in the ordinary count. N:precompiles/ArbRetryableTx.go:225-270. |
| Is the outbox export available through a normal nonzero contract? | `sendMerkleTreeState` requires caller zero. A direct default-from-zero RPC simulation does not confer that power on Migration. It also commits only sends. N:precompiles/ArbSys.go:223-235. |
| Could error bytes disclose an unlisted root? | Custom errors encode handler-supplied arguments; other handler errors at 61 return no revert bytes. Success packs handler outputs. No generic root is appended. N:precompiles/precompile.go:447-495,810-865. |

## 4. Candidate and dataflow challenges

### 4.1 Actual commitments and hash-shaped outputs

| Surface | Update point and exact exclusion |
| --- | --- |
| `0x64 / 0x2b407a82`, `arbBlockHash(uint256)` | Requires `n-256 <= k < n`; reads `BlockContext.GetHash(k)`, whose implementation follows parent headers. It rejects the executing block, so an authenticated old block is not a caller-position prefix. N:precompiles/ArbSys.go:41-58; G:core/evm.go:104-138. |
| `0x64 / 0x7aeecd2a`, `sendMerkleTreeState()` | Exports size/root/partials only for caller zero. `Append` hashes supplied send leaves and folds partials; it is a real ordered selective accumulator, not all execution. N:precompiles/ArbSys.go:223-235; arbos/merkleAccumulator/merkleAccumulator.go:133-258. |
| `0x64 / 0x928c169a`, `sendTxToL1(address,bytes)` and `withdrawEth(address)` | Send hash includes caller, destination, L2/L1 numbers, time, value and supplied bytes. Append occurs in this call; return at 61 is the leaf index. Ordinary token transfers are not automatically leaves. Sending a caller-chosen purported history root authenticates only that it was sent. N:precompiles/ArbSys.go:112-240. |
| `0x6e / 0xeda1122c`, `redeem(bytes32)` | Increments selected ticket tries and constructs a future retry transaction from ticket fields, chain ID, nonce, fees, donated gas and refund caller. The returned hash is that transaction's identity, not preceding execution. N:precompiles/ArbRetryableTx.go:71-158; arbos/retryables/retryable.go:357-387. |
| `0x74 / 0x85c733a4`, `isTransactionFiltered(bytes32)` | Reads whether a supplied hash has a filter bit. Authorized writes and cleanup can change it. Membership does not certify execution, inclusion, ordering, or completeness. N:arbos/filteredTransactions/state.go:26-65. |
| History storage `0x0000F90827F1C53a10cb7A02335B175320002935` | No four-byte selector: exactly a 32-byte L2 height. Ring is 393168 preceding hashes and excludes current. StartBlock obtains `GetHash(n-1)`; ProcessParentBlockHash calls from the system address using those bytes. N:arbos/internal_tx.go:74-86; G:params/protocol_params.go:239-246; V:sources/go-ethereum/core/state_processor.go:340-369. |
| Header state/transaction/receipt roots | New header initializes those fields to zero. After transaction processing, FinalizeBlock calls IntermediateRoot and NewBlock derives transaction/receipt roots. No inspected ordinary method reads a live all-execution root at call position. N:arbos/block_processor.go:197-235,748-790,809-826; G:core/types/block.go:250-265. |

Outbox leaves, retry transaction hashes and history hashes are not dismissed
because they look unfamiliar or have restrictive names. Their concrete
producer inputs exclude the required intervening ordinary-token execution.
Even granting access to outbox export would not repair that completeness
gap. No new witness is needed to distinguish those producer domains.

### 4.2 Every other ordinary output class

All 29 ArbGasInfo handlers were inspected, including variable-length resource
constraints and multi-gas base fees. GasChargingHook adds compressed message
units and computes PosterFee before EVM execution. Transaction end credits
recognized L1 fees and grows gas backlogs. Batch reports allocate units,
settle debt/rewards and adjust surplus/price/time; block start decays backlog.
Multi-gas constraints combine resource usage by weighted, saturating
arithmetic. Current fees rotate from next fees before execution. These are
genuine live observations, but their update rules do not commit ordered
transaction/effect content. In particular, a resource named HistoryGrowth
is a usage dimension, not a history hash.
[N:precompiles/ArbGasInfo.go:27-389;
arbos/tx_processor.go:603-646,834-920;
arbos/l1pricing/l1pricing.go:119-316,320-515;
arbos/l2pricing/model.go:39-150,185-260;
multi_gas_constraint.go:79-178; multi_gas_fees.go:38-68;
arbos/block_processor.go:372-390.]

Account readers return selected balance/code; StateDB has internal root and
transaction-index facilities, but these readers do not expose them.
AddressTable stores explicitly registered addresses and supplies RLP/index
codecs. Its size counts registrations. Legacy tables/statistics are
zero/no-op/error values apart from Statistics' L2 number. Poster lists and
public owner information expose configuration or membership, not a full
account/history census. Public repair and legacy setter no-ops were not
incorrectly removed from ordinary coverage.
[N:precompiles/ArbInfo.go:19-37;
arbos/addressTable/addressTable.go:34-126;
precompiles/ArbFunctionTable.go:18-31; ArbStatistics.go:18-25;
ArbAggregator.go:25-109; ArbOwnerPublic.go:20-130;
G:core/state/statedb.go:380-465,498-565.]

Stylus values come from packed metering parameters or selected codehash
activation records: version, costs, footprint, assembly size, activation
hour and cache flag. Activation records those fields; keepalive updates
activation time and a byte-demand fee model; authorized cache operations
change cache state. A module hash identifies compiled code, not the current
execution history. Returned fields and error arguments do not conceal a
global history commitment.
[N:precompiles/ArbWasm.go:35-245; ArbWasmCache.go:15-78;
arbos/programs/programs.go:112-194,543-744;
params.go:70-182; data_pricer.go:63-89.]

Retryable queries and changes operate on selected-ticket state. Creation
stores from/to/value/data/beneficiary; timeout windows and tries change;
cancel, successful redemption or reaping deletes the ticket.
CurrentRedeemer returns the current retry's refund address. Caller alias,
depth, block/chain/version and constant storage-gas results add context,
not a native prefix authenticator.
[N:arbos/retryables/retryable.go:73-272,315-387;
arbos/tx_processor.go:403-415,543-568,834-850;
precompiles/ArbRetryableTx.go:161-260; ArbSys.go:35-109,243-246.]

These exclusions do not assert that all histories yield equal fee, balance
or gas vectors. The prior report already identifies unequal whole-state
observations in its witness. A distinguishing scalar is not itself an
authenticated complete-prefix commitment.

## 5. Other native paths and EVM hooks

At source ArbOS 61, NewEVM derives Rules from the block context's ArbOS
version; IsElara requires Arbitrum and version >=60. The selected map is
StartingFromArbOS60. Nitro populates it with all 18 ArbOS families and Osaka's
18 standard primitives, at `0x01` through `0x11` plus `0x100`.
[G:core/vm/evm.go:149-160; params/config.go:1489-1495;
params/config_arbitrum.go:51-65; core/vm/contracts.go:151-173,215-226;
N:gethhook/geth-hook.go:71-121.]

The standard entries are ecrecover, SHA-256, RIPEMD-160, identity, modular
exponentiation, three BN256 operations, Blake2F, KZG point evaluation, seven
BLS12-381 operations, and P256 verification. Each actual Run body was read,
including the BN256/point-codec helpers. They calculate over supplied bytes
and cryptographic constants; none receives a live EVM prefix root. KZG proves
an evaluation relative to the supplied commitment/hash, not that commitment's
canonical execution position. Empty ArbBLS does not omit standard BLS.
[G:core/vm/contracts.go:151-173; exact Run ranges in
`audit.json` `standardPrimitives`.]

| Hook or helper | Independent result and primary evidence |
| --- | --- |
| NUMBER / BLOCKHASH | Call Nitro L1-number/hash hooks. StartBlock updates the backing ring; skipped parent-number entries can be synthesized using the preceding L2 hash. Neither gives current L2 execution-prefix semantics. G:core/vm/instructions.go:416-469; N:arbos/tx_processor.go:960-992; arbos/blockhash/blockhash.go:33-78; arbos/internal_tx.go:88-104. |
| BALANCE / SELFBALANCE / EXTCODE operations | Selected account scalar or code identity, not a global state root. G:core/vm/instructions.go:255-260,330-405; eips.go:96-99; core/state/statedb.go:380-445,498-565. |
| SLOAD / TLOAD | Selected storage at the executing contract's address and supplied key; no arbitrary StateDB-root getter. G:core/vm/instructions.go:511-525; eips.go:204-219. |
| GAS / GASPRICE / BASEFEE | Frame budget, paid message price or block fee, not ordered effects. G:core/vm/instructions.go:407-414,568-571; eips.go:223-226; N:arbos/tx_processor.go:1022-1035. |
| Origin/caller/value, calldata/returndata, code, memory, PC | Current frame/message and selected call results; no implicit authenticated history input. G:core/vm/instructions.go:250-367,492-509,558-565; core/evm.go:93-100. |
| Timestamp/coinbase/gas limit/randomness/chain ID | Block context or configuration established before ordinary execution, not a current prefix. G:core/evm.go:42-90; core/vm/instructions.go:452-484; eips.go:113-117; N:arbos/block_processor.go:197-235. |
| BLOBHASH / BLOBBASEFEE | Message blob hashes by supplied index; BLOBBASEFEE explicitly errors on Arbitrum. G:core/vm/eips.go:275-293. |
| NodeInterface `0xc8`, debug helper `0xc9` | Top-level InterceptRPCMessage injects backend/header state. These are not entries in the ordinary native map. Direct RPC success is not contract-callability. N:execution/nodeinterface/node_interface.go:33-47; virtual_contracts.go:39-117. |
| Expected beacon-root contract | R21/R25 return no code at P/C. No deployed prefix input is established there. This observation is not an arbitrary-contract absence proof. |

## 6. What is bound, what is not, and the finite next check

R8/R12 establish the provider-observed encoded version. R14-R18 show ArbSys's
ancestor/current boundaries. R20/R24 return identical history code matching
the exact pinned Arbitrum constant; its Keccak-256 is
`0xceef1f6ad6c0cb7eb8fb15678abf11da3ce0d3a7c7106aa900c5930e556a43ff`.
R27-R38 and R49-R51 corroborate its historical range and format. R51 executes
a nested STATICCALL in creation-style `eth_call`, returning success, 32-byte
returndata and the parent hash. R48's analogous NodeInterface call returns
success with zero returndata, whereas R47's direct RPC request returns data.

These are **provider simulations**, not a deployed Migration call or a mined
Nitro mid-block experiment. They are useful evidence of nested-call behavior
but do not demonstrate the requested fresh prefix. ArbSys's `0xfe` marker in
R19/R23 is not native implementation bytecode. History bytecode matching is
also narrower than attesting the ArbSys handler it calls.

R56 advertises archive build `v3.12.1+70fa99a`; R2 advertises public build
`v3.12.4-rc.3+960ca0a`. Neither string authenticates a source-to-executable
mapping or proves what code governed historical P. The public revision has
not been reconciled to this inventory. The advertised chain-info setting
`AllowDebugPrecompiles: false` likewise is not a cryptographically bound
active configuration. Git-tree equality authenticates the inspected bytes
to the reported source pin under the source-service provenance model, not
to chain execution.

The **finite missing check** is authenticated execution-revision or validation
machine provenance for P/C, connected to the actual generated precompile
metadata, handlers, Geth hook implementation and active chain configuration.
Reconcile any resulting source difference against this exact inventory.
An independently authenticated reproducible executable/validation-module
linkage may supply that connection; a new clientVersion response or a list
of matching calls alone cannot. No such linkage exists in the admitted
evidence, and no build or new environment was authorized.

There is therefore no pending candidate runtime proof. A different reconciled
implementation would first have to identify an exact callable selector and
prefix-producing update point. Only then could faithful Nitro execution at
the actual ordinary call position be a material additional check. Ordinary
Anvil cannot establish that native binding, and no new Anvil or Nitro
environment was started.

## 7. Original E2 obligations and completion

The completed-parent plus selected-observation construction remains rejected;
this verification neither repeats nor rehabilitates it. The finite source
inventory does not establish the remaining E2 construction obligations:

- Authenticated canonical history through the actual pre-custody position,
  including preceding transactions and earlier execution within the custody
  transaction.
- Complete, source-specific origin/representation transitions, disjoint
  correlated claims, proportional consumption, and replay/domain protection.
- Bounded continuation and long-offline recovery without expiry.
- Permitted source-caller handoff and one-operation custody, consumption and
  fresh funded bond, with atomic failure.

All original categories and no-policy-relaxation constraints remain binding.
No minimum owner relaxation follows from the native-surface absence finding.
The independent finite capability task is complete with **unproven-binding**;
E2 and affected implementation readiness remain open.
[Original phase06 brief; complete prior `verification/report.md`, sections
1.1, 5-7.1.]

## 8. Preservation, validation and cleanup

Authored only `V:report.md`, `audit.json`, `commands.md`, `cleanup.json`, and
the one additional raw primary-source copy beneath `V:sources/`. Existing
producer and prior evidence is preserved; `cleanup.json` contains before/after
fingerprints for all 110 inherited evidence files, including the hidden
`.gitmodules` source copy.

Validation consists of the independent source/ABI/version/selector/body
reconciliation above, actual existing RPC result inspection, JSON parsing,
and preservation checks. No production/test edit, Forge/Nitro build, test
suite, install, Git operation, commit, delegation, public transaction, fork,
listener, child, monitor or temporary root was created. No runtime cleanup
was required and no owned runtime is pending.

The tool reported that gopls and Biome are not installed. No LSP-clean result
is claimed and no installation was attempted. The archived Go file is an
unchanged pinned evidence copy, not compiled project code; JSON validation
uses actual parsing. `commands.md` records the operations, results and small
inspection corrections rather than inventing build/test exit codes.
