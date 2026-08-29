// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/// @dev Non-SUT hook-shape harness: DETF self-leg plus a pair with `standardExchangeOf == 0`.
contract BarePairHookHarness {
    address public immutable detfToken;
    address public immutable pair;
    address public immutable owner;

    constructor(address detfToken_, address pair_, address owner_) {
        detfToken = detfToken_;
        pair = pair_;
        owner = owner_;
    }

    function tokens() external view returns (address[] memory t) {
        t = new address[](2);
        t[0] = detfToken;
        t[1] = pair;
    }

    function standardExchangeOf(address) external pure returns (address) {
        return address(0);
    }
}

/// @notice Gold-only §7.1 I/O table IDs. No setUp deploy. Stage 11 must not inherit this.
abstract contract UniswapV4Detf_IoTablesGoldBase is TestBase_UniswapV4Detf {
    uint256 internal constant ONE_WAD = 1e18;
    bytes4 internal constant PAIR_AND_SHARE_SAME_LEG = bytes4(keccak256("PairAndShareSameLeg()"));

    /// @notice T7.1: `standardExchangeOf == 0` on a non-DETF `tokens()` entry reverts deploy.
    function test_T7_1_bareStandardExchange_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "BareSE";
        args.symbol = "BARE";
        address predicted_ = _predictDetf(args);
        BarePairHookHarness harness_ = new BarePairHookHarness(predicted_, address(pairToken), predicted_);
        args.hook = address(harness_);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.BarePairForbidden.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    /// @notice T7.3: Custom mint of a bound-SE token not in `hook.tokens()` is allowed; Default omits extras.
    function test_T7_3_customMint_seUnderlying_allowed() public virtual {
        IUniswapV4SeBufferHook hook_ = IUniswapV4SeBufferHook(reserveHook);
        address[] memory hookToks_ = hook_.tokens();
        address[] memory vaultToks_ = IBasicVault(se).vaultTokens();
        IUniswapV4Detf.IoRoute[] memory defMint_ = detfInfo.mintRoutes();
        for (uint256 i; i < vaultToks_.length; ++i) {
            if (_inList(hookToks_, vaultToks_[i])) continue;
            assertFalse(_routeHasToken(defMint_, vaultToks_[i]), "Default omits extra SE underlying");
        }

        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "CustomMintSE";
        args.symbol = "CMSE";
        args.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.mintRoutes = _customMintRoutesIncludingExtras(hookToks_, vaultToks_);
        address custom_ = _deployGoldInstance(args);
        IUniswapV4Detf info = IUniswapV4Detf(custom_);
        _approveUserForDetf(custom_);

        vm.startPrank(detfUser);
        info.bond(
            IERC20(address(pairToken)),
            80 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(info.isReserveLive(), "live");

        IUniswapV4Detf.IoRoute[] memory customMint_ = info.mintRoutes();
        assertTrue(_routeHasToken(customMint_, address(pairToken)), "custom pair");
        assertTrue(_routeHasToken(customMint_, se), "custom share");
        for (uint256 j; j < vaultToks_.length; ++j) {
            if (_inList(hookToks_, vaultToks_[j])) continue;
            assertTrue(_routeHasToken(customMint_, vaultToks_[j]), "custom extra SE underlying");
        }

        uint256 userBefore = IERC20(custom_).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256 minted_ = info.mint(
            IERC20(address(pairToken)),
            5 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted_, 0, "custom mint");
        assertEq(IERC20(custom_).balanceOf(detfUser) - userBefore, minted_, "user DETF");
    }

    /// @notice T7.4: Custom vault not in the hook SE set reverts deploy.
    function test_T7_4_customVault_notHookSe_reverts() public virtual {
        SimpleYieldERC4626 otherVault_ = new SimpleYieldERC4626(pairToken);
        address otherSe_ = _deployERC4626SE(address(otherVault_));
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "BadVault";
        args.symbol = "BADV";
        args.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.mintRoutes = new IUniswapV4Detf.IoRoute[](1);
        args.mintRoutes[0] = IUniswapV4Detf.IoRoute({
            token: IERC20(address(pairToken)),
            vault: IStandardExchange(otherSe_)
        });
        _deployCpHookOnly(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidRouteTable.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    /// @notice T7.7: Live mint of the SE share. pairEq from share-to-pair preview; Gross is swap-quote of pairEq*(1+p).
    function test_T7_7_liveMint_share_pairEqFromPreviewExchangeOut() public virtual {
        _firstBond(100 ether);
        uint256 wrapIn_ = 10 ether;
        vm.startPrank(detfUser);
        uint256 shareAmt_ = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            wrapIn_,
            IERC20(se),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(shareAmt_, 0, "se shares");

        uint256 pairEq_ = IStandardExchange(se).previewExchangeIn(
            IERC20(se), shareAmt_, IERC20(address(pairToken))
        );
        assertGt(pairEq_, 0, "pairEq");
        uint256 shareInForPair_ = IStandardExchange(se).previewExchangeOut(
            IERC20(se), IERC20(address(pairToken)), pairEq_
        );
        assertEq(shareInForPair_, shareAmt_, "previewExchangeOut share-to-pair inverts pairEq");

        uint256 p_ = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        uint256 boosted_ = Math.mulDiv(pairEq_, ONE_WAD + p_, ONE_WAD);
        uint256 swapQuote_ = IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(
            address(pairToken), detf, boosted_
        );
        (uint256 grossPred_, uint256 userPred_,) = detfInfo.previewMint(IERC20(se), shareAmt_);
        assertEq(grossPred_, swapQuote_, "Gross = previewSwapExactIn(pair, detf, pairEq*(1+p))");
        assertGt(userPred_, 0, "user preview");

        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256 userDetf_ = detfInfo.mint(
            IERC20(se),
            shareAmt_,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(userDetf_, userPred_, "preview==exec");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, userDetf_, "user DETF");
        _assertNoJoinableDust();
    }

    /// @notice T7.16: Unified ABI has no exact-out mint/burn. Loupe: those selectors are not on the proxy.
    function test_T7_16_exactOut_absent() public view {
        IDiamondLoupe loupe_ = IDiamondLoupe(detf);
        assertEq(loupe_.facetAddress(IStandardExchangeOut.exchangeOut.selector), address(0), "no exchangeOut");
        assertEq(
            loupe_.facetAddress(IStandardExchangeOut.previewExchangeOut.selector),
            address(0),
            "no previewExchangeOut"
        );
        assertEq(
            loupe_.facetAddress(bytes4(keccak256("mintExactOut(address,uint256,uint256,address,bool,uint256)"))),
            address(0),
            "no mintExactOut"
        );
        assertEq(
            loupe_.facetAddress(bytes4(keccak256("burnExactOut(uint256,address,uint256,address,uint256)"))),
            address(0),
            "no burnExactOut"
        );
    }

    /// @notice T7.17: Pair + share of the same SE in one `joinUnbalanced` reverts.
    function test_T7_17_joinUnbalanced_pairAndShareSameLeg_reverts() public {
        _firstBond(50 ether);
        address[] memory toks_ = new address[](2);
        toks_[0] = address(pairToken);
        toks_[1] = se;
        uint256[] memory amts_ = new uint256[](2);
        amts_[0] = 1 ether;
        amts_[1] = 1 ether;
        vm.prank(detf);
        vm.expectRevert(PAIR_AND_SHARE_SAME_LEG);
        IUniswapV4SeBufferHook(reserveHook).joinUnbalanced(
            toks_, amts_, detf, 0, block.timestamp + 1 hours
        );
    }

    /// @notice T7.18: `reservePool()==hook`. Family `pairToken` / `rateAsset` / `underlyingVault` unknown on the proxy.
    function test_T7_18_noFamilyGetters() public view {
        assertEq(detfInfo.reservePool(), reserveHook, "reservePool=hook");
        IDiamondLoupe loupe_ = IDiamondLoupe(detf);
        assertEq(loupe_.facetAddress(IDetf.pairToken.selector), address(0), "no pairToken()");
        assertEq(loupe_.facetAddress(IDetf.rateAsset.selector), address(0), "no rateAsset()");
        assertEq(loupe_.facetAddress(IDetf.underlyingVault.selector), address(0), "no underlyingVault()");
        assertTrue(
            loupe_.facetAddress(IDetf.claimLiquidity.selector) != address(0),
            "claimLiquidity cut"
        );
        assertTrue(
            loupe_.facetAddress(IDetf.previewClaimLiquidity.selector) != address(0),
            "previewClaimLiquidity cut"
        );
    }

    /// @notice T7.21: Seed a non-joinable leftover; mint still succeeds; public `sweepDust` no-ops or clears joinable dust.
    function test_T7_21_failedDustJoin_doesNotRevertMint() public {
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(detf, 5 ether);
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        uint256 minted_ = detfInfo.mint(
            IERC20(address(pairToken)),
            10 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted_, 0, "mint despite non-joinable leftover");
        assertEq(junk_.balanceOf(detf), 5 ether, "junk leftover remains");
        detfInfo.sweepDust();
        assertEq(junk_.balanceOf(detf), 5 ether, "sweepDust no-ops junk");
        _assertNoJoinableDust();
    }

    /// @dev n-leg gold overrides to the matching hook+DETF deploy.
    function _deployGoldInstance(IUniswapV4Detf.PkgArgs memory args) internal virtual returns (address) {
        return _deployHookThenDetf(args);
    }

    /// @dev Hook only (predicted DETF etched then cleared). Caller sets Custom tables on `args` first.
    function _deployCpHookOnly(IUniswapV4Detf.PkgArgs memory args) internal virtual returns (address predicted_) {
        predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pairToken).code);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se,
                pairToken: address(pairToken),
                rawToken: predicted_,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        reserveHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(predicted_, address(pairToken));
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = reserveHook;
    }

    function _approveUserForDetf(address detf_) internal virtual {
        vm.startPrank(detfUser);
        pairToken.approve(detf_, type(uint256).max);
        IERC20(se).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function _inList(address[] memory list_, address token_) internal pure returns (bool) {
        for (uint256 i; i < list_.length; ++i) {
            if (list_[i] == token_) return true;
        }
        return false;
    }

    function _routeHasToken(IUniswapV4Detf.IoRoute[] memory rows_, address token_)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < rows_.length; ++i) {
            if (address(rows_[i].token) == token_) return true;
        }
        return false;
    }

    function _customMintRoutesIncludingExtras(address[] memory hookToks_, address[] memory vaultToks_)
        internal
        view
        returns (IUniswapV4Detf.IoRoute[] memory rows_)
    {
        uint256 extra_;
        for (uint256 i; i < vaultToks_.length; ++i) {
            if (!_inList(hookToks_, vaultToks_[i])) {
                unchecked {
                    ++extra_;
                }
            }
        }
        rows_ = new IUniswapV4Detf.IoRoute[](2 + extra_);
        rows_[0] = IUniswapV4Detf.IoRoute({
            token: IERC20(address(pairToken)),
            vault: IStandardExchange(se)
        });
        rows_[1] = IUniswapV4Detf.IoRoute({token: IERC20(se), vault: IStandardExchange(se)});
        uint256 w_ = 2;
        for (uint256 j; j < vaultToks_.length; ++j) {
            if (_inList(hookToks_, vaultToks_[j])) continue;
            rows_[w_] = IUniswapV4Detf.IoRoute({
                token: IERC20(vaultToks_[j]),
                vault: IStandardExchange(se)
            });
            unchecked {
                ++w_;
            }
        }
    }
}
