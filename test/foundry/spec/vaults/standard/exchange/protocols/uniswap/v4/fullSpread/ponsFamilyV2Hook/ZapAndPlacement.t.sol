// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {UniswapV4FullSpreadPonsFamilyHookCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance[]
abstract contract UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance is Acceptance {
    function test_decimalBootstrapAndBothCompositionDirections() public {
        uint256 shares = _bootstrap();
        uint256 minimum = 10 ** ((uint256(_decimalsA()) + _decimalsB()) / 2 - 3);
        assertEq(shares, Math.sqrt(1_000 * unit0 * 1_000 * unit1) - minimum);
        assertEq(vault.balanceOf(address(0xdEaD)), minimum);
        for (uint256 i; i < 2; ++i) {
            IERC20 input = i == 0 ? token0 : token1;
            uint256 amount = i == 0 ? unit0 : unit1;
            uint256 quote = vault.previewExchangeIn(input, amount, IERC20(address(vault)));
            assertGt(quote, 0);
            assertEq(vault.exchangeIn(input, amount, IERC20(address(vault)), quote, address(this), false, block.timestamp), quote);
            _assertBooked();
        }
    }

    function test_oneRawUnitDoesNotBypassRelativeAlignment() public {
        _bootstrap();
        uint256 balance = token0.balanceOf(address(this));
        vm.expectRevert(Common.AlignmentNotAchievable.selector);
        vault.exchangeIn(token0, 1, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        assertEq(token0.balanceOf(address(this)), balance);
        _assertBooked();
    }
}

contract UniswapV4FullSpreadPonsFamilyHookDecimalH6Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalH9Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsA() internal pure override returns (uint8) { return 9; }
    function _decimalsB() internal pure override returns (uint8) { return 9; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalP6R9Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 9; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalP6R18Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalP9R6Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsA() internal pure override returns (uint8) { return 9; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalP9R18Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsA() internal pure override returns (uint8) { return 9; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalP18R6Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsB() internal pure override returns (uint8) { return 6; }
}
contract UniswapV4FullSpreadPonsFamilyHookDecimalP18R9Test is UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance {
    function _decimalsB() internal pure override returns (uint8) { return 9; }
}
// end::UniswapV4FullSpreadPonsFamilyHookDecimalAcceptance[]
