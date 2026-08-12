// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {
    UniV4DetfRebasingClaimTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimTarget.sol";
import {
    IUniV4DetfRebasingClaim
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/IUniV4DetfRebasingClaim.sol";

contract UniV4DetfRebasingClaimFacet is IFacet, UniV4DetfRebasingClaimTarget {
    function facetName() external pure returns (string memory) {
        return "UniV4DetfRebasingClaimFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IUniV4DetfRebasingClaim).interfaceId;
        interfaces_[1] = type(IUnlockCallback).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](12);
        funcs_[0] = IUniV4DetfRebasingClaim.deposit.selector;
        funcs_[1] = IUniV4DetfRebasingClaim.redeem.selector;
        funcs_[2] = IUniV4DetfRebasingClaim.previewDeposit.selector;
        funcs_[3] = IUniV4DetfRebasingClaim.previewRedeem.selector;
        funcs_[4] = IUniV4DetfRebasingClaim.zapOutToPair.selector;
        funcs_[5] = IUniV4DetfRebasingClaim.absorbBondProceeds.selector;
        funcs_[6] = IUniV4DetfRebasingClaim.donateDetf.selector;
        funcs_[7] = IUniV4DetfRebasingClaim.pairToken.selector;
        funcs_[8] = IUniV4DetfRebasingClaim.detfToken.selector;
        funcs_[9] = IUniV4DetfRebasingClaim.listingPoolKey.selector;
        funcs_[10] = IUniV4DetfRebasingClaim.owner.selector;
        funcs_[11] = IUnlockCallback.unlockCallback.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniV4DetfRebasingClaimFacet";
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IUniV4DetfRebasingClaim).interfaceId;
        interfaces_[1] = type(IUnlockCallback).interfaceId;
        funcs_ = new bytes4[](12);
        funcs_[0] = IUniV4DetfRebasingClaim.deposit.selector;
        funcs_[1] = IUniV4DetfRebasingClaim.redeem.selector;
        funcs_[2] = IUniV4DetfRebasingClaim.previewDeposit.selector;
        funcs_[3] = IUniV4DetfRebasingClaim.previewRedeem.selector;
        funcs_[4] = IUniV4DetfRebasingClaim.zapOutToPair.selector;
        funcs_[5] = IUniV4DetfRebasingClaim.absorbBondProceeds.selector;
        funcs_[6] = IUniV4DetfRebasingClaim.donateDetf.selector;
        funcs_[7] = IUniV4DetfRebasingClaim.pairToken.selector;
        funcs_[8] = IUniV4DetfRebasingClaim.detfToken.selector;
        funcs_[9] = IUniV4DetfRebasingClaim.listingPoolKey.selector;
        funcs_[10] = IUniV4DetfRebasingClaim.owner.selector;
        funcs_[11] = IUnlockCallback.unlockCallback.selector;
    }
}
