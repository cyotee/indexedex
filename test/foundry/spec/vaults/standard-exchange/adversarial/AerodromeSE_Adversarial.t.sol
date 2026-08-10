// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/// @notice Wave 2B SE adversarial P0 on production Aerodrome Standard Exchange vault.
/// @dev Catalog: A1 donation, E5 zero/deadline, H3 residual, F1 cut. C-class: see ReentrancyGuard suite.
contract AerodromeSE_Adversarial_Test is TestBase_AerodromeStandardExchange_MultiPool {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("seAttacker");
    }

    function _vault() internal view returns (IStandardExchangeProxy) {
        return _getVault(PoolConfig.Balanced);
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT;
        deal(address(tokenA), attacker, amount_);
        uint256 sharesBefore_ = IERC20(address(vault_)).balanceOf(attacker);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), amount_);
        assertEq(IERC20(address(vault_)).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
    }

    function test_E5_zeroAmount_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
    }

    /// @notice E5: expired deadline reverts with `DeadlineExceeded` (WP-E5-AERO-001).
    function test_E5_expiredDeadline_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
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
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
    }

    function test_H3_minOutTooHigh_noFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 2;
        deal(address(tokenA), attacker, amount_);
        uint256 preview_ = vault_.previewExchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(tokenB)));
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)),
            amount_,
            IERC20(address(tokenB)),
            preview_ + type(uint128).max,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
    }

    function test_F1_diamondCut_blocked() public {
        IStandardExchangeProxy vault_ = _vault();
        (bool ok,) = address(vault_).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_E1_swapRoundTrip_bounded() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 4;
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 outB_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        assertTrue(outB_ > 0, "got tokenB");
        tokenB.approve(address(vault_), outB_);
        uint256 backA_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenB)), outB_, IERC20(address(tokenA)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        // Round-trip loses fees/slippage - out <= in
        assertLe(backA_, amount_, "E1: no free lunch on SE swap round-trip");
    }
}
