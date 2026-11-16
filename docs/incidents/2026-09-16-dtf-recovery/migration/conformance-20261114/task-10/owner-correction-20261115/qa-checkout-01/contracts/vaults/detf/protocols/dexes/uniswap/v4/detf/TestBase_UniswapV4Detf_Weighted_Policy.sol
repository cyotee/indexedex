// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_Policy
 * @notice Weighted gold Policy/Open helpers. Weighted setUp first, then policyCreator.
 * @dev `_deployInstance` → `_deployWeightedHookThenDetf`. `_baseArgs` → `_nLegDetfArgs(2)`.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_Policy is
    TestBase_UniswapV4Detf_Weighted,
    TestBase_UniswapV4Detf_Policy
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Weighted, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Weighted.setUp();
        policyCreator = makeAddr("creator");
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployWeightedHookThenDetf(args);
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }

    function _mintTokenOf(address) internal view virtual override returns (IERC20 tok) {
        return IERC20(address(pair0));
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual override {
        _deployWeightedHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _donatePair(address d, IERC20 tok, uint256 amount) internal {
        SimpleMintableERC20(address(tok)).mint(detfUser, amount);
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        tok.approve(nft_, amount);
        tok.approve(d, amount);
        IUniswapV4Detf(d).donate(tok, amount, false);
        vm.stopPrank();
    }



    function _pushSyntheticUp(address d) internal virtual override {
        _policyBuyFromReserve(d);
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut)
        internal
        virtual
        override
        returns (uint256 amountOut)
    {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        if (!info.isBurningAllowed(tokenOut)) {
            IUniswapV4Detf.IoRoute[] memory rows_ = info.burnRoutes();
            for (uint256 i; i < rows_.length; ++i) {
                if (info.isBurningAllowed(rows_[i].token)) {
                    tokenOut = rows_[i].token;
                    break;
                }
            }
        }
        return TestBase_UniswapV4Detf_Policy._burnOn(d, detfIn, tokenOut);
    }

    function _skewSyntheticDown(address d) internal virtual override {
        _skewSyntheticDownAmt(d, 80e9);
    }

    function _burnAllowedToken(address d) internal view returns (IERC20 tok) {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IUniswapV4Detf.IoRoute[] memory routes_ = info.burnRoutes();
        for (uint256 i; i < routes_.length; ++i) {
            if (info.isBurningAllowed(routes_[i].token)) return routes_[i].token;
        }
        return IERC20(address(pair0));
    }

    function _mintAllowedToken(address d) internal view returns (IERC20 tok) {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IUniswapV4Detf.IoRoute[] memory routes_ = info.mintRoutes();
        for (uint256 i; i < routes_.length; ++i) {
            if (info.isMintingAllowed(routes_[i].token)) return routes_[i].token;
        }
        return IERC20(address(pair0));
    }
}
