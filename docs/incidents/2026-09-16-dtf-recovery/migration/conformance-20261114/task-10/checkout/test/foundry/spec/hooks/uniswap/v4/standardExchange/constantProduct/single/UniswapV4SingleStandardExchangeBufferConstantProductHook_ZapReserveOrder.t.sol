// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Curve
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder_Test
/// @notice Paid joins accept native components against the post-trade book in both currency orders.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder_Test is TestBase {

    /// @dev The production package requires the DETF/raw leg to use eighteen decimals.
    function _rawDecimals() internal pure override returns (uint8) {
        return 18;
    }

    /// @dev Keep pair units different while the real SE wraps at a one-to-one atomic rate.
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    /// @notice Raw input buys native SE components with raw as currency0.
    function test_zapRaw_currency0_independentLpAccounting() public {
        _checkZap(true, true);
    }

    /// @notice Pair input buys raw before caller-only conversion, with raw as currency0.
    function test_zapPair_rawCurrency0_independentLpAccounting() public {
        _checkZap(true, false);
    }

    /// @notice Raw input buys native SE components with raw as currency1.
    function test_zapRaw_currency1_independentLpAccounting() public {
        _checkZap(false, true);
    }

    /// @notice Pair input buys raw before caller-only conversion, with raw as currency1.
    function test_zapPair_rawCurrency1_independentLpAccounting() public {
        _checkZap(false, false);
    }

    function test_zeroBudget_rawCurrency0_preservesClaimInventory() public {
        _checkZeroBudget(true);
    }

    function test_zeroBudget_rawCurrency1_preservesClaimInventory() public {
        _checkZeroBudget(false);
    }

    function test_exitPair_rawCurrency0_independentComponentClaims() public {
        _checkExit(true, true);
    }

    function test_exitPair_rawCurrency1_independentComponentClaims() public {
        _checkExit(false, true);
    }

    function test_exitRaw_currency0_independentComponentClaims() public {
        _checkExit(true, false);
    }

    function test_exitRaw_currency1_independentComponentClaims() public {
        _checkExit(false, false);
    }

    function _checkExit(bool rawFirst, bool pairOutput) internal {
        _seedOrderedHook(rawFirst);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 burn = IERC20(hook).balanceOf(user) / 4;
        uint256 rawBook = rawToken.balanceOf(hook);
        uint256 shareBook = IERC20(se).balanceOf(hook);
        uint256 localBook = pairToken.balanceOf(hook);
        uint256 rawClaim = burn * rawBook / supply;
        uint256 shareClaim = burn * shareBook / supply;
        uint256 localClaim = burn * localBook / supply;
        uint256 rawRemain = rawBook - rawClaim;
        uint256 shareRemain = shareBook - shareClaim;
        uint256 localRemain = localBook - localClaim;
        uint256 pairRemain = shareRemain + localRemain;
        uint256 expected;
        if (pairOutput) {
            uint256 budget = Curve.saleQuote(rawClaim, rawRemain, pairRemain * 1e12) / 1e12;
            uint256 purchasedShares = shareRemain * budget / pairRemain;
            uint256 purchasedLocal = localRemain * budget / pairRemain;
            shareRemain -= purchasedShares;
            localRemain -= purchasedLocal;
            rawRemain += rawClaim;
            // The fixture's final redemption is one-to-one in native units.
            // The internal trade transfers components before that redemption.
            expected = shareClaim + purchasedShares + localClaim + purchasedLocal;
        } else {
            uint256 soldValue = shareClaim + localClaim;
            uint256 purchasedRaw = Curve.saleQuote(soldValue * 1e12, pairRemain * 1e12, rawRemain);
            rawRemain -= purchasedRaw;
            shareRemain += shareClaim;
            localRemain += localClaim;
            expected = rawClaim + purchasedRaw;
        }
        address tokenOut = pairOutput ? address(pairToken) : address(rawToken);
        uint256 userBefore = IERC20(tokenOut).balanceOf(user);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        assertEq(single.previewWithdrawSingle(burn, tokenOut), expected, "independent allocation then curve trade");
        vm.prank(user);
        uint256 out = single.withdrawSingle(burn, tokenOut, user, expected, block.timestamp);
        assertEq(out, expected, "native allocated basket payout");
        assertEq(IERC20(tokenOut).balanceOf(user) - userBefore, expected, "recipient output");
        assertEq(rawToken.balanceOf(hook), rawRemain, "remaining raw after caller-only trade");
        assertEq(IERC20(se).balanceOf(hook), shareRemain, "remaining native shares");
        assertEq(pairToken.balanceOf(hook), localRemain, "remaining native local");
        assertEq(IERC20(hook).totalSupply(), supply - burn, "exit only burns");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "no withdrawal fee");
    }

    function _checkZeroBudget(bool rawFirst) private {
        _seedOrderedHook(rawFirst);
        uint256 amount = 1e9;
        bytes32 before_ = _zeroBudgetSnapshot();
        assertEq(single.previewDepositSingle(address(rawToken), amount), 0, "zero opposite leg cannot mint LP");
        assertEq(ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(hook))), IERC20(address(rawToken)), amount, IERC20(address(pairToken))
        ), 0, "valid rounded-zero swap quote");

        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        vm.prank(user);
        single.depositSingle(address(rawToken), amount, user, 0, block.timestamp);
        assertEq(_zeroBudgetSnapshot(), before_, "unmintable zap rolls back all custody");

        // No approval: ZeroAmount must be raised before attempting the input pull.
        vm.prank(user);
        rawToken.approve(hook, 0);
        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        vm.prank(user);ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(IStandardExchangeIn(hook))), IERC20(address(rawToken)), amount, IERC20(address(pairToken)), 0, user, false, block.timestamp
        );
        assertEq(_zeroBudgetSnapshot(), before_, "zero swap cannot spend existing claim inventory");
    }

    function _zeroBudgetSnapshot() private view returns (bytes32) {
        return keccak256(abi.encode(
            rawToken.balanceOf(user), rawToken.balanceOf(hook), pairToken.balanceOf(user),
            pairToken.balanceOf(hook), IERC20(se).balanceOf(hook), IERC20(se).totalSupply(),
            IERC20(hook).totalSupply(), IERC20(hook).balanceOf(user), single.kLast()
        ));
    }

    /// @dev Reuse the registered package and real SE; only the non-SUT raw token address is selected.
    function _seedOrderedHook(bool rawFirst) internal {
        bytes32 initHash = keccak256(
            abi.encodePacked(type(MintableERC20Decimals).creationCode, abi.encode("Ordered raw", "oRAW", uint8(18)))
        );
        bool found;
        for (uint256 nonce; nonce < 256; ++nonce) {
            bytes32 salt = bytes32(nonce);
            address predicted = vm.computeCreate2Address(salt, initHash, address(this));
            if (predicted == address(pairToken) || (predicted < address(pairToken)) != rawFirst) continue;
            rawToken = new MintableERC20Decimals{salt: salt}("Ordered raw", "oRAW", 18);
            assertEq(address(rawToken), predicted, "selected raw address");
            found = true;
            break;
        }
        assertTrue(found, "raw address with requested currency order");

        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, _defaultPkgArgs());
        hook = PkgFactory.deployHook(hookPkg, _defaultPkgArgs(), mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        single = IHook(hook);
        _bindProductPoolKey();
        assertEq(_isRawCurrency0(), rawFirst, "requested currency order is deployed");
        rawToken.mint(user, _uRaw(1_000));
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        vm.stopPrank();
        // A zero vault override falls back to the global usage fee in this fixture.
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0);
        vm.stopPrank();
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(se), 0, "fee-free SE fixture");
        _enableProtocolFee(0.05e18);
        _depositBoth(_uRaw(300), _uPair(900));
        assertEq(single.rawReserve(), _uRaw(300), "initial raw book");
        assertEq(single.seClaimSupply(), _uPair(900), "one-to-one initial pair claim");
    }

    struct ZapOracle {
        uint256[3] book;
        uint256[3] available;
        uint256[3] userBefore;
        uint256 supply;
        uint256 seSupply;
        uint256 userLp;
        uint256 feeLp;
        uint256 sold;
        uint256 counter;
    }

    /// @dev Native components are ordered raw, SE shares, local pair. No hook mint
    /// quote or production acceptance helper supplies the oracle's gross answer.
    function _checkZap(bool rawFirst, bool rawInput) internal {
        _seedOrderedHook(rawFirst);
        address input = rawInput ? address(rawToken) : address(pairToken);
        uint256 amount = rawInput ? _uRaw(30) : _uPair(90);
        ZapOracle memory q;
        q.book = [rawToken.balanceOf(hook), IERC20(se).balanceOf(hook), pairToken.balanceOf(hook)];
        q.userBefore = [rawToken.balanceOf(user), IERC20(se).balanceOf(user), pairToken.balanceOf(user)];
        q.supply = IERC20(hook).totalSupply();
        q.seSupply = IERC20(se).totalSupply();
        q.userLp = IERC20(hook).balanceOf(user);
        q.feeLp = IERC20(hook).balanceOf(_feeTo());
        uint256 pairBook = q.book[1] + q.book[2]; // Fee-free, one-to-one atomic SE fixture.
        if (rawInput) {
            q.sold = _independentSaleInput(amount, q.book[0]);
            q.counter = _independentSale(q.sold, q.book[0], pairBook * 1e12) / 1e12;
            q.available = [amount - q.sold, q.book[1] * q.counter / pairBook, q.book[2] * q.counter / pairBook];
            q.book[0] += q.sold;
            q.book[1] -= q.available[1];
            q.book[2] -= q.available[2];
        } else {
            q.sold = _independentSaleInput(amount * 1e12, pairBook * 1e12) / 1e12;
            q.counter = _independentSale(q.sold * 1e12, pairBook * 1e12, q.book[0]);
            q.available = [q.counter, uint256(0), amount - q.sold];
            q.book[0] -= q.counter;
            q.book[2] += q.sold; // Native pair sale does not mint incumbent SE shares.
        }
        (uint256 sold, uint256 counter, uint256 kept) = single.previewZapSplit(input, amount);
        assertEq(sold, q.sold, "independent fee-adjusted preparation split");
        assertEq(counter, q.counter, "independent CP output");
        assertEq(kept + sold, amount, "caller input split conserved");
        assertGt(sold, 0, "positive paid sale");
        assertGt(counter, 0, "positive purchased components");
        uint256 preview = single.previewDepositSingle(input, amount);
        assertGt(preview, 0, "positive prepared join");
        bytes32 before_ = _strictJoinState(user);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        single.depositSingle(input, amount, user, preview + 1, block.timestamp);
        assertEq(_strictJoinState(user), before_, "minimum failure rolls back paid trade and conversion");
        vm.prank(user);
        uint256 net = single.depositSingle(input, amount, user, preview, block.timestamp);
        if (rawInput) {
            assertEq(IERC20(se).totalSupply(), q.seSupply, "raw buys shares in kind without SE conversion");
        } else {
            // Observe the actual external conversion receipt, never LP issuance.
            // In this fixture each newly minted SE atom consumes one caller pair atom.
            uint256 acquired = IERC20(se).totalSupply() - q.seSupply;
            assertGt(acquired, 0, "remaining caller pair converts to shares");
            assertLe(acquired, q.available[2], "conversion spends only caller pair");
            q.available[1] = acquired;
            q.available[2] -= acquired;
        }
        _assertZapAcceptance(q, rawInput, amount, net, preview);
    }

    function _assertZapAcceptance(ZapOracle memory q, bool rawInput, uint256 amount, uint256 net, uint256 preview)
        private view
    {
        uint256 gross = type(uint256).max;
        for (uint256 i; i < 3; ++i) {
            assertGt(q.book[i], 0, "fixture has three post-trade components");
            uint256 limit = q.available[i] * q.supply / q.book[i];
            if (limit < gross) gross = limit;
        }
        assertGt(gross, 0, "independently backed gross mint");
        assertEq(IERC20(hook).totalSupply() - q.supply, gross, "maximum native component mint");
        assertEq(net, gross - gross / 20, "five-percent gross fee leaves exact net");
        assertEq(net, preview, "preview equals independently accepted net");
        assertEq(IERC20(hook).balanceOf(user) - q.userLp, net, "recipient net LP");
        assertEq(IERC20(hook).balanceOf(_feeTo()) - q.feeLp, gross / 20, "exact fee LP");
        IERC20[3] memory tokens = [IERC20(address(rawToken)), IERC20(se), IERC20(address(pairToken))];
        bool nextInfeasible;
        for (uint256 i; i < 3; ++i) {
            uint256 accepted = _ceilAcceptance(gross, q.book[i], q.supply);
            assertLe(accepted, q.available[i], "ceil contribution fits caller inventory");
            assertEq(tokens[i].balanceOf(hook), q.book[i] + accepted, "post-trade book plus ceil acceptance");
            uint256 paid = (rawInput && i == 0) || (!rawInput && i == 2) ? amount : 0;
            assertEq(tokens[i].balanceOf(user), q.userBefore[i] - paid + q.available[i] - accepted,
                "all unused native components refunded to caller");
            if (_ceilAcceptance(gross + 1, q.book[i], q.supply) > q.available[i]) nextInfeasible = true;
        }
        assertTrue(nextInfeasible, "one more gross LP exceeds a caller component");
        assertEq(single.rawReserve(), rawToken.balanceOf(hook), "native raw book equals custody");
        assertEq(single.seClaimSupply(), IERC20(se).balanceOf(hook) + pairToken.balanceOf(hook),
            "native pair components equal rated book");
    }

    function _ceilAcceptance(uint256 gross, uint256 component, uint256 supply) private pure returns (uint256) {
        uint256 product = gross * component;
        return product / supply + (product % supply == 0 ? 0 : 1);
    }

    /// @dev Solve the 0.3%-fee balancing equation by integer search, independently
    /// of the production quadratic square-root implementation. Fixture products fit uint256.
    function _independentSaleInput(uint256 amount, uint256 reserve) private pure returns (uint256 lo) {
        uint256 hi = amount;
        while (lo < hi) {
            uint256 mid = lo + (hi - lo + 1) / 2;
            if (mid * (997 * mid + 1997 * reserve) <= 1000 * reserve * amount) lo = mid;
            else hi = mid - 1;
        }
    }

    function _independentSale(uint256 amount, uint256 reserveIn, uint256 reserveOut)
        private pure returns (uint256)
    {
        return amount * 997 * reserveOut / (reserveIn * 1000 + amount * 997);
    }
}
