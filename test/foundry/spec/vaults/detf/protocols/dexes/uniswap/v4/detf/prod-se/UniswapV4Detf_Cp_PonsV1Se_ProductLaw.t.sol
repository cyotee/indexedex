// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Cp_PonsV1Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_PonsV1Se.sol";
import {UniswapV4Detf_Stage11OpenSuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11OpenSuite.sol";

/// @notice H_CP_P1 Stage 11 Open (§7.0). Layer abstracts only (R-24).
contract UniswapV4Detf_Cp_PonsV1Se_ProductLaw is
    TestBase_UniswapV4Detf_Cp_PonsV1Se,
    UniswapV4Detf_Stage11OpenSuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Cp_PonsV1Se, UniswapV4Detf_Stage11OpenSuite)
    {
        TestBase_UniswapV4Detf_Cp_PonsV1Se.setUp();
        _bindStage11OpenActors();
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

    function _d25SeedHook() internal override {
        _buyLaunchFor(detfUser, 30 ether);
        vm.startPrank(detfUser);
        IERC20(mintToken).approve(detf, type(uint256).max);
        detfInfo.mint(IERC20(mintToken), 10 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
    }
}
