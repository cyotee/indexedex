// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {TestBase_UniswapV4Detf_Quad_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Adversarial.sol";
import {Adversarial_TrustFlags} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_TrustFlags.t.sol";

/// @notice Quad gold I1/I2/I3 + K1. Donate/I1 use pair0.
contract UniswapV4Detf_Quad_Adversarial_TrustFlags is
    TestBase_UniswapV4Detf_Quad_Adversarial,
    Adversarial_TrustFlags
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Quad_Adversarial.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _uniqueDetfArgs(string memory tag_)
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Quad_Adversarial._uniqueDetfArgs(tag_);
    }

    function _approveUserForDetf(address detf_)
        internal
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Quad_Adversarial._approveUserForDetf(detf_);
    }

    function _deployHookThenDetfForPair(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    )
        internal
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Quad_Adversarial._deployHookThenDetfForPair(args, pair_, se_);
    }
}
