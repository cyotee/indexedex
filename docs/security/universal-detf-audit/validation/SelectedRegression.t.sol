// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// Focused compile root: imports the original production-fixture tests unchanged.
// Set FOUNDRY_TEST to this directory for this bounded regression selection.
// This does not represent full protocol test coverage.

import {UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital_Test as RegressionImport0} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital.t.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_StagedInit_Test as RegressionImport1} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_StagedInit.t.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_SwapReentrancy_Test as RegressionImport2} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SwapReentrancy.t.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder_Test as RegressionImport3} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder.t.sol";
import {DETFNFTVault_N10Conversion as RegressionImport4} from "test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_N10Conversion.t.sol";
import {RebasingClaimToken_Accounting as RegressionImport5} from "test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Accounting.t.sol";
import {RebasingClaimToken_ExactOutput as RegressionImport6} from "test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_ExactOutput.t.sol";
import {UniswapV4Detf_Alignment_CloseD25 as RegressionImport7} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25.t.sol";
import {UniswapV4Detf_BondNftPackaging as RegressionImport8} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_BondNftPackaging.t.sol";
import {UniswapV4Detf_Close as RegressionImport9} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Close.t.sol";
import {UniswapV4Detf_FacetPackaging as RegressionImport10} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol";
import {UniswapV4Detf_Orbital_Alignment_CloseD25 as RegressionImport11} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_Alignment_CloseD25.t.sol";
import {UniswapV4Detf_OriginalPrincipal as RegressionImport12} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OriginalPrincipal.t.sol";
import {UniswapV4Detf_Quad_Alignment_CloseD25 as RegressionImport13} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad_Alignment_CloseD25.t.sol";
import {UniswapV4Detf_Weighted_Alignment_CloseD25 as RegressionImport14} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted_Alignment_CloseD25.t.sol";
