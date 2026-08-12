// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Share token exposes ERC-2612 permit; approve spender without a separate approve tx.
contract DualLiquidityLinkedCrossVersionUniswapVault_ERC2612 is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    // Prefer makeAddrAndKey over fixed vanity keys - Base fork may already have bytecode
    // at low vanity addresses (EIP-7702), which breaks ecrecover-based permit verification.
    uint256 internal ownerKey;
    address internal shareOwner;
    address internal spender = makeAddr("permitSpender");

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        (shareOwner, ownerKey) = makeAddrAndKey("erc2612ShareOwner_cleanEOA");
        require(shareOwner.code.length == 0, "share owner must be EOA for ecrecover");
        // Fund shareOwner with shares.
        uint256 minted = _depositCommon(shareOwner, LEG_SEED);
        assertGt(minted, 0);
    }

    function test_erc2612_permitAllowsSpenderTransfer() public {
        IERC20 shareToken = IERC20(linkedVault);
        uint256 value = shareToken.balanceOf(shareOwner) / 2;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = IERC20Permit(linkedVault).nonces(shareOwner);

        bytes32 digest = _permitDigest(shareOwner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        IERC20Permit(linkedVault).permit(shareOwner, spender, value, deadline, v, r, s);
        assertEq(shareToken.allowance(shareOwner, spender), value);

        vm.prank(spender);
        bool ok = shareToken.transferFrom(shareOwner, spender, value);
        assertTrue(ok);
        assertEq(shareToken.balanceOf(spender), value);
    }

    function test_erc2612_spenderCannotExceedPermit() public {
        IERC20 shareToken = IERC20(linkedVault);
        uint256 value = 1e18;
        if (shareToken.balanceOf(shareOwner) < value) return;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = IERC20Permit(linkedVault).nonces(shareOwner);
        bytes32 digest = _permitDigest(shareOwner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);
        IERC20Permit(linkedVault).permit(shareOwner, spender, value, deadline, v, r, s);

        vm.prank(spender);
        vm.expectRevert();
        shareToken.transferFrom(shareOwner, spender, value + 1);
    }

    function _permitDigest(address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_)
        internal
        view
        returns (bytes32)
    {
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner_, spender_, value_, nonce_, deadline_));
        return keccak256(abi.encodePacked("\x19\x01", IERC20Permit(linkedVault).DOMAIN_SEPARATOR(), structHash));
    }
}
