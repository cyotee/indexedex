// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

/// @notice V3-ACC-02/03: mixed token decimals never scale the raw-liquidity share basis or floor.
contract UniswapV3FullSpreadStandardExchangeVault_Decimals is FullSpreadReleaseFixture {
    function test_decimals6and18() public { _exercise(6, 18, false); }
    function test_decimals9and18() public { _exercise(9, 18, true); }
    function test_decimals6and6() public { _exercise(6, 6, false); }
    function testFuzz_decimalDirections(bool side, uint8 variant) public {
        uint8[3] memory a = [uint8(6), 9, 6];
        uint8[3] memory b = [uint8(18), 18, 6];
        _exercise(a[variant % 3], b[variant % 3], side);
    }
    function _exercise(uint8 da, uint8 db, bool side) private {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("A", "A", da, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", db, address(this), 0);
        (token0, token1) = address(a) < address(b) ? (IERC20(address(a)), IERC20(address(b))) : (IERC20(address(b)), IERC20(address(a)));
        uint256 unit0 = 10 ** IERC20Metadata(address(token0)).decimals();
        uint256 unit1 = 10 ** IERC20Metadata(address(token1)).decimals();
        pool = IUniswapV3Pool(uniswapV3Factory.createPool(address(a), address(b), FEE_MEDIUM));
        uint256 ratio = FixedPointMathLib.sqrt(unit1 * 1e18 / unit0);
        pool.initialize(uint160(ratio * (uint256(1) << 96) / 1e9));
        // Raw liquidity must fit the fixture's token funding at a decimal-adjusted sqrt price.
        _seedExternalLiquidity(pool, 1e18);
        vault = _deployVault(pool);
        uint256 shares = _join(1000 * unit0, 1000 * unit1);
        assertEq(shares, uint256(_liquidity()) - 1000);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.totalSupply(), uint256(_liquidity()));
        assertEq(IERC20Metadata(address(vault)).decimals(), 18);

        IERC20 input = side ? token1 : token0;
        IERC20 output = side ? token0 : token1;
        uint256 unit = side ? unit1 : unit0;
        _externalSwapExactIn(pool, !side, 10 * unit);
        uint256 supply = vault.totalSupply();
        bytes32 beforeState = _state(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        vault.exchangeIn(input, unit, IERC20(address(vault)), 1, address(this), true, block.timestamp);
        assertEq(_state(address(this)), beforeState, "unfunded pretransfer cannot spend fees");
        (uint256 quote,) = vault.previewExchangeIn(input, unit, IERC20(address(vault)));
        uint128 beforeLiquidity = _liquidity();
        (uint160 beforePrice,,,,,,) = pool.slot0();
        _fund(input, address(vault), unit);
        (uint256 minted, uint256 refund) = vault.exchangeIn(input, unit, IERC20(address(vault)), quote, address(this), true, block.timestamp);
        assertEq(minted, quote);
        assertEq(vault.totalSupply(), supply + minted);
        if (quote == 0) {
            // V3-ACC-05: integer liquidity may not consume every high-decimal output unit.
            assertEq(refund, unit);
            assertEq(_liquidity(), beforeLiquidity);
            (uint160 afterPrice,,,,,,) = pool.slot0();
            assertEq(afterPrice, beforePrice);
            _assertReserves();
            return;
        }
        (uint256 exitQuote,) = vault.previewExchangeIn(IERC20(address(vault)), minted, output);
        uint256 beforeOutput = output.balanceOf(alice);
        (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), minted, output, exitQuote, alice, false, block.timestamp);
        assertEq(paid, exitQuote);
        assertEq(output.balanceOf(alice) - beforeOutput, paid);
        assertEq(vault.totalSupply(), supply);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertLe(refund, unit);
        _assertReserves();
    }
}
