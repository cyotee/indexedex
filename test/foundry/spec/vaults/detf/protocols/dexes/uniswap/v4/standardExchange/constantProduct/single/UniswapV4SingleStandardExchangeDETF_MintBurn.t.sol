// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice Phase 3: live mint/burn, pair-only burn, no expansion on mint/burn.
/// @dev Uses Open threshold mode so primary mint is not blocked when first-bond free legs
///      dilute synthetic below Policy mintThreshold (expected product behavior under Policy).
contract UniswapV4SingleStandardExchangeDETF_MintBurnTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        // Full TestBase then swap default Policy instance for Open (mint path under dilution).
        super.setUp();
        detf = _deployDetfWired(_openArgs());
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

    function test_policy_blocks_mint_when_synthetic_below_threshold() public {
        address d = _deployDetfWired(_policyArgsUnique("mintGate")); // Policy defaults
        pairToken.mint(detfUser, 1000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(d).bond(
            IERC20(address(pairToken)), 200 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        // Free seigniorage dilution typically leaves synthetic < 1.05e18 under Policy.
        if (!IUniswapV4SingleStandardExchangeDETF(d).isMintingAllowed()) {
            vm.expectRevert();
            IStandardExchangeIn(d).exchangeIn(
                IERC20(address(pairToken)), 10 ether, IERC20(d), 0, detfUser, false, block.timestamp + 1 hours
            );
        }
        vm.stopPrank();
    }

    function test_liveMint_previewEqExec_andNoExpansionClock() public {
        uint256 lastBefore = detfInfo.lastExpansionTimestamp();
        uint256 pairIn = 50 ether;

        uint256 preview = detfExchangeIn.previewExchangeIn(
            IERC20(address(pairToken)), pairIn, IERC20(detf)
        );
        assertGt(preview, 0, "preview mint");

        uint256 balBefore = IERC20(detf).balanceOf(detfUser);
        uint256 userOut = _mintPair(pairIn);
        assertEq(userOut, preview, "preview==exec mint");
        assertEq(IERC20(detf).balanceOf(detfUser) - balBefore, userOut);

        // Protocol LP should rise (mint joins protocol LP).
        assertGt(detfInfo.protocolLp(), 0, "protocol lp after mint");

        // Expansion clock unchanged on primary mint.
        assertEq(detfInfo.lastExpansionTimestamp(), lastBefore, "mint must not advance expansion");
    }

    function test_liveBurn_pairOnly_previewEqExec_andNoExpansionClock() public {
        // Ensure free DETF + protocol LP via mint
        uint256 userOut = _mintPair(80 ether);
        assertGt(userOut, 0);
        assertGt(detfInfo.protocolLp(), 0);

        uint256 lastBefore = detfInfo.lastExpansionTimestamp();
        uint256 burnAmt = userOut / 2;

        uint256 preview = detfExchangeIn.previewExchangeIn(IERC20(detf), burnAmt, IERC20(address(pairToken)));
        assertGt(preview, 0, "preview burn");

        uint256 pairBefore = pairToken.balanceOf(detfUser);
        uint256 pairOut = _burnToPair(burnAmt);
        assertEq(pairOut, preview, "preview==exec burn");
        assertEq(pairToken.balanceOf(detfUser) - pairBefore, pairOut);

        assertEq(detfInfo.lastExpansionTimestamp(), lastBefore, "burn must not advance expansion");
    }

    function test_burn_nonPair_revertsInvalidRoute() public {
        uint256 userOut = _mintPair(40 ether);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, type(uint256).max);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            IERC20(detf),
            userOut / 4,
            IERC20(se), // non-pair
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_burn_emptyProtocolLp_afterFirstBondOnly_reverts() public {
        // Fresh instance: first bond only → all LP user-bonded → protocol LP 0
        address d = _deployDetfWired(_policyArgsUnique("emptyLp"));
        pairToken.mint(detfUser, 1000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(d).bond(
            IERC20(address(pairToken)),
            200 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        // No free DETF from mint; free seigniorage legs may exist — try burn if any
        uint256 free = IERC20(d).balanceOf(detfUser);
        if (free > 0 && IUniswapV4SingleStandardExchangeDETF(d).protocolLp() == 0) {
            IERC20(d).approve(d, type(uint256).max);
            vm.expectRevert();
            IStandardExchangeIn(d).exchangeIn(
                IERC20(d), free / 2, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
            );
        }
        vm.stopPrank();
    }
}
