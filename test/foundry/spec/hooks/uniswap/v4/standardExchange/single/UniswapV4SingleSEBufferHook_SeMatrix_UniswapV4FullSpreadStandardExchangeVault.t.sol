// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × UniswapV4FullSpreadStandardExchangeVault.
/// @dev Run every gold row against production. D69's allowance and current-state quote
///      corrections supersede the former log-only INCOMPATIBLE markers.
contract UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function test_row_partialConsumption_bookedNotRefunded() public override {
        assertGt(_wrapExactIn(_f(1)), 0);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(user);
        _assertHookFlat();
    }
    function test_row_ammCallerFundSeparation() public override {
        assertGt(_wrapExactIn(_f(1)), 0);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(user);
        _assertHookFlat();
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        bytes memory reason = SeMatrix_FullSpreadV4Fixture(address(fx)).domainReason(face);
        vm.expectRevert(reason);
        buffer.previewUnwrapExactOut(_f(1));
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterExactOutRejected(address(swapRouter), poolKey, seUT, face);
        _assertHookFlat();
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        bytes memory reason = SeMatrix_FullSpreadV4Fixture(address(fx)).domainReason(seUT);
        vm.expectRevert(reason);
        buffer.previewWrapExactOut(1e12);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterExactOutRejected(address(swapRouter), poolKey, face, seUT);
        _assertHookFlat();
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        uint256 sharesBefore = IERC20(seUT).balanceOf(user);
        uint256 minted = _wrapExactIn(_f(1));
        assertEq(IERC20(seUT).balanceOf(user), sharesBefore + minted);
        uint256 supply = IERC20(seUT).totalSupply();
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256 paid = _unwrapExactIn(minted / 2);
        assertEq(IERC20(face).balanceOf(user), faceBefore + paid);
        assertEq(IERC20(seUT).totalSupply(), supply - minted / 2);
        test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed();
        test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly();
        _assertHookFlat();
    }
    function test_row_previewMatchesExecution() public override {
        uint256 quote = buffer.previewWrap(_f(1));
        assertEq(quote, IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), _f(1), IERC20(seUT)));
        uint256 shares = _wrapExactIn(_f(1));
        assertEq(shares, quote);
        uint256 payout = buffer.previewUnwrap(shares);
        assertEq(_unwrapExactIn(shares), payout);
        test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed();
        test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly();
        _assertHookFlat();
    }

}
