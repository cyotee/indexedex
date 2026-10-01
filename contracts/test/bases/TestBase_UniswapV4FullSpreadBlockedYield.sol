// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

interface IFullSpreadBlockedReserve {
    function canOpenPoolManagerUnlock() external view returns (bool);
    function deployedReserve() external view returns (uint256, uint256);
}

// tag::TestBase_UniswapV4FullSpreadBlockedYield[]
/// @notice Equivalence and rollback assertions; fixtures retain independent family economics.
abstract contract TestBase_UniswapV4FullSpreadBlockedYield is Test {
    IStandardExchangeProxy internal yieldVault;
    IERC20[2] internal yieldTokens;
    uint256[2] internal yieldUnits;

    function _yieldBlocked(bytes memory data_) internal virtual returns (bytes memory);
    function _yieldFeesHash() internal view virtual returns (bytes32) { return bytes32(0); }

    function _startYield(IStandardExchangeProxy vault_, uint256[2] memory units_) internal {
        yieldVault = vault_; yieldUnits = units_;
        address[] memory tokens = vault_.vaultTokens();
        yieldTokens = [IERC20(tokens[0]), IERC20(tokens[1])];
        yieldTokens[0].approve(address(vault_), type(uint256).max);
        yieldTokens[1].approve(address(vault_), type(uint256).max);
    }

    function _yieldEquivalence(uint256 mode_) internal {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 amount = mode_ == 0 ? yieldUnits[leg] : yieldVault.balanceOf(address(this)) / 100_000;
            uint256 residual = mode_ == 2 ? amount / 2 : 0;
            assertGt(amount, 0);
            if (mode_ == 2) yieldVault.transfer(address(yieldVault), amount + residual);
            assertFalse(abi.decode(_yieldBlocked(abi.encodeCall(IFullSpreadBlockedReserve.canOpenPoolManagerUnlock, ())), (bool)));
            bytes32 fees = _yieldFeesHash();
            uint256 snapshot = vm.snapshotState();
            uint256 seResult = _yieldExchange(mode_, leg, amount, false);
            bytes32 expectedState = _yieldStateHash();
            assertTrue(vm.revertToStateAndDelete(snapshot));
            uint256 supply = yieldVault.totalSupply();
            uint256 callerShares = yieldVault.balanceOf(address(this));
            uint256 tokenBalance = yieldTokens[leg].balanceOf(address(this));
            uint256 syResult = _yieldExchange(mode_, leg, amount, true);
            assertGt(syResult, 0); assertEq(syResult, seResult);
            assertEq(_yieldStateHash(), expectedState);
            assertEq(_yieldFeesHash(), fees, "blocked SY cannot charge hook");
            if (mode_ == 0) {
                assertEq(yieldVault.totalSupply(), supply + syResult);
                assertEq(yieldVault.balanceOf(address(this)), callerShares + syResult);
                assertEq(tokenBalance - yieldTokens[leg].balanceOf(address(this)), amount);
            } else {
                assertEq(yieldVault.totalSupply(), supply - amount);
                assertEq(yieldVault.balanceOf(address(this)), mode_ == 2 ? callerShares : callerShares - amount);
                assertEq(yieldTokens[leg].balanceOf(address(this)) - tokenBalance, syResult);
            }
            _assertYieldBooked(residual);
            assertTrue(IFullSpreadBlockedReserve(address(yieldVault)).canOpenPoolManagerUnlock());
            // Carry no self-share credit into the next independent directional comparison.
            if (residual != 0) {
                _yieldExchange(2, leg, residual, true);
                _assertYieldBooked(0);
            }
        }
    }

    function _yieldExchange(uint256 mode_, uint256 leg_, uint256 amount_, bool sy_) private returns (uint256) {
        IERC20 token = yieldTokens[leg_];
        uint256 quote = abi.decode(_yieldBlocked(mode_ == 0
            ? abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (token, amount_, IERC20(address(yieldVault))))
            : abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(yieldVault)), amount_, token))), (uint256));
        bytes memory data;
        if (sy_) {
            uint256 syQuote = abi.decode(_yieldBlocked(mode_ == 0
                ? abi.encodeCall(SY.previewDeposit, (address(token), amount_))
                : abi.encodeCall(SY.previewRedeem, (address(token), amount_))), (uint256));
            assertEq(syQuote, quote);
            data = mode_ == 0 ? abi.encodeCall(SY.deposit, (address(this), address(token), amount_, quote))
                : abi.encodeCall(SY.redeem, (address(this), amount_, address(token), quote, mode_ == 2));
        } else {
            data = mode_ == 0
                ? abi.encodeCall(IStandardExchangeIn.exchangeIn, (token, amount_, IERC20(address(yieldVault)), quote, address(this), false, block.timestamp))
                : abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(yieldVault)), amount_, token, quote, address(this), mode_ == 2, block.timestamp));
        }
        return abi.decode(_yieldBlocked(data), (uint256));
    }

    function _yieldCoverRollback(bool internal_) internal {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 snapshot = vm.snapshotState();
            uint256 burn = yieldVault.balanceOf(address(this)) * 9 / 10;
            bytes memory expected = _yieldShortage(leg, burn);
            if (internal_) yieldVault.transfer(address(yieldVault), burn + 1);
            bytes32 beforeState = _yieldStateHash();
            bytes memory se = abi.encodeCall(IStandardExchangeIn.exchangeIn,
                (IERC20(address(yieldVault)), burn, yieldTokens[leg], 0, address(this), internal_, block.timestamp));
            _expectYieldRollback(se, expected, beforeState);
            bytes memory sy = abi.encodeCall(SY.redeem, (address(this), burn, address(yieldTokens[leg]), 0, internal_));
            _expectYieldRollback(sy, expected, beforeState);
            if (internal_) {
                uint256 small = burn / 1_000;
                uint256 received = _yieldExchange(2, leg, small, true);
                assertGt(received, 0);
                _assertYieldBooked(burn + 1 - small);
            }
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function _yieldShortage(uint256 leg_, uint256 burn_) private view returns (bytes memory) {
        uint256 supply = yieldVault.totalSupply();
        uint256 cover = yieldTokens[leg_].balanceOf(address(yieldVault));
        (uint256 d0, uint256 d1) = IFullSpreadBlockedReserve(address(yieldVault)).deployedReserve();
        // These fresh activation fixtures have no uncollected own LP fees: P's
        // launch has zero LP fees and H activation makes no external swaps.
        uint256[2] memory backing = [d0 + yieldTokens[0].balanceOf(address(yieldVault)), d1 + yieldTokens[1].balanceOf(address(yieldVault))];
        uint256 u = Math.mulDiv(backing[leg_], burn_, supply);
        uint256 v = Math.mulDiv(backing[1 - leg_], burn_, supply);
        uint256 wanted = u + (v == 0 ? 0 : Math.mulDiv(backing[leg_] - u, v, backing[1 - leg_]));
        assertGt(wanted, cover, "fixture must lack local output cover");
        assertLt(burn_, supply);
        return abi.encodeWithSignature("UniswapV4Exchange_InsufficientLocalReserve(address,uint256,uint256)", address(yieldTokens[leg_]), wanted, cover);
    }

    function executeYieldBlocked(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(this), "test self call only");
        return _yieldBlocked(data_);
    }

    function _expectYieldRollback(bytes memory data_, bytes memory expected_, bytes32 before_) private {
        (bool ok, bytes memory error) = address(this).call(abi.encodeCall(this.executeYieldBlocked, (data_)));
        assertFalse(ok); assertEq(error, expected_); assertEq(_yieldStateHash(), before_);
    }

    function _yieldStateHash() private view returns (bytes32) {
        (bytes memory state,) = Transition(address(yieldVault)).quoteState(address(yieldTokens[0]), address(this));
        return keccak256(abi.encode(state, _yieldFeesHash(), yieldVault.balanceOf(address(yieldVault)),
            yieldVault.balanceOf(address(0xdEaD)), yieldVault.reserveOfToken(address(yieldVault)),
            yieldVault.reserveOfToken(address(yieldTokens[0])), yieldVault.reserveOfToken(address(yieldTokens[1])),
            yieldTokens[0].balanceOf(address(this)), yieldTokens[1].balanceOf(address(this)), address(yieldVault).balance));
    }

    function _assertYieldBooked(uint256 residual_) private view {
        assertEq(yieldVault.balanceOf(address(yieldVault)), residual_);
        assertEq(yieldVault.reserveOfToken(address(yieldVault)), residual_);
        for (uint256 i; i < 2; ++i) assertEq(yieldVault.reserveOfToken(address(yieldTokens[i])), yieldTokens[i].balanceOf(address(yieldVault)));
        assertEq(address(yieldVault).balance, 0);
    }
}
// end::TestBase_UniswapV4FullSpreadBlockedYield[]
