// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Permit2 deposit paths (real Permit2 from TestBase_Permit2).
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Permit2_Test is TestBase {
    function setUp() public override {
        TestBase.setUp();
        _seedLiveLiquidity();
    }

    function test_R1_depositWithPermit2Allowance_whenApproved() public {
        uint256 a0 = _amountForCurrency(single.currency0(), 5 ether, 5 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 5 ether, 5 ether);

        vm.startPrank(user);
        rawToken.approve(address(permit2), type(uint256).max);
        pairToken.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(rawToken), hook, type(uint160).max, type(uint48).max
        );
        IAllowanceTransfer(address(permit2)).approve(
            address(pairToken), hook, type(uint160).max, type(uint48).max
        );

        (uint256 lp,,) =
            single.depositWithPermit2Allowance(a0, a1, user, 0, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(lp, 0);
    }

    function test_R1b_depositSingleWithPermit2Allowance() public {
        vm.startPrank(user);
        rawToken.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(rawToken), hook, uint160(10 ether), type(uint48).max
        );
        bytes32 before_ = _strictJoinState(user);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        assertGt(preview, 0, "Permit2 single quote");
        (uint160 allowed_, uint48 expiration_, uint48 nonce_) =
            IAllowanceTransfer(address(permit2)).allowance(user, address(rawToken), hook);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        single.depositSingleWithPermit2Allowance(
            address(rawToken), 5 ether, user, preview + 1, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(_strictJoinState(user), before_, "Permit2 funding and LP state restored");
        (uint160 afterAllowed_, uint48 afterExpiration_, uint48 afterNonce_) =
            IAllowanceTransfer(address(permit2)).allowance(user, address(rawToken), hook);
        assertEq(afterAllowed_, allowed_, "Permit2 amount restored");
        assertEq(afterExpiration_, expiration_, "Permit2 expiration preserved");
        assertEq(afterNonce_, nonce_, "Permit2 nonce preserved");
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 minted = single.depositSingleWithPermit2Allowance(
            address(rawToken), 5 ether, user, preview, block.timestamp + 1 hours
        );
        assertEq(minted, preview, "Permit2 allowance preview equals execution");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, minted, "Permit2 allowance recipient LP");
        (afterAllowed_, afterExpiration_, afterNonce_) =
            IAllowanceTransfer(address(permit2)).allowance(user, address(rawToken), hook);
        assertEq(afterAllowed_, allowed_ - uint160(5 ether), "finite Permit2 allowance consumed");
        assertEq(afterExpiration_, expiration_, "successful transfer preserves expiration");
        assertEq(afterNonce_, nonce_, "allowance transfer does not consume permit nonce");
    }

    /// @notice A minimum failure restores the signature nonce; a paid join consumes it once.
    function test_singlePermit2Signature_minimumRollback_thenConsumesNonce() public {
        uint256 key_ = 0xA117;
        address signer_ = vm.addr(key_);
        rawToken.mint(signer_, 5 ether);
        vm.prank(signer_);
        rawToken.approve(address(permit2), type(uint256).max);
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions(address(rawToken), 5 ether),
            nonce: 7,
            deadline: block.timestamp + 1 hours
        });
        bytes32 permissions_ = keccak256(abi.encode(
            keccak256("TokenPermissions(address token,uint256 amount)"), address(rawToken), 5 ether
        ));
        bytes32 hash_ = keccak256(abi.encode(
            keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            permissions_, hook, permit_.nonce, permit_.deadline
        ));
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), hash_));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(key_, digest_);
        bytes memory data_ = abi.encode(permit_, abi.encodePacked(r_, s_, v_));
        bytes32 before_ = _strictJoinState(signer_);
        uint256 nonceBefore_ = ISignatureTransfer(address(permit2)).nonceBitmap(signer_, 0);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        assertGt(preview, 0, "signature single quote");
        vm.prank(signer_);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        single.depositSingleWithPermit2Signature(address(rawToken), 5 ether, signer_, preview + 1, permit_.deadline, data_);
        assertEq(_strictJoinState(signer_), before_, "signature-funded pull and LP issuance roll back");
        assertEq(ISignatureTransfer(address(permit2)).nonceBitmap(signer_, 0), nonceBefore_, "signature remains unspent");
        vm.prank(signer_);
        uint256 minted = single.depositSingleWithPermit2Signature(
            address(rawToken), 5 ether, signer_, preview, permit_.deadline, data_
        );
        assertEq(minted, preview, "signature preview equals execution");
        assertEq(IERC20(hook).balanceOf(signer_), minted, "signature recipient net LP");
        assertEq(ISignatureTransfer(address(permit2)).nonceBitmap(signer_, 0),
            nonceBefore_ | (uint256(1) << 7), "signature nonce consumed exactly once");
    }
}
