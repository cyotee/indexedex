# Fixed DTF-custody SE implementation handoff

Date: 2026-11-11.

**Producer result: complete for the bounded W-SD increment.** The final candidate
passes 122 current Migration specs, 71 pinned Migration forks, 62 operator tests
in one invocation, strict TypeScript, artifact preparation, both operator-stage
builds and the actual pinned port-18565 CLI with all three mined-before-checkpoint
resumes. Actual controlled-wallet acquisition, native-28 share custody, funded
partial/final surrender and selected ERC4626 redemption are recorded below.

**Source modifications have stopped. No owned runtime remains.** This report,
its bindings and seal are the final producer handoff, not temporary idle.
Independent verification has not been represented as already performed.
No commit or merge was made.

## 1. Admission and exact scope

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se`.

Branch: `work/dtf-migration-phase-15-dtf-custody-se`.
Unchanged HEAD/audited base: `2baab6e58dafcc3fe5f9a94570d99987d58bf42b`.
Initial tracked/untracked status was clean with `--ignore-submodules=all`.
Plain status encountered Git's prescribed Crane-symlink restriction; the
dependency link was not replaced. Root-prepared `out/` and configured
`cache_forge/` were present and warm before compilation. Crane and node_modules
remain links to the primary checkout. There is no staged change.

The complete phase15 brief, current main plan r5 and PRD r22, owner-first-bond
directive, complete phase11 weighted contract and independent report/matrix,
and complete phase14 independent runtime and commit reports were read.
Current Stage2-only surrender and the paid owner-first-bond prerequisite
supersede historical Stage1 surrender/amendment wording.

The candidate contains **34 source/test/operator/runbook files**, including
seven additions. `source-snapshots-final.json` contains their complete final
bytes. Production changes are nine existing Migration-specific files:
configuration/permanent/recovery targets, retained facet, repo and interfaces,
plus the existing legacy recovery library/interface. There are no ordinary,
common or Crane production changes, dependency/configuration changes, public
operations, source-governance changes, provider bypasses or held09
inspection/import/replay.

The design uses a separate fixed-source entitlement and consumption record,
the existing exact funded-bond path, and an append-only recovery stage.
It rejects a generic source adapter, arbitrary calldata/receiver, infrastructure
share impersonation as user authority, and live-rate compensation. Existing
recovery ordinals remain unchanged; `DtfCustodySeRedeem` is ordinal 9.

## 2. Authenticated source and real acquisition

| Binding | Value |
| --- | --- |
| Chain / historical L2 block | 4663 / 108944663 |
| Historical block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| W-SD source, native 28-decimal shares | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` |
| Fixed asset, native 18-decimal DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |
| Deposit/redeem facet | `0xDbcEEFf98F2388b0eFA0C0fDA2e08cdd263Ce8f5` |
| Pinned, archived and recompiled runtime keccak256 | `0x99b74f701969463d5147a782113b30bef06ef1c65f58902d410849d6d2cef616` |
| Actual deposit | `deposit(uint256,address) -> uint256`, selector `0x6e553f65` |
| Actual recovery | `redeem(uint256,address,address) -> uint256`, selector `0xba087652` |

The phase11 absolute archived locators were read:
phase01 `migration/evidence/verification/other-metered.sources.json`
lines 2339-2538 and `other-metered.json` lines 11077-11498, under
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/`.
Their infrastructure-held custody/redemption receipts remain mechanical
evidence, not proof of a user's original entitlement.

`source-archive.json` preserves the complete Sourcify response for the actual
facet. It reports exact creation/runtime matches. The archived
`RebasingAwareERC4626Target` forwards deposit into `executeDeposit`, which
checks inbound enablement, pulls the asset from `msg.sender`, checks exact
payment deltas and mints shares to the selected receiver. Its own-share
redemption burns the owner without allowance when caller equals owner and
pays the selected assets. The archived source was read before using these
calls; the deposit ABI was not inferred from an interface name.

`source-authentication.json` retains the actual pinned header, deposit routing,
capacity read, runtime bytes and each archived source's metadata-keccak
comparison. Archived solc 0.8.35 identifies the legacy deployment only;
all new compiling commands used Solar.

The preliminary `acquisition-gate.json` demonstrates an actual source deposit
and partial own-share redemption before implementation. The complete final
CLI separately repeats acquisition with a fresh controlled wallet:

| Final acquisition fact | Actual result |
| --- | --- |
| Wallet | `0x9c79357189d6af261691ecf48de9a6bbf30438fc` |
| Control | Public development wallet derivation index 104; runner signs source approval and deposit |
| Starting DTF / W-SD | 0 / 0 |
| DTF paid | `1000000000000000000` |
| Shares acquired | `10000000000000000000000000000` |
| Approval receipt | `0x9b09d4da336f648fc60ecc6836395b9c9f9e21c50807baa8fadf4120b8c15edd` |
| Deposit receipt | `0x89e058637c503c4364aa570c3878943538d8b04e1b3de89168f8ea274e325aeb` |

Both receipts have status 1 and the controlled wallet as sender. The deposit
contains the exact DTF wallet-to-source transfer, source share mint and
Deposit event. DTF funding came from the existing actual legacy NFT claim,
receipt unstake, liquid conversion and EOA transfer fixture. No hook/collector
share holding, fabricated token balance, source storage change or replacement
bytecode was used. Local EOA impersonation in that preexisting funding fixture
is explicitly distinct from the newly signed controlled-wallet acquisition.

## 3. Implemented behavior and actual integration

The setter requires nonzero original wallet, canonical economic origin,
evidence identity and eligible native-share quantity, the fixed chain/source,
and both contribution components explicitly known. It computes C0 through the
existing frozen mint-preview accounting. Stage1 full replacement and identical
replay issue nothing. Known-origin collision checks work in both directions
against independent compensation, either NFT family, WD and WY, including
wallet correction and already issued independent exposure. Opaque origin keys
still require operational economic partitioning.

Stage1 surrender rejects before any pull. Stage2 requires the matching
configured original wallet, exact approved share debit and custody increase,
positive proportional frozen credit, valid amount/minimum/deadline and atomic
funding. It books only newly received q and creates one exact-funded fresh
90-day cliff bond. Partial credit uses full-precision remaining C*q/Q; final
surrender takes all remaining credit. Unsolicited shares are not booked.

Current-owner recovery debits only selected booked shares and calls
`redeem(q,MIG,MIG)`. It checks exact share decrease and positive measured DTF
receipt equal to the returned assets and satisfying the selected minimum.
Recovery changes neither C0 nor delivered compensation. Assets remain in
Migration between transactions; donation keeps the fixed new-DETF destination
and existing protected-inventory budget.

Final real run:
`rehearsal-1794441190961/`.
Migration:
`0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Funded frozen snapshot:
`0x0078ac6ed906aec6ff9899fd48c54c46db18d9588914f882834614daa321b6d8`.
Final W-SD configuration:
`0x1e9e5ec8dc04081f85395304c8a072b3a674f1acff008a7a4d76097a05f063e6`.

**Original compensation inputs are synthetic, not approved historical
allocations.** The first configuration used the actual acquired share quantity,
known ETH 0 and DTF 1e18. Stage1 replacement used
Q0=`9999999999999999999999999993`, known ETH 0 and DTF
`600000000000000000`. C0 is **277328729 native new-DETF units**.
The seven excluded shares form an actual unsolicited-custody witness.
These fixture choices are not inferred historical awards or a live share price.

Initial and replacement configuration receipts are
`0x9c0fe91877cd7f3b252efc6dd037e84307a511f1b61ddf1e74707bfd5410caa2`
and
`0x2971118bf77605f000f9209532223ac750ee633a136a77350e8088ccd80f2634`.
The full configuration ABI hash was independently recomputed from the actual
final inputs and snapshot. Stage1 configured and missing-record calls both
mined status-0 `MigrationSurrenderClosed` receipts with no effects.

| Surrender | Native 28-decimal shares | Credit | Bond | Remaining Q / C |
| --- | ---: | ---: | ---: | --- |
| Partial | 3333333333333333333333333331 | 92442909 | 16 | 6666666666666666666666666662 / 184885820 |
| Final | 6666666666666666666666666662 | 184885820 | 17 | 0 / 0 |

Actual surrender receipts:
`0x86f04d85b4de0a3858644665af96ff885adfae05dccc4700845c1df27e112d01`
and
`0x06a31b40d5797160ef94b44112c16880fdcd2d340203f6b166d6b4395c53390c`.
Their raw share transfers, new-DETF mint/funding and bond events reconcile.
Partial credit independently recomputes to floor(C0*q/Q0); both credits sum
exactly to C0. Actual bond starts are 1825762631 and 1825849046, each with
duration 7776000. These are simulated local block timestamps, not public
issuance dates. Funded gons are respectively
39978112030692076788462088785436529383762278 and
79870001027932629052503172863810452403245160.

| Selected recovery | Partial | Final |
| --- | ---: | ---: |
| Exact shares burned | 3333333333333333333333333331 | 6666666666666666666666666662 |
| Measured native DTF | 333333333333333333 | 666666666666666666 |
| DTF donated | 166666666666666666 | 333333333333333333 |
| Protected unbooked shares | 7 | 7 |

Redemption receipts:
`0x679b7c145f97161344e6ea03c3c47d12806454ba65142194bd04810383fc559e`
and
`0xb951a4aa9f8537c7d9401351a5bea45b327185aa38d2df0af967a34bb99cff59`.
Their source Withdraw events, share burns, DTF transfers and Migration recovery
events agree. Values are measured outputs, not historical outputs reused as
future quotes. The self-share redemption allowance remains zero.

For each portion, actual output-minimum, failing-second-item and later-overdraw
transactions have status 0 and zero logs. Executed state comparisons establish
whole-selected-batch rollback and preservation of the prior committed receipt.
The two final-destination donation receipts and all failure hashes are indexed
in `runtime-index.json`. Actual transfer-away/wrong-wallet/return, absent
configuration, removed-loader replay and final-exhaustion receipts are retained
in the corresponding run observations.

Pinned forks additionally prove changed source redemption value does not
reprice C0, non-18 output rounding, actual contract-wallet acquisition and
rejecting-bond callback rollback, owner/pending/former-owner recovery,
insufficient booked shares, mixed NFT/WD/WY inventories and unsolicited share/
DTF floors. Donation preserves funded backing and prior source recovery.
No source or subject is replaced to obtain those positives.

## 4. Preserved owner purchase, activation and resumes

The actual paid owner purchase remains bond 6, receipt
`0xfdf7f9e43d6f29a10ef8cb91a9844dd746987b627f4520c526a0ff621eb1389c`.
Payment is 1e18 native payment-token units, principal 465583908, funded rewards
84489332 and accounted backing 1383 -> 550074623. This is an ordinary purchased
bond, not a migration cliff or synthetic participation seed. Independent
compensation alone fails activation. Stage1 reward and duplicate-purchase
failures remain actual mined negatives.

Activation receipt
`0x6b1c61ddf810cc95ff31e91743fe16f74e91b4a67bdd988dcfc6bc4a98d3c7f7`
removes all **nine** exact interface-derived administration selectors,
including `0x9ade58a9`, the new loader. Raw DiamondFunctionRemoved events were
compared with the interface-derived set; receipt-block routing checks and the
real proxy specs also pass. A nonowner ordinary deposit subsequently returns
462096413 new-DETF units with zero refund.

Earlier NFT, W-L and WY positive routes remain in the real sequence. New bond
IDs are derived from actual events; the W-SD increment does not relabel the
earlier sale-and-hold route as liquidation. The fourth independent recipient
remains unissued under its separate allocation record.

| Real mined interruption | Nonce | Same transaction recovered by fresh-process resume |
| --- | ---: | --- |
| Donation | 2120 | `0xa8b439e6b2f2e5983ffb586ac6bd8ac0bfc38db59ca0037724dc83ec014dcaf2` |
| Independent issuance | 2135 | `0x889b3d59acefab0318b9447304a5ed08ff3a8bfe70bbceda14046f90f2e77178` |
| Owner purchase | 2152 | `0xfdf7f9e43d6f29a10ef8cb91a9844dd746987b627f4520c526a0ff621eb1389c` |

For every interruption, the saved completion marker is absent while the
successful receipt exists. Signed-intent decoding reproduces its hash, nonce
and signer. All 15 canonical receipt fields match the resumed journal receipt;
the reconciliation does not trust the runner's equality Boolean. Actual
SIGKILL command records, read-only resumes, execution resumes, repeated owner
purchase reconciliation, outstanding-row reorder and unclaimed zero issuance
are retained.

The final run has 203 fixture receipts, 45 operator receipts and 47 command
records. Six deliberate domain rejections and three deliberate SIGKILL
interruptions are expected witnesses, not failing final acceptance checks.

## 5. Final checks, bindings and corrected attempts

All required **final** checks exit 0:

| Check | Final result | Raw evidence |
| --- | --- | --- |
| Artifact-first complete Migration specs | 122 passed, 0 failed/skipped | `specs-final.log` |
| Artifact-first complete pinned Migration forks | 71 passed, 0 failed/skipped | `forks.log` |
| Artifact preparation and both operator stages | Exit 0 | `operator-artifacts.log`, `operator-stages.log` |
| Five operator test files, one invocation | 62 passed, 0 failed | `operator-tests.log` |
| Strict TypeScript, including final sequencing fix | Exit 0 | `operator-types-final.log` |
| Actual fixed18565 CLI | `bounded-rehearsal-complete`, exit 0 | `rehearsal-final.log`, final run directory |

`checks.json` records full commands, all nine changed production roots,
monitor identities and actual exits. Forge is 1.9.1-nightly commit
430523103f3e2f9ba432ffdd2031a9f966153d0d; compilation reports Solar 0.8.38
and every compiling command selects `--use solar`. Executed Bun is 1.4.2.
Existing compiler warnings remain visible.

Two corrected attempts remain archived:

1. The first spec run passed 121 tests and failed the retained-selector
   declaration, whose control still listed 26 functions. It now includes the
   four new interface selectors, preserving the exact declaration test.
   The complete final suite passes 122/122.
2. The first CLI acquired W-SD before the environment stage, spending 1 DTF
   from that stage's required 10000-DTF balance. It stopped at the existing
   real-funding assertion. Acquisition now follows environment setup; no
   funding assertion or source balance was bypassed. The failed run
   `rehearsal-1794441130445/` and its cleanup are retained. A fresh complete
   run supplies the final proof.

Initial source-access/launch interpolation mistakes were corrected using the
same configured archive alias and existing login-shell credential, without
provider substitution. The monitor rejected an excessive timeout parameter
before starting a compile; finite persistent monitors then ran the checks.

Production and new fork/rehearsal file diagnostics were clean. The TypeScript
language server retained a stale missing-module diagnostic in `rehearse.ts`;
strict TypeScript read the actual full file set and passed twice. JSON Biome
LSP is unavailable. Neither dependency nor configuration was changed.

`bindings.json` binds 34 final source files, nine authority inputs, two exact
historical archives, **120** bounded raw artifacts and **398** retained
implementation evidence files. The final source snapshot differs from the
earlier pre-CLI snapshot only in the documented sequencing fix.
All **706** distinct compiled metadata source identities match actual final
source bytes. All 120 artifact raw hashes remain unchanged across final CLI
execution; there is no concealed artifact drift.

The 31 captured parent/package/child runtime byte arrays match their recorded
hashes. Ten listed Migration artifacts match actual deployed bytes, masking
only the recorded compiler-artifact link-reference spans. This includes all
three changed permanent/allocation/recovery facets. The latter has no masked
spans. Other captures, including immutable-bearing package bytes, are
hash-bound, not claimed independently byte-identical.
`artifact-runtime-reconciliation.json` records these exact limits and spans.

No unchanged ordinary/common full shared suite or full hermetic monorepo gate
was run; this task's complete current Migration spec/fork gates were run.
The prior weighted-SY commit audit's historical aggregate-preservation
qualification remains explicit: this report does not adopt unretained
pre-commit aggregate inventories as independently proven.

## 6. Cleanup and limits

The final CLI closed providers/subscriptions, stopped its holder impersonations,
copied journals, stopped Anvil PID 94555 and removed the fixed checkpoint.
The failed run's PID 93710 is also absent. External port-18565 and PID probes
return exit 1 with no entries; checkpoint-absence, empty owned-runtime-parent
removal and whitespace checks return 0. `cleanup.json` retains commands and
output. All execution monitors have terminated. No owned runtime remains.

Final source/authority/compiled-source bindings were rechecked. HEAD and branch
remain the admitted values, no files are staged, and shared warm artifacts and
dependency links remain in place. Producer writes are confined to the scoped
candidate and this `implementation/` evidence directory; the independent
`verification/` directory is not authored here.

Other source categories and original operational wallet/origin/Q0/component
datasets remain open. Synthetic allocation inputs do not become approved
historical awards because real source custody works. W-SD success establishes
neither disabled W-SW, earlier SE, nor owner-restricted LP recovery. No global
semantic disjointness of opaque origins is claimed.

Actual local parent deployment consumed **43770976 gas**, above the retained
historical 32000000 transaction limit, on the permissive local node.
This is a receipt observation, not target-gas feasibility, a live funding quote,
full-plan completion or authorization for public deployment, funding,
activation or compensation execution.

**Final producer handoff: bounded W-SD implementation complete; required final
checks pass; source modifications stopped; no owned runtime remains.**
