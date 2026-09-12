// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

library Phase_07_Stage_01_FeeAccrualLiquiditySe {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    function execute(address manager, IDiamondPackageCallBackFactory factory,
        IUniswapV4StandardExchangeDFPkg pkg, IPoolManager poolManager, PoolKey memory key
    ) internal returns (address vault) {
        require(IVaultRegistryVaultPackageQuery(manager).isPackage(address(pkg)), "Liquidity: package not registered");
        (uint160 price,,,) = poolManager.getSlot0(key.toId());
        require(price != 0 && poolManager.getLiquidity(key.toId()) != 0, "Liquidity: inactive Pons pool");
        vault = factory.calcAddress(IDiamondFactoryPackage(address(pkg)), abi.encode(IUniswapV4StandardExchangeDFPkg.PkgArgs({poolKey: key})));
        if (vault.code.length == 0) require(pkg.deployVault(key) == vault, "Liquidity: prediction mismatch");
        require(IVaultRegistryVaultQuery(manager).isVault(vault), "Liquidity: vault not registered");
    }
}
