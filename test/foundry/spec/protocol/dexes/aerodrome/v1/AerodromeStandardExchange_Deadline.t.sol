// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/**
 * @title AerodromeStandardExchange_Deadline_Test
 * @notice WP-E5-AERO-001: vault-level deadline / E5 catalog for Aerodrome SE.
 * @dev Peer SE (Uni V2 / Camelot) revert `DeadlineExceeded` at exchangeIn/Out entry.
 *      Vault-only routes never hit the Aerodrome router, so entry checks are required.
 *      Production: AerodromeStandardExchangeInTarget / OutTarget.
 */
contract AerodromeStandardExchange_Deadline_Test is TestBase_AerodromeStandardExchange_MultiPool {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("aeroDeadlineAttacker");
    }

    function _vault() internal view returns (IStandardExchangeProxy) {
        return _getVault(PoolConfig.Balanced);
    }

    function _tokens() internal view returns (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) {
        return _getTokens(PoolConfig.Balanced);
    }

    /* ---------------------------------------------------------------------- */
    /*                              E5 / deadline                             */
    /* ---------------------------------------------------------------------- */

    /// @notice E5: expired deadline reverts on exchangeIn (swap route) with exact selector.
    function test_E5_expiredDeadline_exchangeIn_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _tokens();
        uint256 amount_ = TEST_AMOUNT / 2;
        uint256 expired_ = _expiredDeadline();

        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, expired_
        );
        vm.stopPrank();

        // H3-class: failed path leaves no free vault share inventory
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
        assertEq(tokenA.balanceOf(attacker), amount_, "input not consumed on expired deadline");
    }

    /// @notice E5: expired deadline reverts on exchangeOut with exact selector.
    function test_E5_expiredDeadline_exchangeOut_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _tokens();
        uint256 amountOut_ = 1 ether;
        uint256 expired_ = _expiredDeadline();
        uint256 maxIn_ = TEST_AMOUNT;

        deal(address(tokenA), attacker, maxIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), maxIn_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        IStandardExchangeOut(address(vault_)).exchangeOut(
            IERC20(address(tokenA)), maxIn_, IERC20(address(tokenB)), amountOut_, attacker, false, expired_
        );
        vm.stopPrank();

        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
        assertEq(tokenA.balanceOf(attacker), maxIn_, "input not consumed on expired deadline");
    }

    /// @notice E5: vault-only deposit route must also honor deadline (no router call).
    function test_E5_expiredDeadline_vaultDeposit_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        address pool_ = address(_getPool(PoolConfig.Balanced));
        uint256 lpAmount_ = TEST_AMOUNT / 4;
        uint256 expired_ = _expiredDeadline();

        // Fund attacker with LP via mint path on the stub pool is not available —
        // transfer LP from this test contract's seed position when present; else deal.
        deal(pool_, attacker, lpAmount_);
        vm.startPrank(attacker);
        IERC20(pool_).approve(address(vault_), lpAmount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(pool_), lpAmount_, IERC20(address(vault_)), 0, attacker, false, expired_
        );
        vm.stopPrank();

        assertEq(IERC20(address(vault_)).balanceOf(attacker), 0, "no free shares on expired vault deposit");
        assertEq(IERC20(pool_).balanceOf(attacker), lpAmount_, "LP not consumed on expired deadline");
    }

    /// @notice Zero amount is rejected (E5 catalog companion to deadline).
    function test_E5_zeroAmount_exchangeIn_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _tokens();
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
    }

    /// @notice Boundary: deadline == block.timestamp is accepted (not expired).
    function test_deadline_exactTimestamp_exchangeIn_succeeds() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _tokens();
        uint256 amount_ = TEST_AMOUNT / 4;

        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 out_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(out_, 0, "exact-timestamp deadline should succeed");
    }

    /// @notice Warped past a captured deadline reverts with that deadline value.
    function test_deadline_warpPast_exchangeIn_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _tokens();
        uint256 amount_ = TEST_AMOUNT / 4;
        uint256 deadline_ = block.timestamp + 100;

        deal(address(tokenA), attacker, amount_);
        vm.warp(deadline_ + 1);

        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, deadline_, block.timestamp)
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, deadline_
        );
        vm.stopPrank();
    }
}
