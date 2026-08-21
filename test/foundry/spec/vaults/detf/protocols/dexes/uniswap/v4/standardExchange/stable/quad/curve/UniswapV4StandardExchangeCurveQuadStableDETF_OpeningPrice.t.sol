// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF,
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @notice PRD T1–T3, T6: peg vs first-bond opening on Uni V4 Curve Quad SE DETF.
contract UniswapV4StandardExchangeCurveQuadStableDETF_OpeningPrice is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
    uint256 internal constant OPENING_LAUNCH_START = 1.1e18;
    uint256 internal constant FIRST_BOND_PAIR = 100 ether;
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

    function _amts(uint256 v) internal pure returns (uint256[] memory a) {
        a = new uint256[](3);
        a[0] = v;
        a[1] = v;
        a[2] = v;
    }

    function _detfLeg(address d) internal view returns (uint256) {
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        uint256[] memory nat_ = IHook(info.reserveHook()).nativeReserves();
        return nat_[info.detfBindingIndex()];
    }

    /// @notice T1: opening = 0 stores as creation; first-bond G matches C=1e18.
    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        uint256[] memory stored_ = detfInfo.openingPairPerDetfWads();
        uint256[] memory creation_ = detfInfo.creationPairPerDetfWads();
        assertEq(stored_.length, 3);
        for (uint256 i; i < 3; ++i) {
            assertEq(stored_[i], creation_[i], "stored opening == creation");
            assertEq(stored_[i], DEFAULT_CREATION);
        }
        _firstBondDefault(FIRST_BOND_PAIR);
        assertTrue(detfInfo.isReserveLive());
        assertEq(_detfLeg(detf), FIRST_BOND_PAIR, "empty-book G at peg");
    }

    /// @notice T2: creation 1e18 + opening 1.1e18 → G uses opening; creation views unchanged.
    function test_T2_openingUsesG_creationViewUnchanged() public {
        address d = _deployDetfWired(_argsWithOpening("t2", OPENING_LAUNCH_START));
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        for (uint256 i; i < 3; ++i) {
            assertEq(info.creationPairPerDetfWad(i), DEFAULT_CREATION);
            assertEq(info.openingPairPerDetfWad(i), OPENING_LAUNCH_START);
        }
        _firstBondOn(d, _amts(FIRST_BOND_PAIR), info.pairToken(0));
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = FIRST_BOND_PAIR * 1e18 / OPENING_LAUNCH_START;
        assertEq(_detfLeg(d), gOpening_, "first-bond G uses opening");
        for (uint256 i; i < 3; ++i) {
            assertEq(info.creationPairPerDetfWad(i), DEFAULT_CREATION, "creation unchanged");
        }
    }

    /// @notice T3+N10: after first bond, Policy mint-open on every Quad leg.
    /// @dev Recorded mint-open WAD: 1.1e18 on Quad (CP needs 2.2e18; 46630 fixture uses 2.2e18).
    function test_T3_n10_isMintingAllowedAfterFirstBond() public {
        uint256 used_;
        for (uint256 i; i < N10_CANDIDATES_LEN; ++i) {
            used_ = _n10Candidate(i);
            address d = _deployDetfWired(
                _argsWithOpening(string(abi.encodePacked("t3", vm.toString(i))), used_)
            );
            IUniswapV4StandardExchangeCurveQuadStableDETF info =
                IUniswapV4StandardExchangeCurveQuadStableDETF(d);
            _setBondTermsFor(d);
            assertEq(info.mintThreshold(), 1.05e18, "default Policy mint threshold");
            _firstBondOn(d, _amts(FIRST_BOND_PAIR), info.pairToken(0));
            assertTrue(info.isReserveLive(), "first bond live");
            bool allOpen_ = true;
            for (uint8 p; p < 3; ++p) {
                if (!info.isMintingAllowed(info.pairToken(p))) {
                    allOpen_ = false;
                    break;
                }
            }
            if (allOpen_) {
                emit log_named_uint("N10 mint-open openingPairPerDetfWad", used_);
                return;
            }
        }
        fail("N10: no candidate opening mint-opened all Quad legs after first bond");
    }

    /// @notice T5: creation = 0 still reverts InvalidCreationRate.
    function test_T5_creationZero_revertsInvalidCreationRate() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "ZeroCreation Quad";
        args.symbol = "zCQ";
        args.creationPairPerDetfWad[1] = 0;
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args, nonce);
    }

    /// @notice T6: opening array length mismatch reverts ArrayLengthMismatch.
    function test_T6_openingLengthMismatch_reverts() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "BadOpenLen Quad";
        args.symbol = "bOLQ";
        args.openingPairPerDetfWad = new uint256[](2);
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.ArrayLengthMismatch.selector);
        detfPkg.deployVault(args, nonce);
    }
}
