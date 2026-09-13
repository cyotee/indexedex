// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/// @title HookPkgArgsDecimalsLib
/// @notice Test/script helper: fill hook `PkgArgs` decimal fields from live tokens.
/// @dev Generic empty accounts use 18. Known predicted DETFs must use the explicit overloads.
library HookPkgArgsDecimalsLib {
    function tokenDec(address token) internal view returns (uint8) {
        if (token.code.length == 0) return 18;
        return IERC20Metadata(token).decimals();
    }

    function tokenDec(address token, address predictedDetf) internal view returns (uint8) {
        return token == predictedDetf ? 9 : tokenDec(token);
    }

    function tokenDecimals(address[] memory toks, address predictedDetf)
        internal view returns (uint8[] memory d)
    {
        d = new uint8[](toks.length);
        for (uint256 i; i < toks.length; ++i) d[i] = tokenDec(toks[i], predictedDetf);
    }

    function tokenDecimals4(address[4] memory toks, address predictedDetf)
        internal view returns (uint8[4] memory d)
    {
        for (uint256 i; i < 4; ++i) d[i] = tokenDec(toks[i], predictedDetf);
    }

    function seDec(address se) internal view returns (uint8) {
        if (se == address(0) || se.code.length == 0) return 0;
        return IERC20Metadata(se).decimals();
    }

    function tokenDecimals(address[] memory toks) internal view returns (uint8[] memory d) {
        d = new uint8[](toks.length);
        for (uint256 i; i < toks.length; ++i) {
            d[i] = tokenDec(toks[i]);
        }
    }

    function seDecimals(address[] memory ses) internal view returns (uint8[] memory d) {
        d = new uint8[](ses.length);
        for (uint256 i; i < ses.length; ++i) {
            d[i] = seDec(ses[i]);
        }
    }

    function tokenDecimals4(address[4] memory toks) internal view returns (uint8[4] memory d) {
        for (uint256 i; i < 4; ++i) {
            d[i] = tokenDec(toks[i]);
        }
    }

    function seDecimals4(address[4] memory ses) internal view returns (uint8[4] memory d) {
        for (uint256 i; i < 4; ++i) {
            d[i] = seDec(ses[i]);
        }
    }
}
