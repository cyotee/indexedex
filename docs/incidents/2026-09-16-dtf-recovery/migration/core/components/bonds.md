# Phase04 Migration funded bonds

Date: 2026-11-10.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Branch: `work/dtf-migration-phase-04`.
Base: `6e27ecaa242c4acca132e3575a160514aad07b11`.

**Delivered: complete owned bond/package/metadata source, with source and LSP
checks. Compilation, deployed selector inspection, rendered metadata and
runtime assertions are pending parent integration.** This is not E4/E5
closure, a legacy surrender implementation, or a production acceptance claim.

## Inputs and owned files

The phase04 brief, original Migration implementation plan, accepted phase03
`egress-contract-r3.md`, `egress-r3-verification.md`, ownership/bootstrap
handoff, phase04 `core/interfaces.md`, actual component interfaces and the
canonical funded bond/staking/ERC721 sources were read. R3 supersedes the
earlier proposals. Current-owner-only genesis is settled; E1/E2 are not.

Path aliases below:

- `B/` = `contracts/vaults/detf/common/bondNft/`.
- `M/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
- `D/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`.
- `K/` = `lib/crane/contracts/`.

New production files, all beneath `M/bondNft/`:

- `UniswapV4DetfMigrationBondNFTRepo.sol`.
- `UniswapV4DetfMigrationBondNFTVaultTarget.sol`.
- `UniswapV4DetfMigrationBondNFTVaultFacet.sol`.
- `UniswapV4DetfMigrationBondNFTVaultDFPkg.sol`.
- `UniswapV4DetfMigrationBondMetadataTarget.sol`.
- `UniswapV4DetfMigrationBondMetadataFacet.sol`.

Existing production changes are only:

- `B/DETFFundedBondTarget.sol`: consumed synchronization and claim-delivery
  dispatch, plus overridable ordinary creation. Ordinary dispatch still
  synchronizes the actual parent and transfers ordinary receipt amounts.
- `B/DETFNFTVaultDFPkg.sol`: make the actual interface declaration overridable.
  Existing registration, initialization and transfer Replace cuts are reused.
- `B/DETFFundedBondMetadata.sol`: default-false presentation options on the
  memory view and their implemented renderer branches. Ordinary callers leave
  these false, preserving their descriptions, attributes and SVG output.

No interface, parent, receipt, SY, factory, test, dependency, configuration or
other lane file was edited.

## Funding, claims, retirement and authority

`M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:19-34` implements
both creation routes. Only the stored canonical parent is authorized.
`createMigrationPosition(uint256,address)` calls the existing common
`_createFundedPosition` with **90 days**, then records one persistent marker.
The clock comes from common `DETFFundedBondRepo._open`, which stores the
actual `block.timestamp`. Neither an old timestamp nor a caller duration is
accepted. The marker survives retirement; it is historical policy identity,
not a cached test of eligibility or a second position ledger.

The actual common pipeline remains:

1. Require initialized reserved roles, nonzero principal/duration and valid
   recipient; no empty position.
2. Pull exactly the principal from the actual parent and require the actual
   inbound DETF balance delta to equal it.
3. Approve exactly that principal to the actual receipt, call its real
   `exchangeIn`, and clear the allowance.
4. Require the actual receipt gon delta to equal
   `StakingMath._toGons(principal,currentK)`.
5. Mint a fresh NFT; store principal, actual clock and measured gons; increase
   the canonical aggregate and require physical coverage.

Idle DETF or receipt inventory does not satisfy either funding delta.
`B/DETFFundedBondTarget.sol` owns this pipeline; no second staking/funding
algorithm was introduced. Ordinary `createFundedPosition` on the Migration
child requires activation and remains unmarked with its supplied linear terms.
The ordinary package is unaffected.

Both preview and execution dispatch to `_calculateClaim`. Migration calls
canonical `StakingMath._claim` at the actual time/index for staking value,
deficit rejection, remaining principal and rewards. For a marked position
only, it replaces vested principal with zero before the cliff or full
principal at/after it, then subtracts already claimed principal. Thus:

```text
principalDue = time < start + 90 days ? 0 : principal - claimedPrincipal
stakingValue = floor(position.stakingGons / k)
require stakingValue >= principal - claimedPrincipal
rewardsDue = stakingValue - (principal - claimedPrincipal)
```

`previewClaim` reports funded accrued components at stored k, not a promise
that the caller is authorized or the reward gate is open. Synchronization
may change k before execution. With unchanged funded state and time, the
principal/reward amounts selected by an authorized open-gate claim equal
the corresponding preview fields.

The common claim path still requires the holder, per-token approved operator,
or approved-for-all operator. A zero recipient resolves to the holder, not
the operator; nonzero recipients retain existing validation. IDs 0/1/2
cannot be claimed as purchased bonds. Rewards-only and combined requests
reject before activation **even when rewards due are zero**; principal-only
does not require activation and therefore succeeds at maturity during a
prolonged Stage 1.

`B/DETFFundedBondTarget.sol:180-225` debits claimed principal, position gons
and aggregate gons before delivery. The Migration delivery override calls
the exact accepted receipt API:

```solidity
deliverBondClaim(address recipient, uint256 principal, uint256 reward, uint256 expectedK)
```

It never invokes the generic receipt transfer path. The receipt must
independently authenticate its fixed bond, verify k/activation/physical
coverage against post-debit `attributedBondGons`, transfer exactly the paid
gons, and credit the recipient's native liquid basis. These are the receipt
lane's implemented obligations, not amounts asserted to be paid by this
source-only check.

Canonical retirement is unchanged: only after all principal is claimed and
this position has less than one native receipt unit of gons does the common
path debit that fraction from the aggregate, delete the position, call
`retireEscrowDust`, then burn the NFT. A whole reward unit keeps the NFT alive.
The receipt retirement boundary must check the actual post-debit aggregate
and preserve canonical aggregate-liability-to-staking-dust accounting.

## Phases, transfers and role ownership

The Migration synchronization override announces `Synchronizing=1` before
calling the real parent. It also holds the existing transient lock across
that call so inherited donation/custody entries cannot reenter during
synchronization. It releases this temporary lock before the inherited
entry's normal `nonReentrant` guard takes over, with phase `Accounting=3`.
Funding, typed claim delivery and retirement all remain Accounting. Completion
restores Idle. Any revert rolls back locks, phases, parent synchronization,
funding and all position effects together.

The getter also reports Accounting when an inherited donation/custody entry
holds the common lock without an explicit phase. Parent activation must
check this actual getter along with the other four children; it must not
activate during synchronization, donation, custody, claim or a safe callback.

All three transfer signatures consume the inherited synchronized,
nonReentrant bodies. They convey the remaining position/clock/marker without
paying a claim. Crane `ERC721Repo._safeTransferFrom` calls the receiver
**before** `_transferFrom` checks authority and mutates ownership
(`K/tokens/ERC721/ERC721Repo.sol:153-169`). The lock/phase cover that actual
order. Even an ultimately unauthorized safe-transfer attempt can execute the
receiver callback before reverting; all callback effects must roll back.

Fee/creator reserved NFT ownership remains the real ERC721 ownership.
Receipt funding resolves the owners at allocation; the receipt lane records
those beneficiaries for Stage-1 R1 custody. Later NFT transfers change future
allocations, not earlier deferred beneficiaries. This bond does not mint role
receipts, cache owners, retarget prior R1, or turn reserved IDs into principal.
Migration role metadata states this distinction.

Live donation and Permit2 routes use the existing bond-first -> parent
join/notify cycle. The parent must not pre-lock its forwarding facade and
deadlock that cycle. Child donation still requires a live/enabled reserve;
pre-live pooled funding/genesis belongs to the separate parent path.

## Selector and call coverage

Signatures below identify selectors canonically; Solidity declarations use
interface `.selector` or keccak for overloads. No unverified hexadecimal
NatSpec values were added. The Migration product facet adds 24 selectors;
the inherited package separately replaces three ERC721 transfers. The
metadata facet adds three. The six generic ERC721 queries/approvals remain
on the canonical ERC721 facet: **36 distinct child selectors**, excluding
callback-factory base loupe/ERC165 surfaces.

| Installed selector signatures | Owning path and policy |
| --- | --- |
| `detf()`, `lpToken()`, `reservedBondNftsWired()` | Migration bond facet, inherited canonical wiring reads |
| `initializeReservedBondNfts(address,address)` | Migration bond facet; actual parent only, once, real protocol/fee/creator IDs |
| `createFundedPosition(uint256,uint256,address)` | Migration bond facet; actual parent only, activation required, ordinary/unmarked linear purchase |
| `createMigrationPosition(uint256,address)` | Migration bond facet; actual parent only, exact common funding, fresh internally fixed cliff |
| `positionOf(uint256)`, `previewClaim(uint256)` | Migration bond facet; canonical existence/position and shared claim policy |
| `claimPrincipal(uint256,address)` | Migration bond facet; holder/operator, cliff on marked IDs, mature Stage-1 principal works |
| `claimRewards(uint256,address)`, `claimBond(uint256,address)` | Migration bond facet; holder/operator and finalized activation; atomic rejection while closed |
| `isMigrationPosition(uint256)`, `attributedBondGons()`, `migrationAccountingPhase()` | Migration bond facet; actual marker, canonical post-effects aggregate and phase/lock queries |
| `transferHeldToken(address,address,uint256)` | Migration bond facet; fixed parent only, cannot transfer DETF or receipt backing |
| `vaultFeeTypeIds()`, `contentsId()`, `vaultTypes()`, `vaultConfig()` | Migration bond facet; actual initialized registry/custody metadata |
| `donate(address,uint256,uint256,bool,uint256)` | Migration bond facet; inherited live reserve donation |
| `donate(address,address,uint256,uint256,bool,uint256)` | Migration bond facet; parent-only donor-preserving forwarding |
| `donateWithPermit2Allowance(address,uint256,uint256,uint256)` | Migration bond facet; actual Permit2 pull, live/enabled reserve, measured input |
| `donateWithPermit2Signature(address,uint256,uint256,uint256,bytes)` | Migration bond facet; actual Permit2 signature pull and unchanged rollback/minimum |
| `previewDonate(address,uint256)` | Migration bond facet; inherited live supported-route quote, zero when unavailable |
| `transferFrom(address,address,uint256)` | Replace to Migration bond facet; guarded synchronized transfer, no payout |
| `safeTransferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256,bytes)` | Replace to Migration bond facet; guarded pre-mutation receiver callback, no payout |
| `balanceOf(address)`, `ownerOf(uint256)`, `approve(address,uint256)`, `setApprovalForAll(address,bool)`, `getApproved(uint256)`, `isApprovedForAll(address,address)` | Canonical ERC721 facet; unchanged authorization/storage |
| `name()`, `symbol()`, `tokenURI(uint256)` | Migration metadata facet; actual collection and policy-aware JSON/SVG |

Package declarations retain the five common interfaces and add the Migration
bond and separate accounting interfaces. Facet declarations advertise the
actual implemented interfaces. Constructor/instance arguments and registered
`deployVault(string,string,IDetf,IERC20)` remain exactly the common schemas.
Parent integration must select the **Migration** lifecycle and metadata facets
in that schema, register the new package through the real manager/registry,
and supply it to the parent's existing child creation pipeline. Existing
`D/UniswapV4DetfTarget.sol:810-849` demonstrates the real bond-before-receipt
wiring; it is not a newly deployed Migration witness.

No current interface incompatibility was found. The parent must settle old
participation before minting/approving the new independent credit and calling
`createMigrationPosition`; a locked-parent callback alone does not settle it.
Receipt funding, delivery and retirement occur while bond phase is Accounting,
as agreed with the receipt lane. During creation, receipt exchange credits the
exact stake packet before `_open` adds that packet to bond attribution; receipt
coverage must allow that genuine fixed-bond packet in flight, not require it
already be an opened position. No initializer, updater, arbitrary
issuer, arbitrary execution selector or historical LP-ledger payout was added.

## Truthful metadata

The actual metadata facet queries proxy `positionOf`, `previewClaim` and
`isMigrationPosition`, and the wired parent's finalized activation getter.
Marked positions use cliff descriptions and **0% until unlock / 100% at
unlock**, not linear progress. JSON includes numeric cliff start, unlock
timestamp, duration seconds and unlocked basis points. Exact nine-decimal
principal/claim/accrued attributes reuse the existing formatter.

Accrued rewards remain visible, separately from executable claimable rewards.
While closed, claimable rewards are zero and total claimable is principal
only; the description/footer explicitly require the principal-only selector
and say combined/reward claims are closed. Activation changes availability,
not accrued gons, start time or maturity. Reserved fee/creator presentation
explains captured beneficiaries. ID zero remains reserve custody. Unmarked
ordinary active positions take the same ordinary rendering branches as
ordinary packages. Burned/nonexistent tokenURI still fails via positionOf.

## Checks actually performed

- Read-only `.git` pointer, worktree HEAD and branch ref matched the branch/base
  above. No Git command or commit was used.
- Source inspection traced real creation two levels through parent wiring,
  common pull/stake/open, shared preview/execution, post-effects typed delivery,
  retirement, all transfer overloads and Crane's actual callback order.
- Source inspection compared canonical bond, donation, registry, ERC721,
  metadata and accepted Migration signatures with the selected facet/package
  cuts. Transfer replacements are deliberately not duplicated in `facetFuncs`.
- An in-memory source comparison found 20 common product selector assignments
  preserved as the exact prefix of the 24 Migration assignments, contiguous
  indices and 24 unique selector expressions. This checks declaration source,
  not generated ABI hashes or deployed routing.
- Direct import resolution through the existing tree checked **73 imports in
  all nine owned production files: zero missing**. No installation occurred.
- Native Solidity `lsp_diagnostics`, severity `all`, returned **No diagnostics
  found** for each of the nine owned production files.
- The receipt-lane follow-up confirmed Accounting for funding, delivery and
  retirement. Bond delivery was aligned to that phase and its diagnostics
  rerun clean. Source inspection of the actual receipt target's
  `_exchange`, `deliverBondClaim`, `retireEscrowDust`, `_requirePostDebit` and
  `_requireEscrow` confirmed the matching phase and pre-open stake packet:
  existing bond coverage is checked before actual pull/credit, not by requiring
  the newly credited packet to be opened early. The final exact ordering was
  sent to root for receipt-lane coordination; the messaging tool accepted it
  into root's follow-up queue.
- A broad initial metadata-caller grep timed out with partial coverage. The
  corrected `contracts/` + `test/`, `*.sol` search completed and found only the
  ordinary and Migration metadata targets. Both use zero-initialized memory
  views; no positional struct initializer is broken by the added options.
- No Forge command, compiler run, runtime harness, model payout, on-chain
  transaction, rendered screenshot, gas or bytecode-size result is claimed.
  Source and LSP results do not establish compiled/runtime correctness.

## Required later real-proxy assertions

Use the genuine canonical CREATE3/manager/registry/callback deployment path,
Migration-selected children, real configured reserve/SEs and actual parent
independent issuance. Do not impersonate a parent, invent a fake issuer,
subclass/mutate/etch the SUT or substitute a model for paid output.

1. **Creation/funding:** configure without issuance, then independently issue
   to two holders at distinct actual times. Check distinct IDs, exact credit
   mint/pull/stake/backing deltas, aggregate increase `P*k`, cleared allowances,
   fixed duration 7776000 seconds and actual timestamps. Prefund surplus and
   prove it cannot supply the new funding deltas. Zero/wrong caller/short pull
   must revert all state. Include a delayed first issue and settlement before
   the second participant; do not credit precreation expansion.
2. **Cliff and successful payments:** at creation, unlock-1, unlock and
   unlock+1 compare real preview/JSON/executed principal. Exercise an
   unexpectedly prolonged Stage 1: successful principal-only delivery and
   actual DETF unstake, but rewards-only/combined reject atomically, including
   zero rewards. Later activation pays retained original bond rewards once.
   Repeat via owner, per-token approval and approval-for-all, with zero and
   nonzero recipients; reject unrelated callers and protected recipients.
3. **Distinct later growth:** deliver mature principal to B while original
   rewards remain on A's NFT; add genuine subsequent funded rewards. Exit B's
   principal directly, exact-output and via parent/configured routes, preserving
   B's R0 and A's original NFT reward ownership. Activate and pay both correctly,
   without creating backing or spending whole old parent/SY inventory.
4. **Retirement/fractions:** partially pay principal/rewards; a whole reward
   unit must preserve the NFT after principal is gone. Only the fully paid
   position's sub-native fraction may retire; check aggregate liability and
   staking-dust delta, remaining other positions, burned existence and persistent
   historical marker. No aggregate pooled or RT remainder may be erased.
5. **Transfers and callback rollback:** exercise all three real routed
   transfers before/after maturity and activation. Check unchanged terms/marker,
   no payout, updated remaining-right owner and approvals. In a real receiver
   callback observe the old owner, attempt claims/transfers/donations and
   owner-contract activation, then assert busy-child rejection and whole-tx
   rollback when transfer fails. Test an unauthorized safe call's pre-check
   callback as well as authorized callbacks.
6. **Roles:** actually fund rewards, transfer fee/creator reserved NFTs, fund
   again, then activate. Old/new beneficiaries retain their separately captured
   R1; equal beneficiaries merge. Delivery before activation remains zero.
   Any caller may trigger fixed-beneficiary release, never redirect it.
7. **Installed surfaces:** interface-derived controls versus actual package
   cuts/loupe and callable selectors; 24 product Adds, three transfer Replaces,
   three metadata Adds and six generic ERC721 selectors. Check seven declared
   interfaces, facet runtime size <=24576, package metadata and registry
   discovery, absent old payout/init/updater/cut/restoration routes.
8. **Metadata and ordinary regressions:** decode real JSON numeric and exact
   decimal attributes, inspect the emitted SVG on the real tokenURI path at
   each boundary and both activation states; require nonoverlap and truthful
   cliff/reward presentation. Compare ordinary output/economics through actual
   ordinary proxies, including linear halfway vesting and immediate ordinary
   role delivery; ordinary active Migration buys must be unmarked/linear.

The parent integration node owns artifact-aware Solar build before these
runtime tests, all five children's combined phase/backing checks, local-chain
proof and ordinary V4/common regressions. E1/E2, actual-recovery E3 and eventual
legacy surrender/harvest/operator gates remain explicit; nothing here relaxes
attribution or transaction atomicity.

Cleanup: no task-owned process, listener, temporary directory, cache or
dependency was created. Warm artifacts and read-only links remain in place.
