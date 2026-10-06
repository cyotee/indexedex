// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC2612} from "@crane/contracts/interfaces/IERC2612.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultSecurityTest is Fixture {
    function test_permitNonceReplayAndVaultDomainSeparation() public {
        uint256 signingKey = 0x123456;
        address signer = vm.addr(signingKey);
        address spender = makeAddr("spender");
        IERC20Permit permit = IERC20Permit(address(wings0));
        bytes32 body = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            signer, spender, 777, permit.nonces(signer), block.timestamp + 10));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", permit.DOMAIN_SEPARATOR(), body));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, digest);
        permit.permit(signer, spender, 777, block.timestamp + 10, v, r, s);
        assertEq(IERC20(address(wings0)).allowance(signer, spender), 777);
        assertEq(permit.nonces(signer), 1);
        vm.expectPartialRevert(IERC2612.ERC2612InvalidSigner.selector);
        permit.permit(signer, spender, 777, block.timestamp + 10, v, r, s);
        vm.expectPartialRevert(IERC2612.ERC2612InvalidSigner.selector);
        IERC20Permit(address(wings1)).permit(signer, spender, 777, block.timestamp + 10, v, r, s);
    }
    function test_donationDuringSupplyDoesNotChangeBookOrRateAndCannotBePulledForFree() public {
        IStandardExchangeIn exchange = IStandardExchangeIn(address(wings0));
        exchange.exchangeIn(token0, 1e12, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        uint256 beforeValue = wings0.liquidationValue().value;
        (uint256 before0,uint256 before1) = wings0.localReserves();
        token0.transfer(address(wings0), 12345); token1.transfer(address(wings0), 67890);
        assertEq(wings0.liquidationValue().value, beforeValue);
        (uint256 after0,uint256 after1) = wings0.localReserves();
        assertEq(after0, before0); assertEq(after1, before1);
        address outsider = makeAddr("outsider");
        vm.prank(outsider); vm.expectRevert();
        exchange.exchangeIn(IERC20(address(wings0)), 1, token0, 0, outsider, false, block.timestamp);
        assertEq(IERC20(address(wings0)).totalSupply(), 1e12);
    }
    function test_lateWithdrawMinimumRestoresBalancesSharesAndPositions() public {
        IStandardExchangeIn exchange = IStandardExchangeIn(address(wings0));
        exchange.exchangeIn(token0, 1e12, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        uint256 beforeValue = wings0.liquidationValue().value;
        uint256 beforeTarget = token0.balanceOf(address(this));
        (,,uint128 wing,) = wings0.position(1);
        vm.expectPartialRevert(IStandardExchangeErrors.MinAmountNotMet.selector);
        exchange.exchangeIn(IERC20(address(wings0)), 1e12, token0, type(uint256).max, address(this), false, block.timestamp);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)), 1e12);
        assertEq(token0.balanceOf(address(this)), beforeTarget);
        assertEq(wings0.liquidationValue().value, beforeValue);
        (,,uint128 afterWing,) = wings0.position(1); assertEq(afterWing, wing);
    }
    function test_expiredDepositCannotPullTokensOrMint() public {
        vm.warp(100);
        uint256 balance = token0.balanceOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 99, 100));
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1000, IERC20(address(wings0)), 0, address(this), false, 99);
        assertEq(token0.balanceOf(address(this)), balance);
        assertEq(IERC20(address(wings0)).totalSupply(), 0);
    }
}
