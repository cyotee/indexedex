// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {IMigrationLegacyExchange} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";

interface ILegacyLpFeeOracle {
    function feeOracle() external view returns (address);
    function feeTo() external view returns (address);
    function setFeeTo(address recipient_) external returns (bool);
    function pullFee(address token_, uint256 amount_, address recipient_) external returns (bool);
}

interface ILegacyEarlierLpExit {
    function withdrawSeShares(uint256 amount_, address recipient_, uint256 minimumRaw_, uint256 minimumSe_, uint256 deadline_)
        external returns (uint256, uint256);
}

/// @notice Conditional source proof only: actual oracle administration on an owned fork.
/// @dev No old parent impersonation, no role bestowed by the Migration implementation.
contract MigrationLegacyLpExitTest is Test {
    function setUp() public {
        vm.createSelectFork("robinhood_mainnet_alchemy", 108944663);
        assertEq(block.chainid, 4663);
        string memory header_ = vm.rpcJson("eth_getBlockByNumber", '["0x67e5d17",false]');
        assertEq(vm.parseJsonBytes32(header_, ".hash"),
            0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733);
    }

    function test_earlierLpCannotExitThroughFeeRoleTimeOrParentIntake() public {
        address source_ = Legacy.EARLIER_LP;
        address oracle_ = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
        address collector_ = ILegacyLpFeeOracle(oracle_).feeTo();
        address collectorOwner_ = IMultiStepOwnable(collector_).owner();
        address administrator_ = IMultiStepOwnable(oracle_).owner();
        address holder_ = makeAddr("local earlier LP holder");
        assertEq(collectorOwner_.code.length, 0);
        assertEq(administrator_.code.length, 0);
        assertEq(IMultiStepOwnable(source_).owner(), Legacy.EARLIER_DETF);
        address facet_ = IDiamondLoupe(source_).facetAddress(ILegacyEarlierLpExit.withdrawSeShares.selector);
        assertEq(facet_, 0x81Fb72511016B42437FE1ac2d5Bdb0bA82f14A35);
        assertEq(facet_.codehash, 0xca224a1792b0b9339c1c5c999c4d5e99bd33f25f8387da864d6eabb4d1d6b398);
        uint256 q_ = 10013;
        vm.startPrank(collectorOwner_);
        ILegacyLpFeeOracle(collector_).pullFee(source_, q_, collectorOwner_);
        IERC20(source_).transfer(holder_, q_);
        vm.stopPrank();
        uint256 supply_ = IERC20(source_).totalSupply();
        for (uint256 phase_; phase_ < 2; ++phase_) {
            if (phase_ == 1) {
                vm.prank(administrator_);
                ILegacyLpFeeOracle(oracle_).setFeeTo(holder_);
                vm.warp(vm.getBlockTimestamp() + 365 days);
            }
            vm.expectRevert(abi.encodeWithSignature("NotOwner(address)", holder_));
            vm.prank(holder_);
            ILegacyEarlierLpExit(source_).withdrawSeShares(q_, holder_, 0, 0, block.timestamp);
            assertEq(IERC20(source_).balanceOf(holder_), q_);
            assertEq(IERC20(source_).totalSupply(), supply_);
        }
        IVaultRegistryDisableQuery query_ = IVaultRegistryDisableQuery(oracle_);
        (, bool byVault_, bool byPackage_) = query_.isDisabledDetailed(Legacy.EARLIER_DETF);
        vm.startPrank(administrator_);
        if (byVault_) IVaultRegistryDisableManager(oracle_).setVaultAddressDisabled(Legacy.EARLIER_DETF, false);
        if (byPackage_) {
            IVaultRegistryDisableManager(oracle_).setPackageDisabled(query_.packageOfVault(Legacy.EARLIER_DETF), false);
        }
        vm.stopPrank();
        assertFalse(query_.isDisabled(Legacy.EARLIER_DETF));
        vm.startPrank(holder_);
        IERC20(source_).approve(Legacy.EARLIER_DETF, q_);
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", source_, Legacy.DTF));
        IMigrationLegacyExchange(Legacy.EARLIER_DETF).exchangeIn(
            source_, q_, Legacy.DTF, 1, holder_, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(IERC20(source_).balanceOf(holder_), q_);
        assertEq(IERC20(source_).totalSupply(), supply_);
    }

    function test_weightedLpExitRequiresActualCurrentFeeRecipientAuthorization() public {
        address source_ = Legacy.WEIGHTED_LP;
        address facet_ = IDiamondLoupe(source_).facetAddress(IMigrationLegacyExchange.exchangeIn.selector);
        assertEq(facet_, 0x1B7a7BC9044642C4e42e64f805f6400D75AD2c16);
        assertEq(facet_.codehash, 0xe5f44175a8c16c705c2c9e5e68b2c3efe842ce694c5e585d2211947802b10d84);
        address oracle_ = ILegacyLpFeeOracle(source_).feeOracle();
        address collector_ = ILegacyLpFeeOracle(source_).feeTo();
        address collectorOwner_ = IMultiStepOwnable(collector_).owner();
        address administrator_ = IMultiStepOwnable(oracle_).owner();
        assertEq(collectorOwner_.code.length, 0);
        assertEq(administrator_.code.length, 0);
        address holder_ = makeAddr("local selected LP holder");
        uint256 q_ = IERC20(source_).balanceOf(collector_) / 2;
        assertGt(q_, 0);
        vm.startPrank(collectorOwner_);
        ILegacyLpFeeOracle(collector_).pullFee(source_, q_, collectorOwner_);
        IERC20(source_).transfer(holder_, q_);
        vm.stopPrank();
        assertEq(IERC20(source_).balanceOf(holder_), q_);
        vm.expectRevert(abi.encodeWithSignature("NotOwner(address)", holder_));
        vm.prank(holder_);
        IMigrationLegacyExchange(source_).exchangeIn(source_, q_, Legacy.DTF, 1, holder_, false, block.timestamp);

        vm.prank(administrator_);
        ILegacyLpFeeOracle(oracle_).setFeeTo(holder_);
        assertEq(ILegacyLpFeeOracle(source_).feeTo(), holder_);
        uint256 supply_ = IERC20(source_).totalSupply();
        uint256 dtf_ = IERC20(Legacy.DTF).balanceOf(holder_);
        vm.prank(holder_);
        uint256 out_ = IMigrationLegacyExchange(source_).exchangeIn(
            source_, q_, Legacy.DTF, 1, holder_, false, block.timestamp
        );
        uint256 feeMint_ = IERC20(source_).totalSupply() + q_ - supply_;
        assertGt(out_, 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(holder_) - dtf_, out_);
        assertEq(IERC20(source_).balanceOf(holder_), feeMint_);
    }
}
