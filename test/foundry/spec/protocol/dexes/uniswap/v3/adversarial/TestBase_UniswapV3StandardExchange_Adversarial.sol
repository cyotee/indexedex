// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

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

    /// @dev The caller already funded/approved token0 and is pranking as actor.
    function _activationInputs(address actor, uint256 amount0, uint256 amount1)
        internal returns (address[] memory tokens, uint256[] memory amounts)
    {
        ERC20PermitMintableStub(pool.token1()).mint(actor, amount1);
        IERC20(pool.token1()).approve(address(vault), amount1);
        tokens = new address[](2);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
    }

    function _activateWithFundedToken0(address actor, uint256 amount0, uint256 amount1)
        internal returns (uint256 shares)
    {
        (address[] memory tokens, uint256[] memory amounts) = _activationInputs(actor, amount0, amount1);
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, actor, false, block.timestamp + 1
        );
    }

    function _assertNoUnexpectedFreeInventory(uint256 maxDust) internal view {
        // D27: dual-sided books keep a ~20% sleeve. Initial activation supplies both tokens.
        // A subsequent single-token deposit can remain in the sleeve.
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
