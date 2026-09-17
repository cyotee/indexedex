// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {StandardExchangeLockedCaller} from "../remediation/StandardExchangeLockedCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {StandardExchangeFullSpreadAdversarialBehavior, FullSpreadLiquidityProvider, FullSpreadRevertingMetadataToken} from "./StandardExchangeFullSpreadAdversarialBehavior.sol";
import {StandardExchangeMarketTrader} from "../remediation/StandardExchangeMarketTrader.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

abstract contract TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial is TestBase_UniswapV4FullSpreadStandardExchangeVault, StandardExchangeFullSpreadAdversarialBehavior {
    StandardExchangeMarketTrader internal trader;
    PoolKey internal market;
    function setUp() public virtual override {
        super.setUp();
        address a = _nativeFixture() ? address(weth) : address(new DeliveryTestToken("Asset A", "A", 18, address(this), 0));
        address b = address(new DeliveryTestToken("Asset B", "B", 18, address(this), 0));
        (asset0, asset1) = _nativeFixture() ? (IERC20(a), IERC20(b)) : a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        if (_nativeFixture()) trader.setNativeWeth(weth);
        market = PoolKey({currency0: Currency.wrap(_nativeFixture() ? address(0) : address(asset0)), currency1: Currency.wrap(address(asset1)),
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
        return IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve(address(subject)).deployedReserve();
    }
    function _rebalance() internal override {
        IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve(address(subject)).rebalanceLiquidReserve();
    }
    function _family() internal pure override returns (string memory) { return "UniswapV4"; }
    function _disable(bool disabled, bool packageWide) internal override {
        vm.prank(owner);
        if (packageWide) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(uniswapV4StandardExchangeDFPkg), disabled);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(subject), disabled);
    }
    function _configureSleeve(uint256 pct) internal override {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(subject), pct);
    }
    function _nativeFixture() internal pure virtual returns (bool) { return false; }
    function _fund(IERC20 token, address recipient, uint256 amount) internal override {
        if (address(token) == address(weth)) {
            vm.deal(address(this), address(this).balance + amount);
            weth.deposit{value: amount}();
            if (recipient != address(this)) token.transfer(recipient, amount);
        } else super._fund(token, recipient, amount);
    }
    function _seedMarket() internal override {
        FullSpreadLiquidityProvider provider = new FullSpreadLiquidityProvider();
        _fund(asset0, address(provider), 100_000 ether);
        _fund(asset1, address(provider), 100_000 ether);
        provider.addV4(poolManager, market, weth, 50_000 ether);
    }
    function _setDecimalFixture(uint8 da, uint8 db, bool failing) internal override {
        address a = failing ? address(new FullSpreadRevertingMetadataToken()) : address(new DeliveryTestToken("Decimal A", "DA", da, address(this), 0));
        address b = address(new DeliveryTestToken("Decimal B", "DB", db, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        market = PoolKey({currency0: Currency.wrap(address(asset0)), currency1: Currency.wrap(address(asset1)), fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))});
        poolManager.initialize(market, uint160(1 << 96));
        subject = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(market));
        lockedCaller = new StandardExchangeLockedCaller(address(poolManager), true);
    }
}
