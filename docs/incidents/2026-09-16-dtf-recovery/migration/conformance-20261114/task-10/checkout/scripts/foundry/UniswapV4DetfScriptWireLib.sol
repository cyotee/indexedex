// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @title UniswapV4DetfScriptWireLib
/// @notice Unified DETF wires Bond NFT and claim in `processArgs`. Hook is finalized
///         before `deployVault`. These helpers assert the hook is live.
library UniswapV4DetfScriptWireLib {
    function _wireCp(address detf) internal view {
        _assertHook(detf);
    }

    function _wireOrbital(address detf) internal view {
        _assertHook(detf);
    }

    function _wireQuad(address detf) internal view {
        _assertHook(detf);
    }

    function _wireWeighted(address detf) internal view {
        _assertHook(detf);
    }

    function _assertHook(address detf) private view {
        address hook = IUniswapV4Detf(detf).hook();
        require(hook != address(0) && hook.code.length > 0, "DETF hook");
    }
}
