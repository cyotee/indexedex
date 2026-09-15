// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {StandardExchangePreservedBehavior} from "./StandardExchangePreservedBehavior.sol";
import {StandardExchangeMarketTrader} from "./StandardExchangeMarketTrader.sol";
import {TestBase_UniswapV4StandardExchange} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

contract UniswapV4StandardExchange_PreservedBaseline is TestBase_UniswapV4StandardExchange, StandardExchangePreservedBehavior {
    StandardExchangeMarketTrader internal trader;
    PoolKey internal market;
    function setUp() public override {
        super.setUp();
        address a = address(new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0));
        address b = address(new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        market = PoolKey({currency0: Currency.wrap(address(asset0)), currency1: Currency.wrap(address(asset1)),
            fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))});
        poolManager.initialize(market, uint160(1 << 96));
        subject = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(market));
    }
    function _trade(bool zeroForOne, uint256 amount) internal override {
        _fund(zeroForOne ? asset0 : asset1, address(trader), amount);
        trader.tradeV4(poolManager, market, zeroForOne, amount);
    }
    function _deployed() internal view override returns (uint256, uint256) {
        return IUniswapV4StandardExchangeLiquidReserve(address(subject)).deployedReserve();
    }
    function _rebalance() internal override {
        IUniswapV4StandardExchangeLiquidReserve(address(subject)).rebalanceLiquidReserve();
    }
}
