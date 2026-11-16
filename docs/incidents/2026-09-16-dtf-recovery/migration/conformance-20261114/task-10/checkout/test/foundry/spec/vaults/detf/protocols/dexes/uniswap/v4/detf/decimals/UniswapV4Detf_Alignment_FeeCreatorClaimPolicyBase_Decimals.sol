// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals.sol";

/// @notice Stage 11 Policy layer: same FC1–FC12 IDs as gold (PRD §7.0 / R-16).
abstract contract UniswapV4Detf_Alignment_FeeCreatorClaimPolicyBase_Decimals is
    UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals
{}
