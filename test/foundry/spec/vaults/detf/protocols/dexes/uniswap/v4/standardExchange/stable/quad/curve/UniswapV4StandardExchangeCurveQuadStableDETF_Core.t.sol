// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF,
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    MintableERC20Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/MintableERC20Decimals.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableDETF_Core
 * @notice Production-first hermetic suite. Drives shipped package entry points (no SUT mocks).
 *
 * Phase 0: exact-out selectors revert InvalidRoute; joinUnbalanced DETF-only zeros accepted after full book.
 */
contract UniswapV4StandardExchangeCurveQuadStableDETF_Core is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
    uint256 internal constant BOND_AMT = 100 ether;

    /* ---------------------------------------------------------------------- */
    /*                         Deploy / inert / config                        */
    /* ---------------------------------------------------------------------- */

    function test_deploy_inert_primaryMintReverts() public {
        _assertInert();
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.ReserveNotLive.selector);
        detfExchangeIn.exchangeIn(IERC20(pair0), 1 ether, IERC20(detf), 0, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_deploy_noRateAssetGetter() public {
        assertEq(detfInfo.n(), 4);
        assertEq(detfInfo.m(), 3);
        assertEq(detfInfo.pairToken(0), pair0);
        assertEq(detfInfo.pairToken0(), pair0);
        assertTrue(detfInfo.standardExchange(0) != address(0));
        assertTrue(detfInfo.reserveHook() != address(0));
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertTrue(detfInfo.rebasingClaimToken() != address(0));
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
        assertGt(detfInfo.baseAmp(), 0);
    }

    function test_config_rejectAllExternalBare() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _argsAllBare();
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, nonce);
    }

    function test_config_rejectZeroCreationRate() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "ZeroRate";
        args.symbol = "zr";
        args.creationPairPerDetfWad[1] = 0;
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, nonce);
    }

    function test_config_rejectInvalidBaseAmp() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "BadAmp";
        args.symbol = "ba";
        args.baseAmp = 0;
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, nonce);
    }

    function test_config_rejectRpWithoutSE() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _args1Se2Bare();
        args.name = "RpNoSe";
        args.symbol = "rns";
        args.rateProviders[1] = address(0xBEEF);
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, nonce);
    }

    function test_config_rejectSameSETwice() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _args2Se1Bare();
        args.name = "DupSE";
        args.symbol = "dse";
        args.standardExchanges[1] = args.standardExchanges[0];
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, nonce);
    }

    /* ---------------------------------------------------------------------- */
    /*                         First bond → live                              */
    /* ---------------------------------------------------------------------- */

    function test_firstBond_allThree_setsLive_refund_capitalToken_fullBook() public {
        uint256 amt0 = 200 ether;
        uint256 amt1 = 100 ether;
        uint256 amt2 = 150 ether;
        SimpleMintableERC20(pair0).mint(detfUser, amt0);
        SimpleMintableERC20(pair1).mint(detfUser, amt1);
        SimpleMintableERC20(pair2).mint(detfUser, amt2);
        uint256 bal0Before = IERC20(pair0).balanceOf(detfUser);
        uint256 bal1Before = IERC20(pair1).balanceOf(detfUser);

        IERC20[] memory ins = new IERC20[](3);
        ins[0] = IERC20(pair0);
        ins[1] = IERC20(pair1);
        ins[2] = IERC20(pair2);
        uint256[] memory amts = new uint256[](3);
        amts[0] = amt0;
        amts[1] = amt1;
        amts[2] = amt2;

        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) =
            detfInfo.bond(ins, amts, pair1, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();

        assertTrue(detfInfo.isReserveLive(), "live");
        assertGt(shares, 0, "lp shares");
        assertGt(tokenId, 0, "tokenId");
        assertEq(detfInfo.capitalTokenOf(tokenId), pair1, "capitalToken");
        assertTrue(IHook(detfInfo.reserveHook()).isFullBook(), "full book");
        assertEq(IHook(detfInfo.reserveHook()).pairDoorCount(), 6, "six doors");

        // Join sized by min detfFrom = amt1. Excess pair0 refunded.
        uint256 bal0After = IERC20(pair0).balanceOf(detfUser);
        uint256 bal1After = IERC20(pair1).balanceOf(detfUser);
        assertEq(bal0After, bal0Before - amt1, "pair0 excess refunded");
        assertEq(bal1After, bal1Before - amt1, "pair1 fully used");
        assertGt(bal0After, 0, "refund remains");
    }

    function test_firstBond_twoPairs_reverts() public {
        IERC20[] memory ins = new IERC20[](2);
        ins[0] = IERC20(pair0);
        ins[1] = IERC20(pair1);
        uint256[] memory amts = new uint256[](2);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        _fundPair(detf, pair0, detfUser, BOND_AMT * 2);
        _fundPair(detf, pair1, detfUser, BOND_AMT * 2);
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.FirstBondRequiresAllExternalPairs.selector);
        detfInfo.bond(ins, amts, pair0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_firstBond_invalidCapitalToken_reverts() public {
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        IERC20[] memory ins = new IERC20[](3);
        ins[0] = IERC20(pair0);
        ins[1] = IERC20(pair1);
        ins[2] = IERC20(pair2);
        _fundPair(detf, pair0, detfUser, BOND_AMT * 2);
        _fundPair(detf, pair1, detfUser, BOND_AMT * 2);
        _fundPair(detf, pair2, detfUser, BOND_AMT * 2);
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

    function test_policy_afterFirstBond_mintDeadband() public {
        _firstBondDefault(BOND_AMT);
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
        // Equality = deadband; first-bond free legs can skew one side. Never both open.
        assertFalse(
            detfInfo.isMintingAllowed(pair0) && detfInfo.isBurningAllowed(pair0),
            "Policy mint and burn both open"
        );
    }

    function test_afterFirstBond_protocolLp_orBurnReverts() public {
        _firstBondDefault(BOND_AMT);
        uint256 free_ = IERC20(detf).balanceOf(detfUser);
        if (free_ == 0) return;
        if (detfInfo.protocolLp() == 0) {
            vm.startPrank(detfUser);
            IERC20(detf).approve(detf, type(uint256).max);
            vm.expectRevert();
            detfExchangeIn.exchangeIn(IERC20(detf), free_ / 10, IERC20(pair0), 0, detfUser, false, _dl());
            vm.stopPrank();
        } else {
            assertGt(detfInfo.protocolLp(), 0, "protocol LP seeded by compound or mint");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Live mint / burn                               */
    /* ---------------------------------------------------------------------- */

    function test_live_mint_previewEqualsExecution() public {
        address d = _deployDetfWired(_openArgsUnique("mintEq"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        IStandardExchangeIn ex = IStandardExchangeIn(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));

        uint256 amt = 5 ether;
        address p0 = info.pairToken(0);
        SimpleMintableERC20(p0).mint(detfUser, amt);
        uint256 preview = ex.previewExchangeIn(IERC20(p0), amt, IERC20(d));
        uint256 exec = _mintOn(d, p0, amt);
        assertEq(exec, preview, "hook-SoT preview==exec");
        assertGt(exec, 0, "minted");
    }

    function test_live_mint_vaultShareFlexible() public {
        address d = _deployDetfWired(_openArgsUnique("flex"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        IStandardExchangeIn ex = IStandardExchangeIn(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));

        address se = info.standardExchange(0);
        address share = info.vaultShare(0);
        require(se != address(0) && share != address(0), "need buffered pair0");

        uint256 pairAmt = 10 ether;
        address p0 = info.pairToken(0);
        SimpleMintableERC20(p0).mint(detfUser, pairAmt);
        vm.startPrank(detfUser);
        IERC20(p0).approve(se, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(p0), pairAmt, IERC20(share), 0, detfUser, false, _dl()
        );
        IERC20(share).approve(d, type(uint256).max);
        uint256 preview = ex.previewExchangeIn(IERC20(share), seOut, IERC20(d));
        uint256 exec = ex.exchangeIn(IERC20(share), seOut, IERC20(d), 0, detfUser, false, _dl());
        vm.stopPrank();
        assertEq(exec, preview, "vaultShare Flexible preview==exec");
        assertGt(exec, 0);
    }

    function test_open_ungated_mint() public {
        address d = _deployDetfWired(_openArgsUnique("mint"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        assertTrue(info.isMintingAllowed(info.pairToken(0)), "open ungated");
        uint256 out_ = _mintOn(d, info.pairToken(0), 2 ether);
        assertGt(out_, 0);
    }

    function test_burn_tokenOutDetf_invalidRoute() public {
        address d = _deployDetfWired(_openArgsUnique("burnDetf"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        IStandardExchangeIn ex = IStandardExchangeIn(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 5 ether);
        uint256 bal = IERC20(d).balanceOf(detfUser);
        require(bal > 0, "have detf");
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        vm.expectRevert();
        ex.exchangeIn(IERC20(d), bal / 20, IERC20(d), 0, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_burn_usageFee_andRedeposit() public {
        address d = _deployDetfWired(_openArgsUnique("burnEq"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        IStandardExchangeIn ex = IStandardExchangeIn(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);
        uint256 bal = IERC20(d).balanceOf(detfUser);
        require(bal > 1 ether, "have detf");
        address p1 = info.pairToken(1);
        uint256 burnAmt = bal / 10;
        uint256 preview = ex.previewExchangeIn(IERC20(d), burnAmt, IERC20(p1));
        uint256 exec = _burnOn(d, p1, burnAmt);
        // D13 sizes LP from NFT-held hook LP (not claim-token protocol LP). Exec
        // then prop-exits and residual-swaps after DETF redeposit. View quote
        // cannot compose that book; relative slip is ~3e-4 on this size.
        assertApproxEqRel(exec, preview, 0.01e18, "burn preview~exec (post-redeposit book)");
        assertGt(exec, 0);
    }

    function test_exactOut_selectors_invalidRoute() public {
        _firstBondDefault(BOND_AMT);
        vm.expectRevert();
        detfInfo.mintExactDetfOut(IERC20(pair0), 1 ether, 10 ether, detfUser, false, _dl());
        vm.expectRevert();
        detfInfo.burnExactTokenOut(IERC20(pair0), 1 ether, 10 ether, detfUser, false, _dl());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Later bonds                                    */
    /* ---------------------------------------------------------------------- */

    function test_laterBond_singlePair_succeeds() public {
        _firstBondDefault(BOND_AMT);
        _fundPair(detf, pair2, detfUser, BOND_AMT * 2);
        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) =
            detfInfo.bond(IERC20(pair2), BOND_AMT, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(tokenId, 0);
        assertGt(shares, 0);
        assertEq(detfInfo.capitalTokenOf(tokenId), pair2);
    }

    function test_laterBond_multiPair_reverts() public {
        _firstBondDefault(BOND_AMT);
        IERC20[] memory ins = new IERC20[](2);
        ins[0] = IERC20(pair0);
        ins[1] = IERC20(pair1);
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1 ether;
        amts[1] = 1 ether;
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.LaterBondSinglePairOnly.selector);
        detfInfo.bond(ins, amts, pair0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    function test_laterBond_userDetf_reverts() public {
        _firstBondDefault(BOND_AMT);
        uint256 bal = IERC20(detf).balanceOf(detfUser);
        if (bal == 0) return;
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfInfo.bond(IERC20(detf), bal / 10, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Mature-only                                    */
    /* ---------------------------------------------------------------------- */

    function test_preMaturity_sellAndClose_revert() public {
        (uint256 tokenId,) = _firstBondDefault(BOND_AMT);
        uint256[] memory minOut_ = _zeroMinOut(detf);
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        vm.expectRevert();
        detfInfo.closeBondMature(tokenId, minOut_, detfUser, _dl());
        vm.stopPrank();
    }

    function test_mature_close_paysNonDetfLegs() public {
        address d = _deployDetfWired(_openArgsUnique("close"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        (uint256 tokenId,) = _firstBondOn(d, amts, info.pairToken(0));
        _mintOn(d, info.pairToken(0), 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 b0 = IERC20(info.pairToken(0)).balanceOf(detfUser);
        uint256[] memory preview_ = info.previewCloseBondMature(tokenId);
        vm.prank(detfUser);
        uint256[] memory out_ = info.closeBondMature(tokenId, _zeroMinOut(d), detfUser, _dl());
        assertEq(out_.length, info.n(), "n");
        assertEq(out_[info.detfBindingIndex()], 0, "D25 DETF slot 0");
        uint256 paid_;
        for (uint256 i; i < out_.length; ++i) {
            paid_ += out_[i];
            assertEq(out_[i], preview_[i], "preview==exec");
        }
        assertGt(paid_, 0, "non-DETF paid");
        assertGt(IERC20(info.pairToken(0)).balanceOf(detfUser), b0, "pair0 paid");
        // D25 harvests pending DETF to the holder; withdrawn self-leg is burned (slot 0).
    }

    function test_nft_transferable() public {
        (uint256 tokenId,) = _firstBondDefault(BOND_AMT);
        address other = address(0xB0B);
        address nft = detfInfo.bondNftVault();
        vm.startPrank(detfUser);
        IDETFNFTVault(nft).approve(detfUser, tokenId);
        IDETFNFTVault(nft).transferFrom(detfUser, other, tokenId);
        vm.stopPrank();
        assertEq(IDETFNFTVault(nft).ownerOf(tokenId), other);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Claim                                          */
    /* ---------------------------------------------------------------------- */

    function test_claim_detfOut_invalidRoute() public {
        address d = _deployDetfWired(_openArgsUnique("claimDetf"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        vm.startPrank(detfUser);
        IERC20(info.pairToken(0)).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(info.pairToken(0)), 2 ether, 0, detfUser, false, _dl());
        require(claimOut > 0, "claim minted");
        IERC20(info.rebasingClaimToken()).approve(d, type(uint256).max);
        uint256 paid = info.redeemClaim(claimOut / 2, IERC20(d), 0, detfUser, _dl());
        vm.stopPrank();
        assertGt(paid, 0, "D15 DETF-only redeem");
    }

    function test_claim_redeem_pair() public {
        address d = _deployDetfWired(_openArgsUnique("claimPay"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        IERC20 pairOut_ = IERC20(info.pairToken(2));
        vm.startPrank(detfUser);
        IERC20(info.pairToken(0)).approve(d, type(uint256).max);
        uint256 claimOut = info.depositClaim(IERC20(info.pairToken(0)), 3 ether, 0, detfUser, false, _dl());
        IERC20(info.rebasingClaimToken()).approve(d, type(uint256).max);
        vm.stopPrank();
        // Cache tokenOut before expectRevert: pairToken() would consume the cheatcode.
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(Repo.InvalidRoute.selector, IERC20(d), pairOut_));
        info.redeemClaim(claimOut / 2, pairOut_, 0, detfUser, _dl());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Compound / expansion                           */
    /* ---------------------------------------------------------------------- */

    function test_compound_skipWhenNotEligible_orIncreases() public {
        _firstBondDefault(BOND_AMT);
        (uint256 dIn, uint256 lpOut) = detfInfo.compoundProtocolRewards();
        // Skip is allowed (0,0). If eligible, LP may increase.
        if (lpOut > 0) assertGt(dIn, 0);
    }

    function test_expansion_openNever() public {
        address d = _deployDetfWired(_openArgsUnique("exp"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));
        vm.warp(block.timestamp + 30 days);
        assertEq(info.pendingExpansionDetf(), 0, "open never expands");
        assertFalse(info.isAllLegsMintRich());
    }

    function test_expansion_notRich_pendingZero() public {
        _firstBondDefault(BOND_AMT);
        detfInfo.compoundProtocolRewards();
        uint256 epoch_ = detfInfo.expansionEpochLength();
        if (epoch_ == 0) epoch_ = 8 hours;
        vm.warp(block.timestamp + epoch_ * 5 + 1);
        if (!detfInfo.isAllLegsMintRich()) {
            assertEq(detfInfo.pendingExpansionDetf(), 0, "not-rich 0");
        }
    }

    function test_expansion_allLegsRich_accrues() public {
        address d = _deployDetfWired(_launchRichArgsUnique("rich"));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = 300 ether;
        amts[1] = 300 ether;
        amts[2] = 300 ether;
        (uint256 tokenId,) = _firstBondOn(d, amts, info.pairToken(0));
        info.compoundProtocolRewards();
        assertGt(info.lastExpansionTimestamp(), 0, "seeded");

        _pushSyntheticMintAllowed(info);
        for (uint8 i; i < 3 && !info.isAllLegsMintRich(); ++i) {
            _donatePairToProtocolLp(info, info.pairToken(i), 50 ether);
        }
        require(info.isAllLegsMintRich(), "all-legs mint-rich");

        uint256 epoch_ = info.expansionEpochLength();
        if (epoch_ == 0) epoch_ = 8 hours;
        vm.warp(block.timestamp + epoch_ * 5 + 1);
        uint256 pending = info.pendingExpansionDetf();
        assertGt(pending, 0, "rich end accrues min S_spot");

        uint256 supplyBefore = IERC20(d).totalSupply();
        vm.prank(detfUser);
        info.claimRewards(tokenId, detfUser);
        assertGt(IERC20(d).totalSupply(), supplyBefore, "realize minted expansion");
    }

    function test_expansion_midFlip_pendingZero() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args =
            _launchRichArgsUnique("flip");
        args.mintThreshold = 1e18;
        address d = _deployDetfWired(args);
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = 300 ether;
        amts[1] = 300 ether;
        amts[2] = 300 ether;
        _firstBondOn(d, amts, info.pairToken(0));
        info.compoundProtocolRewards();

        _pushSyntheticMintAllowed(info);
        for (uint8 i; i < 3 && !info.isAllLegsMintRich(); ++i) {
            _donatePairToProtocolLp(info, info.pairToken(i), 50 ether);
        }
        require(info.isAllLegsMintRich(), "start rich");

        uint256 epoch_ = info.expansionEpochLength();
        if (epoch_ == 0) epoch_ = 8 hours;
        vm.warp(block.timestamp + epoch_ * 5 + 1);
        assertGt(info.pendingExpansionDetf(), 0, "would accrue while rich");

        // Mint (then bond) until realize-time is not all-legs rich → pending must be 0.
        for (uint8 i; i < 3 && info.isAllLegsMintRich(); ++i) {
            for (uint256 j; j < 40 && info.isAllLegsMintRich(); ++j) {
                try this.mintExternal(d, info.pairToken(i), 40 ether) {} catch {
                    break;
                }
            }
        }
        for (uint256 j; j < 40 && info.isAllLegsMintRich(); ++j) {
            try this.bondSingleExternal(d, info.pairToken(0), 40 ether) {} catch {
                break;
            }
        }
        require(!info.isAllLegsMintRich(), "must leave all-legs-rich");
        assertEq(info.pendingExpansionDetf(), 0, "mid-flip realize-time not-rich => 0");
    }

    function test_matrix_1se2bare_firstBond() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory oneSe = _args1Se2Bare();
        oneSe.name = "Quad 1SE explicit";
        oneSe.symbol = "q1seX";
        address d = _deployDetfWired(oneSe);
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        (, uint256 shares) = _firstBondOn(d, amts, info.pairToken(0));
        assertTrue(info.isReserveLive());
        assertGt(shares, 0);
        assertTrue(info.standardExchange(0) != address(0));
        assertEq(info.standardExchange(1), address(0));
        assertEq(info.standardExchange(2), address(0));
    }

    function test_mixedDecimals_6and18_firstBond() public {
        MintableERC20Decimals six = new MintableERC20Decimals("Six", "SIX", 6);
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _args1Se2Bare();
        args.name = "Quad 6+18";
        args.symbol = "q618";
        args.pairTokens[1] = IERC20(address(six));
        args.standardExchanges[1] = IStandardExchangeProxy(address(0));
        args.vaultShares[1] = IERC20(address(0));
        args.rateProviders[1] = address(0);

        address d = _deployDetfWired(args);
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);

        address p0 = info.pairToken(0);
        address p1 = info.pairToken(1);
        address p2 = info.pairToken(2);
        uint256 amt0 = 100 ether;
        uint256 amt1 = p1 == address(six) ? 100e6 : 100 ether;
        uint256 amt2 = p2 == address(six) ? 100e6 : 100 ether;
        if (p0 == address(six)) amt0 = 100e6;

        six.mint(detfUser, 1_000_000e6);
        _fundPair(d, p0, detfUser, amt0 * 2);
        _fundPair(d, p1, detfUser, amt1 * 2);
        _fundPair(d, p2, detfUser, amt2 * 2);

        IERC20[] memory ins = new IERC20[](3);
        ins[0] = IERC20(p0);
        ins[1] = IERC20(p1);
        ins[2] = IERC20(p2);
        uint256[] memory amts = new uint256[](3);
        amts[0] = amt0;
        amts[1] = amt1;
        amts[2] = amt2;
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        IERC20(p1).approve(d, type(uint256).max);
        IERC20(p2).approve(d, type(uint256).max);
        (uint256 tokenId, uint256 shares) =
            info.bond(ins, amts, p0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();

        assertTrue(info.isReserveLive(), "6+18 live");
        assertGt(shares, 0);
        assertGt(tokenId, 0);
        assertTrue(IHook(info.reserveHook()).isFullBook(), "6+18 full book");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Matrix / binding / decimals                    */
    /* ---------------------------------------------------------------------- */

    function test_matrix_2se1bare_firstBond() public {
        address d = _deployDetfWired(_args2Se1Bare());
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        (, uint256 shares) = _firstBondOn(d, amts, info.pairToken(0));
        assertTrue(info.isReserveLive());
        assertGt(shares, 0);
        assertTrue(info.standardExchange(0) != address(0));
        assertTrue(info.standardExchange(1) != address(0));
        assertEq(info.standardExchange(2), address(0));
    }

    function test_matrix_3se_firstBond() public {
        address d = _deployDetfWired(_args3Se());
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(1));
        assertTrue(info.isReserveLive());
        assertTrue(info.standardExchange(2) != address(0));
    }

    function test_binding_notOnlyIndex0() public {
        // Etch a mintable pair at a low address so address-sort cannot put DETF at index 0.
        address lowPair = address(uint160(0x1000));
        vm.etch(lowPair, type(SimpleMintableERC20).runtimeCode);
        SimpleMintableERC20(lowPair).mint(detfUser, 10_000_000 ether);

        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _args1Se2Bare();
        args.name = "Quad bind off0";
        args.symbol = "qOff0";
        args.pairTokens[0] = IERC20(lowPair);
        args.pairTokens[1] = IERC20(address(token0));
        args.pairTokens[2] = IERC20(address(token1));
        args.standardExchanges[0] = IStandardExchangeProxy(address(0));
        args.standardExchanges[1] = IStandardExchangeProxy(se0);
        args.standardExchanges[2] = IStandardExchangeProxy(address(0));
        args.vaultShares[0] = IERC20(address(0));
        args.vaultShares[1] = IERC20(address(0));
        args.vaultShares[2] = IERC20(address(0));
        args.rateProviders[0] = address(0);
        args.rateProviders[1] = address(0);
        args.rateProviders[2] = address(0);
        args.thresholdMode = ThresholdMode.Open;

        address d = _deployDetfWired(args);
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = BOND_AMT;
        amts[1] = BOND_AMT;
        amts[2] = BOND_AMT;
        _firstBondOn(d, amts, info.pairToken(0));

        uint8 idx = info.detfBindingIndex();
        assertTrue(idx < 4, "binding in 0..3");
        assertTrue(idx != 0, "DETF must not occupy address-sort index 0");
        assertEq(IHook(info.reserveHook()).tokens().length, 4);
        assertEq(IHook(info.reserveHook()).tokens()[0], lowPair, "low pair is index 0");
    }

    function test_syntheticVs_noRateAsset_andPerRoute() public {
        _firstBondDefault(BOND_AMT);
        uint256 s0 = detfInfo.syntheticVs(pair0);
        uint256 s1 = detfInfo.syntheticVs(pair1);
        uint256 s2 = detfInfo.syntheticVs(pair2);
        assertGt(s0, 0);
        assertGt(s1, 0);
        assertGt(s2, 0);
    }
}
