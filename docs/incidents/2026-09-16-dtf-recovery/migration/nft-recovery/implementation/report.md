# Bounded NFT recovery implementation and execution proof

Date: 2026-11-11.

**Implemented and executed: W1-W3, ER1-ER2, and W4 for supported recovered DTF.**
Both source NFT models are retained. Actual registry Migration proxies received
the pinned NFTs through surrender, then called the real legacy proxies.
Earlier claim-and-hold and sale-and-hold are successful stages, not successful
earlier liquidation. **This is not complete two-source liquidation, all-source
recovery, final Migration completion, or release approval.**

Final coverage is **96 passing Migration specs**, **35 distinct passing pinned
fork cases across the final run and focused correction**, and **9,932 passing
ordinary/common regressions**. Two failed build/test attempts are retained and
explained below. No product failure remains in the executed scope. No command,
owned node, port or runtime cleanup is pending.

## 1. Scope and provenance

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
- Branch, independently checked before and after:
  `work/dtf-migration-phase-07-recovery`.
- HEAD, unchanged: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
- Root's warm-seed exit 0 is supplied provenance, not a repeated seed run.
  Initial tracked status was clean with `--ignore-submodules=all`; the weighted,
  earlier and source-verification evidence already existed and is read-only.
- Read the complete phase07 brief, original main-checkout implementation plan,
  complete phase01 independent report, both phase07 contracts and source gate,
  accepted phase05 contracts/runtime verification, canonical repository rules,
  actual archived source bodies, and current Migration/ordinary accounting code.
  No uncommitted phase05 production state was imported.
- Only the brief-owned Migration production/TestBase, migration spec/fork,
  and this implementation evidence directory changed. No commit, delegation,
  configuration/dependency edit, source-policy change, public transaction or E2
  implementation occurred.

Historical pin: Robinhood **4663**, L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
The fixture verifies the L2 header and Orbit's L1 `BLOCKNUMBER` value
26367659. No fresh-pin fallback was used. This pin is not the new funded
pricing snapshot.

All executions are **in-process Foundry local-fork calls**, not public
broadcasts or mined Anvil transaction receipts. Historical phase01 receipts
remain separately identified in the source gate; they are not relabeled as
new Migration transactions.

## 2. Stage matrix

| Stage | Installed behavior and actual result | Evidence / disposition |
| --- | --- | --- |
| W1 | Combined, principal-only and rewards-only claims of selected surrendered weighted NFTs pay legacy sDETF to Migration. Principal/reward components and newly received gons are recorded separately. | `MigrationRecoveryWeighted.t.sol`; ID 3 paid 3,772,281,649 principal plus 536,524,556 rewards, totaling 4,308,806,205 native receipt units. Partial ID 4, zero repeat, new vesting, reward-only continuation and final burn execute. |
| W2 | Selected booked sDETF directly unstakes to the same native quantity of weighted liquid DETF at Migration, without allowance. Actual gon debit must preserve the unbooked floor. | Full 4,308,806,205-unit unstake and partial mixed-inventory unstaking execute. The separate numerical fractional-gon boundary test is qualified in section 4. |
| W3 | Selected booked weighted DETF converts into measured DTF at Migration. Exact self-spender approval is cleared. | 4,308,806,205 weighted units produced 24,312,424,763,253,115,621,623 DTF units. The executed branch transfers input into the legacy reserve: **swap fallback**, not proof of every primary-burn state. |
| ER1 | Selected surrendered earlier NFT claims old 18-decimal DETF rewards and remains held, including while locked. | Locked ID 3 initially pays 124,873,542,679,524,901 units; zero repeat and genuine later accrual execute. Mature ID 4 pays 309,005,608,995,105 units. |
| ER2 | Optional mature sale through the earlier parent burns the selected NFT and holds measured earlier receipt external shares and residual rewards at Migration. | ID 4 returns 2,281,854,312,954,086,546 retired original shares and mints 1,967,558,883,021,387,942 receipt external shares. LP custody is unchanged; sold position fields clear. Sale after prior claim does not claim those rewards twice. |
| W4 | Only selected booked DTF enters the same Migration DETF's existing reserve budget. Positive LP output and the selected minimum are required. | Real DTF recovery/donation fixture: 1e18 DTF produces 176,474,176,609,502,837 reserve LP units. Pre/postactivation donations, budget protection, failure/retry and malicious external callback execute. |
| Earlier mature close | **Unimplemented, not admitted.** | `VaultDisabled(0xb7D4Bb379D361AD442CddEE53eA71a33957826A7)` remains. The external wrong-owner call after a committed Migration claim reaches that exact disabled error and rolls back; this is not an ownership-safety PASS. |
| Earlier parent/direct receipt redemption | **Unimplemented, not admitted.** | Preserve source-gate SB-E2/SB-E3 disabled receipts. No Migration executor or impersonated Migration call was added to manufacture access. |
| Earlier liquid DETF liquidation / resulting donation | **Unimplemented, not admitted.** | Source-gate SB-E4 remains unproved. Earlier old DETF and receipt shares stay separately booked and held; weighted conversion success is not substituted. |

The only mutating recovery API is
`recoverMigrationNfts(Step[],uint256)`. Its finite enum fixes all source
methods and tokens. NFT steps select an ID; conversion/donation steps select a
positive booked amount; minima use DTF units, earlier external receipt shares
or reserve LP as appropriate. Unused fields must be zero. There is no target,
selector, calldata, beneficiary, adapter, arbitrary token, pretransfer or
operator parameter.

## 3. Production changes and safety mechanism

Under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`:

- New `interfaces/IUniswapV4DetfMigrationRecovery.sol`,
  `UniswapV4DetfMigrationRecoveryRepo.sol`,
  `UniswapV4DetfMigrationRecoveryTarget.sol` and
  `UniswapV4DetfMigrationRecoveryFacet.sol`.
- New exact historical ABI `legacy/IMigrationLegacyRecovery.sol` and finite
  implementation `legacy/MigrationLegacyRecoveryLib.sol`.
- Existing parent package/interface now include the retained recovery facet.
  The existing artifact-backed component factory supplies it through CREATE3;
  the existing package factory and real manager registry deploy the package.
  No new deployment bypass is introduced.
- The existing TestBase wires the facet and permits real holder-funded
  contribution tokens and an external hostile rate currency. The existing
  fork base has two virtual fixture methods; its default behavior is unchanged.

Every recovery enters the common parent lock, checks the **current**
proxy-local Crane owner, checks all five child accounting states, and enforces
the source chain and deadline. Recovery is not on the removable allocation
facet and has no activation restriction. Pending owners cannot recover;
accepted owners can; former owners cannot. This is tested through actual
ownership acceptance both before and after activation, without inventing an
acceptance delay.

NFT authorization uses permanent surrender and custody records, matching
configuration-at-surrender, purchased IDs and actual live ownership. It does
not use replaceable entitlement configuration or the surrender preview.
Unsolicited unsafe NFT custody is rejected. No NFT approval/operator grant is
made. Sold/burned identities retain consumption and delivered-bond history.

Recovery inventory is not the token balance. Each operation implements:

```text
inventoryAfter = inventoryBefore + newClaims + conversionOutputs
               - conversionInputs - donations
```

WD/ED/DTF use native units. WS additionally tracks actual attributed gons;
claim measurement uses one synchronized index, not a raw rebasing balance
delta. Earlier receipt inventory uses external shares, whose internal scale
is 1e9, not its displayed ERC20 balance or retired LP-accounting shares.
Representation changes are not additional recovered-value totals.

W4 debits exactly the selected recovery quantity and releases only that
quantity below the existing operation floor. Preexisting donation budgets,
unselected recovery and unsolicited holdings remain protected. Any unjoined
part is owned by the existing reserve residual domain, not simultaneously
booked as recovery. Existing residual authority is neither broadened nor
replaced. The real fixture deliberately retains **1e18 DTF of earlier donation
budget** and adds **7e18 unsolicited DTF** while donating selected recovery.
It checks actual staking-SY packets, raw-SY backing, self-leg inventory, new
staking backing and unchanged delivered bonds/supply.

The implementation does not issue independent compensation, buy ordinary
bonds, resize existing bonds or reopen consumption. Temporary W3 and reserve
allowances clear on success; failed transactions roll them back with all
source and local effects.

## 4. Executed proof and explicit coverage limits

New specs: `MigrationRecovery.t.sol`.
New forks: `MigrationRecoveryForkBase.sol`,
`MigrationRecoveryWeighted.t.sol`, `MigrationRecoveryEarlier.t.sol`,
`MigrationRecoveryDonation.t.sol`, `MigrationRecoveryGas.t.sol`.
All are under the existing migration spec/fork directories.

| Obligation | Actual proof |
| --- | --- |
| Real custody and fixed recipients | Genuine holder surrender, current source ownership at Migration, actual typed source calls from that proxy, measured output at Migration. No parent/source-owner impersonation, SUT subclass, etch or storage injection. |
| Selected atomicity | A failing middle weighted item restores the prior successful inner claim, source position, gons and local inventory. A locked middle earlier sale restores the earlier reward claim. Smaller selections succeed. |
| Optional staging | Committed W1/W2 survive a failed W3 minimum. Committed ER1 survives a failed ER2 minimum. Completed conversion survives failed W4. Smaller retries succeed. |
| Whole-chain atomicity | Selected W1 -> W2 -> W3 -> W4 with impossible final LP minimum rolls back the entire transaction. A corrected minimum succeeds. Reverted inner events are not counted as committed recovery. |
| Repetition | Live weighted zero/new-vesting behavior, reward-only continuation, final burn/rejection; earlier zero repeat/new reward accrual, duplicate-sale rejection. Native conversion budgets cannot be spent twice. |
| Mixed inventory | Real preexisting weighted receipts undergo an index change without being booked as new claims; partial unstaking leaves their exact gons untouched. Real preexisting earlier receipts/ED are excluded from sale outputs. Unsolicited DTF remains protected. |
| Fractional-gon boundary | The **exact production checker** is exercised numerically: G=23, attributed=20, divisor=10; full-account debit 23 rejects, smaller debits 10 preserve the three unbooked gons; a fully attributed 23-gon exit is allowed. This is not represented as an injected or fabricated pinned-source balance. The real mixed-inventory fork witness is separate. |
| Earlier receipt minima | Actual positive sale output and an excessive minimum exercise success and complete rollback. Production rejects zero shares. No naturally zero-output pinned sale was manufactured or claimed. |
| Current owner / activation | Current, pending and former owners are checked through actual transfers before and after activation; both source routes and donation remain installed and callable. |
| Registry | Local new-parent disable rejects donation while claims/holding/conversion retain their existing route behavior. No legacy registry was enabled. Exact earlier disabled close remains adverse. |
| Callback | A real external rate token in the new V3 reserve path, also current Migration owner, attempts recovery, activation, surrender and donation during W4. All four return `IsLocked()`. The outer donation succeeds and protected accounting remains equal. A separate hermetic hostile-contribution callback cannot enter recovery. |
| No new compensation | Exact before/after bond fields, holder, supply, staking backing/gons, custody/consumption, SY packet backing and self inventory are asserted. |
| Interface and size | Interface-derived declarations, package cuts, live loupe and all four public recovery selectors are checked. Existing administration removal/restoration negatives remain green. |

The fractional-gon check intentionally fails closed if an unbooked fraction
would be retired. Attributed revaluation/dust can remain held after the native
budget is exhausted; no new policy converts that growth into spendable native
budget. These are retained accounting/liveness limits, not fake liquidation.
Legacy optional compounding may catch its own failure during an earlier sale;
sale success is not proof that optional compounding succeeded.

## 5. Commands, counts and failures

Compiler: `/Users/cyotee/.foundry/bin/forge` **1.9.1-nightly**,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`;
metadata compiler `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
One compiler ran at a time, without viaIR or configuration changes.

`evidence.json.runs` records every complete literal driver command, cwd,
profile, log, count and exit. The driver first builds concrete artifacts with
`forge build --use solar`, then invokes `forge test --use solar` with selected
roots. Expanded Forge commands and their skip sets are in each full log.
All commands used this worktree and `/Users/cyotee/.foundry/bin` first on PATH.
Fork commands used `/bin/zsh -lic` for configured archive access, never a
recorded resolved RPC URL.

| Log | Exit | Result |
| --- | ---: | --- |
| `build-01.log` | 0 | Initial artifact-first recovery facet/package build. |
| `spec-01.log` | 0 | 95 passed, 16 suites. Superseded by the added numerical gon-floor case. |
| `fork-01.log` | 1 | Test compilation rejected two incorrectly checksummed test address literals. Corrected to the compiler-supplied checksum; no product change. |
| `fork-02.log` | 0 | 32 passed, five suites, before final additional witnesses. |
| `gas-01.log` | 0 | One selected-work/population test passed. Also included in the final fork run. |
| `spec-02.log` | 0 | **96 passed, 16 suites, zero failed/skipped.** |
| `fork-03.log` | 1 | **34 passed, one failed, six suites.** The failing rollback assertion expected held DTF to equal recovery inventory and omitted the deliberately retained 1e18 older donation budget. Actual 586,832,391,166,327,609,849 vs expected 585,832,391,166,327,609,849. |
| `fork-donation-04.log` | 0 | **All six donation cases pass** after comparing held balance to its actual pre-operation value. The other 29 final fork cases were unchanged and not redundantly rerun. Thus 35 distinct final cases pass, not 40 distinct cases. |
| `regression-01.log` | 0 | **9,932 passed, 589 suites, zero failed/skipped**, ordinary Uni V4 DETF and common bond/staking scopes. |

Representative complete command forms (all literal expanded forms are also
stored in the machine ledger):

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery
export PATH=/Users/cyotee/.foundry/bin:$PATH
M=contracts/vaults/detf/protocols/dexes/uniswap/v4/migration
S=test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
F=test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration

python3 scripts/forge-artifacts.py build \
  "$M/UniswapV4DetfMigrationRecoveryFacet.sol" "$M/UniswapV4DetfMigrationDFPkg.sol"
python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationRecoveryFacet.sol" "$M/UniswapV4DetfMigrationDFPkg.sol" \
  --test-root "$S" -- -vvv
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationRecoveryFacet.sol" "$M/UniswapV4DetfMigrationDFPkg.sol" \
  --test-root "$F" -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationRecoveryFacet.sol" "$M/UniswapV4DetfMigrationDFPkg.sol" \
  --test-root "$F/MigrationRecoveryDonation.t.sol" \
  -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv
python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationRecoveryFacet.sol" "$M/UniswapV4DetfMigrationDFPkg.sol" \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf \
  --test-root test/foundry/spec/vaults/detf/common -- -vv
```

Each execution used `set -o pipefail`, piped full output through `tee`, then
reported and returned the captured exit. Exit sentinels were delivered by the
execution monitors; their statuses are recorded in this table and `runs`.
Compiler lint warnings and the existing unknown `fmt.skip` warning remain in
logs, unsuppressed. Expected low-gas negative traces are passing tests, not
unresolved compiler/test failures. No full-repository release run is claimed.

Initial monitoring rejected an unsupported four-hour timeout before launching;
the corrected durable subscription completed normally. An early resident
display-helper lookup and an attempt to parse an already-parsed metadata
object failed and were corrected. Two unused CSV path lookups returned
ENOENT; no missing input was treated as zero. These tool/harness issues did
not produce successful test evidence.

## 6. Source, artifact and trace bindings

`evidence.json` contains all new-source SHA-256 values, full log fingerprints,
12 preserved-input comparisons, 226 metadata/source comparisons across
**135 unique source files**, and exact deployment-loader trace bindings.
Every comparison passes. The original main-checkout plan remains SHA-256
`56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`.
Both phase07 contracts and supporting source evidence match the source gate.

The actual fork fixture verifies all six legacy proxy code hashes, relevant
claim/unstake/conversion/sale/share/approval loupe routes and their facet code
hashes from the admitted contracts. The two distinct five-word NFT layouts
and the legacy one-word exchange return are typed explicitly. No current
repository source is substituted for old deployed bytecode.

| Artifact | Runtime bytes | Creation-bytecode Keccak-256 |
| --- | ---: | --- |
| `UniswapV4DetfMigrationRecoveryFacet` | 12,128 | `0x89418c5434878e46282b1db2dbce4f3424a6ee2db7e97f3a32904154b96a7fbf` |
| `UniswapV4DetfMigrationDFPkg` | 16,687 | `0xdb45bc5aeea957ed437c33e376c138471e93007a662674aabeba3b388b10e629` |

Both are below EIP-170's 24,576 bytes, and the existing real-proxy surface test
checks all parent/child facets. `fork-03.log:106135` and `:106238` show the
actual artifact reads and parsed creation bytecode; their hashes equal the
final executable artifacts. Subsequent compilation changed JSON/source-map
envelopes, not those executable bytes. Runtime-object hashes in the JSON
ledger are not mislabeled as immutable-populated package runtime hashes.

Concrete successful trace anchors in `fork-03.log`: weighted conversion at
`:254105` and `:254736`; earlier sale after preexisting holdings at `:258111`;
successful recovered-DTF reserve handoff at `:192745` and `:222144`.
The full trace, test assertions and final test result must be read together:
an inner event from a reverted transaction alone is not a receipt.

The new source files contain 21-149 nonblank/noncomment lines each; the largest
new test file contains 220. Existing package/TestBase files were extended only
for necessary wiring and fixture funding.

## 7. Selected-work gas and local operational bounds

These values are **operation measurements**, not whole test/deployment gas:

| Operation | Selected | Custody population | Measured gas |
| --- | ---: | ---: | ---: |
| W1 partial claim, cooled accounts | 1 | 2 | 494,370 |
| Same W1 claim, cooled accounts | 1 | 26 | 494,370 |
| ER1 claim, cooled accounts | 1 | 2 | 307,674 |
| Same ER1 claim, cooled accounts | 1 | 26 | 307,674 |
| W1 selected batch, cooled accounts | 8 | 26 | 1,914,116 |
| W1 mature combined claim | 1 | 1 | 621,553 |
| W2 full unstake | 1 | 1 | 395,462 |
| W3 actual reserve-swap conversion | 1 | 1 | 1,520,888 |
| ER2 mature sale with prior holdings | 1 | 1 | 1,107,438 |
| W4 selected 1e18 DTF handoff | 1 | 1 | 22,038,936 |

The first five use `vm.lastCallGas().gasTotalUsed` after cooling proxy/facet
accounts. The remaining stage witnesses use a `gasleft()` delta around the
selected call, including small helper/measurement overhead. The population
test adds **24 genuinely surrendered historical weighted NFTs**, not injected
mapping entries or synthetic NFTs. Its original contribution rows were
redecoded from actual phase01 purchase receipts. Selected work is exactly
unchanged between populations in both claim cases.

`chain-gas-limits.log` records three successful pinned read-only calls:

```sh
cast call 0x000000000000000000000000000000000000006c \
  "getGasAccountingParams()(uint256,uint256,uint256)" \
  --rpc-url robinhood_mainnet_alchemy --block 108944663
cast call 0x000000000000000000000000000000000000006c \
  "getMaxTxGasLimit()(uint256)" \
  --rpc-url robinhood_mainnet_alchemy --block 108944663
cast call 0x0000000000000000000000000000000000000064 \
  "arbOSVersion()(uint256)" \
  --rpc-url robinhood_mainnet_alchemy --block 108944663
```

Results: accounting tuple **7,000,000 / 32,000,000 / 32,000,000**;
max-transaction getter **32,000,000**; ArbOS **116**. The archived header
gas limit is `0x4000000000000`, not a useful per-transaction budget.
Foundry's 30-billion test cap is not a target-chain limit.

The demonstrated local bound is **eight selected weighted claims** or
**one conversion/sale/donation stage at a time**, not an extrapolated maximum.
The expensive W4 witness uses about 68.9% of the pinned 32-million limit;
two such donations should not be batched by multiplying the tested amount.
Use staged transactions and re-estimate the exact selected amount, live
routes, current chain limit and calldata/fee overhead before any later
authorized operation. No universal production batch size, live-market gas
guarantee or public execution authorization is inferred from these fixtures.

## 8. Remaining blockers and gates

No external blocker prevented implementing/executing W1-W3, ER1-ER2 or the
supported DTF W4 handoff. These independently admitted stages are delivered.
The following remain deliberately unresolved and unimplemented here:

- **SB-E1/E2/E3:** earlier mature close and both receipt exits hit the disabled
  earlier SE. No registry enable, unsafe caller route or false success stub.
- **SB-E4:** earlier liquid DETF-to-DTF liquidation lacks admitted success.
- **SB-AUTH:** earlier public mature close lacks the required holder check
  before its owner-authorized child retirement; the disabled dependency masks
  final effects. Correct Migration ownership does not repair that source.
- **SB-SOURCE:** earlier facet `0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`
  remains unavailable in the source archive. Its four excluded selectors are
  not invoked by the admitted claim/sale traces.
- Full E1 categories, E2 ordinary-transfer/claim/wrapper ancestry and
  postactivation nonduplication, E3 operational quote domains/routes, E4 actual
  funding provenance, remaining E5 product payout/registry matrix, remaining
  fungible/claim surrender, all-source harvest, reviewed allocation datasets,
  operator/resume rehearsal, full integration/invariants and F1-F4 release
  gates remain open under the original plan.

Both liquid generations, both NFT models, both receipts, SY,
TokenStaking/claim-vault rights, underlying SE shares and fungible LP remain
distinct required categories. No whole original-plan checkbox is closed by
this bounded increment.

## 9. Cleanup and handoff

Every compiler/test/RPC monitor completed with the recorded exit. No Anvil,
listener, owned local port, persistent impersonation or temporary runtime
root was started. In-process forks ended with their Forge runners. Final
process inspection showed only the shared `forge lsp --stdio` service
(PID 86802, parent 10410), left untouched.

`out/` and `cache_forge/` remain warm. No cross-worktree seed write was made
because this lane is restricted to its designated worktree. All 12 checked
historical/source inputs remain identical. Final branch/HEAD checks and
`git diff --check --ignore-submodules=all` pass. No resolved private RPC URL
was found in any owned execution log.

The initial LSP reference lookup and two test-file diagnostic refreshes timed
out. A final fresh diagnostic request for the recovery Target returned **no
diagnostics**. JSON LSP is unavailable because `biome` is not installed; no
installation was authorized or attempted. Resident JSON parsing validates
the machine ledger. Solar compilation/execution and the scoped diff check,
not an invented project-wide LSP pass, are the validation.

**Producer handoff:** bounded stages and fixed reserve handoff implemented,
real execution evidence supplied, all owned runtime finished, no commit.
Independent verification may consume this report and `evidence.json`; this
producer report does not replace that separate gate or authorize public
funding, deployment, activation, compensation or release.
