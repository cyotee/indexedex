# Phase 24 bounded stateful invariant increment

Date: 2026-11-12. Base: `15fd629375edeb361f6a39262795bdc66723ca3a`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants`.

**Delivered: eight new Solidity files, two real stateful targets, deterministic
successful preludes, independent accounting, and passing bounded validation.**
All twelve plan properties have observations in the matrix below. This is
bounded native lifecycle plus ordinary-SY/two-NFT/weighted-recovery coverage,
not all-source stateful closure or full-plan acceptance. Unit-specific gaps
are explicit below; deterministic inherited tests are not relabeled invariants.

No existing source, test, operator, configuration or dependency file changed.
No SUT mock, subclass, impersonation, code/storage injection, provider change,
install, public transaction, CLI/resume replay, commit, ref or index write was
performed. The held phase09 candidate was not inspected, imported or executed.
No genuine SUT defect was established. Preserved development failures and
their harness-only corrections are in `failed-attempts.md`.

## Executed checks

| Final gate | Actual result |
| --- | --- |
| Complete current Migration specs, including new invariant subdirectory | 169 passed, 0 failed/skipped, 29 suites |
| Complete pinned Migration forks, including new invariant subdirectory | 144 passed, 0 failed/skipped, 25 suites |
| Focused ordinary funded staking, weighted V3 SE, fee/creator and trust flags | 58 passed, 0 failed/skipped, 8 suites |
| Native invariant, seed `0x2401` | 16 runs, depth 8, 128 calls, 0 unexpected reverts/discards |
| Legacy invariant, seed `0x2402` | 16 runs, depth 8, 128 calls, 0 unexpected reverts/discards |

The repository's runs=16/depth=8 was retained; fail-on-revert was explicitly
enabled for both invariant gates. Each fixture executes successful actions
before targeting the handler, so reaching an action selector is not a
probabilistic coverage prerequisite. The two deterministic tests separately
drive cliff/activation and terminal-credit/recovery sequences.

`execution-evidence.json` records literal shell commands, expanded
artifact-first `forge build --use solar` and `forge test --use solar` commands,
exit codes, summaries, diagnostics and selector counts. Raw final logs are
`specs-final-01.log`, `forks-final-01.log`, and `ordinary-final-01.log`.
All three completed with exit 0. Compiler metadata is
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer runs 1, viaIR false.
No size override was used.

The native random selector counts were: activate 14, time 12, principal 13,
rewards 7, configure 3, failed batch 17, issue 12, market 6, provider change 15,
role rewards 11, bond transfer 9, owner transfer 9. The legacy counts were:
owner change 10, weighted claim 13, convert 14, donate 13, failed issuance 13,
failed batch 10, SY redeem 12, surrender 5, NFT custody 17, wallet transfer/
rejection 14, unstake 7. Each table sums to 128.

Handler success/rejection counters in Foundry's retained final sequence are
**not aggregates of all 16 runs**. Native retained sequence: 15 successful SUT
actions, 8 exact rejections, 0 zero-value claims; its deterministic test:
13 successful actions, 8 rejections, 2 explicitly nonpositive claims. Legacy
retained sequence: 16 successful actions, 8 rejections, 2 actual bond callbacks,
1 late funding rollback, 1 whole-batch rollback, 8 successful recovery stages.
Its deterministic test records 16/4 successful/rejected actions and 9 recovery
stages. Fixture funding and purchases are separate witnesses, not inflated
handler counts. Empty-domain actions either drive the next real prerequisite
or assert an exact rejection; they are not reported as successful custody.

Six new files have fresh no-diagnostic LSP results. Fresh diagnostics timed
out for `MigrationNativeHandler.sol` and `TestBase_MigrationStateful.sol`;
their final Solar compile and execution passed. Existing compiler/nightly/
fmt warnings remain visible. Biome is absent; evidence JSON was parsed
directly, not represented as editor-validated.

## Independent models and twelve-property matrix

Path abbreviations in this table:

- `N`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationNativeHandler.sol`
- `B`: the same directory's `MigrationNativeLedger.sol`
- `L`: the same directory's `MigrationLegacyHandler.sol`
- `R`: the same directory's `MigrationLegacyRecoveryHandler.sol`
- `NS`: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationNativeInvariant.t.sol`
- `LS`: the corresponding fork directory's `MigrationLegacyInvariant.t.sol`

Every `assertAll` runs after actions and at the invariant boundary. Native
configuration hashes are independently encoded from the input and fixed
domain. Original-credit anchors are captured before live mutations; they are
not reread from the configuration being asserted. Initial quote correctness
is also covered by the existing complete snapshot suite. The new model is
not a second independent implementation of the nonlinear frozen evaluator.

Native principal, gons, claimed amounts, holders, timestamps, supply, backing,
index, two dust partitions and fee/creator weights are separate ghost values.
Reward allocation/rebase/top-up integer equations are implemented independently,
without calling the SUT staking math. The initial real paid-bond quote supplies
purchase inputs, not current staking postconditions. Subsequent expected
state follows action inputs and these equations.

| Plan property | Source and independent expectation | Successful witness and random result | Exact limit |
| --- | --- | --- | --- |
| 1. Wallet-bound credit conservation | `L:95,203`: separate Q/C recurrence, final exact residue, consumed plus remaining Q, delivered plus remaining C=C0, wallet holdings distinct | Actual partial SY custody in every prelude; terminal custody in `LS:99`; random surrender and wallet-transfer actions pass | Native9 ordinary SY; standalone gon/internal-share/static-source state machines are not inferred |
| 2. Configured original wallet and actual asset | `L:131,150,203`: matching immutable wallet, real transfer/return, exact wrong-wallet or missing-record errors, custody/supply/backing unchanged | A different holder really receives and returns SY; original contract wallet succeeds; both historical original-wallet NFTs reach custody | Missing-record check occurs in the exhausted-SY branch; inherited complete forks provide additional deterministic missing/approval/balance cases |
| 3. Corrections preserve execution | `N:43,57,258`, `B:161`: input-derived replacement versus separate issued credit/configuration/ID/time and bond model | Issued recipient corrected in every native prelude; six actor configs and repeated corrections/issuance attempts in random sequences | Configuration correction is Stage 1 only; no claim that partly surrendered Stage 2 configuration is mutable |
| 4. Credit has custody or independent authority | `N:72`, `L:95,150,172`: exact authorized allocation or measured legacy debit for each principal, fresh bond and supply/backing increment | Genuine independent issues; partial/terminal SY and two whole NFTs; all random ledger checks pass | Independent credit is explicitly no-surrender authority; synthetic test originals are not operational awards |
| 5. Failed issuance restores economics | `N:98`, `L:115,193`: first funded batch item undone by second failure; late receiver failure after real receipt funding restores SY allowance/custody, Q/C, supply, backing and NFT count | Deterministic real late failure then successful surrender; repeated random failures; exact receiver error and expected funding call | Ordinary-SY contract callback, not claimed-origin preparation; prior source transactions are not rolled back |
| 6. Funded principal solvency | `B:93,109,161`, `L:172,203`: independent gons/principal, full staking partition, actual escrow, staking value >= remaining principal | Paid reward funding, independent issuance, transfers, principal/reward claims; legacy fresh funding | Native random model has fixed post-purchase index within a high-threshold bounded market domain; arbitrary expansion remains supplemental coverage |
| 7. Own principal cliff | `B:129,161`, `NS:24`: recorded creation plus 7776000 seconds; zero before own cliff and exact remaining principal at it | Actual pre-cliff and exact-cliff principal claims, transfer, activation and later random time/issuance | Native claims cover compensation cliffs; legacy handler does not warp; existing forks supplement delayed surrender clocks |
| 8. No Stage 1 reward payout | `N:169,189`, `B:109,161`: real paid rewards remain in bond/role gons; exact closed errors; no hidden backing/index changes | Funded independent-bond and fee/creator rewards reject before activation and pay after it | Direct combined/SY/RT/egress routes are covered by current deterministic Migration suites, not new randomized wrapper actions |
| 9. Permanent Stage 2 removal | `N:120,248,258`: all 14 interface-derived administration selectors absent; stage never reversed; exact former-selector errors | Real activation, repeated activate/configure/issue attempts, ownership changes and ongoing market/claims | Factory/initializer restoration probes remain in complete deterministic surface tests; no arbitrary execution selector is invented |
| 10. Frozen original pricing | `N:211,232,258`: fixed pre-mutation quotes and full snapshot bytes survive actual market inputs | Real hook trades, oracle fee changes, real reserve donations and SE backing donations that demonstrably change the actual provider rate | Bounded three original sizes and small market inputs, not all weighted quote domains |
| 11. Recovery reconciles by asset/stage | `R:25,39,66,78,91,110,146`, `L:203`: separate SY, attributed WS gons, WD, DTF recovery, protected donation and spendable residual; exact input debits and measured external outputs | Real SY redemption, weighted NFT claim, unstake, conversion, fixed-beneficiary donation and failing selected batch; random stage sequences pass | Legacy rate fixed at the pin; growth and earlier sale/claim/disabled exits remain separate deterministic evidence; no cross-unit sum |
| 12. Owner/registry/bond/isolation preservation | `N:130,148,258`, `B:194`, `R:126`: expected current owner, unchanged registry owner/frozen book/issued facts, separate real proxy/hook/children/ledger | Two independently funded actual instances, new-owner acceptance, former/pending-owner rejection, NFT transfers, owner-only recovery after transfer | Shared external SE valuation may move; stored snapshot and second instance's own accounting remain unchanged |

## Catalog disposition

| Case | Actual evidence / limit |
| --- | --- |
| A0 | Native fixture donates and bootstraps before any independent principal, reconciles self-leg supply, then issues exact principal; existing genesis suite also passes |
| I1-I3 | Supplemental complete Migration gates plus focused ordinary weighted trust-flag suite; these are not newly randomized pretransfer selectors |
| J1-J3 | All new calls use real registry proxies; 14 interface-derived administration selectors checked before/after activation; complete existing `MigrationSurface` tests pass |
| K1 | Donations never amend frozen credit or create independent credit; legacy protected donation and actual recovery budgets are separate |
| E6 | No caller-selected refund on these migration surrender/recovery APIs. Donation sweep uses selected recovery plus previously recorded protocol residual, while protected inventory stays fixed; ordinary trust-flag regressions supplement |
| N1 / reentry | Actual ordinary-SY receiver reaches funded NFT delivery, attempts nested surrender and activation, asserts exact errors, and completes/rejects the outer operation; current hostile-contribution/owner-callback suites supplement |
| Fee/creator nondilution | Native integer weight/rebase/deferred-role model plus actual gated release; complete retained-accounting and focused ordinary fee/creator tests pass |
| Source spoofing / wrapper duplicate | Supported fixed source in new handler; actual complete configuration/fork suites supplement source and canonical-origin exclusions. No new randomized cross-representation enrollment claim |
| NFT claim/surrender races | New target proves real whole custody for both models and later weighted claim; race/empty/prior-claim cases remain in complete existing NFT lifecycle forks |
| Activation reentrancy | Ordinary-SY callback exact absent-activation rejection after activation; complete existing native callback tests supplement preactivation busy-child behavior |
| Custody batch failure | Real SY recovery first item followed by exact failing WD debit restores source and parent economics; independent issuance batch rollback also executes |

## Source and unit boundaries

The pinned fork is chain 4663, L2 block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The inherited fixture verifies its header, state root, Orbit L1 block number,
legacy proxy/facet hashes and actual routes. Forks use only the approved
login-shell `robinhood_mainnet_alchemy` alias. No node was needed.

New stateful coverage is ordinary W-Y native9 SY, W-N native9 fixed-principal
whole NFT, E-N original LP-accounting-share whole NFT, and W-Y/W-N recovery
through attributed WS gons, native9 WD and native18 DTF. The holder donation
and NFT caller simulations are local Foundry fixtures, not signatures, donor
key control, public consent or verified historical contribution eligibility.
The ordinary-SY contract's Q0=8000 and E0=0.01 ETH are disclosed synthetic
original inputs. Canonical configured identities remain unchanged.

W-L, E-L, standalone W-R gons, E-R internal shares, C direct native19,
W-SD native28 and W-SW/E-P/W-P native18 have **no new dedicated stateful
original-unit handlers in this increment**. Their existing deterministic
configuration/custody/recovery tests were run in full and remain distinct
supplemental evidence. W-R/E-R positive nonrepresentable Q/C residue is not
silently forgiven or inferred from the scalar SY model.

Complete-original claimed SY remains direct-signed-EOA, canonical
isolated-source-block evidence only. The three existing claimed-SY Foundry
cases passed, but no operator certificate/signature preparation or CLI replay
was performed. Ordinary-SY callback coverage is not claimed-origin coverage.
Partial/prior-delivered/unknown originals, raw TokenStaking approved pull,
E-S, disabled W-SW/E-P/W-P conversions, standalone historical native/WETH,
operational original datasets, legacy archive equivalence, target gas and
host/archive portability remain unaccepted. Earlier mature-close authority,
optional missing historical facet and external-EOA-owner LP-release
qualifications are unchanged. No source category is declared absent.

## Candidate, artifacts, deployment and stop

`candidate-01.json` retains every new source's complete bytes, SHA-256, length
and mode; `candidate-01.patch` is the complete new-file diff. The candidate
matched those bindings after final execution. `authority-bindings.json`
retains original current law, brief/intake, source boundaries and exact
phase23 producer/r2/immutable reports. The producer and r2 hashes reproduce
`49fab644f20998227e1c30013c07e2895a8feeda1e0714ae481a860b4d11e0dd`
and `14750c64ed29a92ddf36b8c68fd6ec8b9fcdd39b7bc61e612662b1ff617a3f41`.

`artifact-deployment-bindings.json` records 177 artifact identities, all 966
current compiler-source comparisons (zero mismatch), six subject captures,
522 repeated raw runtime captures and 66 unique address/runtime bindings.
All 66 match artifact bytes, allowing only compiler-declared link/immutable
spans; every observed substitution and repeated-value check is retained.
No arbitrary masking or metadata stripping was used. Native submitted package
arguments decode to the actual captured main hook and owner.

This binding is not an independently authenticated constructor transaction
archive or a separate capture of every linked library's runtime. The actual
raw runtimes remain in final logs, and templates, named links, observed
immutable values, current source hashes and typed deployment fixtures remain
bound. The warm `out/`, `cache_forge/`, dependency links and earlier host
evidence are retained; no portability or cold reconstruction claim follows.

The native handler is one bounded action state machine; its independent
accounting is a separate file. It carries an explicit size exception at 256
nonblank/noncomment lines rather than adding a generic abstraction. No
production mutation experiment was run because the scope forbids existing
source edits. Credible regressions are the conservation, input-derived
configuration, funded-claim, exact-error and routing assertions themselves.

Source writes stopped before the final complete runs. `cleanup-final.log` records
the unchanged audited HEAD, correct branch, clean tracked/index comparisons,
new-file whitespace checks and no listener on 18574. All owned execution
monitors exited; no Anvil, checkpoint, subscription, delegated task or other
operation is pending. Only implementation evidence was written afterward.
`seal.json` binds final evidence membership, excluding only its own bytes.
Independent verification owns its separate directory and has not been claimed.

**Bounded increment delivered; broader all-source stateful/full-plan,
full-repository, operational and gas acceptance remains open.**
