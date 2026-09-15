// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {StandardExchangePreservedBehavior} from "./StandardExchangePreservedBehavior.sol";
import {StandardExchangeMarketTrader} from "./StandardExchangeMarketTrader.sol";
import {TestBase_UniswapV3StandardExchange} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";
import {IUniswapV3StandardExchangeLiquidReserve} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

contract UniswapV3StandardExchange_PreservedBaseline is TestBase_UniswapV3StandardExchange, StandardExchangePreservedBehavior {
    StandardExchangeMarketTrader internal trader;
    IUniswapV3Pool internal market;
    function setUp() public override {
        super.setUp();
        address a = address(new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0));
        address b = address(new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        market = _createPoolOneToOne(a, b, FEE_MEDIUM);
        subject = _deployVault(market);
    }
    function _trade(bool zeroForOne, uint256 amount) internal override {
        _fund(zeroForOne ? asset0 : asset1, address(trader), amount);
        trader.tradeV3(market, zeroForOne, amount);
    }
    function _deployed() internal view override returns (uint256, uint256) {
        return IUniswapV3StandardExchangeLiquidReserve(address(subject)).deployedReserve();
    }
    function _rebalance() internal override {
        IUniswapV3StandardExchangeLiquidReserve(address(subject)).rebalanceLiquidReserve();
    }
}
