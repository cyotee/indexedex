// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote as ContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";

// tag::TestBase_UniswapV4FullSpreadUnlockContextQuote[]
/// @notice Read-only context projection compared with actual outer-unlock execution.
abstract contract TestBase_UniswapV4FullSpreadUnlockContextQuote is Test {
    struct PoolSnapshot { uint160 sqrtPriceX96; int24 tick; uint128 liquidity; }
    struct Snapshot {
        address vault; bool token0; bool idle; uint256 supply; uint256 shares;
        uint256 free0; uint256 free1; uint256 fees0; uint256 fees1;
        uint128 positionLiquidity; int24 lower; int24 upper; int128 liquidityDelta;
        PoolSnapshot pool; uint256 sleeveWad; uint256[2] absoluteFloor;
        uint128 lowerLiquidityGross; uint128 upperLiquidityGross; uint128 maxLiquidityPerTick;
    }
    struct Parity {
        IERC20 asset; uint256 amount; bytes projected; bytes next;
        uint256 amountIn; uint256 amountOut; uint256 holderAfter;
        uint256 beforeToken; uint256 beforeShares; uint256 beforeSupply;
    }

    IStandardExchangeProxy internal contextVault;
    IPoolManager internal contextManager;
    IFacet internal contextFacet;
    uint256[2] internal contextUnits;

    function _contextBlocked(bytes memory data_) internal virtual returns (bytes memory);
    function _contextFeesHash() internal view virtual returns (bytes32) { return bytes32(0); }
    function _contextOtherManager() internal view virtual returns (address) { return address(this); }

    function _startContext(IStandardExchangeProxy vault_, IPoolManager manager_, IFacet facet_, uint256[2] memory units_) internal {
        contextVault = vault_; contextManager = manager_; contextFacet = facet_; contextUnits = units_;
        address[] memory tokens = vault_.vaultTokens();
        IERC20(tokens[0]).approve(address(vault_), type(uint256).max);
        IERC20(tokens[1]).approve(address(vault_), type(uint256).max);
    }

    function test_optionalContextAdvertisedAndCallableOnProxy() public view {
        assertTrue(type(ContextQuote).interfaceId != type(Transition).interfaceId);
        assertTrue(IERC165(address(contextVault)).supportsInterface(type(ContextQuote).interfaceId));
        assertTrue(IERC165(address(contextVault)).supportsInterface(type(Transition).interfaceId));
        assertEq(IDiamondLoupe(address(contextVault)).facetAddress(ContextQuote.quoteStateWithUnavailableUnlock.selector), address(contextFacet));
        bytes4[] memory interfaces = contextFacet.facetInterfaces();
        bool declared;
        for (uint256 i; i < interfaces.length; ++i) if (interfaces[i] == type(ContextQuote).interfaceId) declared = true;
        assertTrue(declared);
        (bytes memory original,) = Transition(address(contextVault)).quoteState(contextVault.vaultTokens()[0], address(this));
        assertGt(ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(original, address(contextManager)).length, 0);
    }

    function test_matchingManagerChangesOnlyIdleAndMatchesOuterSnapshot() public {
        address[] memory tokens = contextVault.vaultTokens();
        for (uint256 i; i < 2; ++i) {
            (bytes memory original,) = Transition(address(contextVault)).quoteState(tokens[i], address(this));
            Snapshot memory expected = abi.decode(original, (Snapshot));
            assertTrue(expected.idle);
            uint256 ordinary = contextVault.previewExchangeIn(IERC20(tokens[i]), contextUnits[i], IERC20(address(contextVault)));
            bytes32 fees = _contextFeesHash();
            expected.idle = false;
            bytes memory projected = ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(original, address(contextManager));
            assertEq(projected, abi.encode(expected));
            (bytes memory actualBlocked, uint256 claim) = abi.decode(_contextBlocked(abi.encodeCall(
                Transition.quoteState, (tokens[i], address(this)))), (bytes, uint256));
            assertEq(projected, actualBlocked);
            assertEq(Transition(address(contextVault)).quoteAssets(projected, expected.shares), claim);
            (bytes memory live,) = Transition(address(contextVault)).quoteState(tokens[i], address(this));
            assertEq(live, original, "context projection cannot change live state");
            assertEq(contextVault.previewExchangeIn(IERC20(tokens[i]), contextUnits[i], IERC20(address(contextVault))), ordinary);
            assertEq(_contextFeesHash(), fees);
        }
    }

    function test_mismatchAndAlreadyBlockedPreserveExactBytes() public {
        (bytes memory original,) = Transition(address(contextVault)).quoteState(contextVault.vaultTokens()[0], address(this));
        bytes memory padded = bytes.concat(original, hex"cafebabe");
        assertEq(ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(padded, _contextOtherManager()), padded);
        assertEq(ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(padded, address(0)), padded);
        bytes memory blocked = ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(original, address(contextManager));
        assertFalse(abi.decode(blocked, (Snapshot)).idle);
        bytes memory paddedBlocked = bytes.concat(blocked, hex"cafebabe");
        assertEq(ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(paddedBlocked, address(contextManager)), paddedBlocked);
        assertEq(ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(paddedBlocked, _contextOtherManager()), paddedBlocked);
    }

    function test_suppliedProjectedStatePreservedRatherThanResnapshot() public view {
        (bytes memory original,) = Transition(address(contextVault)).quoteState(contextVault.vaultTokens()[0], address(this));
        (bytes memory next,, uint256 minted,) = Transition(address(contextVault)).quoteTransition(original, Transition.Operation.DepositExactIn, contextUnits[0]);
        assertGt(minted, 0);
        Snapshot memory expected = abi.decode(next, (Snapshot));
        assertGt(expected.supply, abi.decode(original, (Snapshot)).supply);
        expected.idle = false;
        assertEq(ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(next, address(contextManager)), abi.encode(expected));
        (bytes memory live,) = Transition(address(contextVault)).quoteState(contextVault.vaultTokens()[0], address(this));
        assertEq(live, original);
    }

    function test_decoderValidationPrecedesManagerMatch() public view {
        _rejectInvalidState("");
        _rejectInvalidState(abi.encode(uint256(1)));
        (bytes memory original,) = Transition(address(contextVault)).quoteState(contextVault.vaultTokens()[0], address(this));
        Snapshot memory invalid = abi.decode(original, (Snapshot));
        invalid.vault = address(0x1234); _rejectInvalidState(abi.encode(invalid));
        invalid = abi.decode(original, (Snapshot));
        invalid.shares = invalid.supply + 1; _rejectInvalidState(abi.encode(invalid));
        invalid = abi.decode(original, (Snapshot));
        invalid.lower = invalid.upper; _rejectInvalidState(abi.encode(invalid));
    }

    function _rejectInvalidState(bytes memory state_) private view {
        (bool valid, bytes memory expected) = address(contextVault).staticcall(abi.encodeCall(Transition.quoteShareBalance, (state_)));
        assertFalse(valid, "fixture must fail existing decoder");
        for (uint256 i; i < 2; ++i) {
            (bool accepted, bytes memory actual) = address(contextVault).staticcall(abi.encodeCall(
                ContextQuote.quoteStateWithUnavailableUnlock, (state_, i == 0 ? address(contextManager) : _contextOtherManager())));
            assertFalse(accepted); assertEq(actual, expected);
        }
    }

    function test_contextualDepositMatchesRealBlockedExecutionBothDirections() public {
        _bothDirections(true);
    }

    function test_contextualRedeemMatchesRealBlockedExecutionBothDirections() public {
        _bothDirections(false);
    }

    function _bothDirections(bool deposit_) private {
        for (uint256 i; i < 2; ++i) {
            uint256 saved = vm.snapshotState();
            _parity(deposit_, i);
            assertTrue(vm.revertToStateAndDelete(saved));
        }
    }

    function _parity(bool deposit_, uint256 leg_) private {
        Parity memory f;
        f.asset = IERC20(contextVault.vaultTokens()[leg_]);
        f.amount = deposit_ ? contextUnits[leg_] : contextVault.balanceOf(address(this)) / 1_000_000;
        assertGt(f.amount, 0);
        (bytes memory original,) = Transition(address(contextVault)).quoteState(address(f.asset), address(this));
        f.projected = ContextQuote(address(contextVault)).quoteStateWithUnavailableUnlock(original, address(contextManager));
        (f.next, f.amountIn, f.amountOut, f.holderAfter) = Transition(address(contextVault)).quoteTransition(
            f.projected, deposit_ ? Transition.Operation.DepositExactIn : Transition.Operation.RedeemExactIn, f.amount);
        assertEq(f.amountIn, f.amount); assertGt(f.amountOut, 0);
        f.beforeToken = f.asset.balanceOf(address(this));
        f.beforeShares = contextVault.balanceOf(address(this)); f.beforeSupply = contextVault.totalSupply();
        bytes32 fees = _contextFeesHash();
        uint256 received = abi.decode(_contextBlocked(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (deposit_ ? f.asset : IERC20(address(contextVault)), f.amount,
            deposit_ ? IERC20(address(contextVault)) : f.asset, f.amountOut, address(this), false, block.timestamp))), (uint256));
        assertEq(received, f.amountOut);
        (bytes memory actual, uint256 holderAssets) = abi.decode(_contextBlocked(abi.encodeCall(
            Transition.quoteState, (address(f.asset), address(this)))), (bytes, uint256));
        assertEq(actual, f.next, "complete blocked transition state");
        assertEq(holderAssets, f.holderAfter);
        assertEq(_contextFeesHash(), fees);
        if (deposit_) {
            assertEq(f.beforeToken - f.asset.balanceOf(address(this)), f.amount);
            assertEq(contextVault.balanceOf(address(this)), f.beforeShares + f.amountOut);
            assertEq(contextVault.totalSupply(), f.beforeSupply + f.amountOut);
        } else {
            assertEq(f.asset.balanceOf(address(this)) - f.beforeToken, f.amountOut);
            assertEq(contextVault.balanceOf(address(this)), f.beforeShares - f.amount);
            assertEq(contextVault.totalSupply(), f.beforeSupply - f.amount);
        }
        address[] memory tokens = contextVault.vaultTokens();
        for (uint256 i; i < 2; ++i) assertEq(contextVault.reserveOfToken(tokens[i]), IERC20(tokens[i]).balanceOf(address(contextVault)));
        assertEq(contextVault.reserveOfToken(address(contextVault)), contextVault.balanceOf(address(contextVault)));
        assertEq(address(contextVault).balance, 0);
    }
}
// end::TestBase_UniswapV4FullSpreadUnlockContextQuote[]
