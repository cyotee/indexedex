// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_Policy
 * @notice Quad gold Policy fixture. Quad.setUp then policyCreator. Extra deploys bind a Quad hook.
 * @dev `_deployInstance` → `_deployQuadHookThenDetf`. `_baseArgs` → `_nLegDetfArgs(3)`.
 */
abstract contract TestBase_UniswapV4Detf_Quad_Policy is
    TestBase_UniswapV4Detf_Quad,
    TestBase_UniswapV4Detf_Policy
{
    function setUp() public virtual override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf_Policy) {
        TestBase_UniswapV4Detf_Quad.setUp();
        policyCreator = makeAddr("creator");
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployQuadHookThenDetf(args);
    }

    function _baseArgs() internal virtual override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(3);
    }

    function _firstBond(uint256 pairAmount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _mintTokenOf(address) internal view virtual override returns (IERC20 tok) {
        return IERC20(address(pair0));
    }

    function _fundActor(address d, address who) internal {
        pair0.mint(who, 10_000_000 ether);
        pair1.mint(who, 10_000_000 ether);
        pair2.mint(who, 10_000_000 ether);
        vm.startPrank(who);
        pair0.approve(d, type(uint256).max);
        pair1.approve(d, type(uint256).max);
        pair2.approve(d, type(uint256).max);
        IERC20(se0).approve(d, type(uint256).max);
        IERC20(se1).approve(d, type(uint256).max);
        IERC20(se2).approve(d, type(uint256).max);
        vm.stopPrank();
    }

    function _pushSyntheticUp(address d) internal virtual override {
        _donatePairAmt(d, IERC20(address(pair0)), 80 ether);
        if (IUniswapV4Detf(d).isMintingAllowed()) return;
        _donatePairAmt(d, IERC20(address(pair1)), 80 ether);
        if (IUniswapV4Detf(d).isMintingAllowed()) return;
        _donatePairAmt(d, IERC20(address(pair2)), 80 ether);
        if (IUniswapV4Detf(d).isMintingAllowed()) return;
        _ownerSwap(d, d, address(pair0), 40 ether);
        _ownerSwap(d, d, address(pair1), 40 ether);
        _ownerSwap(d, d, address(pair2), 40 ether);
    }

    function _skewSyntheticDown(address d) internal virtual override {
        if (IUniswapV4Detf(d).isMintingAllowed()) {
            try this.mintExternal(d, 30 ether) {} catch {}
        }
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        if (bal_ > 1 ether) {
            uint256 amt_ = bal_ / 4;
            if (amt_ == 0) amt_ = bal_;
            vm.prank(detfUser);
            IERC20(d).transfer(d, amt_);
            _ownerSwap(d, d, address(pair0), amt_ / 3);
            _ownerSwap(d, d, address(pair1), amt_ / 3);
            _ownerSwap(d, d, address(pair2), amt_ - (amt_ / 3) * 2);
            return;
        }
        _ownerSwap(d, d, address(pair0), 80 ether);
        _ownerSwap(d, d, address(pair1), 80 ether);
        _ownerSwap(d, d, address(pair2), 80 ether);
    }

    function _donatePairAmt(address d, IERC20 tok, uint256 amount) internal {
        SimpleMintableERC20(address(tok)).mint(detfUser, amount);
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        tok.approve(nft_, amount);
        tok.approve(d, amount);
        IUniswapV4Detf(d).donate(tok, amount, false);
        vm.stopPrank();
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

    /// @dev Bind a Quad hook at the predicted DETF, then `deployVault` must revert InvalidCreationRate.
    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual override {
        address predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pair0).code);
        address[4] memory toks;
        toks[0] = predicted_;
        toks[1] = address(pair0);
        toks[2] = address(pair1);
        toks[3] = address(pair2);
        _sort4(toks);
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == predicted_) ses[i] = address(0);
            else if (toks[i] == address(pair0)) ses[i] = se0;
            else if (toks[i] == address(pair1)) ses[i] = se1;
            else ses[i] = se2;
        }
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                tokens: toks,
                standardExchanges: ses,
                rateProviders: rps,
                baseAmp: QUAD_BASE_AMP,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = QuadFactory.findMineNonce(hookFactory, quadHookPkg, hArgs);
        address hook_ = QuadFactory.deployHook(quadHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        init.deployPair(toks[2], toks[3]);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = hook_;
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }
}
