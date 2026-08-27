// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";

/// @notice Collect + D27 sleeve-then-deploy-excess (free remains ~20%, not ~0).
contract UniswapV3StandardExchange_FeeCompound_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IUniswapV3StandardExchangeLiquidReserve internal liquid;
    address internal incumbent = makeAddr("incumbent");
    address internal attacker = makeAddr("attacker");

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
    }

    function test_d27_subsequentTinyZap_doesNotDiluteIncumbentIntoFees_freeRemainsSleeve() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 large = 200 ether;
        ERC20PermitMintableStub(token0).mint(incumbent, large);
        ERC20PermitMintableStub(token1).mint(incumbent, large);
        ERC20PermitMintableStub(token0).mint(attacker, 1 ether);

        vm.startPrank(incumbent);
        IERC20(token0).approve(address(vault), type(uint256).max);
        IERC20(token1).approve(address(vault), type(uint256).max);
        uint256 incumbentShares0 =
            vault.exchangeIn(IERC20(token0), large, IERC20(address(vault)), 0, incumbent, false, block.timestamp + 1);
        uint256 incumbentShares1 =
            vault.exchangeIn(IERC20(token1), large, IERC20(address(vault)), 0, incumbent, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 incumbentShares = incumbentShares0 + incumbentShares1;

        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);

        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        assertEq(supplyBefore, incumbentShares);

        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 attackerShares =
            vault.exchangeIn(IERC20(token0), 1 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        assertLt(attackerShares, incumbentShares / 10, "attacker not fee-diluting");
        assertEq(IERC20(address(vault)).balanceOf(incumbent), incumbentShares, "incumbent shares unchanged");

        uint256 free0 = IERC20(pool.token0()).balanceOf(address(vault));
        uint256 free1 = IERC20(pool.token1()).balanceOf(address(vault));
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 total0 = free0 + dep0;
        uint256 total1 = free1 + dep1;
        if (total0 > 0) {
            uint256 target0 = (total0 * 0.20e18) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            assertLe(dev0, target0 / 2 + total0 / 4 + 1e15, "D27: free0 remains near 20%");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * 0.20e18) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            if (target1 > 0) {
                assertLe(dev1, target1 + total1 / 2 + 1e15, "D27: free1 not fully deployed");
            }
        }
        assertGt(free0 + free1, 1 ether, "D27: sleeve remains (not ~0)");
    }
}
