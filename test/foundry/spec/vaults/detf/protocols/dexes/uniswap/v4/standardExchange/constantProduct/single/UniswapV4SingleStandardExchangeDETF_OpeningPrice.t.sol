// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4DetfHookPremineLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol";

/// @notice PRD T1–T5, T7: peg vs first-bond opening on Uni V4 CP Single SE DETF.
/// @dev N10: if first bond at opening 1.1e18 leaves mint closed, raise opening (do not rewrite mint threshold).
///      Recorded mint-open WAD is written in comments after the hermetic run.
contract UniswapV4SingleStandardExchangeDETF_OpeningPrice is TestBase_UniswapV4SingleStandardExchangeDETF {
    uint256 internal constant OPENING_LAUNCH_START = 1.1e18;
    uint256 internal constant FIRST_BOND_PAIR = 100 ether;

    /// @dev N10 candidates. Start at 1.1e18; raise until Policy 1.05 mint-opens after a real `bond`.
    ///      Recorded mint-open WAD: 2.2e18 (1.1e18 left mint closed on CP).
    uint256 internal constant N10_CANDIDATES_LEN = 8;

    function _n10Candidate(uint256 i) internal pure returns (uint256) {
        if (i == 0) return 1.1e18;
        if (i == 1) return 1.2e18;
        if (i == 2) return 1.5e18;
        if (i == 3) return 2e18;
        if (i == 4) return 2.2e18;
        if (i == 5) return 3e18;
        if (i == 6) return 4e18;
        return 5e18;
    }

    function _expectedJoinDetf(uint256 pairAmount_, uint256 opening_) internal pure returns (uint256) {
        return pairAmount_ * 1e18 / opening_;
    }

    function _bindFresh(address d) internal {
        detf = d;
        detfInfo = IUniswapV4SingleStandardExchangeDETF(d);
        detfExchangeIn = IStandardExchangeIn(d);
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        vm.stopPrank();
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
    }

    function _deployWiredOpening(string memory tag, uint256 opening_) internal returns (address) {
        address d = _deployDetfWired(_argsWithOpening(tag, opening_));
        _bindFresh(d);
        return d;
    }

    function _hookRawReserve(address d) internal view returns (uint256) {
        return IHook(IUniswapV4SingleStandardExchangeDETF(d).reserveHook()).rawReserve();
    }

    /// @notice T1: opening = 0 stores as creation; first-bond G matches today's C=1e18 path.
    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        assertEq(detfInfo.openingPairPerDetfWad(), detfInfo.creationPairPerDetfWad(), "stored opening == creation");
        assertEq(detfInfo.openingPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF);
        _assertInert();
        _firstBond(FIRST_BOND_PAIR);
        _assertLive();
        uint256 g_ = _expectedJoinDetf(FIRST_BOND_PAIR, DEFAULT_CREATION_PAIR_PER_DETF);
        assertEq(_hookRawReserve(detf), g_, "empty-book G at peg uses resolved opening = creation");
    }

    /// @notice T2: creation 1e18 + opening 1.1e18 → G uses opening; creation view unchanged.
    function test_T2_openingUsesG_creationViewUnchanged() public {
        address d = _deployWiredOpening("t2", OPENING_LAUNCH_START);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        assertEq(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF, "creation view");
        assertEq(info.openingPairPerDetfWad(), OPENING_LAUNCH_START, "stored opening");
        _firstBond(FIRST_BOND_PAIR);
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = _expectedJoinDetf(FIRST_BOND_PAIR, OPENING_LAUNCH_START);
        uint256 gCreation_ = _expectedJoinDetf(FIRST_BOND_PAIR, DEFAULT_CREATION_PAIR_PER_DETF);
        uint256 raw_ = _hookRawReserve(d);
        assertEq(raw_, gOpening_, "first-bond G uses opening");
        assertTrue(raw_ != gCreation_, "G is not the creation-rate join");
        assertEq(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF, "creation unchanged after bond");
    }

    /// @notice T3+N10: after first bond, Policy mint-open. Raise opening if 1.1e18 is still closed.
    /// @dev Recorded mint-open WAD: 2.2e18.
    function test_T3_n10_isMintingAllowedAfterFirstBond() public {
        uint256 used_;
        address d;
        for (uint256 i; i < N10_CANDIDATES_LEN; ++i) {
            used_ = _n10Candidate(i);
            d = _deployWiredOpening(string(abi.encodePacked("t3", vm.toString(i))), used_);
            IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
            assertEq(info.mintThreshold(), 1.05e18, "default Policy mint threshold");
            _firstBond(FIRST_BOND_PAIR);
            assertTrue(info.isReserveLive(), "first bond live");
            if (info.isMintingAllowed()) {
                assertEq(info.openingPairPerDetfWad(), used_);
                // N10 recorded mint-open WAD (update FixtureEconomics if this is not 1.1e18).
                emit log_named_uint("N10 mint-open openingPairPerDetfWad", used_);
                return;
            }
        }
        fail("N10: no candidate opening mint-opened after first bond; raise OPENING further");
    }

    /// @notice T4: opening = 0 still first-bonds; synthetic near current at-peg behavior.
    function test_T4_openingZero_firstBond_syntheticNearAtPeg() public {
        uint256 synBefore = detfInfo.syntheticPrice();
        assertEq(synBefore, 1e18, "inert synthetic is 1");
        _firstBond(FIRST_BOND_PAIR);
        uint256 synAfter = detfInfo.syntheticPrice();
        // Extra seigniorage DETF pulls synthetic below 1 at peg, same as today's at-peg first bond.
        assertLt(synAfter, 1e18, "at-peg first bond dilutes below 1");
        assertGt(synAfter, 0.4e18, "not a collapsed book");
        assertFalse(detfInfo.isMintingAllowed(), "at-peg first bond does not mint-open");
    }

    /// @notice T5: creation = 0 still reverts InvalidCreationRate.
    function test_T5_creationZero_revertsInvalidCreationRate() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.creationPairPerDetfWad = 0;
        args.openingPairPerDetfWad = 1.1e18;
        args.name = "ZeroCreation Opening";
        args.symbol = "zCOP";
        (, uint256 nonce_) = UniswapV4DetfHookPremineLib.premineCp(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args, nonce_);
        vm.stopPrank();
    }

    /// @notice T7: live mint quotes after first bond follow the live curve, not linear opening.
    function test_T7_liveMintQuotesDoNotUseOpening() public {
        address d = _deployWiredOpening("t7", OPENING_LAUNCH_START);
        _firstBond(FIRST_BOND_PAIR);
        IStandardExchangeIn xin = IStandardExchangeIn(d);
        uint256 q10 = xin.previewExchangeIn(IERC20(address(pairToken)), 10 ether, IERC20(d));
        uint256 q20 = xin.previewExchangeIn(IERC20(address(pairToken)), 20 ether, IERC20(d));
        assertGt(q10, 0, "live mint preview");
        // Linear empty-book G = pair * 1e18 / opening would scale exactly 2x (ignore 1 wei).
        // Live const-prod exact-in is strictly concave.
        assertLt(q20, q10 * 2, "live mint quote is not the opening linear join");
        uint256 linearOpening_ = 10 ether * 1e18 / OPENING_LAUNCH_START;
        assertTrue(q10 != linearOpening_, "preview is not empty-book opening G");
    }

    /// @notice N13: calcSalt hashes full PkgArgs including opening.
    function test_calcSalt_includesOpening() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory a = _defaultDetfArgs();
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory b = _defaultDetfArgs();
        a.openingPairPerDetfWad = 0;
        b.openingPairPerDetfWad = 1.1e18;
        bytes32 saltA = IDiamondFactoryPackage(address(detfPkg)).calcSalt(abi.encode(a, uint256(0)));
        bytes32 saltB = IDiamondFactoryPackage(address(detfPkg)).calcSalt(abi.encode(b, uint256(0)));
        assertTrue(saltA != saltB, "opening in calcSalt");
    }
}
