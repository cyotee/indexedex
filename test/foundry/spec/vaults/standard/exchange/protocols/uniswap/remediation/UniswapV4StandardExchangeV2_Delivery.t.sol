// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StandardExchangeLockedCaller} from "./StandardExchangeLockedCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {DeliveryTestToken} from "./DeliveryTestToken.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {StandardExchangeDeliveryBehavior} from "./StandardExchangeDeliveryBehavior.sol";
import {StandardExchangeMarketTrader} from "./StandardExchangeMarketTrader.sol";
import {TestBase_UniswapV4StandardExchangeV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchangeV2.sol";
import {IUniswapV4StandardExchangeLiquidReserveV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserveV2.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

contract UniswapV4StandardExchangeV2_Delivery is TestBase_UniswapV4StandardExchangeV2, StandardExchangeDeliveryBehavior {
    StandardExchangeMarketTrader internal trader;
    PoolKey internal market;
    function setUp() public override {
        super.setUp();
        address a = address(new DeliveryTestToken("Asset A", "A", 18, address(this), 0));
        address b = address(new DeliveryTestToken("Asset B", "B", 18, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        market = PoolKey({currency0: Currency.wrap(address(asset0)), currency1: Currency.wrap(address(asset1)),
            fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))});
        poolManager.initialize(market, uint160(1 << 96));
        subject = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(market));
        lockedCaller = new StandardExchangeLockedCaller(address(poolManager), true);
    }
    function _trade(bool zeroForOne, uint256 amount) internal override {
        _fund(zeroForOne ? asset0 : asset1, address(trader), amount);
        trader.tradeV4(poolManager, market, zeroForOne, amount);
    }
    function _deployed() internal view override returns (uint256, uint256) {
        return IUniswapV4StandardExchangeLiquidReserveV2(address(subject)).deployedReserve();
    }
    function _rebalance() internal override {
        IUniswapV4StandardExchangeLiquidReserveV2(address(subject)).rebalanceLiquidReserve();
    }
}
