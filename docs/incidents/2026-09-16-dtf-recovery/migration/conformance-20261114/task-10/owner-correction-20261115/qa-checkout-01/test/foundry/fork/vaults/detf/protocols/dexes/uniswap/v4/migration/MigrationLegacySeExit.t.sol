// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {IMigrationLegacyExchange, IMigrationWeightedClaims, IMigrationWeightedReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";

interface ILegacyEarlierReceiptRedemption {
    function redeemClaim(uint256 amount_, address tokenOut_, uint256 minimum_, address recipient_, uint256 deadline_)
        external returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
    function pendingRewards(uint256 tokenId_) external view returns (uint256);
}

/// @notice Source-admission probes, not a replacement Migration TestBase.
/// @dev Real fixed legacy contracts and genuine EOA holdings. Registry enablement is
/// an explicit conditional local fixture, never claimed as publicly performed.
contract MigrationLegacySeExitTest is Test {
    address constant REGISTRY = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;

    function setUp() public {
        vm.createSelectFork("robinhood_mainnet_alchemy", 108944663);
        assertEq(block.chainid, 4663);
        string memory header_ = vm.rpcJson("eth_getBlockByNumber", '["0x67e5d17",false]');
        assertEq(vm.parseJsonBytes32(header_, ".hash"),
            0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733);
    }

    function _enable(address source_) private {
        IVaultRegistryDisableQuery query_ = IVaultRegistryDisableQuery(REGISTRY);
        (bool disabled_, bool byVault_, bool byPackage_) = query_.isDisabledDetailed(source_);
        assertTrue(disabled_);
        vm.startPrank(IMultiStepOwnable(REGISTRY).owner());
        if (byVault_) IVaultRegistryDisableManager(REGISTRY).setVaultAddressDisabled(source_, false);
        if (byPackage_) {
            IVaultRegistryDisableManager(REGISTRY).setPackageDisabled(query_.packageOfVault(source_), false);
        }
        vm.stopPrank();
        assertFalse(query_.isDisabled(source_));
    }

    function _exit(address source_, address holder_, uint256 q_) private {
        assertGt(q_, 0);
        uint256 sharesBefore_ = IERC20(source_).balanceOf(holder_);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(holder_);
        vm.startPrank(holder_);
        IERC20(source_).approve(source_, q_);
        uint256 out_ = IMigrationLegacyExchange(source_).exchangeIn(
            source_, q_, Legacy.DTF, 1, holder_, false, block.timestamp
        );
        IERC20(source_).approve(source_, 0);
        vm.stopPrank();
        assertGt(out_, 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(holder_) - before_, out_);
        assertEq(IERC20(source_).balanceOf(holder_), sharesBefore_ - q_);
        assertEq(IERC20(source_).allowance(holder_, source_), 0);
    }

    function test_earlierSePublicExitAfterLocalEnablement() public {
        _enable(Legacy.EARLIER_SE);
        // The known tiny EOA holding is worth less than one raw DTF unit.
        // Acquire a non-dust source position by a real paid mint, not balance injection.
        address weightedNft_ = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
        address holder_ = IERC721(weightedNft_).ownerOf(3);
        vm.startPrank(holder_);
        (uint256 principal_, uint256 rewards_) =
            IMigrationWeightedClaims(weightedNft_).claimBond(3, holder_);
        uint256 receiptIn_ = principal_ + rewards_;
        IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).exchangeIn(
            Legacy.WEIGHTED_RECEIPT, receiptIn_, Legacy.WEIGHTED_DETF, receiptIn_,
            holder_, false, block.timestamp
        );
        IERC20(Legacy.WEIGHTED_DETF).approve(Legacy.WEIGHTED_DETF, receiptIn_);
        IMigrationLegacyExchange(Legacy.WEIGHTED_DETF).exchangeIn(
            Legacy.WEIGHTED_DETF, receiptIn_, Legacy.DTF, 1e12, holder_, false, block.timestamp
        );
        IERC20(Legacy.WEIGHTED_DETF).approve(Legacy.WEIGHTED_DETF, 0);
        uint256 sharesBefore_ = IERC20(Legacy.EARLIER_SE).balanceOf(holder_);
        IERC20(Legacy.DTF).approve(Legacy.EARLIER_SE, 1e12);
        uint256 minted_ = IMigrationLegacyExchange(Legacy.EARLIER_SE).exchangeIn(
            Legacy.DTF, 1e12, Legacy.EARLIER_SE, 1, holder_, false, block.timestamp
        );
        IERC20(Legacy.DTF).approve(Legacy.EARLIER_SE, 0);
        vm.stopPrank();
        assertEq(IERC20(Legacy.EARLIER_SE).balanceOf(holder_) - sharesBefore_, minted_);
        _exit(Legacy.EARLIER_SE, holder_, minted_);
    }

    function test_weightedSePublicExitAfterLocalEnablement() public {
        _enable(Legacy.WEIGHTED_WETH_SE);
        address holder_ = address(bytes20(hex"72bea6fa3e68ef18c87d045aac7c4aa5249d933b"));
        _exit(Legacy.WEIGHTED_WETH_SE, holder_, IERC20(Legacy.WEIGHTED_WETH_SE).balanceOf(holder_));
    }

    function test_earlierDetfPublicSwapAfterLocalEnablement() public {
        _enable(Legacy.EARLIER_SE);
        address holder_ = address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed"));
        uint256 q_ = 1e24;
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(holder_);
        uint256 held_ = IERC20(Legacy.EARLIER_DETF).balanceOf(holder_);
        assertGe(held_, q_);
        vm.startPrank(holder_);
        IERC20(Legacy.EARLIER_DETF).approve(Legacy.EARLIER_LP, q_);
        uint256 out_ = IMigrationLegacyExchange(Legacy.EARLIER_LP).exchangeIn(
            Legacy.EARLIER_DETF, q_, Legacy.DTF, 1, holder_, false, block.timestamp
        );
        IERC20(Legacy.EARLIER_DETF).approve(Legacy.EARLIER_LP, 0);
        vm.stopPrank();
        assertGt(out_, 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(holder_) - before_, out_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(holder_), held_ - q_);
    }

    function test_earlierReceiptRedeemsFromProtocolRewardsThenSwapsToDtf() public {
        _enable(Legacy.EARLIER_SE);
        address holder_ = 0xBEdf78eB17A054D972c85cE222E2175F19899CD6;
        address nft_ = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;
        uint256 principal_ = IMigrationEarlierNft(nft_).getPosition(0).originalShares;
        emit log_named_uint("protocol original shares", principal_);
        emit log_named_uint("protocol effective shares", IMigrationEarlierNft(nft_).getPosition(0).effectiveShares);
        emit log_named_uint("current protocol pending", ILegacyEarlierReceiptRedemption(nft_).pendingRewards(0));
        vm.warp(vm.getBlockTimestamp() + 365 days);
        emit log_named_uint("future parent expansion", ILegacyEarlierReceiptRedemption(Legacy.EARLIER_DETF).pendingExpansionDetf());
        // Elapsed time alone is not income at this pin. A real external holder
        // supplies new reward tokens through the legacy NFT's actual balance path.
        address rewardDonor_ = address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed"));
        uint256 donorBefore_ = IERC20(Legacy.EARLIER_DETF).balanceOf(rewardDonor_);
        vm.prank(rewardDonor_);
        IERC20(Legacy.EARLIER_DETF).transfer(nft_, 1e24);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(rewardDonor_), donorBefore_ - 1e24);
        uint256 beforeEd_ = IERC20(Legacy.EARLIER_DETF).balanceOf(holder_);
        uint256 beforeDtf_ = IERC20(Legacy.DTF).balanceOf(holder_);
        vm.startPrank(holder_);
        uint256 received_ = ILegacyEarlierReceiptRedemption(Legacy.EARLIER_DETF).redeemClaim(
            1000, Legacy.EARLIER_DETF, 1, holder_, block.timestamp
        );
        assertGt(received_, 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(holder_) - beforeEd_, received_);
        IERC20(Legacy.EARLIER_DETF).approve(Legacy.EARLIER_LP, received_);
        uint256 out_ = IMigrationLegacyExchange(Legacy.EARLIER_LP).exchangeIn(
            Legacy.EARLIER_DETF, received_, Legacy.DTF, 1, holder_, false, block.timestamp
        );
        IERC20(Legacy.EARLIER_DETF).approve(Legacy.EARLIER_LP, 0);
        vm.stopPrank();
        assertGt(out_, 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(holder_) - beforeDtf_, out_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(holder_), beforeEd_);
        assertGe(IMigrationEarlierNft(nft_).getPosition(0).originalShares, principal_);
    }

    function test_earlierSeDustRejectsWithoutBurningAfterLocalEnablement() public {
        _enable(Legacy.EARLIER_SE);
        address holder_ = address(bytes20(hex"bab6a03be445094a10695772a79777407dcdc0e7"));
        uint256 q_ = IERC20(Legacy.EARLIER_SE).balanceOf(holder_);
        uint256 supply_ = IERC20(Legacy.EARLIER_SE).totalSupply();
        vm.startPrank(holder_);
        IERC20(Legacy.EARLIER_SE).approve(Legacy.EARLIER_SE, q_);
        vm.expectRevert(bytes4(keccak256("UniswapV4ExchangeIn_SlippageExceeded()")));
        IMigrationLegacyExchange(Legacy.EARLIER_SE).exchangeIn(
            Legacy.EARLIER_SE, q_, Legacy.DTF, 1, holder_, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(IERC20(Legacy.EARLIER_SE).balanceOf(holder_), q_);
        assertEq(IERC20(Legacy.EARLIER_SE).totalSupply(), supply_);
    }
}
