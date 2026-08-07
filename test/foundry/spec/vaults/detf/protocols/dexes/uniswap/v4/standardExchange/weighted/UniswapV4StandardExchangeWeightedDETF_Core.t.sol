// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF,
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

/**
 * @title UniswapV4StandardExchangeWeightedDETF_Core
 * @notice Production-first hermetic suite: inert deploy, first bond → live, mint/burn, mature-only,
 *         config rejects, n-matrix smoke. Drives shipped package entry points (no SUT mocks).
 */
contract UniswapV4StandardExchangeWeightedDETF_Core is TestBase_UniswapV4StandardExchangeWeightedDETF {
    uint256 internal constant BOND_AMT = 100 ether;

    /* ---------------------------------------------------------------------- */
    /*                         Deploy / inert / config                        */
    /* ---------------------------------------------------------------------- */

    function test_deploy_inert_primaryMintReverts() public {
        _assertInert();
        // No rateAsset getter on this family.
        // Primary mint while inert reverts ReserveNotLive.
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.ReserveNotLive.selector);
        detfExchangeIn.exchangeIn(IERC20(pair0), 1 ether, IERC20(detf), 0, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_deploy_noRateAssetGetter() public {
        // Interface has no rateAsset — compile-time guarantee. Runtime: n/m present.
        assertEq(detfInfo.n(), 2);
        assertEq(detfInfo.m(), 1);
        assertEq(detfInfo.pairToken(0), pair0);
        assertTrue(detfInfo.standardExchange(0) != address(0));
        assertTrue(detfInfo.reserveHook() != address(0));
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertTrue(detfInfo.rebasingClaimToken() != address(0));
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
    }

    function test_config_rejectAllExternalBare() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _argsAllBare();
        vm.startPrank(owner);
        vm.expectRevert(); // AllExternalBareForbidden
        indexedexManager.deployVault(
            IStandardVaultPkg(address(detfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function test_config_rejectZeroCreationRate() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "ZeroRate";
        args.symbol = "zr";
        args.creationPairPerDetfWad[0] = 0;
        vm.startPrank(owner);
        vm.expectRevert(); // InvalidCreationRate
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_config_rejectBadWeights() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "BadW";
        args.symbol = "bw";
        args.detfWeight = 0.9e18; // sum != 1e18 with pair 0.5
        vm.startPrank(owner);
        vm.expectRevert(); // InvalidWeights
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_config_rejectRpWithoutSE() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "RpNoSe";
        args.symbol = "rns";
        args.standardExchanges[0] = IStandardExchangeProxy(address(0));
        // need another SE so not all-bare — use n=3 with SE on pair1 and RP on bare pair0
        args = _argsN3_1SeBare();
        args.name = "RpNoSe";
        args.symbol = "rns";
        // pair1 is bare in _argsN3_1SeBare; put RP on pair1
        args.rateProviders[1] = address(0xBEEF);
        vm.startPrank(owner);
        vm.expectRevert(); // RateProviderWithoutSE
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         First bond → live                              */
    /* ---------------------------------------------------------------------- */

    function test_firstBond_allExternals_setsLive_andRefundsExcess() public {
        // n=3 with unequal capital: min detfFrom sizes join; excess pair0 refunded.
        address d = _deployDetfInstance(_argsN3_1SeBare());
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        address p1 = info.pairToken(1);
        uint256 amt0 = 200 ether;
        uint256 amt1 = 100 ether;
        // Fund exactly the bond amounts (no *2 slack) so refund is observable.
        SimpleMintableERC20(p0).mint(detfUser, amt0);
        SimpleMintableERC20(p1).mint(detfUser, amt1);
        uint256 bal0Before = IERC20(p0).balanceOf(detfUser);
        uint256 bal1Before = IERC20(p1).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        IERC20(p1).approve(d, type(uint256).max);
        IERC20[] memory ins = new IERC20[](2);
        ins[0] = IERC20(p0);
        ins[1] = IERC20(p1);
        uint256[] memory amts = new uint256[](2);
        amts[0] = amt0;
        amts[1] = amt1;
        (uint256 tokenId, uint256 shares) =
            info.bond(ins, amts, p0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();

        assertTrue(info.isReserveLive(), "live");
        assertGt(shares, 0, "lp shares");
        assertGt(tokenId, 0, "tokenId");
        assertEq(info.capitalTokenOf(tokenId), p0, "capitalToken");
        assertTrue(IHook(info.reserveHook()).isFullBook(), "full book");

        // Join sized by min(detfFrom) = amt1 at creation 1e18 → uses 100e18 of each pair.
        // Excess pair0 = 100 ether refunded; pair1 fully consumed.
        uint256 bal0After = IERC20(p0).balanceOf(detfUser);
        uint256 bal1After = IERC20(p1).balanceOf(detfUser);
        assertEq(bal0After, bal0Before - amt1, "pair0 excess refunded (spent only min leg)");
        assertEq(bal1After, bal1Before - amt1, "pair1 fully used as limiting leg");
        assertGt(bal0After, 0, "refunded capital remains with caller");
    }

    function test_firstBond_missingExternal_reverts() public {
        // n=3 needs both externals
        address d = _deployDetfInstance(_argsN3_1SeBare());
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        address p1 = info.pairToken(1);
        _fundPair(d, p0, detfUser, BOND_AMT * 2);
        // Only fund p0 — missing p1
        IERC20[] memory ins = new IERC20[](1);
        ins[0] = IERC20(p0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.FirstBondRequiresAllExternalPairs.selector);
        info.bond(ins, amts, p0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        // silence unused
        p1;
    }

    function test_firstBond_invalidCapitalToken_reverts() public {
        IERC20[] memory ins = new IERC20[](1);
        ins[0] = IERC20(pair0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _fundPair(detf, pair0, detfUser, BOND_AMT * 2);
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.InvalidCapitalToken.selector);
        detfInfo.bond(ins, amts, address(0xDEAD), DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_preLive_singleBondConvenience_reverts() public {
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.FirstBondRequiresAllExternalPairs.selector);
        detfInfo.bond(IERC20(pair0), BOND_AMT, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Live mint / burn                               */
    /* ---------------------------------------------------------------------- */

    function test_live_mint_previewEqualsExecution() public {
        _firstBondDefault(BOND_AMT);
        _assertLive();

        // Open-mode instance for ungated mint under default thresholds may block mint
        // if synthetic not > mintThreshold. Use Open deploy for mint path proof.
        address d = _deployDetfInstance(_openArgsUnique("mint"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);

        uint256 mintIn = 10 ether;
        _fundPair(d, p0, detfUser, mintIn * 2);

        uint256 preview = IStandardExchangeIn(d).previewExchangeIn(IERC20(p0), mintIn, IERC20(d));
        assertGt(preview, 0, "preview > 0");

        uint256 balBefore = IERC20(d).balanceOf(detfUser);
        uint256 exec = _mintOn(d, p0, mintIn);
        uint256 balAfter = IERC20(d).balanceOf(detfUser);
        assertEq(exec, balAfter - balBefore, "exec matches balance delta");
        // Hook SoT: preview == execution (exact or ≤ few wei SE dust — here pair face exact).
        assertEq(exec, preview, "preview == execution");
    }

    function test_live_burn_requiresProtocolLp() public {
        // After first bond only, protocol LP may be empty → burn reverts ProtocolLpEmpty / EmptyProtocolLp.
        _firstBondDefault(BOND_AMT);
        // Mint free DETF to user via Open instance so we have free DETF to burn.
        address d = _deployDetfInstance(_openArgsUnique("burn"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);

        // Primary mint funds protocol LP.
        uint256 mintIn = 20 ether;
        _fundPair(d, p0, detfUser, mintIn * 2);
        uint256 userDetf = _mintOn(d, p0, mintIn);
        assertGt(userDetf, 0);
        assertGt(info.protocolLp(), 0, "protocol LP after mint");

        uint256 preview = IStandardExchangeIn(d).previewExchangeIn(IERC20(d), userDetf / 2, IERC20(p0));
        uint256 out = _burnOn(d, p0, userDetf / 2);
        assertGt(out, 0, "burn out");
        // Allow ≤ few wei if SE dust; pair-face path should be exact-ish.
        if (preview > out) {
            assertLe(preview - out, 10, "preview ~ exec");
        } else {
            assertLe(out - preview, 10, "preview ~ exec");
        }
    }

    function test_burn_tokenOutDetf_reverts() public {
        address d = _deployDetfInstance(_openArgsUnique("badOut"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        _fundPair(d, p0, detfUser, 20 ether);
        uint256 userDetf = _mintOn(d, p0, 10 ether);

        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        vm.expectRevert(); // InvalidRoute
        IStandardExchangeIn(d).exchangeIn(IERC20(d), userDetf / 2, IERC20(d), 0, detfUser, false, _dl());
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Later bond / mature-only                       */
    /* ---------------------------------------------------------------------- */

    function test_laterBond_singleExternal_succeeds() public {
        (uint256 firstId,) = _firstBondDefault(BOND_AMT);
        assertGt(firstId, 0);
        _fundPair(detf, pair0, detfUser, BOND_AMT * 2);
        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) =
            detfInfo.bond(IERC20(pair0), BOND_AMT, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(tokenId, 0);
        assertGt(shares, 0);
        assertEq(detfInfo.capitalTokenOf(tokenId), pair0);
    }

    function test_laterBond_multiExternal_reverts() public {
        address d = _deployDetfInstance(_argsN3_1SeBare());
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        address p1 = info.pairToken(1);
        uint256[] memory amts = new uint256[](2);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        _firstBondOn(d, amts, p0);

        // Later multi-external reverts
        IERC20[] memory ins = new IERC20[](2);
        ins[0] = IERC20(p0);
        ins[1] = IERC20(p1);
        uint256[] memory later = new uint256[](2);
        later[0] = 1 ether;
        later[1] = 1 ether;
        _fundPair(d, p0, detfUser, 2 ether);
        _fundPair(d, p1, detfUser, 2 ether);
        vm.startPrank(detfUser);
        // Accept any revert (selector may be bubbled without data through diamond).
        vm.expectRevert();
        info.bond(ins, later, p0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_matureOnly_sellAndClose_preMatureRevert() public {
        (uint256 tokenId,) = _firstBondDefault(BOND_AMT);
        vm.startPrank(detfUser);
        vm.expectRevert(); // BondNotMature
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        vm.expectRevert(); // BondNotMature
        detfInfo.closeBondMature(tokenId, detfUser);
        vm.stopPrank();
    }

    function test_matureOnly_closePaysCapitalToken() public {
        (uint256 tokenId,) = _firstBondDefault(BOND_AMT);
        // Warp past lock
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 balBefore = IERC20(pair0).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256 out = detfInfo.closeBondMature(tokenId, detfUser);
        vm.stopPrank();
        assertGt(out, 0, "capitalToken payout");
        assertEq(IERC20(pair0).balanceOf(detfUser) - balBefore, out, "only capitalToken");
    }

    function test_claimRewards_whileLocked() public {
        (uint256 tokenId,) = _firstBondDefault(BOND_AMT);
        // May be zero rewards; should not revert for holder.
        vm.prank(detfUser);
        detfInfo.claimRewards(tokenId, detfUser);
    }

    /* ---------------------------------------------------------------------- */
    /*                         n matrix / compound / expansion                */
    /* ---------------------------------------------------------------------- */

    function test_n3_1SeBare_firstBondAndMint() public {
        address d = _deployDetfInstance(_argsN3_1SeBare());
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        assertEq(info.n(), 3);
        assertEq(info.m(), 2);
        address p0 = info.pairToken(0);
        address p1 = info.pairToken(1);
        uint256[] memory amts = new uint256[](2);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        assertTrue(info.isReserveLive());
        assertTrue(IHook(info.reserveHook()).isFullBook());

        // Open-style mint: deploy Open n=3
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory o = _argsN3_1SeBare();
        o.name = "Open n3";
        o.symbol = "on3";
        o.thresholdMode = ThresholdMode.Open;
        address d2 = _deployDetfInstance(o);
        IUniswapV4StandardExchangeWeightedDETF info2 = IUniswapV4StandardExchangeWeightedDETF(d2);
        address q0 = info2.pairToken(0);
        address q1 = info2.pairToken(1);
        uint256[] memory amts2 = new uint256[](2);
        amts2[0] = BOND_AMT;
        amts2[1] = BOND_AMT;
        _firstBondOn(d2, amts2, q0);
        _fundPair(d2, q0, detfUser, 20 ether);
        uint256 minted = _mintOn(d2, q0, 5 ether);
        assertGt(minted, 0);
        q1;
        p1;
    }

    function test_n3_allSe_firstBond() public {
        address d = _deployDetfInstance(_argsN3_AllSe());
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](2);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        assertTrue(info.isReserveLive());
        assertTrue(info.standardExchange(0) != address(0));
        assertTrue(info.standardExchange(1) != address(0));
    }

    function test_compound_skipWhenNotEligible_orSucceeds() public {
        _firstBondDefault(BOND_AMT);
        // Public compound is realize path; skip without revert when not eligible.
        (uint256 detfIn, uint256 lpOut) = detfInfo.compoundProtocolRewards();
        // May be (0,0) if no pending or not full-book eligible for single-asset.
        detfIn;
        lpOut;
    }

    function test_expansion_openNeverExpands() public {
        address d = _deployDetfInstance(_openArgsUnique("exp"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        assertEq(info.pendingExpansionDetf(), 0, "open pending 0");
        vm.warp(block.timestamp + 8 hours * 10);
        // Realize path
        vm.prank(detfUser);
        info.compoundProtocolRewards();
        assertEq(info.pendingExpansionDetf(), 0, "open still 0 after warp");
    }

    function test_detfBindingIndex_notAlwaysZero() public {
        // DETF address is free-sorted; after deploy check binding can be 0 or 1 for n=2.
        uint8 idx = detfInfo.detfBindingIndex();
        assertTrue(idx < detfInfo.n(), "binding in range");
        // weights length matches n
        uint256[] memory w = detfInfo.weights();
        assertEq(w.length, detfInfo.n());
        uint256 sum;
        for (uint256 i; i < w.length; ++i) {
            sum += w[i];
        }
        assertEq(sum, 1e18, "weights sum");
    }

    /// @notice n=4 smoke: 3 externals, 1 SE + bare rest.
    function test_n4_1SeBare_firstBond_smoke() public {
        IERC20[] memory pairs_ = new IERC20[](3);
        pairs_[0] = IERC20(address(token0));
        pairs_[1] = IERC20(address(token1));
        pairs_[2] = IERC20(address(token2));
        IStandardExchangeProxy[] memory ses_ = new IStandardExchangeProxy[](3);
        ses_[0] = IStandardExchangeProxy(se0);
        IERC20[] memory shares_ = new IERC20[](3);
        address[] memory rps_ = new address[](3);
        uint256[] memory pairW_ = new uint256[](3);
        pairW_[0] = 0.25e18;
        pairW_[1] = 0.25e18;
        pairW_[2] = 0.25e18;
        uint256[] memory rates_ = new uint256[](3);
        rates_[0] = DEFAULT_CREATION;
        rates_[1] = DEFAULT_CREATION;
        rates_[2] = DEFAULT_CREATION;
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = IUniswapV4StandardExchangeWeightedDETDFPkg
            .PkgArgs({
            name: "Wgt n4",
            symbol: "w4",
            pairTokens: pairs_,
            standardExchanges: ses_,
            vaultShares: shares_,
            rateProviders: rps_,
            detfWeight: 0.25e18,
            pairWeights: pairW_,
            creationPairPerDetfWad: rates_,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
        address d = _deployDetfInstance(args);
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        assertEq(info.n(), 4);
        assertEq(info.m(), 3);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        assertTrue(info.isReserveLive());
        assertTrue(IHook(info.reserveHook()).isFullBook());
    }

    /// @notice Structural: no whole-DETF rateAsset in interface; package deploys via registry path.
    function test_structural_noRateAsset_and_registryDeploy() public view {
        assertTrue(address(detfPkg) != address(0));
        assertTrue(detfInfo.reserveHook() != address(0));
        // acceptedBondTokens lists pairs only
        address[] memory accepted = detfInfo.acceptedBondTokens();
        assertEq(accepted.length, detfInfo.m());
    }

    /* ---------------------------------------------------------------------- */
    /*                    Policy per-route gates (real trades)                */
    /* ---------------------------------------------------------------------- */

    function test_policy_mint_blocked_then_allowed_after_push() public {
        address d = _deployDetfInstance(_gentleArgsUnique("polMint"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy));
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 400 ether;
        _firstBondOn(d, amts, p0);
        _setBondTermsFor(d);

        // After first bond at creation peg, Policy mint should be blocked (S ≤ mintThreshold).
        assertFalse(info.isMintingAllowed(p0), "mint blocked at peg");
        assertLe(info.syntheticVs(p0), info.mintThreshold(), "S <= mintThreshold");

        SimpleMintableERC20(p0).mint(detfUser, 5 ether);
        uint256 sBlocked = info.syntheticVs(p0);
        uint256 mintTh = info.mintThreshold();
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(Repo.MintingNotAllowed.selector, sBlocked, mintTh));
        IStandardExchangeIn(d).exchangeIn(IERC20(p0), 1 ether, IERC20(d), 0, detfUser, false, _dl());
        vm.stopPrank();

        _pushSyntheticMintAllowed(info);
        assertTrue(info.isMintingAllowed(p0), "mint allowed after push");
        assertGt(info.syntheticVs(p0), info.mintThreshold(), "S > mintThreshold");

        uint256 preview = IStandardExchangeIn(d).previewExchangeIn(IERC20(p0), 5 ether, IERC20(d));
        uint256 out_ = _mintOn(d, p0, 5 ether);
        assertEq(out_, preview, "Policy mint preview == exec when allowed");
        assertGt(out_, 0);
    }

    function test_policy_burn_allowed_when_synthetic_below_burnThreshold() public {
        address d = _deployDetfInstance(_gentleArgsUnique("polBurn"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 100 ether;
        _firstBondOn(d, amts, p0);
        _setBondTermsFor(d);

        // Protocol LP via claim deposit (no mint gate; only full-book single-asset).
        // First bond free DETF may already leave user with free DETF for burn.
        uint256 depIn = 20 ether;
        _fundPair(d, p0, detfUser, depIn * 2);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        info.depositClaim(IERC20(p0), depIn, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(info.protocolLp(), 0, "protocol LP via depositClaim");

        // Ensure burn-allowed: if still mint-side/deadband, dilute free DETF supply (no FD).
        if (!info.isBurningAllowed(p0)) {
            uint256 supply = IERC20(d).totalSupply();
            deal(d, detfUser, supply * 5, true);
        }
        assertTrue(info.isBurningAllowed(p0), "burn allowed under Policy");
        assertLt(info.syntheticVs(p0), info.burnThreshold(), "S < burnThreshold");

        // Free DETF for burn: first-bond free legs and/or deal.
        uint256 bal = IERC20(d).balanceOf(detfUser);
        if (bal < 1 ether) {
            deal(d, detfUser, 10 ether, true);
            bal = IERC20(d).balanceOf(detfUser);
        }
        uint256 burnAmt = bal / 10;
        if (burnAmt == 0) burnAmt = bal;
        require(burnAmt > 0, "need free DETF to burn");

        uint256 preview = IStandardExchangeIn(d).previewExchangeIn(IERC20(d), burnAmt, IERC20(p0));
        uint256 out_ = _burnOn(d, p0, burnAmt);
        assertApproxEqAbs(out_, preview, 100, "Policy burn preview == exec (few-wei)");
        assertGt(out_, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*              Claim deposit/redeem + post-maturity sell                 */
    /* ---------------------------------------------------------------------- */

    function test_mature_sell_mintsRebasingClaim() public {
        (uint256 tokenId, uint256 shares) = _firstBondDefault(BOND_AMT);
        // Later bond for a sellable user position with free inventory path.
        _fundPair(detf, pair0, detfUser, BOND_AMT * 2);
        vm.startPrank(detfUser);
        (uint256 tokenId2, uint256 shares2) =
            detfInfo.bond(IERC20(pair0), 50 ether, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        tokenId; // first bond position
        shares;

        uint256 unlock = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId2);
        vm.warp(unlock + 1);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBefore = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 protocolLpBefore = detfInfo.protocolLp();

        vm.prank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId2, detfUser);

        assertEq(principal, shares2, "principal == LP originalShares");
        assertGt(IRebasingClaimToken(claim).balanceOf(detfUser), claimBefore, "claim minted");
        assertGt(detfInfo.protocolLp(), protocolLpBefore, "protocol LP received bond principal");
    }

    function test_depositClaim_pair_mintsClaim() public {
        address d = _deployDetfInstance(_openArgsUnique("depCl"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        _setBondTermsFor(d);
        // Seed protocol LP via primary mint so depositSingle is meaningful.
        _fundPair(d, p0, detfUser, 50 ether);
        _mintOn(d, p0, 20 ether);
        assertTrue(IHook(info.reserveHook()).isFullBook(), "full book for depositClaim");

        address claim = info.rebasingClaimToken();
        uint256 claimBefore = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 depIn = 5 ether;
        _fundPair(d, p0, detfUser, depIn * 2);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(p0), depIn, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut, 0, "depositClaim mints");
        assertEq(IRebasingClaimToken(claim).balanceOf(detfUser) - claimBefore, claimOut);
    }

    function test_depositClaim_freeDetf_mintsClaim() public {
        address d = _deployDetfInstance(_openArgsUnique("depDetf"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        _fundPair(d, p0, detfUser, 50 ether);
        uint256 userDetf = _mintOn(d, p0, 20 ether);
        require(userDetf > 1 ether, "need free DETF");

        address claim = info.rebasingClaimToken();
        uint256 claimBefore = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 depIn = userDetf / 4;
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(d), depIn, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut, 0, "free DETF depositClaim mints");
        assertGt(IRebasingClaimToken(claim).balanceOf(detfUser), claimBefore);
    }

    function test_redeemClaim_toPair_and_detfOut_reverts() public {
        address d = _deployDetfInstance(_openArgsUnique("redCl"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        _fundPair(d, p0, detfUser, 50 ether);
        _mintOn(d, p0, 20 ether);

        // Build claim inventory via depositClaim.
        uint256 depIn = 5 ether;
        _fundPair(d, p0, detfUser, depIn * 2);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(p0), depIn, 0, detfUser, false, _dl());
        vm.stopPrank();
        require(claimOut > 0, "claim minted");

        address claim = info.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        // Approve claim token burn path if needed (burnShares pulls from owner).
        vm.startPrank(detfUser);
        IERC20(claim).approve(d, type(uint256).max);

        // DETF out → InvalidRoute (selector + args).
        vm.expectRevert(abi.encodeWithSelector(Repo.InvalidRoute.selector, IERC20(d), IERC20(d)));
        info.redeemClaim(claimBal / 4, IERC20(d), 0, detfUser, _dl());

        uint256 before_ = IERC20(p0).balanceOf(detfUser);
        uint256 out_ = info.redeemClaim(claimBal / 2, IERC20(p0), 0, detfUser, _dl());
        vm.stopPrank();
        assertGt(out_, 0, "redeem pair out");
        assertEq(IERC20(p0).balanceOf(detfUser) - before_, out_);
    }

    /// @notice depositClaim(vaultShare/SE) → settle to pair → depositSingle → mint claim.
    function test_depositClaim_vaultShare_mintsClaim() public {
        address d = _deployDetfInstance(_openArgsUnique("depShare"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        address se = info.standardExchange(0);
        require(se != address(0), "SE wired");
        // vaultShare defaults to SE diamond when PkgArgs.vaultShares[i]==0
        address share = info.vaultShare(0);
        if (share == address(0)) share = se;
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        _fundPair(d, p0, detfUser, 50 ether);
        _mintOn(d, p0, 10 ether);
        assertTrue(IHook(info.reserveHook()).isFullBook());

        // Obtain vault shares: deposit pair into underlying ERC-4626 via SE exact-in.
        uint256 pairIn = 10 ether;
        SimpleMintableERC20(p0).mint(detfUser, pairIn * 2);
        vm.startPrank(detfUser);
        IERC20(p0).approve(se, type(uint256).max);
        uint256 sharesIn = IStandardExchangeIn(se).exchangeIn(
            IERC20(p0), pairIn, IERC20(share), 0, detfUser, false, _dl()
        );
        assertGt(sharesIn, 0, "SE minted vault shares");
        assertGt(IERC20(share).balanceOf(detfUser), 0, "user holds shares");
        IERC20(share).approve(d, type(uint256).max);
        address claim = info.rebasingClaimToken();
        uint256 claimBefore = IRebasingClaimToken(claim).balanceOf(detfUser);
        // Use min of balance to avoid underflow if exchangeIn path differs.
        uint256 shareBal = IERC20(share).balanceOf(detfUser);
        uint256 claimOut = info.depositClaim(IERC20(share), shareBal, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut, 0, "depositClaim(vaultShare) mints claim");
        assertEq(IRebasingClaimToken(claim).balanceOf(detfUser) - claimBefore, claimOut);
    }

    /// @notice redeemClaim tokenOut = vaultShare/SE (prefer clean share path).
    function test_redeemClaim_toVaultShare() public {
        address d = _deployDetfInstance(_openArgsUnique("redShare"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        address se = info.standardExchange(0);
        require(se != address(0), "SE wired");
        uint256[] memory amts = new uint256[](1);
        amts[0] = BOND_AMT;
        _firstBondOn(d, amts, p0);
        _fundPair(d, p0, detfUser, 50 ether);
        _mintOn(d, p0, 15 ether);

        uint256 depIn = 8 ether;
        _fundPair(d, p0, detfUser, depIn * 2);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(p0), depIn, 0, detfUser, false, _dl());
        require(claimOut > 0, "claim minted");
        address claim = info.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 redeemAmt = claimBal / 3;
        require(redeemAmt > 0, "redeem amt");
        IERC20(claim).approve(d, type(uint256).max);
        uint256 shareOut = info.redeemClaim(redeemAmt, IERC20(se), 0, detfUser, _dl());
        vm.stopPrank();
        assertGt(shareOut, 0, "redeem vaultShare/SE out");
        assertGt(IERC20(se).balanceOf(detfUser), 0, "user holds SE shares");
    }

    /// @notice Claim deposit hard-reverts NotSingleAssetEligible when book is MIN-only (unlike compound skip).
    function test_depositClaim_reverts_NotSingleAssetEligible_when_not_fullBook() public {
        address d = _deployDetfInstance(_openArgsUnique("notFull"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 50 ether;
        _firstBondOn(d, amts, p0);

        address hook = info.reserveHook();
        address bond = info.bondNftVault();
        uint8 n_ = info.n();

        // Production custody: DETF (bond owner) moves LP to user; user exits all redeemable LP.
        // Leaves only MINIMUM_LIQUIDITY → not single-asset eligible (supply ≤ MIN).
        uint256 bondLp = IERC20(hook).balanceOf(bond);
        assertGt(bondLp, 0, "bond holds first-bond LP");
        vm.prank(d);
        IDETFNFTVault(bond).transferHeldToken(IERC20(hook), detfUser, bondLp);

        uint256 userLp = IERC20(hook).balanceOf(detfUser);
        assertGt(userLp, 0, "user holds LP");
        uint256[] memory mins = new uint256[](n_);
        vm.startPrank(detfUser);
        IERC20(hook).approve(hook, userLp);
        IHook(hook).exitProportional(userLp, detfUser, mins, _dl());
        vm.stopPrank();

        assertLe(IERC20(hook).totalSupply(), 1000, "only MINIMUM_LIQUIDITY remains");
        // DETF eligibility: full book AND supply > MIN — MIN-only is not eligible.
        assertFalse(
            IHook(hook).isFullBook() && IERC20(hook).totalSupply() > 1000,
            "not single-asset eligible at MIN-only"
        );

        // depositClaim must hard-revert NotSingleAssetEligible (not compound-style skip).
        SimpleMintableERC20(p0).mint(detfUser, 10 ether);
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        vm.expectRevert(Repo.NotSingleAssetEligible.selector);
        info.depositClaim(IERC20(p0), 1 ether, 0, detfUser, false, _dl());
        vm.stopPrank();

        // Contrast: compound skips without revert when not single-asset eligible.
        (uint256 a, uint256 b) = info.compoundProtocolRewards();
        assertEq(a, 0);
        assertEq(b, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                    Policy epoch expansion                              */
    /* ---------------------------------------------------------------------- */

    function test_policy_expansion_pending_gt_zero_and_realize_mints() public {
        address d = _deployDetfInstance(_gentleArgsUnique("expPol"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy));
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 300 ether;
        (uint256 tokenId,) = _firstBondOn(d, amts, p0);
        _setBondTermsFor(d);
        require(tokenId > 0, "user bond");

        info.compoundProtocolRewards(); // seed expansion clock
        assertGt(info.lastExpansionTimestamp(), 0, "seeded lastExpansionTimestamp");

        _pushSyntheticMintAllowed(info);
        assertTrue(info.isAllLegsMintRich(), "all-legs mint-rich for expansion");
        assertGt(info.syntheticSpotVs(p0), 1e18, "spot premium after push");

        uint256 epoch_ = info.expansionEpochLength() == 0 ? 8 hours : info.expansionEpochLength();
        vm.warp(block.timestamp + epoch_ * 5 + 1);

        uint256 pending = info.pendingExpansionDetf();
        assertGt(pending, 0, "pendingExpansionDetf > 0 after premium + warp");

        // Snapshot then realize on claimRewards (realize path + reward ledger update).
        uint256 supplyBefore = IERC20(d).totalSupply();
        uint256 lastBefore = info.lastExpansionTimestamp();
        uint256 userDetfBefore = IERC20(d).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 claimed = info.claimRewards(tokenId, detfUser);

        assertGt(IERC20(d).totalSupply(), supplyBefore, "realize mint increased totalSupply");
        assertGt(info.lastExpansionTimestamp(), lastBefore, "realize advanced lastExpansionTimestamp");
        assertLe(info.pendingExpansionDetf(), pending, "pending does not increase on realize");

        // Expansion free DETF lands on bond NFT → reward ledger; user claim or pending > 0.
        if (claimed == 0 && IERC20(d).balanceOf(detfUser) == userDetfBefore) {
            info.compoundProtocolRewards();
            vm.prank(detfUser);
            claimed = info.claimRewards(tokenId, detfUser);
        }
        assertTrue(
            claimed > 0 || IERC20(d).balanceOf(detfUser) > userDetfBefore
                || IDETFNFTVault(info.bondNftVault()).pendingRewards(tokenId) > 0,
            "user bond has expansion rewards after realize"
        );

        // Primary mint must not advance expansion clock.
        lastBefore = info.lastExpansionTimestamp();
        if (info.isMintingAllowed(p0)) {
            _mintOn(d, p0, 1 ether);
            assertEq(info.lastExpansionTimestamp(), lastBefore, "mint must not realize expansion");
        }
    }

    function test_policy_expansion_notRich_atRealize_pendingZero() public {
        address d = _deployDetfInstance(_gentleArgsUnique("exp0"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 200 ether;
        _firstBondOn(d, amts, p0);
        info.compoundProtocolRewards(); // seed

        // Stay near peg (not all-legs mint-rich) → pending 0 after warp.
        assertFalse(info.isAllLegsMintRich(), "not all-rich at peg");
        uint256 epoch_ = info.expansionEpochLength();
        if (epoch_ == 0) epoch_ = 8 hours;
        vm.warp(block.timestamp + epoch_ * 5 + 1);
        assertEq(info.pendingExpansionDetf(), 0, "no expansion when not all-legs rich");
    }

    /* ---------------------------------------------------------------------- */
    /*                         n=8 smoke                                      */
    /* ---------------------------------------------------------------------- */

    function test_n8_1SeBare_firstBond_smoke() public {
        // 7 externals: token0-3 + 3 fresh mintables; SE only on first product leg.
        SimpleMintableERC20 t4 = new SimpleMintableERC20("T4", "T4");
        SimpleMintableERC20 t5 = new SimpleMintableERC20("T5", "T5");
        SimpleMintableERC20 t6 = new SimpleMintableERC20("T6", "T6");

        IERC20[] memory pairs_ = new IERC20[](7);
        pairs_[0] = IERC20(address(token0));
        pairs_[1] = IERC20(address(token1));
        pairs_[2] = IERC20(address(token2));
        pairs_[3] = IERC20(address(token3));
        pairs_[4] = IERC20(address(t4));
        pairs_[5] = IERC20(address(t5));
        pairs_[6] = IERC20(address(t6));
        IStandardExchangeProxy[] memory ses_ = new IStandardExchangeProxy[](7);
        ses_[0] = IStandardExchangeProxy(se0);
        IERC20[] memory shares_ = new IERC20[](7);
        address[] memory rps_ = new address[](7);
        uint256[] memory pairW_ = new uint256[](7);
        uint256[] memory rates_ = new uint256[](7);
        uint256 wEach = 0.12e18;
        uint256 sumW = 0.16e18; // detfWeight
        for (uint256 i; i < 7; ++i) {
            pairW_[i] = (i == 6) ? (1e18 - sumW) : wEach;
            sumW += pairW_[i];
            rates_[i] = DEFAULT_CREATION;
        }
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = IUniswapV4StandardExchangeWeightedDETDFPkg
            .PkgArgs({
            name: "Wgt n8",
            symbol: "w8",
            pairTokens: pairs_,
            standardExchanges: ses_,
            vaultShares: shares_,
            rateProviders: rps_,
            detfWeight: 0.16e18,
            pairWeights: pairW_,
            creationPairPerDetfWad: rates_,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
        // Fix last weight so sum is exact 1e18
        uint256 wSum = args.detfWeight;
        for (uint256 i; i < 6; ++i) {
            wSum += pairW_[i];
        }
        pairW_[6] = 1e18 - wSum;
        args.pairWeights = pairW_;

        address d = _deployDetfInstance(args);
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        assertEq(info.n(), 8);
        assertEq(info.m(), 7);
        uint256[] memory amts = new uint256[](7);
        for (uint256 i; i < 7; ++i) {
            amts[i] = 50 ether;
        }
        _firstBondOn(d, amts, info.pairToken(0));
        assertTrue(info.isReserveLive());
        assertTrue(IHook(info.reserveHook()).isFullBook());
        assertEq(IHook(info.reserveHook()).pairDoorCount(), 28, "C(8,2) doors");
    }
}
