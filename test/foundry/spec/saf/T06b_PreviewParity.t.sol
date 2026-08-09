// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
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

/// @notice T06b CP-single: mint/burn preview ≡ execute.
contract T06b_CpPreviewParity_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        detf = _deployDetfInstance(_openArgs());
        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        vm.stopPrank();
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        _firstBond(500 ether);
    }

    function test_mint_previewEqExecute() public {
        uint256 pairIn = 40 ether;
        uint256 preview =
            detfExchangeIn.previewExchangeIn(IERC20(address(pairToken)), pairIn, IERC20(detf));
        uint256 out = _mintPair(pairIn);
        assertEq(out, preview, "mint preview==exec");
    }

    function test_burn_previewEqExecute() public {
        uint256 userOut = _mintPair(80 ether);
        uint256 burnAmt = userOut / 2;
        uint256 preview =
            detfExchangeIn.previewExchangeIn(IERC20(detf), burnAmt, IERC20(address(pairToken)));
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt);
        uint256 pairOut = detfExchangeIn.exchangeIn(
            IERC20(detf), burnAmt, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(pairOut, preview, "burn preview==exec");
    }
}

/// @notice Orbital L-PREV-1: SE passthrough preview must match execute (not soft-return 0).
contract T06b_OrbitalSePassthrough_Test is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    address internal openDetf;
    IUniswapV4StandardExchangeOrbitalDETF internal openInfo;

    function setUp() public override {
        super.setUp();
        openDetf = _deployDetfInstance(_openArgs());
        openInfo = IUniswapV4StandardExchangeOrbitalDETF(openDetf);
        _firstBondOn(openDetf, 500 ether, 500 ether);
        assertTrue(openInfo.isReserveLive(), "openDetf expected live");
    }

    function test_sePassthrough_previewEqExecute_pairToVaultShare() public {
        address se0 = openInfo.standardExchange0();
        assertTrue(se0 != address(0), "SE0 configured");
        address p0 = openInfo.pairToken0();
        address share0 = openInfo.vaultShare0();
        if (share0 == address(0)) share0 = se0;

        SimpleMintableERC20(p0).mint(detfUser, 100 ether);
        uint256 amountIn = 5 ether;

        uint256 preview =
            IStandardExchangeIn(openDetf).previewExchangeIn(IERC20(p0), amountIn, IERC20(share0));
        // Fails if A-A-detf-univ4-004 still open (preview soft-returns 0).
        assertGt(preview, 0, "SE passthrough preview must be non-zero when route supported");

        uint256 shareBefore = IERC20(share0).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(p0).approve(openDetf, amountIn);
        uint256 out = IStandardExchangeIn(openDetf).exchangeIn(
            IERC20(p0), amountIn, IERC20(share0), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(out, preview, "orbital SE passthrough preview==exec");
        assertEq(IERC20(share0).balanceOf(detfUser) - shareBefore, out);
        assertGt(out, 0, "execute produced SE share out");
    }

    function test_mint_previewEqExecute() public {
        address p0 = openInfo.pairToken0();
        uint256 amountIn = 10 ether;
        uint256 preview =
            IStandardExchangeIn(openDetf).previewExchangeIn(IERC20(p0), amountIn, IERC20(openDetf));
        uint256 userDetf = _mintOn(openDetf, p0, amountIn);
        assertEq(userDetf, preview, "orbital mint preview==exec");
        assertGt(userDetf, 0);
    }
}

/// @notice Weighted L-PREV-1: SE passthrough preview must match execute.
contract T06b_WeightedSePassthrough_Test is TestBase_UniswapV4StandardExchangeWeightedDETF {
    address internal openDetf;
    IUniswapV4StandardExchangeWeightedDETF internal openInfo;

    function setUp() public override {
        super.setUp();
        openDetf = _deployDetfInstance(_openArgs());
        openInfo = IUniswapV4StandardExchangeWeightedDETF(openDetf);
        _setBondTermsFor(openDetf);
        address p0 = openInfo.pairToken(0);
        _firstBondOn(openDetf, _amounts(50 ether), p0);
        assertTrue(openInfo.isReserveLive(), "expected live");
    }

    function _amounts(uint256 a0) internal pure returns (uint256[] memory amts) {
        amts = new uint256[](1);
        amts[0] = a0;
    }

    function test_sePassthrough_previewEqExecute_pairToVaultShare() public {
        address se0 = openInfo.standardExchange(0);
        assertTrue(se0 != address(0), "SE0 configured");
        address p0 = openInfo.pairToken(0);
        address share0 = openInfo.vaultShare(0);
        if (share0 == address(0)) share0 = se0;

        SimpleMintableERC20(p0).mint(detfUser, 100 ether);
        uint256 amountIn = 5 ether;

        uint256 preview =
            IStandardExchangeIn(openDetf).previewExchangeIn(IERC20(p0), amountIn, IERC20(share0));
        assertGt(preview, 0, "weighted SE passthrough preview must be non-zero");

        uint256 shareBefore = IERC20(share0).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(p0).approve(openDetf, amountIn);
        uint256 out = IStandardExchangeIn(openDetf).exchangeIn(
            IERC20(p0), amountIn, IERC20(share0), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(out, preview, "weighted SE passthrough preview==exec");
        assertEq(IERC20(share0).balanceOf(detfUser) - shareBefore, out);
        assertGt(out, 0);
    }

    function test_mint_previewEqExecute() public {
        address p0 = openInfo.pairToken(0);
        uint256 amountIn = 10 ether;
        SimpleMintableERC20(p0).mint(detfUser, amountIn * 2);
        uint256 preview =
            IStandardExchangeIn(openDetf).previewExchangeIn(IERC20(p0), amountIn, IERC20(openDetf));
        uint256 userDetf = _mintOn(openDetf, p0, amountIn);
        assertEq(userDetf, preview, "weighted mint preview==exec");
        assertGt(userDetf, 0);
    }
}
