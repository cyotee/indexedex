// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote as Context} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote as Quantity} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as Shapes} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";

library FullSpreadQuantityReference {
    function backing(bytes memory state_) internal pure returns (Shapes.Snapshot memory q, uint256 selected, uint256 other) {
        q = abi.decode(state_, (Shapes.Snapshot));
        uint160 a = TickMath.getSqrtPriceAtTick(q.lower);
        uint160 b = TickMath.getSqrtPriceAtTick(q.upper);
        uint160 p = q.pool.sqrtPriceX96;
        uint256 b0 = q.free0 + q.fees0;
        uint256 b1 = q.free1 + q.fees1;
        if (p < b) b0 += SqrtPriceMath.getAmount0Delta(p > a ? p : a, b, q.positionLiquidity, false);
        if (p > a) b1 += SqrtPriceMath.getAmount1Delta(a, p < b ? p : b, q.positionLiquidity, false);
        return (q, q.token0 ? b0 : b1, q.token0 ? b1 : b0);
    }

    function input(bytes memory state_, uint256 shares_) internal pure returns (uint256) {
        (Shapes.Snapshot memory q, uint256 selected, uint256 other) = backing(state_);
        if (other == 0) return Math.mulDiv(shares_, selected, q.supply, Math.Rounding.Ceil);
        uint256 product = selected * other;
        uint256 root = Math.sqrt(product);
        if (root * root < product) ++root;
        uint256 needed = root + Math.mulDiv(shares_, root, q.supply, Math.Rounding.Ceil);
        return Math.mulDiv(needed, needed, other, Math.Rounding.Ceil) - selected;
    }
}

abstract contract TestBase_UniswapV4FullSpreadExactOutputQuantity is Test {
    IStandardExchangeProxy internal quantityVault;
    address internal quantityManager;
    uint256[2] internal quantityUnits;
    function _quantityBlocked(bytes memory data_) internal virtual returns (bytes memory);

    function _startQuantity(IStandardExchangeProxy vault_, address manager_, uint256[2] memory units_) internal {
        quantityVault = vault_; quantityManager = manager_; quantityUnits = units_;
        address[] memory tokens = vault_.vaultTokens();
        IERC20(tokens[0]).approve(address(vault_), type(uint256).max);
        IERC20(tokens[1]).approve(address(vault_), type(uint256).max);
    }

    function test_quantityF1BothFacesZeroHolderAndRealExactShareIssuance() public {
        address[] memory tokens = quantityVault.vaultTokens();
        assertTrue(IERC165(address(quantityVault)).supportsInterface(type(Quantity).interfaceId));
        for (uint256 i; i < 2; ++i) {
            (bytes memory ordinary,) = Transition(address(quantityVault)).quoteState(tokens[i], address(0));
            bytes memory state = Context(address(quantityVault)).quoteStateWithUnavailableUnlock(ordinary, quantityManager);
            assertEq(Transition(address(quantityVault)).quoteShareBalance(state), 0);
            uint256 shares = quantityVault.totalSupply() / 1_000_000;
            uint256 required = Quantity(address(quantityVault)).quoteInputForExactShares(state, shares);
            assertGt(required, 0); assertEq(required, FullSpreadQuantityReference.input(state, shares));
            assertEq(abi.decode(_quantityBlocked(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
                (IERC20(tokens[i]), IERC20(address(quantityVault)), shares))), (uint256)), required);
            uint256 beforeBalance = IERC20(tokens[i]).balanceOf(address(this));
            uint256 beforeShares = quantityVault.balanceOf(address(this));
            assertEq(abi.decode(_quantityBlocked(abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (IERC20(tokens[i]), required, IERC20(address(quantityVault)), shares, address(this), false, block.timestamp))), (uint256)), required);
            assertEq(beforeBalance - IERC20(tokens[i]).balanceOf(address(this)), required);
            assertEq(quantityVault.balanceOf(address(this)) - beforeShares, shares);
        }
    }

    function test_quantityUsesSuppliedPostTransitionBookRatherThanLiveBook() public {
        address[] memory tokens = quantityVault.vaultTokens();
        for (uint256 i; i < 2; ++i) {
            (bytes memory ordinary,) = Transition(address(quantityVault)).quoteState(tokens[i], address(0));
            bytes memory state = Context(address(quantityVault)).quoteStateWithUnavailableUnlock(ordinary, quantityManager);
            (bytes memory next,,,) = Transition(address(quantityVault)).quoteTransition(state, Transition.Operation.DepositExactIn, quantityUnits[i] * 100);
            uint256 shares = quantityVault.totalSupply() / 1_000_000;
            uint256 expected = FullSpreadQuantityReference.input(next, shares);
            assertTrue(expected != FullSpreadQuantityReference.input(state, shares), "meaningful projected change required");
            assertEq(Quantity(address(quantityVault)).quoteInputForExactShares(next, shares), expected);
            (bytes memory unchanged,) = Transition(address(quantityVault)).quoteState(tokens[i], address(0));
            assertEq(ordinary, unchanged);
        }
    }

    function test_quantityIdleMintAndTwoLegExitRemainInvalidBothFaces() public {
        address[] memory tokens = quantityVault.vaultTokens();
        for (uint256 i; i < 2; ++i) {
            (bytes memory state,) = Transition(address(quantityVault)).quoteState(tokens[i], address(0));
            assertEq(Quantity(address(quantityVault)).quoteInputForExactShares(state, 0), 0);
            assertEq(Quantity(address(quantityVault)).quoteSharesForExactAssets(state, 0), 0);
            vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, tokens[i], address(quantityVault)));
            Quantity(address(quantityVault)).quoteInputForExactShares(state, 1);
            state = Context(address(quantityVault)).quoteStateWithUnavailableUnlock(state, quantityManager);
            vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(quantityVault), tokens[i]));
            Quantity(address(quantityVault)).quoteSharesForExactAssets(state, 1);
        }
    }

    function test_quantityZeroStillValidatesMalformedAndForeignSnapshots() public {
        _quantityReject("");
        (bytes memory state,) = Transition(address(quantityVault)).quoteState(quantityVault.vaultTokens()[0], address(0));
        Shapes.Snapshot memory foreign = abi.decode(state, (Shapes.Snapshot));
        foreign.vault = address(0x1234);
        _quantityReject(abi.encode(foreign));
    }

    function _quantityReject(bytes memory state_) private view {
        (bool ok, bytes memory expected) = address(quantityVault).staticcall(abi.encodeCall(Transition.quoteShareBalance, (state_)));
        assertFalse(ok);
        (bool accepted, bytes memory reason) = address(quantityVault).staticcall(abi.encodeCall(Quantity.quoteInputForExactShares, (state_, 0)));
        assertFalse(accepted); assertEq(reason, expected);
        (accepted, reason) = address(quantityVault).staticcall(abi.encodeCall(Quantity.quoteSharesForExactAssets, (state_, 0)));
        assertFalse(accepted); assertEq(reason, expected);
    }
}
