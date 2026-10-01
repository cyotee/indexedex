// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

import {UniswapV4Detf_Cp_Univ4Se_ProductLaw_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_Decimals.sol";

/// @notice Combo `H6`. pairToken 6-dec; other/rate 6-dec. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6 is UniswapV4Detf_Cp_Univ4Se_ProductLaw_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }

    /// @notice Idle inverse unavailability is not proof; the full-input alignment rejection permits booked retries.
    function test_alignmentResidualRetainedBookedAndRetried() public {
        _bondOn(detf, detfUser, _uPair(100));
        _bondOn(detf, detfUser, _uPair(10));
        IERC20 pair = IERC20(address(pairToken));
        uint256 retained = pair.balanceOf(detf);
        assertGt(retained, 10, "reproducer exceeds native dust floor");
        _assertIdleAlignmentResidual(pair, retained);
        bytes32 before_ = _alignmentResidualState(pair);
        for (uint256 i_; i_ < 2; ++i_) {
            IUniswapV4Detf(detf).sweepDust();
            _assertIdleAlignmentResidual(pair, retained);
            _assertPairResidualBooked(address(pair), se);
            assertEq(_alignmentResidualState(pair), before_, "repeat retention preserves custody, booking and issuance");
        }

        vm.prank(detfUser);
        pair.transfer(detf, 1e6);
        vm.expectCall(se, abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (pair, retained + 1e6, IERC20(se))));
        IUniswapV4Detf(detf).sweepDust();
        assertLe(pair.balanceOf(detf), retained + 1e6, "later sweep retries the full accumulated amount");
        assertEq(IBasicVault(detf).reserveOfToken(address(pair)), pair.balanceOf(detf), "later custody stays booked");
    }

    /// @dev Independently prove both the unsupported idle inverse and the exact full-amount rejection.
    function _assertIdleAlignmentResidual(IERC20 pair_, uint256 retained_) private {
        assertTrue(IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve(se).canOpenPoolManagerUnlock(),
            "proof uses actual idle context");
        assertTrue(IERC165(se).supportsInterface(type(IStandardExchangeExactOutputQuantityQuote).interfaceId),
            "interface exists despite context restriction");
        (bytes memory state_,) = IStandardExchangeTransitionQuote(se).quoteState(address(pair_), address(0));
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", address(pair_), se));
        IStandardExchangeExactOutputQuantityQuote(se).quoteInputForExactShares(state_, 1);
        vm.expectRevert(abi.encodeWithSignature("AlignmentNotAchievable()"));
        IStandardExchangeIn(se).previewExchangeIn(pair_, retained_, IERC20(se));
        assertEq(pair_.balanceOf(detf), retained_, "full residual remains in custody");
        assertEq(IBasicVault(detf).reserveOfToken(address(pair_)), retained_, "full residual remains booked");
    }

    /// @dev Sweep retries cannot mint SE, hook LP or DETF, or move retained pair backing.
    function _alignmentResidualState(IERC20 pair_) private view returns (bytes32) {
        return keccak256(abi.encode(
            pair_.balanceOf(detf), IBasicVault(detf).reserveOfToken(address(pair_)),
            pair_.balanceOf(se), pair_.balanceOf(reserveHook), IERC20(se).totalSupply(),
            IERC20(se).balanceOf(reserveHook), IERC20(reserveHook).totalSupply(),
            IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), IERC20(detf).totalSupply()
        ));
    }
}
