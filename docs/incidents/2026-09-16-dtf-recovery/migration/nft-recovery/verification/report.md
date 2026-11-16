# Independent bounded NFT recovery verification

Date: 2026-11-11.

**AdversarialVerify: needs-fix.** The recovery native-unit budget permanently
excludes redeemable growth attributable to its own weighted receipt gons.
That violates original task 8's requirement that newly accrued assets remain
harvestable. This is a missing legitimate conversion path in the requested
bounded recovery behavior, not an external disabled-route limitation or an
owner-approved residual policy. Finding R1 below blocks bounded acceptance.

Both actual legacy NFT models were surrendered to genuine registry Migration
proxies and the implemented stages executed through installed selectors.
Earlier claim-and-hold and sale-and-hold work; earlier liquidation is **not**
confirmed. Successful executions do not erase R1.

Independent execution passed **19 pinned recovery fork cases, five focused
hermetic cases, and one additional two-source sequence**. A further terminal
NFT witness successfully **reproduces R1**, with a genuine legacy-holder
control proving that the source can redeem accrued receipt value. The current saved
**96 Migration specs and 9,932 ordinary/common regressions** reconcile with
their individual results and fingerprints; the large suites were not repeated.
All owned execution has ended. General harvest, E2, remaining source categories,
operator/resume and release gates remain open.

## 1. Scope, provenance and findings

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
- Independently checked branch: `work/dtf-migration-phase-07-recovery`.
- HEAD before and after: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
- The reviewed recovery implementation is the **existing uncommitted producer
  delta on that baseline**, not code already contained in the commit.
- Root's successful warm seed is supplied provenance. The verifier did not
  repeat it, rewrite dependency links, or claim the producer delta was clean.
- Read the complete phase07 brief, original main-checkout
  `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
  repository/canonical deployment, architecture and testing rules, complete
  phase01 independent report, accepted phase05 source contracts and runtime
  verification, both phase07 source contracts, source gate, producer report,
  current source/TestBase/tests, and actual archived source and receipt evidence.

### R1 - High: attributed weighted receipt growth has no executable recovery path

Locations: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol:64-65,72-89`
and `UniswapV4DetfMigrationRecoveryRepo.sol:25-30`.
Original plan task 8 requires "newly accrued assets remain harvestable";
MIG-P14 and section 5.6 require measured, staged recovery without recounting.

W1 credits only the native amount received at its claim index and separately
records its attributed gons. When the old receipt index later falls, those
same recovery-owned gons represent more native units. W2 spends/debits the
original native inventory before calling the legacy source. Once that
inventory reaches zero, every positive W2 amount rejects even if the
attributed-gon ledger and real balance contain whole redeemable units. W1 is
the only positive writer of that native inventory; no reconciliation or
accrual-conversion entrypoint can make the existing attributable growth
spendable. A new NFT claim is not a legitimate substitute for recovering
growth on already-held receipts.

**Independent executed counterexample:** `sequence-independent.log:16580-16631`
shows 8,569,202,768,080,137,873,356,303,538,242,130,618,948 actual and attributed
gons, divisor 875,382,550,842,690,052,048,542,616,171,208,246,
and native inventory zero. This is **9,789 whole native 9-decimal receipt
units**, plus fractional remainder, not merely sub-native dust. All of those
gons are attributed; unbooked gons are zero. A one-unit W2 call still reverts
`RecoveryInventoryInsufficient(WS,1,0)` before reaching the legacy receipt.
The exact same admitted source can debit a native unit against its canonical
gon ledger; this failure is the new wrapper's stale budget.

**Terminal-NFT reproduction:** `RecoveryAccrualWitness.s.sol` starts from the
same historical pin, genuinely surrenders weighted NFT 3, and claims its
4,308,806,205 WS through the Migration proxy. The legacy NFT burns. After
eight hours, recovery unstakes the original budget but leaves
**427,882,030,360,010,419,822,646,177,042,295,082,020,945 gons** at divisor
**875,382,550,842,670,612,356,981,754,173,735,900**. Actual receipt
`balanceOf(MIG)` and independent division both equal **488,794 whole native
units**. All held gons equal attributed recovery gons; unbooked gons are zero.
The native budget is zero, one-unit W2 rejects, and a new W1 on the burned
NFT rejects `InvalidRecoveryCustody`. There is no surviving NFT accrual that
could refresh this exhausted native claim budget.

A separate genuine legacy holder directly unstakes its full displayed
receipt balance through the same historical W2 selector, including
**7,919,334 newly accrued native units**. The actual WD balance increases
by exactly the returned amount and its receipt gons become zero. This control
does not impersonate Migration or source infrastructure and does not fake a
Migration success; it distinguishes an executable source route from the
wrapper's missing budget authorization. The terminal event is
`accrual-independent.log:16508`; exit 0 means the defect reproduced, not that
harvestability passed. Exact command, fingerprint and values are in
`accrual-evidence.json`.

The safeguards remain necessary but do not justify this result:

- **Unbooked-gon floor:** do not spend/retire unrelated gons. A legacy full
  account exit that would retire an unbooked fraction may genuinely have to
  reject or use a smaller selection.
- **No duplicate NFT claim:** revaluation is not another claim event,
  principal payment, compensation credit or new gon transfer.
- **Attributed growth:** the already tracked recovery gons establish
  provenance. Their synchronized whole-unit redemption value is legitimate
  recovery inventory, even when the original claim's native budget is zero.
  Value below one native unit is a different rounding limitation; a lack of
  a path for whole units is an implementation defect.

**Correction direction, not a production edit:** make the selected W2 spend
authorization/reconciliation account for the synchronized value of attributed
recovery gons, with a separately identifiable accrual/representation adjustment
rather than another NFT claim. Retain the actual-gon debit bound and exact
unbooked floor, measured WD output, fixed MIG destination, deadline, common
lock, selected-batch atomicity and allowance policy. Prove a completed/burned
NFT's later receipt growth can be converted through the actual Migration
proxy, including when native claim inventory is zero, without spending
unbooked gons or creating new compensation. No arbitrary executor or new
source route is required to address this missing accounting path.

The source gate's instruction not to expand native budget was an engineering
interpretation, not an owner policy lock overriding task 8. The initial
`confirmed` interpretation of permanent attributed residuals is withdrawn.
No production, test, or producer/source-gate evidence is changed by this
verifier; correction and independent re-verification remain required.

The original plan remains SHA-256
`56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`.
All 12 fingerprinted historical/plan/source inputs match before and after.
All 146 source files checked for preservation are unchanged. The tracked
producer diff is byte-for-byte unchanged, including the four existing-file
wiring/fixture edits. The 12 producer new-source/test fingerprints also match.
No uncommitted phase05 code was imported.

Evidence in this directory:

| Artifact | Purpose |
| --- | --- |
| `evidence.json` | Exact commands, exit statuses, current-source/artifact/receipt comparisons, result counts, trace locations and cleanup |
| `commands.md` | Human-readable admitted-path replay command |
| `fork-independent.log` | Complete new 19-case recovery replay, including real W4 and selected-work measurements |
| `spec-independent.log` | Five new executions of recovery declaration, guard, callback and gon-floor cases |
| `RecoverySequenceWitness.s.sol` | Independent booked-index/configuration-replacement/two-source witness |
| `sequence-independent.log` | Successful witness and full genuine deployment/artifact-loader trace |
| `RecoveryAccrualWitness.s.sol` | Terminal burned-NFT reproduction of stranded attributable growth, plus genuine source-holder control |
| `accrual-independent.log`, `accrual-evidence.json` | Actual R1 reproduction, command, values and artifact preservation |

Historical execution state is Robinhood chain **4663**, L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
The executed fixture checks the header and Orbit L1 `BLOCKNUMBER` value
**26367659**. There is no fresh-pin fallback. This is not the new DETF's
funded quote snapshot.

Every new execution is an isolated **in-process Foundry local-fork call**,
not a public broadcast or mined Anvil receipt. Earlier phase01 mined local
receipts are independently joined and retained as historical source evidence.

## 2. Exact admitted/blocked stage matrix

`MIG` means the actual registry-deployed Migration proxy. The only mutating
recovery entrypoint is `recoverMigrationNfts(Step[],uint256)`. Its finite
`Stage` enum fixes the following operations. It accepts no arbitrary target,
selector, calldata, source, beneficiary, executor, adapter or pretransfer flag.

| Stage / enum | Exact proxy call and units | Independent disposition |
| --- | --- | --- |
| W1 / `WeightedClaim` | MIG -> weighted NFT `claimBond(id,MIG)`, `0x084c59ae`; returns separate native 9-decimal principal/rewards in old sDETF | **Confirmed.** Mature ID 3 pays 3,772,281,649 principal + 536,524,556 rewards = 4,308,806,205 receipt units and burns. Partial and repeated live claims remain supported. |
| W1 / `WeightedPrincipal` | MIG -> weighted NFT `claimPrincipal(id,MIG)`, `0xf400c743`; one native 9-decimal receipt amount | **Confirmed.** ID 4 partial principal, same-time zero repeat, later vesting and final principal payment execute. Reward-only continuation is retained. |
| W1 / `WeightedRewards` | MIG -> weighted NFT `claimRewards(id,MIG)`, `0x6c7b69cb`; one native 9-decimal receipt amount | **Confirmed.** Separate rewards and final reward-only burn execute. Burned repeat rejects; a zero live payout is not falsely marked complete. |
| W2 / `WeightedUnstake` | MIG -> old weighted sDETF `exchangeIn(WS,q,WD,q,MIG,false,deadline)`, `0xd02d3063`; historical **one-word** return | **Initial-budget executions pass; acceptance needs-fix (R1).** Full 4,308,806,205 units and partial mixed-inventory exits pay the same native 9-decimal WD quantity and protect unbooked gons. Later whole-unit value attributable to recovery gons cannot be spent after native inventory reaches zero. |
| W3 / `WeightedConvert` | Exact temporary `WD.approve(WD,q)`; MIG -> WD `exchangeIn(WD,q,DTF,min,MIG,false,deadline)`; clear approval | **Confirmed for the executed reserve-swap branch.** 4,308,806,205 WD produces 24,312,424,763,253,115,621,623 native 18-decimal DTF at MIG. This is not an executed proof of every primary-burn state. |
| ER1 / `EarlierClaim` | MIG -> earlier NFT `claimRewards(id,MIG)`, `0x6c7b69cb`; native 18-decimal earlier DETF | **Confirmed claim-and-hold.** Locked ID 3 pays 124,873,542,679,524,901 units, repeats at zero, then claims genuine additional funded accrual. Original shares and ownership remain. Mature ID 4 pays 309,005,608,995,105 units. |
| ER2 / `EarlierSale` | MIG -> earlier parent `sellPositionToDetfNft(id,MIG)`, `0x6b7d927e`; return is retired original LP-accounting shares, not receipt output | **Confirmed optional mature sale-and-hold.** ID 4 retires 2,281,854,312,954,086,546 original shares; the baseline sequence mints 1,967,558,883,021,387,942 external receipt shares. NFT/position clear, physical LP custody is unchanged, and remaining rewards are measured separately. Prior claim rewards are not counted twice. |
| W4 / `Donate` | Selected booked DTF enters MIG's existing protected reserve budget; LP recipient is its bond custody | **Confirmed only for supported recovered DTF.** The selected 1e18 DTF fixture produces 176,474,176,609,502,837 reserve LP units. Pre/postactivation execution, registry rejection, rollback and callback tests pass. Unjoined residual belongs to the existing reserve residual domain, not a second recovery budget. |
| Earlier mature close | Earlier parent `closeBondMature(id,[0,minDtf],MIG,deadline)`, `0x7c212893` | **Blocked; no recovery stage installed.** Exact disabled-SE failure is retained. A newly executed external wrong-owner call against an already-custodied NFT reaches this same error and restores all effects. That is not an ownership-safety PASS. |
| Earlier parent receipt redemption | Earlier parent `redeemClaim(amount,ED,min,MIG,deadline)`, `0xbfe55606` | **Blocked; no recovery stage installed.** Historical actual receipt reaches the disabled earlier SE and rolls back. No successful liquidation or new Migration call is invented. |
| Earlier direct receipt redemption | Earlier receipt `redeem(amount,MIG,false)`, `0x5236be40`; nominal output DTF | **Blocked; no recovery stage installed.** Historical actual receipt reaches the same disabled SE. True pretransfer is not a fallback. |
| Earlier liquid DETF conversion / resulting donation | Earlier parent `exchangeIn(ED,q,DTF,min,MIG,false,deadline)` | **Unproved and not admitted; unimplemented.** Weighted conversion success does not establish this route. ED and earlier receipt shares remain separate held inventories, not automatically supported donation legs. |
| Direct NFT retirement, receipt administration, standalone legacy LP exits | Old-parent-only internals / owner-restricted reserves | **Not admitted as substitute holder routes.** No source-owner or MIG impersonation, registry enable, fake success, or alternate destination was introduced. |

Fixed identities:

| Identity | Address |
| --- | --- |
| Weighted NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` |
| Weighted sDETF, WS | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` |
| Weighted liquid DETF, WD | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` |
| Earlier NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` |
| Earlier liquid DETF, ED | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` |
| Earlier receipt | `0x4AC89aD061A531FA62ddceED53520C2750113b01` |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |

Earlier receipt inventory is in **external shares**, internal scale **1e9**;
its displayed ERC20 balance is a valuation, not the booked quantity.
Original NFT accounting shares, effective reward weight, physical LP,
external receipt shares, weighted gons, old liquid tokens and new Migration
principal are not interchangeable.

## 3. Authority, accounting and atomicity

Source prefix `M` below means
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

`M/UniswapV4DetfMigrationRecoveryTarget.sol:34-62` acquires the common parent
lock, checks the current proxy-local Crane owner, requires all five children
idle, enforces chain/deadline, executes selected steps without catch-and-skip,
and synchronizes expected holdings. There is no activation restriction.
The real ownership acceptance changes the owner without the delay implied by
some Crane comments; the proof uses actual current/pending/former-owner
transitions, not an invented buffer.

`M/legacy/MigrationLegacyRecoveryLib.sol:27-41` authenticates permanent
consumption plus matching immutable custody/configuration-at-surrender and
actual current NFT ownership. Unsolicited unsafe custody is rejected.
Recovery does not reapply surrender's positive-remaining-principal rule to
an already-surrendered reward-only position. Every legacy recipient is MIG.
No NFT approval or approval-for-all is granted by recovery.

The ledger implements, separately within each token/unit:

```text
inventoryAfter = inventoryBefore + newClaims + conversionOutputs
               - conversionInputs - donations
```

W1 measures newly received gons at one synchronized divisor; old receipt
revaluation is not another claim. W2 separately debits its native budget and
actual attributed gons. W3 verifies actual input debit and DTF delta against
the historical one-word return. ER2 measures external receipt shares rather
than displayed balance or its original-share return. No cross-token recovered
value total counts a receipt and its later conversion output twice.

For W4, `RecoveryTarget.sol:65-86` debits only selected recovered DTF, opens
the existing budget, lowers only that token's operation floor by the selected
amount, and requires positive/minimum LP output. The reviewed policy at
`M/UniswapV4DetfMigrationPolicy.sol:18-55` protects prior balances outside the
existing residual domain. Ordinary common sweep work reads those overridden
budgets, clears temporary approvals and sends LP to `_bondLpHolder()`, not the
owner. Existing residual authority remains the existing authority.

Key new replay locations in `fork-independent.log`:

| Obligation | Actual proof |
| --- | --- |
| Current/pending/former owner, before/after activation | `:235729`; actual acceptance both before and after activation; recovery remains installed |
| Both source custodies, fixed recipients, final weighted conversion | `:244223`; genuine surrender, actual source calls and swap-reserve input delta |
| Partial, zero-repeat, new vesting, reward-only final burn | `:240724`; source state and booked inventory checked |
| Preexisting weighted receipts and changing index | `:237471`; old unbooked gons survive both partial exits exactly |
| Earlier locked claim and new accrual | `:4553`; real donor source rewards fund the later claim |
| Earlier sale with preexisting ED/receipt holdings | `:5212`; only local deltas booked, zeroed position, unchanged LP |
| Failed middle weighted item / smaller retry | `:239424`; preceding inner claim, gons, NFT state and ledger all roll back |
| Failed middle earlier sale / staged retry | `:6349`; locked middle sale rolls back the preceding claim; later excessive sale minimum preserves a previously committed claim |
| Committed W1/W2 survive failed W3 | `:233345`; input inventory and zero allowance remain; corrected retry succeeds |
| Committed W3 survives failed W4 | `:93014`; balance, LP and recovery inventory restore; smaller retry succeeds |
| W1 -> W2 -> W3 -> W4 whole-selected-transaction rollback | `:147499`; impossible final LP minimum returns `MinAmountNotMet`, all selected stages revert, corrected selection succeeds |
| W4 protection and retained activation behavior | `:7826`; 1e18 older donation budget and 7e18 unsolicited DTF stay protected |
| Actual staking-SY packets, raw-SY backing and self-leg | `:202750`; recovery/donation preserves these and delivered-bond accounting |
| Malicious external-token callback | `:65093`; current-owner rate token attempts recovery, activation, surrender and donation; all four return `IsLocked()` while the actual outer donation succeeds |
| Route-specific registry behavior | `:232161`; new-parent disable blocks W4, not the admitted claim/unstake/conversion holding stages |
| External earlier wrong-owner close | `:3832`; exact disabled error and rollback, explicitly not an ownership guard success |

The genuine surrender helper checks source ownership, cleared token approval,
absence of Migration's operator grant, exact new principal, holder, fresh
90-day duration and zero funding allowances. Current producer fork evidence
also retains the 16 accepted NFT custody/receiver/rollback cases; these were
not redundantly rerun here. The five focused hermetic executions check the
four interface-derived recovery selectors through declaration and actual
postactivation proxy routing, unused-field rejection, empty inventory,
callback exclusion and the numerical gon-floor boundary.

No recovery path calls `_fundBond`, ordinary bond purchase, or independent
issuance. The executed protected-state assertions include delivered bond
fields/holder, total new supply, staking backing/state/gons, SY backing,
self-leg balance, bootstrap issuance and older donation budgets.

### Additional independent sequence

`RecoverySequenceWitness.s.sol` adds a temporal composition not covered by
the producer's mixed-unbooked-inventory test: **W1 books receipts first, then
W2 itself synchronizes a later index**. It also replaces consumed NFT
configuration with deliberately different original-unit values before
recovering both models through their immutable execution records.

The genuine proxy first claims **86,292,556 WS** from weighted ID 4 and
**309,005,608,995,105 ED** from earlier ID 4. After eight hours, W2 unstakes
exactly the booked 86,292,556 native units. Appreciation leaves
**8,569,202,768,080,137,873,356,303,538,242,130,618,948 attributed gons**
held while the native spending budget is zero. A further one-unit unstake
rejects `RecoveryInventoryInsufficient`, rather than spending appreciation.

A selected two-source call then claims **18,184,063 new WS** and sells earlier
ID 4 into **1,967,558,883,021,387,942 external receipt shares**. Only those new
receipt gons increase the existing attributed-gon ledger. The previously
unstaked WD converts into **487,382,633,669,890,051,746 DTF**. Current
allowance is zero, both delivered bonds and protected backing are unchanged,
and both permanent surrender/custody records remain byte-equal despite
configuration replacement. The final event is
`sequence-independent.log:17875`; the script exits 0.

This witness exposes **R1**, not an acceptable permanent-residual policy.
The retained appreciation contains 9,789 whole native units at the measured
divisor. A successful script means the observations and rejection reproduced;
it does not mean task 8's harvestability contract passed.
The distinct **unbooked sub-native fraction** boundary uses the exact
production checker with numerical inputs (23 total gons, 20 attributed);
it is not represented as a naturally constructed pinned-source fractional
balance. The actual mixed-inventory and booked-index tests are separate.
Likewise, no naturally zero-share earlier sale was manufactured: actual
positive sale and excessive-minimum rollback execute; the zero-share
production rejection is source-reviewed.

## 4. Source, artifact and result reconciliation

The verifier compared all **40 phase07 source excerpts** to actual unescaped
phase01 archives, recomputed **28 weighted selector/runtime bindings**, and
recomputed the four earlier claim/sale/token/receipt facet runtime hashes.
The executed fixture independently checks the fixed proxy runtimes and their
relevant loupe-to-facet bindings. A shared proxy code hash alone is not used
as source authentication.

Four weighted and six earlier historical sent-call/receipt joins match,
including real successful claim/unstake/conversion, the adverse operator
redirection, earlier claim/sale, and the four disabled failures. Source
archive `match` versus `exact_match` qualifications remain unchanged; no
independent historical recompilation or complete transitive legacy audit is
claimed.

Both reviewed current artifacts matched producer fingerprints at entry.
**226 metadata/source comparisons over 135 unique current files pass.**
After the verifier's compilation, creation bytecode, runtime objects and
metadata remain unchanged; JSON/source-map envelopes may differ.

| Artifact | Runtime bytes | Creation-bytecode Keccak-256 |
| --- | ---: | --- |
| `UniswapV4DetfMigrationRecoveryFacet` | 12,128 | `0x89418c5434878e46282b1db2dbce4f3424a6ee2db7e97f3a32904154b96a7fbf` |
| `UniswapV4DetfMigrationDFPkg` | 16,687 | `0xdb45bc5aeea957ed437c33e376c138471e93007a662674aabeba3b388b10e629` |

The script's actual artifact reads are at `sequence-independent.log:10821`
and `:10924`; parsed creation bytes at `:10824` and `:10927` exactly match
these hashes. Those bytes enter the actual CREATE3/registry deployment.
Runtime-object hashes are not mislabeled as immutable-populated package
runtime hashes. Both sizes remain below 24,576 bytes.

All nine producer log fingerprints match. Independently recounted results:

| Saved producer log | Actual result retained |
| --- | --- |
| `build-01.log` | Artifact-first build success; producer-recorded exit 0 |
| `spec-01.log` | 95 pass; superseded by final added checker case |
| `fork-01.log` | Compile failure on two test address checksums; not passing execution |
| `fork-02.log` | 32 pass; superseded by added witnesses |
| `gas-01.log` | One pass; included in final fork and new independent replay |
| `spec-02.log` | **96 pass, 16 suites, zero failed/skipped** |
| `fork-03.log` | **34 pass, one fail, six suites**; the same failed assertion appears twice in the log, not two distinct failures |
| `fork-donation-04.log` | **Six pass, one suite**, including the corrected failed-donation assertion |
| `regression-01.log` | **9,932 pass, 589 suites, zero failed/skipped** |

The producer's one final-fork failure compared held DTF to recovery inventory
and omitted the deliberately retained 1e18 donation budget:
`586832391166327609849 != 585832391166327609849`. The current test compares
actual pre-operation balance; it passes independently here. The 29 other
final-fork cases plus six corrected donation cases establish **35 distinct
current producer fork cases**, not 40. No existing test was edited by this
verifier. Ordinary/common source changes were absent from the captured
producer diff, current source fingerprints match, and the 9,932-case result
was retained rather than needlessly rerun.

## 5. Commands and execution failures

All successful runs used `/Users/cyotee/.foundry/bin/forge` **1.9.1-nightly**,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, with Solar metadata
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. One compiler ran at a time.
Configured source/test paths, profiles, dependencies and compiler settings
were not changed.

Literal complete wrappers are in `evidence.json.runs`. They use
`/bin/zsh -lic`, existing configured archive access, `set -o pipefail`,
full-output `tee`, and a captured exit sentinel:

| Independent execution | Result |
| --- | --- |
| Artifact-first helper with the four `MigrationRecovery{Weighted,Earlier,Donation,Gas}.t.sol` roots; fork profile, `-j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv` | **Exit 0; 19/19 pass, four suites** |
| Artifact-first build with `RecoverySequenceWitness.s.sol` consumer, then `FOUNDRY_PROFILE=fork forge script --use solar ...:RecoverySequenceWitnessRunner --compute-units-per-second 10 --rpc-timeout 120 -vvvv` | **Exit 0; independent sequence assertions pass** |
| Artifact-first helper with `MigrationRecovery.t.sol`; default profile, `-vvv` | **Exit 0; 5/5 pass, two suites** |
| Artifact-first build with `RecoveryAccrualWitness.s.sol`, then fork-profile `forge script --use solar ...:RecoveryAccrualWitnessRunner --compute-units-per-second 10 --rpc-timeout 120 -vvvv` | **Exit 0; R1 reproduces, direct legacy-holder accrual redemption succeeds. Not a passing harvestability verdict.** |

The initial fork wrapper failed **before Forge launched** because outer-shell
expansion split a PATH entry containing spaces:
`zsh:export:1: not valid in this context: Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Applications/Visual`.
Literal single-quoted shell invocation fixed the harness; no source/test fix
or failed product execution was hidden. Plain Git status initially exited
128 on the existing Crane symlink; `--ignore-submodules=all` resolved that
read-only inspection. An initial diff pager was stopped and replaced with
`--no-pager`; no compiler was interrupted.

Two read lookups returned ENOENT, and one offline earlier hash lookup used
the weighted archive's nested field layout. Correct paths/field layout were
used subsequently; all stated final checks pass. These are recorded harness
limitations, not product results.

Solar warnings and the existing unknown `fmt.skip` warning remain visible.
Both independent witnesses' Solidity LSP returns **no diagnostics**. The ownership
definition lookup returned no definition, so the imported guard and acceptance
were read directly. JSON LSP is unavailable because `biome` is not installed;
no installation/configuration change was attempted. Resident JSON
serialization/parsing validates the ledger. There is no claimed full-repository
release run or clean project-wide LSP result.

## 6. Selected-work gas and local operational bound

New independent operation measurements reproduce the producer values:

| Operation | Selected | Custody population | Gas |
| --- | ---: | ---: | ---: |
| W1 cooled partial claim | 1 | 2 | 494,370 |
| Same W1 cooled claim | 1 | 26 | 494,370 |
| ER1 cooled claim | 1 | 2 | 307,674 |
| Same ER1 cooled claim | 1 | 26 | 307,674 |
| W1 cooled selected batch | 8 | 26 | 1,914,116 |
| W1 mature combined claim | 1 | 1 | 621,553 |
| W2 full unstake | 1 | 1 | 395,462 |
| W3 actual reserve swap | 1 | 1 | 1,520,888 |
| ER2 sale with prior holdings | 1 | 1 | 1,107,438 |
| W4 selected 1e18 DTF handoff | 1 | 1 | 22,038,936 |

The first five use `vm.lastCallGas().gasTotalUsed` with cooled accounts;
others use surrounding `gasleft()` deltas including small measurement/helper
overhead. The population fixture actually surrenders 24 additional historical
NFTs; it does not inject inventory mappings. Whole-test and whole-script gas
include deployment/multiple calls and are **not** transaction gas estimates.

The preserved `implementation/chain-gas-limits.log` contains successful
pinned read-only calls with accounting tuple **7,000,000 / 32,000,000 /
32,000,000**, maximum transaction getter **32,000,000**, and ArbOS **116**.
These are retained pinned RPC results, not newly queried current limits.
The header's oversized gas field and Foundry's **30-billion** test cap are
not operational limits.

The honest demonstrated local bound is **eight selected weighted claims**
or **one conversion/sale/donation stage at a time**. W4 consumes about
68.9% of the pinned 32-million limit, so this evidence does not endorse
batching two such donations, extrapolating a maximum, or using the same bound
for a different selected amount/route. Any later authorized operation needs
an estimate of its actual live selection, calldata/fee overhead and current
chain constraints. This report authorizes no such operation.

## 7. Preserved source limitations and remaining gates

The earlier disabled error remains exactly:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

**SB-AUTH remains adverse.** The archived earlier public mature-close path
lacks a holder check before parent-authorized NFT retirement; the child
checks existence/maturity, not the original external caller. The archived
wrong-owner trace reaches retirement, then the disabled exit rolls everything
back. The new independent Migration-custody call likewise reaches the disabled
error. This is neither successful theft nor proof that custody is globally
safe if external dependencies change. Correct Migration owner checks do not
repair the separately callable legacy parent.

**SB-SOURCE remains open.** Earlier facet
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`, runtime hash
`0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`,
has unavailable archived source. Its four excluded selectors
`0x6a4d3f12`, `0xf5ee7c5b`, `0x36abf3dc`, `0x7cc34bb4`
remain outside admission. Successful bounded claim/sale is not a complete
legacy source audit. Optional legacy compounding can catch its own failure;
sale success is not proof that compounding succeeded.

Historical weighted approved-operator redirection remains an actual adverse
result. Standalone fungible-LP `NotOwner`/`UnsupportedRoute`, TokenStaking's
ordinary-caller pull/callback limitation, and disabled weighted WETH-leg SE
`0x999Dae02d22E5feE1c4508430D5196d31D631009` remain unchanged.
Phase01 weighted **34 PASS / 1 FAIL / 2 UNPROVEN** and earlier
**18 PASS / 2 FAIL / 4 UNPROVEN** are not relabeled green.

No whole original-plan checkbox is closed:

| Gate/category | Remaining disposition |
| --- | --- |
| E1 / both NFT models | Bounded surrender and the exact recovery stages above confirmed; earlier liquidation and general source closure remain open |
| E1 / both liquid generations, both receipts, SY | Required distinct categories; recovery inventory conversions are not general surrender/ancestry admission |
| E1 / TokenStaking and claim-vault rights | Ordinary-caller composition, atomic surrender and attribution remain unresolved |
| E1 / underlying SE shares and fungible LP | Required distinct categories; disabled/restricted routes and exposure proof remain open; NFT LP lock is not fungible LP |
| E2 / tasks 1, 4, 6 | Complete authenticated ordinary-transfer/claim/wrapper/merge history, fresh custody and postactivation nonduplication without mutable trusted updates remain unimplemented; no affected ABI is finalized here |
| E3 / task 2 | Accepted frozen evaluator retained; actual deployment route/amount domain and operational original inputs still require admission |
| E4 / task 3 | Accepted genesis/core preserved; actual funding provenance, self-leg and funded snapshot remain operational gates |
| E5 / tasks 5, 7 | Current payout/activation/accounting evidence preserved; full category and parent/child/ordinary/registry surface matrix remains a complete-product gate |
| Tasks 4, 6 | Remaining fungible, receipt, wrapper and nontransferable-claim loading/surrender depend on E1/E2 |
| Task 8 / MIG-P14 | **Bounded increment needs-fix for R1:** recovery-owned receipt growth must remain harvestable. All-source harvest, earlier exits and remaining routes also remain incomplete |
| Task 9 | Reviewed allocation datasets, funding-first operator stages, interrupted/resumable rehearsal and receipt reconciliation remain open |
| Task 10 | Complete-product invariants, all-category integration, broader gas matrix, local rehearsal and eventual full release run remain open |
| F1-F4 / section 11 | Policy/source coverage, complete lifecycle, reproducibility/operator recovery and final release/completion remain open |

Known-origin collision checks do not establish general economic disjointness
of opaque allocation IDs. Receipt/backing/descendant representations gain no
new compensation entitlement from this recovery implementation. No E2
construction, new source policy, arbitrary executor/recipient or disabled
registry relaxation was introduced.

## 8. Cleanup and final disposition

All four completed execution monitors ended with exit 0, including the
successful defect reproduction (not an acceptance pass). The initial
pre-execution shell failure ended with exit 1. No owned command is pending.
No Anvil, listener, owned port, persistent impersonation, temporary runtime
root or public operation was started; in-process forks ended with their Forge
runners. The only observed remaining Forge process was the shared
`/opt/homebrew/bin/forge lsp --stdio` under parent **10410**, left untouched.
It was PID **13503** at the first cleanup check and **15261** at the final
check; the final command was again `forge lsp --stdio` under parent **10410**.
Neither shared language-service process was stopped by this verifier.

Only this `verification/` directory was authored. Production, existing tests,
producer/source evidence, prior phase01/04/05 evidence, dependencies and
configuration were not edited. No commit or delegation occurred.
`git diff --check --ignore-submodules=all` passes, branch/HEAD remain correct,
and tracked producer changes are byte-identical. `out/` and `cache_forge/`
remain warm; no cross-worktree cache write was made under this scope.
The terminal-accrual run also leaves both reviewed production artifacts'
creation bytes, runtime objects and metadata unchanged. No resolved private
RPC URL appears in any of the four owned execution logs.

**Final disposition: needs-fix for R1, despite successful execution of the
implemented bounded stages and preserved current Migration behavior.**
Earlier disabled/restricted stages remain blocked or unproved exactly as
listed. No bounded-completion, general harvest, E2, operator or release gate
is declared closed.
