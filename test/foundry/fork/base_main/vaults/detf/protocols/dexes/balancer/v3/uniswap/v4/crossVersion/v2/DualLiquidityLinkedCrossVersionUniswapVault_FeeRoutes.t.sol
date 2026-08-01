// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Usage fee applies on every share-minting route (common, linked, leg share, BPT).
contract DualLiquidityLinkedCrossVersionUniswapVault_FeeRoutes is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    uint256 internal constant FEE_WAD = 5e16; // 5%
    address internal depositor = makeAddr("feeRouteDep");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
        _setUsageFee(FEE_WAD);
    }

    function test_feeRoute_commonTokenDeposit() public {
        _assertMintRouteFeesFeeTo(commonToken, LEG_SEED);
    }

    function test_feeRoute_tokenADeposit() public {
        _assertMintRouteFeesFeeTo(tokenA, LEG_SEED);
    }

    function test_feeRoute_tokenBDeposit() public {
        _assertMintRouteFeesFeeTo(tokenB, LEG_SEED);
    }

    function test_feeRoute_legShareDeposit() public {
        (IERC20 leg0,,) = _legShares();
        uint256 shares = _acquireLegShare(address(leg0), depositor);
        address feeTo = _feeTo();
        uint256 feeBefore = shareToken.balanceOf(feeTo);

        vm.startPrank(depositor);
        leg0.approve(linkedVault, shares);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            leg0, shares, shareToken, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();

        uint256 feeDelta = shareToken.balanceOf(feeTo) - feeBefore;
        assertGt(minted, 0);
        assertGt(feeDelta, 0, "leg-share deposit takes usage fee");
        uint256 gross = minted + feeDelta;
        assertEq(feeDelta, Math.mulDiv(gross, FEE_WAD, 1e18));
    }

    function test_feeRoute_bptDeposit() public {
        // Acquire BPT via deposit+redeem, then re-deposit BPT (transferFrom path).
        uint256 m = _depositCommon(depositor, LEG_SEED);
        address pool = _reservePool();
        vm.startPrank(depositor);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, m, IERC20(pool), 0, depositor, false, block.timestamp
        );
        address feeTo = _feeTo();
        uint256 feeBefore = shareToken.balanceOf(feeTo);
        IERC20(pool).approve(linkedVault, bpt);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(pool), bpt, shareToken, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();

        uint256 feeDelta = shareToken.balanceOf(feeTo) - feeBefore;
        assertGt(minted, 0);
        assertGt(feeDelta, 0, "BPT deposit takes usage fee");
        uint256 gross = minted + feeDelta;
        assertEq(feeDelta, Math.mulDiv(gross, FEE_WAD, 1e18));
    }

    function _assertMintRouteFeesFeeTo(IERC20 tokenIn, uint256 amount) internal {
        address feeTo = _feeTo();
        uint256 feeBefore = shareToken.balanceOf(feeTo);
        _fund(tokenIn, depositor, amount);
        vm.startPrank(depositor);
        tokenIn.approve(linkedVault, amount);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenIn, amount, shareToken, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();
        uint256 feeDelta = shareToken.balanceOf(feeTo) - feeBefore;
        assertGt(minted, 0);
        assertGt(feeDelta, 0);
        uint256 gross = minted + feeDelta;
        assertEq(feeDelta, Math.mulDiv(gross, FEE_WAD, 1e18), "fee split");
    }
}
