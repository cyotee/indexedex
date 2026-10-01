// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {UniswapV4Detf_Cp_Univ4Se_ProductLaw_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_Decimals.sol";

/// @notice Combo `P18_R6`. pairToken 18-dec; other/rate 6-dec. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6 is UniswapV4Detf_Cp_Univ4Se_ProductLaw_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }

    /// @notice Whole-input SE issuance does not certify CP's selected composition; failed retries retain booked custody.
    function test_T7_10_selectedAlignmentResidual_booked_noIssuance_retry() public {
        test_T7_10_laterBond_joinUnbalanced_unboostedG();
        IERC20 pair_ = IERC20(address(pairToken));
        uint256 retained_ = pair_.balanceOf(detf);
        assertGt(retained_, 10, "exercise above-dust residual");
        _assertSelectedAlignmentResidual(pair_, retained_);
        bytes32 before_ = _selectedResidualState(pair_);
        for (uint256 i_; i_ < 2; ++i_) {
            detfInfo.sweepDust();
            assertEq(pair_.balanceOf(detf), retained_, "failed composition retains entire input");
            _assertSelectedAlignmentResidual(pair_, retained_);
            assertEq(_selectedResidualState(pair_), before_, "retry moves no backing and issues no shares");
        }

        uint256 topUp_ = _uPair(1);
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        assertTrue(pair_.transfer(detf, topUp_), "real holder funds later retry");
        vm.expectCall(se, abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (pair_, retained_ + topUp_, IERC20(se))));
        detfInfo.sweepDust();
        assertLt(pair_.balanceOf(detf), retained_ + topUp_, "funded retry consumes capital");
        assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lpBefore_, "funded retry acquires protocol LP");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "retry issues no DETF");
        _assertPairResidualBooked(address(pair_), se);
    }

    /// @dev Establish the actual mode: unbalanced has zero LP, single-asset rejects with exactly the alignment error.
    function _assertSelectedAlignmentResidual(IERC20 pair_, uint256 retained_) private {
        assertGt(IStandardExchangeIn(se).previewExchangeIn(pair_, retained_, IERC20(se)), 0,
            "whole input can issue SE shares");
        address[] memory tokens_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);
        tokens_[0] = address(pair_);
        amounts_[0] = retained_;
        assertEq(IUniswapV4SeBufferHook(reserveHook).previewJoinUnbalanced(tokens_, amounts_), 0,
            "zero unbalanced LP selects single-asset retry");
        vm.expectRevert(abi.encodeWithSignature("AlignmentNotAchievable()"));
        IUniswapV4SeBufferHook(reserveHook).previewJoinSingleAssetExactIn(address(pair_), retained_);
        assertEq(IBasicVault(detf).reserveOfToken(address(pair_)), retained_, "entire residual booked");
        assertEq(pair_.allowance(detf, reserveHook), 0, "hook allowance cleared");
        assertEq(pair_.allowance(reserveHook, se), 0, "SE allowance cleared");
    }

    /// @dev Include protocol LP custody, DETF and SE supply, and both pair backing balances.
    function _selectedResidualState(IERC20 pair_) private view returns (bytes32) {
        bytes32 custody_ = keccak256(abi.encode(
            IERC20(detf).totalSupply(), IERC20(reserveHook).balanceOf(detf),
            IERC20(reserveHook).balanceOf(detfInfo.bondNftVault())
        ));
        return keccak256(abi.encode(
            custody_, pair_.balanceOf(detf), IBasicVault(detf).reserveOfToken(address(pair_)),
            pair_.balanceOf(se), pair_.balanceOf(reserveHook), IERC20(se).totalSupply(),
            IERC20(se).balanceOf(reserveHook), IERC20(reserveHook).totalSupply()
        ));
    }
}
