// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {StandardExchangeConstantProduct} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport as Import} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInBase as ImportErrors} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultCommon as CommonErrors} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol";

// tag::TestBase_UniswapV4FullSpreadG4ImportClosure[]
/// @notice G4 test-only predicates over either family's actual registry proxy.
/// @dev H imports above supply the existing common ABI/error declarations only, never execution.
abstract contract TestBase_UniswapV4FullSpreadG4ImportClosure is Test {
    using PoolIdLibrary for PoolKey;

    struct G4ImportFixture {
        IStandardExchangeProxy vault;
        IPoolManager manager;
        IPositionManager positions;
        IPermit2 permit;
        PoolKey key;
        IERC20 token0;
        IERC20 token1;
    }
    G4ImportFixture internal g4;

    /// @dev Family adapter creates a separate, genuinely unbound registry package.
    function _g4UnboundVault() internal virtual returns (IStandardExchangeProxy);
    function _g4Trade() internal virtual;

    function _g4Mint(int24 lower_, int24 upper_, uint256 liquidity_) internal returns (uint256 id_) {
        g4.token0.approve(address(g4.permit), type(uint256).max);
        g4.token1.approve(address(g4.permit), type(uint256).max);
        g4.permit.approve(address(g4.token0), address(g4.positions), type(uint160).max, type(uint48).max);
        g4.permit.approve(address(g4.token1), address(g4.positions), type(uint160).max, type(uint48).max);
        id_ = g4.positions.nextTokenId();
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(g4.key, lower_, upper_, liquidity_, uint128(100e18), uint128(100e18), address(this), bytes(""));
        params[1] = abi.encode(g4.key.currency0, g4.key.currency1);
        g4.positions.modifyLiquidities(abi.encode(
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR)), params), block.timestamp);
        assertEq(g4.positions.getPositionLiquidity(id_), liquidity_);
        IERC721(address(g4.positions)).approve(address(g4.vault), id_);
    }

    /// @dev Independent real periphery settlement, reusable for fee-only and full withdrawal controls.
    function _g4Withdraw(uint256 id_, uint256 liquidity_) internal returns (uint256 a0_, uint256 a1_) {
        uint256 before0 = g4.token0.balanceOf(address(this));
        uint256 before1 = g4.token1.balanceOf(address(this));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(id_, liquidity_, uint128(0), uint128(0), bytes(""));
        params[1] = abi.encode(g4.key.currency0, g4.key.currency1, address(this));
        g4.positions.modifyLiquidities(abi.encode(
            abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR)), params), block.timestamp);
        return (g4.token0.balanceOf(address(this)) - before0, g4.token1.balanceOf(address(this)) - before1);
    }

    function _g4Measure(uint256 id_) internal returns (uint256 a0_, uint256 a1_) {
        uint256 snapshot = vm.snapshotState();
        (a0_, a1_) = _g4Withdraw(id_, g4.positions.getPositionLiquidity(id_));
        assertTrue(vm.revertToStateAndDelete(snapshot));
    }

    function _g4Import(uint256 id_, uint256 minimum_) internal returns (uint256) {
        return Import(address(g4.vault)).importPosition(g4.positions, id_, minimum_, address(this), address(this), block.timestamp);
    }

    function _g4Ledger() internal view returns (bytes32) {
        return keccak256(abi.encode(
            g4.token0.balanceOf(address(this)), g4.token1.balanceOf(address(this)),
            g4.token0.balanceOf(address(g4.vault)), g4.token1.balanceOf(address(g4.vault)),
            g4.vault.totalSupply(), g4.vault.balanceOf(address(this)), g4.vault.balanceOf(address(0xdEaD)),
            g4.vault.reserveOfToken(address(g4.token0)), g4.vault.reserveOfToken(address(g4.token1)),
            g4.vault.reserveOfToken(address(g4.vault)), g4.vault.balanceOf(address(g4.vault))));
    }

    function _g4Fingerprint(uint256 id_) internal view returns (bytes32) {
        return keccak256(abi.encode(_g4Ledger(),
            IERC721(address(g4.positions)).ownerOf(id_), IERC721(address(g4.positions)).getApproved(id_),
            g4.positions.getPositionLiquidity(id_), StateLibrary.getLiquidity(g4.manager, g4.key.toId()),
            g4.token0.balanceOf(address(g4.positions)), g4.token1.balanceOf(address(g4.positions)),
            g4.token0.balanceOf(address(g4.manager)), g4.token1.balanceOf(address(g4.manager))));
    }

    /// @notice Wrong manager, unbound package, forged owner, and a different actual NFT owner all reject atomically.
    function test_G4_importTrustMatrix() public {
        uint256 id = _g4Mint(-120, 120, 1_000e18);
        bytes32 beforeState = _g4Fingerprint(id);
        vm.expectRevert(ImportErrors.UniswapV4ExchangeIn_UntrustedPositionManager.selector);
        Import(address(g4.vault)).importPosition(IPositionManager(address(0xBAD)), id, 0, address(this), address(this), block.timestamp);
        assertEq(_g4Fingerprint(id), beforeState);
        vm.expectRevert(ImportErrors.UniswapV4ExchangeIn_UntrustedImportOwner.selector);
        Import(address(g4.vault)).importPosition(g4.positions, id, 0, address(0xBAD), address(this), block.timestamp);
        assertEq(_g4Fingerprint(id), beforeState);
        vm.prank(address(0xBAD));
        vm.expectRevert(ImportErrors.UniswapV4ExchangeIn_UntrustedImportOwner.selector);
        Import(address(g4.vault)).importPosition(g4.positions, id, 0, address(0xBAD), address(0xBAD), block.timestamp);
        assertEq(_g4Fingerprint(id), beforeState);
        assertEq(g4.vault.balanceOf(address(0xBAD)), 0);

        IStandardExchangeProxy bound = g4.vault;
        g4.vault = _g4UnboundVault();
        IERC721(address(g4.positions)).approve(address(g4.vault), id);
        beforeState = _g4Fingerprint(id);
        vm.expectRevert(ImportErrors.UniswapV4ExchangeIn_UntrustedPositionManager.selector);
        _g4Import(id, 0);
        assertEq(_g4Fingerprint(id), beforeState);
        assertEq(g4.vault.totalSupply(), 0);
        assertEq(bound.totalSupply(), 0);
    }

    /// @notice Each naturally one-sided NFT fails even when the missing side has donated local inventory.
    function test_G4_importUnfundedSideRollbackBothOrientations() public {
        for (uint256 side; side < 2; ++side) {
            uint256 snapshot = vm.snapshotState();
            uint256 id = side == 0 ? _g4Mint(60, 180, 1_000e18) : _g4Mint(-180, -60, 1_000e18);
            (uint256 a0, uint256 a1) = _g4Measure(id);
            assertEq(side == 0 ? a1 : a0, 0);
            assertGt(side == 0 ? a0 : a1, 0);
            g4.token0.transfer(address(g4.vault), 1e18);
            g4.token1.transfer(address(g4.vault), 1e18);
            bytes32 beforeState = _g4Fingerprint(id);
            vm.expectRevert(CommonErrors.UniswapV4Exchange_ZeroAmount.selector);
            _g4Import(id, 0);
            assertEq(_g4Fingerprint(id), beforeState);
            assertEq(g4.vault.totalSupply(), 0);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    /// @notice Decimal minimum uses actual NFT proceeds; both NFT transfer and removal roll back.
    function test_G4_importBelowFloorRollback() public {
        uint256 id = _g4Mint(-120, 120, 1e12);
        (uint256 a0, uint256 a1) = _g4Measure(id);
        uint256 raw = Math.sqrt(a0 * a1);
        assertGt(raw, 0);
        assertLe(raw, 1e15);
        bytes32 beforeState = _g4Fingerprint(id);
        vm.expectRevert(abi.encodeWithSelector(StandardExchangeConstantProduct.InsufficientMinimumLiquidity.selector, raw, uint256(1e15)));
        _g4Import(id, 0);
        assertEq(_g4Fingerprint(id), beforeState);
        assertEq(g4.vault.totalSupply(), 0);
        assertEq(g4.token0.balanceOf(address(g4.vault)), 0);
        assertEq(g4.token1.balanceOf(address(g4.vault)), 0);
    }

    /// @notice Real fee collection is included exactly once in first issuance, then the empty NFT cannot issue again.
    function test_G4_importEarnedFeesOnceAndApprovalsZero() public {
        uint256 id = _g4Mint(-120, 120, 1_000e18);
        _g4Trade();
        uint256 snapshot = vm.snapshotState();
        (uint256 fee0, uint256 fee1) = _g4Withdraw(id, 0);
        (uint256 principal0, uint256 principal1) = _g4Withdraw(id, g4.positions.getPositionLiquidity(id));
        assertTrue(vm.revertToStateAndDelete(snapshot));
        // H earns LP fees. P's registered zero-LP-fee pool routes charges to the hook, not the NFT.
        if (g4.key.fee != 0) assertGt(fee0 + fee1, 0);
        else assertEq(fee0 + fee1, 0);
        (uint256 a0, uint256 a1) = _g4Measure(id);
        assertEq(a0, principal0 + fee0);
        assertEq(a1, principal1 + fee1);
        uint256 expected = Math.sqrt(a0 * a1) - 1e15;
        bytes32 beforeState = _g4Fingerprint(id);
        vm.expectRevert(ImportErrors.UniswapV4ExchangeIn_SlippageExceeded.selector);
        _g4Import(id, expected + 1);
        assertEq(_g4Fingerprint(id), beforeState);
        assertEq(_g4Import(id, expected), expected);
        assertEq(g4.vault.balanceOf(address(this)), expected);
        assertEq(g4.vault.balanceOf(address(0xdEaD)), 1e15);
        assertEq(g4.vault.totalSupply(), expected + 1e15);
        assertEq(g4.positions.getPositionLiquidity(id), 0);
        assertEq(IERC721(address(g4.positions)).ownerOf(id), address(g4.vault));
        assertEq(IERC721(address(g4.positions)).getApproved(id), address(0));
        _g4ApprovalsZero(g4.token0);
        _g4ApprovalsZero(g4.token1);
        assertFalse(IERC721(address(g4.positions)).isApprovedForAll(address(g4.vault), address(this)));
        beforeState = _g4Fingerprint(id);
        vm.expectRevert(ImportErrors.UniswapV4ExchangeIn_UntrustedImportOwner.selector);
        _g4Import(id, 0);
        assertEq(_g4Fingerprint(id), beforeState);
        _g4Booked();
    }

    function _g4ApprovalsZero(IERC20 token_) internal view {
        assertEq(token_.allowance(address(g4.vault), address(g4.positions)), 0);
        (uint160 amount, uint48 expiration, uint48 nonce) = g4.permit.allowance(address(g4.vault), address(token_), address(g4.positions));
        assertEq(amount, 0); assertEq(expiration, 0); assertEq(nonce, 0);
    }

    /// @notice Full imported core checkpoint matches real removal, then both SY faces redeem without touching the empty NFT.
    function test_G4_importCoreCheckpointAndSyLifecycleBothFaces() public {
        uint256 id = _g4Mint(-120, 120, 1_000e18);
        _g4Trade();
        (PoolKey memory nftKey, PositionInfo info) = g4.positions.getPoolAndPositionInfo(id);
        assertEq(abi.encode(nftKey), abi.encode(g4.key));
        assertEq(info.tickLower(), -120); assertEq(info.tickUpper(), 120);
        (uint128 beforeLiquidity,,) = StateLibrary.getPositionInfo(g4.manager, nftKey.toId(),
            address(g4.positions), info.tickLower(), info.tickUpper(), bytes32(id));
        assertEq(beforeLiquidity, g4.positions.getPositionLiquidity(id));
        assertGt(beforeLiquidity, 0);
        uint256 snapshot = vm.snapshotState();
        _g4Withdraw(id, beforeLiquidity);
        bytes32 emptiedCheckpoint = _g4NftCoreCheckpoint(id, nftKey, info);
        assertTrue(vm.revertToStateAndDelete(snapshot));
        uint256 issued = _g4Import(id, 0);
        assertEq(_g4NftCoreCheckpoint(id, nftKey, info), emptiedCheckpoint);
        for (uint256 side; side < 2; ++side) {
            snapshot = vm.snapshotState();
            _g4SyExit(side == 0 ? g4.token0 : g4.token1, issued / 10);
            assertEq(_g4NftCoreCheckpoint(id, nftKey, info), emptiedCheckpoint);
            assertEq(g4.positions.getPositionLiquidity(id), 0);
            assertEq(IERC721(address(g4.positions)).ownerOf(id), address(g4.vault));
            assertEq(IERC721(address(g4.positions)).getApproved(id), address(0));
            _g4ApprovalsZero(g4.token0); _g4ApprovalsZero(g4.token1);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function _g4NftCoreCheckpoint(uint256 id_, PoolKey memory key_, PositionInfo info_) internal view returns (bytes32) {
        (PoolKey memory actualKey, PositionInfo actualInfo) = g4.positions.getPoolAndPositionInfo(id_);
        assertEq(abi.encode(actualKey), abi.encode(key_));
        assertEq(actualInfo.tickLower(), info_.tickLower());
        assertEq(actualInfo.tickUpper(), info_.tickUpper());
        (uint128 liquidity, uint256 fee0, uint256 fee1) = StateLibrary.getPositionInfo(g4.manager, key_.toId(),
            address(g4.positions), info_.tickLower(), info_.tickUpper(), bytes32(id_));
        assertEq(liquidity, 0);
        return keccak256(abi.encode(liquidity, fee0, fee1));
    }

    function _g4SyExit(IERC20 output_, uint256 shares_) internal {
        IStandardizedYield sy = IStandardizedYield(address(g4.vault));
        uint256 quoted = sy.previewRedeem(address(output_), shares_);
        assertGt(quoted, 0);
        address recipient = address(0xBEEF);
        uint256 beforeOutput = output_.balanceOf(recipient);
        uint256 beforeShares = g4.vault.balanceOf(address(this));
        uint256 beforeSupply = g4.vault.totalSupply();
        uint256 beforeEth = recipient.balance;
        assertEq(sy.redeem(recipient, shares_, address(output_), quoted, false), quoted);
        assertEq(output_.balanceOf(recipient) - beforeOutput, quoted);
        assertEq(g4.vault.balanceOf(address(this)), beforeShares - shares_);
        assertEq(g4.vault.totalSupply(), beforeSupply - shares_);
        assertEq(g4.vault.balanceOf(address(g4.vault)), 0);
        assertEq(recipient.balance, beforeEth);
        _g4Booked();
    }

    /// @notice Imported assets cannot be claimed as new delivery by either an EOA or a code-bearing caller.
    function test_G4_importCannotManufacturePretransferCredit() public {
        uint256 id = _g4Mint(-120, 120, 1_000e18);
        assertGt(_g4Import(id, 0), 0);
        for (uint256 side; side < 2; ++side) {
            IERC20 input = side == 0 ? g4.token0 : g4.token1;
            assertGt(input.balanceOf(address(g4.vault)), 0, "booked sleeve witness");
            bytes32 beforeState = _g4Fingerprint(id);
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1e12), uint256(0)));
            g4.vault.exchangeIn(input, 1e12, IERC20(address(g4.vault)), 0, address(this), true, block.timestamp);
            assertEq(_g4Fingerprint(id), beforeState);
            vm.prank(address(0xBAD));
            vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
            g4.vault.exchangeIn(input, 1e12, IERC20(address(g4.vault)), 0, address(0xBAD), true, block.timestamp);
            assertEq(_g4Fingerprint(id), beforeState);
            assertEq(g4.vault.balanceOf(address(0xBAD)), 0);
            assertEq(input.balanceOf(address(0xBAD)), 0);
        }
    }

    function _g4Booked() internal view {
        assertEq(g4.vault.reserveOfToken(address(g4.token0)), g4.token0.balanceOf(address(g4.vault)));
        assertEq(g4.vault.reserveOfToken(address(g4.token1)), g4.token1.balanceOf(address(g4.vault)));
        assertEq(g4.vault.reserveOfToken(address(g4.vault)), g4.vault.balanceOf(address(g4.vault)));
        assertEq(address(g4.vault).balance, 0);
    }
}
// end::TestBase_UniswapV4FullSpreadG4ImportClosure[]
