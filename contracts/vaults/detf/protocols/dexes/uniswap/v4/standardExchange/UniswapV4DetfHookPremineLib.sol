// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @title UniswapV4DetfHookPremineLib
/// @notice Predict unified DETF address (hook=0 salt) and mine CP buffer-hook CREATE2 nonce.
library UniswapV4DetfHookPremineLib {
    function predictDetf(IDiamondPackageCallBackFactory diamondPackageFactory, address detfPkg, IUniswapV4Detf.PkgArgs memory args)
        internal
        view
        returns (address predicted)
    {
        IUniswapV4Detf.PkgArgs memory saltArgs_ = args;
        saltArgs_.hook = address(0);
        predicted = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(detfPkg), abi.encode(saltArgs_)
        );
    }

    function premineCpHook(
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage hookPkg,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs
    ) internal returns (uint256 mineNonce) {
        mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
    }

    function premineCp(
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4DetfDFPkg detfPkg,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage hookPkg,
        IUniswapV4Detf.PkgArgs memory args,
        address poolManager,
        address feeOracle,
        address standardExchange,
        address pairToken
    ) internal returns (address predictedDetf, uint256 mineNonce) {
        predictedDetf = predictDetf(diamondPackageFactory, address(detfPkg), args);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                standardExchange: standardExchange,
                pairToken: pairToken,
                rawToken: predictedDetf,
                ownerOnlyLiquidity: true,
                owner: predictedDetf
            });
        mineNonce = premineCpHook(hookFactory, hookPkg, hArgs);
    }
}
