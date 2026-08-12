// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/**
 * @title CamelotV2StandardExchangeIn_Swap_Test
 * @notice WP-H-CAM-001: Route 1 (pass-through swap) hermetic H matrix for Camelot SE.
 * @dev Parity with Aerodrome/UniV2 Route1 execVsPreview + balance changes. Production DFPkg only.
 */
contract CamelotV2StandardExchangeIn_Swap_Test is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;

    uint256 internal constant INITIAL_BALANCE = 10_000 ether;
    uint256 internal constant SEED_AMOUNT = 1000 ether;
    uint256 internal constant TEST_AMOUNT = 1 ether;

    function setUp() public override {
        super.setUp();

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), INITIAL_BALANCE);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), INITIAL_BALANCE);

        tokenA.approve(address(camelotV2StandardExchangeDFPkg), SEED_AMOUNT);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), SEED_AMOUNT);

        address vaultAddr = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), SEED_AMOUNT, IERC20(address(tokenB)), SEED_AMOUNT, address(this)
        );

        vault = IStandardExchangeProxy(vaultAddr);
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Preview vs pool math                          */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_previewVsMath_AtoB() public view {
        _test_previewVsMath(true);
    }

    function test_Route1Swap_previewVsMath_BtoA() public view {
        _test_previewVsMath(false);
    }

    function _test_previewVsMath(bool aToB) internal view {
        IERC20 tokenIn = aToB ? IERC20(address(tokenA)) : IERC20(address(tokenB));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        uint256 expectedFromPool = pair.getAmountOut(TEST_AMOUNT, address(tokenIn));
        uint256 preview = vault.previewExchangeIn(tokenIn, TEST_AMOUNT, tokenOut);

        assertEq(preview, expectedFromPool, "Preview should match pair.getAmountOut()");
        assertTrue(preview > 0, "Preview non-zero");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs preview (H)                         */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_execVsPreview_AtoB() public {
        _test_execVsPreview(true);
    }

    function test_Route1Swap_execVsPreview_BtoA() public {
        _test_execVsPreview(false);
    }

    function _test_execVsPreview(bool aToB) internal {
        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        address recipient = makeAddr("swapRecipient");
        tokenInStub.mint(address(this), TEST_AMOUNT);
        tokenInStub.approve(address(vault), TEST_AMOUNT);

        uint256 preview = vault.previewExchangeIn(tokenIn, TEST_AMOUNT, tokenOut);
        uint256 amountOut =
            vault.exchangeIn(tokenIn, TEST_AMOUNT, tokenOut, 0, recipient, false, _deadline());

        assertEq(amountOut, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Balance changes                             */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_balanceChanges_AtoB() public {
        _test_balanceChanges(true);
    }

    function test_Route1Swap_balanceChanges_BtoA() public {
        _test_balanceChanges(false);
    }

    function _test_balanceChanges(bool aToB) internal {
        ERC20PermitMintableStub tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));

        address recipient = makeAddr("balRecipient");
        tokenInStub.mint(address(this), TEST_AMOUNT);
        tokenInStub.approve(address(vault), TEST_AMOUNT);

        uint256 senderBefore = tokenIn.balanceOf(address(this));
        uint256 recipientBefore = tokenOut.balanceOf(recipient);

        uint256 amountOut =
            vault.exchangeIn(tokenIn, TEST_AMOUNT, tokenOut, 0, recipient, false, _deadline());

        assertEq(tokenIn.balanceOf(address(this)), senderBefore - TEST_AMOUNT, "Sender tokenIn decreased");
        assertEq(tokenOut.balanceOf(recipient), recipientBefore + amountOut, "Recipient tokenOut increased");
        assertTrue(amountOut > 0, "Non-zero out");
    }

    /* ---------------------------------------------------------------------- */
    /*                         H3 / minOut residual                           */
    /* ---------------------------------------------------------------------- */

    /// @notice H3-class: failed Route1 minOut leaves no free vault share inventory.
    function test_Route1Swap_H3_minOutTooHigh_noFreeShares() public {
        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 tokenOut = IERC20(address(tokenB));

        tokenA.mint(address(this), TEST_AMOUNT);
        tokenA.approve(address(vault), TEST_AMOUNT);

        uint256 preview = vault.previewExchangeIn(tokenIn, TEST_AMOUNT, tokenOut);
        uint256 minTooHigh = preview + 1;
        uint256 sharesBefore = IERC20(address(vault)).balanceOf(address(vault));
        uint256 balBefore = tokenA.balanceOf(address(this));

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, minTooHigh, preview)
        );
        vault.exchangeIn(tokenIn, TEST_AMOUNT, tokenOut, minTooHigh, makeAddr("recipient"), false, _deadline());

        assertEq(IERC20(address(vault)).balanceOf(address(vault)), sharesBefore, "H3 residual vault shares");
        assertEq(tokenA.balanceOf(address(this)), balBefore, "input not consumed on failed swap");
    }
}
