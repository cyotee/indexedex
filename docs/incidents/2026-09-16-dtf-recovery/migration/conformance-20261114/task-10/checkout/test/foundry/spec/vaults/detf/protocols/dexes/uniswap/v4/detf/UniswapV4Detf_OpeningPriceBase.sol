// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title UniswapV4Detf_OpeningPriceBase
 * @notice Shared T1/T2/T5 bodies for unified Uni V4 DETF opening vs creation (PRD §7.2). No T6 on CP.
 */
abstract contract UniswapV4Detf_OpeningPriceBase is TestBase_UniswapV4Detf_Policy {
    function _openingT2Detf() internal virtual returns (address d) {
        d = _deployInstance(
            _withOpening(_withTag(_policyArgs(), string.concat("t2", _nextTag())), LAUNCH_RICH_START)
        );
        _bindPolicy(d);
    }
}
