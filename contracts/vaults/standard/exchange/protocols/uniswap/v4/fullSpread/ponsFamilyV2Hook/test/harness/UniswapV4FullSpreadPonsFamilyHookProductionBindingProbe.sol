// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadPonsFamilyHookDFPkg} from "../../UniswapV4FullSpreadPonsFamilyHookDFPkg.sol";
import {IUniswapV4FullSpreadPonsFamilyHookDFPkg} from "../../IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";

/// @dev Fresh full-name test identity; executes the unmodified production constructor.
contract UniswapV4FullSpreadPonsFamilyHookProductionBindingProbe is UniswapV4FullSpreadPonsFamilyHookDFPkg {
    constructor(IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory init_)
        UniswapV4FullSpreadPonsFamilyHookDFPkg(init_) {}
}
