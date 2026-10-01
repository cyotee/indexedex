// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadRateContext as RateChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
contract UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderContextParityTest is Acceptance, RateChecks {
    function setUp() public override(Acceptance) {
        Acceptance.setUp(); _startRateChecks(vault, poolManager, create3Factory, diamondPackageFactory, [unit0, unit1]);
    }
    function _rateBootstrap() internal override { _bootstrap(); }
    function _rateBlocked(bytes memory data_) internal override returns (bytes memory) { return _nested(data_); }
    function _rateZeroSleeve() internal override {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
    }
}
contract UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderDecimalContextTest is UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderContextParityTest {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 9; }
}
