// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf, IUniswapV4DetfFirstBondShares} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfFacet.sol";
import {
    UniswapV4DetfBondTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondTarget.sol";

/// @notice Independently deployed bond selectors of the universal DETF.
contract UniswapV4DetfBondFacet is UniswapV4DetfFacet, UniswapV4DetfBondTarget {
    /// @notice Quote an empty reserve's complete, caller-funded share basket.
    function previewFirstBondShares(uint256[] calldata shareAmounts_, uint256 anchorIndex_, uint256 lockDuration_)
        external view returns (
            uint256 purchasedDetf_, uint256 principalDetf_, uint256 rewardsDetf_, uint256 liquidityDetf_, uint256 lpOut_
        )
    {
        FirstBondSharePlan memory plan_ = _firstBondSharePlan(shareAmounts_, anchorIndex_, lockDuration_);
        return (plan_.split.grossDetf, plan_.split.userDetf, plan_.split.inventoryDetf, plan_.amounts[0], plan_.lpOut);
    }

    /// @notice Bootstrap an ordinary DETF with fresh SE-share contributions.
    function bondFirstShares(
        uint256[] calldata shareAmounts_,
        uint256 anchorIndex_,
        uint256 lockDuration_,
        address recipient_,
        uint256 minPrincipal_,
        uint256 minLp_,
        uint256 deadline_
    ) external returns (uint256 tokenId_, uint256 lpOut_) {
        return _entryBondFirstShares(
            shareAmounts_, anchorIndex_, lockDuration_, recipient_, minPrincipal_, minLp_, deadline_
        );
    }

    /// @inheritdoc UniswapV4DetfFacet
    function facetName() public pure override returns (string memory) {
        return "UniswapV4DetfBondFacet";
    }

    /// @inheritdoc UniswapV4DetfFacet
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](3);
        funcs_[0] = IUniswapV4Detf.bond.selector;
        funcs_[1] = IUniswapV4DetfFirstBondShares.bondFirstShares.selector;
        funcs_[2] = IUniswapV4DetfFirstBondShares.previewFirstBondShares.selector;
    }
}
