// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {UniswapV4HookFlagsFacet} from "contracts/hooks/uniswap/v4/factory/facets/UniswapV4HookFlagsFacet.sol";
import {UniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {Vm} from "forge-std/Vm.sol";

import {IUniswapV4HookDiamondPackage} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";

import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";

/**
 * @title UniswapV4HookDiamondPackageCallBackFactory_FactoryService
 * @notice CREATE3 helpers for the hook diamond package callback factory singleton.
 * @dev Product deploys go Package.deployVault → VaultRegistry.deployHookVault → factory.
 *      `deployHook` below is a low-level factory call (tests / scripts); it does not register vaults.
 */
library UniswapV4HookDiamondPackageCallBackFactory_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4HookFlagsFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet hookFlagsFacet)
    {
        hookFlagsFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4HookFlagsFacet.sol:UniswapV4HookFlagsFacet"), abi.encode("UniswapV4HookFlagsFacet")._hash()
        );
        vm.label(address(hookFlagsFacet), "UniswapV4HookFlagsFacet");
    }

    function deployUniswapV4HookDiamondPackageCallBackFactory(
        ICreate3FactoryProxy create3Factory,
        IUniswapV4HookDiamondPackageCallBackFactory.InitArgs memory initArgs
    ) internal returns (IUniswapV4HookDiamondPackageCallBackFactory factory) {
        factory = IUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode("UniswapV4HookDiamondPackageCallBackFactory.sol:UniswapV4HookDiamondPackageCallBackFactory"),
                abi.encode(initArgs),
                abi.encode("UniswapV4HookDiamondPackageCallBackFactory")._hash()
            )
        );
        vm.label(address(factory), "UniswapV4HookDiamondPackageCallBackFactory");
    }

    /// @notice Low-level factory deploy (no vault registry). Prefer package → registry.deployHookVault in products.
    function deployHook(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4HookDiamondPackage pkg,
        bytes memory pkgArgs,
        uint256 mineNonce
    ) internal returns (address proxy) {
        return factory.deployWithMineNonce(pkg, pkgArgs, mineNonce);
    }

    /**
     * @notice Off-chain mine helper (pure loop). Prefer premine in production; auto-mine is gas-risky.
     */
    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4HookDiamondPackage pkg,
        bytes memory pkgArgs
    ) internal returns (uint256 mineNonce) {
        bytes memory processed = pkg.processArgs(pkgArgs);
        bytes32 packageSalt = pkg.calcSalt(processed);
        uint160 flags = pkg.requiredHookFlags();
        return Create2Lib.findMineNonce(
            address(factory), factory.PROXY_INIT_HASH(), packageSalt, flags, Create2Lib.MAX_LOOP
        );
    }
}
