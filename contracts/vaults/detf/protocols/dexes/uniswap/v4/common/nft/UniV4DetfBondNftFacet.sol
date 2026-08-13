// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {
    UniV4DetfBondNftTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftTarget.sol";
import {
    IUniV4DetfBondNft
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/IUniV4DetfBondNft.sol";

contract UniV4DetfBondNftFacet is IFacet, UniV4DetfBondNftTarget {
    function facetName() external pure returns (string memory) {
        return "UniV4DetfBondNftFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IUniV4DetfBondNft).interfaceId;
        interfaces_[1] = type(IUnlockCallback).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniV4DetfBondNftFacet";
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IUniV4DetfBondNft).interfaceId;
        interfaces_[1] = type(IUnlockCallback).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](21);
        funcs_[0] = IUniV4DetfBondNft.openBond.selector;
        funcs_[1] = IUniV4DetfBondNft.claimRewards.selector;
        funcs_[2] = IUniV4DetfBondNft.closeBondMature.selector;
        funcs_[3] = IUniV4DetfBondNft.sellBond.selector;
        funcs_[4] = IUniV4DetfBondNft.pendingRewards.selector;
        funcs_[5] = IUniV4DetfBondNft.totalShares.selector;
        funcs_[6] = IUniV4DetfBondNft.protocolPrincipal.selector;
        funcs_[7] = IUniV4DetfBondNft.ownerOf.selector;
        funcs_[8] = IUniV4DetfBondNft.unlockTimeOf.selector;
        funcs_[9] = IUniV4DetfBondNft.pairPrincipalOf.selector;
        funcs_[10] = IUniV4DetfBondNft.effectiveSharesOf.selector;
        funcs_[11] = IUniV4DetfBondNft.owner.selector;
        funcs_[12] = IUnlockCallback.unlockCallback.selector;
        funcs_[13] = IUniV4DetfBondNft.openHookLpBond.selector;
        funcs_[14] = IUniV4DetfBondNft.closeHookLpBond.selector;
        funcs_[15] = IUniV4DetfBondNft.sellHookLpBond.selector;
        funcs_[16] = IUniV4DetfBondNft.capitalTokenOf.selector;
        funcs_[17] = IUniV4DetfBondNft.lpPrincipalOf.selector;
        funcs_[18] = IUniV4DetfBondNft.requireMatureForSell.selector;
        funcs_[19] = IUniV4DetfBondNft.reserveLp.selector;
        funcs_[20] = IUniV4DetfBondNft.initializeHookLpMode.selector;
    }
}
