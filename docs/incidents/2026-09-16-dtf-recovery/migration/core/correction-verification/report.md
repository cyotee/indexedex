# Independent corrected-core verification

Date: 2026-11-10.

**AdversarialVerify: confirmed**, for the corrected bounded phase04 core.

**F1: confirmed corrected.** The former 100-token anchor / 1-token other
selection now rejects with the exact other-leg error and restores observable
capital state. Canonical equality, excess, alternate-anchor and six-decimal
boundaries execute successfully or reject as required.

**V1: confirmed closed as an execution-evidence gap.** Both installed bond
donation selectors execute through genuine production proxies and genuine
Permit2 at the production canonical address. Full runtime identity, correct
cached and changed-chain domains, positive transfers, nonce/allowance effects,
and isolated negative rollback are independently verified.

There is no remaining F1/V1 correction blocker. This does **not** complete
Migration, close E1/E2 or the other full-plan gates, certify actual legacy
compatibility, or authorize a public deployment, funding, activation or
compensation operation. The original underfunding success remains a defect
witness, and the original missing-canonical-Permit2 transaction remains a
failed donation, not a pass.

## 1. Scope, independence and evidence

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
The recorded implementation base is
`6e27ecaa242c4acca132e3575a160514aad07b11`; this verifier did not run Git.

Read the complete correction brief, original phase04 brief, original
Migration implementation/test plan, accepted phase03 egress r3 and its
verification, ownership/bootstrap handoff, current repository rules and
applicable canonical deployment/testing/adversarial skills. Read the complete
current `../verification/report.md`, actual preserved F1 witness/log and V1
failed-transaction evidence, `../correction/report.md`, the current correction
sources/tests, their production callees, and the corrected execution receipts.

The independent executions use the producer's inspected existing test
contracts, not a copied SUT or an independently invented deployment model.
Execution, trace interpretation, before/after comparisons, artifact hashing,
runtime reconstruction, and receipt/event reconciliation were performed here.
The 83-test focused run, 10,102-test combined run and corrected two-stage
local broadcast were **audited saved executions**, not broadcasts or large
suite reruns performed by this verifier.

All authored evidence is in this directory:

| File | Independent evidence |
| --- | --- |
| `artifact-source-binding.json` | Recomputed SHA-256 and Keccak source identities, artifact identities/metadata, historical preservation and reviewed-source deltas. |
| `execution-evidence.json` | Exact independent commands, 24 case locators, reconstructed Permit2 identity, positive/negative observations and before/after state reads. |
| `runtime/f1-v1-full-trace.log` | Complete independent Solar build/test trace: 24 passed, 3 suites, 0 failed/skipped, exit 0. |
| `corrected-receipt-audit.json` | Independently counted corrected regressions; reconciled 246 mined receipts; decoded events/transfers; reconstructed facet/package/library hashes; clocks, selectors and conservation. |
| `cleanup-and-preservation.json` | Completed runs, no owned node/listener, empty TMPDIR removed, no source/artifact/historical drift. |

Trace SHA-256:
`731ba02b9e2c36a661acecf7bb149237b6f5ca50f7b8f39a70ea6254f4714333`.
It contains 46,915,043 bytes. Case start/end line numbers and selected
observations are indexed in `execution-evidence.json`; the full trace is
retained rather than replaced by excerpts.

Repository-relative source prefixes:

- **M**: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- **D**: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- **C**: `contracts/vaults/detf/common/`
- **TM**: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- **K**: `lib/crane/contracts/`

No source/test fix, shared dependency/configuration edit, commit, delegation,
extra panel or public action was performed.

## 2. F1: actual correction and independent execution

### Source disposition

`M/UniswapV4DetfMigrationAllocationTarget.sol:26-34,168-187` now inherits the
ordinary target to call the actual `_firstBondOtherPayment`. For every
non-anchor it compares the pre-conversion pair equivalent against the
canonical payment for the self amount actually generated from the anchor.
The rejection is strictly `<`; equality and adequate excess are admitted.

The canonical helper at `D/UniswapV4DetfTarget.sol:854-859` reads the configured
opening price with creation-price fallback, applies
`Math.mulDiv(detf, opening, 1e9)`, then the existing native-decimal conversion.
It is also used by ordinary full-book first-bond acquisition at
`:650-674` and the parent's public first-bond payment preview. Production
does not duplicate its formula, change rounding, add a cap/haircut, require
an exact balance, or introduce a price/configuration setter.

`_genesisPreview` and `_convertGenesis` in the same allocation target preserve
the pre-conversion book and measured-consumption check. Raw pair input uses
the consumed payment after the previewed refund, while direct SE shares use
the public canonical pair-equivalent quote. A late-leg failure propagates
through the external bootstrap call, reverting earlier SE conversion and
approval effects. Earlier successful donation transactions remain booked.

The widened inheritance explicitly preserves all five Migration dispatches:
pending expansion, realized expansion, mint admission, residual balance and
dust sweep. The installed allocation facet still declares exactly the five
administration selectors; inherited methods are not automatically installed
on the proxy.

Current allocation-target SHA-256:
`4f56ac1d008cee074b9f6a2660b41c30f894d4645f890fe743e1c8f73e1b563e`.

### Independent boundary results

All nine cases executed through the real shared TestBase, CREATE3 facets,
manager registry packages, real V3 SEs/pools and real weighted reserve.
No parent impersonation, SUT subclass, storage injection, SUT etch or fake
reserve was used.

| Selection / independent oracle | Actual result |
| --- | --- |
| 100e18 anchor, 1e18 other; public parent preview requires 100e18 other | Exact `InvalidGenesisLeg(otherPair)`; parent remains inert, self supply and receipt funding remain zero, donated 100/1 inventory survives unchanged. |
| 100e18 anchor, canonical other minimum minus one native unit | Same atomic rejection. |
| 100e18 anchor, exactly 100e18 other | Live full-book reserve; self supply exactly 100,000,000,000 native DETF; bond LP 57,086,608,203,115,828,310; receipt principal remains zero. |
| Other minimum plus one native unit | Successful donation/genesis; no extra self supply or personal principal. |
| Alternate anchor, first leg one native unit below required minimum | Exact first-leg rejection with unchanged capital state. |
| Alternate anchor at equality | Successful canonical self amount and fixed bond LP custody. |
| Genuine six-decimal other token, required minimum 100e6 minus one | Exact rejection; no 18-decimal substitution. |
| Six-decimal equality at 100e6 | Successful self supply 100,000,000,000; bond LP 15,172,527,981,510,389. |
| Real direct-SE-share anchor | Pre-conversion public pair equivalence produces 86,994,733,454 native self units; actual mint equals that result; LP 53,992,249,859,258,726,655. |

The ordinary 18-decimal boundary fixture's parent is
`0x4b6C3b2773DF9587F3B4c2960E4556317f7cc0Fc`; its bond is
`0x5592164Ef3bf47C1e0690CeD5818C26E85e6E6cB`. These are fresh test-instance
proxies, not the separately broadcast local-QA addresses.

For each of four rejected F1 cases, this verifier independently extracted
and compared **185 ordered actual state-read observations before and after**
the failed call. Every comparison is equal. The observations include live
state, recorded bootstrap supply, funded staking state, six token supplies,
donation budgets, balances across seven relevant holders, and payer/parent/
bond allowances. Both SEs and the reserve hook are included. The trace shows
the exact revert escaping the bootstrap call, not a swallowed conversion
failure. This establishes transaction rollback, supplemented by explicit
observable custody/accounting equality; it is not a claim to have separately
enumerated every storage slot in every dependency.

Successful cases also assert actual `MigrationCapitalConsumed` values equal
supplied input less the pre-conversion SE refund for both legs, actual supply
equals generated self supply, LP belongs to the bond, donation inventory
equals remaining held pair inventory, and temporary approvals are zero.
Source: `TM/MigrationGenesisCapital.t.sol:17-195`.

### Historical evidence remains adverse

The immutable `../verification/GenesisWitness.s.sol` and
`../verification/runtime/genesis-witness-final.log` still show the former
100/1 success, including 100e9 self units and positive reserve LP. Its exit 0
means the counterexample executed, not that the defective behavior passed.

The correction's `runtime/f1-fail-before-02.log` independently inspected here
records the new regression against defective source
`c3e7d28ef1532a8056dbf7261e73439bef506830f2d20c01ae2f59fd36b63da6`:
0 passed, 1 failed, exit 1, **“next call did not revert as expected.”**
The earlier ambiguous-artifact setup failure remains distinct from this
behavioral red. Neither historical artifact was rewritten.

## 3. V1: genuine canonical Permit2, not missing-code coverage

### Counterparty and signature identity

Production still invokes
`0x000000000022D473030F116dDEE9F6B43aC78BA3` from
`C/bondNft/DETFFundedBondTarget.sol:268,304-325,429-455`.
Both selectors execute through the actual bond proxy
`0x7985Ecc11f051829A8aE4D3812ef55C198765fCa`, whose parent is
`0xA98fD388C687bb01bCB32638Bb4bca11e07Dab91`.

`TM/MigrationPermit2.t.sol:30-43` uses the existing
`lib/crane/lib/forge-std/src/StdCheats.sol:895-914` `deployCodeTo` fixture.
That mechanism executes the genuine `BetterPermit2` constructor at the
canonical address and installs its returned runtime there. This is an
external-counterparty fixture, not an etched SUT or copied foreign runtime.
No production Permit2 address or dependency setter was changed.

This verifier reconstructed the **entire** expected deployed runtime from the
current artifact and the two compiler-declared immutables: chain 31337 and
the independently calculated canonical EIP712 domain. Its 5,276 bytes hash to
the actual executed fixture's emitted code hash:

`0x584b3dfa0888b6e2ba8f0a3a47011aa3c53dcd8a819c8dd1963e00cbcc82ba6a`.

This is full runtime equality after supplying the legitimate constructor
values, not merely masking immutables and declaring a match.

| Execution chain ID | Independently recomputed and executed domain separator |
| --- | --- |
| 31337 | `0x4d553c58ae79a6c4ba64f0e690a5d1cd2deff8c6b91cf38300e0f2b76f9ee346` |
| 1 | `0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28` |
| 31338 | `0xd39117098c7fdd9b7eb1fa23b1f6296122c98bb236a734d2beeb44bdad389f2b` |

Domain fields are name `Permit2`, the actual chain ID, and the canonical
verifying contract, with the exact type
`EIP712Domain(string name,uint256 chainId,address verifyingContract)`.
The actual `EIP712`, `PermitHash`, `SignatureTransfer`, `AllowanceTransfer`
and `SignatureVerification` sources were read. The spender is the bond
proxy's actual `msg.sender` at Permit2, not the parent or fixture. Real
signature recovery, nonce bitmap mutation and ERC20 transfers execute;
no signature verifier or successful transfer is mocked.

### Positive observed routes

Each route starts from a fresh genuine funded reserve and the same
funded/approved external donor. These values were independently read from
the new passing traces:

| Observation | Allowance donation | Signature donation |
| --- | ---: | ---: |
| Donor contribution-token debit | 10,000,000,000,000,000 | 10,000,000,000,000,000 |
| ERC20 allowance to Permit2, before -> after | 10e18 -> 9.99e18 | 10e18 -> 9.99e18 |
| Permit2 allowance to bond, before -> after | 1e18 -> 0.99e18 | 1e18 -> 1e18 |
| Signed-allowance nonce | 0, unchanged | 0, unchanged |
| Unordered nonce bitmap | 0, unchanged | 0 -> 128; nonce 7 consumed |
| Reported primary LP, exactly equal to preview | 1,555,724,301,217,996 | 1,555,724,301,217,996 |
| Actual total bond LP increase | 1,770,544,802,207,521 | 1,770,544,802,207,521 |

The additional LP is from actual residual joins. Tests reconcile the full
bond LP delta against the real LP mint events instead of incorrectly equating
it with the primary join's return. Donor LP stays zero; parent supply and
total receipt gons do not increase; no personal principal is created.
Bond-to-parent and parent-to-hook temporary approvals clear.

### Isolated negatives and rollback

All twelve negative tests pass with valid surrounding funding/approval/
deadline inputs wherever needed to isolate the named failure:

| Negative | Actual inner/outer failure |
| --- | --- |
| Expired outer allowance-route deadline | `DeadlineExceeded(86399,86400)` |
| Expired Permit2 allowance, valid outer deadline | `AllowanceExpired(86399)` |
| Funded ERC20-approved caller lacking its own Permit2 allowance | `InsufficientAllowance(0)` |
| Expired signature permit, valid outer deadline | `SignatureExpired(86399)` |
| Wrong signed spender | `InvalidSigner()` |
| Wrong funded and ERC20-approved caller | `InvalidSigner()` |
| Signature from chain 31338 used on 31337 | `InvalidSigner()` |
| Reused nonce after a committed successful donation | `InvalidNonce()`; first donation remains committed |
| Downstream impossible minimum, allowance route | Actual reserve execution, then `MinAmountNotMet`; all prior transfer/approval effects revert |
| Downstream impossible minimum, signature route | Same, including restored nonce |
| Actual forbidden token callback, allowance route | Inner parent `NotAuthorized(token)` propagates as `TransferFromFailed()` |
| Actual forbidden token callback, signature route | Same, including restored nonce |

For every failed V1 route, this verifier compared **193 observations per
state snapshot**, including the full capital fingerprint's reads plus
Permit2 allowance/expiration/nonce, signature bitmap, caller balance/ERC20
approval/product balances, and child phases. Wrong-caller/signature helpers
compare both requested snapshots; where donor and caller coincide, these
are duplicate snapshots, not two distinct actors. All comparisons are equal.
Together with F1 there are **16 failed-call cases and 4,214 compared
before/after observations**, with zero differences.

Both minimum and both callback failures are followed by genuine successful
reuse of the restored allowance or same signature nonce. This rules out
mistaking an earlier unrelated failure for downstream rollback.

**Callback evidence qualification:** the external callback fixture always
propagates a failure; if the nested call unexpectedly succeeded, its own
`require(!ok)` would also be wrapped as `TransferFromFailed`. Therefore that
outer selector alone is not a sufficient regression oracle for the inner
authorization guard. This verifier checked the actual independent traces:
both contain `UniswapV4DetfMigrationMaintenanceFacet::synchronizeRewards`
reverting `NotAuthorized(0xf600471362E76508D1e3F5BA5d705755B7e1043C)`
before the transfer wrapper reverts. The current guard rejection and full
rollback are established; the test assertion's future-regression limitation
is not hidden. No test was edited.

No narrow phase/caller production repair was needed. The common bond target,
Migration bond target, parent maintenance facet and Migration policy hashes
match the original reviewed sources. Inherited donation's real lock maps to
bond Accounting; the actual fixed bond may call join/notify. Token callbacks
cannot borrow the parent synchronization exception. Ordinary defaults and
phase admission were not broadened.

### Original V1 limit is not relabeled

`../verification/runtime/inherited-donation-probes.json` still records
canonical code `0x` and failed receipt
`0x9a1a94383d36a2c68a00ac8d05596c16c73b89116b238883b6e83f3c8f8de78e`.
Its status is `0x0`. That remains failed positive coverage.

The unchanged two-stage local QA script creates its other Permit2 at a
CREATE3 address. Its local receipts do not establish canonical Permit2
availability. V1 is closed by the separate genuine canonical Foundry
executions above, not by reclassifying that local environment. Actual
deployment-chain dependency identity remains an operational/release gate.

## 4. Artifact binding and corrected regression receipts

Independent checks covered **932 unique artifact files and 2,482 source
files**. Every source SHA-256/Keccak and every artifact SHA-256 agrees with
the current files; every metadata source hash agrees with those source bytes.
Compiler metadata is
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, with no viaIR.
The selected Forge is `/Users/cyotee/.foundry/bin/forge`, recorded version
`1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`.

Among the original 45 reviewed paths, only the allocation target and the
TestBase differ. The latter makes the external pool-seed helper virtual;
its ordinary body remains unchanged. New capital/Permit2 tests and the
external callback token were inspected. No ordinary production source,
policy/caller target or configuration was changed by this correction.

| Run | Disposition and independently checked actual result |
| --- | --- |
| New bounded F1/V1 execution | 24 passed, 3 suites, zero failed/skipped, exit 0; nine F1 and fifteen V1 cases. |
| Corrected complete TM focused execution | Audited raw log: 83 PASS lines, 13 successful suites, zero failed/skipped, exit 0. |
| Corrected combined ordinary/common/pricing execution | Audited raw log: 10,102 PASS lines, 612 successful suites, zero failed/skipped, exit 0. |
| Corrected local script build | Audited `QA_BUILD_EXIT=0` and successful Solar build. |
| Corrected Stage A / Stage B | Audited 230 / 16 successful mined receipts, no pending transactions, both script exits 0. |
| Independent wrong-endpoint guard | Actual selected argv with port 18549 rejects before RPC/broadcast, exit 64. |

The large focused/combined scopes were not rerun without a new concern.
The bounded independent run was repeated once solely because the first PTY
capture discarded earlier trace output; both runs passed, and the second
retains the complete trace. Counts above are **24 distinct tests**, not 48.

The independent command uses the artifact-first helper, the existing warm
`out/`, and an owned seeded cache/TMPDIR under this directory:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationGenesisCapital.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationPermit2.t.sol \
  -- -vvvv
```

Exact environment, wrapper, output capture and exit sentinel are preserved in
`execution-evidence.json`. No concurrent compiler was present.

## 5. Corrected local-chain evidence and retained core

The audited corrected node instance is
`0x86c73d741983bdf3fbff119692d28fb7951dd9b3b335e8105e9dd94a00fd477a`.
It used owned `127.0.0.1:18548`, chain 31337, 100M block gas, unlocked dev
accounts, adequate native genesis funding, no fork/private key and no
code-size-limit bypass. WETH was actually wrapped. Contribution/rate ERC20s
are external fixtures, not actual recovery provenance.

The saved Stage A/B commands match the brief's exact Forge argv, including
`FOUNDRY_BLOCK_GAS_LIMIT=1000000000`, `--use solar`, `--broadcast`,
`--unlocked`, sender and port. The guard binds the selected Foundry binary
and actual Anvil instance. Its saved wrong-port test leaves nonce `0xe6`
unchanged; the independent wrong-port invocation also exits 64.

All 246 raw broadcast transactions were reconciled with successful receipts
and captured mined block/hash bindings. Sender, destination, chain and
transaction identity agree. The producer's stopped node was not resurrected
or silently replaced; these are independently audited saved receipts.

| Actual local identity | Address |
| --- | --- |
| Parent, derived from mined bootstrap event | `0x406cd20cb6f03f51cd303a3d14d6b1fbbcccab88` |
| Current contract owner | `0xD8c0e1DF4Cb2a23Eb2949A193374F6524c12D9aE` |
| Owner controller | `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` |
| Receipt | `0xEf2E550310745309Fc07B1DdE1853447e6a528bF` |
| Bond | `0xfA53c3188BcbDaE211Fe037aCD211C4031b8fE9d` |
| Raw SY / staking SY | `0x3af09b5667CCd422F4Cc883F4D991Bc5bFB4Af96` / `0xd5A995B3199Be66EC1b6825014CbAE48691c3425` |
| RT | `0x186a8c0806FACeDC673789980F7483DCCC633430` |
| Captured role beneficiary | `0xc02C5970BC54EB54442C421C7DE43Eec12481C5D` |

The actual owner contract reads the on-chain configuration ID before issuing:
`0xbd7d54a99ab363eae09d2a4ecb5f19efe56d43dd2d02e42c28c7e265d3615771`.
Genesis creates only 100e9 self units. Independent issuance creates
1,201,585,232 principal with equal held backing; configuration alone creates
none. The mined issue time is 1794353395 and unlock is 1802129395.
The actual node clock advances from 1794353396 to 1802129397 by
`evm_increaseTime(7776001)` and `evm_mine`, not a simulation-only warp.

Independently decoded mined events and actual ERC20 Transfer logs establish:

| Payment | Native amount / disposition |
| --- | --- |
| Mature principal before activation | 1,201,585,232 sDETF, reward component exactly zero |
| Original NFT reward after activation | 1,065,857,776 sDETF |
| Deferred wallet release | 9,810,261 sDETF released from escrow; the same transaction first checkpoints existing wallet growth, so this is not an assertion that its net wallet balance delta equals the gross release |
| Captured role release | 717,112,024 sDETF to the actual recorded beneficiary, not the owner/controller |
| Departed SY holder's RT | 2,903,655,350,914,193,571,309,238 native RT |
| RT redemption to a different receiver | 5,529,754 sDETF; 394,395,608,778,125,083,915,324,042,509,108,970 gons retained for the RT owner |
| Sub-RT remainder at this local index | Zero; retained rather than falsely claimed as positive payout |
| Repeated SY reward claim | Zero |
| Subsequent ordinary NFT 4 | Unmarked, ordinary terms |

Fee and creator beneficiaries coincide in this local fixture. Separate
allocation-time ownership and later creator transfer remain covered by the
current `MigrationRetainedAccounting` test, not inferred from that coincidence.

### Full retained core matrix

**E** = independently executed in this correction verification;
**R** = independently reconciled corrected saved execution/source;
**H** = preserved earlier independent witness on unchanged relevant logic,
not represented as a fresh rerun.

| Core obligation | Evidence and retained limit |
| --- | --- |
| Real registry packages, reciprocal parent/child identities, zero configured principal | R: current TestBase, Core deployment assertions, actual Stage A owner/children and decoded constructors. |
| Owner isolation, nonzero owner, pending/former/current owner, immediate Crane acceptance | R: Core/Administration suites and actual contract-owner Stage A/B. No invented acceptance delay. |
| Partial/native/all-leg donation, current-owner genesis, no personal genesis principal | E: corrected F1 cases; R: Core partial/native/nonowner case and mined genesis. |
| Frozen original grouping and immutable snapshot | R: current Snapshot/Core/Administration suites, configuration/event IDs and current artifacts. Actual recovery-domain admission remains open. |
| Replacement after issue, exact history, no top-up, whole batch rollback | R: current Core/Administration tests, inspected actual code and corrected passing suite. |
| Fresh cliffs, unlock boundary, delayed first issue, prior participant settlement, standing-only participation | R: Core/Administration/RetainedAccounting tests and independently recomputed mined clock. |
| Long Stage 1: positive mature principal, no new reward delivery | R: actual preactivation principal transfer, zero reward field, escrowed role events and current Egress matrix. |
| Positive active NFT/wallet/role rewards | R: decoded payments above; actual current-owner activation precedes them. |
| Both SYs, every configured input/output, both bearer burn modes, parent packet isolation | R: current Egress source and passing corrected run. Covers the actual fixture's declared routes, not arbitrary configurations or stock Pendle lifecycles. |
| Old-holder rewards, RT native units, different receiver and owner fraction | R: actual RT mint/burn/payment and retained R0 event, plus current Egress tests. |
| Positive native sub-RT payment | R: current RetainedAccounting test uses genuine funding and an admitted very large timestamp to reach k below q; positive exact payout and repeat zero. Not an operational time forecast; local Stage B pays zero at its own index. |
| Self-held SY and U | R: current delayed-self/bearer tests; H: earlier actual positive-U witness. Self-held SY is bearer principal, not authenticated user escrow. |
| Canonical wallet/NFT retirement | R: current PermitAndRetirement tests and actual retirement of NFT 3 after payment. No arbitrary pooled fraction retirement. |
| ERC2612 and custody caller negatives | R: current receipt/SY permit tests and Surface suite. Stale k carried by an unauthorized caller tests `Unauthorized`, not the authorized `UnexpectedGonsPerUnit` branch. No fabricated child was used. |
| Short input, slippage, token callbacks and full rollback | E: F1/V1 state comparisons and real inner callback rejection; R: HostileContribution/Egress; H: actual owner-receiver outer-failure witness, which rolls back due funding, supply, gons, position, ownership and activation. |
| Registry-disabled mature exit | H: preserved `CallbackRollbackWitness` pays mature principal and held DETF through actual registry disable. No new blanket exit pause. |
| All installed selectors/interfaces, complete irreversible administration removal | R: independently recomputed six-proxy selector sets, five removals and interface XOR; current Surface tests. H: actual failed initializer/postDeploy/completion and same-args registered redeployment/restoration probes. |
| Ordinary defaults | R: unchanged shared/policy source fingerprints, 10,102-test ordinary/common/pricing result and unmarked ordinary Stage B bond. |
| Metadata | R: independently decoded fresh mined JSON numeric fields before/after activation; H: preserved visual inspection. No new visual-rendering or frontend claim for this allocation-only correction. |
| Actual CLI binding and cleanup | E: wrong endpoint exits 64; R: exact corrected stage commands, instance/receipt bindings and producer cleanup; E: own cleanup below. |

### Runtime, selector and conservation reconciliation

All **22 live facet hashes** were independently reconstructed from current
artifacts, inserting actual declared library addresses where required, and
match the recorded local-chain runtime hashes. All **five package creation
bytecodes** match the actual mined deployment calldata. Decoded constructor
values reconstruct all five complete runtime hashes, matching recorded live
hashes. The three linked-library hashes also match current artifacts.
No unresolved link or arbitrary immutable masking substitutes for identity.

The corrected allocation facet is **20,183 bytes**, below EIP-170's 24,576;
the parent package is 16,632 bytes. The parent selector count is 96 -> 91;
receipt 44, bond 42, raw SY 42, staking SY 42 and RT 22 stay unchanged.
Exactly these five selectors disappear, with no added selector:

`0xec55c474`, `0x161d9afc`, `0xccff9894`, `0x787642e8`, `0xe9dc9e6d`.

Their independently recomputed interface XOR is `0xa71d1a99`, unsupported
after activation. Captured direct calls to all five reject. The retained
source/census has no generic executor, updater, installed initializer or
former LP-principal payout/restoration path.

All seven conservation equalities were independently recalculated from
recorded per-holder physical gons and deferred domains:

```text
sum physical gons = T
receipt escrow = sum(R0 + R1 + R2) + E + U
E = native RT supply * 10^18
bond physical gons = attributed bond gons
staking-SY physical gons = attributed SY gons
actual held DETF = accounted backing
accounted backing = floor(T / k) + allocation dust + staking dust
```

Final backing is 2,696,982,231 native DETF, with allocation/staking dust 2/1.
E and U are zero at this specific Stage B checkpoint; the preserved
positive-U witness is a different observation, not retroactively merged into
it. No unverified model balance was substituted for those recorded reads.

## 6. Original-plan gates remain open

No original plan checkbox or complete acceptance criterion is closed by this
bounded correction. MIG-P01/P02's independent original-quote portion,
P06/P07's genuine independent funded clocks, P08's inspected core reward
boundary, P09/P10's independent configuration/history, P11's installed-core
cut, and P12/P13's owner/funding core are supported. Their historical,
surrender, complete-source and operational counterparts remain open.
MIG-P03/P04/P05, source-dependent portions of P02/P06/P09/P10/P15, and
P14 harvesting are not delivered by F1/V1 closure.

| Gate / task | Explicit remaining disposition |
| --- | --- |
| E1 / task 1 | Open: pinned actual source code, units, authority, custody, rollback and recovery route for every category/generation. |
| E2 / task 1 | Open: authenticated ancestry through ordinary legacy transfers, wrapping, claims and postactivation operations. No static allowance, original-payer restriction or mutable trusted approver substituted. |
| E3 / task 2 | Bounded frozen evaluator retained; actual recovery asset/provider/route identities, supported domain and operational configuration remain open. |
| E4 / task 3 | F1 no longer blocks the tested bounded genesis. Actual-recovery deployment/funding prerequisites and complete task-3 acceptance remain open. |
| E5 / task 5 | Corrected bounded core and V1 ingress evidence supported. Complete product/source payout closure and expressly qualified branch/integration coverage remain full-plan gates. |
| Tasks 4/7 | Independent configuration and current installed-core cutoff verified; source-dependent loading and every future administration surface still require closure. |
| Task 6 | Legacy surrender, proportional attribution/credit, actual custody and issuance atomicity remain open. |
| Task 8 | Bounded staged harvesting, conversion, fixed-destination donation and recovery conservation remain open. |
| Task 9 | Deterministic datasets, checkpoint/resume, interrupted/mined-before-checkpoint recovery and operator rehearsal remain open. This local QA is not that workflow. |
| Task 10 / final verification F1-F4 | Full hermetic release, pinned legacy forks, full-product stateful invariants, operational gas/batch limits, complete source matrix and resumable rehearsal remain open. These final-wave F1-F4 labels are distinct from this report's historical core defect F1. |

All required source rows remain: weighted liquid DETF; earlier CP liquid
DETF; weighted fixed-principal NFT; earlier CP LP-lock NFT; weighted sDETF;
earlier receipt; legacy SY; TokenStaking/claim-vault rights; underlying SE
shares; fungible LP tokens. No category is merged, omitted or declared to
have zero exposure without proof.

### All 53 acceptance dispositions retained

| ID | Bounded evidence / remaining full-plan gate |
| --- | --- |
| MIG-AC01 | Core ordinary new-money closure retained. |
| MIG-AC02 | Legacy surrender before/after activation open. |
| MIG-AC03 | Core pre-branch gate retained; complete source bypass matrix open. |
| MIG-AC04 | Independent replacement/cut retained; source loading/operator batching open. |
| MIG-AC05 | Core current-owner/callback checks retained; legacy/harvest roles open. |
| MIG-AC06 | Legacy custody/credit atomicity open. |
| MIG-AC07 | Original quote times remaining-principal fraction open. |
| MIG-AC08 | Legacy old-reward exclusion open. |
| MIG-AC09 | Cross-representation/recovery duplicate prevention open. |
| MIG-AC10 | Harvest cannot resize bond: harvest implementation open. |
| MIG-AC11 | Distinct legacy LP-lock/funded/fungible units open. |
| MIG-AC12 | Ordinary defaults and corrected combined regression retained. |
| MIG-AC13 | Genuine independent issuance retained; surrender counterpart open. |
| MIG-AC14 | Core cliff/reward policy retained; surrender class integration open. |
| MIG-AC15 | Current-owner/role separation retained; harvesting open. |
| MIG-AC16 | Bounded all-leg funding now includes corrected F1 minimum/rollback proof; actual recovery funding open. |
| MIG-AC17 | Recovered DTF/legacy DETF conversion/donation open. |
| MIG-AC18 | Every legacy category still requires verified route closure. |
| MIG-AC19 | Core cliff-boundary positive principal retained. |
| MIG-AC20 | Core accrued ownership, payments and repeats retained. |
| MIG-AC21 | Frozen independent original credits retained; surrender fraction open. |
| MIG-AC22 | Core snapshot stability retained; live eligible-fraction equality open. |
| MIG-AC23 | Historical routed-input/descendant/recovery duplication proof open. |
| MIG-AC24 | Once-captured core book retained through activation. |
| MIG-AC25 | Actual independent clock retained; per-surrender clocks open. |
| MIG-AC26 | Installed-core cut/activation atomicity retained. |
| MIG-AC27 | Current full selector/restoration census retained. |
| MIG-AC28 | Removed activation and preserved no-restoration evidence retained. |
| MIG-AC29 | Core queries, claims and donations retained, including genuine Permit2; surrender/harvest absent. |
| MIG-AC30 | No Migration pause; preserved registry-disabled mature exit. |
| MIG-AC31 | Local funding-first sequence retained; resumable workflow open. |
| MIG-AC32 | Owner-only harvesting implementation open. |
| MIG-AC33 | Selected-work gas/batch evidence open. |
| MIG-AC34 | Repeat/overlapping harvest reconciliation open. |
| MIG-AC35 | Authenticated transferred legacy attribution open. |
| MIG-AC36 | Legacy remaining-principal proportional delivery open. |
| MIG-AC37 | Core administration removed; future source/configuration cutoff open. |
| MIG-AC38 | Independent replacement preserves bond/history; legacy consumption open. |
| MIG-AC39 | Legacy proportional attribution/credit conservation open. |
| MIG-AC40 | Final surrender/custody/issuance rollback open. |
| MIG-AC41 | Partial fungible and whole-NFT surrender open. |
| MIG-AC42 | Surrender current-holder/recipient proof open. |
| MIG-AC43 | Core NFT terms/transfers retained; legacy-created positions open. |
| MIG-AC44 | Selected harvest whole-batch rollback open. |
| MIG-AC45 | Staged recovery custody and fixed destination open. |
| MIG-AC46 | Real per-proxy owner/children and isolation retained. |
| MIG-AC47 | Core pending/former/current owner behavior retained; harvesting open. |
| MIG-AC48 | Core composition/census retained; former V1 ingress gap closed only by genuine canonical executions above. |
| MIG-AC49 | Legacy NFT quote-without-issue and actual-principal surrender open. |
| MIG-AC50 | Legacy collection+ID/current holder proof open. |
| MIG-AC51 | Separate-original consolidation retained; operational exposure exclusion open. |
| MIG-AC52 | Independent replacement/replay/cut retained; legacy end-to-end scenario open. |
| MIG-AC53 | Bounded core payout checks retained; not complete legacy/release acceptance. |

## 7. Limits, attempts and cleanup

The first independent 24-test run passed but terminal capture dropped earlier
output. That capture defect was corrected with one bounded repeat and a full
on-disk trace, not by claiming inaccessible output had been inspected.
Read-only analysis initially assumed decoded package arguments were present
in broadcast records; actual raw `deployPkg`/`deployPackageWithArgs` calldata
was subsequently decoded and matched instead. A domain-helper invocation
also failed before producing a value; final domains were calculated directly
from the read Solidity ABI formula. Neither analysis issue altered the SUT,
test inputs or receipts.

The producer's preserved setup/fixture failures remain preserved, including
the old cached-domain mismatch. No passing value was manufactured by signing
that wrong cached domain. Existing unrelated compiler warnings and the
`fmt.skip` warning remain visible. JSON Biome LSP is not installed; no
installation/configuration edit was made. Evidence JSON was serialized from
parsed data. No new Solidity source was authored or claimed to have fresh
source diagnostics.

Coverage is finite, not a proof of every possible deployment or optional
consumer. The authorized-stale-k branch, optional stock Pendle lifecycles,
actual legacy forks, operational gas bounds and actual recovery bindings are
not silently promoted to passes. The canonical Permit2 evidence is the
genuine repository implementation on the test chain, not a public-network
deployment or blanket ERC1271/batch-permit compatibility claim.

Both owned finite executions completed with exit 0. No Anvil or listener was
created by this verifier; the port-18548 probe found no listener. The empty
owned TMPDIR was removed. Warm artifacts, original caches, the owned seeded
runtime cache, all logs/receipts and shared dependency links were retained.
No other session's resource was stopped.

After execution, all 2,482 source hashes, all 932 artifact hashes and all
101 fingerprinted historical evidence files still match. The original report,
counterexample, callback witness, receipt records and correction evidence
are immutable and unchanged. There is no pending required run or cleanup.

**Final disposition: confirmed for corrected bounded core F1/V1 verification.
All remaining original Migration, legacy, operator and release gates above
stay open.**
