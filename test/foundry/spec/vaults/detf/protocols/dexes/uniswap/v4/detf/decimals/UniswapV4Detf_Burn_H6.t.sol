// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {UniswapV4DetfRepo} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

import {
    UniswapV4Detf_Burn_Decimals
} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Burn_Decimals.sol";

/// @notice Combo `H6`. pairToken 6-dec mint/bond input; other/rate role 6-dec.
/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible. Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role.
contract UniswapV4Detf_Burn_H6 is UniswapV4Detf_Burn_Decimals {
    uint256 private smallBondId;

    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function test_smallPrimaryBurn_zeroOutputRevertsAtomically() public {
        uint256 amount_ = _prepareSmallBurn();
        assertEq(amount_, 1, "one native DETF unit");
        bytes32 before_ = _burnCustodySnapshot();
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        vm.prank(detfUser);
        _burn(amount_, 0);
        assertEq(_burnCustodySnapshot(), before_, "failed burn preserves supply and custody");
    }

    function test_smallPrimaryBurn_positiveMinimumRevertsAtomically() public {
        uint256 amount_ = _prepareSmallBurn();
        bytes32 before_ = _burnCustodySnapshot();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, 1, 0));
        vm.prank(detfUser);
        _burn(amount_, 1);
        assertEq(_burnCustodySnapshot(), before_);
    }

    function test_smallPrimaryBurn_firstPayableBoundary() public {
        _prepareSmallBurn();
        uint256 first_ = _firstPayableBurn();
        bytes32 before_ = _burnCustodySnapshot();
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        vm.prank(detfUser);
        _burn(first_ - 1, 0);
        assertEq(_burnCustodySnapshot(), before_);
        _assertPaidBurn(first_);
    }

    function testFuzz_smallPrimaryBurn_payablePartialExit(uint256 seed_) public {
        _prepareSmallBurn();
        uint256 amount_ = bound(seed_, _firstPayableBurn(), IERC20(detf).balanceOf(detfUser) / 2);
        _assertPaidBurn(amount_);
    }

    function test_smallPrimaryBurn_fullExit() public {
        _prepareSmallBurn();
        _assertPaidBurn(IERC20(detf).balanceOf(detfUser));
        assertEq(IERC20(detf).balanceOf(detfUser), 0, "full user exit");
    }

    function test_smallFallbackBurn_zeroOutputRevertsAtomically() public {
        _prepareFallbackBurn();
        assertEq(_preview(1), 0, "one native unit cannot buy a pair unit");
        bytes32 before_ = _burnCustodySnapshot();
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        vm.prank(detfUser);
        _burn(1, 0);
        assertEq(_burnCustodySnapshot(), before_);
    }

    function test_smallFallbackBurn_firstPayableAndFullExit() public {
        _prepareFallbackBurn();
        uint256 first_ = _firstPayableBurn();
        bytes32 before_ = _burnCustodySnapshot();
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        vm.prank(detfUser);
        _burn(first_ - 1, 0);
        assertEq(_burnCustodySnapshot(), before_);
        _assertPaidFallback(first_);
        _assertPaidFallback(IERC20(detf).balanceOf(detfUser));
        assertEq(IERC20(detf).balanceOf(detfUser), 0);
    }

    function test_smallPrimaryBurn_rawSYFailurePreservesShares() public {
        uint256 amount_ = _prepareSmallBurn();
        IStandardizedYield sy_ = IStandardizedYield(IDETFStandardizedYield(detf).rawSY());
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(sy_), amount_);
        uint256 shares_ = sy_.deposit(detfUser, detf, amount_, amount_);
        vm.stopPrank();
        bytes32 before_ = _burnCustodySnapshot();
        uint256 supply_ = sy_.totalSupply();
        uint256 backing_ = IERC20(detf).balanceOf(address(sy_));
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        vm.prank(detfUser);
        sy_.redeem(detfUser, shares_, address(pairToken), 0, false);
        assertEq(sy_.balanceOf(detfUser), shares_);
        assertEq(sy_.totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(sy_)), backing_);
        assertEq(_burnCustodySnapshot(), before_);
    }

    function test_smallPrimaryBurn_composedUnstakeFailurePreservesGons() public {
        uint256 amount_ = _prepareSmallBurn();
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(staking_), amount_);
        staking_.exchangeIn(IERC20(detf), amount_, IERC20(address(staking_)), amount_, detfUser, false, block.timestamp);
        staking_.approve(detf, amount_);
        vm.stopPrank();
        bytes32 before_ = _burnCustodySnapshot();
        uint256 gons_ = staking_.gonsOf(detfUser);
        bytes32 state_ = keccak256(abi.encode(staking_.stakingState()));
        vm.expectRevert(UniswapV4DetfRepo.ZeroAmount.selector);
        vm.prank(detfUser);
        IStandardExchangeIn(detf)
            .exchangeIn(
                IERC20(address(staking_)), amount_, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp
            );
        assertEq(staking_.gonsOf(detfUser), gons_);
        assertEq(keccak256(abi.encode(staking_.stakingState())), state_);
        assertEq(_burnCustodySnapshot(), before_);
    }

    function _prepareSmallBurn() private returns (uint256 amount_) {
        (smallBondId,) = _firstBond(_uPair(100));
        IStandardExchangeIn exchange_ = IStandardExchangeIn(detf);
        vm.prank(detfUser);
        exchange_.exchangeIn(IERC20(address(pairToken)), _uPair(20), IERC20(detf), 1, detfUser, false, block.timestamp);
        assertTrue(detfInfo.isBurningAllowed(IERC20(address(pairToken))), "primary burn selected");
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 lp_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        amount_ = (supply_ + lp_ - 1) / lp_;
        assertGt(amount_ * lp_ / supply_, 0, "existing LP guard passes");
        assertEq(
            exchange_.previewExchangeIn(IERC20(detf), amount_, IERC20(address(pairToken))),
            0,
            "final asset rounds to zero"
        );
        vm.prank(detfUser);
        IERC20(detf).approve(detf, type(uint256).max);
    }

    function _prepareFallbackBurn() private {
        IUniswapV4Detf.PkgArgs memory args_ = _defaultDetfArgs();
        args_.name = "Small fallback DETF";
        args_.mintThreshold = 100e18;
        args_.burnThreshold = 1;
        detf = _deployHookThenDetf(args_);
        detfInfo = IUniswapV4Detf(detf);
        vm.prank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        (smallBondId,) = _firstBond(_uPair(100));
        vm.startPrank(detfUser);
        IStandardExchangeIn(detf)
            .exchangeIn(IERC20(address(pairToken)), _uPair(20), IERC20(detf), 1, detfUser, false, block.timestamp);
        IERC20(detf).approve(detf, type(uint256).max);
        vm.stopPrank();
        assertFalse(detfInfo.isBurningAllowed(IERC20(address(pairToken))), "reserve swap selected");
    }

    function _firstPayableBurn() private view returns (uint256 high_) {
        uint256 low_;
        high_ = IERC20(detf).balanceOf(detfUser) / 2;
        assertGt(_preview(high_), 0);
        while (high_ - low_ > 1) {
            uint256 mid_ = low_ + (high_ - low_) / 2;
            if (_preview(mid_) == 0) low_ = mid_;
            else high_ = mid_;
        }
        assertEq(_preview(high_ - 1), 0);
    }

    function _preview(uint256 amount_) private view returns (uint256) {
        return IStandardExchangeIn(detf).previewExchangeIn(IERC20(detf), amount_, IERC20(address(pairToken)));
    }

    function _burn(uint256 amount_, uint256 minimum_) private returns (uint256) {
        return IStandardExchangeIn(detf)
            .exchangeIn(IERC20(detf), amount_, IERC20(address(pairToken)), minimum_, detfUser, false, block.timestamp);
    }

    function _assertPaidBurn(uint256 amount_) private {
        uint256 quoted_ = _preview(amount_);
        uint256 before_ = IERC20(address(pairToken)).balanceOf(detfUser);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        assertEq(_burn(amount_, quoted_), quoted_);
        assertGt(quoted_, 0);
        assertEq(IERC20(address(pairToken)).balanceOf(detfUser) - before_, quoted_);
        assertEq(IERC20(detf).totalSupply(), supply_ - amount_);
    }

    function _assertPaidFallback(uint256 amount_) private {
        uint256 quoted_ = _preview(amount_);
        uint256 before_ = IERC20(address(pairToken)).balanceOf(detfUser);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        assertEq(_burn(amount_, quoted_), quoted_);
        assertGt(quoted_, 0);
        assertEq(IERC20(address(pairToken)).balanceOf(detfUser) - before_, quoted_);
        assertEq(IERC20(detf).totalSupply(), supply_, "fallback preserves DETF supply");
    }

    function _burnCustodySnapshot() private view returns (bytes32) {
        bytes32 balances_ = keccak256(
            abi.encode(
                IERC20(detf).totalSupply(),
                IERC20(detf).balanceOf(detfUser),
                IERC20(detf).balanceOf(detf),
                IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()),
                IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()),
                IERC20(reserveHook).balanceOf(detf),
                IERC20(address(pairToken)).balanceOf(detfUser),
                IERC20(address(pairToken)).balanceOf(detf)
            )
        );
        return keccak256(
            abi.encode(
                balances_,
                IStakedDETF(detfInfo.rebasingClaimToken()).stakingState(),
                IDetfBondNFT(detfInfo.bondNftVault()).positionOf(smallBondId)
            )
        );
    }
}
