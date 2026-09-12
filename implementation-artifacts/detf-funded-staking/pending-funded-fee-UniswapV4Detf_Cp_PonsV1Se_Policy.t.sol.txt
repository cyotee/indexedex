// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Cp_PonsV1Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_PonsV1Se.sol";
import {UniswapV4Detf_Stage11PolicySuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11PolicySuite.sol";

/// @notice H_CP_P1 Stage 11 Policy (§7.0). FC names use fixture id (R-16).
contract UniswapV4Detf_Cp_PonsV1Se_Policy is
    TestBase_UniswapV4Detf_Cp_PonsV1Se,
    UniswapV4Detf_Stage11PolicySuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Cp_PonsV1Se, UniswapV4Detf_Stage11PolicySuite)
    {
        TestBase_UniswapV4Detf_Cp_PonsV1Se.setUp();
        policyCreator = makeAddr("creator");
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Cp_PonsV1Se)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Cp_PonsV1Se._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Cp_PonsV1Se)
    {
        TestBase_UniswapV4Detf_Cp_PonsV1Se._assertNoJoinableDust();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override
        returns (address)
    {
        return _deployPonsV1HookThenDetf(args);
    }

    function _fundTokenFallback(address token_, address to_, uint256 amount_) internal override {
        if (token_ == launchToken) _buyLaunchFor(to_, amount_);
    }














}
