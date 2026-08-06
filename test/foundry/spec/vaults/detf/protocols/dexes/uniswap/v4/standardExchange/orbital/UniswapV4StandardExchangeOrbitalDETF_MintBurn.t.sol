// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @dev Preview parity + empty protocol LP + FD + invalid route (split from Policy/NotZap for via-IR size).
contract UniswapV4StandardExchangeOrbitalDETF_MintBurnTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    address internal openDetf;
    IUniswapV4StandardExchangeOrbitalDETF internal openInfo;

    function setUp() public override {
        super.setUp();
        openDetf = _deployDetfInstance(_openArgs());
        openInfo = IUniswapV4StandardExchangeOrbitalDETF(openDetf);
        _firstBondOn(openDetf, 500 ether, 500 ether);
        _firstBondBothPairs(500 ether, 500 ether);
        _assertLive();
    }

    function test_mint_previewEqualsExecution_open() public {
        address p0 = openInfo.pairToken0();
        uint256 amountIn = 10 ether;
        uint256 preview = IStandardExchangeIn(openDetf).previewExchangeIn(IERC20(p0), amountIn, IERC20(openDetf));
        uint256 userDetf = _mintOn(openDetf, p0, amountIn);
        assertEq(userDetf, preview, "mint preview == execution");
        assertGt(userDetf, 0);
    }

    function test_burn_previewEqualsExecution_fewWei() public {
        address p1 = openInfo.pairToken1();
        uint256 userDetf = _mintOn(openDetf, p1, 50 ether);
        uint256 burnAmt = userDetf / 2;
        uint256 preview =
            IStandardExchangeIn(openDetf).previewExchangeIn(IERC20(openDetf), burnAmt, IERC20(p1));
        uint256 lastExpBefore = openInfo.lastExpansionTimestamp();
        uint256 out_ = _burnOn(openDetf, p1, burnAmt);
        assertApproxEqAbs(out_, preview, 100, "burn preview == execution (few-wei)");
        assertEq(openInfo.lastExpansionTimestamp(), lastExpBefore, "burn must not realize expansion");
        assertGt(out_, 0);
    }

    function test_burn_emptyProtocolLp_afterFirstBondOnly() public {
        address d2 = _deployDetfInstance(_openArgsUnique("emptyProto"));
        IUniswapV4StandardExchangeOrbitalDETF info2 = IUniswapV4StandardExchangeOrbitalDETF(d2);
        _firstBondOn(d2, 100 ether, 100 ether);
        // First bond LP is on bond NFT only — protocol holder must be empty.
        assertEq(info2.protocolLp(), 0, "protocol LP empty after first bond only");
        uint256 freeDetf = IERC20(d2).balanceOf(detfUser);
        assertGt(freeDetf, 0, "user has free DETF from first bond");
        // Cache outs before expectRevert (arg evaluation would consume expectRevert).
        address p0 = info2.pairToken0();
        uint256 burnAmt = freeDetf / 2 == 0 ? freeDetf : freeDetf / 2;
        uint256 dl = _dl();
        vm.startPrank(detfUser);
        IERC20(d2).approve(d2, type(uint256).max);
        vm.expectRevert(Repo.EmptyProtocolLp.selector);
        IStandardExchangeIn(d2).exchangeIn(IERC20(d2), burnAmt, IERC20(p0), 0, detfUser, false, dl);
        vm.stopPrank();
    }

    function test_fd_includes_detf_leg_gt_pairs_only() public {
        _mintOn(openDetf, openInfo.pairToken0(), 20 ether);
        uint256 fullFd = openInfo.fdRateAssetWad();
        uint256 pairsOnly = openInfo.fdPairsOnlyRateAssetWad();
        assertGt(fullFd, 0, "full FD");
        assertGt(fullFd, pairsOnly, "FD full residual includes DETF->rateAsset beyond pairs-only");
    }

    function test_invalid_tokenOut_reverts() public {
        uint256 userDetf = _mintOn(openDetf, openInfo.pairToken0(), 5 ether);
        vm.startPrank(detfUser);
        IERC20(openDetf).approve(openDetf, type(uint256).max);
        vm.expectRevert();
        IStandardExchangeIn(openDetf).exchangeIn(
            IERC20(openDetf), userDetf / 4, IERC20(address(0xDEAD)), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
    }
}
