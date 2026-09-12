// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4DetfTarget} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";

/// @notice Claim entrypoints for the universal DETF diamond.
abstract contract UniswapV4DetfClaimTarget is UniswapV4DetfTarget {
    /// @notice Deploys and binds the bond NFT child once through its configured package.
    function completeReserveBondNft() external returns (address bondNftVault_) {
        return _entryCompleteReserveBondNft();
    }

    /// @notice Deploys and binds the rebasing claim child once through its configured package.
    function completeReserveClaim() external returns (address rebasingClaimToken_) {
        return _entryCompleteReserveClaim();
    }
}
