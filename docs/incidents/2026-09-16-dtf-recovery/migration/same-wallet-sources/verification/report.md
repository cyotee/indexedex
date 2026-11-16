# Independent original-wallet source reconciliation

Date: 2026-11-11.

**AdversarialVerify: confirmed for this evidence handoff only.**
The three clarified producer contracts accurately separate usable legacy
primitives, missing original configuration/unit mappings, finite Migration
integration work, and actual caller/disabled-exit restrictions. No producer
correction is required for that bounded disposition. The reconciled coverage
is **13 required category groups, expanded into 16 source/exposure rows** in
`matrix.md`. This does not confirm original-wallet enforcement in current
code, all-category support, complete recovery, operational allocations, or
runtime success under the changed rule.

## 1. Authority and work boundary

Read the complete phase11 brief at
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase11-same-wallet-source-brief.md`
and the current main-checkout plan at
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
revision `migration-detf-implementation-plan-r3-original-wallet-entitlement`.
Section 1.3 governs eligibility; sections 5.1-5.4 govern domains,
configuration and credit arithmetic.

Read all of `../weighted/contract.md`, `../earlier/contract.md` and
`../claims/contract.md`, then checked load-bearing archived source extracts,
actual result/receipt/trace ranges and present implementation seams.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources`.
Independent read-only Git checks returned:

| Check | Observed result |
| --- | --- |
| `rev-parse HEAD` | `3f577eeca049c1bd70a812d130941c8a38dd4781` |
| `branch --show-current` | `work/dtf-migration-phase-11-same-wallet-sources` |
| Ordinary `status --short` | Exit 128; prescribed linked `lib/crane` prevents ordinary submodule status |
| `status --short --ignore-submodules=all` | Exit 0; existing untracked `docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources/` producer evidence |

Only this directory's `report.md` and `matrix.md` are authored. No production,
script, test, configuration, dependency or historical evidence edits; no
compilation, tests, RPC probes, ancestry research, deployment, transaction,
commit, delegation, cache seed or owned runtime. The separate held phase09
gas candidate, tests, node and provider hold were not inspected or resumed.

## 2. Evidence roots and independent checks

Aliases are absolute roots, not main-checkout substitutes:

| Alias | Root |
| --- | --- |
| E | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence` |
| N | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05/docs/incidents/2026-09-16-dtf-recovery/migration/nft` |
| R | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery/docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery` |
| M | This worktree's `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| O | This worktree's `scripts/recovery/dtf-migration` |

Historical domain H is chain **4663**, L2 block **108944663**, block hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
This is not the funded Migration pricing snapshot or a fresh November 11
validation. Phase01 mined local-fork receipts and phase05/07 isolated
in-process Foundry traces remain different evidence types.

| Inspected evidence | Independent reconciliation |
| --- | --- |
| `E/phase01-verification.md:95-223` | Retain TokenStaking caller restriction, LP caller restrictions, both disabled SEs and infrastructure-fixture limits. Supersede only its old transfer-following E2 eligibility requirement. Missing future Migration integration is not a missing legacy transfer primitive. |
| `E/provenance/report.md:33-136` | Purchase joins differ from observed balances; original ETH and other blanks remain unknown; no approved allocations/C0. Zero SE/LP rows do not prove no exposure. Descendant/backing and independent-award overlap remain real input-partition issues. |
| `E/weighted/deployed-source-extracts.json`, `staking`, `gons`, `sy` | Native allowance and synchronized receipt transfer; partial gon debit versus full-account retirement; selected SY burn and backing-gon conversion. These are archived source excerpts, not substituted current code. |
| `R/weighted/source-evidence.json:353-642,1910-2380` | Seven-word staking state and one-word legacy exchange returns; fixed caller/pull semantics. |
| `N/weighted/archive-audit.json`, bindings; `N/earlier/source-evidence.json`, bindings/source extracts | Distinct five-word NFT layouts, facet identities, receiver-before-owner-update ordering and earlier owner/parent claim/sale authority. |
| `R/earlier/source-evidence.json:206-332` | Parent sale returns one retired-accounting-share word; child sale returns principal shares and rewards. Receipt external/internal scale, getters, direct redeem, parent redeem and mature-close paths remain distinct. |
| `E/verification/weighted-replay.results.json:49447-50963` | Actual WD/WS custody and SY conversion; WD quantity 21,225,531 and WS quantity 38,283,506 are fixture quantities, not configured awards. |
| `E/verification/cp-replay.json`, liquid custody and `receiptCustody` | Earlier liquid direct transfer passes. Displayed receipt input 1e18 receives 999999999999999999 display units and 455166135639508420573509330905780 external shares; not an exact-display-unit pull/credit proof. |
| `E/verification/other-metered.json`, named custody/harvest/rollback cases | Historical acquisition and mechanical custody are real; supersede producer HTTP-429 acquisition gaps. Claim-vault fixture belongs to TokenStaking; SE/LP fixtures likewise do not establish original user authority. |
| `E/verification/other-metered.json:11206-11289` | DTF-custody SE burns selected shares and receives 162264645901640184296798 DTF, local tx `0xb9d405ac37e7aa22f544912461c9945bfeb8c858938bd4fdea7264674c5f0ba6`. This is not proof that the WETH-leg SE works. |
| `E/verification/other-metered.json:10649-10686`; `native-replay.json`, native staged harvest cases | Registry disabled flag is actually returned for weighted WETH SE. LP ownership restrictions and unchanged custody/zero-output maps remain actual results, not transport failures. |
| `E/verification/tokenstaking-caller.json:507-605` and reassignment trace | Ordinary forwarding fails `InsufficientStake(helper,q,0)`; holder reassignment to an always-reverting receiver succeeds without recipient callback. A source PASS labeled atomic surrender does not prove atomic Migration issuance. |
| `N/verification/report.md`; `fork-independent.log:20099` | Accepted bounded two-NFT implementation under the former current-holder rule; weighted ID32 principal 54436459, claimed 8071216, remaining 46365243. Trace decoder field names can alias the earlier tuple: use the authenticated weighted layout, not those printed aliases. |
| `R/correction-verification/report.md`; `fork-independent.log:66439,67372,68752` | Corrected attributed growth conversion, retained wrong-owner disabled-close result and measured earlier sale. The configured tuples still have no original-wallet field. |

Historical suite outcomes are preserved, not rerun or relabeled: weighted
**34 PASS / 1 FAIL / 2 UNPROVEN**; earlier CP **18 / 2 / 4**; other-metered
**21 / 4 / 3**. Weighted approved-operator claim redirection is an actual
adverse result. Old ancestry-only UNPROVEN labels are no longer eligibility
blockers. The phase07 original
`RecoveryInventoryInsufficient(WS,1,0)` failure remains archived; its accepted
correction converts the terminal NFT's additional **488,794** whole receipt
units after spending **4,308,806,205**, reaching **4,309,294,999 WD**.
This is recovery-owned gon accounting, not external fungible entitlement
admission. Historical fingerprints in the producer contracts and cited audits
retain their original attribution; none was recomputed or changed here.

## 3. Reconciled eligibility and conservation contract

Every compensated surrender must have a **present matching configuration,
recorded original wallet equal to caller, and actual current control and
surrender of the eligible asset/claim**. Approval or ownership alone is
insufficient. Check wallet/configuration before any custody, consumption or
issuance. Failure leaves assets, consumed quantities, remaining credit,
supply and new bonds unchanged. Successful credit and bond recipient are
that same wallet, not an arbitrary beneficiary.

Original wallet, qualifying acquisition/economic origin, verified original
ETH/DTF components, source-native original eligible denominator, knownness
and evidence are approved-record inputs. Sources expose current owner,
balances, positions, remaining principal, gons/shares or claim weights.
They do not manufacture the missing original contribution or wallet record.
Configure neither a zero substitute nor an allowance inferred from possession.
Operational inputs and the funded frozen quote are not approved by this review.

Quote each original once on the same funded frozen book:
`C0 = U(ETH, originalEth) + U(DTF, originalDtf)`. Do not reprice reduced
partial contributions, sum different original contributions before nonlinear
quoting, count routed DTF twice, or treat recovered rewards as principal.

* Weighted NFT: require authenticated `P0`, live `Pc <= P0`, and positive
  `Pr=P0-Pc`; deliver `floor(C0*Pr/P0)`. Locked principal counts, rewards do
  not. Consume the entire collection/ID, including the withdrawn fraction.
* Earlier NFT: live original accounting shares must equal its purchased
  positive baseline. A live eligible lock has the full fraction; rewards and
  effective shares do not reduce or increase it. Burn/sale removes the identity.
* Fungibles/claims: after proving source-native q, require `0<q<=Q`;
  deliver C for final `q==Q`, otherwise `floor(C*q/Q)` with full-precision
  multiplication/division. Debit q and delivered credit from that record.
  Zero-credit operations revert without confiscating dust.

Whole operation custody/consumption and one fresh exactly funded 90-day bond
are atomic. A separately completed approval or prior holder claim is not
rolled back by a later transaction. Later recovery batches also have their
own transaction boundaries. Only booked recovery inventory may be spent,
with every legacy output fixed to Migration and eventual reserve donation
fixed to the new DETF; no second compensation or ordinary bond purchase.

Replaceable configuration cannot reset consumed identities, delivered credit,
custody or existing bonds. Ordinary transfers do not move the configured
record; return to the original wallet needs no intermediate-transfer proof
and restores no spent credit. Distinguish a wallet-containing lookup/config
identity from the **wallet-independent canonical economic-origin collision
identity**: correcting a wallet must not create another quote or evade
independent/NFT/descendant overlap checks. This reconciles the producers'
wallet-keyed configuration descriptions with `claims/contract.md` section 1.

Independent compensation remains recipient-keyed, Stage 1, no-surrender and
disjoint from outstanding surrender exposure. Permissionless capital donation
needs no personal entitlement and creates none.

## 4. Retained limitations and exact source dispositions

The complete source-by-source distinction is in `matrix.md`. In particular:

1. **TokenStaking raw weight:** no ordinary-contract atomic pull/issuance
   composition is established. `reassign` debits source caller, and there is
   no recipient callback or admitted approval route. Own-wallet
   `withdrawClaim` is a legitimate preparatory conversion to SY, not an
   atomic compensated surrender. A later SY surrender additionally needs
   exact same-origin native-unit/remaining-credit configuration and duplicate
   prevention; no such credited route is silently substituted here.
2. **Earlier receipt:** external-share floor carries cannot automatically
   measure exact newly received internal shares when custody has an existing
   fraction. Original eligible denominator, fractional attribution and
   contribution mapping remain explicit gaps. Accepted NFT sale mints whole
   external shares and does not solve arbitrary receipt-transfer rounding.
3. **Earlier SE and weighted WETH SE:** actual `VaultDisabled(address)`
   (`0x1ba84b43`) remains. Transferability is not liquidation. No enable,
   owner impersonation or substitute source is admitted.
4. **Both fungible LPs:** owning their ERC20 does not confer the legacy
   DETF's owner role. Earlier exact-in exits give `UnsupportedRoute()`
   (`0x5d5fe824`); earlier native and weighted direct/native exits give
   `NotOwner(custodian)` (`0x245aecd3`). No source-authorized recovery of
   this newly surrendered LP inventory is proved.
5. **Earlier liquid conversion:** exact source method exists, but no passing
   ED-to-DTF execution is admitted. Do not convert that absence into a newly
   observed disabled error or borrow weighted success.
6. **Earlier mature close:** disabled rollback masks its external holder
   authorization weakness; neither safe ownership rejection nor successful
   theft is established. Optional earlier facet archive HTTP 404 remains a
   complete-source-audit limit, not absence of every authenticated primitive.
7. **Native/WETH and standalone infrastructure holdings:** native original
   amounts remain unknown; partial WETH joins are source-specific inputs, not
   a complete standalone entitlement census. Infrastructure impersonation
   proves mechanics, never original user authority over those holdings.

The obsolete ancestry mechanism, native-prefix oracle and execution-build
attestation are removed as requirements. Actual economic nonduplication,
source identity, original-wallet admission, unit proof, disabled/caller
restrictions and captured failures remain.

## 5. Finite future implementation handoff

These are separately authorized future changes/tests, not edits or executed
acceptance in this phase.

| ID | Exact code seam and bounded work | Required proof |
| --- | --- | --- |
| H1 | `M/interfaces/IUniswapV4DetfMigration.sol:95-112`; `UniswapV4DetfMigrationAllocationTarget.sol:129-153`: add nonzero recorded `originalWallet` to complete NFT inputs/storage/hash and setter validation. `legacy/MigrationLegacyNftLib.sol:20-24` canonical origin remains wallet-independent. | Both NFT generations: missing config, zero wallet, wrong original wallet despite current ownership/approval, original without control, and transfer-back without history. No movement/consumption/supply/bond on rejection. |
| H2 | `M/UniswapV4DetfMigrationTarget.sol:64-106`: before safe pull require caller equals recorded original wallet as well as live owner. `legacy/MigrationLegacyNftLib.sol:48-66` already rejects absent config/consumed IDs; preserve it. Reuse `Repo._fundBond:64-75`, expected receiver and post-position checks. | Pre/postactivation r3 enforcement; both NFT layouts, weighted withdrawn fraction, earlier full original-share fraction, reserved/burned/reward-only rejection, callback/approval/funding rollback and fresh clocks. Update former transferred-current-holder positive expectations. |
| H3 | `M/UniswapV4DetfMigrationRepo.sol:18-39`, retained interface/Target and `UniswapV4DetfMigrationFacet.sol:10-27`: separate fixed-source fungible configurations, retained queries, immutable consumed/delivered state and measured surrender entrypoints. Do not reuse independent issuance. | Per-origin Q/C partial/final/zero-credit arithmetic, source/domain isolation, replacements preserving execution, exact funded bonds, no on-demand config, and NFT/receipt/wrapper/backing/independent nonduplication. Unknown unit mappings reject. |
| H4 | `M/UniswapV4DetfMigrationRecoveryRepo.sol:11-39`; `legacy/MigrationLegacyRecoveryLib.sol:73-130`: admit measured WD/WS surrender inventory and attributed gons. Preserve corrected synchronized revaluation and every unbooked-gon floor. | Actual synchronized WS pull, mixed NFT/external inventory, growth/full-account fractions, overdraw and funding rollback; no index growth in compensation C. WD uses the one-word return and exact temporary self-source allowance. |
| H5 | `M/interfaces/IUniswapV4DetfMigrationRecovery.sol:6-29`, recovery Target/Lib: finite WY, DE and direct claim-vault-share conversion stages only where evidence admits them; actual fixed recipients, selected inventory and measured outputs. | Real proxy compositions SY->WS->WD->DTF, 28-decimal DE->DTF and 19-decimal vault->SY; exact burn/output/dust, minima/deadlines, staged preservation and whole-selected-batch rollback. Positive user admission needs approved original records, not infrastructure substitution. |
| H6 | Earlier receipt surrender in H3 is gated on its explicit original share denominator/fraction accounting proof. Keep ED/ER/ES/EL, WE/WL custody domains distinct; do not install failed or unproved liquidation paths as accepted recovery stages. | Real approved-pull and fractional floor-carry proof for ER; retained disabled/NotOwner/UnsupportedRoute negatives with no lost held inventory or invented donation. Actual new successful ED or LP route evidence is required before liquidation acceptance. |
| H7 | `M/UniswapV4DetfMigrationAllocationTarget.sol:155-178`, AllocationFacet and retained Facet inventories: remove every new loading selector at activation, retain surrender/queries/recovery. `O/schema.ts:32-41`, `payloads.ts:7-28,30-51,76-88` and typed Foundry Stage08 `configureNfts:58-61`: carry original wallet in serialization/hash and evidence joins; replace stale ancestry-only `blockedGate` reasons with actual row-specific gaps, without unblocking unimplemented categories. | ABI/config hash parity, wallet-independent origin parity, idempotent replacement, removal/no restoration through proxy/package wiring, retained postactivation surrender and current-owner recovery. Keep unsupported rows explicit, not green because ancestry is obsolete. |
| H8 | `M/UniswapV4DetfMigrationRecoveryTarget.sol:33-83`, Policy `:18-55`: extend only measured selected recovery budgets, never raw balances or arbitrary execution. | Fixed receiving custody/eventual reserve destination; protected donations, unsolicited inventory and new backing; no second compensation, no ordinary bond purchase, atomic selected batches and independent prior committed stages. |

For every positive integration fixture, load original records supplying the
wallet, source/economic origin, verified components and exact source-unit
denominator. No production amount is inferred from these mechanical fixtures.
Missing numerical mappings and inaccessible source routes are named above;
they are not broad owner questions or an invitation to redo unchanged probes.

## 6. Verdict limits and completion

No material correction to the three producer evidence contracts was found.
H1-H8 are the finite implementation handoff; retained source/input limitations
are not claimed fixed. Current NFT input has no original wallet and
`surrenderMigrationNft` checks only current ownership. Current interface and
storage have no general fungible/claim surrender ledger. Therefore **r3
runtime enforcement and full Migration acceptance remain unverified**.

Validation was read-only reconciliation of the written evidence against
captured source/results and current code, followed by output-scope and document
checks. No new runtime success is claimed. There is no owned runtime to stop.
