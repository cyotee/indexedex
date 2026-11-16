// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Transaction-order preview needed to quote static SY issuance after due rewards.
interface IDETFStakingPreview {
    /// @notice Simulate due expansion, then this input's ordinary mint seigniorage, before new stake enters.
    /// @dev Direct DETF/sDETF inputs add no mint seigniorage. This does not fund or mutate the index.
    function previewStakingGonsPerUnit(IERC20 tokenIn_, uint256 amountIn_) external view returns (uint256);
}

/// @notice Deterministically deployed wrapper addresses on each DETF instance.
interface IDETFStandardizedYield {
    function rawSY() external view returns (address);
    function stakingSY() external view returns (address);
}
