// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {StandardExchangeLockedCaller} from "../remediation/StandardExchangeLockedCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {StandardExchangeFullSpreadAdversarialBehavior, FullSpreadLiquidityProvider, FullSpreadRevertingMetadataToken} from "./StandardExchangeFullSpreadAdversarialBehavior.sol";
import {StandardExchangeMarketTrader} from "../remediation/StandardExchangeMarketTrader.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";

/// @notice Existing accounting oracle with controllable external tokens and real pools.
abstract contract TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial is TestBase_UniswapV3FullSpreadAccounting, StandardExchangeFullSpreadAdversarialBehavior {
    StandardExchangeMarketTrader internal trader;
    IUniswapV3Pool internal market;
    function setUp() public virtual override {
        // Initialize the production registry once, then bind the hostile-token market
        // to the existing accounting base's independent liquidity oracle.
        TestBase_UniswapV3FullSpreadStandardExchangeVault.setUp();
        vm.prank(owner); IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        trader = new StandardExchangeMarketTrader(); _setDecimalFixture(18,18,false);
    }
    function _trade(bool side,uint256 amount) internal override {
        _fund(side?asset0:asset1,address(trader),amount); trader.tradeV3(market,side,amount);
    }
    function _deployed() internal view override returns (uint256,uint256) {
        (uint160 price,,,,,,)=market.slot0(); return _amounts(price,_positionLiquidity(),false);
    }
    function _rebalance() internal override {
        // Compatibility hook only; no migrated money path invokes a retired API.
        _retired(abi.encodeWithSignature("rebalanceLiquidReserve()"));
    }
    function _family() internal pure override returns (string memory) { return "UniswapV3"; }
    function _disable(bool disabled,bool packageWide) internal override {
        vm.prank(owner);
        if(packageWide) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(uniswapV3StandardExchangeDFPkg),disabled);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(subject),disabled);
    }
    function _configureSleeve(uint256 pct) internal override {
        vm.prank(owner); IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(subject),pct);
    }
    function _seedMarket() internal override {
        FullSpreadLiquidityProvider provider=new FullSpreadLiquidityProvider();
        _fund(asset0,address(provider),100_000 ether); _fund(asset1,address(provider),100_000 ether); provider.addV3(market,50_000 ether);
    }
    function _setDecimalFixture(uint8 da,uint8 db,bool failing) internal override {
        address a=failing?address(new FullSpreadRevertingMetadataToken()):address(new DeliveryTestToken("Decimal A","DA",da,address(this),0));
        address b=address(new DeliveryTestToken("Decimal B","DB",db,address(this),0));
        market=_createPoolOneToOne(a,b,FEE_MEDIUM); subject=_deployVault(market);
        (asset0,asset1)=a<b?(IERC20(a),IERC20(b)):(IERC20(b),IERC20(a));
        lockedCaller=new StandardExchangeLockedCaller(address(market),false);
        pool=market; vault=subject; token0=ERC20PermitMintableStub(address(asset0)); token1=ERC20PermitMintableStub(address(asset1));
        lower=TickMath.minUsableTick(market.tickSpacing()); upper=TickMath.maxUsableTick(market.tickSpacing());
    }
    function _expectedAddedLiquidity(uint256 a,uint256 b) internal view override returns (uint128) {
        (uint160 price,,,,,,)=market.slot0(); return _expectedLiquidity(price,a,b);
    }
}
