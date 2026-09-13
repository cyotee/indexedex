// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {
    IUniswapV4DetfSelfCall
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4DetfSelfCall.sol";
import {UniswapV4DetfFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfFacet.sol";
import {
    UniswapV4DetfMaintenanceTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfMaintenanceTarget.sol";

/// @notice Independently deployed maintenance selectors of the universal DETF.
contract UniswapV4DetfMaintenanceFacet is UniswapV4DetfFacet, UniswapV4DetfMaintenanceTarget {
    /// @inheritdoc UniswapV4DetfFacet
    function facetName() public pure override returns (string memory) {
        return "UniswapV4DetfMaintenanceFacet";
    }

    /// @inheritdoc UniswapV4DetfFacet
    function facetFuncs() public pure override returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](7);
        funcs_[0] = IUniswapV4Detf.donate.selector;
        funcs_[1] = IUniswapV4Detf.sweepDust.selector;
        funcs_[2] = IUniswapV4Detf.joinDonatedCapital.selector;
        funcs_[3] = IUniswapV4Detf.notifyReserveDonated.selector;
        funcs_[4] = IUniswapV4DetfSelfCall.sweepDustAtomic.selector;
        funcs_[5] = IUniswapV4DetfSelfCall.sweepPairToShare.selector;
        funcs_[6] = IDETFFundedRewards.synchronizeRewards.selector;
    }
}
