// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IRocketPoolRETHStandardVault
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {
    RocketPoolRETHStandardExchangeCommon
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol";

contract RocketPoolRETHMarkerFacet is RocketPoolRETHStandardExchangeCommon, IFacet {
    function facetName() public pure returns (string memory) {
        return type(RocketPoolRETHMarkerFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IRocketPoolRETHStandardVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IRocketPoolRETHStandardVault.rETH.selector;
        funcs[1] = IRocketPoolRETHStandardVault.weth.selector;
        funcs[2] = IRocketPoolRETHStandardVault.depositPool.selector;
        funcs[3] = IRocketPoolRETHStandardVault.liquidReserveEth.selector;
        funcs[4] = IRocketPoolRETHStandardVault.lockedReserveEth.selector;
        funcs[5] = IRocketPoolRETHStandardVault.totalReserveEth.selector;
        funcs[6] = IRocketPoolRETHStandardVault.actualLiquidReservePercentage.selector;
        funcs[7] = IRocketPoolRETHStandardVault.targetLiquidReservePercentage.selector;
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
