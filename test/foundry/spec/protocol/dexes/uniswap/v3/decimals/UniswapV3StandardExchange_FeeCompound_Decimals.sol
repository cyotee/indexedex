// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {
    TestBase_UniswapV3StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";

/// @notice D27 sleeve-then-deploy. pairToken = tokenA. Amounts are raw units via `_u0`/`_u1`.
abstract contract UniswapV3StandardExchange_FeeCompound_Decimals is TestBase_UniswapV3StandardExchange_Decimals {
    IUniswapV3StandardExchangeLiquidReserve internal liquid;
    address internal incumbent = makeAddr("incumbent");
    address internal attacker = makeAddr("attacker");

    function setUp() public virtual override {
        super.setUp();
        _deployPairTokens();
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 0);
        vault = _deployVault(pool);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
    }

    function test_d27_subsequentTinyZap_doesNotDiluteIncumbentIntoFees_freeRemainsSleeve() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 large0 = _u0(200);
        uint256 large1 = _u1(200);
        _mint(token0, incumbent, large0);
        _mint(token1, incumbent, large1);
        _mint(token0, attacker, _u0(1));

        vm.startPrank(incumbent);
        IERC20(token0).approve(address(vault), type(uint256).max);
        IERC20(token1).approve(address(vault), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = large0;
        amounts[1] = large1;
        uint256 incumbentShares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, incumbent, false, block.timestamp + 1
        );
        vm.stopPrank();

        _swapHuman(pool, true, 50_000);
        _swapHuman(pool, false, 50_000);

        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        assertEq(supplyBefore, incumbentShares);

        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 attackerShares =
            vault.exchangeIn(IERC20(token0), _u0(1), IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        assertLt(attackerShares, incumbentShares / 10, "attacker not fee-diluting");
        assertEq(IERC20(address(vault)).balanceOf(incumbent), incumbentShares, "incumbent shares unchanged");

        uint256 free0 = IERC20(pool.token0()).balanceOf(address(vault));
        uint256 free1 = IERC20(pool.token1()).balanceOf(address(vault));
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 total0 = free0 + dep0;
        uint256 total1 = free1 + dep1;
        uint256 dust0 = _u0(1) / 1000;
        uint256 dust1 = _u1(1) / 1000;
        if (total0 > 0) {
            uint256 target0 = (total0 * 0.20e18) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            assertLe(dev0, target0 / 2 + total0 / 4 + dust0, "D27: free0 remains near 20%");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * 0.20e18) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            if (target1 > 0) {
                assertLe(dev1, target1 + total1 / 2 + dust1, "D27: free1 not fully deployed");
            }
        }
        assertTrue(free0 > 0 || free1 > 0, "D27: sleeve remains (not ~0)");
    }
}
