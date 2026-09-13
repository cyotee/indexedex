// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals.sol";
import {UniswapV4Detf_Stage11OpenSuite_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Stage11OpenSuite_Decimals.sol";

abstract contract UniswapV4Detf_Cp_PonsV1Se_ProductLaw_Decimals is
    TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals,
    UniswapV4Detf_Stage11OpenSuite_Decimals
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals, UniswapV4Detf_Stage11OpenSuite_Decimals)
    {
        TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals.setUp();
        _bindStage11OpenActors();
    }
    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals._firstBond(pairAmount_);
    }
    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals)
    {
        TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals._assertNoJoinableDust();
    }

    function _fundBondLegFallback(address token_, address to_, uint256 amount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Decimals, TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals)
    {
        TestBase_UniswapV4Detf_Cp_PonsV1Se_Decimals._fundBondLegFallback(token_, to_, amount_);
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployPonsV1HookThenDetf(args);
    }

    function _fundTokenFallback(address token_, address to_, uint256 amount_) internal virtual override {
        if (token_ == launchToken) _buyLaunchFor(to_, amount_);
    }

    function _d25SeedHook() internal virtual override {
        _buyLaunchFor(detfUser, 30 ether);
        vm.startPrank(detfUser);
        IERC20(mintToken).approve(detf, type(uint256).max);
        IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(mintToken), _uPair(10), IERC20(address(detfInfo)), 0, detfUser, false, _deadline());
        vm.stopPrank();
    }
}
