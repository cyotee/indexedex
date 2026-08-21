// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF,
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";

/// @notice PRD T1–T2: peg vs first-bond opening on Uni V4 Orbital SE DETF.
contract UniswapV4StandardExchangeOrbitalDETF_OpeningPrice is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    uint256 internal constant OPENING_LAUNCH_START = 1.1e18;
    uint256 internal constant FIRST_BOND_PAIR = 100 ether;

    function _detfLeg(address d) internal view returns (uint256) {
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        return IHook(info.reserveHook()).rawReserve(info.detfBindingIndex());
    }

    /// @notice T1: opening = 0 stores as creation; first-bond G matches C=1e18.
    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        assertEq(detfInfo.openingPair0PerDetfWad(), detfInfo.creationPair0PerDetfWad());
        assertEq(detfInfo.openingPair1PerDetfWad(), detfInfo.creationPair1PerDetfWad());
        assertEq(detfInfo.openingPair0PerDetfWad(), DEFAULT_CREATION);
        assertEq(detfInfo.openingPair1PerDetfWad(), DEFAULT_CREATION);
        _firstBondBothPairs(FIRST_BOND_PAIR, FIRST_BOND_PAIR);
        assertTrue(detfInfo.isReserveLive());
        assertEq(_detfLeg(detf), FIRST_BOND_PAIR, "empty-book G at peg");
    }

    /// @notice T2: creation 1e18 + opening 1.1e18 → G uses opening; creation views unchanged.
    function test_T2_openingUsesG_creationViewUnchanged() public {
        address d = _deployDetfWired(_argsWithOpening("t2", OPENING_LAUNCH_START));
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        _setBondTermsFor(d);
        assertEq(info.creationPair0PerDetfWad(), DEFAULT_CREATION);
        assertEq(info.creationPair1PerDetfWad(), DEFAULT_CREATION);
        assertEq(info.openingPair0PerDetfWad(), OPENING_LAUNCH_START);
        assertEq(info.openingPair1PerDetfWad(), OPENING_LAUNCH_START);
        _firstBondOn(d, FIRST_BOND_PAIR, FIRST_BOND_PAIR);
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = FIRST_BOND_PAIR * 1e18 / OPENING_LAUNCH_START;
        assertEq(_detfLeg(d), gOpening_, "first-bond G uses opening");
        assertEq(info.creationPair0PerDetfWad(), DEFAULT_CREATION);
        assertEq(info.creationPair1PerDetfWad(), DEFAULT_CREATION);
    }

    /// @notice T5: creation = 0 still reverts InvalidCreationRate.
    function test_T5_creationZero_revertsInvalidCreationRate() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "ZeroCreation Orb";
        args.symbol = "zCO";
        args.creationPair0PerDetfWad = 0;
        uint256 nonce = _premineNonce(args);
        vm.prank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args, nonce);
    }
}
