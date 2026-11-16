// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ILidoWstETHStandardVault} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {LidoWstETHStandardYieldTarget} from "contracts/protocols/staking/lido/LidoWstETHStandardYieldTarget.sol";

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

contract LidoWstETHMarkerFacet is LidoWstETHStandardYieldTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(LidoWstETHMarkerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IStandardizedYield).interfaceId;
        interfaces[0] = type(ILidoWstETHStandardVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](9);
        funcs[0] = ILidoWstETHStandardVault.wstETH.selector;
        funcs[1] = ILidoWstETHStandardVault.stETH.selector;
        funcs[2] = ILidoWstETHStandardVault.weth.selector;
        funcs[3] = ILidoWstETHStandardVault.withdrawalQueue.selector;
        funcs[4] = ILidoWstETHStandardVault.liquidReserveEth.selector;
        funcs[5] = ILidoWstETHStandardVault.lockedReserveEth.selector;
        funcs[6] = ILidoWstETHStandardVault.totalReserveEth.selector;
        funcs[7] = ILidoWstETHStandardVault.actualLiquidReservePercentage.selector;
        funcs[8] = ILidoWstETHStandardVault.targetLiquidReservePercentage.selector;
        funcs = NativeStandardYieldSelectors._append(funcs);
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
