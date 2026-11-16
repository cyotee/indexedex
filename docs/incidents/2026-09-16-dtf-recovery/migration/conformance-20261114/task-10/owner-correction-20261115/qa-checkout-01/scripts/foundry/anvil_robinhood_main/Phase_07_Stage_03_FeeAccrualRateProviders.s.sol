// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_07_Stage_03_FeeAccrualRateProviders as Providers} from "./Phase_07_Stage_03_FeeAccrualRateProviders.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";

contract Phase_07_Stage_03_FeeAccrualRateProviders is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 07 Stage 03: Fee accrual rate providers");
        liquidityVault = _loadProduct(LIQUIDITY_FILE, "liquidityVault");
        custodyVault = _loadProduct(CUSTODY_FILE, "custodyVault");
        IDiamondPackageCallBackFactory factory = IDiamondPackageCallBackFactory(_configAddress(".diamondPackageFactory"));
        IStandardExchangeRateProviderDFPkg pkg = IStandardExchangeRateProviderDFPkg(_configAddress(".packages.rateProvider"));
        _broadcast();
        address liquidityProvider = Providers.execute(factory, pkg, liquidityVault, wethToken);
        address custodyProvider = Providers.execute(factory, pkg, custodyVault, dtf);
        vm.stopBroadcast();
        _exportProduct("phase07_stage03_fee_accrual_liquidity_provider.json", "liquidityProvider", liquidityProvider);
        _exportProduct("phase07_stage03_fee_accrual_custody_provider.json", "custodyProvider", custodyProvider);
    }
}
