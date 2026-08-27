// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

/// @notice Harness holding AddressSets so Stage 00 tests drive the production lib.
contract UniswapV4SeBufferHookLegLibHarness {
    using UniswapV4SeBufferHookLegLib for UniswapV4SeBufferHookLegLib.Layout;
    using AddressSetRepo for AddressSet;

    UniswapV4SeBufferHookLegLib.Layout internal layoutStruct;

    function setDetfToken(address detfToken_) external {
        layoutStruct.detfToken = detfToken_;
    }

    function addPairSe(address pair, address se) external {
        layoutStruct.addPairSe(pair, se);
    }

    function classify(address addr) external view returns (UniswapV4SeBufferHookLegLib.LegKind) {
        return layoutStruct.classify(addr);
    }

    function pairContains(address addr) external view returns (bool) {
        return layoutStruct.pairTokens._contains(addr);
    }

    function seContains(address addr) external view returns (bool) {
        return layoutStruct.standardExchanges._contains(addr);
    }

    function standardExchangeOf(address pair) external view returns (address) {
        return layoutStruct.standardExchangeOf[pair];
    }

    function pairOfStandardExchange(address se) external view returns (address) {
        return layoutStruct.pairOfStandardExchange[se];
    }
}

/// @notice Pure unit tests for UniswapV4SeBufferHookLegLib (Stage 00). Not a hook SUT.
contract UniswapV4SeBufferHookLegLibTest is Test {
    UniswapV4SeBufferHookLegLibHarness internal harness;

    address internal detf = address(0xD07F);
    address internal pair0 = address(0xA11);
    address internal se0 = address(0x5E01);
    address internal pair1 = address(0xA12);
    address internal se1 = address(0x5E02);
    address internal unknown = address(0xDEAD);

    function setUp() public {
        harness = new UniswapV4SeBufferHookLegLibHarness();
        harness.setDetfToken(detf);
        harness.addPairSe(pair0, se0);
    }

    function test_classify_detf() public view {
        assertEq(
            uint256(harness.classify(detf)),
            uint256(UniswapV4SeBufferHookLegLib.LegKind.Detf)
        );
    }

    function test_classify_pair() public view {
        assertEq(
            uint256(harness.classify(pair0)),
            uint256(UniswapV4SeBufferHookLegLib.LegKind.Pair)
        );
    }

    function test_classify_standardExchange() public view {
        assertEq(
            uint256(harness.classify(se0)),
            uint256(UniswapV4SeBufferHookLegLib.LegKind.StandardExchange)
        );
    }

    function test_classify_unknown() public view {
        assertEq(
            uint256(harness.classify(unknown)),
            uint256(UniswapV4SeBufferHookLegLib.LegKind.Unknown)
        );
    }

    function test_addPairSe_overlapPairInSeSet_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4SeBufferHookLegLib.PairSeOverlap.selector, se0, pair1)
        );
        harness.addPairSe(se0, pair1);
    }

    function test_addPairSe_twoPairsOneSe_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4SeBufferHookLegLib.SeAlreadyBound.selector, se0, pair0)
        );
        harness.addPairSe(pair1, se0);
    }

    function test_addPairSe_detfAsPair_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4SeBufferHookLegLib.DetfTokenInSets.selector, detf)
        );
        harness.addPairSe(detf, se1);
    }

    function test_addPairSe_pairEqualsSe_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4SeBufferHookLegLib.PairSeOverlap.selector, pair1, pair1)
        );
        harness.addPairSe(pair1, pair1);
    }

    function test_addPairSe_secondLeg_ok() public {
        harness.addPairSe(pair1, se1);
        assertTrue(harness.pairContains(pair1));
        assertTrue(harness.seContains(se1));
        assertEq(harness.standardExchangeOf(pair1), se1);
        assertEq(harness.pairOfStandardExchange(se1), pair1);
        assertEq(
            uint256(harness.classify(pair1)),
            uint256(UniswapV4SeBufferHookLegLib.LegKind.Pair)
        );
        assertEq(
            uint256(harness.classify(se1)),
            uint256(UniswapV4SeBufferHookLegLib.LegKind.StandardExchange)
        );
    }

    function test_requiredAbi_joinUnbalancedTakesAddressArray() public pure {
        bytes4 sel_ = IUniswapV4SeBufferHook.joinUnbalanced.selector;
        assertEq(sel_, bytes4(keccak256("joinUnbalanced(address[],uint256[],address,uint256,uint256)")));
    }

    function test_requiredAbi_previewSwapExactInTakesTokenAddresses() public pure {
        bytes4 sel_ = IUniswapV4SeBufferHook.previewSwapExactIn.selector;
        assertEq(sel_, bytes4(keccak256("previewSwapExactIn(address,address,uint256)")));
    }

    function test_requiredAbi_quoteSelectorsExist() public pure {
        assertEq(
            IDetfReserveQuote.previewSynthetic.selector,
            bytes4(keccak256("previewSynthetic((uint256,uint256,uint256,uint256),address)"))
        );
        assertEq(
            IDetfReserveQuote.previewBurnToToken.selector,
            bytes4(keccak256("previewBurnToToken(uint256,address)"))
        );
    }
}
