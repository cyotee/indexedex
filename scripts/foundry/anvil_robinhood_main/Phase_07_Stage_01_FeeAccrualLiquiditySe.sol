// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {IUniswapV4FullSpreadPonsFamilyHookDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";
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
        IUniswapV4FullSpreadPonsFamilyHookDFPkg pkg, IPoolManager poolManager, PoolKey memory key
    ) internal returns (address vault) {
        require(IVaultRegistryVaultPackageQuery(manager).isPackage(address(pkg)), "Liquidity: package not registered");
        require(address(key.hooks) == ROBINHOOD_MAIN.PONS_V2_MEME_HOOK, "Liquidity: unsupported hook");
        require(keccak256(bytes(pkg.packageName())) == keccak256("UniswapV4FullSpreadPonsFamilyHookDFPkg"), "Liquidity: wrong family");
        (uint160 price,,,) = poolManager.getSlot0(key.toId());
        require(price != 0 && poolManager.getLiquidity(key.toId()) != 0, "Liquidity: inactive Pons pool");
        vault = factory.calcAddress(IDiamondFactoryPackage(address(pkg)), abi.encode(IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgArgs({poolKey: key})));
        if (vault.code.length == 0) require(pkg.deployVault(key) == vault, "Liquidity: prediction mismatch");
        require(IVaultRegistryVaultQuery(manager).isVault(vault), "Liquidity: vault not registered");
    }
}
