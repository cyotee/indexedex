# Migration core shared interface contract

Date: 2026-11-10.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Branch: `work/dtf-migration-phase-04`.
Base: `6e27ecaa242c4acca132e3575a160514aad07b11`.

**Delivered: six actual Solidity interface files, nine interface declarations.**
These are the source contract consumed by the component lanes, not an
implementation of their behavior or a runtime acceptance claim.

Authority is the current phase04 implementation instruction and complete
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase04-core-brief.md`,
the complete original Migration implementation plan, and accepted
`migration/package/egress-contract-r3.md` plus
`egress-r3-verification.md` in phase03. The complete ownership/bootstrap
reports and implementation handoff were also read. R3 supersedes r1/r2.
The current-owner-only genesis decision supersedes the old handoff's
BOOTSTRAP-AUTH question; it is not reopened here.

## 1. Exact files and declaration ownership

Prefixes below are repository-relative in this worktree:

- `M/`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `C/`: `contracts/vaults/detf/common/`
- `D/`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- `K/`: `lib/crane/contracts/`
- `TM/`: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`

| New file, owned exclusively by this interface node | Declarations |
| --- | --- |
| `M/interfaces/IUniswapV4DetfMigration.sol` | `IUniswapV4DetfMigrationAccounting`, permanent `IUniswapV4DetfMigration`, removable `IUniswapV4DetfMigrationAllocation` |
| `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | `IUniswapV4DetfMigrationDFPkg`, parent `PkgInit` and `PkgArgs` |
| `M/claimToken/IUniswapV4DetfMigrationStakedDETF.sol` | `IUniswapV4DetfMigrationStakedDETF` |
| `M/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol` | `IUniswapV4DetfMigrationBondNFTVault` |
| `M/sy/IUniswapV4DetfMigrationSY.sol` | `IUniswapV4DetfMigrationSY` |
| `M/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol` | `IUniswapV4DetfMigrationRewardToken`, `IUniswapV4DetfMigrationRewardTokenDFPkg`, RT `PkgInit` and `PkgArgs` |

This report is the seventh authored file. No implementation, storage repo,
test, factory, config, shared dependency or existing production file was
edited. The verified `M/interfaces/IUniswapV4DetfMigrationSnapshot.sol`,
`M/UniswapV4DetfMigrationSnapshotLib.sol` and snapshot TestBase remain
read-only. No duplicate snapshot types or quote evaluator were introduced.

## 2. Package argument contract

### Parent

`IUniswapV4DetfMigrationDFPkg.PkgArgs`, in ABI field order:

```solidity
IUniswapV4Detf.PkgArgs baseArgs;
address owner;
uint256 ownershipBufferPeriod;
address weth;
address originalDtf;
```

The entire existing base argument struct is reused without changing its
metadata, hook, policies, child metadata or four route tables. WETH and
original DTF are nonzero distinct composition bindings. They are not prices,
caller-supplied snapshot sources, or post-deployment settings.
`Source.subject` is the parent proxy and `Source.feeOracle` is the package's
installed oracle. Native ETH uses the snapshot's existing zero-address
contribution identity and is adapted through the configured WETH.

Canonical encoding includes all fields. For prediction, clear **only**
`baseArgs.hook` in the salt copy and hash `abi.encode(copy)`. Owner, buffer,
WETH, original DTF, all base policies and routes remain in the salt.
Ownable initialization must remain in the once-guarded proxy initialization.
Crane acceptance is not given a new buffer delay.

`IUniswapV4DetfMigrationDFPkg.PkgInit`, in ABI field order:

```solidity
IUniswapV4DetfDFPkg.PkgInit baseInit;
IFacet ownableFacet;
IFacet migrationFacet;
IFacet allocationFacet;
IUniswapV4DetfMigrationRewardTokenDFPkg rewardTokenPkg;
```

`baseInit` is the actual existing common constructor dependency schema, not
a duplicated list. Its `productFacets` order remains exchange, bond,
maintenance, claim/wiring, query. Supply Migration implementations wherever
R3 requires changed policy, including receipt/SY packages selected with the
real Migration facets. Its bond package's existing nominal V4 interface is
ABI-compatible with the common registered funded-bond deployment API.
No ordinary child is an acceptable temporary binding.

`migrationFacet` owns the new permanent donation/query methods below;
`allocationFacet` owns exactly the five new removable administration methods.
The base query facet retains the compatible ordinary queries. Do not install
the same selector from both query facets.

Parent package helper:

```solidity
function deployVault(PkgArgs memory args_) external returns (address vault_);
```

It uses the real registry, not a direct generic factory bypass.

### Existing bond, receipt and two-SY packages

Reuse these **unchanged types and helper signatures**, rather than defining
Migration copies:

| Child | Constructor/instance schema | Existing deployment helper |
| --- | --- | --- |
| Bond | `C/bondNft/IDETFNFTVaultDFPkg.sol` `PkgInit`/`PkgArgs`; V4 alias is `IUniswapV4DetfBondNFTVaultDFPkg` | `deployVault(string,string,IDetf,IERC20) returns(address)` |
| Receipt | `C/claimToken/IRebasingClaimTokenDFPkg.sol` `PkgInit`/`PkgArgs` | `deployToken(IDetf,IDETFNFTVault,IVaultFeeOracleQuery,string,string) returns(address)` |
| Raw/staking SY | `C/sy/IDETFSYDFPkg.sol` `PkgInit`/`PkgArgs` | `deployVault(IDETFSYDFPkg.PkgArgs) returns(address)` |

The receipt constructor's historical `IDETFNFTVault` reference is retained
for ABI compatibility; it does **not** make the historical LP-position ABI
the funded bond's public interface. The new bond extends `IDetfBondNFT` and
therefore reuses `DETFFundedStakingMath.BondPosition` and `BondClaim`.

Bond and SY packages remain registered. Receipt remains a generic
callback-factory package. `DETFSYDeploymentLib` already supplies both
`isStaking` modes, metadata, and the parent's directional routes.
Component owners make the brief-authorized narrow package declaration
changes so installed Migration interfaces are actually advertised.

### RT

The RT package is declared in the same owned file as its token interface.

```solidity
// IUniswapV4DetfMigrationRewardTokenDFPkg.PkgInit
IFacet rewardTokenFacet;
IDiamondPackageCallBackFactory diamondFactory;

// IUniswapV4DetfMigrationRewardTokenDFPkg.PkgArgs
address parent;
address receipt;
string name;
string symbol;

function deployToken(PkgArgs memory args_) external returns (address token_);
```

One selected facet supplies the guarded ERC20, metadata and RT methods.
The generic package uses the existing callback factory. Parent metadata
supplies derived RT metadata; decimals `27` and quantum `1e18` are fixed,
not deployment knobs. Bind the already-wired parent/receipt reciprocally,
then store RT once on the parent before either SY deployment. There is no
predicted circular child address, mutable minter, added protocol factory,
permit requirement for RT, or third-party registration.

## 3. Permanent parent, types and removable administration

The parent interface extends the existing `IUniswapV4Detf`,
`IDETFStandardizedYield`, `IDETFStakingPreview`, `IDETFFundedRewards` and
`IMultiStepOwnable`. Their signatures are reused, not redeclared.

New permanent methods, with return types:

```solidity
migrationActivated() -> bool
migrationSyRewardToken() -> address
migrationSnapshotSource() -> IUniswapV4DetfMigrationSnapshot.Source
migrationSnapshot() -> IUniswapV4DetfMigrationSnapshot.Snapshot
previewOriginalCredit(uint256 originalEth, uint256 originalDtf) -> uint256
independentAllocation(address recipient) -> IndependentAllocation
independentIssuance(address recipient) -> IndependentIssuance
migrationDonationInventory(IERC20 token) -> uint256
migrationBootstrapSelfMinted() -> uint256
donateMigrationCapital(
    IERC20[] tokens, uint256[] amounts, uint256 nativeAmount,
    uint256 minLpOut, uint256 deadline
) payable -> uint256 lpOut
```

All methods except `donateMigrationCapital` above are `external view`.
The source files contain exact Solidity parameter locations and names;
the arrows here denote ABI returns, not executable Solidity.

Interface-owned structs, in field order:

| Type | Fields |
| --- | --- |
| `OriginalEntitlement` | `bytes32 entitlementId, uint256 originalEth, uint256 originalDtf, bytes32 evidenceId` |
| `IndependentAllocationInput` | `address recipient, bytes32 evidenceId, OriginalEntitlement[] entitlements` |
| `QuotedOriginalEntitlement` | `OriginalEntitlement original, uint256 credit` |
| `IndependentAllocation` | `bytes32 configurationId, bytes32 evidenceId, QuotedOriginalEntitlement[] entitlements, uint256 totalCredit` |
| `IndependentIssuanceRequest` | `address recipient, bytes32 configurationId` |
| `IndependentIssuance` | `bool issued, bytes32 configurationId, uint256 credit, uint256 bondTokenId, uint256 issuedAt` |
| `GenesisLeg` | `IERC20 token, uint256 amount, uint256 minSharesOut` |

Configuration identity is exactly
`keccak256(abi.encode(block.chainid, address(this), snapshot.id, input))`,
where `input` is the whole `IndependentAllocationInput`, retaining its
array order. Identical input replay preserves identity. Original ETH/DTF
inputs are native 18-decimal quantities; all credits are native nine-decimal
user DETF. For each original, call the existing snapshot
`evaluateOriginals(snapshot, originalEth, originalDtf)` separately, then sum.
Never quote consolidated contribution amounts or mutate the book between
components/recipients.

The original IDs/evidence hashes identify verified independent inputs;
they are not a new E2 proof scheme or permission to overlap held exposure.
Distinct originals must not be counted twice. Full replacement remains
allowed after issuance, but the immutable execution record, bond, and
once-only recipient issuance do not change. An issued record never becomes
a top-up request. No `credit` field exists in the configuration input.

The separate `IUniswapV4DetfMigrationAllocation` declares only:

```solidity
bootstrapMigrationReserve(GenesisLeg[] legs, uint256 anchorIndex,
    uint256 minLpOut, uint256 deadline) -> (uint256 selfMinted, uint256 lpOut)
captureMigrationSnapshot() -> bytes32 snapshotId
configureIndependentAllocations(IndependentAllocationInput[] allocations)
issueIndependentAllocations(IndependentIssuanceRequest[] requests)
    -> uint256[] bondTokenIds
activateMigration()
```

Each is `external`, current-owner-only and Stage-1-only. Arrays are calldata.
Genesis consumes only booked amounts, selects one representation per
external leg, derives self mint from the consumed anchor and fixed opening
policy, and sends LP to the fixed bond child. Permissionless donations
cannot choose pooled genesis. Configuration and execution batches are
whole-transaction atomic; execution checks the selected configuration
identity, refuses repeats/zero credit, and returns bond IDs in input order.

Activation removes all five installed selectors, including genesis,
capture and activation itself, using their actual owning facets. Permanent
queries and Ownable survive. No source loader, surrender/harvest placeholder,
price setter, `fundingComplete`, or configuration-finalization API is defined.

## 4. Exact R3 child signatures

All four child interfaces inherit:

```solidity
function migrationAccountingPhase() external view returns (uint8);
```

`IUniswapV4DetfMigrationAccounting.AccountingPhase` ordinals are fixed:
`Idle=0, Synchronizing=1, Acquiring=2, Accounting=3, Paying=4`.
Both SY instances implement this handshake, so activation checks five
children: bond, receipt, raw SY, staking SY, RT. It is a query, not a setter.

### Receipt

Extends `IStakedDETF` and the accounting handshake. Existing ERC20,
`stakingState`, `gonsOf`, `previewDistributions`, funding, retirement,
SE exact-in/exact-out and preview APIs remain canonical. Existing package
ERC2612/EIP712 facets remain separate from this product interface.

```solidity
egressState(address account) view -> (
    uint256 physicalGons, uint256 liquidBasis, uint256 latentGons,
    uint256 walletGons, uint256 roleGons, uint256 syGons, uint256 maxUnstake)
checkpointRewards() -> uint256 movedGons
deferredRewardGons(uint8 domain, address beneficiary) view -> uint256
tokenizedSyRewardGons() view -> uint256
claimDeferredRewards(uint8 domain) -> uint256 nativePaid
claimDeferredRoleRewards(address beneficiary) -> uint256 nativePaid
transferDeferredRewardRights(uint8 domain, address to, uint256 gons)
deliverBondClaim(address recipient, uint256 principal, uint256 reward, uint256 expectedK)
deferSyRewards(address beneficiary, uint256 gons, uint256 expectedK)
transferSyPrincipal(address recipient, uint256 principal, uint256 expectedK)
withdrawSyPrincipal(address recipient, uint256 principal, uint256 expectedK)
issueSyRewardTokens(address beneficiary, uint256 expectedK) -> uint256 nativeRT
paySyRewardRemainder(address beneficiary, uint256 expectedK) -> uint256 nativeSDETF
redeemSyRewardTokens(address owner, address receiver, uint256 nativeRT, uint256 minNative)
    -> (uint256 nativeSDETF, uint256 retainedGons)
```

Every method is external. Domain parameters remain `uint8`, exactly R3:
Wallet/R0=0, Role/R1=1, SY/R2=2. Native deferred release accepts 0/1;
rights assignment accepts 0/2 by the actual owner, never by native allowance.
R1's allocation-time beneficiary is immutable. Role release has a fixed
beneficiary, not a redirection argument.

`deliverBondClaim` is wired-bond-only. The four SY custody/payment methods
and `issueSyRewardTokens` are wired-staking-SY-only.
`redeemSyRewardTokens` is fixed-RT-only and **synchronizes itself**.
Every pinned-k method checks current k plus physical coverage and actual
post-debit attribution; a declared amount is not a credit source.
Protected custodians have no generic public spend authority.

### Bond

Extends `IDetfBondNFT`, `IDetfNftReserveDonation` and accounting:

```solidity
createMigrationPosition(uint256 principal, address recipient) -> uint256 tokenId
isMigrationPosition(uint256 tokenId) view -> bool
attributedBondGons() view -> uint256
```

The genuine fixed parent creates a fresh exact-funded 90-day cliff, with
actual creation time. No duration/old timestamp is accepted. Ordinary
`createFundedPosition` retains its original ABI and unmarked linear terms.
Use the inherited canonical `BondPosition`/`BondClaim`; do not copy their
fields into Migration types. Metadata reads the marker and parent gate.
All three ERC721 transfer signatures still route through guarded bond code.

### Both SYs

Extends the complete unchanged `IStandardizedYield` and accounting:

```solidity
claimRewardRemainder() -> uint256 nativeSDETF
attributedSyGons() view -> uint256
```

In particular retain `deposit(address,address,uint256,uint256)` payable and
`redeem(address,uint256,address,uint256,bool)` without a ticket, source-owner
argument, router whitelist or `redeemInternal` replacement. `false` burns
caller shares, `true` burns issued shares actually held at SY.

Staking SY settles each affected old holder before a share mutation and
represents native principal at rate `1e18`. `attributedSyGons` is common
`backingGons`, not another balance ledger. Direct DETF/sDETF principal
previews are 1:1; other routes retain real parent quote/budget semantics.
Raw SY remains raw-backed, with empty reward arrays and no automatic receipt
route. Its attributed staking gons are zero and its active remainder payout
is zero because it has no R2.

### RT

Extends canonical `IERC20Metadata` (which inherits ERC20) and accounting:

```solidity
mintByReceipt(address beneficiary, uint256 amount)
burnByReceipt(address owner, uint256 amount)
redeem(uint256 amount, address receiver, uint256 minimum)
    -> (uint256 nativeSDETF, uint256 retainedGons)
previewRedeem(uint256 amount) view -> uint256 nativeSDETF
receipt() view -> address
parent() view -> address
```

Mint/burn are fixed-receipt-only. Redemption binds `owner` to the RT caller,
not a caller-chosen argument. Preview uses stored funded k; synchronization
can change the executed value, whose actual output must meet minimum.

### Units and storage authorities

`Q=1e36`, `W=q=1e18`, `1<=k<=Q`. DETF, receipt and both SYs are nine
decimals. RT is 27 decimals and one native RT represents q exact gons.
R3's index is `1+Q-k`, initially 1, in WAD-scaled native RT per native SY.
Standard staking-SY reward arrays/events contain native RT, not sDETF.
Stage-1 RT supply and newly delivered reward receipts remain zero.

| Owner | Authoritative units/state |
| --- | --- |
| Existing funded receipt repo | Physical `G`, total `T`, k, backing B, allocation/staking dust, standing fee/creator weights |
| New receipt namespace | Native liquid basis P; exact-gon R0/R1/R2 and aggregate, tokenized E, protocol self-held U, phase |
| Existing funded bond repo | Native principal/claimed principal, attributed gons, start/duration and aggregate |
| New bond namespace | Cliff marker and phase, not duplicate positions |
| Existing SY/ERC20 repos | Actual shares and common backingGons A; rawBacking for raw mode |
| New SY namespace | Per-account lastK and phase only; no tickets or duplicate shares |
| RT/ERC20 plus new RT namespace | Canonical native token supply/balances; fixed parent/receipt and phase |
| Parent/Crane repos | Existing base routes/reserve/child state and Crane owner; Migration activation, RT pointer, frozen book, donation budget/self mint, separate configuration/execution |

`E=q*RT.totalSupply()` is already part of escrow's physical gons and T.
`deferSyRewards(SY,...)` credits U, not a public beneficiary; U is neither
rounding dust nor sweepable inventory. R2 tokenization retains `R2%q`;
the native remainder extension spends only that modulus. RT redemption
retains unpaid gons in the actual RT owner's R0. Canonical own-account and
fully-paid-position retirement remains narrowly admitted; it never erases
an arbitrary pooled fraction or RT quantum remainder.

Events in the owned sources distinguish native DETF/sDETF/RT from gons:
receipt custody events carry source/beneficiary/domain/gons/k, tokenization
and remainder events name their native unit, retirement reports the native
staking-dust increase, and configuration/issuance events bind immutable
identities and actual bond IDs. Existing standard events remain inherited.

## 5. Component call graph and admission

```text
authorized manager owner/operator
  -> registry.deployPkg(artifact bytecode, abi.encode(PkgInit), release salt)
  -> registered parentPkg.deployVault(Migration PkgArgs)
  -> registry.deployVault -> generic callback factory -> once-only parent init
  -> parent postDeploy context:
       common-compatible registered Migration bond
       -> selected generic funded receipt
       -> generic RT(parent, receipt, metadata), store fixed RT once
       -> selected registered raw SY and staking SY
       -> validate reciprocal identities -> remove temporary hook

current owner -> capture -> configure originals (no mint)
current owner -> issueIndependentAllocations(current identities)
  -> parent settlement before new participation
  -> mint stored native credit, approve exact principal
  -> bond.createMigrationPosition -> exact pull/stake/delta -> fresh cliff
  -> clear parent approval, commit immutable issuance atomically

bond claim -> synchronize parent -> validate clock/authority/gate
  -> debit position and aggregate
  -> receipt.deliverBondClaim(expectedK)
  -> receipt reads bond.attributedBondGons -> physical coverage -> delivery
  -> canonical final-position retirement when applicable

staking SY mutation -> synchronize parent -> checkpoint old holder
  -> debit common backingGons -> receipt.deferSyRewards(holder,gons,k)
  -> R2 escrow (or U for self) -> change principal shares
staking SY redeem -> burn selected source/debit A
  -> receipt.transferSyPrincipal OR withdrawSyPrincipal
  -> optional exact-budget parent exchange -> final minimum/approval cleanup
staking SY claim -> checkpoint -> receipt.issueSyRewardTokens
  -> activation gate -> R2 to E -> RT.mintByReceipt -> native RT return/event
staking SY remainder -> checkpoint -> receipt.paySyRewardRemainder
  -> activation gate -> native sDETF from R2%q, remainder retained

RT.redeem(actual caller, receiver)
  -> receipt.redeemSyRewardTokens -> synchronize parent -> activation/k
  -> RT.burnByReceipt during admitted busy phase
  -> verify E against actual post-burn supply
  -> receipt payment to receiver, retained gons to actual caller R0

current owner -> all five child phases Idle -> parent lock
  -> actual-owning-facet Remove cuts for entire allocation interface
  -> finalize activation without an intervening external callback
```

Receipt synchronization must save/restore Synchronizing across genuine
parent reward-funding callbacks. Parent's locked synchronization no-op
remains bond/receipt-only, never generic SY/RT/router admission.
Parent recognizes only a fixed child's matching phase/callback.
Bond safe receiver callbacks precede ownership mutation in actual Crane;
the guard must cover that order. Preserve the existing bond-first donation
cycle rather than pre-locking its parent forwarding facade.

Parent-composed receipt exit remains exact user-to-parent receipt pull,
exact unstake, optional actual output route. It does not use SY internal
redemption or spend the parent's whole pre-existing balance. An atomic SY
router uses its returned/delta principal budget, not `balanceOf(SY)`.

## 6. Source compatibility checks

The following source was read in this worktree. New consumers listed here
are the downstream implementation contract, not claims of already-present
runtime implementations.

| Declared surface | Actual production source checked and downstream consumer |
| --- | --- |
| Parent base args/dependencies/helper | `D/interfaces/IUniswapV4Detf.sol:32-55,185-200`; `D/UniswapV4DetfDFPkg.sol:53-102,197-247`; `D/UniswapV4DetfInitializationLib.sol:23-96`. Parent package/factory consumes nested base schemas without a tuple rewrite. |
| Registry/generic distinction | `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:44-76,141-165`; `D/UniswapV4Detf_Pkg_FactoryService.sol:16-32`; `K/factories/diamondPkg/IDiamondFactoryPackage.sol`; `K/interfaces/IDiamondPackageCallBackFactory.sol`. Parent/bond/SY registration and generic receipt/RT remain distinct. |
| Ownership | `K/access/ERC8023/IMultiStepOwnable.sol`; `MultiStepOwnableRepo.sol:83-98,108-122,253-274`. Owner is canonical Crane storage; acceptance has no newly inferred delay. |
| Snapshot source/query/original preview/configuration | Existing `M/interfaces/IUniswapV4DetfMigrationSnapshot.sol`; `M/UniswapV4DetfMigrationSnapshotLib.sol:28-67,127-174`. Allocation target supplies fixed source, stores one book, quotes originals separately. No route enum/hash substitutes for admission. |
| Independent configuration/issuance and genesis/donation reads | Original Plan sections 5.1-5.3 and 6; phase04 brief; accepted R3 section 1; bootstrap handoff as superseded on owner authority. Parent allocation/repo/retained target consume these real core types. No existing legacy-source consumer is invented. |
| Parent receipt composition | `D/UniswapV4DetfTarget.sol:344-374,410-477,810-849`; `D/UniswapV4DetfMaintenanceTarget.sol:16-27`. Policy facets preserve exact packets and actual child getters. |
| Receipt public/typed methods | `contracts/interfaces/IStakedDETF.sol`; `C/claimToken/StakedDETFTarget.sol:41-80,147-246`; `C/claimToken/RebasingClaimTokenFacet.sol:23-56`; accepted R3 sections 2,3,6,7. Receipt target consumes existing funded types; bond/SY/RT use the exact new typed calls. |
| Bond creation/marker/attribution | `contracts/interfaces/IDetfBondNFT.sol:10-41`; `C/bondNft/DETFFundedBondTarget.sol:94-208`; `C/bondNft/DETFFundedBondRepo.sol:13-18,46-56`; `C/bondNft/DETFNFTVaultFacet.sol:17-46`. Genuine parent issuance and receipt post-effects coverage consume these methods; marker also feeds metadata. |
| Bond package/transfer cut | `C/bondNft/IDETFNFTVaultDFPkg.sol`; `C/bondNft/DETFNFTVaultDFPkg.sol:38-53,68-93`. Existing common constructor and three guarded Replace cuts remain required. |
| Receipt package | `C/claimToken/IRebasingClaimTokenDFPkg.sol`; `C/claimToken/RebasingClaimTokenDFPkg.sol:39-59,76-108,137-149`. Selected Migration facet, same funding identities and generic deploy API. |
| SY standard ABI/extensions | `K/protocols/perps/pendle/interfaces/IStandardizedYield.sol:62-172`; `C/sy/DETFSYTarget.sol:65-180,196-242`; `C/sy/DETFSYRepo.sol:15-23,38-69`; `C/sy/DETFSYFacet.sol:17-59`. Actual standard callers keep deposit/redeem/reward signatures; receipt consumes post-debit A. |
| SY package/routes | `C/sy/IDETFSYDFPkg.sol`; `C/sy/DETFSYDFPkg.sol:33-51,66-74,99-117`; `C/sy/DETFSYDeploymentLib.sol:15-27`. Same schema deploys two wrappers; no new wrapper framework. |
| RT methods/bindings/phase | Accepted R3 sections 5-7; canonical `K/tokens/ERC20/IERC20Metadata.sol`; generic package interfaces above. RT target and receipt are reciprocal new consumers. No existing RT implementation is falsely claimed. |
| Accounting phases | Exact R3 section 7 order; current common synchronization, SY acquisition/payment, parent callback exemption above. Each child target exposes uint8; parent activation and fixed custody callers consume it. |

Additional checks actually performed:

- Read `.git` pointer, worktree `HEAD` and branch ref: exact branch/base above.
  No Git command or write was used.
- Initial Migration inventory contained only the verified snapshot library,
  interface and TestBase. No pre-existing shared interface file was overwritten.
- Source-level signature comparison found **all 26 R3 section 6 methods**
  with their exact names and parameter types, each declared once. Return
  tuples and mutability were also inspected against R3.
- All **23 direct imports** in the six new files resolved to existing files.
- All six files contain interface declarations only, with no implementation
  contract/library, function body or storage mutation.
- Compared the snapshot interface/library source text with the pre-edit read:
  unchanged. Neither was an apply_patch target.
- Native Solidity `lsp_diagnostics`, severity `all`, returned
  **`No diagnostics found` for each of the six new files**.
- An earlier Native LSP reference request for `createFundedPosition` timed
  out (`textDocument/references`); actual interfaces, targets, facets and
  package callers were read directly instead. No reference result was invented.

These are source/LSP checks, not a Forge build, ABI artifact generation,
live selector census, runtime size check or executed money-path test.
No Forge build/test was run: those belong to parent integration after
the component writers finish. Interface IDs must be derived and advertised
per interface, including inherited canonical interfaces and the separate
accounting interface; inheritance is not permission to claim an uninstalled
selector. After activation, do not continue advertising the removed
allocation interface as callable.

## 7. Exact downstream source ownership

The brief's dependency barrier is
`interfaces -> (receipt-rt + bonds + sy) -> parent-and-tests -> verify-core`.
All six new files above are shared **read-only inputs** to the parallel
component writers. No two component nodes own the same common file.
Only the parent integration node, after all three writers finish, may
repair interface/component integration defects.

| Exclusive lane | New implementation paths and permitted existing edits |
| --- | --- |
| Receipt/RT | `M/claimToken/UniswapV4DetfMigrationStakedDETF{Repo,Target,Facet}.sol`; `M/sy/rewards/UniswapV4DetfMigrationRewardToken{Repo,Target,Facet,DFPkg}.sol`; only `C/claimToken/StakedDETFTarget.sol` and `C/claimToken/RebasingClaimTokenDFPkg.sol` among existing files |
| Bonds | `M/bondNft/UniswapV4DetfMigrationBondNFTRepo.sol`; `M/bondNft/UniswapV4DetfMigrationBondNFTVault{Target,Facet,DFPkg}.sol`; `M/bondNft/UniswapV4DetfMigrationBondMetadata{Target,Facet}.sol`; only `C/bondNft/DETFFundedBondTarget.sol`, `C/bondNft/DETFNFTVaultDFPkg.sol`, `C/bondNft/DETFFundedBondMetadata.sol` among existing files |
| SY | `M/sy/UniswapV4DetfMigrationSY{Repo,Target,Facet}.sol`, directly under `sy/`, excluding `rewards/`; only `C/sy/DETFSYTarget.sol` and `C/sy/DETFSYDFPkg.sol` among existing files |
| Parent integration | New `M/UniswapV4DetfMigration{Repo,Policy,Target,Facet,DFPkg}.sol`; `M/UniswapV4DetfMigration{Exchange,Bond,Maintenance,Query}Facet.sol`; `M/UniswapV4DetfMigrationAllocation{Target,Facet}.sol`; `M/UniswapV4DetfMigration_Component_FactoryService.sol`; `M/UniswapV4DetfMigration_Pkg_FactoryService.sol`; `M/TestBase_UniswapV4DetfMigration.sol`; new TM core specs; existing `D/UniswapV4DetfCommon.sol` and `D/UniswapV4DetfTarget.sol` |
| Parent local QA | `scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol`; only if needed, `scripts/recovery/dtf-migration/core-local-qa-guard.sh` |

Brace groups in this table expand to the named exact files, not permission
to edit adjacent interfaces. Component reports belong under
`docs/incidents/2026-09-16-dtf-recovery/migration/core/components/`.
The seven existing C files are partitioned 2/3/2 as above. Shared Crane,
dependencies, configs, locks, ordinary gold TestBases, verified snapshot and
weighted/V3 pricing sources have no writer in these component lanes.
Observed file inventory and this task's write receipts contain no conflicting
shared write; scheduling must retain the stated barrier.

## 8. DoneClaim and limits

**DoneClaim: the shared declaration/argument node is complete.** The six
owned Solidity files contain the accepted cross-component interfaces,
parent independent configuration/execution types, fixed package schemas,
phase handshake and R3 units. Production consumers were traced; diagnostics
and source compatibility checks are recorded above. Existing common types
were reused rather than introducing incompatible parallel structs.

Routine decisions settled here: nested base `PkgInit`/`PkgArgs` reuse;
canonical funded-bond rather than historical LP-bond inheritance; distinct
permanent/removable interfaces in the owned parent file; deterministic
full-input configuration identity; generic RT package schema without
configurable quantum/decimals. None is an additional product approval,
legacy provenance mechanism or new protocol rollout.

No component behavior is implemented or claimed accepted by this node.
Parent integration must still compile the assembled source and prove
actual funding, callback/phase ordering, all five children's wiring,
proxy cuts/declarations, exact backing, mature principal, gated rewards,
ordinary regressions and local-chain execution. E1/E2 remain unanswered;
actual-recovery E3, runtime E4/E5, surrender/harvest and resumable operator
gates remain open without attribution or atomicity relaxation.

Cleanup: no owned process, RPC listener, temporary root, cache, server or
dependency was created. Nothing requires runtime cleanup. Warm artifacts
and read-only dependency links were preserved. No commit, delegation,
public action, install, build, test or storage mutation occurred.
