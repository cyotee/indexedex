# Independent phase04 Migration core verification

Date: 2026-11-10.

**AdversarialVerify: needs-fix.**

The bounded core is not accepted. An independently executed, actual-proxy
witness confirms that pooled genesis omits the accepted other-leg minimum
capital check. A 100-token anchor creates 100,000,000,000 native DETF self
units while the second leg contributes only 1 token against a required 100;
the reserve nevertheless becomes live. This is a source defect, not a missing
legacy decision. No production or existing test correction was made.

The required two-stage local rehearsal independently succeeded after correcting
the verifier's local funding and journal setup: 230 successful Stage A receipts
and 16 successful Stage B receipts. Mature principal paid before activation;
owned rewards and RT paid afterward. Current artifact bindings, the complete
installed selector census, native/gon conservation, rendered metadata, and
additional callback rollback/disabled-exit witnesses were checked. Those
positive results do not override the genesis defect or close the original
legacy, release, or operator gates.

## 1. Finding and bounded validation limits

### F1 - High: genesis does not enforce the other legs' opening-price capital requirements

Location:
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol:168-181`.
Related conversion code: lines 215-260.

The implementation previews all legs, but only the selected anchor's
`equivalents_` value determines `selfMinted_`. Every other equivalent is passed
to `_convertGenesis` solely to check that its own measured consumption matches
its preview. Nothing compares it with the capital required for the generated
self leg. A successful full-book join proves positive inventory, not adequate
other-leg capital.

The accepted bootstrap contract, `phase-03/.../migration/package/bootstrap.md`
section 3.2, step 4, requires the other legs' supplied pair-equivalent capital
to be at least `_firstBondOtherPayment(G,pair)`. The ownership/bootstrap
handoff section 3.1 preserves that rule. R3 sections 1, 7, and 8 retain the
genesis contract while settling **who** selects the amounts: the current
owner. That authority decision does not remove the sizing condition.
The ordinary implementation actually requires the other payment at
`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:650-674`.

Independent evidence:

| Actual-proxy observation | Value |
| --- | ---: |
| Anchor donated and selected | 100 * 10^18 WETH |
| Second leg donated and selected | 1 * 10^18 external contribution-token units |
| Required second payment from the parent's real pre-genesis `previewFirstBondPayments` | 100 * 10^18 |
| Actual self-leg supply minted | 100,000,000,000 native DETF |
| Actual bond-child LP | 15,161,195,257,184,343,688 |
| Reserve live | true |
| Staking receipt supply | zero |

`GenesisWitness.s.sol` uses the real shared TestBase and registry/CREATE3
deployment. It does not impersonate the parent, supply an arbitrary credit,
subclass the SUT, alter storage, or replace a child. The independent oracle is
the real parent payment preview, not a copied expected constant. Output is in
`runtime/genesis-witness-final.log`, exit 0. **That exit confirms the
counterexample; it is not a passing acceptance test.**

Impact: owner-authorized genesis can permanently establish a self-supply and
reserve composition outside the accepted opening contract, subsequently used
by the immutable compensation snapshot. This is not a claim that an arbitrary
non-owner can execute genesis or withdraw the LP.

Correction direction, not an edit: enforce the other-leg lower bounds using
the already measured/pre-conversion pair equivalents and canonical opening
payment formula before committing genesis. Preserve selected excess donations,
fixed LP custody, owner authority, and transaction rollback. Add a real-proxy
regression where this underfunded selection rejects, then sufficient actual
capital succeeds without changing the anchor rule.

### V1 - Incomplete positive proof for the inherited Permit2 donation routes

The complete census includes both
`donateWithPermit2Allowance(address,uint256,uint256,uint256)` and
`donateWithPermit2Signature(address,uint256,uint256,uint256,bytes)`.
Their inherited implementation uses the fixed canonical Permit2 address
`0x000000000022D473030F116dDEE9F6B43aC78BA3`:
`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:268,429-455`.

The local QA script deploys its `BetterPermit2` at a CREATE3-derived address,
not that fixed address. The independent node returned `0x` for canonical
Permit2 code, and an actual allowance-donation transaction reverted.
`runtime/inherited-donation-probes.json` preserves the receipt and call trace.
The two ordinary transfer-funded donation routes independently succeeded and
increased child LP by 2,532,786,518,327,222 without minting DETF.

This is a **fixture/coverage gap**, not a newly introduced change to the
inherited Permit2 constant, a discovered payout bypass, or authority to edit
shared dependencies. Neither the new core tests nor this local rehearsal
establish positive execution of those two inherited selectors through their
actual fixed external dependency. Do not describe the current evidence as
exhaustive successful execution of every installed monetary selector.

### Other distinctions required when interpreting the evidence

- `MigrationSurface.t.sol:84-100` tests unauthorized callers carrying stale
  `k`, and correctly receives `Unauthorized`. It does **not** execute the
  authorized-caller `UnexpectedGonsPerUnit` branch. Actual production callers
  pin and immediately pass `k`; that ordering was traced and exercised, but a
  forged caller/child was not introduced to manufacture separate stale-index
  branch coverage.
- The producer's callback test rejects nested activation/reentry while the
  outer transfer succeeds. This verifier supplied the previously missing
  **outer failure** witness: a real current-owner receiver rejects delivery
  after probing both gates, and due funding, supply, gons, position, ownership,
  and activation roll back. See section 4.
- The ordinary-active and configured-output tests exercise actual fixtures,
  not every conceivable deployment configuration. Unsupported snapshot
  recipes and real-recovery bindings remain explicit deployment gates.
- The producer's positive sub-RT native-remainder witness uses real funding
  over a very large, admitted timestamp interval. It proves integer-domain
  behavior, not operational time-to-reward projections.

## 2. Scope, identities, and source ownership

Working tree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Branch: `work/dtf-migration-phase-04`.
HEAD/base: `6e27ecaa242c4acca132e3575a160514aad07b11`.
No commit was created.

Read completely: the main checkout's `phase04-core-brief.md`, the original
`MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, phase03
`egress-contract-r3.md` and `egress-r3-verification.md`, and the
ownership/bootstrap implementation handoff. The current repository router,
assistant rules, relevant canonical architecture/deployment/testing and
adversarial skills were loaded. The implementation report, actual core
interfaces/implementations, seven new core test files, TestBase, local script,
guard, and their relevant inherited callees were inspected.

R3 replaces r1/r2. Current-owner-only pooled genesis is settled; contributions
and subsequent ordinary donations remain permissionless. No E1/E2 attribution
or atomicity relaxation is adopted.

Source prefixes used below:

- **M**: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- **D**: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- **C**: `contracts/vaults/detf/common/`
- **TM**: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- **K**: `lib/crane/contracts/`

The producer's 45-path manifest consists of 36 new Migration source/interface/
fixture files and nine permitted shared edits:

| Permitted shared paths | Observed change |
| --- | --- |
| `C/bondNft/DETFFundedBondTarget.sol` | Consumed synchronization/delivery dispatch seams; ordinary delivery remains receipt transfer |
| `C/bondNft/DETFNFTVaultDFPkg.sol` | Virtual declaration seam |
| `C/bondNft/DETFFundedBondMetadata.sol` | Opt-in Migration presentation; zero-initialized ordinary options preserve ordinary rendering |
| `C/claimToken/StakedDETFTarget.sol` | Virtual entry/internal dispatch declarations |
| `C/claimToken/RebasingClaimTokenDFPkg.sol` | Selected-facet extension declarations, preserving ordinary IDs/order |
| `C/sy/DETFSYTarget.sol` | Virtual dispatch and reward-method mutability needed by the selected implementation |
| `C/sy/DETFSYDFPkg.sol` | Selected-facet extension declarations, preserving ordinary IDs/order |
| `D/UniswapV4DetfCommon.sol` | Preview/settlement/residual dispatch; ordinary residual default is its existing held balance |
| `D/UniswapV4DetfTarget.sol` | Narrow consumed staking, unstaking, bond, donation, and preview seams |

No snapshot, weighted-hook, V3-pricing, shared Crane, configuration,
dependency-link, lockfile, or ordinary gold-TestBase correction was made by
this verifier. All authored deliverables are under `verification/`; compiler
and broadcaster runtime artifacts are explicitly identified. The two new
verification `.s.sol` files are local proof harnesses, not production changes
or edits to the producer's tests.

### Independently checked identities

`binding-summary.json`, `reviewed-input-identities.json`, and
`surface-artifact-matrix.json` record exact paths and hashes:

- 2,479 source files matched their recorded SHA-256 **and independently
  recomputed Keccak-256**.
- 927 unique artifact JSON files matched their recorded SHA-256. Their
  compiler metadata source hashes match that current source graph.
- No recorded artifact used viaIR or a non-Solar compiler.
- All 927 original artifact files still matched after compiling the two new
  verification witnesses. All 45 producer source hashes remained unchanged.
- All 22 actual preactivation unique facet runtimes matched current compiled
  bytecode, masking only compiler-declared link/immutable offsets. Linked
  addresses were separately checked against the three actual linked library
  artifacts; no nested unresolved library link remained.
- Five actual package runtimes matched their compiled artifacts. The parent
  package is 16,632 bytes; the largest inspected core facet is the allocation
  facet at 19,975 bytes, below 24,576. Code-size enforcement remained enabled
  on the mined local node.

The compiler/toolchain was
`/Users/cyotee/.foundry/bin/forge`, version `1.9.1-nightly`, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`; metadata identifies
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.

The inspected producer logs contain exactly 59 passing tests in 10 focused
suites and 10,078 passing tests in 609 combined suites, with zero failures or
skips. These are **verified prior executions**, not independently rerun
regressions. The unchanged large combined run was not repeated. Its explicit
ordinary V4/common/pricing roots and test names remain in
`../implementation/verification-summary.json`; independent log hashes and
counts are in `binding-summary.json`.

## 3. Complete selector and caller/phase review

The full compiled-signature-to-live-facet matrix is
`surface-artifact-matrix.json`. It includes every installed selector, not just
Migration additions, and distinguishes compiled package methods from proxy
routes. Every function in each compiled inherited product interface was found
on its intended preactivation proxy; missing interface selectors: **zero**.

| Actual proxy | Before activation | After activation |
| --- | ---: | ---: |
| Parent | 96 selectors | 91 |
| Receipt | 44 | 44 |
| Bond NFT | 42 | 42 |
| Raw SY | 42 | 42 |
| Staking SY | 42 | 42 |
| RT | 22 | 22 |

The five removals are exactly:

| Selector | Signature |
| --- | --- |
| `0xec55c474` | `bootstrapMigrationReserve((address,uint256,uint256)[],uint256,uint256,uint256)` |
| `0x161d9afc` | `captureMigrationSnapshot()` |
| `0xccff9894` | `configureIndependentAllocations((address,bytes32,(bytes32,uint256,uint256,bytes32)[])[])` |
| `0x787642e8` | `issueIndependentAllocations((address,bytes32)[])` |
| `0xe9dc9e6d` | `activateMigration()` |

The parent administration interface `0xa71d1a99` becomes unsupported.
All other package-declared interfaces queried on the six actual proxies
remain supported. The complete remaining map contains no generic executor,
cut/updater, package initializer, temporary post-deploy hook, former
LP-principal payout, or reward-policy setter.

### Monetary and authority graph

Phases are the actual shared enum:
Idle=0, Synchronizing=1, Acquiring=2, Accounting=3, Paying=4.

| Installed surface, including inherited paths | Caller, phase, and accounting boundary inspected | Evidence |
| --- | --- | --- |
| Parent ERC20 transfer/transferFrom/approve/permit | Canonical token/allowance storage; these move existing DETF, not compensation credit | Compiled/live census; real funding transfers; unchanged common regressions |
| Parent `exchangeIn` | Admission before branch selection; external acquisitions closed in Stage 1, existing DETF/receipt principal routes retained | `M/UniswapV4DetfMigrationExchangeFacet.sol:26-62`; Core/Egress suites; Stage B |
| Parent `bond`, including reserve LP input | Stage 1 gate before ordinary purchase selection; active purchases use real parent-funded child creation and remain unmarked | `M/UniswapV4DetfMigrationBondFacet.sol:22-42`; ordinary active test and Stage B token 4 |
| Parent new all-leg/native donation | Actual measured pulls/wrap; booked budgets separate from unsolicited inventory; no user LP/credit | `M/UniswapV4DetfMigrationTarget.sol:44-105`; Core/Hostile tests; Stage A |
| Parent inherited donate and child direct/forwarded donate | Donor identity preserved; bond-first lock and fixed parent join/notify cycle; no personal principal | `M/UniswapV4DetfMigrationMaintenanceFacet.sol:49-67`; `C/bondNft/DETFFundedBondTarget.sol:273-455`; independent positive RPC probes; V1 for Permit2 |
| Parent sweepDust and self-only sweep/join helpers | Only operation residual budget, not pooled donations/unsolicited inventory; actual self-only call checks remain | `M/UniswapV4DetfMigrationPolicy.sol:18-63`; inherited residual implementation and source diff |
| Parent synchronization | Parent settlement before new participation; fixed receipt/bond-only locked callback with explicit expected synchronizer; otherwise exact busy-child graph | `M/UniswapV4DetfMigrationMaintenanceFacet.sol:28-47`; `M/UniswapV4DetfMigrationPolicy.sol:74-123`; delayed/second/standing-only tests |
| Configuration and genuine independent issuance | Current Crane owner; no credit input; originals quoted separately; actual mint/pull/stake/open under Accounting; once-only execution history | `M/UniswapV4DetfMigrationAllocationTarget.sol:30-126`; Administration/Core tests; Stage A |
| Genesis, capture, activation | Current owner and all children idle, parent lock; activation resolves current owning facets and removes complete administration with no external callback | Allocation target:128-213; F1; actual five-selector removal and callback witness |
| Parent child completion | Once-only stored packages and children, not an arbitrary replacement route | `D/UniswapV4DetfTarget.sol` completion methods; fresh deployment and failed actual repeat calls |
| Crane Ownable | Pending owner has no authority until actual acceptance; acceptance does not enforce the confirmation delay | `K/access/ERC8023/MultiStepOwnableRepo.sol`; actual source and Administration test |
| Bond creation/claims | Fixed parent creates exactly funded fresh cliff; owner/operator claims; effects debit position and aggregate before typed receipt delivery; rewards/combined reject while closed | `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:19-79`; common bond:107-223; Stage B |
| All three NFT transfers, approvals, role transfers | Actual guarded replacements, synchronization before local accounting; safe receiver called before ownership mutation; transfer conveys remaining rights, not a reward payout | Common bond:233-250; `K/tokens/ERC721/ERC721Repo.sol:153-169`; callback witness and retained-role test |
| Bond `transferHeldToken` and reserved initialization | Fixed parent only; cannot spend DETF/receipt backing; reserved IDs initialized once | Common bond:88-97,225-230; immutable parent call graph |
| Receipt transfer/transferFrom/permit | Stage 1 checkpoint into R0 then exact native basis cap; canonical allowance semantics; authenticated SY pull only in Acquiring | Receipt target:84-100,375-408; permit and egress suites |
| Receipt exact-in and exact-out stake/unstake | Both compiled inherited selectors dispatch to Migration `_exchange`; exact actual DETF funding; closed principal cap; only own canonical final wallet fraction retires | Receipt target:295-350; common receipt:147-166; positive principal/exact-out tests and Stage B |
| Receipt funding and role delivery | Fixed parent only; save/restore Synchronizing; canonical two-floor funding; closed allocations go to captured R1, not role-owner wallets | Receipt target:102-127,353-373; role tests and actual fixed-beneficiary payout |
| R0/R1 release and R0/R2 assignment | Actual owner assigns exact rights, no allowance substitute; R1 never retargeted; active release goes to fixed beneficiary and retains unpaid gons | Receipt target:142-169,399-452; actual R0/R1 payments; source tracing |
| Bond receipt delivery/retirement | Fixed bond Accounting, current k, actual post-debit aggregate; no arbitrary pooled gon retirement | Receipt target:129-139,172-182,465-496; genuine claims and canonical retirement tests |
| SY receipt ingress/defer/principal exits | Fixed staking SY: Acquiring for pull/stake, Accounting for post-debit typed calls; exact native principal and physical gon coverage | Receipt target:185-234,308-323; SY:77-145,235-250; earned-position, both burn modes and output tests |
| Raw SY | Raw backing equals issued principal shares, empty reward arrays, no automatic receipt route; actual configured routes use measured parent packets | Full common/Migration SY source; raw-output/input tests |
| Staking SY transfers/deposit/redeem | Canonical shares, lastK checkpoints for old owners, one incoming A addition; standard caller/self bearer burn; Paying only after debit | `M/sy/UniswapV4DetfMigrationSYTarget.sol:57-145,227-301`; Egress tests and independent bearer/U probe |
| SY reward API and native remainder | Staking `[RT]`, index `1+Q-k`, claim uses native RT at q=10^18; activation even for zero; remainder spends only R2 modulo q | SY:168-225,303-316; receipt:236-269; Stage B and retained-accounting test |
| RT transfer/allowance/mint/burn/redeem | Fixed 27-decimal native units; receipt-only mint/burn with E/supply equality; redemption binds owner to caller, synchronizes receipt, retains modulus in owner's R0 | `M/sy/rewards/UniswapV4DetfMigrationRewardTokenTarget.sol`; receipt:272-292; Stage B and one-native-RT test |

The ordinary multi-asset vault facets installed on the parent are read-only
inventory/metadata surfaces. ERC2612 changes allowance/nonces only. The
ERC8109 factory contribution is only `functionFacetPairs`, not an update
entrypoint. These inherited surfaces were inspected rather than assumed safe
from their names.

## 4. Actual execution matrix

**I** means independently executed here. **P** means producer execution whose
test source, passing output, and current artifact bindings were inspected.
Neither label implies the entire original-plan criterion is complete.

| Required behavior | Actual evidence and disposition |
| --- | --- |
| Real package/child identity and EIP-170 | I: six proxy censuses, 22 facets, five package runtimes, three linked libraries; zero mismatches; P: Surface deployment tests |
| Nonzero owner, isolation, contract owner, immediate acceptance | P: Core/Administration tests; I: actual owner contract controls Stage A/B, caller/controller/role identities remain distinct |
| Partial/all-leg/native funding and no configured supply | P: partial native/WETH and configuration tests; I: Stage A exact issued backing/supply and actual genesis receipt. F1 prevents complete genesis acceptance |
| Same frozen book and separate original grouping | P: immutable snapshot and individual-original/nonlinear grouping tests; I: actual book/source, stored credit and issuance match, snapshot unchanged through Stage B |
| Overwrite after issue, idempotence, no top-up, whole-batch rollback | P: Core configuration and Administration duplicate/history/bad-second-item tests; no fake issuer |
| Fresh 90-day clocks, unlock boundaries | P: actual creation, unlock-1/unlock/+1 numeric/claim tests; I: issuedAt 1794348311, duration 7,776,000, real mined increase 7,776,001 before Stage B |
| Empty delayed baseline and earlier participant settlement | P: seven-day delayed first issue, second-participant, standing-weight-only witnesses; source empty predicate includes T, F and Cw |
| Positive mature principal during long Stage 1 | I: 1,201,585,232 principal paid with reward field zero before activation; actual receipt unstake and SY deposit; P: exact cliff/exact-out/parent packet paths |
| No early reward receipt/RT delivery | I: actual failed early reward tx, status 0, `MigrationRewardsClosed` selector `0x2fd2fbf4`; RT supply zero before activation; P: fee/creator and wallet/SY gate tests |
| Positive activated NFT, R0 and R1 rewards | I: 1,065,857,776 NFT reward; 9,810,261 wallet units; 717,112,024 captured role units paid to actual role beneficiary |
| Old SY owner, native RT and owner remainder | I: 2,903,655,350,914,193,571,309,238 native RT tokenized for departed holder, then redeemed for 5,529,754 receipt units to another receiver; 394,395,608,778,125,083,915,324,042,509,108,970 gons initially retained for RT owner |
| Positive sub-RT native payment | P: `MigrationRetainedAccounting.test_subRewardTokenRemainderPaysNativeUnitsWhenIndexBelowQuantum`, real expansion, `expected > 0`, exact payout/debit and repeat zero. I: Stage B remainder is correctly zero at its index, not mislabeled positive coverage |
| Both wrappers, all configured input/output directions, both burn sources | P: four actual Egress matrix tests enumerate live getTokensIn/Out and assert positive measured output plus cleared allowances; I: required Stage B composition |
| Bearer self balance and U | I: 100,000,000 issued self-held shares acquire real further rewards, arbitrary caller redeems exactly principal, U increases by exactly `shares*(kBefore-kAfter)`, self accrued RT is zero; P: delayed-self/internal-burn tests |
| Canonical wallet/NFT retirement | P: active full-wallet fraction and real bond retirement paths; I: token 3 retires only after principal and whole-unit rewards are paid; RT remainder remains separately owned |
| Wrong caller and short receipt | P: exact unauthorized typed receipt calls, short external contribution rollback, actual hostile token reentry failure; stale-index qualification in section 1 |
| Failed minimum and allowance/gon rollback | P: deposit and underlying-redeem failure snapshots; no swallowed production exception |
| Current-owner callback activation and full rollback | I: `CallbackRollbackWitnessRunner`, exit 0. Receiver really accepts ownership. A failed safe transfer rolls back due expansion, supply, gons, position and NFT ownership; callback observes old owner and cannot activate/reenter receipt |
| Registry-disabled mature exit | I: same witness disables the real parent through real registry authority, then pays 1,201,585,232 mature principal and equal held DETF successfully |
| Irreversible activation/restoration | I: all five actual selectors removed; init/postDeploy and repeat child completion fail; package postDeploy fails at absent hook; same-args registered redeployment mines successfully and leaves routing/owner/activation unchanged |
| Ordinary defaults | P: 10,078-test combined run includes unchanged ordinary V4/common/pricing roots; I: Stage B token 4 unmarked with ordinary linear metadata; source diff preserves default policy |
| Truthful metadata/rendering | I: issued cliff, mature closed, activated cliff and ordinary tokenURI/event captures decoded and rendered; 0/100% cliff, locked/accrued distinction, actual amounts; no overlap/overflow in inspected captures |
| Actual CLI/RPC/receipt binding | I: guard rejects port 18549 before broadcast, nonce unchanged; selected Foundry binary and Anvil instance recorded; all Stage A calldata/from/to/value/nonce and Stage A/B receipt block hashes verified |

The callback witness is deliberately constructed so an unexpectedly successful
nested activation/reentry makes the receiver accept and the outer witness
fail. It does not hide a failed callback assertion behind ERC721's catch.
Both verification Solidity files have fresh **No diagnostics found** results.

## 5. Independent mined-chain evidence

Successful node identity:
`0x3c7762a059c4bc219482898a6c93a94a6ccc887be30cafa822e7c45f05b7a5b7`.
Endpoint `http://127.0.0.1:18548`, chain 31337, 100,000,000 block gas,
standard unlocked accounts, no fork, no private key, code-size enforcement on.
Native dev accounts were funded at Anvil genesis with `--balance 1000000`.
WETH was actually wrapped; the mintable contribution token is an explicitly
labeled external fixture, not historical recovery provenance.

| Role | Actual address |
| --- | --- |
| Parent | `0x406cd20cb6f03f51cd303a3d14d6b1fbbcccab88` |
| Bond | `0xfA53c3188BcbDaE211Fe037aCD211C4031b8fE9d` |
| Receipt | `0xEf2E550310745309Fc07B1DdE1853447e6a528bF` |
| Raw SY | `0x3af09b5667CCd422F4Cc883F4D991Bc5bFB4Af96` |
| Staking SY | `0xd5A995B3199Be66EC1b6825014CbAE48691c3425` |
| RT | `0x186a8c0806FACeDC673789980F7483DCCC633430` |
| Parent package | `0x642fa76f2F7A6b97ec0822D67a785379A92DF347` |
| Actual contract owner | `0xD8c0e1DF4Cb2a23Eb2949A193374F6524c12D9aE` |
| Captured fee/creator beneficiary | `0xc02C5970BC54EB54442C421C7DE43Eec12481C5D` |

Addresses repeat the producer's deterministic addresses, but these are fresh
transactions on a different captured Anvil instance, not reuse of its chain.
The exact commands, receipts, and state are in
`runtime/stage-a-readback.json` and `runtime/stage-b-readback.json`.
Both preserve the brief's exact Forge argv; the environment supplies the
guard and separate broadcast/runtime-cache locations.

The actual clock moved from 1794348313 to 1802124314, exactly 7,776,001
seconds, through `evm_increaseTime` and `evm_mine`. No simulation-only warp
substituted for Stage B's mined maturity.

### Conservation at completion of required Stage B

`runtime/conservation.json` independently enumerates every receipt holder
observed in the actual Transfer logs and reads their physical gons and
R0/R1/R2. It verifies:

```text
sum physical G = T
G[receipt] = sum(R0 + R1 + R2) + E + U
E = RT.totalSupply * 10^18
G[bond] = attributedBondGons
G[stakingSY] = attributedSyGons
actual held DETF = B = floor(T/k) + allocationDust + stakingDust
parent totalSupply = all actual mint Transfer values - burn Transfer values
```

At that checkpoint, T is
1,416,176,165,680,858,659,435,357,140,800,263,187,536,702,280 gons;
k is 525,096,587,753,919,033,863,740,427,634,928,695;
backing/accounted liability is 2,696,982,231 native DETF;
allocation/staking dust is 2/1; parent supply is 103,860,207,234.
All equalities hold. U and E are zero at this checkpoint. The later independent
self-bearer witness creates and exactly reconciles **positive U**; it does not
retroactively alter the Stage B checkpoint.

### Metadata

`runtime/metadata-captures.json` preserves actual JSON/SVG and lossless
base64 PNG captures. Measured PNG sizes are 1440x1100 and 390x1800 in light
and dark canvases. The four states were visually inspected; SVG text bounds
show no overflow. The mature-closed owner event is after principal payment,
so zero remaining principal and positive accrued-but-unclaimable reward are
correct. Activation opens the same accrued amount. The ordinary token remains
linear. This is NFT artwork inspection, not a claim of frontend QA.

## 6. Original-plan traceability and gates still open

No original plan task or legacy acceptance row is marked complete by this
bounded report. The following separates verified core portions from the
missing full-plan behavior.

| Requirement | Bounded disposition |
| --- | --- |
| MIG-P01 | Independent original credits use frozen per-original user quotes; historical source proof remains open |
| MIG-P02 | Summing independent original credits is verified; proportional surrender remains open |
| MIG-P03 | Legacy remaining-principal calculation remains open |
| MIG-P04 | Burned/nonexistent/empty legacy NFT eligibility remains open |
| MIG-P05 | Whole legacy identity consumption and descendant exclusion remain open |
| MIG-P06 | Genuine independent exact-funded issuance verified; surrender issuance/custody open |
| MIG-P07 | Independent fresh 90-day clock verified; later surrender clocks open |
| MIG-P08 | New-instance retained accrual/principal/reward boundary verified within the matrix; V1 prevents blanket monetary-surface coverage |
| MIG-P09 | Distinct recipient-keyed independent execution verified; operational no-overlap evidence open |
| MIG-P10 | Independent replacement/history/no-top-up verified; legacy partial-consumption replacement open |
| MIG-P11 | Entire installed core administration removed; later source surfaces must join that complete cutoff |
| MIG-P12 | Current Crane owner, separate roles and no price setter verified; harvesting not implemented |
| MIG-P13 | Real donations/funding-first core verified in part; F1 blocks genesis acceptance and operator sequencing remains open |
| MIG-P14 | Staged bounded owner harvesting/custody remains open |
| MIG-P15 | Every original category retained as a requirement; no unsupported category claimed delivered |

### All 53 original acceptance dispositions

| ID | Verified core portion / remaining full-plan gate |
| --- | --- |
| MIG-AC01 | Core ordinary acquisition/bond closure verified |
| MIG-AC02 | Legacy surrender before/after activation remains open |
| MIG-AC03 | Core gate precedes primary/swap; source-entry bypass matrix remains open |
| MIG-AC04 | Independent replacement/cut verified; source loading and operator batching open |
| MIG-AC05 | Current-owner core authorization and callback rollback verified; legacy/harvest roles open |
| MIG-AC06 | Legacy custody/credit atomicity remains open |
| MIG-AC07 | Original quote times actual remaining-principal fraction remains open |
| MIG-AC08 | Legacy old-reward exclusion remains open |
| MIG-AC09 | Cross-representation and recovery duplicate prevention remains open |
| MIG-AC10 | Harvest cannot resize new bond: unimplemented harvest path |
| MIG-AC11 | Distinct legacy LP-lock/funded/fungible units remain open |
| MIG-AC12 | Ordinary source defaults and inspected combined regression verified |
| MIG-AC13 | Genuine independent path verified; surrender counterpart open |
| MIG-AC14 | Independent cliff class/reward gate verified; surrender class integration open |
| MIG-AC15 | Core owner/role separation and no price setter verified; harvesting open |
| MIG-AC16 | Closed-stage actual funding demonstrated, but genesis F1 blocks acceptance |
| MIG-AC17 | Actual recovered DTF/legacy DETF conversion/donation remains open |
| MIG-AC18 | Every accepted legacy category still requires verified route closure |
| MIG-AC19 | Core exact cliff boundary positive principal verified |
| MIG-AC20 | Core accrued rewards/old ownership/repeat claim verified |
| MIG-AC21 | Frozen exact original credit verified in bounded fixture; surrender fraction open |
| MIG-AC22 | Core snapshot stability verified; live eligible-fraction equality open |
| MIG-AC23 | Historical routed-input/claimed-descendant/recovery duplicate prevention open |
| MIG-AC24 | Actual once-captured core book remains unchanged through activation |
| MIG-AC25 | Independent actual clock verified; per-surrender clocks open |
| MIG-AC26 | Actual core cut/activation atomicity and busy-child rejection verified |
| MIG-AC27 | Complete installed core removed-selector/restoration census verified |
| MIG-AC28 | Removed activation selector rejects; repeat package deployment does not restore it |
| MIG-AC29 | Retained core queries/donation/claims verified; surrender/harvest absent by scope |
| MIG-AC30 | No Migration pause; independent registry-disabled mature principal succeeds |
| MIG-AC31 | Local funding-first sequence verified; resumable operator workflow open |
| MIG-AC32 | Harvest owner-only implementation remains open |
| MIG-AC33 | Harvest bounded work/gas evidence remains open |
| MIG-AC34 | Repeat/overlapping harvest reconciliation remains open |
| MIG-AC35 | Authenticated transferred legacy attribution remains open |
| MIG-AC36 | Legacy remaining-principal delivery, not repricing, remains open |
| MIG-AC37 | Core administration removed; future source/config/root cutoff must be verified |
| MIG-AC38 | Independent overwrite preserves delivered bond/history; legacy consumption open |
| MIG-AC39 | Legacy proportional attribution/credit conservation remains open |
| MIG-AC40 | Final surrender/custody/issuance rollback remains open |
| MIG-AC41 | Partial fungible and whole-NFT surrender remain open |
| MIG-AC42 | Surrender recipient/current-holder proof remains open |
| MIG-AC43 | Core NFT terms/guarded transfer behavior verified; legacy surrender-created positions open |
| MIG-AC44 | Selected harvest whole-batch rollback remains open |
| MIG-AC45 | Staged recovery custody and fixed donation destination remain open |
| MIG-AC46 | Real per-proxy owner/child wiring and isolated-owner tests verified |
| MIG-AC47 | Core current/pending/former owner behavior verified; harvesting open |
| MIG-AC48 | Core compiled/interface/loupe and inherited surface census verified; V1 positive ingress gap remains |
| MIG-AC49 | Legacy NFT configured quote without issuance and actual-principal surrender open |
| MIG-AC50 | Legacy collection+ID/current holder identity remains open |
| MIG-AC51 | Separate-original recipient consolidation verified; operational held-exposure exclusion open |
| MIG-AC52 | Independent overwrite/replay/cut verified; legacy source end-to-end scenario open |
| MIG-AC53 | Required new-instance payout routes inspected and core gating positively exercised; not a full legacy/release acceptance |

### Feasibility and release gates

| Gate/task | Status |
| --- | --- |
| E1 / task 1 source route closure | Open: actual pinned code, units, ownership, custody, rollback and recovery route per source/generation |
| E2 / task 1 authenticated attribution | Open: ordinary legacy transfers/wrapping/claims and postactivation ancestry; no static allowance, original-payer restriction or trusted mutable approver substituted |
| E3 / task 2 actual recovery configuration | Bounded evaluator/artifact evidence retained; actual recovery asset/provider/route bindings, supported domain and operational inputs remain open |
| E4 / task 3 bootstrap | **Needs-fix: F1**; real balanced funding success is not full genesis-rule acceptance |
| E5 / task 5 payout closure | Substantial positive core evidence above; no early payout found in inspected graph. Not full-plan closure; V1 and explicitly qualified branch coverage remain |
| Tasks 4/7 | Independent core configuration/activation portions verified; source-dependent configuration and complete future administration cutoff remain open |
| Task 6 | Source-specific surrender/custody/proportional delivery unimplemented in this bounded core |
| Task 8 | Bounded staged harvesting/conversion/donation unimplemented |
| Task 9 | Deterministic evidence preparation, checkpoints, interrupted/mined-before-checkpoint resume and operator rehearsal unimplemented; this local script is not a substitute |
| Task 10 / final F1-F4 wave | Full hermetic release, pinned actual-legacy forks, stateful full-product invariants, operational gas/batch bounds, complete source matrix and resumable rehearsal remain open |

Required source rows remain explicit: weighted liquid DETF; earlier CP liquid
DETF; weighted fixed-principal NFT; earlier CP LP-lock NFT; weighted sDETF;
earlier receipt; legacy SY; TokenStaking/claim-vault rights; underlying SE
shares; fungible LP tokens. The two NFT models and fungible LP are not merged.
No zero-exposure claim is made for an unproved category.

No public deployment, actual recovery funding, reviewed allocation dataset,
public activation, compensation execution, legacy fork compatibility, or
operational authorization follows from this report.

## 7. Reproduction, failures, and cleanup

The required local commands are stored verbatim with the readbacks. The two
additional bounded proof commands, from the worktree with the selected
Foundry binary, owned TMPDIR/cache, and existing warm out/, were:

```sh
forge script --use solar \
  docs/incidents/2026-09-16-dtf-recovery/migration/core/verification/GenesisWitness.s.sol:GenesisWitnessRunner \
  --sig 'run()' -vvv

forge script --use solar \
  docs/incidents/2026-09-16-dtf-recovery/migration/core/verification/CallbackRollbackWitness.s.sol:CallbackRollbackWitnessRunner \
  --sig 'run()' -vvv
```

No source string/prose pin was added. The first witness checks actual funding,
live reserve, self supply and public payment preview. The second checks actual
callback behavior, rollback and mature payout. Their SUTs are real production
proxies; the fixture contract is not a SUT subclass. No parent impersonation,
storage injection, SUT etch/mock, or fake issuer is used.

Failed attempts are preserved, not relabeled passing:

1. The verifier's first Anvil used the default 10,000 ETH account balance.
   After 56 successful deployment transactions it could not wrap the fixture's
   full 10,000 ETH plus gas. The uncertain submission was reconciled against
   the actual nonce/block/receipts; no duplicate was sent. That node was
   stopped and the successful fresh node used sufficient native genesis
   funding. No source balance was forged.
2. The first fresh attempt encountered the previous unfinished script journal
   before broadcasting. A separately seeded verifier runtime cache removed
   that collision without changing the required argv, source paths, profiles
   or shared dependencies. A copy attempt initially treated the `.abi` cache
   directory as a file and failed; the actual Solidity cache seed was present,
   and the successful script reported compilation skipped.
3. The initial genesis harness used an incorrect getter signature and failed
   compilation. It was corrected to the real public payment preview. Its
   first execution then hit Foundry's ephemeral script-address restriction;
   a separate ordinary TestBase fixture contract resolved that harness-only
   issue. The final compiler/run and fresh diagnostics pass.
4. A first direct RPC helper queried a receipt before automining had completed.
   The actual failed reward transaction was recovered from its mined block.
   Subsequent sends registered a bounded WebSocket new-head signal before
   submission, without timing sleeps or duplicate sends.
5. The owner fixture's later `activate()` attempt fails on metadata for the
   already-retired NFT 3 before reaching activation. It is explicitly **not**
   counted as a removed-selector witness; a direct actual removed-selector
   transaction and the complete loupe comparison provide that proof.

There are no failures in the selected pre-existing producer focused/combined
regressions. V1 is an inherited-dependency fixture gap, not a regression
silently repaired in shared code. F1 is a defect in this new Migration
implementation and blocks bounded acceptance. JSON/HTML Biome LSP is not
installed; no installation/configuration change was made. Evidence JSON was
serialized from parsed RPC/artifact data. Initial Solidity diagnostic timeouts
were followed by fresh clean results for both verifier witnesses.

`cleanup.json` records both owned Anvil processes stopped, no listener on
18548, no matching owned Anvil process, WebSocket and WebView closed, and the
empty owned TMPDIR removed. The final node's stop tool reported an EPERM
removing its terminal monitor-state file; the actual process exited and the
independent port/process probes confirmed shutdown. No other session's node
or port was stopped. Runtime journals, logs, receipts, proof sources, metadata,
source/artifact manifests, warm out/cache, and shared dependency links are
preserved. There is no pending required execution.

**Final disposition: needs-fix for F1, with V1 and the stated proof limits
retained. This report neither certifies unfinished original-plan gates nor
authorizes a production correction or public action.**
