# Independent two-generation NFT surrender verification

Date: 2026-11-11.

**AdversarialVerify: confirmed**, for the complete bounded two-generation NFT
surrender implementation. **Weighted route: confirmed. Earlier route:
confirmed.** No unresolved product defect was found within this boundary.

Both pinned legacy collections were actually surrendered into genuine
registry-deployed Migration proxies. This is not an ABI-only, source-only,
fake-legacy, or EOA-custodian verdict. All non-NFT original-plan gates remain
open. Full Migration, harvesting, operational allocations, operator readiness
and release completion are **not confirmed**.

## 1. Scope and provenance

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`.
Independently observed branch: `work/dtf-migration-phase-05`.
HEAD before and after verification:
`5021e8d4a62bcbddc555f580ef98f8666d993aab`.
The NFT implementation is the existing uncommitted delta on that base, not
code already contained in that commit.

Read the complete phase05 brief and original
`migration-detf-implementation-plan-r1`, including MIG-P01-P15, E1-E5,
all ten work packages, all 53 acceptance dispositions, and F1-F4. The original
plan was read at
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`;
its SHA-256 remains
`56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`.

Also read repository routers, canonical deployment/architecture/testing/
adversarial rules, both source contracts, the source gate, implementation
report, actual adapters/parent/child/funding/package/TestBase code, the
configuration and pinned fork tests, phase01 independent and source evidence,
and accepted phase04 correction verification. Phase03 r3 accounting and
phase04 F1/V1 corrections were retained, not redefined.

Root supplied the warm-seed exit-0 and initial clean-state receipts.
Verification independently checked the exact branch/HEAD and accounted for
the existing implementation changes. Plain Git status initially returned 128
because the seeded `lib/crane` is a symlink; read-only status/diff with
submodules ignored succeeded. The symlink was not changed.

Evidence:

| Artifact | Meaning |
| --- | --- |
| [evidence.json](evidence.json) | Exact commands/exits, source/artifact fingerprints, receipt audit, trace locators, preservation and runtime disposition |
| [fork-independent.log](fork-independent.log) | Independently executed 16-case historical fork suite; complete test traces |
| [configuration-independent.log](configuration-independent.log) | Independently executed eight real-proxy configuration/collision cases |
| [NftStageOneWitness.s.sol](NftStageOneWitness.s.sol) | Additional independent prolonged-Stage1 lifecycle witness |
| [stage1-independent-r2.log](stage1-independent-r2.log) | Successful witness, including full real deployment/artifact-loading trace |
| [stage1-independent.log](stage1-independent.log) | Preserved initial verifier-harness failure; not product failure or passing coverage |

All transactions here are isolated, in-process Foundry fork calls. They are
not public broadcasts or mined Anvil transaction receipts. The archived
phase01 purchase/custody receipts are separately identified as such.

## 2. Source, artifact and receipt bindings

Both actual source routes use Robinhood chain **4663**, L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
There was no fresh-pin fallback. The fixture checks the L2 header and its
L1 number; Orbit's EVM `BLOCKNUMBER` is 26367659. It does not replace the
historical execution state. This pin is not the new funded pricing snapshot.

| Historical identity | Independently recomputed runtime Keccak-256 |
| --- | --- |
| Weighted `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Earlier `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | Same proxy hash; distinct selector routing |
| Owner/approval facet `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| Weighted position/transfer `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |
| Earlier position/transfer `0x3AB85813785b43B864F9C171F7ac97d6B76c459b` | `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |

The executed fixture checks actual owner, position, safe-transfer and approval
loupe routes and facet hashes, not merely the shared proxy hash. Its two
five-word return layouts are explicitly typed. Current repository contracts
were not substituted for deployed legacy code.

Independent offline inspection re-decoded **43 weighted and 16 earlier**
original purchase receipts, checked successful status and archived canonical
block-hash joins, and reproduced all **eight integrated fixtures'** original
units and direct native ETH/WETH/DTF inputs. Earlier ID 3 contributes 2e18 WETH;
its routed intermediate DTF is not counted again. These are fixture bindings,
not approval of the operational compensation dataset.

The weighted deployed target/math/ERC721 excerpts and all 17 earlier source
excerpts were checked against the actual unescaped source archives.
All **17** fingerprinted plan/phase01/phase04 inputs and both admitted source
contracts still match. Their runtime/source observations remain distinct from
the archived Sourcify recompilation's metadata-match qualifications.

All **215 unique transitive source hashes** embedded in the four changed
production artifacts match the current source bytes. The implementation
report's four initial artifact SHA-256 values also matched at entry.
The verifier's script compilation subsequently changed artifact source IDs
and source-map envelopes, so their final JSON-file hashes differ:
**creation bytecode, deployed-bytecode objects and metadata remain exactly
equal**. Both versions are recorded in `evidence.json.productionBinding`.
The successful script trace contains the exact JSON artifacts actually read
by the deployment helper; all four match the reviewed executable bytes and
metadata (`traceArtifactBindings`). No stale-artifact substitution is used.

Runtime sizes remain 20,886 bytes for the retained facet, 21,204 for the
allocation facet, 16,646 for the parent package and 9,496 for the bond facet,
all below 24,576. Artifact runtime-object hashes are not represented as
fully linked/immutable-populated on-chain hashes.

## 3. Decisive execution observations

Source prefix **M** below is
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
Fork trace line numbers refer to `fork-independent.log`.

| Obligation | Independent observation |
| --- | --- |
| Original credit times remaining fraction | Line 20099: weighted ID 32 has P0=54,436,459, Pc=8,071,216, Pr=46,365,243. Delivered credit is **16,965,232,709,984**, exactly floor(C0*Pr/P0), and differs from quoting reduced original DTF. Actual supply, receipt backing and attributed gons reconcile. |
| Earlier accounting units | Line 13665: ID 12's 47,848,240,999,749,918,187,208,884 original shares differ from physical LP assets. Credit uses original shares. Line 13966: a real reward claim pays 309,005,608,995,105 old DETF without reducing ID 4's original shares or increasing its C0. |
| Actual holder and beneficiary | Line 19121: weighted ID 26's transferred holder, not purchaser or approved operator, receives the new bond. Earlier holder transfer is exercised at line 13966. No beneficiary argument is exposed by surrender. |
| Whole identity and custody | Line 17931: the two ID 3 identities both surrender, remain distinct and create distinct bonds; earlier ID 3 is still legacy-locked. Source ownership becomes the actual Migration proxy; per-token approval clears; Migration grants no holder/operator approval over custody. |
| Invalid eligibility | Lines 12222, 14555 and 16741: burned/nonexistent/reserved/zero-credit and mismatched-unit inputs reject. Actual weighted principal-only claim leaves a reward-only NFT which rejects. Actual earlier sale burns its NFT, which also rejects. |
| Live claim race | Line 12643: actual principal claim after configuration lowers the live award. Stale minimum rejects before consumption; the current fraction succeeds. |
| Permanent consumption and replacement | Line 7710: replacement after partial weighted surrender cannot resize its delivered bond, clock or custody or reopen the identity. No residual NFT/descendant award is produced. |
| Independent overlap | The eight-case independent configuration run rejects canonical NFT-origin collisions in both configuration orders and after independent issuance followed by replacement. The fork also rejects independent configuration after consumed NFT replacement. |
| Safe-transfer callback ordering | Line 14790: both real sources invoke the expected receiver before their authorization/ownership update; missing approval then reverts everything. A properly approved retry succeeds. The callback is acceptance only, not issuance. |
| Receiver failure and reentry | Line 5679: a real contract holder rejects a fully funded marked new bond, reverting source custody, approvals, new supply, backing, gons, consumption and the new NFT. Retry succeeds. Line 6892: even a holder which is current Migration owner cannot reenter surrender, replay acceptance or activate from the bond callback. |
| Real funding failure | Line 7226: limited-gas surrender reaches the genuine bond and receipt, actually transfers backing into the receipt, then runs out of gas there. Owner, approval, supply, backing, gons and consumption roll back. Exact receipt-call count two covers failed acquisition plus successful retry, not retry alone. |
| Distinct instances | Line 8776: two actual registry instances have distinct origin domains; the second cannot take an NFT already held by the first. No SUT impersonation supplies that authority. |
| Activation and fresh later clocks | Line 2828: both routes work before and after actual activation; later bonds start 120 days later and retain full 90-day cliffs. Independent configuration checks retain all 17 permanent selectors. The additional witness verifies all six administration removals and withdrawal of the allocation interface. |

The fork trace contains **18 successful surrender events and 18 corresponding
Migration-position events**, across isolated cases. This is not 18 independent
test cases or a set of public receipts.

The implementation call graph supports these observations:

- `M/legacy/MigrationLegacyNftLib.sol:14-65` fixes the two chain-4663 sources,
  uses weighted principal minus claimed principal, enforces earlier original
  share equality, and applies full-precision proportional credit.
- `M/UniswapV4DetfMigrationTarget.sol:67-124` guards the complete pull,
  authenticates the current holder, constrains one callback, verifies actual
  ownership and position after return, records whole consumption, then funds.
- `M/UniswapV4DetfMigrationAllocationTarget.sol:54-184` separates loading from
  issuance, checks canonical origin collisions in both directions, and removes
  the actual six-selector administration surface.
- `M/UniswapV4DetfMigrationRepo.sol:60-72` uses the common exact-funded path.
  `common/bondNft/DETFFundedBondTarget.sol:107-143` measures actual pulls and
  exact receipt gons; no escrow surplus substitutes for new principal.
- `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:27-87` marks the
  funded position before receiver acceptance, preserves the shared accounting
  guard, gives migration positions their cliff and gates reward requests.

### Additional prolonged-Stage1 witness

The independent script deploys through the same production TestBase but runs
a new combined lifecycle, rather than copying the implementation. Parent:
`0x2328d231C43A15940f5E312dDEc0e720a8ACdF37`, local simulation only.

Initial weighted ID 32 and earlier ID 4 create new bonds 3/4 at **1794110901**,
unlocking at **1801886901**. Both actual principal claims return zero one
second before the cliff. Stage 1 remains closed for 120 days. Rewards-only
and combined requests revert `MigrationRewardsClosed`, while principal-only
claims pay exactly **16,965,232,709,984** and **2,566,655,548,570** receipt
units, with zero reward components. Both holders then redeem those receipts
for the exact same native raw DETF amounts before activation. Actual
expansion funding occurs in this run; the gate is not inferred solely from
an empty rewards system. Reverted funding events inside failed calls are
not counted as committed rewards.

Legacy custody and immutable surrender history survive these new-bond exits;
both source identities still reject another surrender. Activation removes all
six loading/issuance/activation selectors and their interface. Weighted ID 26
and earlier ID 3 then create bonds 5/6 at **1804478901**, with principal
**17,785,729,540** and **711,428,507**, unlocking at **1812254901**.
Both later principal previews are zero one second before their own cliff and
equal their full principal at the boundary. No earlier clock is restarted.

The complete successful trace is `stage1-independent-r2.log`, SHA-256
`45b9a9baca4e55677c364e0bcdb097a755dbaf4720bfe3ac0dc80933c91ef009`.
Its final `VerifiedNftLifecycle` event is at line 15396.

## 4. Boundaries which this verdict does not erase

**Known-origin rejection is not a general ancestry proof.** Independent
allocation IDs are opaque verified-input identifiers. Supplying an unrelated
alias does not prove different economic exposure, and the contract does not
magically detect undisclosed aliases. The canonical NFT-origin collision
checks and absence of a descendant issuance path satisfy the admitted
bounded contract; operational economic disjointness and complete fungible/
claim/wrapper ancestry remain E2 obligations. No mutable postactivation
approver, new signature authority or original-payer restriction was introduced.

**Surrender is not harvesting.** The independently executed earlier mature
close still returns
`VaultDisabled(0xb7D4Bb379D361AD442CddEE53eA71a33957826A7)`,
selector `0x1ba84b43`. Earlier receipt redemption remains blocked by the
preserved source evidence. Wrong-owner mature-close authority remains masked
by that disable check. The missing old-DETF facet source
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE` remains missing; it is not one
of the admitted NFT read/transfer facets. No source policy was changed.

The historical weighted approved-operator redirection, restricted fungible
LP exits, TokenStaking ordinary-caller limitation and phase01 adverse verdicts
remain adverse evidence. They are not relabeled as passing full recovery.

## 5. Commands, regression counts and failed attempts

All executions ran in the named worktree, sequentially, using
`/Users/cyotee/.foundry/bin/forge` 1.9.1-nightly,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, and Solar metadata
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. No viaIR, configuration change,
dependency installation or concurrent compiler was used.

Exact wrappers, output paths and exit sentinels are in `evidence.json`.
They use `/bin/zsh -lic` for existing archive access, `set -o pipefail`,
and `tee` to preserve the complete output. No secret or resolved RPC URL
is recorded.

| Execution | Result |
| --- | --- |
| Artifact-first historical fork helper, existing NFT fork directory, `-j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv` | **Exit 0; 16 passed, two suites, zero failed/skipped** |
| Artifact-first helper, `MigrationNftConfiguration.t.sol`, `-vvv` | **Exit 0; eight passed, one suite, zero failed/skipped** |
| `FOUNDRY_PROFILE=fork forge script --use solar .../NftStageOneWitness.s.sol:NftStageOneWitnessRunner --compute-units-per-second 10 --rpc-timeout 120 -vvvv` | **Exit 0; complete independent lifecycle assertions passed** |
| Initial script targeting the fixture directly rather than its runner | **Exit 1 during setup**: Forge rejected use of the ephemeral script address; no surrender verdict came from that attempt |

The harness correction follows the existing phase04 verifier pattern:
instantiate an ordinary external test fixture, allow its cheatcodes, call
its setup/run. Only the owned witness changed. Production and existing tests
were not fixed or weakened.

Saved implementation results were independently counted, not rerun as large
suites:

| Saved log | Independently recounted result and disposition |
| --- | --- |
| `build-01.log` | Successful artifact-first Solar closure; producer recorded exit 0 |
| `spec-01.log` | 90 passed / one failed, 14 suites; historical receiver-fixture failure retained |
| `spec-02.log` | **91 passed**, 14 suites, zero failed/skipped; producer recorded exit 0 |
| `fork-01.log` | Compilation failure; no executed test result |
| `fork-02.log` | Two setup failures from L1/L2 block-number comparison |
| `fork-03.log` | 13 passed / one failed, two suites; timestamp-local assertion failure retained |
| `fork-04.log` | 15 passed, two suites; superseded weak funding-call witness is not used |
| `fork-05.log` | **16 passed**, two suites, zero failed/skipped; independently replayed here |
| `regression-01.log` | **9,932 passed**, 589 suites, zero failed/skipped; producer recorded exit 0 |

Each saved count agrees with both individual PASS lines and final suite
summary. The old logs do not independently embed all shell exit statuses;
their recorded exits come from the implementation report. Fresh owned runs
have explicit exit sentinels and monitor completion codes. The 91 and 9,932
passing scopes were not repeated without a named concern. No full-repository
release run is claimed.

Compiler warnings remain visible. The JSON LSP cannot run because `biome`
is not installed; no installation is authorized or needed. JSON structural
validation and successful Solar compilation/execution are the checks used,
not a claimed clean LSP report.

## 6. Exact remaining original-plan gates

No whole original-plan checkbox is closed by this bounded verification.
The accepted bounded snapshot/genesis/core results remain accepted, but do
not imply closure of the complete operational product.

| Original gate/work package | Exact remaining obligation |
| --- | --- |
| **E1 / task 1 / MIG-P15** | Close every retained category's actual custody, caller authority, rollback and recovery/conversion route. Both NFT read/surrender routes are now confirmed; broader harvest remains open. |
| **E2 / tasks 1, 4, 6** | Authenticated complete ordinary-transfer, claim, wrapper, merge and proportional partial-surrender history, fresh custody and nonduplication after activation without trusted mutable updates; operational independent/held/descendant exposure reconciliation. Do not finalize an unsupported fungible attribution ABI. |
| **E3 / task 2** | Preserve accepted frozen evaluator evidence; admit actual deployment reserve/routes, complete amount-dependent quote domain and operational original entitlements. Do not substitute fixture liquidity, live rates or split nonlinear quote units. |
| **E4 / task 3** | Preserve corrected genuine genesis/core evidence; bind actual funding receipts, reserve self-leg, capital and quote snapshot for the eventual deployment. No funding-complete flag is invented. |
| **E5 / tasks 5, 7** | Preserve accepted r3/core payout evidence and this NFT integration; complete the full product's parent/child/ordinary-route payout, accounting, disable and irreversible-activation matrix as remaining categories arrive. No early-principal or Stage1 reward-policy change. |
| **Task 4** | Remaining typed fungible/claim/source loading and partial-consumption corrections depend on E1/E2. NFT replacement and known-origin separation do not implement those records. |
| **Task 6** | Remaining fungible, receipt, wrapper and nontransferable-claim surrender must be atomic with proportional prequoted credit and fresh bonds. Both confirmed NFT models remain separate required rows. |
| **Task 7** | Final complete-product selector inventory, aliases, indirect restoration/callback negatives and registry policy; this phase proves the currently installed six-selector cut, not future unimplemented surfaces. |
| **Task 8 / MIG-P14** | Owner-only bounded harvest/conversion/donation, fixed new-DETF destination, measured operation-local deltas, staged custody, selected-batch rollback, repeat safety and actual restricted/disabled route resolution. |
| **Task 9** | Deterministic non-issuable-evidence-to-reviewed-dataset preparation, source/snapshot fingerprints, funding-first stages, receipt/checkpoint reconciliation, interrupted/reordered resumable rehearsal, no duplicate funding or issuance. |
| **Task 10 / section 8** | Complete source matrix, all-product successful-action invariants, conservation, measured gas/batch limits, full local rehearsal, ordinary regression and eventual full hermetic release run. |
| **F1** | Verify all MIG-P01-P15, all 53 acceptance dispositions, every source category and complete E1-E5. Open. |
| **F2** | Execute the complete product lifecycle, all required pinned routes, money paths, invariants and final proxy/ordinary matrix. Open. |
| **F3** | Independently reproduce operational configuration and interrupted operator recovery, with receipt reconciliation and complete administration removal. Open. |
| **F4 / section 11** | Full implementation-completion report only after the above are closed; deployment, real funding, activation and compensation execution require separate authorization and reviewed operational datasets. Open. |

Required categories are still: weighted liquid DETF, earlier liquid DETF,
weighted fixed-principal NFT, earlier LP-lock NFT, weighted sDETF, earlier
receipt, legacy SY, TokenStaking/claim-vault rights, underlying SE shares and
fungible LP. NFT LP locks and fungible LP are not one category. None was
omitted, declared absent from missing rows, or replaced with a wallet allowance.

## 7. Preservation and runtime cleanup

All four owned monitored runs completed: fork 0, initial witness 1, corrected
witness 0, configuration 0. No owned execution remains pending. No Anvil,
listening port, public transaction, broadcast, persistent impersonation or
temporary runtime root was created. In-process fork states ended with their
Forge runners. The observed `/opt/homebrew/bin/forge lsp --stdio`, PID 20817,
parent 10410, is a shared language service and was left untouched.

Final tracked diff is byte-for-byte identical to the captured pre-verification
diff. `git diff --check --ignore-submodules=all` exits 0. The 17 checked
historical/plan inputs and two source contracts remain unchanged. Only this
verification directory was authored; existing implementation/tests, source
evidence and phase01/phase04 evidence were not edited. Compiler-managed
`out/` and `cache_forge/` remain warm and were not deleted; artifact-envelope
changes and unchanged executable bytes are explicitly documented above.

**Final disposition: confirmed for both bounded NFT surrender routes; no
owned runtime pending; all remaining category, operator and release gates
listed above remain open.**
