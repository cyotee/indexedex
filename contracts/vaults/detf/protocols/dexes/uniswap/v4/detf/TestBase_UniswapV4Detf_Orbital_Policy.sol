// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_Policy
 * @notice Orbital gold Policy TestBase. setUp is Orbital (n=3), not CP.
 * @dev `_deployInstance` → `_deployOrbitalHookThenDetf`. `_baseArgs` → `_nLegDetfArgs(2)`.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_Policy is
    TestBase_UniswapV4Detf_Orbital,
    TestBase_UniswapV4Detf_Policy
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Orbital, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Orbital.setUp();
        policyCreator = makeAddr("creator");
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployOrbitalHookThenDetf(args);
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }

    function _mintTokenOf(address) internal view virtual override returns (IERC20 tok) {
        return IERC20(address(pair0));
    }

    function _skewSyntheticDown(address d) internal virtual override {
        IERC20 tok_ = _mintTokenOf(d);
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        if (bal_ > 1 ether) {
            uint256 amt_ = bal_ / 2;
            if (amt_ == 0) amt_ = bal_;
            vm.prank(detfUser);
            IERC20(d).transfer(d, amt_);
            _ownerSwap(d, d, address(tok_), amt_);
            _ownerSwap(d, d, address(pair1), amt_ / 2);
            return;
        }
        if (IUniswapV4Detf(d).isMintingAllowed()) {
            try this.mintExternal(d, LIVE_MINT_AMT) {} catch {}
        }
        _ownerSwap(d, d, address(tok_), 40 ether);
        _ownerSwap(d, d, address(pair1), 40 ether);
    }

    function _pushSyntheticUp(address d) internal virtual override {
        IERC20 tok_ = _mintTokenOf(d);
        try this.donateExternal(d, 80 ether) {} catch {}
        if (IUniswapV4Detf(d).isMintingAllowed() && IUniswapV4Detf(d).syntheticPrice() > POLICY_MINT_THRESHOLD) {
            return;
        }
        _ownerSwap(d, address(tok_), d, 200 ether);
        _ownerSwap(d, address(pair1), d, 200 ether);
        try this.donateExternal(d, 80 ether) {} catch {}
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual override {
        _deployOrbitalHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Orbital._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital)
    {
        TestBase_UniswapV4Detf_Orbital._assertNoJoinableDust();
    }
}
