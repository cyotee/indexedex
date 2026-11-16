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
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

abstract contract TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial is TestBase_UniswapV3FullSpreadStandardExchangeVault, StandardExchangeFullSpreadAdversarialBehavior {
    StandardExchangeMarketTrader internal trader;
    IUniswapV3Pool internal market;
    function setUp() public virtual override {
        super.setUp();
        address a = address(new DeliveryTestToken("Asset A", "A", 18, address(this), 0));
        address b = address(new DeliveryTestToken("Asset B", "B", 18, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        trader = new StandardExchangeMarketTrader();
        market = _createPoolOneToOne(a, b, FEE_MEDIUM);
        subject = _deployVault(market);
        lockedCaller = new StandardExchangeLockedCaller(address(market), false);
    }
    function _trade(bool zeroForOne, uint256 amount) internal override {
        _fund(zeroForOne ? asset0 : asset1, address(trader), amount);
        trader.tradeV3(market, zeroForOne, amount);
    }
    function _deployed() internal view override returns (uint256, uint256) {
        return IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve(address(subject)).deployedReserve();
    }
    function _rebalance() internal override {
        IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve(address(subject)).rebalanceLiquidReserve();
    }
    function _family() internal pure override returns (string memory) { return "UniswapV3"; }
    function _disable(bool disabled, bool packageWide) internal override {
        vm.prank(owner);
        if (packageWide) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(uniswapV3StandardExchangeDFPkg), disabled);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(subject), disabled);
    }
    function _configureSleeve(uint256 pct) internal override {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(subject), pct);
    }
    function _seedMarket() internal override {
        FullSpreadLiquidityProvider provider = new FullSpreadLiquidityProvider();
        _fund(asset0, address(provider), 100_000 ether);
        _fund(asset1, address(provider), 100_000 ether);
        provider.addV3(market, 50_000 ether);
    }
    function _setDecimalFixture(uint8 da, uint8 db, bool failing) internal override {
        address a = failing ? address(new FullSpreadRevertingMetadataToken()) : address(new DeliveryTestToken("Decimal A", "DA", da, address(this), 0));
        address b = address(new DeliveryTestToken("Decimal B", "DB", db, address(this), 0));
        (asset0, asset1) = a < b ? (IERC20(a), IERC20(b)) : (IERC20(b), IERC20(a));
        market = _createPoolOneToOne(a, b, FEE_MEDIUM);
        subject = _deployVault(market);
        lockedCaller = new StandardExchangeLockedCaller(address(market), false);
    }
}
