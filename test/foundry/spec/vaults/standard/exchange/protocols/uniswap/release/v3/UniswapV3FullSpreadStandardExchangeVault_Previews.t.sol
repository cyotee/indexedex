// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @notice V3-ACC-03/05/12/17/19: preview words describe the executable operation.
contract UniswapV3FullSpreadStandardExchangeVault_Previews_Test is FullSpreadReleaseFixture {
    function _passPreview(bool zeroForOne) internal {
        IERC20 input = zeroForOne ? token0 : token1;
        IERC20 output = zeroForOne ? token1 : token0;
        _fund(input, address(this), 5 ether);
        input.approve(address(vault), 5 ether);
        (uint256 quoted, uint256 refundQuote) = vault.previewExchangeIn(input, 5 ether, output);
        uint256 beforeOutput = output.balanceOf(address(this));
        (uint256 paid, uint256 refund) = vault.exchangeIn(input, 5 ether, output, quoted, address(this), false, block.timestamp);
        assertGt(quoted, 0);
        assertEq(paid, quoted);
        assertEq(output.balanceOf(address(this)) - beforeOutput, paid);
        assertEq(refund, refundQuote);
        assertEq(vault.totalSupply(), 0);
    }
    function test_P_IN_01_exactIn_token0_to_token1() public { _passPreview(true); }
    function test_P_IN_02_exactIn_token1_to_token0() public { _passPreview(false); }

    function _genesisPreview(IERC20 input) internal {
        (uint256 quoted,) = vault.previewExchangeIn(input, 50 ether, IERC20(address(vault)));
        assertGt(quoted, 0, "external pool liquidity admits the 49% genesis plan");
        uint256 beforeInput = input.balanceOf(address(this));
        (uint256 issued, uint256 refund) = _mintOne(input, 50 ether, alice);
        assertEq(issued, quoted);
        assertEq(vault.balanceOf(alice), quoted);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.totalSupply(), quoted + 1000);
        assertEq(input.balanceOf(address(this)) - beforeInput, refund);
    }
    function test_P_IN_03_singleToken0Activation_matchesPlan() public { _genesisPreview(token0); }
    function test_P_IN_04_singleToken1Activation_matchesPlan() public { _genesisPreview(token1); }

    function test_P_IN_05_zapIn_subsequent_afterFees() public {
        _join(100 ether, 100 ether);
        _externalSwapExactIn(pool, true, 20_000 ether);
        _externalSwapExactIn(pool, false, 20_000 ether);
        (uint256 quoted,) = vault.previewExchangeIn(token0, 10 ether, IERC20(address(vault)));
        (uint256 issued,) = _mintOne(token0, 10 ether, alice);
        assertGt(quoted, 0);
        assertEq(issued, quoted, "one planner gives exact net-share parity after fees");
        assertEq(vault.balanceOf(alice), issued);
        _assertReserves();
    }

    function _exactOutPreview(IERC20 input, IERC20 output) internal {
        assertEq(vault.previewExchangeOut(input, output, 1 ether), 0);
        bytes32 beforeState = _state(alice);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        vault.exchangeOut(input, 100 ether, output, 1 ether, alice, false, block.timestamp);
        assertEq(_state(alice), beforeState);
    }
    function test_P_OUT_01_exactOut_token0_to_token1_unavailable() public { _exactOutPreview(token0, token1); }
    function test_P_OUT_02_exactOut_token1_to_token0_unavailable() public { _exactOutPreview(token1, token0); }

    function test_P_OUT_03_04_zapOut_bothTokens() public {
        _join(100 ether, 100 ether);
        for (uint256 i; i < 2; ++i) {
            IERC20 output = i == 0 ? token0 : token1;
            uint256 shares = vault.balanceOf(address(this)) / 4;
            (uint256 quote,) = vault.previewExchangeIn(IERC20(address(vault)), shares, output);
            uint256 beforeOutput = output.balanceOf(alice);
            uint256 supply = vault.totalSupply();
            (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), shares, output, quote, alice, false, block.timestamp);
            assertGt(quote, 0);
            assertEq(paid, quote);
            assertEq(output.balanceOf(alice) - beforeOutput, quote);
            assertEq(vault.totalSupply(), supply - shares);
        }
    }

    function test_P_PRE_01_pretransferred_exactIn() public {
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        _fund(token0, address(this), 3 ether);
        token0.approve(address(wallet), 3 ether);
        (uint256 quoted,) = vault.previewExchangeIn(token0, 3 ether, token1);
        bytes memory result = wallet.consumePretransfer(token0, address(this), address(vault), 3 ether,
            abi.encodeCall(IStandardExchangeIn.exchangeIn,
                (token0, uint256(3 ether), token1, quoted, address(wallet), true, block.timestamp)));
        (uint256 paid, uint256 refund) = abi.decode(result, (uint256, uint256));
        assertEq(paid, quoted);
        assertEq(token1.balanceOf(address(wallet)), paid);
        assertEq(token0.balanceOf(address(wallet)), refund);
    }
}
