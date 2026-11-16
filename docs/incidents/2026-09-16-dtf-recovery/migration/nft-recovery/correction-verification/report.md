# Independent R1 correction verification

Date: 2026-11-11.

**AdversarialVerify: confirmed.** R1 is corrected in the reviewed uncommitted
recovery implementation. The formerly stranded **488,794 whole native
weighted-receipt units** convert through the actual registry-deployed Migration
proxy after the terminal NFT burns and the entire original claim quantity is
spent. Revaluation remains distinct from new NFT claims and compensation.
The executed bounded recovery protections remain intact.

Independent execution: **22 pinned recovery fork cases, five focused hermetic
cases, and one new composition witness**, all successful. The witness also
requests more than the stored native inventory on the first synchronization,
then challenges a late unsolicited receipt transfer and a source-payable
overdraw. No production or existing test file was edited.

This closes **R1 only**, not task 8 in full or any whole original-plan gate.
Earlier liquidation remains unimplemented and blocked. Source limitations,
E2 attribution, general harvest, operator, invariant, broader gas and release
gates remain open.

## Scope and authority

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
- Branch: `work/dtf-migration-phase-07-recovery`.
- Base and final HEAD: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
- Reviewed state: existing uncommitted recovery implementation plus producer
  R1 correction, not code already present in that commit.
- Consumed the complete correction mandate, original implementation plan,
  repository rules, complete source gate and producer reports, original
  independent report, both immutable witness sources and their actual R1
  trace ranges, current source and relevant fixture/test bodies.
- Original plan fingerprint remains
  `56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`.
  Task 8's harvestable-accrual requirement governs the superseded engineering
  no-native-budget-expansion sentence. No other source or authority condition
  was relaxed.

All new authored evidence is in this `correction-verification/` directory.
Prior reports, failed runs, witnesses and producer evidence remain immutable.
No commits, delegation, public operations, configuration/dependency changes
or common/ordinary/Crane edits occurred.

## 1. Decisive terminal execution

`fork-independent.log:64287-66502` independently executes
`test_terminalBurnedNftGrowthConvertsAfterOriginalClaimSpent`.
The actual Migration proxy surrenders weighted NFT 3, claims
**4,308,806,205 WS**, and observes its burn. A genuine external holder performs
the same separate claim used in the original terminal witness. Eight hours
later, W2 itself synchronizes the actual source and spends the entire original
4,308,806,205-unit claim quantity.

The remaining actual and attributed gons are
**427,882,030,360,010,419,822,646,177,042,295,082,020,945**, at divisor
**875,382,550,842,670,612,356,981,754,173,735,900**. They represent
**488,794 whole native units**. Unbooked gons are zero.
Migration then successfully converts one unit and the remaining 488,793.
Actual gons, attributed gons and WS inventory finish at zero; actual WD and
booked WD both equal **4,309,294,999**. Claim records and the protected new
bond/staking/backing state remain unchanged. Another W2 and another claim
on the burned NFT reject. The final value event is at
`fork-independent.log:66439`.

The corrected ledger retains 488,794 after the original quantity is spent;
it intentionally no longer reproduces the defective ledger's zero.
The original zero-budget failure is preserved in
`../verification/accrual-independent.log:16240-16515` and
`../correction/fail-before.log`. It is not simulated here by writing storage.
The other immutable witness's 9,789-unit stranded case remains preserved in
`../verification/sequence-independent.log:16550-16644`.

The producer's fail-before log actually fails with
`RecoveryInventoryInsufficient(WS,1,0)`, with zero passes and one failed case.
Its repeated failure summary is not a second failure. Independently extracted
creation-bytecode hashes at lines 10232 and 10335 match the original facet and
package. The passing current executions load the corrected artifacts.
No stale-artifact explanation remains.

## 2. Additional independent composition

`RecoveryCorrectionWitness.s.sol` inherits the accepted real fixture, not a
production SUT. `witness-independent.log` contains its successful execution
and setup-inclusive registry/CREATE3 trace.

After terminal NFT 3 burns, the witness leaves the stored budget at
4,308,806,205, advances eight hours, and immediately requests **4,308,806,206**
through Migration. This deliberately exceeds stored native inventory before
any priming recovery call. The call succeeds against synchronized attributed
value **4,309,294,999**, credits exactly the requested WD and leaves
488,793 native units. Exactly one revaluation event has the measured
pre-existing attributed gons and divisor; no Migration claim event occurs.
See `witness-independent.log:13433`.

Two branches start from that actually reached checkpoint:

| Branch | Actual observation |
| --- | --- |
| Fully attributed final exit | The remaining 488,793 units convert; the source retires all remaining attributable gons, including their own fraction. WD equals 4,309,294,999; WS and attributed gons are zero. Another native spend rejects. `:13604`. |
| Late unbooked inventory | Restore the checkpoint, then a genuine external holder transfers 17 WS to Migration. Those **14,881,503,364,325,400,410,068,689,820,953,510,300 gons** are not added to recovery attribution. |
| Source-payable overdraw | Request 488,794 when recovery owns only 488,793 native units. The real source can pay because unrelated receipts exist; Migration's post-call native check rejects with the exact requested/available values. Source gons, staking state, WD balance, WS/WD ledgers and attributed gons all restore. |
| Partial then final attributable selection | Convert seven units and 488,786 units. Every unbooked gon survives; only **291,803,418,080,526,227,637,492,698,016,516,345 attributable fractional gons** remain, below one native unit. A further one-unit request rejects and restores all effects. `:14202`. |

Both branches preserve new compensation backing. The completed mixed branch
also checks unchanged surrender/custody history, claim records, donor/owner
WD balances and zero receipt allowance. Another claim on the burned NFT
rejects. The checkpoint restores an actual executed state solely to compare
two branches; it is not an injected balance, gon, ownership or bytecode state.
Branch outputs are not added together as cumulative recovery.

## 3. Accounting and preserved bounds

Let B be attributed gons, G actual account gons, k the source operation's
synchronized divisor, and q selected native input:

```text
reconciled WS inventory = floor(B / k)
representation adjustment = reconciled inventory - stored inventory
WS inventory after W2 = floor(B / k) - q
attributed gons after W2 = B - actual gon debit
unbooked gons = G - B
WD inventory increase = actual WD receipt = q
```

For partial exits, actual debit is q*k, so the remaining native inventory
equals floor((B-q*k)/k). Full-account retirement is permitted only when its
entire actual gon debit fits B and preserves G-B. W1 revalues only the
previously held B before adding the actual new claim's A*k gons and A native
units. Revaluation never updates principal/reward claim totals, surrender
credit or compensation.

Current source anchors under
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`:

- `legacy/MigrationLegacyRecoveryLib.sol`, `claimWeighted` and
  `unstakeWeighted`: synchronized reconciliation, exact claim-gon measurement,
  fixed exchange route and exact observed WD output.
- `UniswapV4DetfMigrationRecoveryRepo.sol`, `_reconcileWeighted`:
  representation adjustment only; unchanged storage layout.
- `UniswapV4DetfMigrationRecoveryTarget.sol:34-62`: unchanged common lock,
  current owner, all five idle children, chain/deadline, finite step validation,
  selected execution without catch-and-skip, and expected-hold synchronization.
- `UniswapV4DetfMigrationPolicy.sol:18-55,97-104`: unchanged operation floors,
  residual accounting and child-state admission.

The current custody, gon checker, W3, ER1 and ER2 function bodies are
byte-identical to the producer's saved pre-correction source. Recovery Target
and policy fingerprints are unchanged. The admitted historical staking source
was read directly: `StakedDETFTarget.sol:142-149,187-208,230-236` synchronizes
before withdrawal; `DETFFundedStakingRepo.sol:107-124` implements the exact
partial/full gon-debit distinction. These are archived legacy sources, not
substituted current contracts.

The following fresh executions confirm the preserved bounds. Line locators
refer to `fork-independent.log` unless stated otherwise.

| Protection | Independent evidence |
| --- | --- |
| Real index change, partial/full exits, exact outputs | Terminal case `:64287`; independent composition above; real mixed whole/fractional unbooked case `:62043`. |
| Revaluation followed by repeat and later real claim | `:59249`: exact event payloads, no same-index duplicate adjustment, new claim A*k isolated from old-gon value, exact subsequent conversion. |
| Full-account unrelated fraction | `spec-independent.log:2975`: unchanged production checker rejects G=23, B=20, k=10 full retirement; smaller debits preserve three unbooked gons; fully attributed retirement succeeds. This is numerical supplemental proof, not a fabricated real-source fractional transfer. |
| Reconciliation/source debit/conversion/donation rollback | `:2894`: committed W1 survives W2 revaluation, W3 and successful inner W4 followed by an invalid selected NFT. All selected effects restore, including source state, balances, inventories, LP, approvals and protected backing. Removing only the final failing step succeeds. |
| W1 variants and repeat/burn | `:78745`: principal-only, same-time zero repeat, later vesting, reward-only final burn. Unsolicited NFT rejection `:81546`; middle-item rollback `:77445`. |
| W3 exact conversion and staging | `:82246`: real reserve-swap branch and zero final approval; `:71366`: prior committed W1/W2 survive failed conversion, corrected retry succeeds, duplicate input spend rejects. |
| ER1/ER2 | `:68093,68752,69889`: locked claim/new accrual, measured external receipt shares excluding prior holdings, unchanged physical LP, duplicate-sale rejection and selected rollback. Postactivation `:66505`. |
| Current/pending/former owners | `:73750`: actual ownership acceptance before and after activation. No invented acceptance delay. |
| W4 floors and backing | `:84186`: old donation budget, unsolicited DTF and unselected recovery protected; `:279110`: actual staking-SY packets, raw-SY backing and self-leg protected. LP goes to bond custody. |
| W4 failures and callbacks | `:169374,223859`: staged/full-selected rollback and smaller retry; `:141453`: hostile current-owner rate token attempts four parent money paths, all return `IsLocked()`, outer donation succeeds. Additional hermetic callback `spec-independent.log:3017`. |
| Registry and blocked legacy route | `:308521`: new registry disable blocks W4 but not admitted holding/conversion; `:67372`: external wrong-owner earlier close still hits the exact disabled dependency and rolls back. This is not an ownership-safety pass. |
| Surface and native budget admission | `spec-independent.log:2974-3018`: interface-derived selectors, real postactivation proxy routing, empty/unbooked budget rejection and invalid fields. |

Deadline and five-child admission checks were source-reviewed and preserved
with unchanged dependencies and the current 96-spec provenance; no new
isolated expired-deadline or busy-child recovery fixture is claimed.
The callback executions independently exercise the common lock.

The event `MigrationRecoveryRevalued` is the only added event semantics.
`migrationRecoveryInventory(WS)` remains a stored, last-synchronized query,
not a live preview. The four callable recovery selectors are unchanged.
No new source, recipient setter, generic executor or credit authority exists.
The original compensation and configuration records remain separate.

## 4. Source, artifact and result reconciliation

Historical execution pin remains Robinhood chain **4663**, L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
The actual fixture verifies the header and Orbit L1 `BLOCKNUMBER`
**26367659**, proxy runtimes and relevant selector/facet routes.
No fresh-pin fallback or legacy bytecode replacement was used.

All executions are in-process Foundry local forks, not public transactions
or mined Anvil receipts. No current live-chain readiness is inferred.

Independent reconciliation:

- **40/40** saved source excerpts match actual unescaped archives.
- **28 weighted bindings and four earlier facet runtime hashes** match
  their archived bytecode; current fork fixture verifies relevant live-at-pin
  routes and code hashes. Archive `match` versus `exact_match` qualifications
  remain; this is not an independent historical recompilation/transitive audit.
- **226/226 metadata/source comparisons over 135 unique files** pass.
- **193/193 captured current source/configuration/helper fingerprints** and
  **38/38 pre-existing evidence files** remain unchanged through verification.
- All **12 original plan/source/historical inputs** match prior fingerprints.
  Of the original verifier's 146 source fingerprints, only the expected three
  production/interface files and donation fixture differ after correction.
  Ordinary/common/Crane inputs in that binding set remain unchanged; the Crane
  checkout's tracked status is clean.
- The existing tracked producer delta remains byte-identical. No ordinary
  production path appears in that delta.

Actual witness deployment bytes:

| Artifact | Runtime-object bytes | Creation Keccak-256 | Witness loader/bytecode lines |
| --- | ---: | --- | --- |
| Recovery facet | 12,312 | `0xb5c728e1d786308228f9d92388fc5483226229b9207f27d36dbde5f8f0ef1c02` | 7939 / 7942 |
| Migration package | 16,687 | `0xf9a8cc0c49ddc52cd96274b7354c089f66462f33243654970986e0d844a426c3` | 8042 / 8045 |

Creation bytes enter CREATE3 and the real manager registry. Both sizes remain
below 24,576 bytes. Final creation bytes, runtime objects and metadata are
unchanged after execution. Package runtime-object hashes are not represented
as immutable-populated deployed runtime hashes.

The saved producer correction logs independently recount to **96 specs and
39 pinned fork cases**, zero failures/skips, with matching fingerprints.
The deliberately failed before-correction case remains failed evidence.
The retained ordinary/common result is **9,932 passes in 589 suites**, zero
failures/skips, from `../implementation/regression-01.log`, SHA-256
`89a4da6fa44bfdd43233a5293dc1ea6152b9204cb5b714518f3436ccbc810fb0`.
It was not rerun or relabeled as this verifier's execution.

## 5. Commands and validation

`evidence.json` records the complete literal commands, monitor IDs, observed
exits, fingerprints, source comparisons and trace locators.

| Owned execution | Exit | Actual result |
| --- | ---: | --- |
| `fork-independent.log` | 0 | 22 passing cases in five recovery suites |
| `spec-independent.log` | 0 | Five passing cases in two focused suites |
| `witness-independent.log` | 0 | New independent composition assertions succeed |

The two test drivers use `python3 scripts/forge-artifacts.py test` with the
recovery facet/package roots, recording artifact-first `forge build --use solar`
before `forge test --use solar`. The witness wrapper likewise builds before
its `&& forge script --use solar`; its `tee` captures the script, not that
third build's stdout. No complete third build transcript is claimed. The two
saved test-driver build transcripts and exact witness bytecode bindings
establish the artifact-first current-source chain.

Compiler: `/Users/cyotee/.foundry/bin/forge` **1.9.1-nightly**,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`;
metadata `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
Fork commands use the configured archive alias with
`--compute-units-per-second 10 --rpc-timeout 120`; test workers use `-j 1`.
No concurrent compiler, viaIR, changed profile paths, cache deletion or
cross-worktree seed write occurred. Existing Solar lint and unknown
`fmt.skip` warnings remain unsuppressed.

The new witness has no Solidity LSP diagnostics. JSON parsing validates the
evidence; JSON LSP is unavailable because `biome` is not installed, and no
installation/configuration change was made. Scoped Git whitespace checks
pass. None of the three owned execution logs contains a resolved private
Alchemy URL.

Read-only harness issues were resolved without product edits: the incident
directory was initially sought at the wrong relative location; the plan is
in the main checkout; ordinary Git status rejects the existing Crane symlink
and requires `--ignore-submodules=all`; one offline function-text comparison
helper initially mishandled brace depth and was corrected. No failed product
execution was hidden or converted to a passing result.

No new operational maximum is claimed. Retain the producer's corrected
selected-work gas and the prior **eight selected claims or one
conversion/sale/donation stage** demonstrated bound, qualified by the pinned
32-million transaction limit. Whole-test/script gas includes fixture
deployment and multiple calls and is not transaction gas.

## 6. Retained blockers, gates and cleanup

| Gate | Unchanged disposition |
| --- | --- |
| SB-E1/E2/E3 | Earlier mature close and both receipt exits remain disabled, unimplemented recovery routes. Exact `VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)` evidence remains. |
| SB-E4 | Earlier liquid DETF conversion and resulting donation remain unproved and unimplemented. Earlier claim-and-hold/sale-and-hold do not establish liquidation. |
| SB-AUTH | Earlier external mature-close authorization exposure remains masked by the disabled exit. Migration's owner guard does not repair the legacy parent. |
| SB-SOURCE | Earlier facet `0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE` still lacks archived source; excluded selectors stay outside admission. |
| E1 and tasks 1/4/6 | Both liquid generations, both receipt models, SY, TokenStaking/claim-vault rights, underlying SE shares and fungible LP remain distinct required categories with their existing blockers. NFT recovery is not general surrender support. |
| E2 | Authenticated ordinary-transfer/claim/wrapper/merge attribution and postactivation nonduplication remain unresolved; no trusted mutable update is introduced. |
| E3/E4/E5 | Operational quote domain/routes, real funding provenance and complete-product payout/surface/registry coverage remain their original gates. |
| Task 8 | This bounded R1 correction is confirmed; all-source harvest and earlier exits remain incomplete. |
| Tasks 9/10 and F1-F4 | Reviewed allocations, operator/resume rehearsal, full-category integration/invariants, broader gas/rehearsal and release remain open. |

No approval for deployment, funding, activation, compensation execution or
source-policy change follows from this report. Phase01 weighted
34 PASS / 1 FAIL / 2 UNPROVEN and earlier 18 PASS / 2 FAIL / 4 UNPROVEN
remain historical adverse/qualified results, not green source closure.

All three owned execution monitors ended with exit 0. No owned Anvil node,
listener, port, persistent impersonation or temporary runtime root was
started. Final process inspection found only the shared `forge lsp --stdio`
service, PID 19720 under parent 10410, left untouched. Warm `out/`,
`cache_forge/` and the existing Crane symlink remain. No runtime is pending.

**Final disposition: confirmed for R1 and the preserved bounded recovery
contract, with the explicit source and full-plan limits above.**
