# ED source producer report

Date: 2026-11-12. **Custody: admitted-proposal. Conversion: not-ready.**
Source/probe work is stopped and sealed in `seal.json`. No Migration
implementation or commit was made. Independent admission is not claimed.

## 1. Delivered boundary

`contract.md` supplies the original-wallet/evidence/canonical-origin domain,
native18 Q0/Q/q mapping, known original ETH/DTF and frozen C0 requirements,
remaining-credit recurrence, exact approved custody and bounded recovery
contract. Actual pinned custody succeeds. The one investigated ED exit
fails at the disabled underlying ES after meaningful positive input; it is
not an unexecuted inference from ER.

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source`.
HEAD is `acdbe319f3a20c3af6bea594c62461b6c7988717`, branch
`work/dtf-migration-phase-19-earlier-liquid-source`.
This source-only older base is not a future cumulative implementation base.
Phase18 changing outputs were neither consumed nor edited.
Owned writes are confined to this `source/` tree, including disposable probes
and generated helper artifacts/cache. No existing test/operator, production,
dependency, configuration, held09, governance, public write, commit or merge
was performed.

## 2. Source, input, compiler and runtime bindings

| Artifact | Binding and purpose |
| --- | --- |
| `source-evidence.json` | Absolute authority/history paths, raw lengths/SHA-256, actual ED/core/ERC20 ABI, flattened source hashes/ranges and archived-runtime comparisons |
| `run-02/identity.json` | Actual pinned Anvil instance, source proxy bytes, seven selector/facet/runtime bindings and archive identity |
| `history/probe-02.ts.txt` | Exact source that executed the admitted main run |
| `probe.ts`, `run-03-control/identity.json` | Final source and separate custody-only positive-allowance/zero-balance control |
| `EdCustodyProbe.sol`, `artifacts/EdCustodyProbe.sol/EdCustodyProbe.json` | Disposable caller, actual Solar output and complete compiler metadata |
| `run-02/helper-runtime.json`, `audit.json` | Actual deployed helper bytes, source/compiler/immutable/runtime equality and raw signed receipt audit |
| `run-02/*.json`, `run-03-control/*.json` | Actual signed inputs, full raw RPC receipt objects/callTracer trees, before/after economic state and cleanup |
| `commands.md`, `history/probe-01.ts.txt`, `run-01/` | Exact invocations and preserved failed publication attempt, not relabeled success |
| `cleanup.json`, `seal.json` | Final process/port/checkpoint/scope checks and every owned evidence file's raw byte length/SHA-256 |

All source and probe execution uses chain4663/block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
There was no fresh fallback, alternate provider or new source download.
Only the existing `/bin/zsh -lc` bootstrap and configured archive alias were
used. Credentials and resolved upstream URLs were not printed or retained.

The archived ED and generic ERC20 facet byte arrays equal actual fresh pinned
runtime bytes. Both archives say `match`; their published executable bodies
match after terminal CBOR removal, not after arbitrary masking. Their archived
compiler is solc0.8.35, Prague, optimizer enabled/runs1. This is retained
source proof, not a newly rebuilt legacy contract or a full transitive audit.
Optional missing facet/source remains qualified in `contract.md`.

The disposable helper was built first with Solar
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer/runs1, no viaIR.
Forge is 1.9.1-nightly, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`; Bun is the installed1.4.2.
The helper source is 2363 bytes, SHA-256
`dbfc837a5dbe330806506853ecb89baaa939a3fe3e13af2204b739b021bd7132`.
Actual runtime is1065 bytes, Keccak
`0x52cf86d60b3174d4d222a387c06ac6e6760329612b269955ab2e9556f34fe209`,
SHA-256 `d4d7f85f4bfd5066dd23566490e9fecd09491fc38b228e933c6d7b2810e77276`.
Full runtime equality substitutes only the three compiler-declared20-byte
immutable original-address spans at offsets103,150,246; it also verifies
the compiled source Keccak against actual source bytes. No fake Migration
runtime, deployed-code injection or source-storage modification was used.

## 3. Genuine controlled custody

Synthetic original:
`0x8d86ef40df93b1b3822bf996b972ba53e79c07c9`, public development mnemonic
derivation119. Stranger derivation120 is
`0xc9db8bec097c2cbdce109e03a36f98a87e04ffef`.
All their operations were signed. Custody helper:
`0xa135e0e79d74cb641cd73c5098cedda0a04603d1`.

The actual existing EOA ED holder
`0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed` was locally impersonated only
to transfer `1000007000000000000000000` actual ED to the synthetic original.
Its code was checked empty. Both ED deltas matched.
Only native gas funding was adjusted; ED/DTF balances, roles, storage and code
were never fabricated. The donor impersonation stopped in `finally`.
This proves actual controlled acquisition, not that the development wallet
is a historical qualifying original.

Seven ED tokens, native `7000000000000000000`, were then sent to the helper
as unrelated inventory. Original eligible proof denominator
Q0=`1000000000000000000000000` was acquired separately from that budget.
No original ETH/DTF component or operational liquid allocation is inferred
from either transfer or any other NFT purchase.

| Main-run operation | Actual transaction | Observation |
| --- | --- | --- |
| Controlled acquisition | `0xee0e7e093ae221aa8944956a644707f7c08eafc5b894cea12c78639924291473` | Genuine donor debit and original credit; successful bool return |
| Missing approval | `0x89e3e04e0664161b0daee9e9a7cc81b46e628684e58eef7cbc1c9754f26d5f4a` | `ERC20InsufficientAllowance`, no economic changes |
| Wrong original caller | `0x834200c2d371dc14977102084d9029b0edc9f86a87efd39516894af0a03379db` | Helper `WrongWallet`, no source pull or economic changes |
| Approved partial | `0x0b5d07e56bca888ff256b812fe133b632bd4e1c8e2362a25c90a99a76e4e5953` | Exact debit/credit400000000000000000000000; allowance1e24 ->6e23 |
| Late-after-pull rollback | `0x54380da64903346c39d3f69a71b2492fe320bd367c5992b80bd69591e2662d4c` | Inner `transferFrom(1)` returns true; subsequent reads observe debit/credit1, then `LateFailure()` restores balances and allowance |
| Terminal | `0x1e1239e1e6fe0696b2f77b4604a4761ba5e9a6ccfc4a0d6baaca573635d795a4` | Exact debit/credit600000000000000000000000; remaining native units/allowance0 |

The custody-only fresh control proves actual insufficient balance with
allowance1, not merely a missing approval:
`0x248393e511b71ca26b967bac0ac5f9c7d16677f20736f2c0e910583bd314566e`.
Revert `0xe450d38c` encodes original wallet, balance0, required1.
The allowance spend preceding failure rolls back to1. A separately signed
clear sets it to0 before shutdown. This control executes no ED exit.

These are real-source mechanical proofs. The disposable helper has no
Migration configuration, quote book, origin registry, credit ledger or funded
bond. The C0=1001/400/601 example is arithmetic only, explicitly synthetic.
Actual integration and numerical operational originals remain unproved.

## 4. Single finite ED exit: structural disabled dependency

Exact path:

```text
signed original -> custody helper.convert(100000000000000000000000,1,1794114512,false)
helper -> ED.approve(ED,100000000000000000000000)
helper -> ED.exchangeIn(ED,100000000000000000000000,DTF,1,helper,false,1794114512)
ED -> EL.withdrawSingle(...)
EL -> ES.exchangeIn(ES,...,DTF,...,EL,false,internalDeadline)
ES -> registry.isDisabled(ES) -> true
```

The actual failing EL selector is `0x50a7e68e`; ES exchange selector is
`0xd02d3063`. The ES facet is
`0x461d94f18AfeF2C82bBffBDb63270e37c322da07`.
The actual registry query to `0x09682b00d873d913aDA0BB69b4D4c9631810D0bC`
uses selector `0x4f6c171d`, argument ES, and returns a32-byte boolean1.
Full nested arguments, outputs and revert propagation are retained, not
inferred from an ER receipt attempt. Core source cause anchors are
`UniswapV4SingleStandardExchangeDETFFacet.sol:25023-25035,25137-25174,24894-24900,25204-25236`
in the bound historical archive. The downstream true/error is an actual trace
observation; no unavailable transitive source equivalence is claimed.

Actual input is100000 whole ED tokens, not one rounding unit.
Burning is allowed; pending expansion is0.
Supply=`50292329131921480247306459955614`,
NFT-held LP=`107516722668090845797720021675152213`.
The source proportional sizing
`floor(q*nftLp/supply)=213783542190031470635423511` is positive.
The trace reaches the approved source pull and LP withdrawal. It is not an
allowance, caller, zero-input, expired-deadline or zero-LP failure.

Exact failed receipt:
`0x32fef16e3be33c26d73ab92174023ddc65be4266765a66774a54bc8b0455a9fc`,
block `0x67e5d23`, hash
`0xc35f7afef791145a1f4da457a9427a7e9efad406634e457f70f290c51d4c0602`,
status0, gasUsed `0x117fbe`, logs empty. The root, ED, EL and ES frames
propagate exactly:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
```

Custody ED stays `1000007000000000000000000`; DTF stays0; both source
allowances stay0. All six recorded accounts' ED/DTF, ED total supply and
EN-held LP match before/after. Unrelated7e18 ED and the EN reward-token
inventory remain untouched. This is rollback of the attempted source
pull/burn/unwind, not a committed burn or a successful recovery.

No successful return was decoded. The archived one-word return schema does
not turn revert bytes into amountOut. No successful late-after-conversion
rollback or DTF donation can be claimed because the source call never
completes. No parameter retry, weighted substitution, vault enablement,
infrastructure approval or alternative route followed this failure.

## 5. Validation, limitations and stop

Solar helper build and strict probe typechecks passed. The completed main
and custody-only runtime commands exited0. `audit.json` independently of
the runtime's summary parses20 raw signed transactions, verifies hash,
signer, chain, target and calldata, and checks eight status0/no-log/economic
rollbacks across those two runs. It binds complete serialized captured
receipt/trace objects and their containing raw files; those object hashes
are not presented as original HTTP transport-byte hashes.
The full helper runtime/compiler-source comparison also passes.

Failed tool registration, run-01 bigint publication failure and the initial
offline-audit syntax error remain failures in `commands.md`.
Historical unrelated source failures retain their original dispositions.
No inherited suite was replayed. There is no production-change test claim.
TypeScript editor diagnostics timed out; final strict tsc passed.
JSON LSP was unavailable; JSON was constructed, parsed and raw-hashed without
installing Biome. These diagnostic limitations are not called clean LSP.

The original-wallet/canonical-origin policy, frozen C0 evaluator and
remaining-credit rule are preserved; obsolete wallet-less, preactivation
surrender and post-use amendment text is not revived. Actual Migration
integration remains separate. Operational original datasets, opaque origins,
ER conversion, SE/LP and raw-weight constraints, archive portability and
actual parent deployment gas44,353,454 versus32million remain open.
Optional missing-facet/source and masked earlier mature-close authorization
are separate qualifications, not newly executed ED failures.

All three owned nodes exited, providers/receipt subscriptions closed, EOA
impersonations stopped, and unused control allowance cleared.
No snapshot/checkpoint was created. Port18569 is closed and no operation is
pending. Final cleanup and scope results are in `cleanup.json`; `seal.json`
binds the complete stopped producer tree, excluding its own self-reference.
Only the disjoint independent verification lane may now add its evidence.
