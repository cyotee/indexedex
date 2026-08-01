// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet.sol";

/// @notice CREATE3 facet deploy helpers for the DualLiquidityLinkedCrossVersionUniswapVault family.
library DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet).creationCode,
            abi.encode(type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet).name);
    }

    function deployExchangeInQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet).creationCode,
            abi.encode(type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet).name);
    }

    function deployExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet).creationCode,
            abi.encode(type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet).name);
    }

    function deployExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet).creationCode,
            abi.encode(type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet).name);
    }
}
