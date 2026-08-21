// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF,
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

/// @notice PRD T1–T2, T6: peg vs first-bond opening on Uni V4 Weighted SE DETF.
contract UniswapV4StandardExchangeWeightedDETF_OpeningPrice is TestBase_UniswapV4StandardExchangeWeightedDETF {
    uint256 internal constant OPENING_LAUNCH_START = 1.1e18;
    uint256 internal constant FIRST_BOND_PAIR = 100 ether;

    function _detfLeg(address d) internal view returns (uint256) {
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        uint256[] memory nat_ = IHook(info.reserveHook()).nativeReserves();
        return nat_[info.detfBindingIndex()];
    }

    function _amts1(uint256 v) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = v;
    }

    /// @notice T1: opening = 0 stores as creation; first-bond G matches C=1e18.
    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        uint256[] memory stored_ = detfInfo.openingPairPerDetfWads();
        uint256[] memory creation_ = detfInfo.creationPairPerDetfWads();
        assertEq(stored_.length, creation_.length);
        for (uint256 i; i < stored_.length; ++i) {
            assertEq(stored_[i], creation_[i], "stored opening == creation");
            assertEq(stored_[i], DEFAULT_CREATION);
        }
        _firstBondDefault(FIRST_BOND_PAIR);
        assertTrue(detfInfo.isReserveLive());
        assertEq(_detfLeg(detf), FIRST_BOND_PAIR, "empty-book G at peg");
    }

    /// @notice T2: creation 1e18 + opening 1.1e18 → G uses opening; creation view unchanged.
    function test_T2_openingUsesG_creationViewUnchanged() public {
        address d = _deployDetfWired(_argsWithOpening("t2", OPENING_LAUNCH_START));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        _setBondTermsFor(d);
        assertEq(info.creationPairPerDetfWad(0), DEFAULT_CREATION);
        assertEq(info.openingPairPerDetfWad(0), OPENING_LAUNCH_START);
        _firstBondOn(d, _amts1(FIRST_BOND_PAIR), info.pairToken(0));
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = FIRST_BOND_PAIR * 1e18 / OPENING_LAUNCH_START;
        assertEq(_detfLeg(d), gOpening_, "first-bond G uses opening");
        assertEq(info.creationPairPerDetfWad(0), DEFAULT_CREATION, "creation unchanged");
    }

    /// @notice T5: creation = 0 still reverts InvalidCreationRate.
    function test_T5_creationZero_revertsInvalidCreationRate() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "ZeroCreation Wgt";
        args.symbol = "zCW";
        args.creationPairPerDetfWad[0] = 0;
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args, nonce);
    }

    /// @notice T6: opening array length mismatch reverts ArrayLengthMismatch.
    function test_T6_openingLengthMismatch_reverts() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "BadOpenLen Wgt";
        args.symbol = "bOLW";
        args.openingPairPerDetfWad = new uint256[](2);
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETDFPkg.ArrayLengthMismatch.selector);
        detfPkg.deployVault(args, nonce);
    }
}
