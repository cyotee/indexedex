// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4DetfHookStagedInitLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookStagedInitLib.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

address constant STAGED_INIT_STRANGER = address(0xB0B);

function _countLivePairs(address hook, address[] memory tokens) view returns (uint256 live) {
    for (uint256 i; i < tokens.length; ++i) {
        for (uint256 j = i + 1; j < tokens.length; ++j) {
            if (IUniswapV4HookStagedPairInit(hook).isPairPoolLive(tokens[i], tokens[j])) {
                ++live;
            }
        }
    }
}

function _assertHookUnmatched(address hook) {
    (bool okDec,) = hook.call(abi.encodeWithSignature("decimals()"));
    require(!okDec, "decimals matched");
    (bool okDep,) = hook.call(abi.encodeWithSignature("depositSingle(address,uint256,address,uint256,uint256)"));
    require(!okDep, "depositSingle matched");
    (bool okT0,) = hook.call(abi.encodeWithSignature("token0()"));
    require(!okT0, "token0 matched");
}

/// @notice Units A–E for CP Single Uni V4 SE DETF staged hook init.
contract UniswapV4SeDetfStagedHookInit_Cp is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfBootstrapOnly(_defaultDetfArgs());
        _bindDetfPointers();
    }

    function test_deployOnly_bootstrapHook() public {
        assertTrue(detfInfo.reserveHook() != address(0));
        assertFalse(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertEq(detfInfo.bondNftVault(), address(0));
        assertEq(detfInfo.rebasingClaimToken(), address(0));
        assertFalse(detfInfo.isReserveLive());
        assertFalse(IUniswapV4HookStagedPairInit(detfInfo.reserveHook()).isInitializationFinalized());
        _assertHookUnmatched(detfInfo.reserveHook());
    }

    function test_bondNftBeforeFinalizeReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETF.ReserveHookNotFinalized.selector);
        IUniswapV4SingleStandardExchangeDETF(detf).completeReserveBondNft();
    }

    function test_claimBeforeBondNftReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETF.ReserveBondNftNotWired.selector);
        IUniswapV4SingleStandardExchangeDETF(detf).completeReserveClaim();
    }

    function test_finalizeWithoutWiring() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensCp(
            IUniswapV4SingleStandardExchangeDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        assertTrue(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertTrue(IERC20Metadata(hook).decimals() > 0);
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETF.ReserveNotWired.selector);
        _firstBond(100 ether);
    }

    function test_twoStepWiringAndFirstBond() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensCp(
            IUniswapV4SingleStandardExchangeDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4SingleStandardExchangeDETF(detf).completeReserveBondNft();
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertFalse(detfInfo.isReserveWired());
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETF.ReserveNotWired.selector);
        _firstBond(100 ether);

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4SingleStandardExchangeDETF(detf).completeReserveClaim();
        _assertWired();

        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETF.ReserveBondNftAlreadyWired.selector);
        IUniswapV4SingleStandardExchangeDETF(detf).completeReserveBondNft();
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4SingleStandardExchangeDETF.ReserveClaimAlreadyWired.selector);
        IUniswapV4SingleStandardExchangeDETF(detf).completeReserveClaim();

        _firstBond(100 ether);
        _assertLive();
    }

    function test_productPairCount() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensCp(
            IUniswapV4SingleStandardExchangeDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        assertEq(_countLivePairs(hook, tokens), 1);
    }
}

/// @notice Units A–E for Orbital Uni V4 SE DETF staged hook init.
contract UniswapV4SeDetfStagedHookInit_Orbital is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfBootstrapOnly(_defaultDetfArgs());
        _bindDetfPointers();
    }

    function test_deployOnly_bootstrapHook() public {
        assertTrue(detfInfo.reserveHook() != address(0));
        assertFalse(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertEq(detfInfo.bondNftVault(), address(0));
        assertEq(detfInfo.rebasingClaimToken(), address(0));
        assertFalse(detfInfo.isReserveLive());
        assertFalse(IUniswapV4HookStagedPairInit(detfInfo.reserveHook()).isInitializationFinalized());
        _assertHookUnmatched(detfInfo.reserveHook());
    }

    function test_bondNftBeforeFinalizeReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETF.ReserveHookNotFinalized.selector);
        IUniswapV4StandardExchangeOrbitalDETF(detf).completeReserveBondNft();
    }

    function test_claimBeforeBondNftReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETF.ReserveBondNftNotWired.selector);
        IUniswapV4StandardExchangeOrbitalDETF(detf).completeReserveClaim();
    }

    function test_finalizeWithoutWiring() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensOrbital(
            IUniswapV4StandardExchangeOrbitalDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        assertTrue(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertTrue(IERC20Metadata(hook).decimals() > 0);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETF.ReserveNotWired.selector);
        _firstBondBothPairs(100 ether, 100 ether);
    }

    function test_twoStepWiringAndFirstBond() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensOrbital(
            IUniswapV4StandardExchangeOrbitalDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4StandardExchangeOrbitalDETF(detf).completeReserveBondNft();
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertFalse(detfInfo.isReserveWired());
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETF.ReserveNotWired.selector);
        _firstBondBothPairs(100 ether, 100 ether);

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4StandardExchangeOrbitalDETF(detf).completeReserveClaim();
        _assertWired();

        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETF.ReserveBondNftAlreadyWired.selector);
        IUniswapV4StandardExchangeOrbitalDETF(detf).completeReserveBondNft();
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETF.ReserveClaimAlreadyWired.selector);
        IUniswapV4StandardExchangeOrbitalDETF(detf).completeReserveClaim();

        _firstBondBothPairs(100 ether, 100 ether);
        _assertLive();
    }

    function test_productPairCount() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensOrbital(
            IUniswapV4StandardExchangeOrbitalDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        assertEq(_countLivePairs(hook, tokens), 3);
    }
}

/// @notice Units A–E for Weighted Uni V4 SE DETF staged hook init.
contract UniswapV4SeDetfStagedHookInit_Weighted is TestBase_UniswapV4StandardExchangeWeightedDETF {
    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfBootstrapOnly(_defaultDetfArgs());
        _bindDetfPointers();
    }

    function test_deployOnly_bootstrapHook() public {
        assertTrue(detfInfo.reserveHook() != address(0));
        assertFalse(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertEq(detfInfo.bondNftVault(), address(0));
        assertEq(detfInfo.rebasingClaimToken(), address(0));
        assertFalse(detfInfo.isReserveLive());
        assertFalse(IUniswapV4HookStagedPairInit(detfInfo.reserveHook()).isInitializationFinalized());
        _assertHookUnmatched(detfInfo.reserveHook());
    }

    function test_bondNftBeforeFinalizeReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETF.ReserveHookNotFinalized.selector);
        IUniswapV4StandardExchangeWeightedDETF(detf).completeReserveBondNft();
    }

    function test_claimBeforeBondNftReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETF.ReserveBondNftNotWired.selector);
        IUniswapV4StandardExchangeWeightedDETF(detf).completeReserveClaim();
    }

    function test_finalizeWithoutWiring() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensWeighted(
            IUniswapV4StandardExchangeWeightedDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        assertTrue(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertTrue(IERC20Metadata(hook).decimals() > 0);
        _expectWeightedFirstBondReserveNotWired();
    }

    function test_twoStepWiringAndFirstBond() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensWeighted(
            IUniswapV4StandardExchangeWeightedDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4StandardExchangeWeightedDETF(detf).completeReserveBondNft();
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertFalse(detfInfo.isReserveWired());
        _expectWeightedFirstBondReserveNotWired();

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4StandardExchangeWeightedDETF(detf).completeReserveClaim();
        _assertWired();

        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETF.ReserveBondNftAlreadyWired.selector);
        IUniswapV4StandardExchangeWeightedDETF(detf).completeReserveBondNft();
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETF.ReserveClaimAlreadyWired.selector);
        IUniswapV4StandardExchangeWeightedDETF(detf).completeReserveClaim();

        _firstBondDefault(100 ether);
        _assertLive();
    }

    function test_productPairCount() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensWeighted(
            IUniswapV4StandardExchangeWeightedDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        uint256 n_ = tokens.length;
        assertEq(_countLivePairs(hook, tokens), n_ * (n_ - 1) / 2);
    }

    function _expectWeightedFirstBondReserveNotWired() internal {
        address p0 = detfInfo.pairToken(0);
        _fundPair(detf, p0, detfUser, 200 ether);
        IERC20[] memory ins = new IERC20[](1);
        ins[0] = IERC20(p0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 100 ether;
        vm.prank(detfUser);
        vm.expectRevert(IUniswapV4StandardExchangeWeightedDETF.ReserveNotWired.selector);
        detfInfo.bond(ins, amts, p0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
    }
}

/// @notice Units A–E for Curve Quad Uni V4 SE DETF staged hook init.
contract UniswapV4SeDetfStagedHookInit_Quad is TestBase_UniswapV4StandardExchangeCurveQuadStableDETF {
    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfBootstrapOnly(_defaultDetfArgs());
        _bindDetfPointers();
    }

    function test_deployOnly_bootstrapHook() public {
        assertTrue(detfInfo.reserveHook() != address(0));
        assertFalse(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertEq(detfInfo.bondNftVault(), address(0));
        assertEq(detfInfo.rebasingClaimToken(), address(0));
        assertFalse(detfInfo.isReserveLive());
        assertFalse(IUniswapV4HookStagedPairInit(detfInfo.reserveHook()).isInitializationFinalized());
        _assertHookUnmatched(detfInfo.reserveHook());
    }

    function test_bondNftBeforeFinalizeReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveHookNotFinalized.selector);
        IUniswapV4StandardExchangeCurveQuadStableDETF(detf).completeReserveBondNft();
    }

    function test_claimBeforeBondNftReverts() public {
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveBondNftNotWired.selector);
        IUniswapV4StandardExchangeCurveQuadStableDETF(detf).completeReserveClaim();
    }

    function test_finalizeWithoutWiring() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensQuad(
            IUniswapV4StandardExchangeCurveQuadStableDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        assertTrue(detfInfo.isReserveHookFinalized());
        assertFalse(detfInfo.isReserveWired());
        assertTrue(IERC20Metadata(hook).decimals() > 0);
        _expectQuadFirstBondReserveNotWired();
    }

    function test_twoStepWiringAndFirstBond() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensQuad(
            IUniswapV4StandardExchangeCurveQuadStableDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4StandardExchangeCurveQuadStableDETF(detf).completeReserveBondNft();
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertFalse(detfInfo.isReserveWired());
        _expectQuadFirstBondReserveNotWired();

        vm.prank(STAGED_INIT_STRANGER);
        IUniswapV4StandardExchangeCurveQuadStableDETF(detf).completeReserveClaim();
        _assertWired();

        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveBondNftAlreadyWired.selector);
        IUniswapV4StandardExchangeCurveQuadStableDETF(detf).completeReserveBondNft();
        vm.prank(STAGED_INIT_STRANGER);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveClaimAlreadyWired.selector);
        IUniswapV4StandardExchangeCurveQuadStableDETF(detf).completeReserveClaim();

        _firstBondDefault(100 ether);
        _assertLive();
    }

    function test_productPairCount() public {
        address hook = detfInfo.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensQuad(
            IUniswapV4StandardExchangeCurveQuadStableDETF(detf)
        );
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        assertEq(_countLivePairs(hook, tokens), 6);
    }

    function _expectQuadFirstBondReserveNotWired() internal {
        IERC20[] memory ins = new IERC20[](3);
        uint256[] memory amts = new uint256[](3);
        for (uint8 i; i < 3; ++i) {
            address p = detfInfo.pairToken(i);
            ins[i] = IERC20(p);
            amts[i] = 100 ether;
            _fundPair(detf, p, detfUser, 200 ether);
        }
        vm.prank(detfUser);
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveNotWired.selector);
        detfInfo.bond(ins, amts, pair0, DEFAULT_MIN_LOCK, detfUser, false, _dl());
    }
}
