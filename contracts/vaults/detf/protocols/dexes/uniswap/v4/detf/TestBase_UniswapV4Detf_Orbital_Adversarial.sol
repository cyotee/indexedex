// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {
    TestBase_UniswapV4Detf_Adversarial,
    UniV4DetfPretransferHelper
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_Adversarial
 * @notice Orbital gold adversarial helpers. Orbital.setUp first; do not call CP TestBase.setUp.
 * @dev E6 N/A no residual-return. Deferred T-NEST-4..8.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_Adversarial is
    TestBase_UniswapV4Detf_Orbital,
    TestBase_UniswapV4Detf_Adversarial
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf_Orbital, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Orbital.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        preHelper = new UniV4DetfPretransferHelper();
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

    function _deployHookThenDetfForPair(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    ) internal virtual override returns (address detf_) {
        address predicted_ = _bindHostileOrbitalHook(args, pair_, se_);
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "hostile detf != predicted");
        _setBondTermsOn(detf_, DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        vm.label(detf_, args.symbol);
    }

    function _bindHostileOrbitalHook(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    ) internal returns (address predicted_) {
        address pairB_ = pair_ == address(pair1) ? address(pair0) : address(pair1);
        predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pair0).code);
        (address t0, address t1, address t2) = _sort3(predicted_, pair_, pairB_);
        address seB_ = pairB_ == address(pair0) ? se0 : se1;
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory hArgs;
        hArgs.poolManager = address(pm);
        hArgs.feeOracle = address(indexedexManager);
        hArgs.token0 = t0;
        hArgs.token1 = t1;
        hArgs.token2 = t2;
        hArgs.se0 = _hostileSeOf(t0, predicted_, pair_, se_, seB_);
        hArgs.se1 = _hostileSeOf(t1, predicted_, pair_, se_, seB_);
        hArgs.se2 = _hostileSeOf(t2, predicted_, pair_, se_, seB_);
        hArgs.ownerOnlyLiquidity = true;
        hArgs.owner = predicted_;
        uint256 mineNonce = OrbitalFactory.findMineNonce(hookFactory, orbitalHookPkg, hArgs);
        address hook_ = OrbitalFactory.deployHook(orbitalHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        require(init.finalizeInitialization(), "finalize hostile");
        vm.etch(predicted_, "");
        args.hook = hook_;
        vm.label(hook_, "hostileOrbitalHook");
    }

    function _hostileSeOf(
        address token_,
        address predicted_,
        address pair_,
        address se_,
        address seB_
    ) internal pure returns (address) {
        if (token_ == predicted_) return address(0);
        if (token_ == pair_) return se_;
        return seB_;
    }
}
