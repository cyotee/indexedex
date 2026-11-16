// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    EtherFiWeETHStandardYieldTarget
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardYieldTarget.sol";

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

contract EtherFiWeETHMarkerFacet is EtherFiWeETHStandardYieldTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(EtherFiWeETHMarkerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IStandardizedYield).interfaceId;
        interfaces[0] = type(IEtherFiWeETHStandardVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IEtherFiWeETHStandardVault.weETH.selector;
        funcs[1] = IEtherFiWeETHStandardVault.eETH.selector;
        funcs[2] = IEtherFiWeETHStandardVault.weth.selector;
        funcs[3] = IEtherFiWeETHStandardVault.liquidityPool.selector;
        funcs[4] = IEtherFiWeETHStandardVault.withdrawRequestNFT.selector;
        funcs[5] = IEtherFiWeETHStandardVault.redemptionManager.selector;
        funcs[6] = IEtherFiWeETHStandardVault.liquidReserveEth.selector;
        funcs[7] = IEtherFiWeETHStandardVault.lockedReserveEth.selector;
        funcs[8] = IEtherFiWeETHStandardVault.totalReserveEth.selector;
        funcs[9] = IEtherFiWeETHStandardVault.actualLiquidReservePercentage.selector;
        funcs[10] = IEtherFiWeETHStandardVault.targetLiquidReservePercentage.selector;
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
