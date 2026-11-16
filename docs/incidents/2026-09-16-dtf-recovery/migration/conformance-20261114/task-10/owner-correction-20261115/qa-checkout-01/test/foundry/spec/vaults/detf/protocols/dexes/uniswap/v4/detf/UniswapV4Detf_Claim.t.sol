// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_ClaimOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimOpenBase.sol";

/// @notice CP gold claim: pre/post-maturity NFT sell + locked claimRewards (WP-UDPL-CLAIM).
contract UniswapV4Detf_Claim is UniswapV4Detf_ClaimOpenBase {}
