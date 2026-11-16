# Independent assessment of additional bond preparation

Date: 2026-11-11.

**Disposition: admitted.** Admit one construction: extend the existing
full-argument, package-held preparation transaction to deploy and validate
the exact existing Migration bond through its registered package, followed
by both SYs. Leave reserved NFT IDs 0/1/2, receipt and RT construction,
reciprocal validation, parent hook removal and parent publication in the
final transaction. The requirements below are part of this admission.

No new product decision, preparer role, owner signature or change to bond
economics is required. The bond already initializes immutable future-parent
and actual-hook bindings without reading live parent code. Its exposed
pre-parent routes cannot create a position or reserved NFT, attribute funded
principal, change those bindings, or confer authority over another holder's
future NFT. Exact permissionless predeployment must be accepted as reuse,
not rejected as an address reservation.

**This is design admission, not successful gas verification.** The preserved
two-SY candidate still fails G1/G2, and the independent verifier's
`needs-fix` verdict remains correct. No corrected construction was compiled,
deployed or executed here. Both distinct instances must still produce
successful receipts for every required transaction with an explicit envelope
no greater than 32,000,000 gas.

## 1. Scope and evidence

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`.

Supplied and previously verified branch/base:
`work/dtf-migration-phase-09-deployment-gas`,
`421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
The existing uncommitted two-SY candidate was read, not modified. This review
does not claim a new Git or compiler-source comparison.

Read completely:

- `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase09-bond-preparation-correction.md`.
- `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase09-deployment-gas-brief.md`.
- This evidence tree's `diagnosis/report.md`, `design-verification/report.md`,
  `implementation/report.md` and `verification/report.md`.

Read the actual current parent/SY packages and interfaces, existing bond
package/initializer/selected economic and metadata surfaces, ERC721
authorization and mint implementation, registry deployment/publication,
callback factory/adaptor/hook, parent bond/receipt wiring, receipt initializer,
Migration funding/recovery/custody and accounting policy sources. Repository
router, applicable product law and canonical construction guidance informed
the interpretation. Migration's explicit ownership/lifecycle rules are not
replaced by the ordinary unowned-DETF default.

Parsed the actual current `implementation/first-current.json`,
`second-current.json`, `post-split-contributors.json`, source/artifact evidence,
and independent `verification/transactions.json`, `traces.json` and
`commands-and-cleanup.json`. The independent report and cleanup are complete;
the earlier running-verifier condition is not an unresolved prerequisite.
No replay was started in this review.

All source references below are worktree-relative. Prefixes:

| Prefix | Path |
| --- | --- |
| `M/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `U/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `B/` | `contracts/vaults/detf/common/bondNft/` |
| `C/` | `lib/crane/contracts/` |

### Current failure remains adverse evidence

Independent inspection of retained receipt envelopes and trace trees gives:

| Operation | Envelope | Status | Gas used |
| --- | ---: | ---: | ---: |
| First two-SY preparation | 32,000,000 | 1 | 13,505,863 |
| First parent finalization | 32,000,000 | 0 | 31,009,212 |
| Second two-SY preparation | 32,000,000 | 1 | 13,454,737 |
| Second parent finalization | 32,000,000 | 0 | 31,009,212 |

Finalization hashes are
`0x44dae0db2469210973bb479c2496d865f6cd0647cb49b305fc0d0e64dd0c855a`
and
`0xb2bed13a0708646f7bc699ad1ed3844d1851763ee8dd19ceeff40e5d00d1a70d`.
Independent retry
`0xaea7b35078421c5c30dab3d065b05d4bf0672bf6f90c0b1dd57a9dd499e04e50`
has the same failed outer frames.

In both current traces, registry delegatecall `0.0.0` receives and consumes
30,963,406 gas and reports `out of gas`. The nested factory at `0.0.0.0`
returns successfully: 24,676,299 gas for the first instance and 24,676,647
for the second. Registered bond construction at
`0.0.0.0.4.1.0.0.0.0.0` costs 5,771,637 inclusive gas in each trace.
These are nested frame costs, not additive transaction budgets. The final
failed receipts retain no logs.

`contracts/registries/vault/VaultRegistryDeploymentTarget.sol:64-76` calls
the factory before registering the parent;
`contracts/registries/vault/VaultRegistryVaultRepo.sol:92-152` performs the
indexes. Moving bond construction is a credible packaging hypothesis, not
proof that either corrected transaction fits. Do not subtract 5,771,637
from a failed receipt and call the remainder a successful gas result.

The producer's 96 existing Migration spec passes and 39 existing pinned
fork passes, its failing bounded regression, the oversized first attempt,
and the independent verifier's incomplete G3-G8 matrix remain preserved
historical results. None is reclassified by this report.

## 2. The single admitted construction

### 2.1 Canonical derivation and commitment

Retain the package-only `prepareSyChildren(PkgArgs)` entry and update its
documentation to say it prepares the bond and both SYs. Retain its existing
return values and the canonical parent `PkgArgs`; no new proxy selector or
operator entry is necessary.

Retain the current parent address domain: canonical parent arguments with
only `baseArgs.hook` cleared in the salt copy. Retain the complete
preparation ID:

```text
keccak256(abi.encode(block.chainid, parentPackage, completeCanonicalParentArgs))
```

The ID includes the actual hook, initial owner, ownership buffer,
WETH/original-DTF bindings, metadata, route rows, rates and every other
parent argument. The factory's package-address salt domain remains part of
every predicted instance. Never key exclusive preparation ownership by
predicted parent alone.

Use one canonical bond argument value in the existing construction
derivation:

```text
IDETFNFTVaultDFPkg.PkgArgs(
    resolveBondName(baseArgs.bondName, baseArgs.name),
    resolveBondSymbol(baseArgs.bondSymbol, baseArgs.symbol),
    predictedParent,
    actual baseArgs.hook
)
```

Expose that value in the interface-owned construction result. Predict the
bond through the actual callback factory and the parent's immutable
`bondPackage`. Preserve `abi.encode(bondArgs)` exactly; the existing bond
package's salt hashes the ABI encoding of those bytes, not an invented
replacement tuple hash. Derive the receipt and both SYs from that same bond
and parent as currently done.

Source: `M/sy/UniswapV4DetfMigrationSYDFPkg.sol:111-142` already derives
these identities and validates hook shape, policy, self-leg/ownership,
creation rates and ordered routes. `B/DETFNFTVaultDFPkg.sol:48-54,102-112`
defines the existing registered deployment and canonical-byte rules.
`M/UniswapV4DetfMigrationDFPkg.sol:237-258` preserves the hook-clearing
prediction and full-preparation admission.

Extend the SELF-held `Preparation` record with the selected bond package
and `keccak256(abi.encode(bondArgs))`. Retain all existing parent,
construction ID, predicted receipt, SY addresses/hashes and completion
fields. These are immutable construction facts, not a caller-controlled
authorization list. Final validation must rederive and compare the bond
arguments; a stored hash alone is not sufficient.

### 2.2 One atomic preparation transaction

Use the existing authenticated parent-package to Migration-SY-package call.
Keep registration, selected-SY dependency, fee-oracle agreement, SELF
context, absent-parent and reentrancy checks.

After the existing static derivation checks, and **before any bond registry
deployment**, acquire the current preparation lock and install the
incomplete full-ID record and exact SY authorizations. Then:

1. Call the existing selected bond package's typed `deployVault` with the
   canonical name, symbol, predicted parent and actual hook. This reaches
   the existing manager registry; do not call the callback factory directly.
2. Require the returned bond address to equal the prediction and perform
   the pre-finalization bond validation in section 4.
3. Deploy/reuse raw SY and staking SY through the current registered
   Migration-SY construction, retaining all existing child validation.
4. Reconfirm the bond's pre-finalization invariants and all three actual
   identities before setting `completed=true`. Clear the lock only after
   completion is recorded.

An already deployed exact bond is admissible, including one permissionlessly
created through its existing package helper before this call. Do not require
bond code to be absent, do not demand the preparer be its deployer, and do
not reinitialize it. The public helper already permits this construction.
Require exact immutable state and factory bindings instead.

An identical completed preparation remains idempotent while the parent is
absent. Revalidate the record's exact bond/child identities and initial-state
invariants on that return; do not turn an old two-SY-only completion marker
into evidence that a bond was prepared. No in-place upgrade or alteration
of a previously deployed package is admitted.

Only this package record means completed preparation. Early bond registry
visibility is not a completed parent, funding authorization, reserved role
or migration entitlement. Bond and SY registry membership is expected;
parent, receipt and RT code remain absent between transactions.

### 2.3 One atomic final parent transaction

Use the existing registered `deployVault(PkgArgs)` route. Its fresh
`processArgs` must require the exact completed bond-plus-SY record, including
bond package/hash/identity, even when entered through the manager rather
than the package helper.

In Migration parent `postDeploy`, validate the prepared bond against the
actual factory-recorded parent arguments before calling the unchanged
`completeReserveBondNft()`. That operation must still traverse the existing
registered bond package and initialize reserved IDs from the live fee
recipient and parent creator. Do not set the parent bond pointer by hand.

Then retain the existing order: complete the live receipt, construct RT,
resolve both registered prepared SYs, and perform all reciprocal,
composition, initial-accounting and five-child distinctness checks. Perform
the post-role bond checks in section 4. Keep temporary parent hook removal
and all manager publication indexes at their existing final boundary.

Sources: `U/UniswapV4DetfTarget.sol:812-850` separates registered bond
construction from reserved IDs and then creates the receipt.
`M/UniswapV4DetfMigrationDFPkg.sol:293-371` contains the existing atomic
post-deploy validation sequence. The common receipt initializer's live
nine-decimal parent check at
`contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol:52-63`
stays unchanged.

## 3. Early-bond authority and economic proof

This section distinguishes source reasoning from runtime observation.
These are source-backed conclusions about the specified construction,
not a claim that the expanded negative matrix has already executed.

### Fixed initialization, no principal or roles

`B/DETFNFTVaultDFPkg.sol:119-125` initializes collection metadata,
StandardVault classification and `DETFFundedBondRepo`.
`B/DETFFundedBondRepo.sol:12-19,33-44` stores only nonzero fixed `detf`
and `lpToken`, rejecting repeated initialization. It does not read the
future parent's code, mint an NFT, fund a position, pull tokens or initialize
roles. Positions, attributed gons, the reserved flag and ERC721 next ID
start at zero. The Migration-specific repo contains only position markers
and accounting phase, initially empty/Idle
(`M/bondNft/UniswapV4DetfMigrationBondNFTRepo.sol:11-14`).

The parent/hook bindings have no exposed setter. The selected bond package
adds Migration interfaces without changing this initializer
(`M/bondNft/UniswapV4DetfMigrationBondNFTVaultDFPkg.sol:9-25`).
Its only selected functional surfaces are ERC721, Migration bond and
Migration metadata; factory base surfaces are introspection, not ownership
or upgrade authority. See `B/DETFNFTVaultDFPkg.sol:60-99`,
`M/bondNft/UniswapV4DetfMigrationBondNFTVaultFacet.sol:31-57`,
and `C/factories/diamondPkg/DiamondPackageCallBackFactory.sol:244-309`.

### Reachable route matrix

| Early route | Actual guard/effect and conclusion |
| --- | --- |
| `initializeReservedBondNfts` | `B/DETFFundedBondTarget.sol:41-44,89-98` requires `msg.sender == fixed detf`, false reserved flag and next ID zero. No external account or preparer can impersonate the absent future contract. It mints roles only when the real parent calls during finalization. |
| `createFundedPosition` | Migration override requires fixed-parent caller, synchronization and activation; the common body additionally requires roles and actual funding. No early position exists. `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:20-25`; `B/DETFFundedBondTarget.sol:108-137`. |
| `createMigrationPosition` | Also fixed-parent-only, synchronized and locked. Only after actual pull/stake/gon verification does it mint, mark the position and call an NFT receiver. Early callers cannot reach that callback or start a 90-day clock. `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:28-42`. |
| Principal/reward/combined claims | All synchronize with the fixed parent before ledger mutation. The absent parent cannot complete the required contract call. Nonexistent/reserved-ID and owner/operator checks remain additional barriers. Rewards also require activation. `B/DETFFundedBondTarget.sol:53-55,158-211`; Migration target lines 72-78,89-110. |
| Three ERC721 transfers | The package deliberately replaces all three base transfers with synchronized Migration bond routes. There are no NFTs to convey; the absent-parent synchronization prevents any custody or callback effect. `B/DETFNFTVaultDFPkg.sol:85-94`; `B/DETFFundedBondTarget.sol:233-251`. |
| `transferHeldToken` | Fixed-parent-only and nonreentrant; it protects the parent token and live staking asset. A donor, registry caller or preparer acquires no sweep right. `B/DETFFundedBondTarget.sol:225-230`. |
| Public `donate`, Permit2 allowance and Permit2 signature donation | A positive amount first calls `_staking()`, which decodes the fixed parent's `rebasingClaimToken()` result; the absent parent cannot supply it. The live/disabled checks also precede `_pullDonate`. No token transfer, Permit2 use, approval, LP accounting or notify callback occurs early. Zero amount reverts separately. `B/DETFFundedBondTarget.sol:253-255,273-325,341-407`. |
| Parent-forwarded donation | Additionally requires the fixed parent caller and nonzero donor before the same donation body. It is not a public donor-spoofing route. `B/DETFFundedBondTarget.sol:285-302`. |
| `previewDonate` | Returns zero while the parent is absent, including for direct LP input; it does not make a deposit or reserve live. `B/DETFFundedBondTarget.sol:328-338,410-428`. |
| Token-specific `approve` | Requires the caller to equal the existing NFT owner. Before minting, that owner is zero, so an ordinary caller cannot approve future IDs 0/1/2/3. `C/tokens/ERC721/ERC721Repo.sol:281-290`. |
| `setApprovalForAll` | Can succeed early but writes only `operatorApprovals[msg.sender][operator]`. It cannot approve for the bond, fee recipient, creator or another future owner. An actual future owner can grant an operator its own future rights; that is ordinary ERC721 consent, not preparer authority. Do not require an empty approval mapping at finalization. `C/tokens/ERC721/ERC721Repo.sol:317-322`. |
| Metadata, ownership and position reads | Names and fixed configuration are available. This ERC721 `ownerOf` returns the stored zero for an unminted ID, rather than promising an ERC721 nonexistent-token revert. `positionOf`/`previewClaim` explicitly require existence; metadata calls those views. No read creates a position. `C/tokens/ERC721/ERC721Repo.sol:124-137`; `B/DETFFundedBondTarget.sol:140-150,257-260`; Migration metadata target lines 21-35. |
| Parent recovery/surrender routes | The parent is absent. After construction, surrender still checks idle children, live reserve, actual holder, accepted whole-NFT custody and unchanged position; exact `_fundBond` follows. Recovery remains current-owner-only with idle-child and source checks. Early bond registration adds neither an allocation nor a recovery capability. `M/UniswapV4DetfMigrationTarget.sol:64-114`; `M/UniswapV4DetfMigrationRepo.sol:62-72`; `M/UniswapV4DetfMigrationRecoveryTarget.sol:33-60`. |

Failed synchronization restores the transient phase/lock writes. Migration
bond synchronization explicitly locks around the parent call and restores
Idle only on completion; a revert cannot strand a busy bond
(`M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:89-117`).

### Unsolicited assets do not buy authority or veto completion

An external ERC20 can transfer tokens to the predicted address before code
exists or to the prepared bond afterward. That changes the external token's
balance ledger, not bond principal, attributed gons, NFT ownership or fixed
bindings. The initializer does not inspect balances and reserved-ID creation
does not inspect them. An unsolicited hook LP balance is protocol custody
under the existing LP model, not a purchased bond or a reserved role.

Do not add a `balanceOf(bond)==0` condition for LP, arbitrary ERC20s, native
balance or unrelated NFTs, and do not count them as funded principal.
Do not call arbitrary donated-token code while validating initial state.
The canonical fund path measures only the current pull and newly credited
staking gons, so an old surplus cannot substitute for future principal
(`B/DETFFundedBondTarget.sol:121-137`). The parent recovery ledger also
does not book unsolicited balances as recovered inventory
(`M/UniswapV4DetfMigrationRecoveryTarget.sol:62-80`).

There is no bond `onERC721Received` selector in the selected composition.
Safe NFT delivery cannot install a callback or binding; an unrelated
collection's unsafe transfer does not change the bond's own NFT ledger.
No new rescue, donation attribution or sweep policy is part of this split.

## 4. Exact reuse and initialization/callback safety

### Required reusable bond validator

Keep this validation in the already-admitted Migration package composition,
not in ordinary/common/Crane code and not in a new bond implementation.
Use one package-side read-only validator callable by the parent and by
preparation, with the expected selected package, canonical bond arguments
and predicted bond. It must independently check:

1. Nonempty bond code; exact callback-factory predicted address; exact
   `pkgOfAccount(bond)`; and equality of actual `pkgArgsOfAccount(bond)` to
   the canonical encoded bond arguments/hash bound to this construction.
2. Actual `detf()`, `lpToken()`, collection name and symbol match those
   arguments. Check the real registry membership/package association and
   the existing StandardVault LP-token/configuration identity.
3. Actual selected interfaces and selector ownership match the existing
   Migration bond package and factory base composition, with no temporary
   `postDeploy()` selector, initializer, diamond-cut or ownership setter.
   **Apply cuts in order:** the three transfer selectors must resolve to
   the Migration bond facet after the package's Replace cut, not to the
   ERC721 facet's earlier Add cut. A naive assertion that every historical
   cut still owns its selectors would reject every legitimate bond.
4. Zero `attributedBondGons()` and Idle accounting phase. Before reserved
   initialization require `reservedBondNftsWired()==false` and zero owners
   of IDs 0/1/2/3. At final completion require the flag true, IDs 0/1/2
   owned by bond/current fee recipient/creator-or-fee-recipient as before,
   ID 3 absent, and still zero attributed principal gons/Idle.

The deployed selected initializer and the complete exposed mint-path proof
establish there are no hidden purchased IDs before finalization; checking a
few owner slots alone would not establish that. Runtime witnesses must
also inspect the canonical next ID and position/aggregate storage without
injecting state: zero before finalization, three afterward, no funded
position or Migration marker. No new production getter is required solely
to inspect that proof.

Recompute canonical bond arguments from the actual initialized parent and
its actual factory arguments at final validation. Compare them to the
completed record, selected dependency, returned bond and parent pointer.
Retain all existing receipt/RT/SY validations. The current candidate only
checks bond address, accounting phase and reserved owners at this boundary;
those checks are not a substitute for the expanded bond reuse validation.

### Factory fast path is not initialization

`C/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-232`
returns an already coded address at lines 215-217 **before** processing,
update, initializer or post-deploy callbacks. That is why both preparation
and finalization must validate an existing bond explicitly. Keep genuine
registry traversal even when the child exists: registration and disable
checks remain authoritative and indexes use sets rather than minting rights.

Retain parent-helper reconciliation against the actual factory-recorded
full arguments (`M/UniswapV4DetfMigrationDFPkg.sol:130-141`). A different
hook payload sharing the historical parent prediction must not be reported
by that helper as the requested deployment. The unchanged direct
registry/factory existing-parent fast path is not fresh construction or
fresh full-payload validation; it must not rewrite argument records,
reinitialize children or restore removed selectors.

### Direct initializer calls do not reach the prepared child

The common bond package's public `initAccount` is not SELF/caller-guarded.
Do not falsely report that every direct call to it necessarily reverts:
the first call can initialize the package's own storage. It cannot modify
the package's immutable selected facets/registry/oracle or the separate
prepared proxy, and package metadata/deployment declarations use those
immutables and pure methods rather than the package-local bond ledger.
Repeated bond-ledger initialization reverts atomically at the existing
one-time guard.

The bond proxy does not install `initAccount`, factory `initAccount`,
package `updatePkg`, or package `postDeploy(address)`. Calls on a package,
facet, factory or an attacker's delegatecall context do not execute in the
bond proxy's storage. This is a reachability proof for this child, not a
claim that every unrelated public factory method is universally harmless.
No new global factory change is needed or admitted.

### Temporary-hook and reentrancy windows

The temporary factory hook delegates to its caller
(`C/factories/diamondPkg/PostDeployAccountHookFacet.sol:19-22`);
retaining it across preparation would be unacceptable. Actual bond
initialization only writes fixed metadata/configuration/ledger fields.
Selected facet/configuration queries are reads, the existing bond package's
post-deploy is pure, and no asset transfer or NFT mint occurs. There is
no user-controlled nonstatic callback between bond creation and factory
hook removal. The factory removes that selector before the bond returns to
the registry (`DiamondPackageCallBackFactory.sol:230-231,425-451`).

Extend the existing `preparing` guard over the bond deployment and every
subsequent child call. A partial record remains `completed=false`; a
reentrant fresh-parent attempt therefore fails preparation admission.
All construction-time external argument/configuration reads remain static;
do not introduce arbitrary external call data or a preparation callback.
After successful preparation, the bond has no temporary hook to exploit.

In finalization, unchanged reserved-ID creation uses `_mint`, not a safe
mint: `C/tokens/ERC721/ERC721Repo.sol:407-415` writes ownership and emits
the transfer without receiver callbacks. The fee-recipient query is a
read. The public parent wiring entry does not accept a caller-selected
recipient or child; it derives the same fixed package/metadata/hook and
rejects an already wired parent (`U/UniswapV4DetfTarget.sol:812-833`).
Preserve all existing parent callback guards and hook removal. Exercise
reentrancy at both transaction boundaries in G5; atomic rollback by itself
is not a substitute for this call-graph analysis.

## 5. No reservation poisoning and both rollback/retry windows

### Changed hook, same historical parent prediction

A different valid actual hook yields a different full construction ID and
a different canonical bond LP argument. That yields a different bond and
receipt, and consequently different SY argument hashes/addresses. Neither
preparation may overwrite the other or reserve the parent address
exclusively. Preparing one full payload cannot prevent preparing/finalizing
the other while the parent is absent.

An already correctly deployed bond for the same payload must be reusable.
A wrong parent, hook, metadata or package yields another predicted bond;
it must never be substituted. Neither the caller nor the record chooses
arbitrary bond addresses.

The existing permissionless parent helper and hook-clearing salt permit
the first valid final construction to occupy the shared parent address.
This review does not invent an owner-signature rule to eliminate that
pre-existing competition. After a parent exists, preparation rejects it,
and mismatching helper reuse rejects the requested payload. Unused
alternative children confer no principal or rights against the winning
parent: parent-only funding and initialization cannot be requested from
the parent for an arbitrary alternative child.

### Preparation transaction rollback

Failure in bond deployment/registration/validation, raw-SY construction,
staking-SY construction, final child validation, or completion publication
must revert the entire preparation transaction: all newly created children,
factory/registry entries, incomplete record, SY authorization entries and
the preparation lock.

If the exact bond existed before this transaction, failure cannot erase
that prior state. It remains fixed and unreserved, including prior
unsolicited balances and caller-owned approvals; the preparation record
and newly created SYs still roll back. Retry must accept this exact
existing bond. Test both fresh-bond and independently predeployed-bond
failure cases, not only failure after a newly created first SY.

### Final transaction rollback

Failure during reserved-ID wiring, receipt/RT construction, reciprocal
checks, hook removal or parent registry publication must leave no parent,
no partial parent registration and no newly created receipt/RT. It must
also roll back mutations to the **already committed** bond: reserved flag
false, next ID zero, no owners/positions/gons, same fixed configuration and
Idle phase. Previously committed bond/SYs and the completed preparation
remain available, with prior balances/approvals unchanged.

An exact retry can therefore initialize reserved IDs once and complete
the same intended parent. Do not mark preparation consumed or permanently
failed merely because a final transaction reverted. Package disable
failures remain real: they must roll back in the relevant window, and
retry after authorized re-enablement must use the same immutable payload.
Preserving existing registry governance is not a new preparer veto.

## 6. Carry-forward of C1-C6 and G1-G8

The initial independent design report remains binding except for the
explicit relocation of registered bond construction. This table identifies
the narrow amendment; it does not discard any initial requirement.

| Constraint | Retained requirement and bond-specific extension |
| --- | --- |
| C1 | Same parent salt and complete canonical arguments; full chain/package/actual-hook commitment; permissionless preparation for explicit owner; no parent-only reservation. |
| C2 | Same five-child derivation and exact metadata/ordered routes. Canonical bond arguments now drive both early registered deployment and final reuse proof. Receipt/RT identities and initializer rules do not change. |
| C3 | Same registered Migration-SY package, SELF-held records, authenticated parent dependency, immutable exact child authorizations and one-time initialization guards. Completion now means the bond and both SYs have finished and validated; lock covers all three. |
| C4 | Same fully initialized zero-supply SY behavior and narrowly scoped pre-parent identity proof. No common receipt or SY initializer relaxation. Extend intermediate safety to the fully initialized, unreserved, unfunded bond. |
| C5 | Amend only “bond construction remains final.” Registered bond construction moves to preparation; registered reuse, reserved IDs, receipt/RT construction, all reciprocal checks, hook removal and parent publication remain final and atomic. |
| C6 | Same factory fast-path reconciliation and callback restrictions, extended to exact bond reuse and preexisting-bond adoption. No initializer or hook may be restored after activation. |

| Gate | Required corrected evidence, not claimed here |
| --- | --- |
| G1 | First fresh instance: real CREATE3/manager packages and actual status-1 bond-plus-SY preparation/final receipts, each envelope at most 32,000,000. Include newly required infrastructure, current bytecode and complete calldata. |
| G2 | Second distinct initial owner, parent, actual hook and five children using shared global infrastructure; repeat every bounded transaction. No existing-parent fast path as the second-instance witness. |
| G3 | Retain all owner/package/chain/hook/parent/receipt/metadata/mode/route/canonical-byte negatives. Add wrong bond LP/package/hash, exact independently predeployed bond adoption, both hook-payload preparation orders and final helper mismatch reconciliation. |
| G4 | Parent discovery/code absent; bond and both SYs fully bound and hook-free. Bond roles/positions/gons absent, SY supply/backing zero and all phases Idle. Execute every exposed early money/claim/transfer/donation variant, approvals, unsolicited assets, direct initialization and callback negatives; then prove legitimate finalization still succeeds. Do not expect `setApprovalForAll` to revert. |
| G5 | Execute both rollback windows above, including failure after bond creation and before preparation completion, failure after reserved minting and during final publication, exact retries, reentrancy and package disable/re-enable. Cover a bond that predates the failed preparation as well as a fresh bond. |
| G6 | Retain complete parent/child factory arguments, registry indexes, loupe routing, interfaces, metadata, decimals, owner/hook, five reciprocal links and Idle/zero accounting. Add bond pre/post-role state and ordered Add/Replace selector resolution. |
| G7 | Retain funding/genesis, frozen capture, configuration without issuance, fresh exact-funded independent/NFT bonds, Stage 1 negatives, mature principal, late surrender's fresh clock, owner transfer, irreversible activation, custody/recovery and selector-restoration negatives through package/factory/callback routes. No preparation timestamp becomes a position or reward clock. |
| G8 | Preserve old adverse evidence; bind corrected receipts to final source/Solar artifacts/populated runtimes; run affected Migration specs/forks artifact-first and independently replay the correction. Retain cleanup receipts, other worktrees/port 18560 and warm caches. |

The already failing bounded regression must pass because the implementation
fits, not because the envelope or assertions were weakened. Retain actual
code-size enforcement, simulation, all selected facets/children and every
registry index. If either corrected bounded transaction fails, the gas
correction remains `needs-fix`; this admission does not permit a further
split, weaker validation or changed economics without reassessment.

## 7. Exact permitted implementation paths

Only these existing admitted construction paths are needed/allowed for
the correction. This report itself edits none of them.

| Exact worktree-relative path | Bounded change |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | Extend interface-owned construction result with canonical bond arguments; document bond-plus-SY preparation while retaining canonical parent arguments and package-only API. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | Require completed bond-plus-SY commitment; rederive/validate prepared bond before unchanged final wiring and validate final bond/child state before publication; retain existing-parent reconciliation. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSYDFPkg.sol` | Add selected bond package/hash to the immutable preparation record and a typed read-only bond validation query as needed by the parent. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/UniswapV4DetfMigrationSYDFPkg.sol` | Single canonical bond derivation, lock-scoped registered bond deployment/adoption, exact reuse validation and completion only after all three prepared children validate. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol` | Only wiring/artifact construction changes needed by those package schemas; keep existing bond package and real CREATE3/manager registration. No new authority or factory. Current dependency schema may need no edit. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol` | Real fixture preparation and expected initial-state evidence for the expanded construction; keep existing lifecycle behavior. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` | Preserve the failing bounded regression and direct-registry negative; add the bond-specific binding, intermediate-state, rollback and lifecycle obligations using real instances. |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` | Add the previously unimplemented dedicated pinned construction proof, including first/second instance and initial bond state. |
| `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasLocalQA.s.sol` | Dedicated local corrected construction witness with individually bounded preparation/final transactions and exact state/receipt evidence. |

Subsequent implementation/independent runtime evidence must use their
separately assigned owned evidence directories, not rewrite the existing
diagnosis, initial design, implementation or verification reports/receipts.
This assessment's sole write is
`docs/incidents/2026-09-16-dtf-recovery/migration/deployment-gas/bond-design-verification/report.md`.

No existing bond package, bond facet/target/repo, receipt/RT economic
implementation, ordinary/common/Crane source, operator TypeScript,
configuration or dependency change is necessary or admitted. Do not broaden
the edit set to introduce a preparer registry, generic executor, staged
parent, new setter, donation veto or owner-signature requirement.

## 8. Decision and limits

**Decision settled:** deterministic, fully initialized but unreserved and
unfunded existing bond construction can move into the same atomic
preparation as the two SYs without changing ownership or economic policy.
Its fixed-parent gates, absent live dependencies and exact reuse checks
are sufficient for this bounded design. No early-bond authority/economic
path remains an unresolved design blocker in the specified construction.

Rejected alternatives are the already insufficient bond-only split; a
direct-factory/script-only shortcut without full-ID completion; rejecting
an exact permissionless predeployment; early reserved-ID creation; relaxed
common receipt initialization; and treating arithmetic/estimates as gas
acceptance.

Assumptions are the existing accepted factory/package implementations and
configured dependency contracts, canonical cryptographic address domains,
and ordinary EVM transaction rollback. This is not a new guarantee against
replacement of shared infrastructure or existing registry governance.
No trust is assigned to the preparer's identity. Arbitrary donor balances
and caller-owned operator approvals are explicitly permitted intermediate
state, not an assumption that they remain empty.

No production edits, source commit, merge, public operation, test/build,
new chain transaction, owned node, impersonation, listener, subscription
or child task occurred here. No owned runtime remains. Source reasoning and
retained current traces support this design verdict; the corrected runtime
and complete G1-G8 results remain the implementation and independent
verification obligations.

All original full-plan/category limits remain open, including E2
attribution, unsupported recovery/surrender categories, original allocation
and funding provenance, complete E1-E5/tasks 9-10/invariants/F1-F4 and
release. This report closes only the requested additional bond-split
assessment.

**Final disposition: admitted for this exact construction and edit
boundary; the preserved two-SY implementation remains needs-fix, and
corrected bounded deployment success is not yet established.**
