// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4WeightedSwapHook, MintableDec} from
    "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {IUniswapV4WeightedSwapHook} from
    "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {DeployPermit2} from "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {UniswapV4WeightedSwapHookCommon} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol";

import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";

/// @notice Production-proxy accounting regression for exact Permit2 funding.
contract UniswapV4WeightedSwapHook_Recurrence is TestBase_UniswapV4WeightedSwapHook, DeployPermit2 {
    function test_recurrence_RawWeightedPermit2BooksOnlyDeliveredAmounts() public {
        address permit = deployPermit2();
        MintableDec first = new MintableDec("First", "FIRST", 18);
        MintableDec second = new MintableDec("Second", "SECOND", 18);
        if (address(second) < address(first)) (first, second) = (second, first);
        address[] memory tokens = new address[](2);
        tokens[0] = address(first);
        tokens[1] = address(second);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        (address deployed,) = _mineAndDeploy(tokens, weights, new address[](2));
        for (uint256 i; i < 2; ++i) {
            MintableDec(tokens[i]).mint(user, 100 ether);
            vm.startPrank(user);
            MintableDec(tokens[i]).approve(permit, type(uint256).max);
            IAllowanceTransfer(permit).approve(tokens[i], deployed, type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        IUniswapV4WeightedSwapHook subject = IUniswapV4WeightedSwapHook(deployed);
        uint256 snapshot = vm.snapshotState();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        vm.prank(user);
        (uint256 control,) = subject.joinProportional(amounts, user, 0, block.timestamp, abi.encode(uint8(1)));
        assertGt(control, 0, "ordinary Permit2 funding is live");
        assertEq(subject.reserveOf(tokens[0]), first.balanceOf(deployed));
        assertTrue(vm.revertToState(snapshot));

        amounts[0] += uint256(1) << 160;
        amounts[1] += uint256(1) << 160;
        (uint256 preview,) = subject.previewJoinProportional(amounts);
        assertGt(preview, 0, "large request reaches an admitted mint quote");
        vm.expectRevert(UniswapV4WeightedSwapHookCommon.InvalidPermit2Data.selector);
        vm.prank(user);
        subject.joinProportional(amounts, user, 0, block.timestamp, abi.encode(uint8(1)));
        assertEq(first.balanceOf(user), 100 ether, "failed funding preserves payer balance");
        assertEq(second.balanceOf(user), 100 ether, "failed batch rolls back every leg");
        assertEq(first.balanceOf(deployed), 0, "no truncated input survives");
        assertEq(second.balanceOf(deployed), 0, "no second input survives");
        assertEq(subject.reserveOf(tokens[0]), first.balanceOf(deployed), "book must equal delivered first token");
        assertEq(subject.reserveOf(tokens[1]), second.balanceOf(deployed), "book must equal delivered second token");
    }

    function test_taxedDirectFundingRejects() public { _assertTaxedFunding(0); }
    function test_taxedAllowanceFundingRejects() public { _assertTaxedFunding(1); }
    function test_taxedSignatureFundingRejects() public { _assertTaxedFunding(2); }

    function _assertTaxedFunding(uint8 mode) internal {
        address permit = deployPermit2();
        address payer = vm.addr(0xA11CE);
        address[] memory tokens = new address[](2);
        tokens[0] = address(new TaxedERC20Harness("First", "FIRST", 18, 0));
        tokens[1] = address(new TaxedERC20Harness("Second", "SECOND", 18, 0));
        if (tokens[1] < tokens[0]) (tokens[0], tokens[1]) = (tokens[1], tokens[0]);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        (address deployed,) = _mineAndDeploy(tokens, weights, new address[](2));
        assertLe(IDiamondLoupe(deployed).facetAddress(IUniswapV4WeightedSwapHook.joinProportional.selector).code.length, 24576);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = 100 ether;
            TaxedERC20Harness(tokens[i]).mint(payer, amounts[i]);
            vm.startPrank(payer);
            TaxedERC20Harness(tokens[i]).approve(mode == 0 ? deployed : permit, type(uint256).max);
            if (mode == 1) IAllowanceTransfer(permit).approve(tokens[i], deployed, type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        bytes memory data = mode == 2 ? _signedBatch(tokens, deployed, permit) : mode == 1 ? abi.encode(uint8(1)) : bytes("");
        IUniswapV4WeightedSwapHook subject = IUniswapV4WeightedSwapHook(deployed);
        uint256 snapshot = vm.snapshotState();
        vm.prank(payer);
        (uint256 shares,) = subject.joinProportional(amounts, payer, 0, block.timestamp, data);
        assertGt(shares, 0, "untaxed funding succeeds");
        assertTrue(vm.revertToState(snapshot));
        TaxedERC20Harness(tokens[1]).setTaxBps(1000);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100 ether, 90 ether));
        vm.prank(payer);
        subject.joinProportional(amounts, payer, 0, block.timestamp, data);
        for (uint256 i; i < 2; ++i) {
            assertEq(TaxedERC20Harness(tokens[i]).balanceOf(payer), amounts[i], "payer restored");
            assertEq(TaxedERC20Harness(tokens[i]).balanceOf(deployed), 0, "batch rolled back");
            assertEq(subject.reserveOf(tokens[i]), 0, "no unbacked reserves");
        }
    }

    function _signedBatch(address[] memory tokens, address spender, address permit2) internal view returns (bytes memory) {
        ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](2);
        bytes32[] memory hashes = new bytes32[](2);
        for (uint256 i; i < 2; ++i) {
            permissions[i] = ISignatureTransfer.TokenPermissions(tokens[i], 100 ether);
            hashes[i] = keccak256(abi.encode(keccak256("TokenPermissions(address token,uint256 amount)"), tokens[i], 100 ether));
        }
        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom(permissions, 0, block.timestamp);
        bytes32 structHash = keccak256(abi.encode(
            keccak256("PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            keccak256(abi.encodePacked(hashes)), spender, permit.nonce, permit.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", IPermit2(permit2).DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 sigS) = vm.sign(0xA11CE, digest);
        return abi.encode(uint8(0), permit, abi.encodePacked(r, sigS, v));
    }
}
