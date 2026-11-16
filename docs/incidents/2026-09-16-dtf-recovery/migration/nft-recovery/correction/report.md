# R1 correction: attributable receipt growth remains convertible

Date: 2026-11-11.

**Producer result: corrected and ready for independent verification.**
The new real-proxy regression fails on the original recovery source with
`RecoveryInventoryInsufficient(WS,1,0)` and passes unchanged after the
accounting correction. The terminal burned-NFT case converts the previously
stranded **488,794 whole native receipt units** through Migration, without
another NFT claim. Current complete Migration verification passes:
**96 specs and 39 pinned fork cases**, zero failures or skips.

This is a producer handoff, not the independent R1 acceptance verdict.
No whole original-plan, all-source harvest, E2, operator, invariant or release
gate is declared closed. Earlier liquidation remains unimplemented and blocked.

## Scope and files

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
Branch: `work/dtf-migration-phase-07-recovery`.
HEAD remains `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
The correction is on the existing uncommitted recovery implementation.

Only these additional production/test changes were made:

| Path, relative to Migration production or fork directory | Correction |
| --- | --- |
| `legacy/MigrationLegacyRecoveryLib.sol` | Reconcile existing attributed gons at the synchronized source index before native debit or addition of a fresh claim. Preserve actual gon-debit and output checks. |
| `UniswapV4DetfMigrationRecoveryRepo.sol` | Small reconciliation helper; no storage-layout change. |
| `interfaces/IUniswapV4DetfMigrationRecovery.sol` | Separate revaluation event and truthful stored-inventory/gon query documentation. No new callable selector. |
| `MigrationRecoveryAccrual.t.sol` | Terminal R1 regression, real mixed unbooked inventory, repeated revaluation and later genuine claim accounting. |
| `MigrationRecoveryDonation.t.sol` | Expose its existing real donation fixture as an abstract test base; existing six test bodies remain unchanged. |
| `MigrationRecoveryAccrualRollback.t.sol` | Revaluation/conversion/donation followed by a failing selected step, exact rollback and smaller successful retry. |

Production directory:
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
Fork directory:
`test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
All new evidence is in this `correction/` directory.

The original plan and complete correction brief, source gate, producer report,
independent report, both immutable witness sources and their R1 trace ranges
were consumed. The original plan's SHA-256 remains
`56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`.
Original task 8's harvestable-accrual requirement governs the stale engineering
no-budget-expansion sentence; the remaining source/authority constraints stand.

## Accounting correction

Let B be attributed recovery gons before the operation, G actual account gons,
k the divisor synchronized by the admitted legacy operation, and q the selected
native unstake amount.

```text
reconciled native inventory = floor(B / k)
representation adjustment  = reconciled inventory - previous native inventory
native inventory after W2  = floor(B / k) - q
attributed gons after W2   = B - actual observed gon debit
unbooked floor             = G - B
```

W2 retains the same fixed `WS.exchangeIn(WS,q,WD,q,MIG,false,deadline)`
call. That source operation synchronizes before debiting receipt gons.
The wrapper consequently validates its native budget at the resulting
divisor, rather than rejecting first against a stale claim-native amount.
Zero requests or zero attributed gons still reject before a source call.
Any subsequent native-budget, gon-floor or output failure reverts the source
call and its synchronization with the entire selected transaction.

Both safeguards remain:

- Actual gon debit cannot exceed B; remaining actual gons cannot fall below
  G-B. The full-account source branch must debit exactly G; the partial branch
  must debit exactly q*k. Unrelated fractional gons cannot be retired.
- Actual WD received and the source's one-word return must both equal q.
  Recipient, route, common lock, child admission, owner and deadline are unchanged.

For W1, reconcile only the **previously held** B at the claim's synchronized k,
then add the measured new claim A and its exact A*k received gons. Existing
principal/reward claim records and `MigrationRecoveryClaimed` still contain
only the real new NFT payout. No compensation, new principal, source transfer
or second recovery total is created by revaluation.

`MigrationRecoveryRevalued(token,previousAmount,currentAmount,attributedGons,divisor)`
identifies the representation adjustment separately. It emits only when the
whole native representation changes. Same-index repetition does not emit
another adjustment. There is no added cumulative-value counter or storage
field to double-count.

`migrationRecoveryInventory(WS)` remains a stored view: it reflects the last
recovery claim/unstake synchronization, not a live preview. The next admitted
operation reconciles later growth. All four recovery selectors are unchanged.

Decision: use the existing source operation's synchronized divisor with atomic
post-call validation. Rejected alternatives are retaining the stale native
cap, counting appreciation as another NFT claim, or adding a synchronization/
executor/source route. The admitted source's verified synchronization and
partial/full gon-debit rules remain the contract assumptions.

## Genuine fail-before and passing-after proof

The regression was added before production edits:
`test_terminalBurnedNftGrowthConvertsAfterOriginalClaimSpent`.
Its initial source SHA-256 is
`a928a0e239a236d46a4d294e379842f806dbd337f006e2b3113f898d4be32b49`.
The same test body passed after the fix; later additions to that file are
separate tests, not a weakening of the regression.

Historical execution pin remains Robinhood chain **4663**, L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
The real fixture checks the header and Orbit L1 `BLOCKNUMBER` **26367659**.
No fresh pin or substituted bytecode was used.

The actual registry proxy surrenders weighted NFT 3, claims **4,308,806,205**
native WS and observes the old NFT burn. After eight hours, W2 executes real
source index movement and spends the entire original claim quantity.
Remaining actual and attributed gons are
**427,882,030,360,010,419,822,646,177,042,295,082,020,945**;
the synchronized divisor is
**875,382,550,842,670,612,356,981,754,173,735,900**.
Unbooked gons are zero.

- **Before:** the one-unit W2 call rejects with the exact R1 error; test
  exit **1**, 0 passing / 1 failing. `fail-before.log:2892` and its final
  trace/result retain the genuine failure.
- **After:** reconciliation records **4,309,294,999** native units before
  debiting the original **4,308,806,205**. Thus the old claim quantity is
  exhausted but the corrected ledger retains **488,794** whole units.
  W2 converts one unit, then the remaining **488,793**. Both actual and
  attributed receipt gons end at zero, WD inventory and actual WD become
  **4,309,294,999**, claim records and new compensation backing are unchanged.
  Repeat W2 and a new claim on the burned NFT reject.

The corrected native ledger intentionally no longer reproduces the erroneous
zero while those 488,794 whole units remain. The failure log retains that old
zero-budget state; the successful regression proves conversion after the
entire original native claim quantity has been spent.

`terminal-current.log:15845` records the separate revaluation;
`:16183` records the complete successful conversion;
`:16246` records the passing result. These are in-process Foundry local-fork
executions, not public transactions or mined Anvil receipts.

## Protection and accounting coverage

| Obligation | Current execution |
| --- | --- |
| Partial and full attributable exit | Terminal case spends one unit and then the full remaining account, including legitimate retirement of its own fraction. Actual gons and WD are exact. |
| Mixed whole/fractional unbooked inventory | A genuine external holder transfers 17 WS to Migration before the recovery claim. Real index movement gives that unbooked gon amount both whole and fractional components. Partial and final attributable selections leave every unbooked gon untouched. Only attributable sub-native residue remains; another native spend rejects and rolls back. |
| Fraction-only full-account boundary | The unchanged hermetic production-checker case uses G=23, B=20, k=10: full retirement rejects, partial debits preserve the unbooked three gons, and fully attributed retirement is allowed. This is numerical supplemental proof, **not** a fabricated real-source sub-native transfer. |
| Repeated accounting and later claim | Exact event payloads distinguish revaluation from claims. Same-index repeated conversion produces no revaluation or claim event. Later real index movement plus a genuine NFT claim reconcile old gons separately from the exact newly transferred A*k gons; subsequent conversion exhausts the correct combined inventory. |
| Selected-batch rollback | A committed W1 is followed by W2 synchronization/revaluation, W3 conversion, successful W4 donation, then an invalid selected NFT. The exact final error restores source staking state, actual/attributed gons, native/WD/DTF ledgers and balances, LP, allowances and protected backing. Removing only the failing last selection succeeds. |
| Existing protections | All existing 35 pinned cases pass, including W1/W3/ER1/ER2/W4, owner transitions/activation, callbacks, registry, source custody, native budgets, prior-stage survival and unchanged delivered bonds. The new four cases bring the current total to 39. |

New case anchors in `fork-current.log`:
rollback **21127**, separate accounting **77482**, mixed unbooked
inventory **80276**, terminal case **82520**. Inner events in the failed
selected batch are not counted as committed adjustments or donations.

True sub-native attributable value may remain held. The unchanged full-account
floor can still reject an exit that would retire someone else's fractional
gons; that source-specific boundary is not permission to strand otherwise
convertible whole attributable units behind an exhausted historical claim cap.

## Commands, exits and current bindings

`evidence.json` records each complete literal shell command, monitor identity,
exit, count, log SHA-256, source identities and trace bindings. Logs are here,
not in another worktree or a temporary session directory:

| Log | Exit | Result |
| --- | ---: | --- |
| `fail-before.log` | 1 | Artifact-first build succeeds; genuine R1 regression fails, 0/1 passing. |
| `passing-after.log` | 0 | Corrected artifact build and the unchanged regression pass, 1/1. |
| `fork-current.log` | 0 | Complete current pinned Migration scope: **39/39, eight suites**. |
| `spec-current.log` | 0 | Complete current Migration specs: **96/96, 16 suites**. |
| `terminal-current.log` | 0 | Same terminal case with setup-inclusive tracing for exact deployed artifact bindings, 1/1. Not another distinct case. |

Each command uses `python3 scripts/forge-artifacts.py test` with the recovery
facet/package inputs, so concrete `forge build --use solar` precedes
`forge test --use solar`. Fork profile uses the configured archive alias,
`-j 1 --compute-units-per-second 10 --rpc-timeout 120`. Full expanded compiler
commands and skip sets are in the logs. No concurrent compiler, changed
configuration, viaIR, cache deletion or cross-worktree seed write was used.
Wrapper exit sentinels were delivered by the execution monitor after `tee`;
their exact statuses are recorded in the ledger.

Compiler: `/Users/cyotee/.foundry/bin/forge` **1.9.1-nightly**,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`;
metadata **0.8.38+commit.e7a91fc7.solar.0.3.0-dev**.
Existing Solar lint and unknown `fmt.skip` warnings remain unsuppressed.

**226 current artifact/source metadata comparisons over 135 unique source
files pass.** Actual setup trace reads and parsed creation bytes match:

| Artifact | Runtime bytes | Creation Keccak-256 | Current loader/bytecode lines |
| --- | ---: | --- | --- |
| Recovery facet | 12,312 | `0xb5c728e1d786308228f9d92388fc5483226229b9207f27d36dbde5f8f0ef1c02` | `terminal-current.log:10298,10305` |
| Migration package | 16,687 | `0xf9a8cc0c49ddc52cd96274b7354c089f66462f33243654970986e0d844a426c3` | `terminal-current.log:10401,10408` |

Both remain below EIP-170. The facet grows by **184 bytes**.
Package executable size stays unchanged; its imported interface metadata
changes its bytecode fingerprint. Runtime-object hashes in the ledger are
not mislabeled as immutable-populated deployed package runtime hashes.
Final artifact creation bytes, runtime objects and metadata remain equal to
the bound versions after all runs.

The fail-before trace independently loads the original facet/package creation
hashes from the prior verified implementation, at `:10225,10232` and
`:10328,10335`. This excludes stale-artifact explanations in either direction.
Pinned legacy runtimes and relevant selector/facet routes are checked by the
unchanged real fork fixture.

Current selected-work gas: W1 **621,975**, W2 **396,027**, W3 **1,520,888**,
W4 **22,038,935**. Compared with prior values, W1 adds **422** and W2
adds **565** in the no-revaluation measured case. Cooled W1 remains identical
at custody populations 2 and 26: **494,792**; eight selected claims use
**1,917,492**. Cooled earlier claim remains **307,674**.
These are operation measurements; whole test gas includes multiple calls.
No new maximum batch size or live gas guarantee is claimed. Preserve the
prior staged-operation bound and its pinned 32-million transaction-limit
qualification.

## Preservation, cleanup and remaining gates

`preserved-before.sha256` checks **28/28 prior reports, witness sources,
ledgers and logs unchanged**, including both adverse R1 witnesses and all
earlier failures. Of the prior verifier's 146 source fingerprints,
**142 remain unchanged**; the four changes are precisely the three
production/interface paths and donation test fixture listed above.
`source-before.sha256` also preserves the local pre-correction Migration
source/test baseline.

The earlier **9,932 ordinary/common passes in 589 suites** remain preserved
with their original `implementation/regression-01.log` provenance and hash
`89a4da6fa44bfdd43233a5293dc1ea6152b9204cb5b714518f3436ccbc810fb0`.
They are not represented as rerun here. No ordinary/common/Crane input changed;
the current changed-input Migration specs/forks were rerun in full.

All six changed Solidity files return **no LSP diagnostics**. Scoped Git
whitespace checking passes. Resident JSON serialization and parsing validate
the evidence ledger. JSON LSP is unavailable because `biome` is not installed;
no dependency/configuration change or clean JSON-LSP result is claimed.
No resolved private Alchemy URL appears in the five
owned logs. The first monitor request rejected an invalid filter before
launch; a corrected filter launched the run. One resident hashing helper
lookup failed and was restored; no execution result was fabricated from it.
The sole product failure is the deliberately retained fail-before regression.

All five execution monitors have ended. No node, owned port, listener,
temporary runtime root, persistent impersonation or public action was started.
Final process inspection found only shared `forge lsp --stdio`, PID **16569**,
left untouched. Warm `out/`, `cache_forge/` and the existing Crane symlink
remain. No commit, delegation or edits outside the allowed worktree occurred.

SB-E1/E2/E3 disabled earlier liquidation, SB-E4 unproved earlier liquid
conversion, SB-AUTH's masked old-source authorization exposure and SB-SOURCE's
missing archived facet remain as recorded. All remaining original source
categories, E2 attribution, general harvest, operational inputs, operator/resume,
full integration/invariant/gas and release gates remain explicit and open.
Independent correction verification is the next gate; this report neither
performs that role nor authorizes public deployment, funding or activation.
