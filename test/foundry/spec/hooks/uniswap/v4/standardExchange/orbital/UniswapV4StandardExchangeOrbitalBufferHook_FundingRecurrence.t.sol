// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice I4/I5/L2: liquidity joins must reject undelivered raw-leg funding.
/// @dev Uses a hostile underlying, real SE leg and production hook. Other catalog checks stay in existing suites.
contract UniswapV4StandardExchangeOrbitalBufferHook_FundingRecurrence is TestBase {
    TaxedERC20Harness internal taxed;

    function setUp() public override {
        user = vm.addr(0xA11CE);
        super.setUp();
        taxed = new TaxedERC20Harness("Funding token", "FUND", 18, 0);
        token1 = SimpleMintableERC20(address(taxed));
        _deployHookWithArgs(_defaultPkgArgs());
        taxed.mint(user, FUND);
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function test_L2_FoT_forbidden_directLiquidity() public { _rejectShortReceipt(0); }
    function test_L2_FoT_forbidden_permit2Liquidity() public { _rejectShortReceipt(1); }
    function test_L2_FoT_forbidden_signatureLiquidity() public { _rejectShortReceipt(2); }
    function test_L2_FoT_forbidden_flexibleLiquidity() public { _rejectShortReceipt(3); }
    function test_L2_FoT_forbidden_directZap() public { _rejectShortZap(0); }
    function test_L2_FoT_forbidden_permit2Zap() public { _rejectShortZap(1); }
    function test_L2_FoT_forbidden_singleAssetJoin() public { _rejectShortZap(2); }

    function _rejectShortReceipt(uint8 mode) private {
        bytes memory permitData;
        if (mode == 1 || mode == 2) {
            address[3] memory tokens = [address(token0), address(token1), address(token2)];
            vm.startPrank(user);
            for (uint256 i; i < 3; ++i) {
                IERC20(tokens[i]).approve(PERMIT2_ADDR, type(uint256).max);
                IAllowanceTransfer(PERMIT2_ADDR).approve(tokens[i], hook, type(uint160).max, type(uint48).max);
            }
            vm.stopPrank();
            permitData = mode == 1 ? abi.encode(uint8(1)) : _signedBatch(tokens);
        }
        uint256 snapshot = vm.snapshotState();
        vm.prank(user);
        (uint256 shares,,,) = _join(mode, permitData);
        assertGt(shares, 0, "untaxed control must issue funded LP");
        assertEq(taxed.balanceOf(hook), 100 ether);
        assertTrue(vm.revertToState(snapshot));
        taxed.setTaxBps(1000);
        uint256 payerBefore = taxed.balanceOf(user);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100 ether, 90 ether));
        vm.prank(user);
        _join(mode, permitData);
        assertEq(taxed.balanceOf(user), payerBefore);
        assertEq(taxed.balanceOf(hook), 0);
        assertEq(IERC20(hook).totalSupply(), 0, "short funding cannot issue LP");
        assertEq(token0.balanceOf(hook), 0, "other transfers roll back");
        assertEq(token2.balanceOf(hook), 0, "other transfers roll back");
    }

    function _rejectShortZap(uint8 mode) private {
        _seedThreeLeg(100 ether);
        bytes memory data;
        if (mode == 1) {
            vm.startPrank(user);
            taxed.approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(address(taxed), hook, type(uint160).max, type(uint48).max);
            vm.stopPrank();
            data = abi.encode(uint8(1));
        }
        uint256 snapshot = vm.snapshotState();
        vm.prank(user);
        uint256 shares = _zap(mode, data);
        assertGt(shares, 0, "untaxed zap control");
        assertTrue(vm.revertToState(snapshot));
        taxed.setTaxBps(1000);
        uint256 payerBefore = taxed.balanceOf(user);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 hookBefore = taxed.balanceOf(hook);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 5 ether, 4.5 ether));
        vm.prank(user);
        _zap(mode, data);
        assertEq(taxed.balanceOf(user), payerBefore);
        assertEq(taxed.balanceOf(hook), hookBefore);
        assertEq(IERC20(hook).totalSupply(), supplyBefore);
    }

    function _join(uint8 mode, bytes memory data) private returns (uint256, uint256, uint256, uint256) {
        if (mode == 3) {
            return orbital.depositFlexible(100 ether, false, 100 ether, false, 100 ether, false, user, 1, block.timestamp);
        }
        return orbital.addLiquidity(100 ether, 100 ether, 100 ether, user, 1, block.timestamp, data);
    }

    function _zap(uint8 mode, bytes memory data) private returns (uint256) {
        if (mode == 2) {
            return IUniswapV4SeBufferHook(hook).joinSingleAssetExactIn(address(taxed), 5 ether, user, 1, block.timestamp);
        }
        return orbital.depositSingle(address(taxed), 5 ether, user, 1, block.timestamp, data);
    }

    function _signedBatch(address[3] memory tokens) private view returns (bytes memory) {
        ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](3);
        bytes32[] memory hashes = new bytes32[](3);
        for (uint256 i; i < 3; ++i) {
            permissions[i] = ISignatureTransfer.TokenPermissions(tokens[i], 100 ether);
            hashes[i] = keccak256(abi.encode(keccak256("TokenPermissions(address token,uint256 amount)"), tokens[i], 100 ether));
        }
        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom(permissions, 0, block.timestamp);
        bytes32 structHash = keccak256(abi.encode(
            keccak256("PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            keccak256(abi.encodePacked(hashes)), hook, permit.nonce, permit.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", IPermit2(PERMIT2_ADDR).DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xA11CE, digest);
        return abi.encode(uint8(0), permit, abi.encodePacked(r, s, v));
    }
}
