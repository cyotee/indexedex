// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationRecoveryDonationForkBase} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol";
import {IClaimVaultAcquisition} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVaultForkBase.sol";
import {IDtfCustodySeAcquisition} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySeForkBase.sol";
import {IHeldSeLpCollector} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol";
import {MigrationSourceUnitsRecoveryHandler} from "./MigrationSourceUnitsRecoveryHandler.sol";
import {MigrationStatefulBindings} from "./MigrationStatefulBindings.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from "../interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IMigrationWeightedReceipt, IMigrationEarlierReceipt, IMigrationWeightedSynchronization}
    from "../legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "../legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Reuses actual admitted source acquisitions; source donors are local simulations, not signatures.
/// @dev Every original component/eligible-unit allocation is disclosed synthetic test input.
abstract contract TestBase_MigrationSourceUnits is MigrationRecoveryDonationForkBase {
    MigrationSourceUnitsRecoveryHandler public handler;
    uint256 internal laterFirst;
    address private constant WD_DONOR = address(bytes20(hex"082cb14f04d9c485473dedc00d604d7e9abca303"));
    address private constant ED_DONOR = address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed"));
    address private constant ER_DONOR = 0xBEdf78eB17A054D972c85cE222E2175F19899CD6;
    address private constant SY_DONOR = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
    address private constant LP_DONOR = address(bytes20(hex"72bea6fa3e68ef18c87d045aac7c4aa5249d933b"));
    address private constant COLLECTOR = address(bytes20(hex"20af9a1e21a59a411cd3b0c40e70af9084770b2e"));

    function setUp() public virtual override {
        super.setUp();
        Package.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.mintThreshold = 100e18;
        detf = _deployMigration(args_);
        migration = Migration(detf); allocation = Allocation(detf);
        receipt = MigrationReceipt(migration.rebasingClaimToken()); bonds = Bonds(migration.bondNftVault());
        IERC20(pairA).approve(detf, type(uint256).max); IERC20(pairB).approve(detf, type(uint256).max);
        _fundHistoricalBook(); _buyOwnerFirstBond();
        _configureNft(EARLIER, 3); _returnToOriginal(EARLIER, 3);
        handler = new MigrationSourceUnitsRecoveryHandler(migration);
        uint256[9] memory q_;
        _acquireLiquid();
        q_[0] = 10000; q_[1] = 10000;
        q_[2] = _acquireWeightedReceipt();
        q_[3] = _acquireEarlierReceipt();
        q_[4] = _acquireClaimVault();
        q_[5] = _acquireCustodySe();
        for (uint256 i_ = 6; i_ < 9; ++i_) { _acquireHeld(i_); q_[i_] = 10000; }
        uint8[9] memory decimals_ = [9, 18, 9, 18, 19, 28, 18, 18, 18];
        for (uint256 i_; i_ < 9; ++i_) {
            assertEq(IERC20Metadata(handler.source(i_)).decimals(), decimals_[i_]);
            emit log_named_address("admitted fixed unit source", handler.source(i_));
            emit log_named_uint("configured eligible original source units", q_[i_]);
        }
        uint256[2] memory credits_ = [migration.previewOriginalCredit(0.01 ether, 0),
            migration.previewOriginalCredit(0.02 ether, 0)];
        handler.initialize(q_, credits_);
        handler.enrollmentWitness();
        handler.independentOriginWitness();
        for (uint256 i_; i_ < 9; ++i_) {
            vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
            handler.surrender(i_, 3);
            handler.assertAll();
        }
        _activate();
        MigrationStatefulBindings.capture(migration, address(migrationPkg), address(indexedexManager));
        for (uint256 i_; i_ < 9; ++i_) {
            handler.rejectControls(i_);
            handler.failedIssuance(i_);
            handler.surrender(i_, 3);
        }
        handler.failedRecoveryBatch();
        for (uint256 i_; i_ < 4; ++i_) handler.recover(i_, 3);
        handler.redeemRecoveredSy(3);
        handler.takeEarlier(_original(EARLIER, 3).originalWallet, migration.previewOriginalCredit(2 ether, 0));
        handler.sellEarlier();
        IERC20(Legacy.DTF).transfer(address(handler), 100 ether);
        handler.changeEarlierRate(0);
        handler.changeOwner();
        handler.advanceTime(29);
        laterFirst = handler.positionCount();
        for (uint256 i_; i_ < 9; ++i_) handler.surrender(i_, 3);
        handler.transferBond(handler.positionCount() - 1);
        handler.claimPrincipal(handler.positionCount() - 1);
        _target();
    }

    function _acquireLiquid() private {
        vm.prank(WD_DONOR); assertTrue(IERC20(Legacy.WEIGHTED_DETF).transfer(address(handler), 20110));
        vm.prank(ED_DONOR); assertTrue(IERC20(Legacy.EARLIER_DETF).transfer(address(handler), 20000));
        vm.startPrank(address(handler));
        assertTrue(IERC20(Legacy.WEIGHTED_DETF).transfer(detf, 10));
        assertTrue(IERC20(Legacy.EARLIER_DETF).transfer(detf, 10));
        vm.stopPrank();
    }

    function _acquireWeightedReceipt() private returns (uint256) {
        IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
        uint256 divisor_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).stakingState().gonsPerUnit;
        vm.startPrank(address(handler));
        IERC20(Legacy.WEIGHTED_DETF).approve(Legacy.WEIGHTED_RECEIPT, 110);
        IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).exchangeIn(
            Legacy.WEIGHTED_DETF, 110, Legacy.WEIGHTED_RECEIPT, 110, address(handler), false, block.timestamp);
        assertTrue(IERC20(Legacy.WEIGHTED_RECEIPT).transfer(detf, 1));
        vm.stopPrank();
        assertEq(handler.units(2, address(handler)), 109 * divisor_);
        // One eligible gon below a native transfer boundary; it must not be forgiven.
        return 101 * divisor_ - 1;
    }

    function _acquireEarlierReceipt() private returns (uint256) {
        uint256 rate_ = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).redemptionRate();
        assertEq(rate_, 2197);
        vm.prank(ER_DONOR);
        assertTrue(IERC20(Legacy.EARLIER_RECEIPT).transfer(address(handler), 10010));
        vm.prank(address(handler)); assertTrue(IERC20(Legacy.EARLIER_RECEIPT).transfer(detf, 1));
        assertEq(handler.units(3, address(handler)), Math.mulDiv(10010, 1e27, rate_) - Math.mulDiv(1, 1e27, rate_));
        return Math.mulDiv(10000, 1e27, rate_) - 1;
    }

    function _acquireClaimVault() private returns (uint256 q_) {
        address facet_ = 0x517234F78A4BcAfc5F880024A3E45D49cF43b305;
        assertEq(facet_.codehash, 0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f);
        assertEq(IDiamondLoupe(Legacy.CLAIM_VAULT).facetAddress(IClaimVaultAcquisition.deposit.selector), facet_);
        vm.prank(SY_DONOR); assertTrue(IERC20(Legacy.WEIGHTED_SY).transfer(address(handler), 3000));
        vm.startPrank(address(handler));
        IERC20(Legacy.WEIGHTED_SY).approve(Legacy.CLAIM_VAULT, 3000);
        q_ = IClaimVaultAcquisition(Legacy.CLAIM_VAULT).deposit(3000, address(handler));
        assertTrue(IERC20(Legacy.CLAIM_VAULT).transfer(detf, 11));
        vm.stopPrank();
        assertEq(q_, 29999999967592);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(address(handler)), q_ - 11);
        q_ -= 17;
    }

    function _acquireCustodySe() private returns (uint256 q_) {
        address facet_ = 0xDbcEEFf98F2388b0eFA0C0fDA2e08cdd263Ce8f5;
        assertEq(facet_.codehash, 0x99b74f701969463d5147a782113b30bef06ef1c65f58902d410849d6d2cef616);
        assertEq(IDiamondLoupe(Legacy.DTF_CUSTODY_SE).facetAddress(IDtfCustodySeAcquisition.deposit.selector), facet_);
        IERC20(Legacy.DTF).transfer(address(handler), 1 ether);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE);
        vm.startPrank(address(handler));
        IERC20(Legacy.DTF).approve(Legacy.DTF_CUSTODY_SE, 1 ether);
        q_ = IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).deposit(1 ether, address(handler));
        assertTrue(IERC20(Legacy.DTF_CUSTODY_SE).transfer(detf, 1e18));
        vm.stopPrank();
        assertEq(IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE) - before_, 1 ether);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(address(handler)), q_ - 1e18);
        q_ -= 1e20;
    }

    function _acquireHeld(uint256 i_) private {
        address token_ = handler.source(i_);
        assertEq(LP_DONOR.code.length, 0);
        assertEq(IHeldSeLpCollector(COLLECTOR).owner(), LP_DONOR);
        address facet_ = IDiamondLoupe(COLLECTOR).facetAddress(IHeldSeLpCollector.pullFee.selector);
        assertEq(facet_, 0xF7A99a0aeD1A4252C71c99FDD2a5B3250a41f669);
        assertEq(facet_.codehash, 0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb);
        assertEq(IDiamondLoupe(token_).facetAddress(IERC20.transferFrom.selector),
            0x1d17acA0e0717d90cea916372070a1BE4652223F);
        if (i_ != 6) {
            uint256 before_ = IERC20(token_).balanceOf(COLLECTOR);
            vm.prank(LP_DONOR); assertTrue(IHeldSeLpCollector(COLLECTOR).pullFee(token_, 10020, LP_DONOR));
            assertEq(IERC20(token_).balanceOf(COLLECTOR), before_ - 10020);
        }
        vm.prank(LP_DONOR); assertTrue(IERC20(token_).transfer(address(handler), 10020));
        vm.prank(address(handler)); assertTrue(IERC20(token_).transfer(detf, 10));
        assertEq(IERC20(token_).balanceOf(address(handler)), 10010);
    }

    function _target() private {
        bytes4[] memory selectors_ = new bytes4[](15);
        selectors_[0] = handler.surrender.selector; selectors_[1] = handler.missingRecord.selector;
        selectors_[2] = handler.rejectControls.selector; selectors_[3] = handler.rejectExcess.selector;
        selectors_[4] = handler.failedIssuance.selector; selectors_[5] = handler.removedConfiguration.selector;
        selectors_[6] = handler.recover.selector; selectors_[7] = handler.failedRecoveryBatch.selector;
        selectors_[8] = handler.advanceTime.selector; selectors_[9] = handler.transferBond.selector;
        selectors_[10] = handler.claimPrincipal.selector;
        selectors_[11] = handler.sellEarlier.selector;
        selectors_[12] = handler.redeemRecoveredSy.selector;
        selectors_[13] = handler.changeOwner.selector;
        selectors_[14] = handler.changeEarlierRate.selector;
        targetContract(address(handler));
        string[] memory artifacts_ = new string[](1);
        artifacts_[0] = "MigrationSourceUnitsRecoveryHandler.sol:MigrationSourceUnitsRecoveryHandler";
        targetInterface(FuzzInterface(address(handler), artifacts_));
        targetSelector(FuzzSelector(address(handler), selectors_));
    }
}
