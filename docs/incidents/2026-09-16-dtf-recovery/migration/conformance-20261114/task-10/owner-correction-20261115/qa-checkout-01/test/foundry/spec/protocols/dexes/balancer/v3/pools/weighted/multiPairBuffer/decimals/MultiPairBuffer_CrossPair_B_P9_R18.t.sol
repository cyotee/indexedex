// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MultiPairBuffer_CrossPair_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/decimals/MultiPairBuffer_CrossPair_Decimals.sol";

/// @notice Book `B_P9_R18`. pairToken 9-dec; one other raw leg 18-dec; remaining 18-dec.
/// @dev Remaining-18: B_P18_R6 is 18,6,18 not homogeneous rest. vaultShare / detfToken / claim / Bond NFT stay 18.
contract MultiPairBuffer_CrossPair_B_P9_R18 is MultiPairBuffer_CrossPair_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _restDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
