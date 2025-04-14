// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

library SeigniorageSetterSelectors {
    // canonical selector for `setSeigniorage(uint256)`
    bytes4 internal constant SET_SEIGNIORAGE = bytes4(keccak256("setSeigniorage(uint256)"));
}
