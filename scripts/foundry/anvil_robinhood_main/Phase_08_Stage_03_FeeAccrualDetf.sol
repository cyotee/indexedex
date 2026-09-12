// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4HookDiamondPackage} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as WeightedPkg} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedFactory} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";

library Phase_08_Stage_03_FeeAccrualDetf {
    struct Dependencies {
        address manager;
        address poolManager;
        IDiamondPackageCallBackFactory diamondFactory;
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory;
        IUniswapV4DetfDFPkg detfPkg;
        WeightedPkg hookPkg;
        address dtf;
        address weth;
        address liquidityVault;
        address custodyVault;
        address liquidityProvider;
        address custodyProvider;
    }

    struct Prepared {
        address detf;
        address hook;
        uint256 mineNonce;
        WeightedPkg.PkgArgs hookArgs;
    }

    /// @dev Run outside broadcast: CREATE2 flag mining is an offchain computation.
    function prepare(Dependencies memory d, IUniswapV4Detf.PkgArgs memory args)
        internal returns (Prepared memory p)
    {
        require(IVaultRegistryVaultPackageQuery(d.manager).isPackage(address(d.detfPkg)), "Fee DETF: unregistered DETF package");
        require(IVaultRegistryVaultPackageQuery(d.manager).isPackage(address(d.hookPkg)), "Fee DETF: unregistered hook package");
        args.hook = address(0);
        p.detf = d.diamondFactory.calcAddress(IDiamondFactoryPackage(address(d.detfPkg)), abi.encode(args));
        WeightedPkg.PkgArgs memory h;
        h.poolManager = d.poolManager;
        h.feeOracle = d.manager;
        h.n = 3;
        h.owner = p.detf;
        h.ownerOnlyLiquidity = args.ownerOnlyLiquidity;
        h.tokens = new address[](3);
        h.tokens[0] = p.detf;
        h.tokens[1] = d.weth;
        h.tokens[2] = d.dtf;
        for (uint256 i; i < 3; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (h.tokens[i] > h.tokens[j]) (h.tokens[i], h.tokens[j]) = (h.tokens[j], h.tokens[i]);
            }
        }
        h.weights = new uint256[](3);
        h.standardExchanges = new address[](3);
        h.rateProviders = new address[](3);
        h.tokenDecimals = new uint8[](3);
        h.seDecimals = new uint8[](3);
        for (uint256 i; i < 3; ++i) {
            if (h.tokens[i] == p.detf) {
                h.weights[i] = FixtureEconomics.FEE_ACCRUAL_DETF_WEIGHT;
                h.tokenDecimals[i] = 9;
            } else {
                bool isWeth = h.tokens[i] == d.weth;
                h.weights[i] = isWeth ? FixtureEconomics.FEE_ACCRUAL_WETH_WEIGHT : FixtureEconomics.FEE_ACCRUAL_DTF_WEIGHT;
                h.standardExchanges[i] = isWeth ? d.liquidityVault : d.custodyVault;
                h.rateProviders[i] = isWeth ? d.liquidityProvider : d.custodyProvider;
                h.tokenDecimals[i] = IERC20Metadata(h.tokens[i]).decimals();
                h.seDecimals[i] = IERC20Metadata(h.standardExchanges[i]).decimals();
            }
        }
        p.hookArgs = h;
        p.mineNonce = WeightedFactory.findMineNonce(d.hookFactory, d.hookPkg, h);
        p.hook = d.hookFactory.calcAddress(IUniswapV4HookDiamondPackage(address(d.hookPkg)), abi.encode(h), p.mineNonce);
    }

    function execute(Dependencies memory d, IUniswapV4Detf.PkgArgs memory args, Prepared memory p)
        internal returns (address)
    {
        if (p.hook.code.length == 0) {
            require(d.hookPkg.deployVault(p.hookArgs, p.mineNonce) == p.hook, "Fee DETF: hook prediction mismatch");
        }
        require(IMultiStepOwnable(p.hook).owner() == p.detf, "Fee DETF: wrong reserve owner");
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(p.hook);
        if (IDiamondLoupe(p.hook).facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector) != address(0)) {
            for (uint256 i; i < 3; ++i) {
                for (uint256 j = i + 1; j < 3; ++j) {
                    address a = p.hookArgs.tokens[i];
                    address b = p.hookArgs.tokens[j];
                    if (!init.isPairPoolLive(a, b)) init.deployPair(a, b);
                }
            }
            require(init.finalizeInitialization(), "Fee DETF: hook not finalized");
        }
        args.hook = p.hook;
        if (p.detf.code.length == 0) require(d.detfPkg.deployVault(args) == p.detf, "Fee DETF: prediction mismatch");
        require(IVaultRegistryVaultQuery(d.manager).isVault(p.detf), "Fee DETF: unregistered vault");
        require(IUniswapV4Detf(p.detf).hook() == p.hook, "Fee DETF: wrong hook");
        return p.detf;
    }
}
