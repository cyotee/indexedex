// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IEIP712} from "@crane/contracts/interfaces/IEIP712.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Signature-based Permit2 AllowanceTransfer (signed `permit`) then transfer into vault
///         and pretransferred routes. Covers the wallet "sign once" funding pattern on Base Permit2.
contract DualLiquidityLinkedCrossVersionUniswapVault_Permit2Signature is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    // Avoid fixed vanity keys that may already have bytecode on Base (e.g. EIP-7702
    // designators) - Permit2 routes those to EIP-1271 instead of ecrecover.
    uint256 internal userKey;
    address internal user;

    bytes32 internal constant PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");
    bytes32 internal constant PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        (user, userKey) = makeAddrAndKey("permit2SigUser_cleanEOA");
        // Guard against an accidental collision with on-chain code (forked Base).
        require(user.code.length == 0, "signer must be EOA for ecrecover path");
    }

    function test_permit2SignedAllowance_depositCommon() public {
        uint256 amount = LEG_SEED;
        _fund(commonToken, user, amount);
        vm.prank(user);
        commonToken.approve(address(permit2), type(uint256).max);

        _signedAllowanceAndTransfer(address(commonToken), amount);

        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, amount, IERC20(linkedVault));
        vm.prank(user);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amount, IERC20(linkedVault), 0, user, true, block.timestamp
        );
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop deposit preview ~ execution");
        assertEq(IERC20(linkedVault).balanceOf(user), minted);
    }

    function test_permit2SignedAllowance_swapTokenAToTokenB() public {
        uint256 amount = 200e18;
        _fund(tokenA, user, amount);
        vm.prank(user);
        tokenA.approve(address(permit2), type(uint256).max);

        _signedAllowanceAndTransfer(address(tokenA), amount);

        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, amount, tokenB);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, amount, tokenB, 0, user, true, block.timestamp
        );
        assertEq(out, preview);
        assertEq(tokenB.balanceOf(user), out);
    }

    /// @dev User signs PermitSingle allowing this test as spender; test pulls into linkedVault.
    ///      Split into helpers so the compiler stays under the stack limit (via_ir=false).
    function _signedAllowanceAndTransfer(address token, uint256 amount) internal {
        IAllowanceTransfer.PermitSingle memory permitSingle = _buildPermitSingle(token, uint160(amount));
        bytes memory sig = _signPermitSingle(permitSingle);

        IAllowanceTransfer p2 = IAllowanceTransfer(address(permit2));
        p2.permit(user, permitSingle, sig);
        p2.transferFrom(user, linkedVault, uint160(amount), token);
        assertEq(IERC20(token).balanceOf(linkedVault), amount);
    }

    function _buildPermitSingle(address token, uint160 amount)
        internal
        view
        returns (IAllowanceTransfer.PermitSingle memory permitSingle)
    {
        (,, uint48 nonce) = IAllowanceTransfer(address(permit2)).allowance(user, token, address(this));
        permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: token,
                amount: amount,
                expiration: uint48(block.timestamp + 1 days),
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: block.timestamp + 1 days
        });
    }

    function _signPermitSingle(IAllowanceTransfer.PermitSingle memory permitSingle)
        internal
        view
        returns (bytes memory)
    {
        bytes32 detailsHash = keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, permitSingle.details));
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_SINGLE_TYPEHASH, detailsHash, permitSingle.spender, permitSingle.sigDeadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", IEIP712(address(permit2)).DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
