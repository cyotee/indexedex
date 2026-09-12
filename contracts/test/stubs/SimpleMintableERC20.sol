// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title SimpleMintableERC20
 * @notice 18-dec wrap of `MintableERC20Decimals` for gold callers that do not set decimals.
 */
contract SimpleMintableERC20 is MintableERC20Decimals {
    constructor(string memory name_, string memory symbol_) MintableERC20Decimals(name_, symbol_, 18) {}
}
