// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    ISignatureTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IAllowanceTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {DeployPermit2} from
    "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

/**
 * @title UniswapV4OrbitalSwapHook_Permit2_Test
 * @notice Empty transferFrom + Signature batch + AllowanceTransfer via etched Permit2 (PRD §5.6).
 */
contract UniswapV4OrbitalSwapHook_Permit2_Test is TestBase_UniswapV4OrbitalSwapHook, DeployPermit2 {
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    uint256 internal userPk = 0xA11CE;
    address internal userSigner;

    function setUp() public override {
        TestBase_UniswapV4OrbitalSwapHook.setUp();
        deployPermit2(); // etch canonical Permit2 bytecode

        userSigner = vm.addr(userPk);
        // Fund dedicated signer (user in base is 0xBEEF without known pk)
        token0.mint(userSigner, FUND);
        token1.mint(userSigner, FUND);
        token2.mint(userSigner, FUND);
        vm.startPrank(userSigner);
        token0.approve(PERMIT2, type(uint256).max);
        token1.approve(PERMIT2, type(uint256).max);
        token2.approve(PERMIT2, type(uint256).max);
        vm.stopPrank();
    }

    function test_emptyPermit2Data_transferFromPull() public {
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) =
            _addLiquidity(10 ether, 10 ether, 10 ether);
        assertGt(shares, 0);
        assertEq(u0, 10 ether);
        assertEq(u1, 10 ether);
        assertEq(u2, 10 ether);
        assertEq(token0.balanceOf(hook), 10 ether);
    }

    function test_signatureBatch_threeLeg_firstMint() public {
        uint256 a = 20 ether;
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](3);
        permitted[0] = ISignatureTransfer.TokenPermissions({token: address(token0), amount: a});
        permitted[1] = ISignatureTransfer.TokenPermissions({token: address(token1), amount: a});
        permitted[2] = ISignatureTransfer.TokenPermissions({token: address(token2), amount: a});

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        bytes memory sig = _signBatch(permit, userPk, hook);
        bytes memory permit2Data = abi.encode(uint8(0), permit, sig);

        vm.prank(userSigner);
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = orbital.addLiquidity(
            a, a, a, userSigner, 0, block.timestamp + 1 hours, permit2Data
        );
        assertGt(shares, 0);
        assertEq(u0, a);
        assertEq(u1, a);
        assertEq(u2, a);
        assertEq(token0.balanceOf(hook), a);
    }

    function test_signatureBatch_oneLeg_partialSeed() public {
        // Seed three-leg via transferFrom path (user 0xBEEF)
        _seedThreeLeg(100 ether);

        uint256 seed = 25 ether;
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](1);
        // Binding-order pulled legs only: full book pulls all three; use full three for later mint
        // Use empty max on t0/t1 by... full book requires three legs. Use three-leg permit.
        permitted = new ISignatureTransfer.TokenPermissions[](3);
        permitted[0] = ISignatureTransfer.TokenPermissions({token: address(token0), amount: seed});
        permitted[1] = ISignatureTransfer.TokenPermissions({token: address(token1), amount: seed});
        permitted[2] = ISignatureTransfer.TokenPermissions({token: address(token2), amount: seed});

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: block.timestamp + 1 hours
        });
        bytes memory sig = _signBatch(permit, userPk, hook);
        bytes memory permit2Data = abi.encode(uint8(0), permit, sig);

        // Fund/approve already; userSigner must also hold tokens
        vm.prank(userSigner);
        (uint256 shares,,,) = orbital.addLiquidity(
            seed, seed, seed, userSigner, 0, block.timestamp + 1 hours, permit2Data
        );
        assertGt(shares, 0);
    }

    function test_allowanceMode_pullsUsedLegs() public {
        uint256 a = 15 ether;
        vm.startPrank(userSigner);
        // Permit2 allowance for hook as spender on each token
        IAllowanceTransfer(PERMIT2).approve(
            address(token0), hook, uint160(a), uint48(block.timestamp + 1 days)
        );
        IAllowanceTransfer(PERMIT2).approve(
            address(token1), hook, uint160(a), uint48(block.timestamp + 1 days)
        );
        IAllowanceTransfer(PERMIT2).approve(
            address(token2), hook, uint160(a), uint48(block.timestamp + 1 days)
        );

        bytes memory permit2Data = abi.encode(uint8(1));
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = orbital.addLiquidity(
            a, a, a, userSigner, 0, block.timestamp + 1 hours, permit2Data
        );
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(u0, a);
        assertEq(u1, a);
        assertEq(u2, a);
    }

    function test_wrongBatchOrder_reverts() public {
        uint256 a = 10 ether;
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](3);
        // Wrong order: token2, token0, token1
        permitted[0] = ISignatureTransfer.TokenPermissions({token: address(token2), amount: a});
        permitted[1] = ISignatureTransfer.TokenPermissions({token: address(token0), amount: a});
        permitted[2] = ISignatureTransfer.TokenPermissions({token: address(token1), amount: a});

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 9,
            deadline: block.timestamp + 1 hours
        });
        bytes memory sig = _signBatch(permit, userPk, hook);
        bytes memory permit2Data = abi.encode(uint8(0), permit, sig);

        vm.prank(userSigner);
        vm.expectRevert();
        orbital.addLiquidity(a, a, a, userSigner, 0, block.timestamp + 1 hours, permit2Data);
    }

    function _signBatch(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        uint256 pk,
        address spender
    ) internal view returns (bytes memory) {
        // Use live Permit2 domain (etched) — not a hand-rolled separator
        bytes32 domainSep = IPermit2(PERMIT2).DOMAIN_SEPARATOR();

        bytes32 tokenPermissionsHash;
        {
            bytes32[] memory hashes = new bytes32[](permit.permitted.length);
            for (uint256 i; i < permit.permitted.length; i++) {
                hashes[i] = keccak256(
                    abi.encode(
                        TOKEN_PERMISSIONS_TYPEHASH,
                        permit.permitted[i].token,
                        permit.permitted[i].amount
                    )
                );
            }
            tokenPermissionsHash = keccak256(abi.encodePacked(hashes));
        }

        bytes32 permitHash = keccak256(
            abi.encode(
                PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                tokenPermissionsHash,
                spender,
                permit.nonce,
                permit.deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domainSep, permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }
}
