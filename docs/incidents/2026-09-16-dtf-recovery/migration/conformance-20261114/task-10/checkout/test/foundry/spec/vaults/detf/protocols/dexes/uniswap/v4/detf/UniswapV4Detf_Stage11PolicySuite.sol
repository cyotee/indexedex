// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_PolicyLayerBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_PolicyLayerBase.sol";
import {UniswapV4Detf_OpeningPriceLayerBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPriceLayerBase.sol";
import {UniswapV4Detf_Alignment_RedeemD15PolicyBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15PolicyBase.sol";
import {UniswapV4Detf_Alignment_FeeCreatorClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol";

/// @notice Stage 11 Policy layer IDs (R-24). Fixture-id FC names live on each sibling.
abstract contract UniswapV4Detf_Stage11PolicySuite is
    UniswapV4Detf_PolicyLayerBase,
    UniswapV4Detf_OpeningPriceLayerBase,
    UniswapV4Detf_Alignment_RedeemD15PolicyBase,
    UniswapV4Detf_Alignment_FeeCreatorClaimBase
{
    function setUp() public virtual override {
        TestBase_UniswapV4Detf_Policy.setUp();
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
    {
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        this.policyDeployInstance(args);
    }

    function policyDeployInstance(IUniswapV4Detf.PkgArgs memory args) public virtual {
        _deployInstance(args);
    }
}
