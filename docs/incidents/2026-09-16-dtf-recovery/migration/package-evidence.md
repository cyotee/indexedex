# Current package verification - 2026-11-18

The [current audit](implementation-audit-20261118/verification.md) records 235
successful native deployment/funding transactions, current runtime fingerprints,
the subsequent lifecycle, and actual removal of all 17 administration selectors.
The following November 15 record is historical and retains its original limits.

# Package evidence

Date: 2026-11-15. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

This record binds package, cut, funding, and role facts to files read and hashed for remediation task 9. It does not close E4, GAP-7, GAP-8, GAP-10, or a deployment gate. It does not approve a reserve composition, a donation inventory, or a public role change. Archive design notes under `migration/package/` were not used as operational receipts.

## Confirmation boundary

Task 4 round 2, `.omo/ulw-execute/dtf-conformance/task-4-verdict-r2.json`, `88c1721505d634f610a224c6406fc1cc6923943bd2a36e9673fbb1b5d1381207` (12058 bytes), confirms the command-bound repair logs only. This task recomputed the four log digests recorded in that verdict. All four matched:

| Log | SHA-256 | Bytes |
| --- | --- | --- |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/happy.log` | `2bb12559d2f9179db99115db30430fad387ab32e6fab89566015a6723a71f4f0` | 6134774 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/failures.log` | `b58ca87e782c3f1e9c64279587975a58c689dd70de699449113ddfb043aec131` | 9474596 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/happy-final.log` | `13bb4a68ee715d1fad56d62967b5a00d89ca6ab03fb18abb447b72c3bcb4a429` | 6133246 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/failures.log` | `b562ffaddfffb18dbcac47f45d4e9e3fe2b71dd145ba22881a38d6508a6dd662` | 9473559 |

`happy-final.log` and `failures.log` still have zero outer helper invocations, as round 1 found. They are preserved originals, not the accepting command binding.

`docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/proxy-census.json`, `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18` (5737 bytes), says its source is `happy-final.log`. Round 1 decoded that census against the original logs with zero field mismatches, and round 1 did not confirm. This task therefore re-read the command-bound repair log. Line 6117 is the passing activation-cut test. Line 6119 is the proxy writer ABI. Parsed as left-aligned `bytes4` words, its sixteen selectors equal the census writer selectors in the same order. The census after-activation owner for every writer is the zero address.

Task 6 conservation and funding assertions are `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json`, `18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054` (173171 bytes), bound to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/fork-qa-1.log`, `ec59e2ca0e0f6c936b848ed226571e303cd9a37a7d9fc674b22c3eeca7cee238` (3884899 bytes).

Solidity hashes for the package files read here:

| File | SHA-256 | Bytes |
| --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Component_FactoryService.sol` | `bca895a9e049f8c952bdd8d05b2f3564a957b5d05edba05f268e6da345d829ba` | 1660 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol` | `a2695d87fda6ba7424c30674b15f6a200c251e4584544a0a07a18668a5e1b4d9` | 3251 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | `69ea9feb701ef20eaaea00e57531069bcade94a96668439286a30e1bc316964b` | 22464 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationFacet.sol` | `be911127e8a68b332f052bee93534f655b3ff9e2f096d0252e32d8f7f1bbc9f2` | 1262 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920` | 25265 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` | `294492b0045f05ef4106d203ba78e55aa534099218f006cb80de44576421d373` | 5536 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` | `e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29` | 22719 |

`UniswapV4DetfMigrationFacet.sol` is not in the migration directory. A direct read returned ENOENT. The plan's pre-rename line range was not available as that filename. The current administration facet file is `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationFacet.sol`.

## Registry and CREATE3 wiring

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Component_FactoryService.sol` lines 15-28: `deployFacet` calls `ICreate3FactoryProxy.deployFacet` with `ArtifactCreationCode.creationCode` of `name.sol:name` and `ArtifactCreationCode.releaseSalt(keccak256(abi.encode(name)))`. `deployParentFacets` deploys exchange, bond, maintenance, the shared claim facet, and query by those names.

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol` lines 18-60: `deployParent`, `deployBond`, and `deploySy` call `registry.deployPkg` through `_registered`, with the same name-derived release salt. `deployRewardToken` calls `factory.deployPackageWithArgs` with that salt. The names read are `UniswapV4DetfMigrationDFPkg`, `UniswapV4DetfMigrationBondNFTVaultDFPkg`, `UniswapV4DetfMigrationSYDFPkg`, and `UniswapV4DetfMigrationRewardTokenDFPkg`.

These are source wiring facts. This task found no confirmed task 1-6 artifact that records a production registry address, a deployed package address, or the salt bytes actually used on a public chain. Those operational addresses remain unresolved. Local fixture addresses appearing in a trace are identified below as fixture addresses, not as a deployment manifest.

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` `calcSalt`, read at lines 246-250, zeros `baseArgs.hook` and returns `keccak256(abi.encode(args))`. That CREATE2 prediction salt is not the CREATE3 `releaseSalt(keccak256(abi.encode(name)))` used by the factories above. The two salts are not interchangeable in this record.

## Facet, interface, and cut declarations

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationFacet.sol` declares `facetName` `UniswapV4DetfMigrationAllocationFacet`, one interface id `type(Allocation).interfaceId`, and eight `facetFuncs`: the first five administration selectors, then weighted-SY, DTF-custody-SE, and claimed-SY configuration.

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` `_administrationSelectors`, read at lines 285-303, returns sixteen selectors. Activation, read at lines 267-283, requires `ownerFirstBondTokenId != 0`, builds a removal cut for each current facet owner, reverts if any current owner is the zero address, calls `_processFacetCuts`, clears the Allocation interface support flag, sets `activated`, and emits `MigrationActivated`. It does not reinstall selectors.

The command-bound writer ABI at repair `happy.log:6119` matches this selector list and order:

| Selector | Signature in the census | Loupe owner before | Loupe owner after |
| --- | --- | --- | --- |
| `0xec55c474` | `bootstrapMigrationReserve((address,uint256,uint256)[],uint256,uint256,uint256)` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0x43d1e0cc` | `setMigrationWeightedPricing((uint256,uint256,uint256,uint256,uint256,(address,address,uint8,uint256,uint256,uint256,uint256,uint256,uint256,(uint8,address,(address,address,address,uint8),address,address,uint256,uint256,uint256,uint256))[]))` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0x703e5943` | `configureIndependentAllocations((address,bytes32,(bytes32,uint256,uint256,bytes32)[])[],bytes32)` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0x1f9aab7f` | `configureNftEntitlements((address,uint256,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0x9fbc6598` | `configureNftContributionEntitlements((address,uint256,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0x69f61e45` | `configureWeightedLiquidEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0x3bbb46c3` | `configureWeightedSyEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0x653470af` | `configureClaimedSyEntitlements(((bytes32,address,address,uint256,uint256,uint256,bytes32,bool),uint256,uint256)[],bytes32)` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0x559e5d0b` | `configureDtfCustodySeEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0x37444d48` | `configureClaimVaultEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0xc11ab8d4` | `configureWeightedReceiptEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0xcbaead69` | `configureEarlierReceiptEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0x12f4be5f` | `configureEarlierLiquidEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0x15af3f80` | `configureHeldSeLpEntitlements((bytes32,address,address,uint256,uint256,uint256,bytes32,bool)[],bytes32)` | `0x59bf980935b2ffd7af72b526b5d0cf3a642a9c7b` | `0x0000000000000000000000000000000000000000` |
| `0x787642e8` | `issueIndependentAllocations((address,bytes32)[])` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |
| `0xe9dc9e6d` | `activateMigration()` | `0x5a74935bdf9f5e2804c2992e282ef5f3e9605059` | `0x0000000000000000000000000000000000000000` |

Census alias selectors, absent before and after. No signature was recorded for them in the census, and none is invented here:

| Selector | Before | After |
| --- | --- | --- |
| `0x161d9afc` | `0x0000000000000000000000000000000000000000` | `0x0000000000000000000000000000000000000000` |
| `0xa5ef9788` | `0x0000000000000000000000000000000000000000` | `0x0000000000000000000000000000000000000000` |
| `0x7fda99ae` | `0x0000000000000000000000000000000000000000` | `0x0000000000000000000000000000000000000000` |

Census retained entries from the same activation test. This is not a complete post-activation surface census:

| Selector | Signature | Loupe owner |
| --- | --- | --- |
| `0xcc337380` | `migrationWeightedPricing()` | `0xd8da8fb6c3dae05ef52117ff8c167cccf7abbc6b` |
| `0xdc6bf0d3` | `previewOriginalCredit(uint256,uint256)` | `0xd8da8fb6c3dae05ef52117ff8c167cccf7abbc6b` |

The retained function bodies read in this task are `migrationWeightedPricing` and `previewOriginalCredit` at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` lines 39-40. The census owner `0xd8da8fb6c3dae05ef52117ff8c167cccf7abbc6b` is the loupe address in the test trace. This task did not bind that address to a source filename. That binding is unresolved.

Expected-book loading is `UniswapV4DetfMigrationRepo._weightedPricing(bytes32)`, read at lines 83-88. It loads the stored book and reverts `MigrationWeightedPricingBookMismatch(expected, actual)` when the final scalar differs. An empty stored book reverts `MigrationWeightedPricingNotSet` from the no-argument loader at lines 76-80. The setter is `setMigrationWeightedPricing`, selector `0x43d1e0cc`, present before activation and absent after, in the census and in the repair ABI.

## Roles

`administration()`, read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` lines 37-38, calls `MultiStepOwnableRepo._onlyOwner()`. The body of that library was not read, so this record does not describe the queued-owner or previous-owner storage layout.

The command-bound repair failure log line 50147 passes `test_UnauthorizedPricing_CurrentPendingFormerOwnerAndRollback`. The test body was not read. The pass is an execution witness that the named test succeeded. It is not a restatement of unread library storage. Current-owner administration is the modifier that was read. Rejection details for the non-current owner roles, beyond that test name, remain unresolved as source lines.

Task 6 does not add a second owner model. Surrender callers are configured original wallets, not the proxy owner. See the surrender record.

## Children

The factory names above are the child packages and parent facets the source deploys. No confirmed task 1-6 evidence read for this record supplies a production child address list. Local trace addresses are not promoted to that list. Real deployed child addresses remain unresolved.

## Bootstrap, external capital, and reserve self-mint

`donateMigrationCapital`, read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` lines 327-358, pulls caller-specified tokens into `donationInventory` after duplicate and route checks. Before the reserve is live it requires `minLpOut == 0`. Native value must equal `msg.value` and is wrapped to the configured WETH before booking. The function is permissionless and `nonReentrant`. It does not create a personal entitlement. The remainder of the post-live branch was not read.

`bootstrapMigrationReserve`, read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` lines 305-367, is an administration entry. It reverts if the reserve is already live. It previews each leg, quotes `selfMinted_` from the anchor, reverts if that quote is zero, converts legs from booked inventory, mints `selfMinted_` of the migration token to itself, joins unbalanced liquidity, and accounts residual self-mint and unused donation inventory separately. It stores `bootstrapSelfMinted` and emits `MigrationReserveBootstrapped(selfMinted_, lpOut_, timestamp)`.

The repair failure log line 2606 is the compiler trace of that emit statement, not a decoded `selfMinted_` or `lpOut_` value. Numeric bootstrap receipts for that run were not decoded in this task and stay unresolved. A search for the 100-ether wei quantity in that log hit an unrelated fee field inside a book trace, so no 100-ether transfer is cited.

External donated capital and the reserve self-mint are different stores in the function that was read: donation inventory is pulled or consumed, and `_mintDetf(address(this), selfMinted_)` creates the self-leg. The amended plan section 1.5, read at lines 76-86, says at line 80 that reserve self-leg minting does not substitute for the paid first ordinary bond. This record does not add a self-mint amount.

## Donation and refund inventories

The code books `donationInventory` on donation and bootstrap residuals, `residualInventory` for self-mint left after the join, and recovery `inventory` on measured surrender. Surrender inventory increments were read in the weighted-liquid, weighted-SY, held-SE, and DTF-custody-SE bodies. Refund accounting inside the unread tail of `donateMigrationCapital` stays unresolved as a line citation.

No operational donation, refund, or holder inventory is approved by tasks 1-6. Task 6 conservation notes describe fixture donation deltas in words, for example that a selected donation debits recovered DTF and that an earlier-NFT donation remainder equals combined recovery minus donation. Those are assertion descriptions in `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json`. They are not an operational inventory and no extra amount is added here.

## Issuance on configuration

`configureClaimedSyEntitlements`, read in full at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` lines 166-217, stores entitlement, remaining units, and remaining credit, and emits a configured event. It does not call `_fundBond` or `_mintDetf`. `issueIndependentAllocations` is a separate administration selector, `0x787642e8`, removed by activation. The other configure function bodies were not all read. Their signatures, read by search, take `expectedBookId` as the final scalar and call `_weightedPricing(expectedBookId_)` before the unread body. A log-extracted supply delta for every loader was not produced in this task. Zero issuance is therefore cited for the claimed-SY store that was read, and unresolved as a trace delta for the other loaders.

## Paid first ordinary bond

`activateMigration` reverts `MigrationOwnerFirstBondRequired` when `ownerFirstBondTokenId == 0`. The command-bound failure log line 12374 is `VM::expectRevert(MigrationOwnerFirstBondRequired())`. Line 40259 emits `MigrationOwnerFirstBondPurchased` for fixture owner `0xFB3A3B4E9c9a875C864bB6c97b560eE43672fA1F` and `bondTokenId` 3. That owner is a local trace value, not an operational buyer and not a compensation recipient. The purchase function body was not read, so the paid amount and argument list are unresolved here. Amended plan section 1.5 says the purchase is paid capital, not compensation, and not a use of harvested recovery inventory.

## Funded compensation supply and gons

`_fundBond`, read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` lines 92-101, mints `credit_` to the migration proxy, approves the bond vault, and calls `createMigrationPosition(credit_, recipient_)`. Task 6's weighted-NFT positive assertions, recorded in `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json`, include supply increase equal to the quoted credit, receipt balance and `accountedBacking` increased by that credit, and `stakingGons` equal to credit times `gonsPerUnit`. Those are assertion-backed expressions in the named test, not a new gas measurement and not an operational award. The same funding call is used by the surrender entries whose bodies were read.

## Post-activation retained routes

Activation removes the sixteen administration selectors and clears Allocation interface support. Surrender entries require `activated` and remain after that cut. Recovery selection is a later owner route, not a restored configuration selector. The two census retained selectors above remain owned by the recorded loupe address in that test. A complete retained-selector census was not in `proxy-census.json`. Query, exchange, and recovery facet inventories beyond the files hashed above are unresolved as a full surface list.

## Restoration

`activateMigration` has no path that sets `activated` back to false or re-adds the removed selectors. `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` `facetCuts`, read at lines 230-234, builds `FacetCutAction.Add` cuts from `facetAddresses()` for package wiring. The same Add action appears in the SY and reward-token package files at the deployment wiring lines found by search (`UniswapV4DetfMigrationSYDFPkg.sol:265` and `UniswapV4DetfMigrationRewardTokenDFPkg.sol:64`). Those are initial package cuts, not a post-activation restore function.

A search of the migration Solidity tree for `activated = false` and for a function whose name contains a restore stem found no such function. That search does not cover contracts outside the migration tree. No restoration path was read inside the migration tree. Absence outside that tree is unresolved.

## Source fingerprint binding

Each state citation above names the file and the SHA-256 recomputed for this record. The fourteen source rows used by surrender are bound to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json`, `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` (211316 bytes). Their recorded runtime code hash is `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` on every row. This task did not recompute runtime code from chain. The observation file also contains archive binding hashes. Those constituent files were not rehashed in this task, so an aggregate source fingerprint is not claimed. The task 3 verdict states the same limit: constituent bindings were verified by that verifier; an aggregate preimage was not reconstructed.

Task 6 execution is bound to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/fork-qa-1.log`, whose recomputed digest matches the digest stored in `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json`. Package execution citations are bound to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/happy.log` and `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/failures.log`, whose recomputed digests match the round-2 verdict.
