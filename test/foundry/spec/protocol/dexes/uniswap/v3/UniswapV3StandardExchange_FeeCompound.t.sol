// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

/// @notice Fee-first compound / non-dilution (A3-class happy path).
contract UniswapV3StandardExchange_FeeCompound_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    address internal incumbent = makeAddr("incumbent");
    address internal attacker = makeAddr("attacker");

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool, DEFAULT_WIDTH_MULTIPLIER);
    }

    function test_feeFirst_subsequentTinyZap_doesNotDiluteIncumbentIntoFees() public {
        address token0 = pool.token0();
        uint256 large = 200 ether;
        ERC20PermitMintableStub(token0).mint(incumbent, large);
        ERC20PermitMintableStub(token0).mint(attacker, 1 ether);

        vm.startPrank(incumbent);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 incumbentShares =
            vault.exchangeIn(IERC20(token0), large, IERC20(address(vault)), 0, incumbent, false, block.timestamp + 1);
        vm.stopPrank();

        // Accrue Uni fees against managed liquidity.
        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);

        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        assertEq(supplyBefore, incumbentShares);

        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 attackerShares =
            vault.exchangeIn(IERC20(token0), 1 ether, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();

        // Attacker receives only shares for own principal — not all of accrued fee value.
        assertLt(attackerShares, incumbentShares / 10, "attacker not fee-diluting");
        assertEq(IERC20(address(vault)).balanceOf(incumbent), incumbentShares, "incumbent shares unchanged");

        // Free residual inventory on success: vault may hold dust; must not hold large idle principal.
        uint256 free0 = IERC20(pool.token0()).balanceOf(address(vault));
        uint256 free1 = IERC20(pool.token1()).balanceOf(address(vault));
        assertLt(free0 + free1, 1 ether, "residual free inventory policy");
    }
}
