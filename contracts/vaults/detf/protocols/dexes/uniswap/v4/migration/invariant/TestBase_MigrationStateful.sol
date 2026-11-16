// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4DetfMigration} from "../TestBase_UniswapV4DetfMigration.sol";
import {MigrationNativeHandler} from "./MigrationNativeHandler.sol";
import {MigrationNativeLedger} from "./MigrationNativeLedger.sol";
import {MigrationStatefulBindings} from "./MigrationStatefulBindings.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from "../interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";

/// @notice Two independently funded real registry proxies, not two aliases of one fixture member.
abstract contract TestBase_MigrationStateful is TestBase_UniswapV4DetfMigration {
    MigrationNativeHandler public handler;
    event StatefulDeployment(address parent, address hook, address receipt, address bonds, bytes32 snapshot, bytes32 parentCode);

    function setUp() public virtual override {
        super.setUp();
        _fundAndCapture();
        _configure(address(0x2499), 4e15, bytes32("isolated-original"));
        _issue(address(0x2499));
        MigrationStatefulBindings.capture(migration, address(migrationPkg), address(indexedexManager));
        MigrationNativeLedger.Seed memory s_;
        s_.isolated = detf;
        s_.isolatedBook = keccak256(abi.encode(migration.owner(), migration.hook(), migration.rebasingClaimToken(),
            migration.bondNftVault(), migration.migrationWeightedPricing(), migration.independentAllocation(address(0x2499)),
            migration.independentIssuance(address(0x2499)), IERC20(detf).totalSupply(), receipt.stakingState(),
            bonds.positionOf(3)));
        emit StatefulDeployment(detf, migration.hook(), address(receipt), address(bonds),
            migration.migrationWeightedPricing().id, detf.codehash);

        Package.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.mintThreshold = 100e18;
        detf = _deployMigration(args_);
        migration = Migration(detf); allocation = Allocation(detf);
        receipt = MigrationReceipt(migration.rebasingClaimToken());
        bonds = Bonds(migration.bondNftVault());
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
        _fundAndCapture();
        s_.bootstrapSupply = migration.migrationBootstrapSelfMinted();
        assertEq(IERC20(detf).totalSupply(), s_.bootstrapSupply);
        for (uint256 i_; i_ < 3; ++i_) s_.quotes[i_] = migration.previewOriginalCredit((i_ + 1) * 1e15, (i_ + 1) * 1e15);
        for (uint256 i_; i_ < 6; ++i_) {
            _configure(address(uint160(0x2400 + i_)), (i_ % 3 + 1) * 1e15,
                keccak256(abi.encode("stateful-original", i_)));
        }
        assertEq(_issue(address(0x2400)), 3);
        assertEq(_issue(address(0x2401)), 4);
        s_.firstCredit = s_.quotes[0];
        s_.secondCredit = s_.quotes[1];
        (, s_.paidPrincipal, s_.paidReward, s_.paidSelf) = migration.previewBond(IERC20(pairA), 1 ether, 90 days);
        assertEq(_buyOwnerFirstBond(), 5);
        emit log_named_bytes("native submitted package arguments", abi.encode(args_));
        MigrationStatefulBindings.capture(migration, address(migrationPkg), address(indexedexManager));
        s_.parent = migration; s_.owner = migrationOwner;
        s_.registry = address(indexedexManager); s_.registryOwner = owner;
        s_.pair = pairA; s_.otherPair = pairB; s_.se = se0;
        (, s_.feeFraction, s_.creatorFraction) =
            IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(detf);
        handler = new MigrationNativeHandler(s_);
        IERC20(pairA).transfer(address(handler), 20 ether);
        handler.assertAll();
        emit StatefulDeployment(detf, migration.hook(), address(receipt), address(bonds),
            migration.migrationWeightedPricing().id, detf.codehash);
        address[] memory facets_ = IDiamondLoupe(detf).facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) {
            emit log_named_address("deployed parent facet", facets_[i_]);
            emit log_named_bytes32("deployed parent facet codehash", facets_[i_].codehash);
        }
        // Mandatory successful witnesses do not depend on selecting random actions.
        handler.setPricing(0);
        handler.staleBook(0);
        handler.setPricing(1);
        handler.staleBook(1);
        // Recipient zero keeps immutable issuance A while its configuration is explicitly replaced under B.
        handler.configure(0, 2);
        handler.failedBatch();
        handler.issue(2);
        handler.transferBond(0);
        handler.transferOwner();
        handler.claimRewards(0);
        handler.rejectRoleRewards();
        handler.market(7);
        handler.providerRateChange(1);
        bytes4[] memory selectors_ = new bytes4[](15);
        selectors_[0] = handler.configure.selector; selectors_[1] = handler.issue.selector;
        selectors_[2] = handler.failedBatch.selector; selectors_[3] = handler.activate.selector;
        selectors_[4] = handler.transferOwner.selector; selectors_[5] = handler.transferBond.selector;
        selectors_[6] = handler.claimPrincipal.selector; selectors_[7] = handler.claimRewards.selector;
        selectors_[8] = handler.advanceTime.selector; selectors_[9] = handler.rejectRoleRewards.selector;
        selectors_[10] = handler.market.selector;
        selectors_[11] = handler.providerRateChange.selector;
        selectors_[12] = handler.paidBond.selector;
        selectors_[13] = handler.setPricing.selector;
        selectors_[14] = handler.staleBook.selector;
        targetContract(address(handler));
        string[] memory artifacts_ = new string[](1);
        artifacts_[0] = "MigrationNativeHandler.sol:MigrationNativeHandler";
        targetInterface(FuzzInterface(address(handler), artifacts_));
        targetSelector(FuzzSelector(address(handler), selectors_));
    }
}
