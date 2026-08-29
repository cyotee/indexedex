// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Alignment_CloseD25OpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25OpenBase.sol";

/// @notice CP gold D25 close alignment on SUT UniswapV4DetfDFPkg / IUniswapV4Detf.
/// @dev T7.12 in UniswapV4Detf_Close.t.sol remains Default basket smoke; it does not replace D25-1..7.
contract UniswapV4Detf_Alignment_CloseD25 is UniswapV4Detf_Alignment_CloseD25OpenBase {}
