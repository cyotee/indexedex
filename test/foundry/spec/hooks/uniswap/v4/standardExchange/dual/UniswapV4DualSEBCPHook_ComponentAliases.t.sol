// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {TestBase_UniswapV4DualSEBCPHook} from "./TestBase_UniswapV4DualSEBCPHook.sol";

/// @notice Installed aliases on real ERC4626 SE proxies, complementing the real FullSpread adapter.
contract UniswapV4DualSEBCPHook_ComponentAliases is TestBase_UniswapV4DualSEBCPHook {
    uint256 private constant FEE = 2e16;
    uint256 private constant SIGNER_KEY = 0xA11CE840;

    struct Snapshot {
        uint256 supply;
        uint256 userLp;
        uint256 feeLp;
        uint256[4] components;
    }

    function _snapshot(address actor) private view returns (Snapshot memory s) {
        s.supply = IERC20(hook).totalSupply();
        s.userLp = IERC20(hook).balanceOf(actor);
        s.feeLp = IERC20(hook).balanceOf(dual.feeTo());
        s.components = [IERC20(seA).balanceOf(hook), tokenA.balanceOf(hook),
            IERC20(seB).balanceOf(hook), tokenB.balanceOf(hook)];
    }

    function _feeReceipt(Snapshot memory before_, address actor, uint256 net) private view {
        Snapshot memory after_ = _snapshot(actor);
        uint256 gross = after_.supply - before_.supply;
        assertGt(net, 0, "alias reaches actual positive issuance");
        assertEq(after_.userLp - before_.userLp, net);
        assertEq(after_.feeLp - before_.feeLp, gross * FEE / 1e18);
        assertEq(net + after_.feeLp - before_.feeLp, gross, "no fee on top");
    }

    function _componentReceipt(Snapshot memory before_, address actor, uint256 net) private view {
        _feeReceipt(before_, actor, net);
        Snapshot memory after_ = _snapshot(actor);
        uint256 gross = after_.supply - before_.supply;
        for (uint256 i; i < 4; ++i) {
            uint256 product = gross * before_.components[i];
            uint256 required = product / before_.supply + (product % before_.supply == 0 ? 0 : 1);
            assertEq(after_.components[i] - before_.components[i], required, "one common ceil fraction");
            assertGe(after_.components[i] * before_.supply, before_.components[i] * after_.supply);
        }
    }

    function test_H3_allFlexibleInputAndOutputFlags() public {
        _enableProtocolFee(FEE);
        _depositBoth(100 ether, 100 ether);
        uint256 checkpoint = vm.snapshotState();
        for (uint256 mask; mask < 4; ++mask) {
            assertTrue(vm.revertToState(checkpoint));
            checkpoint = vm.snapshotState();
            uint256 sharesA = _userAcquireSeShares(seA, tokenA, 20 ether);
            uint256 sharesB = _userAcquireSeShares(seB, tokenB, 20 ether);
            bool firstA = dual.currency0() == address(tokenA);
            bool share0 = mask & 1 != 0;
            bool share1 = mask & 2 != 0;
            uint256 amount0 = share0 ? (firstA ? sharesA : sharesB) : 20 ether;
            uint256 amount1 = share1 ? (firstA ? sharesB : sharesA) : 20 ether;
            Snapshot memory before_ = _snapshot(user);
            (uint256 preview, uint256 used0, uint256 used1) =
                dual.previewDepositFlexible(amount0, share0, amount1, share1);
            vm.prank(user);
            (uint256 net, uint256 actual0, uint256 actual1) =
                dual.depositFlexible(amount0, share0, amount1, share1, user, preview, block.timestamp);
            assertEq(net, preview);
            assertEq(actual0, used0);
            assertEq(actual1, used1);
            _componentReceipt(before_, user, net);

            uint256 burn = net / 3;
            before_ = _snapshot(user);
            (uint256 out0, uint256 out1) = dual.previewWithdrawFlexible(burn, share0, share1);
            address token0 = share0 ? dual.standardExchangeOf(dual.currency0()) : dual.currency0();
            address token1 = share1 ? dual.standardExchangeOf(dual.currency1()) : dual.currency1();
            uint256 balance0 = IERC20(token0).balanceOf(user);
            uint256 balance1 = IERC20(token1).balanceOf(user);
            vm.prank(user);
            (actual0, actual1) = dual.withdrawFlexible(burn, user, share0, share1, out0, out1, block.timestamp);
            assertEq(actual0, out0);
            assertEq(actual1, out1);
            assertEq(IERC20(token0).balanceOf(user) - balance0, out0);
            assertEq(IERC20(token1).balanceOf(user) - balance1, out1);
            Snapshot memory after_ = _snapshot(user);
            assertEq(after_.feeLp, before_.feeLp, "no exit fee");
            for (uint256 i; i < 4; ++i) {
                assertEq(before_.components[i] - after_.components[i],
                    burn * before_.components[i] / before_.supply, "floor each component before conversion");
            }
        }
    }

    function test_H3_proportionalAndUnbalancedAliases() public {
        _enableProtocolFee(FEE);
        _depositBoth(100 ether, 100 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 11 ether;
        amounts[1] = 17 ether;
        Snapshot memory before_ = _snapshot(user);
        (uint256 preview,) = dual.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 net,) = dual.joinProportional(amounts, user, preview, block.timestamp);
        assertEq(net, preview);
        _componentReceipt(before_, user, net);
        address[] memory tokens = new address[](2);
        tokens[0] = dual.currency1();
        tokens[1] = dual.currency0();
        before_ = _snapshot(user);
        preview = dual.previewJoinUnbalanced(tokens, amounts);
        vm.prank(user);
        net = dual.joinUnbalanced(tokens, amounts, user, preview, block.timestamp);
        assertEq(net, preview);
        _componentReceipt(before_, user, net);
        uint256 burned = net / 2;
        uint256[] memory expected = dual.previewExitProportional(burned);
        vm.prank(user);
        uint256[] memory paid = dual.exitProportional(burned, user, expected, block.timestamp);
        assertEq(paid, expected);
        assertGt(paid[0], 0);
        assertGt(paid[1], 0);
    }

    /// @dev Reproduce the paid trade separately, then assert the proportional mint at that boundary.
    function _referenceSingle(address actor, address token, uint256 amount) private returns (Snapshot memory expected) {
        address pair = token == seA ? address(tokenA) : token;
        vm.startPrank(actor);
        if (token == seA) {
            IERC20(token).approve(token, amount);
            (amount,) = IStandardExchangeIn(token).exchangeIn(
                IERC20(token), amount, IERC20(pair), 1, actor, false, block.timestamp);
        }
        IERC20(pair).approve(hook, type(uint256).max);
        vm.stopPrank();
        (uint256 sold,, uint256 kept) = dual.previewZapSplit(pair, amount);
        address other = pair == dual.currency0() ? dual.currency1() : dual.currency0();
        vm.prank(actor);
        (uint256 received,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(pair), sold, IERC20(other), 1, actor, false, block.timestamp);
        Snapshot memory boundary = _snapshot(actor);
        vm.startPrank(actor);
        IERC20(other).approve(hook, type(uint256).max);
        (uint256 net,,) = dual.deposit(pair == dual.currency0() ? kept : received,
            pair == dual.currency0() ? received : kept, actor, 1, block.timestamp);
        vm.stopPrank();
        _componentReceipt(boundary, actor, net);
        expected = _snapshot(actor);
    }

    function test_H3_singleInputSeAndNativeSyAliasesFundPaidSwap() public {
        _enableProtocolFee(FEE);
        _depositBoth(100 ether, 100 ether);
        uint256 checkpoint = vm.snapshotState();
        for (uint256 route; route < 8; ++route) {
            assertTrue(vm.revertToState(checkpoint));
            checkpoint = vm.snapshotState();
            address token = address(tokenA);
            uint256 amount = 10 ether;
            if (route >= 5) {
                token = seA;
                amount = _userAcquireSeShares(seA, tokenA, 10 ether);
            }
            uint256 funded = vm.snapshotState();
            Snapshot memory expected = _referenceSingle(user, token, amount);
            assertTrue(vm.revertToState(funded));
            uint256 preview = dual.previewJoinSingleAssetExactIn(token, amount);
            assertGt(preview, 0, "caller-funded swap prepares both legs");
            assertEq(IStandardizedYield(hook).previewDeposit(token, amount), preview);
            (uint256 sePreview, uint256 refund) = IStandardExchangeIn(hook)
                .previewExchangeIn(IERC20(token), amount, IERC20(hook));
            assertEq(sePreview, preview);
            assertEq(refund, 0);
            Snapshot memory before_ = _snapshot(user);
            uint256 net;
            vm.startPrank(user);
            if (route == 0) net = dual.depositSingle(token, amount, user, preview, block.timestamp);
            else if (route == 1 || route == 5)
                net = dual.joinSingleAssetExactIn(token, amount, user, preview, block.timestamp);
            else if (route == 2) {
                address[] memory tokens = new address[](1);
                uint256[] memory amounts = new uint256[](1);
                tokens[0] = token;
                amounts[0] = amount;
                net = dual.joinUnbalanced(tokens, amounts, user, preview, block.timestamp);
            } else if (route == 3 || route == 6) {
                (net,) = IStandardExchangeIn(hook).exchangeIn(IERC20(token), amount, IERC20(hook),
                    preview, user, false, block.timestamp);
            } else net = IStandardizedYield(hook).deposit(user, token, amount, preview);
            vm.stopPrank();
            assertEq(net, preview);
            _feeReceipt(before_, user, net);
            assertEq(abi.encode(_snapshot(user)), abi.encode(expected),
                "alias equals a paid swap plus ceil-backed post-swap mint");
        }
    }

    function test_H3_singleAssetExitAliasesStillPayAllocatedBasket() public {
        _enableProtocolFee(FEE);
        uint256 net = _depositBoth(100 ether, 100 ether);
        uint256 checkpoint = vm.snapshotState();
        for (uint256 route; route < 6; ++route) {
            assertTrue(vm.revertToState(checkpoint));
            checkpoint = vm.snapshotState();
            uint256 burn = net / 3;
            address exitToken = route % 2 == 0 ? address(tokenB) : seB;
            uint256 predicted = dual.previewExitSingleAssetExactBptIn(exitToken, burn);
            uint256 pairBefore = IERC20(exitToken).balanceOf(user);
            uint256 feeBefore = IERC20(hook).balanceOf(dual.feeTo());
            uint256 output;
            vm.startPrank(user);
            if (route % 3 == 0)
                output = dual.exitSingleAssetExactBptIn(exitToken, burn, user, predicted, block.timestamp);
            else if (route % 3 == 1)
                (output,) = IStandardExchangeIn(hook).exchangeIn(IERC20(hook), burn, IERC20(exitToken),
                    predicted, user, false, block.timestamp);
            else output = IStandardizedYield(hook).redeem(user, burn, exitToken, predicted, false);
            vm.stopPrank();
            assertGt(output, 0);
            assertEq(output, predicted);
            assertEq(IERC20(exitToken).balanceOf(user) - pairBefore, output);
            assertEq(IERC20(hook).balanceOf(dual.feeTo()), feeBefore);
        }
    }

    function _signature(bytes32 permitHash) private view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", IPermit2(PERMIT2_ADDR).DOMAIN_SEPARATOR(), permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _batchData(uint256 amount) private view returns (bytes memory) {
        ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](2);
        permitted[0] = ISignatureTransfer.TokenPermissions(dual.currency0(), amount);
        permitted[1] = ISignatureTransfer.TokenPermissions(dual.currency1(), amount);
        ISignatureTransfer.PermitBatchTransferFrom memory permit =
            ISignatureTransfer.PermitBatchTransferFrom(permitted, 8, block.timestamp + 1 hours);
        bytes32 tokenType = keccak256("TokenPermissions(address token,uint256 amount)");
        bytes32 permissions = keccak256(abi.encodePacked(
            keccak256(abi.encode(tokenType, permitted[0].token, amount)),
            keccak256(abi.encode(tokenType, permitted[1].token, amount))));
        bytes32 hash = keccak256(abi.encode(keccak256(
            "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            permissions, hook, permit.nonce, permit.deadline));
        return abi.encode(permit, _signature(hash));
    }

    function _singleData(address token, uint256 amount) private view returns (bytes memory) {
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom(
            ISignatureTransfer.TokenPermissions(token, amount), 9, block.timestamp + 1 hours);
        bytes32 permission = keccak256(abi.encode(
            keccak256("TokenPermissions(address token,uint256 amount)"), token, amount));
        bytes32 hash = keccak256(abi.encode(keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            permission, hook, permit.nonce, permit.deadline));
        return abi.encode(permit, _signature(hash));
    }

    function test_H3_permit2MultiInputAndSingleInputMintBackedLp() public {
        _enableProtocolFee(FEE);
        _depositBoth(100 ether, 100 ether);
        address signer = vm.addr(SIGNER_KEY);
        tokenA.mint(signer, 100 ether);
        tokenB.mint(signer, 100 ether);
        vm.startPrank(signer);
        tokenA.approve(PERMIT2_ADDR, type(uint256).max);
        tokenB.approve(PERMIT2_ADDR, type(uint256).max);
        IAllowanceTransfer(PERMIT2_ADDR).approve(address(tokenA), hook, 100 ether, type(uint48).max);
        IAllowanceTransfer(PERMIT2_ADDR).approve(address(tokenB), hook, 100 ether, type(uint48).max);
        vm.stopPrank();
        uint256 checkpoint = vm.snapshotState();
        for (uint256 route; route < 4; ++route) {
            assertTrue(vm.revertToState(checkpoint));
            checkpoint = vm.snapshotState();
            Snapshot memory before_ = _snapshot(signer);
            bytes memory data = route == 0 ? _batchData(10 ether) : _singleData(address(tokenA), 10 ether);
            uint256 net;
            Snapshot memory expected;
            if (route >= 2) {
                uint256 funded = vm.snapshotState();
                expected = _referenceSingle(signer, address(tokenA), 10 ether);
                assertTrue(vm.revertToState(funded));
            }
            uint256 nonce = ISignatureTransfer(PERMIT2_ADDR).nonceBitmap(signer, 0);
            (uint160 allowanceBefore, uint48 expirationBefore, uint48 nonceBefore) =
                IAllowanceTransfer(PERMIT2_ADDR).allowance(signer, address(tokenA), hook);
            vm.prank(signer);
            if (route == 0) (net,,) = dual.depositWithPermit2Signature(10 ether, 10 ether, signer, 1, block.timestamp, data);
            else if (route == 1) (net,,) = dual.depositWithPermit2Allowance(10 ether, 10 ether, signer, 1, block.timestamp);
            else if (route == 2) net = dual.depositSingleWithPermit2Signature(address(tokenA), 10 ether, signer, 1, block.timestamp, data);
            else net = dual.depositSingleWithPermit2Allowance(address(tokenA), 10 ether, signer, 1, block.timestamp);
            if (route < 2) _componentReceipt(before_, signer, net);
            else {
                _feeReceipt(before_, signer, net);
                assertEq(abi.encode(_snapshot(signer)), abi.encode(expected), "paid-swap mint boundary");
                assertEq(ISignatureTransfer(PERMIT2_ADDR).nonceBitmap(signer, 0),
                    route == 2 ? nonce | (uint256(1) << 9) : nonce, "signature nonce consumed only on signature route");
                (uint160 allowanceAfter, uint48 expirationAfter, uint48 nonceAfter) =
                    IAllowanceTransfer(PERMIT2_ADDR).allowance(signer, address(tokenA), hook);
                assertEq(uint256(allowanceAfter), uint256(allowanceBefore) - (route == 3 ? 10 ether : 0),
                    "finite Permit2 allowance pays actual input");
                assertEq(expirationAfter, expirationBefore);
                assertEq(nonceAfter, nonceBefore);
            }
        }
    }

    function test_H3_zeroRefundSwapKeepsInputLocalBookUnchanged() public {
        _enableProtocolFee(FEE);
        _depositBoth(100 ether, 100 ether);
        (uint256 shares, uint256 refund) = IStandardExchangeIn(seA)
            .previewExchangeIn(IERC20(address(tokenA)), 10 ether, IERC20(seA));
        assertGt(shares, 0);
        assertEq(refund, 0);
        Snapshot memory before_ = _snapshot(user);
        vm.prank(user);
        (uint256 paid,) = IStandardExchangeIn(hook).exchangeIn(IERC20(address(tokenA)), 10 ether,
            IERC20(address(tokenB)), 1, user, false, block.timestamp);
        Snapshot memory after_ = _snapshot(user);
        assertGt(paid, 0);
        assertEq(after_.components[0] - before_.components[0], shares);
        assertEq(after_.components[1], before_.components[1], "zero refund creates no local credit");
        assertEq(after_.supply, before_.supply);
        assertEq(after_.feeLp, before_.feeLp);
    }

    function test_H3_nativeSyVaultHeldLpUsesTheSameExitBook() public {
        _enableProtocolFee(FEE);
        uint256 net = _depositBoth(100 ether, 100 ether);
        uint256 burn = net / 4;
        uint256 preview = IStandardizedYield(hook).previewRedeem(address(tokenB), burn);
        uint256 beforePair = tokenB.balanceOf(user);
        uint256 beforeSupply = IERC20(hook).totalSupply();
        uint256 beforeFee = IERC20(hook).balanceOf(dual.feeTo());
        vm.prank(user);
        IERC20(hook).transfer(hook, burn);
        uint256 paid = IStandardizedYield(hook).redeem(user, burn, address(tokenB), preview, true);
        assertGt(paid, 0);
        assertEq(paid, preview);
        assertEq(tokenB.balanceOf(user) - beforePair, paid);
        assertEq(IERC20(hook).balanceOf(hook), 0);
        assertEq(IERC20(hook).totalSupply(), beforeSupply - burn);
        assertEq(IERC20(hook).balanceOf(dual.feeTo()), beforeFee);
    }

    function test_H3_protocolLpWithdrawsItsOrdinaryComponentFraction() public {
        _enableProtocolFee(FEE);
        _depositBoth(100 ether, 100 ether);
        address recipient = dual.feeTo();
        Snapshot memory before_ = _snapshot(recipient);
        uint256 burned = before_.userLp / 2;
        assertGt(burned, 0);
        address payout = address(0xFEED840);
        (uint256 expected0, uint256 expected1) = dual.previewWithdraw(burned);
        vm.prank(recipient);
        (uint256 actual0, uint256 actual1) = dual.withdraw(burned, payout, expected0, expected1, block.timestamp);
        assertEq(actual0, expected0);
        assertEq(actual1, expected1);
        assertEq(IERC20(dual.currency0()).balanceOf(payout), actual0);
        assertEq(IERC20(dual.currency1()).balanceOf(payout), actual1);
        Snapshot memory after_ = _snapshot(recipient);
        assertEq(after_.supply, before_.supply - burned);
        assertEq(after_.userLp, before_.userLp - burned);
        for (uint256 i; i < 4; ++i)
            assertEq(before_.components[i] - after_.components[i], burned * before_.components[i] / before_.supply);
    }

    function test_H3_inactiveFeeAndZeroRecipientDoNotDilute() public {
        IVaultFeeOracleManager manager = IVaultFeeOracleManager(address(indexedexManager));
        vm.startPrank(owner);
        manager.setDefaultDexSwapFee(0);
        manager.setVaultDexSwapFee(hook, 0);
        vm.stopPrank();
        assertEq(dual.dexSwapFee(), 0, "resolved fee, not an unset override assumption");
        uint256 net = _depositBoth(100 ether, 100 ether);
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        _enableProtocolFee(FEE);
        vm.prank(owner);
        manager.setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 supply = IERC20(hook).totalSupply();
        net = _depositBoth(10 ether, 10 ether);
        assertEq(IERC20(hook).totalSupply() - supply, net);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000, "zero recipient never receives a fee mint");
    }
}


