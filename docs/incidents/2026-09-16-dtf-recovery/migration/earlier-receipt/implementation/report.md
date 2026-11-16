# Bounded earlier ER Migration implementation

Date: 2026-11-12. **Producer disposition: complete for this bounded, stopped
custody and frozen-credit candidate. Conversion remains blocked.**

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`.
Branch: `work/dtf-migration-phase-18-earlier-receipt`.
Unchanged HEAD/base: `acdbe319f3a20c3af6bea594c62461b6c7988717`.
No commit or merge was made. Independent runtime verification is a separate
lane; this report does not grant its verdict or authorize a public operation.

## 1. Identity, authority and preservation

The complete implementation/original briefs, main-checkout plan
`migration-detf-implementation-plan-r5-owner-first-bond`, PRD
`migration-detf-discussion-r22-owner-first-bond`, accepted phase17 runtime
report and commit receipt/audit, phase11 earlier contract and verification
report/matrix, and referenced phase01/phase07 source/execution/provenance and
correction authorities were consulted. The later Stage2-only surrender,
immutable activation, current-owner administration and paid owner-first-bond
requirements govern conflicting historical prose.

The two root admission inputs remain byte-for-byte unchanged:

| Input | Bytes | SHA-256 |
| --- | ---: | --- |
| `../source/contract.md` | 22508 | `173bc343faf90a1d01ada52f16f86b0d707f6d87687bc438d9e209654bcbdc91` |
| `../source-verification/report.md` | 20560 | `86d0c1a22ffd398b528f9008c658a8fc51c39f273cdd50275faabd64668fbf35` |

The audit additionally checks all producer/verifier seal entries and exact
membership: **236 immutable files**, including both self-excluded seals.
The producer seal still matches the independent verifier's recorded producer
seal hash. No source/admission file was created, edited, removed or replaced.

The admitted fixed source is chain4663 ER
`0x4AC89aD061A531FA62ddceED53520C2750113b01`, pinned at block108944663,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The actual receipt facet is
`0x25E611FB63Eb904776678286EF5cbe2a931B4f9A`, runtime keccak256
`0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc`.
Its historical archive qualification remains **match, not exact_match**.
Actual pinned facet bytes were authenticated; no complete transitive legacy
recompilation or universally exact historical source match is claimed.

## 2. Implemented contract and complete requirement coverage

There are **34 changed/new source, test, operator and runbook paths**, of
which **11 are production roots**, all inside the admitted Migration-specific
interface/repository/target/facet/legacy-helper scope. No ordinary DETF,
common/Crane production, dependency, configuration, compiler profile or
held09 content was changed. Package/TestBase changes were unnecessary.
`audit.json` enumerates and hashes the exact paths.

| Brief requirement | Implementation and executed evidence |
| --- | --- |
| 1. Exact original units and frozen original pricing | `EarlierReceiptEntitlementInput` binds original identity/wallet, fixed source, positive exact internal Q0, explicitly known ETH/DTF, evidence identity and configuration hash including chain/proxy/snapshot. The removable claim/receipt allocation target evaluates the real frozen book, not a supplied award or source-helper C0. Complete replacements and replay create no issuance. Operator provenance binds the full original, exposure partition and genuine acquisition input/rate/internal allocation evidence. Unknown components, malformed quantities, selectable units/pricing and supplied credit are rejected. |
| 2. Actual pull and singleton proof | `MigrationLegacyRecoveryLib` observes both public external-share endpoints, both displayed endpoints, rate and total external shares immediately around the authenticated displayed-unit `transferFrom` requiring true. It computes candidate q with full-precision mulDiv, verifies both external floor/ceiling deltas and displayed consistency, builds checked L and H+1, and requires `rLow == rHigh == r`. Checked multiplication/increment failures and unresolved/inconsistent observations revert. Production has no diagnostic internal-share getter, storage RPC dependency or external-delta-times-scale attribution. |
| 3. Exact partial/terminal recurrence and residue | The retained Recovery target checks positive remaining Q/C, actual q within Q, positive proportional credit, minimum and deadline. Actual q==Q takes all C; otherwise floor(C*q/Q). Consumption, delivered credit, remaining Q/C and B update atomically. Real tests cover genuine divisible terminal, one-internal/one-credit residue, extra-input cap rejection and zero-credit rollback using a genuine acquisition denominator. Actual native input1 succeeds from a source wallet whose displayed balance is0: there is no incorrect absolute display cap. |
| 4. Owner, Stage1, canonical origins and permanent activation | Real registry instances test current/pending/accepted ownership, malformed second-row rollback, known zero components, wrong chain/source, complete replacement and replay. Every existing category excludes the ER canonical origin in both directions, including independent and already-issued originals after correction, both NFTs, WD, WY, W-SD, claim-vault and WS. Stage1 surrender rejects. The genuine paid first owner bond is required. Atomic activation removes all twelve administration selectors across both removable facets, including the new loader, while records and retained queries/surrender remain available. |
| 5. Stage2 custody, funding, cliffs and rollback | The configured original wallet performs the real approved pull under the shared parent reentry lock. Each success creates exactly one funded same-wallet90-day cliff with fresh start, correct principal/staking ownership and backing. Tests restore source balances/internal ownership, allowance, Q/C/B/E, supply, child staking/gons/backing and parent funding allowance after source, credit/minimum/deadline and late receiver failure. The receiver failure occurs after genuine funding, exercising rollback of the funding leg. Prior independent approval remains. Reentry fails; a legitimate later callback ER donation is unbooked and does not cause a false post-funding interval-equality requirement. |
| 6. Separate E/B inventory and preserved fractions | Existing `migrationRecoveryInventory(ER)` remains NFT-sale **external** shares E. Retained `migrationEarlierReceiptInternalShares()` returns standalone **internal** B. Whole external representation is floor(B/1e9); fractional internal representation is B%1e9. Both booking routes check total internal capacity E*1e9+B without changing either query unit. Real NFT3 sale at its actual unlock and standalone pulls execute in both arrival orders, preserving prior unrelated internal fractions. Whole external NFT minting remains separately measured. |
| 7. No new conversion or false recovery claim | No ER conversion, debit or donation recovery stage was added; the existing Stage enum and other recoveries remain intact. Status/runbook distinguish available bounded ER custody/credit from blocked liquidation. Direct ER and parent ED `VaultDisabled(ES)` evidence and historical FAIL/UNPROVEN labels remain retained, not rerun or relabeled as new successful liquidation coverage. No source governance enablement, owner impersonation to enable a vault, arbitrary executor or success decoder was introduced. |

Main production changes are in `IUniswapV4DetfMigration.sol`,
`IUniswapV4DetfMigrationRecovery.sol`, the Migration/Recovery repositories,
the Recovery target/facet, the primary allocation target, removable
claim/receipt allocation target/facet, and the two existing legacy
interface/helper files. All other old selectors/routes remain installed
or removed under their existing lifecycle rules.

`MigrationEarlierReceiptConfiguration.t.sol` supplies4 new configuration
tests, the retained `MigrationRecovery.t.sol` supplies4 supplemental arithmetic
tests, and the real `MigrationEarlierReceipt.t.sol` supplies9 pinned integration
tests. Mathematical vectors supplement actual source integration: they cover
unresolved/zero deltas, inconsistent rate/supply/display observations,
full-precision accepted products beyond uint256 multiplication, interval
overflow and inverse-bound increment overflow. They are not manufactured
legacy balances, rates, implementations or source total-share states.

## 3. Validation and real size enforcement

All final commands exited0. Full argv/root lists, bootstrap and failure history
are in `commands.md` and the retained logs.

| Gate | Final evidence | Result |
| --- | --- | --- |
| Artifact-first Solar production build | `build-04.log` | All11 edited production roots, Solar0.8.38 |
| Complete current Migration specs | `specs-02.log` | **142 passed**,0 failed/skipped,24 suites |
| Complete current pinned Migration forks | `forks-05.log` | **101 passed**,0 failed/skipped,19 suites |
| Both operator stages | `stages-01.log` | Stage00 environment and Stage01 execution build successfully |
| Strict TypeScript | `types-sealed.log` | All operator files plus evidence auditor; noEmit, strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes, verbatimModuleSyntax |
| One final combined operator-test invocation | `operator-tests-sealed.log` | **72 passed**,0 failed,8 files |
| Actual fixed18568 CLI | `cli-03.log` and `runtime-03/` | `bounded-rehearsal-complete`; all retained recoveries and3 actual mined-before-checkpoint/fresh-process resumes |
| Independent source/input/runtime/signature/economics audit | `audit-05.log`, `audit.json` | Validated after all runtime cleanup |
| Final seal | `seal.json`, `seal.log` | Revalidates the stopped source/input/artifact/runtime candidate and binds this report and all owned evidence |

Foundry's existing format-config, compiler/lint warning output is retained.
Fresh explicit Recovery-target and ER-runner LSP checks returned zero errors;
some edit-time LSP refreshes timed out, as recorded in the ledger. No error,
warning or failing test was suppressed. The complete compiler/type gates,
not edit-time diagnostic freshness, are the executable acceptance evidence.

Real deployed sizes are8713 bytes for the claim/receipt allocation facet,
24510 bytes for the primary allocation facet, and20416 bytes for Recovery.
The primary allocation facet has only66 bytes below EIP170. The actual Anvil
rehearsal retained code-size enforcement; no disabling flag or viaIR was used.
Every captured runtime, including linked libraries, satisfies24576 bytes.
Passing that check is not target transaction-gas acceptance.

## 4. Actual final CLI and exact economics

Final execution:
`runtime-03/rehearsal-1794471846294`.

The real local registry/package deployed Migration and its actual children.
A controlled empty wallet acquired10000 displayed ER through genuine
source transfer at r=2197. The exact original allocation was
Q0=`4551661356395084205735093309` internal shares, with total original
allocation equal to eligible allocation and explicitly excluded allocation0.
The acquisition file retains the original native input, rate, exact internal
allocation and authenticated facet identities.

Original ETH0.01 and known DTF0, then a full Stage1 ETH0.006/DTF0 replacement,
are **disclosed synthetic code-proof components**, not operational awards.
The actual frozen evaluator produced replacement C0=`2774608` native9
new DETF. Configuration/replacement/replay did not issue it.

Stage1 rejects and actual source approvals, missing-record and wrong-wallet
rejections, transfer away/back, real original-wallet Stage2 pulls and funded
bonds are retained with raw signed transactions/receipts. Actual DTF donation
to the old rate source changed ER r from2197 to4046 between operations,
without repricing C0:

| Operation | Native ER input | Exact internal q | New native9 credit | Remaining Q | Remaining C |
| --- | ---: | ---: | ---: | ---: | ---: |
| Partial at r2197 | 4 | 1820664542558033682294037 | 1109 | 4549840691852526172052799272 | 2773499 |
| Partial at r4046 | 1 | 247157686604053386060306 | 150 | 4549593534165922118666738966 | 2773349 |

C0 remains2774608; delivered1259 plus remaining2773349 equals C0.
Final B is`2067822229162087068354343` internal shares: whole external
representation`2067822229162087`, fractional internal representation
`68354343` (nine-digit fractional field`068354343`).
Existing E remains`485044501927175493321` external shares throughout both
standalone operations. E*1e9+B matches the actual source internal custody
observations; the inventory domains are not added directly.

Each operation's independently audited source debit/custody increase equals q;
displayed allowance decreases by exactly its native input. Both inverse bounds
equal the observed positive rate and total external shares remain unchanged.
The real new-share supply and receipt backing each increase exactly by the
delivered credit. Bond ownership, principal, fresh creation timestamp,
7776000-second cliff and Migration-position flag were checked on-chain.

The final archive contains **288 typed fixture receipt observations** and
**222 environment mined receipts**, not a claim that all are distinct
signed-wallet raw records. **21 raw source/wallet signed receipts** were
independently decoded, hashed, signer/nonce/to/data/chain4663/status/gas checked.
Separately, all **3 parent interruption journals** bind signed raw bytes,
successful canonical receipts, missing pre-resume completion, exact same
transaction hash/nonce and same canonical receipt after fresh-process resume.
They cover donation, independent issuance and the paid first owner purchase.
No duplicate funding/issuance/purchase or altered unclaimed supply was accepted.

The original18567 invocation remains accepted when adding18568. Signing
stays restricted to the owned fixed loopback rehearsals, with no public
fallback, provider substitution or source-only helper replacing Migration.
Fourteen category dispositions and all previous recovery/resume routes remain.

## 5. Exact bindings, failed attempts and final cleanup

`audit.json` binds:

* 34 changed/new source/test/operator/runbook files and11 production roots.
* 236 unchanged source/admission evidence files and21 external authority inputs.
* 23 original prepared-input files, checked against all final prepared manifests.
* 50 compiled artifact/runtime bindings across28 distinct artifact files;
  all286 compiler source keccak256 values match current raw inputs.
* 75 runtime capture entries, including shared-facet repeats and3 distinct
  transitive linked libraries; this is not75 distinct deployed contracts.
* 21 raw signed source/wallet receipts,3 real interrupted/resumed parent
  transactions and exact ER economic observations.

The actual bytes at every linked address are captured and matched against
current compiled library code/source. Link offsets are checked against the
correct library identity, and a library's compiler self-address guard is
bound to its actual address. Library addresses are not merely masked away.
Full raw runtime bytes, compiler artifacts/metadata, source/input hashes,
signed witnesses, receipts, economics and the report are sealed.

All failures and earlier attempts remain:
the wrong initial Forge PATH/Solar launches, shell quoting failure, stale
declaration assertions, checksum errors, genuinely locked NFT3 sale, the
alternate NFT4 original's E3 rejection, the first CLI's post-compilation
artifact-hash drift, strict auditor nonce decoding error and empty runtime
parent finding. No failure was changed into a pass by editing its evidence.
The final genuine NFT3 mixing proof waits for that source's actual unlock;
no maturity, source balance, source implementation or governance state was
fabricated. Prior CLI archives remain non-final, not substituted for the
current fully bound runtime03.

All three owned nodes exited; each checkpoint root was removed. The final
empty `.omo-runtime/dtf-migration-earlier-receipt` parent was inspected and
removed by exact-path `rmdir`. Port18568 has no listener. All owned source
impersonations and receipt subscriptions were closed. No owned runtime,
checkpoint, approval operation, monitor-backed execution or public action is
pending at handoff. Warm ignored compiler outputs remain for the independent
verifier; no foreign process, checkpoint or evidence was removed.

Source/test/operator modifications are stopped. The final seal excludes only
itself and its streaming `seal.log` from self-reference; it binds this report,
the ledger, auditor and every retained owned evidence file. No further source
or evidence edits follow successful final sealing.

## 6. Explicit limits and retained open work

This is bounded ER custody and frozen-credit implementation, not complete
recovery, operational allocation approval, full-plan acceptance or a public
deployment. Positive remaining Q/C is recorded state, not a pending operation
or a promise that future source rates make every residual redeemable.
Genuine terminal and nonrepresentable-residue behavior are separately proven
on real source acquisitions in the current Migration forks.

ER liquidation remains blocked by disabled ES
`0xb7D4Bb379d361aD442Cddee53EA71A33957826A7`. The retained direct and parent
`VaultDisabled(ES)` evidence has not been promoted to successful conversion.
Earlier liquid conversion, restricted/disabled SE and LP exits, raw-claim
atomic-pull limits and other source qualifications retain their prior
dispositions. No category was silently removed from the plan.

Operational original datasets, opaque-origin reconciliation, archive/host
portability, the full hermetic repository gate, full Migration plan completion
and target transaction gas remain open. The retained phase15 W-SD source
archive remains a host dependency. The phase17 weighted-receipt source and
admission are referenced at their actual retained worktree paths because
those non-committed source archives are absent from this new worktree;
they were not copied, fabricated or re-admitted. Their exact bytes are bound.

Prior parent deployment gas**44,353,454 exceeds32million**. It remains an
open target-chain finding, not acceptance furnished by this rehearsal's
permissive block/transaction gas. No improved current target-gas verdict is
claimed. The source measurement domain still rejects unresolved/overflow
states; supplemental arithmetic does not claim those artificial vectors were
manufactured in the actual legacy contract.

**Final: complete for the admitted stopped bounded candidate, subject to its
final seal and separate independent runtime verification. Conversion, broader
recovery and the listed open requirements remain unaccepted.**
