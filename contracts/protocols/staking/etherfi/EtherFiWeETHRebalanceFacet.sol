// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IEtherFiWeETHRebalance
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    EtherFiWeETHRebalanceTarget
} from "contracts/protocols/staking/etherfi/EtherFiWeETHRebalanceTarget.sol";

contract EtherFiWeETHRebalanceFacet is EtherFiWeETHRebalanceTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(EtherFiWeETHRebalanceFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IEtherFiWeETHRebalance).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IEtherFiWeETHRebalance.rebalance.selector;
        // Required so LiquidityPool.requestWithdraw can safeMint WithdrawRequestNFT to the vault.
        funcs[1] = this.onERC721Received.selector;
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
