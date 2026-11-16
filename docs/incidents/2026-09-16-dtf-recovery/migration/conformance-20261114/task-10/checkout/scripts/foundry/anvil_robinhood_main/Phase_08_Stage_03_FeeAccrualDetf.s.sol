// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {Phase_08_Stage_03_FeeAccrualDetf as Composition} from "./Phase_08_Stage_03_FeeAccrualDetf.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

contract Phase_08_Stage_03_FeeAccrualDetf is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 08 Stage 03: DTF-DETF weighted composition");
        liquidityVault = _loadProduct(LIQUIDITY_FILE, "liquidityVault");
        custodyVault = _loadProduct(CUSTODY_FILE, "custodyVault");
        Composition.Dependencies memory d = _dependencies();
        IUniswapV4Detf.PkgArgs memory args = _args();
        Composition.Prepared memory p = Composition.prepare(d, args);
        _broadcast();
        targetDetf = Composition.execute(d, args, p);
        vm.stopBroadcast();
        _exportProduct(FEE_DETF_FILE, "feeDetf", targetDetf);
        _exportProduct("phase08_stage03_fee_accrual_hook.json", "reserveHook", p.hook);
        _loadFeeDetf(false);
    }

    function _dependencies() internal view returns (Composition.Dependencies memory d) {
        d.manager = manager;
        d.poolManager = _configAddress(".poolManager");
        d.diamondFactory = IDiamondPackageCallBackFactory(_configAddress(".diamondPackageFactory"));
        d.hookFactory = IUniswapV4HookDiamondPackageCallBackFactory(_configAddress(".hookFactory"));
        d.detfPkg = IUniswapV4DetfDFPkg(_configAddress(".packages.detf"));
        string memory bondManifest = vm.readFile(_artifactPath("phase06_stage01_bond_nft_pkg.json"));
        require(vm.parseJsonUint(bondManifest, ".chainId") == block.chainid, "Fee DETF: bond package chain");
        d.bondNftPkg = IUniswapV4DetfBondNFTVaultDFPkg(vm.parseJsonAddress(bondManifest, ".bondNftVaultPkg"));
        d.hookPkg = IUniswapV4StandardExchangeWeightedBufferHookPackage(_configAddress(".packages.weightedHook"));
        d.dtf = dtf;
        d.weth = wethToken;
        d.liquidityVault = liquidityVault;
        d.custodyVault = custodyVault;
        d.liquidityProvider = _loadProduct("phase07_stage03_fee_accrual_liquidity_provider.json", "liquidityProvider");
        d.custodyProvider = _loadProduct("phase07_stage03_fee_accrual_custody_provider.json", "custodyProvider");
    }

    function _args() internal view returns (IUniswapV4Detf.PkgArgs memory a) {
        a.name = FixtureEconomics.FEE_ACCRUAL_DETF_NAME;
        a.symbol = FixtureEconomics.FEE_ACCRUAL_DETF_SYMBOL;
        a.ownerOnlyLiquidity = vm.parseJsonBool(feeConfig, ".detf.ownerOnlyLiquidity");
        a.creator = vm.parseJsonAddress(feeConfig, ".detf.creator");
        require(a.creator != address(0), "Fee DETF: missing creator");
        a.claimName = vm.parseJsonString(feeConfig, ".detf.claimName");
        a.claimSymbol = vm.parseJsonString(feeConfig, ".detf.claimSymbol");
        a.bondName = vm.parseJsonString(feeConfig, ".detf.bondName");
        a.bondSymbol = vm.parseJsonString(feeConfig, ".detf.bondSymbol");
        a.creationPairPerDetfWad = _prices("creation");
        a.openingPairPerDetfWad = _prices("opening");
        a.mintThreshold = vm.parseJsonUint(feeConfig, ".detf.mintThreshold");
        a.burnThreshold = vm.parseJsonUint(feeConfig, ".detf.burnThreshold");
        a.expansionClosureRatePerYearWad = vm.parseJsonUint(feeConfig, ".detf.expansionClosureRatePerYearWad");
        a.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a.burnRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a.bondRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a.donateRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a.mintRoutes = _routes();
        a.donateRoutes = _routes();
        a.bondRoutes = _routes();
        a.burnRoutes = new IUniswapV4Detf.IoRoute[](1);
        a.burnRoutes[0] = IUniswapV4Detf.IoRoute(IERC20(dtf), IStandardExchange(custodyVault));
    }

    function _prices(string memory kind) internal view returns (uint256[] memory values) {
        values = new uint256[](2);
        values[dtf < wethToken ? 0 : 1] = vm.parseJsonUint(feeConfig, string.concat(".detf.", kind, "DtfPerDetfWad"));
        values[dtf < wethToken ? 1 : 0] = vm.parseJsonUint(feeConfig, string.concat(".detf.", kind, "WethPerDetfWad"));
        require(values[0] != 0 && values[1] != 0, "Fee DETF: explicit nonzero prices required");
    }

    function _routes() internal view returns (IUniswapV4Detf.IoRoute[] memory routes) {
        routes = new IUniswapV4Detf.IoRoute[](2);
        routes[0] = IUniswapV4Detf.IoRoute(IERC20(dtf), IStandardExchange(custodyVault));
        routes[1] = IUniswapV4Detf.IoRoute(IERC20(wethToken), IStandardExchange(liquidityVault));
    }
}
