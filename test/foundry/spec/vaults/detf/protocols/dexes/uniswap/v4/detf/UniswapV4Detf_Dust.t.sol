// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {UniswapV4DetfRepo} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IDetfReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DetfResidualAssertions} from "contracts/test/libs/DetfResidualAssertions.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.19 / T7.20 R19 diamond dust sweep.
contract UniswapV4Detf_Dust is TestBase_UniswapV4Detf {
    function test_T7_19_afterMint_bookedBalances_feeToSweepClearsJoinableDust() public {
        _firstBond(80 ether);
        pairToken.mint(detf, 5 ether);
        vm.startPrank(detfUser);IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pairToken)), 10 ether, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _assertRetainedThenSweep();
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.rebasingClaimToken()), 0, "no LP on claim");
    }

    function test_T7_20_sweepDust_joinsPairDust_unassignedLp() public {
        (uint256 tokenId,) = _firstBond(80 ether);
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        bytes32 positionBefore = keccak256(abi.encode(nft.positionOf(tokenId)));
        IStakedDETF staking = IStakedDETF(detfInfo.rebasingClaimToken());
        bytes32 fundingBefore = keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking))));
        uint256 nftLpBefore = IERC20(reserveHook).balanceOf(address(nft));


        pairToken.mint(detf, 5 ether);
        assertGt(IERC20(address(pairToken)).balanceOf(detf), 0, "dust parked");

        uint256 joinable = IDetfReserveDonation(detf).previewJoinDonatedCapital(IERC20(address(pairToken)), 5 ether);
        assertGt(joinable, 0, "the negative control is real joinable capital");
        vm.expectRevert(abi.encodeWithSelector(
            DetfResidualAssertions.JoinableResidual.selector, address(pairToken), 5 ether, joinable,
            IDetfReserveDonation.previewJoinDonatedCapital.selector
        ));
        this.checkResiduals();
        vm.prank(address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()));
        detfInfo.sweepDust();

        assertLt(IERC20(address(pairToken)).balanceOf(detf), 5 ether, "joinable capital was swept");
        _sweepDustUntilSettled();
        uint256 nftLpAfter = IERC20(reserveHook).balanceOf(address(nft));
        assertGt(nftLpAfter, nftLpBefore, "NFT LP up");
        assertEq(keccak256(abi.encode(nft.positionOf(tokenId))), positionBefore, "sweep preserves fixed principal and attributed staking");
        assertEq(keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking)))), fundingBefore, "reserve dust creates no staking funding");
        _assertNoJoinableDust();
    }

    function test_T7_20_afterBond_bookedBalances_feeToSweepClearsJoinableDust() public {
        _firstBond(50 ether);
        pairToken.mint(detf, 5 ether);
        vm.prank(detfUser);
        detfInfo.bond(IERC20(address(pairToken)), 10 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        _assertRetainedThenSweep();
    }

    /// @notice Burn leaves unrelated owned pair capital booked until explicit maintenance.
    function test_sweepDust_burnRetainsAndBooksPairDust() public {
        _firstBond(80 ether);
        vm.prank(detfUser);
        (uint256 minted_,) = IStandardExchangeIn(detf).exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(detf), 0, detfUser, false, block.timestamp + 1 hours
        );
        pairToken.mint(detf, 5 ether);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, minted_ / 2);
        IStandardExchangeIn(detf).exchangeIn(
            IERC20(detf), minted_ / 2, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertRetainedThenSweep();
    }

    /// @notice Donation joins only its declared payment and leaves earlier dust booked.
    function test_sweepDust_donateRetainsAndBooksPairDust() public {
        _firstBond(80 ether);
        pairToken.mint(detf, 5 ether);
        address nft_ = detfInfo.bondNftVault();
        vm.startPrank(detfUser);
        pairToken.approve(nft_, 8 ether);
        detfInfo.donate(IERC20(address(pairToken)), 8 ether, false);
        vm.stopPrank();
        _assertRetainedThenSweep();
    }

    /// @notice The NFT notification books custody without performing maintenance.
    function test_sweepDust_notifyRetainsAndBooksPairDust() public {
        _firstBond(80 ether);
        pairToken.mint(detf, 5 ether);
        vm.prank(detfInfo.bondNftVault());
        detfInfo.notifyReserveDonated();
        _assertRetainedThenSweep();
    }

    /// @notice A stranger cannot move protocol dust or change its booked reserve.
    function test_sweepDust_strangerRejected() public {
        _firstBond(80 ether);
        pairToken.mint(detf, 5 ether);
        uint256 held_ = pairToken.balanceOf(detf);
        uint256 booked_ = IBasicVault(detf).reserveOfToken(address(pairToken));
        uint256 lp_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        address stranger_ = makeAddr("dust stranger");
        vm.prank(stranger_);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, stranger_));
        detfInfo.sweepDust();
        assertEq(pairToken.balanceOf(detf), held_, "unauthorized sweep retains custody");
        assertEq(IBasicVault(detf).reserveOfToken(address(pairToken)), booked_, "unauthorized sweep preserves booking");
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lp_, "unauthorized sweep issues no LP");
    }

    /// @notice Maintenance authorization follows the oracle's current recipient immediately.
    function test_sweepDust_changedFeeToRevokesPreviousRecipient() public {
        _firstBond(80 ether);
        address previous_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address current_ = makeAddr("new dust fee recipient");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(current_));
        pairToken.mint(detf, 5 ether);
        uint256 held_ = pairToken.balanceOf(detf);
        vm.prank(previous_);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, previous_));
        detfInfo.sweepDust();
        assertEq(pairToken.balanceOf(detf), held_, "previous recipient cannot sweep");
        vm.prank(current_);
        detfInfo.sweepDust();
        assertLt(pairToken.balanceOf(detf), held_, "current recipient deploys dust");
        _sweepDustUntilSettled();
        _assertNoJoinableDust();
    }

    /// @notice A real imbalanced basket refunds capital that only a later external call reinvests.
    function test_sweepDust_refundsWaitForLaterExternalCall() public {
        _firstBond(80 ether);
        _sweepDustUntilSettled();
        vm.startPrank(detfUser);
        (uint256 minted_,) = IStandardExchangeIn(detf).exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(detf), 0, detfUser, false, block.timestamp + 1 hours
        );
        assertTrue(IERC20(detf).transfer(detf, minted_ / 10), "real holder supplies the raw basket leg");
        vm.stopPrank();
        pairToken.mint(detf, 5 ether);
        uint256 supply_ = IERC20(detf).totalSupply();
        address holder_ = detfInfo.bondNftVault();
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(holder_);
        uint256 callerBefore_ = pairToken.balanceOf(address(this));
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBefore_ = pairToken.balanceOf(feeTo_);

        vm.recordLogs();
        vm.prank(feeTo_);
        detfInfo.sweepDust();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bool refunded_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].topics.length != 3
                || logs_[i_].topics[0] != keccak256("Transfer(address,address,uint256)")
                || logs_[i_].topics[1] != bytes32(uint256(uint160(reserveHook)))
                || logs_[i_].topics[2] != bytes32(uint256(uint160(detf)))) continue;
            address token_ = logs_[i_].emitter;
            if (token_ != address(pairToken) && token_ != se && token_ != detf) continue;
            uint256 amount_ = abi.decode(logs_[i_].data, (uint256));
            if (amount_ == 0) continue;
            refunded_ = true;
            assertGe(IERC20(token_).balanceOf(detf), amount_, "genuine hook refund remains in DETF custody");
            assertEq(IBasicVault(detf).reserveOfToken(token_), IERC20(token_).balanceOf(detf),
                "genuine refund is booked for the next call");
        }
        assertTrue(refunded_, "real basket returns genuine refunds");
        uint256 lpAfterFirst_ = IERC20(reserveHook).balanceOf(holder_);
        assertGt(lpAfterFirst_, lpBefore_, "first call joins the funded basket");
        assertEq(IERC20(detf).totalSupply(), supply_, "first call creates no entitlement");

        // No new funding: the next authorized transaction can use only retained refunds.
        vm.prank(address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()));
        detfInfo.sweepDust();
        assertGt(IERC20(reserveHook).balanceOf(holder_), lpAfterFirst_, "later external call acquires more LP");
        _sweepDustUntilSettled();
        assertEq(IERC20(detf).totalSupply(), supply_, "maintenance creates no entitlement");
        assertEq(pairToken.balanceOf(address(this)), callerBefore_, "no caller payout");
        assertEq(pairToken.balanceOf(feeTo_), feeBefore_, "no fee-recipient payout");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "LP remains in NFT custody");
        _assertNoJoinableDust();
    }

    function _assertRetainedThenSweep() internal {
        uint256 held_ = pairToken.balanceOf(detf);
        assertGe(held_, 5 ether, "ordinary operation retains earlier dust");
        assertEq(IBasicVault(detf).reserveOfToken(address(pairToken)), held_, "ordinary operation books retained dust");
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 lp_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        _sweepDustUntilSettled();
        assertLt(pairToken.balanceOf(detf), held_, "feeTo deploys retained dust");
        assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lp_, "maintenance acquires protocol LP");
        assertEq(IERC20(detf).totalSupply(), supply_, "maintenance creates no DETF entitlement");
        _assertNoJoinableDust();
    }

    function checkResiduals() external view {
        _assertNoJoinableDust();
    }
}
