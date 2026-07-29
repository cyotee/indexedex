// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    CommonBufferMultiVaultStablePoolLiquidityTarget
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolLiquidityTarget.sol";

contract CommonBufferMultiVaultStablePoolLiquidityFacet is CommonBufferMultiVaultStablePoolLiquidityTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(CommonBufferMultiVaultStablePoolLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](1);
        ifaces[0] = type(IPoolLiquidity).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IPoolLiquidity.onAddLiquidityCustom.selector;
        funcs[1] = IPoolLiquidity.onRemoveLiquidityCustom.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName();
        i = facetInterfaces();
        f = facetFuncs();
    }
}
