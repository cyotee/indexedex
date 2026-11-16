// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4BalancerStableLiquidityUnitsCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol";

abstract contract UniswapV4BalancerStableLiquidityUnitsTarget is UniswapV4BalancerStableLiquidityUnitsCore {
    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata sharesIn)
        external view returns (uint256 shares, uint256[] memory used) {
        return _entryPreviewJoinProportionalFlexible(amounts, sharesIn);
    }

    function joinProportionalFlexible(uint256[] calldata amounts, bool[] calldata sharesIn, address to, uint256 minimum, uint256 deadline)
        external  returns (uint256 shares, uint256[] memory used) {
        return _entryJoinProportionalFlexible(amounts, sharesIn, to, minimum, deadline);
    }

    function previewExitProportionalFlexible(uint256 shares, bool[] calldata flags)
        external view returns (uint256[] memory amounts) {
        return _entryPreviewExitProportionalFlexible(shares, flags);
    }

    function exitProportionalFlexible(uint256 shares, address to, bool[] calldata flags, uint256[] calldata minimum, uint256 deadline)
        external  returns (uint256[] memory amounts) {
        return _entryExitProportionalFlexible(shares, to, flags, minimum, deadline);
    }

    function previewJoinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts) external view returns (uint256) {
        return _entryPreviewJoinUnbalanced(tokens_, amounts);
    }

    function joinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        external  returns (uint256 shares) {
        return _entryJoinUnbalanced(tokens_, amounts, to, minimum, deadline);
    }
}
