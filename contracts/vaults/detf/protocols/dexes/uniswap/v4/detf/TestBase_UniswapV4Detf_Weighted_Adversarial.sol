// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedFactory
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {
    TestBase_UniswapV4Detf_Adversarial,
    UniV4DetfPretransferHelper
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_Adversarial
 * @notice Weighted gold adversarial helpers. Weighted.setUp first; do not call CP TestBase.setUp.
 * @dev E6 N/A no residual-return. Deferred T-NEST-4..8.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_Adversarial is
    TestBase_UniswapV4Detf_Weighted,
    TestBase_UniswapV4Detf_Adversarial
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Weighted, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Weighted.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        preHelper = new UniV4DetfPretransferHelper();
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

    function _uniqueDetfArgs(string memory tag_)
        internal
        view
        virtual
        override
        returns (IUniswapV4Detf.PkgArgs memory args)
    {
        args = _nLegDetfArgs(2);
        args.name = string.concat("UniV4 DETF ", tag_);
        args.symbol = string.concat("uv4", tag_);
    }

    function _approveUserForDetf(address detf_) internal virtual override {
        vm.startPrank(detfUser);
        pair0.approve(detf_, type(uint256).max);
        pair1.approve(detf_, type(uint256).max);
        IERC20(se0).approve(detf_, type(uint256).max);
        IERC20(se1).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function _bindHostileWeightedHook(
        IUniswapV4Detf.PkgArgs memory args,
        address pairA_,
        address seA_,
        address pairB_,
        address seB_
    ) internal returns (address predicted_) {
        predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pair0).code);
        address[] memory toks = new address[](3);
        toks[0] = predicted_;
        toks[1] = pairA_;
        toks[2] = pairB_;
        _sortInPlace(toks);
        uint256[] memory w = new uint256[](3);
        w[0] = 4e17;
        w[1] = 3e17;
        w[2] = 3e17;
        address[] memory ses = new address[](3);
        address[] memory rps = new address[](3);
        for (uint256 i; i < 3; ++i) {
            if (toks[i] == predicted_) ses[i] = address(0);
            else if (toks[i] == pairA_) ses[i] = seA_;
            else ses[i] = seB_;
        }
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                n: 3,
                tokens: toks,
                weights: w,
                standardExchanges: ses,
                rateProviders: rps,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = WeightedFactory.findMineNonce(hookFactory, weightedHookPkg, hArgs);
        address hook_ = WeightedFactory.deployHook(weightedHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[1], toks[2]);
        require(init.finalizeInitialization(), "finalize hostile");
        vm.etch(predicted_, "");
        args.hook = hook_;
        vm.label(hook_, "hostileWeightedHook");
    }

    function _deployHookThenDetfForPair(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    ) internal virtual override returns (address detf_) {
        address pairB_ = pair_ == address(pair1) ? address(pair0) : address(pair1);
        address seB_ = pairB_ == address(pair0) ? se0 : se1;
        address predicted_ = _bindHostileWeightedHook(args, pair_, se_, pairB_, seB_);
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "hostile detf != predicted");
        _setBondTermsOn(detf_, DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        vm.label(detf_, args.symbol);
    }
}
