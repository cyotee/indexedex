// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch} from "./TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";

// tag::TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested[]
/// @notice A real outer manager session around the genuine graduated-launch proxy.
abstract contract TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested
    is TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch, IUnlockCallback
{
    bool private launchCallbackActive;

    function _launchBlocked(bytes memory data_) internal returns (bytes memory result_) {
        require(!launchCallbackActive, "recursive launch driver");
        launchCallbackActive = true;
        result_ = poolManager.unlock(data_);
        launchCallbackActive = false;
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory result_) {
        require(msg.sender == address(poolManager) && launchCallbackActive, "unauthorized launch callback");
        bool ok;
        (ok, result_) = address(ponsSe).call(data_);
        if (!ok) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
    }
}
// end::TestBase_UniswapV4FullSpreadPonsFamilyHook_LaunchNested[]
