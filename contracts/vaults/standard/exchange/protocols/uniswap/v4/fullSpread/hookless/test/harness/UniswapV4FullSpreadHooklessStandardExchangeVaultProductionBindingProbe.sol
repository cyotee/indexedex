// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg} from "../../IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";

/// @dev Fresh full-name test identity; executes the unmodified production constructor.
contract UniswapV4FullSpreadHooklessStandardExchangeVaultProductionBindingProbe is UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg {
    constructor(IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.PkgInit memory init_)
        UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg(init_) {}
}
