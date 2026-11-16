// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {UniswapV4Detf_Alignment_CloseD25OpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25OpenBase.sol";

/// @notice Weighted gold D25 close alignment on SUT UniswapV4DetfDFPkg / IUniswapV4Detf.
contract UniswapV4Detf_Weighted_Alignment_CloseD25 is
    TestBase_UniswapV4Detf_Weighted,
    UniswapV4Detf_Alignment_CloseD25OpenBase
{
    function setUp() public override(TestBase_UniswapV4Detf_Weighted, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Weighted.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        override
        returns (uint256 tokenId_, uint256 shares_)
    {
        _fundActor(detf, bonder_, pairAmount_ * 4);
        return super._bondAs(bonder_, pairAmount_);
    }
}
