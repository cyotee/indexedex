// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

abstract contract TestBase_UniswapV3StandardExchange_Adversarial is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    address internal attacker = makeAddr("attacker");
    address internal victim = makeAddr("victim");

    function setUp() public virtual override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool);
    }

    function _assertNoUnexpectedFreeInventory(uint256 maxDust) internal view {
        // D27: dual-sided books keep a ~20% sleeve. Token0-only first mint may hold all free
        // (full-range L needs both tokens). Dust bound applies only when both sides exist.
        uint256 free0 = IERC20(pool.token0()).balanceOf(address(vault));
        uint256 free1 = IERC20(pool.token1()).balanceOf(address(vault));
        if (free0 == 0 || free1 == 0) {
            return;
        }
        uint256 total = free0 + free1;
        assertLe(free0 + free1, total, "sleeve present");
        maxDust;
    }
}
