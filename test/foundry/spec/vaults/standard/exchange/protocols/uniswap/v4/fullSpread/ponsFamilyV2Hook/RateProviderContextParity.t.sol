// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as LaunchBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {TestBase_UniswapV4FullSpreadRateContext as RateChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
contract UniswapV4FullSpreadPonsFamilyHookRateProviderContextParityTest is Launch, RateChecks {
    function setUp() public override(LaunchBase) {
        LaunchBase.setUp();
        bool launch0 = Currency.unwrap(graduatedPoolKey.currency0) == launchToken;
        _startRateChecks(ponsSe, poolManager, create3Factory, diamondPackageFactory,
            [launch0 ? uint256(1e16) : uint256(1e10), launch0 ? uint256(1e10) : uint256(1e16)]);
    }
    function _rateBootstrap() internal override {
        _activatePonsSe(); _wrapWeth(address(this), 1 ether);
        // The launch activation helper intentionally approves exact bootstrap amounts.
        rateTokens[0].approve(address(ponsSe), type(uint256).max);
        rateTokens[1].approve(address(ponsSe), type(uint256).max);
    }
    function _rateBlocked(bytes memory data_) internal override returns (bytes memory) { return _launchBlocked(data_); }
    function _rateZeroSleeve() internal override {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
    }
}
