# Actual EOA-owner funding report

Date: 2026-11-12. **Complete bounded producer follow-up.**

E-P and W-P now have positive signed controlled-wallet source custody
fixtures, dependent on an external existing EOA owner's release and personal
donation. E-S remains not-ready because the fixed collector holds zero.
W-SW's prior independent admission is unchanged and was not replayed.
No generic-user acquisition, operational award, recovery or Migration
implementation is admitted.

## 1. Exact completed boundary

Only
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source`
was used for execution; only its
`docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources/owner-funding/`
was written. HEAD remains
`1df9076c73b94a4f63172395763fa8cdd48fe060`, branch
`work/dtf-migration-phase-20-se-lp-source`.

The complete follow-up brief, prior actual four-row producer contract/report,
independent report, holder follow-up report and raw collector owner/routing/
ordinary-caller rejection/inventory evidence were read. All prior evidence
and verdicts remain immutable. The follow-up changes only the narrow fixture
acquisition restriction for the actual existing EOA collector owner.

The node used the existing login-shell provider alias, fixed port and pin:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source && export PATH=/Users/cyotee/.foundry/bin:$PATH; exec anvil --silent --host 127.0.0.1 --port 18570 --chain-id 4663 --fork-url robinhood_mainnet_alchemy --fork-block-number 108944663'
```

Actual fresh instance:
`0xa61154ca15991d2bb84cab9460e8211c3c057ae915ea677ac92503f138a96127`.
Anvil 1.9.1 nightly commit 430523103f3e2f9ba432ffdd2031a9f966153d0d
authenticated chain4663 and historical block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The full historical header/state root and final metadata are retained.
No alternate provider, history scan, log-range request or chunking occurred.

## 2. Actual deployed authority and donor transactions

Collector `0x20af9a1e21a59a411cd3b0c40e70af9084770b2e` reports owner
`0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b`, whose code is empty.
Actual selector 0x45e94ee3 routes to
`0xF7A99a0aeD1A4252C71c99FDD2a5B3250a41f669`, runtime hash
`0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb`.
All bytes, full collector selector table and owner reads are captured.
Current manager source is explanatory only, not legacy bytecode equivalence.
The prior artifact mismatch remains a qualification.

For each positive balance, this same actual EOA owner was impersonated
only on the disposable local fork to call fixed pullFee(token,q,owner).
Each mined release has status 1 and returns ABI bool true. The second
operation is a separate personal token transfer to the controlled signer.
Both operations are **owner-impersonated donor transactions**, not evidence
of donor-key ownership or actual public donor consent.

| Row | Held collector quantity | Released | Collector remainder | Personal donation to controlled wallet |
| --- | ---: | ---: | ---: | ---: |
| E-S | 0 | not attempted | 0 | none |
| E-P | 453163036817578813953732920170 | 10020 | 453163036817578813953732910150 | 10020 |
| W-P | 1516646747724649142 | 10030 | 1516646747724639112 | 10030 |

E-P release:
`0x669d3afe10fc1e33ce2ea59896fc65fdd222294a309df0c32effa8b178730785`.
E-P personal transfer:
`0x21a2a9ce5f2ff858c9d16ec39399280fe08b921b141878b195fa49d20e2693a4`.
W-P release:
`0x557603a2a0dfe57c5acf0141fa9391e5c49603664a3b8188aac621d59f675c4f`.
W-P personal transfer:
`0x4ed29c55db8e190e7ed526216f33fa642162372123ca98cae2060906e0a438dd`.

For each release, actual collector debit equals actual owner credit q.
For each donation, owner debit equals controlled-wallet credit q; collector
balance stays fixed. Owner begins/ends with zero of these tokens.
Every donor prestate-diff trace has exactly two token storage deltas,
-q/+q, no collector storage update and no code update. Gas and nonce
changes are ordinary transaction effects. Total supplies remain unchanged:
E-S 240208335094234316503663860544238124591,
E-P 107517175831127663376533975408073383,
W-P 119195520344084872399058.

E-S's zero inventory supplies no legal positive release on this path.
No withdrawal was attempted and no substitute holder or alternate call was
used. This is a bounded not-ready result, not universal acquisition
impossibility or zero historical exposure.

## 3. Genuine controlled signatures and exact custody

Controlled derivation140:
`0xb24e6C5d01d14be3918ed712aCe1b2f7F2Bef53a`.
Other controlled derivation141:
`0xFaF513321611B74ca918dF250d6ac38d43ab57f8`.
Both derive from the disclosed public Anvil development mnemonic in
`contract.md` and `runtime.json.wallets`. Development account0 signed
actual ETH gas funding and helper deployment. No gas injection occurred.

All 34 real signed payloads have recovered matching signers, chain4663,
exact nonce/target/calldata, hash and canonical receipt. There are 20
successes and 14 intentional reverts, separate from the four impersonated
donor successes. Receipt subscriptions were acknowledged before sends and
closed in finally; no resend, sleep or receipt polling was used.

The 63-line (51 nonblank, noncomment lines) isolated Solidity witness has one custody responsibility and
two concrete hardcoded token implementations. No configurable source,
arbitrary calldata, recipient setter or generic executor exists. The
helper accepts only its immutable wallet and pulls to itself. The boolean
synthetic-record control is not a Migration eligibility gate. The source
checks are real deployed ERC20 calls, not mocked tokens.

Isolated build:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source/docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources/owner-funding/probe && export PATH=/Users/cyotee/.foundry/bin:$PATH; forge build --use solar --root . --contracts . --out build --cache-path cache OwnerFundingCustody.sol'
```

Exit 0: Compiling 1 file with Solar 0.8.38; finished in 5.05 ms;
Compiler run successful. Native Solidity diagnostics: no diagnostics found.
Both actual 874-byte runtimes equal compiler artifacts after substituting
only the five declared 20-byte wallet immutable spans:

| Row | Fixed helper | Runtime keccak256 |
| --- | --- | --- |
| E-P | `0xe65b75e7a8de220bcfec86f58c4c25a62ab7cd9b` | `0x47f2be674060003dc533cf4c8d51ae8c50b13ccab6e77f4b335605e2532f23d0` |
| W-P | `0x1fb0d426927dab092def63b73e1397b3f29e7b33` | `0x16d66023b1ea167c71f1e9e934030312208d23c868b359e8af3c1e72d0043ed3` |

The E-P helper address repeats an old disposable helper address only because
the fresh fork/deployer nonce repeats. This instance, source, wallet
immutable, bytecode hash and transactions are independently bound; no old
helper state or W-SW execution is reused.

| Operation on each newly acquired row | E-P | W-P |
| --- | --- | --- |
| Synthetic eligible Q0; excluded floor; synthetic C0 | 10007;13;1001 | 10013;17;1001 |
| Missing record, wrong wallet | Signed status0; exact helper errors and unchanged measured state | Same |
| Missing allowance | Actual source ERC20InsufficientAllowance, signed status0 | Same |
| Missing token control | Signed transfer10020 away; actual ERC20InsufficientBalance; signed transfer-back | Signed transfer10030 away; actual ERC20InsufficientBalance; signed transfer-back |
| Unsolicited inventory | Separate signed13 to custody; booked0, Q/C unchanged | Separate signed17 to custody; booked0, Q/C unchanged |
| Zero-credit dust | q1 rejected; measured state unchanged | Same |
| Finite partial | Exact debit/credit4003; Q/C6004/601; delivered400; allowance10007->6004 | Exact debit/credit4007; Q/C6006/601; delivered400; allowance10013->6006 |
| Maximum allowance | Separate signed max approval | Same |
| Late-after-pull | Actual inner pull6004 returns true, then LateFailure/status0; all measured balances, allowance, Q/C/booked restore | Same for6006 |
| Terminal | Exact debit/credit6004; delivered601; Q=C=0; allowance max-6004 | Exact debit/credit6006; delivered601; Q=C=0; allowance max-6006 |
| Final unrelated floor | custody10020-booked10007=13 | custody10030-booked10013=17 |
| Consumed record and cleanup | Further pull rejects; separate signed approval clear leaves0 | Same |

Decisive signed transaction hashes:

| Row | Finite partial | Late rollback | Maximum terminal |
| --- | --- | --- | --- |
| E-P | `0x58e0c609609e31d6e04da367f76ef21ca51c05cc3e83e1ef4511cd52666d9030` | `0x4963f6677dd3e82d0dd1413ddcab5f517fb62690da063a72d0ab2a6de3e68891` | `0xe08bab6f55dc2d8b6bc57f912cc96055ebce212cd1416b8c3b31f425b855249d` |
| W-P | `0x0b1456a070e07118e2a6e59693e10a6fba83dd93fe6014b07ef2f30169574bbc` | `0x14dc845f0fec91bd16fb8e2c22882e5c8651a915d4dc2e12744821d428084f0c` | `0x02486b52659323388840f27817836363e4d7c5611bf972f6dd21526ebf39bd60` |

Both late traces contain the fixed token's successful transferFrom with the
actual wallet, fixed helper and exact remaining q, returning uint2561
before the outer LateFailure. Their prestate diffs contain no storage
changes. Earlier maximum approvals survive. Source balances, spent
allowance and helper Q/C/booked are explicitly equal before/after.

Synthetic Q0/C0 prove bounded recurrence only, not approved historical
allocations, cost components, an actual frozen quote, issuance or bond
funding. Small safe products do not prove general production mulDiv.

## 4. Preservation and raw evidence

`runtime.json` contains:

- `domain`, `pin`, `finalMetadata`: fresh fork identity and historical header.
- `bindings`, `sourceBefore`, `sourceAfter`, `collectorAfter`: full actual
  bytecode/selector routing, owner and supply witnesses.
- `acquisition`, `donor`: exact inventory transitions, previews, mined
  receipts, transaction objects, call traces and prestate storage diffs.
- `signed`, `fixtures`: all raw signatures, canonical receipts, exact
  before/after state, negative returns, partial/terminal quantities and
  successful-inner-pull late rollback.
- `protectedBefore`, `protectedAfter`, `infrastructure`, `policy`:
  preservation of checked unrelated inventory and retained source restrictions.
- `inputs`, `preservation`, `failures`, `cleanup`: input byte/hash bindings,
  immutable prior evidence, failed read attempts and resource cleanup.

`rpc.json` retains complete JSON-RPC request objects, parsed responses and
raw response strings for this execution, including failure responses.
`seal.json` records raw file byte counts and SHA-256 for all final owned
files except itself, including reports, raw witnesses, helper source,
compiler artifacts and isolated cache. No raw signed payload or trace is
replaced by a summary flag.

Collector owner/code/full routing and all three sources' actual code/full
routing/owner bindings/total supplies match before/after. E-S owner selector
is unbound, not assigned an owner by analogy. E-P remains ED-owned, W-P
remains WD-owned; both owners have actual contract code. The checks include
the fixed historical and final E-S/E-P/W-P holdings of EL, EN, WL, ED and
WD, all unchanged. The checked collector/personal W-SW and DTF inventories
are unchanged; no W-SW transfer or custody transaction occurred. The
E-S disabled flag remains true and W-P ownerOnlyLiquidity remains true.
This is a specified checked-inventory preservation result, not an
exhaustive unrelated-token census.

The 35 original files under `source/`, `source-verification/` and
`holder-followup-root/` retain their original raw byte lengths and SHA-256.
Their membership was preserved and no prior verdict was rewritten.
Worktree index SHA-256 remains
`922910a886493195b17f66f34e0990ae1f15d3f559c017be88695a5b1316766f`.
All Git reads use GIT_MASTER=1 and GIT_OPTIONAL_LOCKS=0. Tracked and staged
diffs are empty; branch/HEAD are unchanged. No refs/indexes, production,
existing tests/operators, dependencies/configuration, held09 or changing
ED implementation outputs were changed or used.

## 5. Failures, diagnostics and cleanup

Four read/harness failures are retained, not counted as passing coverage:

1. Initial Git status without submodule suppression rejected the existing
   `lib/crane` symlink. Subsequent reads used `--ignore-submodules=all`;
   nothing about that link, submodule or index was changed.
2. A cross-cell function declaration was not persistent (`call is not
   defined`). Helpers were rebound with persistent var bindings before
   any transaction. No transaction was lost or resent.
3. An E-S owner read returned FunctionNotFound 0x23dbef4b for 0x8da5cb5b.
   Subsequent source snapshots bind the actual absent selector rather than
   inventing an E-S owner.
4. The first direct file-validation cell treated the asynchronous read helper
   as a string (`probeInspection.split is not a function`). Awaiting the
   same read corrected it. No source, transaction or evidence was substituted.

The isolated Solar build and Solidity diagnostics passed. JSON Biome LSP
is unavailable; no installation or configuration change was permitted or
performed. Direct parsing validates both persisted JSON documents and all
1141 raw response strings; all 34 persisted raw signatures were independently
recovered again and their hashes and chain4663 checked. No production build or existing
test/operator suite was run or claimed.

The owned node session `bash_4`, PID 83130, was stopped by kill_bash,
completion exit 0. Subsequent ps/lsof reads show no such PID or
127.0.0.1:18570 listener. Both owner impersonation windows have explicit
stop RPCs. All receipt subscriptions closed; open count 0. No persistent
provider was created. Readiness and isolated-build monitors completed,
exit 0. No checkpoint was created; the optional
`.omo-runtime/dtf-migration-se-lp-sources/checkpoints` path is absent.
Both source allowances were cleared by separately signed transactions.
Local custody is discarded fork state, not a pending public action.
No owned runtime, subscription, impersonation, checkpoint or source/probe
change remains pending at sealing.

## 6. Final qualified disposition

**E-P/W-P: admitted-proposal only for owner-donation-dependent, signed
exact native18 source custody-and-hold. E-S: not-ready, zero fixed-collector
inventory. W-SW: prior independent admission retained, not replayed.**

The previous ordinary-caller acquisition and blocked recovery observations
remain valid and were not replayed for extra coverage. Source owners ED/WD
were never impersonated. LP possession does not grant their permissions.
There is no source enablement, conversion, liquidity exit, liquidation probe,
generic executor or award approval.

Operational original datasets/components, canonical/opaque origins, actual
Migration integration and atomic funded fresh90-day bonds, recovery routes,
archive source qualifications, portability and target gas remain separate
open gates. The retained 44,653,392-gas parent exceeds 32,000,000; no gas
solution or remeasurement is claimed. Independent follow-up verification
and root's reading of the actual qualified admission remain required
before any production integration.
