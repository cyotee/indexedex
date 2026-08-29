// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {
    TestBase_UniswapV4Detf_Adversarial,
    UniV4DetfPretransferHelper
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_Adversarial
 * @notice Quad gold adversarial helpers. Quad.setUp first; do not call CP TestBase.setUp.
 * @dev E6 N/A no residual-return. Deferred T-NEST-4..8. Donate/I1 use pair0.
 */
abstract contract TestBase_UniswapV4Detf_Quad_Adversarial is
    TestBase_UniswapV4Detf_Quad,
    TestBase_UniswapV4Detf_Adversarial
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Quad.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        preHelper = new UniV4DetfPretransferHelper();
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

    function _uniqueDetfArgs(string memory tag_)
        internal
        view
        virtual
        override
        returns (IUniswapV4Detf.PkgArgs memory args)
    {
        args = _nLegDetfArgs(3);
        args.name = string.concat("UniV4 DETF ", tag_);
        args.symbol = string.concat("uv4", tag_);
    }

    function _approveUserForDetf(address detf_) internal virtual override {
        vm.startPrank(detfUser);
        pair0.approve(detf_, type(uint256).max);
        pair1.approve(detf_, type(uint256).max);
        pair2.approve(detf_, type(uint256).max);
        IERC20(se0).approve(detf_, type(uint256).max);
        IERC20(se1).approve(detf_, type(uint256).max);
        IERC20(se2).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function _deployHookThenDetfForPair(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    ) internal virtual override returns (address detf_) {
        address predicted_ = _predictDetf(args);
        address hook_ = _deployHostileQuadHook(predicted_, pair_, se_);
        args.hook = hook_;
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "hostile detf != predicted");
        _setBondTermsOn(detf_, DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        vm.label(detf_, args.symbol);
        vm.label(hook_, "hostileQuadHook");
    }

    function _deployHostileQuadHook(address predicted_, address pair_, address se_)
        internal
        returns (address hook_)
    {
        address pB_ = pair_ == address(pair0) ? address(pair1) : address(pair0);
        address pC_ = (pair_ == address(pair2) || pB_ == address(pair2)) ? address(pair1) : address(pair2);
        if (pC_ == pair_ || pC_ == pB_) pC_ = address(pair2);
        vm.etch(predicted_, address(pair0).code);
        address[4] memory toks;
        toks[0] = predicted_;
        toks[1] = pair_;
        toks[2] = pB_;
        toks[3] = pC_;
        _sort4(toks);
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == predicted_) ses[i] = address(0);
            else if (toks[i] == pair_) ses[i] = se_;
            else if (toks[i] == pB_) ses[i] = pB_ == address(pair0) ? se0 : (pB_ == address(pair1) ? se1 : se2);
            else ses[i] = pC_ == address(pair0) ? se0 : (pC_ == address(pair1) ? se1 : se2);
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
        hook_ = QuadFactory.deployHook(quadHookPkg, hArgs, QuadFactory.findMineNonce(hookFactory, quadHookPkg, hArgs));
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        init.deployPair(toks[2], toks[3]);
        require(init.finalizeInitialization(), "finalize hostile");
        vm.etch(predicted_, "");
    }
}
